# Primer Dock ISP relay test

The XIAO ESP32-S3 Plus is programmed over its USB connection. Its Grove Base
`D0/A0` socket controls the ISP strap relay; `D1/A1` controls the second relay
for a dry-contact test. Its load terminals remain unwired. The S3 reports state
at 115200 baud using `ON`/`OFF` for the boot relay and
`POWERON`/`POWEROFF` for the second relay, plus `STATUS`, `INFO`, `OTAINFO`,
and `HELP`. Commands are line terminated
and case insensitive. Every reset starts with both GPIO outputs low. The relay
input can float before firmware starts, so use a physical pull-down if reset
behavior must be guaranteed.

This laptop's S3 has been identified as an ESP32-S3 with 16 MB flash at
`/dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_94:A9:90:CF:7D:0C-if00`.
The firmware was uploaded and `STATUS` and `OFF` both replied
`BOOT=OPEN POWER=LOW`. The user confirmed on 2026-09-22 that the isolated
relay contacts open and close as commanded by the S3. With the relay closing
J7 pins 5 and 7 before Dock power-up, the Dock then enumerated on this laptop
as USB `349b:6160` (Bouffalo CDC DEMO) at `/dev/ttyACM1`. This proves
relay-controlled BL616 ISP entry. No Dock flash write was performed.

The corrected Wi-Fi build was uploaded on 2026-09-22. Initially it fell back
to its access point because the S3 antenna was not attached. After the antenna
was installed, the S3 joined `ATTSXsK5YS` and reported
`WIFI_MODE=STA` with address `192.168.1.171`. The laptop fetched the relay page
over that network with HTTP 200, and the user confirmed that it opens in a
browser. Web requests now exercise both relay outputs, but Dock ISP entry
initiated through the page still needs physical validation.

OTA support was added and tested on 2026-09-22. A USB upload installed the
receiver. A password-protected OTA transfer of the same application image
then completed over `ATTSXsK5YS`; the S3 rebooted, its authenticated relay
page returned, and USB serial reported `BOOT=OPEN POWER=LOW`. The stable
`nestv-relay-s3.local` name resolved on this laptop. Closing the boot relay
made `OTAINFO` report OTA unavailable; reopening the relay restored OTA.

The updated firmware was uploaded by OTA on 2026-09-22. Its relay page returned
after reboot. Live web checks confirmed that `nestv-relay-s3.local` resolves
with the second relay output HIGH and with the boot relay CLOSED. Attempting
to change the boot relay while the second relay was active returned HTTP 409.
Both outputs were restored to `BOOT=OPEN POWER=LOW`. Continuity across the
second relay's unwired contacts still needs a meter check.

The two-switch page was uploaded by OTA and checked on the live S3. With the
power relay closed, the programming-mode switch was disabled and a direct boot
relay request returned HTTP 409. The controls also displayed the programmed
boot state through a power-relay cycle. Both outputs were left open.

## Laptop commands

Run these files from the repository root. The control script requires Python
`pyserial`; it is installed on this laptop.

```sh
scripts/esp32_relay_control.py status
scripts/esp32_relay_control.py on
scripts/esp32_relay_control.py off
scripts/esp32_relay_control.py poweron
scripts/esp32_relay_control.py poweroff
scripts/esp32_relay_control.py info
scripts/esp32_relay_wifi_setup.py
scripts/flash_esp32_relay_test.sh
scripts/esp32_relay_ota_setup.py
scripts/flash_esp32_relay_ota.py
```

The flashing script uses the PlatformIO installation and detected USB port on
this laptop. Pass a different serial port as its first argument when needed.

## OTA updates of the S3

The first USB firmware upload with OTA support is complete. The S3 generated
an independent 24-character OTA password in NVS. While USB was connected,
`esp32_relay_ota_setup.py` saved the OTA address and password to
`.local/esp32-relay-ota.json`, mode `0600`. That file is git-ignored and must
stay on the laptop used for OTA uploads. Never copy its contents into a commit
or chat message.

For future S3 application updates, run `flash_esp32_relay_ota.py` from the
repository root. It builds the current application and sends it over the
existing Wi-Fi, then waits for the authenticated relay page to return. It
resolves `nestv-relay-s3.local` first and falls back to the saved IP. If both
addresses fail after a router change, pass the current IP with `--host`.

