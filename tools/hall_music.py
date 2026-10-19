"""Música ambiente del Salón de las Facultades (loop de 48 s, tranquila y solemne).

Pad lento en La menor (Am - F - Dm - E), un bordón grave, campanitas sueltas y mucha reverberación.
Uso: python tools/hall_music.py salida.wav   (luego: ffmpeg -i salida.wav -c:a libvorbis -q:a 5 hall_ambient.ogg)
"""
import sys
import wave
import numpy as np
from scipy.signal import lfilter

SR = 44100
BAR = 12.0
CHORDS = [
    [45, 57, 60, 64, 69],   # Am
    [41, 53, 57, 60, 65],   # F
    [38, 50, 57, 62, 65],   # Dm
    [40, 52, 56, 59, 64],   # E
]
LEN = BAR * len(CHORDS)
TAIL = 8.0


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def env(n, a, r):
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, na) ** 2
    e[-nr:] *= np.linspace(1, 0, nr) ** 2
    return e


def pad_note(m, dur, rng):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for det in (-0.07, 0.0, 0.06):
        f = hz(m + det)
        vib = 1 + 0.0025 * np.sin(2 * np.pi * (0.2 + rng.random() * 0.2) * t + rng.random() * 6)
        ph = 2 * np.pi * f * np.cumsum(vib) / SR
        for h, w in ((1, 1.0), (2, 0.35), (3, 0.16), (4, 0.06)):
            out += w * np.sin(h * ph + rng.random() * 6)
    return out * env(n, 3.5, 4.0) / 3.0


def bell(m, rng):
    dur = 5.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    out = np.zeros(n)
    for r, w, d in ((1.0, 1.0, 1.6), (2.76, 0.4, 0.9), (5.4, 0.2, 0.5), (8.9, 0.08, 0.3)):
        out += w * np.sin(2 * np.pi * f * r * t) * np.exp(-t / d)
    out *= np.minimum(1.0, t / 0.004)
    return out


def reverb(x, mix=0.45):
    combs = [(1557, 0.84), (1617, 0.83), (1491, 0.85), (1422, 0.86), (1277, 0.87), (1356, 0.86)]
    y = np.zeros_like(x)
    for d, g in combs:
        b = np.zeros(d + 1)
        b[d] = 1.0
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -g
        y += lfilter(b, a, x)
    y /= len(combs)
    for d, g in ((225, 0.5), (556, 0.5), (441, 0.5)):
        b = np.zeros(d + 1)
        b[0] = -g
        b[d] = 1.0
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -g
        y = lfilter(b, a, y)
    return x * (1 - mix) + y * mix


def main(path):
    rng = np.random.default_rng(7)
    n = int((LEN + TAIL) * SR)
    L = np.zeros(n)
    R = np.zeros(n)
    for i, ch in enumerate(CHORDS):
        start = int(i * BAR * SR)
        for j, m in enumerate(ch):
            note = pad_note(m, BAR + 3.0, rng) * (0.5 if j == 0 else 0.3)
            pan = (j - 2) * 0.18
            end = min(n, start + len(note))
            L[start:end] += note[: end - start] * (1 - pan)
            R[start:end] += note[: end - start] * (1 + pan)
    # bordón grave en La
    t = np.arange(n) / SR
    drone = 0.25 * np.sin(2 * np.pi * hz(33) * t) * (0.8 + 0.2 * np.sin(2 * np.pi * t / LEN))
    L += drone
    R += drone
    # campanitas sueltas
    for k in range(10):
        at = 2.0 + k * 4.7 + rng.random() * 0.8
        bar = int(at // BAR) % len(CHORDS)
        m = CHORDS[bar][rng.integers(2, 5)] + 24
        b = bell(m, rng) * 0.12
        s = int(at * SR)
        e = min(n, s + len(b))
        pan = rng.uniform(-0.6, 0.6)
        L[s:e] += b[: e - s] * (1 - pan)
        R[s:e] += b[: e - s] * (1 + pan)
    L = reverb(L)
    R = reverb(np.roll(R, 300))
    # loop sin costura: la cola se suma al principio
    nl = int(LEN * SR)
    L[: n - nl] += L[nl:]
    R[: n - nl] += R[nl:]
    L, R = L[:nl], R[:nl]
    x = np.stack([L, R], 1)
    x /= np.abs(x).max() + 1e-9
    x *= 0.6
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(path, LEN, "s")


if __name__ == "__main__":
    main(sys.argv[1])
