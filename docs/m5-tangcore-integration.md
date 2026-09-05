# M5 — TangCore integration boundary

> Historical bring-up analysis. For the current matched upstream source build,
> see [TangCore source integration](tangcore-source-build.md). M5.0 ROM/controller
> operation is verified; source-package hardware testing is the next step.


Written 2026-08-12, at the start of M5. Records what TangCore actually is,
what the existing Primer 25K RTL already provides, and what is genuinely
missing. Sources are the pinned TangCore checkout at `firmware/tangcore`,
its `firmware-bl616` submodule, and the published release artifacts —
all read directly, not inferred from summaries.

## Summary

The integration boundary is much smaller than assumed. `rtl/core/nestang`
already **is** TangCore's NES core, and the M3 bitstream already contains
TangCore's FPGA-side interface. The real gaps are (1) BL616 application
firmware has never been flashed, (2) the board has no free pins for a
gamepad, and (3) Primer 25K support exists only in TangCore release v0.7.

## What was assumed, and what is actually true

The plan going into M5 was that the current top level uses "NESTang's legacy
UART-based `iosys_bl616` protocol" and that TangCore "works differently
(BL616 loads FPGA SRAM via JTAG itself)". Half of that is right, and the
half that is wrong is the half that would have caused work.

**`iosys_bl616` is TangCore's interface, not the legacy one.** The legacy IO
system is `iosys_picorv32.v` — a RISC-V softcore inside the FPGA that fetches
`firmware.bin` from SPI flash. That is the path the 2026-08-12 session chased
to `0x500000` and abandoned. `iosys_bl616.v` is its replacement: its header
reads *"BL616-based IO system … Author: nand2mario, 2/2025"* and its config
string is literally `"Tangcores;-;…"`. TangCore's own
`docs/dev-guide/core-development.md` lists `src/iosys/iosys_bl616.v` as a
required part of any TangCore core.

**JTAG and UART are both used, for different things.** BL616 bit-bangs JTAG
to load the *bitstream* into FPGA SRAM (`firmware-bl616/fpga/programmer.cpp`,
which knows `IDCODE_GW5A_25 = 0x0001281b`). Everything after that — ROM data,
OSD text, joypad state — runs over a 2 Mbps UART to `iosys_bl616`. The JTAG
mechanism replaces NOR-flash core switching, not the UART protocol.

**Our NESTang pin already is TangCore's NES core.** TangCore `f69c6ff` pins
`nestang` at `c2450818`; `THIRD_PARTY.md` pins `5b24a710`. `5b24a710` is a
descendant, two commits later, and `git diff c2450818 5b24a710` touches only
`CHANGES.md`. The RTL is byte-identical.

