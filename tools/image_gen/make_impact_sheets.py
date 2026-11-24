# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""Cut one puff out of an alpha video and tile it into a 4x4 sprite sheet.

List the puffs in a clip:   uv run tools/image_gen/make_impact_sheets.py list Bullet_Impacts.mov
Write one sheet:            uv run tools/image_gen/make_impact_sheets.py sheet Bullet_Impacts.mov 3 dust_puff
Needs ffmpeg on PATH. Sheets go to content/effects/impacts/<name>.png.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "content" / "effects" / "impacts"
W, H = 360, 288          # decode size (the clips are 720x576)
FRAME_PX = 128           # one frame in the sheet
GRID = 4                 # 4x4 = 16 frames
ALPHA_MIN = 0.004        # mean alpha that counts as "something is on screen"
MIN_RUN = 8              # shorter runs are noise
TAIL_KEEP = 0.12         # drop the faint tail: frames below this share of the peak alpha


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-vf", f"scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
        check=True, capture_output=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, H, W, 4)


def runs(frames: np.ndarray) -> list[tuple[int, int]]:
    live = frames[..., 3].mean(axis=(1, 2)) / 255.0 > ALPHA_MIN
    found, start = [], None
    for i, on in enumerate(list(live) + [False]):
        if on and start is None:
            start = i
        elif not on and start is not None:
            if i - start >= MIN_RUN:
                found.append((start, i))
            start = None
    return found


def make_sheet(frames: np.ndarray, start: int, end: int) -> Image.Image:
    clip = frames[start:end]
    alpha = clip[..., 3].mean(axis=(1, 2))
    clip = clip[: int(np.nonzero(alpha >= alpha.max() * TAIL_KEEP)[0].max()) + 1]
    ys, xs = np.nonzero(clip[..., 3].max(axis=0) > 8)
    cx, cy = (xs.min() + xs.max()) // 2, (ys.min() + ys.max()) // 2
    half = max(xs.max() - xs.min(), ys.max() - ys.min()) // 2 + 4
    picks = np.linspace(0, len(clip) - 1, GRID * GRID).round().astype(int)
    sheet = Image.new("RGBA", (FRAME_PX * GRID, FRAME_PX * GRID))
    for n, idx in enumerate(picks):
        image = Image.fromarray(clip[idx], "RGBA").crop((cx - half, cy - half, cx + half, cy + half))
        sheet.paste(image.resize((FRAME_PX, FRAME_PX), Image.LANCZOS), ((n % GRID) * FRAME_PX, (n // GRID) * FRAME_PX))
    return sheet


def main() -> None:
    command, source = sys.argv[1], Path(sys.argv[2])
    frames = decode(source)
    found = runs(frames)
    if command == "list":
        for n, (a, b) in enumerate(found):
            print(f"{n}: frames {a}-{b} ({(b - a) / 25:.2f} s)")
    else:
        start, end = found[int(sys.argv[3])]
        OUT.mkdir(parents=True, exist_ok=True)
        make_sheet(frames, start, end).save(OUT / f"{sys.argv[4]}.png")
        print(f"wrote {OUT / (sys.argv[4] + '.png')}")


if __name__ == "__main__":
    main()
