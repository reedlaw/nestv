# Build and toolchain

## Reproducible inputs

`scripts/fetch_upstream.sh` downloads `yc_out.sv` from an immutable Git commit
and verifies its SHA-256 digest. NESTang and TangCore pins are recorded in
`THIRD_PARTY.md`; they are not required by the M0 standalone build.

## Open-source checks

The supported entry points are:

```sh
make lint
make test
make check
```

CI runs `make check` on Ubuntu 24.04 using the distribution Verilator package.

## Gowin synthesis

Release synthesis is pinned to Gowin EDA 1.9.12.03. The wrapper automatically
uses `.tools/gowin/1.9.12.03/IDE/bin/gw_sh` when present. Alternatively, put
`gw_sh` on `PATH` or set `GOWIN_SH` to its path.

On Fedora, the wrapper preloads the system FreeType library to avoid an ABI
conflict between Gowin's bundled FreeType and the current system Fontconfig.

```sh
GOWIN_SH=/opt/gowin/IDE/bin/gw_sh make synth-primer25k
```

The command runs `scripts/gowin/primer25k.tcl`; Gowin writes its project
products under ignored `impl/`. The M0 synthesis harness retains the encoder
datapath while exposing only clock and Y/C samples. Physical pins remain
unassigned; pin selection belongs to M3 after I/O-bank and DAC review.
