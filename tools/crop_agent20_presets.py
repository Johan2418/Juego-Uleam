#!/usr/bin/env python3
"""Crop Runway Agent turnaround sheets → 128×192 RGBA character-creator presets."""
from __future__ import annotations

import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SRC_DIR = Path("/workspace/runway_agent_20/named")
OUT_VARIANTS = Path("/workspace/prototipo/assets/sprites/student/variants")
OUT_PREVIEWS = Path("/workspace/prototipo/assets/sprites/student/_previews")
STUDENT_ROOT = Path("/workspace/prototipo/assets/sprites/student")

CANVAS_W, CANVAS_H = 128, 192
FOOT_MARGIN = 3
PREVIEW_SCALE = 3

LABELS = {
    0: "Gorra roja + camisa",
    1: "Chaqueta negra",
    2: "Traje azul",
    3: "Traje negro",
    4: "Jersey deportivo",
    5: "Pelo rubio punta",
    6: "Coleta / coleta negra",
    7: "Trenza larga",
    8: "Pelo gris",
    9: "Mochila",
    10: "Afro / rizado grande",
    11: "Bufanda",
    12: "Chaleco utilitario",
    13: "Pelo naranja rizado",
    14: "Hoodie rojo",
    15: "Piel más oscura + camisa",
    16: "Overalls / peto",
    17: "Impermeable amarillo",
    18: "Coletas rubias",
    19: "Gafas",
}

TRAITS = {
    0: "gorra roja, camisa azul clara, pantalón azul",
    1: "chaqueta negra, look formal casual",
    2: "traje / blazer azul",
    3: "traje negro formal",
    4: "jersey / camiseta deportiva",
    5: "pelo rubio en punta, camisa",
    6: "coleta negra / pelo recogido",
    7: "trenza larga",
    8: "pelo gris / canoso",
    9: "mochila / accesorio espalda",
    10: "afro / rizado voluminoso",
    11: "bufanda",
    12: "chaleco utilitario / cargo",
    13: "pelo naranja rizado",
    14: "hoodie rojo",
    15: "piel más oscura, camisa",
    16: "overalls / peto",
    17: "impermeable amarillo",
    18: "coletas rubias / dos colas",
    19: "gafas",
}


def content_bbox(mask: np.ndarray, pad: int = 0):
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return None
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    h, w = mask.shape
    return (
        max(0, x0 - pad),
        max(0, y0 - pad),
        min(w, x1 + pad),
        min(h, y1 + pad),
    )


def mint_mask(rgb: np.ndarray, seed: np.ndarray, tol: float = 48.0) -> np.ndarray:
    diff = rgb.astype(np.float32) - seed.astype(np.float32)
    dist = np.sqrt((diff * diff).sum(axis=-1))
    r = rgb[..., 0].astype(np.float32)
    g = rgb[..., 1].astype(np.float32)
    b = rgb[..., 2].astype(np.float32)
    greenish = (g > r + 18) & (g > b + 18) & (g > 150)
    return (dist <= tol) | (greenish & (dist <= tol * 1.55))


