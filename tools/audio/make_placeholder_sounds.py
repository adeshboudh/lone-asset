# SPDX-License-Identifier: MIT
"""Synthesises the placeholder sound effects and writes data/audio/sound_bank.tres.

The sounds are simple (filtered noise, thumps, clicks) and are meant to be replaced by real recordings
from CC0 / CC BY sources (docs/design/m1-technical-design.md §17.4). Replace a file, keep its name.

Usage (from the repository root):
    uv run --with numpy python tools/audio/make_placeholder_sounds.py

Output is 16-bit mono WAV: web builds play sounds as samples, and WAV is the format Godot's sample
playback is built around. Re-test Ogg Vorbis on the web before switching real recordings to Ogg.
Keep each file's import setting compress/mode=0 (uncompressed PCM): QOA-compressed WAV is unverified for
web sample playback. tests/unit/test_audio_bank.gd checks this.
"""
import wave
from pathlib import Path

import numpy as np

SR = 32000
OUT = Path("content/audio/sfx")
BANK = Path("data/audio/sound_bank.tres")
MUFFLE_CUTOFF_HZ = 900


def t_axis(seconds: float, sr: int = SR) -> np.ndarray:
    return np.arange(int(seconds * sr)) / sr


def fft_filter(x: np.ndarray, lo: float | None, hi: float | None, sr: int = SR) -> np.ndarray:
    """Brick-wall band-pass (circular, so a looped signal stays seamless)."""
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / sr)
    mask = np.ones_like(freqs)
    if lo is not None:
        mask[freqs < lo] = 0.0
    if hi is not None:
        mask[freqs > hi] = 0.0
    return np.fft.irfft(spectrum * mask, len(x))


def noise(seconds: float, rng: np.random.Generator, lo=None, hi=None, sr: int = SR) -> np.ndarray:
    return fft_filter(rng.standard_normal(int(seconds * sr)), lo, hi, sr)


def decay(seconds: float, tau: float, attack: float = 0.0005) -> np.ndarray:
    t = t_axis(seconds)
    env = np.exp(-t / tau)
    if attack > 0:
        env *= np.clip(t / attack, 0.0, 1.0)
    return env


def thump(seconds: float, f_start: float, f_end: float, tau: float) -> np.ndarray:
    t = t_axis(seconds)
    freq = f_end + (f_start - f_end) * np.exp(-t / (tau * 0.5))
    return np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t / tau)


def place(track: np.ndarray, sound: np.ndarray, at: float, gain: float = 1.0) -> None:
    start = int(at * SR)
    end = min(start + len(sound), len(track))
    track[start:end] += sound[: end - start] * gain


def click(rng: np.random.Generator, brightness: float = 1.0) -> np.ndarray:
    n = noise(0.03, rng, 1500, 9000) * decay(0.03, 0.004, 0.0002)
    tone = np.sin(2 * np.pi * 2400 * brightness * t_axis(0.03)) * decay(0.03, 0.003, 0.0002)
    return n * 0.7 + tone * 0.5


def clack(rng: np.random.Generator) -> np.ndarray:
    n = noise(0.08, rng, 900, 5000) * decay(0.08, 0.014, 0.0003)
    body = np.sin(2 * np.pi * 380 * t_axis(0.08)) * decay(0.08, 0.02, 0.0003)
    return n * 0.8 + body * 0.6


def normalise(x: np.ndarray, peak: float = 0.85) -> np.ndarray:
    return x / max(np.max(np.abs(x)), 1e-9) * peak


def shot_suppressed(rng: np.random.Generator) -> np.ndarray:
    track = np.zeros(int(0.4 * SR))
    place(track, noise(0.4, rng, 700, 7000) * decay(0.4, 0.035), 0.0, 0.8)
    place(track, thump(0.4, 110, 45, 0.09), 0.0, 0.9)
    place(track, click(rng, 0.7), 0.045, 0.35)  # action cycling
    return normalise(track)


