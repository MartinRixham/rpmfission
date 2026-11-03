#!/bin/bash
# Whether a spec builds for a Fedora release.
#
#   release-ok.sh <release> <spec>
#
# A spec's "# rpmfission-fedora: <op> <release>" lines (op one of < <= > >= =)
# limit the releases it builds for; it builds for those that meet all of them,
# and for every release if it has none. Exits 0 if the spec builds for the
# release, 1 if not, and 2 on a malformed line.
set -euo pipefail

release=$1
spec=$2
re='^#[[:space:]]*rpmfission-fedora:[[:space:]]*(<|<=|>|>=|=)[[:space:]]*([0-9]+)[[:space:]]*$'

if bad=$(grep -E '^#[[:space:]]*rpmfission-fedora:' "$spec" | grep -vE "$re"); then
    echo "::error::$spec: malformed line: $bad" >&2
    exit 2
fi

while read -r op version; do
    case $op in
        '<') (( release < version )) ;;
        '<=') (( release <= version )) ;;
        '>') (( release > version )) ;;
        '>=') (( release >= version )) ;;
        '=') (( release == version )) ;;
    esac || exit 1
done < <(sed -nE "s/$re/\\1 \\2/p" "$spec")
