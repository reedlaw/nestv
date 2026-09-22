# Primer 25K test harness

This is the single reference for the physical test harness around the Tang
Primer 25K Dock. It records what is connected today, what has been proven on
hardware, and what is still a future automation project. It is deliberately
conservative: a proposed connection is not a tested connection.

## Purpose and boundaries

The harness supports repeatable Primer/TangCore/NesTV bring-up without loose,
unlabelled wiring. Its immediate jobs are:

- run the known-good TangCore configuration from removable USB storage;
- provide an ESP32-S3 Wi-Fi control and logging platform;
- allow the BL616 ISP boot strap to be closed remotely; and
- leave a safe place to add controlled Dock power later.

It does **not** yet provide one-step remote BL616 flashing. The required
USB data/power routing has not been selected or validated. The S3 is a
candidate networked programming host, but its BL616 programming firmware has
not been implemented. A separate Linux host is an alternative, not a requirement.

## Status key

| Mark | Meaning |
| --- | --- |
| **Proven** | Recorded as working on the physical Dock. |
| **Build now** | Uses parts on hand or confirmed ordered; verify before relying on it. |
| **Planned** | Intended design, but firmware or hardware is missing. |

## Hardware inventory

| Item | Status | Harness role |
| --- | --- | --- |
| Tang Primer 25K Dock and J7 2x4 header | **Proven** | Device under test; J7 exposes the BL616 debugger signals. |
| XIAO ESP32-S3 Plus | **Proven for Wi-Fi relay control and OTA** | Harness controller; BL616 programming and USB storage emulation remain future work. |
| Grove Base for XIAO | **Proven for relay control** | Connector base for the S3 and Grove modules. |
| Grove Relay, two | **Boot contacts proven; power contacts untested** | Boot relay entered BL616 ISP; second relay responds to controller commands but its load terminals remain unwired. |
| Grove conversion cables | **Build now** | UART and general harness wiring as required. |
| USB-C OTG power-injection splitter, powered hub, charger, USB drive, N64 adapter | **Proven together** | Current known-good TangCore run topology. |
| XIAO Debug Mate | Existing | Optional, separate diagnostic aid. |

The S3's USB mass-storage emulation remains **planned**. Wi-Fi control of both
relay outputs and S3 application OTA updates have been tested. Physical
continuity of the second relay and Dock ISP entry initiated over Wi-Fi still
need testing.
Do not assume that buying the S3 makes it a
USB-C power-delivery controller, a BL616 programmer, or a USB switch.

## Physical construction

Build an open fixture on a small non-conductive base (acrylic, plywood, or a
project-box lid). Secure the Grove Base/S3 and both relays with standoffs or
strong foam tape. Keep the Primer Dock beside the fixture rather than mounting
it underneath it, so the Dock's USB-C, HDMI, and PMOD connectors remain
accessible.

Label every cable at both ends. Keep relay contact wires short, use cable ties
for strain relief, and keep them away from the USB-C and HDMI connectors. Do
not use a solderless breadboard for relay contact or power wiring.

## Relay assignment

The selected Base ports and firmware GPIO assignments are:

| Function | Grove Base port | XIAO pin | State when inactive |
| --- | --- | --- | --- |
| BL616 ISP boot strap | `D0/A0` | `D0` | Relay contacts open. |
| Dock-power control | `D1/A1` | `D1` | Relay contacts open; no load wiring installed yet. |

Firmware must initialize `D0` and `D1` as outputs driven low before enabling
any automation. Confirm the delivered relay revision works from the Base's
signal/power level before connecting it to the Dock.

### Boot-strap relay — ISP entry proven

The Dock schematic's ISP mode condition is `JTAG_TDO` tied to `+3V3` **before
power-up**. On J7 this is:

| J7 pin | Signal | Relay terminal |
| ---: | --- | --- |
| 5 | `JTAG_TDO` | `COM` (or either terminal on a two-terminal relay) |
| 7 | `+3V3` | `NO` (or the other terminal) |

Use two female Dupont jumper leads on the header pins. At the other end, strip
only enough insulation for the relay screw terminal; no bare conductor should
remain outside the terminal. The relay contact is unpolarized. Do not connect
these contact wires to XIAO GPIO, 5 V, or ground: the relay replaces the
manual jumper cap and must remain electrically isolated.

Before connecting the contact leads to J7, measure across the isolated relay
output terminals. Keep the Dock disconnected; power the S3/relay control side
only when testing the active state. Measuring across connected Dock pins can
include board circuitry and is not a valid isolated-contact test:

| S3 `D0` state | Expected resistance across isolated relay contacts |
| --- | --- |
| Low / relay inactive | Open circuit |
| High / relay active | Near zero ohms |

ISP sequence: turn Dock power off, close the boot relay, apply Dock power,
perform the flash operation, turn Dock power off, open the relay, then apply
power for normal boot.

