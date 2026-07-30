# FPGA CRT Console

Engineering plan for an affordable FPGA-based retro console with native 240p composite video for consumer CRT televisions.

**Status:** Architecture revision in progress. No production hardware has been purchased. The next phase is simulation, synthesis, and development-board validation.

**Document date:** 2026-07-29

---

## 1. Project objective

Build a compact FPGA console that:

- runs console cores directly in FPGA logic;
- outputs native-rate 240p composite video without a scaler or frame-buffered video conversion path;
- retains HDMI as a development, diagnostic, and optional secondary output;
- supports two original NES controllers in the first product;
- boots without a general-purpose operating system;
- stores cores, firmware, configuration, saves, and user-provided ROMs internally;
- can be manufactured at low volume without requiring a difficult chip-down BGA FPGA design on the first revision.

The first supported system is NES. Other TangCore systems remain future work and must not distort the first hardware or software milestone.

### Product thesis

The product is not merely an inexpensive FPGA board. Its differentiator is an integrated, composite-native console for North American consumer CRTs:

- no Raspberry Pi;
- no Linux video stack;
- no RGB or SCART adapter chain;
- no HDMI-to-analog downscaler;
- no external USB drive required in normal use;
- one enclosure, one power cable, two NES controller ports, and direct composite output.

---

## 2. Current decisions

### Settled for the validation phase

- **Validation FPGA:** Sipeed Tang Primer 25K SoM using the Gowin GW5A-25A.
- **Core framework:** TangCore and its NESTang integration are the primary reference.
- **First system:** NES only.
- **Composite encoder:** port and validate MiSTer `yc_out` rather than writing a new encoder.
- **Analog architecture:** separate digital Y and C outputs, separate resistor DACs, analog filtering, active composite summing, and a 75-ohm output driver.
- **S-Video:** expose Y and C before the composite mixer when the added connector cost is acceptable.
- **HDMI:** retain the existing HDMI path during development and preferably in the final product.
- **Storage:** internal microSD is the baseline. User-facing USB mass storage is not required.
- **Development order:** simulation and synthesis first, dev-board analog prototype second, custom carrier PCB third.
- **Boot and menu UX:** cold boot launches the last successfully selected game; the normal NES bitstream contains its controller-operated overlay menu rather than requiring a separate monitor-core round trip.
- **System controls:** a long `Select + Start` gesture opens the menu, with long-press Reset as the front-panel fallback.
- **Power UX:** target soft power and warm suspend with video disabled; retain a cold-standby path pending carrier power measurements.
- **Save states:** persistent save states are a stretch goal. Baseline warm suspend retains a session only while standby power remains available.

The detailed behavior and implementation boundaries are recorded in
[`docs/boot-menu-suspend.md`](docs/boot-menu-suspend.md).

### Not yet settled

- Production FPGA or module.
- Six-bit versus eight-bit Y and C DACs.
- Exact luma trap, chroma filter, active summer, and video-driver circuit.
- Whether HDMI remains populated on the production board.
- Whether the first production firmware uses full TangCore or a narrower NESTang-derived configuration.
- Whether the BL616 remains the production host MCU.
- Internal microSD versus soldered eMMC after validation.
- Final enclosure, connector arrangement, and retail price.

---

## 3. Rejected or deferred directions

### Rejected: two-resistor color composite based on `agg23/fpga-compositevideo`

That project is a grayscale composite implementation, not a complete NTSC color encoder. It is useful as a timing reference but does not supply chroma modulation or colorburst generation.

### Rejected as the primary path: external RGB encoder IC

AD723, AD725, and CXA1645-class encoders remain useful as reference implementations and fallback hardware. They reduce FPGA work but add meaningful BOM cost and provide less control over carrier phase, filtering, and core-specific artifact behavior.

An AD723 or AD725 development adapter may still be built to establish a known-good baseline against which the native FPGA encoder can be compared.

### Deferred: cartridge slot and cartridge passthrough

NESTang loads ROM images into memory and implements cartridge mapper behavior in FPGA logic. Real-time cartridge passthrough is a separate high-speed bus project and is outside the first product.

