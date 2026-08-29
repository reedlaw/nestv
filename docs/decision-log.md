# Decision log

Records decisions and corrections made during development, especially ones
that aren't obvious from reading the code or `PROJECT.md` alone.

## 2026-08-29 (M5.0 root cause) — the Dock's USB-C is a fixed sink; a laptop hub can never work

With the diagnostic UART finally readable, a boot with the powered hub and USB
stick attached gives:

```
SD mount failed (3). USB...
USB mount failed (FRESULT=3)
No monitor.bin found for board.
core_id=-1
hid1: off none, hid2: off none, xbox1: off none, xbox2: off none
```

`FRESULT=3` is `FR_NOT_READY`, and the HID/xbox line shows the BL616's USB host
stack running and enumerating **nothing**. Not a mount timeout, not a filesystem
problem -- no device ever appeared.

**Cause, from the schematic netlist.** `J8` (USB-C, 16-pin) has `CC1`/`CC2` tied
down by `R21` and `R22`, both 5.1 K, with no PD controller anywhere on the board.
That is a fixed Rd pair: the port is permanently a sink/UFP and can neither
advertise itself as a host nor perform a PD data-role swap. `R19`/`R20` (0 Ohm)
are the series jumpers carrying `D+`/`D-` to the BL616; `FU1` is the 6 V 2 A
polyfuse on `5V_USB`.

An active USB-C hub therefore decides the Dock is a device to be charged and
never offers its downstream ports. This is not fixable by cable, adapter
orientation, or boot ordering with that class of hardware.

**The BL616 is not the problem.** It never reads CC -- its USB PHY sits directly
on `D+`/`D-` through `R19`/`R20`, and host mode is purely a firmware decision
that the running CherryUSB stack has already made.

