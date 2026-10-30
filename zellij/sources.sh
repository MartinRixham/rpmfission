#!/bin/bash
# Produce the vendored crate tarball (Source1) from the upstream tarball.
# Called by .copr/srpm.sh with the upstream sources already downloaded into
# the current directory.
set -euo pipefail

name=zellij
version=$(rpmspec -q --qf '%{version}\n' --srpm "$(dirname "$0")/$name.spec")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

tar -xzf "$name-$version.tar.gz" -C "$work"
(
    cd "$work/$name-$version"
    rm -f rust-toolchain.toml
    cargo vendor --locked --versioned-dirs vendor > /dev/null
)
tar -cJf "$name-$version-vendor.tar.xz" -C "$work/$name-$version" vendor