**2026-09-22 physical result:** The user confirmed the isolated boot-relay
contacts open and close as commanded by the S3. With the relay joining J7
pins 5 and 7 before Dock power-up, the laptop enumerated USB `349b:6160`
(Bouffalo CDC DEMO) on `/dev/ttyACM1`. This validates relay-controlled BL616
ISP entry. No Dock flash write was performed. The Dock-power relay remains
unwired, and its contact continuity has not been measured.

### Dock-power relay — reserve; do not wire the load yet

The second relay is intended to interrupt the Dock's only deliberate 5 V
source. A relay must switch only **VBUS/+5 V**, never ground. It cannot safely
provide USB-C switching by itself: USB-C also has data and CC role-detection
connections, and the powered hub or programmer can be alternate power paths.

The current confirmed normal topology is:

```text
standalone charger -> OTG splitter charging/power input
OTG splitter USB-C plug -> Primer Dock USB-C
OTG splitter USB-A data leg -> powered hub upstream
powered-hub downstream -> USB drive and N64 adapter
Primer Dock HDMI -> display
```

Keep this topology unchanged for known-good runs. Do not cut a USB-C cable,
put a relay into a random USB cable, or build a female-to-female USB-C adapter
from passive breakouts. Those approaches do not establish a safe, controlled
USB-C role/power path.

Before adding a power relay, the design must name the exact 5 V source and
prove that the hub and programmer cannot backfeed the Dock when the relay is
open. Automatic switching needs a defined data route and controlled power path.
If switching USB-C connectors, account for their CC wiring and orientation;
a USB-C/PD controller is not automatically required for every fixed 5 V design.
A fixed USB 2.0 data mux arrangement is another candidate, but no circuit or
specific switch has been selected or validated. The two mechanical relays
are for boot and power, not USB D+/D− switching.

## USB, programming, and Wi-Fi modes

### Normal TangCore run — **Proven**

Use the OTG splitter/powered-hub topology above and a standalone charger. Do
not substitute a PC USB data connection for the standalone charger in this
known-good topology. The boot strap and running firmware determine BL616 mode;
a PC cable alone does not guarantee entry into the ROM ISP bootloader. The successful 2026-09-04 test loaded
the packaged `monitor.bin` and NESTang core, ran `Baseball (USA, Europe).nes`,
and accepted the USB-N64 adapter.

### Manual BL616 flashing — **Proven**

Disconnect the normal OTG topology and connect the programming host to the
Dock USB-C port. Use the boot strap above to enter ISP mode. The established
flash command writes only the application at `0x40000`; it must not overwrite
the stock partner firmware at `0x0`. Restore the normal topology after
flashing.

### Wi-Fi control — **Controller and OTA proven; physical checks pending**

The S3 now hosts a password-protected web page with two stateful relay switches.
The corrected firmware was uploaded on 2026-09-22. With the S3 antenna
installed and credentials provisioned over USB, it joined the existing
`ATTSXsK5YS` network. The laptop fetched the relay page with HTTP 200, and
the user confirmed that it opens in a browser. The latest switch UI was
uploaded by OTA and tested on the live S3: it disables the programming-mode
switch while the power relay is closed, and the firmware rejects a direct
unsafe request with HTTP 409. The second relay's contact continuity and Dock
ISP entry initiated from the page still need physical testing. `D1` has
controls for a dry-contact test, while its load contacts remain unwired. See
[the relay test instructions](../firmware/esp32_relay_test/README.md).

The S3's application OTA path was proven on 2026-09-22: a USB-installed,
password-protected receiver accepted the same application image over the
existing Wi-Fi, rebooted, and returned the authenticated relay page. Serial
reported the boot relay open afterward. OTA is disabled while either relay is
active. The updated firmware keeps mDNS active when OTA stops. A subsequent
OTA upload and live web checks confirmed that the local name resolves with
each relay active; the boot relay interlock returned HTTP 409 while the second
relay was active. Both outputs were left open. The local upload script and
secret handling are in the relay test instructions.

The S3 and relay outputs were left at `BOOT=OPEN POWER=LOW` after the latest
live check. The power relay cannot disconnect Dock power while its load is
unwired; disconnect Dock power manually before changing programming mode.

The S3 can also receive the optional J7 diagnostic UART when
the diagnostic firmware is installed. J7 pin 2 is the diagnostic transmit
signal and pin 6 is ground; connect it as receive-only, with no S3 transmit or
power wire attached.

The production/source firmware does not currently restore this J7 diagnostic
output, so absence of logs is expected until that firmware work is done.

### One-step remote flashing — **Planned; architecture not finalized**

Discussion review, 2026-09-20: we had identified that the S3 could potentially
replace the laptop as programmer, but explicitly left that as a separate
firmware-development task. We had not designed a complete OTG/programming
switchover circuit. Wireless USB-storage updates and BL616 firmware flashing
are distinct operations.

