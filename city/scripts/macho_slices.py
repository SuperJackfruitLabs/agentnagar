#!/usr/bin/env python3
"""Prints each architecture in a Mach-O file and whether it carries a code
signature, e.g. "x86_64:signed arm64:signed". smoke_package.sh uses it off
a Mac, where lipo and codesign are not available."""
import struct
import sys

LC_CODE_SIGNATURE = 0x1D
CPU = {0x01000007: "x86_64", 0x0100000C: "arm64"}


def slice_info(data, offset):
    magic = struct.unpack_from("<I", data, offset)[0]
    if magic != 0xFEEDFACF:
        raise SystemExit("not a 64-bit Mach-O slice at offset %d" % offset)
    cputype, _, _, ncmds, _, _, _ = struct.unpack_from("<IIIIIII", data, offset + 4)
    at = offset + 32
    signed = False
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", data, at)
        signed = signed or cmd == LC_CODE_SIGNATURE
        at += size
    return CPU.get(cputype, hex(cputype)), signed


def main(path):
    with open(path, "rb") as f:
        data = f.read()
    magic = struct.unpack_from(">I", data, 0)[0]
    if magic in (0xCAFEBABE, 0xCAFEBABF):
        count = struct.unpack_from(">I", data, 4)[0]
        slices = []
        for i in range(count):
            if magic == 0xCAFEBABE:
                offset = struct.unpack_from(">IIIII", data, 8 + i * 20)[2]
            else:
                offset = struct.unpack_from(">IIQQII", data, 8 + i * 32)[2]
            slices.append(slice_info(data, offset))
    else:
        slices = [slice_info(data, 0)]
    print(" ".join("%s:%s" % (arch, "signed" if s else "unsigned") for arch, s in slices))


if __name__ == "__main__":
    main(sys.argv[1])
