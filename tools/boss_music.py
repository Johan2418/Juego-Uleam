"""Música original de los 8 bosses, estilo SNES (16 bits), sintetizada con numpy.

Por cada boss genera 3 loops (uno por fase, cada vez más intensos) y un final de victoria:
    assets/audio/bosses/<boss>_p1.wav, _p2.wav, _p3.wav, _win.wav
y uno común al perder: assets/audio/bosses/lose.wav
Uso: python tools/boss_music.py <carpeta_salida> [boss ...]
Luego convertir a .ogg (ffmpeg -i x.wav -c:a libvorbis -q:a 6 x.ogg).
"""
import numpy as np, wave, sys, os

SR = 32000
rng = np.random.default_rng(11)

NOTES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
         "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(n):
    return 12 * (int(n[-1]) + 1) + NOTES[n[:-1]]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def parse_chord(c):
    root = c[:2] if len(c) > 1 and c[1] in "#b" else c[:1]
    q = c[len(root):]
    r = NOTES[root]
    iv = {"": [0, 4, 7], "m": [0, 3, 7], "5": [0, 7], "dim": [0, 3, 6], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10]}[q]
    return r, iv


def parse_mel(s):
    bars = []
    for b in s.split("|"):
        b = b.strip()
        if not b:
            continue
        notes = []
        for tok in b.split():
            n, d = tok.split(":")
            notes.append((None if n == "r" else midi(n), float(d)))
        bars.append(notes)
    return bars


# ---------------------------------------------------------------- síntesis básica

def lp(x, k):
    if k <= 1:
        return x
    w = np.ones(k) / k
    return np.convolve(np.convolve(x, w, "same"), w, "same")


def env(n, a, d, s, r, sus):
    a, d, r = max(1, int(a * SR)), max(1, int(d * SR)), max(1, int(r * SR))
    sl = max(0, sus - a - d)
    e = np.concatenate([np.linspace(0, 1, a), np.linspace(1, s, d), np.full(sl, s), np.linspace(s, 0, r)])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def phase_of(f, t, vib=0.0, vib_delay=0.15, rate=5.5):
    ph = f * t
    if vib:
        depth = np.clip((t - vib_delay) / 0.2, 0, 1) * vib
        ph = ph + depth * f * np.sin(2 * np.pi * rate * t) / (2 * np.pi * rate)
    return ph


def sq(ph, duty=0.5):
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def sw(ph):
    return 2.0 * (ph % 1.0) - 1.0


def tri(ph):
    return 2.0 * np.abs(2.0 * (ph % 1.0) - 1.0) - 1.0


# ---------------------------------------------------------------- instrumentos

def inst_lead(kind, m, dur):
    tail = {"bell": 0.6, "musicbox": 0.9, "harpsi": 0.3}.get(kind, 0.12)
    n = int((dur + tail) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    sus = int(dur * SR)
    if kind == "pulse":      # lead de Mega Man X: pulso 25% + 50% desafinado, vibrato tardío
        ph = phase_of(f, t, 0.012)
        x = 0.6 * sq(ph, 0.25) + 0.4 * sq(ph * 1.004, 0.5)
        return lp(x, 3) * env(n, 0.005, 0.08, 0.75, 0.1, sus)
    if kind == "glitch":     # pulso fino que a veces salta de octava (0xDEADBEEF)
        ph = phase_of(f, t, 0.01)
        x = 0.7 * sq(ph, 0.125) + 0.3 * sq(ph * 2.0, 0.5)
        x = np.round(x * 3) / 3
        return lp(x, 2) * env(n, 0.003, 0.05, 0.7, 0.06, sus)
    if kind == "cold":       # sintetizador frío (B.S.O.D.)
        ph = phase_of(f, t, 0.008, 0.3, 4.5)
        x = 0.55 * tri(ph) + 0.3 * sq(ph, 0.5) + 0.25 * tri(ph * 2.003)
        return lp(x, 4) * env(n, 0.02, 0.1, 0.8, 0.15, sus)
    if kind == "brass":      # metales (DIV/0!, KERNEL PANIC)
        ph = phase_of(f, t, 0.01, 0.2)
        x = sw(ph) + 0.6 * sw(ph * 1.005)
        x = lp(np.tanh(x * 0.8), 3)
        return x * env(n, 0.03, 0.1, 0.8, 0.08, sus)
    if kind == "harpsi":     # clavecín (SYNTAX ERROR)
        x = 0.6 * sq(f * t, 0.125) + 0.4 * sq(f * 2 * t, 0.25)
        return lp(x, 2) * np.exp(-t * 3.5) * env(n, 0.002, 0.01, 1.0, 0.05, sus + int(0.3 * SR))
    if kind == "guitar":     # guitarra solista distorsionada (STACK OVERFLOW)
        ph = phase_of(f, t, 0.02, 0.2, 6)
        x = sw(ph) + 0.7 * sw(ph * 1.007) + 0.3 * sq(ph * 0.5, 0.5)
        x = np.tanh(x * 3.0)
        return lp(x, 4) * env(n, 0.004, 0.1, 0.8, 0.08, sus)
    if kind == "organ":      # órgano de iglesia (403 FORBIDDEN)
        x = sum(a * np.sin(2 * np.pi * f * h * t) for h, a in ((1, 0.6), (2, 0.35), (3, 0.25), (4, 0.15), (0.5, 0.3)))
        x = x + 0.15 * sq(f * t, 0.5)
        return x * env(n, 0.02, 0.05, 0.9, 0.08, sus)
    if kind == "musicbox":   # caja de música (MISSING TEXTURE)
        x = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t * 8) + 0.25 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 12)
        return x * np.exp(-t * 2.2) * env(n, 0.002, 0.01, 1.0, 0.2, sus + int(0.5 * SR))
    if kind == "bell":
        x = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 6)
        return x * np.exp(-t * 3)
    raise ValueError(kind)


