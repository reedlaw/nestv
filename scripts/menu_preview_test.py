#!/usr/bin/env python3
"""Deterministic tests for the NESTang menu protocol previewer."""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sim.models.menu_overlay import COLOR_CURSOR, COLOR_LOGO, COLOR_TEXT, MenuOverlay, frame


def main() -> int:
    menu = MenuOverlay(
        ROOT / "rtl/core/nestang/src/assets/font.vh",
        ROOT / "rtl/core/nestang/src/assets/logo.py",
    )

    stream = frame(4, b"\x00\x02") + frame(5, b">TEST")
    for byte in stream:
        menu.feed(bytes((byte,)))
    assert menu.cursor_x == 5
    assert bytes(menu.cells[64:69]) == b">TEST"

    image = menu.render()
    assert image.shape == (224, 256, 3)
    assert np.any(np.all(image == COLOR_CURSOR, axis=2))
    assert np.any(np.all(image == COLOR_TEXT, axis=2))
    assert np.any(np.all(image == COLOR_LOGO, axis=2))

    menu.feed(b"noise" + frame(8, b"\x00"))
    assert not menu.enabled
    assert not menu.render().any()

    menu.feed(frame(8, b"\x01"))
    menu.feed(frame(4, b"\x1f\x03") + frame(5, b"AB"))
    assert menu.cells[3 * 32 + 31] == ord("A")
    assert menu.cursor_x == 32

    print("PASS: menu UART framing, character buffer, font, logo, and overlay")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
