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

The repository has priority 90, ahead of the default 99. Where another
repository, such as RPM Fusion, has a package of the same name, dnf takes this
repository's. Its metadata expires after 6 hours, so dnf sees new builds the
same day. If you added the repository before these were set, add it again with
`--overwrite`.

## Packages

| Package | Upstream |
| ------- | -------- |
| [droid-sans-mono-nerd-fonts](droid-sans-mono-nerd-fonts/droid-sans-mono-nerd-fonts.spec) | https://github.com/ryanoasis/nerd-fonts |
| [ffmpeg](ffmpeg/ffmpeg.spec) | https://ffmpeg.org/ |
| [intel-media-driver](intel-media-driver/intel-media-driver.spec) | https://github.com/intel/media-driver |
| [mesa-freeworld](mesa-freeworld/mesa-freeworld.spec) | https://mesa3d.org/ |
| [resvg](resvg/resvg.spec) | https://github.com/linebender/resvg |
| [tui-torrent](tui-torrent/tui-torrent.spec) | https://github.com/QuintenWiggill/tui-torrent |
| [video-drivers](video-drivers/video-drivers.spec) | (metapackages) |
| [x264](x264/x264.spec) | https://code.videolan.org/videolan/x264 |
| [x265](x265/x265.spec) | https://bitbucket.org/multicoreware/x265_git |
| [yazi](yazi/yazi.spec) | https://github.com/sxyazi/yazi |
| [zellij](zellij/zellij.spec) | https://github.com/zellij-org/zellij |

### FFmpeg and hardware video acceleration

`ffmpeg` has every codec, x264, x265 and all of FFmpeg's hardware APIs. It
replaces Fedora's `ffmpeg-free` and RPM Fusion's `ffmpeg`, with the same
library sonames, so every application that links FFmpeg gets the codecs:

```sh
sudo dnf swap ffmpeg-free ffmpeg --allowerasing
# or, replacing RPM Fusion's build of the same version
sudo dnf reinstall ffmpeg ffmpeg-libs libavdevice x264-libs x265-libs
```

Fedora's video drivers leave out H.264, H.265 and VC-1. The `video-drivers`
packages install full builds, which take precedence over Fedora's:

| Package | Installs |
| ------- | -------- |
| `video-drivers-intel` | `intel-media-driver` (VA-API, Broadwell and newer) and the Quick Sync runtimes |
| `video-drivers-amd` | `mesa-va-drivers-freeworld` (VA-API for radeonsi, r600 and nouveau) |
| `video-drivers-nvidia` | `libva-nvidia-driver`; NVDEC/NVENC need NVIDIA's proprietary driver, from RPM Fusion |
| `video-drivers` | all of the above |

Install the one for your GPU, or `video-drivers` for any GPU (drivers for
absent hardware are not loaded), and check with `vainfo` from `libva-utils`.

`mesa-va-drivers-freeworld` replaces the shared `libgallium` of Fedora's Mesa,
so it must be exactly the version of Fedora's `mesa-dri-drivers`. Until it is
rebuilt for a Fedora Mesa update, dnf holds that update back.

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
- A package whose spec has a `BuildRequires` on another package of this
  repository (`<pkg>`, `<pkg>-devel`, `<pkg>-libs` or `<pkg>-static`, such as
  ffmpeg's on `x264-devel`) builds in a second stage. Its mock chroot gets the
  RPMs built in the first stage and the published repository. Name such
  dependencies as packages, not `pkgconfig()`, so that the build is staged.
  The dependencies themselves must not need this repository.
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
such as tui-torrent, are skipped, as are those hosted elsewhere: ffmpeg, x264
and x265 are updated by hand. Keep x264 and x265 at RPM Fusion's sonames
while their packages, which link them, are installed alongside.

A spec with a `# rpmfission-follows-fedora: <package>` line follows that Fedora
package instead: the PR comes when the oldest release in `FEDORA_RELEASES`
gets a new version of it. `mesa-freeworld` follows `mesa-dri-drivers` this
way.

## Repository settings

- GitHub Pages must deploy from the `gh-pages` branch.
- Actions must be allowed to create pull requests (Settings → Actions →
  General → "Allow GitHub Actions to create and approve pull requests").
