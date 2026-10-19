#!/usr/bin/env python3
"""Slice Runway combat sheets → assets/sprites/combat/ RGBA frames.

Chroma: edge-flood mint green only (no HSV body paint).
Canvas: 128x192, feet near bottom, content centered horizontally.
"""
from __future__ import annotations

import json
import shutil
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path("/workspace/prototipo")
OUT = ROOT / "assets/sprites/combat"
CANVAS_W, CANVAS_H = 128, 192
FOOT_PAD = 8  # pixels from bottom
BG_SEED = np.array([150.0, 215.0, 161.0])

RAW2 = Path("/workspace/runway_2gen1/raw")
NAMED19 = Path("/workspace/runway_anim_check/named")


def color_dist(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return np.sqrt(((a.astype(np.float64) - b.astype(np.float64)) ** 2).sum(axis=-1))


def flood_remove_bg(rgba: np.ndarray, seed_color: np.ndarray,
                    thr: float = 52.0, fringe_thr: float = 70.0) -> np.ndarray:
    h, w = rgba.shape[:2]
    rgb = rgba[..., :3]
    dist = color_dist(rgb, seed_color)
    mintish = (
        (rgb[..., 1] > rgb[..., 0] + 15)
        & (rgb[..., 1] > rgb[..., 2] + 8)
        & (rgb[..., 1] > 140)
        & (rgb[..., 1] < 240)
        & (rgb[..., 0] > 80)
        & (rgb[..., 0] < 200)
    )
    is_bg_seed = (dist < thr) | mintish
    visited = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bg_seed[y, x]:
                q.append((y, x))
                visited[y, x] = True
    for y in range(h):
        for x in (0, w - 1):
            if is_bg_seed[y, x] and not visited[y, x]:
                q.append((y, x))
                visited[y, x] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                if is_bg_seed[ny, nx] or dist[ny, nx] < thr:
                    visited[ny, nx] = True
                    q.append((ny, nx))
    alpha = np.where(visited, 0, 255).astype(np.uint8)
    opaque = alpha > 0
    near_trans = ndimage.binary_dilation(~opaque, iterations=2) & opaque
    fringe = near_trans & ((dist < fringe_thr) | mintish)
    rim_green = (
        near_trans
        & (rgb[..., 1] > rgb[..., 0] + 8)
        & (rgb[..., 1] > rgb[..., 2] + 5)
        & (rgb[..., 1] > 40)
        & (rgb[..., 0] < 180)
    )
    alpha[fringe | rim_green] = 0
    out = rgba.copy()
    out[..., 3] = alpha
    out[alpha == 0] = [0, 0, 0, 0]
    return out


def load_rgba(path: Path) -> np.ndarray:
    im = Image.open(path).convert("RGBA")
    arr = np.asarray(im).copy()
    # sample corner for seed
    seed = arr[8, 8, :3].astype(np.float64)
    # prefer mint-ish seed
    if seed[1] > seed[0] and seed[1] > seed[2]:
        used = seed
    else:
        used = BG_SEED
    cleaned = flood_remove_bg(arr, used)
    return cleaned


def content_bbox(cell: np.ndarray, min_alpha: int = 16) -> tuple[int, int, int, int] | None:
    alpha = cell[..., 3] > min_alpha
    if not alpha.any():
        return None
    ys, xs = np.where(alpha)
    return int(ys.min()), int(xs.min()), int(ys.max()) + 1, int(xs.max()) + 1


def place_on_canvas(cell: np.ndarray, canvas_w=CANVAS_W, canvas_h=CANVAS_H) -> Image.Image:
    bb = content_bbox(cell)
    canvas = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)
    if bb is None:
        return Image.fromarray(canvas, "RGBA")
    y0, x0, y1, x1 = bb
    crop = cell[y0:y1, x0:x1]
    ch, cw = crop.shape[:2]
    # Scale to fit canvas with margin; prefer keeping pixel art crisp via nearest
    max_w = canvas_w - 8
    max_h = canvas_h - FOOT_PAD - 4
    scale = min(max_w / max(cw, 1), max_h / max(ch, 1), 1.0)
    # If source is huge (full sheet cells), allow downscale; if small, keep 1:1 or slight downscale only
    # For large cells from 2752 sheets, we need aggressive downscale
    if scale >= 1.0 and max(cw, ch) > max(max_w, max_h):
        scale = min(max_w / cw, max_h / ch)
    nw = max(1, int(round(cw * scale)))
    nh = max(1, int(round(ch * scale)))
    pil = Image.fromarray(crop, "RGBA").resize((nw, nh), Image.Resampling.NEAREST)
    arr = np.asarray(pil)
    ox = (canvas_w - nw) // 2
    oy = canvas_h - FOOT_PAD - nh
    oy = max(0, oy)
    canvas[oy:oy + nh, ox:ox + nw] = arr
    return Image.fromarray(canvas, "RGBA")