### Deferred: chip-down FPGA

The Primer 25K SoM avoids BGA fanout, multi-rail FPGA power sequencing, configuration-flash design, and BGA-level debugging. A chip-down design should be reconsidered only after demand, yield, and platform requirements are known.

### Rejected for the first version: ARM-only emulation

The project previously encountered display-controller clock constraints when attempting exact NTSC timing from a conventional ARM SoC. Programmable-I/O MCUs can generate native composite, but the first product prioritizes FPGA core behavior and TangCore compatibility rather than the lowest possible BOM.

---

## 4. System architecture

```text
                         +----------------------+
                         | Internal microSD     |
                         | cores / ROMs / saves |
                         +----------+-----------+
                                    |
                                    v
+-------------+      host/control   +----------------+
| USB-C       |<------------------->| BL616 host MCU |
| power/data  |                      +-------+--------+
+-------------+                              |
                                               | JTAG / UART / control
                                               v
                                  +--------------------------+
                                  | Gowin GW5A-25A FPGA      |
                                  |                          |
NES controllers ---------------->| TangCore / NESTang       |
                                  | SDRAM controller         |
                                  | menu and overlay path    |
                                  | audio generation         |
                                  +------------+-------------+
                                               |
                                     native core video
                                               |
                              +----------------+----------------+
                              | shared palette / overlay stage  |
                              +----------+-----------------------+
                                         |
                              +----------+----------+
                              |                     |
                              v                     v
                    +----------------+     +-------------------+
                    | HDMI pipeline  |     | MiSTer `yc_out`   |
                    | framebuffer /  |     | native Y/C encoder|
                    | scaler         |     +---------+---------+
                    +----------------+               |
                                              digital Y and C
                                                      |
                                      +---------------+---------------+
                                      |                               |
                                      v                               v
                                Y resistor DAC                  C resistor DAC
                                      |                               |
                                luma filtering                 chroma filtering
                                      |                               |
                                      +---------------+---------------+
                                                      |
                                               active summer
                                                      |
                                             75-ohm video driver
                                                      |
                                              composite RCA output
```

The composite branch must remain tied to the source core's native raster. It must not read from the HDMI framebuffer or create an independent output raster that requires line duplication, line dropping, or frame-rate correction.

---

## 5. Video architecture

### 5.1 Core-facing interface

Create a vendor-neutral video boundary before either physical output path.

Suggested conceptual interface:

```systemverilog
interface core_video_if;
    logic        clk;
    logic        pixel_ce;
    logic [23:0] rgb;
    logic        hsync;
    logic        vsync;
    logic        csync;
    logic        de;
    logic [10:0] x;
    logic [9:0]  y;
endinterface
```

The exact synthesizable representation may use a packed struct or explicit ports instead of a SystemVerilog interface if Gowin tool compatibility requires it.

For NESTang, the adapter begins with:

- six-bit NES palette index;
- PPU cycle coordinate;
- scanline coordinate;
- core clock;
- overlay/menu information.

The adapter must:

1. convert the NES palette index to RGB;
2. define active video and blanking from native coordinates;
3. generate or expose HSync, VSync, and CSync in the polarity expected by `yc_out`;
4. composite the menu and overlay before the HDMI/composite split;
5. repeat or resample pixels into the encoder clock only through an exact synchronous clock relationship;
6. avoid an asynchronous frame buffer in the native analog path.

### 5.2 `yc_out` integration

Use the upstream MiSTer `yc_out.sv` as the initial golden implementation.

Do not optimize or rewrite it until:

- it passes standalone simulation;
- the Gowin wrapper is bit-identical to the upstream module under the same stimulus;
- the complete design synthesizes;
- analog output has been measured.

Important inputs include:

- `PHASE_INC`: 40-bit carrier phase increment;
- `PAL_EN`: disabled for the first NTSC-only milestone;
- `CVBS`: disabled for the preferred separate Y/C path;
- `COLORBURST_RANGE`;
- RGB, sync, and data-enable inputs.

