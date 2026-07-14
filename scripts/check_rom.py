#!/usr/bin/env python3
"""Validate the generated mapper-0 iNES cartridge."""

import sys


rom_path, chr_path = sys.argv[1:]
rom = open(rom_path, "rb").read()
chr_data = open(chr_path, "rb").read()

assert len(rom) == 16 + 32768 + 8192, f"unexpected ROM size: {len(rom)}"
assert rom[:8] == b"NES\x1a\x02\x01\x00\x00", "invalid mapper-0 iNES header"
assert rom[-8192:] == chr_data, "embedded CHR bank differs from generated assets"

vectors = rom[16 + 32768 - 6:16 + 32768]
nmi = int.from_bytes(vectors[0:2], "little")
reset = int.from_bytes(vectors[2:4], "little")
irq = int.from_bytes(vectors[4:6], "little")
assert all(0x8000 <= vector <= 0xFFFF for vector in (nmi, reset, irq))
print(f"valid NROM-256: NMI=${nmi:04X} RESET=${reset:04X} IRQ=${irq:04X}")
