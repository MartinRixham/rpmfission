# Firmware for the Apple Silicon video decoder (AVD), with every video codec.
# The firmware is Asahi's own, written from scratch, for the Cortex-M3 inside
# the decoder; the downstream Asahi kernel's apple_avd driver (V4L2,
# stateless) loads it, and does not probe without it. Asahi packages it as
# avd-fw in the @asahi/kernel COPR, built with -Dvideo-codecs=all_free: VP9
# and AV1 only. This package also has H.264 and H.265.
#
# Asahi's patches are carried from their package (src.rpm of COPR build
# 11236058). The third is needed on Asahi kernels up to asahi-7.2.14-1,
# which read the codec config from the end of the firmware.
#
# Installed by video-drivers-apple. "dnf swap avd-fw video-drivers-apple"
# replaces Asahi's avd-fw. The firmware is loaded when the driver probes, so
# reload it ("modprobe -r apple_avd; modprobe apple_avd") or reboot.

%global srcname avd-fw

# Firmware for the decoder, not code for the host: no host build flags
%undefine _auto_set_build_flags
%global build_cflags %{nil}
%global build_ldflags %{nil}
%global debug_package %{nil}

Name:           avd-fw-freeworld
Version:        0.2
Release:        1%{?dist}
Summary:        Apple Silicon video decoder firmware with all video codecs

License:        MIT
URL:            https://github.com/AsahiLinux/avd-fw
Source0:        %{url}/releases/download/v%{version}/%{srcname}-v%{version}.tar.xz

Patch1:         0001-build-factor-out-objcopy_cmd.patch
Patch2:         0002-build-use-int-as-type-for-pad-value.patch
Patch3:         0003-compat-Provide-the-config-at-the-end-of-the-firmware.patch

BuildArch:      noarch
# Only Apple Silicon Macs (Fedora Asahi Remix) have the decoder
ExclusiveArch:  aarch64

BuildRequires:  meson >= 1.4.0
BuildRequires:  arm-none-eabi-gcc-cs
BuildRequires:  arm-none-eabi-binutils-cs

# Same files as Asahi's package
Provides:       %{srcname} = %{version}-%{release}
Conflicts:      %{srcname}

%description
Firmware for the video decoder (AVD) of Apple M1, M2 and M3 Macs, used by the
apple_avd V4L2 driver of the Asahi Linux kernel for hardware video decoding,
for example by GStreamer's v4l2codecs plugin. Built with H.264, H.265, VP9 and
AV1 support, where the hardware has them; Asahi's avd-fw package has VP9 and
AV1 only.

%prep
%autosetup -p1 -n %{srcname}-v%{version}

%build
%meson --cross-file=./arm-none-eabi-gcc.ini -Dvideo-codecs=all
%meson_build

%install
%meson_install
# meson installs them executable
chmod 0644 %{buildroot}%{_prefix}/lib/firmware/apple/avd-fw-*.bin

%files
%license LICENSE
%dir %{_prefix}/lib/firmware/apple
%{_prefix}/lib/firmware/apple/avd-fw-*.bin

%changelog
* Thu Nov 05 2026 Martin Rixham <martin.rixham@gmail.com> - 0.2-1
- Initial package
