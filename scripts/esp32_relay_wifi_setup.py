#!/usr/bin/env python3
"""Store existing Wi-Fi credentials on the USB-connected ESP32 relay controller."""

import getpass
from pathlib import Path
import sys
import time

import serial


def main() -> int:
    matches = sorted(Path("/dev/serial/by-id").glob("usb-Espressif_USB_JTAG_serial_debug_unit_*-if00"))
    if len(matches) != 1:
        print(f"expected one ESP32 USB serial port, found {len(matches)}", file=sys.stderr)
        return 1

    ssid = input("Existing Wi-Fi network name (SSID): ")
    password = getpass.getpass("Wi-Fi password: ")
    ssid_bytes = ssid.encode("utf-8")
    password_bytes = password.encode("utf-8")
    if not 1 <= len(ssid_bytes) <= 32 or not 8 <= len(password_bytes) <= 63:
        print("SSID must be 1–32 bytes and password 8–63 bytes", file=sys.stderr)
        return 1
    if b"\t" in ssid_bytes + password_bytes or b"\n" in ssid_bytes + password_bytes:
        print("SSID and password cannot contain tabs or newlines", file=sys.stderr)
        return 1

    try:
        with serial.Serial(str(matches[0]), 115200, timeout=3) as device:
            time.sleep(0.3)
            device.reset_input_buffer()
            device.write(b"\nWIFI\t" + ssid_bytes + b"\t" + password_bytes + b"\n")
            reply = device.readline().decode("ascii", errors="replace").strip()
    except serial.SerialException as error:
        print(f"serial error: {error}", file=sys.stderr)
        return 1

    if reply != "OK Wi-Fi configured; restarting":
        print(reply or "ESP32 did not reply", file=sys.stderr)
        return 1
    print("Credentials saved. Checking whether the ESP32 joins your Wi-Fi...")
    deadline = time.monotonic() + 35
    while time.monotonic() < deadline:
        time.sleep(2)
        try:
            with serial.Serial(str(matches[0]), 115200, timeout=2) as device:
                device.reset_input_buffer()
                device.write(b"INFO\n")
                info = device.readline().decode("ascii", errors="replace").strip()
        except serial.SerialException:
            continue
        if info.startswith("WIFI_MODE=STA "):
            print("Joined your existing Wi-Fi network.")
            print(info)
            return 0
        if info.startswith("WIFI_MODE=AP "):
            print("ESP32 did not join the network; recovery access point is active.", file=sys.stderr)
            print("Check the Wi-Fi password and antenna connection, then retry.", file=sys.stderr)
            return 2
    print("No Wi-Fi result from ESP32; use the control script's info action", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
