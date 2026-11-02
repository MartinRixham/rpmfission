#!/bin/bash
# Produce the source tarball (Source0) from the upstream git tag.
# gitlab.gnome.org refuses archive downloads from curl, and so from spectool,
# so the tag is cloned instead. Its commit is pinned in the spec; git checks
# the objects against their hashes, which stands in for a checksum in
# "sources". Called by .copr/srpm.sh in the spec's source directory.
set -euo pipefail

spec=$(dirname "$0")/bijiben.spec
query() { rpmspec -q --srpm --qf "$1\n" "$spec"; }
name=$(query '%{name}')
version=$(query '%{version}')
url=$(query '%{url}')
tag=$(sed -n 's/^%global tag *//p' "$spec")
commit=$(sed -n 's/^%global commit *//p' "$spec")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git clone --quiet --depth 1 --branch "$tag" "$url.git" "$work/repo"
actual=$(git -C "$work/repo" rev-parse HEAD)
if [ "$actual" != "$commit" ]; then
    echo "$tag is $actual, but the spec pins $commit" >&2
    exit 1
fi
git -C "$work/repo" archive --format=tar --prefix="$name-$version/" HEAD |
    xz > "$name-$version.tar.xz"
