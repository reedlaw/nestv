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

TangCore is initialized by `git submodule update --init`. Its `firmware-bl616`
and `monitor` nested submodules are used by the matching source build; other
nested cores remain optional. See [source build instructions](docs/tangcore-source-build.md).

The two NESTang pins are the same code. TangCore `f69c6ff` pins NESTang at
`c2450818`; the `rtl/core/nestang` pin `5b24a710` is two commits later and the
diff between them touches only `CHANGES.md`. The vendored core is therefore
already TangCore's NES core, and the M3 bitstream already carries TangCore's
FPGA-side `iosys_bl616` interface — the legacy IO system is `iosys_picorv32`,
which this project does not build.

**M5.0 hardware bring-up passed on 2026-09-04**, using v0.7's packaged Primer
FPGA images and patched firmware based on v0.9's source revision. The matching
current-source firmware/monitor/NESTang build is now integrated and builds
successfully, but its hardware validation is pending. See
[the source integration record](docs/tangcore-source-build.md) for exact pins,
Primer adaptations, SDK provenance, build requirements, and validation limits.
The legacy package remains available as the recovery baseline.