The initial target is NTSC only. PAL support must not delay the first hardware validation.

### 5.3 Encoder clock

The encoder clock should be synchronously related to the native NES clock. A useful initial target is approximately twice the NES master clock, yielding about twelve digital samples per NTSC subcarrier cycle.

The final values must be calculated from the actual NESTang clock implementation and confirmed by simulation and static timing analysis. Avoid hardcoding nominal values before measuring the generated clocks.

### 5.4 DAC architecture

Preferred first prototype:

- six-bit Y resistor DAC;
- six-bit C resistor DAC;
- integrated matched resistor arrays where practical;
- FPGA I/O drive strength chosen to reduce switching noise and DAC nonlinearity;
- test points on every analog stage.

Eight-bit DACs remain an option if pin count, resistor matching, and layout permit. Six bits should be tested first because it is comparable to the established resistor-DAC class used by traditional MiSTer analog arrangements.

### 5.5 Analog output stage

The analog circuit is not optional support circuitry. It determines whether the FPGA encoder produces usable MiSTer-class output.

Required functions:

- convert digital Y and C codes to controlled analog levels;
- apply suitable luma filtering or trapping around the NTSC chroma region;
- filter the chroma output;
- insert or combine synchronization at the correct level;
- actively sum Y and C for composite;
- drive a terminated 75-ohm load;
- provide AC coupling where required;
- avoid instability with common cable and TV loads;
- expose S-Video Y and C before the composite summer when populated.

Do not use a passive Y/C join as the final composite circuit. MiSTer documentation warns that passive combination without a luma trap produces severe rainbowing.

### 5.6 Video claims

Acceptable claim after validation:

> Native 240p composite generated in FPGA logic without scaling or frame buffering in the analog path.

Potential claim after direct comparison:

> Composite encoding and output quality comparable to MiSTer native Y/C.

Claims to avoid:

- electrically identical to an original NES;
- more accurate than all software emulation;
- zero artifacts;
- universal compatibility with every CRT or capture device;
- cycle accuracy unless supported by the underlying core and measured behavior.

---

## 6. Storage and host architecture

### Baseline

Use an internal 4-8 GB microSD card.

Reasons:

- capacity is ample for firmware, cores, NES ROMs, saves, metadata, and diagnostics;
- the media can be imaged before assembly;
- replacement and recovery remain possible;
- FAT-based storage avoids custom flash translation, ECC, and bad-block handling;
- the console does not require a protruding USB stick or a powered USB host port.

### External interface

Use USB-C for:

- fixed 5 V power;
- BL616 firmware recovery;
- optional storage provisioning or update mode;
- serial diagnostics during development.

USB mass-storage host support may remain available on development hardware but is not a product requirement.

### Future storage option

Soldered eMMC may replace internal microSD after validation if:

- driver support is proven;
- manufacturing programming is reliable;
- field recovery remains possible;
- eMMC cost and BGA assembly are justified by production volume.

### Boot and recovery policy

The system must always retain a recovery route independent of the normal user filesystem.

Required behavior:

- known-good boot or recovery image in FPGA configuration flash or other protected storage;
- safe-mode strap or jumper;
- external or internal media can override the normal image only through an explicit boot policy;
- interrupted updates must not permanently brick the console;
- status LED codes must distinguish host boot, storage mount, FPGA configuration, core start, and video start.

---

## 7. Audio and controllers

### Controllers

First hardware target:

- two physical NES controller connectors;
- correct 5 V controller power;
- level shifting or protection between 5 V controller signals and 3.3 V FPGA/MCU I/O;
- series resistors on data and clock lines;
- ESD protection;
- test pads for latch, clock, and data signals.

USB controllers are not required for the first product.

### Audio

The audio path needs an explicit design rather than a single BOM placeholder.

Define and verify:

- source sample format and clock domain;
- DAC method;
- reconstruction filter;
- output level;
- mono or stereo connector policy;
- mute behavior during reset and core loading;
- startup and shutdown pop suppression;
- separation from the video analog supply and FPGA switching noise.

---

## 8. Repository structure

