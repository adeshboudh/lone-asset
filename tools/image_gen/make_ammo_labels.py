# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=10"]
# ///
"""Generate the ammo box label textures from one template.

Run:  uv run tools/image_gen/make_ammo_labels.py [--out DIR] [--scale N]

Writes <id>_label.png for each ammo type (same names the AmmoType .tres files
reference). Add a type by adding an entry to LABELS. Original artwork, no
third-party brand names; Rajdhani font (OFL-1.1) from content/ui/fonts/.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONT_DIR = ROOT / "content" / "ui" / "fonts"
DEFAULT_OUT = ROOT / "content" / "weapons" / "common" / "ammo_boxes"

BASE_W, BASE_H = 228, 128  # design grid; the output is this times --scale
BG = (22, 24, 22)
TEXT = (232, 232, 224)
MUTED = (150, 154, 146)


@dataclass(frozen=True)
class Label:
    id: str
    caliber: str  # large line
    spec: str  # bullet / grain line
    kind: str  # type line, drawn in the accent colour
    count: str
    accent: tuple[int, int, int]
    warning: str


LABELS: list[Label] = [
    Label("fmj_9", "9x19", "9mm LUGER  115 GR", "FULL METAL JACKET", "50 CARTRIDGES",
          (222, 168, 40), "HANDGUN AMMUNITION  KEEP DRY  KEEP OUT OF REACH OF CHILDREN"),
    Label("subsonic_9", "9x19", "9mm LUGER  147 GR", "SUBSONIC", "50 CARTRIDGES",
          (70, 150, 220), "SUPPRESSOR USE  LOW VELOCITY  NOT FOR LONG RANGE"),
    Label("fmj_556", "5.56", "5.56x45mm  55 GR", "FULL METAL JACKET", "20 CARTRIDGES",
          (110, 180, 80), "RIFLE AMMUNITION  KEEP DRY  KEEP OUT OF REACH OF CHILDREN"),
    Label("ap_556", "5.56", "5.56x45mm  62 GR", "ARMOUR PIERCING", "20 CARTRIDGES",
          (214, 60, 52), "MILITARY USE ONLY  HANDLE WITH CARE  KEEP DRY"),
]


def font(weight: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / f"Rajdhani-{weight}.ttf"), size)


def fit(draw: ImageDraw.ImageDraw, text: str, weight: str, size: int, max_w: int) -> ImageFont.FreeTypeFont:
    """Largest font at or below `size` whose text fits in max_w pixels."""
    while size > 6:
        f = font(weight, size)
        if draw.textlength(text, font=f) <= max_w:
            return f
        size -= 1
    return font(weight, 6)


def render(label: Label, scale: int) -> Image.Image:
    s = scale
    img = Image.new("RGB", (BASE_W * s, BASE_H * s), BG)
    d = ImageDraw.Draw(img)
    pad = 10 * s
    inner_w = img.width - 2 * pad

    # Border and accent stripe along the top.
    d.rectangle([2 * s, 2 * s, img.width - 2 * s - 1, img.height - 2 * s - 1], outline=(70, 74, 68), width=s)
    d.rectangle([2 * s, 2 * s, img.width - 2 * s - 1, 9 * s], fill=label.accent)

    # Caliber, large.
    f = fit(d, label.caliber, "Bold", 50 * s, inner_w)
    d.text((pad, 11 * s), label.caliber, font=f, fill=TEXT)
    y = 11 * s + f.size

    # Type line in the accent colour.
    f = fit(d, label.kind, "Bold", 17 * s, inner_w)
    d.text((pad, y), label.kind, font=f, fill=label.accent)
    y += f.size + 2 * s

    # Spec and count.
    f = fit(d, label.spec, "SemiBold", 13 * s, inner_w)
    d.text((pad, y), label.spec, font=f, fill=TEXT)
    y += f.size
    f = fit(d, label.count, "Medium", 12 * s, inner_w)
    d.text((pad, y), label.count, font=f, fill=MUTED)

    # Footer warning on a darker strip.
    strip_top = img.height - 18 * s
    d.rectangle([3 * s, strip_top, img.width - 3 * s - 1, img.height - 3 * s - 1], fill=(14, 15, 14))
    f = fit(d, label.warning, "Medium", 7 * s, inner_w)
    d.text((pad, strip_top + (15 * s - f.size) // 2), label.warning, font=f, fill=MUTED)
    return img


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output directory")
    p.add_argument("--scale", type=int, default=4, help="pixel multiplier on the 228x128 design grid")
    a = p.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    for label in LABELS:
        path = a.out / f"{label.id}_label.png"
        render(label, a.scale).save(path)
        print(path)


if __name__ == "__main__":
    main()
