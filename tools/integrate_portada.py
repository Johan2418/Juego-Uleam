"""Integra las imágenes de grokbot de la portada y la selección (GROKBOT_PORTADA.md).

    referencias_animacion/_entregas_runway/portada/portada_fondo.png
        -> assets/sprites/title/title_bg.png  (recorte 16:9 y escala a 1280x720)
    referencias_animacion/_entregas_runway/portada/retrato_<id>.png   (fondo magenta)
        -> assets/sprites/portraits/<id>_select_hd.png  (sin fondo, recortado)

Uso: python tools/integrate_portada.py   (desde la carpeta del proyecto)
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "referencias_animacion", "_entregas_runway", "portada")


def fondo():
    p = os.path.join(SRC, "portada_fondo.png")
    if not os.path.exists(p):
        print("falta", p)
        return
    im = Image.open(p).convert("RGB")
    w, h = im.size
    tw = min(w, int(h * 16 / 9))
    th = int(tw * 9 / 16)
    x0, y0 = (w - tw) // 2, (h - th) // 2
    im = im.crop((x0, y0, x0 + tw, y0 + th)).resize((1280, 720), Image.LANCZOS)
    out = os.path.join(ROOT, "assets", "sprites", "title", "title_bg.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out)
    print("ok", out)


def sin_magenta(im):
    a = np.array(im.convert("RGBA")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = (r > 150) & (b > 150) & (g < 110) & (np.abs(r - b) < 90)
    a[..., 3][mag] = 0
    # borde: quita el tinte magenta de los píxeles vecinos al fondo
    edge = (~mag) & (np.roll(mag, 1, 0) | np.roll(mag, -1, 0) | np.roll(mag, 1, 1) | np.roll(mag, -1, 1))
    pink = edge & (r > g + 40) & (b > g + 40)
    a[..., 0][pink] = np.minimum(a[..., 0][pink], a[..., 1][pink] + 30)
    a[..., 2][pink] = np.minimum(a[..., 2][pink], a[..., 1][pink] + 30)
    a[..., :3][a[..., 3] == 0] = 0
    out = Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")
    return out.crop(out.getbbox())


def retratos():
    for cid in ("wadrid", "marlonx_a"):
        p = os.path.join(SRC, f"retrato_{cid}.png")
        if not os.path.exists(p):
            print("falta", p)
            continue
        im = sin_magenta(Image.open(p))
        if im.height > 900:
            s = 900 / im.height
            im = im.resize((int(im.width * s), 900), Image.NEAREST)
        out = os.path.join(ROOT, "assets", "sprites", "portraits", f"{cid}_select_hd.png")
        im.save(out)
        print("ok", out, im.size)


if __name__ == "__main__":
    fondo()
    retratos()
