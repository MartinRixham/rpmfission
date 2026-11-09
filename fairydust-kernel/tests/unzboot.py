#!/usr/bin/python3
"""Unpack an arm64 EFI zboot kernel (vmlinuz.efi) to a raw Image that QEMU's
-kernel boots directly (helper for the boot test). QEMU itself unpacks only
gzip zboot images, and Fedora's are zstd.

    unzboot.py <vmlinuz> <Image>

The zboot header (drivers/firmware/efi/libstub/zboot-header.S): "MZ" at 0,
"zimg" at 4, then the payload's offset and size (little-endian u32) at 8 and
12, and the compression type, NUL padded, at 24.
"""

import struct
import subprocess
import sys


def main():
    src, dst = sys.argv[1:3]
    with open(src, "rb") as f:
        data = f.read()
    if data[0:2] != b"MZ" or data[4:8] != b"zimg":
        sys.exit(f"{src}: not an EFI zboot image")
    offset, size = struct.unpack_from("<II", data, 8)
    comp = data[24:32].rstrip(b"\0").decode()
    payload = data[offset:offset + size]
    tools = {"gzip": ["gzip", "-dc"], "zstd": ["zstd", "-qdc"],
             "xz": ["xz", "-dc"], "lzma": ["xz", "--format=lzma", "-dc"]}
    if comp not in tools:
        sys.exit(f"{src}: unsupported compression {comp!r}")
    image = subprocess.run(tools[comp], input=payload, check=True,
                           stdout=subprocess.PIPE).stdout
    # arm64 Image header: magic "ARM\x64" at 56
    if image[56:60] != b"ARM\x64":
        sys.exit(f"{src}: payload is not an arm64 Image")
    with open(dst, "wb") as f:
        f.write(image)
    print(f"{src}: {comp} zboot, {len(image)} byte Image")


if __name__ == "__main__":
    main()
