"""Tema de jefe original estilo SNES (rock en Mi menor, 160 BPM), sintetizado con numpy.
Salida: WAV 32 kHz estéreo. Estructura: intro (2 compases) + cuerpo en loop (A, A', B, puente)."""
import numpy as np, wave, sys

SR = 32000
BPM = 160
E8 = 60.0 / BPM / 2          # duración de una corchea
BAR = 8                       # corcheas por compás
rng = np.random.default_rng(7)

NOTES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
def midi(n):
    name, octv = n[:-1], int(n[-1])
    return 12 * (octv + 1) + NOTES[name]
def hz(m): return 440.0 * 2 ** ((m - 69) / 12)

def env(n, a, d, s, r, sus_len):
    """ADSR en muestras."""
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    sl = max(0, sus_len - a - d)
    e = np.concatenate([np.linspace(0, 1, max(a, 1)), np.linspace(1, s, max(d, 1)), np.full(sl, s), np.linspace(s, 0, max(r, 1))])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))

def lp(x, k):
    """Paso bajo FIR (promedio móvil de k muestras, dos pasadas)."""
    if k <= 1: return x
    w = np.ones(k) / k
    return np.convolve(np.convolve(x, w, "same"), w, "same")

def pulse(f, t, duty, vib=0.0, vib_delay=0.15):
    ph = f * t
    if vib:
        depth = np.clip((t - vib_delay) / 0.2, 0, 1) * vib
        ph = ph + depth * np.sin(2 * np.pi * 5.5 * t) / (2 * np.pi * 5.5) * f
    return np.where((ph % 1.0) < duty, 1.0, -1.0)

def saw(f, t):
    return 2.0 * ((f * t) % 1.0) - 1.0

class Track:
    def __init__(self, n):
        self.L = np.zeros(n); self.R = np.zeros(n)
    def add(self, start, sig, pan=0.0, gain=1.0):
        s = int(start * SR)
        e = min(len(self.L), s + len(sig))
        if e <= s: return
        sig = sig[: e - s] * gain
        self.L[s:e] += sig * (1 - max(0, pan))
        self.R[s:e] += sig * (1 + min(0, pan))

# ---- instrumentos ----
def lead(m, dur):
    n = int((dur + 0.12) * SR); t = np.arange(n) / SR; f = hz(m)
    x = 0.6 * pulse(f, t, 0.25, vib=0.012) + 0.4 * pulse(f * 1.004, t, 0.5, vib=0.012)
    x = lp(x, 3)
    return x * env(n, 0.005, 0.08, 0.75, 0.1, int(dur * SR))

def guitar(root, dur, mute=True):
    n = int((dur + (0.03 if mute else 0.15)) * SR); t = np.arange(n) / SR
    x = sum(saw(hz(m) * d, t) for m in (root, root + 7, root + 12) for d in (1.0, 1.006))
    x = np.tanh(x * 2.2)
    x = lp(x, 6 if mute else 4)
    e = env(n, 0.002, 0.05 if mute else 0.2, 0.25 if mute else 0.7, 0.03, int(dur * SR))
    return x * e

def bass(m, dur):
    n = int((dur + 0.02) * SR); t = np.arange(n) / SR; f = hz(m)
    x = 0.7 * saw(f, t) + 0.5 * pulse(f, t, 0.5)
    pop = np.exp(-t * 40)
    x = lp(x, 10) * (0.6 + 0.4 * pop) + 0.3 * pulse(f * 2, t, 0.5) * pop
    return np.tanh(x * 1.5) * env(n, 0.002, 0.12, 0.6, 0.02, int(dur * SR))

def arp(m, dur):
    n = int(dur * SR); t = np.arange(n) / SR
    return pulse(hz(m), t, 0.125) * np.exp(-t * 18)

def kick():
    n = int(0.22 * SR); t = np.arange(n) / SR
    f = 50 + 120 * np.exp(-t * 35)
    ph = np.cumsum(f) / SR
    return np.sin(2 * np.pi * ph) * np.exp(-t * 14) + 0.3 * rng.uniform(-1, 1, n) * np.exp(-t * 200)

def snare():
    n = int(0.2 * SR); t = np.arange(n) / SR
    nz = lp(rng.uniform(-1, 1, n), 2)
    return 0.8 * nz * np.exp(-t * 18) + 0.5 * np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)

def hat(open_=False):
    n = int((0.2 if open_ else 0.05) * SR); t = np.arange(n) / SR
    nz = rng.uniform(-1, 1, n); nz = nz - lp(nz, 3)
    return nz * np.exp(-t * (14 if open_ else 70))

def crash():
    n = int(1.4 * SR); t = np.arange(n) / SR
    nz = rng.uniform(-1, 1, n); nz = nz - lp(nz, 2)
    return nz * np.exp(-t * 2.8)

