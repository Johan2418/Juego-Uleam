#!/usr/bin/env python3
"""Genera referencias_animacion/PROMPTS_PULIDO_2.md y GROKBOT_PULIDO_2.md (ciclos de 8 poses en UNA imagen).
Uso: python3 tools/gen_prompts_pulido2.py   (no pisa el progreso de GROKBOT_PULIDO_2.md si ya existe)
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFD = ROOT / "referencias_animacion"
SRC = REFD / "_entregas_runway"

CHARS = {
    "wadrid": ("Wadrid", "big curly dark brown afro, black rectangular glasses, warm medium-brown skin, "
               "dark green polo, blue lanyard with grey ID card on the chest, blue jeans, brown shoes"),
    "marlonx_a": ("MarlonX-a", "short straight black hair, black rectangular glasses, light-brown skin, "
                  "charcoal dark grey polo with small gold badge, blue lanyard with light ID card on the chest, blue jeans, black shoes"),
}
EQUIP = {
    "guerrero": "Equipment: long wooden school ruler (light yellow wood, black tick marks) held like a sword in the RIGHT hand only; "
                "big pink rubber eraser STRAPPED to the LEFT forearm like a buckler, visible in all 8 poses.",
    "mago": "Equipment: gnarled wooden branch staff about body height with a small glowing blue crystal on top, held in the RIGHT hand, "
            "exactly ONE staff in every pose. Do NOT draw any orb, projectile, trail or magic effect.",
    "chain": "Equipment: ONE black phone charger cable used as a whip, held by the plug end in the RIGHT hand.",
    "none": "Empty hands, no weapon.",
}
VIEW = {
    "right": ("seen from the side facing RIGHT in ALL 8 poses (strict side profile)", "derecha_lado"),
    "down": ("FACING THE VIEWER in ALL 8 poses (front view)", "abajo_frente"),
    "up": ("seen FROM BEHIND in ALL 8 poses: back of the head (hair only), back of the polo and jeans; NO face, NO glasses, "
           "NO ID card visible", "arriba_espalda"),
    "down_right": ("in a three-quarter FRONT view turned 45 degrees toward the RIGHT (facing down-right) in ALL 8 poses",
                   "abajo_frente"),
    "up_right": ("in a three-quarter BACK view turned 45 degrees toward the RIGHT (facing up-right) in ALL 8 poses: back of the head, "
                 "NO face, NO glasses, NO ID card visible", "arriba_espalda"),
}
HEAD = ("2D pixel art SPRITE SHEET of the character in the first attached image, top-down 3/4 view action-RPG, 16-bit SNES style, "
        "chibi proportions, crisp 1-pixel black outline, hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. "
        "The second attached image is the EXACT sprite reference: copy that character's design, pixel art style, palette, head size, "
        "body width and total height exactly; only the arms, legs and weapon change between poses. "
        "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. "
        "Exactly 8 full-body poses of the SAME character in ONE image, arranged in a grid of 4 columns and 2 rows "
        "(read left to right, top row = poses 1-4, bottom row = poses 5-8), evenly spaced, lots of empty space between poses, "
        "wide margin, nothing touching the image edges or each other. Landscape image (3:2).")
SAME = ("CONSISTENCY RULES: all 8 poses have EXACTLY the same scale; the feet of every pose rest on the same invisible "
        "baseline of its row; the top of the head stays at the same height in every pose (at most a tiny 1-2 pixel bob). "
        "No text, no numbers, no labels, no frame borders, no motion lines, no effects.")

WALK = ("Animation: 8-frame WALK CYCLE, smooth loop from pose 8 back to pose 1, arms swing opposite to the legs. "
        "Pose 1: contact, LEFT foot forward, right foot back. Pose 2: down, weight on the left foot, knees slightly bent. "
        "Pose 3: passing, right leg passing under the body, feet close together. Pose 4: up, right leg reaching forward. "
        "Pose 5: contact, RIGHT foot forward, left foot back. Pose 6: down, weight on the right foot. "
        "Pose 7: passing, left leg passing under the body, feet close together. Pose 8: up, left leg reaching forward. "
        "The body and head keep facing the same direction in all 8 poses; never turn the body.")
ATTACK = {
    "guerrero_attack": ("Animation: 8-frame TWO-HIT SWORD COMBO with the ruler. Hit 1 (poses 1-4): 1 ready stance, 2 wind-up with the "
                        "ruler pulled back to the side, 3 fast slash forward, 4 follow-through with the arm extended. Hit 2 (poses 5-8): "
                        "5 ruler brought back across the body, 6 second slash in the opposite direction, 7 follow-through, 8 back to ready stance. "
                        "The ruler is visible in ALL 8 poses and never bends."),
    "mago_cast": ("Animation: 8-frame TWO-CAST SPELL COMBO with the staff. Cast 1 (poses 1-4): 1 idle holding the staff, 2 staff pulled back at "
                  "chest height, 3 staff thrust forward, 4 hold. Cast 2 (poses 5-8): 5 staff raised to the other side, 6 sweeping thrust "
                  "forward, 7 hold, 8 back to idle. Exactly one staff, no projectile drawn."),
    "chain_whip": ("Animation: 8-frame TWO-LASH WHIP COMBO with the cable. Lash 1 (poses 1-4): 1 ready with the cable coiled, 2 short wind-up "
                   "to the side, 3 fast crack forward, 4 cable snapping back. Lash 2 (poses 5-8): 5 wind-up to the other side, 6 second crack "
                   "forward, 7 cable snapping back, 8 ready. Exactly one cable."),
}
COMBO_SHEETS = [("wadrid", "guerrero_attack", "down"), ("wadrid", "guerrero_attack", "down_right"),
                ("wadrid", "mago_cast", "up_right"), ("wadrid", "chain_whip", "up"),
                ("marlonx_a", "guerrero_attack", "up"), ("marlonx_a", "guerrero_attack", "right"),
                ("marlonx_a", "mago_cast", "up"), ("marlonx_a", "chain_whip", "up_right")]


def src_name(stem):
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        if (SRC / f"{stem}{ext}").exists():
            return f"{stem}{ext}"
    return f"{stem}.png"


def block(ch, d, out_stem, style_stem, anim, equip):
    name, desc = CHARS[ch]
    view, ref = VIEW[d]
    prompt = " ".join([HEAD, f"Character ({name}): {desc}. The character is {view}.", equip, anim, SAME])
    return (f"### `{out_stem}.png`\n- Imagen 1: `REF_{ch}/ref_{ch}_{ref}.png` · Imagen 2: `_entregas_runway/{src_name(style_stem)}`\n"
            f"```\n{prompt}\n```\n")


sections = []
items = [(f"{ch}_walk8_{d}", block(ch, d, f"{ch}_walk8_{d}", f"{ch}_walk_{d}", WALK, EQUIP["none"]))
         for ch in CHARS for d in ["down", "up", "right", "down_right", "up_right"]]
sections.append(("A · Caminata de 8 poses (una imagen por dirección)",
                 "Imagen 2 = la caminata actual de esa dirección (diseño y tamaño a copiar).", items))
items = []
for ch, base, d in COMBO_SHEETS:
    cls = base.split("_")[0]
    items.append((f"{ch}_{base}8_{d}", block(ch, d, f"{ch}_{base}8_{d}", f"{ch}_{base}_{d}", ATTACK[base], EQUIP[cls])))
sections.append(("B · Combos J de 8 poses (los 8 que no encajaban)",
                 "Imagen 2 = el ataque actual de esa dirección (diseño, arma y tamaño a copiar).", items))

total = sum(len(x[2]) for x in sections) + 1
out = [f"# PROMPTS DE PULIDO 2 — ciclos de 8 poses en UNA imagen ({total} hojas)\n",
       "Cada bloque: archivo a guardar, Imagen 1 (en `referencias_animacion/`), Imagen 2 (en `referencias_animacion/_entregas_runway/`) y el prompt.\n"]
for title, note, its in sections:
    out.append(f"\n## {title}\n{note}\n")
    out += [b for _, b in its]
out.append("\n## C · Hoja pendiente del pulido anterior\n"
           "`marlonx_a_mago_parry_up_right.png`: usa su bloque de `PROMPTS_PULIDO.md` (formato 2x2 de siempre, vertical 3:4) "
           "+ la CRITICAL VIEW RULE de `GROKBOT_PULIDO.md`.\n")
(REFD / "PROMPTS_PULIDO_2.md").write_text("\n".join(out), encoding="utf-8")

task = REFD / "GROKBOT_PULIDO_2.md"
if not task.exists():
    L = [f"# TAREA PARA GROKBOT — pulido 2: ciclos de 8 poses ({total} hojas)\n",
         "Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a esa carpeta).",
         "Base: `referencias_animacion/GROKBOT_TAREA.md` (procedimiento y lista de control). Prompts: `referencias_animacion/PROMPTS_PULIDO_2.md`.\n",
         "## Por qué esta tarea",
         "Las hojas \"intermedias\" (`walk_b`, `*_b`) se generaron aparte: salieron con otra altura y otro orden de piernas, y al intercalarlas "
         "el personaje vibraba. Ahora cada ciclo va COMPLETO (8 poses) en UNA sola imagen, así las 8 poses salen del mismo dibujo.\n",
         "## Herramientas: Gemini Plus o ChatGPT Plus",
         "- Puedes usar cualquiera de las dos. Lo único que importa es que el personaje se vea IDÉNTICO a la Imagen 2 (mismo diseño, colores, "
         "tamaño de cabeza, alto y estilo pixel art). Si uno de los dos lo cambia, prueba con el otro.",
         "- Recomendado: intenta primero con el que mejor copie la Imagen 2; si al 1.er intento el estilo sale suave/pintado (sin píxeles duros) "
         "o cambia la cara, el pelo o la ropa, cambia de herramienta para el 2.º intento.",
         "- En los dos: conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.",
         "- Formato: HORIZONTAL 3:2 para las hojas de 8 poses (en ChatGPT pide 1536x1024; en Gemini elige 3:2 o 16:9). "
         "La hoja de la sección C es vertical 3:4.",
         "- Fondo verde menta liso (#A0EFA5), NO transparente (el recortador usa ese color).",
         "- ChatGPT a veces agranda la imagen con bordes o añade sombra en el suelo: regenera si pasa.\n",
         "## Lista de control de cada hoja de 8 poses (debe cumplir TODO)",
         "- Exactamente 8 poses en 4 columnas x 2 filas, separadas, sin tocarse ni tocar los bordes, sin números ni texto.",
         "- El personaje es el MISMO de la Imagen 2: cara, gafas, pelo, piel, polo, carnet, jeans y zapatos iguales; mismo estilo pixel art.",
         "- Las 8 poses tienen el MISMO tamaño y la cabeza a la misma altura (pon las 8 una al lado de la otra mentalmente: no debe haber una más alta).",
         "- Caminata: las piernas avanzan en orden (izq. delante → juntas → der. delante → juntas) y el cuerpo NO gira entre poses.",
         "- Combos: el arma se ve en las 8 poses, una sola arma, sin estelas.",
         "- Vista correcta en las 8: `_up` / `_up_right` de espaldas SIN cara, gafas ni carnet.\n",
         "## Guardado",
         "Guarda en `referencias_animacion/_entregas_runway/<nombre exacto>.png` (o .jpg). Marca `[x]` al guardar cada una. "
         "Si falla 2 veces (contando las dos herramientas), marca `[!]` con nota y sigue. No toques código, `assets/`, `scenes/` ni `scripts/`.\n",
         "## Progreso"]
    for title, _, its in sections:
        L.append(f"\n### {title}")
        L += [f"- [ ] `{stem}.png`" for stem, _ in its]
    L.append("\n### C · Pendiente del pulido anterior\n- [ ] `marlonx_a_mago_parry_up_right.png`")
    L.append("\n## Notas de grokbot\n(resumen al terminar: qué herramienta usaste en cada hoja y qué falló)\n")
    task.write_text("\n".join(L), encoding="utf-8")
print(total, "hojas")
