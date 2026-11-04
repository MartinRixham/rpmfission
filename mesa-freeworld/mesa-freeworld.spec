# Mesa's VA-API drivers (AMD radeonsi and r600, nouveau, virtio-gpu and
# d3d12) with every video codec. Fedora builds Mesa without H.264, H.265 and
# VC-1.
#
# Since Mesa 25 the drivers are thin wrappers around one library,
# libgallium-<version>.so, which also does the work for Fedora's OpenGL and
# EGL. So this package ships its own libgallium, built with the same
# drivers and options as Fedora's, into %%{_libdir}/dri-freeworld and puts
# that directory ahead of the system's in the library path. Fedora's libva
# looks for VA-API drivers there before %%{_libdir}/dri. This is RPM Fusion's
# scheme and package naming, which this package replaces.
#
# The version must be exactly that of Fedora's mesa, as the library is shared
# with it (hence the Requires on mesa-filesystem). A newer Fedora mesa cannot
# be installed until this package is rebuilt at that version; the update
# workflow opens a pull request for that (see .github/scripts/check-updates.sh).
#
# rpmfission-follows-fedora: mesa-dri-drivers

%global ver %{gsub %version ~ -}

# Mesa's own choice for Fedora: LTO breaks some games
# https://bugzilla.redhat.com/show_bug.cgi?id=1862771
%global _lto_cflags %{nil}

Name:           mesa-freeworld
Version:        26.2.6
Release:        1%{?dist}
Summary:        Mesa VA-API drivers with all video codecs

License:        MIT AND BSD-3-Clause AND SGI-B-2.0
URL:            https://mesa3d.org
Source0:        https://archive.mesa3d.org/mesa-%{ver}.tar.xz

# x86_64 is the only architecture built here; the gallium driver list below
# is Fedora's for x86_64
ExclusiveArch:  x86_64

BuildRequires:  bison
BuildRequires:  clang-devel
BuildRequires:  flex
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  gettext
BuildRequires:  glslang
BuildRequires:  kernel-headers
BuildRequires:  libstdc++-static
BuildRequires:  llvm-devel
# Fedora's libgallium, compared with this one in %%check. This also fails the
# build when Fedora's mesa is at another version.
BuildRequires:  mesa-dri-drivers%{?_isa} = %{version}
BuildRequires:  lm_sensors-devel
BuildRequires:  meson >= 1.3.0
BuildRequires:  pkgconfig(DirectX-Headers) >= 1.619.1
BuildRequires:  pkgconfig(dri2proto) >= 2.8
BuildRequires:  pkgconfig(expat)
BuildRequires:  pkgconfig(glproto) >= 1.4.14
BuildRequires:  pkgconfig(libclc)
BuildRequires:  pkgconfig(libdisplay-info)
BuildRequires:  pkgconfig(libdrm) >= 2.4.133
BuildRequires:  pkgconfig(libelf)
BuildRequires:  pkgconfig(libglvnd) >= 1.3.2
BuildRequires:  pkgconfig(libunwind)
BuildRequires:  pkgconfig(libva) >= 0.38.0
BuildRequires:  pkgconfig(libzstd)
BuildRequires:  pkgconfig(LLVMSPIRVLib)
BuildRequires:  pkgconfig(SPIRV-Tools)
BuildRequires:  pkgconfig(valgrind)
BuildRequires:  pkgconfig(vulkan)
BuildRequires:  pkgconfig(wayland-client) >= 1.11
BuildRequires:  pkgconfig(wayland-egl-backend) >= 3
BuildRequires:  pkgconfig(wayland-protocols) >= 1.41
BuildRequires:  pkgconfig(wayland-scanner)
BuildRequires:  pkgconfig(wayland-server) >= 1.11
BuildRequires:  pkgconfig(x11)
BuildRequires:  pkgconfig(x11-xcb)
BuildRequires:  pkgconfig(xcb)
BuildRequires:  pkgconfig(xcb-dri2) >= 1.8
BuildRequires:  pkgconfig(xcb-dri3)
BuildRequires:  pkgconfig(xcb-glx) >= 1.8.1
BuildRequires:  pkgconfig(xcb-present)
BuildRequires:  pkgconfig(xcb-randr)
BuildRequires:  pkgconfig(xcb-sync)
BuildRequires:  pkgconfig(xcb-xfixes)
BuildRequires:  pkgconfig(xdamage) >= 1.1
BuildRequires:  pkgconfig(xext)
BuildRequires:  pkgconfig(xfixes)
BuildRequires:  pkgconfig(xrandr) >= 1.3
BuildRequires:  pkgconfig(xshmfence) >= 1.1
BuildRequires:  pkgconfig(xxf86vm)
BuildRequires:  pkgconfig(zlib) >= 1.2.3
BuildRequires:  python3-devel
BuildRequires:  python3-mako
BuildRequires:  python3-pycparser
BuildRequires:  python3-pyyaml
BuildRequires:  systemd-devel
BuildRequires:  vulkan-headers

%description
Mesa's VA-API video acceleration drivers built with every video codec,
including the H.264, H.265 and VC-1 that Fedora's build leaves out.

%package     -n mesa-va-drivers-freeworld
Summary:        Mesa VA-API drivers with all video codecs
# Shares libgallium with Fedora's mesa of exactly this version
Requires:       mesa-filesystem%{?_isa} = %{version}
Provides:       mesa-va-drivers = %{version}-%{release}
Provides:       mesa-va-drivers%{?_isa} = %{version}-%{release}