def tom(m):
    n = int(0.25 * SR); t = np.arange(n) / SR
    f = hz(m) * (1 + 0.5 * np.exp(-t * 20))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 10)

KICK, SNARE, HAT, OHAT, CRASH = kick(), snare(), hat(), hat(True), crash()

# ---- composición ----
# acordes por compás (raíz del power chord, en MIDI)
E2, F2, G2, A2, B2, C3, D3 = 40, 41, 43, 45, 47, 48, 50
CH = {"Em": E2, "C": C3 - 12, "D": D3 - 12, "B": B2, "Am": A2, "G": G2}
CHORD_TONES = {"Em": [64, 67, 71], "C": [60, 64, 67], "D": [62, 66, 69], "B": [59, 63, 66], "Am": [57, 60, 64], "G": [55, 59, 62]}

INTRO = ["Em", "Em"]
A = ["Em", "Em", "C", "D", "Em", "Em", ("C", "D"), "B"]
B = ["Am", "Am", "Em", "Em", "C", "D", "B", "B"]
BR = ["C", "D", "Em", "Em", "C", "D", "B", "B"]

MEL_A = [
    [("E5", 2), ("B4", 1), ("E5", 1), ("F#5", 1), ("G5", 2), ("F#5", 1)],
    [("E5", 1), ("D5", 1), ("B4", 2), (None, 2), ("G4", 1), ("A4", 1)],
    [("B4", 2), ("C5", 1), ("D5", 1), ("E5", 2), ("G5", 2)],
    [("F#5", 3), ("E5", 1), ("D5", 2), ("A4", 2)],
    [("E5", 2), ("B4", 1), ("E5", 1), ("F#5", 1), ("G5", 2), ("A5", 1)],
    [("B5", 3), ("A5", 1), ("G5", 2), ("F#5", 2)],
    [("G5", 2), ("E5", 2), ("F#5", 2), ("D5", 2)],
    [("D#5", 4), ("B4", 2), ("F#5", 2)],
]
# segunda vuelta de A: termina subiendo a la parte B
MEL_A2 = MEL_A[:6] + [
    [("G5", 2), ("A5", 2), ("B5", 2), ("C6", 2)],
    [("B5", 4), ("D#6", 2), ("F#6", 2)],
]
MEL_B = [
    [("A5", 3), ("G5", 1), ("E5", 2), ("C5", 2)],
    [("D5", 2), ("E5", 2), ("C5", 4)],
    [("B4", 2), ("E5", 2), ("G5", 2), ("B5", 2)],
    [("A5", 1), ("G5", 1), ("F#5", 2), ("G5", 4)],
    [("E6", 3), ("D6", 1), ("C6", 2), ("B5", 2)],
    [("A5", 3), ("B5", 1), ("C6", 2), ("D6", 2)],
    [("D#6", 4), ("F#6", 2), ("D#6", 2)],
    [("B5", 6), (None, 2)],
]
MEL_BR = [[(None, 8)]] * 4 + [
    [("G5", 2), ("A5", 2), ("B5", 2), ("C6", 2)],
    [("D6", 2), ("E6", 2), ("F#6", 4)],
    [("F#6", 8)],
    [("D#6", 2), ("F#6", 2), ("B6", 4)],
]

SECTIONS = [("intro", INTRO, None), ("A", A, MEL_A), ("A2", A, MEL_A2), ("B", B, MEL_B), ("BR", BR, MEL_BR)]
total_bars = sum(len(s[1]) for s in SECTIONS)
BODY_BARS = total_bars - len(INTRO)
# se renderiza intro + cuerpo + cuerpo para que el eco del final caiga sobre el inicio del loop
render_bars = len(INTRO) + 2 * BODY_BARS
N = int((render_bars * BAR * E8 + 2.0) * SR)
tr = Track(N)

