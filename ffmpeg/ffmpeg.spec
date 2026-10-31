# FFmpeg with every codec, x264 and x265 (from this repository), and all the
# hardware acceleration APIs: VA-API, Vulkan, NVDEC/NVENC/CUDA, Intel QSV
# (oneVPL), AMD AMF and VDPAU. The video-drivers packages install drivers
# for these.
#
# A drop-in replacement for Fedora's ffmpeg-free and RPM Fusion's ffmpeg: the
# libraries keep the sonames of the FFmpeg release Fedora ships, so the rest
# of Fedora uses them, and the package names and layout are RPM Fusion's. Swap
# Fedora's build out with
#   dnf swap ffmpeg-free ffmpeg --allowerasing
# Move to a new FFmpeg major release (new sonames) only when Fedora does.
#
# The configure options follow Fedora's ffmpeg.spec, which knows which
# libraries Fedora has, with its codec restrictions dropped.

%global avcodec_soversion    62
%global avdevice_soversion   62
%global avfilter_soversion   11
%global avformat_soversion   62
%global avutil_soversion     60
%global swresample_soversion 6
%global swscale_soversion    9

Name:           ffmpeg
Version:        8.1.3
Release:        2%{?dist}
Summary:        Record, convert and stream audio and video

# --enable-gpl and --enable-version3 (for the Apache-2.0 and LGPL-3.0
# libraries it links, such as opencore-amr, vo-amrwbenc and smbclient)
License:        GPL-3.0-or-later
URL:            https://ffmpeg.org/
Source0:        https://ffmpeg.org/releases/ffmpeg-%{version}.tar.xz
Source1:        https://ffmpeg.org/releases/ffmpeg-%{version}.tar.xz.asc
# https://ffmpeg.org/ffmpeg-devel.asc, kept here so a re-signed key does not
# change a checksum
Source2:        ffmpeg-devel.asc

# Add av_stream_get_first_dts, which Chromium uses (from Fedora)
# https://bugzilla.redhat.com/show_bug.cgi?id=2240127
Patch0:         ffmpeg-chromium.patch
# fdk-aac-free (Fedora's fdk-aac) is GPL compatible (from Fedora)
# https://bugzilla.redhat.com/show_bug.cgi?id=1501522#c112
Patch1:         ffmpeg-allow-fdk-aac-free.patch
# Vulkan video frames exported to DMA-BUF render wrongly in Firefox (from
# Fedora and RPM Fusion)
# https://github.com/FFmpeg/FFmpeg/commit/25e187f8494966377a4b9d077260ce7b501a911c
Patch2:         ffmpeg-vulkan-direct-export.patch

Requires:       %{name}-libs%{?_isa} = %{version}-%{release}
Requires:       libavdevice%{?_isa} = %{version}-%{release}
Conflicts:      ffmpeg-free%{?_isa}

