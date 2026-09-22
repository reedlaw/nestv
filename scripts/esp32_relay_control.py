#!/usr/bin/env python3
"""Send one command to the USB-connected Primer Dock relay controller."""

import argparse
from pathlib import Path
import sys
import time

import serial


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("on", "off", "poweron", "poweroff", "status", "info", "otainfo"))
    parser.add_argument("--port", help="ESP32 USB serial port; auto-detected if omitted")
    args = parser.parse_args()

    if args.port:
        port = args.port
    else:
        matches = sorted(Path("/dev/serial/by-id").glob("usb-Espressif_USB_JTAG_serial_debug_unit_*-if00"))
        if len(matches) != 1:
            parser.error(f"expected one ESP32 USB serial port, found {len(matches)}; use --port")
        port = str(matches[0])

    try:
        with serial.Serial(port, 115200, timeout=2) as device:
            time.sleep(0.3)
            device.reset_input_buffer()
            device.write(("\n" + args.command.upper() + "\n").encode("ascii"))
            reply = device.readline().decode("ascii", errors="replace").strip()
    except serial.SerialException as error:
        print(f"serial error: {error}", file=sys.stderr)
        return 1

    if not reply:
        print("ESP32 did not reply", file=sys.stderr)
        return 1
    print(reply)
    return 0 if reply.startswith(("BOOT=", "WIFI_MODE=", "OTA_HOST=")) else 1


if __name__ == "__main__":
    sys.exit(main())
