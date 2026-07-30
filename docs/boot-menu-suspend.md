# Boot, menu, and suspend behavior

This document records the intended NesTV user experience and the architectural
requirements it creates. It is a product target for the NES-only console, not a
claim that the pinned TangCore firmware already implements these features.

## Product behavior

NesTV should behave like a console with a cartridge left installed, rather than
like a computer that opens a file browser on every boot.

- The console remembers the last successfully launched game.
- A cold start normally loads the NES core and launches that game directly.
- A missing, changed, or invalid ROM falls back safely to the game menu.
- The full library remains available without requiring a special controller.
- HDMI and analog video present the same menu and game content.
- An encoder and OLED are not part of the baseline design. They may remain an
  optional future front-panel feature, but controller operation must be
  sufficient from normal viewing distance.

The normal NES configuration should contain both the NES core and its overlay
menu. Selecting another game should load a ROM without first loading a separate
monitor bitstream or reconfiguring the FPGA. A protected monitor/recovery image
may still be used when the normal core or storage cannot boot.

## Controller and front-panel controls

Original NES controllers have no system button, so NesTV reserves a deliberate
gesture outside ordinary gameplay:

- Hold `Select + Start` for approximately two seconds to open the system menu.
- Once the gesture is recognized, those button events are consumed rather than
  delivered to the emulated console.
- While the menu is visible, controller input belongs exclusively to the menu
  and the NES is paused.
- `B` closes the menu and resumes the current game without reloading it.

The front panel provides a guaranteed fallback:

- A short Reset press resets the emulated NES.
- A long Reset press opens the system menu.
- The Power button enters or leaves the console's apparent-off state.

Exact hold times and behavior when a game is already paused remain usability
parameters, not file-format or hardware-interface commitments.

## Persistent selection

The BL616 stores a small, versioned boot record containing at least:

- the identity and path of the last successfully launched ROM;
- a ROM hash or other identity check;
- the last library directory and cursor position;
- boot-policy and settings fields;
- a checksum or CRC.

The record is updated only after a ROM launches successfully, not on every
cursor movement. It must be written atomically so interrupted writes cannot
prevent recovery. A corrupt record must fall back to the menu.

## Suspend and power behavior

The final carrier should use soft power under BL616 control. With external power
connected, the front-panel Power button may make the product appear off while a
small always-on domain continues monitoring controls.

The desired normal path is warm suspend:

1. pause the NES at a controlled boundary;
2. gate emulation clocks;
3. retain the configured FPGA and any memory required for the running machine;
4. disable HDMI and analog video output;
5. place the BL616 and peripherals into their lowest practical states;
6. restore clocks and video when Power is pressed.

Warm suspend resumes the exact running machine quickly, but it is not a
persistent save state: unplugging the console or losing standby power loses the
session.

The carrier should also support cold standby by switching off the FPGA, SDRAM,
video DAC, and other nonessential rails. On the next start, the BL616 loads the
normal NES image and launches the remembered game from reset. Cold standby is
the fallback if measured warm-suspend power, FPGA rail requirements, or SDRAM
retention make warm suspend unsuitable.

The development board may only approximate these modes by freezing clocks and
blanking video. Final decisions about the default standby mode require measured
power and wake-time results on the carrier hardware.

## Video-off requirements

Apparent-off mode must not leave a visible raster or audible output:

- analog sync and DAC outputs are disabled or driven to a defined blank state;
- HDMI is disabled so the television treats NesTV as inactive;
- audio output is muted before clocks or rails change;
- wake-up sequencing prevents flashes, pops, or malformed sync.

Television HDMI acquisition time is separate from FPGA wake time and must be
measured as part of user-visible startup validation.

## Persistent save states: stretch goal

Persistent save states are explicitly outside the baseline boot/menu/suspend
implementation. They require serializing and restoring CPU, PPU, APU, DMA,
memory, clock, and mapper state; the current NESTang integration has no general
state interface.

The architecture should avoid blocking later implementation:

- reserve a versioned bulk state-transfer command family between FPGA and
  BL616;
- provide a way to freeze the core at a defined boundary;
- include ROM identity, mapper identity, core version, state-format version,
  and a checksum in any future state file;
- design automated save/run/restore simulation tests;
- enable persistent states mapper by mapper rather than claiming unsupported
  compatibility.

Warm suspend is a baseline product goal. Surviving removal of external power and
manual save slots are stretch goals.
