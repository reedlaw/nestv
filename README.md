# nestv

FPGA CRT console research and implementation, beginning with a native-rate
NTSC Y/C encoder path for NESTang on the Tang Primer 25K.

The engineering plan and milestone definitions live in [PROJECT.md](PROJECT.md).

## Prerequisites

- GNU Make
- `curl` and `sha256sum`
- Verilator 5 or newer
- Gowin EDA 1.9.12.03 for FPGA synthesis (not required for tests)

## Quick start

```sh
make bootstrap
make check
```

`make bootstrap` downloads the exact pinned `yc_out.sv` revision and verifies
its SHA-256 digest. Generated and downloaded files are kept under `build/`.

Useful targets:

```sh
make lint             # Verilator lint
make test             # standalone yc_out simulation
make synth-primer25k  # reproducible Gowin entry point
make clean
```

If `Gowin_V1.9.12.03_linux.tar.gz` is in the repository root, unpack its
`IDE/` directory beneath `.tools/gowin/1.9.12.03/`. The synthesis wrapper
detects that location automatically.

Upstream revisions and licensing are recorded in [THIRD_PARTY.md](THIRD_PARTY.md).
