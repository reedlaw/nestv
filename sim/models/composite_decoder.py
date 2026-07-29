"""Simple notch-style NTSC decoder for comparative validation."""

from __future__ import annotations

import numpy as np

from sim.models.filters import moving_average, one_pole_lowpass


def decode_line(y: np.ndarray, c: np.ndarray, phase_offset: float = 0.0) -> np.ndarray:
    count = len(y)
    phase = np.arange(count, dtype=np.float64) * (2.0 * np.pi / 12.0)
    phase += phase_offset
    chroma = (np.asarray(c, dtype=np.float64) - 128.0) / 128.0
    # A 12-sample integrate-and-dump approximates a notch/heterodyne decoder.
    u = 2.0 * moving_average(chroma * np.sin(phase), 12)
    v = 2.0 * moving_average(chroma * np.cos(phase), 12)
    luma = one_pole_lowpass(np.asarray(y, dtype=np.float64) / 255.0, 0.65)
    red = luma + 1.140 * v
    green = luma - 0.395 * u - 0.581 * v
    blue = luma + 2.032 * u
    return np.clip(np.stack((red, green, blue), axis=1) * 255.0, 0, 255)
