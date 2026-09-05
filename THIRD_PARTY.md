# Third-party software

Original nestv material is licensed under GPL-3.0-or-later as described in
`LICENSES/README.md`.

All revisions are immutable commit IDs. The bootstrap script verifies any
individually vendored file before it is used.

| Component | Upstream | Pinned revision | License | Use |
| --- | --- | --- | --- | --- |
| MiSTer `yc_out.sv` | [Arcade-Gaplus_MiSTer](https://github.com/MiSTer-devel/Arcade-Gaplus_MiSTer) | `bcb33525b3e09c9c619768c9cf91e28d18a8ff7c` | GPL-2.0-or-later in the file header; repository COPYING is GPL-3.0 | Encoder source fetched unchanged into `build/upstream/` |
| NESTang | [nand2mario/nestang](https://github.com/nand2mario/nestang) | `5b24a710b176fc33575cb7a69d3afabad92f1f7d` | GPL-3.0 | NES core, Primer 25K platform, SDRAM, BL616 menu/loader, and HDMI implementation; Git submodule at `rtl/core/nestang/` |
| TangCore | [nand2mario/tangcore](https://github.com/nand2mario/tangcore) | `f69c6ff7e21dc43af70465d9428c079f4550abf6` | Apache-2.0 firmware; individual cores retain their licenses | BL616 host firmware and integration reference; Git submodule at `firmware/tangcore/` |

The complete license text accompanying `yc_out.sv` is downloaded from the
same pinned repository revision to `build/upstream/COPYING`. NESTang's complete
GPL-3.0 text is present in the submodule as `rtl/core/nestang/COPYING`.

NESTang was added for M2 and is initialized by `git submodule update --init`.
The project does not modify the submodule checkout. For M3,
`scripts/synth_primer25k.sh` mechanically generates an untracked copy of
NESTang's HDMI PLL in `build/gowin/primer25k/`, changing its equivalent VCO
configuration from 1485 MHz to an in-range 742.5 MHz before Gowin synthesis.

**The BL616 firmware and Bouffalo SDK are patched for Primer 25K bring-up.**
The diagnostic UART, legacy-core compatibility, controller workaround, and
26 MHz SDK clock changes are preserved as patches in `firmware/`.
See [firmware/README.md](firmware/README.md) for exact base revisions,
application order, build instructions, and validation limits. The patches are
tracked here so reconstruction does not depend on unpublished submodule commits.

TangCore was fetched for M5 and is initialized by `git submodule update --init`.
Its own eight nested submodules are deliberately left uninitialized, so a
recursive init does not pull a second NESTang checkout alongside the directly
pinned one. Initialize individual nested submodules only as needed, e.g.
`git -C firmware/tangcore submodule update --init firmware-bl616`.

The two NESTang pins are the same code. TangCore `f69c6ff` pins NESTang at
`c2450818`; the `rtl/core/nestang` pin `5b24a710` is two commits later and the
diff between them touches only `CHANGES.md`. The vendored core is therefore
already TangCore's NES core, and the M3 bitstream already carries TangCore's
FPGA-side `iosys_bl616` interface — the legacy IO system is `iosys_picorv32`,
which this project does not build.

**M5 is in progress and no ROM-loading path works yet.** TangCore v0.7's BL616
application has been flashed and verified by read-back, but runtime execution,
storage mounting, and UART communication have not yet been observed. Note also
that Primer 25K binaries ship only in
TangCore release **v0.7** (2025-03-13); v0.8 and v0.9 dropped them, and the
board is commented out of `buildall.bat` at the pinned revision, though the
source still supports `TANG_BOARD=primer25k`. See
`docs/m5-tangcore-integration.md` for the full boundary analysis, and
`docs/bringup.md` and `docs/decision-log.md` for status.
