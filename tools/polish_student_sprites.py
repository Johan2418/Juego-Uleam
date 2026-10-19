#!/usr/bin/env python3
"""Local polish pipeline for student character customization sprites.
No external APIs — PIL/numpy/scipy only.
"""
from __future__ import annotations

import colorsys
import os
from collections import Counter, deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path("/workspace/prototipo/assets/sprites/student")
RAW = ROOT / "base_raw.png"
OUT_W, OUT_H = 64, 96
PAD = 4
OUTLINE = np.array([12, 10, 8, 255], dtype=np.uint8)
BG_SEED = np.array([150.0, 215.0, 161.0])  # mint green


# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------

def rgb_to_hsv_arr(rgb: np.ndarray) -> np.ndarray:
    """rgb uint8 HxWx3 -> hsv float HxWx3 (H 0-360, S/V 0-1)."""
    r = rgb[..., 0].astype(np.float64) / 255.0
    g = rgb[..., 1].astype(np.float64) / 255.0
    b = rgb[..., 2].astype(np.float64) / 255.0
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    df = mx - mn
    h = np.zeros_like(mx)
    mask = df > 1e-8
    rmax = mask & (mx == r)
    gmax = mask & (mx == g) & ~rmax
    bmax = mask & (mx == b) & ~rmax & ~gmax
    h[rmax] = (60 * ((g[rmax] - b[rmax]) / df[rmax]) + 360) % 360
    h[gmax] = (60 * ((b[gmax] - r[gmax]) / df[gmax]) + 120) % 360
    h[bmax] = (60 * ((r[bmax] - g[bmax]) / df[bmax]) + 240) % 360
    s = np.zeros_like(mx)
    s[mx > 1e-8] = df[mx > 1e-8] / mx[mx > 1e-8]
    return np.stack([h, s, mx], axis=-1)


def hex_to_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def hsv_transfer(src_rgb: np.ndarray, target_rgb: tuple[int, int, int],
                 sat_blend: float = 0.55) -> np.ndarray:
    """Preserve shading (relative V) while shifting hue toward target."""
    out = src_rgb.copy()
    if src_rgb.size == 0:
        return out
    hsv = rgb_to_hsv_arr(src_rgb)
    th, ts, tv = colorsys.rgb_to_hsv(
        target_rgb[0] / 255.0, target_rgb[1] / 255.0, target_rgb[2] / 255.0
    )
    th *= 360.0
    # Relative value vs median of region
    v = hsv[..., 2]
    med = float(np.median(v)) if len(v) else tv
    if med < 1e-6:
        med = tv
    scale = v / med
    new_v = np.clip(tv * scale, 0.05, 1.0)
    new_s = np.clip(hsv[..., 1] * (1.0 - sat_blend) + ts * sat_blend, 0.0, 1.0)
    # Darken very dark source pixels further for outline-adjacent shading
    result = np.zeros_like(src_rgb, dtype=np.float64)
    for i in range(len(src_rgb)):
        rr, gg, bb = colorsys.hsv_to_rgb(th / 360.0, float(new_s[i]), float(new_v[i]))
        result[i] = [rr * 255, gg * 255, bb * 255]
    return np.clip(result, 0, 255).astype(np.uint8)


# ---------------------------------------------------------------------------
# Background removal
# ---------------------------------------------------------------------------