**The M3 bitstream is already a TangCore core.** `scripts/gowin/primer25k_m3.tcl`
compiles `iosys_bl616.v` (which is where `` `define MCU_BL616 `` comes from)
ahead of `nestang_top.sv`, so the unconditional `iosys_bl616` instance with
`CORE_ID(1)` is live. The "NESTang boot screen" already confirmed over HDMI
during M3 bring-up *is* that instance's overlay, sitting idle waiting for a
BL616 that has never spoken to it.

So nothing in the existing top level needs to be unwound. There is no legacy
path left to extend.

## The interface, concretely

| Channel | Direction | Carries | Pins |
| --- | --- | --- | --- |
| JTAG | BL616 → FPGA | Core bitstream into SRAM | SOM debug header TDI/TCK/TDO/TMS |
| UART @2 Mbps | BL616 → FPGA | ROM bytes, OSD text, overlay enable, core config | FPGA `B3` (`UART_RXD`) |
| UART @2 Mbps | FPGA → BL616 | Joypad state, core ID, `printf` | FPGA `C3` (`UART_TXD`) |

On the BL616 side, `firmware-bl616/utils/init.cpp` puts the Primer 25K core
control UART on `GPIO_PIN_11` (TX) / `GPIO_PIN_10` (RX), described as JTAG
connector pins 6/7. Those are the same physical wires as the FPGA's `B3`/`C3`,
which NESTang's `primer25k.cst` labels "UART through USB-C port". *This
routing is inferred from both ends agreeing, not from the Dock schematic —
worth confirming with a scope on first bring-up if the link does not come up.*

Baud is configured as `2000000 * 40 / 26` on the Primer because that board's
BL616 has a 26 MHz crystal rather than 40 MHz; the resulting line rate is
2 Mbps, matching `iosys_bl616`'s `BAUD_RATE = 2_000_000`.

`nestv_primer25k_top.sv` passes `UART_RXD`/`UART_TXD` straight through to
`nestang_top`, and `nestv_primer25k.cst` already assigns `B3`/`C3`. **No
change is required to the UART path.**

## Bitstream format and layout on media

TangCore loads cores from `<drv>cores/<board>/<name>.bin`, falling back to
`<drv>cores/<name>.bin` (`firmware-bl616/core/cores.cpp:58`). `<board>` is
`primer25k` (`main.cpp:69`). The files are Gowin **binary** bitstreams, not
`.fs` text.

Our build already emits one: `impl/pnr/nestv_primer25k_m3.bin`, 862,199 bytes,
against TangCore v0.7's `cores/primer25k/nestang.bin` at 848,821 bytes. Same
format, same size class. Nothing needs converting.

Required media layout for a first run:

```
/cores/primer25k/monitor.bin      # menu core — without this there is no video
/cores/primer25k/nestang.bin      # NES core
/nes/*.nes
```

## Storage: SD is already supported

`main_task` mounts `"sd:"` first (500 ms timeout) and only falls back to
`"usb:"` (2 s) if that fails. `CMakeLists.txt` enables both
`CONFIG_FATFS_SDH_SDCARD` and `CONFIG_FATFS_USBH`, and `main()` registers the
SDH driver. This is better news than TangCore's architecture doc suggests —
that doc only mentions USB — and it lines up with `PROJECT.md` §6's internal
microSD baseline without a firmware fork.

**On the Primer 25K Dock, `sd:` will never mount.** Sipeed's Dock
specification lists three PMOD sockets, one USB-A, one USB-C and a 2x20 SDRAM
header — and no microSD/TF slot at all. The PMOD-TF Card on hand connects to
the *FPGA*, which is the wrong side: TangCore's firmware reads storage from
the BL616. So on this board the firmware's 500 ms `sd:` attempt always times
out and falls through to `usb:`.

Consequences:

- **Development storage is a USB flash drive**, populated on a PC. Nothing
  else is possible on the Dock.
- **A USB microSD card reader on the hub is a reasonable interim stand-in**
  for the eventual internal card — it enumerates as mass storage and mounts as
  `usb:`, so media images can be built and tested in their final form.
- **§6's internal-microSD baseline is a carrier-board item**, not something
  M5.2 can demonstrate on the Dock. The firmware support already exists
  (`CONFIG_FATFS_SDH_SDCARD`, the `sd:`-first mount order), so the carrier
  only has to route the BL616's SDH pins to a slot. That is the whole of the
  remaining work, and it is hardware, not software.

## BL616 firmware: flash layout and the v0.7 problem

`flash_primer25k.ini` from release v0.7:

```ini
[official]
filedir = bl616_fpga_partner_primer25k.bin
address = 0x0

[custom]
filedir = tangcore_primer25k.bin
address = 0x40000
```

This confirms the secondary-boot layout recorded in `docs/decision-log.md`,
and confirms the board's `2025030317` debugger firmware is the right
generation — TangCore's bundled `bl616_fpga_partner_primer25k.bin` is dated
2025-03-04, the console variant 2025-03-03.

Two caveats the decision log did not have:

- **The standard procedure rewrites `0x0` anyway.** The `.ini` flashes the
  partner firmware at `0x0` as well as TangCore at `0x40000`. No *update* is
  needed, but the debugger firmware does get overwritten with TangCore's copy.
  A failure mid-write costs JTAG access to the FPGA, which is currently the
  only way to get a bitstream onto this board. Treat it as the riskiest single
  step in M5.
- **Only release v0.7 ships Primer 25K.** Verified across all 15 releases:

  | Release | Date | Primer 25K artifacts |
  | --- | --- | --- |
  | v0.7 | 2025-03-13 | `flash_primer25k.ini`, `tangcore_primer25k.bin`, `bl616_fpga_partner_primer25k.bin`, `cores/primer25k/{monitor,nestang,snestang}.bin` |
  | r0.8 | 2025-04-13 | none |
  | v0.9 | 2025-05-03 | none |

  At the pinned source revision, `firmware-bl616/buildall.bat` has `primer25k`
  commented out of its board list, and `tangcore/build.bat package` creates an
  empty `build\cores\primer25k\` and copies nothing into it. The *source*
  still supports it — `CMakeLists.txt`, `main.cpp`, `utils/init.cpp` and
  `fpga/programmer.cpp` all handle `TANG_PRIMER25K`, and NESTang's own
  `buildall.bat` still builds `primer25k ds2` — but nobody has shipped or,
  presumably, tested it since March 2025.

  Recommendation: **use the v0.7 prebuilt binaries first**, because they are
  the only Primer 25K firmware known to have worked. Build from the pinned
  source (`TANG_BOARD=primer25k make`) only after the prebuilt path is proven,
  so a failure can be attributed.

## Controllers: three routes, only one of which costs FPGA pins

Corrected from an earlier reading of this file, which called the DAC pinout a
blocker for M5. It is not. There are three input routes and two of them
bypass the FPGA's pins entirely.

1. **USB gamepad on the BL616 (no FPGA pins at all).** The BL616 runs its own
   USB host stack. `usb/usb_gamepad.cpp` writes `hid1_state`/`hid2_state`,
   `main.cpp:199-205` ships them to the FPGA over the UART, they emerge on
   `iosys_bl616`'s `hid1`/`hid2` outputs, and `nestang_top.sv:153` ORs them
   into the gameplay controller inputs (`joy1 = joy1_btns | hid1 | joy_usb1`).
   Menu navigation uses the same state (`main.cpp:230`, `joy1 |= hid1`). So a
   USB pad on the BL616 side drives both the menu and the game while consuming
   zero FPGA I/O. It shares the single USB-C port with the storage drive, so
   it needs a powered hub — `usb/usb_config.h` allows 2 external hubs, 5 HID
   devices, 2 mass-storage devices and 2 Xbox devices.
2. **USB gamepad on the Dock's USB-A port (2 FPGA pins).** That port is wired
   to the *FPGA* at `L6`/`K6`, driven by NESTang's bit-banged `usb_hid_host`.
   Per TangCore's `controllers.md`, only Sipeed's own SNES-style USB pad works
   on FPGA-connected ports. Needs no hub, but the DAC pinout currently takes
   those two pins.
3. **DS2 pad on a PMOD (4 FPGA pins per controller).** Most reliable per
   upstream, but the DAC pinout takes all eight of those pins.

So the pin conflict is real only for routes 2 and 3, i.e. only when the analog
DAC and a *wired* controller must coexist. That is an M4/M5 reunification
problem, not something that blocks a first ROM load.

`hardware/analog-prototype/pin-map.csv` assigns all twelve prototype DAC bits
to exactly the pins routes 2 and 3 would use:

| DAC bits | Reclaimed from |
| --- | --- |
| `video_y[0:3]`, `video_c[0:3]` | both DS2 controller PMOD interfaces (8 pins) |
| `video_y[4]`, `video_c[4]` | LED1, LED0 |
| `video_y[5]`, `video_c[5]` | USB D+, D− (the USB HID gamepad path) |

With the M3 pinout, routes 2 and 3 are both unavailable —
`nestv_primer25k_top.sv` ties `ds_miso`/`ds_miso2` to `1'b1` and leaves
`usb1_dp`/`usb1_dn` dangling. `docs/m3-primer25k-fit.md` already noted the
Primer exposes only eight convenient PMOD pins after HDMI and SDRAM; the DAC
consumed those plus the LED and USB pads.

For M5 itself, route 1 sidesteps this. For M5.4 — analog output and a wired
controller together — the ways out, in the order I would try them:

1. **Reclaim the PMOD-TF Card pins.** `primer25k.cst` carries commented-out
   assignments for `C11 D11 B11 G10 D10 G11` on the TF-card socket. TangCore
   keeps storage on the BL616, so an FPGA-side SD card is dead weight — six
   pins, enough to restore one DS2 controller and both LEDs while keeping a
   full 6+6 DAC. **Needs checking against the Dock schematic** before being
   relied on; `docs/m3-primer25k-fit.md` counted only eight free pins, which
   suggests the previous session did not consider this socket available.
2. **Stay on route 1 and don't spend pins on controllers at all.** A USB pad
   through a hub on the BL616 works alongside a full 6+6 DAC today. The cost
   is a hub in the product's box and no DS2 support, which conflicts with §7's
   goal of two physical NES controller connectors on the carrier — but the
   carrier can wire controllers however it likes, so this may only ever be a
   development-board constraint.
3. **Four-bit Y and C.** Frees four pins for one DS2 controller and keeps
   analog alive. §2 lists six- versus eight-bit DACs as unsettled, so dropping
   to four bits would prejudge a decision M1 was supposed to inform. Last
   resort.

Meanwhile the `m5` synthesis target — upstream `primer25k` pinout restored,
`video_y`/`video_c` dropped, HDMI only — remains the right shape for M5.1. It
costs nothing to build, frees `L6`/`K6` so route 2 also becomes available, and
matches the decision-log ruling that M5 proceeds over HDMI first.

## Boot policy diverges from PROJECT.md

`main_task` unconditionally loads `monitor.bin` at startup and shows the menu.
`PROJECT.md` §2 and M5's exit criteria call for cold boot launching the last
successfully selected game without a separate monitor-core round trip. There
is no last-game persistence in the firmware at the pinned revision — no config
file is read or written.

The menu gesture is closer than expected: `utils/utils.h` defines
`OPTION_OSD_KEY_SELECT_START`, and `iosys_bl616`'s config string offers
"Select+Start" as one of three OSD keys. The default is `Select+Right`, so
this is a default change, not new functionality.

Suspend/resume and video blanking (`docs/boot-menu-suspend.md`) have no
counterpart in the firmware at all.

All of this means **M5's last three exit criteria require a fork of
`firmware-bl616`**, not just configuration. That work is well-defined but it
is not on the critical path to a first ROM load, and it should not be started
until the stock path boots.

## Proposed order of work

| Step | Goal | Repo changes |
| --- | --- | --- |
| M5.0 | Stock TangCore v0.7 boots on this board: BL616 flashed, menu appears over HDMI, a ROM runs, using TangCore's *own* `primer25k` cores | none |
| M5.1 | Our bitstream replaces `cores/primer25k/nestang.bin` and runs a ROM | new `m5` synth target, HDMI only, DAC dropped |
| M5.2 | Media image built in its final layout | none — deferred to the carrier, which must route BL616 SDH to a slot |
| M5.3 | Last-game boot, Select+Start menu, suspend | fork of `firmware-bl616` |
| M5.4 | Reunite with M4: analog output and a wired controller coexist | pin plan per the options above |

### Hardware still needed

Nothing on hand can navigate the menu, so M5.0 is blocked on parts rather than
on work:

| Item | Why | Alternative |
| --- | --- | --- |
| USB hub, ≥3 ports, with power pass-through, into the USB-C port | Carries the storage drive and the gamepad on the BL616 side simultaneously; also powers the board | A USB-C OTG adapter with power pass-through covers storage alone, but then the pad must go via the Dock's USB-A |
| USB gamepad | Menu navigation. 8BitDo SN30 Pro wired and the 8BitDo wireless adapter are both listed as fully working on the hub | Sipeed's SNES-style USB pad in the Dock's USB-A port — the only model the FPGA-side host is documented to accept, and it needs `L6`/`K6`, so it requires the `m5` (no-DAC) bitstream |
| USB flash drive, FAT32 | Cores and ROMs | A USB microSD reader, which doubles as a rehearsal for the carrier's internal card |

Upstream keeps a compatible-hub list at
<https://github.com/nand2mario/tangcore/wiki/Compatible-USB-Hubs>. That list is
short and community-maintained; absence from it is not evidence against a hub.
The hard requirement is a power-input port, since the hub occupies the only
USB-C and the Dock has no other documented power path.

The DS2 PMOD is **not** required for M5 and, given the DAC pinout, is the
least useful of the three input routes on this board.

### What the BL616 accepts as a gamepad

`usb/hidparser.cpp` is a generic HID report-descriptor parser (Till Harbaum's,
from FPGA-Companion) — no VID/PID whitelist. Anything declaring itself
`USAGE_JOYSTICK` or `USAGE_GAMEPAD` on the generic-desktop page is parsed, so
the compatibility table lists what has been confirmed, not what is possible.
Three behaviours worth knowing before blaming a controller:

- **Directions come from the X/Y axes, not the hat.** `joystick_parse`
  thresholds `a[0]`/`a[1]` at `<0x40` / `>0xC0`. A hat descriptor is parsed
  into the report config but never consulted for direction, so a pad whose
  d-pad is *only* a hat gives no directional input. Analog sticks work.
- **Button mapping is positional.** HID buttons 1–4 → X/A/B/Y; buttons 9/10 →
  Select/Start. A pad with a different button order produces scrambled labels,
  not a failure.
- **The menu needs only directions plus A and B** (`main.cpp:244-256`), so an
  unusual pad is usually good enough to reach a ROM even if labels are wrong.
  The in-game OSD gestures all require Select, which some pads (e.g. an N64
  controller behind a USB adapter) simply do not have.

M5.0 needs no code and settles the largest unknown — whether a March-2025
firmware still drives this board. Doing it first means a failure at M5.1 can
only be our bitstream.

Tooling for M5.0 is in the repository:

```sh
make tangcore-fetch    # download + verify v0.7, lay out firmware and media
make tangcore-flash    # write both BL616 images over the USB bootloader
```

`scripts/fetch_tangcore_release.sh` downloads the v0.7 zip, checks it against
SHA-256 `885ab987…d011ca`, and stages `build/tangcore/firmware/` (the two BL616
images) and `build/tangcore/media/` (the `cores/primer25k/` tree to copy onto
the drive or card). Nothing is vendored into the repository.

`scripts/flash_bl616_tangcore.sh` writes `0x0` and `0x40000` with
`bflb-iot-tool --single --addr … --firmware …`, which is the command-line
equivalent of the `flash_primer25k.ini` that BLDevCube consumes on Windows. It
never passes the tool's `--erase`, which is a *chip* erase rather than the
per-section erase the `.ini` asks for. It also writes a `telnetlib` stub into
`build/`: `bflb-iot-tool` imports that module unconditionally but only uses it
from its OpenOCD backend, and it left the standard library in Python 3.13.
Overrides: `PORT=/dev/ttyXXX`, `BAUD=…`.

Operational notes for M5.0, from TangCore's troubleshooting page and
installation guide:

- Enter BL616 boot mode by shorting two pins near the BL616 (the Primer has no
  BOOT button) while connecting USB.
- **Do not power the board from a PC when running TangCore** — the Sipeed
  firmware enters JTAG/debug mode when it detects a host. Use a separate
  supply, or a USB-OTG dongle with power pass-through.
- The DS2 PMOD goes in the *middle* PMOD socket on the Primer.
- No `monitor.bin` on the media means no video at all, which looks identical
  to a dead board.

## Pinning

`firmware/tangcore` is a submodule at `f69c6ff7e21dc43af70465d9428c079f4550abf6`
— the revision already recorded in `THIRD_PARTY.md`, and also upstream `HEAD`
as of 2026-08-12 (upstream last moved 2025-09-13).

Its own eight submodules are deliberately **not** initialized, so
`git submodule update --init` does not pull a second NESTang checkout
alongside `rtl/core/nestang`. Initialize `firmware/tangcore/firmware-bl616`
individually if and when M5.3 starts:

```sh
git -C firmware/tangcore submodule update --init firmware-bl616
```

The firmware source revision that pairs with the pinned tree is
`a5a6ea1cf7c81f32c1c3f0f91ea9d913be5ba078` (2025-05-03). Note this is *later*
than the v0.7 binaries recommended for M5.0; the two are not interchangeable.
