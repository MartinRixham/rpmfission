# RPMFission

Source builds of software packaged as RPMs for the latest stable Fedora
release. They are built on GitHub Actions and served as a dnf repository from
GitHub Pages.

## Using the repository

```sh
sudo dnf config-manager addrepo --from-repofile=https://martinrixham.github.io/rpmfission/rpmfission.repo
sudo dnf install zellij
```

Packages are not signed yet (`gpgcheck=0`).

## Packages

| Package | Upstream |
| ------- | -------- |
| [zellij](zellij/zellij.spec) | https://github.com/zellij-org/zellij |

## Layout

The layout follows COPR's conventions so that packages can be moved to COPR
without changes:

- `<name>/<name>.spec`: one directory per package, with the spec and any local
  sources or patches.
- `<name>/sources`: SHA512 checksums of the spec's downloaded sources, in
  dist-git format (`sha512sum --tag <file>`). Every remote source must be
  listed, and the SRPM build fails on a missing or mismatched checksum.
- `<name>/sources.sh`: an optional hook that generates sources that cannot be
  downloaded, such as vendored Rust crates. It runs in a directory that already
  holds the spec's downloaded sources.
- `.copr/Makefile`: the entry point for COPR's **make_srpm** source method.
  It calls `.copr/srpm.sh`, which downloads sources with `spectool`, checks
  them against `sources`, runs the hook and builds the SRPM.

CI does what COPR does: it builds the SRPM through `.copr/Makefile`, then
rebuilds it with `mock` in the `fedora-<release>-x86_64` chroot. The network is
off during the RPM build. The published repository uses COPR's per-chroot
layout (`fedora-$releasever-$basearch/`).

## Building locally

```sh
make -f .copr/Makefile srpm outdir=out spec=zellij/zellij.spec
mock -r fedora-44-x86_64 --rebuild out/*.src.rpm
```

## CI

- A push to `main` builds the packages whose directories changed. A change
  under `.copr/` or `.github/` rebuilds everything.
- Running the workflow by hand builds the listed packages, or `all`. Do this
  after a new Fedora release to fill its chroot.
- Built binary RPMs are added to the `gh-pages` branch. The two newest builds
  of each package are kept, and the branch is force-pushed as a single commit.
  SRPMs and debuginfo packages are too large for git. They are kept only as
  workflow artifacts, along with the mock logs.

GitHub Pages must be set to deploy from the `gh-pages` branch.