def slice_grid(rgba: np.ndarray, cols: int, rows: int, margin: float = 0.02) -> list[np.ndarray]:
    h, w = rgba.shape[:2]
    mx = int(w * margin)
    my = int(h * margin)
    usable_w = w - 2 * mx
    usable_h = h - 2 * my
    cw = usable_w // cols
    ch = usable_h // rows
    cells = []
    for r in range(rows):
        for c in range(cols):
            x0 = mx + c * cw
            y0 = my + r * ch
            cells.append(rgba[y0:y0 + ch, x0:x0 + cw].copy())
    return cells


def detect_row_frames(row: np.ndarray, min_gap: int = 8, min_width: int = 20) -> list[np.ndarray]:
    """Split a horizontal strip into frames by alpha column projection gaps."""
    alpha = row[..., 3] > 20
    col_sum = alpha.sum(axis=0)
    active = col_sum > max(3, row.shape[0] * 0.02)
    frames = []
    in_run = False
    start = 0
    gap = 0
    for i, a in enumerate(active):
        if a:
            if not in_run:
                # start new if gap was enough or first
                start = i
                in_run = True
            gap = 0
        else:
            if in_run:
                gap += 1
                if gap >= min_gap:
                    end = i - gap + 1
                    if end - start >= min_width:
                        frames.append(row[:, start:end].copy())
                    in_run = False
                    gap = 0
    if in_run:
        end = len(active)
        if end - start >= min_width:
            frames.append(row[:, start:end].copy())
    return frames


def save_seq(frames: list[Image.Image], folder: Path, prefix: str) -> list[str]:
    folder.mkdir(parents=True, exist_ok=True)
    # clear old matching
    for old in folder.glob(f"{prefix}_*.png"):
        old.unlink()
    paths = []
    for i, im in enumerate(frames):
        p = folder / f"{prefix}_{i}.png"
        im.save(p)
        paths.append(str(p.relative_to(ROOT)))
    return paths


def pick_indices(n: int, target: int) -> list[int]:
    if n <= target:
        return list(range(n))
    if target == 1:
        return [0]
    return [int(round(i * (n - 1) / (target - 1))) for i in range(target)]


def extract_projectile(cell: np.ndarray) -> Image.Image | None:
    """Try to isolate blue orb pixels from a cast frame."""
    rgb = cell[..., :3].astype(np.float32)
    a = cell[..., 3] > 16
    # blue-ish: B high, B>R, B>G somewhat
    blue = a & (rgb[..., 2] > 140) & (rgb[..., 2] > rgb[..., 0] + 30) & (rgb[..., 2] > rgb[..., 1] + 10)
    if blue.sum() < 30:
        return None
    ys, xs = np.where(blue)
    pad = 4
    y0, y1 = max(0, ys.min() - pad), min(cell.shape[0], ys.max() + pad + 1)
    x0, x1 = max(0, xs.min() - pad), min(cell.shape[1], xs.max() + pad + 1)
    crop = cell[y0:y1, x0:x1].copy()
    # keep only blue-ish + nearby glow
    rgb2 = crop[..., :3].astype(np.float32)
    keep = (
        (crop[..., 3] > 16)
        & (rgb2[..., 2] > 100)
        & (rgb2[..., 2] >= rgb2[..., 0] - 10)
    )
    crop[~keep] = 0
    # place on small canvas 48x48
    cw, ch = 48, 48
    canvas = np.zeros((ch, cw, 4), dtype=np.uint8)
    hh, ww = crop.shape[:2]
    scale = min(cw / ww, ch / hh, 1.0)
    nw, nh = max(1, int(ww * scale)), max(1, int(hh * scale))
    pil = Image.fromarray(crop, "RGBA").resize((nw, nh), Image.Resampling.NEAREST)
    arr = np.asarray(pil)
    ox, oy = (cw - nw) // 2, (ch - nh) // 2
    canvas[oy:oy + nh, ox:ox + nw] = arr
    return Image.fromarray(canvas, "RGBA")


