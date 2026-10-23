"""Recorta las hojas de EFECTOS de la ronda épica de los bosses 1-8 (ver gen_prompts_bosses_epico.py).

Lee   referencias_animacion/_entregas_runway/bosses/boss_<boss>_fx_<nombre>8.png  (rejilla 4x2, 8 cuadros en orden)
Crea  assets/sprites/bosses/<boss>/boss_<boss>_<prefijo>_<0..7>.png con el CENTRO del efecto en el centro del lienzo
      (en el juego lo dibuja epic_fx.gd Anim). Faltan hojas = se siguen usando los efectos por código.
Uso: python tools/slice_boss_fx.py [boss ...]
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import slice_sudo_sheets as S  # noqa: E402
from gen_prompts_bosses_epico import BOSSES  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "referencias_animacion" / "_entregas_runway" / "bosses"


def slice_sheet(kind: str, fname: str, prefix: str, anchor: str, target: int, magenta: bool) -> bool:
    path = SRC / fname
    if not path.exists():
        print("falta", path.name)
        return False
    out = ROOT / "assets" / "sprites" / "bosses" / kind
    out.mkdir(parents=True, exist_ok=True)
    rgb = np.asarray(Image.open(path).convert("RGB"))
    fg = ~S.bg_mask(rgb)
    masks = S.cells(fg, 4, 2, 12)
    boxes = [S.main_box(m) if m.any() else None for m in masks]
    sizes = [max(b[2] - b[0], b[3] - b[1]) for b in boxes if b]
    if not sizes:
        print("vacía", path.name)
        return False
    k = target / max(sizes)
    for i, m in enumerate(masks):
        box = boxes[i]
        if box is None:
            print("  cuadro vacío", fname, i)
            continue
        img = S.shrink(rgb, m, box, k, magenta)
        h, w = img.shape[:2]
        x0, y0, x1, y1 = box
        if anchor == "ground":
            ax, ay = (S.feet_x(m, box) - x0) * k, h
        elif anchor == "cell":
            # grokbot dibuja cada cuadro centrado en su celda: el centro de la celda es el ancla fija
            hh, ww = rgb.shape[:2]
            cx = ww / 4 * (i % 4 + 0.5)
            cy = hh / 2 * (i // 4 + 0.5)
            ax, ay = (cx - x0) * k, (cy - y0) * k
        else:
            ax, ay = w / 2, h / 2
        hx = int(np.ceil(max(ax, w - ax))) + 1
        if anchor == "ground":
            canvas = np.zeros((h, hx * 2, 4), dtype=np.uint8)
            oy = 0
        else:
            hy = int(np.ceil(max(ay, h - ay))) + 1
            canvas = np.zeros((hy * 2, hx * 2, 4), dtype=np.uint8)
            oy = int(round(hy - ay))
        ox = int(round(hx - ax))
        canvas[oy:oy + h, ox:ox + w] = img
        Image.fromarray(canvas, "RGBA").save(out / f"boss_{kind}_{prefix}_{i}.png")
    print(f"{fname}: factor {k:.3f}")
    return True


def main() -> None:
    kinds = sys.argv[1:] or list(BOSSES)
    for kind in kinds:
        for fname, prefix, anchor, px, magenta, _es, _en in BOSSES[kind][1]:
            slice_sheet(kind, fname, prefix, "cell", px, magenta)


if __name__ == "__main__":
    main()
