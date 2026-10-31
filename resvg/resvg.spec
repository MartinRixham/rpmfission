# Upstream's release tarball bundles the vendored Rust dependencies, so the
# build runs offline as it would in COPR or mock.

Name:           resvg
Version:        0.49.0
Release:        1%{?dist}
Summary:        SVG rendering tool

# resvg itself is Apache-2.0 OR MIT. The rest covers the bundled crates, as
# printed by %%cargo_license_summary in the build log; update it when bumping
# the version.
SourceLicense:  Apache-2.0 OR MIT
License:        MIT AND BSD-2-Clause AND BSD-3-Clause AND ISC AND Zlib AND (Apache-2.0 OR MIT) AND (0BSD OR MIT OR Apache-2.0) AND (MIT OR Zlib OR Apache-2.0) AND (Unlicense OR MIT)
URL:            https://github.com/linebender/resvg
Source0:        %{url}/releases/download/v%{version}/%{name}-%{version}.tar.xz

ExclusiveArch:  %{rust_arches}

BuildRequires:  cargo-rpm-macros >= 26

%description
resvg renders SVG files to PNG. It aims to support the whole static SVG
subset, including text, filters and embedded raster images. Yazi uses it for
SVG previews.

%prep
%autosetup -n %{name}-%{version}
# Upstream's cargo config points at the bundled vendor directory. Cargo reads
# .cargo/config ahead of the config.toml that %%cargo_prep writes, which would
# hide the rpm profile, so remove it.
rm .cargo/config
%cargo_prep -v vendor

%build
# The workspace's default member is the resvg command line tool; the C API
# and usvg are not built
%cargo_build
%{cargo_license_summary}
%{cargo_license} > LICENSE.dependencies
%cargo_vendor_manifest

%install
install -Dpm 0755 target/rpm/resvg %{buildroot}%{_bindir}/resvg

%check
%cargo_test
%{buildroot}%{_bindir}/resvg --version

%files
%license LICENSE-APACHE LICENSE-MIT LICENSE.dependencies cargo-vendor.txt
%doc README.md CHANGELOG.md
%{_bindir}/resvg

%changelog
* Sat Oct 31 2026 Martin Rixham <martin.rixham@gmail.com> - 0.49.0-1
- Initial package
