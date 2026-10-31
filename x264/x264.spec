# x264 makes no releases. Packaged from a snapshot of upstream's stable
# branch; to update, take the head of that branch and its revision number
# (the commit count, as printed by version.sh in a git checkout).
#
# The ABI (X264_BUILD, the soname) matches RPM Fusion's x264, so packages
# built against either library work with both.

%global api     165
%global commit  b35605ace3ddf7c1a5d67a2eb553f034aef41d55
%global shortcommit %(c=%{commit}; echo ${c:0:7})
%global date    20250608
%global rev     3222

Name:           x264
Version:        0.%{api}^%{date}git%{shortcommit}
Release:        1%{?dist}
Summary:        H.264/AVC video encoder

License:        GPL-2.0-or-later
URL:            https://www.videolan.org/developers/x264.html
Source0:        https://code.videolan.org/videolan/x264/-/archive/%{commit}/x264-%{commit}.tar.bz2

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  nasm
BuildRequires:  pkgconfig(bash-completion)

Requires:       %{name}-libs%{?_isa} = %{version}-%{release}

%description
x264 is a library and command line tool for encoding video streams into the
H.264/MPEG-4 AVC format.

This package contains the command line encoder. It reads raw and Y4M input;
reading other formats through FFmpeg is not built in, to avoid a dependency
loop with ffmpeg, which links libx264.

%package        libs
Summary:        H.264/AVC video encoder library
# OpenCL lookahead is loaded at run time when an OpenCL driver is present
Recommends:     libOpenCL.so.1()(64bit)

%description    libs
x264 is a library for encoding video streams into the H.264/MPEG-4 AVC
format. This build encodes at both 8 and 10 bits per sample.

%package        devel
Summary:        Development files for the x264 library
Requires:       %{name}-libs%{?_isa} = %{version}-%{release}

%description    devel
Headers and pkg-config file for building against libx264.

%prep
%autosetup -n x264-%{commit}
# version.sh reads the revision from git, which a tarball does not have
cat > version.sh <<'EOF'
#!/bin/sh
echo '#define X264_REV %{rev}'
echo '#define X264_REV_DIFF 0'
echo '#define X264_VERSION " r%{rev} %{shortcommit}"'
echo '#define X264_POINTVER "0.%{api}.%{rev} %{shortcommit}"'
EOF
grep -q '#define X264_BUILD %{api}$' x264.h
# Load the versioned OpenCL library, as the unversioned one is only in -devel
sed -i 's/dlopen( "libOpenCL.so",/dlopen( "libOpenCL.so.1",/' common/opencl.c
grep -q '"libOpenCL.so.1"' common/opencl.c

%build
%set_build_flags
# Not an autoconf script. --bit-depth=all puts the 8 and 10 bit encoders in
# one library; the CLI's FFmpeg, ffms and gpac inputs are left out (see
# %%description).
./configure \
    --prefix=%{_prefix} \
    --bindir=%{_bindir} \
    --includedir=%{_includedir} \
    --libdir=%{_libdir} \
    --extra-cflags="$CFLAGS" \
    --extra-ldflags="$LDFLAGS" \
    --bit-depth=all \
    --enable-shared \
    --enable-pic \
    --enable-debug \
    --system-libx264 \
    --disable-lavf \
    --disable-swscale \
    --disable-ffms \
    --disable-gpac \
    --disable-lsmash
%make_build

%install
%make_install

%check
LD_LIBRARY_PATH=%{buildroot}%{_libdir} %{buildroot}%{_bindir}/x264 --version | grep -q '0.%{api}.%{rev}'

%files
%{_bindir}/x264
%{bash_completions_dir}/x264

%files libs
%license COPYING
%doc AUTHORS
%{_libdir}/libx264.so.%{api}

%files devel
%doc doc/*.txt
%{_includedir}/x264.h
%{_includedir}/x264_config.h
%{_libdir}/libx264.so
%{_libdir}/pkgconfig/x264.pc

%changelog
* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 0.165^20250608gitb35605a-1
- Initial package
