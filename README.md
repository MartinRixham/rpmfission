# RPMFission

Source builds of software packaged as RPMs for the supported Fedora
releases, on x86_64 and aarch64. The aarch64 builds also serve Fedora Asahi
Remix on Apple Silicon Macs. They are built on GitHub Actions and served as a dnf repository from
GitHub Pages.

## Using the repository

```sh
sudo dnf config-manager addrepo --from-repofile=https://martinrixham.github.io/rpmfission/rpmfission.repo
sudo dnf install zellij
```

The packages and the repository metadata are signed. dnf asks you to accept
the key the first time you install from the repository. If you added the repository before signing began, add it again
with `--overwrite` so that dnf checks the signatures.

On Fedora Asahi Remix the same commands work: the Remix is Fedora's aarch64
release, so dnf picks the `fedora-$releasever-aarch64` repository. Its 16K
page kernel needs nothing special from these packages, except yazi's jemalloc,
which is built for pages of up to 64K.

The repository has priority 90, ahead of the default 99. Where another
repository, such as RPM Fusion, has a package of the same name, dnf takes this
repository's. Its metadata expires after 6 hours, so dnf sees new builds the
same day. If you added the repository before these were set, add it again with
`--overwrite`.

## Packages

`intel-media-driver` and `mesa-freeworld` are x86_64 only, and
`avd-fw-freeworld` and `fairydust-kernel` (Fedora Asahi Remix),
`gstreamer1-plugins-bad-free` and `mesa` are aarch64 only. On aarch64, `ffmpeg` has no libvmaf or Intel Quick Sync Video,
which Fedora builds for x86_64 only.

