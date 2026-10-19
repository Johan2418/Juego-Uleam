#!/usr/bin/env python3
"""Hand-authored procedural pixel student (32x32) — Zelda / Minish Cap chibi.
Mirrors CharacterPreview GDScript. DISPLAY_SCALE 7 → 224px.
"""
from __future__ import annotations
from PIL import Image
import os

W, H = 32, 32
DISPLAY_SCALE = 7

SKIN = {
    "clara":  ((0xF2, 0xD0, 0xA8), (0xE0, 0xB4, 0x88), (0xC4, 0x8C, 0x64)),
    "media":  ((0xE0, 0xB0, 0x78), (0xC8, 0x94, 0x5C), (0xA0, 0x70, 0x44)),
    "morena": ((0xB0, 0x78, 0x48), (0x8C, 0x58, 0x34), (0x68, 0x3C, 0x22)),
    "oscura": ((0x78, 0x4C, 0x30), (0x58, 0x34, 0x20), (0x3C, 0x22, 0x14)),
}
HAIR = {
    "negro":     ((0x3A, 0x3A, 0x3E), (0x1E, 0x1E, 0x22), (0x5A, 0x5A, 0x62)),
    "castano":   ((0x8B, 0x52, 0x2A), (0x5C, 0x32, 0x14), (0xB4, 0x78, 0x40)),
    "rubio":     ((0xF0, 0xD4, 0x68), (0xC8, 0xA0, 0x30), (0xFC, 0xEC, 0xA0)),
    "pelirrojo": ((0xE0, 0x58, 0x28), (0xA8, 0x30, 0x14), (0xF0, 0x88, 0x50)),
    "azul":      ((0x48, 0x78, 0xE0), (0x28, 0x48, 0xA8), (0x80, 0xA8, 0xF0)),
    "rosa":      ((0xF0, 0x78, 0xB8), (0xC0, 0x40, 0x88), (0xFC, 0xB0, 0xD4)),
}
OUTLINE = (0x14, 0x10, 0x0E, 255)
SHADOW = (0x18, 0x12, 0x10, 100)
WHITE = (0xFF, 0xFF, 0xFF, 255)
PUPIL = (0x10, 0x0C, 0x0C, 255)
MOUTH = (0x7A, 0x3C, 0x2C, 255)
SHOE = ((0x62, 0x3C, 0x22), (0x42, 0x26, 0x14))
PANTS = ((0x3C, 0x4C, 0x70), (0x2A, 0x36, 0x50))

OUTFIT_PAL = {
    "hoodie": {
        "pri": (0x4A, 0x6E, 0xA4), "shade": (0x30, 0x48, 0x72), "light": (0x6C, 0x8E, 0xC0),
        "sec": (0x28, 0x3C, 0x58), "accent": (0xF0, 0xF0, 0xF8),
    },
    "camiseta": {
        "pri": (0xD0, 0x40, 0x40), "shade": (0x98, 0x28, 0x28), "light": (0xE8, 0x70, 0x70),
        "sec": (0xF8, 0xF8, 0xF8), "accent": (0xF8, 0xD0, 0x30),
    },
    "camisa": {
        "pri": (0xEC, 0xE4, 0xD4), "shade": (0xC8, 0xB8, 0xA0), "light": (0xFC, 0xF8, 0xF0),
        "sec": (0x40, 0x60, 0xA8), "accent": (0x48, 0x68, 0xB8),
    },
    "chaqueta": {
        "pri": (0x2C, 0x2C, 0x30), "shade": (0x18, 0x18, 0x1C), "light": (0x4A, 0x4A, 0x52),
        "sec": (0xA0, 0xA0, 0xA8), "accent": (0xC0, 0xC0, 0xC8),
    },
    "lab": {
        "pri": (0xF6, 0xF6, 0xF8), "shade": (0xD0, 0xD0, 0xD8), "light": (0xFF, 0xFF, 0xFF),
        "sec": (0x3C, 0x50, 0xA8), "accent": (0x60, 0x74, 0xC8),
    },
}


def rgba(c, a=255):
    return c if len(c) == 4 else (c[0], c[1], c[2], a)


