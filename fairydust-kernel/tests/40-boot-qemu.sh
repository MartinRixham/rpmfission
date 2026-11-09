#!/bin/bash
# The kernel boots: QEMU's generic arm64 machine with an emulated CPU that has
# 16K pages, to a busybox shell in an initramfs, which reports the page size.
# Exercises the kernel as a whole, none of the Apple drivers.
set -euo pipefail
here=$(dirname "$0")
. "$here/lib.sh"

dnf_install qemu-system-aarch64-core busybox cpio gzip python3 zstd
extract_kernel fairydust-kernel-16k-core

python3 "$here/unzboot.py" "$MODDIR/vmlinuz" "$WORKDIR/Image"

initramfs=$WORKDIR/initramfs
mkdir -p "$initramfs"/{bin,proc,dev}
cp "$(command -v busybox)" "$initramfs/bin/busybox"
cat > "$initramfs/init" << 'EOF'
#!/bin/busybox sh
/bin/busybox mount -t proc proc /proc
echo "rpmfission-boot: release $(/bin/busybox uname -r)"
echo "rpmfission-boot: $(/bin/busybox grep -m 1 KernelPageSize /proc/self/smaps)"
/bin/busybox poweroff -f
EOF
chmod +x "$initramfs/init"
(cd "$initramfs" && find . | cpio -o -H newc --quiet | gzip) > "$WORKDIR/initramfs.cpio.gz"

log=$WORKDIR/console.log
rc=0
timeout 1200 qemu-system-aarch64 \
    -machine virt -cpu max,pauth-impdef=on -smp 2 -m 2G \
    -nographic -no-reboot \
    -kernel "$WORKDIR/Image" -initrd "$WORKDIR/initramfs.cpio.gz" \
    -append "console=ttyAMA0 rdinit=/init panic=-1" < /dev/null > "$log" 2>&1 || rc=$?

status=0
if grep -q "rpmfission-boot: release $KVER" "$log"; then
    echo "ok   $KVER boots to userspace"
else
    echo "FAIL: $KVER did not reach userspace (qemu exit $rc)"
    status=1
fi
if grep -qE 'rpmfission-boot: KernelPageSize: +16 kB' "$log"; then
    echo "ok   with 16K pages"
else
    echo "FAIL: no 16K page size reported"
    status=1
fi
if [ "$status" -ne 0 ]; then
    echo "--- last 60 lines of the console"
    tail -n 60 "$log"
fi
exit "$status"
