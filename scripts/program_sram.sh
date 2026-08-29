#!/bin/sh
# SRAM-program a bitstream onto the Tang Primer 25K over JTAG.
#
# SRAM configuration is volatile — this must be re-run after every power cycle.
#
#   scripts/program_sram.sh [bitstream.fs]
#
# Defaults to impl/pnr/nestv_primer25k_m3.fs. Override the cable with
# LOCATION=<n>; by default the location is taken from --scan-cables, since
# passing only --operation_index fails with "Cable failed to open via the
# channel" and the location changes between plug-ins.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cli=$root/.tools/gowin/1.9.12.03/Programmer/bin/programmer_cli
device=${DEVICE:-GW5A-25A}
fs=${1:-$root/impl/pnr/nestv_primer25k_m3.fs}

[ -x "$cli" ] || { echo "error: $cli not found" >&2; exit 127; }
case $fs in /*) ;; *) fs=$root/$fs ;; esac
[ -f "$fs" ] || { echo "error: bitstream not found: $fs" >&2; exit 1; }

location=${LOCATION:-}
if [ -z "$location" ]; then
	# " Cable found:  USB Debugger A/0/4385/null (USB location:4385)"
	location=$("$cli" --scan-cables 2>/dev/null |
		sed -n 's/.*USB location:\([0-9][0-9]*\).*/\1/p' | head -1)
fi
[ -n "$location" ] || {
	echo "error: no JTAG cable found — is the board connected to this PC?" >&2
	echo "note: TangCore only runs when the board is NOT connected to a PC," >&2
	echo "      so these two modes are mutually exclusive by design." >&2
	exit 1
}

echo "==> SRAM programming $(basename "$fs") via cable at location $location"
"$cli" -d "$device" -r 2 --fsFile "$fs" --location "$location" 2>&1 |
	tr '\r' '\n' | grep -vE '^Programing: |^Programming\.\.\.: .*[0-9]%'
