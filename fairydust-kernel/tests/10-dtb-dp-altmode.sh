#!/bin/bash
# The kernel's device trees for the M2 MacBooks wire the external display
# coprocessor to the front-left USB-C port (see check_dp_altmode.py). Catches
# a rebase of the fairydust patches that builds but leaves the DisplayPort
# setup out, for example by losing "#define ENABLE_DCPEXT_TYPEC".
set -euo pipefail
here=$(dirname "$0")
. "$here/lib.sh"

dnf_install python3-libfdt
extract_kernel fairydust-kernel-16k-core

dtbs=()
for dtb in $DP_ALTMODE_DTBS; do
    dtbs+=("$MODDIR/dtb/apple/$dtb.dtb")
done
python3 "$here/check_dp_altmode.py" "${dtbs[@]}"
