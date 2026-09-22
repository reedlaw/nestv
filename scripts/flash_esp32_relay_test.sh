#!/bin/sh
# Build and upload the first-relay test sketch to the USB-connected XIAO S3.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
pio=${PIO:-$HOME/.platformio/penv/bin/pio}
port=${1:-/dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_94:A9:90:CF:7D:0C-if00}

if [ ! -x "$pio" ]; then
    echo "PlatformIO executable not found: $pio" >&2
    exit 1
fi
if [ ! -e "$port" ]; then
    echo "Serial port not found: $port" >&2
    exit 1
fi

exec "$pio" run -d "$root/firmware/esp32_relay_test" -t upload --upload-port "$port"
