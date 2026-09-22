# Development build and hardware-test log

Keep build results separate from hardware results. For each future candidate,
append its source/package identity, commands or reproduction reference, artifact
hashes, build checks, hardware observations, and recovery baseline. Never infer
hardware success from compilation or timing reports. Local build files are
ignored artifacts; hashes below identify them even if those directories change.

## 2026-09-04 — last known-good M5.0 hardware setup

**Result: hardware PASS.** Primer 25K Dock displayed the TangCore menu, mounted
USB storage, loaded Baseball into gameplay, and accepted USB-N64 adapter input.
The setup used the powered hub and USB-C OTG power-injection splitter.

This was a mixed-provenance, intentionally compatible set: v0.7 packaged FPGA
monitor/NESTang images plus locally rebuilt BL616 diagnostic firmware with the
26 MHz startup correction, legacy unframed protocol compatibility, and N64
mapping fixes. It was not a source rebuild of both v0.7 FPGA images.
The firmware work was captured in root commit `a90d7c1`; reproduction patches
are described in [firmware README](../firmware/README.md).

| Local artifact | SHA-256 |
| --- | --- |
| `build/tangcore/firmware/tangcore_primer25k_debug_uart.bin` | `387a301ea19021a11ad2f92c0d07d72056b5c4ba32a0ac1094863987996419af` |
| `build/tangcore/media/cores/primer25k/monitor.bin` | `a49290e8e31c903210b6136b32e45be0dbb695c6bc7d7d8899ff7d2456fa6df9` |
| `build/tangcore/media/cores/primer25k/nestang.bin` | `d0b69517ad8f60a7697342001db96ec8d94951c6c001a2fbbbbc4683b1975781` |

Existing USB diagnostic files documented successful mount, core identification,
ROM transfer, and controller input. See [decision log](decision-log.md) for the
investigation and successful test details. This set remains the recovery baseline.

## 2026-09-05 — matching upstream source package

**Build: PASS. Hardware: FAIL; unresolved.** Recorded retrospectively on
2026-09-06 from the build outputs and hardware-session observations.

Integration commit: `e51c597`. Package: `build/tangcore-source/primer/package`.
Experimental N64 mapping enabled; upstream framed protocol. Source revisions:

- tangcore: `f69c6ff7e21dc43af70465d9428c079f4550abf6`
- firmware: `a5a6ea1cf7c81f32c1c3f0f91ea9d913be5ba078`
- nestang: `c2450818e1f0c858e13c5dd16746ee5221a5c760`
- monitor: `e4446093a754205f46e7000e6ef1bf37176bda19`
- Bouffalo SDK: `7f44f9ea6b4ccf96db8c5236c8024b68e2a76df7`

The [source-build guide](tangcore-source-build.md) records reproduction and
Primer patches. BL616 generic and N64-enabled builds succeeded. Gowin
1.9.12.03 completed monitor and NESTang synthesis, placement/routing, and
bitstream generation; both had zero total negative setup/hold slack under
current constraints. Package integrity checks passed. These checks did not
establish successful operation on the board.

| Local artifact | SHA-256 |
| --- | --- |
| `build/tangcore-source/primer/package/firmware/tangcore_primer25k.bin` | `443039ee4f38e2e06bfcb8aaea4678af80d0ebfba6521cc29cd1f0f6397ef2fd` |
| `build/tangcore-source/primer/package/media/cores/primer25k/monitor.bin` | `afa10576b1589ffa8af09afa14b745e21d1f01f54e0959e242046ca8d50350d9` |
| `build/tangcore-source/primer/package/media/cores/primer25k/nestang.bin` | `c6817dfde70f972f8bc4ea57e15be08f91cdd4b31ca11f9fba11f6c78ce45cf6` |

### Hardware-session evidence

- User flashed using
  `SOURCE_PACKAGE="$PWD/build/tangcore-source/primer/package" make tangcore-flash-source`
  and installed the FPGA images on USB storage.
- An initial drive inspection found the old v0.7 core files. That mismatch was
  corrected; it does not explain the subsequent matching-set failure.
- Retry still produced a black screen. The user reported the DONE LED lighting
  repeatedly and continuing to flash on and off.
- After that retry, both installed USB core hashes matched the source package
  above. The flash command was user-reported; no BL616 flash readback was taken.
- No fresh diagnostic logs were found on the drive. Existing
  `tangcore-diagnostic.txt`, `rom-diagnostic.txt`, and
  `controller-diagnostic.txt` were from the older diagnostic build, not evidence
  of this boot's progress. This source build omits both persistent logging and
  the J7 diagnostic UART.
- The source monitor repurposes the DONE-associated output for USB error status;
  blinking alone does not establish repeated FPGA reconfiguration or its cause.

**Next diagnostic step:** restore early UART logging and capture a complete
boot using the planned Wi-Fi harness. Keep the known-good set intact. The source
package manifest's `hardware_validated: false` remains accurate; this log adds
that testing was attempted and failed, rather than merely pending.

## 2026-09-06 — records audit

Recomputed all six local artifact hashes above; source package hashes agree
with its manifest. Corrected the stale claim that the source package had never
been flashed. No new compilation, flashing, or hardware test was performed
for this documentation update. Second Seeed order confirmed placed; see
[hardware inventory](hardware-inventory.md).
