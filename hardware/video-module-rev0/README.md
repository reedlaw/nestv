# Optional analog-video module, revision 0

Revision 0 defines the reusable module boundary before schematic capture and
PCB layout. It is intended to work first through a short Primer 25K harness
and later from the same connector on the nestv carrier.

The base board remains fully functional over HDMI when this module is absent.
The module adds S-Video and composite output. It is not hot-pluggable.

## Partition

The base board owns:

- native raster and menu composition;
- RGB-to-Y/C encoding;
- sync-level insertion and six-bit quantization;
- module detection, enable, and safe pin states.

The video module owns:

- two resistor DACs;
- luma and chroma gain;
- reconstruction filtering;
- S-Video output;
- active composite summing;
- 75-ohm output drive and connector protection.

This is a stable sample-stream boundary. The module contains no NES-specific
state and requires no module-specific FPGA bitstream.

## Revision-0 signal chain

```text
Y[5:0] -> matched R-2R -> attenuate/buffer -> configurable Y filter
                                                    +-> S-Video Y driver
                                                    +-> active summer --+
                                                                         +-> composite driver
C[5:0] -> matched R-2R -> AC coupling -> gain -> configurable C filter --+
                                                    +-> S-Video C driver
```

Both connector outputs must be designed for a 75-ohm load. Their acceptance
levels are measured at the far side of a 75-ohm source resistor into a 75-ohm
termination.

## Initial electrical contract

| Property | Revision-0 requirement |
| --- | --- |
| Digital I/O | 3.3 V LVCMOS |
| Active DAC width | 6 bits Y and 6 bits C |
| Reserved width | 8 bits per channel |
| Maximum sample clock | 75 MHz |
| Y code 0 | Sync tip |
| Y code 19 | Blank and black |
| Y code 63 | Peak white |
| C code 32 | Zero chroma |
| Analog supply | 5 V nominal, module-filtered |
| Hot plugging | Not supported |
| Module-present | Passive active-low strap |
| Missing-module behavior | DAC pins disabled or driven low; HDMI unaffected |

`connector.csv` reserves eight bits per channel, sample clock, sync, data
enable, configuration I2C, and hardware output enable. Revision 0 drives only
bits 0 through 5. Reserved data bits must be pulled to a defined state on the
module.

## Layout constraints

- Place both resistor networks immediately beside the module connector.
- Match Y and C data-route topology; avoid routing them through the output
  region.
- Interleave connector grounds with switching-signal groups.
- Keep raw DAC, filtered video, and connector-output test points distinct.
- Put the composite driver and its 75-ohm source resistor beside the RCA jack.
- Keep the chroma path away from the sample clock and digital connector edge.
- Join digital and analog grounds through a continuous reference plane; do not
  force return current through a narrow split-plane bridge.
- Reserve component alternatives for luma trap/low-pass and chroma filtering.

## Prototype strategy

The Primer adapter is only a wiring harness. It maps the twelve available
prototype outputs to this connector and supplies ground and power. It must not
change the reusable connector definition.

Do not order a PCB from this revision. The open decisions in `design-review.md`
must be resolved from Primer measurements and a captured schematic first.