**Fix:** a *passive* USB-C OTG adapter with power pass-through, as TangCore's
own docs specify ("For Primer/Console, use USB-OTG dongle with power
pass-through"). Having no controller, it wires `D+`/`D-` straight through to a
USB-A socket and feeds VBUS to both sides, putting the drive directly on the
BL616's data lines. TangCore also specifies the order: **drive -> OTG -> power**.

**For the carrier board (`PROJECT.md` §6).** This is another reason the internal
microSD baseline is the right design: `main_task` mounts `sd:` before `usb:`, so
routing the BL616's SDH pins to a slot removes the OTG dongle from the product
entirely. On the stock Dock there is no alternative -- the USB-A port (`J13`) is
wired to the FPGA (`L6`/`K6`), not the BL616, and there is no SD slot.

---

## 2026-08-29 (later still) — diagnostic UART working; cause was a wire seating

The BL616 diagnostic UART now decodes. The fault was mechanical: a wire that
looked seated in the Debug Mate's XIAO socket was not making contact. Reseating
it produced output immediately.

Everything else checked out and was ruled in along the way, and none of it was
wasted: the transmit path was verified on a multimeter (0.00 V / 2.98 V swings
driven through `transmit_byte()` itself), and a stopwatch analysis of a
calibration square wave recorded on video confirmed the bit period is ~104.6 us
(~9560 baud) and that `bflb_mtimer_delay_us()` behaves identically with
interrupts enabled and disabled. The `DEBUG_UART_BIT_US = 68` constant and its
40/26 clock-ratio rationale are both correct; the 3 s marker measuring ~4.6 s
independently confirms the ratio.

Working configuration: Dock J7 `TDI` -> Debug Mate XIAO socket `D6`, J7 `GND` ->
socket `GND`, Mate set to `UART: XIAO` at 9600. Note `D6` is TX and `D7` is RX on
every XIAO board -- an earlier attempt used `D7` and could not have worked.

`utils/debug_uart.cpp` gained three build-time test modes, all now off:
`DEBUG_UART_SOAK` (multimeter-readable 0x00 stream), `DEBUG_UART_SWEEP` (walks
the bit period, one letter per candidate), and `DEBUG_UART_CALIBRATE` (times the
bit delay with interrupts on and off). It also now flushes synchronously while
`xTaskGetSchedulerState() == taskSCHEDULER_NOT_STARTED`, so init-time messages
reach the wire instead of sitting in a buffer until `debug_uart_task` is created.

Flash it with `make tangcore-flash-debug` (`APP=debug`), which writes only
`0x40000`.

---

## 2026-08-29 (later) — why the diagnostic UART never transmitted

The Debug Mate's Grove input was blamed for this; it was not the cause. Two
findings, in order.

**The listener works, via the XIAO socket, on `D6`.** On every XIAO board `D6`
is TX and `D7` is RX. An earlier attempt wired the source to socket `D7` — the
pin the Debug Mate *drives* — so nothing could arrive. Feeding an externally
powered ESP32's `D6` into socket `D6` (plus `GND`) decodes correctly, which also
disproves the theory that the Mate needs to be powering the board it monitors.

**The firmware buffered its output and never drained it before the scheduler
started.** `debug_uart_log()` only appends to a ring buffer; the only thing that
drives the pin is `debug_uart_task`, created at `main.cpp:607`, three lines
before `vTaskStartScheduler()`. Everything logged during init — including
`usbh_initialize()`, which is a plausible place to hang on a board powered by a
charger with no USB host — was therefore invisible. A hang anywhere in that
sequence is indistinguishable from a dead UART: the app runs, TDI idles at
3.3 V, and not one byte is ever sent.

`utils/debug_uart.cpp` now transmits synchronously while
`xTaskGetSchedulerState() == taskSCHEDULER_NOT_STARTED`, so init messages reach
the wire as they are produced. Rebuilt and staged to
`build/tangcore/firmware/tangcore_primer25k_debug_uart.bin`.

---

## 2026-08-29 — Dock schematic read; DONE LED and the UART tap point

The Dock schematic (`Tang_Primer_25K_Dock_60033_Schematic.pdf`) and interactive
BOM (`..._ibom.html`) were already in the repo but had never been read. Doing so
resolves three things previously inferred from silkscreen photographs.

- **`J7`, the "Debugger" pads, is JTAG-only.** It is a `Conn_02x04_2.54mm`
  carrying `JTAG_TMS`, `JTAG_TDI`, `JTAG_TCK`, `JTAG_TDO`, `+5V`, `GND`, `+3V3`
  and `BL616_EN`. The Dock wiki's "supports JTAG+UART" describes what the
  onboard BL616 presents to a host over USB-C (two FTDI-emulated channels, as
  seen in `--scan-cables`), not what is broken out at the header.
- **`B3`/`C3` are not on the 40-pin headers.** In the SoM connector list every
  header-routed pin carries a `_40P` suffix; `B3_IOB56A_FPGA_UART_RX` and
  `C3_IOB56B_FPGA_UART_TX` do not, alongside `D7_DONE`, `E8_READY` and the USB
  pins.
- **The BL616↔FPGA UART is tappable at `R15`/`R16`.** Both are `0R` in `R_0402`,
  in series with `616_UART_RX` (BL616 `GPIO_10`) and `616_UART_TX` (`GPIO_11`).
  They sit ~1.0 mm apart immediately beside the BL616 (`U1`, QFN-40 5x5 mm),
  between it and PMOD socket `J4`; pads are 0.54 x 0.64 mm. Which of the two is
  the BL616's transmit side was not pinned down from the extracted text — probe
  both. The link runs at **2 Mbps**, so a monitor capped at 921600 cannot
  decode it.

**Cheapest diagnostic first: `LED4`.** `D7_DONE` drives `LED4` via `R2`/`R6`,
and `E8_READY` drives `LED3`; both sit in a column of three green LEDs beside
the USB-C connector with `LED1` (POWER). The schematic reproduces the legend
"Normal: Done=1 / Fail: Done=0". Watching `LED4` while the board runs standalone
splits the M5.0 failure without any probing: lit means the FPGA was configured
and the fault is downstream; dark means TangCore never reached the programming
step, implicating BL616 startup or media mount.

Note `-use_done_as_gpio 1` in our own build makes `LED4` untrustworthy for
bitstreams we synthesise — but M5.0 runs TangCore's stock `nestang.bin`, where
it is a valid indicator.

### USB topology — the BL616 and the FPGA do not share a port

From the `USB` and `Debugger` sheets:

- **`J13` is the USB-A port and it belongs to the FPGA.** Its data pins reach
  the SoM as `L6_IOT23A_USB_P` / `K6_IOT23B_USB_N` through 0 Ω `R29`/`R30`. It
  is strapped as a host port: `R26`/`R27` (15 K pulldowns on D+/D-) are fitted
  and `R28` (the 1.5 K device-role pullup) is marked `NC`. The sheet labels it
  "USB Host".
- **The BL616's own USB (`BL616_USB#_P` / `BL616_USB#_N`) goes to the USB-C
  port**, which is also the power input and the JTAG/debug path to a PC.

So TangCore's storage can only arrive through the USB-C port, on the same
connector that supplies power and that puts the BL616 into debugger mode when
it detects a host. Plugging the Dock into an ordinary USB-C hub's PD input gets
power in, but that port is designed to be fed by a charger or to face a
computer — it does not present downstream devices to the Dock. This is why
TangCore's install docs name specific OTG dongles with power pass-through.
The Dock's USB-A port cannot substitute: it is FPGA-side.

Two mode notes are printed on the schematic and both are reachable at `J7`:
connect `BL616_EN` to `GND` to use an external JTAG debugger, and connect
`JTAG_TDO` to `3V3` before power-up to force the BL616 into flash/ISP mode.

`LED5` sits beside the BL616 on the Debugger sheet, far from the
POWER/READY/DONE cluster; its function was not resolved from the extracted
text, but its placement suggests a BL616-side status indicator worth watching.


---

## 2026-08-12 (later) — M5 started; `iosys_bl616` is TangCore, not legacy

### Correction to the entry below

The entry below, and `docs/bringup.md`'s next-step note, described the
existing top level as implementing "NESTang's legacy UART-based `iosys_bl616`
protocol", to be replaced by TangCore's JTAG mechanism. Reading TangCore's
sources directly shows that is wrong in a way that would have caused
unnecessary work:

- `iosys_bl616.v` **is** TangCore's FPGA-side interface. Its header reads
  "BL616-based IO system … 2/2025", its config string is `"Tangcores;-;…"`,
  and TangCore's `docs/dev-guide/core-development.md` lists it as a required
  part of every TangCore core. The legacy IO system is `iosys_picorv32.v` —
  the FPGA softcore that fetches `firmware.bin` from SPI flash, i.e. exactly
  the `0x500000` path abandoned in the entry below.
- JTAG and UART are both used. BL616 bit-bangs JTAG to load the *bitstream*
  into FPGA SRAM; ROM data, OSD text and joypad state still run over a 2 Mbps
  UART to `iosys_bl616`. The JTAG mechanism replaced NOR-flash core switching,
  not the UART protocol.
- The two NESTang pins are the same code: TangCore `f69c6ff` pins NESTang at
  `c2450818`, `THIRD_PARTY.md` pins `5b24a710`, and the diff between them
  touches only `CHANGES.md`. `rtl/core/nestang` was already TangCore's NES
  core.

So the M3 bitstream was already a TangCore core, already on the right UART
pins, already emitting a Gowin binary bitstream in the format TangCore loads.
The HDMI "NESTang boot screen" validated during M3 is `iosys_bl616`'s own
overlay waiting for a BL616.

### Decisions

- **TangCore is now a submodule** at `firmware/tangcore`, pinned to the
  revision already recorded in `THIRD_PARTY.md`. Its eight nested submodules
  are left uninitialized so a recursive init does not pull a second NESTang
  checkout.
- **M5.0 comes first: prove the stock path before substituting our own
  bitstream.** Flash the BL616, boot TangCore's *own* `primer25k` cores from
  removable media, and get a ROM running. No repository changes. This is the
  only way a later failure can be attributed to our bitstream rather than to
  the firmware.
- **Use TangCore release v0.7 binaries for M5.0, not a source build.** Primer
  25K artifacts ship only in v0.7 (2025-03-13) — verified across all fifteen
  releases; v0.8 and v0.9 contain console60k/138k only, `primer25k` is
  commented out of `firmware-bl616/buildall.bat` at the pinned revision, and
  `build.bat package` creates an empty `cores/primer25k` and copies nothing
  into it. The source still supports `TANG_BOARD=primer25k`, so a source build
  remains possible later, but nothing has shipped or presumably been tested
  since March 2025.
- **M5 proceeds over HDMI with the DAC dropped**, via a separate `m5`
  synthesis target, because the DAC pinout leaves no pins for a controller and
  TangCore's menu needs one. This is consistent with the existing ruling that
  M4 does not block M5.

### Findings worth keeping

- `flash_primer25k.ini` confirms the secondary-boot layout: partner firmware
  at `0x0`, `tangcore_primer25k.bin` at `0x40000`. The `.ini` also rewrites
  `0x0`, which looked like the riskiest step in M5 since that image provides
  the JTAG access this board depends on. **Measured on hardware 2026-08-12 and
  the risk is gone:** a read-back of `0x0` before flashing is byte-identical to
  TangCore's bundled `bl616_fpga_partner_primer25k.bin` (SHA-256
  `1be5c1f9…aacd`), so there is nothing to gain by writing it.
  `scripts/flash_bl616_tangcore.sh` now backs up `0x0-0x60000`, compares, and
  skips `0x0` unless it actually differs (`FLASH_PARTNER=1` to force). Only
  `0x40000` is written. `0x40000` read back as erased beforehand, confirming
  the BL616 had never held application firmware.
