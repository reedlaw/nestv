# M4 analog bring-up record

Date: ____________________

Operator: ____________________

Bitstream commit: ____________________

Fixture revision: ____________________

Oscilloscope/probe: ____________________
Displays/capture devices:

## Safety and continuity

- [ ] No shorts between 3.3 V, analog supply, and ground.
- [ ] Every DAC input reaches the intended resistor-ladder bit.
- [ ] USB and controller accessories are disconnected.
- [ ] Analog supply is current-limited for first power-on.
- [ ] All amplifier supply pins have local decoupling.

## Unloaded measurements

Hold S1 to display native color bars.

| Node | Expected | Measured | Pass |
| --- | ---: | ---: | :---: |
| Raw Y sync code | monotonic minimum | | |
| Raw Y blank/black | code 19/63 of range | | |
| Raw Y peak white | code 63/63 of range | | |
| Raw C center | code 32/63 of range | | |
| Encoder sample clock | approximately 64.475 MHz | | |
| Horizontal period | approximately 63.51 µs | | |

Verify all 64 DAC codes with a slow diagnostic counter or static test build
before judging video quality. Record missing codes, non-monotonic steps, and
bit-transition glitches.

## Terminated video levels

Measure at the connector with a real 75 Ω termination. Do not use unloaded
scope amplitudes as the acceptance result.

| Measurement | Initial target | Measured | Pass |
| --- | ---: | ---: | :---: |
| S-Video Y sync tip to blank | 0.286 V nominal | | |
| S-Video Y blank to white | 0.714 V nominal | | |
| Composite sync tip to white | 1.000 V nominal | | |
| Chroma burst amplitude | record peak-to-peak | | |
| DC at cable after coupling | safe for display input | | |

## Display compatibility

| Display | Input | Locks | Stable color | Notes |
| --- | --- | :---: | :---: | --- |
| | S-Video | | | |
| | S-Video | | | |
| | Composite | | | |
| | Composite | | | |

## Comparative artifacts

Use the same display, cable, scene, and settings for each source.

| Source | Dot crawl | Cross-color | Luma sharpness | Color stability |
| --- | --- | --- | --- | --- |
| nestv S-Video | | | | |
| nestv composite | | | | |
| MiSTer reference | | | | |
| External encoder | | | | |

## Result

- [ ] Output levels are within the fixture's documented tolerances.
- [ ] S-Video locks on at least two displays.
- [ ] Composite locks on at least two displays.
- [ ] Failures and component substitutions are recorded.
- [ ] Native composite quality is acceptable and repeatable.