| Package | Upstream |
| ------- | -------- |
| [avd-fw-freeworld](avd-fw-freeworld/avd-fw-freeworld.spec) | https://github.com/AsahiLinux/avd-fw |
| [bijiben](bijiben/bijiben.spec) | https://gitlab.gnome.org/MartinRixham/gnome-notes |
| [droid-sans-mono-nerd-fonts](droid-sans-mono-nerd-fonts/droid-sans-mono-nerd-fonts.spec) | https://github.com/ryanoasis/nerd-fonts |
| [fairydust-kernel](fairydust-kernel/fairydust-kernel.spec) (Asahi's `kernel-16k`, with DisplayPort over USB-C) | https://github.com/AsahiLinux/linux |
| [ffmpeg](ffmpeg/ffmpeg.spec) (Fedora 45 and later) | https://ffmpeg.org/ |
| [ffmpeg8](ffmpeg8/ffmpeg8.spec) (`ffmpeg` 8 for Fedora 44) | https://ffmpeg.org/ |
| [gstreamer1-plugins-bad-free](gstreamer1-plugins-bad-free/gstreamer1-plugins-bad-free.spec) (Fedora's, with a fix) | https://gstreamer.freedesktop.org/ |
| [intel-media-driver](intel-media-driver/intel-media-driver.spec) | https://github.com/intel/media-driver |
| [mesa](mesa/mesa.spec) (Fedora's, with a fix; [mesa-fedora44](mesa-fedora44/mesa-fedora44.spec) for Fedora 44) | https://mesa3d.org/ |
| [mesa-freeworld](mesa-freeworld/mesa-freeworld.spec) | https://mesa3d.org/ |
| [mozilla-vpn](mozilla-vpn/mozilla-vpn.spec) | https://github.com/mozilla-mobile/mozilla-vpn-client |
| [mullvad-containers](mullvad-containers/mullvad-containers.spec) (Mullvad servers in Multi-Account Containers; conflicts with `mozilla-vpn`) | (this repository) |
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
library sonames, so every application that links FFmpeg gets the codecs. Each
release gets the FFmpeg major version Fedora ships for it: 8 for Fedora 44
(from `ffmpeg8/`) and 9 for Fedora 45 (from `ffmpeg/`), under the same package
names:

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
| `video-drivers-apple` | `avd-fw-freeworld` (video decoder firmware for Apple Silicon Macs, on Fedora Asahi Remix) |
| `video-drivers` | all of the above for the architecture: Intel, AMD and NVIDIA on x86_64, Apple on aarch64 |

Install the one for your GPU, or `video-drivers` for any GPU (drivers for
absent hardware are not loaded), and check with `vainfo` from `libva-utils`.

On Apple Silicon, the firmware is Asahi's, built with H.264 and H.265, which
Asahi's own `avd-fw` package leaves out. It replaces that package
(`sudo dnf swap avd-fw video-drivers-apple` where it is installed), and the
decoder starts after a reboot. It is a V4L2 decoder rather than VA-API:
GStreamer applications use it through the `v4l2codecs` plugin, but FFmpeg, and
so mpv, Firefox and Chromium, does not support it yet. Check for the decoder
with `v4l2-ctl --list-devices` from `v4l-utils`.

`gstreamer1-plugins-bad-free` is Fedora's package with a fix to that plugin:
Fedora's gives the frames the padded size of the decoder's buffers, so
`videoconvert` squashes 1080p video by 8 lines. `mesa` is Fedora's Mesa with a
fix to Honeykrisp, the Vulkan driver, which misplaced the colour of those
frames in GTK's Vulkan renderer (a green band across the top in GNOME's video
player). Both follow Fedora's version like `mesa-freeworld`. Fedora's dnf
does not change a package's vendor on upgrade, so `video-drivers-apple`
installs a vendor change policy (`/usr/share/dnf5/vendors.d/rpmfission.conf`)
that lets dnf replace Fedora's builds with these. With `video-drivers-apple`
installed, the next `dnf upgrade` after it does so.

### DisplayPort over USB-C on Apple Silicon

`fairydust-kernel` swaps Fedora Asahi Remix's 16K kernel (`kernel-16k`) for
the same kernel with the patches of Asahi's `fairydust` branch, which give
the front-left USB-C port of the MacBook Air 13" and 15" (M2) and MacBook Pro
13" (M2) DisplayPort output, with audio and hotplug. No other port carries
video. The patches are Asahi's work in progress, by their own account hacks,
and the port's power domain stays on, which costs some battery life at idle.
m1n1, the bootloader stage that hands the device tree to the kernel, stays
Fedora's: it reserves the firmware of the display coprocessor the port uses
on M2 Macs from 1.9.9, the version Fedora ships, at least.

```sh
sudo dnf install fairydust-kernel
```

This installs the fairydust kernel as `fairydust-kernel-16k`, beside
Asahi's `kernel-16k`, which keeps coming from Asahi. It becomes the default
boot entry, and `/boot/efi/m1n1/boot.bin`, m1n1 stage 2, is rebuilt with its
device trees. It stays the default when Asahi's kernel is updated:
`fairydust-kernel` sets it back after every transaction that installs a
kernel. Reboot to start it; `uname -r` then ends in
`.fairydust.fc44.aarch64+16k`. To swap back:

```sh
sudo dnf remove fairydust-kernel
```

This makes Asahi's newest 16K kernel the default again and rebuilds
`boot.bin` with its device trees. dnf also removes the `fairydust-kernel-16k`
packages it installed with it. If it keeps the running kernel, reboot into
Asahi's and run `sudo dnf autoremove`.

m1n1 runs before GRUB, so a broken `boot.bin` can only be fixed from macOS
recovery: keep a copy of it first. For the same reason, picking the other
kind of kernel in GRUB boots it with the default kernel's device trees.

The fairydust kernel must be rebuilt for each Asahi kernel. A build older
than Asahi's newest is not published (see
`fairydust-kernel/tests/30-newer-than-asahi.sh`); see the top of
`fairydust-kernel/fairydust-kernel.spec` for the update. The debug kernel,
debuginfo, `kernel-headers` and the tools are not built, and Asahi's stay in
use.

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
- `# rpmfission-fedora: <op> <release>`: optional spec comments (`op` one of
  `<`, `<=`, `>`, `>=` and `=`) that limit the Fedora releases the package
  builds for, such as `< 45`. A package can so have a spec per range of
  releases, as `ffmpeg` and `ffmpeg8` do. A malformed line fails the build.
- `<name>/sources.sh`: an optional hook that generates sources that cannot be
  downloaded, such as vendored Rust crates. It runs in a directory that already
  holds the spec's downloaded sources.
- `.copr/Makefile`: the entry point for COPR's **make_srpm** source method.
  It calls `.copr/srpm.sh`, which downloads sources with `spectool`, checks
  them against `sources`, runs the hook and builds the SRPM.

CI does what COPR does: it builds the SRPM through `.copr/Makefile`, then
rebuilds it with `mock` in the `fedora-<release>-<arch>` chroot, on a GitHub
runner of that architecture (`ubuntu-24.04-arm` for aarch64). A package whose
`ExclusiveArch` or `ExcludeArch` rules out an architecture is not built
for it, nor is a package for a release its `rpmfission-fedora` lines rule
out. The network is
off during the RPM build. The published repository uses COPR's per-chroot
layout (`fedora-$releasever-$basearch/`).

## Building locally

```sh
make -f .copr/Makefile srpm outdir=out spec=zellij/zellij.spec
mock -r fedora-45-x86_64 --rebuild out/*.src.rpm
```

Use `fedora-45-aarch64` on an aarch64 machine, and `fedora-44-*` for Fedora
44. mock can build it on x86_64
through `qemu-user-static`, but slowly.

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
  remove it at end of life. Its chroot is then deleted from `gh-pages`, and
  its release, on the next publish.
- Built binary RPMs are uploaded to a GitHub release per chroot, tagged with
  the chroot's name, such as `fedora-45-x86_64`. The two newest builds of each
  package are kept. The repository metadata, `.repo` file and key are on the
  `gh-pages` branch, force-pushed as a single commit, and the metadata points
  dnf at the release assets: GitHub Pages times out deploying the RPMs
  themselves. SRPMs and debuginfo packages are kept only as workflow
  artifacts, along with the mock logs.

- Only `main` publishes. Builds of other branches keep their RPMs as
  workflow artifacts.
- Every build is tested after both build stages, in a container of the
  chroot's release, on a runner of its architecture (see
  `.github/scripts/run-tests.sh`). The tests are the executable files in the
  top-level `tests/` directory, run for every package, then those in the
  package's own `tests/` directory. A change to the top-level `tests/` builds
  nothing; it is first run by the next build of each package. Tests get the run's RPMs for the chroot as a dnf
  repository ahead of the published one. A package whose tests do not all
  pass is not published for that chroot. A package leaves out a top-level test
  by naming it in its own `tests/skip-common`, with a comment saying why.
  To run them locally, give the script a directory of the run's RPMs and one
  of the package's own, as root in a Fedora container:
  `podman run --rm -v $PWD:/r -v ./rpms:/rpms -w /r fedora:44 .github/scripts/run-tests.sh ffmpeg8 fedora-44-aarch64 /rpms/run /rpms/ffmpeg8`.
  Add `-e REPO_URL=https://martinrixham.github.io/rpmfission` to test the
  upgrade from the published build.
  The common tests check that every dependency of the package can be met
  (`dnf repoclosure`), and that it upgrades from the published build,
  installs and removes with no scriptlet failing. `ffmpeg` and `ffmpeg8`
  check that their libraries provide every soname and symbol version of
  Fedora's `-free` libraries, and that `dnf swap ffmpeg-free ffmpeg
  --allowerasing` removes nothing else and leaves Fedora's GStreamer libav
  plugin decoding H.264 and H.265 through them.
  `fairydust-kernel` checks the device trees for DisplayPort over USB-C, the modules and
  the USB-C driver's hotplug patch, that it is at least as new as Asahi's kernel,
  boots it in QEMU with 16K pages, and installs and removes it beside Asahi's
  kernel to check the swap of the default boot entry and m1n1's device trees.
  They cannot test the hardware.

## Upstream updates

A daily workflow (`.github/workflows/update.yml`) checks the upstream GitHub
repository of each package, the first `github.com/<owner>/<repo>` in the
spec's `URL` or `Source` fields. When the latest release (not a draft or
pre-release) is newer than the spec's `Version`, it keeps an issue titled
`<name>: newer version available` open, with a checklist for the update, and
the workflow run fails. The issue closes itself once the spec is up to date.
Packages with no GitHub releases,
such as tui-torrent, are skipped, as are those hosted elsewhere: bijiben,
ffmpeg, ffmpeg8, x264 and x265 are updated by hand. bijiben's tarball is made from its
git tag by `sources.sh`, so a bump changes the `tag` and `commit` at the top of
its spec rather than `sources`. mozilla-vpn also needs three of upstream's git submodules,
which the tag's tarball leaves out: a bump updates the commits at the top of
its spec to those the new tag pins (`sources.sh` fails until they match),
along with their checksums, and its `nftables_version` to that of
`linux/netfilter/go.mod`: the netfilter library builds against Fedora's Go
packages, but for nftables, which Fedora does not package. Keep x264 and x265 at RPM Fusion's sonames
while their packages, which link them, are installed alongside.

A spec that carries Fedora's patches for a package names it on a
`# rpmfission-fedora-patches: <package>` line. The same workflow compares the
spec's patches, by file name, with those of Fedora's spec for each release the
spec builds for, and keeps an issue open for each that differs, such as when
Fedora backports a fix, failing the workflow run meanwhile. Fedora patches
left out on purpose go on `# rpmfission-fedora-patches-ignore:` lines, with a
comment saying why. ffmpeg and ffmpeg8 do this.

A spec with a `# rpmfission-follows-fedora: <package>` line follows that Fedora
package instead: the issue comes when the oldest release in `FEDORA_RELEASES`
gets a new version of it. `mesa-freeworld` follows `mesa-dri-drivers` this
way, and `gstreamer1-plugins-bad-free` and `mesa` follow Fedora's own
packages. To update one, take Fedora's new spec and redo the changes the spec
marks.

## Repository settings

- GitHub Pages must deploy from the `gh-pages` branch.
