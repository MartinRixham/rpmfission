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
#
# If SOURCE_CACHE names a directory, downloaded sources are taken from it
# when present and saved to it once verified, so that a cached source never
# depends on the upstream server again. The checksums are checked either way.
set -euo pipefail

spec=$(realpath "$1")
outdir=$(realpath -m "$2")
pkgdir=$(dirname "$spec")

# "# rpmfission-srpm-requires: <package>..." lines name what the package's
# sources.sh needs, such as cargo or pnpm. Those not installed are installed
# here, so that the shared SRPM environment carries no package's tools.
re='^#[[:space:]]*rpmfission-srpm-requires:([[:space:]]+[A-Za-z0-9._+-]+)+[[:space:]]*$'
if bad=$(grep -E '^#[[:space:]]*rpmfission-srpm-requires:' "$spec" | grep -vE "$re"); then
    echo "$spec: malformed line: $bad" >&2
    exit 1
fi
missing=()
for dep in $(sed -nE 's/^#[[:space:]]*rpmfission-srpm-requires://p' "$spec"); do
    rpm -q --whatprovides "$dep" > /dev/null 2>&1 || missing+=("$dep")
done
# Retried, as Fedora's mirrors sometimes time out
if [ ${#missing[@]} -gt 0 ]; then
    for delay in 30 90 0; do
        dnf -y install "${missing[@]}" && break
        [ "$delay" -gt 0 ] || exit 1
        echo "dnf install failed; retrying in $delay seconds" >&2
        sleep "$delay"
    done
fi

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

# spectool skips files that are already there
if [ -n "${SOURCE_CACHE:-}" ]; then
    mkdir -p "$SOURCE_CACHE"
    for file in $remote_files; do
        if [ -f "$SOURCE_CACHE/$file" ]; then
            echo "Using cached $file"
            cp -p "$SOURCE_CACHE/$file" "$sourcedir"
        fi
    done
fi

# spectool does not fail on download errors, so verify the checksums and
# retry the whole download, backing off for a few minutes in all, to ride out
# flaky upstream servers
attempts=5
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
    sleep $((15 * 2 ** (attempt - 1)))
done

if [ -n "${SOURCE_CACHE:-}" ] && [ -f "$pkgdir/sources" ]; then
    for file in $remote_files; do cp -p "$sourcedir/$file" "$SOURCE_CACHE"; done
fi

if [ -x "$pkgdir/sources.sh" ]; then
    (cd "$sourcedir" && "$pkgdir/sources.sh")
fi

rpmbuild -bs "$spec" \
    --define "_sourcedir $sourcedir" \
    --define "_srcrpmdir $outdir"
