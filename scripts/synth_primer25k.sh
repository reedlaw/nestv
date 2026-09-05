#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

mkdir -p "$root/build/gowin/primer25k"

# NESTang's pinned HDMI PLL requests a 1485 MHz VCO. Generate an equivalent
# 742.5 MHz / 2 configuration that remains inside the GW5A 700-1400 MHz range.
sed \
	-e 's/ODIV0_SEL = 4;/ODIV0_SEL = 2;/' \
	-e 's/MDIV_SEL = 55;/MDIV_SEL = 27;/' \
	-e 's/MDIV_FRAC_SEL = 0;/MDIV_FRAC_SEL = 4;/' \
	"$root/rtl/core/nestang/src/plla/gowin_pll_hdmi.v" \
	> "$root/build/gowin/primer25k/gowin_pll_hdmi_m3.v"

cd "$root"
target=${1:-m3}
case "$target" in
	m0) project=scripts/gowin/primer25k.tcl ;;
	m3) project=scripts/gowin/primer25k_m3.tcl ;;
	*)
		echo "error: unknown synthesis target: $target" >&2
		exit 2
		;;
esac

exec "$root/scripts/run_gowin.sh" "$project"
