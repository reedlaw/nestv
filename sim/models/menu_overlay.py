"""NESTang BL616 UART menu protocol and exact 256x224 overlay renderer."""

from __future__ import annotations

import ast
import re
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

WIDTH = 256
HEIGHT = 224
COLS = 32
ROWS = 28

COLOR_BACK = (0, 0, 0)
COLOR_TEXT = (255, 255, 132)
COLOR_CURSOR = (255, 197, 132)
COLOR_LOGO = (66, 0, 99)


def _load_font(path: Path) -> tuple[tuple[int, ...], ...]:
    entries = re.findall(
        r"'\{\s*((?:8'h[0-9A-Fa-f]{2}\s*,\s*){7}8'h[0-9A-Fa-f]{2})\s*\}",
        path.read_text(),
    )
    font = tuple(
        tuple(int(value, 16) for value in re.findall(r"8'h([0-9A-Fa-f]{2})", entry))
        for entry in entries
    )
    if len(font) != 128 or any(len(glyph) != 8 for glyph in font):
        raise ValueError(f"expected 128 8x8 glyphs in {path}, found {len(font)}")
    return font


def _load_logo(path: Path) -> tuple[str, ...]:
    source = path.read_text()
    match = re.search(r"LOGO\s*=\s*(\[[\s\S]*?\])\s*\n\s*\n", source)
    if not match:
        raise ValueError(f"could not find LOGO in {path}")
    logo = tuple(ast.literal_eval(match.group(1)))
    if len(logo) != 14 or any(len(row) != 72 for row in logo):
        raise ValueError(f"expected a 72x14 logo in {path}")
    return logo


def frame(command: int, payload: bytes = b"") -> bytes:
    """Build one TangCore BL616-to-FPGA frame."""
    body = bytes((command,)) + payload
    if len(body) >= 2048:
        raise ValueError("frame exceeds FPGA protocol limit")
    return b"\xaa" + len(body).to_bytes(2, "big") + body


@dataclass
class MenuOverlay:
    font_path: Path
    logo_path: Path
    cells: bytearray = field(default_factory=lambda: bytearray(b" " * (COLS * ROWS)))
    cursor_x: int = 0
    cursor_y: int = 0
    enabled: bool = True
    _rx: bytearray = field(default_factory=bytearray)

    def __post_init__(self) -> None:
        self.font = _load_font(self.font_path)
        self.logo = _load_logo(self.logo_path)

    def feed(self, data: bytes) -> None:
        """Consume an arbitrarily chunked UART byte stream."""
        self._rx.extend(data)
        while True:
            marker = self._rx.find(0xAA)
            if marker < 0:
                self._rx.clear()
                return
            if marker:
                del self._rx[:marker]
            if len(self._rx) < 3:
                return
            length = int.from_bytes(self._rx[1:3], "big")
            if length == 0 or length >= 2048:
                del self._rx[0]
                continue
            if len(self._rx) < 3 + length:
                return
            body = bytes(self._rx[3 : 3 + length])
            del self._rx[: 3 + length]
            self.apply(body[0], body[1:])

    def apply(self, command: int, payload: bytes) -> None:
        if command == 4 and len(payload) >= 2:
            self.cursor_x, self.cursor_y = payload[:2]
        elif command == 5:
            for value in payload:
                if self.cursor_x < COLS:
                    if self.cursor_y < ROWS:
                        self.cells[self.cursor_y * COLS + self.cursor_x] = value & 0x7F
                    self.cursor_x += 1
        elif command == 8 and payload:
            self.enabled = bool(payload[0] & 1)

    def render(self) -> np.ndarray:
        image = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
        if not self.enabled:
            return image

        for cell_y in range(ROWS):
            for cell_x in range(COLS):
                glyph = self.font[self.cells[cell_y * COLS + cell_x] & 0x7F]
                foreground = COLOR_CURSOR if cell_x == 0 else COLOR_TEXT
                for row, bits in enumerate(glyph):
                    for column in range(8):
                        if bits & (1 << column):
                            image[cell_y * 8 + row, cell_x * 8 + column] = foreground

        logo_x = 128 - 36
        logo_y = 201
        for row, bits in enumerate(self.logo):
            for column, bit in enumerate(bits):
                if bit == "1":
                    image[logo_y + row, logo_x + column] = COLOR_LOGO
        return image