BuildRequires:  AMF-devel
BuildRequires:  clang
BuildRequires:  fdk-aac-free-devel
BuildRequires:  flite-devel >= 2.2
BuildRequires:  game-music-emu-devel
BuildRequires:  gcc
BuildRequires:  gnupg2
BuildRequires:  gsm-devel
BuildRequires:  ladspa-devel
BuildRequires:  lame-devel
BuildRequires:  libgcrypt-devel
BuildRequires:  libmysofa-devel
BuildRequires:  librtmp-devel
BuildRequires:  libX11-devel
BuildRequires:  libXext-devel
BuildRequires:  libXv-devel
BuildRequires:  make
BuildRequires:  nasm
BuildRequires:  perl(Pod::Man)
BuildRequires:  pkgconfig(alsa)
BuildRequires:  pkgconfig(aom)
BuildRequires:  pkgconfig(aribb24) >= 1.0.3
BuildRequires:  pkgconfig(bzip2)
BuildRequires:  pkgconfig(caca)
BuildRequires:  pkgconfig(codec2)
BuildRequires:  pkgconfig(dav1d)
BuildRequires:  pkgconfig(dvdnav)
BuildRequires:  pkgconfig(dvdread)
BuildRequires:  pkgconfig(ffnvcodec)
BuildRequires:  pkgconfig(flac)
BuildRequires:  pkgconfig(fontconfig)
BuildRequires:  pkgconfig(freetype2)
BuildRequires:  pkgconfig(frei0r)
BuildRequires:  pkgconfig(fribidi)
BuildRequires:  pkgconfig(gl)
BuildRequires:  pkgconfig(gmp)
BuildRequires:  pkgconfig(gnutls)
BuildRequires:  pkgconfig(harfbuzz)
BuildRequires:  pkgconfig(jack)
BuildRequires:  pkgconfig(lc3) >= 1.1.0
BuildRequires:  pkgconfig(lcms2) >= 2.13
BuildRequires:  pkgconfig(libaribcaption) >= 1.1.1
BuildRequires:  pkgconfig(libass)
BuildRequires:  pkgconfig(libavc1394)
BuildRequires:  pkgconfig(libbluray)
BuildRequires:  pkgconfig(libbs2b)
BuildRequires:  pkgconfig(libcdio)
BuildRequires:  pkgconfig(libcdio_paranoia)
BuildRequires:  pkgconfig(libchromaprint)
BuildRequires:  pkgconfig(libdc1394-2)
BuildRequires:  pkgconfig(libdrm)
BuildRequires:  pkgconfig(libiec61883)
BuildRequires:  pkgconfig(libilbc)
BuildRequires:  pkgconfig(libjxl) >= 0.7.0
BuildRequires:  pkgconfig(libmodplug)
BuildRequires:  pkgconfig(libopenjp2)
BuildRequires:  pkgconfig(libopenmpt)
BuildRequires:  pkgconfig(libplacebo) >= 4.192.0
BuildRequires:  pkgconfig(libpulse)
BuildRequires:  pkgconfig(libqrencode)
BuildRequires:  pkgconfig(librabbitmq)
BuildRequires:  pkgconfig(librist)
BuildRequires:  pkgconfig(librsvg-2.0)
BuildRequires:  pkgconfig(libssh)
BuildRequires:  pkgconfig(libv4l2)
BuildRequires:  pkgconfig(libva)
BuildRequires:  pkgconfig(libva-drm)
BuildRequires:  pkgconfig(libva-x11)
%ifarch x86_64
# Fedora builds libvmaf for x86_64 only
BuildRequires:  pkgconfig(libvmaf)
%endif
BuildRequires:  pkgconfig(libwebp)
BuildRequires:  pkgconfig(libxml-2.0)
BuildRequires:  pkgconfig(libzmq)
BuildRequires:  pkgconfig(lilv-0)
BuildRequires:  pkgconfig(lv2)
BuildRequires:  pkgconfig(oapv)
BuildRequires:  pkgconfig(ogg)
BuildRequires:  pkgconfig(openal)
BuildRequires:  pkgconfig(opencore-amrnb)
BuildRequires:  pkgconfig(OpenCL)
BuildRequires:  pkgconfig(openh264)
BuildRequires:  pkgconfig(opus)
BuildRequires:  pkgconfig(rav1e)
BuildRequires:  pkgconfig(rubberband)
BuildRequires:  pkgconfig(sdl2)
BuildRequires:  pkgconfig(shaderc) >= 2019.1
BuildRequires:  pkgconfig(smbclient)
BuildRequires:  pkgconfig(snappy)
BuildRequires:  pkgconfig(soxr)
BuildRequires:  pkgconfig(speex)
BuildRequires:  pkgconfig(srt)
BuildRequires:  pkgconfig(SvtAv1Enc) >= 0.9.0
BuildRequires:  pkgconfig(tesseract)
BuildRequires:  pkgconfig(theora)
BuildRequires:  pkgconfig(twolame)
BuildRequires:  pkgconfig(vapoursynth)
BuildRequires:  pkgconfig(vdpau)
BuildRequires:  pkgconfig(vidstab)
BuildRequires:  pkgconfig(vo-amrwbenc)
BuildRequires:  pkgconfig(vorbis)
%ifarch x86_64
# Intel Quick Sync Video; Fedora builds oneVPL for x86_64 only
BuildRequires:  pkgconfig(vpl) >= 2.6
%endif
BuildRequires:  pkgconfig(vpx)
BuildRequires:  pkgconfig(vulkan) >= 1.3.255
BuildRequires:  pkgconfig(wavpack)
BuildRequires:  pkgconfig(xcb)
BuildRequires:  pkgconfig(xcb-render)
BuildRequires:  pkgconfig(xcb-shape)
BuildRequires:  pkgconfig(xcb-shm)
BuildRequires:  pkgconfig(xcb-xfixes)
BuildRequires:  pkgconfig(xevdb)
BuildRequires:  pkgconfig(xeveb)
BuildRequires:  pkgconfig(zimg)
BuildRequires:  pkgconfig(zlib)
BuildRequires:  pkgconfig(zvbi-0.2)
BuildRequires:  texinfo
BuildRequires:  xvidcore-devel
# From this repository. Named as packages, not pkgconfig(), so that CI knows
# to build them first (see .github/workflows/build.yml).
BuildRequires:  x264-devel
BuildRequires:  x265-devel

