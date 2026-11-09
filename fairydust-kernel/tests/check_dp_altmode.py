#!/usr/bin/python3
"""Check that a device tree enables DisplayPort alt mode the way the
fairydust patches do (helper for the kernel and m1n1 tests).

    check_dp_altmode.py <file.dtb>...

For each device tree, checks that
  - the dcpext alias names the external display coprocessor, which is
    enabled with a DP connector, its DP PHY and its crossbar mux,
  - a USB-C connector points at it with a "displayport" property, for the
    tipd driver's hotplug events,
  - a DP audio controller is enabled,
  - the sio node (DMA for DP audio) is enabled,
  - the atc1_common power domain is always on, for suspend and resume.

Prints each failed check and exits 1 if any failed.
"""

import sys

import libfdt


def string(fdt, node, name):
    prop = fdt.getprop(node, name, quiet=(libfdt.NOTFOUND,))
    if isinstance(prop, int):
        return None
    return prop.as_str()


def strings(fdt, node, name):
    prop = fdt.getprop(node, name, quiet=(libfdt.NOTFOUND,))
    if isinstance(prop, int):
        return []
    return [s.decode() for s in bytes(prop).split(b"\0") if s]


def has(fdt, node, name):
    return not isinstance(fdt.getprop(node, name, quiet=(libfdt.NOTFOUND,)), int)


def nodes(fdt):
    """Every node offset, depth first."""
    node = 0
    depth = 0
    while True:
        yield node
        try:
            node, depth = fdt.next_node(node, depth)
        except libfdt.FdtException as e:
            if e.err == -libfdt.NOTFOUND:
                return
            raise
        if depth < 0:
            return


def okay(fdt, node):
    return string(fdt, node, "status") in (None, "okay", "ok")


def check(path):
    with open(path, "rb") as f:
        fdt = libfdt.Fdt(f.read())
    failures = []

    aliases = fdt.path_offset("/aliases", quiet=(libfdt.NOTFOUND,))
    dcpext_path = string(fdt, aliases, "dcpext") if aliases >= 0 else None
    if dcpext_path is None:
        failures.append("no dcpext alias")
        dcpext = -1
    else:
        dcpext = fdt.path_offset(dcpext_path)
        if "apple,dcpext" not in strings(fdt, dcpext, "compatible"):
            failures.append(f"dcpext alias {dcpext_path} is not an apple,dcpext")
        if not okay(fdt, dcpext):
            failures.append(f"{dcpext_path} is not enabled")
        if string(fdt, dcpext, "apple,connector-type") != "DP":
            failures.append(f"{dcpext_path} has no DP connector type")
        for prop in ("phys", "mux-controls", "apple,dptx-phy"):
            if not has(fdt, dcpext, prop):
                failures.append(f"{dcpext_path} has no {prop}")

    connectors = []
    dpaudio_enabled = False
    atc1_always_on = None
    for node in nodes(fdt):
        compatible = strings(fdt, node, "compatible")
        if "usb-c-connector" in compatible and has(fdt, node, "displayport"):
            connectors.append(node)
        if "apple,dpaudio" in compatible and okay(fdt, node):
            dpaudio_enabled = True
        if ("apple,pmgr-pwrstate" in compatible
                and string(fdt, node, "label") == "atc1_common"):
            atc1_always_on = has(fdt, node, "apple,always-on")

    if dcpext >= 0:
        phandle = fdt.get_phandle(dcpext)
        if not any(fdt.getprop(c, "displayport").as_uint32() == phandle
                   for c in connectors):
            failures.append("no USB-C connector has displayport = <&dcpext>")
    if not dpaudio_enabled:
        failures.append("no DP audio controller is enabled")

    sio_path = string(fdt, aliases, "sio") if aliases >= 0 else None
    if sio_path is None:
        failures.append("no sio alias")
    elif not okay(fdt, fdt.path_offset(sio_path)):
        failures.append(f"{sio_path} is not enabled")

    if atc1_always_on is None:
        failures.append("no atc1_common power domain")
    elif not atc1_always_on:
        failures.append("atc1_common power domain is not always on")

    return failures


def main():
    status = 0
    for path in sys.argv[1:]:
        failures = check(path)
        if failures:
            status = 1
            for failure in failures:
                print(f"FAIL {path}: {failure}")
        else:
            print(f"ok   {path}")
    return status


if __name__ == "__main__":
    sys.exit(main())
