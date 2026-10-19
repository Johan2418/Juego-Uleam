"""Música del duelo final del juez (403 FORBIDDEN): OBJECIÓN FINAL.

Usa el mismo estilo que tools/boss_music.py (órgano barroco en Re menor armónico, timbales y mazo):
    judge_final1.wav  loop del duelo (más rápido que la fase 3)
    judge_final2.wav  loop más rápido, con mazo en cada tiempo
    judge_final3.wav  loop al máximo: bombo en corcheas, mazo y lead doblado a la octava
    judge_epic.wav    cierre épico al ganar el duelo (subida del puente + acorde mayor enorme)
Uso: python tools/judge_final_music.py <carpeta_salida> [referencia_p3.wav]
Luego convertir a .ogg (ffmpeg -i x.wav -c:a libvorbis -q:a 6 x.ogg).
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boss_music as bm
from boss_music import SR, Track, Song, echo, inst_chord, inst_lead, inst_bass, d_tom, KICK, SNARE, CRASH, GAVEL, OHAT

BASE = bm.SPECS["judge"]


def song_at(bpm):
    spec = dict(BASE)
    spec["bpm"] = [bpm, bpm, bpm]
    return Song(spec)


def loop(bpm, extra):
    song = song_at(bpm)
    secs = [(BASE["chB"], BASE["B"]), (BASE["chA"], BASE["A"])]
    L, R, _ = song.render(secs, 3, 0)
    E8 = song.e8(3)
    n = len(L)
    if extra:
        tr = Track(n / SR + 2.0)
        beats = int(n / SR / (E8 * 2))
        for b in range(beats):
            t = b * E8 * 2
            if extra >= 1:
                tr.add(t, GAVEL, 0, 0.16 if b % 2 else 0.24)
            if extra >= 2:
                tr.add(t, KICK, 0, 0.35)
                tr.add(t + E8, KICK, 0, 0.25)
                tr.add(t + E8, OHAT, 0.2, 0.08)
        # lead doblado a la octava en la última intensidad
        if extra >= 2:
            bar = song.bar
            bi = 0
            for chords, mel in secs:
                for k, notes in enumerate(mel):
                    pos = 0
                    for m, d in notes:
                        if m is not None:
                            tr.add((bi * bar + pos) * E8, inst_lead(BASE["lead"], m + 12, d * E8 * 0.9), 0.25, 0.07)
                        pos += d
                    bi += 1
        L = L + tr.L[:n]
        R = R + tr.R[:n]
    return L, R


def epic():
    bpm = 150
    song = song_at(bpm)
    E8 = song.e8(3)
    # subida: segunda mitad del puente (termina en A6 sostenido)
    L1, R1, _ = song.render([(BASE["chB"][4:], BASE["B"][4:])], 3, 0)
    end = len(L1) / SR
    tr = Track(end + 6.0)
    tr.L[:len(L1)] += L1
    tr.R[:len(R1)] += R1
    # redoble de timbales hacia el golpe final
    for k in range(16):
        tr.add(end - 1.0 + k * (1.0 / 16), d_tom(40 + (k % 2) * 2), 0, 0.15 + 0.03 * k)
    # acorde final en RE MAYOR: la sentencia a tu favor
    D = 50
    maj = [D, D + 4, D + 7, D + 12, D + 16, D + 19, D + 24]
    tr.add(end, inst_chord("organ", maj, 3.2), -0.2, 0.2)
    tr.add(end, inst_chord("organ", [m + 12 for m in maj[:4]], 3.2), 0.2, 0.14)
    tr.add(end, inst_bass(BASE.get("bass_type", "organ"), D - 24, 3.0), 0, 0.45)
    for k, m in enumerate([D + 24, D + 28, D + 31, D + 36]):
        tr.add(end + k * 0.09, inst_lead(BASE["lead"], m, 2.6 - k * 0.09), (k - 1.5) * 0.25, 0.14)
    tr.add(end, CRASH, 0, 0.35)
    tr.add(end, KICK, 0, 0.8)
    tr.add(end, d_tom(38), 0, 0.6)
    for k in range(3):
        tr.add(end + 0.7 + k * 0.42, GAVEL, 0, 0.5)
    tr.add(end + 2.0, CRASH, 0, 0.18)
    L, R = echo(tr.L, tr.R, 0.2, 0.42, 0.24)
    n = int((end + 4.2) * SR)
    fade = np.ones(n)
    fade[-int(1.2 * SR):] = np.linspace(1, 0, int(1.2 * SR))
    return L[:n] * fade, R[:n] * fade


def rms_db(L, R):
    x = np.concatenate([L, R])
    return 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-9)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    ref = -15.0
    if len(sys.argv) > 2:
        x = bm.read_wav(sys.argv[2])
        ref = bm.rms_db(x)
    parts = {
        "judge_final1": loop(138, 0),
        "judge_final2": loop(150, 1),
        "judge_final3": loop(164, 2),
        "judge_epic": epic(),
    }
    for name, (L, R) in parts.items():
        boost = {"judge_final1": 0.0, "judge_final2": 0.8, "judge_final3": 1.6, "judge_epic": 1.5}[name]
        g = 10 ** ((ref + boost - rms_db(L, R)) / 20)
        x = np.stack([L, R], 1) * g
        x = np.tanh(x * 1.05) / np.tanh(1.05)
        bm.save(os.path.join(out, name + ".wav"), x)
        print(name, "%.1fs" % (len(L) / SR))
