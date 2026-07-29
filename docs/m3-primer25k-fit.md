# M3 Primer 25K synthesis report

Tool: Gowin EDA 1.9.12.03  
Device: GW5A-LV25MG121NC1/I0  
Source: NESTang `5b24a710b176fc33575cb7a69d3afabad92f1f7d`

The reproducible `make synth-primer25k` target builds the full NES, external
SDRAM interface, BL616 loader/menu, 720p HDMI, native video adapter, unchanged
`yc_out`, and two six-bit DAC buses. Place-and-route and bitstream generation
complete successfully.

## Resource use

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Logic | 11,497 | 23,040 | 50% |
| Registers | 6,038 | 23,280 | 26% |
| CLS | 8,194 | 11,520 | 72% |
| BSRAM | 33 | 56 | 59% |
| DSP | 2.5 | 28 | 9% |
| PLLA | 4 | 6 | 67% |
| I/O ports | 63 | 86 | 74% |

## Timing

Gowin reports zero setup violations, zero hold violations, and zero total
negative slack across 19,485 analyzed endpoints.

| Domain | Required | Reported Fmax |
| --- | ---: | ---: |
| NES | 21.492 MHz | 36.325 MHz |
| SDRAM / Y-C encoder | 64.475 MHz | 105.972 MHz |
| HDMI pixel | 74.239 MHz | 96.075 MHz |
| USB | 12.000 MHz | 133.481 MHz |

The encoder uses the existing 3x NES/SDRAM PLL output. At 64.432 MHz, NTSC
color carrier is exactly one eighteenth of the sample clock. The build
generates a project-local HDMI PLL variant with a 742.5 MHz VCO and divide by
two output; this replaces upstream's equivalent 1.485 GHz configuration, which
is above Gowin's stated 1.4 GHz VCO ceiling.

## Pin and coexistence assessment

All DAC outputs are LVCMOS33 at 8 mA. The six-bit Y and C buses use the pins
otherwise assigned to the two controller interfaces, the USB gamepad pair,
and the two LEDs. HDMI, SDRAM, system clock, reset, and BL616 UART remain
assigned and fit simultaneously.

This proves electrical-bank and package fit, but the Primer exposes only eight
convenient PMOD I/O pins after HDMI and SDRAM are installed. Reaching all
twelve prototype DAC signals therefore requires wiring to the LED and USB
pads as well as the controller PMOD. It is suitable for engineering validation,
not a final daughterboard connector arrangement.
