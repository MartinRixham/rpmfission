# Metapackages for hardware video acceleration: one per GPU vendor, and
# video-drivers for all of them. RPM cannot pick dependencies by the hardware
# present, but drivers for absent GPUs are harmless: libva and the other
# APIs load the driver matching the kernel driver of each GPU.
#
# On x86_64 the vendors are Intel, AMD and NVIDIA; on aarch64 there is only
# Apple Silicon (Fedora Asahi Remix). The packages are empty, but archful so
# that %%ifarch can choose the subpackages for each architecture.

Name:           video-drivers
Version:        1
Release:        4%{?dist}
Summary:        Hardware video acceleration drivers for all supported GPUs

License:        MIT

# dnf vendor change policy for rpmfission's builds of Fedora packages
Source0:        rpmfission.conf

ExclusiveArch:  x86_64 aarch64

# Nothing to debug in empty packages
%global debug_package %{nil}

%ifarch x86_64
Requires:       %{name}-intel = %{version}-%{release}
Requires:       %{name}-amd = %{version}-%{release}
Requires:       %{name}-nvidia = %{version}-%{release}
%endif
%ifarch aarch64
Requires:       %{name}-apple = %{version}-%{release}
%endif

%description
%ifarch x86_64
Installs the video decoding and encoding drivers for Intel, AMD and NVIDIA
GPUs, with the H.264, H.265 and VC-1 codecs that Fedora's drivers leave out.
Applications that use VA-API (Firefox, Chromium, mpv, GStreamer, FFmpeg) and
FFmpeg's Quick Sync and NVENC/NVDEC support pick the driver for the GPU in
use.

Install video-drivers-intel, video-drivers-amd or video-drivers-nvidia
instead for one vendor's drivers only.
%endif
%ifarch aarch64
Installs the video decoding firmware for Apple Silicon Macs, with the
H.264 and H.265 codecs that Asahi's firmware leaves out.
%endif

%ifarch x86_64
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
%endif

%ifarch aarch64
%package        apple
Summary:        Hardware video acceleration drivers for Apple Silicon Macs
# Firmware for the video decoder (AVD), with all codecs. Replaces Asahi's
# avd-fw, which conflicts with it: "dnf swap avd-fw video-drivers-apple"
Requires:       avd-fw-freeworld
# GStreamer's v4l2codecs, the stateless V4L2 decoders that use it. This
# repository's build fixes it, as its mesa does Honeykrisp (Vulkan) for the
# decoded frames; the vendor change policy lets dnf upgrade Fedora's builds
# to them.
Recommends:     gstreamer1-plugins-bad-free
# Reads the vendor change policy
Requires:       libdnf5 >= 5.3
# v4l2-ctl, to check the decoder device
Recommends:     v4l-utils

%description    apple
Hardware video decoding for Apple M1, M2 and M3 Macs on Fedora Asahi Remix:
firmware for the video decoder (AVD) with H.264, H.265, VP9 and AV1, which
the Asahi kernel's apple_avd V4L2 driver needs. GStreamer applications
(GNOME's video player, for example) decode on the hardware through the
v4l2codecs plugin. FFmpeg, and so mpv, Firefox and Chromium, has no support
for these decoders yet. The firmware is loaded when the driver starts, so
reboot after installing.

It also lets dnf replace Fedora's gstreamer1-plugins-bad-free and mesa with
this repository's builds, which fix video whose size is not aligned, such as
1080p: the v4l2codecs plugin, and the Vulkan driver that GTK draws the frames
with.
%endif

%prep

%build

%install
%ifarch aarch64
install -D -p -m 0644 %{SOURCE0} \
    %{buildroot}%{_datadir}/dnf5/vendors.d/rpmfission.conf
%endif

%files

%ifarch x86_64
%files intel

%files amd

%files nvidia
%endif

%ifarch aarch64
%files apple
%{_datadir}/dnf5/vendors.d/rpmfission.conf
%endif

%changelog
* Fri Nov 06 2026 Martin Rixham <martin.rixham@gmail.com> - 1-4
- video-drivers-apple: the vendor change policy also covers mesa, now
  rpmfission.conf

* Thu Nov 05 2026 Martin Rixham <martin.rixham@gmail.com> - 1-3
- video-drivers-apple: add a dnf vendor change policy, so that dnf upgrades
  Fedora's gstreamer1-plugins-bad-free to this repository's build

* Thu Nov 05 2026 Martin Rixham <martin.rixham@gmail.com> - 1-2
- Add video-drivers-apple for Apple Silicon (Asahi)
- Build for aarch64 too; the packages are archful so that each architecture
  gets its own subpackages

* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 1-1
- Initial package
