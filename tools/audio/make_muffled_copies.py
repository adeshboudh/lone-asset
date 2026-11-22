# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
"""Writes the pre-muffled copies of weapon sounds (heard through walls), same recipe as the rifle's:
an FFT low-pass at 900 Hz, peak normalised to 0.7.

  python3 tools/audio/make_muffled_copies.py in.wav out.wav [in2.wav out2.wav ...]
"""
import sys
import wave

import numpy as np

CUTOFF_HZ = 900
PEAK = 0.7


def muffle(src: str, dst: str) -> None:
    with wave.open(src, "rb") as wav:
        channels, rate, frames = wav.getnchannels(), wav.getframerate(), wav.readframes(wav.getnframes())
    data = np.frombuffer(frames, dtype=np.int16).reshape(-1, channels) / 32768.0
    out = np.empty_like(data)
    for c in range(channels):
        spectrum = np.fft.rfft(data[:, c])
        spectrum[np.fft.rfftfreq(len(data), 1.0 / rate) > CUTOFF_HZ] = 0.0
        out[:, c] = np.fft.irfft(spectrum, len(data))
    out *= PEAK / max(float(np.abs(out).max()), 1e-9)
    with wave.open(dst, "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes((out * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    args = sys.argv[1:]
    for i in range(0, len(args), 2):
        muffle(args[i], args[i + 1])
