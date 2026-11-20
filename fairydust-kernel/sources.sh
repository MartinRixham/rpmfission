#!/bin/bash
# Unpack Asahi's sources (the kernel tarball, patch-*-redhat.patch, configs
# and scripts) from the source RPM of their kernel build in the @asahi/kernel
# COPR, which fairydust-kernel.spec is taken from. Every file except Asahi's
# kernel.spec; the fairydust patches are ours, next to the spec. The source
# RPM is not a Source of the spec, so as not to carry it inside ours; its
# checksum is checked here instead of in "sources". Called by .copr/srpm.sh
# in the spec's source directory.
set -euo pipefail

ASAHI_SRPM=https://download.copr.fedorainfracloud.org/results/@asahi/kernel/fedora-44-aarch64/Packages/k/kernel-7.3.4-401.asahi.fc44.src.rpm
ASAHI_SRPM_SHA512=318fd65aff92ed00e8bfd5a8baec9489b8fb124ba5c7c8edacc90a17954b64b926fca8b6f5220652dc5bc27bf10493cf75d0e2bce3fcca01ed66f37586f9d37c

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