The repository should separate upstream code, portable project code, platform-specific integration, simulation, firmware, and hardware.

```text
.
├── PROJECT.md
├── README.md
├── LICENSES/
├── THIRD_PARTY.md
├── Makefile
├── rtl/
│   ├── core/
│   │   └── nestang/                 # pinned upstream source or submodule
│   ├── video/
│   │   ├── yc_out/                  # pinned upstream source and wrapper
│   │   ├── nes_video_adapter.sv
│   │   ├── overlay_compositor.sv
│   │   ├── sync_generator.sv
│   │   ├── dac_quantizer.sv
│   │   └── video_types.sv
│   ├── audio/
│   ├── host/
│   └── platform/
│       ├── primer25k/
│       │   ├── top.sv
│       │   ├── clocks.sv
│       │   ├── constraints.cst
│       │   └── timing.sdc
│       └── common/
├── firmware/
│   ├── tangcore/                    # pinned upstream source or submodule
│   ├── board/
│   └── tools/
├── sim/
│   ├── yc_out/
│   │   ├── tb_yc_out.sv
│   │   ├── test_patterns.sv
│   │   └── assertions.sv
│   ├── nestang_video/
│   ├── models/
│   │   ├── resistor_dac.py
│   │   ├── filters.py
│   │   ├── composite_encoder.py
│   │   └── composite_decoder.py
│   ├── vectors/
│   └── expected/
├── scripts/
│   ├── sim.sh
│   ├── lint.sh
│   ├── synth_primer25k.sh
│   ├── timing_primer25k.sh
│   ├── render_composite.py
│   └── compare_frames.py
├── hardware/
│   ├── analog-prototype/
│   ├── carrier-rev-a/
│   ├── enclosure/
│   ├── bom/
│   └── manufacturing/
├── docs/
│   ├── architecture.md
│   ├── video.md
│   ├── clocks.md
│   ├── storage.md
│   ├── bringup.md
│   ├── test-plan.md
│   ├── decision-log.md
│   └── platform-evaluation.md
└── .github/
    └── workflows/
```

### Source-management policy

- Pin all upstream dependencies to known commits.
- Do not track moving branch heads in reproducible builds.
- Record local patches separately and keep them small.
- Prefer upstreamable interfaces and fixes over permanent forks.
- Preserve every upstream license and copyright notice.
- Document the exact Gowin tool version used for release bitstreams.

---

## 9. Simulation plan

Simulation is the first implementation milestone.

### Stage A: lint and compile

Tools:

- Verilator as the primary simulator and lint tool;
- Icarus Verilog as a secondary compatibility check where supported;
- GTKWave for waveform inspection;
- Python and NumPy/SciPy for offline signal modeling and image generation.

Initial checks:

- upstream `yc_out.sv` compiles unchanged;
- no unintended latches or width truncations;
- all signed operations behave as expected;
- control and data pipelines remain aligned;
- no unknown values enter active video after reset.

### Stage B: standalone `yc_out` testbench

Generate a synthetic NTSC-like raster and feed:

- color bars;
- all 64 NES palette values;
- grayscale ramps;
- single-pixel black/white stripes;
- saturated-color stripes;
- checkerboards;
- hard color transitions at blanking boundaries;
- captured frames represented as RGB test vectors.

Validate:

- carrier frequency;
- phase accumulator behavior;
- colorburst location and duration;
- luma and chroma neutral levels;
- chroma gating outside active video;
- seven-cycle output-control alignment;
- frame-to-frame carrier behavior;
- separate Y/C mode and packed CVBS mode.

### Stage C: bit-exact wrapper comparison

Drive the upstream module and the project wrapper with identical inputs.

Assert equality of:

- Y;
- C;
- HSync;
- VSync;
- CSync;
- data enable.

Any difference must be explained and documented.

### Stage D: digital-to-analog model

Export time-series Y, C, sync, blanking, and active-video samples.

The software model must support:

