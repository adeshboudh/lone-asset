# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
"""Builds the player's left/right footstep sounds for concrete, metal and grass from two recordings.

The recordings (Footstep_Boot_Concrete-left.wav / -right.wav, CC BY-ND 4.0) are kept in
content/audio/local/source/ (gitignored). Run this script to write footstep_<surface>_<side>.wav into
content/audio/sfx/, which the game loads at startup (Audio._load_sided_footsteps).
"""
import wave
from pathlib import Path

import numpy as np

AUDIO = Path(__file__).resolve().parents[2] / "content" / "audio"
RATE = 44100
KEEP_S = 0.35  # the recorded step is over by about 0.3 s
PEAK = 0.6


def read_wav(path: Path) -> np.ndarray:
    with wave.open(str(path)) as w:
        assert w.getnchannels() == 1 and w.getframerate() == RATE, "expected mono 44.1 kHz"
        raw = np.frombuffer(w.readframes(w.getnframes()), dtype=np.uint8)
        width = w.getsampwidth()
    b = raw.reshape(-1, width).astype(np.int32)
    value = sum(b[:, i] << (8 * i) for i in range(width))
    value = np.where(value >= 1 << (8 * width - 1), value - (1 << (8 * width)), value)
    return value / float(1 << (8 * width - 1))


def write_wav(path: Path, x: np.ndarray) -> None:
    x = x / max(np.abs(x).max(), 1e-9) * PEAK
    fade = int(0.02 * RATE)
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def filtered(x: np.ndarray, low_hz: float, high_hz: float) -> np.ndarray:
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / RATE)
    spectrum[(freqs < low_hz) | (freqs > high_hz)] = 0.0
    return np.fft.irfft(spectrum, len(x))


def metal(x: np.ndarray) -> np.ndarray:
    """The boot hitting a plate: the same step plus a ringing, decaying set of resonances."""
    t = np.arange(int(0.3 * RATE)) / RATE
    ring = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / d)
               for f, a, d in ((1180, 1.0, 0.09), (2460, 0.7, 0.07), (3900, 0.5, 0.05)))
    n = len(x) + len(ring)
    rung = np.fft.irfft(np.fft.rfft(filtered(x, 400, 8000), n) * np.fft.rfft(ring, n), n)
    rung = rung / np.abs(rung).max() * np.abs(x).max()
    return np.pad(x, (0, n - len(x))) * 0.6 + rung * 0.8


def grass(x: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """A soft step: dull thud, plus a rustle that follows the step's loudness."""
    thud = filtered(x, 40, 1200)
    envelope = np.convolve(np.abs(x), np.ones(int(0.04 * RATE)) / int(0.04 * RATE), "same")
    envelope = np.convolve(envelope, np.exp(-np.arange(int(0.12 * RATE)) / (0.05 * RATE)))[: len(x)]
    rustle = filtered(rng.standard_normal(len(x)), 2500, 9000) * envelope
    return thud * 0.7 + rustle / np.abs(rustle).max() * np.abs(thud).max() * 0.6


def main() -> None:
    rng = np.random.default_rng(7)
    for side in ("left", "right"):
        step = read_wav(AUDIO / "local" / "source" / f"Footstep_Boot_Concrete-{side}.wav")[: int(KEEP_S * RATE)]
        for surface, sound in (("concrete", step), ("metal", metal(step)), ("grass", grass(step, rng))):
            write_wav(AUDIO / "sfx" / f"footstep_{surface}_{side}.wav", sound[: int(KEEP_S * RATE)].copy())
            print(f"footstep_{surface}_{side}.wav")


if __name__ == "__main__":
    main()
