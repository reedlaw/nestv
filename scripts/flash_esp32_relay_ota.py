#!/usr/bin/env python3
"""Build and upload the S3 relay firmware over the existing Wi-Fi network."""

import argparse
import json
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request


ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "firmware" / "esp32_relay_test"
CONFIG = ROOT / ".local" / "esp32-relay-ota.json"
PIO = Path.home() / ".platformio" / "penv" / "bin" / "pio"
ESPOTA = Path.home() / ".platformio" / "packages" / "framework-arduinoespressif32" / "tools" / "espota.py"
IMAGE = PROJECT / ".pio" / "build" / "xiao_esp32s3" / "firmware.bin"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", help="current S3 IP address if it changed")
    args = parser.parse_args()
    try:
        config = json.loads(CONFIG.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        parser.error(f"OTA login unavailable; run the USB OTA setup script first: {error}")
    if args.host:
        host = args.host
    else:
        try:
            host = socket.gethostbyname("nestv-relay-s3.local")
        except OSError:
            host = config["host"]
    if not PIO.is_file() or not ESPOTA.is_file():
        parser.error("PlatformIO or its ESP OTA uploader is missing")

    print("Building S3 application image...", flush=True)
    subprocess.run([str(PIO), "run", "-d", str(PROJECT)], check=True)
    print(f"Uploading application to {host} over Wi-Fi...", flush=True)
    subprocess.run([sys.executable, str(ESPOTA), "-i", host, "-p", str(config["port"]),
                    "-a", config["password"], "-f", str(IMAGE)], check=True)

    print("Waiting for the relay page to return after the S3 reboot...", flush=True)
    deadline = time.monotonic() + 25
    while time.monotonic() < deadline:
        try:
            urllib.request.urlopen(f"http://{host}/", timeout=2)
        except urllib.error.HTTPError as error:
            if error.code == 401:
                print("S3 rebooted; authenticated relay page is responding.")
                return 0
        except (OSError, urllib.error.URLError):
            pass
        time.sleep(1)
    print("Upload completed, but the relay page did not respond after reboot", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
