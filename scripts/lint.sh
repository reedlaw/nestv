#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

command -v verilator >/dev/null 2>&1 || {
	echo "error: Verilator is required" >&2
	exit 127
}

verilator \
	--lint-only \
	--timing \
	--Wall \
	-Wno-DECLFILENAME \
	-Wno-PROCASSINIT \
	-Wno-TIMESCALEMOD \
	-Wno-UNUSEDSIGNAL \
	-Wno-WIDTHEXPAND \
	-Wno-WIDTHTRUNC \
	"$root/build/upstream/yc_out.sv" \
	"$root/sim/yc_out/tb_yc_out.sv"