%description
FFmpeg is a complete, cross-platform solution to record, convert and stream
audio and video. This build has every codec FFmpeg offers, the x264 and x265
encoders, and hardware accelerated decoding and encoding through VA-API,
Vulkan, NVIDIA NVDEC/NVENC and CUDA, Intel Quick Sync Video and AMD AMF.

This package contains the ffmpeg, ffprobe and ffplay commands.

%package        libs
Summary:        FFmpeg libraries
# Replaces the -free libraries of Fedora's build; see the top of the spec
Conflicts:      libavcodec-free%{?_isa}
Conflicts:      libavfilter-free%{?_isa}
Conflicts:      libavformat-free%{?_isa}
Conflicts:      libavutil-free%{?_isa}
Conflicts:      libswresample-free%{?_isa}
Conflicts:      libswscale-free%{?_isa}
# libavcodec-freeworld (RPM Fusion) puts a second libavcodec ahead of this one
# in the library path; this libavcodec has the same codecs
Provides:       libavcodec-freeworld = %{version}-%{release}
Provides:       libavcodec-freeworld%{?_isa} = %{version}-%{release}
Obsoletes:      libavcodec-freeworld < %{version}-%{release}
# The H.264 encoder and decoder through Cisco's openh264. Fedora's
# noopenh264 is a stub; the real library is in the fedora-cisco-openh264
# repository.
Suggests:       openh264%{?_isa}

%description    libs
The FFmpeg libraries: libavcodec (codecs), libavformat (containers and
protocols), libavfilter (filters), libavutil (utilities), libswresample
(audio resampling) and libswscale (scaling and pixel formats).

%package     -n libavdevice
Summary:        FFmpeg device library
Requires:       %{name}-libs%{?_isa} = %{version}-%{release}
Conflicts:      libavdevice-free%{?_isa}

%description -n libavdevice
libavdevice grabs from and renders to input and output devices such as
Video4Linux2, ALSA, PulseAudio, JACK, X11 and KMS.

%package        devel
Summary:        Development files for FFmpeg
Requires:       %{name}-libs%{?_isa} = %{version}-%{release}
Requires:       libavdevice%{?_isa} = %{version}-%{release}
Requires:       pkgconfig
Conflicts:      ffmpeg-free-devel%{?_isa}
Conflicts:      libavcodec-free-devel%{?_isa}
Conflicts:      libavdevice-free-devel%{?_isa}
Conflicts:      libavfilter-free-devel%{?_isa}
Conflicts:      libavformat-free-devel%{?_isa}
Conflicts:      libavutil-free-devel%{?_isa}
Conflicts:      libswresample-free-devel%{?_isa}
Conflicts:      libswscale-free-devel%{?_isa}

%description    devel
Headers, pkg-config files and API documentation for building against the
FFmpeg libraries.

%prep
%{gpgverify} --keyring='%{SOURCE2}' --signature='%{SOURCE1}' --data='%{SOURCE0}'
%autosetup -p1
# The host tools would otherwise be built with -O3 -g, ignoring the build
# flags
sed -i "s|check_host_cflags -O3|check_host_cflags %{optflags}|" configure
install -m 0755 -d _doc/examples
cp -a doc/examples/{*.c,Makefile,README} _doc/examples/

