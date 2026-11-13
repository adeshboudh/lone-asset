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


MAG = "1235545.audio-GUNMech-SMorph-LockxLoad-TLM170_-AR-15_Steel_Mag_PIstol_Clip_Manipulation_05.mp3"
SLIDE = "213017-Pistol-Luger-9mm-Foley-SlideAction-1.mp3"
# Reload sounds are placed so the clips' events land on the viewmodel animations' key moments, and padded to
# the reload time. Magazine clip events: out 0.02 s, in 0.93 s, seated 1.15 s. Slide clip: snap at 0.66 s.
# (id, reload time, [(clip, start in the reload s)])
RELOADS = [
    ("rifle_reload", 2.2, [(MAG, 0.35)]),  # M4 magazine out at 0.55 s, in at 1.21 s
    ("rifle_reload_empty", 2.8, [(MAG, 0.57), (SLIDE, 1.26)]),  # magazine in at 1.50 s, bolt release at 1.92 s
    ("pistol_reload", 1.5, [(MAG, 0.0)]),  # hand dips at 0.25 to 0.8 s and rises at 1.15 s
    ("pistol_reload_empty", 1.9, [(MAG, 0.0), (SLIDE, 0.84)]),  # slide snap at 1.5 s
]


def reloads() -> None:
    clips = {file: decode(SOURCE / file) for file in (MAG, SLIDE)}
    for sound_id, length_s, parts in RELOADS:
        track = np.zeros(int(length_s * SR))
        for file, start_s in parts:
            clip = clips[file] / np.abs(clips[file]).max()
            start = int(start_s * SR)
            end = min(len(track), start + len(clip))
            track[start:end] += clip[: end - start]
        fade = int(0.1 * SR)
        track[-fade:] *= np.linspace(1.0, 0.0, fade)
        write_wav(sound_id, normalise(track, 0.8))
        print(sound_id, length_s)


CHARGING = "205940-EFX_INT_AR-15_M4_Charging_Handle_with_Trigger_04-B.mp3"
MAKAROV = "1232860.audio-GUNMech-SMorph-LockLoad-CO-100k_-Makarov_9mm_Single_Action_Pistol_Dry_Fire_03.mp3"
# The charging-handle recording holds several clicks (about 1.03, 2.15, 3.29, 3.47, 3.65, 6.03, 7.72, 7.88 and
# 8.14 s). This one is the dry-fire trigger click; change it if it is the wrong sound.
M4_TRIGGER_AT_S = 6.03
DRY = {
    "rifle_dry": (CHARGING, M4_TRIGGER_AT_S - 0.01, 0.16),
    "pistol_dry": (MAKAROV, 0.0, 0.15),
}


def dry_fire() -> None:
    for sound_id, (file, start_s, length_s) in DRY.items():
        x = decode(SOURCE / file)[int(start_s * SR): int((start_s + length_s) * SR)]
        fade = int(0.05 * SR)
        x[-fade:] *= np.linspace(1.0, 0.0, fade)
        write_wav(sound_id, normalise(x, 0.8))
        print(sound_id)


def main() -> None:
    dry_fire()
    reloads()
    for sound_id, file in SHOTS.items():
        x = decode(SOURCE / file)[: int(KEEP_S * SR)]
        fade = int(FADE_S * SR)
        x[-fade:] *= np.linspace(1.0, 0.0, fade)
        write_wav(sound_id, normalise(x))
        write_wav(f"{sound_id}_muffled", normalise(fft_filter(x, None, MUFFLE_CUTOFF_HZ), 0.7))
        print(sound_id)


if __name__ == "__main__":
    main()