def play_section(bar0, name, chords, mel):
    for bi, ch in enumerate(chords):
        b = bar0 + bi
        t0 = b * BAR * E8
        last = bi == len(chords) - 1
        halves = ch if isinstance(ch, tuple) else (ch, ch)
        for i in range(8):
            c = halves[0] if i < 4 else halves[1]
            root = CH[c]
            t = t0 + i * E8
            # --- guitarra ---
            if name == "intro":
                if i in (0, 3, 6):
                    tr.add(t, guitar(root, E8 * (3 if i < 6 else 2), mute=False), -0.35, 0.18)
                    tr.add(t, guitar(root, E8 * (3 if i < 6 else 2), mute=False), 0.35, 0.18)
            elif name == "BR" and bi < 4:
                if i in (0, 4):
                    tr.add(t, guitar(root, E8 * 4, mute=False), -0.35, 0.15)
                    tr.add(t, guitar(root, E8 * 4, mute=False), 0.35, 0.15)
            elif name == "B" and i in (0, 3, 6) and bi % 2 == 0:
                d = 3 if i < 6 else 2
                tr.add(t, guitar(root, E8 * d, mute=False), -0.35, 0.16)
                tr.add(t, guitar(root, E8 * d, mute=False), 0.35, 0.16)
            elif not (name == "B" and bi % 2 == 0):
                g = 0.17 if i in (0, 3, 6) else 0.11
                tr.add(t, guitar(root, E8 * 0.9, mute=True), -0.35, g)
                tr.add(t, guitar(root, E8 * 0.9, mute=True), 0.35, g)
            # --- bajo: raíz y octava alternadas ---
            if not (name == "BR" and bi < 4 and i % 2 == 1):
                bm = root - 12 + (12 if i % 2 == 1 else 0)
                tr.add(t, bass(bm, E8 * 0.95), 0.0, 0.32)
            # --- arpegio del puente ---
            if name in ("BR", "B"):
                tones = CHORD_TONES[c]
                for k in range(2):
                    m = tones[(i * 2 + k) % 3] + (12 if name == "BR" and bi >= 4 else 0)
                    tr.add(t + k * E8 / 2, arp(m, E8 / 2), 0.5 if k else -0.5, 0.05 if name == "B" else 0.08)
            # --- batería ---
            half = name == "BR" and bi < 4
            if half:
                if i == 0: tr.add(t, KICK, 0, 0.55)
                if i == 4: tr.add(t, SNARE, 0, 0.42)
                if i % 2 == 0: tr.add(t, HAT, 0.2, 0.08)
            elif name == "intro":
                if i in (0, 3, 6): tr.add(t, KICK, 0, 0.55); tr.add(t, CRASH if (i == 0 and bi == 0) else OHAT, 0, 0.12)
                if bi == 1 and i >= 4:
                    for k in range(2): tr.add(t + k * E8 / 2, SNARE, 0, 0.25 + 0.05 * i)
            else:
                if i in (0, 3, 5): tr.add(t, KICK, 0, 0.55)
                if i in (2, 6): tr.add(t, SNARE, 0, 0.42)
                tr.add(t, OHAT if i == 7 else HAT, 0.2, 0.06 if i % 2 else 0.09)
                if bi == 0 and i == 0: tr.add(t, CRASH, -0.2, 0.16)
            # redoble de toms al cerrar cada sección
            if last and name != "intro" and i >= 4:
                for k in range(2):
                    tr.add(t + k * E8 / 2, tom(52 - (i - 4) * 2 - k), 0.3 - 0.15 * (i - 4), 0.3)
        # --- melodía ---
        if mel:
            pos = 0
            for note, d in mel[bi]:
                if note:
                    dur = d * E8 * 0.92
                    x = lead(midi(note), dur)
                    tr.add(t0 + pos * E8, x, -0.1, 0.22)
                    # doble una octava abajo, suave (como el lead de MMX)
                    tr.add(t0 + pos * E8, lead(midi(note) - 12, dur), 0.15, 0.06)
                pos += d

bar = 0
for rep in range(2):
    for name, chords, mel in SECTIONS:
        if name == "intro" and rep == 1:
            continue
        play_section(bar, name, chords, mel)
        bar += len(chords)

# eco estilo SNES (feedback con paso bajo), un poco cruzado entre canales
def echo(x, y, delay, fb, mix):
    d = int(delay * SR)
    outL, outR = x.copy(), y.copy()
    bufL, bufR = np.zeros_like(x), np.zeros_like(y)
    for k in range(1, 7):
        g = fb ** (k - 1)
        sL = np.roll(lp(x, 2 + k), d * k); sL[: d * k] = 0
        sR = np.roll(lp(y, 2 + k), d * k); sR[: d * k] = 0
        bufL += g * (sR if k % 2 else sL)
        bufR += g * (sL if k % 2 else sR)
    return outL + mix * bufL, outR + mix * bufR

L, R = echo(tr.L, tr.R, E8 * 1.5, 0.45, 0.22)
# recorte: intro + segunda vuelta del cuerpo (ya trae el eco del final)
intro_n = int(len(INTRO) * BAR * E8 * SR)
body_n = int(BODY_BARS * BAR * E8 * SR)
L = np.concatenate([L[:intro_n], L[intro_n + body_n: intro_n + 2 * body_n]])
R = np.concatenate([R[:intro_n], R[intro_n + body_n: intro_n + 2 * body_n]])
st = np.stack([L, R], 1)
st = np.tanh(st / (np.abs(st).max() * 0.8) * 1.1) * 0.9
pcm = (st * 32000).astype(np.int16)
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("duración %.2f s, loop desde %.4f s" % (len(L) / SR, intro_n / SR))
