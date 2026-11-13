#!/bin/bash
# Produce the vendored dependency tarball (Source4) from the upstream sources.
# Called by .copr/srpm.sh with the upstream sources already downloaded into
# the current directory.
set -euo pipefail

name=mozilla-vpn
spec="$(dirname "$0")/$name.spec"
version=$(rpmspec -q --qf '%{version}\n' --srpm "$spec")
commit() { sed -nE "s/^%global[[:space:]]+$1_commit[[:space:]]+//p" "$spec"; }
boringtun_commit=$(commit boringtun)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The submodule commits in the spec must be those the tag pins, or a version
# bump that missed them would build with stale submodules. A treeless clone
# fetches only the tag's commit and trees.
git clone --quiet --depth 1 --filter=blob:none --no-checkout \
    --branch "v$version" https://github.com/mozilla-mobile/mozilla-vpn-client.git \
    "$work/git"
for pair in boringtun:boringtun wgtools:wireguard-tools i18n:i18n; do
    pinned=$(git -C "$work/git" ls-tree HEAD "3rdparty/${pair#*:}" | awk '{print $3}')
    if [ "$pinned" != "$(commit "${pair%%:*}")" ]; then
        echo "v$version pins 3rdparty/${pair#*:} at $pinned; update ${pair%%:*}_commit in $spec" >&2
        exit 1
    fi
done

src="$work/mozilla-vpn-client-$version"
tar -xzf "mozilla-vpn-client-$version.tar.gz" -C "$work"

# Likewise nftables (Source5), the one Go dependency of netfilter that is not
# Fedora's
nftables=$(sed -nE 's/^[[:space:]]*github\.com\/google\/nftables v([^[:space:]]+).*/\1/p' \
    "$src/linux/netfilter/go.mod")
spec_nftables=$(sed -nE 's/^%global[[:space:]]+nftables_version[[:space:]]+//p' "$spec")
if [ "$nftables" != "$spec_nftables" ]; then
    echo "linux/netfilter/go.mod requires nftables v$nftables; update nftables_version in $spec" >&2
    exit 1
fi

# boringtun is a member of the Cargo workspace, so cargo needs it to resolve
# the lock file, even though only the obfuscator and signature crates are
# built for Linux
rmdir "$src/3rdparty/boringtun" 2>/dev/null || true
tar -xzf "boringtun-$boringtun_commit.tar.gz" -C "$src/3rdparty"
mv "$src/3rdparty/boringtun-$boringtun_commit" "$src/3rdparty/boringtun"
(
    cd "$src"
    # %cargo_prep -v only redirects crates.io to the vendor directory. Keep
    # the stanzas cargo vendor prints for git dependencies (the obfuscator
    # takes udp-over-tcp from git) so %prep can add them to the config.
    cargo vendor --locked --versioned-dirs vendor |
        awk '/^\[source\./ { keep = /^\[source\."git\+/ } keep' > vendor-git-sources.toml
)
tar -cJf "$name-$version-vendor.tar.xz" -C "$src" vendor vendor-git-sources.toml
