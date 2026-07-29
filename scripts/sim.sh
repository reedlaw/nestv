#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
obj_dir="$root/build/verilator/yc_out"

command -v verilator >/dev/null 2>&1 || {
	echo "error: Verilator is required" >&2
	exit 127
}

mkdir -p "$obj_dir"
verilator \
	--binary \
	--timing \
	--top-module tb_yc_out \
	-Mdir "$obj_dir" \
	-o Vtb_yc_out \
	-Wno-fatal \
	-Wno-INITIALDLY \
	-Wno-PROCASSINIT \
	-Wno-TIMESCALEMOD \
	-Wno-UNUSEDSIGNAL \
	-Wno-WIDTHEXPAND \
	-Wno-WIDTHTRUNC \
	"$root/build/upstream/yc_out.sv" \
	"$root/sim/yc_out/tb_yc_out.sv"
"$obj_dir/Vtb_yc_out"
