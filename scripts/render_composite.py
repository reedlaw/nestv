#!/usr/bin/env python3
"""Render decoded frames and compare six- and eight-bit resistor DACs."""

from __future__ import annotations

import argparse
import csv
import json
import sys
import zlib
from pathlib import Path
from struct import pack

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sim.models.composite_encoder import decode_frame


def write_png(path: Path, image: np.ndarray) -> None:
    height, width, channels = image.shape
    if channels != 3 or image.dtype != np.uint8:
        raise ValueError("PNG input must be uint8 RGB")

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return pack(">I", len(payload)) + kind + payload + pack(
            ">I", zlib.crc32(kind + payload) & 0xFFFFFFFF
        )

    raw = b"".join(b"\0" + image[row].tobytes() for row in range(height))
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, level=9))
        + chunk(b"IEND", b"")
    )


def read_samples(path: Path) -> tuple[np.ndarray, np.ndarray, int, int]:
    records: list[tuple[int, int, int, int, int, int]] = []
    source: list[tuple[int, int, int]] = []
    with path.open(newline="") as handle:
        for row in csv.DictReader(handle):
            if row["de"] != "1":
                continue
            line = int(row["line"]) - 20
            sample = int(row["sample"]) - 468
            if 0 <= line < 240 and 0 <= sample < 2112:
                records.append(
                    (line, sample, int(row["y"]), int(row["c"]),
                     int(row["hsync"]), int(row["vsync"]))
                )
                source.append((int(row["r"]), int(row["g"]), int(row["b"])))
    dtype = np.dtype(
        [("active_line", "i4"), ("sample", "i4"), ("y", "f8"), ("c", "f8"),
         ("hsync", "u1"), ("vsync", "u1")]
    )
    return np.array(records, dtype=dtype), np.array(source, dtype=np.uint8), 2112, 240


def psnr(left: np.ndarray, right: np.ndarray) -> float:
    mse = np.mean((left.astype(np.float64) - right.astype(np.float64)) ** 2)
    return float("inf") if mse == 0 else 10.0 * np.log10(255.0**2 / mse)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    rows, source, width, height = read_samples(args.input)
    expected = width * height
    if rows.size != expected:
        raise SystemExit(f"expected {expected} active samples, found {rows.size}")

    frame6, composite6 = decode_frame(rows, width, height, 6)
    frame8, composite8 = decode_frame(rows, width, height, 8)
    source_frame = source.reshape(height, width, 3)
    write_png(args.output_dir / "source.png", source_frame)
    write_png(args.output_dir / "decoded-6bit.png", frame6)
    write_png(args.output_dir / "decoded-8bit.png", frame8)

    report = {
        "samples": int(rows.size),
        "width": width,
        "height": height,
        "decoded_6_vs_8_psnr_db": psnr(frame6, frame8),
        "source_vs_6_psnr_db": psnr(source_frame, frame6),
        "source_vs_8_psnr_db": psnr(source_frame, frame8),
        "composite_6_vs_8_rms_codes": float(
            np.sqrt(np.mean((composite6 - composite8) ** 2))
        ),
        "model": {
            "resistor_tolerance": 0.001,
            "fpga_output_ohms": 33.0,
            "load_ohms": 75.0,
            "decoder": "12-sample quadrature notch approximation",
        },
    }
    report_path = args.output_dir / "comparison.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