def inst_bass(kind, m, dur):
    n = int((dur + 0.02) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    sus = int(dur * SR)
    if kind == "slap":
        pop = np.exp(-t * 50)
        x = lp(sw(f * t) + 0.5 * sq(f * t), 6) * (0.7 + 0.5 * pop) + 0.4 * sq(f * 2 * t, 0.25) * pop
        return np.tanh(x * 1.6) * env(n, 0.002, 0.08, 0.5, 0.02, sus)
    if kind == "sub":
        x = np.sin(2 * np.pi * f * t) + 0.35 * tri(f * 2 * t)
        return x * env(n, 0.005, 0.1, 0.8, 0.04, sus)
    if kind == "organ":
        x = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2 * t) + 0.25 * sq(f * t, 0.5)
        return x * env(n, 0.02, 0.05, 0.9, 0.06, sus)
    # "pick": bajo de rock con púa
    pop = np.exp(-t * 40)
    x = 0.7 * sw(f * t) + 0.5 * sq(f * t, 0.5)
    x = lp(x, 10) * (0.6 + 0.4 * pop) + 0.3 * sq(f * 2 * t, 0.5) * pop
    return np.tanh(x * 1.5) * env(n, 0.002, 0.12, 0.6, 0.02, sus)


def inst_chord(kind, notes, dur):
    """notes = alturas MIDI del acorde."""
    tail = {"pad": 0.3, "organ": 0.1, "musicpad": 0.3}.get(kind, 0.04)
    n = int((dur + tail) * SR)
    t = np.arange(n) / SR
    sus = int(dur * SR)
    if kind in ("chug", "power"):
        root = notes[0]
        x = sum(sw(hz(m) * d * t) for m in (root, root + 7, root + 12) for d in (1.0, 1.006))
        x = np.tanh(x * (2.6 if kind == "chug" else 2.2))
        x = lp(x, 6 if kind == "chug" else 4)
        e = env(n, 0.002, 0.05 if kind == "chug" else 0.25, 0.25 if kind == "chug" else 0.7, 0.03, sus)
        return x * e
    if kind == "stab":       # metales o piano cortos
        x = sum(sw(hz(m) * t) + 0.5 * sw(hz(m) * 1.004 * t) for m in notes)
        return np.tanh(lp(x, 4) * 0.6) * env(n, 0.005, 0.08, 0.45, 0.03, sus)
    if kind == "piano":
        x = sum(sq(hz(m) * t, 0.25) * 0.7 + np.sin(2 * np.pi * hz(m) * t) * 0.5 for m in notes)
        return lp(x, 3) * np.exp(-t * 5)
    if kind == "pad":
        x = sum(sw(hz(m) * d * t) for m in notes for d in (0.997, 1.003))
        return lp(x, 14) * env(n, 0.12, 0.2, 0.8, 0.3, sus)
    if kind == "musicpad":
        x = sum(tri(hz(m) * t) for m in notes)
        return lp(x, 6) * env(n, 0.04, 0.2, 0.6, 0.3, sus)
    if kind == "organ":
        x = sum(np.sin(2 * np.pi * hz(m) * t) + 0.4 * np.sin(2 * np.pi * hz(m) * 2 * t) + 0.12 * sq(hz(m) * t, 0.5) for m in notes)
        return x * env(n, 0.03, 0.05, 0.9, 0.1, sus)
    raise ValueError(kind)


def arp_note(m, dur, duty=0.125):
    n = int(dur * SR)
    t = np.arange(n) / SR
    return sq(hz(m) * t, duty) * np.exp(-t * 16)


def _noise(n, hp=True):
    x = rng.uniform(-1, 1, n)
    return x - lp(x, 3) if hp else x


def d_kick():
    n = int(0.22 * SR); t = np.arange(n) / SR
    f = 50 + 120 * np.exp(-t * 35)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14) + 0.3 * rng.uniform(-1, 1, n) * np.exp(-t * 200)


def d_snare():
    n = int(0.2 * SR); t = np.arange(n) / SR
    return 0.8 * lp(rng.uniform(-1, 1, n), 2) * np.exp(-t * 18) + 0.5 * np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)


def d_hat(open_=False):
    n = int((0.2 if open_ else 0.05) * SR); t = np.arange(n) / SR
    return _noise(n) * np.exp(-t * (14 if open_ else 70))


def d_crash():
    n = int(1.4 * SR); t = np.arange(n) / SR
    return lp(_noise(n), 1) * np.exp(-t * 2.8)


def d_tom(m):
    n = int(0.3 * SR); t = np.arange(n) / SR
    f = hz(m) * (1 + 0.5 * np.exp(-t * 20))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def d_metal():
    """Golpe de yunque / metal (obra)."""
    n = int(0.5 * SR); t = np.arange(n) / SR
    x = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in ((523, 7), (1307, 9), (2150, 12), (3417, 16)))
    return x * 0.5 + 0.3 * _noise(n) * np.exp(-t * 60)


def d_gavel():
    """Martillo de juez: madera seca + golpe grave."""
    n = int(0.35 * SR); t = np.arange(n) / SR
    wood = np.sin(2 * np.pi * 820 * t) * np.exp(-t * 60) + 0.6 * _noise(n) * np.exp(-t * 90)
    thud = np.sin(2 * np.pi * np.cumsum(90 + 60 * np.exp(-t * 30)) / SR) * np.exp(-t * 12)
    return wood + thud


def d_ecg():
    n = int(0.12 * SR); t = np.arange(n) / SR
    return np.sin(2 * np.pi * 1000 * t) * env(n, 0.003, 0.01, 1.0, 0.02, int(0.09 * SR)) * 0.6


def d_ding():
    n = int(1.2 * SR); t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 2093 * t) + 0.5 * np.sin(2 * np.pi * 2093 * 2.76 * t) * np.exp(-t * 8)) * np.exp(-t * 3.5)


def d_schoolbell(dur=1.6):
    n = int(dur * SR); t = np.arange(n) / SR
    trem = 0.5 + 0.5 * sq(t * 22, 0.5)
    x = sum(np.sin(2 * np.pi * f * t) for f in (1568, 1568 * 2.4, 1568 * 3.9)) * trem
    return x * np.exp(-t * 1.2) * 0.4