- six-bit and eight-bit quantization;
- ideal and tolerance-varied resistor ladders;
- FPGA output resistance approximation;
- Y and C output amplitudes;
- candidate luma and chroma filters;
- sync-level insertion;
- active summing;
- 75-ohm source and load;
- cable capacitance approximation;
- simple notch and comb decoder models.

Produce:

- waveform plots;
- spectral plots;
- decoded PNG frames;
- differences from source RGB;
- comparisons between consecutive frames to reveal dot crawl;
- six-bit versus eight-bit comparison reports.

Simulation is a comparison tool, not proof of CRT compatibility.

### Stage E: NESTang video integration

Simulate the NES video adapter with NESTang output signals.

Assertions:

- palette index changes only at expected pixel boundaries;
- active-video coordinates are monotonic and bounded;
- blanking is black;
- overlay coordinates align with native pixels;
- no HDMI framebuffer is used by the analog path;
- clock-domain crossings are either absent or explicitly constrained;
- the carrier phase remains deterministic relative to the source raster;
- frame and line periods are stable.

### Stage F: synthesis and timing

Build progressively:

1. `yc_out` alone;
2. NESTang plus `yc_out`;
3. NESTang plus `yc_out` plus Y/C DAC outputs;
4. add HDMI;
5. add overlay and menu;
6. add full TangCore host integration.

Record for every build:

- LUT utilization;
- flip-flop utilization;
- block RAM utilization;
- multiplier utilization;
- PLL utilization;
- maximum clock frequency;
- setup and hold slack;
- unconstrained paths;
- warnings and waived warnings.

---

## 10. Development-board prototype

Do not design the production carrier until this phase succeeds.

### Required development hardware

- Tang Primer 25K SoM;
- compatible SDRAM module;
- Primer dock or equivalent breakout;
- HDMI output hardware for the known-good diagnostic path;
- storage supported by the selected TangCore firmware revision;
- external UART access;
- logic analyzer or oscilloscope access to clock, sync, Y, and C;
- prototype Y/C DAC and active composite board.

### Analog prototype board

Build the analog section as a replaceable daughterboard before incorporating it into the carrier.

Include:

- six-bit Y DAC;
- six-bit C DAC;
- optional footprints or jumpers for alternate resistor values;
- independently adjustable Y and C gain;
- swappable filter components;
- S-Video output;
- composite active summer;
- 75-ohm output driver;
- RCA composite output;
- test points for raw DAC Y, filtered Y, raw DAC C, filtered C, sync, and composite;
- clean analog supply filtering;
- ground arrangement representative of the final board.

### Reference encoder

Build or obtain an AD723/AD725 RGB-to-composite reference adapter if practical. It provides a known external-encoder baseline for:

- color lock;
- sync compatibility;
- palette comparison;
- dot crawl;
- cross-color;
- sharpness;
- TV compatibility.

The external encoder is a test reference, not the default production design.

---

## 11. Hardware carrier requirements

### Digital section

- Primer 25K SoM socket or soldered module footprint;
- compatible SDRAM;
- BL616 host MCU or module;
- internal microSD;
- USB-C power and data;
- fixed 5 V operation without USB-PD dependency;
- HDMI connector and ESD protection if retained;
- two NES controller ports with protection and level management;
- audio output;
- accessible programming and recovery interfaces.

### Debug and support section

Mandatory in revision A:

- labeled UART header;
- FPGA JTAG access;
- BL616 boot and programming access;
- safe-mode jumper or switch;
- status LED with documented codes;
- test points for all power rails;
- test points for system clocks and reset;
- test points for Y, C, sync, audio, and composite;
- silkscreened board revision;
- machine-readable board identification through an EEPROM or resistor strap;
- recovery boot independent of the normal filesystem.

### Analog layout rules

- keep resistor DACs close to the FPGA output bank or connector;
- keep Y and C traces short and isolated from HDMI and SDRAM clocks;
- use a continuous ground reference;
- isolate or filter the analog supply;
- place the video driver close to the output connector;
- control return-current paths;
- avoid routing high-speed digital signals through the analog region;
- provide component options for filter tuning without a new PCB revision;
- validate thermal and load behavior into a real 75-ohm termination.

