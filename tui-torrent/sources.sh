#!/bin/bash
# Produce the vendored crate tarball (Source1) from the upstream crate.
# Called by .copr/srpm.sh with the upstream sources already downloaded into
# the current directory.
set -euo pipefail

name=tui-torrent
version=$(rpmspec -q --qf '%{version}\n' --srpm "$(dirname "$0")/$name.spec")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A .crate is a gzipped tarball holding <name>-<version>/ with its Cargo.lock
tar -xzf "$name-$version.crate" -C "$work"
(
    cd "$work/$name-$version"
    # openssl-sys before 0.9.117 rejects OpenSSL 4 (Fedora 45). Update it and
    # openssl within their semver range; the vendor tarball carries the
    # updated Cargo.lock, which %autosetup -a1 unpacks over upstream's.
    cargo update --quiet -p openssl-sys -p openssl
    cargo vendor --locked --versioned-dirs vendor > /dev/null
)
tar -cJf "$name-$version-vendor.tar.xz" -C "$work/$name-$version" vendor Cargo.lock
