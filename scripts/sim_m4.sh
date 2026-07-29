#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
obj_dir="$root/build/verilator/video_dac_quantizer"

command -v verilator >/dev/null 2>&1 || {
	echo "error: Verilator is required" >&2
	exit 127
}

mkdir -p "$obj_dir"
verilator \
	--binary \
	--timing \
	--top-module tb_video_dac_quantizer \
	-Mdir "$obj_dir" \
	-o Vtb_video_dac_quantizer \
	-Wno-fatal \
	-Wno-TIMESCALEMOD \
	"$root/rtl/video/video_dac_quantizer.sv" \
	"$root/sim/nestang_video/tb_video_dac_quantizer.sv"
"$obj_dir/Vtb_video_dac_quantizer"
