#!/usr/bin/env python3
"""Fast deterministic tests for the M1 analog model."""

from __future__ import annotations

import tempfile
from pathlib import Path

import numpy as np

from render_composite import write_png

ROOT = Path(__file__).resolve().parents[1]
import sys
sys.path.insert(0, str(ROOT))

from sim.models.composite_decoder import decode_line
from sim.models.composite_encoder import model_line
from sim.models.resistor_dac import quantize, resistor_dac


def main() -> int:
    ramp = np.arange(256, dtype=np.float64)
    six = quantize(ramp, 6)
    eight = quantize(ramp, 8)
    assert np.unique(six).size == 64
    assert np.array_equal(eight, ramp)
    assert np.all(np.diff(resistor_dac(ramp, 6, tolerance=0.001)) >= 0)

    y, c, composite = model_line(ramp, np.full(256, 128), 6)
    decoded = decode_line(y, c).astype(np.uint8)
    assert y.shape == c.shape == composite.shape == (256,)
    assert decoded.shape == (256, 3)
    assert np.isfinite(composite).all()

    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "test.png"
        write_png(path, decoded.reshape(1, 256, 3))
        assert path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")

    print("PASS: M1 analog model")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
