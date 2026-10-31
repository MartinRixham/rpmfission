# Droid Sans Mono patched by Nerd Fonts with Powerline symbols and icon sets,
# as used by terminal programs such as zellij and yazi. Fedora packages the
# unpatched font (google-droid-sans-mono-fonts) but no Nerd Fonts.

%global fontdir %{_datadir}/fonts/%{name}

Name:           droid-sans-mono-nerd-fonts
Version:        3.5.1
Release:        1%{?dist}
Summary:        Droid Sans Mono patched with Nerd Fonts glyphs

# Droid Sans Mono is Apache-2.0. The added glyphs, per the bundled README.md:
# Codicons and Font Awesome are CC-BY-4.0; MaterialDesign is Apache-2.0;
# Pomicons are OFL-1.1-RFN; Weather Icons are OFL-1.1; the rest are MIT, apart
# from Font Logos, which upstream lists as unlicensed.
License:        Apache-2.0 AND CC-BY-4.0 AND MIT AND OFL-1.1 AND OFL-1.1-RFN
URL:            https://github.com/ryanoasis/nerd-fonts
Source0:        %{url}/releases/download/v%{version}/DroidSansMono.tar.xz#/%{name}-%{version}.tar.xz

BuildArch:      noarch

%description
Droid Sans Mono patched by the Nerd Fonts project with a large number of
extra glyphs: Powerline symbols, Font Awesome, Material Design icons, Devicons,
Octicons and more. Terminal programs use these for status bars, file type icons
and prompts.

Three families are included:
- DroidSansM Nerd Font: icons may be up to about 1.5 cells wide
- DroidSansM Nerd Font Mono: every glyph is one cell wide
- DroidSansM Nerd Font Propo: proportional, for user interfaces

%prep
%setup -q -c

%build

%install
install -d %{buildroot}%{fontdir}
install -pm 0644 *.otf %{buildroot}%{fontdir}/

%files
%license LICENSE.txt
%doc README.md
%{fontdir}

%changelog
* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 3.5.1-1
- Initial package