%build
%set_build_flags
# Not an autoconf script. The external libraries are Fedora's ffmpeg.spec's
# (less DeckLink and libklvanc, which need the proprietary DeckLink SDK) plus
# x264, x265, librtmp and the CUDA filters, compiled to PTX with clang.
./configure \
    --prefix=%{_prefix} \
    --bindir=%{_bindir} \
    --datadir=%{_datadir}/%{name} \
    --docdir=%{_docdir}/%{name} \
    --incdir=%{_includedir}/%{name} \
    --libdir=%{_libdir} \
    --mandir=%{_mandir} \
    --arch=%{_target_cpu} \
    --optflags="%{build_cflags}" \
    --extra-ldflags="%{build_ldflags}" \
    --disable-htmlpages \
    --disable-static \
    --disable-stripping \
    --enable-pic \
    --enable-shared \
    --enable-lto \
    --enable-gpl \
    --enable-version3 \
    --enable-alsa \
    --enable-amf \
    --enable-bzlib \
    --enable-chromaprint \
    --enable-cuda-llvm \
    --enable-cuvid \
    --enable-ffnvcodec \
    --enable-frei0r \
    --enable-gcrypt \
    --enable-gmp \
    --enable-gnutls \
    --enable-gray \
    --enable-iconv \
    --enable-ladspa \
    --enable-lcms2 \
    --enable-libaom \
    --enable-libaribb24 \
    --enable-libaribcaption \
    --enable-libass \
    --enable-libbluray \
    --enable-libbs2b \
    --enable-libcaca \
    --enable-libcdio \
    --enable-libcodec2 \
    --enable-libdav1d \
    --enable-libdc1394 \
    --enable-libdvdnav \
    --enable-libdvdread \
    --enable-libfdk-aac \
    --enable-libflite \
    --enable-libfontconfig \
    --enable-libfreetype \
    --enable-libfribidi \
    --enable-libgme \
    --enable-libgsm \
    --enable-libharfbuzz \
    --enable-libiec61883 \
    --enable-libilbc \
    --enable-libjack \
    --enable-libjxl \
    --enable-liblc3 \
    --enable-libmodplug \
    --enable-libmp3lame \
    --enable-libmysofa \
    --enable-liboapv \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libopenh264 \
    --enable-libopenjpeg \
    --enable-libopenmpt \
    --enable-libopus \
    --enable-libplacebo \
    --enable-libpulse \
    --enable-libqrencode \
    --enable-librabbitmq \
    --enable-librav1e \
    --enable-librist \
    --enable-librsvg \
    --enable-librtmp \
    --enable-librubberband \
    --enable-libshaderc \
    --enable-libsmbclient \
    --enable-libsnappy \
    --enable-libsoxr \
    --enable-libspeex \
    --enable-libsrt \
    --enable-libssh \
    --enable-libsvtav1 \
    --enable-libtesseract \
    --enable-libtheora \
    --enable-libtwolame \
    --enable-libv4l2 \
    --enable-libvidstab \
%ifarch x86_64
    --enable-libvmaf \
%endif
    --enable-libvo-amrwbenc \
    --enable-libvorbis \
%ifarch x86_64
    --enable-libvpl \
%endif
    --enable-libvpx \
    --enable-libwebp \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libxcb \
    --enable-libxcb-shape \
    --enable-libxcb-shm \
    --enable-libxcb-xfixes \
    --enable-libxeveb \
    --enable-libxevdb \
    --enable-libxml2 \
    --enable-libxvid \
    --enable-libzimg \
    --enable-libzmq \
    --enable-libzvbi \
    --enable-lv2 \
    --enable-lzma \
    --enable-manpages \
    --enable-nvdec \
    --enable-nvenc \
    --enable-openal \
    --enable-opencl \
    --enable-opengl \
    --enable-pthreads \
    --enable-sdl2 \
    --enable-swresample \
    --enable-swscale \
    --enable-v4l2-m2m \
    --enable-vaapi \
    --enable-vapoursynth \
    --enable-vdpau \
    --enable-vulkan \
    --enable-xlib \
    --enable-zlib \
    --disable-cuda-nvcc \
    --disable-decklink \
    --disable-libklvanc \
    --disable-openssl \
    || { cat ffbuild/config.log; exit 1; }