OTA is available only while the S3 is on the existing Wi-Fi network and both
relays are open. Closing either relay stops the OTA listener; reopening both
starts the listener again. mDNS remains active while either relay is closed,
so `nestv-relay-s3.local` continues to resolve on the local network. The update
callback drives both relay outputs low,
and a successful update reboots the S3 with both outputs low. Leave Dock power
disconnected for firmware-maintenance work. This updates only the S3
application, not its bootloader or partition table and not the Dock BL616.
The USB flashing script remains the recovery path.

## Wi-Fi relay control

Install the included Wi-Fi/BT antenna on the XIAO ESP32-S3 Plus U.FL connector
with S3 power disconnected. Seeed warns that Wi-Fi may fail without it. The
board uses 2.4 GHz Wi-Fi; this laptop sees `ATTSXsK5YS` on a compatible
2.4 GHz WPA2 access point.

Run the setup script above once while the S3 is connected over USB. It prompts
locally for the existing Wi-Fi SSID and password, sends them to the S3, and
does not save them in the repository. The S3 stores them in its NVS, restarts,
and joins that network. The boot relay must be open to accept configuration.
The setup script checks the result after the restart. Use the `info` action to
display the current mode,
page address, browser user name, and generated browser password. The browser
password is different from the Wi-Fi password. Open the reported address from
the same Wi-Fi network; no network switching is needed in normal operation.

If no network has been configured or joining fails, the S3 advertises its own
WPA2 recovery access point. `info` then reports `WIFI_MODE=AP` and its SSID,
password, and page address. Re-run the local setup script to correct the
network credentials. On first boot the S3 generates a 16-character browser
password, also used for the recovery access point, and saves it in NVS.

After provisioning, the S3 may be moved from laptop USB to a normal 5 V USB-C
wall charger. First remove Dock power and leave the boot relay open. Moving
power reboots the S3, which starts with both relay outputs low and rejoins the
saved Wi-Fi network. The page address is assigned by the router and may change
after a reboot; this board reported `192.168.1.171` during the first test.

The page has two switches that show the current relay states. Turn the power
relay off before changing programming mode; the programming-mode switch is
disabled while the power relay is closed, and the firmware rejects an unsafe
request from a stale page. The second relay's contacts are still unwired, so
its switch is currently only a dry-contact test. It cannot disconnect Dock
power yet: disconnect Dock power manually before changing programming mode.
The page requires the generated browser password. USB serial remains available
as a fallback.

For the first wireless check, leave the Dock unpowered and watch the meter
across the isolated relay contacts while operating the switches. After that
passes, repeat the ISP-enumeration test below with Wi-Fi controlling the boot
relay. Disconnect Dock power before reopening the contact.

## Physical validation

1. **Passed 2026-09-22:** With the Primer Dock disconnected, the user checked
   open contacts with `off` and closed contacts with `on`.
2. With Dock power removed and the relay set to `off`, connect relay `COM` to Dock J7 pin 5
   (`JTAG_TDO`) and `NO` to J7 pin 7 (`+3V3`). These are dry contacts; do not
   connect either contact to ESP32 GPIO or power.
3. **Passed 2026-09-22:** Power the S3 from the laptop. Keep the Dock unpowered, send `on`, then
   connect the Dock USB-C port directly to the programming laptop. ISP mode
   should enumerate as USB `349b:6160` and a new `/dev/ttyACM*`, rather than
   the normal FTDI debugger. No flash write is needed for this test.
4. Remove Dock power, send `off`, and check the contacts open before the next
   normal boot.
5. With the second relay's load terminals disconnected from everything, measure
   resistance across `COM` and `NO`. Send `poweron` and expect near zero ohms;
   send `poweroff` and expect an open circuit. Leave it open afterward. This
   does not validate any Dock power wiring.

The ESP32 cannot cycle Dock power in this first test; the USB-C connection is
the manual Dock power switch. See [the harness wiring plan](../../docs/test-harness.md)
for J7 orientation and the wider power-routing constraints.
