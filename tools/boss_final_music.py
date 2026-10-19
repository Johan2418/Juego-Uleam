"""Música del DUELO FINAL de cualquier boss (base común; el juez tiene la suya en judge_final_music.py).

Usa el estilo de cada boss definido en tools/boss_music.py (SPECS) y genera:
    <boss>_final1.wav  loop del duelo (un poco más rápido que la fase 3)
    <boss>_final2.wav  más rápido, con un golpe de percusión propio en cada tiempo
    <boss>_final3.wav  al máximo: bombo en corcheas y melodía doblada a la octava
    <boss>_epic.wav    cierre épico al ganar (subida del puente + acorde mayor enorme + su firma)
Uso: python tools/boss_final_music.py <carpeta_salida> <boss> [<boss> ...]
     (lee <carpeta>/../<boss>_p3 si existe para igualar volumen; si no, -13 dB)
Luego convertir a .ogg (ffmpeg -i x.wav -c:a libvorbis -q:a 6 x.ogg).
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boss_music as bm
from boss_music import SR, Track, Song, echo, inst_chord, inst_lead, inst_bass, d_tom, KICK, SNARE, CRASH, OHAT

## velocidad de cada nivel respecto a la fase 3
SPEED = [1.0, 1.08, 1.17]


def accent(spec):
    """Golpe de percusión propio del boss para final2/final3."""
    sig = set(spec.get("signature", ()))
    if "gavel" in sig:
        return bm.GAVEL
    if "heart" in sig:
        return bm.ECG
    if "metal" in sig:
        return bm.METAL
    if "ticker" in sig or "ding" in sig:
        return bm.DING
    if "hex" in sig:
        return bm.METAL
    return SNARE


def song_at(spec, bpm):
    s = dict(spec)
    s["bpm"] = [bpm, bpm, bpm]
    return Song(s)


def loop(spec, bpm, extra):
    song = song_at(spec, bpm)
    secs = [(spec["chB"], spec["B"]), (spec["chA"], spec["A"])]
    L, R, _ = song.render(secs, 3, 0)
    E8 = song.e8(3)
    n = len(L)
    if extra:
        tr = Track(n / SR + 2.0)
        bar = song.bar
        beat = E8 * 2
        beats = int(n / SR / beat)
        acc = accent(spec)
        for b in range(beats):
            t = b * beat
            tr.add(t, acc, 0, 0.14 if b % 2 else 0.22)
            if extra >= 2:
                tr.add(t, KICK, 0, 0.33)
                tr.add(t + E8, KICK, 0, 0.22)
                tr.add(t + E8, OHAT, 0.2, 0.08)
        if extra >= 2:
            bi = 0
            for chords, mel in secs:
                for notes in mel:
                    pos = 0
                    for m, d in notes:
                        if m is not None:
                            tr.add((bi * bar + pos) * E8, inst_lead(spec["lead"], m + 12, d * E8 * 0.9), 0.25, 0.07)
                        pos += d
                    bi += 1
        L = L + tr.L[:n]
        R = R + tr.R[:n]
    return L, R


def epic(spec, bpm):
    song = song_at(spec, bpm)
    half = len(spec["chB"]) // 2
    L1, R1, _ = song.render([(spec["chB"][half:], spec["B"][half:])], 3, 0)
    end = len(L1) / SR
    tr = Track(end + 6.0)
    tr.L[:len(L1)] += L1
    tr.R[:len(R1)] += R1
    for k in range(16):
        tr.add(end - 1.0 + k / 16.0, d_tom(40 + (k % 2) * 2), 0, 0.15 + 0.03 * k)
    tonic = 48 + ((spec["tonic"] - 48) % 12)
    maj = [tonic, tonic + 4, tonic + 7, tonic + 12, tonic + 16, tonic + 19, tonic + 24]
    kind = "organ" if spec.get("rhythm") == "organ" else "pad"
    tr.add(end, inst_chord(kind, maj, 3.2), -0.2, 0.2 if kind == "organ" else 0.16)
    tr.add(end, inst_chord("stab", maj[:4], 0.5), 0.2, 0.18)
    tr.add(end, inst_bass(spec.get("bass_type", "pick"), tonic - 24, 3.0), 0, 0.45)
    for k, m in enumerate([tonic + 24, tonic + 28, tonic + 31, tonic + 36]):
        tr.add(end + k * 0.09, inst_lead(spec["lead"], m, 2.6 - k * 0.09), (k - 1.5) * 0.25, 0.14)
    tr.add(end, CRASH, 0, 0.35)
    tr.add(end, KICK, 0, 0.8)
    tr.add(end, d_tom(38), 0, 0.6)
    sig = set(spec.get("signature", ()))
    if "schoolbell" in sig:
        tr.add(end + 0.5, bm.d_schoolbell(2.5), 0, 0.3)
    elif "applause" in sig or "static" in sig:
        tr.add(end + 0.2, bm.d_applause(3.5), 0, 0.45)
    elif "heart" in sig:
        tr.add(end + 0.6, bm.ECG, 0, 0.6)
        tr.add(end + 1.6, bm.ECG, 0, 0.6)
    elif "ticker" in sig or "ding" in sig:
        tr.add(end + 0.3, bm.DING, 0.2, 0.3)
        tr.add(end + 0.7, bm.DING, -0.2, 0.25)
    elif "metal" in sig or "hex" in sig:
        for k in range(3):
            tr.add(end + 0.6 + k * 0.4, bm.METAL, 0, 0.35)
    tr.add(end + 2.0, CRASH, 0, 0.18)
    L, R = echo(tr.L, tr.R, 0.2, 0.42, 0.24)
    n = int((end + 4.2) * SR)
    fade = np.ones(n)
    fade[-int(1.2 * SR):] = np.linspace(1, 0, int(1.2 * SR))
    return L[:n] * fade, R[:n] * fade


def rms_db(L, R):
    x = np.concatenate([L, R])
    return 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-9)


def build(name, out, ref):
    spec = bm.SPECS[name]
    p3 = spec["bpm"][2]
    parts = {
        f"{name}_final1": loop(spec, p3 * SPEED[0] + 6, 0),
        f"{name}_final2": loop(spec, p3 * SPEED[1] + 6, 1),
        f"{name}_final3": loop(spec, p3 * SPEED[2] + 6, 2),
        f"{name}_epic": epic(spec, p3 + 10),
    }
    boost = [0.0, 0.8, 1.6, 1.5]
    for (fname, (L, R)), b in zip(parts.items(), boost):
        g = 10 ** ((ref + b - rms_db(L, R)) / 20)
        x = np.stack([L, R], 1) * g
        x = np.tanh(x * 1.05) / np.tanh(1.05)
        bm.save(os.path.join(out, fname + ".wav"), x)
        print(fname, "%.1fs" % (len(L) / SR))


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name in sys.argv[2:]:
        ref = -13.0
        refp = os.path.join(out, f"ref_{name}_p3.wav")
        if os.path.exists(refp):
            ref = bm.rms_db(bm.read_wav(refp))
        build(name, out, ref)
