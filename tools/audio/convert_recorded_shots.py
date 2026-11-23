# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
"""Turns the gun shots in tools/audio/source/ (recorded, and generated with text_to_sfx) into game sounds (needs ffmpeg on the PATH).

Mono, 44.1 kHz, trimmed to the first 1.2 s with a fade-out (a long tail would pile up voices in fast fire),
normalised like the generated sounds, plus a muffled copy for walls. Run make_placeholder_sounds.py afterwards
to refresh data/audio/sound_bank.tres.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

from make_placeholder_sounds import MUFFLE_CUTOFF_HZ, OUT, SR, fft_filter, normalise, write_wav

SOURCE = Path(__file__).resolve().parent / "source"
KEEP_S = 1.2
FADE_S = 0.3
SHOTS: dict[str, str] = {}  # the pistol and the old M4 shots were removed 2026-11-22; the rifle fire sounds are supplied directly
# One gun's recording holding several single shots: each shot becomes a variant (id_1, id_2, ...).
# Add a gun by adding its recordings here and its sound ids in sound_bank.tres.
SLICED_SHOTS: dict[str, str] = {}
SHOT_LENGTH_S = 0.7
SHOT_LEAD_S = 0.03


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


MAG = "1235545.audio-GUNMech-SMorph-LockxLoad-TLM170_-AR-15_Steel_Mag_PIstol_Clip_Manipulation_05.mp3"
# The pistol and rifle reload sounds are gone (the rifle's are supplied by the developer, trimmed to its clips).
RELOADS: list[tuple[str, float, list[tuple[str, float]]]] = []


def reloads() -> None:
    clips = {file: decode(SOURCE / file) for file in {f for _, _, parts in RELOADS for f, _ in parts}}
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
# The charging-handle recording holds several clicks (about 1.03, 2.15, 3.29, 3.47, 3.65, 6.03, 7.72, 7.88 and
# 8.14 s). This one is the dry-fire trigger click; change it if it is the wrong sound.
M4_TRIGGER_AT_S = 6.03
DRY = {
    "rifle_dry": (CHARGING, M4_TRIGGER_AT_S - 0.01, 0.16),
}


def dry_fire() -> None:
    for sound_id, (file, start_s, length_s) in DRY.items():
        x = decode(SOURCE / file)[int(start_s * SR): int((start_s + length_s) * SR)]
        fade = int(0.05 * SR)
        x[-fade:] *= np.linspace(1.0, 0.0, fade)
        write_wav(sound_id, normalise(x, 0.8))
        print(sound_id)


def split_shots(x: np.ndarray) -> list[np.ndarray]:
    """One slice per gunshot in a recording: finds the loud peaks (at least 0.3 s apart) and cuts from just
    before each, so reverb tails and neighbouring shots do not leak in."""
    window = int(0.005 * SR)
    env = np.array([np.abs(x[i: i + window]).max() for i in range(0, len(x) - window, window)])
    reach = int(0.15 * SR / window)
    peaks: list[int] = []
    for i, level in enumerate(env):
        if level > 0.4 * env.max() and level == env[max(0, i - reach): i + reach].max():
            if not peaks or (i - peaks[-1]) * window > 0.3 * SR:
                peaks.append(i)
    slices = []
    for peak in peaks:
        start = max(0, peak * window - int(SHOT_LEAD_S * SR))
        shot = x[start: start + int(SHOT_LENGTH_S * SR)].copy()
        fade = int(FADE_S * SR)
        shot[-fade:] *= np.linspace(1.0, 0.0, fade)
        slices.append(shot)
    return slices


def sliced_shots() -> None:
    for sound_id, file in SLICED_SHOTS.items():
        for i, shot in enumerate(split_shots(decode(SOURCE / file)), 1):
            write_wav(f"{sound_id}_{i}", normalise(shot))
            write_wav(f"{sound_id}_{i}_muffled", normalise(fft_filter(shot, None, MUFFLE_CUTOFF_HZ), 0.7))
            print(f"{sound_id}_{i}")


def main() -> None:
    # --shots: only the gun shots (the sources of the other sounds are unchanged).
    if "--shots" not in sys.argv:
        dry_fire()
        reloads()
    sliced_shots()
    for sound_id, file in SHOTS.items():
        x = decode(SOURCE / file)[: int(KEEP_S * SR)]
        fade = int(FADE_S * SR)
        x[-fade:] *= np.linspace(1.0, 0.0, fade)
        write_wav(sound_id, normalise(x))
        write_wav(f"{sound_id}_muffled", normalise(fft_filter(x, None, MUFFLE_CUTOFF_HZ), 0.7))
        print(sound_id)


if __name__ == "__main__":
    main()
