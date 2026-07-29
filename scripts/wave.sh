#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
obj_dir="$root/build/verilator/yc_out_wave"
wave_dir="$root/build/waves"
wave_file="$wave_dir/yc_out.fst"

command -v verilator >/dev/null 2>&1 || {
	echo "error: Verilator is required" >&2
	exit 127
}

mkdir -p "$obj_dir" "$wave_dir"
verilator \
	--binary \
	--timing \
	--trace-fst \
	--trace-structs \
	--top-module tb_yc_out_wave \
	-Mdir "$obj_dir" \
	-o Vtb_yc_out_wave \
	-Wno-fatal \
	-Wno-INITIALDLY \
	-Wno-PROCASSINIT \
	-Wno-TIMESCALEMOD \
	-Wno-UNUSEDSIGNAL \
	-Wno-WIDTHEXPAND \
	-Wno-WIDTHTRUNC \
	"$root/build/upstream/yc_out.sv" \
	"$root/sim/yc_out/test_patterns.sv" \
	"$root/sim/yc_out/tb_yc_out_wave.sv"

"$obj_dir/Vtb_yc_out_wave" +WAVE="$wave_file"

test -s "$wave_file"
echo "waveform: $wave_file"

if [ "${1:-}" = "--open" ]; then
	command -v gtkwave >/dev/null 2>&1 || {
		echo "error: GTKWave is not installed; open $wave_file in another FST viewer" >&2
		exit 127
	}
	exec gtkwave "$wave_file"
fi
