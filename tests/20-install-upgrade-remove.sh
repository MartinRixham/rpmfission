#!/bin/bash
# The package's RPMs install, upgrade from the published build and remove
# with dnf, with no scriptlet failing:
#
#   1. The published build of each of its subpackages, where there is one,
#      is installed, and upgraded with "dnf upgrade" to this run's, as users
#      get it. This exercises Obsoletes, Conflicts and the old build's
#      %preun and %postun. If the published build's dependencies can no
#      longer be met from Fedora, this is skipped with a warning.
#   2. This run's RPMs are installed, for the subpackages not published yet.
#   3. They are all removed.
#
# Weak dependencies are left out, to keep the transactions small.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

status=0
fail() {
    echo "FAIL: $*"
    status=1
}

mapfile -t rpms < <(pkg_rpms)
mapfile -t names < <(pkg_names)
mapfile -t nevras < <(pkg_nevras)
declare -A nevra_of
while read -r name nevra; do
    nevra_of[$name]=$nevra
done < <(pkg_rpms | xargs -r rpm -qp --qf '%{name} %{nevra}\n' 2> /dev/null)

published=()
if dnf repo list --enabled 2> /dev/null | grep -q '^rpmfission-published'; then
    mapfile -t published < <(
        dnf repoquery -q --repo=rpmfission-published --qf '%{name}\n' "${names[@]}" |
            sort -u
    )
fi

if [ ${#published[@]} -gt 0 ]; then
    echo "== Installing the published build: ${published[*]}"
    rc=0
    out=$(dnf_checked install --disable-repo=rpmfission-run "${published[@]}" 2>&1) || rc=$?
    echo "$out"
    if [ "$rc" -ne 0 ] && grep -q 'Failed to resolve the transaction' <<< "$out"; then
        # Its dependencies are gone from Fedora, as for a package that
        # requires an exact Fedora version (mesa-freeworld) once Fedora has
        # moved on: this run's build is what fixes that, so there is nothing
        # to upgrade from.
        echo "::warning::the published build of ${published[*]} no longer installs on Fedora; skipping the upgrade from it"
        published=()
    elif [ "$rc" -ne 0 ]; then
        fail "the published build does not install"
    fi
fi

if [ ${#published[@]} -gt 0 ]; then
    echo "== Upgrading to this run's build"
    dnf_checked upgrade "${published[@]}" || fail "dnf upgrade failed"
    for name in "${published[@]}"; do
        if ! rpm -q "${nevra_of[$name]}" > /dev/null; then
            fail "dnf upgrade left $(rpm -q "$name" || true), not ${nevra_of[$name]}"
        fi
    done
fi

echo "== Installing this run's build"
dnf_checked install "${rpms[@]}" || fail "this run's build does not install"
for nevra in "${nevras[@]}"; do
    rpm -q "$nevra" > /dev/null || fail "$nevra is not installed"
done

echo "== Removing it"
dnf_checked remove "${names[@]}" || fail "dnf remove failed"
for name in "${names[@]}"; do
    if rpm -q "$name" > /dev/null; then
        fail "$name is still installed"
    fi
done

exit "$status"
