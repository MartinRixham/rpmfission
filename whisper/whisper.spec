# whisper.cpp with its Vulkan backend, which runs on any GPU with a Vulkan
# driver, including Apple Silicon's under Fedora Asahi Remix (Honeykrisp).
#
# The libraries (libwhisper and ggml) are private, in %%{_libdir}/whisper,
# because Fedora's whisper-cpp and llama-cpp packages ship their own builds
# of them under the same sonames. The commands find them through their
# RPATH. whisper-devel keeps to the same directory, and its headers to
# %%{_includedir}/whisper, so that it installs alongside whisper-cpp-devel:
# programs that build against it find it through its CMake package
# (-Dwhisper_DIR=%%{_libdir}/whisper/cmake/whisper) and need the same RPATH.
#
# The ggml backends are loaded at runtime from the same directory: one CPU
# backend for each level of x86_64 or aarch64 features, from which ggml picks
# the best the CPU supports, and Vulkan, which ggml uses when it finds a GPU
# and skips otherwise.

%global libdir_private %{_libdir}/whisper

# The private libraries must not provide their sonames, which would satisfy
# other packages' dependencies on Fedora's builds of them; so the commands,
# in the same package, do not require them either
%global __provides_exclude_from ^%{libdir_private}/.*$
%global __requires_exclude ^lib(whisper|parakeet|ggml|ggml-base)\\.so.*$

Name:           whisper
Version:        1.9.6
Release:        1%{?dist}
Summary:        Speech recognition with OpenAI's Whisper models, accelerated with Vulkan

# whisper.cpp and ggml are MIT. examples/miniaudio.h is MIT-0 or Unlicense,
# examples/stb_vorbis.c is MIT or Unlicense, and the header-only libraries
# the server uses (httplib.h, json.hpp) are MIT.
License:        MIT AND (MIT-0 OR Unlicense) AND (MIT OR Unlicense)
URL:            https://github.com/ggml-org/whisper.cpp
Source0:        %{url}/archive/v%{version}/whisper.cpp-%{version}.tar.gz

ExclusiveArch:  x86_64 aarch64

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  glslc
BuildRequires:  pkgconfig(sdl2)
BuildRequires:  spirv-headers-devel
BuildRequires:  vulkan-headers
BuildRequires:  vulkan-loader-devel

# whisper-download-ggml-model downloads with any of these
Requires:       (curl or wget or wget2)
# The Vulkan backend needs a driver to use the GPU; without one, ggml falls
# back to the CPU
Recommends:     mesa-vulkan-drivers

%description
whisper.cpp is a C/C++ implementation of OpenAI's Whisper automatic speech
recognition model. This build runs the model on the GPU through Vulkan where
there is a Vulkan driver, and otherwise on the CPU, with the best code for its
instruction set.

It contains whisper-cli, which transcribes and translates audio files,
whisper-server, an HTTP server with an OpenAI-compatible transcription API,
whisper-stream and whisper-command, which transcribe from the microphone,
whisper-lsp, a language server for voice commands in editors, whisper-bench,
whisper-quantize, and parakeet-cli and parakeet-quantize, for NVIDIA's
Parakeet models. Models are not included: whisper-download-ggml-model
downloads Whisper models into the current directory.

%package        devel
Summary:        Development files for the whisper package's whisper.cpp
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description    devel
Headers, CMake packages and pkg-config files for building against this
package's libwhisper and ggml, which are installed in %{libdir_private}
rather than on the linker's search path. The ggml backends are loaded at
runtime, so a program must call ggml_backend_load_all() before it creates a
whisper context.

%prep
%autosetup -n whisper.cpp-%{version}
# The talk-llama example downloads llama.cpp while configuring, and needs a
# llama.cpp model to run, so it is not built
sed -i '/add_subdirectory(talk-llama)/d' examples/CMakeLists.txt
if grep -q talk-llama examples/CMakeLists.txt; then exit 1; fi

%build
# GGML_NATIVE would tune the build for the build machine's CPU; the CPU
# variants are selected at runtime instead.
%cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=%{_lib}/whisper \
    -DCMAKE_INSTALL_INCLUDEDIR=include/whisper \
    -DCMAKE_INSTALL_RPATH=%{libdir_private} \
    -DCMAKE_SKIP_INSTALL_RPATH=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=ON \
    -DWHISPER_BUILD_SERVER=ON \
    -DWHISPER_SDL2=ON \
    -DGGML_NATIVE=OFF \
    -DGGML_BACKEND_DL=ON \
    -DGGML_BACKEND_DIR=%{libdir_private} \
    -DGGML_CPU_ALL_VARIANTS=ON \
    -DGGML_VULKAN=ON
%cmake_build

%install
%cmake_install
install -Dpm 0755 models/download-ggml-model.sh \
    %{buildroot}%{_bindir}/whisper-download-ggml-model

# The deprecated names of the commands, which only print a warning
for f in %{buildroot}%{_bindir}/*; do
    case "${f##*/}" in
        whisper-*|parakeet-*) ;;
        *) rm "$f" ;;
    esac
done

%check
# Models are not packaged, so nothing is transcribed: the commands link and
# start, and the backends were installed.
LD_LIBRARY_PATH=%{buildroot}%{libdir_private} \
    %{buildroot}%{_bindir}/whisper-cli --help > /dev/null 2>&1
ls %{buildroot}%{libdir_private}/libggml-cpu-*.so
ls %{buildroot}%{libdir_private}/libggml-vulkan.so

%files
%license LICENSE
%doc README.md
%{_bindir}/whisper-*
%{_bindir}/parakeet-*
%dir %{libdir_private}
%{libdir_private}/libwhisper.so.1*
%{libdir_private}/libparakeet.so.*
%{libdir_private}/libggml.so.1*
%{libdir_private}/libggml-base.so.1*
# The backends are loaded with dlopen and so have no soname
%{libdir_private}/libggml-cpu-*.so
%{libdir_private}/libggml-vulkan.so

%files devel
%{_includedir}/whisper/
%{libdir_private}/libwhisper.so
%{libdir_private}/libparakeet.so
%{libdir_private}/libggml.so
%{libdir_private}/libggml-base.so
%{libdir_private}/cmake/
%{libdir_private}/pkgconfig/

%changelog
* Wed Nov 25 2026 Martin Rixham <martin.rixham@gmail.com> - 1.9.6-1
- Update to 1.9.6, whose ggml libraries have soname 1

* Mon Nov 16 2026 Martin Rixham <martin.rixham@gmail.com> - 1.9.5-1
- Initial package
