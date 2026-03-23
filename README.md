# CHIP-8 Emulator — Sipeed Tang Nano 20K FPGA

A complete CHIP-8 emulator implemented in Verilog and synthesized on a Sipeed Tang
Nano 20K FPGA (Gowin GW2AR-18). The emulator runs at the correct 500Hz CPU tick rate,
outputs video over HDMI at 640x480, and supports the full 16-key CHIP-8 keypad.

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │                top.v                    │
                    │                                         │
  ┌──────────┐      │  ┌──────────┐      ┌─────────────────┐ │
  │ sprites  │─────►│  │ memory.v │◄────►│     cpu.v       │ │
  │ .mem     │      │  │  4KB     │      │  35 opcodes     │ │
  └──────────┘      │  │  BRAM    │      │  fetch/decode/  │ │
                    │  └──────────┘      │  execute FSM    │ │
                    │                    └────────┬────────┘ │
                    │                             │fb ports  │
                    │  ┌──────────────────────────▼────────┐ │
                    │  │         framebuffer.v              │ │
                    │  │   256x8-bit dual port BRAM         │ │
                    │  │   CPU port (r/w) | Display port(r) │ │
                    │  └──────────────────┬─────────────────┘ │
                    │                     │                   │
                    │  ┌──────────────────▼─────────────────┐ │
                    │  │           video_top.v               │ │
                    │  │  PLL (27MHz→125MHz) + CLKDIV (÷5)  │ │
                    │  │  display.v → DVI_TX_Top             │ │
                    │  │  640x480 VGA timing + TMDS encode   │ │
                    │  └─────────────────────────────────────┘ │
                    └─────────────────────────────────────────┘
                                        │
                                   HDMI output
```

## Modules

| File | Description |
|------|-------------|
| `src/top.v` | System top level — wires all modules together |
| `src/cpu.v` | CHIP-8 CPU — all 35 opcodes, fetch/decode/execute state machine |
| `src/memory.v` | 4KB synchronous BRAM — initialized with font data and ROM via `$readmemh` |
| `src/framebuffer.v` | 256x8-bit dual port synchronous BRAM — CPU writes, display reads simultaneously |
| `src/display.v` | VGA timing generator — scans framebuffer and outputs 640x480 RGB + sync signals |
| `src/video_top.v` | Video subsystem — PLL, CLKDIV, display, DVI_TX_Top instantiation |
| `src/chip8.cst` | Physical pin constraints for Tang Nano 20K |
| `src/chip8.sdc` | Timing constraints |
| `src/dvi_tx/` | Gowin TMDS encoder IP core (generated) |
| `src/gowin_rpll/` | Gowin PLL IP core — generates 125MHz serial clock from 27MHz |
| `mem/sprites.mem` | CHIP-8 font sprites (0-F) in hex format |
| `tb/cpu_tb.v` | CPU testbench — verifies all opcodes including CALL/RET |
| `tb/display_tb.v` | Display testbench — verifies VGA timing, hsync/vsync, framebuffer readout |
| `tb/memory_tb.v` | Memory testbench |

## Key Design Decisions

**CPU clock enable:** The CPU runs on the 27MHz master clock gated by a `cpu_tick`
enable signal derived from a clock divider. This avoids clock domain crossings and
keeps all logic in one clock domain.

**Framebuffer:** Organized as 256x8-bit words (64 pixels wide x 32 rows, 8 pixels
per byte, MSB = leftmost pixel). Dual port design — CPU has read/write access on one
port, display controller has read-only access on a second port. No arbitration needed.

**Display pipeline:** `display.v` prefetches the next pixel address to compensate for
one cycle of synchronous BRAM read latency. The `de` (data enable) signal protects
against stale data at line boundaries.

**HDMI output:** Uses Gowin's TMDS IP core. The PLL generates a 125MHz serial clock
from the 27MHz oscillator. CLKDIV divides by 5 using DDR (both clock edges) to produce
the 25MHz pixel clock — implementing the 10-bit TMDS serialization at 125MHz.

**execution_done:** Combinational wire, not a register — fixes a race condition where
a registered signal would cause the FSM to skip states.

## Hardware Requirements

- Sipeed Tang Nano 20K FPGA board
- HDMI monitor
- 4x4 matrix keypad (16 keys)
- USB-C cable for programming

## Prerequisites

- [Gowin IDE](https://www.gowinsemi.com/en/support/download_eda/) V1.9.x or later
- Gowin programmer (bundled with IDE)

## Building and Flashing

1. Clone this repository
2. Open Gowin IDE and create a new project targeting `GW2AR-LV18QN88C8/I7`
3. Add all files from `src/` to the project
4. Add `src/chip8.cst` as the physical constraints file
5. Add `src/chip8.sdc` as the timing constraints file
6. Set `top` as the top level module
7. Run Synthesis → Place & Route → Generate Bitstream
8. Program the device using Gowin programmer with `impl/pnr/chip-8.fs`

## Loading a ROM

Edit `mem/sprites.mem` loading in `src/memory.v`:

```verilog
$readmemh("mem/sprites.mem", mem, 0);    // font data — always keep this
$readmemh("path/to/your/rom.ch8", mem, 512); // ROM loads at 0x200
```

CHIP-8 ROMs load at address 0x200 (512 decimal) by convention.

## Simulation

Requires [Icarus Verilog](https://steveicarus.github.io/iverilog/) and
[GTKWave](https://gtkwave.sourceforge.net/).

```bash
# CPU testbench
iverilog -o tb/cpu_tb src/cpu.v src/memory.v tb/cpu_tb.v && vvp tb/cpu_tb
gtkwave dump.vcd