def footstep(rng: np.random.Generator, surface: str) -> np.ndarray:
    if surface == "metal":
        track = np.zeros(int(0.35 * SR))
        place(track, noise(0.35, rng, 300, 4000) * decay(0.35, 0.02), 0.0, 0.8)
        place(track, thump(0.35, 130, 80, 0.05), 0.0, 0.7)
        t = t_axis(0.35)
        ring = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((820, 0.25), (1310, 0.18), (2150, 0.1)))
        place(track, ring * decay(0.35, 0.09), 0.0, 0.5)
        return normalise(track, 0.8)
    if surface == "grass":
        track = np.zeros(int(0.25 * SR))
        env = decay(0.25, 0.05, 0.012)
        place(track, noise(0.25, rng, 1200, 6000) * env, 0.0, 0.7)
        place(track, thump(0.25, 90, 60, 0.04), 0.0, 0.25)
        return normalise(track, 0.6)
    track = np.zeros(int(0.2 * SR))
    place(track, noise(0.2, rng, 150, 1400) * decay(0.2, 0.03), 0.0, 0.9)
    place(track, thump(0.2, 120, 70, 0.04), 0.0, 0.8)
    return normalise(track, 0.75)


def landing(rng: np.random.Generator) -> np.ndarray:
    track = np.zeros(int(0.4 * SR))
    place(track, thump(0.4, 90, 38, 0.12), 0.0, 1.0)
    place(track, noise(0.4, rng, 80, 900) * decay(0.4, 0.05), 0.0, 0.7)
    return normalise(track, 0.9)


def reload(rng: np.random.Generator, empty: bool) -> np.ndarray:
    length = 2.7 if empty else 2.1
    track = np.zeros(int(length * SR))
    place(track, click(rng, 0.8), 0.25, 0.8)                                   # magazine release
    place(track, noise(0.15, rng, 500, 3500) * decay(0.15, 0.05, 0.01), 0.45, 0.35)  # magazine slides out
    place(track, thump(0.12, 160, 90, 0.03), 1.1, 0.6)                          # magazine seated
    place(track, click(rng, 1.0), 1.12, 0.9)
    place(track, clack(rng), 1.75, 0.8)                                          # charging handle back
    place(track, clack(rng), 1.88, 0.7)                                          # and forward
    if empty:
        place(track, clack(rng), 2.4, 0.9)                                       # bolt release
    return normalise(track, 0.8)


def shot_loud(rng: np.random.Generator) -> np.ndarray:
    """An unsuppressed rifle shot: a sharp crack, a deep boom and a short echo tail."""
    track = np.zeros(int(0.9 * SR))
    place(track, noise(0.9, rng, 300, 9000) * decay(0.9, 0.05, 0.0002), 0.0, 1.0)
    place(track, thump(0.9, 90, 32, 0.16), 0.0, 1.0)
    place(track, click(rng, 0.6), 0.004, 0.5)
    place(track, noise(0.9, rng, 150, 2500) * decay(0.9, 0.22), 0.05, 0.35)  # tail
    return normalise(track, 0.95)


def impact_world(rng: np.random.Generator) -> np.ndarray:
    track = np.zeros(int(0.3 * SR))
    place(track, noise(0.3, rng, 1500, 9000) * decay(0.3, 0.025), 0.0, 0.7)
    place(track, thump(0.3, 220, 120, 0.04), 0.0, 0.5)
    place(track, noise(0.3, rng, 4000, 10000) * decay(0.3, 0.1) * 0.3, 0.02, 0.4)  # debris
    return normalise(track, 0.7)


def impact_body(rng: np.random.Generator) -> np.ndarray:
    track = np.zeros(int(0.25 * SR))
    place(track, noise(0.25, rng, 100, 1500) * decay(0.25, 0.04), 0.0, 0.9)
    place(track, thump(0.25, 170, 80, 0.06), 0.0, 0.8)
    return normalise(track, 0.7)


def hit_marker() -> np.ndarray:
    t = t_axis(0.07)
    return normalise(np.sin(2 * np.pi * 1900 * t) * decay(0.07, 0.02, 0.0005), 0.5)


