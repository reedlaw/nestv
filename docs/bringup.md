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
| 2 | Confirm BL616 programming and UART output | **Done.** Diagnostic UART on J7 pin 2 at 9600 confirms the application runs: banner, `TangBoard: primer25k`, USB host init, and `main_task` all observed. The 2 Mbps BL616↔FPGA link is still unverified (`core_id=-1`, no core loaded) |
| 3 | Confirm FPGA JTAG and configuration-flash access | Done for JTAG/SRAM programming via Gowin's Linux Programmer CLI. Configuration-flash (exFlash) write access is **not working** on Linux — see decision log |
| 4 | Load a minimal LED/clock test bitstream | Skipped — went straight to the M3 build, which worked |
| 5 | Validate SDRAM independently | Done — M3 build (full NES + SDRAM + HDMI + native video + DAC test outputs) SRAM-programs and runs correctly |
| 6 | Validate HDMI with the known NESTang path | Done — confirmed NESTang boot screen renders correctly over HDMI |
| 7 | Validate storage mounting and file reads | **Blocked on hardware.** BL616 app and USB host stack confirmed running, but nothing enumerates through an active USB-C hub (`FRESULT=3`): the Dock's USB-C is a fixed sink (`R21`/`R22`, 5.1 K on CC, no PD controller). Needs a passive USB-C OTG adapter with power pass-through — see decision log |
| 8 | Load NESTang and run a known ROM | **Not started**, blocked on step 7 |
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
- **M5 (TangCore/storage integration):** **started 2026-08-12.** TangCore is
  now a pinned submodule at `firmware/tangcore` and the integration boundary
  is analysed in `docs/m5-tangcore-integration.md`. The BL616 application is
  flashed, but execution, storage mounting, and ROM loading remain unverified.
  Earlier that day, a session was spent trying to get ROM loading working via
  NESTang's
  *legacy standalone* companion firmware (`firmware.bin`, written to external
  flash at `0x500000` via JTAG). That was a mistake — see decision log.

### What M5 turned out to already have

The RTL side is essentially done. `rtl/core/nestang` is TangCore's NES core
(same code, two docs-only commits later than TangCore's own pin), and the M3
bitstream already instantiates TangCore's `iosys_bl616` with `CORE_ID(1)` on
the correct UART pins (`B3`/`C3`). The boot screen previously seen over HDMI
is that interface's overlay; communication with the BL616 has not been
observed.
`impl/pnr/nestv_primer25k_m3.bin` is already in the Gowin binary format
TangCore loads. Details and evidence in `docs/m5-tangcore-integration.md`.

### M5 sub-steps

| # | Goal | Status |
| - | --- | --- |
| M5.0 | Stock TangCore v0.7 boots: BL616 flashed, menu over HDMI, ROM runs from TangCore's own `primer25k` cores | **BL616 flashed 2026-08-12** (see below); menu and ROM not yet observed |
| M5.1 | Our bitstream replaces `cores/primer25k/nestang.bin` and runs a ROM | Blocked on M5.0 and on the pin conflict below |
| M5.2 | Storage moves from USB drive to SD | Not started |
| M5.3 | Last-game boot, Select+Start menu, suspend | Not started; needs a `firmware-bl616` fork |
| M5.4 | Analog output and a controller coexist | Not started (M4 territory) |

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

Still unverified: that TangCore itself runs.

## Open items

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

The listener has been the blocker, not the firmware. Use a XIAO ESP32 as the
serial adapter via `scripts/uart_bridge_esp32/` — set `SELFTEST 1` and jumper
`D6`->`D7` first to prove the receive path independently, then set it back to 0
and connect the Dock. The XIAO Debug Mate's UART Monitor was tried and could
not be made to decode anything in Grove mode.

Flash the diagnostic build (`make tangcore-flash-debug`), wire J7 pin 2 to the
ESP32's `D7` and J7 pin 6 to its ground, open the USB serial monitor, and power
the Dock from a plain charger with nothing else attached.

- `[debug] heartbeat 0, 1, 2…` → the BL616 runs TangCore; the mount messages
  that follow say exactly where it stops.
- silence → the app at `0x40000` never starts, and the secondary-boot chain is
  the fault, not storage.

Note that LED evidence alone cannot settle this: `main_task` mounts media before
it calls `fpga_program()`, so DONE stays dark whether TangCore is running
perfectly with no media or not running at all.

Do not reflash `0x0`: it already matches the stock partner firmware, and the
project flash script deliberately skips it.
