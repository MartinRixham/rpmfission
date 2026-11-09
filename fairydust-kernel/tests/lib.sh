# shellcheck shell=bash
# Helpers for the kernel tests; sourced, not run (see run-tests.sh).

# extract_kernel <subpackage>...
#
# Downloads the 16K kernel's subpackages (default: fairydust-kernel-16k-core) from the
# test repositories and unpacks them into $WORKDIR/root. Sets KVER to the
# kernel release, MODDIR to its modules directory and KROOT to the unpacked
# root.
extract_kernel() {
    local rpm
    [ $# -gt 0 ] || set -- fairydust-kernel-16k-core
    dnf_install cpio
    mkdir -p "$WORKDIR/rpms" "$WORKDIR/root"
    dnf download -q --arch="$ARCH" --destdir "$WORKDIR/rpms" "$@"
    for rpm in "$WORKDIR"/rpms/*.rpm; do
        rpm2cpio "$rpm" | (cd "$WORKDIR/root" && cpio -idm --quiet)
    done
    KROOT=$WORKDIR/root
    # Packaged under /lib/modules or /usr/lib/modules
    MODDIR=$(find "$KROOT" -mindepth 3 -maxdepth 4 -type f -path '*/lib/modules/*/vmlinuz' \
        -printf '%h\n' | head -n 1)
    if [ -z "$MODDIR" ]; then
        echo "no vmlinuz in $*" >&2
        return 1
    fi
    KVER=$(basename "$MODDIR")
    echo "Kernel under test: $KVER"
}

# The Apple Silicon machines whose front-left USB-C port the fairydust patches
# give DisplayPort alt mode: MacBook Air 13" and 15" (M2), MacBook Pro 13" (M2)
# shellcheck disable=SC2034 # used by the tests that source this
DP_ALTMODE_DTBS="t8112-j413 t8112-j415 t8112-j493"

# dnf_install <package>...: installs quietly, showing dnf's output on failure
dnf_install() {
    local out
    out=$(dnf -y install "$@" 2>&1) || { echo "$out" >&2; return 1; }
}
