#!/usr/bin/env python3
"""Save the S3's OTA login locally after its first USB firmware upload."""

import json
import os
from pathlib import Path
import sys
import tempfile
import time

import serial


ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / ".local" / "esp32-relay-ota.json"


def main() -> int:
    ports = sorted(Path("/dev/serial/by-id").glob("usb-Espressif_USB_JTAG_serial_debug_unit_*-if00"))
    if len(ports) != 1:
        print(f"expected one ESP32 USB serial port, found {len(ports)}", file=sys.stderr)
        return 1
    try:
        with serial.Serial(str(ports[0]), 115200, timeout=2) as device:
            time.sleep(0.3)
            device.reset_input_buffer()
            device.write(b"\nOTAINFO\n")
            reply = ""
            for _ in range(5):
                line = device.readline().decode("ascii", errors="replace").strip()
                if "OTA_HOST=" in line:
                    reply = line[line.index("OTA_HOST="):]
                    break
    except serial.SerialException as error:
        print(f"serial error: {error}", file=sys.stderr)
        return 1

    values = dict(part.split("=", 1) for part in reply.split() if "=" in part)
    if not all(key in values for key in ("OTA_HOST", "OTA_PORT", "OTA_PASSWORD")):
        print("ESP32 did not report ready OTA service", file=sys.stderr)
        return 1
    if len(values["OTA_PASSWORD"]) != 24 or values["OTA_PORT"] != "3232":
        print("unexpected OTA configuration", file=sys.stderr)
        return 1

    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix="ota-", dir=CONFIG.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump({"host": values["OTA_HOST"], "port": 3232,
                       "password": values["OTA_PASSWORD"]}, handle)
            handle.write("\n")
        os.replace(temporary_name, CONFIG)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)
    print(f"OTA login saved to {CONFIG} (owner-only permissions).")
    print(f"Current S3 address: {values['OTA_HOST']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
