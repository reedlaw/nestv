# Standalone encoder validation

M1 uses the upstream `yc_out.sv` file unchanged. At twelve samples per NTSC
subcarrier cycle, the SystemVerilog raster generator drives 2,730 samples by
262 lines with a 2,112-by-240 active region.
Its patterns cover color bars, grayscale, all 64 NES palette entries,
single-sample monochrome stripes, and saturated checkerboards.

`make validate-m1` performs the complete repeatable experiment:

1. compile upstream `yc_out` and the synthetic raster using Verilator;
2. export RGB reference data, Y, C, sync, and blanking to
   `build/vectors/yc_out.csv`;
3. quantize separate Y and C paths through deterministic six- and eight-bit
   resistor-DAC models;
4. apply luma/chroma low-pass approximations, FPGA output resistance,
   resistor tolerance, active summing, and a terminated 75-ohm load;
5. decode both results through a simple quadrature/notch model;
6. write source and decoded PNGs plus `build/m1/comparison.json`.

For signal-level inspection, `make wave` records three representative lines
(color bars, grayscale, and NES palette) to `build/waves/yc_out.fst`.
`make wave-open` opens the trace when GTKWave is installed. Useful top-level
signals include `din`, `dout`, `de`, sync inputs, and their delayed outputs;
the `dut` scope also exposes the phase accumulator, burst counter, Y/U/V
pipeline, and chroma lookup values.

The decoder is intentionally diagnostic rather than a claim of CRT
equivalence. Its value is stable comparison between encoder or DAC changes.
The phase increment advances the carrier by one twelfth of a cycle per sample,
matching the initial approximately 42.955 MHz encoder-clock experiment.

## M1 baseline

The initial deterministic run processed 506,880 active samples. The modeled
six-bit and eight-bit decoded frames differ by 48.02 dB PSNR, while their
composite waveforms differ by 1.53 RMS eight-bit codes. This small simulated
difference supports starting the hardware prototype at six bits, but does not
replace tolerance sweeps or measurement of a physical DAC.
