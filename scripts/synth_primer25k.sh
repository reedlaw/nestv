#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
local_gowin="$root/.tools/gowin/1.9.12.03/IDE/bin/gw_sh"

if [ -n "${GOWIN_SH:-}" ]; then
	gowin_sh=$GOWIN_SH
elif [ -x "$local_gowin" ]; then
	gowin_sh=$local_gowin
else
	gowin_sh=gw_sh
fi

command -v "$gowin_sh" >/dev/null 2>&1 || {
	echo "error: Gowin shell not found; set GOWIN_SH to the Gowin gw_sh executable" >&2
	echo "expected release tool: Gowin EDA 1.9.12.03" >&2
	exit 127
}

# Gowin bundles an older FreeType that is ABI-incompatible with current
# Fedora Fontconfig. Preloading the matching system library keeps gw_sh
# headless and does not modify the installed toolchain.
if [ -f /etc/fedora-release ] && [ -f /lib64/libfreetype.so.6 ]; then
	if [ -n "${LD_PRELOAD:-}" ]; then
		LD_PRELOAD="/lib64/libfreetype.so.6:$LD_PRELOAD"
	else
		LD_PRELOAD=/lib64/libfreetype.so.6
	fi
	export LD_PRELOAD
fi

# gw_sh links Qt even in batch mode. Use its headless backend unless the
# caller explicitly selected another platform plugin.
QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen}
export QT_QPA_PLATFORM
if [ "$QT_QPA_PLATFORM" = offscreen ]; then
	unset DISPLAY
fi
gowin_bin=$(CDPATH= cd -- "$(dirname -- "$gowin_sh")" && pwd)
QT_PLUGIN_PATH=${QT_PLUGIN_PATH:-"$gowin_bin/../plugins/qt"}
export QT_PLUGIN_PATH
QT_IM_MODULE=${GOWIN_QT_IM_MODULE:-compose}
export QT_IM_MODULE
QT_OPENGL=${QT_OPENGL:-software}
QT_QUICK_BACKEND=${QT_QUICK_BACKEND:-software}
QT_XCB_GL_INTEGRATION=${QT_XCB_GL_INTEGRATION:-none}
QTWEBENGINE_CHROMIUM_FLAGS=${QTWEBENGINE_CHROMIUM_FLAGS:---disable-gpu}
QTWEBENGINE_DISABLE_SANDBOX=${QTWEBENGINE_DISABLE_SANDBOX:-1}
export QT_OPENGL QT_QUICK_BACKEND QT_XCB_GL_INTEGRATION
export QTWEBENGINE_CHROMIUM_FLAGS QTWEBENGINE_DISABLE_SANDBOX

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

exec "$gowin_sh" "$project"
