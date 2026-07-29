# Third-party software

Original nestv material is licensed under GPL-3.0-or-later as described in
`LICENSES/README.md`.

All revisions are immutable commit IDs. The bootstrap script verifies any
individually vendored file before it is used.

| Component | Upstream | Pinned revision | License | Use |
| --- | --- | --- | --- | --- |
| MiSTer `yc_out.sv` | [Arcade-Gaplus_MiSTer](https://github.com/MiSTer-devel/Arcade-Gaplus_MiSTer) | `bcb33525b3e09c9c619768c9cf91e28d18a8ff7c` | GPL-2.0-or-later in the file header; repository COPYING is GPL-3.0 | Encoder source fetched unchanged into `build/upstream/` |
| NESTang | [nand2mario/nestang](https://github.com/nand2mario/nestang) | `5b24a710b176fc33575cb7a69d3afabad92f1f7d` | GPL-3.0 | NES core, Primer 25K platform, SDRAM, BL616 menu/loader, and HDMI implementation; Git submodule at `rtl/core/nestang/` |
| TangCore | [nand2mario/tangcore](https://github.com/nand2mario/tangcore) | `f69c6ff7e21dc43af70465d9428c079f4550abf6` | Apache-2.0 firmware; individual cores retain their licenses | Future host firmware and integration reference |

The complete license text accompanying `yc_out.sv` is downloaded from the
same pinned repository revision to `build/upstream/COPYING`. NESTang's complete
GPL-3.0 text is present in the submodule as `rtl/core/nestang/COPYING`.

NESTang was added for M2 and is initialized by `git submodule update --init`.
The project does not modify the submodule checkout. For M3,
`scripts/synth_primer25k.sh` mechanically generates an untracked copy of
NESTang's HDMI PLL in `build/gowin/primer25k/`, changing its equivalent VCO
configuration from 1485 MHz to an in-range 742.5 MHz before Gowin synthesis.

TangCore remains recorded for the planned M5 host integration and is not
currently fetched. This avoids carrying TangCore's nested NESTang checkout in
parallel with the directly pinned core submodule.
