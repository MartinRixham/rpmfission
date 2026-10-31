# The full Intel media driver (iHD), for VA-API decoding, encoding and video
# processing on Broadwell and newer Intel graphics. Fedora's build
# (libva-intel-media-driver) leaves out the precompiled GPU kernels, which
# some encoders and video processing features need; this build has them.
#
# Installed in %%{_libdir}/dri-nonfree, which Fedora's libva searches before
# %%{_libdir}/dri, so it takes over from Fedora's driver without conflicting
# with it. Named like RPM Fusion's build, which it replaces.

Name:           intel-media-driver
Version:        26.3.5
Release:        2%{?dist}
Summary:        Intel Media Driver for VA-API, with all kernels

# The driver is MIT; the VP8/VP9 code from libvpx is BSD-3-Clause
License:        MIT AND BSD-3-Clause
URL:            https://github.com/intel/media-driver
Source0:        %{url}/archive/intel-media-%{version}.tar.gz#/%{name}-%{version}.tar.gz

# Intel graphics only
ExclusiveArch:  x86_64

# The build also makes a static library, which is not packaged; without fat
# LTO objects it takes a few GB less disk
%global _lto_cflags -flto=auto

BuildRequires:  cmake
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  pkgconfig(igdgmm)
BuildRequires:  pkgconfig(libva) >= 1.6.0
BuildRequires:  pkgconfig(pciaccess)
BuildRequires:  pkgconfig(x11)

# Bundles a modified libdrm and the archived cmrt (C for Media runtime)
Provides:       bundled(libdrm)
Provides:       bundled(libcmrt)

Requires(posttrans): coreutils
Requires(postun): coreutils

%description
The Intel Media Driver for VAAPI (iHD) is a VA-API user mode driver for
hardware accelerated video decoding, encoding and post processing on Intel
graphics from Broadwell (Gen8) onwards, including Arc and Xe.

This build includes the precompiled GPU kernels that Fedora's
libva-intel-media-driver leaves out, and takes precedence over it.

%prep
%autosetup -n media-driver-intel-media-%{version}
# New compiler warnings would fail the build
sed -i '/-Werror/d' media_driver/cmake/linux/media_compile_flags_linux.cmake
sed -i 's/COMPILE_FLAGS "-Werror"/COMPILE_FLAGS ""/' media_driver/media_top_cmake.cmake
if grep -q -- '-Werror"' media_driver/media_top_cmake.cmake; then exit 1; fi

%build
%cmake \
    -DENABLE_KERNELS=ON \
    -DENABLE_NONFREE_KERNELS=ON \
    -DBUILD_CMRTLIB=OFF \
    -DMEDIA_RUN_TEST_SUITE=OFF \
    -DRUN_TEST_SUITE=OFF
%cmake_build

%install
%cmake_install
mv %{buildroot}%{_libdir}/dri %{buildroot}%{_libdir}/dri-nonfree

# GStreamer's va plugin registers decoders for the VA-API driver it finds when
# it is scanned, and rescans only when the plugin's file changes. Touch it so
# every user's registry picks up this driver, or drops it.
%posttrans
touch -c %{_libdir}/gstreamer-1.0/libgstva.so || :

%postun
if [ $1 -eq 0 ]; then
    touch -c %{_libdir}/gstreamer-1.0/libgstva.so || :
fi

%files
%license LICENSE.md
%doc README.md
%{_libdir}/dri-nonfree/iHD_drv_video.so

%changelog
* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 26.3.5-2
- Make GStreamer rescan its va plugin when the driver is installed or removed

* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 26.3.5-1
- Initial package
