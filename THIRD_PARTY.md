# Third-party software

All revisions are immutable commit IDs. The bootstrap script verifies any
individually vendored file before it is used.

| Component | Upstream | Pinned revision | License | Use |
| --- | --- | --- | --- | --- |
| MiSTer `yc_out.sv` | [Arcade-Gaplus_MiSTer](https://github.com/MiSTer-devel/Arcade-Gaplus_MiSTer) | `bcb33525b3e09c9c619768c9cf91e28d18a8ff7c` | GPL-2.0-or-later in the file header; repository COPYING is GPL-3.0 | Encoder source fetched unchanged into `build/upstream/` |
| NESTang | [nand2mario/nestang](https://github.com/nand2mario/nestang) | `5b24a710b176fc33575cb7a69d3afabad92f1f7d` | GPL-3.0 | Future native-video integration reference |
| TangCore | [nand2mario/tangcore](https://github.com/nand2mario/tangcore) | `f69c6ff7e21dc43af70465d9428c079f4550abf6` | Apache-2.0 firmware; individual cores retain their licenses | Future host firmware and integration reference |

The complete license text accompanying `yc_out.sv` is downloaded from the
same pinned repository revision to `build/upstream/COPYING`.

NESTang and TangCore are recorded here but are not fetched by the M0 build:
neither is needed for the standalone encoder test. They should be added as
submodules only when M2 integration begins, avoiding a duplicate nested
NESTang checkout.
