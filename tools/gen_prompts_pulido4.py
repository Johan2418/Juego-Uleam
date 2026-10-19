#!/usr/bin/env python3
"""Genera referencias_animacion/PROMPTS_PULIDO_4.md y GROKBOT_PULIDO_4.md (reutiliza los textos del pulido 3)
(animaciones nuevas y de 8 poses en UNA imagen: derribo, reposo largo, contraataque, ultimate, especial, parry).
Uso: python3 tools/gen_prompts_pulido3.py   (no pisa el progreso de GROKBOT_PULIDO_3.md si ya existe)
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFD = ROOT / "referencias_animacion"
SRC = REFD / "_entregas_runway"
DIRS = ["down", "up", "right", "down_right", "up_right"]
CLASSES = ["guerrero", "mago", "chain"]

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
            "exactly ONE staff in every pose. Do NOT draw any orb, projectile, lightning, trail or magic effect.",
    "chain": "Equipment: ONE black phone charger cable used as a whip, held by the plug end in the RIGHT hand. "
             "The cable always stays inside its own grid cell.",
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
        "body width and total height exactly; only the pose changes between frames. "
        "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. "
        "Exactly 8 full-body poses of the SAME character in ONE image, arranged in a grid of 4 columns and 2 rows "
        "(read left to right, top row = poses 1-4, bottom row = poses 5-8), evenly spaced, lots of empty space between poses, "
        "wide margin, nothing touching the image edges or each other. Landscape image (3:2).")
SAME = ("CONSISTENCY RULES: all 8 poses have EXACTLY the same scale (same head size in every pose); the feet of every pose rest on the "
        "same invisible baseline of its row. Pose 8 is ALWAYS the character standing upright at full height, exactly as tall as the "
        "second image. No text, no numbers, no labels, no frame borders, no motion lines, no effects.")
BACK_RULE = ("CRITICAL VIEW RULE: the character is seen FROM BEHIND in ALL 8 poses. We see the back of the head (hair only), the back of "
             "the polo and the back of the jeans. NO face, NO eyes, NO glasses, NO ID card visible. If the second image shows another "
             "orientation, only copy its style and size.")
HAND_RULE = ("HAND RULE: the weapon stays in the character's RIGHT hand in ALL 8 poses. Because we see his back, his right hand is on "
             "the RIGHT side of the image. Never switch the weapon to the left hand and never mirror the character.")

KNOCKDOWN = ("Animation: 8-frame KNOCKDOWN AND GET-UP after a heavy hit; the character falls BACKWARD, away from the direction he faces. "
             "Pose 1: struck, upper body snapping backward, arms flung out, feet still on the ground. "
             "Pose 2: losing balance, falling backward. Pose 3: hitting the ground, small bounce. "
             "Pose 4: lying flat on the ground, dazed. Pose 5: still lying, lifting the head. "
             "Pose 6: pushing up with the arms into a sitting position. Pose 7: kneeling on one knee, getting up. "
             "Pose 8: standing upright again in the normal idle pose.")
IDLE_LONG = ("Animation: 8-frame IDLE FIDGET played after standing still for a while (a university student checking his phone). "
             "Pose 1: normal relaxed idle stance. Pose 2: reaching into the jeans pocket. "
             "Pose 3: holding a small black smartphone at chest height with both hands, looking down at it. "
             "Pose 4: thumb scrolling on the phone. Pose 5: small smile, shoulders slightly raised (laughing at the phone). "
             "Pose 6: scrolling again. Pose 7: putting the phone back into the pocket. "
             "Pose 8: normal relaxed idle stance, identical to pose 1. The body keeps facing the same direction in all poses.")
COUNTER = {
    "guerrero": ("Animation: 8-frame PARRY COUNTERATTACK. Pose 1: blocking with the eraser buckler raised in front, ruler held back. "
                 "Pose 2: the block absorbs a hit, body pushed back slightly. Pose 3: shoving the eraser outward. "
                 "Pose 4: winding up the ruler, body twisting. Pose 5: powerful slash forward with the ruler, lunging step. "
                 "Pose 6: follow-through, arm fully extended. Pose 7: pulling the ruler back. Pose 8: normal ready stance, standing upright."),
    "mago": ("Animation: 8-frame PARRY COUNTERATTACK. Pose 1: guarding with the SAME guard as the second image. "
             "Pose 2: the guard absorbs a hit, small step back. Pose 3: swinging the staff aside to deflect. "
             "Pose 4: pulling the staff back at chest height. Pose 5: thrusting the staff crystal forward with both hands, lunging step. "
             "Pose 6: hold, arms extended. Pose 7: drawing the staff back. Pose 8: normal standing pose with the staff upright."),
    "chain": ("Animation: 8-frame PARRY COUNTERATTACK. Pose 1: guarding with the SAME guard as the second image. "
              "Pose 2: the guard absorbs a hit. Pose 3: spinning the cable once at the side. Pose 4: winding up the right arm. "
              "Pose 5: fast crack forward, cable extended straight ahead. Pose 6: cable snapping back. "
              "Pose 7: catching the cable. Pose 8: normal ready stance, standing upright."),
}
SPECIAL = {
    "guerrero": ("Animation: 8-frame SHIELD BASH DASH with the eraser buckler. Pose 1: ready stance. Pose 2: crouching, eraser raised in front. "
                 "Pose 3: pushing off, starting the dash. Pose 4: dashing forward shoulder-first behind the eraser. "
                 "Pose 5: impact, eraser thrust forward at full extension. Pose 6: sliding to a stop. Pose 7: recovering balance. "
                 "Pose 8: normal ready stance, standing upright."),
    "mago": ("Animation: 8-frame TRIPLE CAST (a fan of three bolts that are NOT drawn). Pose 1: idle holding the staff. "
             "Pose 2: staff pulled back over the shoulder. Pose 3: pointing the staff forward-left. Pose 4: pointing the staff straight forward. "
             "Pose 5: pointing the staff forward-right. Pose 6: hold, arm extended. Pose 7: lowering the staff. "
             "Pose 8: normal standing pose with the staff upright."),
    "chain": ("Animation: 8-frame LONG LASH THAT PULLS THE ENEMY. Pose 1: ready, cable coiled. Pose 2: big wind-up over the head. "
              "Pose 3: throwing the cable forward. Pose 4: cable stretched straight forward as far as the grid cell allows. "
              "Pose 5: yanking the cable back with both hands, leaning back. Pose 6: still pulling, cable coming back. "
              "Pose 7: coiling the cable. Pose 8: normal ready stance, standing upright."),
}
PARRY = ("Animation: 8-frame PARRY GUARD, using the SAME guard pose and weapon position as the second image. "
         "Pose 1: ready stance. Pose 2: starting to raise the guard. Pose 3: guard fully raised. "
         "Poses 4, 5 and 6: holding the guard firmly (only tiny 1-pixel differences between them). "
         "Pose 7: lowering the guard. Pose 8: normal ready stance, standing upright.")
ULTIMATE = {
    "guerrero": ("Animation: 8-frame ULTIMATE: CHARGED GIANT SWORD STRIKE with the ruler. Pose 1: ready stance. "
                 "Pose 2: raising the ruler overhead with both hands. Pose 3: ruler held high above the head, knees bent, gathering power. "
                 "Pose 4: same, leaning back a bit more (peak of the charge). Pose 5: massive overhead slash forward, big step forward. "
                 "Pose 6: ruler stopped low in front, arms extended, held firmly. Pose 7: rising from the slash. "
                 "Pose 8: normal ready stance, standing upright. The ruler never bends; no glow, no beam drawn."),
    "mago": ("Animation: 8-frame ULTIMATE: CALLING A LIGHTNING STORM (no lightning drawn). Pose 1: idle holding the staff. "
             "Pose 2: lifting the staff. Pose 3: staff raised high overhead with the right arm, left arm open. "
             "Pose 4: both arms up, staff pointing at the sky. Pose 5: same, body slightly crouched. "
             "Pose 6: same, body slightly stretched upward. Pose 7: slamming the bottom of the staff down onto the ground. "
             "Pose 8: normal standing pose with the staff upright."),
    "chain": ("Animation: 8-frame ULTIMATE: CABLE WHIRLWIND START. Pose 1: ready stance. Pose 2: raising the cable over the head. "
              "Pose 3: twirling the cable over the head like a lasso. Pose 4: crouching, cable whirling low around the body. "
              "Poses 5-8: SPIN LOOP: the body keeps facing the same direction while the cable swings in a wide horizontal circle around "
              "him (5: cable in front, 6: cable at his right side, 7: cable behind him, 8: cable at his left side), standing upright, "
              "smooth loop from pose 8 back to pose 5."),
}


def src_name(stem):
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        if (SRC / f"{stem}{ext}").exists():
            return f"{stem}{ext}"
    return f"{stem}.png"



SAME8 = ("CONSISTENCY RULES: all 8 poses have EXACTLY the same scale and the SAME body proportions as the second image "
         "(same head size relative to the body, same leg length: do NOT make the head bigger or the body shorter). The feet of every pose "
         "rest on the same invisible baseline of its row; the top of the head stays at about the same height. "
         "No text, no numbers, no labels, no frame borders, no motion lines, no speed lines, no effects.")
ATTACK = {
    "guerrero_attack": ("Animation: 8-frame TWO-HIT SWORD COMBO with the ruler. Hit 1 (poses 1-4): 1 ready stance, 2 wind-up with the "
                        "ruler pulled back to the side, 3 fast slash forward, 4 follow-through with the arm extended. Hit 2 (poses 5-8): "
                        "5 ruler brought back across the body, 6 second slash in the opposite direction (backhand, SAME right hand), "
                        "7 follow-through, 8 back to ready stance. The ruler is visible in ALL 8 poses and never bends."),
    "mago_cast": ("Animation: 8-frame TWO-CAST SPELL COMBO with the staff, standing firmly on the ground (NO jumping, NO crouching). "
                  "Cast 1 (poses 1-4): 1 idle holding the staff, 2 staff pulled back at chest height, 3 staff thrust forward, 4 hold. "
                  "Cast 2 (poses 5-8): 5 staff raised to the other side, 6 sweeping thrust forward, 7 hold, 8 back to idle. "
                  "Exactly one staff, no projectile drawn."),
    "chain_whip": ("Animation: 8-frame TWO-LASH WHIP COMBO with the cable, standing firmly on the ground (NO jumping, NO crouching). "
                   "Lash 1 (poses 1-4): 1 ready with the cable coiled, 2 short wind-up to the side, 3 fast crack forward, 4 cable snapping "
                   "back. Lash 2 (poses 5-8): 5 wind-up to the other side, 6 second crack forward, 7 cable snapping back, 8 ready. "
                   "Exactly one cable, always inside its own grid cell."),
}
ERASER = ("ERASER RULE: the big pink rubber eraser stays strapped to the LEFT forearm and is clearly visible in ALL 8 poses "
          "(in back views it is on the LEFT side of the image).")
NOFX = "ABSOLUTELY NO motion lines, NO speed lines, NO wave marks, NO impact effects: only the character and the cable."
COMBOS = [("wadrid","guerrero_attack","up"),("wadrid","guerrero_attack","up_right"),
          ("wadrid","mago_cast","down"),("wadrid","mago_cast","up"),("wadrid","mago_cast","right"),("wadrid","mago_cast","down_right"),
          ("wadrid","chain_whip","down"),("wadrid","chain_whip","right"),("wadrid","chain_whip","down_right"),("wadrid","chain_whip","up_right"),
          ("marlonx_a","mago_cast","down"),("marlonx_a","mago_cast","right"),("marlonx_a","mago_cast","down_right"),("marlonx_a","mago_cast","up_right"),
          ("marlonx_a","chain_whip","down"),("marlonx_a","chain_whip","up"),("marlonx_a","chain_whip","right"),("marlonx_a","chain_whip","down_right")]
REDO = [("marlonx_a","guerrero","counter8","down_right",COUNTER["guerrero"],[ERASER]),
        ("wadrid","guerrero","ultimate8","up_right",ULTIMATE["guerrero"],[ERASER]),
        ("wadrid","chain","counter8","up",COUNTER["chain"],[NOFX])]
ROLL_HEAD = HEAD.replace("Exactly 8 full-body poses of the SAME character in ONE image, arranged in a grid of 4 columns and 2 rows "
        "(read left to right, top row = poses 1-4, bottom row = poses 5-8), evenly spaced, lots of empty space between poses, "
        "wide margin, nothing touching the image edges or each other. Landscape image (3:2).",
        "Exactly 4 full-body poses of the SAME character in ONE image, arranged in a 2x2 grid (read left to right, top row = poses 1-2, "
        "bottom row = poses 3-4), lots of empty space between poses, wide margin, nothing touching the image edges. Portrait image (3:4).")
ROLL = ("Animation: 4-frame DODGE ROLL toward the UPPER RIGHT (away from the viewer and to the RIGHT of the image). Pose 1: crouching, "
        "about to jump toward the upper right. Pose 2: diving toward the UPPER RIGHT with the arms stretched up and to the RIGHT. Pose 3: "
        "curled in a tight ball rolling. Pose 4: landing crouched on one knee, facing up-right. In ALL poses the body moves to the RIGHT "
        "side of the image, never to the left.")

def blk(out_stem, ch, d, style_stem, prompt):
    view, ref = VIEW[d]
    return (f"### `{out_stem}.png`\n- Imagen 1: `REF_{ch}/ref_{ch}_{ref}.png` · Imagen 2: `_entregas_runway/{src_name(style_stem)}`\n"
            f"```\n{prompt}\n```\n")

def prompt8(ch, d, equip, anim, extra, weapon=True):
    name, desc = CHARS[ch]; view, _ = VIEW[d]
    parts = [HEAD, f"Character ({name}): {desc}. The character is {view}.", equip, anim, SAME8] + extra
    if d in ("up", "up_right"):
        parts.append(BACK_RULE)
        if weapon: parts.append(HAND_RULE)
    return " ".join(parts)

sections = []
items = []
for ch, cls, key, d, anim, extra in REDO:
    stem = f"{ch}_{cls}_{key}_{d}"; style = f"{ch}_{cls}_{'parry' if key=='counter8' else 'ultimate'}_{d}"
    items.append((stem, blk(stem, ch, d, style, prompt8(ch, d, EQUIP[cls], anim, extra))))
sections.append(("A · Pendientes del pulido 3 (2 rechazadas + 1 [!])", "Imagen 2 = la hoja actual de esa clase/dirección.", items))
items = []
for ch, base, d in COMBOS:
    cls = base.split("_")[0]; stem = f"{ch}_{base}8_{d}"
    extra = [ERASER] if cls == "guerrero" else []
    items.append((stem, blk(stem, ch, d, f"{ch}_{base}_{d}", prompt8(ch, d, EQUIP[cls], ATTACK[base], extra))))
sections.append(("B · Combos J de 8 poses que faltan (mago y chain sin saltito; guerrero de espaldas de Wadrid)",
                 "Imagen 2 = el ataque actual de esa dirección (diseño, arma y tamaño a copiar).", items))
items = []
for ch in CHARS:
    name, desc = CHARS[ch]; view, _ = VIEW["up_right"]; stem = f"{ch}_roll_up_right"
    pr = " ".join([ROLL_HEAD, f"Character ({name}): {desc}. The character is seen from behind, turned toward the upper RIGHT.",
                   EQUIP["none"], ROLL, BACK_RULE.replace("ALL 8 poses", "ALL 4 poses"),
                   "Same scale and proportions as the second image, but the dive goes to the RIGHT (the second image goes to the left: mirror that direction)."])
    items.append((stem, blk(stem, ch, "up_right", f"{ch}_roll_up_right", pr)))
sections.append(("C · Rodar arriba-derecha (las actuales se lanzan hacia la izquierda)", "Formato 2x2 vertical 3:4, como las hojas de rodar originales.", items))

total = sum(len(x[2]) for x in sections)
out = [f"# PROMPTS DE PULIDO 4 ({total} hojas)\n",
       "Cada bloque: archivo a guardar, Imagen 1 (en `referencias_animacion/`), Imagen 2 (en `referencias_animacion/_entregas_runway/`) y el prompt.\n"]
for title, note, its in sections:
    out.append(f"\n## {title}\n{note}\n"); out += [b for _, b in its]
(REFD / "PROMPTS_PULIDO_4.md").write_text("\n".join(out), encoding="utf-8")
task = REFD / "GROKBOT_PULIDO_4.md"
if not task.exists():
    L = [f"# TAREA PARA GROKBOT — pulido 4 ({total} hojas)\n",
         "Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a esa carpeta).",
         "Procedimiento igual que `GROKBOT_PULIDO_3.md`. Prompts: `referencias_animacion/PROMPTS_PULIDO_4.md`.\n",
         "## Qué se pide",
         "- A: rehacer las 2 rechazadas del pulido 3 (faltaba el borrador) y reintentar la `[!]` (sin líneas de movimiento).",
         "- B: combos J de 8 poses en UNA imagen para las direcciones que faltan. Las hojas intermedias viejas de mago y chain hacían que el "
         "personaje \"saltara\" y cambiara de tamaño; con 8 poses del mismo dibujo el golpe queda fluido y estable.",
         "- C: rodar arriba-derecha bien orientado (que se lance hacia la DERECHA). Formato 2x2 vertical 3:4.\n",
         "## Reglas clave (además de la lista de control del pulido 3)",
         "- MISMAS PROPORCIONES que la Imagen 2: la cabeza NO debe salir más grande ni el cuerpo más corto (ChatGPT tiende a hacerlo más cabezón; si pasa, usa Gemini).",
         "- Mago y chain: de pie todo el combo, sin saltar ni agacharse.",
         "- Vistas de espaldas: sin cara/gafas/carnet y el arma en la mano derecha (lado derecho de la imagen). Si ChatGPT cambia de mano, Gemini.",
         "- Fondo menta liso #A0EFA5, sin sombra. Horizontal 3:2 para A y B; vertical 3:4 para C.",
         "- Conversación nueva por hoja, Imagen 1 y luego Imagen 2, prompt completo sin cambios. No uses nada de `_rechazadas/`.\n",
         "## Guardado",
         "`referencias_animacion/_entregas_runway/<nombre exacto>.png` (o .jpg). Marca `[x]` al guardar; `[!]` con nota si falla 2 veces. "
         "No toques código, `assets/`, `scenes/` ni `scripts/`. (Para Claude: al integrar C, quitar `roll_up_right` de MIRROR_SHEETS.)\n",
         "## Progreso"]
    for title, _, its in sections:
        L.append(f"\n### {title}"); L += [f"- [ ] `{stem}.png`" for stem, _ in its]
    L.append("\n## Notas de grokbot\n(resumen al terminar: herramienta usada en cada hoja y qué falló)\n")
    task.write_text("\n".join(L), encoding="utf-8")
print(total, "hojas")
