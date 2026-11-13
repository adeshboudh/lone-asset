# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
"""Turns the recorded gun shots in tools/audio/source/ into game sounds (needs ffmpeg on the PATH).

Mono, 44.1 kHz, trimmed to the first 1.2 s with a fade-out (a long tail would pile up voices in fast fire),
normalised like the generated sounds, plus a muffled copy for walls. Run make_placeholder_sounds.py afterwards
to refresh data/audio/sound_bank.tres.
"""
import subprocess
from pathlib import Path

import numpy as np

from make_placeholder_sounds import MUFFLE_CUTOFF_HZ, OUT, SR, fft_filter, normalise, write_wav

SOURCE = Path(__file__).resolve().parent / "source"
KEEP_S = 1.2
FADE_S = 0.3
SHOTS = {
    "rifle_shot_suppressed": "301533-M4-SPRSD-SINGLESHOT-ON-GUN-A-03.mp3",
    "rifle_shot_loud": "516405-Gun-Assault_Rifle-M4_Carbine-5_56x45mm-Shot-Single-5-Mix.mp3",
    "pistol_shot_suppressed": "163536-M-P9-Suppressed_-Single_Shot_-Open_Exterior-09.mp3",
}


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def main() -> None:
    for sound_id, file in SHOTS.items():
        x = decode(SOURCE / file)[: int(KEEP_S * SR)]
        fade = int(FADE_S * SR)
        x[-fade:] *= np.linspace(1.0, 0.0, fade)
        write_wav(sound_id, normalise(x))
        write_wav(f"{sound_id}_muffled", normalise(fft_filter(x, None, MUFFLE_CUTOFF_HZ), 0.7))
        print(sound_id)


if __name__ == "__main__":
    main()