def d_applause(dur=2.5):
    n = int(dur * SR); t = np.arange(n) / SR
    claps = np.zeros(n)
    for _ in range(int(dur * 60)):
        s = rng.integers(0, n - 800)
        claps[s:s + 800] += _noise(800, False) * np.exp(-np.arange(800) / SR * 120) * rng.uniform(0.3, 1)
    return lp(claps, 2) * np.minimum(1, t * 3) * np.minimum(1, (dur - t) * 1.5) * 0.5


def d_static(dur):
    n = int(dur * SR)
    return lp(rng.uniform(-1, 1, n), 2) * 0.5


def d_ticker():
    n = int(0.06 * SR); t = np.arange(n) / SR
    return sq(2600 * t, 0.5) * np.exp(-t * 60) * 0.5


KICK, SNARE, HAT, OHAT, CRASH = d_kick(), d_snare(), d_hat(), d_hat(True), d_crash()
METAL, GAVEL, ECG, DING, TICK = d_metal(), d_gavel(), d_ecg(), d_ding(), d_ticker()


# ---------------------------------------------------------------- mezcla

class Track:
    def __init__(self, seconds):
        self.L = np.zeros(int(seconds * SR))
        self.R = np.zeros(int(seconds * SR))

    def add(self, start, sig, pan=0.0, gain=1.0):
        s = int(start * SR)
        if s < 0:
            sig = sig[-s:]
            s = 0
        e = min(len(self.L), s + len(sig))
        if e <= s:
            return
        sig = sig[: e - s] * gain
        self.L[s:e] += sig * (1 - max(0, pan))
        self.R[s:e] += sig * (1 + min(0, pan))


def echo(L, R, delay, fb, mix):
    d = int(delay * SR)
    oL, oR = L.copy(), R.copy()
    for k in range(1, 6):
        g = mix * fb ** (k - 1)
        sL = np.roll(lp(L, 2 + k), d * k); sL[: d * k] = 0
        sR = np.roll(lp(R, 2 + k), d * k); sR[: d * k] = 0
        oL += g * (sR if k % 2 else sL)
        oR += g * (sL if k % 2 else sR)
    return oL, oR