# configure skips a requested hardware API whose dependencies it cannot
# find, rather than failing. Intel Quick Sync Video (oneVPL) is x86_64 only.
configs="AMF CUDA_LLVM CUVID FFNVCODEC NVDEC NVENC VAAPI VDPAU VULKAN OPENCL"
codecs="H264_DECODER HEVC_DECODER VC1_DECODER VVC_DECODER
        LIBX264_ENCODER LIBX265_ENCODER
        H264_VAAPI_ENCODER HEVC_VAAPI_ENCODER AV1_VAAPI_ENCODER
        H264_NVENC_ENCODER HEVC_NVENC_ENCODER AV1_NVENC_ENCODER
        H264_AMF_ENCODER HEVC_AMF_ENCODER H264_VULKAN_ENCODER
        H264_VAAPI_HWACCEL HEVC_VAAPI_HWACCEL AV1_VAAPI_HWACCEL
        H264_VULKAN_HWACCEL HEVC_NVDEC_HWACCEL"
%ifarch x86_64
configs="$configs LIBVPL"
codecs="$codecs H264_QSV_ENCODER HEVC_QSV_ENCODER AV1_QSV_ENCODER"
%endif
for config in $configs; do
    grep -q "^#define CONFIG_${config} 1" config.h
done
for codec in $codecs; do
    grep -q "^#define CONFIG_${codec} 1" config_components.h
done

%make_build V=1
%make_build documentation V=1
%make_build alltools V=1

%install
%make_install V=1
# Packaged as %%doc in -devel
rm -r %{buildroot}%{_datadir}/%{name}/examples

%check
export LD_LIBRARY_PATH=%{buildroot}%{_libdir}
%{buildroot}%{_bindir}/ffmpeg -hide_banner -version
# Encode and decode a short H.264 and HEVC clip in software
for codec in libx264 libx265; do
    %{buildroot}%{_bindir}/ffmpeg -hide_banner -loglevel error \
        -f lavfi -i testsrc2=size=128x72:rate=25:duration=0.4 \
        -c:v $codec -pix_fmt yuv420p10le out-$codec.mkv
    %{buildroot}%{_bindir}/ffmpeg -hide_banner -loglevel error \
        -i out-$codec.mkv -f null -
done

%files
%doc CREDITS README.md
%{_bindir}/ffmpeg
%{_bindir}/ffplay
%{_bindir}/ffprobe
%{_mandir}/man1/ff*.1*
%dir %{_datadir}/%{name}
%{_datadir}/%{name}/ffprobe.xsd
%{_datadir}/%{name}/libvpx-*.ffpreset

%files libs
%license COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1 COPYING.LGPLv3 LICENSE.md
%{_libdir}/libavcodec.so.%{avcodec_soversion}{,.*}
%{_libdir}/libavfilter.so.%{avfilter_soversion}{,.*}
%{_libdir}/libavformat.so.%{avformat_soversion}{,.*}
%{_libdir}/libavutil.so.%{avutil_soversion}{,.*}
%{_libdir}/libswresample.so.%{swresample_soversion}{,.*}
%{_libdir}/libswscale.so.%{swscale_soversion}{,.*}

%files -n libavdevice
%license COPYING.GPLv2 LICENSE.md
%{_libdir}/libavdevice.so.%{avdevice_soversion}{,.*}

%files devel
%doc MAINTAINERS doc/APIchanges doc/*.txt
%doc _doc/examples
%{_includedir}/%{name}
%{_libdir}/pkgconfig/lib*.pc
%{_libdir}/lib*.so
%{_mandir}/man3/lib*.3*

%changelog
* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 8.1.3-2
- Build for aarch64 (Fedora Asahi Remix), without libvmaf and Quick Sync
  Video, which Fedora has for x86_64 only

* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 8.1.3-1
- Initial package