def edge_flood_bg_pil(rgb_im: Image.Image, seed_rgb: tuple[int, int, int], thresh: int = 48) -> np.ndarray:
    """Fast PIL flood-fill from borders → True where BACKGROUND."""
    # Work on a copy; floodfill replaces bg with a sentinel color
    work = rgb_im.copy().convert("RGB")
    sentinel = (255, 0, 255)  # magenta not present in mint art
    w, h = work.size
    # Sample border seeds every few pixels
    seeds = []
    for x in range(0, w, 8):
        seeds.append((x, 0))
        seeds.append((x, h - 1))
    for y in range(0, h, 8):
        seeds.append((0, y))
        seeds.append((w - 1, y))
    # Also corners and mid-edges
    seeds.extend([(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
                  (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)])

    for sx, sy in seeds:
        px = work.getpixel((sx, sy))
        # only flood if still mint-like (not already sentinel / character)
        if px == sentinel:
            continue
        dr = abs(px[0] - seed_rgb[0])
        dg = abs(px[1] - seed_rgb[1])
        db = abs(px[2] - seed_rgb[2])
        if max(dr, dg, db) > thresh + 10:
            continue
        ImageDraw.floodfill(work, (sx, sy), sentinel, thresh=thresh)

    arr = np.array(work)
    bg = (arr[..., 0] == 255) & (arr[..., 1] == 0) & (arr[..., 2] == 255)
    return bg


def find_column_cuts(fg_row: np.ndarray, min_gap: int = 20) -> list[tuple[int, int]]:
    """Given a 1D boolean (columns with content), return (start,end) spans of content blobs."""
    spans = []
    in_blob = False
    start = 0
    for i, v in enumerate(fg_row):
        if v and not in_blob:
            in_blob = True
            start = i
        elif not v and in_blob:
            in_blob = False
            spans.append((start, i))
    if in_blob:
        spans.append((start, len(fg_row)))
    # merge tiny gaps
    if not spans:
        return spans
    merged = [spans[0]]
    for s, e in spans[1:]:
        ps, pe = merged[-1]
        if s - pe < min_gap:
            merged[-1] = (ps, e)
        else:
            merged.append((s, e))
    return merged


def isolate_front_cell(fg: np.ndarray) -> tuple[np.ndarray, tuple, str]:
    """Isolate top-left front character. Handles 2×2 and denser grids."""
    h, w = fg.shape
    bb = content_bbox(fg)
    if bb is None:
        raise RuntimeError("empty foreground")
    x0, y0, x1, y1 = bb
    cw, ch = x1 - x0, y1 - y0

    # Vertical projection on top half of content to find columns
    top_band = fg[y0:y0 + max(1, ch // 2), x0:x1]
    col_has = top_band.any(axis=0)
    col_spans = find_column_cuts(col_has, min_gap=max(12, cw // 40))

    # Horizontal projection for rows
    row_has = fg[y0:y1, x0:x1].any(axis=1)
    row_spans = find_column_cuts(row_has, min_gap=max(12, ch // 40))

    method = "grid_proj"
    if len(col_spans) >= 2 and len(row_spans) >= 1:
        # TL cell = first col span × first row span (relative to content bbox)
        cs, ce = col_spans[0]
        rs, re = row_spans[0]
        # Expand cell slightly into gutter midpoint toward next span if exists
        if len(col_spans) >= 2:
            ce = (ce + col_spans[1][0]) // 2
        if len(row_spans) >= 2:
            re = (re + row_spans[1][0]) // 2
        cell = np.zeros_like(fg)
        cell[y0 + rs:y0 + re, x0 + cs:x0 + ce] = fg[y0 + rs:y0 + re, x0 + cs:x0 + ce]
        method = f"proj_{len(row_spans)}x{len(col_spans)}"
    else:
        # Classic 2×2 mid split of content
        mid_x = (x0 + x1) // 2
        mid_y = (y0 + y1) // 2
        cell = fg.copy()
        cell[:, mid_x:] = False
        cell[mid_y:, :] = False
        cell[:y0, :] = False
        cell[:, :x0] = False
        method = "mid_split_2x2"

    tbb = content_bbox(cell)
    if tbb is None:
        # fallback mid split
        mid_x = (x0 + x1) // 2
        mid_y = (y0 + y1) // 2
        cell = fg.copy()
        cell[:, mid_x:] = False
        cell[mid_y:, :] = False
        tbb = content_bbox(cell)
        method = "mid_split_fallback"
    if tbb is None:
        raise RuntimeError("could not isolate front")
    return cell, tbb, method


def paint_enclosed_mint(rgba: np.ndarray, seed: np.ndarray, tol: float = 38.0) -> np.ndarray:
    """Paint tiny fully-enclosed mint blobs (e.g. green eyes) to near-black."""
    h, w = rgba.shape[:2]
    rgb = rgba[..., :3]
    alpha = rgba[..., 3]
    opaque = alpha > 128
    mintish = mint_mask(rgb, seed, tol=tol) & opaque
    visited = np.zeros((h, w), dtype=bool)
    out = rgba.copy()
    ys, xs = np.where(mintish)
    for y, x in zip(ys.tolist(), xs.tolist()):
        if visited[y, x]:
            continue
        q = deque([(y, x)])
        visited[y, x] = True
        pixels = []
        touches_outside = False
        while q:
            cy, cx = q.popleft()
            pixels.append((cy, cx))
            if len(pixels) > 100:
                touches_outside = True  # too big — leave alone
                # still mark rest visited via flood without collecting
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if not (0 <= ny < h and 0 <= nx < w):
                    touches_outside = True
                    continue
                if alpha[ny, nx] <= 128:
                    touches_outside = True
                    continue
                if mintish[ny, nx] and not visited[ny, nx]:
                    visited[ny, nx] = True
                    q.append((ny, nx))
        if (not touches_outside) and 1 <= len(pixels) <= 80:
            for py, px in pixels:
                out[py, px] = (18, 16, 14, 255)
    return out


def nearest_scale(img: Image.Image, scale: float) -> Image.Image:
    nw = max(1, int(round(img.width * scale)))
    nh = max(1, int(round(img.height * scale)))
    return img.resize((nw, nh), Image.NEAREST)


def place_on_canvas(char_rgba: Image.Image, scale: float) -> Image.Image:
    scaled = nearest_scale(char_rgba, scale)
    canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    arr = np.array(scaled)
    fg = arr[..., 3] > 128
    bb = content_bbox(fg)
    if bb is None:
        return canvas
    cx0, cy0, cx1, cy1 = bb
    content_cx = (cx0 + cx1) / 2.0
    dest_x = int(round(CANVAS_W / 2.0 - content_cx))
    dest_y = int(round((CANVAS_H - FOOT_MARGIN) - cy1))
    sw, sh = scaled.size
    if dest_y < 0:
        dest_y = 0
    if dest_y + sh > CANVAS_H:
        dest_y = max(0, CANVAS_H - sh)
    canvas.paste(scaled, (dest_x, dest_y), scaled)
    return canvas


def extract_front_rgba(path: Path) -> tuple[Image.Image, dict]:
    rgb_im = Image.open(path).convert("RGB")
    rgb = np.array(rgb_im)
    h, w = rgb.shape[:2]
    corner = np.stack([rgb[0, 0], rgb[0, -1], rgb[-1, 0], rgb[-1, -1],
                       rgb[5, 5], rgb[5, -6], rgb[-6, 5], rgb[-6, -6]])
    seed = np.median(corner, axis=0)
    seed_t = tuple(int(x) for x in seed)

    bg = edge_flood_bg_pil(rgb_im, seed_t, thresh=48)
    # Also mark remaining mint-like edge-adjacent... but flood should cover.
    # Extra: any mint pixel that is still "bg candidate" on borders already handled.
    # Clear residual mint fringe by OR-ing mint that is NOT deep inside character:
    # Safer: fg = ~bg, then later clear mint from crop.
    fg = ~bg

    cell_mask, bb, method = isolate_front_cell(fg)
    x0, y0, x1, y1 = bb
    pad = 2
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(w, x1 + pad), min(h, y1 + pad)

    crop_rgb = rgb[y0:y1, x0:x1].copy()
    crop_m = cell_mask[y0:y1, x0:x1]
    alpha = np.where(crop_m, 255, 0).astype(np.uint8)
    # Remove mint remnants inside crop (bg leftovers)
    mint_local = mint_mask(crop_rgb, seed, tol=42.0)
    alpha = np.where(mint_local, 0, alpha).astype(np.uint8)

    rgba = np.dstack([crop_rgb, alpha])
    tbb = content_bbox(alpha > 128)
    if tbb is None:
        raise RuntimeError(f"empty after mint clear: {path.name}")
    tx0, ty0, tx1, ty1 = tbb
    rgba = rgba[ty0:ty1, tx0:tx1]
    rgba = paint_enclosed_mint(rgba, seed, tol=38.0)
    tbb = content_bbox(rgba[..., 3] > 128)
    tx0, ty0, tx1, ty1 = tbb
    rgba = rgba[ty0:ty1, tx0:tx1]

    special = "proj_" in method and not method.endswith("2x2")
    # denser if more than 2 cols
    if "proj_" in method:
        parts = method.split("_")[1]  # e.g. 2x4
        try:
            rr, cc = parts.split("x")
            special = int(cc) > 2 or int(rr) > 2
        except Exception:
            pass

    meta = {
        "method": method,
        "front_bbox_sheet": [x0, y0, x1, y1],
        "front_size": [int(rgba.shape[1]), int(rgba.shape[0])],
        "special": special,
        "seed": seed.tolist(),
    }
    return Image.fromarray(rgba, "RGBA"), meta


def checker_bg(w: int, h: int, cell: int = 8) -> Image.Image:
    yy, xx = np.mgrid[0:h, 0:w]
    chk = ((xx // cell) + (yy // cell)) % 2
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    arr[chk == 0] = (40, 40, 44, 255)
    arr[chk == 1] = (55, 55, 60, 255)
    return Image.fromarray(arr, "RGBA")


def main():
    OUT_VARIANTS.mkdir(parents=True, exist_ok=True)
    OUT_PREVIEWS.mkdir(parents=True, exist_ok=True)

    fronts: list[Image.Image] = []
    metas = []
    heights = []

    print("=== Pass 1: extract fronts ===", flush=True)
    for i in range(20):
        path = SRC_DIR / f"sheet_{i:02d}.png"
        front, meta = extract_front_rgba(path)
        fronts.append(front)
        metas.append(meta)
        heights.append(front.height)
        # save raw front debug
        front.save(OUT_PREVIEWS / f"_raw_front_{i:02d}.png")
        print(
            f"  sheet_{i:02d}: size={front.size} method={meta['method']} special={meta['special']}",
            flush=True,
        )

    usable_h = CANVAS_H - FOOT_MARGIN - 2
    usable_w = CANVAS_W - 4
    median_h = float(np.median(heights))
    max_h = float(max(heights))
    max_w = float(max(im.width for im in fronts))
    scale = min(usable_h / max_h, usable_w / max_w)
    print(f"\nScale={scale:.6f} median_h={median_h} max_h={max_h} max_w={max_w}", flush=True)

    presets = []
    for i, front in enumerate(fronts):
        canvas = place_on_canvas(front, scale)
        out_path = OUT_VARIANTS / f"preset_{i:02d}.png"
        canvas.save(out_path)
        prev = nearest_scale(canvas, PREVIEW_SCALE)
        prev_bg = checker_bg(prev.width, prev.height, cell=12)
        prev_bg.paste(prev, (0, 0), prev)
        prev_bg.save(OUT_PREVIEWS / f"preset_{i:02d}.png")
        presets.append(canvas)
        arr = np.array(canvas)
        bb = content_bbox(arr[..., 3] > 128)
        print(f"  preset_{i:02d}: bbox={bb} feet_y={bb[3] if bb else None}", flush=True)

    p0 = OUT_VARIANTS / "preset_00.png"
    (OUT_VARIANTS / "default.png").write_bytes(p0.read_bytes())
    (STUDENT_ROOT / "base.png").write_bytes(p0.read_bytes())
    nearest_scale(Image.open(p0), PREVIEW_SCALE).save(STUDENT_ROOT / "base_preview.png")

    cols, rows = 5, 4
    pad = 8
    cell_w, cell_h = CANVAS_W + pad, CANVAS_H + pad + 18
    contact = checker_bg(cols * cell_w + pad, rows * cell_h + pad, cell=10)
    draw = ImageDraw.Draw(contact)
    for i, canvas in enumerate(presets):
        r, c = i // cols, i % cols
        x = pad + c * cell_w
        y = pad + r * cell_h
        contact.paste(canvas, (x, y), canvas)
        draw.text((x + 2, y + CANVAS_H + 2), f"{i:02d}", fill=(240, 240, 240, 255))
    contact_path = OUT_PREVIEWS / "presets_contact.png"
    contact.save(contact_path)
    print(f"\nContact → {contact_path}", flush=True)

    md = [
        "# Character presets (Runway Agent ×20)",
        "",
        "Canvas: **128×192** RGBA. Front view only. Shared NN scale + common foot baseline.",
        "",
        "| id | file | label (ES) | suggested traits |",
        "|----|------|------------|------------------|",
    ]
    for i in range(20):
        md.append(f"| {i:02d} | `variants/preset_{i:02d}.png` | {LABELS[i]} | {TRAITS[i]} |")
    md += [
        "",
        "## Notes",
        f"- Uniform scale factor: `{scale:.6f}`",
        f"- Foot margin from canvas bottom: `{FOOT_MARGIN}px`",
        f"- Contact sheet: `_previews/presets_contact.png`",
        f"- `default.png` and `base.png` ← `preset_00.png`",
        f"- Old base backed up as `base_old_camisa.png`",
        "",
        "## Per-sheet extraction",
    ]
    for i, m in enumerate(metas):
        md.append(
            f"- sheet_{i:02d}: method={m['method']}, front_size={m['front_size']}, special={m['special']}"
        )
    (STUDENT_ROOT / "PRESETS.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    (OUT_PREVIEWS / "_crop_meta.json").write_text(
        json.dumps({"scale": scale, "metas": metas, "heights": heights}, indent=2),
        encoding="utf-8",
    )
    print("Done.", flush=True)


if __name__ == "__main__":
    main()
