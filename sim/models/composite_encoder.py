"""Y/C filtering, summing, termination, and frame decoding."""

from __future__ import annotations

import numpy as np

from sim.models.composite_decoder import decode_line
from sim.models.filters import one_pole_lowpass
from sim.models.resistor_dac import resistor_dac


def model_line(
    y_codes: np.ndarray,
    c_codes: np.ndarray,
    bits: int,
    tolerance: float = 0.001,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    y_loaded = resistor_dac(y_codes, bits, tolerance, seed=bits)
    c_loaded = resistor_dac(c_codes, bits, tolerance, seed=bits + 100)
    load_scale = 75.0 / (33.0 + 75.0)
    y = one_pole_lowpass(y_loaded / load_scale, 0.72)
    c = one_pole_lowpass(c_loaded / load_scale, 0.82)
    composite = y + (c - 128.0)
    return y, c, composite


def decode_frame(
    rows: np.ndarray,
    width: int,
    height: int,
    bits: int,
) -> tuple[np.ndarray, np.ndarray]:
    frame = np.zeros((height, width, 3), dtype=np.uint8)
    composite_rows = np.zeros((height, width), dtype=np.float64)
    for line in range(height):
        selection = rows[rows["active_line"] == line]
        if selection.size != width:
            raise ValueError(f"line {line} has {selection.size} active samples")
        y, c, composite = model_line(selection["y"], selection["c"], bits)
        # yc_out's phase accumulator is free-running across the 2730-sample
        # raster, so each active line starts at a different carrier phase.
        phase_offset = ((line + 20) * 2730 + 468) * (2.0 * np.pi / 12.0)
        frame[line] = decode_line(y, c, phase_offset).astype(np.uint8)
        composite_rows[line] = composite
    return frame, composite_rows