def ui_click() -> np.ndarray:
    t = t_axis(0.06)
    freq = 700 + 300 * np.exp(-t / 0.01)
    return normalise(np.sin(2 * np.pi * np.cumsum(freq) / SR) * decay(0.06, 0.012, 0.001), 0.5)


def wind_loop(rng: np.random.Generator) -> tuple[np.ndarray, int]:
    sr, seconds = 16000, 8.0
    base = noise(seconds, rng, 60, 700, sr)
    gust = noise(seconds, rng, 700, 1800, sr) * 0.35
    t = t_axis(seconds, sr)
    # Whole numbers of cycles per loop keep the end and start of the loop matched.
    swell = 0.6 + 0.25 * np.sin(2 * np.pi * 2 * t / seconds) + 0.15 * np.sin(2 * np.pi * 5 * t / seconds + 1.0)
    return normalise((base + gust) * swell, 0.5), sr


def door_open(rng: np.random.Generator) -> np.ndarray:
    """Latch click, then a low creak that rises as the door swings."""
    seconds = 0.9
    t = t_axis(seconds)
    track = np.zeros(len(t))
    place(track, clack(rng), 0.0, 0.8)
    creak_env = np.clip((t - 0.05) / 0.1, 0.0, 1.0) * np.exp(-np.clip(t - 0.35, 0.0, None) / 0.2)
    freq = 90 + 60 * t + 25 * np.sin(2 * np.pi * 7 * t)
    tone = np.sin(2 * np.pi * np.cumsum(freq) / SR) + 0.5 * np.sin(2 * np.pi * np.cumsum(freq * 2.01) / SR)
    rasp = noise(seconds, rng, 300, 1400)
    place(track, (tone * 0.35 + rasp * 0.25) * creak_env, 0.0, 0.7)
    return normalise(track, 0.7)


def door_close(rng: np.random.Generator) -> np.ndarray:
    """A soft thud as the door meets the frame, then a latch click."""
    track = np.zeros(int(0.5 * SR))
    place(track, thump(0.3, 140, 55, 0.07) + noise(0.3, rng, 80, 700) * decay(0.3, 0.03), 0.0, 0.9)
    place(track, clack(rng), 0.12, 0.5)
    return normalise(track, 0.75)


def terminal_loop(rng: np.random.Generator) -> tuple[np.ndarray, int]:
    """A quiet hum with data chirps. Whole numbers of cycles keep the loop seamless."""
    sr, seconds = 16000, 2.0
    t = np.arange(int(sr * seconds)) / sr
    hum = np.sin(2 * np.pi * 120 * t) * 0.5 + np.sin(2 * np.pi * 240 * t) * 0.2
    gate = (np.sin(2 * np.pi * 8 * t) > 0.2).astype(float)
    chirp = np.sin(2 * np.pi * (900 + 300 * np.sin(2 * np.pi * 3 * t)) * t) * gate * 0.25
    return normalise(hum + chirp, 0.45), sr


def terminal_done() -> np.ndarray:
    t = t_axis(0.5)
    track = np.zeros(len(t))
    for at, freq in ((0.0, 880), (0.14, 1320)):
        tone = np.sin(2 * np.pi * freq * t_axis(0.3)) * decay(0.3, 0.09, 0.002)
        place(track, tone, at, 0.8)
    return normalise(track, 0.55)


def objective_complete() -> np.ndarray:
    track = np.zeros(int(0.8 * SR))
    for at, freq in ((0.0, 660), (0.12, 880), (0.24, 1175)):
        tone = np.sin(2 * np.pi * freq * t_axis(0.5)) * decay(0.5, 0.14, 0.003)
        place(track, tone, at, 0.8)
    return normalise(track, 0.5)


