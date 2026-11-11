#!/bin/bash
# The libraries provide every soname and symbol version that Fedora's -free
# libraries of the same release do, so that whatever Fedora builds against
# ffmpeg-free runs with these instead. Shared by ffmpeg8 (a symlink).
set -euo pipefail
. tests/lib.sh

# Fedora's libraries; libpostproc-free only where FFmpeg still has it
fedora_pkgs=(libavcodec-free libavdevice-free libavfilter-free libavformat-free
    libavutil-free libpostproc-free libswresample-free libswscale-free)

# Library provides, such as libavcodec.so.62()(64bit) and
# libavcodec.so.62(LIBAVCODEC_62)(64bit)
libs() { grep -E '^lib[^ ]*\.so\.[0-9]+\(' | sed 's/ .*//' | sort -u; }

fedora=$(dnf repoquery -q --disable-repo='rpmfission-*' --arch="$ARCH" \
    --latest-limit=1 --provides "${fedora_pkgs[@]}" | libs)
ours=$(pkg_rpms | xargs rpm -qp --provides 2> /dev/null | libs)

if [ -z "$fedora" ]; then
    echo "FAIL: no library provides from Fedora's ${fedora_pkgs[*]}"
    exit 1
fi
echo "Fedora's -free libraries provide:"
sed 's/^/  /' <<< "$fedora"

missing=$(comm -23 <(echo "$fedora") <(echo "$ours"))
if [ -n "$missing" ]; then
    echo "FAIL: provided by Fedora's -free libraries but not by these:"
    sed 's/^/  /' <<< "$missing"
    exit 1
fi
