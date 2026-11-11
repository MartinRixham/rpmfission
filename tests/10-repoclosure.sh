#!/bin/bash
# Every dependency of the package's RPMs can be met from Fedora (with
# updates), this run's RPMs and the published repository. Catches a Requires
# that a release cannot satisfy, such as an exact version of a Fedora package
# that has since been updated.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

mapfile -t nevras < <(pkg_nevras)
if [ ${#nevras[@]} -eq 0 ]; then
    echo "FAIL: no RPMs of $PKG in $PKG_RPMS"
    exit 1
fi
quiet dnf -y install dnf5-plugins
dnf repoclosure --check=rpmfission-run "${nevras[@]}"
