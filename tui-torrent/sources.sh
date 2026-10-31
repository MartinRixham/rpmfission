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
    cargo vendor --locked --versioned-dirs vendor > /dev/null
)
tar -cJf "$name-$version-vendor.tar.xz" -C "$work/$name-$version" vendor
