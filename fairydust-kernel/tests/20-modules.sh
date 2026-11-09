#!/bin/bash
# The modules resolve against the kernel and each other, and the USB-C
# controller driver (tipd) has the fairydust hotplug patch: it calls into DRM
# to report DisplayPort hotplug.
set -euo pipefail
here=$(dirname "$0")
. "$here/lib.sh"

dnf_install kmod binutils xz zstd
extract_kernel fairydust-kernel-16k-core fairydust-kernel-16k-modules-core fairydust-kernel-16k-modules fairydust-kernel-16k-modules-extra

status=0

# depmod -b wants <base>/lib/modules/<kver>
base=${MODDIR%/lib/modules/*}
unresolved=$(depmod -b "$base" -e -F "$MODDIR/System.map" -n "$KVER" 2>&1 > /dev/null |
    grep -i 'unknown symbol' || true)
if [ -n "$unresolved" ]; then
    echo "FAIL: modules with unresolved symbols:"
    echo "$unresolved"
    status=1
else
    echo "ok   every module's symbols resolve"
fi

ko=$(find "$MODDIR" -name 'tps6598x-core.ko*' | head -n 1)
if [ -z "$ko" ]; then
    echo "FAIL: no tps6598x-core module"
    exit 1
fi
case $ko in
    *.xz) xz -dc "$ko" ;;
    *.zst) zstd -qdc "$ko" ;;
    *.gz) gzip -dc "$ko" ;;
    *) cat "$ko" ;;
esac > "$WORKDIR/tipd.ko"
if nm -u "$WORKDIR/tipd.ko" | grep -qw drm_connector_oob_hotplug_event; then
    echo "ok   tipd reports DisplayPort hotplug to DRM"
else
    echo "FAIL: tipd does not call drm_connector_oob_hotplug_event (hotplug patch missing)"
    status=1
fi

exit "$status"