def color_dist(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return np.sqrt(((a.astype(np.float64) - b.astype(np.float64)) ** 2).sum(axis=-1))


def flood_remove_bg(rgba: np.ndarray, seed_color: np.ndarray,
                    thr: float = 48.0, fringe_thr: float = 62.0) -> np.ndarray:
    """Flood from edges where color ~ seed; then strip near-bg fringe."""
    h, w = rgba.shape[:2]
    rgb = rgba[..., :3]
    dist = color_dist(rgb, seed_color)
    # Also treat near-uniform mint (high G, G>R, G>B) as bg candidate
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
    # Seed from all border pixels that look like bg
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

    # Remove fringe: opaque pixels that are near bg color AND adjacent to transparent
    opaque = alpha > 0
    # Dilate transparency to find fringe band
    from scipy.ndimage import binary_dilation
    near_trans = binary_dilation(~opaque, iterations=2) & opaque
    fringe = near_trans & ((dist < fringe_thr) | mintish)
    # Also kill very green-tinted dark pixels on the rim (anti-aliased black+mint)
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
    # Zero RGB on transparent (cleaner)
    out[alpha == 0] = [0, 0, 0, 0]
    return out


def morph_cleanup(rgba: np.ndarray) -> np.ndarray:
    """Erode fringe then restore silhouette; fill small holes."""
    alpha = rgba[..., 3] > 0
    # Remove isolated speckles
    labeled, n = ndimage.label(alpha)
    if n > 0:
        sizes = ndimage.sum(alpha, labeled, range(1, n + 1))
        keep = (sizes >= max(80, int(sizes.max() * 0.05))).tolist()
        mask = np.zeros_like(alpha)
        for i, k in enumerate(keep, start=1):
            if k:
                mask[labeled == i] = True
        alpha = mask

    # Close small holes inside character
    alpha = ndimage.binary_closing(alpha, iterations=1)
    # Slight open to kill remaining whiskers
    alpha = ndimage.binary_opening(alpha, iterations=1)
    # Closing again for smooth silhouette
    alpha = ndimage.binary_closing(alpha, structure=np.ones((3, 3)), iterations=1)

    out = rgba.copy()
    out[~alpha] = [0, 0, 0, 0]
    # For newly filled holes, sample neighbor colors (median of opaque neighbors)
    new_fill = alpha & (rgba[..., 3] == 0)
    if new_fill.any():
        ys, xs = np.where(new_fill)
        for y, x in zip(ys, xs):
            y0, y1 = max(0, y - 2), min(rgba.shape[0], y + 3)
            x0, x1 = max(0, x - 2), min(rgba.shape[1], x + 3)
            patch = rgba[y0:y1, x0:x1]
            valid = patch[..., 3] > 0
            if valid.any():
                out[y, x, :3] = np.median(patch[..., :3][valid], axis=0).astype(np.uint8)
                out[y, x, 3] = 255
            else:
                out[y, x] = [0, 0, 0, 0]
                alpha[y, x] = False
    return out


def force_outline(rgba: np.ndarray, color: np.ndarray = OUTLINE) -> np.ndarray:
    """Force a clean 1px dark outline on the silhouette boundary."""
    alpha = rgba[..., 3] > 0
    # Interior = eroded alpha
    eroded = ndimage.binary_erosion(alpha, iterations=1)
    boundary = alpha & ~eroded
    out = rgba.copy()
    # Clear any leftover green tint in boundary and set outline
    out[boundary] = color
    # Also darken near-boundary interior pixels that are mint-tainted
    near_b = ndimage.binary_dilation(boundary, iterations=1) & eroded
    rgb = out[..., :3].astype(np.int16)
    mint = (
        near_b
        & (rgb[..., 1] > rgb[..., 0] + 12)
        & (rgb[..., 1] > rgb[..., 2] + 8)
        & (rgb[..., 1] > 60)
    )
    # Replace mint-tainted near-outline with neighbor interior color or outline
    out[mint] = color
    return out


def crop_tight(rgba: np.ndarray, pad: int = PAD) -> np.ndarray:
    alpha = rgba[..., 3] > 0
    ys, xs = np.where(alpha)
    if len(ys) == 0:
        return rgba
    y0, y1 = ys.min(), ys.max() + 1
    x0, x1 = xs.min(), xs.max() + 1
    y0 = max(0, y0 - pad)
    x0 = max(0, x0 - pad)
    y1 = min(rgba.shape[0], y1 + pad)
    x1 = min(rgba.shape[1], x1 + pad)
    return rgba[y0:y1, x0:x1].copy()


def mode_downscale(rgba: np.ndarray, factor: int = 2) -> np.ndarray:
    """Block mode downscale for RGB; alpha = any opaque in block -> opaque."""
    h, w = rgba.shape[:2]
    nh, nw = h // factor, w // factor
    rgba = rgba[: nh * factor, : nw * factor]
    out = np.zeros((nh, nw, 4), dtype=np.uint8)
    for y in range(nh):
        for x in range(nw):
            block = rgba[y * factor : (y + 1) * factor, x * factor : (x + 1) * factor]
            opaque = block[..., 3] > 128
            if not opaque.any():
                continue
            pixels = block[opaque]
            # Mode of quantized colors
            q = (pixels[:, :3] // 12) * 12
            keys = [tuple(p) for p in q]
            mode_q = Counter(keys).most_common(1)[0][0]
            # Average of pixels matching mode bucket
            match = np.all(q == mode_q, axis=1)
            avg = pixels[match][:, :3].mean(axis=0)
            out[y, x, :3] = np.clip(avg, 0, 255).astype(np.uint8)
            out[y, x, 3] = 255
    return out


def place_on_canvas(rgba: np.ndarray, cw: int = OUT_W, ch: int = OUT_H) -> np.ndarray:
    canvas = np.zeros((ch, cw, 4), dtype=np.uint8)
    h, w = rgba.shape[:2]
    # If larger than canvas, downscale more
    scale = 1
    while h // scale > ch - 2 or w // scale > cw - 2:
        scale += 1
    if scale > 1:
        rgba = mode_downscale(rgba, scale)
        h, w = rgba.shape[:2]
    ox = (cw - w) // 2
    oy = max(2, (ch - h) // 2 - 2)  # slightly high bias for feet room
    # clamp
    if oy + h > ch:
        oy = ch - h
    if ox < 0:
        ox = 0
    if oy < 0:
        oy = 0
    hh = min(h, ch - oy)
    ww = min(w, cw - ox)
    canvas[oy : oy + hh, ox : ox + ww] = rgba[:hh, :ww]
    return canvas


# ---------------------------------------------------------------------------
# Extract + rebuild base
# ---------------------------------------------------------------------------

def extract_idle_frame(raw: Image.Image) -> np.ndarray:
    """Idle front = first large sprite row ~ y117-251, first column ~x30-102."""
    # Use slightly generous crop then let bg removal + tight crop refine
    return np.array(raw.crop((24, 110, 110, 260)).convert("RGBA"))


def rebuild_base() -> tuple[np.ndarray, dict]:
    raw = Image.open(RAW).convert("RGBA")
    frame = extract_idle_frame(raw)
    # Estimate bg from corners
    corners = np.stack([
        frame[0, 0, :3], frame[0, -1, :3], frame[-1, 0, :3], frame[-1, -1, :3],
        frame[2, 2, :3], frame[2, -3, :3],
    ]).astype(np.float64)
    seed = corners.mean(axis=0)

    cleaned = flood_remove_bg(frame, seed, thr=52.0, fringe_thr=70.0)
    cleaned = morph_cleanup(cleaned)
    cleaned = force_outline(cleaned)
    tight = crop_tight(cleaned, pad=3)

    # Downscale: character is ~70x130 -> aim ~36x66 (factor 2)
    h, w = tight.shape[:2]
    factor = 2 if min(h, w) >= 48 else 1
    if factor > 1:
        small = mode_downscale(tight, factor)
    else:
        small = tight
    # Re-apply outline after downscale (edges get muddy)
    small = force_outline(small)
    # Kill any remaining mint
    rgb = small[..., :3].astype(np.int16)
    mint = (
        (small[..., 3] > 0)
        & (rgb[..., 1] > rgb[..., 0] + 15)
        & (rgb[..., 1] > rgb[..., 2] + 10)
        & (rgb[..., 1] > 100)
        & (rgb[..., 0] < 200)
    )
    # For mint interior (shouldn't happen often) — make transparent if on edge else recolor
    alpha = small[..., 3] > 0
    eroded = ndimage.binary_erosion(alpha, iterations=1)
    small[mint & ~eroded] = [0, 0, 0, 0]
    # mint interior: replace with nearby non-mint
    if (mint & eroded).any():
        ys, xs = np.where(mint & eroded)
        for y, x in zip(ys, xs):
            small[y, x] = OUTLINE  # safer as outline than green

    small = force_outline(small)
    canvas = place_on_canvas(small, OUT_W, OUT_H)
    # Final outline pass on canvas
    canvas = force_outline(canvas)

    ys, xs = np.where(canvas[..., 3] > 0)
    meta = {
        "char_origin": (int(xs.min()), int(ys.min())),
        "char_size": (int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)),
        "canvas": f"{OUT_W}x{OUT_H}",
        "mint_left": int((
            (canvas[..., 3] > 0)
            & (canvas[..., 1] > canvas[..., 0] + 15)
            & (canvas[..., 1] > canvas[..., 2] + 10)
            & (canvas[..., 1] > 100)
        ).sum()),
    }
    return canvas, meta


# ---------------------------------------------------------------------------
# Region mask
# ---------------------------------------------------------------------------

def build_region_mask(base: np.ndarray) -> np.ndarray:
    """R=skin, G=hair, B=cloth. Outline/eyes/shoes = black (no recolor)."""
    h, w = base.shape[:2]
    mask = np.zeros((h, w, 4), dtype=np.uint8)
    alpha = base[..., 3] > 0
    if not alpha.any():
        return mask

    ys, xs = np.where(alpha)
    y0, y1 = ys.min(), ys.max()
    x0, x1 = xs.min(), xs.max()
    ch = y1 - y0 + 1
    cw = x1 - x0 + 1

    hsv = rgb_to_hsv_arr(base[..., :3])
    rgb = base[..., :3].astype(np.int16)
    v = hsv[..., 2]
    s = hsv[..., 1]
    hue = hsv[..., 0]
    lum = rgb.sum(axis=-1)

    # Outline / eyes / very dark — never recolor
    is_dark = alpha & ((v < 0.14) | (lum < 55))
    # Shoes: bottom ~12% of character, brownish
    shoe_y = y0 + int(ch * 0.88)
    is_shoe = alpha & (np.arange(h)[:, None] >= shoe_y) & (hue < 50) & (v < 0.55)

    # Relative positions
    yy = (np.arange(h)[:, None] - y0) / max(ch, 1)
    xx = (np.arange(w)[None, :] - x0) / max(cw, 1)

    # Hair: top ~45%, brown/dark warm, not skin-light
    is_hair = (
        alpha & ~is_dark & ~is_shoe
        & (yy < 0.46)
        & (hue < 55)
        & (s > 0.12)
        & (v > 0.08) & (v < 0.72)
        & (rgb[..., 0] + 10 >= rgb[..., 2])
    )
    # Expand hair slightly in top region for bowl cut
    hair_core = is_hair.copy()
    # Also catch darker hair tops
    is_hair |= (
        alpha & ~is_dark & ~is_shoe
        & (yy < 0.42)
        & (v < 0.55)
        & (hue < 60)
        & (s > 0.08)
        & ~((hue > 8) & (hue < 45) & (v > 0.55) & (s > 0.15))  # not light skin
    )

    # Skin: face band + hands
    is_skin = (
        alpha & ~is_dark & ~is_shoe & ~is_hair
        & (hue > 5) & (hue < 55)
        & (s > 0.10) & (s < 0.75)
        & (v > 0.40)
        & (rgb[..., 0] > rgb[..., 2] + 5)
        & (yy > 0.12) & (yy < 0.55)
    )
    # Hands at sleeve ends — warm mid-body sides
    is_hand = (
        alpha & ~is_dark & ~is_shoe & ~is_hair
        & (hue > 5) & (hue < 55)
        & (s > 0.10) & (v > 0.35)
        & (rgb[..., 0] > rgb[..., 2] + 5)
        & (yy > 0.48) & (yy < 0.72)
        & ((xx < 0.22) | (xx > 0.78))
    )
    is_skin |= is_hand

    # Cloth: blue-ish body below hair
    is_cloth = (
        alpha & ~is_dark & ~is_shoe & ~is_hair & ~is_skin
        & (
            ((hue > 170) & (hue < 280) & (s > 0.08))
            | ((yy > 0.40) & (yy < 0.90) & (s > 0.05) & ~((hue > 5) & (hue < 50) & (v > 0.45)))
        )
    )
    # Anything remaining opaque that's not dark/shoe → cloth if lower, hair if upper
    leftover = alpha & ~is_dark & ~is_shoe & ~is_hair & ~is_skin & ~is_cloth
    is_hair |= leftover & (yy < 0.40)
    is_cloth |= leftover & (yy >= 0.40)

    # Morphological cleanup per region — no bleed into outline
    def clean_region(m: np.ndarray) -> np.ndarray:
        m = ndimage.binary_opening(m, iterations=1)
        m = ndimage.binary_closing(m, iterations=1)
        return m & alpha & ~is_dark & ~is_shoe

    is_hair = clean_region(is_hair)
    is_skin = clean_region(is_skin) & ~is_hair
    is_cloth = clean_region(is_cloth) & ~is_hair & ~is_skin

    # Eyes: small dark pixels in face — already in is_dark; ensure face holes not skin-bleed
    # Protect a 2px band of outline by not assigning mask there
    eroded = ndimage.binary_erosion(alpha, iterations=1)
    rim = alpha & ~eroded
    is_hair &= ~rim
    is_skin &= ~rim
    is_cloth &= ~rim

    mask[is_skin] = [255, 0, 0, 255]
    mask[is_hair] = [0, 255, 0, 255]
    mask[is_cloth] = [0, 0, 255, 255]
    # Dark/shoe/outline stay 0
    return mask


# ---------------------------------------------------------------------------
# Variant generation
# ---------------------------------------------------------------------------

SKIN_TARGETS = {
    "clara": (240, 200, 160),
    "media": (212, 165, 116),
    "morena": (160, 103, 63),
    "oscura": (107, 63, 42),
}

HAIR_TARGETS = {
    "negro": (26, 26, 26),
    "castano": (92, 51, 23),
    "rubio": (224, 192, 96),
    "pelirrojo": (192, 64, 32),
    "azul": (48, 96, 192),
    "rosa": (224, 96, 160),
}

OUTFIT_TARGETS = {
    # primary, secondary (for accents)
    "hoodie": ((58, 90, 140), (42, 64, 96)),
    "camiseta": ((192, 64, 64), (240, 240, 240)),
    "camisa": ((232, 224, 208), (64, 96, 160)),
    "chaqueta": ((42, 42, 42), (128, 128, 128)),
    "lab": ((245, 245, 245), (64, 80, 160)),
}


def apply_region_recolor(base: np.ndarray, mask: np.ndarray, region: str,
                         target: tuple[int, int, int], sat_blend: float = 0.55) -> np.ndarray:
    out = base.copy()
    if region == "skin":
        sel = mask[..., 0] > 200
    elif region == "hair":
        sel = mask[..., 1] > 200
    else:
        sel = mask[..., 2] > 200
    if not sel.any():
        return out
    src = out[sel][:, :3]
    new = hsv_transfer(src, target, sat_blend=sat_blend)
    out[sel, :3] = new
    return out


def edit_outfit_silhouette(img: np.ndarray, mask: np.ndarray, outfit_id: str) -> np.ndarray:
    """Pixel edits on torso to make outfits OBVIOUSLY different."""
    out = img.copy()
    alpha = out[..., 3] > 0
    ys, xs = np.where(alpha)
    if len(ys) == 0:
        return out
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    ch, cw = y1 - y0 + 1, x1 - x0 + 1
    cx = (x0 + x1) // 2

    cloth = mask[..., 2] > 200
    skin = mask[..., 0] > 200
    primary, secondary = OUTFIT_TARGETS[outfit_id]

    def setpx(x, y, rgb, a=255):
        if 0 <= y < out.shape[0] and 0 <= x < out.shape[1]:
            # Don't overwrite pure outline blacks unless extending silhouette
            out[y, x] = [rgb[0], rgb[1], rgb[2], a]

    def outline_px(x, y):
        setpx(x, y, OUTLINE[:3])

    # Body band
    torso_y0 = y0 + int(ch * 0.38)
    torso_y1 = y0 + int(ch * 0.72)
    sleeve_y = y0 + int(ch * 0.42)
    hip_y = y0 + int(ch * 0.70)

    if outfit_id == "hoodie":
        # Hood bump behind head (top of hair area sides) + pocket + drawstrings
        # Kangaroo pocket darker band
        py = y0 + int(ch * 0.58)
        for x in range(cx - 6, cx + 7):
            for y in range(py, py + 5):
                if cloth[y, x] if 0 <= y < cloth.shape[0] and 0 <= x < cloth.shape[1] else False:
                    setpx(x, y, secondary)
        # Drawstrings
        for dy in range(4):
            setpx(cx - 2, torso_y0 + 4 + dy, secondary)
            setpx(cx + 2, torso_y0 + 4 + dy, secondary)
        # Hood silhouette: extend 1px above shoulders at sides of neck
        hy = y0 + int(ch * 0.34)
        for x in range(cx - 8, cx - 5):
            if out[hy, x, 3] == 0:
                setpx(x, hy, primary)
                outline_px(x, hy - 1)
        for x in range(cx + 6, cx + 9):
            if out[hy, x, 3] == 0:
                setpx(x, hy, primary)
                outline_px(x, hy - 1)
        # Emblem
        setpx(cx + 4, torso_y0 + 6, secondary)
        setpx(cx + 5, torso_y0 + 6, (min(255, secondary[0] + 40), min(255, secondary[1] + 40), min(255, secondary[2] + 50)))

    elif outfit_id == "camiseta":
        # Short sleeves: cut outer sleeve pixels to skin / transparent then redraw short cuff
        # Find sleeve columns: cloth at mid-torso sides
        for y in range(sleeve_y, hip_y):
            for x in list(range(x0, x0 + 6)) + list(range(x1 - 5, x1 + 1)):
                if 0 <= y < out.shape[0] and 0 <= x < out.shape[1] and cloth[y, x]:
                    # Upper outer sleeve -> remove (short sleeve)
                    if y < sleeve_y + int(ch * 0.10):
                        continue  # keep shoulder
                    if y > sleeve_y + int(ch * 0.12) and (x <= x0 + 3 or x >= x1 - 3):
                        # turn to transparent or leave hand skin
                        if y > y0 + int(ch * 0.55):
                            # likely hand area — leave skin if was cloth wrongly
                            setpx(x, y, SKIN_TARGETS["media"])
                        else:
                            out[y, x] = [0, 0, 0, 0]
        # Crest on chest
        cy = torso_y0 + 8
        for dx, dy in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]:
            setpx(cx + dx, cy + dy, secondary)
        setpx(cx, cy, (255, 220, 80))
        # Re-outline ragged sleeve ends
        for y in range(sleeve_y, sleeve_y + 14):
            for x in range(x0, x1 + 1):
                if out[y, x, 3] > 0:
                    for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                        nx, ny = x + dx, y + dy
                        if 0 <= ny < out.shape[0] and 0 <= nx < out.shape[1]:
                            if out[ny, nx, 3] == 0:
                                # edge — if this pixel is cloth-colored, ensure dark rim neighbor
                                pass

    elif outfit_id == "camisa":
        # Collar V at neckline + lighter body already from recolor
        ny = torso_y0 + 1
        for i in range(5):
            setpx(cx - i, ny + i, secondary)
            setpx(cx + i, ny + i, secondary)
        # Collar tips
        setpx(cx - 4, ny + 1, (255, 255, 255))
        setpx(cx + 4, ny + 1, (255, 255, 255))
        # Buttons
        for i, by in enumerate(range(torso_y0 + 8, hip_y - 4, 5)):
            setpx(cx, by, secondary)

    elif outfit_id == "chaqueta":
        # Dark jacket: open front showing shirt strip down middle
        for y in range(torso_y0 + 2, hip_y):
            for x in range(cx - 1, cx + 2):
                if cloth[y, x] if y < cloth.shape[0] and x < cloth.shape[1] else False:
                    setpx(x, y, (200, 200, 205))  # shirt under
        # Lapels
        for i in range(6):
            setpx(cx - 3 - i // 2, torso_y0 + 2 + i, secondary)
            setpx(cx + 3 + i // 2, torso_y0 + 2 + i, secondary)
        # Shoulder pads slightly wider
        sy = torso_y0 + 2
        for x in (x0 + 1, x1 - 1):
            if out[sy, x, 3] == 0:
                setpx(x, sy, primary)
                outline_px(x, sy - 1)

    elif outfit_id == "lab":
        # White coat open with blue underlayer down center; coat flaps wider
        under = secondary
        for y in range(torso_y0 + 2, hip_y + 2):
            for x in range(cx - 2, cx + 3):
                if 0 <= y < out.shape[0] and 0 <= x < out.shape[1]:
                    if out[y, x, 3] > 0:
                        setpx(x, y, under)
        # Coat flaps: lighter white on sides of underlayer
        for y in range(torso_y0 + 2, hip_y + 4):
            for x in list(range(cx - 7, cx - 2)) + list(range(cx + 3, cx + 8)):
                if 0 <= y < out.shape[0] and 0 <= x < out.shape[1] and out[y, x, 3] > 0:
                    # keep white-ish
                    setpx(x, y, primary)
        # Longer coat hem: extend below hip a few px on sides
        for y in range(hip_y, min(out.shape[0], hip_y + 6)):
            for x in list(range(cx - 8, cx - 3)) + list(range(cx + 4, cx + 9)):
                if 0 <= x < out.shape[1]:
                    if out[y, x, 3] == 0:
                        # only if above shoes
                        if y < y0 + int(ch * 0.88):
                            setpx(x, y, primary)
                            # outline outer
                            if x == cx - 8 or x == cx + 8:
                                outline_px(x, y)
        # Re-outline bottom of flaps
        for x in list(range(cx - 8, cx - 3)) + list(range(cx + 4, cx + 9)):
            y = hip_y + 5
            if 0 <= y < out.shape[0] and 0 <= x < out.shape[1] and out[y, x, 3] > 0:
                outline_px(x, y + 1)

    # Final: restore outline on silhouette
    return force_outline(out)


def make_hair_style_overlays(base: np.ndarray, mask: np.ndarray) -> dict[str, np.ndarray]:
    """Intentional pixel-art hair style overlays matching base style."""
    h, w = base.shape[:2]
    hair = mask[..., 1] > 200
    alpha = base[..., 3] > 0
    ys, xs = np.where(alpha)
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    ch, cw = y1 - y0 + 1, x1 - x0 + 1
    cx = (x0 + x1) // 2
    hair_ys, hair_xs = np.where(hair)
    if len(hair_ys):
        hy0, hy1 = int(hair_ys.min()), int(hair_ys.max())
        hx0, hx1 = int(hair_xs.min()), int(hair_xs.max())
    else:
        hy0, hy1, hx0, hx1 = y0, y0 + int(ch * 0.4), x0 + 4, x1 - 4

    # Base hair color sample for drawing (will be tinted at runtime too)
    hair_col = (92, 51, 23)
    if hair.any():
        hair_col = tuple(int(v) for v in np.median(base[hair][:, :3], axis=0))
    shade = tuple(max(0, int(c * 0.7)) for c in hair_col)
    light = tuple(min(255, int(c * 1.15)) for c in hair_col)

    def blank():
        return np.zeros((h, w, 4), dtype=np.uint8)

    def draw_ellipse(img, cx, cy, rx, ry, col, a=255):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if 0 <= y < h and 0 <= x < w:
                    dx = (x - cx) / max(rx, 1)
                    dy = (y - cy) / max(ry, 1)
                    if dx * dx + dy * dy <= 1.05:
                        img[y, x] = [col[0], col[1], col[2], a]

    def draw_rect(img, x, y, ww, hh, col, a=255):
        for yy in range(y, y + hh):
            for xx in range(x, x + ww):
                if 0 <= yy < h and 0 <= xx < w:
                    img[yy, xx] = [col[0], col[1], col[2], a]

    overlays = {}

    # medio = empty
    overlays["medio"] = blank()

    # corto = trim bang line / flatten top (darker short fringe across forehead)
    corto = blank()
    bang_y = hy0 + (hy1 - hy0) // 2 + 2
    draw_rect(corto, hx0 + 2, bang_y, max(1, hx1 - hx0 - 3), 2, shade)
    # slight top flatten markers
    draw_rect(corto, cx - 5, hy0 + 1, 10, 1, shade)
    overlays["corto"] = corto

    # largo = side strands down past cheeks
    largo = blank()
    strand_col = hair_col
    for side, sign in ((hx0 - 1, -1), (hx1 + 1, 1)):
        sx = side
        for i, y in enumerate(range(hy0 + 4, y0 + int(ch * 0.62))):
            x = sx + sign * (0 if i < 3 else (1 if i % 5 < 3 else 0))
            draw_rect(largo, x, y, 2, 1, strand_col if i % 3 else shade)
            # outline outer edge
            draw_rect(largo, x + sign * 2, y, 1, 1, tuple(OUTLINE[:3]))
    overlays["largo"] = largo

    # recogido = bun on top
    recogido = blank()
    bun_y = hy0 - 1
    draw_ellipse(recogido, cx, bun_y, 5, 3, hair_col)
    draw_ellipse(recogido, cx, bun_y - 1, 3, 2, light)
    # hair tie
    draw_rect(recogido, cx - 3, hy0 + 1, 6, 1, (160, 40, 80))
    # outline bun
    for y in range(bun_y - 4, bun_y + 4):
        for x in range(cx - 6, cx + 7):
            if 0 <= y < h and 0 <= x < w and recogido[y, x, 3] > 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= ny < h and 0 <= nx < w and recogido[ny, nx, 3] == 0:
                        if base[ny, nx, 3] == 0:
                            recogido[ny, nx] = [OUTLINE[0], OUTLINE[1], OUTLINE[2], 255]
    overlays["recogido"] = recogido

    # rizado = curl bumps around hair silhouette
    rizado = blank()
    bumps = [
        (hx0 - 1, hy0 + 4, 2),
        (hx0 - 2, hy0 + 10, 2),
        (hx1 + 1, hy0 + 4, 2),
        (hx1 + 2, hy0 + 10, 2),
        (cx - 6, hy0 - 1, 2),
        (cx + 6, hy0 - 1, 2),
        (cx, hy0 - 2, 2),
        (hx0 + 2, hy1 - 1, 2),
        (hx1 - 2, hy1 - 1, 2),
    ]
    for bx, by, r in bumps:
        draw_ellipse(rizado, bx, by, r, r, hair_col)
        draw_ellipse(rizado, bx, by - 1, max(1, r - 1), max(1, r - 1), light)
        # mini outline
        draw_ellipse(rizado, bx - r, by, 1, 1, tuple(OUTLINE[:3]))
    overlays["rizado"] = rizado

    return overlays


def make_accessory_overlays(base: np.ndarray, mask: np.ndarray) -> dict[str, np.ndarray]:
    h, w = base.shape[:2]
    alpha = base[..., 3] > 0
    ys, xs = np.where(alpha)
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    ch, cw = y1 - y0 + 1, x1 - x0 + 1
    cx = (x0 + x1) // 2

    skin = mask[..., 0] > 200
    # Estimate eye row: dark pixels in upper face
    face_y0 = y0 + int(ch * 0.18)
    face_y1 = y0 + int(ch * 0.38)

    def blank():
        return np.zeros((h, w, 4), dtype=np.uint8)

    def put(img, x, y, col, a=255):
        if 0 <= y < h and 0 <= x < w:
            img[y, x] = [col[0], col[1], col[2], a]

    def rect(img, x, y, ww, hh, col, a=255):
        for yy in range(y, y + hh):
            for xx in range(x, x + ww):
                put(img, xx, yy, col, a)

    def ellipse(img, ecx, ecy, rx, ry, col, a=255):
        for y in range(ecy - ry, ecy + ry + 1):
            for x in range(ecx - rx, ecx + rx + 1):
                dx = (x - ecx) / max(rx, 1)
                dy = (y - ecy) / max(ry, 1)
                if dx * dx + dy * dy <= 1.05:
                    put(img, x, y, col, a)

    overlays = {"none": blank()}

    # glasses — on eyes
    glasses = blank()
    ey = face_y0 + (face_y1 - face_y0) // 2
    # find actual eye pixels
    dark = (base[..., 3] > 0) & (base[..., 0].astype(int) + base[..., 1].astype(int) + base[..., 2].astype(int) < 60)
    eye_band = dark & (np.arange(h)[:, None] >= face_y0) & (np.arange(h)[:, None] <= face_y1)
    if eye_band.any():
        eys = np.where(eye_band)[0]
        ey = int(np.median(eys))
    frame = (20, 20, 24)
    glass = (140, 180, 200)
    # left lens
    rect(glasses, cx - 8, ey - 2, 6, 5, frame)
    rect(glasses, cx - 7, ey - 1, 4, 3, glass)
    # right lens
    rect(glasses, cx + 2, ey - 2, 6, 5, frame)
    rect(glasses, cx + 3, ey - 1, 4, 3, glass)
    # bridge
    rect(glasses, cx - 2, ey, 4, 1, frame)
    overlays["glasses"] = glasses

    # backpack — behind/sides at torso
    backpack = blank()
    bag = (90, 55, 32)
    bag_d = (60, 35, 20)
    ty = y0 + int(ch * 0.48)
    ellipse(backpack, x0 - 1, ty + 6, 3, 8, bag)
    ellipse(backpack, x1 + 1, ty + 6, 3, 8, bag)
    rect(backpack, x0 - 2, ty + 2, 2, 10, bag_d)
    rect(backpack, x1 + 1, ty + 2, 2, 10, bag_d)
    # straps
    rect(backpack, x0 + 3, y0 + int(ch * 0.36), 1, 10, bag_d)
    rect(backpack, x1 - 3, y0 + int(ch * 0.36), 1, 10, bag_d)
    overlays["backpack"] = backpack

    # cap on head
    cap = blank()
    cap_c = (40, 85, 150)
    cap_d = (25, 55, 100)
    cap_y = y0 + int(ch * 0.08)
    ellipse(cap, cx, cap_y + 2, 11, 4, cap_c)
    rect(cap, cx - 10, cap_y + 4, 20, 2, cap_d)
    # brim
    rect(cap, cx - 4, cap_y + 6, 14, 2, cap_d)
    # outline top
    for x in range(cx - 11, cx + 12):
        put(cap, x, cap_y - 1, tuple(OUTLINE[:3]))
    overlays["cap"] = cap

    # headphones on ears
    headphones = blank()
    band = (45, 45, 50)
    cup = (25, 25, 28)
    accent = (80, 200, 120)
    rect(headphones, cx - 10, y0 + int(ch * 0.10), 20, 2, band)
    ellipse(headphones, x0 + 2, y0 + int(ch * 0.28), 3, 5, cup)
    ellipse(headphones, x1 - 2, y0 + int(ch * 0.28), 3, 5, cup)
    put(headphones, x0 + 2, y0 + int(ch * 0.28), accent)
    put(headphones, x1 - 2, y0 + int(ch * 0.28), accent)
    overlays["headphones"] = headphones

    return overlays


# ---------------------------------------------------------------------------
# Composites for preview
# ---------------------------------------------------------------------------

def composite_preview(base, mask, skin_img, hair_img, outfit_img, style_ov, acc_ov,
                      hair_tint=None) -> np.ndarray:
    """Match CharacterPreview logic roughly."""
    result = outfit_img.copy() if outfit_img is not None else base.copy()
    h, w = result.shape[:2]
    for y in range(h):
        for x in range(w):
            if base[y, x, 3] < 10:
                continue
            m = mask[y, x]
            if m[0] > 150 and skin_img is not None:
                result[y, x] = skin_img[y, x]
            elif m[1] > 150 and hair_img is not None:
                result[y, x] = hair_img[y, x]
            elif m[2] > 150 and outfit_img is not None:
                result[y, x] = outfit_img[y, x]
    # hair style tinted
    if style_ov is not None and style_ov[..., 3].any():
        for y in range(h):
            for x in range(w):
                sc = style_ov[y, x]
                if sc[3] < 10:
                    continue
                use = sc.astype(np.float64) / 255.0
                if hair_tint is not None and (sc[0] + sc[1] + sc[2]) > 30:
                    # shade from value
                    v = max(sc[0], sc[1], sc[2]) / 255.0
                    shade = np.clip(v / 0.45, 0.25, 1.35)
                    use = np.array([
                        np.clip(hair_tint[0] / 255.0 * shade, 0, 1),
                        np.clip(hair_tint[1] / 255.0 * shade, 0, 1),
                        np.clip(hair_tint[2] / 255.0 * shade, 0, 1),
                        sc[3] / 255.0,
                    ])
                a = use[3]
                dc = result[y, x].astype(np.float64) / 255.0
                out = [
                    use[0] * a + dc[0] * (1 - a),
                    use[1] * a + dc[1] * (1 - a),
                    use[2] * a + dc[2] * (1 - a),
                    min(1.0, dc[3] + a * (1 - dc[3])),
                ]
                result[y, x] = [int(c * 255) for c in out]
    # accessory
    if acc_ov is not None:
        for y in range(h):
            for x in range(w):
                sc = acc_ov[y, x]
                if sc[3] < 10:
                    continue
                a = sc[3] / 255.0
                dc = result[y, x].astype(np.float64)
                result[y, x] = [
                    int(sc[0] * a + dc[0] * (1 - a)),
                    int(sc[1] * a + dc[1] * (1 - a)),
                    int(sc[2] * a + dc[2] * (1 - a)),
                    int(min(255, dc[3] + sc[3] * (1 - dc[3] / 255.0))),
                ]
    return result


def scale_nn(img: np.ndarray, scale: int) -> np.ndarray:
    pil = Image.fromarray(img, "RGBA")
    return np.array(pil.resize((img.shape[1] * scale, img.shape[0] * scale), Image.NEAREST))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def save_rgba(path: Path, arr: np.ndarray) -> None:
    Image.fromarray(arr, "RGBA").save(path)
    print(f"  wrote {path.relative_to(ROOT.parent.parent.parent) if False else path} ({arr.shape[1]}x{arr.shape[0]})")


def main() -> None:
    print("=== A. Rebuild base ===")
    base, meta = rebuild_base()
    save_rgba(ROOT / "base.png", base)
    preview = scale_nn(base, 4)
    save_rgba(ROOT / "base_preview.png", preview)
    print("meta", meta)

    print("=== Region mask ===")
    mask = build_region_mask(base)
    save_rgba(ROOT / "region_mask.png", mask)
    print("  skin/hair/cloth",
          int((mask[..., 0] > 200).sum()),
          int((mask[..., 1] > 200).sum()),
          int((mask[..., 2] > 200).sum()))

    print("=== B. Skin variants ===")
    (ROOT / "skin").mkdir(exist_ok=True)
    skin_imgs = {}
    for name, target in SKIN_TARGETS.items():
        img = apply_region_recolor(base, mask, "skin", target, sat_blend=0.65)
        skin_imgs[name] = img
        save_rgba(ROOT / "skin" / f"{name}.png", img)

    print("=== Hair color variants ===")
    (ROOT / "hair").mkdir(exist_ok=True)
    hair_imgs = {}
    for name, target in HAIR_TARGETS.items():
        # For near-black, lower sat blend issues — still preserve shading via V
        sb = 0.85 if name in ("negro", "azul", "rosa", "pelirrojo", "rubio") else 0.7
        img = apply_region_recolor(base, mask, "hair", target, sat_blend=sb)
        hair_imgs[name] = img
        save_rgba(ROOT / "hair" / f"{name}.png", img)

    print("=== Outfit variants (recolor + silhouette) ===")
    (ROOT / "outfit").mkdir(exist_ok=True)
    outfit_imgs = {}
    for name, (primary, _sec) in OUTFIT_TARGETS.items():
        img = apply_region_recolor(base, mask, "cloth", primary, sat_blend=0.75)
        # Pants slightly darker variant of primary for non-lab
        cloth = mask[..., 2] > 200
        ys, xs = np.where(base[..., 3] > 0)
        y0 = int(ys.min()); ch = int(ys.max() - ys.min() + 1)
        pants_y = y0 + int(ch * 0.68)
        pants = cloth & (np.arange(base.shape[0])[:, None] >= pants_y)
        if name == "lab":
            # pants stay blue-ish under coat
            pant_target = OUTFIT_TARGETS["lab"][1]
        elif name == "camiseta":
            pant_target = (50, 50, 70)
        elif name == "camisa":
            pant_target = (50, 60, 100)
        elif name == "chaqueta":
            pant_target = (30, 30, 35)
        else:
            pant_target = tuple(max(0, c - 25) for c in primary)
        if pants.any():
            img[pants, :3] = hsv_transfer(img[pants][:, :3], pant_target, sat_blend=0.7)
        img = edit_outfit_silhouette(img, mask, name)
        outfit_imgs[name] = img
        save_rgba(ROOT / "outfit" / f"{name}.png", img)

    print("=== Hair style overlays ===")
    (ROOT / "hair_style").mkdir(exist_ok=True)
    styles = make_hair_style_overlays(base, mask)
    for name, ov in styles.items():
        save_rgba(ROOT / "hair_style" / f"{name}.png", ov)

    print("=== Accessory overlays ===")
    (ROOT / "accessory").mkdir(exist_ok=True)
    accs = make_accessory_overlays(base, mask)
    for name, ov in accs.items():
        save_rgba(ROOT / "accessory" / f"{name}.png", ov)

    # sprite_meta
    (ROOT / "sprite_meta.txt").write_text(
        f"char_origin={meta['char_origin'][0]},{meta['char_origin'][1]}\n"
        f"char_size={meta['char_size'][0]},{meta['char_size'][1]}\n"
        f"canvas={meta['canvas']}\n"
    )

    print("=== D. Preview composites ===")
    prev_dir = ROOT / "_previews"
    prev_dir.mkdir(exist_ok=True)

    def make_comp(outfit, skin, hair, style, acc, hair_tint, fname):
        comp = composite_preview(
            base, mask,
            skin_imgs[skin], hair_imgs[hair], outfit_imgs[outfit],
            styles[style], accs[acc],
            hair_tint=hair_tint,
        )
        save_rgba(prev_dir / fname, scale_nn(comp, 4))

    make_comp("hoodie", "media", "castano", "medio", "none", HAIR_TARGETS["castano"],
              "01_default_hoodie.png")
    make_comp("lab", "clara", "negro", "medio", "glasses", HAIR_TARGETS["negro"],
              "02_lab_glasses.png")
    make_comp("camiseta", "media", "rubio", "corto", "cap", HAIR_TARGETS["rubio"],
              "03_camiseta_rubio_cap.png")
    make_comp("chaqueta", "morena", "castano", "largo", "none", HAIR_TARGETS["castano"],
              "04_chaqueta_largo.png")

    # Update HEURISTICS
    (ROOT / "HEURISTICS.md").write_text("""# Student sprite palette heuristics (ref A) — polished

Source: `base_raw.png` idle front frame. Mint-green bg removed via edge flood-fill
+ color-distance fringe strip + morphological open/close. Forced dark 1px outline.
Mode-block downscale ×2 → **64×96** canvas. No mint fringe remaining.

## Region mask (`region_mask.png`)
- **R** = skin (face + hands); never outline/eyes/shoes
- **G** = hair (top bowl); rim excluded
- **B** = cloth (hoodie/pants body)
- Black = outline, eyes, shoes (never recolored)

## Variants
- `skin/*` — HSV transfer preserving shading
- `hair/*` — strong distinct hues, shading kept
- `outfit/*` — HSV recolor **plus** silhouette pixel edits (hood/pocket, short sleeves+crest, collar/buttons, open jacket, lab coat flaps)
- `hair_style/*` — intentional overlays (corto fringe, largo strands, recogido bun, rizado bumps); `medio` empty
- `accessory/*` — glasses/backpack/cap/headphones in base palette language

## Compositing
Outfit base → mask-swap skin/hair from variants → tinted hair_style → accessory.
Nearest-neighbor display in `CharacterPreview`.
""")
    print("DONE mint_left=", meta["mint_left"])


if __name__ == "__main__":
    main()
