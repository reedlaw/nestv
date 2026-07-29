"""Deterministic resistor-DAC quantization model."""

from __future__ import annotations

import numpy as np


def quantize(samples: np.ndarray, bits: int) -> np.ndarray:
    """Round 8-bit codes to *bits* and expand them back to 0..255."""
    if bits not in (6, 8):
        raise ValueError("only 6-bit and 8-bit DACs are supported")
    levels = (1 << bits) - 1
    codes = np.rint(np.asarray(samples, dtype=np.float64) * levels / 255.0)
    return codes * 255.0 / levels


def resistor_dac(
    samples: np.ndarray,
    bits: int,
    tolerance: float = 0.0,
    seed: int = 0,
    output_resistance: float = 33.0,
    load_resistance: float = 75.0,
) -> np.ndarray:
    """Model a binary-weighted DAC, resistor tolerance, and loaded output."""
    ideal = quantize(samples, bits)
    levels = (1 << bits) - 1
    codes = np.rint(ideal * levels / 255.0).astype(np.uint16)
    weights = 2.0 ** np.arange(bits, dtype=np.float64)
    if tolerance:
        rng = np.random.default_rng(seed)
        weights *= 1.0 + rng.normal(0.0, tolerance / 3.0, bits)
    weighted = np.zeros(codes.shape, dtype=np.float64)
    for bit, weight in enumerate(weights):
        weighted += ((codes >> bit) & 1) * weight
    weighted *= 255.0 / weights.sum()
    return weighted * load_resistance / (output_resistance + load_resistance)
