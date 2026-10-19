#!/usr/bin/env python3
"""Recorta las hojas 2x2 de Runway (referencias_animacion/_entregas_runway) en frames
transparentes para Godot.

Salida: assets/sprites/characters_anim/<personaje>/<anim>_<dir>_<i>.png  (dir: down/up/right;
left = right espejado en runtime) + _preview.png por personaje.

- Fondo mint #A0EFA5 -> transparente (+ erosión de 2 px para quitar el borde verde).
- 4 poses por hoja en orden de lectura (arriba-izq, arriba-der, abajo-izq, abajo-der).
- Una escala por hoja: altura mediana de las 4 poses -> TARGET_H px. En las hojas de rodar
  (poses agachadas) se usa la altura de pie del personaje medida en sus otras hojas.
- Cada frame va en un lienzo CANVAS x CANVAS con los pies en FOOT_Y y el cuerpo centrado en x.

Uso (desde la raíz del proyecto):  python3 tools/slice_character_sheets.py
Requiere: pillow, numpy.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "referencias_animacion" / "_entregas_runway"
OUT = ROOT / "assets" / "sprites" / "characters_anim"
CHARACTERS = ["wadrid", "marlonx_a"]
ANIMS = ["idle", "walk", "roll", "guerrero_attack", "mago_cast", "chain_whip",
         "guerrero_finisher", "mago_finisher", "chain_finisher",
         "guerrero_special", "guerrero_parry", "guerrero_ultimate",
         "mago_special", "mago_parry", "mago_ultimate",
         "chain_special", "chain_parry", "chain_ultimate", "hurt",
         # pulido (GROKBOT_PULIDO.md): poses intermedias, torbellino en bucle y reposo animado
         "walk_b", "guerrero_attack_b", "mago_cast_b", "chain_whip_b", "chain_ultimate_spin", "idle_anim",
         # ciclos completos de 8 poses en UNA imagen (4 columnas x 2 filas): GROKBOT_PULIDO_2.md
         "walk8", "guerrero_attack8", "mago_cast8", "chain_whip8",
         # pulido 3 (GROKBOT_PULIDO_3.md): derribo, reposo largo, contraataque, especial/parry/ultimate de 8 poses
         "knockdown8", "idle_long"] + [f"{c}_{a}8" for c in ("guerrero", "mago", "chain")
                                       for a in ("counter", "special", "parry", "ultimate")]
# Hojas con 8 poses en cuadrícula 4x2 (orden de lectura: fila de arriba 1-4, fila de abajo 5-8)
GRID8 = ("walk8", "guerrero_attack8", "mago_cast8", "chain_whip8", "knockdown8", "idle_long") + tuple(
    f"{c}_{a}8" for c in ("guerrero", "mago", "chain") for a in ("counter", "special", "parry", "ultimate"))
# Hojas con poses agachadas/saltando: escalar con la altura de pie del personaje.
STAND_REF = ("roll", "hurt", "guerrero_finisher", "mago_finisher", "chain_finisher",
             "guerrero_special", "guerrero_parry", "guerrero_ultimate",
             "mago_special", "mago_parry", "mago_ultimate",
             "chain_special", "chain_parry", "chain_ultimate", "knockdown8") + tuple(
    f"{c}_{a}8" for c in ("guerrero", "mago", "chain") for a in ("counter", "special", "parry", "ultimate"))
DIRS = ["down", "up", "right", "down_right", "up_right"]
TARGET_H = 88
CANVAS = 160   # con margen para saltos y armas en alto (antes 128: se cortaban 11 frames)
FOOT_Y = 152
# Poses en el aire: subir el frame N px (índice de pose -> px), por animación.
POSE_LIFT = {
    "guerrero_finisher": {1: 12},
}
# Ajustes de orden de poses por hoja (índices 0-3).
POSE_ORDER = {
    "wadrid_mago_cast_down": [0, 1, 2, 0],  # pose 4 cambia de mano: recupera con pose 1
    "marlonx_a_mago_parry_down": [0, 1, 1, 3],  # la pose 3 salió como ataque: se repite la guardia
}


# Factores de escala por hoja (1.0 = sin cambio). Los genera tools/measure_head_scale.py.
_FIX_PATH = Path(__file__).resolve().parent / "scale_fix.json"
SCALE_FIX = json.loads(_FIX_PATH.read_text()) if _FIX_PATH.exists() else {}
# Estiramiento vertical por hoja (alto/ancho): iguala proporciones entre hojas hechas con distintas herramientas
# (p. ej. las caminatas de ChatGPT salen más "cabezonas" que las hojas de Runway). Se aplica sobre la imagen grande.
_ASPECT_PATH = Path(__file__).resolve().parent / "aspect_fix.json"
ASPECT_FIX = json.loads(_ASPECT_PATH.read_text()) if _ASPECT_PATH.exists() else {}


# Corrección de color por zonas (piel, polo, jeans): las hojas hechas con otra herramienta (ChatGPT) salen más
# brillantes/saturadas. Se igualan a los tonos de la hoja de referencia (mismo personaje y dirección, ya recortada).
COLOR_REF_EXEMPT = ("walk", "idle")  # paleta de referencia (hojas originales de Runway)
COLOR_MATCH = {"walk8": "walk", "guerrero_attack8": "guerrero_attack", "mago_cast8": "mago_cast", "chain_whip8": "chain_whip"}


def _hsv(rgb: np.ndarray):
    c = rgb.astype(np.float32) / 255.0
    mx, mn = c.max(-1), c.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    m = d > 1e-6
    rr = m & (mx == r)
    gg = m & (mx == g) & ~rr
    bb = m & ~rr & ~gg
    h[rr] = ((g - b)[rr] / d[rr]) % 6
    h[gg] = (b - r)[gg] / d[gg] + 2
    h[bb] = (r - g)[bb] / d[bb] + 4
    return h * 60.0, np.where(mx > 0, d / np.maximum(mx, 1e-6), 0), mx


def _zones(rgba: np.ndarray, ch: str) -> dict:
    op = rgba[..., 3] > 0
    h, s, v = _hsv(rgba[..., :3])
    z = {"piel": op & (h > 12) & (h < 40) & (s > 0.35) & (v > 0.55),
         "jeans": op & (h > 195) & (h < 240) & (s > 0.25) & (v > 0.25)}
    if ch == "wadrid":
        z["polo"] = op & (h > 90) & (h < 170) & (s > 0.12) & (v > 0.15) & (v < 0.65)
    else:
        z["polo"] = op & (s < 0.2) & (v > 0.18) & (v < 0.45)
    return z


def color_match(frames: list, refs: list, ch: str) -> list:
    """Ganancia RGB por zona = mediana(referencia) / mediana(hoja). Mantiene el sombreado del pixel art."""
    if not frames or not refs:
        return frames
    arr = [np.asarray(f).copy() for f in frames]
    ref = [np.asarray(r) for r in refs]
    for zone in ("piel", "polo", "jeans"):
        sp = np.concatenate([a[_zones(a, ch)[zone]][:, :3] for a in arr] or [np.zeros((0, 3))])
        rp = np.concatenate([r[_zones(r, ch)[zone]][:, :3] for r in ref] or [np.zeros((0, 3))])
        if len(sp) < 30 or len(rp) < 30:
            continue
        gain = np.clip(np.median(rp, 0) / np.maximum(np.median(sp, 0), 1.0), 0.75, 1.3)
        for a in arr:
            m = _zones(a, ch)[zone]
            a[..., :3][m] = np.clip(a[..., :3][m].astype(np.float32) * gain, 0, 255).astype(np.uint8)
    return [Image.fromarray(a, "RGBA") for a in arr]


def fg_mask(rgb: np.ndarray) -> np.ndarray:
    r, g, b = (rgb[..., i].astype(np.int32) for i in range(3))
    dist = np.sqrt((r - 160) ** 2 + (g - 239) ** 2 + (b - 165) ** 2)
    mint = ((g > r + 15) & (g > b + 8) & (g > 140) & (r > 80) & (r < 205)) | (dist < 50)
    return ~mint


def erode(mask: np.ndarray, it: int) -> np.ndarray:
    m = mask.copy()
    for _ in range(it):
        s = m.copy()
        s[1:, :] &= m[:-1, :]
        s[:-1, :] &= m[1:, :]
        s[:, 1:] &= m[:, :-1]
        s[:, :-1] &= m[:, 1:]
        m = s
    return m


def remove_specks(mask: np.ndarray, min_px: int = 40) -> np.ndarray:
    """Quita manchas sueltas pequeñas (etiquetado simple por BFS en baja resolución)."""
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    out = mask.copy()
    cur = 0
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if lab[y0, x0]:
            continue
        cur += 1
        stack = [(y0, x0)]
        lab[y0, x0] = cur
        pix = []
        while stack:
            y, x = stack.pop()
            pix.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = cur
                    stack.append((ny, nx))
        if len(pix) < min_px:
            for y, x in pix:
                out[y, x] = False
    return out


def split_at(profile: np.ndarray, lo: float, hi: float) -> int:
    n = len(profile)
    a, b = int(n * lo), int(n * hi)
    seg = profile[a:b].astype(np.float64)
    zeros = np.nonzero(seg == 0)[0]
    if len(zeros):
        # centro del hueco vacío más ancho
        runs, start = [], zeros[0]
        for i in range(1, len(zeros) + 1):
            if i == len(zeros) or zeros[i] != zeros[i - 1] + 1:
                runs.append((start, zeros[i - 1]))
                if i < len(zeros):
                    start = zeros[i]
        s, e = max(runs, key=lambda r: r[1] - r[0])
        return a + (s + e) // 2
    return a + int(np.argmin(seg))


def grid8(mask: np.ndarray) -> list:
    """Cajas de 8 poses en cuadrícula 4 columnas x 2 filas (orden de lectura)."""
    h, w = mask.shape
    ys = split_at(mask.sum(1), 0.3, 0.7)
    boxes = []
    for (y0, y1) in ((0, ys), (ys, h)):
        band = mask[y0:y1]
        prof = band.sum(0)
        cuts = [0] + [split_at(prof, lo, hi) for lo, hi in ((0.15, 0.35), (0.40, 0.60), (0.65, 0.85))] + [w]
        for x0, x1 in zip(cuts[:-1], cuts[1:]):
            q = band[:, x0:x1]
            if not q.any():
                boxes.append(None)
                continue
            q = _drop_neighbor_spill(q)
            # se limpia también la máscara original (el render usa la máscara de la hoja)
            sub = mask[y0:y1, x0:x1]
            sub &= q
            yy, xx = np.nonzero(q)
            boxes.append((x0 + xx.min(), y0 + yy.min(), x0 + xx.max() + 1, y0 + yy.max() + 1))
    return boxes


def _drop_neighbor_spill(q: np.ndarray) -> np.ndarray:
    """Quita trozos sueltos que tocan el borde izquierdo/derecho de la celda (p. ej. la punta de un arma de
    la pose vecina que cruzó la división). Se conserva el componente más grande (el personaje)."""
    f = 3  # etiquetado en baja resolución (rápido, sin scipy)
    h, w = q.shape
    small = q[: h - h % f, : w - w % f].reshape(h // f, f, w // f, f).any(axis=(1, 3))
    sh, sw = small.shape
    lab = np.zeros((sh, sw), np.int32)
    sizes, touches = [], []
    for y0, x0 in zip(*np.nonzero(small)):
        if lab[y0, x0]:
            continue
        k = len(sizes) + 1
        lab[y0, x0] = k
        stack, n, t = [(y0, x0)], 0, False
        while stack:
            y, x = stack.pop()
            n += 1
            if x <= 0 or x >= sw - 1:
                t = True
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < sh and 0 <= nx < sw and small[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = k
                        stack.append((ny, nx))
        sizes.append(n)
        touches.append(t)
    if len(sizes) <= 1:
        return q
    main = int(np.argmax(sizes))
    drop = np.zeros_like(small)
    for i, (n, t) in enumerate(zip(sizes, touches)):
        if i != main and t and n < 0.25 * sizes[main]:
            drop |= lab == i + 1
    if not drop.any():
        return q
    big = np.repeat(np.repeat(drop, f, axis=0), f, axis=1)
    out = q.copy()
    out[: big.shape[0], : big.shape[1]] &= ~big
    return out


def quadrants(mask: np.ndarray) -> list[tuple[int, int, int, int]]:
    h, w = mask.shape
    ys = split_at(mask.sum(1), 0.3, 0.7)
    boxes = []
    for (y0, y1) in ((0, ys), (ys, h)):
        band = mask[y0:y1]
        xs = split_at(band.sum(0), 0.3, 0.7)
        for (x0, x1) in ((0, xs), (xs, w)):
            q = band[:, x0:x1]
            if not q.any():
                boxes.append(None)
                continue
            yy, xx = np.nonzero(q)
            boxes.append((x0 + xx.min(), y0 + yy.min(), x0 + xx.max() + 1, y0 + yy.max() + 1))
    return boxes


def load_sheet(path: Path):
    im = Image.open(path).convert("RGB")
    # normalizar a ~1200 px de alto (las hojas de Gemini vienen a 2400): mucho más rápido
    if im.height > 1400:
        im = im.resize((round(im.width * 1200 / im.height), 1200), Image.Resampling.LANCZOS)
    rgb = np.asarray(im)
    # trabajar a ~1200 px de alto para que umbrales/erosión sean comparables
    k = rgb.shape[0] / 1200.0
    mask = fg_mask(rgb)
    mask = erode(mask, max(1, int(round(2 * k))))
    small = np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).resize(
        (max(1, mask.shape[1] // 4), max(1, mask.shape[0] // 4)), Image.Resampling.NEAREST)) > 0
    small = remove_specks(small, 6)
    keep = np.asarray(Image.fromarray(small.astype(np.uint8) * 255).resize(
        (mask.shape[1], mask.shape[0]), Image.Resampling.NEAREST)) > 0
    mask &= keep
    return rgb, mask


def _resize_pre(crop_rgb, crop_a, nw, nh):
    pre_im = Image.fromarray(np.dstack([crop_rgb * crop_a[..., None], crop_a[..., None] * 255.0]).clip(0, 255).astype(np.uint8), "RGBA")
    return np.asarray(pre_im.resize((max(1, nw), max(1, nh)), Image.Resampling.BOX)).astype(np.float32)


# Parte superior (cabeza) que NO se estira con ASPECT_FIX: fracción del alto hasta los pies.
HEAD_FRAC = 0.42


def render_pose(rgb, mask, box, scale, aspect: float = 1.0) -> Image.Image:
    x0, y0, x1, y1 = box
    crop_rgb = rgb[y0:y1, x0:x1].astype(np.float32)
    crop_a = mask[y0:y1, x0:x1].astype(np.float32)
    nw = max(1, int(round((x1 - x0) * scale)))
    # pies = última fila "gruesa" (ignora la punta de un cable o arma que cuelga bajo los pies)
    rows = crop_a.sum(1)
    thick = np.nonzero(rows >= max(8.0, 0.15 * rows.max()))[0]
    foot = (thick[-1] + 1) if len(thick) else (y1 - y0)
    if abs(aspect - 1.0) < 1e-3:
        nh = max(1, int(round((y1 - y0) * scale)))
        small = _resize_pre(crop_rgb, crop_a, nw, nh)
        foot_px = int(round(foot * scale))
    else:
        # estiramiento SOLO del cuerpo (debajo de la cabeza): la cabeza conserva su forma y tamaño
        # parte de arriba de la cabeza = primera fila "ancha" (ignora armas finas por encima de la cabeza)
        wide = np.nonzero(rows >= 0.25 * rows.max())[0]
        htop = int(wide[0]) if len(wide) else 0
        split = max(1, int(round(htop + (foot - htop) * HEAD_FRAC)))
        k = max(0.3, ((foot - htop) * aspect - (split - htop)) / max(1, foot - split))
        h_head = max(1, int(round(split * scale)))
        h_body = max(1, int(round((foot - split) * scale * k)))
        h_tail = int(round((y1 - y0 - foot) * scale))
        parts = [_resize_pre(crop_rgb[:split], crop_a[:split], nw, h_head),
                 _resize_pre(crop_rgb[split:foot], crop_a[split:foot], nw, h_body)]
        if h_tail > 0 and (y1 - y0 - foot) > 0:
            parts.append(_resize_pre(crop_rgb[foot:], crop_a[foot:], nw, h_tail))
        small = np.concatenate(parts, axis=0)
        nh = small.shape[0]
        foot_px = h_head + h_body
    a = small[..., 3] / 255.0
    rgb_s = np.where(a[..., None] > 0.01, small[..., :3] / np.maximum(a[..., None], 1e-3), 0)
    alpha = (a >= 0.5).astype(np.uint8) * 255
    frame = np.dstack([rgb_s.clip(0, 255).astype(np.uint8), alpha])
    frame[alpha == 0] = 0
    # ancla: pies abajo, x = mediana de la masa del cuerpo
    xs = np.nonzero(crop_a)[1]
    cx = (np.median(xs) if len(xs) else (x1 - x0) / 2) * scale
    canvas = np.zeros((CANVAS, CANVAS, 4), np.uint8)
    ox = int(round(CANVAS / 2 - cx))
    # pies = última fila "gruesa" (ignora la punta de un cable o arma que cuelga bajo los pies)
    oy = FOOT_Y - foot_px
    sx0, sy0 = max(0, -ox), max(0, -oy)
    dx0, dy0 = max(0, ox), max(0, oy)
    ww = min(nw - sx0, CANVAS - dx0)
    hh = min(nh - sy0, CANVAS - dy0)
    if ww > 0 and hh > 0:
        canvas[dy0:dy0 + hh, dx0:dx0 + ww] = frame[sy0:sy0 + hh, sx0:sx0 + ww]
    return Image.fromarray(canvas, "RGBA")


def main() -> None:
    import sys
    # uso opcional: slice_character_sheets.py [personaje] [filtro_de_animación]
    chars = [sys.argv[1]] if len(sys.argv) > 1 else CHARACTERS
    only = sys.argv[2] if len(sys.argv) > 2 else ""
    report_path = OUT / "_slice_report.json"
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    for ch in chars:
        out_dir = OUT / ch
        out_dir.mkdir(parents=True, exist_ok=True)
        sheets = {}
        stand_ratio = []
        for anim in ANIMS:
            if only and only not in anim and anim != "walk":
                continue  # "walk" se carga siempre: da la altura de pie para rodar/daño
            for d in DIRS:
                p = SRC / f"{ch}_{anim}_{d}.png"
                if not p.exists():
                    # también se aceptan .jpg / .jpeg / .webp (p. ej. descargas de Gemini)
                    alts = [SRC / f"{ch}_{anim}_{d}{ext}" for ext in (".jpg", ".jpeg", ".webp")]
                    p = next((a for a in alts if a.exists()), p)
                if not p.exists():
                    continue
                rgb, mask = load_sheet(p)
                boxes = grid8(mask) if anim in GRID8 else quadrants(mask)
                heights = [b[3] - b[1] for b in boxes if b]
                sheets[(anim, d)] = (rgb, mask, boxes, heights)
                if anim not in STAND_REF and heights:
                    stand_ratio.append(float(np.median(heights)) / rgb.shape[0])
        stand = float(np.median(stand_ratio)) if stand_ratio else 0.43
        frames_preview = []
        for (anim, d), (rgb, mask, boxes, heights) in sheets.items():
            if only and only not in anim:
                continue
            # remates/especiales/parry/ultimate: la pose 4 es de pie (recuperación) -> referencia de altura
            if anim.split("_", 1)[-1] in ("finisher", "special", "parry", "ultimate") and boxes[3] is not None:
                # la pose 4 del remate es de pie (recuperación): referencia de altura
                ref = float(boxes[3][3] - boxes[3][1])
            elif anim in GRID8 and anim not in ("walk8", "guerrero_attack8", "mago_cast8", "chain_whip8", "idle_long") \
                    and len(boxes) >= 8 and boxes[7] is not None:
                # pulido 3: la pose 8 es SIEMPRE de pie (vuelta a la guardia) -> referencia de altura
                ref = float(boxes[7][3] - boxes[7][1])
            elif anim in STAND_REF:
                ref = stand * rgb.shape[0]
            else:
                ref = float(np.median(heights))
            scale = TARGET_H / max(ref, 1.0)
            # corrección medida comparando el tamaño de la CABEZA con la caminata (tools/scale_fix.json):
            # un número (toda la hoja) o una lista de 4 (una por pose)
            fix = SCALE_FIX.get(f"{ch}_{anim}_{d}", 1.0)
            order = POSE_ORDER.get(f"{ch}_{anim}_{d}", list(range(len(boxes))))
            # (se sobrescriben los frames existentes; siempre son 4 por hoja)
            row = []
            for i, idx in enumerate(order):
                box = boxes[idx] if idx < len(boxes) else None
                if box is None:
                    continue
                f_pose = float(fix[idx if idx < len(fix) else -1]) if isinstance(fix, list) else float(fix)
                im = render_pose(rgb, mask, box, scale * f_pose, float(ASPECT_FIX.get(f"{ch}_{anim}_{d}", 1.0)))
                lift = POSE_LIFT.get(anim, {}).get(idx, 0)
                if lift:
                    lifted = Image.new("RGBA", im.size, (0, 0, 0, 0))
                    lifted.paste(im, (0, -lift))
                    im = lifted
                row.append(im)
            # todas las animaciones se igualan a la paleta de la caminata original (o a su hoja base si es una de 8 poses)
            if anim not in COLOR_REF_EXEMPT:
                ref_anim = COLOR_MATCH.get(anim, "walk")
                refs = [Image.open(q).convert("RGBA") for q in sorted(out_dir.glob(f"{ref_anim}_{d}_[0-9].png"))]
                if not refs and d not in ("down", "up", "right"):
                    # diagonal sin caminata de referencia: la de la dirección vertical más cercana
                    refs = [Image.open(q).convert("RGBA") for q in sorted(out_dir.glob(f"{ref_anim}_{d.split('_')[0]}_[0-9].png"))]
                row = color_match(row, refs, ch)
            for i, im in enumerate(row):
                im.save(out_dir / f"{anim}_{d}_{i}.png")
            frames_preview.append((f"{anim}_{d}", row))
            report[f"{ch}_{anim}_{d}"] = {"scale": round(scale, 4), "fix": fix, "frames": len(row),
                                          "pose_heights": [int(h) for h in heights]}
        # hoja de revisión
        rows = len(frames_preview)
        cols = max([len(r) for _, r in frames_preview] + [4])
        prev = Image.new("RGBA", (CANVAS * cols, CANVAS * max(rows, 1)), (60, 60, 70, 255))
        for r, (_, row) in enumerate(frames_preview):
            for c, im in enumerate(row):
                prev.alpha_composite(im, (c * CANVAS, r * CANVAS))
        prev.save(out_dir / (f"_preview_{only}.png" if only else "_preview.png"))
    (OUT / "_slice_report.json").write_text(json.dumps(report, indent=1))
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
