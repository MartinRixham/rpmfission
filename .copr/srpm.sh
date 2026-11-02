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

# Every downloaded source must have a checksum; generated ones (from
# sources.sh) are not downloaded and so are not listed
remote_files=$(spectool --list-files "$spec" | awk '{print $2}' |
    { grep '://' || true; } | xargs -rn1 basename)
for file in $remote_files; do
    grep -qF "($file)" "$pkgdir/sources" 2>/dev/null ||
        { echo "$file has no checksum in $pkgdir/sources" >&2; exit 1; }
done

# spectool does not fail on download errors, so verify the checksums and
# retry the whole download a few times to ride out flaky upstream servers
attempts=3
for attempt in $(seq "$attempts"); do
    spectool --get-files --sourcedir --define "_sourcedir $sourcedir" "$spec"
    if [ ! -f "$pkgdir/sources" ] ||
        (cd "$sourcedir" && sha512sum --check --strict "$pkgdir/sources"); then
        break
    fi
    if [ "$attempt" -eq "$attempts" ]; then
        echo "Sources failed verification after $attempts attempts" >&2
        exit 1
    fi
    echo "Source verification failed (attempt $attempt/$attempts), retrying" >&2
    # Drop partial or corrupt downloads so spectool fetches them again
    for file in $remote_files; do rm -f "$sourcedir/$file"; done
    sleep $((attempt * 10))
done

if [ -x "$pkgdir/sources.sh" ]; then
    (cd "$sourcedir" && "$pkgdir/sources.sh")
fi

rpmbuild -bs "$spec" \
    --define "_sourcedir $sourcedir" \
    --define "_srcrpmdir $outdir"
