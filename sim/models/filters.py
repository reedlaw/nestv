"""Small signal-processing primitives with no SciPy dependency."""

from __future__ import annotations

import numpy as np


def moving_average(values: np.ndarray, taps: int) -> np.ndarray:
    if taps < 1:
        raise ValueError("taps must be positive")
    kernel = np.ones(taps, dtype=np.float64) / taps
    return np.convolve(np.asarray(values, dtype=np.float64), kernel, mode="same")


def one_pole_lowpass(values: np.ndarray, alpha: float) -> np.ndarray:
    if not 0.0 < alpha <= 1.0:
        raise ValueError("alpha must be in (0, 1]")
    source = np.asarray(values, dtype=np.float64)
    result = np.empty_like(source)
    result[0] = source[0]
    for index in range(1, source.size):
        result[index] = result[index - 1] + alpha * (
            source[index] - result[index - 1]
        )
    return result
