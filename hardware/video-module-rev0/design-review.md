# Revision-0 design review

## Decisions already made

- The module is optional; HDMI is part of the base-board configuration.
- The interface is a parallel Y/C sample stream, not NES-specific signals.
- Revision 0 implements six bits but reserves eight bits per channel.
- Sync is encoded into Y, so a passive module can produce a valid luma signal.
- Composite uses an active summer rather than a passive Y/C join.
- The module is cold-plug only.

## Decisions requiring bench evidence

| Decision | Evidence required | Status |
| --- | --- | --- |
| Exact board-to-board connector family | Current rating, availability, insertion life, mechanical envelope | Open |
| R-2R values and network package | FPGA drive behavior, settling, monotonicity, obtainable ratio tolerance | Start with 1 kΩ/2 kΩ at 0.1% |
| Y attenuation and gain | Terminated sync/blank/white measurements | Open |
| C gain | Measured burst and saturated-color levels | Open |
| Luma filter/trap | Dot-crawl versus sharpness comparison | Open |
| Chroma filter | Burst shape and display color-lock margin | Open |
| Amplifier/video driver | Stability, output swing, 150 Ω drive, supply availability | Open |
| AC-coupling values | Field-rate droop and display compatibility | Open |
| ESD parts | Added capacitance and connector test standard | Open |
| Analog rail filtering | HDMI-on versus HDMI-off noise measurement | Open |

## Required schematic sheets

1. Connector, module detection, power entry, and mute.
2. Y and C resistor DACs with raw test points.
3. Luma gain/filter and S-Video Y output.
4. Chroma coupling/gain/filter and S-Video C output.
5. Active composite summer and RCA driver.

## Review gates before PCB order

- [ ] Stock NESTang boots and runs over HDMI on the purchased Primer hardware.
- [ ] nestv diagnostic color bars are visible over HDMI.
- [ ] The twelve proposed DAC pins are accessible and electrically usable.
- [ ] Static DAC-code measurements agree with the digital code contract.
- [ ] Candidate amplifier is simulated or evaluated in its intended topology.
- [ ] All outputs are stable into a 75-ohm termination and realistic cable.
- [ ] Connector footprint and mating height fit the modular enclosure concept.
- [ ] The module can be absent without floating outputs or excess base-board
      power consumption.
