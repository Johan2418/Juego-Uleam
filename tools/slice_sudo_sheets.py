"""Recorta las hojas del boss 9 SUDO (grokbot) con fondo transparente, ya al tamaño del juego.

SUDO es una persona: se anima por POSES (hojas de 8 poses en 4x2), no por piezas como los bosses 1-8.
Uso:  python tools/slice_sudo_sheets.py
Lee   referencias_animacion/_entregas_runway/bosses/boss_sudo_*.png
Crea  assets/sprites/bosses/sudo/
      boss_sudo_<anim>_<i>.png   poses: el lienzo se rellena para que los PIES queden abajo al centro
                                 (en el juego: Sprite/draw con offset (-ancho/2, -alto)).
      boss_sudo_<hoja>_<i>.png   objetos sueltos (pantalla, esbirros, astros, objetos, proyectiles).
Cada hoja se parte en su rejilla (columnas x filas); cada mancha va a la celda donde cae su centro.
Solo usa numpy + PIL (sin scipy).
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "referencias_animacion" / "_entregas_runway" / "bosses"
OUT = ROOT / "assets" / "sprites" / "bosses" / "sudo"

## Alto en el juego de SUDO de pie (pies a coronilla). El boss por código medía ~205.
STAND_H = 214
BG_TOL = 62.0

## Hojas de poses: hoja -> (nombres de las 8 poses en orden, índice de la pose "de pie" que fija la escala)
POSE_SHEETS = {
    "boss_sudo_idle_walk8": (["idle_0", "idle_1", "idle_2", "idle_3", "walk_0", "walk_1", "walk_2", "walk_3"], 0),
    "boss_sudo_cast8": (["raise_0", "raise_1", "point_0", "point_1", "spread_0", "spread_1", "summon_0", "summon_1"], 3),
    "boss_sudo_moves8": (["crouch_0", "dash_0", "stomp_0", "wave_0", "present_0", "think_0", "laugh_0", "stand_0"], 7),
    "boss_sudo_hurt8": (["flinch_0", "flinch_1", "dizzy_0", "dizzy_1", "kneel_0", "kneel_1", "fade_0", "fade_1"], 6),
    # ronda épica: grokbot la dibujó ~15 % más grande; se escala por el ANCHO DE LA CABEZA (ver HEAD_REF)
    "boss_sudo_power8": (["charge_0", "shout_0", "leap_0", "slam_0", "invoke_0", "throw_0", "push_0", "victory_0"], 0),
}
## Hojas que se escalan por el ancho de la cabeza (poses agachadas o con brazos arriba: el alto no sirve).
## hoja -> poses cuya cabeza se mide (la cabeza es lo de más arriba en ellas).
HEAD_REF = {"boss_sudo_power8": [0, 1]}
## Ancho de la cabeza en el juego (el de boss_sudo_idle_0: 104 px de hoja x 0.460).
HEAD_W = 48.0

## Hojas de objetos: hoja -> (columnas, filas, [tamaño final (lado mayor, px) de cada objeto en orden])
ITEM_SHEETS = {
    "boss_sudo_screen": (3, 1, [176, 176, 176]),
    "boss_sudo_minions": (4, 2, [62, 62, 62, 62, 66, 56, 40, 40]),
    "boss_sudo_planets": (3, 2, [40, 30, 56, 40, 30, 56]),
    "boss_sudo_props": (4, 2, [36, 34, 36, 30, 64, 24, 100, 28]),
    "boss_sudo_projectiles": (4, 2, [34, 110, 18, 26, 34, 30, 128, 64]),
}
## Objetos que se escalan por su ANCHO aunque sean más altos (la pantalla, la tarjeta 2FA).
BY_WIDTH = {("boss_sudo_screen", i) for i in range(3)} | {("boss_sudo_props", 6)}


def bg_mask(rgb: np.ndarray) -> np.ndarray:
    corners = np.concatenate([rgb[:10, :10].reshape(-1, 3), rgb[:10, -10:].reshape(-1, 3),
                              rgb[-10:, :10].reshape(-1, 3), rgb[-10:, -10:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((rgb.astype(np.float32) - bg) ** 2).sum(axis=2))
    return dist < BG_TOL


def components(fg: np.ndarray, min_area: int) -> list[tuple[tuple[int, int, int, int], np.ndarray, tuple[float, float]]]:
    """Manchas conectadas (8 vecinos) sobre la máscara reducida a 1/4: caja, máscara y centro de cada una."""
    h, w = fg.shape
    sm = fg[: h // 4 * 4, : w // 4 * 4].reshape(h // 4, 4, w // 4, 4).any(axis=(1, 3))
    lab = np.zeros(sm.shape, dtype=np.int32)
    n = 0
    for y0, x0 in zip(*np.nonzero(sm)):
        if lab[y0, x0]:
            continue
        n += 1
        stack = [(y0, x0)]
        lab[y0, x0] = n
        while stack:
            y, x = stack.pop()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < sm.shape[0] and 0 <= xx < sm.shape[1] and sm[yy, xx] and not lab[yy, xx]:
                        lab[yy, xx] = n
                        stack.append((yy, xx))
    big = np.repeat(np.repeat(lab, 4, axis=0), 4, axis=1)
    full = np.zeros(fg.shape, dtype=np.int32)
    full[: big.shape[0], : big.shape[1]] = big
    out = []
    for i in range(1, n + 1):
        m = (full == i) & fg
        area = int(m.sum())
        if area < min_area:
            continue
        ys, xs = np.nonzero(m)
        out.append(((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1), m, (xs.mean(), ys.mean())))
    return out


def cells(fg: np.ndarray, cols: int, rows: int, min_area: int) -> list[np.ndarray]:
    """Una máscara por celda de la rejilla (las manchas van a la celda de su centro)."""
    h, w = fg.shape
    out = [np.zeros(fg.shape, dtype=bool) for _ in range(cols * rows)]
    for _box, m, (cx, cy) in components(fg, min_area):
        c = min(cols - 1, int(cx / (w / cols)))
        r = min(rows - 1, int(cy / (h / rows)))
        out[r * cols + c] |= m
    return out


def main_box(m: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.nonzero(m)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def despill(rgb: np.ndarray, m: np.ndarray, band: int = 4, magenta: bool = False) -> np.ndarray:
    """Quita el verde menta que queda en el BORDE de cada figura (píxeles mezclados con el fondo).
    Solo toca una franja de `band` px junto al fondo: los verdes de verdad (cubo, rayos, antena) no cambian."""
    near = np.zeros(m.shape, dtype=bool)
    bg = ~m
    for dy in range(-band, band + 1):
        for dx in range(-band, band + 1):
            near |= np.roll(np.roll(bg, dy, axis=0), dx, axis=1)
    edge = m & near
    out = rgb.astype(np.int32).copy()
    r, g, b = out[..., 0], out[..., 1], out[..., 2]
    if magenta:
        # fondo magenta: el borde se tiñe de rosa (rojo y azul altos); se baja a la altura del verde
        spill = edge & (np.minimum(r, b) > g + 8)
        r[spill] = g[spill]
        b[spill] = g[spill]
    else:
        spill = edge & (g > np.maximum(r, b) + 8)
        g[spill] = np.maximum(r, b)[spill]
    return out.clip(0, 255).astype(np.uint8)


def shrink(rgb: np.ndarray, m: np.ndarray, box: tuple[int, int, int, int], k: float, magenta: bool = False) -> np.ndarray:
    """Recorta, quita el fondo y reduce (BOX premultiplicado, alfa duro como los otros bosses)."""
    x0, y0, x1, y1 = box
    rgb = despill(rgb[y0:y1, x0:x1], m[y0:y1, x0:x1], magenta=magenta)
    m = m[y0:y1, x0:x1]
    x1, y1, x0, y0 = x1 - x0, y1 - y0, 0, 0
    rgba = np.dstack([rgb[y0:y1, x0:x1], np.where(m[y0:y1, x0:x1], 255, 0).astype(np.uint8)]).astype(np.float32)
    rgba[..., :3] *= rgba[..., 3:4] / 255.0
    small = Image.fromarray(rgba.astype(np.uint8), "RGBA").resize(
        (max(1, round((x1 - x0) * k)), max(1, round((y1 - y0) * k))), Image.BOX)
    s = np.asarray(small).astype(np.float32)
    a = s[..., 3:4]
    s[..., :3] = np.where(a > 0, s[..., :3] * 255.0 / np.maximum(a, 1), 0)
    s[..., 3] = np.where(s[..., 3] >= 110, 255, 0)
    # lo transparente en negro: si el juego filtra la imagen, el borde no se tiñe del color del fondo
    s[s[..., 3] == 0, :3] = 0
    return s.clip(0, 255).astype(np.uint8)


def feet_x(m: np.ndarray, box: tuple[int, int, int, int]) -> float:
    """Centro de los pies: promedio de las columnas opacas en el 12 % de abajo de la pose."""
    x0, y0, x1, y1 = box
    band = m[y1 - max(4, int((y1 - y0) * 0.12)): y1, x0:x1]
    xs = np.nonzero(band)[1]
    return x0 + (xs.mean() if xs.size else (x1 - x0) / 2)


def head_width(m: np.ndarray) -> float:
    """Ancho de la cabeza: mediana del ancho opaco entre 50 y 80 px por debajo de la coronilla (px de la hoja)."""
    ys = np.nonzero(m.any(axis=1))[0]
    top = ys.min()
    ws = []
    for y in range(top + 50, top + 80):
        row = np.nonzero(m[y])[0]
        if row.size:
            ws.append(row.max() - row.min())
    return float(np.median(ws))


def slice_poses() -> None:
    for name, (names, ref) in POSE_SHEETS.items():
        path = SRC / f"{name}.png"
        if not path.exists():
            print("falta", path)
            continue
        rgb = np.asarray(Image.open(path).convert("RGB"))
        fg = ~bg_mask(rgb)
        masks = cells(fg, 4, 2, 600)
        if name in HEAD_REF:
            k = HEAD_W / float(np.mean([head_width(masks[i]) for i in HEAD_REF[name]]))
        else:
            # escala de la hoja: alto de la mancha principal de la pose de referencia
            comps = components(masks[ref], 600)
            mb = max(comps, key=lambda c: int(c[1].sum()))[0]
            k = STAND_H / (mb[3] - mb[1])
        for i, pose in enumerate(names):
            m = masks[i]
            if not m.any():
                print("  vacía", name, i)
                continue
            box = main_box(m)
            fx = feet_x(m, box)
            img = shrink(rgb, m, box, k)
            h, w = img.shape[:2]
            ax = (fx - box[0]) * k
            half = int(np.ceil(max(ax, w - ax))) + 1
            canvas = np.zeros((h, half * 2, 4), dtype=np.uint8)
            ox = int(round(half - ax))
            canvas[:, ox:ox + w] = img
            Image.fromarray(canvas, "RGBA").save(OUT / f"boss_sudo_{pose}.png")
        print(f"{name}: factor {k:.3f}")


def slice_items() -> None:
    for name, (cols, rows, sizes) in ITEM_SHEETS.items():
        path = SRC / f"{name}.png"
        if not path.exists():
            print("falta", path)
            continue
        rgb = np.asarray(Image.open(path).convert("RGB"))
        fg = ~bg_mask(rgb)
        masks = cells(fg, cols, rows, 60)
        short = name.replace("boss_sudo_", "")
        for i, m in enumerate(masks):
            if not m.any():
                print("  vacía", name, i)
                continue
            box = main_box(m)
            bw, bh = box[2] - box[0], box[3] - box[1]
            side = bw if (name, i) in BY_WIDTH else max(bw, bh)
            img = shrink(rgb, m, box, sizes[i] / side)
            Image.fromarray(img, "RGBA").save(OUT / f"boss_sudo_{short}_{i}.png")
        print(f"{name}: {sum(1 for m in masks if m.any())} objetos")


## Efectos animados (ronda épica): hoja -> (nombre corto, ancla, lado mayor en px del cuadro MÁS GRANDE, fondo magenta)
## Ancla: "ground" = abajo al centro (el rayo cae al piso), "center" = centro de la caja del cuadro,
## "core" = centro del núcleo blanco (el sol: así no "salta" cuando sale la llamarada hacia un lado).
## Cada cuadro sale con su ancla en el CENTRO del lienzo ("ground": abajo al centro), así en el juego se dibuja con offset fijo.
FX_SHEETS = {
    "boss_sudo_fx_bolt8": ("fxbolt", "ground", 230, True),
    "boss_sudo_fx_fire8": ("fxfire", "center", 200, False),
    "boss_sudo_fx_cosmic8": ("fxcosmic", "center", 240, False),
    "boss_sudo_fx_sun8": ("fxsun", "core", 150, False),
    "boss_sudo_fx_data8": ("fxdata", "center", 180, False),
}


def slice_fx() -> None:
    for name, (short, anchor, target, magenta) in FX_SHEETS.items():
        path = SRC / f"{name}.png"
        if not path.exists():
            print("falta", path)
            continue
        rgb = np.asarray(Image.open(path).convert("RGB"))
        fg = ~bg_mask(rgb)
        masks = cells(fg, 4, 2, 12)
        boxes = [main_box(m) if m.any() else None for m in masks]
        biggest = max(max(b[2] - b[0], b[3] - b[1]) for b in boxes if b)
        k = target / biggest
        for i, m in enumerate(masks):
            box = boxes[i]
            if box is None:
                print("  vacío", name, i)
                continue
            img = shrink(rgb, m, box, k, magenta)
            h, w = img.shape[:2]
            x0, y0, x1, y1 = box
            if anchor == "ground":
                ax, ay = (feet_x(m, box) - x0) * k, h
            elif anchor == "core":
                sub = rgb[y0:y1, x0:x1].astype(int)
                hot = (sub.min(axis=2) > 225) & m[y0:y1, x0:x1]
                ys, xs = np.nonzero(hot)
                if xs.size:
                    ax, ay = xs.mean() * k, ys.mean() * k
                else:
                    ax, ay = w / 2, h / 2
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
            Image.fromarray(canvas, "RGBA").save(OUT / f"boss_sudo_{short}_{i}.png")
        print(f"{name}: factor {k:.3f}")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    slice_poses()
    slice_items()
    slice_fx()