The S3 has a general-purpose USB OTG controller capable of host or device
operation, and Espressif provides a CDC-ACM host driver. This makes an S3-based
BL616 programmer plausible; it does not establish BL616 ISP compatibility.
The existing laptop flashing script uses `bflb-iot-tool` with a serial transport
and an application offset of `0x40000`. A native S3 programmer must implement
or port the required BL616 handshake, loader/flash protocol, verification,
and error handling. Validate the actual ROM USB descriptors and transport.
Do not assume a generic serial terminal or USB host example performs flashing.

Two software approaches are possible:

- **Standalone S3 programmer:** receive the image over Wi-Fi, validate it,
  enter ISP, and program/verify the BL616 through USB host mode. No Linux host
  is inherently required.
- **S3 USB-to-network bridge:** forward the bootloader's USB serial transport
  to a laptop running the existing tool. Serial-port adaptation, control
  requests, timing, and error handling still need implementation/testing.
  The laptop communicates over Wi-Fi and need not be cabled to the Dock.

A separate networked Linux USB host is another option, not a mandatory purchase.

#### Why USB role switching alone does not complete the harness

Normal operation currently has the Dock as host, with a hub attached. An S3
emulated drive would occupy a downstream hub port. In programming mode the
Dock becomes a USB device and the S3 must become a host. A conventional hub
cannot reverse upstream/downstream direction: the S3 cannot reach the Dock
through that same downstream port just by changing its USB controller mode.

A candidate routing arrangement (conceptual, not a wiring plan) is:

| Mode | Dock USB data route | S3 USB data route |
| --- | --- | --- |
| Run | Hub upstream | Hub downstream, S3 as emulated storage device |
| Program | Direct to S3 | Direct to Dock, S3 as programming host |

Both connections must be rerouted with USB-rated switching, with the hub paths
isolated during programming. A direct S3–Dock link without the intervening hub
could avoid this particular rerouting, but does not accommodate the current
USB controller/drive topology unchanged. It still requires deliberate USB-C
and VBUS design. An ordinary USB sharing switch is not automatically suitable.

The S3 must remain powered while the Dock is off. Its supply, the powered hub,
and the programming connection must not bypass the Dock power switch. The
XIAO USB connector does not itself provide a complete switched host-power/CC
solution merely because the ESP32-S3 supports USB host mode.

#### Target wireless sequence

1. Receive and validate the firmware package; stop storage access cleanly.
2. Remove Dock power and isolate the normal USB paths.
3. Close the ISP strap and select the direct programming route.
4. Start S3 USB host mode and apply controlled Dock power; enumerate the ISP
   device and confirm communication. Release the strap once entry is confirmed.
5. Program and verify the application at `0x40000`, preserving the partner
   firmware at `0x0`. On failure, remain in a recoverable state and report it.
6. Power the Dock off, ensure the strap is open, restore the normal USB routes
   and S3 storage-device mode, then power up for a logged test boot.

This is the intended state sequence, not a tested implementation. Until routing,
power isolation, and programmer firmware are validated, use manual cable swaps.

References:

- [Espressif USB host support and CDC-ACM example](https://docs.espressif.com/projects/esp-usb/en/latest/esp32s3/usb_host.html)
- [Espressif USB device stack and controller/PHY limitations](https://docs.espressif.com/projects/esp-usb/en/latest/esp32s3/usb_device.html)
- [Existing BL616 flashing script](../scripts/flash_bl616_tangcore.sh)

## Bring-up checklist

1. Mount the Base/S3 and relays; label `BOOT / D0` and `POWER / D1`.
2. **Firmware done:** The S3 initializes both pins low and can command each
   relay independently. The second relay still needs a meter continuity check
   across its isolated contacts, with its load terminals disconnected.
3. **Passed:** The boot relay's isolated contacts were checked before wiring
   them to J7 pins 5 and 7.
4. **Baseline recorded 2026-09-04:** The normal USB/HDMI setup worked before
   harness changes. Repeat it after adding new physical wiring.
5. **Passed with USB serial control:** The relay-controlled boot strap entered
   BL616 ISP without a flash write. Repeat this with Wi-Fi control after
   confirming the physical contacts and manual Dock power sequence.
6. Leave the Dock-power relay load terminals empty until the USB-C switching
   and backfeed design has been selected and reviewed.

## Source records

- [Hardware inventory](hardware-inventory.md) is the purchase record and
  distinguishes confirmed purchases from discussed accessories.
- [Bring-up status](bringup.md) records the proven OTG splitter/hub topology
  and the last known-good result.
- [Decision log](decision-log.md) records J7 signal assignments, USB-port
  ownership, and the BL616 ISP strap condition.
- [Development log](dev-log.md) retains the detailed hardware-session
  evidence.
- [TangCore integration](m5-tangcore-integration.md) explains why the Dock's
  USB-C port is shared by BL616 storage and the programming/debug path.
