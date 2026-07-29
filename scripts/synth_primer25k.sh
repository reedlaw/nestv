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
cd "$root"
exec "$gowin_sh" scripts/gowin/primer25k.tcl
