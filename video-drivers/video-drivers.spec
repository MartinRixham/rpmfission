# Metapackages for hardware video acceleration: one per GPU vendor, and
# video-drivers for all three. RPM cannot pick dependencies by the hardware
# present, but drivers for absent GPUs are harmless: libva and the other
# APIs load the driver matching the kernel driver of each GPU.

Name:           video-drivers
Version:        1
Release:        1%{?dist}
Summary:        Hardware video acceleration drivers for Intel, AMD and NVIDIA GPUs

License:        MIT

BuildArch:      noarch

Requires:       %{name}-intel = %{version}-%{release}
Requires:       %{name}-amd = %{version}-%{release}
Requires:       %{name}-nvidia = %{version}-%{release}

%description
Installs the video decoding and encoding drivers for Intel, AMD and NVIDIA
GPUs, with the H.264, H.265 and VC-1 codecs that Fedora's drivers leave out.
Applications that use VA-API (Firefox, Chromium, mpv, GStreamer, FFmpeg) and
FFmpeg's Quick Sync and NVENC/NVDEC support pick the driver for the GPU in
use.

Install video-drivers-intel, video-drivers-amd or video-drivers-nvidia
instead for one vendor's drivers only.

%package        intel
Summary:        Hardware video acceleration drivers for Intel GPUs
# VA-API (iHD), with all codecs
Requires:       intel-media-driver
# Quick Sync Video through oneVPL, Tiger Lake (Gen12) and newer
Requires:       intel-vpl-gpu-rt
# Quick Sync Video through Media SDK, Broadwell to Ice Lake
Recommends:     intel-mediasdk
# vainfo, to check what the driver supports
Recommends:     libva-utils

%description    intel
Hardware video decoding and encoding for Intel graphics from Broadwell
(Gen8) onwards, including Arc: the full Intel media driver for VA-API and the
Quick Sync Video runtimes. Older Intel graphics need the i965 driver
(libva-intel-driver), which is not included.

%package        amd
Summary:        Hardware video acceleration drivers for AMD GPUs
# radeonsi and r600 for VA-API, with all codecs. Also covers nouveau.
Requires:       mesa-va-drivers-freeworld
Recommends:     libva-utils

%description    amd
Hardware video decoding and encoding for AMD Radeon GPUs: Mesa's VA-API
drivers built with H.264, H.265 and VC-1. The same package covers the
nouveau driver for NVIDIA GPUs, where its firmware allows.

%package        nvidia
Summary:        Hardware video acceleration drivers for NVIDIA GPUs
# VA-API on top of NVDEC, for applications that only speak VA-API
Requires:       libva-nvidia-driver
# NVDEC and NVENC, which FFmpeg loads at run time. They come with NVIDIA's
# proprietary driver (RPM Fusion's xorg-x11-drv-nvidia-cuda-libs, for
# example), which is not available here.
Recommends:     libnvcuvid.so.1()(64bit)
Recommends:     libnvidia-encode.so.1()(64bit)
Recommends:     libva-utils

%description    nvidia
Hardware video decoding for NVIDIA GPUs through VA-API (nvidia-vaapi-driver),
and NVDEC/NVENC decoding and encoding through FFmpeg.

Both need NVIDIA's proprietary driver, from RPM Fusion's nonfree repository
for example, which is not installed by this package; the VA-API driver also
needs the nvidia-drm.modeset=1 kernel parameter. Without the proprietary
driver, video-drivers-amd covers nouveau.

%prep

%build

%install

%files

%files intel

%files amd

%files nvidia

%changelog
* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 1-1
- Initial package
