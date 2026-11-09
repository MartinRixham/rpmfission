#!/bin/bash
# The kernel is at least as new as the newest kernel-16k of Fedora Asahi Remix
# (the @asahi/kernel COPR) for the release. With fairydust-kernel installed it
# stays the default boot entry when Asahi's kernel is updated, so publishing
# an older kernel would hold its users back on it. When this fails, Asahi has
# released a newer kernel: move fairydust-kernel/ to its source RPM (see the
# comment at the top of fairydust-kernel.spec).
set -euo pipefail
here=$(dirname "$0")
. "$here/lib.sh"

dnf_install rpmdevtools
extract_kernel fairydust-kernel-16k-core
# Asahi's release without our build id, which sorts before Asahi's own
# release (".fairydust.fc44" < ".fc44")
ours=$(rpm -qp --nosignature --qf '%{epoch}:%{version}-%{release}\n' \
    "$WORKDIR"/rpms/fairydust-kernel-16k-core-*.rpm | sed -e 's/^(none)/0/' -e 's/\.fairydust//')

copr=https://download.copr.fedorainfracloud.org/results/@asahi/kernel/fedora-$RELEASE-$ARCH/
theirs=$(dnf repoquery -q --repofrompath="asahi-kernel,$copr" --repo=asahi-kernel \
    --latest-limit=1 --qf '%{epoch}:%{version}-%{release}\n' kernel-16k-core)
if [ -z "$theirs" ]; then
    echo "FAIL: no kernel-16k-core in $copr"
    exit 1
fi

# rpmdev-vercmp exits 0 when the versions are equal, 11 when the first is newer
rc=0
rpmdev-vercmp "$ours" "$theirs" > /dev/null || rc=$?
if [ "$rc" -eq 0 ] || [ "$rc" -eq 11 ]; then
    echo "ok   $ours is at least Asahi's $theirs"
else
    echo "FAIL: $ours is older than Asahi's $theirs; update fairydust-kernel/ to Asahi's kernel"
    exit 1
fi