Requires(posttrans): coreutils
Requires(postun): coreutils

%description -n mesa-va-drivers-freeworld
Mesa's VA-API drivers for AMD (radeonsi, r600), nouveau, virtio-gpu and d3d12
(WSL) with hardware decoding of H.264, H.265, VC-1, VP9 and AV1 and encoding
of H.264, H.265 and AV1, where the GPU supports them. They take precedence
over Fedora's drivers, which leave out H.264, H.265 and VC-1.

%prep
%autosetup -n mesa-%{ver} -p1

%build
# Fedora's mesa.spec options for x86_64, except:
# - all video codecs
# - install to dri-freeworld
# - no Vulkan drivers, OpenCL (rusticl) or Teflon (NPU), which do not use
#   libgallium, and so no ethosu or rocket (Teflon's NPU drivers)
%meson \
    --libdir=%{_libdir}/dri-freeworld \
    -Ddri-drivers-path=%{_libdir}/dri-freeworld \
    -Dva-libs-path=%{_libdir}/dri-freeworld \
    -Dplatforms=x11,wayland \
    -Dgallium-drivers=llvmpipe,virgl,nouveau,r300,crocus,i915,iris,svga,radeonsi,r600,asahi,freedreno,etnaviv,tegra,vc4,v3d,lima,panfrost,zink,d3d12 \
    -Dgallium-va=enabled \
    -Dgallium-mediafoundation=disabled \
    -Dgallium-rusticl=false \
    -Dteflon=false \
    -Dvideo-codecs=all \
    -Dvulkan-drivers= \
    -Dvulkan-layers= \
    -Dgles1=enabled \
    -Dgles2=enabled \
    -Dopengl=true \
    -Dgbm=enabled \
    -Dglx=dri \
    -Degl=enabled \
    -Dglvnd=enabled \
    -Dintel-rt=disabled \
    -Dmicrosoft-clc=disabled \
    -Dllvm=enabled \
    -Dshared-llvm=enabled \
    -Dvalgrind=enabled \
    -Dbuild-tests=false \
    -Dandroid-libbacktrace=disabled \
    -Dspirv-tools=enabled
%meson_build

%install
%meson_install
# Keep only libgallium and the VA-API drivers (symlinks to it)
dir=%{buildroot}%{_libdir}/dri-freeworld
mkdir keep
mv $dir/libgallium-%{ver}.so $dir/*_drv_video.so keep/
rm -r %{buildroot}
install -d $dir
mv keep/* $dir/

# Ahead of the system library directories, so that Fedora's OpenGL and EGL
# use this libgallium too. Byte for byte RPM Fusion's file, which their
# mesa-vulkan-drivers-freeworld also installs.
install -d %{buildroot}%{_sysconfdir}/ld.so.conf.d
printf '%s \n\n' %{_libdir}/dri-freeworld/ \
    > %{buildroot}%{_sysconfdir}/ld.so.conf.d/%{name}-%{_lib}.conf

%check
dir=%{buildroot}%{_libdir}/dri-freeworld
python3 -c '
import json, sys
options = {o["name"]: o["value"] for o in json.load(open(sys.argv[1]))}
assert options["video-codecs"] == ["all"], options["video-codecs"]
' %{_vpath_builddir}/meson-info/intro-buildoptions.json
# Fedora's OpenGL and EGL will call into this libgallium in place of
# Fedora's, so it must export everything that one does
nm -D --defined-only %{_libdir}/libgallium-%{ver}.so | awk '{print $3}' | sort > fedora.syms
nm -D --defined-only $dir/libgallium-%{ver}.so | awk '{print $3}' | sort > freeworld.syms
comm -23 fedora.syms freeworld.syms > missing.syms
if [ -s missing.syms ]; then
    echo "Exported by Fedora's libgallium but not by this one:"
    cat missing.syms
    exit 1
fi

%ldconfig_scriptlets -n mesa-va-drivers-freeworld

# GStreamer's va plugin registers decoders for the VA-API driver it finds when
# it is scanned, and rescans only when the plugin's file changes. Touch it so
# every user's registry picks up these drivers' H.264 and H.265, or drops them.
%posttrans -n mesa-va-drivers-freeworld
touch -c %{_libdir}/gstreamer-1.0/libgstva.so || :

%postun -n mesa-va-drivers-freeworld
if [ $1 -eq 0 ]; then
    touch -c %{_libdir}/gstreamer-1.0/libgstva.so || :
fi

%files -n mesa-va-drivers-freeworld
%license docs/license.rst
%config %{_sysconfdir}/ld.so.conf.d/%{name}-%{_lib}.conf
%{_libdir}/dri-freeworld/libgallium-%{ver}.so
%{_libdir}/dri-freeworld/d3d12_drv_video.so
%{_libdir}/dri-freeworld/nouveau_drv_video.so
%{_libdir}/dri-freeworld/r600_drv_video.so
%{_libdir}/dri-freeworld/radeonsi_drv_video.so
%{_libdir}/dri-freeworld/virtio_gpu_drv_video.so

%changelog
* Wed Nov 04 2026 github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com> - 26.2.6-1
- Update to 26.2.6

* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 26.2.5-2
- Make GStreamer rescan its va plugin when the drivers are installed or removed

* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 26.2.5-1
- Initial package
