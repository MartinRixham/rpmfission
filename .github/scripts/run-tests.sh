#!/bin/bash
# Run a package's tests against the RPMs built for one chroot.
#
#   run-tests.sh <pkg> <chroot> <rpm-dir> [<pkg-rpm-dir>]
#
# The tests are the executable files in the top-level tests/ directory, run
# for every package, and then those in the package's own tests/, next to its
# spec. Each runs from the top of the checkout as root in a Fedora container
# of the chroot's release and architecture, with network access.
# Non-executable files there are helpers for the tests. A package leaves out
# top-level tests by listing their file names in its tests/skip-common,
# one per line, with a comment saying why. Tests run in order, the common
# ones first; all of them run even if one fails, and the run fails if any did.
#
# <rpm-dir> holds the RPMs this workflow run built for the chroot. It is made
# a dnf repository (rpmfission-run, priority 1), and the published repository
# for the chroot (rpmfission-published, priority 2) is added after it, so
# "dnf download" and "dnf install" in a test take this run's build of a
# package first and the published one for packages the run did not build.
#
# <pkg-rpm-dir> holds the package's own RPMs of this run, which the common
# tests install; it defaults to <rpm-dir>, for a directory of only the
# package's RPMs.
#
# Each test gets in its environment:
#   PKG      the package, e.g. ffmpeg8
#   PKG_RPMS <pkg-rpm-dir>
#   CHROOT   the chroot, e.g. fedora-44-aarch64
#   RELEASE  its Fedora release, e.g. 44
#   ARCH     its architecture, e.g. aarch64
#   RPMS     <rpm-dir>
#   WORKDIR  an empty directory of its own
#
# Environment: REPO_URL, the published repository's base URL; optional, and
# without it only this run's RPMs are available.
set -euo pipefail

pkg=$1
chroot=$2
rpms=$(realpath "$3")
pkg_rpms=$(realpath "${4:-$3}")

release=$(cut -d- -f2 <<< "$chroot")
arch=$(cut -d- -f3 <<< "$chroot")

shopt -s nullglob
skip=()
if [ -f "$pkg/tests/skip-common" ]; then
    mapfile -t skip < <(sed -E 's/#.*//; s/[[:space:]]+//g; /^$/d' "$pkg/tests/skip-common")
fi
tests=()
for test in tests/*; do
    [ -f "$test" ] && [ -x "$test" ] || continue
    if printf '%s\n' "${skip[@]}" | grep -qxF "$(basename "$test")"; then
        echo "SKIP $test (listed in $pkg/tests/skip-common)"
        continue
    fi
    tests+=("$test")
done
for test in "$pkg"/tests/*; do
    [ -f "$test" ] && [ -x "$test" ] && tests+=("$test")
done

out=$(dnf -y install createrepo_c 2>&1) || { echo "$out" >&2; exit 1; }
createrepo_c -q "$rpms"
{
    echo "[rpmfission-run]"
    echo "name=RPMs of this workflow run"
    echo "baseurl=file://$rpms"
    echo "priority=1"
    echo "gpgcheck=0"
    echo "skip_if_unavailable=False"
    if [ -n "${REPO_URL:-}" ]; then
        echo
        echo "[rpmfission-published]"
        echo "name=Published rpmfission repository"
        echo "baseurl=$REPO_URL/$chroot/"
        echo "priority=2"
        echo "gpgcheck=1"
        echo "gpgkey=$REPO_URL/RPM-GPG-KEY-${REPO_URL##*/}"
        # A chroot not yet published has no repository
        echo "skip_if_unavailable=True"
    fi
} > /etc/yum.repos.d/rpmfission-test.repo

status=0
failed=()
for test in "${tests[@]}"; do
    workdir=$(mktemp -d)
    echo "::group::$test"
    rc=0
    PKG=$pkg PKG_RPMS=$pkg_rpms CHROOT=$chroot RELEASE=$release ARCH=$arch RPMS=$rpms WORKDIR=$workdir \
        "$test" || rc=$?
    echo "::endgroup::"
    if [ "$rc" -eq 0 ]; then
        echo "PASS $test"
    else
        echo "::error::FAIL $test (exit $rc)"
        failed+=("$test")
        status=1
    fi
    rm -rf "$workdir"
done

if [ "$status" -ne 0 ]; then
    echo "$pkg on $chroot: ${#failed[@]} of ${#tests[@]} tests failed: ${failed[*]}"
fi
exit "$status"