def shade_down(c, f=0.75):
    return (int(c[0] * f), int(c[1] * f), int(c[2] * f))


def shade_up(c, f=1.15):
    return (min(255, int(c[0] * f)), min(255, int(c[1] * f)), min(255, int(c[2] * f)))


class Canvas:
    def __init__(self):
        self.px = [[None] * W for _ in range(H)]

    def set(self, x, y, c):
        if 0 <= x < W and 0 <= y < H and c is not None:
            self.px[y][x] = rgba(c)

    def get(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            return self.px[y][x]
        return None

    def clear(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            self.px[y][x] = None

    def fill_rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def fill_ellipse(self, cx, cy, rx, ry, c):
        for yy in range(cy - ry, cy + ry + 1):
            for xx in range(cx - rx, cx + rx + 1):
                dx = (xx - cx) / max(rx, 0.01)
                dy = (yy - cy) / max(ry, 0.01)
                if dx * dx + dy * dy <= 1.02:
                    self.set(xx, yy, c)

    def erase_ellipse(self, cx, cy, rx, ry):
        for yy in range(cy - ry, cy + ry + 1):
            for xx in range(cx - rx, cx + rx + 1):
                dx = (xx - cx) / max(rx, 0.01)
                dy = (yy - cy) / max(ry, 0.01)
                if dx * dx + dy * dy <= 1.0:
                    self.clear(xx, yy)

    def to_image(self) -> Image.Image:
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        for y in range(H):
            for x in range(W):
                p = self.px[y][x]
                if p:
                    im.putpixel((x, y), p)
        return im


def add_outline(cv: Canvas, protect=None):
    """1px dark outline on opaque body. protect = set of (x,y) to skip."""
    protect = protect or set()
    solid = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            p = cv.get(x, y)
            if p and p[3] >= 160:
                solid[y][x] = True
    pts = []
    for y in range(H):
        for x in range(W):
            if not solid[y][x] or (x, y) in protect:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= W or ny >= H or not solid[ny][nx]:
                    pts.append((x, y))
                    break
    for x, y in pts:
        cv.set(x, y, OUTLINE)


# Face window (open skin area) — hair must not cover this permanently
FACE_CX, FACE_CY, FACE_RX, FACE_RY = 16, 9, 5, 4


def paint_shadow(cv: Canvas):
    for yy in range(29, 32):
        for xx in range(10, 22):
            dx = (xx - 16) / 6.5
            dy = (yy - 30.2) / 1.4
            if dx * dx + dy * dy <= 1.0:
                cv.set(xx, yy, SHADOW)


def paint_legs_shoes(cv: Canvas):
    cv.fill_rect(11, 22, 4, 5, PANTS[0])
    cv.fill_rect(17, 22, 4, 5, PANTS[0])
    cv.fill_rect(11, 25, 4, 2, PANTS[1])
    cv.fill_rect(17, 25, 4, 2, PANTS[1])
    cv.fill_rect(10, 27, 5, 2, SHOE[0])
    cv.fill_rect(17, 27, 5, 2, SHOE[0])
    cv.fill_rect(10, 28, 5, 1, SHOE[1])
    cv.fill_rect(17, 28, 5, 1, SHOE[1])


def paint_torso(cv: Canvas, outfit_id: str, pal: dict, skin):
    skin_l, skin_m, skin_d = skin
    pri, shade, light = pal["pri"], pal["shade"], pal["light"]
    sec, accent = pal["sec"], pal["accent"]

    if outfit_id == "hoodie":
        # hood mass behind / around neck (distinct silhouette bump)
        cv.fill_ellipse(16, 13, 8, 3, shade)
        cv.fill_ellipse(16, 12, 7, 2, pri)
        # torso
        cv.fill_rect(10, 14, 12, 8, pri)
        cv.fill_rect(10, 14, 12, 2, light)
        cv.fill_rect(10, 19, 12, 3, shade)
        # kangaroo pocket
        cv.fill_rect(12, 18, 8, 3, shade)
        cv.fill_rect(12, 18, 8, 1, light)
        cv.set(12, 19, OUTLINE[:3])
        cv.set(19, 19, OUTLINE[:3])
        # drawstrings
        cv.set(14, 15, accent)
        cv.set(14, 16, accent)
        cv.set(18, 15, accent)
        cv.set(18, 16, accent)
        # long sleeves
        cv.fill_rect(7, 14, 3, 8, pri)
        cv.fill_rect(22, 14, 3, 8, pri)
        cv.fill_rect(7, 14, 3, 2, light)
        cv.fill_rect(22, 14, 3, 2, light)
        cv.fill_rect(7, 19, 3, 3, shade)
        cv.fill_rect(22, 19, 3, 3, shade)
        cv.fill_rect(7, 22, 3, 2, skin_m)
        cv.fill_rect(22, 22, 3, 2, skin_m)

    elif outfit_id == "camiseta":
        cv.fill_rect(10, 14, 12, 8, pri)
        cv.fill_rect(10, 14, 12, 2, light)
        cv.fill_rect(10, 19, 12, 3, shade)
        # short sleeves (distinct stubby)
        cv.fill_rect(8, 14, 2, 4, pri)
        cv.fill_rect(22, 14, 2, 4, pri)
        cv.fill_rect(8, 16, 2, 2, shade)
        cv.fill_rect(22, 16, 2, 2, shade)
        # bare arms
        cv.fill_rect(7, 18, 3, 4, skin_m)
        cv.fill_rect(22, 18, 3, 4, skin_m)
        cv.fill_rect(7, 21, 3, 1, skin_d)
        cv.fill_rect(22, 21, 3, 1, skin_d)
        # crest
        cv.fill_rect(14, 16, 4, 3, accent)
        cv.fill_rect(15, 17, 2, 1, sec)

    elif outfit_id == "camisa":
        cv.fill_rect(10, 14, 12, 8, pri)
        cv.fill_rect(10, 14, 12, 2, light)
        cv.fill_rect(10, 19, 12, 3, shade)
        # pointed collar
        cv.fill_rect(12, 13, 4, 2, light)
        cv.fill_rect(16, 13, 4, 2, light)
        cv.set(15, 14, shade)
        cv.set(16, 14, shade)
        # buttons down center
        for by in (16, 18, 20):
            cv.set(16, by, accent)
        # cuffs
        cv.fill_rect(8, 14, 2, 5, pri)
        cv.fill_rect(22, 14, 2, 5, pri)
        cv.fill_rect(8, 18, 2, 1, sec)
        cv.fill_rect(22, 18, 2, 1, sec)
        cv.fill_rect(7, 19, 3, 3, skin_m)
        cv.fill_rect(22, 19, 3, 3, skin_m)

    elif outfit_id == "chaqueta":
        # lighter shirt under
        cv.fill_rect(12, 14, 8, 8, sec)
        cv.fill_rect(12, 14, 8, 2, accent)
        cv.fill_rect(12, 19, 8, 3, shade_down(sec, 0.82))
        # open dark jacket panels (distinct silhouette wider)
        cv.fill_rect(8, 14, 5, 8, pri)
        cv.fill_rect(19, 14, 5, 8, pri)
        cv.fill_rect(8, 14, 5, 2, light)
        cv.fill_rect(19, 14, 5, 2, light)
        cv.fill_rect(8, 19, 5, 3, shade)
        cv.fill_rect(19, 19, 3, 3, shade)
        # lapel edges
        cv.fill_rect(12, 14, 1, 6, light)
        cv.fill_rect(19, 14, 1, 6, light)
        # sleeves
        cv.fill_rect(6, 14, 3, 8, pri)
        cv.fill_rect(23, 14, 3, 8, pri)
        cv.fill_rect(6, 19, 3, 3, shade)
        cv.fill_rect(23, 19, 3, 3, shade)
        cv.fill_rect(6, 22, 3, 2, skin_m)
        cv.fill_rect(23, 22, 3, 2, skin_m)

    elif outfit_id == "lab":
        # blue under
        cv.fill_rect(11, 14, 10, 8, sec)
        # white coat
        cv.fill_rect(9, 14, 14, 8, pri)
        cv.fill_rect(9, 14, 14, 2, light)
        cv.fill_rect(9, 19, 14, 3, shade)
        # open center flaps → blue underlayer visible
        cv.fill_rect(14, 15, 4, 7, sec)
        cv.fill_rect(14, 19, 4, 3, shade_down(sec, 0.78))
        # lapels
        cv.fill_rect(12, 14, 2, 4, light)
        cv.fill_rect(18, 14, 2, 4, light)
        # coat flaps extending slightly wider at bottom
        cv.fill_rect(8, 18, 2, 4, pri)
        cv.fill_rect(22, 18, 2, 4, pri)
        # sleeves
        cv.fill_rect(6, 14, 3, 8, pri)
        cv.fill_rect(23, 14, 3, 8, pri)
        cv.fill_rect(6, 19, 3, 3, shade)
        cv.fill_rect(23, 19, 3, 3, shade)
        cv.fill_rect(6, 22, 3, 2, skin_m)
        cv.fill_rect(23, 22, 3, 2, skin_m)
        # breast pocket
        cv.fill_rect(19, 16, 3, 2, shade)


def paint_neck_head(cv: Canvas, skin):
    skin_l, skin_m, skin_d = skin
    cv.fill_rect(14, 13, 4, 2, skin_m)
    cv.fill_rect(14, 14, 4, 1, skin_d)
    # round head
    cv.fill_ellipse(16, 8, 7, 7, skin_m)
    cv.fill_ellipse(16, 7, 5, 4, skin_l)
    # cheek shade
    for y in range(8, 13):
        cv.set(10, y, skin_d)
        cv.set(22, y, skin_d)


def paint_hair(cv: Canvas, style: str, hair_pal, skin_m):
    mid, dark, light = hair_pal

    # Always: top hair cap
    cv.fill_ellipse(16, 4, 8, 4, mid)
    cv.fill_rect(10, 3, 12, 3, mid)
    cv.fill_rect(12, 2, 8, 2, light)
    cv.fill_rect(9, 4, 2, 4, dark)
    cv.fill_rect(21, 4, 2, 4, dark)

    if style == "corto":
        # tight bowl — high above ears, short fringe
        cv.fill_ellipse(16, 5, 7, 3, mid)
        cv.fill_rect(11, 5, 10, 2, mid)
        # short fringe line above eyes
        cv.fill_rect(12, 6, 8, 1, dark)
        cv.fill_rect(13, 2, 6, 1, light)
        # no side locks below y=7

    elif style == "medio":
        # medium with side locks to cheek + parted bangs
        cv.fill_rect(9, 5, 2, 6, mid)   # left lock
        cv.fill_rect(21, 5, 2, 6, mid)   # right lock
        cv.fill_rect(9, 9, 2, 2, dark)
        cv.fill_rect(21, 9, 2, 2, dark)
        # bangs that leave eye gap (center parting)
        cv.fill_rect(11, 6, 4, 2, mid)
        cv.fill_rect(17, 6, 4, 2, mid)
        cv.set(15, 6, dark)
        cv.set(16, 6, dark)
        cv.fill_rect(13, 2, 6, 1, light)

    elif style == "largo":
        # long hair cascading on BOTH sides down to shoulders — face center clear
        cv.fill_rect(8, 5, 3, 12, mid)
        cv.fill_rect(21, 5, 3, 12, mid)
        cv.fill_rect(8, 12, 3, 5, dark)
        cv.fill_rect(21, 12, 3, 5, dark)
        cv.fill_rect(8, 16, 3, 1, dark)
        cv.fill_rect(21, 16, 3, 1, dark)
        # bangs with center gap
        cv.fill_rect(11, 6, 4, 2, mid)
        cv.fill_rect(17, 6, 4, 2, mid)
        cv.fill_rect(13, 2, 6, 2, light)

    elif style == "recogido":
        # pulled back — little side hair, bun on top
        cv.fill_ellipse(16, 5, 7, 3, mid)
        cv.fill_rect(11, 4, 10, 2, mid)
        # thin temples only
        cv.fill_rect(10, 5, 1, 4, dark)
        cv.fill_rect(21, 5, 1, 4, dark)
        # high forehead (minimal bangs)
        cv.fill_rect(13, 6, 6, 1, mid)
        # bun
        cv.fill_ellipse(16, 1, 4, 3, mid)
        cv.fill_ellipse(16, 1, 3, 2, light)
        cv.fill_rect(14, 3, 4, 1, dark)
        # hair tie
        cv.fill_rect(14, 4, 4, 1, (0xC8, 0x38, 0x70))

    elif style == "rizado":
        # curly silhouette bumps — clearly wider / irregular
        bumps = [
            (10, 2, 2), (14, 1, 2), (18, 1, 2), (22, 2, 2),
            (8, 5, 2), (24, 5, 2), (9, 8, 2), (23, 8, 2),
            (12, 2, 2), (20, 2, 2), (16, 1, 2),
        ]
        for bx, by, r in bumps:
            cv.fill_ellipse(bx, by, r, r, mid)
        cv.fill_ellipse(13, 2, 2, 2, light)
        cv.fill_ellipse(19, 2, 2, 2, light)
        cv.fill_rect(9, 6, 2, 4, dark)
        cv.fill_rect(21, 6, 2, 4, dark)
        # light bangs with gap
        cv.fill_rect(12, 6, 3, 1, mid)
        cv.fill_rect(17, 6, 3, 1, mid)

    # CRITICAL: punch face window so skin/eyes remain readable
    # Re-fill face oval with skin
    cv.fill_ellipse(FACE_CX, FACE_CY, FACE_RX, FACE_RY, skin_m)
    # soft forehead highlight strip
    cv.fill_rect(13, 7, 6, 1, skin_m)


def paint_face(cv: Canvas, skin):
    skin_l, skin_m, skin_d = skin
    # ensure face oval skin
    cv.fill_ellipse(FACE_CX, FACE_CY, FACE_RX, FACE_RY, skin_m)
    cv.fill_ellipse(16, 8, 3, 2, skin_l)
    # eyes: 2 white + pupils looking south
    # left
    cv.set(13, 8, WHITE)
    cv.set(14, 8, WHITE)
    cv.set(13, 9, PUPIL)
    cv.set(14, 9, PUPIL)
    # right
    cv.set(18, 8, WHITE)
    cv.set(19, 8, WHITE)
    cv.set(18, 9, PUPIL)
    cv.set(19, 9, PUPIL)
    # tiny mouth
    cv.set(15, 11, MOUTH)
    cv.set(16, 11, MOUTH)


def paint_accessory(cv: Canvas, acc: str, skin_m=None):
    if acc == "none":
        return
    if acc == "glasses":
        frame = (0x22, 0x22, 0x28)
        # left lens frame around eyes
        for x in (12, 15):
            cv.set(x, 8, frame)
            cv.set(x, 9, frame)
        for x in range(12, 16):
            cv.set(x, 7, frame)
            cv.set(x, 10, frame)
        # right
        for x in (17, 20):
            cv.set(x, 8, frame)
            cv.set(x, 9, frame)
        for x in range(17, 21):
            cv.set(x, 7, frame)
            cv.set(x, 10, frame)
        # bridge + temples
        cv.set(16, 8, frame)
        cv.set(11, 8, frame)
        cv.set(21, 8, frame)
        # keep pupils visible (re-stamp)
        cv.set(13, 8, WHITE)
        cv.set(14, 8, WHITE)
        cv.set(13, 9, PUPIL)
        cv.set(14, 9, PUPIL)
        cv.set(18, 8, WHITE)
        cv.set(19, 8, WHITE)
        cv.set(18, 9, PUPIL)
        cv.set(19, 9, PUPIL)

    elif acc == "backpack":
        pack = (0x72, 0x48, 0x2A)
        pack_d = (0x4E, 0x30, 0x18)
        pack_l = (0x92, 0x62, 0x3A)
        cv.fill_rect(4, 13, 4, 8, pack)
        cv.fill_rect(24, 13, 4, 8, pack)
        cv.fill_rect(4, 17, 4, 4, pack_d)
        cv.fill_rect(24, 17, 4, 4, pack_d)
        cv.fill_rect(5, 14, 2, 2, pack_l)
        cv.fill_rect(25, 14, 2, 2, pack_l)
        # straps hint
        cv.set(8, 13, pack_d)
        cv.set(23, 13, pack_d)

    elif acc == "cap":
        crown = (0x2A, 0x5A, 0xA0)
        crown_l = (0x48, 0x78, 0xC0)
        bill = (0x1A, 0x3A, 0x68)
        # crown on top of head only (y=1..6)
        cv.fill_ellipse(16, 3, 8, 3, crown)
        cv.fill_rect(9, 3, 14, 3, crown)
        cv.fill_rect(11, 2, 10, 2, crown_l)
        # bill ABOVE eyes (y=6), face stays visible
        cv.fill_rect(10, 6, 12, 1, bill)
        cv.fill_rect(11, 6, 10, 1, shade_up(bill, 1.25))

    elif acc == "headphones":
        band = (0x34, 0x34, 0x3A)
        cup = (0x16, 0x16, 0x1A)
        cup_l = (0x58, 0x58, 0x62)
        cv.fill_rect(11, 1, 10, 2, band)
        cv.fill_rect(8, 4, 3, 6, cup)
        cv.fill_rect(21, 4, 3, 6, cup)
        cv.fill_rect(8, 5, 3, 4, cup_l)
        cv.fill_rect(21, 5, 3, 4, cup_l)


def paint_character(
    skin_id="media",
    hair_style="medio",
    hair_color="castano",
    outfit="hoodie",
    accessory="none",
) -> Image.Image:
    cv = Canvas()
    skin = SKIN[skin_id]
    hair = HAIR[hair_color]
    pal = OUTFIT_PAL[outfit]

    paint_shadow(cv)
    if accessory == "backpack":
        paint_accessory(cv, "backpack")
    paint_legs_shoes(cv)
    paint_torso(cv, outfit, pal, skin)
    paint_neck_head(cv, skin)
    paint_hair(cv, hair_style, hair, skin[1])
    paint_face(cv, skin)

    if accessory == "glasses":
        paint_accessory(cv, "glasses")
    elif accessory == "cap":
        paint_accessory(cv, "cap")
        # face must remain under bill
        paint_face(cv, skin)
    elif accessory == "headphones":
        paint_accessory(cv, "headphones")

    # protect face feature pixels from outline overwrite
    protect = {(13, 8), (14, 8), (13, 9), (14, 9), (18, 8), (19, 8), (18, 9), (19, 9),
               (15, 11), (16, 11)}
    add_outline(cv, protect=protect)
    # re-stamp face after outline so eyes always crisp
    paint_face(cv, skin)
    if accessory == "glasses":
        paint_accessory(cv, "glasses")

    return cv.to_image()


def scale_nearest(im: Image.Image, scale: int = DISPLAY_SCALE) -> Image.Image:
    return im.resize((W * scale, H * scale), Image.NEAREST)


def save_preview(path: str, **kwargs):
    im = paint_character(**kwargs)
    big = scale_nearest(im)
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    big.save(path)
    im.save(path.replace(".png", "_32.png"))
    return path


if __name__ == "__main__":
    out = "/workspace/prototipo/assets/sprites/student/_previews"
    specs = [
        ("01_hoodie.png", dict(skin_id="media", hair_style="medio", hair_color="castano", outfit="hoodie", accessory="none")),
        ("02_lab_glasses.png", dict(skin_id="clara", hair_style="corto", hair_color="negro", outfit="lab", accessory="glasses")),
        ("03_camiseta_rubio_cap.png", dict(skin_id="media", hair_style="medio", hair_color="rubio", outfit="camiseta", accessory="cap")),
        ("04_chaqueta_largo.png", dict(skin_id="morena", hair_style="largo", hair_color="castano", outfit="chaqueta", accessory="none")),
    ]
    for name, kw in specs:
        print("wrote", save_preview(os.path.join(out, name), **kw))
