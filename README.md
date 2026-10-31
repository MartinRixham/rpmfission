# RPMFission

Source builds of software packaged as RPMs for the supported Fedora
releases. They are built on GitHub Actions and served as a dnf repository from
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
| [tui-torrent](tui-torrent/tui-torrent.spec) | https://github.com/QuintenWiggill/tui-torrent |
| [yazi](yazi/yazi.spec) | https://github.com/sxyazi/yazi |
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
- Running the workflow by hand builds the listed packages, or `all`.
- Every package is built for each Fedora release in `FEDORA_RELEASES` at the
  top of `.github/workflows/build.yml`. A release whose chroot is not yet on
  `gh-pages` gets every package. Add a release when it branches or ships, and
  remove it at end of life. Its chroot is then deleted from `gh-pages` on the
  next publish.
- Built binary RPMs are added to the `gh-pages` branch. The two newest builds
  of each package are kept, and the branch is force-pushed as a single commit.
  SRPMs and debuginfo packages are too large for git. They are kept only as
  workflow artifacts, along with the mock logs.

- Only `main` publishes. Builds of other branches keep their RPMs as
  workflow artifacts.

## Upstream updates

A daily workflow (`.github/workflows/update.yml`) checks the upstream GitHub
repository of each package, the first `github.com/<owner>/<repo>` in the
spec's `URL` or `Source` fields. When the latest release (not a draft or
pre-release) is newer than the spec's `Version`, it opens a pull request on
`update/<name>-<version>`. The PR bumps `Version`, resets `Release`, adds a
changelog entry and refreshes `sources`, and the build workflow runs on its
branch. Patches, `License:` and anything else the release changes are left to
review. A version whose branch already exists is not offered again, so to skip
a release, close its PR and keep the branch. Packages with no GitHub releases,
such as tui-torrent, are skipped.

## Repository settings

- GitHub Pages must deploy from the `gh-pages` branch.
- Actions must be allowed to create pull requests (Settings → Actions →
  General → "Allow GitHub Actions to create and approve pull requests").