def write_wav(path, L, R, peak):
    st = np.stack([L, R], 1) / peak
    st = np.tanh(st * 1.1) * 0.9
    with wave.open(path, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((st * 32000).astype(np.int16).tobytes())


# ---------------------------------------------------------------- canción

class Song:
    def __init__(self, spec):
        self.s = spec
        self.bar = spec.get("bar", 8)            # corcheas por compás
        self.scale = [NOTES[n] for n in spec["scale"]]

    def e8(self, level):
        return 60.0 / self.s["bpm"][level - 1] / 2

    def harm(self, m):
        """Una tercera diatónica abajo."""
        pc = m % 12
        if pc in self.scale:
            i = self.scale.index(pc)
            tgt = self.scale[(i - 2) % len(self.scale)]
            d = (pc - tgt) % 12
            return m - d
        return m - 3

    def render(self, sections, level, intro=0):
        """sections: lista de (acordes, melodía). Devuelve L, R del cuerpo (dos vueltas: se usa la segunda)."""
        s = self.s
        E8 = self.e8(level)
        BAR = self.bar
        bars = sum(len(c) for c, _ in sections)
        total = intro + 2 * bars
        tr = Track(total * BAR * E8 + 3.0)
        swing = s.get("swing", 0.0)

        def at(bar, i):
            off = swing * E8 if (i % 2 == 1) else 0.0
            return (bar * BAR + i) * E8 + off

        b = 0
        if intro:
            self.play_intro(tr, at, level, E8)
            b = intro
        for rep in range(2):
            for si, (chords, mel) in enumerate(sections):
                for bi, ch in enumerate(chords):
                    self.play_bar(tr, at, b, ch, level, E8, first=bi == 0, last=bi == len(chords) - 1, sec=si)
                    if mel:
                        self.play_mel(tr, at, b, mel[bi], level, E8)
                    b += 1
        sig = set(s.get("signature", ()))
        if ("glitch" in sig or "glitchend" in sig) and level >= 2:
            # tartamudeo de "textura que falta": el último pulso de cada 4 compases se repite trabado
            seg = int(E8 * SR / 4)
            for bb in range(intro, total):
                if (bb - intro) % 4 != 3:
                    continue
                s0 = int(at(bb, BAR - 2) * SR)
                for buf in (tr.L, tr.R):
                    chunk = buf[s0: s0 + seg].copy()
                    for k in range(8):
                        buf[s0 + k * seg: s0 + (k + 1) * seg] = chunk * (1 - k * 0.08)
        L, R = echo(tr.L, tr.R, E8 * s.get("echo", 1.5), 0.42, 0.2)
        n_intro = int(intro * BAR * E8 * SR)
        n_body = int(bars * BAR * E8 * SR)
        return (np.concatenate([L[:n_intro], L[n_intro + n_body: n_intro + 2 * n_body]]),
                np.concatenate([R[:n_intro], R[n_intro + n_body: n_intro + 2 * n_body]]),
                n_intro / SR)

    # --- partes por compás
    def chord_notes(self, ch, base=52):
        r, iv = parse_chord(ch)
        root = base + ((r - base) % 12)
        return root, [root + i for i in iv]

    def play_intro(self, tr, at, level, E8):
        s = self.s
        ch = s["intro_chord"]
        root, notes = self.chord_notes(ch)
        sig = set(s.get("signature", ()))
        if "schoolbell" in sig:
            tr.add(at(0, 0), d_schoolbell(2 * self.bar * E8), 0.0, 0.35)
        if "static" in sig:
            tr.add(at(0, 0), d_static(self.bar * E8 * 2) * np.linspace(0.2, 1, int(self.bar * E8 * 2 * SR)), 0, 0.25)
        for b in range(2):
            for i in s.get("intro_hits", [0, 3, 6]):
                if i >= self.bar:
                    continue
                hit_k = s.get("rhythm", "chug")
                kind = "power" if hit_k in ("chug", "power") else ("organ" if hit_k == "organ" else "stab")
                tr.add(at(b, i), inst_chord(kind, notes if kind != "power" else [root - 12], E8 * 2), -0.3, 0.17)
                tr.add(at(b, i), inst_chord(kind, notes if kind != "power" else [root - 12], E8 * 2), 0.3, 0.17)
                tr.add(at(b, i), KICK, 0, 0.5)
                tr.add(at(b, i), GAVEL if "gavel" in sig else (METAL if "metal" in sig else OHAT), 0, 0.25 if sig in ("gavel", "metal") else 0.1)
            if b == 1:
                for k in range(8):
                    tr.add(at(1, 4) + k * E8 / 2, SNARE, 0, 0.15 + 0.03 * k)
        tr.add(at(0, 0), CRASH, 0, 0.15)

    def play_bar(self, tr, at, b, ch, level, E8, first, last, sec):
        s = self.s
        BAR = self.bar
        halves = ch if isinstance(ch, tuple) else (ch, ch)
        sig = set(s.get("signature", ()))
        rhythm = s["rhythm"] if level < 3 else s.get("rhythm3", s["rhythm"])
        for i in range(BAR):
            c = halves[0] if i < BAR // 2 else halves[1]
            root, notes = self.chord_notes(c)
            low = root - 12
            t = at(b, i)
            # --- acompañamiento
            if rhythm == "chug":
                g = 0.17 if i in (0, 3, 6) else 0.11
                for p in (-0.35, 0.35):
                    tr.add(t, inst_chord("chug", [low], E8 * 0.9), p, g)
            elif rhythm == "power" and i in (0, 3, 6):
                for p in (-0.35, 0.35):
                    tr.add(t, inst_chord("power", [low], E8 * (3 if i < 6 else 2)), p, 0.15)
            elif rhythm == "stab" and i in s.get("stab_at", (1, 3, 6)):
                tr.add(t, inst_chord("stab", notes, E8 * 0.7), 0.25, 0.09)
            elif rhythm == "piano" and i % 2 == 1:
                tr.add(t, inst_chord("piano", [n + 12 for n in notes], E8), 0.2, 0.08)
            elif rhythm == "pad" and i == 0:
                tr.add(t, inst_chord("pad", [n + 12 for n in notes], E8 * BAR), 0.0, 0.07)
            elif rhythm == "organ" and i == 0:
                tr.add(t, inst_chord("organ", [n + 12 for n in notes], E8 * BAR * 0.98), 0.0, 0.06)
            elif rhythm == "waltz" and i in (2, 4):
                tr.add(t, inst_chord("musicpad", [n + 12 for n in notes], E8 * 1.6), 0.2, 0.09)
            # --- bajo
            bs = s["bass"]
            btype = s.get("bass_type", "pick")
            if bs == "oct":
                tr.add(t, inst_bass(btype, low - 12 + (12 if i % 2 else 0), E8 * 0.95), 0, 0.3)
            elif bs == "drive":
                tr.add(t, inst_bass(btype, low - 12, E8 * 0.9), 0, 0.32)
            elif bs == "walk" and i % 2 == 0:
                step = [0, 7, 12, 7][(i // 2) % 4]
                tr.add(t, inst_bass(btype, low - 12 + step, E8 * 1.8), 0, 0.32)
            elif bs == "slap" and i in (0, 2, 3, 5, 7):
                tr.add(t, inst_bass("slap", low - 12 + (12 if i in (3, 7) else 0), E8 * 0.8), 0, 0.3)
            elif bs == "pedal" and i in (0, BAR // 2):
                tr.add(t, inst_bass(btype, low - 12, E8 * (BAR // 2) * 0.95), 0, 0.3)
            elif bs == "disco":
                tr.add(t, inst_bass(btype, low - 12 + (12 if i % 2 else 0), E8 * 0.8), 0, 0.3)
            elif bs == "waltz" and i == 0:
                tr.add(t, inst_bass(btype, low - 12, E8 * 1.8), 0, 0.3)
            elif bs == "waltz" and i in (2, 4) and level >= 2:
                tr.add(t, inst_bass(btype, low - 12 + 7, E8 * 1.5), 0, 0.2)
            # --- arpegio (fase 2 y 3, o siempre si el boss lo pide)
            if level >= s.get("arp_from", 2):
                tones = notes[:3] if len(notes) >= 3 else notes + [notes[0] + 12]
                up = 12 if level == 3 else 0
                for k in range(2):
                    m = tones[(i * 2 + k) % len(tones)] + 12 + up
                    tr.add(t + k * E8 / 2, arp_note(m, E8 / 2), 0.5 if k else -0.5, 0.045)
            # --- firma del boss
            if "hex" in sig and level >= 2 and (b * BAR + i) % 5 == 0:
                for k in range(2):
                    m = 84 + int(rng.integers(0, 16))
                    tr.add(t + k * E8 / 2, arp_note(m, E8 / 2, 0.5), 0.6, 0.035)
            if "ticker" in sig and level >= 1 and i % 2 == 1 and rng.random() < 0.5:
                tr.add(t, TICK, 0.6 if i % 4 == 1 else -0.6, 0.05)
            if "metal" in sig and i in ((1, 5) if level < 3 else (1, 3, 5, 7)):
                tr.add(t, METAL, -0.3 if i in (1, 5) else 0.3, 0.07)
            if "gavel" in sig and i == 0 and (b % 2 == 0 or level == 3):
                tr.add(t, GAVEL, 0, 0.28)
            if "stack" in sig and level >= 2 and i % 2 == 0:
                # arpegio que se "apila": cada compás sube un poco más
                m = notes[0] + 24 + ((b % 4) * 2 + i // 2) * 2
                tr.add(t, arp_note(m, E8, 0.25), 0.4, 0.04)
            if "static" in sig and level == 3 and i == 0:
                tr.add(t, d_static(BAR * E8) * 0.15, 0, 0.3)
            # --- batería
            self.drums(tr, t, i, b, level, E8, first, last)
        if "applause" in sig and last and level >= 2:
            tr.add(at(b, 0), d_applause(BAR * E8), 0, 0.25)
        if "ding" in sig and first:
            tr.add(at(b, 0), DING, 0.3, 0.06)

    def drums(self, tr, t, i, b, level, E8, first, last):
        s = self.s
        style = s["drums"]
        BAR = self.bar
        if first and i == 0 and level >= 2 and style != "heart":
            tr.add(t, CRASH, -0.2, 0.15)
        if style == "heart":
            # latido: lub-dub en cada pulso del corazón, con bip de monitor
            beat = {1: (0,), 2: (0, 4), 3: (0, 4)}[level]
            if i in beat:
                tr.add(t, KICK, 0, 0.55)
                tr.add(t + 0.13, KICK, 0, 0.32)
                if i == 0:
                    tr.add(t, ECG, 0.4, 0.5)
            if level >= 2 and i in (2, 6):
                tr.add(t, SNARE, 0, 0.3)
            if level >= 2:
                tr.add(t, HAT, 0.2, 0.05 if i % 2 else 0.07)
            if level == 3:
                tr.add(t + E8 / 2, HAT, -0.2, 0.04)
            if level == 1 and i % 2 == 0:
                tr.add(t, HAT, 0.2, 0.04)
        elif style == "waltz":
            if level == 1:
                if i == 0:
                    tr.add(t, KICK, 0, 0.35)
                if i in (2, 4):
                    tr.add(t, HAT, 0.2, 0.06)
            else:
                if i == 0 or (level == 3 and i == 3):
                    tr.add(t, KICK, 0, 0.5)
                if i in (2, 4):
                    tr.add(t, SNARE, 0, 0.25 if level == 2 else 0.35)
                tr.add(t, HAT, 0.2, 0.06)
                if level == 3:
                    tr.add(t + E8 / 2, HAT, -0.2, 0.04)
        elif style == "baroque":
            if i in (0, 4):
                tr.add(t, d_tom(38 if i == 0 else 33), 0, 0.45)
            if level >= 2:
                if i in (2, 6):
                    tr.add(t, SNARE, 0, 0.33)
                if i in (0, 3, 5):
                    tr.add(t, KICK, 0, 0.45)
                tr.add(t, HAT, 0.2, 0.06 if i % 2 else 0.09)
            if level == 3:
                tr.add(t + E8 / 2, HAT, -0.2, 0.04)
        else:
            pat = {
                "rock": ((0, 3, 5), (2, 6)),
                "funk": ((0, 3, 5), (2, 6)),
                "disco": ((0, 2, 4, 6), (2, 6)),
                "march": ((0, 4), (2, 6)),
                "industrial": ((0, 1, 3, 4, 5), (2, 6)),
            }[style]
            kicks, snares = pat
            if level == 1 and style != "march":
                kicks = tuple(k for k in kicks if k in (0, 4, 3))
            if i in kicks:
                tr.add(t, KICK, 0, 0.55)
            if level == 3 and style in ("rock", "industrial"):
                tr.add(t + E8 / 2, KICK, 0, 0.3)
            if i in snares:
                tr.add(t, SNARE, 0, 0.42)
            if style == "funk" and i == 7:
                tr.add(t, SNARE, 0, 0.12)
            if style == "march" and i in (3, 7):
                for k in range(2):
                    tr.add(t + k * E8 / 2, SNARE, 0, 0.12 + 0.05 * level)
            if style == "disco":
                tr.add(t, OHAT if i % 2 else HAT, 0.2, 0.08 if i % 2 else 0.05)
            else:
                tr.add(t, OHAT if i == 7 else HAT, 0.2, 0.06 if i % 2 else 0.09)
            if level == 3:
                tr.add(t + E8 / 2, HAT, -0.2, 0.035)
        # redoble al cerrar la sección
        if last and i >= BAR - 4 and style not in ("waltz", "heart"):
            for k in range(2):
                tr.add(t + k * E8 / 2, d_tom(52 - (i - BAR + 4) * 2 - k), 0.3 - 0.15 * (i - BAR + 4), 0.25)
        if last and style in ("waltz", "heart") and level >= 2 and i >= BAR - 2:
            for k in range(2):
                tr.add(t + k * E8 / 2, SNARE, 0, 0.15 + 0.05 * k)

    def play_mel(self, tr, at, b, bar_notes, level, E8):
        s = self.s
        kind = s["lead"]
        pos = 0.0
        for m, d in bar_notes:
            if m is not None:
                i = int(pos)
                t = at(b, i) + (pos - i) * E8
                dur = d * E8 * 0.92
                up = s.get("p3_up", 0) if level == 3 else 0
                mm = m + up
                tr.add(t, inst_lead(kind, mm, dur), -0.1, s.get("lead_gain", 0.22))
                if s.get("double", True):
                    tr.add(t, inst_lead(kind, mm - 12, dur), 0.15, 0.06)
                if level >= 2:
                    # segunda voz una tercera abajo
                    tr.add(t, inst_lead(s.get("harm_lead", kind), self.harm(mm), dur), 0.35, 0.08 if level == 2 else 0.1)
            pos += d

    # --- final de victoria
    def win(self):
        s = self.s
        E8 = self.e8(1) * 1.4
        BAR = self.bar
        tr = Track(14.0)
        mel = s["A"][:2]
        sig = set(s.get("signature", ()))
        pos = 0.0
        t0 = 0.0
        # primeros dos compases del tema, lentos y en mayor
        for bar_notes in mel:
            for m, d in bar_notes:
                if m is not None:
                    mm = m
                    if s.get("minor", True) and (m - s["tonic"]) % 12 == 3:
                        mm = m + 1
                    tr.add(t0 + pos * E8, inst_lead(s["lead"], mm, d * E8 * 0.95), -0.1, 0.24)
                    tr.add(t0 + pos * E8, inst_lead(s["lead"], self.harm(mm), d * E8 * 0.95), 0.3, 0.09)
                pos += d
        end = t0 + pos * E8
        # acorde final mayor sobre la tónica
        tonic = 52 + ((s["tonic"] - 52) % 12)
        maj = [tonic, tonic + 4, tonic + 7, tonic + 12]
        for k, m in enumerate(maj):
            tr.add(end + k * 0.06, inst_lead(s["lead"], m + 12, 2.2), (k - 1.5) * 0.2, 0.12)
        tr.add(end, inst_chord("pad", [m + 12 for m in maj], 2.4), 0, 0.12)
        tr.add(end, inst_bass(s.get("bass_type", "pick"), tonic - 24, 2.2), 0, 0.35)
        tr.add(end, CRASH, 0, 0.25)
        tr.add(end, KICK, 0, 0.6)
        for k in range(6):
            tr.add(end - 0.6 + k * 0.1, SNARE, 0, 0.12 + 0.04 * k)
        if "schoolbell" in sig:
            tr.add(end + 0.2, d_schoolbell(2.5), 0, 0.3)
        elif "gavel" in sig:
            for k in range(3):
                tr.add(end + 0.4 + k * 0.35, GAVEL, 0, 0.4)
        elif "applause" in sig or "static" in sig:
            tr.add(end, d_applause(3.5), 0, 0.45)
        elif "ticker" in sig or "ding" in sig:
            tr.add(end + 0.1, DING, 0.2, 0.25)
        elif "metal" in sig:
            tr.add(end, METAL, 0, 0.3)
        elif "heart" in sig:
            tr.add(end + 0.4, ECG, 0, 0.6)
            tr.add(end + 1.4, ECG, 0, 0.6)
        L, R = echo(tr.L, tr.R, 0.18, 0.4, 0.22)
        n = int((end + 3.2) * SR)
        fade = np.ones(n); fade[-int(0.8 * SR):] = np.linspace(1, 0, int(0.8 * SR))
        return L[:n] * fade, R[:n] * fade


def lose():
    """Jingle común al perder: bajada cromática y acorde menor apagándose."""
    tr = Track(5.0)
    seq = [76, 75, 74, 73, 71, 70, 69]
    for k, m in enumerate(seq):
        tr.add(k * 0.16, inst_lead("pulse", m, 0.14), -0.1, 0.22)
    end = len(seq) * 0.16
    for m in (57, 60, 64):
        tr.add(end, inst_lead("pulse", m, 1.6), 0.1, 0.12)
    tr.add(end, inst_bass("pick", 33, 1.6), 0, 0.35)
    tr.add(end, d_tom(40), 0, 0.5)
    L, R = echo(tr.L, tr.R, 0.2, 0.45, 0.25)
    n = int((end + 2.4) * SR)
    fade = np.ones(n); fade[-int(1.0 * SR):] = np.linspace(1, 0, int(1.0 * SR))
    return L[:n] * fade, R[:n] * fade


# ---------------------------------------------------------------- los 8 bosses

M = parse_mel
SPECS = {
    # 1. Ciencias de la Vida y Tecnología: bestia biotecnológica. Mi frigio, rock pesado con bips hexadecimales.
    "deadbeef": dict(
        bpm=[150, 156, 166], scale="E F G A B C D".split(), tonic=4, lead="glitch", harm_lead="pulse",
        rhythm="chug", rhythm3="power", bass="oct", drums="rock", signature=("hex", "glitchend"), intro_chord="E5",
        A=M("E5:1 E5:1 F5:1 E5:1 B4:2 r:1 E5:1 | G5:2 F5:1 E5:1 D5:2 E5:2 | F5:3 E5:1 C5:2 A4:2 | B4:6 r:2 |"
            "E5:1 E5:1 F5:1 E5:1 B4:2 r:1 E5:1 | G5:2 A5:1 B5:1 C6:2 B5:2 | A5:2 G5:2 F5:2 E5:2 | F5:4 E5:4"),
        B=M("C6:3 B5:1 A5:2 G5:2 | A5:2 B5:2 F#5:4 | G5:2 E5:2 B5:4 | A5:1 G5:1 F#5:1 G5:1 E5:4 |"
            "C6:2 D6:2 E6:2 C6:2 | D6:3 C6:1 B5:2 A5:2 | B5:8 | D#6:4 F#6:4"),
        chA=["Em", "Em", "F", "Em", "Em", "Em", "G", ("F", "E")],
        chB=["C", "D", "Em", "Em", "C", "D", "B", "B"],
    ),
    # 2. Ciencias de la Salud: cirujano robot. Si menor, sintetizador frío; la batería es su latido (60/90/140).
    "bsod": dict(
        bpm=[120, 135, 140], scale="B C# D E F# G A".split(), tonic=11, lead="cold", rhythm="pad",
        bass="pedal", bass_type="sub", drums="heart", signature=("heart",), arp_from=1, intro_chord="Bm",
        intro_hits=[0], double=False, lead_gain=0.24,
        A=M("F#5:4 D5:2 B4:2 | D5:2 E5:2 F#5:2 G5:2 | A5:4 F#5:2 D5:2 | E5:6 C#5:2 |"
            "F#5:4 D5:2 B4:2 | G5:3 F#5:1 E5:2 D5:2 | E5:2 F#5:2 G5:2 E5:2 | F#5:6 r:2"),
        B=M("B5:3 A5:1 G5:2 F#5:2 | A5:3 G5:1 F#5:2 E5:2 | F#5:2 D5:2 B5:4 | B5:2 C#6:2 D6:4 |"
            "E6:3 D6:1 C#6:2 B5:2 | A#5:4 F#5:4 | B5:2 D6:2 F#6:4 | F#6:4 A#5:4"),
        chA=["Bm", "G", "D", "A", "Bm", "G", "Em", "F#"],
        chB=["G", "A", "Bm", "Bm", "Em", "F#", "Bm", "F#"],
    ),
    # 3. Administrativas: ejecutivo de la bóveda. Re dórico, funk con metales, swing y teletipo de la bolsa.
    "div0": dict(
        bpm=[128, 134, 144], scale="D E F G A B C".split(), tonic=2, lead="brass", rhythm="stab",
        bass="slap", bass_type="slap", drums="funk", signature=("ticker", "ding"), swing=0.16, intro_chord="Dm",
        stab_at=(1, 3, 6), lead_gain=0.2,
        A=M("D5:1 F5:1 r:1 G5:1 A5:2 r:1 C6:1 | B5:2 A5:1 G5:1 F5:2 E5:2 | D5:1 F5:1 r:1 G5:1 A5:2 G5:1 F5:1 | G5:6 r:2 |"
            "A5:2 C6:2 A5:1 G5:1 F5:2 | E5:2 G5:2 C6:4 | D6:2 C6:1 Bb5:1 A5:2 G5:2 | A5:4 C#6:4"),
        B=M("D6:2 r:1 D6:1 C6:2 Bb5:2 | C#6:3 E6:1 A5:4 | F6:2 E6:2 D6:2 A5:2 | D6:6 r:2 |"
            "D6:2 F6:2 E6:2 D6:2 | E6:2 G6:2 C6:4 | C#6:2 E6:2 A6:4 | A6:4 E6:2 C#6:2"),
        chA=["Dm7", "G7", "Dm7", "G7", "F", "C", "Bb", "A7"],
        chB=["Gm", "A", "Dm", "Dm", "Bb", "C", "A", "A7"],
    ),
    # 4. Educación: profesor robot. Sol menor, marcha escolar con clavecín y timbre de la escuela.
    "syntax": dict(
        bpm=[126, 132, 142], scale="G A Bb C D Eb F#".split(), tonic=7, lead="harpsi", harm_lead="bell",
        rhythm="piano", bass="walk", drums="march", signature=("schoolbell",), intro_chord="Gm", lead_gain=0.24,
        A=M("G5:2 D5:1 G5:1 Bb5:2 A5:1 G5:1 | F#5:2 A5:2 D5:4 | G5:2 D5:1 G5:1 Bb5:2 C6:1 D6:1 | A5:6 r:2 |"
            "Bb5:2 G5:1 Bb5:1 Eb6:2 D6:2 | D6:2 C6:1 Bb5:1 F5:4 | G5:2 A5:2 Bb5:2 C6:2 | D6:4 A5:2 F#5:2"),
        B=M("G5:1 A5:1 Bb5:1 C6:1 Eb6:2 D6:2 | D6:4 Bb5:2 G5:2 | A5:2 F#5:2 D5:2 A5:2 | G5:6 r:2 |"
            "G5:2 Bb5:2 Eb6:2 G6:2 | F6:2 Eb6:2 C6:2 A5:2 | Bb5:2 D6:2 F6:2 D6:2 | F#6:4 D6:4"),
        chA=["Gm", "D", "Gm", "D", "Eb", "Bb", "Cm", "D"],
        chB=["Cm", "Gm", "D", "Gm", "Eb", "F", "Bb", "D"],
    ),
    # 5. Ingeniería: máquina de obra. La menor, metal industrial con yunques y un arpegio que se apila.
    "stack": dict(
        bpm=[144, 150, 160], scale="A B C D E F G".split(), tonic=9, lead="guitar", rhythm="chug",
        rhythm3="chug", bass="drive", drums="industrial", signature=("metal", "stack"), intro_chord="A5", lead_gain=0.19,
        A=M("A4:1 A4:1 C5:1 A4:1 D5:1 A4:1 E5:2 | A4:1 A4:1 C5:1 A4:1 G5:2 E5:2 | F5:2 E5:1 D5:1 C5:2 D5:2 | E5:6 r:2 |"
            "A5:2 G5:1 E5:1 A5:2 B5:1 C6:1 | B5:2 G5:2 E5:4 | C6:2 B5:2 A5:2 E5:2 | G#5:6 r:2"),
        B=M("A5:3 C6:1 F6:4 | D6:3 B5:1 G5:4 | A5:2 C6:2 E6:2 A6:2 | G6:2 E6:2 A6:4 |"
            "F6:3 E6:1 D6:2 C6:2 | D6:3 C6:1 B5:2 G5:2 | E6:4 G#6:4 | B6:8"),
        chA=["Am", "Am", "F", "G", "Am", "Am", "C", "E"],
        chB=["F", "G", "Am", "Am", "F", "G", "E", "E"],
    ),
    # 6. Sociales y Derecho: juez robot. Re menor armónico, órgano barroco, timbales y el martillo del juez.
    "judge": dict(
        bpm=[118, 124, 134], scale="D E F G A Bb C#".split(), tonic=2, lead="organ", rhythm="organ",
        bass="pedal", bass_type="organ", drums="baroque", signature=("gavel",), intro_chord="Dm",
        intro_hits=[0, 4], double=False, lead_gain=0.17,
        A=M("D5:1 E5:1 F5:1 G5:1 A5:2 D5:2 | C#5:1 D5:1 E5:1 F5:1 E5:2 A4:2 | D5:1 E5:1 F5:1 G5:1 A5:2 Bb5:1 A5:1 | G5:1 F5:1 E5:1 D5:1 C#5:4 |"
            "D6:2 A5:2 Bb5:1 A5:1 G5:1 F5:1 | A5:2 F5:2 C5:2 F5:2 | G5:1 A5:1 Bb5:1 G5:1 E5:2 G5:2 | A5:6 r:2"),
        B=M("Bb5:2 G5:2 D6:2 Bb5:2 | A5:2 F5:2 D6:2 A5:2 | C#6:1 D6:1 E6:1 C#6:1 A5:4 | D6:2 F6:2 A6:4 |"
            "Bb6:2 A6:1 G6:1 F6:2 D6:2 | G6:2 F6:1 E6:1 D6:2 Bb5:2 | A5:2 C#6:2 E6:2 G6:2 | A6:8"),
        chA=["Dm", "A", "Dm", "A", "Bb", "F", "Gm", "A"],
        chB=["Gm", "Dm", "A", "Dm", "Bb", "Gm", "A", "A"],
    ),
    # 7. Artes: estatua del museo. Do# menor, vals de caja de música que se congela con estática.
    "tex": dict(
        bpm=[150, 156, 170], bar=6, scale="C# D# E F# G# A C".split(), tonic=1, lead="musicbox", harm_lead="bell",
        rhythm="waltz", bass="waltz", bass_type="sub", drums="waltz", signature=("glitch",), intro_chord="C#m",
        intro_hits=[0], double=False, lead_gain=0.26, echo=2.0,
        A=M("G#5:2 C#6:2 E6:2 | D#6:4 C#6:2 | C#6:2 E6:2 A6:2 | G#6:4 E6:2 |"
            "F#6:2 E6:2 D#6:2 | D#6:2 C6:2 G#5:2 | C#6:2 E6:2 G#6:2 | G#6:4 r:2"),
        B=M("A6:3 G#6:1 F#6:2 | F#6:3 E6:1 D#6:2 | E6:2 G#6:2 B6:2 | B6:6 |"
            "A6:2 F#6:2 C#6:2 | C6:2 D#6:2 G#6:2 | G#6:2 E6:2 C#6:2 | C#6:6"),
        chA=["C#m", "C#m", "A", "A", "F#m", "G#", "C#m", "G#"],
        chB=["A", "B", "E", "E", "F#m", "G#", "C#m", "C#m"],
    ),
    # 8. Técnicas y Tecnológicas: chef presentador de TV. Fa mayor, funk de programa de concursos con aplausos.
    "kp": dict(
        bpm=[146, 150, 160], scale="F G A Bb C D E".split(), tonic=5, minor=False, lead="brass", harm_lead="pulse",
        rhythm="stab", bass="disco", bass_type="slap", drums="disco", signature=("applause", "static"), intro_chord="F",
        stab_at=(0, 3, 6), lead_gain=0.2,
        A=M("C6:1 A5:1 C6:1 D6:1 r:1 C6:1 A5:2 | F5:2 G5:2 A5:4 | D6:1 C6:1 A5:1 F5:1 r:1 A5:1 C6:2 | D6:6 r:2 |"
            "Bb5:2 D6:2 F6:2 D6:2 | C6:2 E6:2 G6:4 | F6:2 E6:1 D6:1 C6:2 A5:2 | G5:4 C6:4"),
        B=M("D6:2 F6:2 Bb6:2 F6:2 | E6:2 G6:2 C7:4 | C7:2 A6:2 E6:2 C6:2 | D6:6 r:2 |"
            "Bb5:2 D6:2 G6:2 Bb6:2 | A6:2 G6:2 E6:2 C6:2 | F6:3 E6:1 F6:2 A6:2 | C7:6 r:2"),
        chA=["F", "F", "Dm", "Dm", "Bb", "C", "F", "C"],
        chB=["Bb", "C", "Am", "Dm", "Gm", "C", "F", "C"],
    ),
    # 9. Club IA: SUDO, el expositor. Fa# menor, synthwave de "keynote" con bips de datos y arpegios desde el inicio.
    "sudo": dict(
        bpm=[128, 136, 148], scale="F# G# A B C# D E".split(), tonic=6, lead="cold", harm_lead="pulse",
        rhythm="stab", bass="oct", bass_type="sub", drums="disco", signature=("hex",), arp_from=1, intro_chord="F#m",
        stab_at=(0, 3, 6), lead_gain=0.22,
        A=M("F#5:2 C#6:2 A5:1 B5:1 C#6:2 | E6:2 D6:1 C#6:1 B5:2 A5:2 | F#5:2 A5:2 C#6:2 F#6:2 | E6:6 r:2 |"
            "D6:2 C#6:1 B5:1 A5:2 B5:2 | C#6:2 E6:2 A5:4 | B5:2 D6:2 F#6:2 E6:2 | C#6:4 G#5:4"),
        B=M("A5:3 B5:1 C#6:2 E6:2 | F#6:4 E6:2 C#6:2 | D6:2 F#6:2 A6:2 F#6:2 | E6:6 r:2 |"
            "D6:2 E6:2 F#6:2 A6:2 | G#6:2 E6:2 C#6:4 | F#6:3 E6:1 D6:2 C#6:2 | C#6:8"),
        chA=["F#m", "D", "A", "E", "Bm", "A", "D", "C#"],
        chB=["D", "E", "Bm", "A", "D", "E", "F#m", "C#"],
    ),
}


def build(name, out):
    spec = SPECS[name]
    song = Song(spec)
    A, B = spec["A"], spec["B"]
    chA, chB = spec["chA"], spec["chB"]
    parts = {
        1: ([(chA, A), (chB, B)], 2),          # fase 1: tema y puente, sencillo (con intro)
        2: ([(chA, A), (chB, B)], 0),          # fase 2: tema + puente, con segunda voz y arpegios
        3: ([(chB, B), (chA, A)], 0),          # fase 3: más rápida y con todo
    }
    outs = {}
    for lv, (secs, intro) in parts.items():
        L, R, loop = song.render(secs, lv, intro)
        outs[lv] = (L, R, loop)
    wl, wr = song.win()
    peak = max(max(np.abs(L).max(), np.abs(R).max()) for L, R, _ in outs.values()) * 0.85
    info = {}
    for lv, (L, R, loop) in outs.items():
        write_wav(os.path.join(out, f"{name}_p{lv}.wav"), L, R, peak)
        info[lv] = (len(L) / SR, loop)
    write_wav(os.path.join(out, f"{name}_win.wav"), wl, wr, max(np.abs(wl).max(), np.abs(wr).max()) * 0.95)
    return info


def read_wav(path):
    with wave.open(path) as w:
        return np.frombuffer(w.readframes(w.getnframes()), np.int16).reshape(-1, 2).astype(float) / 32768


def save(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32000).astype(np.int16).tobytes())


def rms_db(x):
    return 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-9)


def normalize(out, names, target=-15.0):
    """Mismo volumen entre bosses: la fase 2 de cada uno queda en `target` dB y las otras guardan su diferencia."""
    for n in names:
        p2 = read_wav(os.path.join(out, f"{n}_p2.wav"))
        g = 10 ** ((target - rms_db(p2)) / 20)
        for part in ("p1", "p2", "p3"):
            f = os.path.join(out, f"{n}_{part}.wav")
            x = read_wav(f) * g
            save(f, np.tanh(x * 1.05) / np.tanh(1.05))
        f = os.path.join(out, f"{n}_win.wav")
        x = read_wav(f)
        x = x * 10 ** ((target + 1 - rms_db(x)) / 20)
        save(f, np.tanh(x * 1.05) / np.tanh(1.05))


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    names = sys.argv[2:] or list(SPECS)
    for n in names:
        info = build(n, out)
        print(n, {k: "%.1fs loop %.3f" % v for k, v in info.items()})
    L, R = lose()
    write_wav(os.path.join(out, "lose.wav"), L, R, max(np.abs(L).max(), np.abs(R).max()) * 0.95)
    normalize(out, names)