def map_raw2() -> dict[str, Path]:
    raws = sorted(RAW2.glob("*.png"), key=lambda p: p.name.lower())
    assert len(raws) == 5, raws
    return {
        "mago_cast": raws[0],      # thumbs/00
        "chain_whip": raws[1],     # thumbs/01
        "walk": raws[2],           # thumbs/02
        "mago_glow": raws[3],      # thumbs/03
        "mago_melee": raws[4],     # thumbs/04
    }


def process_walk(path: Path) -> dict:
    rgba = load_rgba(path)
    h, w = rgba.shape[:2]
    # 4 rows
    row_h = h // 4
    dirs = ["front", "back", "right", "left"]
    meta = {}
    for i, dname in enumerate(dirs):
        row = rgba[i * row_h:(i + 1) * row_h, :]
        frames = detect_row_frames(row, min_gap=10, min_width=30)
        if len(frames) < 2:
            # fallback equal split into 8
            frames = slice_grid(row, 8, 1)
        idxs = pick_indices(len(frames), 4)
        chosen = [place_on_canvas(frames[j]) for j in idxs]
        paths = save_seq(chosen, OUT / "walk", dname)
        meta[dname] = {"source_frames": len(frames), "saved": paths, "picked": idxs}
    return meta


def process_grid_anim(path: Path, cols: int, rows: int, out_dir: Path, prefix: str,
                      take: list[int] | None = None) -> dict:
    rgba = load_rgba(path)
    cells = slice_grid(rgba, cols, rows)
    if take is not None:
        cells = [cells[i] for i in take if i < len(cells)]
    # drop nearly empty
    kept = []
    for c in cells:
        bb = content_bbox(c)
        if bb is None:
            continue
        y0, x0, y1, x1 = bb
        if (y1 - y0) * (x1 - x0) < 400:
            continue
        kept.append(c)
    imgs = [place_on_canvas(c) for c in kept]
    paths = save_seq(imgs, out_dir, prefix)
    return {"cells": len(cells), "kept": len(kept), "saved": paths}


def process_mago_cast(path: Path) -> dict:
    # 2x4 grid — use first 4 as cast anim (cast+release), skip projectile travel for character anim
    rgba = load_rgba(path)
    cells = slice_grid(rgba, 4, 2)
    # cast: frames 0..3 (top row) + maybe frame 6 recovery
    cast_idxs = [0, 1, 2, 3, 6]
    cast_cells = [cells[i] for i in cast_idxs if i < len(cells)]
    # For cast frames that include projectile in same cell, still OK for character anim
    imgs = [place_on_canvas(c) for c in cast_cells]
    paths = save_seq(imgs, OUT / "mago", "cast")
    # projectile from cells 3,4,5
    proj = None
    for i in (3, 4, 5):
        if i < len(cells):
            proj = extract_projectile(cells[i])
            if proj is not None:
                break
    if proj is None:
        # procedural blue orb fallback
        orb = np.zeros((48, 48, 4), dtype=np.uint8)
        yy, xx = np.ogrid[:48, :48]
        d = np.sqrt((yy - 23.5) ** 2 + (xx - 23.5) ** 2)
        mask = d < 12
        orb[mask] = [80, 160, 255, 255]
        glow = (d < 16) & ~mask
        orb[glow] = [120, 200, 255, 180]
        proj = Image.fromarray(orb, "RGBA")
    proj_path = OUT / "mago" / "projectile.png"
    proj.save(proj_path)
    return {"cast": paths, "projectile": str(proj_path.relative_to(ROOT))}


