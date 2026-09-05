# Development-board bring-up status

Tracks real-hardware progress against `PROJECT.md` §12 (bring-up sequence)
and §14 (software milestones). Update this file, not `PROJECT.md`, as
bring-up progresses — `PROJECT.md` should stay a stable plan.

## Hardware on hand

Tang Primer 25K SoM + Dock, Tang SDRAM module, PMOD-DVI, PMOD-TF Card.
Debugger firmware serial `2025030317` (current as of 2026-08, confirmed via
Sipeed's debugger-update wiki page — see `docs/decision-log.md`).

## Status against §12 bring-up sequence

| # | Step | Status |
| - | --- | --- |
| 1 | Verify power rails | Done (board powers, no issues) |
| 2 | Confirm BL616 programming and UART output | **Done.** J7 `TDI` diagnostic output proved BL616 execution and exposed the 40/26 MHz clock mismatch. The 2 Mbps BL616↔FPGA link is now verified in both directions: four core-ID requests returned `11 00`, parsed as monitor core ID `0`. |
| 3 | Confirm FPGA JTAG and configuration-flash access | Done for JTAG/SRAM programming via Gowin's Linux Programmer CLI. Configuration-flash (exFlash) write access is **not working** on Linux — see decision log |
| 4 | Load a minimal LED/clock test bitstream | Skipped — went straight to the M3 build, which worked |
| 5 | Validate SDRAM independently | Done — M3 build (full NES + SDRAM + HDMI + native video + DAC test outputs) SRAM-programs and runs correctly |
| 6 | Validate HDMI with the known NESTang path | Done — confirmed NESTang boot screen renders correctly over HDMI |
| 7 | Validate storage mounting and file reads | **Done for USB.** A FAT32 USB drive mounts through a power-injection OTG splitter, and `cores/primer25k/monitor.bin` is read and programmed successfully. The earlier `FRESULT=3` was ultimately caused by incorrect 40 MHz board startup on 26 MHz hardware, not a bad drive or either tested splitter. |
| 8 | Load NESTang and run a known ROM | **Done 2026-09-04.** TangCore loads the packaged Primer `nestang.bin`, transfers `/nes/Baseball (USA, Europe).nes`, starts the game, and accepts menu/game input from the USB-N64 adapter. |
| 9–14 | Analog Y/C DAC, S-Video, composite validation (M4 territory) | Not started |

**Bitstream used for validation:** `impl/pnr/nestv_primer25k_m3.fs`, built via
`make synth-primer25k` and SRAM-programmed via `make program-sram`.

`--operation_index 2` on its own is not enough: without `--location` the
programmer picks the wrong cable and fails with "Cable failed to open via the
channel", and the location changes between plug-ins.
`scripts/program_sram.sh` reads it from `--scan-cables` each run. The full
call is

```
programmer_cli -d GW5A-25A -r 2 --fsFile <bitstream>.fs --location <n>
```
This bitstream must be re-flashed after every power cycle — it has never
been written to persistent configuration flash (see decision log for why an
attempt to do so was reverted).

## Milestone status (§14)

- **M0–M2:** done (predates this bring-up session; see git history).
- **M3 (Primer synthesis):** hardware-confirmed. Fits, timing closes, SDRAM
  and HDMI work on real hardware via JTAG/SRAM programming.
- **M4 (analog output):** not started. No technical dependency on M5 — can
  proceed independently once desired (see decision log for the ordering
  question this raised).
- **M5 (TangCore/storage integration):** **hardware bring-up substantially
  complete as of 2026-09-04.** The BL616 application boots, USB storage mounts,
  `monitor.bin` loads, the two-way 2 Mbps MCU/FPGA protocol works, and the menu
  renders over HDMI. NESTang ROM loading and USB controller input now work.
  Earlier that day, a session was spent trying to get ROM loading working via
  NESTang's
  *legacy standalone* companion firmware (`firmware.bin`, written to external
  flash at `0x500000` via JTAG). That was a mistake — see decision log.

### What M5 turned out to already have

The RTL side is essentially done. `rtl/core/nestang` is TangCore's NES core
(same code, two docs-only commits later than TangCore's own pin), and the M3
bitstream already instantiates TangCore's `iosys_bl616` with `CORE_ID(1)` on
the correct UART pins (`B3`/`C3`). The boot screen previously seen over HDMI
is that interface's overlay. Communication with the BL616 is now confirmed in
both directions on real hardware.
`impl/pnr/nestv_primer25k_m3.bin` is already in the Gowin binary format
TangCore loads. Details and evidence in `docs/m5-tangcore-integration.md`.

### M5 sub-steps

| # | Goal | Status |
| - | --- | --- |
| M5.0 | Stock TangCore v0.7 boots: BL616 flashed, menu over HDMI, ROM runs from TangCore's own `primer25k` cores | **Done 2026-09-04**, using the compatibility firmware documented below. |
| M5.1 | Our bitstream replaces `cores/primer25k/nestang.bin` and runs a ROM | **Pending hardware test.** Validate the matching source package first, then substitute the NesTV M3 binary and repeat the ROM/controller test; see [source integration](tangcore-source-build.md). |
| M5.2 | Storage moves from USB drive to SD | Not started |
| M5.3 | Last-game boot, Select+Start menu, suspend | Not started; needs a `firmware-bl616` fork |
| M5.4 | Analog output and a controller coexist | Not started (M4 territory) |

### Known-good M5.0 setup — resume here

Validated 2026-09-04:

- firmware: `build/tangcore/firmware/tangcore_primer25k_debug_uart.bin`,
  SHA-256 `387a301ea19021a11ad2f92c0d07d72056b5c4ba32a0ac1094863987996419af`;
- flash command: `make tangcore-flash-debug` (application at `0x40000` only;
  never rewrite the stock partner firmware at `0x0`);
- USB drive label/mount: `TANGCORE` / `/run/media/reed/TANGCORE`;
- packaged cores: `cores/primer25k/monitor.bin` and `nestang.bin` from
  TangCore 0.7; known ROM: `nes/Baseball (USA, Europe).nes`;
- topology: splitter USB-C male to Dock; splitter charging USB-C to charger;
  splitter USB-A data leg to the powered hub's upstream port; USB drive and
  N64 adapter in hub downstream ports; HDMI from Dock to display;
- result: menu navigation, ROM selection, NESTang programming, complete ROM
  transfer, game start, and controller input all confirmed;
- N64 mapping: D-pad and analog stick both provide directions; A/B map to NES
  A/B; Start maps to Start; Z maps to Select. The adapter's six-byte report
  uses byte 1 as the current button sample and bytes 2/3 as centered X/Y axes.

Diagnostic files on the drive are `tangcore-diagnostic.txt`,
`controller-diagnostic.txt`, and `rom-diagnostic.txt`. They are useful evidence
but are not required for normal boot. The J7 debug wiring is likewise no longer
required for the known-good workflow.

### BL616 flashing, 2026-08-12

Done via `make tangcore-flash`, board in BL616 ISP mode (USB `349b:6160`,
"Bouffalo CDC DEMO", on `/dev/ttyACM0`). Result:

- `0x40000` now holds `tangcore_primer25k.bin` from TangCore v0.7, confirmed
  by an independent read-back after the write.
- `0x0` was **not** written. A read-back before flashing showed it already
  byte-identical to TangCore's bundled `bl616_fpga_partner_primer25k.bin`
  (SHA-256 `1be5c1f9…aacd`), so the stock debugger firmware — and with it JTAG
  access to the FPGA — was never at risk.
- `0x40000` read back as erased beforehand: the BL616 had never held
  application firmware, as recorded.
- Backup of `0x0-0x60000` kept at
  `build/tangcore/backup/bl616-flash-0x0-0x60000.bin`.

**JTAG confirmed intact after flashing.** With the board back on the PC it
enumerates as `0403:6010` (FT2232H) — the Sipeed debugger firmware mimics an
FTDI cable so stock tools work — and `programmer_cli` read
`GW5A-25A (0x0001281B)` and SRAM-programmed the M3 bitstream normally.

TangCore execution is now verified; this flashing record is retained for the
recovery details and hashes.

## Open items

M5.0 is complete. First validate the matching upstream source package; then
complete M5.1 by substituting this repository's NesTV Primer bitstream and
repeating the HDMI/USB/controller test. After that, resume M4 analog Y/C/composite
work, then return to M5.2–M5.4 for internal storage, last-game boot/menu UX, and
coexistence with the final wired NES controllers.

Before upstreaming, split the current diagnostic branch into reviewable changes:

- Primer BL616 26 MHz startup and true 2 Mbps UART;
- preservation of GPIO10/GPIO11 for the FPGA control UART;
- explicit compatibility between TangCore 0.7's legacy packaged cores and the
  newer framed source protocol (or rebuild/package matching cores instead);
- USB-N64 mapping only after identifying its VID/PID; do not upstream the broad
  six-byte-report heuristic;
- remove or separately retain the J7 UART, persistent reports, packet probes,
  and repeated release commands as diagnostics rather than production behavior.

Before treating the firmware as final, turn the successful diagnostic changes
into a maintained Primer 25K board configuration: keep the 26 MHz startup,
2 Mbps UART without the old 40/26 compensation, unframed FPGA response parser,
null-terminated text commands, and GPIO10/11 UART ownership. The temporary
USB-only mount path should remain until the Primer's SD pin conflict is resolved;
the stock Dock has no BL616-connected SD slot.

The USB diagnostic report successfully records core-ID evidence, but its first
sector was corrupted because both the write buffer and FatFs `FIL` private sector
buffer must live in non-cached RAM. Both are now placed there in the latest
unflashed build; this logging-only correction does not invalidate the menu test.

### Superseded investigation notes

M5.0 was attempted with a USB drive and powered USB-C hub, but no HDMI menu
appeared. Confirm that the adapter actually supplies USB host/OTG data (not
only power), that the board is powered from a standalone supply rather than a
PC, and that the drive contains `cores/primer25k/monitor.bin`. A gamepad is not
required to make the initial menu visible.

**Split the failure with `LED4` before probing anything.** The Dock schematic
shows `D7_DONE` driving `LED4` and `E8_READY` driving `LED3`, in a column of
three green LEDs beside the USB-C connector (`LED1` is POWER). With the board
running standalone: `LED4` lit means the FPGA was configured and the fault is
downstream (core handshake or UART); `LED4` dark means TangCore never got that
far, implicating BL616 startup or media mount. `LED4` is only meaningful for
TangCore's stock bitstream — our own builds pass `-use_done_as_gpio 1`.

**A diagnostic firmware build already exists and supersedes probing the
BL616↔FPGA link.** `tangcore_primer25k_debug_uart.bin` (built 2026-08-13, in
`build/tangcore/firmware/`) mirrors `overlay_status()`, `printf()` and a 1 Hz
`[debug] heartbeat N` to **J7 pin 2 (JTAG TDI) at 9600 8N1**, with J7 pin 6 as
ground. Both are 2.54 mm through-holes. Flash it with `make
tangcore-flash-debug`; it writes only `0x40000`. See
`firmware/tangcore/firmware-bl616/DEBUG_UART.md`.

The heartbeat is unconditional — it does not depend on media, mounting or the
FPGA — so it separates "the BL616 never runs the app at `0x40000`" from "the app
runs and fails later" with nothing attached but a charger.

The `R15`/`R16` tap (0 Ω `R_0402` in series with BL616 `GPIO_10`/`GPIO_11`,
beside `U1` and PMOD socket `J4`, running at 2 Mbps) remains a fallback only if
the diagnostic build itself is suspect. The `J7` "Debugger" pads otherwise carry
JTAG only, and `B3`/`C3` reach no 40-pin header — see the decision log.

**The DAC pinout is not an M5 blocker**, only an M5.4 one. It conflicts only
with the two *wired* input routes (DS2 PMOD, Dock USB-A), not with the USB
route on the BL616 side.

**The Dock has no microSD slot**, so `sd:` can never mount there and the
firmware always falls through to `usb:`. Internal microSD per `PROJECT.md` §6
is a carrier-board item; the firmware side already works.

## Next step

First validate the [matching upstream source package](tangcore-source-build.md)
on hardware. It builds successfully and retains the Primer board fixes while
using the current protocol. Preserve the v0.7/diagnostic setup above for recovery.
After this passes, test the NesTV M3 binary with the new firmware and monitor
and record its hash to complete M5.1. The earlier instruction to replace only
`nestang.bin` while keeping the legacy-compatible firmware is superseded:
M3 already uses the newer framed protocol.

Do not reflash `0x0`: it already matches the stock partner firmware, and the
project flash script deliberately skips it by default.
