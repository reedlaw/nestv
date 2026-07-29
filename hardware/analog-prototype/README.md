# Analog prototype

This directory defines the M4 development-board fixture. It is an engineering
prototype, not a production-ready video circuit.

## Digital interface

The FPGA presents two unsigned six-bit buses at 3.3 V:

- `video_y`: code 0 is sync tip, 19 is blank/black, and 63 is peak white;
- `video_c`: code 32 is zero chroma and is intended to be AC-coupled.

Holding Primer button S1 selects eight native-raster color bars and disables
the menu overlay. Releasing S1 returns to NES video. This permits analog
bring-up without relying on a loaded game.

The twelve outputs do not fit on one free PMOD while SDRAM and HDMI are
installed. See `pin-map.csv`. Use short ground-paired wires from the controller
PMOD, USB pads, and LED pads to the analog fixture. Do not connect USB equipment
or controller accessories while the M4 bitstream is installed.

## Prototype signal chain

Build two identical six-bit R-2R ladders using 1.00 kΩ and 2.00 kΩ, 0.1%
resistors or matched arrays:

```text
video_y[5:0] -> R-2R DAC -> Y gain/level buffer -> Y low-pass -> S-Video Y
video_c[5:0] -> R-2R DAC -> AC coupling -> C gain buffer -> S-Video C
                                              |
filtered Y + filtered C -> active summer -> 75 Ω source -> composite RCA
```

The first assembly should expose raw and filtered Y/C test points and use
socketed or easily replaced gain/filter parts. Select a video-capable,
single-supply amplifier only after checking that it is stable at the intended
gain, can swing the required level into the effective 150 Ω source-plus-load
network, and has adequate output current.

The active stage must be powered from a clean regulated rail with local
100 nF and bulk decoupling. FPGA and analog grounds must be common, with each
DAC bus accompanied by nearby ground returns. Never connect an unbuffered
FPGA resistor ladder directly to a television input.

## Required evidence

M4 is complete only after the fixture is assembled and the measurements in
`bringup.md` are recorded. Simulation and successful FPGA fitting do not
substitute for those measurements.