- **TangCore firmware already supports SD**, not just USB. `main_task` mounts
  `sd:` first and falls back to `usb:`; `CMakeLists.txt` enables both FATFS
  backends. TangCore's architecture doc only mentions USB and is misleading
  here. **But the Primer 25K Dock has no microSD slot** — Sipeed's Dock
  specification lists three PMOD sockets, one USB-A, one USB-C and the SDRAM
  header, and nothing else — so `sd:` always times out there and the drive is
  always `usb:`. The PMOD-TF Card on hand is FPGA-side and cannot serve. §6's
  internal-microSD baseline is therefore a carrier-board task: route the
  BL616's SDH pins to a slot, and the existing firmware picks it up with no
  change. A USB microSD reader on the hub is a usable interim stand-in.
- **The DAC pinout does not block M5.** An earlier draft of this entry called
  it a blocker; that was wrong. The BL616 runs its own USB host stack, and
  `usb/usb_gamepad.cpp` → `main.cpp:199-205` → `iosys_bl616.hid1/hid2` →
  `nestang_top.sv:153` carries a USB gamepad's state into both the menu and
  the game **using zero FPGA pins**. The pin conflict applies only to the two
  wired routes — a DS2 PMOD, or the Dock's USB-A port (FPGA pins `L6`/`K6`,
  Sipeed's own pad only) — so it is an M5.4 problem, not an M5 one. Candidate
  relief for M5.4: the PMOD-TF Card socket pins (`C11 D11 B11 G10 D10 G11`),
  commented out in NESTang's `primer25k.cst` and dead weight under TangCore
  since storage lives on the BL616 — six pins, enough for one DS2 controller
  plus both LEDs at a full 6+6 DAC. Needs checking against the Dock schematic;
  `docs/m3-primer25k-fit.md` counted only eight free pins and appears not to
  have considered that socket.
