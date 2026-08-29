#!/bin/sh
# Flash TangCore's BL616 firmware onto a Tang Primer 25K Dock.
#
# Writes two images over the BL616's own USB bootloader:
#   0x00000  bl616_fpga_partner_primer25k.bin   Sipeed stock debugger firmware
#   0x40000  tangcore_primer25k.bin             TangCore application
#
# Set APP=debug to write tangcore_primer25k_debug_uart.bin instead — the
# diagnostic build that mirrors overlay_status(), printf() and a 1 Hz
# heartbeat to J7 pin 2 (JTAG TDI) at 9600 8N1. See
# firmware/tangcore/firmware-bl616/DEBUG_UART.md.
#
# This mirrors flash_primer25k.ini, which BLDevCube/Bouffalo Flash Cube uses on
# Windows. Erase is per-section (the tool's --erase is a *chip* erase and is
# deliberately never passed).
#
# Before running:
#   1. scripts/fetch_tangcore_release.sh
#   2. Put the BL616 in boot mode (the Primer has no BOOT button): short J7
#      pin 5 (TDO) to J7 pin 7 (3V3) -- adjacent holes in the row of the
#      Debugger header furthest from the board edge, nearest the USB-C end --
#      while connecting USB, then release. This is the short shown in
#      firmware/tangcore/docs/user-guide/primer25k.jpg and printed on the Dock
#      schematic as "connect JTAG_TDO to 3V3 before power up".
#      The board should then enumerate as 349b:6160 "Bouffalo CDC DEMO" on a
#      new /dev/ttyACM*, rather than the usual 0403:6010 FTDI debugger.
#
# Recovery: boot mode lives in the BL616's mask ROM and does not depend on
# flash contents, so a failed write can always be retried. The 0x0 image is
# Sipeed's own debugger firmware, so this does not replace the debugger with
# anything foreign.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fw=$root/build/tangcore/firmware
work=$root/build/tangcore/flash

[ -f "$fw/tangcore_primer25k.bin" ] || {
	echo "error: $fw/tangcore_primer25k.bin not found" >&2
	echo "run scripts/fetch_tangcore_release.sh first" >&2
	exit 1
}

command -v bflb-iot-tool >/dev/null 2>&1 || {
	echo "error: bflb-iot-tool not found; pip install --user bflb-iot-tool" >&2
	exit 127
}

# bflb-iot-tool imports telnetlib unconditionally, but only uses it from its
# OpenOCD backend. telnetlib left the stdlib in Python 3.13, so supply a stub
# rather than pinning an old interpreter.
mkdir -p "$work"
if ! python3 -c "import telnetlib" >/dev/null 2>&1; then
	cat > "$work/telnetlib.py" <<'EOF'
"""Stub for the stdlib telnetlib removed in Python 3.13.

bflb-iot-tool imports this unconditionally but only uses it from its OpenOCD
backend, which the serial bootloader path never touches.
"""


class Telnet:
    def __init__(self, *args, **kwargs):
        raise NotImplementedError("telnetlib stub: OpenOCD backend unavailable")
EOF
	PYTHONPATH=${PYTHONPATH:+$PYTHONPATH:}$work
	export PYTHONPATH
fi

port=${PORT:-}
if [ -z "$port" ]; then
	for candidate in /dev/ttyACM*; do
		[ -e "$candidate" ] || continue
		port=$candidate
		break
	done
fi
[ -n "$port" ] || {
	echo "error: no /dev/ttyACM* found — is the BL616 in boot mode?" >&2
	echo "short the two test points near the BL616 while connecting USB" >&2
	echo "override with PORT=/dev/ttyXXX $0" >&2
	exit 1
}
echo "using port $port"

baud=${BAUD:-2000000}
backup=$root/build/tangcore/backup

tool() {
	bflb-iot-tool --chipname bl616 --interface uart --port "$port" \
		--baudrate "$baud" "$@"
}

# Read back everything the flash steps below could touch, before touching it.
# bflb-iot-tool hardcodes the output to flash.bin inside its own package
# directory regardless of cwd, so collect it from there.
mkdir -p "$backup"
dump=$backup/bl616-flash-0x0-0x60000.bin
echo "==> backing up flash 0x0-0x60000"
tool --read --start 0x0 --end 0x60000 >/dev/null
pkg=$(python3 -c 'import bflb_iot_tool, os; print(os.path.dirname(bflb_iot_tool.__file__))')
[ -f "$pkg/flash.bin" ] || { echo "error: read produced no flash.bin" >&2; exit 1; }
mv "$pkg/flash.bin" "$dump"
echo "    saved $dump"

flash() {
	addr=$1
	file=$2
	echo
	echo "==> writing $(basename "$file") at $addr"
	tool --single --addr "$addr" --firmware "$file"
}

# The image at 0x0 is Sipeed's stock debugger firmware and is what provides
# JTAG access to the FPGA — the only route for programming it. TangCore ships
# an identical copy, so on a board that already has it there is nothing to
# gain by rewriting it, and a failed write would cost JTAG. Compare and skip.
partner=$fw/bl616_fpga_partner_primer25k.bin
size=$(wc -c < "$partner")
if head -c "$size" "$dump" | cmp -s - "$partner"; then
	echo "==> 0x0 already matches bl616_fpga_partner_primer25k.bin; skipping"
else
	echo "==> 0x0 differs from the stock image"
	if [ "${FLASH_PARTNER:-0}" = 1 ]; then
		flash 0x0 "$partner"
	else
		echo "    not writing it. Re-run with FLASH_PARTNER=1 to update 0x0," >&2
		echo "    having confirmed $dump is a usable backup." >&2
	fi
fi

case ${APP:-stock} in
debug)	app=$fw/tangcore_primer25k_debug_uart.bin ;;
stock)	app=$fw/tangcore_primer25k.bin ;;
*)	echo "error: APP must be 'stock' or 'debug'" >&2; exit 2 ;;
esac
[ -f "$app" ] || { echo "error: $app not found" >&2; exit 1; }

echo "==> writing $(basename "$app") to 0x40000"
flash 0x40000 "$app"

cat <<'EOF'

Done. Verify next, in this order:

1. Reconnect to the PC and SRAM-program the M3 bitstream as usual
   (make synth-primer25k output, programmer_cli --operation_index 2).
   The HDMI boot screen coming back proves JTAG survived the flash.

2. Power the board standalone through the powered hub with the media
   attached. TangCore should load cores/primer25k/monitor.bin over JTAG
   by itself and show its menu on HDMI.

Do not power the board from a PC when running TangCore — the Sipeed
firmware enters JTAG/debug mode whenever it detects a host.
EOF
