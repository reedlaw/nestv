#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
obj_dir="$root/build/verilator/nestang_video"

command -v verilator >/dev/null 2>&1 || {
	echo "error: Verilator is required" >&2
	exit 127
}

mkdir -p "$obj_dir"
verilator \
	--binary \
	--timing \
	--top-module tb_nestang_video_adapter \
	-Mdir "$obj_dir" \
	-o Vtb_nestang_video_adapter \
	-Wno-fatal \
	-Wno-PROCASSINIT \
	-Wno-TIMESCALEMOD \
	-Wno-UNUSEDSIGNAL \
	-Wno-WIDTHEXPAND \
	-Wno-WIDTHTRUNC \
	"$root/build/upstream/yc_out.sv" \
	"$root/rtl/video/nes_palette.sv" \
	"$root/rtl/video/nestang_video_adapter.sv" \
	"$root/sim/nestang_video/tb_nestang_video_adapter.sv"
"$obj_dir/Vtb_nestang_video_adapter"