### Mechanical rules

Freeze before batch production:

- enclosure outline;
- board mounting holes;
- RCA, HDMI, USB-C, audio, and controller locations;
- microSD service access;
- safe-mode access;
- airflow and thermal assumptions;
- labeling and regulatory markings.

---

## 12. Bring-up sequence

1. Verify every power rail before installing the SoM or expensive components.
2. Confirm BL616 programming and UART output.
3. Confirm FPGA JTAG and configuration-flash access.
4. Load a minimal LED and clock test bitstream.
5. Validate SDRAM independently.
6. Validate HDMI with the known NESTang path.
7. Validate internal storage mounting and file reads.
8. Load NESTang and run a known ROM.
9. Probe digital Y, C, and sync outputs without the analog board.
10. Install the analog prototype and validate S-Video first.
11. Validate composite after Y and C are independently correct.
12. Compare against the reference encoder.
13. Test multiple CRTs and at least one capture device.
14. Run extended power-cycle, storage-removal, reset, and controller-ESD tests.

S-Video should be validated before composite because separate Y and C isolate encoder errors from mixer and luma-trap errors.

---

## 13. Validation matrix

### Digital

- clean boot from cold power-on;
- repeatable FPGA configuration;
- stable SDRAM behavior;
- correct mapper behavior for representative games;
- menu and overlay visible on both HDMI and analog outputs;
- stable line and frame timing;
- no FIFO underflow or overflow in the native video path;
- no unexplained synthesis or timing warnings.

### Video

Test patterns and games must cover:

- flat fields;
- grayscale ramps;
- high-frequency monochrome detail;
- saturated edges;
- scrolling backgrounds;
- flashing and rapid palette changes;
- sprite-heavy scenes;
- overscan-sensitive titles;
- menus and overlays.

Measure or inspect:

- sync level and width;
- blanking and black levels;
- colorburst frequency, amplitude, phase, start, and duration;
- luma and chroma amplitude;
- composite output level into 75 ohms;
- dot crawl;
- cross-color and rainbowing;
- horizontal sharpness;
- frame-to-frame stability;
- cold and warm behavior;
- effect of HDMI activity on analog noise.

### CRT coverage

Minimum validation set:

- older consumer CRT with simple notch filtering;
- later consumer CRT with comb filtering;
- small portable CRT if available;
- CRT or monitor with S-Video;
- at least one modern capture device for diagnostics.

The capture device must not be treated as the authority for CRT compatibility.

### Reliability

- 100 cold boots;
- repeated reset during core loading;
- power loss during storage writes;
- corrupted or missing microSD;
- safe-mode recovery;
- controller hot-plugging;
- long-duration thermal run;
- operation from several ordinary 5 V USB power supplies;
- ESD-oriented handling tests on exposed connectors.

---

## 14. Software milestones

### M0 — Repository bootstrap

- create directory structure;
- pin upstream sources;
- add licenses and `THIRD_PARTY.md`;
- establish Verilator lint and simulation commands;
- establish reproducible Gowin synthesis command or documented project file;
- add CI for lint and unit simulation.

**Exit:** clean clone can run lint and standalone `yc_out` tests.

### M1 — Standalone encoder validation

- upstream `yc_out` builds unchanged;
- synthetic raster generator completed;
- test patterns completed;
- Y/C samples exported;
- Python analog model produces decoded frames;
- six-bit and eight-bit quantization compared.

**Exit:** digital encoder behavior is understood and repeatable.

### M2 — NESTang native-video adapter

- NES palette lookup moved or shared upstream of output branches;
- native blanking and sync defined;
- menu/overlay path moved or duplicated before the output split;
- `yc_out` driven from native timing;
- HDMI remains functional.

**Exit:** simulation produces matching HDMI content and native Y/C content without using the HDMI framebuffer for analog output.

### M3 — Primer synthesis

- full NES plus `yc_out` build fits;
- timing closes;
- DAC pins assigned to a suitable I/O bank;
- HDMI coexistence assessed;
- utilization report committed.

**Exit:** no unresolved fit, PLL, multiplier, or timing blocker.