def process_mago_melee(path: Path) -> dict:
    rgba = load_rgba(path)
    # 2 rows — top 4, bottom 5-ish; use detection per row
    h = rgba.shape[0]
    top = rgba[: h // 2]
    bot = rgba[h // 2:]
    frames = detect_row_frames(top, min_gap=8, min_width=40)
    frames += detect_row_frames(bot, min_gap=8, min_width=40)
    if len(frames) < 4:
        frames = slice_grid(rgba, 4, 2)
    # take up to 6 good frames for melee
    idxs = pick_indices(len(frames), min(6, len(frames)))
    imgs = [place_on_canvas(frames[j]) for j in idxs]
    paths = save_seq(imgs, OUT / "mago", "melee")
    return {"source_frames": len(frames), "saved": paths}


def process_chain(path: Path) -> dict:
    # 3 cols x 2 rows
    meta = process_grid_anim(path, 3, 2, OUT / "chain", "whip_short")
    return meta


def process_guerrero_attack(path: Path) -> dict:
    rgba = load_rgba(path)
    h, w = rgba.shape[:2]
    # Main action is lower ~60% of sheet (ghost blur on top)
    # Try: use bottom 55% as strip, detect frames
    y0 = int(h * 0.35)
    strip = rgba[y0:, :]
    frames = detect_row_frames(strip, min_gap=12, min_width=50)
    if len(frames) < 3:
        # full sheet single row of 6
        frames = detect_row_frames(rgba, min_gap=12, min_width=50)
    if len(frames) < 3:
        frames = slice_grid(rgba, 6, 1)
    imgs = [place_on_canvas(f) for f in frames]
    paths = save_seq(imgs, OUT / "guerrero", "attack")
    # guard from idle-like first/last with shield visible
    return {"source_frames": len(frames), "attack": paths}


def process_guerrero_guard(path: Path) -> dict:
    rgba = load_rgba(path)
    h = rgba.shape[0]
    # bottom row has guard poses
    bot = rgba[h // 2:, :]
    frames = detect_row_frames(bot, min_gap=10, min_width=40)
    if len(frames) < 2:
        frames = detect_row_frames(rgba, min_gap=10, min_width=40)
    # Prefer frames that look like guard — take middle ones if many
    if len(frames) >= 3:
        # skip first idle duplicates often; take indices 1 and maybe 3
        pick = [1]
        if len(frames) > 3:
            pick.append(min(3, len(frames) - 2))
        elif len(frames) > 1:
            pick.append(len(frames) - 1)
        chosen = [frames[i] for i in pick if i < len(frames)]
    else:
        chosen = frames
    if not chosen:
        # fallback: use first attack frame duplicated as guard
        atk = sorted((OUT / "guerrero").glob("attack_*.png"))
        if atk:
            shutil.copy(atk[0], OUT / "guerrero" / "guard_0.png")
            return {"saved": ["assets/sprites/combat/guerrero/guard_0.png"], "note": "fallback from attack_0"}
        return {"saved": []}
    imgs = [place_on_canvas(c) for c in chosen]
    # also add a held guard = first guard frame as guard_idle
    paths = save_seq(imgs, OUT / "guerrero", "guard")
    idle = imgs[0]
    idle.save(OUT / "guerrero" / "guard_idle.png")
    paths.append("assets/sprites/combat/guerrero/guard_idle.png")
    return {"source_frames": len(frames), "saved": paths}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sources = map_raw2()
    report = {"sources": {k: str(v) for k, v in sources.items()}, "outputs": {}}

    print("Walk…")
    report["outputs"]["walk"] = process_walk(sources["walk"])

    print("Mago cast…")
    report["outputs"]["mago_cast"] = process_mago_cast(sources["mago_cast"])

    print("Mago melee…")
    report["outputs"]["mago_melee"] = process_mago_melee(sources["mago_melee"])

    print("Chain…")
    report["outputs"]["chain"] = process_chain(sources["chain_whip"])

    g_atk = NAMED19 / "19_00.png"
    g_grd = NAMED19 / "19_10.png"
    print("Guerrero attack (19_00)…")
    report["outputs"]["guerrero_attack"] = process_guerrero_attack(g_atk)
    report["sources"]["guerrero_attack"] = str(g_atk.resolve())
    print("Guerrero guard (19_10)…")
    report["outputs"]["guerrero_guard"] = process_guerrero_guard(g_grd)
    report["sources"]["guerrero_guard"] = str(g_grd.resolve())

    # also keep glow sheet note (optional unused for now)
    report["sources"]["mago_glow_unused"] = str(sources["mago_glow"])

    meta_path = OUT / "_slice_report.json"
    meta_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("Wrote", meta_path)
    # inventory
    for sub in ["walk", "guerrero", "mago", "chain"]:
        files = sorted((OUT / sub).glob("*.png"))
        print(f"  {sub}: {len(files)} files -> {[f.name for f in files]}")


if __name__ == "__main__":
    main()
