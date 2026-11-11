#!/bin/bash
# "dnf swap ffmpeg-free ffmpeg --allowerasing", as the README has users do,
# replaces Fedora's ffmpeg-free and its -free libraries and nothing else, and
# leaves Fedora's applications that link FFmpeg working, with the codecs
# Fedora's build leaves out. GStreamer's libav plugin stands in for those
# applications. Shared by ffmpeg8 (a symlink).
set -euo pipefail
. tests/lib.sh

status=0
fail() {
    echo "FAIL: $*"
    status=1
}

echo "== Installing Fedora's ffmpeg-free and gstreamer1-plugin-libav"
dnf_checked install --disable-repo='rpmfission-*' \
    ffmpeg-free gstreamer1-plugin-libav gstreamer1 gstreamer1-plugins-good > /dev/null

before=$(rpm -qa --qf '%{name}\n' | sort -u)
echo "== dnf swap ffmpeg-free ffmpeg --allowerasing"
dnf_checked swap --allowerasing ffmpeg-free ffmpeg || fail "dnf swap failed"
after=$(rpm -qa --qf '%{name}\n' | sort -u)

removed=$(comm -23 <(echo "$before") <(echo "$after"))
echo "Removed: $(echo $removed)"
unexpected=$(grep -vE '^(ffmpeg-free|lib(av|sw|postproc)[a-z]*-free)$' <<< "$removed" || true)
[ -z "$unexpected" ] || fail "the swap removed more than ffmpeg-free: $(echo $unexpected)"

# This run's build, not the published one
for rpm in $(pkg_rpms); do
    name=$(rpm -qp --qf '%{name}' "$rpm" 2> /dev/null)
    nevra=$(rpm -qp --qf '%{nevra}' "$rpm" 2> /dev/null)
    if rpm -q "$name" > /dev/null && ! rpm -q "$nevra" > /dev/null; then
        fail "$name is $(rpm -q "$name"), not $nevra"
    fi
done
for name in ffmpeg ffmpeg-libs; do
    rpm -q "$name" > /dev/null || fail "$name is not installed"
done

# Fedora's plugin links these libraries, from this build
rpm -q gstreamer1-plugin-libav > /dev/null || fail "gstreamer1-plugin-libav was removed"
plugin=$(rpm -ql gstreamer1-plugin-libav | grep -m1 '/libgstlibav\.so$')
ldd_out=$(ldd "$plugin")
if grep -q 'not found' <<< "$ldd_out"; then
    fail "$plugin has unresolved libraries:"$'\n'"$(grep 'not found' <<< "$ldd_out")"
fi
for lib in $(awk '/libav(codec|format|util)\.so/ { print $3 }' <<< "$ldd_out"); do
    owner=$(rpm -qf --qf '%{name}' "$lib")
    [ "$owner" = ffmpeg-libs ] || fail "$plugin links $lib from $owner, not ffmpeg-libs"
done

# H.264 and H.265, which Fedora's build leaves out: encoded with x264 and
# x265 by this ffmpeg, decoded by Fedora's plugin through this libavcodec
for codec in h264 h265; do
    encoder=libx${codec#h}
    file=$WORKDIR/$codec.mp4
    if ! quiet ffmpeg -nostdin -hide_banner -f lavfi -i testsrc=size=128x96:rate=10:duration=1 \
        -c:v "$encoder" -pix_fmt yuv420p "$file"; then
        fail "ffmpeg does not encode with $encoder"
        continue
    fi
    if ! quiet gst-launch-1.0 -q filesrc location="$file" ! qtdemux ! "avdec_$codec" ! fakesink; then
        fail "Fedora's gstreamer1-plugin-libav does not decode $codec with this libavcodec"
    fi
done

exit "$status"
