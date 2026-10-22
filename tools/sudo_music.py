"""Música épica del boss 9 SUDO (Club IA): un estilo distinto por fase.

    sudo_p1  DEMO EN VIVO (Supabase + Cursor)  tecno/trance eléctrico: supersaw con bombeo, arpegio de rayos,
             subidas de ruido y golpes graves al cambiar de sección.
    sudo_p2  AGENTES (Grokbot + Clerk)         industrial oscuro y robótico: guitarra distorsionada, coro grave,
             tartamudeo glitch, sirena de alerta y golpes de metal.
    sudo_p3  TERRA · LUNA · SOL                orquesta cósmica: metales, coro, timbales, campanas estelares.
    sudo_win                                   victoria (tema de la fase 3 en mayor).
    sudo_final1..3                             duelo ASTRA sobre el tema cósmico, cada vez más rápido y lleno.
    sudo_epic                                  cierre al vencer ASTRA.

Usa el motor de tools/boss_music.py (Song, instrumentos, batería) y le suma capas propias (coro, supersaw,
timbales, subidas). Mismo volumen que los otros bosses: la fase 2 queda en -15 dB.
Uso: python tools/sudo_music.py <carpeta_salida>   (luego convertir a .ogg con ffmpeg -c:a libvorbis -q:a 6)
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boss_music as bm
import boss_final_music as bfm
from boss_music import (SR, Track, Song, echo, write_wav, inst_chord, inst_lead, inst_bass, arp_note,
                        d_tom, lp, env, sw, tri, hz, KICK, SNARE, CRASH, OHAT, METAL, DING, M)

rng = np.random.default_rng(9)

# ---------------------------------------------------------------- capas épicas

FORMANTS = ((730, 1.0, 90), (1090, 0.5, 110), (2440, 0.25, 160))   # vocal "ah"


def choir(notes, dur, vowel=FORMANTS, att=0.25):
    """Coro sintético: armónicos con envolvente de formantes, varias voces desafinadas y vibrato lento."""
    n = int((dur + 0.5) * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for m in notes:
        f0 = hz(m)
        for v, det in enumerate((0.996, 1.0, 1.004)):
            ph = 2 * np.pi * f0 * det * (t + 0.004 * np.sin(2 * np.pi * (4.8 + v * 0.4) * t + v))
            h = 1
            while f0 * h < 4000:
                fh = f0 * h
                a = sum(g * np.exp(-((fh - fc) / bw) ** 2 / 2) for fc, g, bw in vowel) + 0.04 / h
                x += a * np.sin(h * ph + v * 1.7)
                h += 1
    x /= max(1, len(notes)) * 3
    return x * env(n, att, 0.2, 0.85, 0.5, int(dur * SR))


def supersaw(notes, dur):
    n = int((dur + 0.1) * SR)
    t = np.arange(n) / SR
    x = sum(sw(hz(m) * d * t + d) for m in notes for d in (0.988, 0.995, 1.0, 1.005, 1.012))
    return lp(x, 3) * env(n, 0.01, 0.15, 0.7, 0.08, int(dur * SR)) / (len(notes) * 2.5)


def timpani(m, length=1.0):
    n = int(length * SR); t = np.arange(n) / SR
    f = hz(m) * (1 + 0.12 * np.exp(-t * 12))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR) * np.exp(-t * 4)
    hit = lp(rng.uniform(-1, 1, n), 3) * np.exp(-t * 40)
    return (body * np.exp(-t * 3.2) + 0.5 * hit) * 0.9


def riser(dur):
    """Subida de ruido + tono que asciende (antes de cada sección)."""
    n = int(dur * SR); t = np.arange(n) / SR
    k = t / dur
    noise = rng.uniform(-1, 1, n)
    nz = noise - lp(noise, int(2 + 10 * 1)) * (1 - k)
    f = 200 * 2 ** (k * 4)
    tone = sw(np.cumsum(f) / SR) * 0.25
    return (nz * 0.35 + tone) * k ** 2


def boom(m=30, length=1.6):
    n = int(length * SR); t = np.arange(n) / SR
    f = hz(m) * (1 + 2.0 * np.exp(-t * 18))
    return np.tanh(np.sin(2 * np.pi * np.cumsum(f) / SR) * 2.2 * np.exp(-t * 2.4)) + 0.3 * lp(rng.uniform(-1, 1, n), 2) * np.exp(-t * 10)


def siren(dur, base=74):
    n = int(dur * SR); t = np.arange(n) / SR
    f = hz(base) * (1 + 0.12 * np.sin(2 * np.pi * 1.6 * t))
    return lp(tri(np.cumsum(f) / SR) + 0.4 * sw(np.cumsum(f) / SR), 2) * env(n, 0.1, 0.1, 0.9, 0.3, n - int(0.3 * SR))


def zap(m):
    """Chispazo eléctrico (rayo verde de Supabase)."""
    n = int(0.18 * SR); t = np.arange(n) / SR
    f = hz(m) * 2 ** (-t * 14)
    return np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * np.exp(-t * 22) * 0.5


def pump(n, E8, depth=0.65):
    """Bombeo tipo sidechain: baja en cada negra y recupera."""
    t = np.arange(n) / SR
    ph = (t % (2 * E8)) / (2 * E8)
    return 1 - depth * np.exp(-ph * 9)


# ---------------------------------------------------------------- fases

SC = "F# G# A B C# D E".split()

P1 = dict(  # DEMO EN VIVO: tecno/trance eléctrico
    bpm=[138, 138, 138], scale=SC, tonic=6, lead="pulse", harm_lead="cold",
    rhythm="stab", stab_at=(1, 3, 4, 6), bass="disco", bass_type="sub", drums="disco",
    signature=("hex",), arp_from=1, intro_chord="F#m", lead_gain=0.2, echo=1.5,
    A=M("C#6:1 F#5:1 C#6:1 F#5:1 E6:2 C#6:2 | D6:1 A5:1 D6:1 A5:1 F#6:2 E6:2 | C#6:1 A5:1 C#6:1 E6:1 A6:3 G#6:1 |"
        "E6:3 B5:1 G#5:2 B5:2 | C#6:1 F#5:1 C#6:1 F#5:1 E6:2 F#6:2 | A6:2 F#6:1 D6:1 E6:2 F#6:2 |"
        "E6:2 C#6:1 A5:1 B5:2 C#6:2 | C#6:4 G#5:2 F5:2"),
    B=M("F#6:4 E6:2 D6:2 | F#6:4 A6:2 F#6:2 | G#6:3 E6:1 B5:4 | C#6:2 F#6:2 A6:2 C#7:2 |"
        "B6:4 A6:2 F#6:2 | A6:4 F#6:2 D6:2 | E6:2 G#6:2 B6:2 G#6:2 | F6:4 G#6:2 C#7:2"),
    chA=["F#m", "D", "A", "E", "F#m", "D", "A", "C#"],
    chB=["Bm", "D", "E", "F#m", "Bm", "D", "E", "C#"],
)

P2 = dict(  # AGENTES: industrial oscuro y robótico
    bpm=[144, 144, 144], scale=SC, tonic=6, lead="guitar", harm_lead="glitch",
    rhythm="chug", bass="drive", bass_type="pick", drums="industrial",
    signature=("glitch", "metal"), arp_from=3, intro_chord="F#m", lead_gain=0.19, echo=1.0,
    A=M("F#5:1 F#5:1 r:1 F#5:1 G5:1 F#5:1 C#6:2 | D6:1 D6:1 r:1 B5:1 G5:2 A5:2 | F#5:1 A5:1 C#6:1 F#6:1 E6:1 C#6:1 A5:2 |"
        "G#5:2 B5:2 E6:3 r:1 | F#6:1 F#6:1 r:1 E6:1 D6:1 A5:1 F#5:2 | F5:1 G#5:1 C#6:1 F6:1 G#6:4 |"
        "A6:2 G6:2 F#6:2 C#6:2 | D6:2 B5:2 C#6:2 G#5:2"),
    B=M("B5:3 C#6:1 D6:2 F#6:2 | G6:4 F#6:2 D6:2 | A6:3 F#6:1 D6:2 A5:2 | G#6:4 F6:2 C#6:2 |"
        "B6:2 A6:2 F#6:2 D6:2 | G6:2 B6:2 D7:2 B6:2 | C#7:3 B6:1 A6:2 E6:2 | D7:2 B6:2 C#7:4"),
    chA=["F#m", "G", "F#m", "E", "D", "C#", "F#m", ("G", "C#")],
    chB=["Bm", "G", "D", "C#", "Bm", "G", "A", ("G", "C#")],
)

P3 = dict(  # TERRA · LUNA · SOL: orquesta cósmica
    bpm=[150, 150, 150], scale=SC, tonic=6, lead="brass", harm_lead="brass",
    rhythm="power", bass="oct", bass_type="pick", drums="rock",
    signature=("ding",), arp_from=2, intro_chord="F#m", lead_gain=0.21, echo=1.5,
    A=M("F#5:3 C#6:1 F#6:4 | F#6:2 E6:1 D6:1 A5:4 | B5:2 C#6:1 D6:1 E6:2 G#6:2 | G#6:4 F6:2 C#6:2 |"
        "F#6:3 A6:1 C#7:4 | B6:2 A6:1 F#6:1 D6:4 | D#6:2 F#6:2 B6:2 A6:2 | G#6:6 F6:2"),
    B=M("A6:3 F#6:1 D6:2 E6:2 | G#6:3 E6:1 B5:2 C#6:2 | C#7:4 A6:2 F#6:2 | E6:2 F#6:2 G#6:2 A6:2 |"
        "A6:3 B6:1 A6:2 F#6:2 | B6:3 C#7:1 B6:2 G#6:2 | C#7:2 B6:2 A#6:4 | F#6:8"),
    chA=["F#m", "D", "E", "C#", "F#m", "D", "B", "C#"],
    chB=["D", "E", "F#m", "F#m", "D", "E", ("C#", "F#"), "F#"],
)


def bars_of(secs):
    """Lista plana (acordes, índice en sección, es_primero, es_último) de una vuelta."""
    out = []
    for chords, _ in secs:
        for i, ch in enumerate(chords):
            out.append((ch, i == 0, i == len(chords) - 1))
    return out


def halves(ch):
    return ch if isinstance(ch, tuple) else (ch, ch)


def chord(song, c, base=52):
    return song.chord_notes(c, base)


# --- capas por fase. Cada función pinta UNA vuelta empezando en t0 (segundos).

def layer_p1(tr, song, E8, t0, secs, power=1.0):
    BAR = song.bar
    padL = Track(len(tr.L) / SR)
    for k, (ch, first, last) in enumerate(bars_of(secs)):
        tb = t0 + k * BAR * E8
        for h, c in enumerate(halves(ch)):
            root, notes = chord(song, c, 60)
            # supersaw en corcheas sincopadas (se bombea luego)
            for i in range(BAR // 2):
                t = tb + (h * BAR // 2 + i) * E8
                padL.add(t, supersaw(notes, E8 * 0.95), -0.4 if i % 2 else 0.4, 0.5)
        root, notes = chord(song, halves(ch)[0], 52)
        if first:
            tr.add(tb, boom(root - 24 + 12 * ((root - 24) < 28)), 0, 0.35 * power)
            tr.add(tb, CRASH, 0.3, 0.12)
        # rayos: chispazos en contratiempos
        for i in (1, 5) if power < 1.2 else (1, 3, 5, 7):
            if rng.random() < 0.6:
                tr.add(tb + i * E8 + E8 / 2, zap(96 + int(rng.integers(0, 8))), rng.uniform(-0.7, 0.7), 0.05)
        if last:
            tr.add(tb, riser(BAR * E8), 0, 0.12 * power)
            for k2 in range(8):
                tr.add(tb + (4 + k2 / 2) * E8, SNARE, 0, 0.06 + 0.025 * k2)
    pm = pump(len(padL.L), E8)
    tr.L += padL.L * pm * 0.85
    tr.R += padL.R * pm * 0.85


def layer_p2(tr, song, E8, t0, secs, power=1.0):
    BAR = song.bar
    for k, (ch, first, last) in enumerate(bars_of(secs)):
        tb = t0 + k * BAR * E8
        root, notes = chord(song, halves(ch)[0], 48)
        tr.add(tb, choir([n for n in notes[:3]], BAR * E8 * 0.98, FORMANTS, 0.15), 0, 0.22 * power)
        if first:
            tr.add(tb, boom(root - 12 if root - 12 >= 28 else root, 1.4), 0, 0.38)
            tr.add(tb, siren(BAR * E8 * 2, 74), 0.5, 0.05)
        # golpes de metal "robot" y pulso de datos en semicorcheas
        if k % 2 == 1:
            tr.add(tb + 7 * E8, METAL, -0.4, 0.09)
        for i in range(BAR * 2):
            if i % 3 == 0:
                tr.add(tb + i * E8 / 2, arp_note(notes[0] + 36 + (7 if i % 6 else 0), E8 / 2, 0.25), 0.6 if i % 2 else -0.6, 0.025)
        if last:
            tr.add(tb, riser(BAR * E8), 0, 0.1)
            tr.add(tb + 6 * E8, timpani(root - 12, 0.8), 0, 0.45)
            tr.add(tb + 7 * E8, timpani(root - 12, 0.8), 0, 0.5)


def layer_p3(tr, song, E8, t0, secs, power=1.0):
    BAR = song.bar
    for k, (ch, first, last) in enumerate(bars_of(secs)):
        tb = t0 + k * BAR * E8
        hs = halves(ch)
        for h, c in enumerate(hs):
            root, notes = chord(song, c, 55)
            dur = BAR * E8 / (2 if hs[0] != hs[1] else 1)
            if h == 1 and hs[0] == hs[1]:
                continue
            th = tb + h * dur
            tr.add(th, choir(notes + [notes[0] + 12], dur * 0.98), 0, 0.2 * power)
            tr.add(th, inst_chord("pad", [n + 12 for n in notes], dur * 0.95), 0, 0.05)
        root, notes = chord(song, hs[0], 52)
        tl = root - 12 if root - 12 >= 36 else root
        # timbales: tónica en 1 y quinta en 5
        tr.add(tb, timpani(tl), 0, 0.55 * power)
        tr.add(tb + 4 * E8, timpani(tl + 7 if tl + 7 < 50 else tl - 5, 0.8), 0, 0.4 * power)
        # campanas estelares cayendo (arpegio de la tríada en lo alto)
        for i, m in enumerate(notes[::-1] + [notes[0] - 12]):
            tr.add(tb + (2 + i) * E8 * 1.0 + (BAR // 2 * E8 if k % 2 else 0) * 0, inst_lead("bell", m + 36, E8), 0.5 - 0.3 * i, 0.03)
        if first:
            tr.add(tb, boom(30, 2.0), 0, 0.32)
            tr.add(tb, CRASH, -0.3, 0.14)
        if last:
            for r in range(16):     # redoble de timbal
                tr.add(tb + 4 * E8 + r * E8 / 4, timpani(tl, 0.3), 0, 0.12 + 0.025 * r)
            tr.add(tb, riser(BAR * E8), 0, 0.07)


def render_phase(spec, level, secs, intro, layer, power=1.0, song=None):
    song = song or Song(spec)
    L, R, loop = song.render(secs, level, intro)
    E8 = song.e8(level)
    BAR = song.bar
    bars = sum(len(c) for c, _ in secs)
    t_bar = BAR * E8
    tr = Track((intro + 2 * bars) * t_bar + 4.0)
    for rep in range(2):
        layer(tr, song, E8, (intro + rep * bars) * t_bar, secs, power)
    oL, oR = echo(tr.L, tr.R, E8 * 3, 0.35, 0.18)
    n_intro = int(intro * t_bar * SR)
    n_body = int(bars * t_bar * SR)
    oL = np.concatenate([oL[:n_intro], oL[n_intro + n_body: n_intro + 2 * n_body]])
    oR = np.concatenate([oR[:n_intro], oR[n_intro + n_body: n_intro + 2 * n_body]])
    m = min(len(L), len(oL))
    return L[:m] + oL[:m], R[:m] + oR[:m], loop


def final_loop(bpm, extra):
    """Duelo ASTRA: tema cósmico acelerado + capas (coro, timbales) que crecen con cada nivel."""
    spec = dict(P3)
    spec["bpm"] = [bpm] * 3
    song = Song(spec)
    secs = [(spec["chB"], spec["B"]), (spec["chA"], spec["A"])]
    L, R = bfm.loop(spec, bpm, extra)
    E8 = song.e8(3)
    t_bar = song.bar * E8
    bars = sum(len(c) for c, _ in secs)
    tr = Track(2 * bars * t_bar + 4.0)
    for rep in range(2):
        layer_p3(tr, song, E8, rep * bars * t_bar, secs, 1.0 + 0.2 * extra)
        if extra >= 1:
            layer_p1(tr, song, E8, rep * bars * t_bar, secs, 1.0 + 0.2 * extra)
    oL, oR = echo(tr.L, tr.R, E8 * 3, 0.35, 0.18)
    n_body = int(bars * t_bar * SR)
    oL, oR = oL[n_body: 2 * n_body], oR[n_body: 2 * n_body]
    m = min(len(L), len(oL))
    return L[:m] + oL[:m] * 0.8, R[:m] + oR[:m] * 0.8


def epic_close():
    """Cierre al vencer ASTRA: subida del puente + acorde mayor enorme con coro y timbales."""
    spec = dict(P3)
    L, R = bfm.epic(spec, spec["bpm"][2] + 10)
    tr = Track(len(L) / SR + 1)
    end = len(L) / SR - 4.2
    tonic = 54   # F#3
    maj = [tonic, tonic + 4, tonic + 7, tonic + 12, tonic + 16]
    tr.add(end - 2.0, riser(2.0), 0, 0.15)
    for r in range(24):
        tr.add(end - 1.5 + r * 1.5 / 24, timpani(42, 0.3), 0, 0.12 + 0.02 * r)
    tr.add(end, choir(maj, 3.4, att=0.08), 0, 0.5)
    tr.add(end, timpani(42, 2.5), 0, 0.9)
    tr.add(end, boom(30, 3.0), 0, 0.5)
    for k, m in enumerate([90, 94, 97, 102, 106]):          # polvo de estrellas
        tr.add(end + 0.3 + k * 0.12, inst_lead("bell", m, 0.4), 0.6 - 0.3 * k, 0.06)
    oL, oR = echo(tr.L, tr.R, 0.24, 0.4, 0.25)
    n = len(L)
    fade = np.ones(n); fade[-int(1.2 * SR):] = np.linspace(1, 0, int(1.2 * SR))
    return L + oL[:n] * fade, R + oR[:n] * fade


def rms(L, R):
    return bfm.rms_db(L, R)


def save_at(out, name, L, R, db):
    g = 10 ** ((db - rms(L, R)) / 20)
    x = np.stack([L, R], 1) * g
    x = np.tanh(x * 1.05) / np.tanh(1.05)
    bm.save(os.path.join(out, name + ".wav"), x)
    print(name, "%.2fs" % (len(L) / SR))


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    order = lambda s: [(s["chA"], s["A"]), (s["chB"], s["B"])]
    L1, R1, intro = render_phase(P1, 2, order(P1), 2, layer_p1)
    L2, R2, _ = render_phase(P2, 2, order(P2), 0, layer_p2)
    L3, R3, _ = render_phase(P3, 3, [(P3["chB"], P3["B"]), (P3["chA"], P3["A"])], 0, layer_p3)
    print("intro p1 = %.4f s" % intro)
    save_at(out, "sudo_p1", L1, R1, -15.6)
    save_at(out, "sudo_p2", L2, R2, -15.0)
    save_at(out, "sudo_p3", L3, R3, -14.4)
    wl, wr = Song(P3).win()
    save_at(out, "sudo_win", wl, wr, -14.0)
    p3 = P3["bpm"][2]
    for k, sp in enumerate(bfm.SPEED):
        L, R = final_loop(p3 * sp + 6, k)
        save_at(out, f"sudo_final{k + 1}", L, R, -14.4 + 0.8 * k)
    L, R = epic_close()
    save_at(out, "sudo_epic", L, R, -12.9)
