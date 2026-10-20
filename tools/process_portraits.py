#!/usr/bin/env python3
"""Recorta los retratos de Grok (referencias_animacion/_entregas_runway/portrait_<personaje>_<clase>.png)
para el menú del personaje: quita el fondo menta, recorta al personaje y lo reduce a pixel art real
(TARGET_H px de alto, vecino más cercano). Salida: assets/sprites/portraits/<personaje>_<clase>.png
El menú (scripts/ui/character_menu.gd) lo usa solo en cuanto existe el archivo.
Uso: python3 tools/process_portraits.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "referencias_animacion" / "_entregas_runway"
OUT = ROOT / "assets" / "sprites" / "portraits"
TARGET_H = 230
MINT = np.array([160, 239, 165], dtype=np.float32)


def remove_mint(img: Image.Image) -> Image.Image:
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    # el fondo es el color de las esquinas (menta); se quita todo lo parecido que toque el borde
    corners = np.array([rgb[2, 2], rgb[2, -3], rgb[-3, 2], rgb[-3, -3]])
    bg = np.median(corners, axis=0) if np.abs(corners - MINT).sum(1).min() < 120 else MINT
    dist = np.abs(rgb - bg).sum(-1)
    near = dist < 70
    h, w = near.shape
    seen = np.zeros_like(near)
    stack = [(y, x) for y in (0, h - 1) for x in range(w)] + [(y, x) for x in (0, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if y < 0 or x < 0 or y >= h or x >= w or seen[y, x] or not near[y, x]:
            continue
        seen[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    a = np.where(seen, 0, 255).astype(np.uint8)
    out = np.dstack([rgb.astype(np.uint8), a])
    return Image.fromarray(out, "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    n = 0
    for p in sorted(SRC.glob("portrait_*.*")):
        if p.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        stem = p.stem.removeprefix("portrait_")
        im = remove_mint(Image.open(p))
        box = im.getbbox()
        if box is None:
            continue
        im = im.crop(box)
        k = TARGET_H / im.height
        im = im.resize((max(1, round(im.width * k)), TARGET_H), Image.LANCZOS)
        # alfa duro (pixel art: sin bordes semitransparentes)
        arr = np.asarray(im).copy()
        arr[..., 3] = np.where(arr[..., 3] > 128, 255, 0)
        Image.fromarray(arr, "RGBA").save(OUT / f"{stem}.png")
        print("retrato", stem, im.size)
        n += 1
    print(n, "retratos")


if __name__ == "__main__":
    main()
