#!/usr/bin/env python3
"""Generate the game's placeholder-quality chiptune audio.

Writes 15 SFX (WAV, low latency) to assets/audio/sfx/ and 8 seamless music
loops (OGG Vorbis, small for web builds) to assets/audio/music/. Output is
deterministic: re-running produces the same sounds, so tweak a recipe here and
regenerate rather than editing files by hand.

Usage:  python3 tools/generate_audio.py           (needs numpy and ffmpeg)

These are GBA/SNES-flavoured stand-ins built from pulse, triangle and noise
voices. Swap any file for hand-made audio later; AudioManager loads whatever
sits at the expected path.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 32000
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")


# ── Voices ────────────────────────────────────────────────────────────────────

def _phase(freq, n):
    """Phase in cycles for a constant or per-sample frequency."""
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    return np.cumsum(f) / SR


def pulse(freq, n, duty=0.25):
    return np.where((_phase(freq, n) % 1.0) < duty, 1.0, -1.0)


def triangle(freq, n):
    p = _phase(freq, n) % 1.0
    return 4.0 * np.abs(p - 0.5) - 1.0


def noise(n, rng, hold=1):
    """Sample-and-hold noise; larger hold = lower, crunchier pitch."""
    raw = rng.uniform(-1.0, 1.0, n // hold + 1)
    return np.repeat(raw, hold)[:n]


def env(n, attack=0.005, decay=None, sustain=1.0, release=0.02):
    """Simple AD(S)R envelope over n samples."""
    t = np.arange(n) / SR
    dur = n / SR
    e = np.ones(n) * sustain
    a = max(attack, 1e-4)
    e[t < a] = t[t < a] / a
    if decay is not None:
        m = t >= a
        e[m] = sustain + (1.0 - sustain) * np.exp(-(t[m] - a) / decay)
    r = max(release, 1e-4)
    tail = t > dur - r
    e[tail] *= np.clip((dur - t[tail]) / r, 0.0, 1.0)
    return e


def sweep(f0, f1, n, curve=1.0):
    x = np.linspace(0.0, 1.0, n) ** curve
    return f0 + (f1 - f0) * x


def secs(s):
    return int(SR * s)


def note_hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


# ── SFX recipes ───────────────────────────────────────────────────────────────

def sfx_recipes(rng):
    def seq(notes, step, voice=pulse, duty=0.5):
        parts = []
        for m in notes:
            n = secs(step)
            parts.append(voice(note_hz(m), n, duty) * env(n, decay=step * 0.6, sustain=0.3))
        return np.concatenate(parts)

    r = {}
    n = secs(0.16)
    r["dig"] = noise(n, rng, hold=6) * env(n, decay=0.05, sustain=0.0) \
        + 0.5 * triangle(sweep(140, 60, n), n) * env(n, decay=0.06, sustain=0.0)
    r["pickup"] = seq([76, 83, 88], 0.05, duty=0.25)
    n = secs(0.14)
    r["attack_melee"] = noise(n, rng, hold=2) * env(n, attack=0.01, decay=0.04, sustain=0.0) * 0.8
    n = secs(0.18)
    r["attack_ranged"] = pulse(sweep(1400, 300, n, 0.6), n, 0.125) * env(n, decay=0.08, sustain=0.0)
    n = secs(0.22)
    r["player_hit"] = pulse(sweep(420, 110, n), n, 0.5) * env(n, decay=0.1, sustain=0.0) \
        + 0.4 * noise(n, rng, hold=4) * env(n, decay=0.05, sustain=0.0)
    n = secs(0.09)
    r["enemy_hit"] = pulse(sweep(700, 350, n), n, 0.25) * env(n, decay=0.04, sustain=0.0)
    n = secs(0.35)
    r["enemy_die"] = noise(n, rng, hold=8) * env(n, decay=0.12, sustain=0.0) \
        + 0.5 * pulse(sweep(500, 60, n, 0.5), n, 0.5) * env(n, decay=0.15, sustain=0.0)
    n = secs(0.16)
    r["boss_hit"] = triangle(sweep(160, 70, n), n) * env(n, decay=0.08, sustain=0.0) \
        + 0.6 * noise(n, rng, hold=10) * env(n, decay=0.05, sustain=0.0)
    n = secs(0.9)
    wobble = 1.0 + 0.03 * np.sin(2 * np.pi * 9 * np.arange(n) / SR)
    r["boss_phase"] = pulse(sweep(90, 360, n, 2.0) * wobble, n, 0.5) * env(n, attack=0.05, release=0.3) * 0.7 \
        + 0.5 * noise(n, rng, hold=12) * env(n, attack=0.3, release=0.4) * 0.6
    r["craft_success"] = seq([72, 76, 79, 84], 0.07, duty=0.25)
    r["quiz_correct"] = seq([79, 84], 0.09, duty=0.5)
    r["quiz_wrong"] = seq([55, 54], 0.14, voice=lambda f, n, d: pulse(f, n, 0.5))
    n = secs(0.06)
    r["interact"] = pulse(note_hz(81), n, 0.25) * env(n, decay=0.03, sustain=0.0)
    n = secs(0.1)
    r["ui_open"] = pulse(sweep(500, 900, n), n, 0.25) * env(n, decay=0.06, sustain=0.2)
    r["ui_close"] = pulse(sweep(900, 500, n), n, 0.25) * env(n, decay=0.06, sustain=0.2)
    return r


# ── Music ─────────────────────────────────────────────────────────────────────

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]
DORIAN = [0, 2, 3, 5, 7, 9, 10]
PHRYGIAN = [0, 1, 3, 5, 7, 8, 10]
LYDIAN = [0, 2, 4, 6, 7, 9, 11]

# key = MIDI root, chords = scale degrees (0-based) one per bar, 8 bars,
# looped twice with a varied melody second time (16 bars total).
TRACKS = {
    "surface_plains":    dict(bpm=112, key=60, scale=MAJOR,    chords=[0, 4, 5, 3, 0, 4, 3, 4], duty=0.25, drums="march", seed=1),
    "underground_mines": dict(bpm=92,  key=57, scale=DORIAN,   chords=[0, 0, 6, 3, 0, 6, 4, 4], duty=0.125, drums="clank", seed=2),
    "crystal_caverns":   dict(bpm=84,  key=64, scale=LYDIAN,   chords=[0, 1, 0, 4, 3, 1, 4, 4], duty=0.5,  drums="soft",  seed=3),
    "sky_islands":       dict(bpm=126, key=65, scale=MAJOR,    chords=[0, 3, 4, 0, 5, 3, 1, 4], duty=0.25, drums="light", seed=4),
    "ocean_floor":       dict(bpm=76,  key=55, scale=MINOR,    chords=[0, 5, 2, 6, 0, 5, 3, 4], duty=0.5,  drums="soft",  seed=5),
    "magma_layer":       dict(bpm=138, key=52, scale=PHRYGIAN, chords=[0, 1, 0, 6, 0, 1, 5, 4], duty=0.125, drums="drive", seed=6),
    "boss_battle":       dict(bpm=152, key=50, scale=MINOR,    chords=[0, 5, 6, 4, 0, 5, 3, 4], duty=0.25, drums="drive", seed=7),
    "title":             dict(bpm=100, key=62, scale=MAJOR,    chords=[0, 5, 3, 4, 0, 5, 1, 4], duty=0.25, drums="light", seed=8),
}

DRUM_PATTERNS = {   # 16 steps per bar: K=kick, S=snare, h=hat, .=rest
    "march": "K.h.S.h.K.hKS.h.",
    "clank": "K...S..hK.K.S...",
    "soft":  "K.......h.......",
    "light": "K.h.h.h.K.h.h.hh",
    "drive": "KhhhShhhKhKhShhh",
}


def degree_midi(t, deg, octave=0):
    sc = t["scale"]
    return t["key"] + 12 * (octave + deg // 7) + sc[deg % 7]


def render_track(name, t):
    rng = np.random.default_rng(t["seed"])
    step = 60.0 / t["bpm"] / 4.0            # sixteenth note
    bar_n = secs(step * 16)
    bars = len(t["chords"]) * 2
    total = bar_n * bars
    mix = np.zeros(total)

    def place(sig, start):
        end = min(start + len(sig), total)
        mix[start:end] += sig[: end - start]

    # Melody motif per half (A, then A' with new endings) so it sounds composed.
    def motif(var):
        r = np.random.default_rng(t["seed"] * 10 + var)
        rhythm = [2, 2, 4, 2, 2, 4] if r.random() < 0.5 else [4, 2, 2, 4, 4]
        return [(int(r.integers(0, 5)), d) for d in rhythm]

    motifs = [motif(0), motif(1)]
    for b in range(bars):
        chord = t["chords"][b % len(t["chords"])]
        start = b * bar_n
        # Bass: triangle on root, octave pump on eighths
        for i in range(8):
            m = degree_midi(t, chord, -2 + (i % 2))
            n = secs(step * 2)
            place(0.55 * triangle(note_hz(m), n) * env(n, decay=step * 1.5, sustain=0.5), start + i * secs(step * 2))
        # Arpeggio: chord tones on sixteenths, quiet
        for i in range(16):
            deg = chord + [0, 2, 4, 7][i % 4]
            n = secs(step)
            place(0.12 * pulse(note_hz(degree_midi(t, deg, 0)), n, 0.5) * env(n, decay=step * 0.5, sustain=0.0), start + i * n)
        # Lead: motif chosen by half, transposed to the chord
        mot = motifs[(b // 4) % 2]
        pos = 0
        for k, (off, dur) in enumerate(mot):
            if pos >= 16:
                break
            dur = min(dur, 16 - pos)
            deg = chord + [0, 2, 4, 5, 7][off]
            if b % 4 == 3 and k == len(mot) - 1:
                deg = chord            # resolve phrase endings to the root
            n = secs(step * dur)
            vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.5 * np.arange(n) / SR)
            place(0.3 * pulse(note_hz(degree_midi(t, deg, 1)) * vib, n, t["duty"]) * env(n, attack=0.005, decay=step * 3, sustain=0.6, release=0.03),
                  start + secs(step * pos))
            pos += dur
        # Drums
        for i, ch in enumerate(DRUM_PATTERNS[t["drums"]]):
            s = start + i * secs(step)
            if ch == "K":
                n = secs(0.12)
                place(0.7 * triangle(sweep(150, 45, n, 0.4), n) * env(n, decay=0.05, sustain=0.0), s)
            elif ch == "S":
                n = secs(0.12)
                place(0.35 * noise(n, rng, hold=3) * env(n, decay=0.04, sustain=0.0), s)
            elif ch == "h":
                n = secs(0.04)
                place(0.12 * noise(n, rng, hold=1) * env(n, decay=0.01, sustain=0.0), s)
    return mix


# ── Output ────────────────────────────────────────────────────────────────────

def normalise(sig, peak=0.85):
    m = np.max(np.abs(sig))
    return sig * (peak / m) if m > 0 else sig


def write_wav(path, sig):
    data = (normalise(sig) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path, sig):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = tmp.name
    try:
        write_wav(tmp_path, sig)
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", tmp_path,
             "-c:a", "vorbis", "-strict", "-2", "-ac", "2", "-q:a", "4", path],
            check=True)
    finally:
        os.unlink(tmp_path)


def main():
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    rng = np.random.default_rng(1729)
    for key, sig in sfx_recipes(rng).items():
        write_wav(os.path.join(SFX_DIR, key + ".wav"), sig)
        print("sfx  ", key)
    for key, t in TRACKS.items():
        write_ogg(os.path.join(MUSIC_DIR, key + ".ogg"), render_track(key, t))
        print("music", key)
    return 0


if __name__ == "__main__":
    sys.exit(main())
