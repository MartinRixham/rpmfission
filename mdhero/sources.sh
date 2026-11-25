#!/bin/bash
# Produce the vendored dependencies from the upstream tarball: the Rust crates
# (Source1) and the frontend's node_modules (Source2). Called by .copr/srpm.sh
# with the upstream sources already downloaded into the current directory.
set -euo pipefail

name=mdhero
version=$(rpmspec -q --qf '%{version}\n' --srpm "$(dirname "$0")/$name.spec")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

tar -xzf "$name-$version.tar.gz" -C "$work"
src=$work/$name-$version

(
    cd "$src/src-tauri"
    cargo vendor --locked --versioned-dirs vendor > /dev/null
)
tar -cJf "$name-$version-vendor.tar.xz" -C "$src/src-tauri" vendor

# The SRPM is built on one architecture but the RPMs on both, so take the
# native packages (esbuild, rollup, Tailwind's oxide, lightningcss) for both.
# Install scripts are not run: those of the packages used only fetch or check
# the native binaries that pnpm installs as optional dependencies.
cat > "$src/pnpm-workspace.yaml" <<'YAML'
supportedArchitectures:
  os: [linux]
  cpu: [x64, arm64]
  libc: [glibc]
YAML
(
    cd "$src"
    pnpm install --frozen-lockfile --ignore-scripts --reporter=silent
)
tar -cJf "$name-$version-node_modules.tar.xz" -C "$src" node_modules