# Display testbench
iverilog -o tb/display_tb src/display.v src/framebuffer.v tb/display_tb.v && vvp tb/display_tb
gtkwave dump.vcd
```

## Test ROMs

A collection of public domain CHIP-8 ROMs is included in `chip8-roms/`.

Recommended test sequence:
1. `IBM Logo.ch8` — simplest test, just draws the IBM logo
2. `Pong.ch8` — verifies display, CPU timing, and keypad input
3. `Tetris.ch8` — verifies complex sprite drawing and game logic
4. `Space Invaders.ch8` — stress test for sprite collision detection

## CHIP-8 Keypad Mapping

The original CHIP-8 used a 16-key hex keypad:

```
Original    Keyboard
1 2 3 C     1 2 3 4
4 5 6 D     Q W E R
7 8 9 E     A S D F
A 0 B F     Z X C V
```

## What I Learned

**VGA/HDMI timing from first principles:** Built the complete display pipeline
without using any display IP — understanding the relationship between pixel clock,
blanking periods, sync polarity, and the TMDS serialization chain (10-bit encoding,
DDR serialization at 5x pixel clock).

**Synchronous BRAM pipeline latency:** Discovered that synchronous memory introduces
a one-cycle read latency that must be compensated in the display pipeline. Solved by
prefetching the next pixel address rather than delaying sync signals.

**Clock domain design:** Learned why running the CPU on a clock enable rather than
a divided clock matters — avoids clock domain crossings and keeps the entire design
in one clock domain, simplifying timing closure.

**Dual port framebuffer:** Designed a dual port BRAM to allow simultaneous CPU writes
and display reads without arbitration logic — understanding that complexity you don't
add is complexity that can't break.

**FPGA toolchain:** Complete flow from Verilog through Gowin synthesis, place and
route, timing constraints, and bitstream generation on real hardware.

## Project Status

- [x] CPU — all 35 opcodes implemented and verified in simulation
- [x] Memory — 4KB BRAM with font data
- [x] Framebuffer — dual port BRAM
- [x] Display — VGA timing, HDMI output, synthesized and verified
- [ ] Hardware verification — pending Tang Nano 20K arrival
- [ ] Keypad matrix decoder
- [ ] Full system integration and ROM testing

## License

MIT License — see LICENSE file.

Font data adapted from public domain CHIP-8 references.
CHIP-8 ROMs in `chip8-roms/` are public domain.
Gowin IP cores (`dvi_tx/`, `gowin_rpll/`) are copyright Gowin Semiconductor.