def write_wav(name: str, samples: np.ndarray, sr: int = SR) -> None:
    pcm = (np.clip(samples, -1.0, 1.0) * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sr)
        wav.writeframes(pcm.tobytes())


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(20261101)
    bank: dict[str, list[str]] = {}

    def add(sound_id: str, variants: list[np.ndarray], sr: int = SR, muffled: bool = False) -> None:
        names = []
        for i, samples in enumerate(variants, 1):
            name = f"{sound_id}_{i}" if len(variants) > 1 else sound_id
            write_wav(name, samples, sr)
            names.append(name)
        bank[sound_id] = names
        if muffled:
            # Sounds heard through walls. Web builds play samples, which cannot use low-pass bus effects,
            # so the muffled version is a separate file.
            muffled_names = []
            for name, samples in zip(names, variants):
                muffled_name = f"{name}_muffled"
                write_wav(muffled_name, normalise(fft_filter(samples, None, MUFFLE_CUTOFF_HZ, sr), 0.7), sr)
                muffled_names.append(muffled_name)
            bank[f"{sound_id}_muffled"] = muffled_names

    def add_recorded(sound_id: str, muffled: bool = True) -> None:
        """Registers a recorded sound (and its muffled copy) that convert_recorded_shots.py already wrote."""
        bank[sound_id] = [sound_id]
        if muffled:
            bank[f"{sound_id}_muffled"] = [f"{sound_id}_muffled"]

    # The gun shots are recordings now (convert_recorded_shots.py); the draws below keep the random stream
    # the other sounds were generated from.
    for _ in range(3):
        shot_suppressed(rng)
    add_recorded("rifle_shot_suppressed")
    add_recorded("pistol_shot_suppressed")
    for surface in ("concrete", "metal", "grass"):
        add(f"footstep_{surface}", [footstep(rng, surface) for _ in range(3)], muffled=True)
    add("landing", [landing(rng)], muffled=True)
    reload(rng, False)  # recordings now (convert_recorded_shots.py); the draws keep the random stream
    reload(rng, True)
    add_recorded("rifle_reload", muffled=False)
    add_recorded("rifle_reload_empty", muffled=False)
    add_recorded("pistol_reload", muffled=False)
    add_recorded("pistol_reload_empty", muffled=False)
    click(rng, 0.9)  # recordings now (convert_recorded_shots.py); the draw keeps the random stream
    add_recorded("rifle_dry", muffled=False)
    add_recorded("pistol_dry", muffled=False)
    add("impact_world", [impact_world(rng) for _ in range(3)], muffled=True)
    add("impact_body", [impact_body(rng) for _ in range(2)], muffled=True)
    add("hit_marker", [hit_marker()])
    add("ui_click", [ui_click()])
    wind, wind_sr = wind_loop(rng)
    add("wind_loop", [wind], wind_sr)
    # Added after the others so earlier sounds keep their exact samples (shared random generator).
    for _ in range(3):
        shot_loud(rng)
    add_recorded("rifle_shot_loud")
    # Added in WP 9, after the sounds above, for the same reason.
    add("door_open", [door_open(rng)], muffled=True)
    add("door_close", [door_close(rng)], muffled=True)
    loop, loop_sr = terminal_loop(rng)
    add("terminal_loop", [loop], loop_sr)
    add("terminal_done", [terminal_done()])
    add("objective_complete", [objective_complete()])

    lines = ['[gd_resource type="Resource" script_class="SoundBank" load_steps=%d format=3]\n' % (2 + sum(len(v) for v in bank.values())),
             '[ext_resource type="Script" path="res://game/audio/sound_bank.gd" id="1_bank"]']
    ids = {}
    for sound_id, names in bank.items():
        for name in names:
            ids[name] = f"{len(ids) + 2}_{name}"
            lines.append(f'[ext_resource type="AudioStream" path="res://content/audio/sfx/{name}.wav" id="{ids[name]}"]')
    lines.append("\n[resource]\nscript = ExtResource(\"1_bank\")\nsounds = {")
    entries = [f'&"{sound_id}": [{", ".join(f"ExtResource(\"{ids[n]}\")" for n in names)}]' for sound_id, names in bank.items()]
    lines.append(",\n".join(entries))
    lines.append("}")
    BANK.parent.mkdir(parents=True, exist_ok=True)
    BANK.write_text("\n".join(lines) + "\n")
    total = sum(p.stat().st_size for p in OUT.glob("*.wav"))
    print(f"wrote {sum(len(v) for v in bank.values())} sounds, {total / 1024:.0f} KiB")


if __name__ == "__main__":
    main()
