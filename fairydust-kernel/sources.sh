#!/bin/bash
# Unpack Asahi's sources (the kernel tarball, patch-*-redhat.patch, configs
# and scripts) from the source RPM of their kernel build in the @asahi/kernel
# COPR, which fairydust-kernel.spec is taken from. Every file except Asahi's
# kernel.spec; the fairydust patches are ours, next to the spec. The source
# RPM is not a Source of the spec, so as not to carry it inside ours; its
# checksum is checked here instead of in "sources". Called by .copr/srpm.sh
# in the spec's source directory.
set -euo pipefail

ASAHI_SRPM=https://download.copr.fedorainfracloud.org/results/@asahi/kernel/srpm-builds/11219225/kernel-7.2.12-402.asahi.fc44.src.rpm
ASAHI_SRPM_SHA512=40aabee7619be73db366106fcc4f2b4e93e187c070a16eed0c777974cd9a3deed9c62918e5cf3bf508048a528980e88ca097cc94c78ad75de0eea3316d106957

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

srpm=$work/${ASAHI_SRPM##*/}
attempts=3
for attempt in $(seq "$attempts"); do
    if curl -sfL -o "$srpm" "$ASAHI_SRPM" &&
        echo "$ASAHI_SRPM_SHA512  $srpm" | sha512sum --check --strict --quiet; then
        break
    fi
    if [ "$attempt" -eq "$attempts" ]; then
        echo "$ASAHI_SRPM failed download or verification after $attempts attempts" >&2
        exit 1
    fi
    echo "Download of $ASAHI_SRPM failed (attempt $attempt/$attempts), retrying" >&2
    sleep $((attempt * 10))
done

mkdir "$work/unpacked"
rpm2cpio "$srpm" | (cd "$work/unpacked" && cpio -idm --quiet)
rm "$work/unpacked/kernel.spec" "$srpm"
# The spec's package name is fairydust-kernel, and it takes the config files
# and the changelog by that name (%{name}-*.config, %{name}.changelog)
for file in "$work"/unpacked/kernel-*.config "$work"/unpacked/kernel.changelog; do
    base=${file##*/}
    mv "$file" "$work/unpacked/fairydust-${base}"
done
# Our files (the patches) win over Asahi's of the same name
cp --update=none "$work"/unpacked/* .
