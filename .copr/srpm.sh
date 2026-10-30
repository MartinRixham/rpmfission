#!/bin/bash
# Build a source RPM for one package of this repository.
#
#   .copr/srpm.sh <path/to/pkg.spec> <outdir>
#
# Downloads the spec's remote sources and verifies them against the package's
# "sources" file (dist-git format: "SHA512 (file) = hash"), runs the package's
# optional sources.sh hook to generate anything that cannot be downloaded
# (e.g. vendored dependencies), then runs rpmbuild -bs. Used both by COPR's
# make_srpm method (via .copr/Makefile) and by the GitHub Actions workflow.
set -euo pipefail

spec=$(realpath "$1")
outdir=$(realpath -m "$2")
pkgdir=$(dirname "$spec")

mkdir -p "$outdir"
sourcedir=$(mktemp -d)
trap 'rm -rf "$sourcedir"' EXIT

# Local files next to the spec (patches, extra sources) are sources too
find "$pkgdir" -maxdepth 1 -type f ! -name '*.spec' ! -name sources \
    ! -name sources.sh -exec cp -p {} "$sourcedir" \;

spectool --get-files --sourcedir --define "_sourcedir $sourcedir" "$spec"

# Every downloaded source must have a checksum; generated ones (from
# sources.sh) are not downloaded and so are not listed
for url in $(spectool --list-files "$spec" | awk '{print $2}' | grep '://'); do
    file=$(basename "$url")
    grep -qF "($file)" "$pkgdir/sources" 2>/dev/null ||
        { echo "$file has no checksum in $pkgdir/sources" >&2; exit 1; }
done
if [ -f "$pkgdir/sources" ]; then
    (cd "$sourcedir" && sha512sum --check --strict "$pkgdir/sources")
fi

if [ -x "$pkgdir/sources.sh" ]; then
    (cd "$sourcedir" && "$pkgdir/sources.sh")
fi

rpmbuild -bs "$spec" \
    --define "_sourcedir $sourcedir" \
    --define "_srcrpmdir $outdir"
