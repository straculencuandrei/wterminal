"""Generate a 4K AMOLED Dark-Grey Transparent Terminal wallpaper with zero banding."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def generate_wallpaper(width: int, height: int, output_path: Path) -> None:
    """Create a true-black AMOLED canvas with subtle dark-grey glass light & micro-grid."""
    y_coords, x_coords = np.mgrid[0:height, 0:width].astype(np.float32)
    nx = x_coords / width
    ny = y_coords / height

    # True AMOLED black base (#000000) with ultra-subtle dark-grey ambient fields
    glow1 = np.exp(-(((nx - 0.30) / 0.36) ** 2 + ((ny - 0.30) / 0.44) ** 2))
    glow2 = np.exp(-(((nx - 0.74) / 0.38) ** 2 + ((ny - 0.70) / 0.44) ** 2))

    # Diagonal translucent smoked-glass fold
    diag = (nx * 0.76 + ny * 0.50) - 0.64
    smoked_band = np.exp(-((diag / 0.16) ** 2)) * np.exp(-(((nx - 0.5) / 0.52) ** 2))
    hairline = np.exp(-(((diag + 0.003) / 0.0022) ** 2)) * np.exp(-(((nx - 0.5) / 0.44) ** 2))

    # Neutral zinc/graphite monochrome luminance (R ~= G ~= B, tiny cool tilt)
    lum = 14.0 * glow1 + 11.0 * glow2 + 12.0 * smoked_band + 16.0 * hairline

    # Vignette keeps outer OLED pixels near pure #000000
    vignette = 1.0 - 0.45 * (((nx - 0.5) * 1.45) ** 2 + ((ny - 0.5) * 1.35) ** 2)
    vignette = np.clip(vignette, 0.0, 1.0)
    lum *= vignette

    # Ultra-subtle terminal dot-matrix grid in the center region (fade smoothly toward edges)
    dot_mask = ((x_coords.astype(np.int32) % 48 == 0) & (y_coords.astype(np.int32) % 48 == 0)).astype(np.float32)
    center_fade = np.exp(-(((nx - 0.5) / 0.34) ** 2 + ((ny - 0.5) / 0.34) ** 2))
    lum += dot_mask * center_fade * 14.0

    # Triangular dithering for smooth dark transitions without banding
    rng = np.random.default_rng(7)
    dither = rng.uniform(-0.65, 0.65, size=(height, width)).astype(np.float32)

    r = np.clip(lum * 0.96 + dither, 0, 255)
    g = np.clip(lum * 0.98 + dither, 0, 255)
    b = np.clip(lum * 1.04 + dither, 0, 255)

    rgb = np.stack([r, g, b], axis=-1).astype(np.uint8)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgb, mode="RGB").save(output_path, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate 4K AMOLED Terminal wallpaper.")
    parser.add_argument("--width", type=int, default=3840)
    parser.add_argument("--height", type=int, default=2160)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "amoled-terminal-4k.png",
    )
    args = parser.parse_args()
    generate_wallpaper(args.width, args.height, args.output)
    print(f"Generated {args.width}x{args.height} wallpaper at {args.output}")


if __name__ == "__main__":
    main()