- **M5's boot-UX exit criteria need a firmware fork.** `main_task`
  unconditionally loads `monitor.bin` and shows the menu; there is no
  last-game persistence and no suspend support at the pinned revision. The
  menu gesture is closer — `OPTION_OSD_KEY_SELECT_START` already exists and is
  just not the default.
- Operational: do not power the board from a PC while running TangCore. The
  Sipeed firmware enters JTAG/debug mode when it detects a host.

Full analysis: `docs/m5-tangcore-integration.md`.

---

## 2026-08-12 — ROM loading attempted on the wrong architecture; correcting course for M5

### What happened

During a long hardware bring-up session, ROM loading was investigated by
trying to get NESTang's *legacy standalone* companion firmware
(`firmware.bin`, from `nand2mario/nestang` release `v0.11`) running on the
board's BL616 debugger chip, written to external SPI flash at `0x500000`
via JTAG (Gowin Programmer / openFPGALoader `--external-flash -o
0x500000`). Several real tool bugs were found and partially diagnosed along
the way (see "Findings worth keeping" below), but this entire direction was
a mistake: `PROJECT.md` §2 already settled on **TangCore** (not legacy
NESTang) as "the primary reference" framework, and ROM loading/menu/storage
is explicitly milestone **M5 — TangCore/storage integration**, not
something to bolt onto the legacy architecture.

