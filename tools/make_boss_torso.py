"""Saca el torso (hombreras, tubos de ensayo, rack, cables) del sprite completo del boss 0xDEADBEEF.

Uso:  python tools/make_boss_torso.py   (después de slice_boss_sheets.py)
Crea  assets/sprites/bosses/deadbeef/boss_0xdeadbeef_torso_0.png (normal) y _torso_1.png (dañado).

El sprite "full" es el más fiel a la imagen de referencia, pero trae cabeza y brazos pegados.
Aquí se borran cabeza, antebrazos y tanque (el hueco del tanque queda oscuro para cuando se rompe el vidrio).
Se escala x1.05 para que las orugas midan lo mismo que boss_0xdeadbeef_body_0.
En el juego el torso se dibuja con su esquina superior izquierda en (-81, -207) respecto a los pies.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
D = ROOT / "assets" / "sprites" / "bosses" / "deadbeef"
X0, Y0, X1, Y1 = 60, 52, 242, 176
K = 1.05


def main() -> None:
    full = Image.open(D / "boss_0xdeadbeef_full_0.png").convert("RGBA")
    crop = full.crop((X0, Y0, X1, Y1))
    m = Image.new("L", crop.size, 255)
    d = ImageDraw.Draw(m)

    def poly(pts):
        d.polygon([(x - X0, y - Y0) for x, y in pts], fill=0)

    poly([(95, 52), (190, 52), (190, 82), (170, 88), (150, 80), (132, 92), (104, 92), (95, 80)])  # cabeza
    poly([(60, 104), (96, 100), (100, 176), (60, 176)])      # brazo izquierdo
    poly([(206, 118), (242, 110), (242, 176), (206, 176)])   # brazo derecho
    arr = np.asarray(crop).copy()
    arr[..., 3] = np.where(np.asarray(m) > 0, arr[..., 3], 0)
    arr[96 - Y0:176 - Y0, 102 - X0:160 - X0, :3] = (34, 36, 42)   # hueco del tanque
    arr[96 - Y0:176 - Y0, 102 - X0:160 - X0, 3] = 255
    t = Image.fromarray(arr, "RGBA")
    t = t.resize((round(t.width * K), round(t.height * K)), Image.NEAREST)
    t.save(D / "boss_0xdeadbeef_torso_0.png")
    b = np.asarray(t).astype(np.float32).copy()
    b[..., :3] *= 0.78
    rng = np.random.default_rng(3)
    yy, xx = np.ogrid[:t.height, :t.width]
    for _ in range(9):
        cx, cy, r = rng.integers(0, t.width), rng.integers(0, t.height), rng.integers(4, 9)
        b[(xx - cx) ** 2 + (yy - cy) ** 2 < r * r, :3] *= 0.35
    Image.fromarray(b.clip(0, 255).astype(np.uint8), "RGBA").save(D / "boss_0xdeadbeef_torso_1.png")
    print("torso", t.size)


if __name__ == "__main__":
    main()