### M4 — Development-board analog output

- DAC daughterboard assembled;
- S-Video locks on multiple displays;
- composite locks on multiple displays;
- output levels measured;
- dot crawl and cross-color compared with MiSTer and external encoder reference where available.

**Exit:** native composite quality is acceptable and repeatable.

### M5 — TangCore/storage integration

- selected TangCore revision boots reliably on the Primer 25K;
- internal microSD replaces normal dependence on external USB storage;
- recovery and provisioning flow demonstrated;
- menu and game loading work without HDMI.
- normal NES startup bypasses the separate monitor core and launches the last successfully selected game;
- long `Select + Start` and long-press Reset open the in-core menu without requiring a nonstandard controller;
- clock-gated suspend and video/audio blanking behavior are demonstrated on the development platform.

**Exit:** standalone console workflow operates entirely through composite and NES controllers, including last-game boot and non-persistent suspend/resume.

### M6 — Carrier revision A

- schematic and PCB completed;
- design review completed;
- two prototypes assembled;
- bring-up checklist passed;
- analog performance matches the development-board reference.

**Exit:** carrier is ready for a small validation batch, not general sale.

### M7 — Validation batch

- approximately 20 units;
- assembly time and yield measured;
- support issues recorded;
- BOM corrected from actual purchases;
- enclosure and mechanical design validated;
- licensing and source-distribution process tested.

**Exit:** evidence exists for or against a production run.

---

## 15. Hardware milestones and cost gates

### Cost model rules

BOM must include:

- FPGA module or silicon;
- SDRAM;
- host MCU and its flash/support components;
- internal storage;
- PCB and assembly;
- connectors;
- video DAC and active analog stage;
- audio circuit;
- controller protection and level management;
- power protection;
- enclosure hardware;
- programming and test time;
- expected rework and yield loss.

Track separately:

- development tooling;
- freight and import costs;
- packaging;
- payment and marketplace fees;
- warranty reserve;
- compliance testing;
- development labor.

### Platform strategy

Primer 25K is the reference and validation target. The project must not assume permanent availability of the exact Sipeed module.

Maintain `docs/platform-evaluation.md` with synthesis and cost data for possible production alternatives, including:

- chip-down GW5A-25A;
- Lattice ECP5-25F;
- Efinix Trion T20 or larger;
- Cyclone 10 LP 25K;
- another available FPGA module with sufficient SDRAM and I/O.

Do not port platforms speculatively. First isolate vendor-specific logic behind clock, memory, serializer, and top-level wrappers. Use synthesis-only experiments to eliminate unsuitable alternatives.

---

## 16. Principal risks

### R1 — Primer 25K supply

The module is convenient but not guaranteed as a long-lived product. Mitigation:

- validate on Primer;
- keep platform-specific code isolated;
- document every dependency on its pinout, SDRAM module, and BL616 arrangement;
- evaluate chip-down or alternate FPGA targets before scaling.

### R2 — TangCore reliability on Primer 25K

Primer support is experimental. Mitigation:

- reproduce current boot behavior before modifying video;
- retain UART and HDMI diagnostics;
- pin known-good versions;
- separate TangCore problems from video-encoder problems.

### R3 — Aggregate FPGA fit

NESTang, SDRAM, TangCore integration, HDMI, overlay, and `yc_out` may approach device limits. Mitigation:

- synthesize incrementally;
- record utilization continuously;
- permit a production configuration without HDMI if required;
- optimize only after a working reference exists.

### R4 — Analog quality

Correct RTL does not guarantee good composite video. Mitigation:

- prototype the analog stage separately;
- expose S-Video;
- compare against MiSTer native Y/C and an external encoder;
- tune with measurements across several displays.

### R5 — Incorrect native timing integration

Using the HDMI framebuffer or an independent raster would undermine the design. Mitigation:

- define a native core-video interface;
- make clock relationships explicit;
- assert line and frame timing in simulation;
- prohibit undocumented asynchronous buffering in the analog path.

### R6 — Menu visible only on HDMI

