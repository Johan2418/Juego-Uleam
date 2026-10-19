#!/usr/bin/env python3
"""Genera referencias_animacion/PROMPTS_PULIDO.md y referencias_animacion/GROKBOT_PULIDO.md
(tarea de pulido de sprites para grokbot). Uso: python3 tools/gen_prompts_pulido.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFD = ROOT / "referencias_animacion"
SRC = REFD / "_entregas_runway"

CHARS = {
    "wadrid": ("Wadrid", "big curly dark brown afro, black rectangular glasses, warm medium-brown skin, "
               "dark green polo, blue lanyard with grey ID, blue jeans, brown shoes"),
    "marlonx_a": ("MarlonX-a", "short straight black hair, black rectangular glasses, light-brown skin, "
                  "charcoal dark grey polo with small gold badge, blue lanyard with light ID, blue jeans, black shoes"),
}
EQUIP = {
    "guerrero": "Equipment: long wooden school ruler (light yellow wood, black tick marks) held like a sword in the RIGHT hand only; "
                "big pink rubber eraser STRAPPED to the LEFT forearm like a buckler, never floating.",
    "mago": "Equipment: gnarled wooden branch staff about body height with a small glowing blue crystal on top, held in the RIGHT hand. "
            "Do NOT draw any orb, projectile or magic effect.",
    "chain": "Equipment: black phone charger cable used as a whip, held by the plug end in the RIGHT hand.",
    "none": "Empty hands, no weapon.",
}
VIEW = {
    "right": ("The character is seen from the side facing RIGHT in ALL poses (strict side profile), acting toward the right.",
              "derecha_lado"),
    "down": ("The character FACES THE VIEWER in ALL poses (front view), acting toward the camera.", "abajo_frente"),
    "up": ("The character is seen from BEHIND in ALL poses, acting away from the camera; the face is not visible and "
           "the ID card is NOT visible (it hangs on the chest).", "arriba_espalda"),
    "down_right": ("The character is shown in a three-quarter FRONT view turned 45 degrees toward the RIGHT (facing down-right) "
                   "in ALL poses, acting toward the lower right.", "abajo_frente"),
    "up_right": ("The character is shown in a three-quarter BACK view turned 45 degrees toward the RIGHT (facing up-right) "
                 "in ALL poses, acting toward the upper right; the face is mostly hidden and the ID card is NOT visible.",
                 "arriba_espalda"),
}
HEAD = ("2D pixel art character sheet of the character in the first attached image, top-down 3/4 view action-RPG, "
        "16-bit SNES style, chibi proportions, crisp 1-pixel black outline, hard pixels, no anti-aliasing, no blur. "
        "Drawn in EXACTLY the same pixel art style, proportions, head size and body size as the second attached image. "
        "Flat solid mint green background (#A0EFA5). Exactly 4 full-body poses of the SAME character arranged in a 2x2 grid "
        "with lots of empty space between them, wide empty margin, nothing touching the image edges.")
TAIL = ("IMPORTANT: keep EXACTLY the same character design, head size, body width, height, hair color and skin color "
        "as the second attached image. All 4 poses must have the same scale. No effects, no motion lines, no text.")
DIRS4 = ["right", "down", "up"]
DIAG = ["down_right", "up_right"]
ACTIONS = ["roll", "guerrero_attack", "guerrero_finisher", "guerrero_special", "guerrero_parry", "guerrero_ultimate",
           "mago_cast", "mago_finisher", "mago_special", "mago_parry", "mago_ultimate",
           "chain_whip", "chain_finisher", "chain_special", "chain_parry", "chain_ultimate", "hurt"]
ATTACKS = ["guerrero_attack", "mago_cast", "chain_whip"]


def equip_for(anim: str) -> str:
    for k in ("guerrero", "mago", "chain"):
        if anim.startswith(k):
            return EQUIP[k]
    return EQUIP["none"]


def src_name(stem: str) -> str:
    """Nombre real (con extensión) de una hoja ya entregada, o .png si todavía no existe."""
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        if (SRC / f"{stem}{ext}").exists():
            return f"{stem}{ext}"
    return f"{stem}.png (se genera antes en esta misma tarea)"


def block(ch, d, out_stem, style_stem, anim_text, equip):
    name, desc = CHARS[ch]
    view, ref = VIEW[d]
    prompt = " ".join([HEAD, f"Character ({name}): {desc}.", view, equip, anim_text, TAIL])
    return (f"### `{out_stem}.png`\n"
            f"- Imagen 1: `REF_{ch}/ref_{ch}_{ref}.png` · Imagen 2: `_entregas_runway/{src_name(style_stem)}`\n"
            f"```\n{prompt}\n```\n")


sections = []   # (titulo, explicacion, [bloques], [nombres])


def add(title, note, items):
    sections.append((title, note, items))


# F1 — caminata a 8 frames: poses intermedias
items = []
for ch in CHARS:
    for d in ["down", "up", "right", "down_right", "up_right"]:
        txt = ("Animation: IN-BETWEEN frames of the 4-frame walk cycle shown in the second image (same direction, same arm swing). "
               "Pose 1 (top-left): halfway between walk pose 1 (left foot forward) and pose 2 (passing), back foot lifting. "
               "Pose 2 (top-right): halfway between pose 2 (passing) and pose 3 (right foot forward), right leg reaching forward. "
               "Pose 3 (bottom-left): halfway between pose 3 (right foot forward) and pose 4 (passing), back foot lifting. "
               "Pose 4 (bottom-right): halfway between pose 4 (passing) and pose 1 (left foot forward), left leg reaching forward.")
        items.append((f"{ch}_walk_b_{d}", block(ch, d, f"{ch}_walk_b_{d}", f"{ch}_walk_{d}", txt, EQUIP["none"])))
add("F1 · Caminata con 8 frames (poses intermedias)",
    "Imagen 2 = la hoja de caminata actual de esa dirección. El juego intercala: caminata 1, intermedia 1, caminata 2, intermedia 2…",
    items)

# F2 — combo J con 4 frames por golpe
items = []
for ch in CHARS:
    for base in ATTACKS:
        for d in DIRS4:
            txt = ("Animation: IN-BETWEEN frames of the attack shown in the second image (same weapon, same direction). "
                   "Pose 1 (top-left): halfway between its pose 1 (wind-up) and pose 2 (strike), weapon in mid-swing. "
                   "Pose 2 (top-right): follow-through right after its pose 2, arm fully extended, weapon past the target. "
                   "Pose 3 (bottom-left): halfway between its pose 3 and pose 4, second swing in mid-motion. "
                   "Pose 4 (bottom-right): recovering from its pose 4 back to a ready stance.")
            items.append((f"{ch}_{base}_b_{d}", block(ch, d, f"{ch}_{base}_b_{d}", f"{ch}_{base}_{d}", txt, equip_for(base))))
add("F2 · Combo J con 4 frames por golpe",
    "Imagen 2 = la hoja de ataque actual de esa dirección. Golpe 1 = ataque 1, intermedia 1, ataque 2, intermedia 2; golpe 2 = lo mismo con 3-4.",
    items)

# F3 — torbellino de chain en bucle + reposo animado
items = []
for ch in CHARS:
    for d in DIRS4:
        txt = ("Animation: LOOPING CABLE WHIRLWIND, 4 frames of one continuous spin. The character stands in the SAME wide stance, "
               "at the SAME height and size in all 4 poses, arm swinging the cable in a wide horizontal ring around the waist. "
               "Pose 1 (top-left): cable ring in front of the body. Pose 2 (top-right): cable swung to the character's right side. "
               "Pose 3 (bottom-left): cable passing behind the body. Pose 4 (bottom-right): cable swung to the character's left side. "
               "Feet planted, no jumping, the loop must repeat smoothly from pose 4 to pose 1.")
        items.append((f"{ch}_chain_ultimate_spin_{d}",
                      block(ch, d, f"{ch}_chain_ultimate_spin_{d}", f"{ch}_chain_ultimate_{d}", txt, EQUIP["chain"])))
for ch in CHARS:
    for d in ["down", "up", "right", "down_right", "up_right"]:
        txt = ("Animation: IDLE BREATHING loop, standing relaxed in place, arms at the sides, feet together as in the second image. "
               "Pose 1 (top-left): neutral standing. Pose 2 (top-right): inhaling, chest and shoulders raised very slightly. "
               "Pose 3 (bottom-left): neutral standing, eyes closed in a blink (if the face is visible) or head tilted a tiny bit. "
               "Pose 4 (bottom-right): exhaling, shoulders slightly lowered. Very subtle differences, same size and position.")
        items.append((f"{ch}_idle_anim_{d}", block(ch, d, f"{ch}_idle_anim_{d}", f"{ch}_walk_{d}", txt, EQUIP["none"])))
add("F3 · Torbellino de chain en bucle + reposo animado",
    "Torbellino: Imagen 2 = la ultimate de chain actual (para el estilo y el cable). Reposo: Imagen 2 = la caminata de esa dirección.",
    items)

# F4 — diagonales de todas las acciones
items = []
for ch in CHARS:
    for anim in ACTIONS:
        for d in DIAG:
            style = f"{ch}_{anim}_{'down' if d == 'down_right' else 'up'}"
            txt = ("Animation: the SAME 4 poses, in the SAME order and with the same timing and weapon positions, as the second image, "
                   "but with the character turned 45 degrees as described above. "
                   + ("Empty hands." if anim in ("roll", "hurt") else ""))
            items.append((f"{ch}_{anim}_{d}", block(ch, d, f"{ch}_{anim}_{d}", style, txt, equip_for(anim))))
add("F4 · Diagonales de todas las acciones",
    "Imagen 2 = la misma animación mirando abajo (para `_down_right`) o arriba (para `_up_right`). El juego las espeja para izquierda.",
    items)

# F5 — extras diagonales (dependen de F4)
items = []
for ch in CHARS:
    for base in ATTACKS:
        for d in DIAG:
            txt = ("Animation: IN-BETWEEN frames of the attack shown in the second image (same weapon, same direction). "
                   "Pose 1 (top-left): halfway between its pose 1 (wind-up) and pose 2 (strike), weapon in mid-swing. "
                   "Pose 2 (top-right): follow-through right after its pose 2, arm fully extended. "
                   "Pose 3 (bottom-left): halfway between its pose 3 and pose 4, second swing in mid-motion. "
                   "Pose 4 (bottom-right): recovering from its pose 4 back to a ready stance.")
            items.append((f"{ch}_{base}_b_{d}", block(ch, d, f"{ch}_{base}_b_{d}", f"{ch}_{base}_{d}", txt, equip_for(base))))
    for d in DIAG:
        txt = ("Animation: LOOPING CABLE WHIRLWIND, 4 frames of one continuous spin, same wide stance, SAME height and size in all "
               "4 poses, cable in a wide horizontal ring around the waist. Pose 1: ring in front. Pose 2: cable to the right side. "
               "Pose 3: cable behind the body. Pose 4: cable to the left side. Feet planted, smooth loop.")
        items.append((f"{ch}_chain_ultimate_spin_{d}",
                      block(ch, d, f"{ch}_chain_ultimate_spin_{d}", f"{ch}_chain_ultimate_{d}", txt, EQUIP["chain"])))
add("F5 · Extras diagonales (hacer después de F4)",
    "Imagen 2 = la hoja diagonal generada en F4 (ataque) o la ultimate de chain diagonal.", items)

# ---- escribir PROMPTS_PULIDO.md
total = sum(len(s[2]) for s in sections)
out = [f"# PROMPTS DE PULIDO — {total} hojas (generado por tools/gen_prompts_pulido.py)\n",
       "Cada bloque: nombre de archivo a guardar, Imagen 1 (referencia del personaje, en `referencias_animacion/`), "
       "Imagen 2 (hoja ya existente, en `referencias_animacion/_entregas_runway/`) y el prompt (copiar tal cual).\n"]
for title, note, items in sections:
    out.append(f"\n## {title}\n{note}\n")
    out += [b for _, b in items]
(REFD / "PROMPTS_PULIDO.md").write_text("\n".join(out), encoding="utf-8")

# ---- escribir GROKBOT_PULIDO.md (sin pisar el progreso si ya existe)
task = REFD / "GROKBOT_PULIDO.md"
done = set()
if task.exists():
    for line in task.read_text(encoding="utf-8").splitlines():
        if line.startswith("- [x]") or line.startswith("- [!]"):
            done.add(line.split("`")[1].replace(".png", ""))
lines = [f"# TAREA PARA GROKBOT — pulido de sprites ({total} hojas)\n",
         "Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a esa carpeta).",
         "Mismo procedimiento y lista de control que `referencias_animacion/GROKBOT_TAREA.md` (léelo primero), con estas reglas:\n",
         "## Cómo trabajar",
         "1. Sigue el orden de las fases (F1 → F5). F5 usa hojas que se generan en F4.",
         "2. Para cada hoja pendiente, busca su bloque en `referencias_animacion/PROMPTS_PULIDO.md` por el nombre de archivo.",
         "3. En Gemini, en una conversación NUEVA, adjunta Imagen 1 y luego Imagen 2 del bloque y pega el prompt completo, sin cambios. Proporción vertical 3:4.",
         "4. Revisa el resultado (lista de control abajo). Si falla, regenera una vez. Si vuelve a fallar, marca `[!]` con una nota corta y sigue.",
         "5. Guarda en `referencias_animacion/_entregas_runway/<nombre>.png` (o `.jpg` si Gemini solo da jpg), con el nombre EXACTO del bloque.",
         "6. Marca `[x]` aquí al guardar cada hoja (así se puede retomar si se corta).",
         "7. No toques código, `assets/`, `scenes/` ni `scripts/`. No sobrescribas hojas que no estén en esta lista.\n",
         "## Lista de control (además de la de GROKBOT_TAREA.md)",
         "- El personaje es IDÉNTICO al de la Imagen 2: mismo tamaño de cabeza, mismo alto y grosor, mismo pelo y piel.",
         "- Las 4 poses tienen el MISMO tamaño entre sí (no una más alta o más grande que las otras).",
         "- Vista correcta: `_right` perfil; `_down` de frente; `_up` de espaldas sin carnet; `_down_right` 3/4 de frente girado a la derecha; `_up_right` 3/4 de espaldas girado a la derecha.",
         "- Hojas \"intermedias\" (`_b_`): las poses deben quedar ENTRE las de la Imagen 2, no repetirlas.",
         "- Torbellino (`chain_ultimate_spin`): mismo pie y misma postura en las 4 poses; solo gira el cable.\n",
         "## Progreso",
         "Leyenda: `[ ]` pendiente · `[x]` hecha · `[!]` falló 2 veces (con nota)\n"]
for title, _, items in sections:
    lines.append(f"\n### {title}")
    for stem, _ in items:
        mark = "x" if stem in done else " "
        lines.append(f"- [{mark}] `{stem}.png`")
lines.append("\n## Notas de grokbot\n(escribe aquí el resumen al terminar o si paras a mitad)\n")
if not task.exists():
    task.write_text("\n".join(lines), encoding="utf-8")
print(total, "hojas")
