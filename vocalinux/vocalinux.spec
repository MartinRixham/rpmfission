# Vocalinux, a voice dictation app, with its default whisper.cpp engine
# running on this repository's pywhispercpp and so on the GPU through Vulkan.
#
# Upstream's own RPM vendors CPU-only pywhispercpp wheels and pynput. Here
# pywhispercpp comes from this repository, and pynput, which Fedora does not
# package, is left out: it is the hotkey backend for X11, and Vocalinux falls
# back to evdev, which works under X11 and Wayland alike.

Name:           vocalinux
Version:        0.18.6
Release:        1%{?dist}
Summary:        Offline voice dictation for Linux

# vocalinux is AGPL-3.0-only; the Silero VAD model it ships
# (speech_recognition/data/silero_vad.onnx) is MIT
License:        AGPL-3.0-only AND MIT
URL:            https://github.com/VocaHQ/vocalinux
Source0:        %{url}/releases/download/v%{version}/%{name}-%{version}.tar.gz

# Vocalinux looks for pywhispercpp's GPU backend next to the extension, and
# so would take this one for CPU-only: look in the whisper package's
# directory too
Patch0:         vocalinux-whisper-vulkan-detect.patch

BuildArch:      noarch

BuildRequires:  desktop-file-utils
BuildRequires:  python3-devel

# Typelibs PyGObject loads, which the Python metadata cannot express
Requires:       gtk3
Requires:       libayatana-appindicator-gtk3
Requires:       python3-cairo
# Text injection and the tray fall back through these
Recommends:     gtk-layer-shell
Recommends:     ibus
Recommends:     libnotify
Recommends:     wl-clipboard
Recommends:     wtype
Recommends:     xclip
Recommends:     xdotool
Recommends:     xsel
Recommends:     ydotool

%description
Vocalinux is a voice dictation system for Linux. Hold the push-to-talk key
(Right Alt by default) and speak, and it transcribes the speech locally and
types it into the focused window, under X11 or Wayland.

Its default engine is whisper.cpp, through pywhispercpp, which this
repository builds against its Vulkan-accelerated whisper.cpp, so dictation
runs on the GPU where there is a Vulkan driver.

%prep
%autosetup -p1 -n %{name}-%{version}
# pynput is not packaged; see the top of this file
sed -i '/"pynput>=/d' pyproject.toml
if grep -q pynput pyproject.toml; then exit 1; fi
# dnf updates the package: do not notify of upstream releases by default
sed -i 's/^DEFAULT_CHECK_AUTOMATICALLY = True$/DEFAULT_CHECK_AUTOMATICALLY = False/' \
    src/vocalinux/utils/update_checker.py
grep -q '^DEFAULT_CHECK_AUTOMATICALLY = False$' src/vocalinux/utils/update_checker.py
# Modules' shebangs; the commands are the entry points
find src -name '*.py' -exec sed -i '1{/^#!/d}' {} +

%generate_buildrequires
%pyproject_buildrequires

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l vocalinux
desktop-file-install --dir=%{buildroot}%{_datadir}/applications vocalinux.desktop
install -Dpm 0644 resources/icons/scalable/vocalinux.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/vocalinux.svg

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/vocalinux.desktop
# The rest needs the runtime dependencies, a display and audio
%pyproject_check_import -t

%files -f %{pyproject_files}
%doc README.md
%{_bindir}/vocalinux
%{_bindir}/vocalinux-gui
%{_datadir}/applications/vocalinux.desktop
%{_datadir}/icons/hicolor/scalable/apps/vocalinux.svg

%changelog
* Mon Nov 16 2026 Martin Rixham <martin.rixham@gmail.com> - 0.18.6-1
- Initial package
