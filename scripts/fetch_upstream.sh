#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
destination="$root/build/upstream"
revision=bcb33525b3e09c9c619768c9cf91e28d18a8ff7c
yc_sha256=ccd2247dc1f57684bd1c87553dc2169cb93fd8f99f451025ca15355e961c08d5
base_url="https://raw.githubusercontent.com/MiSTer-devel/Arcade-Gaplus_MiSTer/$revision"

mkdir -p "$destination"

fetch_and_verify() {
	output=$1
	url=$2
	expected=$3
	temporary="$output.tmp"

	if [ -f "$output" ] &&
		printf '%s  %s\n' "$expected" "$output" | sha256sum --check --status
	then
		return
	fi

	curl --fail --location --silent --show-error "$url" --output "$temporary"
	printf '%s  %s\n' "$expected" "$temporary" | sha256sum --check --status
	mv "$temporary" "$output"
}

fetch_and_verify \
	"$destination/yc_out.sv" \
	"$base_url/sys/yc_out.sv" \
	"$yc_sha256"

if [ ! -f "$destination/COPYING" ]; then
	curl --fail --location --silent --show-error \
		"$base_url/LICENSE" --output "$destination/COPYING.tmp"
	mv "$destination/COPYING.tmp" "$destination/COPYING"
fi
