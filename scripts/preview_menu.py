#!/usr/bin/env python3
"""Render a deterministic NESTang firmware-menu protocol preview."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from render_composite import write_png
from sim.models.menu_overlay import MenuOverlay, frame


def write_line(menu: MenuOverlay, row: int, text: str) -> None:
    payload = text.encode("ascii", errors="replace")[:32]
    menu.feed(frame(4, bytes((0, row))))
    menu.feed(frame(5, payload.ljust(32)))


def build_preview(menu: MenuOverlay) -> None:
    menu.feed(frame(8, b"\x01"))
    write_line(menu, 1, "            NESTV")
    write_line(menu, 3, " ROMS")
    write_line(menu, 5, "> Super Mario Bros.")
    write_line(menu, 6, "  The Legend of Zelda")
    write_line(menu, 7, "  Metroid")
    write_line(menu, 8, "  Mega Man 2")
    write_line(menu, 9, "  Castlevania")
    write_line(menu, 11, " SETTINGS")
    write_line(menu, 13, "  Video        NTSC")
    write_line(menu, 14, "  Analog out   Y/C + CVBS")
    write_line(menu, 15, "  Overscan     Normal")
    write_line(menu, 18, " A: Load   B: Back")
    write_line(menu, 19, " Start: Options")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "build/menu-preview/menu.png")
    parser.add_argument("--scale", type=int, default=3)
    args = parser.parse_args()
    if args.scale < 1:
        parser.error("--scale must be at least 1")

    menu = MenuOverlay(
        ROOT / "rtl/core/nestang/src/assets/font.vh",
        ROOT / "rtl/core/nestang/src/assets/logo.py",
    )
    build_preview(menu)
    image = menu.render()
    if args.scale != 1:
        image = image.repeat(args.scale, axis=0).repeat(args.scale, axis=1)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    write_png(args.output, image)
    print(f"Wrote {args.output} ({image.shape[1]}x{image.shape[0]})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
