"""Recorta las hojas de los bosses (grokbot) en piezas sueltas con fondo transparente.

Uso:  python tools/slice_boss_sheets.py            (todos los bosses)
      python tools/slice_boss_sheets.py bsod       (solo uno)
Lee   referencias_animacion/_entregas_runway/bosses/<hoja>.png
Crea  assets/sprites/bosses/<boss>/<hoja>_<i>.png  (ya al tamaño del juego)

Cada hoja se parte por las bandas vacías (filas y luego columnas de fondo menta),
se quita el fondo y se reduce para que la pieza mida TARGET px (ancho o alto).
Solo usa numpy + PIL (sin scipy).
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "referencias_animacion" / "_entregas_runway" / "bosses"
OUT_DIR = ROOT / "assets" / "sprites" / "bosses"

# hoja -> (medida, tamaño en px del juego). "w" = ancho, "h" = alto, de la pieza MÁS GRANDE de la hoja;
# todas las piezas de una hoja usan el mismo factor (así conservan su tamaño relativo).
SHEETS = {
    "boss_0xdeadbeef_full": ("h", 250),
    "boss_0xdeadbeef_body": ("w", 214),
    "boss_0xdeadbeef_tank": ("h", 112),
    "boss_0xdeadbeef_head": ("w", 150),
    "boss_0xdeadbeef_claw": ("h", 166),
    "boss_0xdeadbeef_grabber": ("h", 166),
    "boss_animals": ("w", 64),
    "boss_minion_plant": ("h", 62),
    "boss_props": ("w", 40),
    "boss_debris": ("w", 26),
}

# Boss 2 B.S.O.D. (medidas sacadas de boss_bsod_full: el boss entero mide ~260 px de alto)
SHEETS_BSOD = {
    "boss_bsod_full": ("h", 260),
    "boss_bsod_body": ("h", 256),
    "boss_bsod_heart": ("h", 64),
    "boss_bsod_head": ("w", 64),
    "boss_bsod_scalpel": ("h", 170),
    "boss_bsod_tool": ("h", 150),
    "boss_bsod_projectiles": ("w", 52),
    "boss_bsod_food": ("w", 30),
    "boss_bsod_bacteria": ("w", 44),
    "boss_bsod_debris": ("w", 28),
}

# Boss 3 #DIV/0! (boss_div0_full: el boss entero mide ~260 px de alto)
SHEETS_DIV0 = {
    "boss_div0_full": ("h", 260),
    "boss_div0_body": ("h", 210),
    "boss_div0_vault": ("w", 94),
    "boss_div0_head": ("h", 66),
    "boss_div0_stamp": ("h", 132),
    "boss_div0_tool": ("h", 153),
    "boss_div0_projectiles": ("h", 49),
    "boss_div0_containers": ("w", 170),
    "boss_div0_briefcase": ("h", 40),
    "boss_div0_debris": ("w", 28),
}

# Boss 4 SYNTAX ERROR (boss_syntax_full: el boss entero mide ~270 px de alto)
SHEETS_SYNTAX = {
    "boss_syntax_full": ("h", 270),
    "boss_syntax_body": ("h", 207),
    "boss_syntax_board": ("w", 72),
    "boss_syntax_head": ("h", 63),
    "boss_syntax_pointer": ("h", 150),
    "boss_syntax_hand": ("h", 135),
    "boss_syntax_projectiles": ("h", 40),
    "boss_syntax_desks": ("h", 74),
    "boss_syntax_bellhop": ("h", 52),
    "boss_syntax_debris": ("w", 28),
}

# Boss 5 STACK OVERFLOW (boss_stack_full: la máquina entera mide ~260 px de alto)
SHEETS_STACK = {
    "boss_stack_full": ("h", 260),
    "boss_stack_body": ("h", 200),
    "boss_stack_engine": ("w", 66),
    "boss_stack_head": ("w", 76),
    "boss_stack_crane": ("h", 170),
    "boss_stack_hammer": ("h", 150),
    "boss_stack_tower": ("w", 90),
    "boss_stack_projectiles": ("w", 48),
    "boss_stack_drone": ("h", 64),
    "boss_stack_debris": ("w", 28),
}

# Boss 6 403 FORBIDDEN (boss_judge_full: el juez entero mide ~270 px de alto)
SHEETS_JUDGE = {
    "boss_judge_full": ("h", 270),
    "boss_judge_body": ("w", 200),
    "boss_judge_core": ("w", 46),
    "boss_judge_head": ("w", 74),
    "boss_judge_gavel": ("h", 140),
    "boss_judge_hand": ("h", 130),
    "boss_judge_evidence": ("w", 34),
    "boss_judge_projectiles": ("w", 44),
    "boss_judge_folder": ("h", 52),
    "boss_judge_debris": ("w", 28),
}

# Boss 7 MISSING TEXTURE (boss_tex_full: la estatua entera con su pedestal mide ~290 px de alto)
SHEETS_TEX = {
    "boss_tex_full": ("h", 290),
    "boss_tex_body": ("h", 215),
    "boss_tex_core": ("w", 46),
    "boss_tex_head": ("w", 78),
    "boss_tex_brush": ("h", 165),
    "boss_tex_palette": ("h", 150),
    "boss_tex_projectiles": ("w", 44),
    "boss_tex_props": ("w", 90),
    "boss_tex_mannequin": ("h", 82),
    "boss_tex_debris": ("w", 30),
}

# Boss 8 KERNEL PANIC (boss_kp_full: el chef con su carrito mide ~300 px de alto)
SHEETS_KP = {
    "boss_kp_full": ("h", 300),
    "boss_kp_body": ("h", 218),
    "boss_kp_core": ("w", 57),
    "boss_kp_head": ("w", 82),
    "boss_kp_pan": ("h", 150),
    "boss_kp_mic": ("h", 150),
    "boss_kp_projectiles": ("w", 44),
    "boss_kp_props": ("w", 90),
    "boss_kp_paparazzi": ("h", 72),
    "boss_kp_debris": ("w", 28),
}

# Hojas cuyas piezas casi se tocan: se cortan a mano en estas columnas (px de la hoja).
SPLIT_X = {"boss_div0_body": [784]}
# Hojas cuyas piezas se cruzan (una mano por debajo del hombro de la otra): se separan por manchas conectadas.
COMPONENTS = {"boss_syntax_hand", "boss_tex_debris", "boss_tex_mannequin", "boss_kp_paparazzi", "boss_kp_debris"}
# Hojas en 2 filas separadas por manchas: se ordenan por fila (arriba/abajo) y luego de izquierda a derecha.
ROWS2 = {"boss_tex_debris", "boss_tex_mannequin", "boss_kp_paparazzi", "boss_kp_debris"}
# Piezas más chicas que esto (px de la hoja) se descartan (gotitas sueltas).
MIN_PIECE = {"boss_syntax_projectiles": 40}

SETS = {"deadbeef": SHEETS, "bsod": SHEETS_BSOD, "div0": SHEETS_DIV0, "syntax": SHEETS_SYNTAX, "stack": SHEETS_STACK, "judge": SHEETS_JUDGE, "tex": SHEETS_TEX, "kp": SHEETS_KP}

BG_TOL = 60.0      # distancia de color al fondo para considerarlo fondo
GAP_MIN = 6        # filas/columnas vacías seguidas para separar piezas


def bg_mask(rgb: np.ndarray) -> np.ndarray:
    h, w, _ = rgb.shape
    corners = np.concatenate([rgb[:8, :8].reshape(-1, 3), rgb[:8, -8:].reshape(-1, 3),
                              rgb[-8:, :8].reshape(-1, 3), rgb[-8:, -8:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((rgb.astype(np.float32) - bg) ** 2).sum(axis=2))
    return dist < BG_TOL


def bands(filled: np.ndarray) -> list[tuple[int, int]]:
    """Tramos con contenido separados por >= GAP_MIN posiciones vacías."""
    out: list[tuple[int, int]] = []
    start = None
    empty = 0
    for i, f in enumerate(filled):
        if f:
            if start is None:
                start = i
            empty = 0
            end = i
        elif start is not None:
            empty += 1
            if empty >= GAP_MIN:
                out.append((start, end + 1))
                start = None
    if start is not None:
        out.append((start, end + 1))
    return [b for b in out if b[1] - b[0] > 12]


def pieces(rgb: np.ndarray, fg: np.ndarray) -> list[tuple[int, int, int, int]]:
    boxes = []
    for y0, y1 in bands(fg.sum(axis=1) > 2):
        row = fg[y0:y1]
        for x0, x1 in bands(row.sum(axis=0) > 2):
            sub = fg[y0:y1, x0:x1]
            ys = np.where(sub.any(axis=1))[0]
            boxes.append((x0, y0 + ys[0], x1, y0 + ys[-1] + 1))
    return boxes


def components(fg: np.ndarray, min_area: int = 4000) -> list[tuple[tuple[int, int, int, int], np.ndarray]]:
    """Manchas conectadas (8 vecinos) sobre la máscara reducida a 1/4; devuelve caja y máscara de cada una."""
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
        if m.sum() < min_area:
            continue
        ys, xs = np.nonzero(m)
        out.append(((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1), m))
    out.sort(key=lambda b: (b[0][0]))
    return out


def main() -> None:
    wanted = sys.argv[1:] or list(SETS)
    for boss in wanted:
        slice_set(OUT_DIR / boss, SETS[boss])
    if "bsod" in wanted:
        bsod_variants(OUT_DIR / "bsod")
    if "div0" in wanted:
        div0_variants(OUT_DIR / "div0")
    if "stack" in wanted:
        stack_variants(OUT_DIR / "stack")


def stack_variants(out: Path) -> None:
    """La bola y el ancla sueltas: se recorta la punta de la grúa (debajo de donde termina la cadena)."""
    for idx, name in ((2, "boss_stack_ball"), (1, "boss_stack_anchor")):
        src = out / f"boss_stack_crane_{idx}.png"
        if not src.exists():
            continue
        a = np.asarray(Image.open(src).convert("RGBA"))
        op = a[..., 3] > 0
        widths = op.sum(axis=1)
        h = a.shape[0]
        # la pluma termina donde el ancho cae a la mitad; luego viene la cadena (angosta) y la punta
        y = h // 2
        while y < h - 1 and widths[y] > widths[h // 2] * 0.5:
            y += 1
        chain = float(np.median(widths[y:y + 20]))
        while y < h - 1 and widths[y] <= chain + 3:
            y += 1
        crop = a[y:]
        cols = np.nonzero(crop[..., 3].any(axis=0))[0]
        Image.fromarray(crop[:, cols.min():cols.max() + 1], "RGBA").save(out / f"{name}.png")
    print("variantes stack listas")


def div0_variants(out: Path) -> None:
    """La mancha del sello sale rojo oscuro (parece sangre): se pasa a tinta morada."""
    ink = out / "boss_div0_projectiles_6.png"
    if ink.exists():
        a = np.asarray(Image.open(ink).convert("RGBA")).copy()
        lum = a[..., :3].astype(np.float32) @ np.array([0.3, 0.59, 0.11])
        k = np.clip(lum / 120.0, 0.0, 1.6)
        a[..., 0] = np.clip(70 * k, 0, 255).astype(np.uint8)
        a[..., 1] = np.clip(40 * k, 0, 255).astype(np.uint8)
        a[..., 2] = np.clip(150 * k, 0, 255).astype(np.uint8)
        Image.fromarray(a, "RGBA").save(out / "boss_div0_ink.png")
    print("variantes div0 listas")


def bsod_variants(out: Path) -> None:
    """Variantes que el juego tiñe: jeringa lanzada en azul (anestesia) y charco en gris."""
    syr = out / "boss_bsod_projectiles_0.png"
    if syr.exists():
        a = np.asarray(Image.open(syr).convert("RGBA")).copy()
        r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
        red = (r > g + 40) & (r > b + 40)
        a[red, 0], a[red, 2] = b[red] // 2 + 20, np.minimum(255, r[red] + 20)
        a[red, 1] = np.minimum(255, g[red] + 70)
        Image.fromarray(a, "RGBA").save(out / "boss_bsod_syringe_blue.png")
    pud = out / "boss_bsod_projectiles_7.png"
    if pud.exists():
        a = np.asarray(Image.open(pud).convert("RGBA")).copy()
        lum = (a[..., :3].astype(np.float32) @ np.array([0.3, 0.59, 0.11])) * 1.9
        a[..., 0] = a[..., 1] = a[..., 2] = np.clip(lum, 0, 255).astype(np.uint8)
        Image.fromarray(a, "RGBA").save(out / "boss_bsod_puddle_grey.png")
    print("variantes bsod listas")


def slice_set(OUT: Path, sheets: dict) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (dim, target) in sheets.items():
        path = SRC / f"{name}.png"
        if not path.exists():
            print("falta", path)
            continue
        im = Image.open(path).convert("RGB")
        rgb = np.asarray(im)
        bgm = bg_mask(rgb)
        fg = ~bgm
        masks = {}
        if name in COMPONENTS:
            boxes = []
            for box, m in components(fg):
                masks[box] = m
                boxes.append(box)
            if name in ROWS2:
                half = rgb.shape[0] / 2
                boxes.sort(key=lambda b: (int((b[1] + b[3]) / 2 > half), b[0]))
        else:
            cuts = [0] + SPLIT_X.get(name, []) + [rgb.shape[1]]
            boxes = []
            for c0, c1 in zip(cuts, cuts[1:]):
                for (x0, y0, x1, y1) in pieces(rgb[:, c0:c1], fg[:, c0:c1]):
                    boxes.append((x0 + c0, y0, x1 + c0, y1))
        mn = MIN_PIECE.get(name, 0)
        boxes = [b for b in boxes if b[2] - b[0] >= mn or b[3] - b[1] >= mn]
        biggest = max((b[2] - b[0]) if dim == "w" else (b[3] - b[1]) for b in boxes)
        k = target / biggest
        for i, (x0, y0, x1, y1) in enumerate(boxes):
            m = masks[(x0, y0, x1, y1)] if (x0, y0, x1, y1) in masks else fg
            rgba = np.dstack([rgb[y0:y1, x0:x1], np.where(m[y0:y1, x0:x1], 255, 0).astype(np.uint8)])
            piece = Image.fromarray(rgba, "RGBA")
            # premultiplicar para que el borde no se manche de verde al reducir
            arr = np.asarray(piece).astype(np.float32)
            arr[..., :3] *= arr[..., 3:4] / 255.0
            small = Image.fromarray(arr.astype(np.uint8), "RGBA").resize(
                (max(1, round(piece.width * k)), max(1, round(piece.height * k))), Image.BOX)
            s = np.asarray(small).astype(np.float32)
            a = s[..., 3:4]
            s[..., :3] = np.where(a > 0, s[..., :3] * 255.0 / np.maximum(a, 1), 0)
            s[..., 3] = np.where(s[..., 3] >= 110, 255, 0)
            Image.fromarray(s.clip(0, 255).astype(np.uint8), "RGBA").save(OUT / f"{name}_{i}.png")
        print(f"{name}: {len(boxes)} piezas, factor {k:.3f}")


if __name__ == "__main__":
    main()
