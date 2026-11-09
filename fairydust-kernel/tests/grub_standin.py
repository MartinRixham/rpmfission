#!/usr/bin/python3 -I
"""Stand-ins for grub2-editenv, grub2-mkrelpath and grub2-probe, for
50-swap.sh, by the name it is run as (the test links the three to it).

The real tools look up the block device that holds /boot, which a container's
overlay root file system has not got, and fail. These do what the real ones
do with /boot on an ext4 root file system: grub2-editenv reads and writes the
1024-byte GRUB environment block, in GRUB's format, grub2-mkrelpath returns
the path as it is, and grub2-probe reports ext4.
"""

import os
import sys

HEADER = "# GRUB Environment Block\n"
SIZE = 1024
DEFAULT_ENV = "/boot/grub2/grubenv"


def read_env(path):
    try:
        with open(path) as f:
            data = f.read()
    except FileNotFoundError:
        sys.exit(f"grub2-editenv: error: cannot open `{path}'")
    if not data.startswith(HEADER) or len(data) != SIZE:
        sys.exit(f"grub2-editenv: error: invalid environment block `{path}'")
    env = {}
    for line in data[len(HEADER):].split("\n"):
        if line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env[key] = value
    return env


def write_env(path, env):
    block = HEADER + "".join(f"{k}={v}\n" for k, v in env.items())
    if len(block) > SIZE:
        sys.exit("grub2-editenv: error: environment block too small")
    with open(path, "w") as f:
        f.write(block + "#" * (SIZE - len(block)))


def editenv(args):
    args = [a for a in args if not a.startswith("-") or a == "-"]
    if len(args) == 1:
        # "grub2-editenv list", as 95-set-boot-entry.install runs it
        args = ["-"] + args
    if len(args) < 2:
        sys.exit("usage: grub2-editenv FILENAME COMMAND")
    path = DEFAULT_ENV if args[0] == "-" else args[0]
    command, rest = args[1], args[2:]
    if command == "create":
        write_env(path, {})
    elif command == "list":
        for key, value in read_env(path).items():
            print(f"{key}={value}")
    elif command == "set":
        env = read_env(path)
        for assignment in rest:
            key, value = assignment.split("=", 1)
            env[key] = value
        write_env(path, env)
    elif command == "unset":
        env = read_env(path)
        for key in rest:
            env.pop(key, None)
        write_env(path, env)
    else:
        sys.exit(f"grub2-editenv: error: unknown command `{command}'")


def mkrelpath(args):
    paths = [a for a in args if not a.startswith("-")]
    print(paths[0])


def probe(args):
    print("ext4" if "--target=fs" in args else "/dev/root")


name = os.path.basename(sys.argv[0])
{"grub2-editenv": editenv, "grub2-mkrelpath": mkrelpath, "grub2-probe": probe}[name](sys.argv[1:])
