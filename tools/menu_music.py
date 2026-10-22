"""Música de la portada y de la sala de entrenamiento (mismo motor que los bosses: boss_music.py).

    title_theme     himno heroico en Re mayor (metales, coro, timbales): suena con las sombras de los bosses.
    training_theme  rock-funk con ganas de practicar (guitarra, slap, batería rock).
Uso: python tools/menu_music.py <carpeta_salida>   -> title_theme.wav, training_theme.wav
Luego: ffmpeg -i x.wav -c:a libvorbis -q:a 6 assets/audio/x.ogg
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boss_music as bm
import sudo_music as sm
from boss_music import SR, Track, Song, echo, M

TITLE = dict(
    bpm=[112, 112, 112], scale="D E F# G A B C#".split(), tonic=2, lead="brass", harm_lead="brass",
    rhythm="power", bass="oct", bass_type="pick", drums="march", signature=(), arp_from=3,
    intro_chord="D", lead_gain=0.2, minor=False,
    A=M("D5:3 A5:1 D6:4 | C#6:2 B5:1 A5:1 F#5:4 | G5:2 A5:1 B5:1 D6:2 B5:2 | A5:6 r:2 |"
        "D6:3 E6:1 F#6:4 | G6:2 F#6:1 E6:1 D6:4 | B5:2 C#6:2 D6:2 E6:2 | A5:8"),
    B=M("B5:3 A5:1 G5:2 B5:2 | A5:4 F#5:2 D5:2 | G5:3 A5:1 B5:2 C#6:2 | D6:6 r:2 |"
        "E6:3 D6:1 C#6:2 B5:2 | C#6:4 A5:4 | B5:2 C#6:2 D6:2 F#6:2 | E6:8"),
    chA=["D", "A", "G", "A", "D", "G", "Bm", "A"],
    chB=["G", "D", "G", "D", "Em", "A", "Bm", "A"],
)

TRAINING = dict(
    bpm=[138, 138, 138], scale="E F# G A B C D".split(), tonic=4, lead="guitar", harm_lead="pulse",
    rhythm="chug", bass="slap", bass_type="slap", drums="rock", signature=(), arp_from=3,
    intro_chord="Em", lead_gain=0.18, swing=0.0,
    A=M("E5:1 G5:1 A5:2 B5:2 A5:1 G5:1 | E5:2 D5:1 E5:1 G5:4 | A5:1 B5:1 D6:2 B5:2 A5:1 G5:1 | A5:6 r:2 |"
        "E5:1 G5:1 A5:2 B5:2 D6:1 E6:1 | D6:2 B5:1 A5:1 G5:4 | A5:2 B5:2 G5:2 E5:2 | E5:6 r:2"),
    B=M("C6:3 B5:1 A5:2 G5:2 | A5:4 E5:4 | D6:3 C6:1 B5:2 A5:2 | B5:6 r:2 |"
        "C6:2 D6:2 E6:2 G6:2 | F#6:4 D6:4 | E6:2 D6:2 B5:2 A5:2 | B5:8"),
    chA=["Em", "C", "D", "Em", "Em", "C", "D", "Em"],
    chB=["C", "Am", "D", "Em", "C", "D", "Am", "B"],
)


def layer_title(tr, song, E8, t0, secs, power=1.0):
    BAR = song.bar
    for k, (ch, first, last) in enumerate(sm.bars_of(secs)):
        tb = t0 + k * BAR * E8
        root, notes = sm.chord(song, sm.halves(ch)[0], 55)
        tr.add(tb, sm.choir(notes + [notes[0] + 12], BAR * E8 * 0.98), 0, 0.16)
        tl = root - 12 if root - 12 >= 36 else root
        tr.add(tb, sm.timpani(tl), 0, 0.4)
        if first:
            tr.add(tb, bm.CRASH, 0, 0.12)
        if last:
            for r in range(8):
                tr.add(tb + 4 * E8 + r * E8 / 2, sm.timpani(tl, 0.3), 0, 0.12 + 0.03 * r)


def layer_training(tr, song, E8, t0, secs, power=1.0):
    BAR = song.bar
    for k, (ch, first, last) in enumerate(sm.bars_of(secs)):
        tb = t0 + k * BAR * E8
        if first:
            tr.add(tb, bm.CRASH, 0.2, 0.1)
        if k % 2 == 1:   # "¡hey!" del público: palmas en 2 y 4
            for i in (2, 6):
                tr.add(tb + i * E8, bm.d_applause(0.12), 0, 0.5)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    order = lambda s: [(s["chA"], s["A"]), (s["chB"], s["B"])]
    L, R, _ = sm.render_phase(TITLE, 2, order(TITLE), 0, layer_title)
    sm.save_at(out, "title_theme", L, R, -16.0)
    L, R, _ = sm.render_phase(TRAINING, 2, order(TRAINING), 0, layer_training)
    sm.save_at(out, "training_theme", L, R, -16.5)
