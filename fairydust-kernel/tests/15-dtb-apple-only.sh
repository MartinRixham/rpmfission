#!/bin/bash
# The kernel ships only the Apple silicon device trees, the only ones m1n1
# loads. Each installed kernel copies its dtbs into /boot, which is 1G on
# Fedora Asahi Remix, and the other vendors' made a kernel ~180MB there.
set -euo pipefail
here=$(dirname "$0")
. "$here/lib.sh"

extract_kernel fairydust-kernel-16k-core

others=$(find "$MODDIR/dtb" -mindepth 1 -maxdepth 1 ! -name apple -printf '%f\n')
if [ -n "$others" ]; then
    echo "FAIL: device trees other than Apple's in $MODDIR/dtb: ${others//$'\n'/ }"
    exit 1
fi
count=$(find "$MODDIR/dtb/apple" -name 't[68]1*.dtb' | wc -l)
if [ "$count" -eq 0 ]; then
    echo "FAIL: no Apple silicon device trees in $MODDIR/dtb/apple"
    exit 1
fi
echo "ok   only Apple's device trees ($count for m1n1)"