Current overlay integration may be tied to the HDMI path. Mitigation:

- move or duplicate composition before the output split;
- require composite-only operation as a milestone.

### R7 — Storage and recovery

Internal storage improves the product but creates provisioning and update requirements. Mitigation:

- use internal microSD first;
- maintain protected recovery firmware;
- provide USB-C provisioning and UART diagnostics;
- test power loss during writes.

### R8 — Licensing

`yc_out` is GPL-2.0-or-later, NESTang is GPL-3.0, and TangCore components retain their own licenses. Mitigation:

- maintain `THIRD_PARTY.md`;
- preserve notices;
- publish corresponding source for distributed binaries as required;
- document build tools and local modifications;
- obtain legal review before commercial distribution if uncertainty remains.

---

## 17. Immediate issue list

Create these as the first repository issues:

1. Pin current NESTang, TangCore, and MiSTer `yc_out` revisions.
2. Add all third-party licenses and source-attribution records.
3. Build an unchanged `yc_out` Verilator testbench.
4. Generate NTSC test raster and color-bar stimulus.
5. Export Y/C samples and render decoded frames in Python.
6. Compare six-bit and eight-bit DAC quantization.
7. Document NESTang's actual clocks, pixel cadence, line period, and frame period.
8. Define the NESTang-to-`core_video_if` adapter.
9. Determine where menu/overlay composition must move.
10. Synthesize `yc_out` alone for GW5A-25A.
11. Synthesize NESTang plus `yc_out` without HDMI.
12. Synthesize NESTang plus `yc_out` with HDMI.
13. Select a provisional Y/C DAC pin bank and confirm available I/O.
14. Locate an open MiSTer active Y/C adapter schematic suitable as an analog reference.
15. Draw the first six-bit Y/C prototype daughterboard.
16. Define measurement targets for sync, burst, luma, chroma, and output impedance.
17. Reproduce TangCore boot and ROM loading on the exact Primer/SDRAM revision.
18. Verify current TangCore SD support and decide whether firmware work is required for internal microSD.
19. Define safe-mode and recovery boot behavior.
20. Update the BOM from the selected analog prototype circuit.

---

## 18. Definition of success

The first engineering phase succeeds when:

- NESTang runs reliably on the Primer 25K;
- the native analog path does not use the HDMI framebuffer;
- upstream `yc_out` behavior is preserved;
- the complete design fits and meets timing;
- S-Video and composite lock reliably on multiple CRTs;
- composite quality is comparable to MiSTer native Y/C under direct observation;
- menu, ROM selection, games, audio, and both NES controllers work without HDMI;
- internal storage boots without an external USB stick;
- failure states are diagnosable through UART, status codes, and recovery mode;
- the carrier design is based on measured signals rather than paper assumptions.

The product phase begins only after these conditions are met.

---

## 19. References

Primary source baselines:

- TangCore architecture: <https://nand2mario.github.io/tangcore/dev-guide/architecture/>
- TangCore installation and supported devices: <https://nand2mario.github.io/tangcore/user-guide/installation/>
- TangCore repository: <https://github.com/nand2mario/tangcore>
- NESTang repository: <https://github.com/nand2mario/nestang>
- NESTang HDMI/video path: <https://github.com/nand2mario/nestang/blob/master/src/nes2hdmi.sv>
- MiSTer `yc_out`: <https://github.com/MiSTer-devel/Template_MiSTer/blob/master/sys/yc_out.sv>
- MiSTer CRT and native Y/C documentation: <https://mister-devel.github.io/MkDocs_MiSTer/advanced/crt/>
- Tang Primer 25K documentation: <https://wiki.sipeed.com/hardware/en/tang/tang-primer-25k/primer-25k.html>

Reference-encoder documentation:

- AD723: <https://www.analog.com/media/en/technical-documentation/data-sheets/ad723.pdf>
- AD725: <https://www.analog.com/media/en/technical-documentation/data-sheets/AD725.pdf>

These links identify upstream projects and documentation. Release builds must pin exact source revisions rather than relying on the current contents of mutable branches.
