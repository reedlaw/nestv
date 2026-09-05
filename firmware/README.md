# Primer 25K firmware

The current development path is the [matching upstream source build](../docs/tangcore-source-build.md).
It preserves the upstream protocol and has reproducible firmware/FPGA packaging.

## Legacy diagnostic firmware checkpoint

This package preserves the M5.0 bring-up source, including diagnostics and the
USB-N64 six-byte report workaround. It is a development checkpoint, not the
final board configuration. Hardware results and remaining cleanup are in
[bringup.md](../docs/bringup.md#open-items).

## Reconstruct from pinned sources

Run from the NesTV repository root, using fresh checkouts for the two clones
below (choose other paths if they already exist):

```sh
nestv_root="$PWD"
git clone https://github.com/nand2mario/firmware-bl616.git build/primer25k-firmware
git -C build/primer25k-firmware checkout a5a6ea1cf7c81f32c1c3f0f91ea9d913be5ba078
git -C build/primer25k-firmware apply "$nestv_root/firmware/bl616-debug-uart.patch"
git -C build/primer25k-firmware apply "$nestv_root/firmware/bl616-primer25k-compat.patch"
git clone https://github.com/nand2mario/bouffalo_sdk.git build/primer25k-sdk
git -C build/primer25k-sdk checkout 7f44f9ea6b4ccf96db8c5236c8024b68e2a76df7
git -C build/primer25k-sdk apply "$nestv_root/firmware/bouffalo-sdk-primer25k-clock.patch"
```

The SDK patch changes the generic `bl616dk` startup and firmware header to
26 MHz. Use this SDK checkout only for this Primer build. The firmware patch
keeps GPIO10/11 on the FPGA UART, uses true 2 Mbps, speaks the legacy protocol
of TangCore v0.7's packaged Primer cores, and preserves USB/ROM/controller
logging and the experimentally established N64 mapping. It includes the
non-cached FatFs diagnostic-buffer correction.

## Build and stage

Use the Bouffalo T-Head `riscv64-unknown-elf-` toolchain (the validated local
compiler is GCC 10.2.0) and the SDK's bundled CMake. Put the toolchain's `bin`
directory on PATH, then run from the NesTV root:

```sh
make -C build/primer25k-firmware \
  BL_SDK_BASE="$PWD/build/primer25k-sdk" TANG_BOARD=primer25k
make tangcore-fetch
# Preserve any previously flashed application before replacing the staging file.
cp -n build/tangcore/firmware/tangcore_primer25k_debug_uart.bin \
  build/tangcore/firmware/tangcore_primer25k_debug_uart.previous.bin
cp build/primer25k-firmware/build/build_out/tangcore_bl616.bin \
  build/tangcore/firmware/tangcore_primer25k_debug_uart.bin
sha256sum build/tangcore/firmware/tangcore_primer25k_debug_uart.bin
```

On a fresh setup there is no previous debug binary; skip the backup command.
When ready for a hardware test, `make tangcore-flash-debug` writes the
application at `0x40000` and preserves the partner firmware at `0x0`.
Building/staging does not flash hardware.

## Evidence and limits

The existing staged application and existing build output both hash to
`387a301ea19021a11ad2f92c0d07d72056b5c4ba32a0ac1094863987996419af`.
The September 4 record reports successful menu, ROM, and controller operation;
it also records the final logging-buffer correction as not yet flashed.
Do not infer hardware validation of that correction from the current files.

Patch reconstruction was checked against every tracked file in the working
firmware checkout. The SDK patch was checked against the local SDK changes.
A fresh build from reconstructed firmware source is the packaging check;
firmware hashes may differ across build paths/toolchains. M5.1 testing with
NesTV's own FPGA binary and production cleanup remain outstanding.

Fresh reconstruction build passed on 2026-09-05. Its application SHA-256 is
`1fd827f4e98a79bde24dffae87249e8c91fb5b707cdc9a33571fe64d53bd73d9`.
