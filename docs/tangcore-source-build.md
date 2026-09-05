# TangCore source integration for Primer 25K

As of 2026-09-05, upstream TangCore `main` is `f69c6ff7` (confirmed by fetch).
Its firmware, monitor, and NES pins match v0.9. The commits after v0.9 only
change documentation. The source build uses these matching revisions:

| Component | Revision |
| --- | --- |
| TangCore distribution | `f69c6ff7e21dc43af70465d9428c079f4550abf6` |
| BL616 firmware | `a5a6ea1cf7c81f32c1c3f0f91ea9d913be5ba078` |
| Monitor FPGA | `e4446093a754205f46e7000e6ef1bf37176bda19` |
| NESTang FPGA | `c2450818e1f0c858e13c5dd16746ee5221a5c760` |
| Bouffalo SDK | `7f44f9ea6b4ccf96db8c5236c8024b68e2a76df7` |

The source build extracts immutable Git objects into a new build directory.
It ignores edits in the development firmware submodule. NesTV's own NESTang
checkout is two documentation-only commits beyond the distribution's NES pin;
its RTL is identical. This package builds upstream NESTang with its original
Primer DS2/USB pinout; it does not include NesTV's analog video additions.

## Build

Initialize the required source repositories once:

```sh
git submodule update --init firmware/tangcore rtl/core/nestang
git -C firmware/tangcore submodule update --init firmware-bl616 monitor
```

On an existing diagnostic checkout, the second command moves the firmware HEAD
back to its upstream pin if Git can do so; preserve local work first. The
source builder itself never updates submodules and does not need their HEADs
to match, only the pinned Git objects to be available.

Use Python 3.12 or newer. Install the Bouffalo SDK at the revision above and the T-Head RISC-V GCC
10.2.0 toolchain. The defaults are `.tools/bl616/bouffalo_sdk` and
`.tools/bl616/toolchain_gcc_t-head_linux/bin`; `--sdk` overrides the SDK, and
PATH may supply the compiler. Gowin EDA 1.9.12.03 is used via
`scripts/run_gowin.sh`; set `GOWIN_SH` if it is not installed at the project's
usual `.tools/gowin/1.9.12.03/IDE/bin/gw_sh` path. Gowin requires its license
server to be reachable.

```sh
make tangcore-build-source
# For the USB-N64 adapter used in the September 4 hardware test:
make tangcore-build-source TANGCORE_BUILD_ARGS='--n64-adapter'
```

Each invocation creates a new timestamped directory under
`build/tangcore-source/`. Use `--output <new-directory>` for a chosen location;
existing directories are refused. `--prepare-only` reconstructs sources without
compiling. `--firmware-only` produces an incomplete package suitable for build
checks, which the source-flash path deliberately rejects.

The complete output is:

```text
package/
  manifest.json
  firmware/tangcore_primer25k.bin
  media/cores/primer25k/monitor.bin
  media/cores/primer25k/nestang.bin
```

The manifest records source revisions, patch/builder hashes, controller mode,
and SHA-256 hashes of all three images. Verify it with:

```sh
python3 scripts/build_tangcore_source.py --verify-package <build-directory>/package
```

## Primer changes

`firmware/bl616-primer25k-source.patch` preserves the upstream framed protocol.
It selects true 2 Mbps UART, keeps GPIO10/11 assigned to that UART, and mounts
USB directly on Primer because the Dock has no BL616-connected SD slot.
There is no legacy protocol parser, ROM pacing/release workaround, J7 debug
UART, or persistent diagnostic logger in this source build.

The build generates a dedicated SDK board directory from pristine pinned SDK
files, changes the startup crystal and firmware header to 26 MHz, and passes
it through `BOARD_DIR`. It does not edit the shared SDK. Existing local edits
outside the overridden SDK board directory are rejected.

The N64 mapping is disabled by default. `--n64-adapter` explicitly enables the
known six-byte report workaround. The adapter's VID/PID still needs identifying
before this can become an automatic device-specific mapping. Generic HID and
upstream XInput behavior remain the default.

Both FPGA builds use the existing equivalent HDMI VCO correction from 1485 to
742.5 MHz, with adjusted output dividers to retain the HDMI frequencies.
`firmware/monitor-primer25k-source.patch` limits Primer's monitor LED output to
the two wired LEDs (upstream's eight-bit output otherwise allocates extra pins)
and supplies its missing 50 MHz input clock constraint.

## Hardware validation and recovery

The initial complete package is `build/tangcore-source/primer/package`, built
with the experimental N64 mapping. Generic and N64 firmware builds passed.
Monitor and NESTang synthesis, placement/routing, and bitstream generation
passed. Both timing reports have zero total negative setup/hold slack under
their current constraints; this is not a complete board-level timing audit.
The six package-integrity tests pass, including rejection of replaced cores,
missing files, incomplete packages, and the legacy protocol.

**This source package has not been flashed or tested on hardware.** The working
v0.7 FPGA images and diagnostic application under `build/tangcore/` remain the
recovery baseline. Its original application SHA-256 is
`387a301ea19021a11ad2f92c0d07d72056b5c4ba32a0ac1094863987996419af`.

For the next hardware session, back up the USB drive's two known-good core
files and copy both files from the new package's `media/cores/primer25k/` into
`cores/primer25k/` on the drive. Keep the same ROM, hub, power splitter and
controller. With the BL616 in ISP mode, the corresponding application can be
flashed using:

```sh
SOURCE_PACKAGE="$PWD/build/tangcore-source/primer/package" make tangcore-flash-source
```

This verifies the complete package first and uses the existing application
flash path at `0x40000`. Leave `FLASH_PARTNER` unset to preserve the debugger
firmware at `0x0`. Verify USB mounting, monitor/menu display, NES loading, and
controller input. Rollback requires restoring both old FPGA images and the old
diagnostic application (`make tangcore-flash-debug`); mixing the old and new
protocols is not a supported combination.

After this matched upstream package passes, test NesTV's M3 binary as the NES
image with the same source firmware and monitor. That remains M5.1 hardware
validation. Do not copy the M3 binary into a package with its existing manifest;
keep the original package intact and record the substituted binary's hash.
