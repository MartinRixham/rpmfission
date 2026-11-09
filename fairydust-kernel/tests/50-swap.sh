#!/bin/bash
# Installing fairydust-kernel swaps Asahi's 16K kernel for the fairydust one,
# and removing it swaps back. The swap is the default boot entry, /boot/dtb
# and the device trees in m1n1 stage 2 (boot.bin). Runs real dnf transactions
# with Asahi's kernel-16k from the @asahi/kernel COPR, set up as on Fedora
# Asahi Remix, and the real kernel-install plugins, dracut, grubby and
# update-m1n1, in this container. Only the GRUB tools that need /boot on a
# block device are stand-ins (grub_standin.py). In order:
#
#   1. Asahi's kernel alone is the default (kernel-install makes a new kernel
#      the default, which is what fairydust-kernel has to undo).
#   2. Installing fairydust-kernel makes the fairydust kernel the default.
#   3. Asahi's kernel added again (kernel-install add by hand, which takes
#      the default as an update of Asahi's kernel does) and then reinstalled
#      with dnf: after the transaction the fairydust kernel is the default.
#   4. Removing fairydust-kernel makes Asahi's the default and removes the
#      fairydust kernel.
#   5. Installing fairydust-kernel again swaps again.
#   6. An upgrade of fairydust-kernel (to a copy without scriptlets, so that
#      nothing but the old package's %preun can change the default) is not a
#      removal: the fairydust kernel stays the default.
#
# What a container cannot show: that GRUB and m1n1 boot what is set here, and
# whether dnf keeps a running fairydust kernel on removal.
set -euo pipefail
here=$(dirname "$0")
. "$here/lib.sh"

status=0
fail() {
    echo "FAIL: $*"
    status=1
}

# Fedora Asahi Remix's boot setup: GRUB with BLS entries and a saved default,
# new 16K kernels made the default, and update-m1n1 for m1n1 stage 2, which
# here writes to a file instead of the EFI system partition
copr=https://download.copr.fedorainfracloud.org/results/@asahi/kernel/fedora-$RELEASE-$ARCH/
cat > /etc/yum.repos.d/asahi-kernel.repo <<EOF
[asahi-kernel]
name=Asahi kernel COPR
baseurl=$copr
gpgcheck=0
EOF
dnf_install grubby grub2-tools-minimal dracut systemd-udev m1n1 update-m1n1 \
    uboot-images-armv8 rpm-build python3
# The real grub2-editenv, grub2-mkrelpath and grub2-probe need /boot on a
# block device, which the container's root file system is not
install -D -m 0755 "$here/grub_standin.py" /usr/local/libexec/grub_standin.py
for tool in grub2-editenv grub2-mkrelpath grub2-probe; do
    ln -sf /usr/local/libexec/grub_standin.py "/usr/bin/$tool"
done
systemd-machine-id-setup > /dev/null
cat > /etc/default/grub <<'EOF'
GRUB_DEFAULT=saved
GRUB_ENABLE_BLSCFG=true
EOF
cat > /etc/sysconfig/kernel <<'EOF'
UPDATEDEFAULT=yes
DEFAULTKERNEL=kernel-16k-core
EOF
mkdir -p /boot/grub2 /boot/loader/entries
grub2-editenv /boot/grub2/grubenv create
bootbin=$WORKDIR/boot.bin
echo "TARGET=$bootbin" >> /etc/sysconfig/update-m1n1

dnf_install --from-repo=asahi-kernel kernel-16k
asahi=$(rpm -q --qf '%{version}-%{release}.%{arch}+16k\n' kernel-16k-core | sort -V | tail -n 1)
echo "Asahi's kernel: $asahi"

# The M2 MacBook Air 13", whose device tree the fairydust patches change
model=t8112-j413

# expect <kver> <step>: the default boot entry, /boot/dtb and the device trees
# in boot.bin are those of <kver>
expect() {
    local kver=$1 step=$2 default dtb
    default=$(grubby --default-kernel 2> /dev/null || true)
    if [ "$default" = "/boot/vmlinuz-$kver" ]; then
        echo "ok   $step: the default boot entry is $kver"
    else
        fail "$step: the default boot entry is '$default', not $kver"
    fi
    dtb=$(readlink /boot/dtb || true)
    if [ "$dtb" = "dtb-$kver" ]; then
        echo "ok   $step: /boot/dtb is dtb-$kver"
    else
        fail "$step: /boot/dtb is '$dtb', not dtb-$kver"
    fi
    if python3 -I -c '
import sys
boot_bin, dtb = (open(path, "rb").read() for path in sys.argv[1:])
sys.exit(dtb not in boot_bin)
' "$bootbin" "/boot/dtb-$kver/apple/$model.dtb"; then
        echo "ok   $step: boot.bin has the $model device tree of $kver"
    else
        fail "$step: boot.bin does not have the $model device tree of $kver"
    fi
}

expect "$asahi" "Asahi's kernel alone"

dnf_install fairydust-kernel
fairydust=$(rpm -q --qf '%{version}-%{release}.%{arch}+16k\n' fairydust-kernel-16k-core)
echo "Fairydust kernel: $fairydust"
if cmp -s "/boot/dtb-$asahi/apple/$model.dtb" "/boot/dtb-$fairydust/apple/$model.dtb"; then
    fail "the $model device trees of $asahi and $fairydust are the same, so this test cannot tell them apart"
fi
expect "$fairydust" "fairydust-kernel installed"

kernel-install add "$asahi" "/lib/modules/$asahi/vmlinuz"
if [ "$(grubby --default-kernel 2> /dev/null)" = "/boot/vmlinuz-$asahi" ]; then
    echo "ok   kernel-install add of Asahi's kernel makes it the default"
else
    fail "kernel-install add of Asahi's kernel does not make it the default, so this test does not show the swap surviving it"
fi
out=$(dnf -y reinstall --from-repo=asahi-kernel kernel-16k-core 2>&1) || { echo "$out"; fail "reinstall of Asahi's kernel"; }
expect "$fairydust" "Asahi's kernel reinstalled"

out=$(dnf -y remove fairydust-kernel 2>&1) || { echo "$out"; fail "dnf remove fairydust-kernel"; }
expect "$asahi" "fairydust-kernel removed"
if rpm -q fairydust-kernel-16k-core > /dev/null; then
    fail "fairydust-kernel-16k-core is still installed after removing fairydust-kernel"
else
    echo "ok   removing fairydust-kernel removes the fairydust kernel"
fi

dnf_install fairydust-kernel
expect "$fairydust" "fairydust-kernel installed again"

# The upgrade: the same package with a higher release and no scriptlets
cat > "$WORKDIR/upgrade.spec" <<EOF
Name: fairydust-kernel
Version: $(rpm -q --qf '%{version}' fairydust-kernel)
Release: $(rpm -q --qf '%{release}' fairydust-kernel).1
Summary: Upgrade of fairydust-kernel without scriptlets, for the test
License: MIT
Requires: fairydust-kernel-16k
%description
%{summary}.
%files
EOF
out=$(rpmbuild -bb --define "_topdir $WORKDIR/rpmbuild" "$WORKDIR/upgrade.spec" 2>&1) || { echo "$out"; exit 1; }
out=$(dnf -y install "$WORKDIR"/rpmbuild/RPMS/*/fairydust-kernel-*.rpm 2>&1) || { echo "$out"; fail "upgrade of fairydust-kernel"; }
expect "$fairydust" "fairydust-kernel upgraded"

exit "$status"
