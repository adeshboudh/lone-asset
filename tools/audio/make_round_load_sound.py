# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
"""Writes content/audio/sfx/round_load.wav: the short brass click of pushing a round into a magazine.

  python3 tools/audio/make_round_load_sound.py content/audio/sfx/round_load.wav

A 6 ms noise tick plus two quickly decaying metallic partials, mono, 44.1 kHz, peak 0.6. Deterministic.
"""
import sys
import wave

import numpy as np

SR = 44100


def main(path: str) -> None:
    rng = np.random.default_rng(20261122)
    t = np.arange(int(0.09 * SR)) / SR
    tick = rng.standard_normal(len(t)) * np.exp(-t / 0.002)
    spectrum = np.fft.rfft(tick)
    freqs = np.fft.rfftfreq(len(tick), 1.0 / SR)
    tick = np.fft.irfft(spectrum * ((freqs > 1500) & (freqs < 9000)), len(tick))
    ring = 0.5 * np.sin(2 * np.pi * 3120 * t) * np.exp(-t / 0.012) + 0.3 * np.sin(2 * np.pi * 5380 * t) * np.exp(-t / 0.008)
    out = 0.7 * tick / max(float(np.abs(tick).max()), 1e-9) + ring
    out *= 0.6 / float(np.abs(out).max())
    fade = np.linspace(1.0, 0.0, 200)
    out[-200:] *= fade
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes((out * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    main(sys.argv[1])
