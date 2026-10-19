#!/usr/bin/env python3
"""Convierte una hoja "bloque" (3 filas × 4 poses) en hojas 2x2 normales para slice_character_sheets.py.

Uso: python3 tools/split_block.py <bloque.png|jpg> <nombre_fila1> <nombre_fila2> <nombre_fila3>
     (usa "-" para descartar una fila). Las hojas salen en referencias_animacion/_entregas_runway/.
Ej.: python3 tools/split_block.py referencias_animacion/_entregas_runway/wadrid_guerrero_bloque_right.jpg \
        wadrid_guerrero_special_right wadrid_guerrero_parry_right -
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "referencias_animacion" / "_entregas_runway"
MINT = (160, 239, 165)


def fg_mask(rgb):
    r, g, b = (rgb[..., i].astype(np.int32) for i in range(3))
    dist = np.sqrt((r - 160) ** 2 + (g - 239) ** 2 + (b - 165) ** 2)
    mint = ((g > r + 15) & (g > b + 8) & (g > 140) & (r > 80) & (r < 205)) | (dist < 50)
    return ~mint


def keep_main(mask):
    """Deja solo los trozos grandes (la pose) y quita restos de poses vecinas en el borde."""
    h, w = mask.shape
    k = 4
    small = mask[::k, ::k]
    sh, sw = small.shape
    lab = np.zeros((sh, sw), np.int32)
    sizes = {}
    cur = 0
    for y0, x0 in zip(*np.nonzero(small)):
        if lab[y0, x0]:
            continue
        cur += 1
        stack = [(y0, x0)]
        lab[y0, x0] = cur
        n = 0
        while stack:
            y, x = stack.pop()
            n += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < sh and 0 <= nx < sw and small[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = cur
                        stack.append((ny, nx))
        sizes[cur] = n
    if not sizes:
        return mask
    big = max(sizes.values())
    keep_ids = [i for i, n in sizes.items() if n >= big * 0.08]
    keep_small = np.isin(lab, keep_ids)
    keep = np.repeat(np.repeat(keep_small, k, 0), k, 1)[:h, :w]
    # dilatar un poco para no cortar bordes finos
    from PIL import ImageFilter
    keep = np.asarray(Image.fromarray(keep.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(9))) > 0
    return mask & keep


def runs(profile, min_gap, min_len):
    act = profile > 0
    segs, start, gap = [], None, 0
    for i, v in enumerate(act):
        if v:
            if start is None:
                start = i
            gap, end = 0, i
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                if end + 1 - start >= min_len:
                    segs.append((start, end + 1))
                start, gap = None, 0
    if start is not None and end + 1 - start >= min_len:
        segs.append((start, end + 1))
    return segs


def main():
    src = Path(sys.argv[1])
    names = sys.argv[2:5]
    rgb = np.asarray(Image.open(src).convert("RGB"))
    m = fg_mask(rgb)
    h, w = m.shape
    rows = runs((m.sum(1) > 3).astype(int), h // 60, h // 12)
    print("filas:", rows)
    for (y0, y1), name in zip(rows, names):
        if name == "-":
            continue
        band = m[y0:y1]
        cols = runs((band.sum(0) > 2).astype(int), w // 120, w // 30)
        if len(cols) != 4:
            # partir en 4 columnas iguales si las poses se tocan
            q = w // 4
            cols = [(i * q, (i + 1) * q) for i in range(4)]
        crops = []
        for (x0, x1) in cols:
            sub = keep_main(band[:, x0:x1])
            ys = np.nonzero(sub.any(1))[0]
            xs = np.nonzero(sub.any(0))[0]
            c = rgb[y0 + ys.min(): y0 + ys.max() + 1, x0 + xs.min(): x0 + xs.max() + 1].copy()
            c[~sub[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1]] = MINT
            crops.append(c)
        ch = max(c.shape[0] for c in crops)
        cw = max(c.shape[1] for c in crops)
        pad = max(ch, cw) // 3
        W, H = 2 * (cw + 2 * pad), 2 * (ch + 2 * pad)
        sheet = Image.new("RGB", (W, H), MINT)
        for i, c in enumerate(crops):
            cx = (i % 2) * (cw + 2 * pad) + pad + (cw - c.shape[1]) // 2
            cy = (i // 2) * (ch + 2 * pad) + pad + (ch - c.shape[0])  # pies alineados abajo
            sheet.paste(Image.fromarray(c), (cx, cy))
        sheet.save(OUT / f"{name}.png")
        print("->", name, sheet.size, "columnas:", cols)


if __name__ == "__main__":
    main()
