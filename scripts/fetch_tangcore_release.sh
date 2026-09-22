#!/bin/sh
# Fetch and verify TangCore release v0.7 and lay out its Primer 25K artifacts.
#
# v0.7 is the only TangCore release that ships Primer 25K binaries; v0.8 and
# v0.9 dropped the board. See docs/m5-tangcore-integration.md.
#
# Produces, under build/tangcore/:
#   firmware/   BL616 images to flash (see scripts/flash_bl616_tangcore.sh)
#   media/      copy this tree onto the USB drive or microSD card
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=$root/build/tangcore
url=https://github.com/nand2mario/tangcore/releases/download/v0.7/tangcore-0.7.zip
sha=885ab987908698512907dc298d33f45c5a97e944a4680801c69b89c629d011ca

mkdir -p "$out"
zip=$out/tangcore-0.7.zip

if [ ! -f "$zip" ]; then
	echo "fetching $url"
	curl -fsSL -o "$zip.part" "$url"
	mv "$zip.part" "$zip"
fi

echo "$sha  $zip" | sha256sum -c - >/dev/null || {
	echo "error: checksum mismatch on $zip; delete it and re-run" >&2
	exit 1
}
echo "verified tangcore-0.7.zip"

rm -rf "$out/extract"
unzip -q "$zip" -d "$out/extract"
src=$out/extract/tangcore-0.7

mkdir -p "$out/firmware" "$out/media/cores/primer25k" "$out/media/nes"
cp "$src/firmware-bl616/bl616_fpga_partner_primer25k.bin" \
   "$src/firmware-bl616/tangcore_primer25k.bin" \
   "$src/firmware-bl616/flash_primer25k.ini" "$out/firmware/"
cp "$src/cores/primer25k/monitor.bin" "$src/cores/primer25k/nestang.bin" \
   "$out/media/cores/primer25k/"

rm -rf "$out/extract"

if [ "${APP:-stock}" = source ]; then
    cat <<EOF

Prepared v0.7 recovery files and the stock partner image under $out.
These are recovery files, not the media for this source-firmware test.
Use the matching source package for both cores:
  make tangcore-install-media SOURCE_PACKAGE="${SOURCE_PACKAGE:-<source-package>}" MEDIA_DIR=<mounted-drive>
EOF
else
cat <<EOF

BL616 images     $out/firmware
  0x00000  bl616_fpga_partner_primer25k.bin   Sipeed stock debugger firmware
  0x40000  tangcore_primer25k.bin             TangCore application

Media tree       $out/media
  copy its contents to the root of the USB drive or microSD card,
  then add ROMs under nes/

Next: scripts/flash_bl616_tangcore.sh
EOF
fi