The mistake wasn't caught until several rounds of user pushback (challenging
premature "this works" claims, asking why other Linux TangCore users
wouldn't hit these bugs, and finally asking directly whether the planning
phase had already addressed this). It should have been caught immediately
when ROM loading first came up as a topic, by re-reading `PROJECT.md`
instead of working forward from whatever was already built in the repo.

**Status at the end of this session:** no working ROM-loading path existed;
the legacy-firmware attempts never succeeded and TangCore integration had not
started. This status was superseded later the same day by the entry above.

### Decision

M5 must target TangCore specifically, per `PROJECT.md` §2. The legacy
NESTang `iosys_bl616`/UART companion-firmware path should not be pursued
further for ROM loading — it's a different, older mechanism than what this
project's plan calls for.

### Findings worth keeping (mostly not relevant to TangCore, but don't re-derive them)

- **BL616 debugger firmware is already TangCore-compatible.** The board's
  debugger firmware serial is `2025030317`. Per Sipeed's official
  "Update debugger" wiki page
  (wiki.sipeed.com/hardware/en/tang/common-doc/update_debugger.html), this
  is both the current Primer 25K debugger firmware *and* the first version
  supporting the "secondary boot" flash layout TangCore uses: debugger
  firmware at flash `0x0`, secondary application firmware (i.e. TangCore's
  BL616 firmware) at flash `0x40000`. **This is good news for M5** — no
  debugger firmware update should be needed before flashing TangCore's
  firmware.
- **TangCore's firmware flashing tool is different from what legacy NESTang
  docs describe.** TangCore's BL616 firmware is flashed via Bouffalo Lab's
  own tooling (`BLDevCube` on Windows, or the cross-platform
  `bflb-iot-tool` Python package, `pip install bflb-iot-tool` — works on
  Linux, though note it currently requires a `telnetlib` shim since that
  stdlib module was removed in Python 3.13+). This goes over BL616's own
  native USB bootloader mode (entered by shorting two test points near the
  BL616 chip while powering on — see TangCore's installation guide for the
  Primer 25K-specific photo), **not** through Gowin/openFPGALoader JTAG
  flash-writing. This sidesteps the legacy-path tool bugs below entirely.
- **Legacy-path tool bugs (only relevant if ever revisiting the legacy
  architecture):** Gowin's Linux Programmer CLI doesn't recognize this
  board's external flash chip's JEDEC ID (`0x0B4017`) in its internal
  vendor database, so `exFlash` operations fail with "spi flash not found."
  openFPGALoader needed an unpatched-upstream JTAG workaround to even
  detect the board (forcing the `_cmd8EWA` Sipeed-cable workaround in
  `ftdiJtagMPSSE.cpp` unconditionally, since the board's cable serial isn't
  one of the two upstream hardcodes), and even after that, external flash
  writes fail reproducibly on a `write_enable()` call after a successful
  erase — a real, traced bug, reported upstream (openFPGALoader issue
  #389 is related but for a different chip variant; a full report was
  drafted but not yet posted). None of this blocks M5, since TangCore
  doesn't use this flash-write path.
- A stray Gowin CLI attempt (`operation_index 30`,
  `Firmware Erase,Program,Verify` with `--mcuFile`) partially wrote to
  flash at an address that likely overlapped the bitstream and produced a
  configured-but-blank-video state after a cold boot. Restored via SRAM
  reprogram. Flash on this board is presumed to still contain whatever
  that operation wrote at address `0x0`/nearby — **don't assume flash is
  blank; check before relying on boot-from-flash.**

### Also raised, resolved

Whether M4 (analog output) blocks M5 (TangCore/ROM loading): no. §12's
bring-up sequence lists ROM loading (step 8) before the analog prototype
steps (steps 9–14), and M5's exit criteria only requires composite/no-HDMI
operation as its *final* checkbox, not a prerequisite to start. M5 can and
should proceed over HDMI first, independent of M4.
