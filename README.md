# Sol Snake

A small Snake game for the Nintendo Entertainment System, written in 6502
assembly. It uses the mapper-free NROM cartridge format and generated CHR-ROM
graphics, so the source has no external asset dependencies.

The playfield is 30 by 18 cells. Board cells are packed two per byte using
4-bit values, while the snake coordinate ring buffers use 16-bit indices.
The snake uses distinct head and tail-tip tiles that rotate with its direction;
intermediate segments are rendered as body tiles.

The soundtrack uses pulse 2 for melody. Pulse 1 and the noise channel remain
available for food and game-over sound effects; the triangle channel is
disabled. Title and gameplay themes loop independently, pause with the game,
and stop on game over.

## Build

Install the Debian packages and build the ROM:

```sh
sudo apt install cc65 python3 make
make
```

The resulting ROM is `build/sol-snake.nes`. Run `make clean` to remove all
generated files. Run `make check` to verify the iNES header, cartridge size,
vectors, and embedded graphics bank.

## Controls

- D-pad: move
- Start: begin, pause, resume, or restart after game over

The game targets NTSC NES hardware and mapper 0. Open the ROM in Mesen,
FCEUX, Nestopia, or another NES-compatible emulator on your local computer.
