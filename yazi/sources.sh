#!/bin/bash
# Produce the vendored crate tarball (Source1) from the upstream tarball.
# Called by .copr/srpm.sh with the upstream sources already downloaded into
# the current directory.
set -euo pipefail

name=yazi
version=$(rpmspec -q --qf '%{version}\n' --srpm "$(dirname "$0")/$name.spec")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

tar -xzf "$name-$version.tar.gz" -C "$work"
(
    cd "$work/$name-$version"
    # %cargo_prep -v only redirects crates.io to the vendor directory. Keep
    # the stanzas cargo vendor prints for git dependencies (upstream patches
    # ratatui-core from a git branch) so %prep can add them to the config.
    cargo vendor --locked --versioned-dirs vendor |
        awk '/^\[source\./ { keep = /^\[source\."git\+/ } keep' > vendor-git-sources.toml
)
tar -cJf "$name-$version-vendor.tar.xz" -C "$work/$name-$version" \
    vendor vendor-git-sources.toml
