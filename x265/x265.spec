# The 10 and 12 bit encoders are built as static libraries and linked into
# the 8 bit libx265, upstream's "multilib" build (build/linux/multilib.sh), so
# one library encodes at every bit depth.
#
# The ABI (X265_BUILD, the soname) matches RPM Fusion's x265, so that packages
# built against either library work with both. Keep the version in step with
# RPM Fusion's while their packages are installed alongside these: a newer
# x265 changes the soname.

%global so_version 215

Name:           x265
Version:        4.1
Release:        1%{?dist}
Summary:        H.265/HEVC video encoder

# source/Lib/TLibCommon and source/Lib/TLibEncoder are BSD-3-Clause; the rest
# is GPL-2.0-or-later. json11 (dynamicHDR10) is MIT.
License:        GPL-2.0-or-later AND BSD-3-Clause AND MIT
URL:            https://www.x265.org/
Source0:        https://bitbucket.org/multicoreware/x265_git/downloads/x265_%{version}.tar.gz

# Build with -DPIC, so the assembly is position independent too (from RPM
# Fusion)
Patch0:         x265-pic.patch
# Missing include, an error with GCC 15 (from RPM Fusion)
Patch1:         x265-json11-cstdint.patch
# Crash when the length of user SEI messages changes between frames
# https://bitbucket.org/multicoreware/x265_git/pull-requests/10
Patch2:         x265-sei-length-crash-fix.patch

BuildRequires:  cmake
BuildRequires:  gcc-c++
# The build reads the version from x265Version.txt only when git is installed
BuildRequires:  git-core
BuildRequires:  nasm
BuildRequires:  numactl-devel

Requires:       %{name}-libs%{?_isa} = %{version}-%{release}

%description
x265 is an encoder for the H.265/High Efficiency Video Coding (HEVC) format.

This package contains the command line encoder.

%package        libs
Summary:        H.265/HEVC video encoder library

%description    libs
x265 is a library for encoding video into the H.265/High Efficiency Video
Coding (HEVC) format. This build encodes at 8, 10 and 12 bits per sample.

%package        devel
Summary:        Development files for the x265 library
Requires:       %{name}-libs%{?_isa} = %{version}-%{release}

%description    devel
Headers and pkg-config file for building against libx265.

%prep
%autosetup -p1 -n x265_%{version}
# CMake 4 no longer accepts the OLD behaviour of these policies (as upstream
# did after 4.1)
sed -i -E '/cmake_policy\(SET CMP00(25|54) OLD\)/d' source/CMakeLists.txt
if grep -q 'cmake_policy(SET CMP00[0-9]* OLD)' source/CMakeLists.txt; then exit 1; fi

%build
# Upstream's CMakeLists predates CMake 3.5. LIB_INSTALL_DIR is made relative
# because x265.pc prefixes it with ${exec_prefix}.
%define _vpath_srcdir source
%define x265_cmake \
%cmake \\\
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \\\
    -DCMAKE_ASM_NASM_FLAGS=-w-macro-params-legacy \\\
    -DCMAKE_SKIP_RPATH=ON \\\
    -DLIB_INSTALL_DIR=%{_lib} \\\
    -DENABLE_PIC=ON \\\
    -DENABLE_HDR10_PLUS=ON

%define _vpath_builddir build-12bit
%{x265_cmake} \
    -DHIGH_BIT_DEPTH=ON \
    -DMAIN12=ON \
    -DEXPORT_C_API=OFF \
    -DENABLE_SHARED=OFF \
    -DENABLE_CLI=OFF
%cmake_build

%define _vpath_builddir build-10bit
%{x265_cmake} \
    -DHIGH_BIT_DEPTH=ON \
    -DEXPORT_C_API=OFF \
    -DENABLE_SHARED=OFF \
    -DENABLE_CLI=OFF
%cmake_build

%define _vpath_builddir build-8bit
mkdir -p %{__cmake_builddir}
ln -sf ../build-10bit/libx265.a %{__cmake_builddir}/libx265_main10.a
ln -sf ../build-12bit/libx265.a %{__cmake_builddir}/libx265_main12.a
%{x265_cmake} \
    -DENABLE_SHARED=ON \
    -DEXTRA_LIB="x265_main10.a;x265_main12.a" \
    -DEXTRA_LINK_FLAGS=-L. \
    -DLINKED_10BIT=ON \
    -DLINKED_12BIT=ON
%cmake_build

%install
%cmake_install
rm %{buildroot}%{_libdir}/libx265.a %{buildroot}%{_libdir}/libhdr10plus.a

%check
export LD_LIBRARY_PATH=%{buildroot}%{_libdir}
%{buildroot}%{_bindir}/x265 --version 2>&1 | grep -q 'version %{version}+'
grep -q '^Version: %{version}$' %{buildroot}%{_libdir}/pkgconfig/x265.pc
for depth in 8 10 12; do
    head -c $((64 * 64 * 3 / 2 * 4)) /dev/zero |
        %{buildroot}%{_bindir}/x265 --input - --input-res 64x64 --fps 25 \
            --output-depth $depth --frames 4 --log-level error -o out.hevc
    test -s out.hevc
done

%files
%{_bindir}/x265

%files libs
%license COPYING
%{_libdir}/libx265.so.%{so_version}
# HDR10+ metadata library, unversioned upstream (as in RPM Fusion's x265-libs)
%{_libdir}/libhdr10plus.so

%files devel
%doc doc/reST/*.rst
%{_includedir}/x265.h
%{_includedir}/x265_config.h
%{_includedir}/hdr10plus.h
%{_libdir}/libx265.so
%{_libdir}/pkgconfig/x265.pc

%changelog
* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 4.1-1
- Initial package
