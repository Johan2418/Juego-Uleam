#!/usr/bin/env python3
"""Genera referencias_animacion/PROMPTS_TECNICAS.md y GROKBOT_TECNICAS.md:
 A) 6 retratos detallados para el menú del personaje (2 personajes x 3 clases)
 B) 18 hojas de 8 poses para las ultimates de los bosses (Desfibrilador, Push/Pop, Corte comercial),
    2 personajes x 3 direcciones, con el arma A LA ESPALDA para que sirvan a las 3 clases.
Uso: python3 tools/gen_prompts_tecnicas.py   (no pisa el progreso de GROKBOT_TECNICAS.md si ya existe)
Integración: los retratos van recortados a assets/sprites/portraits/<personaje>_<clase>.png (tools/process_portraits.py);
las hojas B se cortan con tools/slice_character_sheets.py (ya conoce tech_*8) y el juego las usa solas.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFD = ROOT / "referencias_animacion"
CLASSES = ["guerrero", "mago", "chain"]
CLASS_ES = {"guerrero": "Guerrero", "mago": "Mago", "chain": "Chain"}

CHARS = {
    "wadrid": ("Wadrid", "big curly dark brown afro, black rectangular glasses, warm medium-brown skin, "
               "dark green polo, blue lanyard with grey ID card on the chest, blue jeans, brown shoes"),
    "marlonx_a": ("MarlonX-a", "short straight black hair, black rectangular glasses, light-brown skin, "
                  "charcoal dark grey polo with small gold badge, blue lanyard with light ID card on the chest, blue jeans, black shoes"),
}
EQUIP = {
    "guerrero": "long wooden school ruler (light yellow wood, black tick marks) held like a sword in the RIGHT hand, and a big pink "
                "rubber eraser STRAPPED to the LEFT forearm like a buckler",
    "mago": "gnarled wooden branch staff about body height with a small glowing blue crystal on top, held in the RIGHT hand",
    "chain": "ONE black phone charger cable used as a whip, held by the plug end in the RIGHT hand, a few loops hanging",
}
POSE = {
    "guerrero": "heroic battle-ready stance: feet apart, ruler raised diagonally in front, eraser buckler up, confident smile",
    "mago": "spell-casting stance: staff held up beside him, free left hand open with a few tiny blue sparkle pixels around the crystal, "
            "calm focused smile",
    "chain": "agile stance: slight crouch, cable swinging in a loose loop at his side (inside the image), smirking",
}

PORTRAIT = ("High-detail 2D PIXEL ART character portrait of the character in the first attached image, for a character selection "
            "menu. Same character, same outfit and colors as the first image, and the same pixel art look as the second attached "
            "image but MUCH more detailed: a large sprite about 220 pixels tall drawn with real hard square pixels, crisp 1-pixel "
            "dark outline, limited palette (about 48 colors), clean pixel shading with 3 tones per material, no anti-aliasing, "
            "no blur, no painterly brush strokes, no gradients, no realistic rendering. Full body, three-quarter FRONT view "
            "(turned slightly toward the right), standing on nothing, chibi proportions but less chibi than the in-game sprite "
            "(head about one quarter of the total height). Flat solid mint green background (#A0EFA5) everywhere, no ground, "
            "no shadow, no scenery, no frame, no text, no logo. Portrait image (3:4) with the whole character centered and a "
            "wide empty margin on every side; nothing touches the image edges.")

HEAD8 = ("2D pixel art SPRITE SHEET of the character in the first attached image, top-down 3/4 view action-RPG, 16-bit SNES style, "
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
             "the polo and the back of the jeans. NO face, NO eyes, NO glasses, NO ID card visible.")
STOWED = ("WEAPON RULE: EMPTY HANDS in all 8 poses (no ruler, no staff, no cable, no eraser, no weapon of any kind). "
          "Do NOT draw any effect: no electricity, no blocks, no TV, no sparks, no glow; the game draws the effects.")
VIEW = {
    "down": ("FACING THE VIEWER in ALL 8 poses (front view)", "abajo_frente"),
    "up": ("seen FROM BEHIND in ALL 8 poses", "arriba_espalda"),
    "right": ("seen from the side facing RIGHT in ALL 8 poses (strict side profile)", "derecha_lado"),
}
TECH = {
    "desfibrilador": ("Desfibrilador (B.S.O.D.)",
        "Animation: 8-frame DEFIBRILLATOR SHOCK. Pose 1: normal standing pose. Pose 2: rubbing both palms together quickly in front "
        "of the chest. Pose 3: pulling both hands apart, elbows out, charging. Pose 4: both hands raised high above the head, palms "
        "facing each other, body tense. Pose 5: slamming both palms down and forward at waist height, knees bent, shouting. "
        "Pose 6: hold the slam, hair and polo pushed back by the blast. Pose 7: straightening up, shaking the hands. "
        "Pose 8: normal standing pose."),
    "pushpop": ("Push / Pop (STACK OVERFLOW)",
        "Animation: 8-frame SUMMON FROM ABOVE (commanding falling crates). Pose 1: normal standing pose. Pose 2: right arm raised "
        "straight up, index finger pointing to the sky. Pose 3: hold, left hand on the hip. Pose 4: right arm swings down pointing "
        "forward and down at the ground ahead (\"push\"). Pose 5: right arm raised up again. Pose 6: both arms swing down hard pointing "
        "at the ground ahead (\"pop\"), leaning forward. Pose 7: straightening up, satisfied. Pose 8: normal standing pose."),
    "comercial": ("Corte comercial (KERNEL PANIC)",
        "Animation: 8-frame TV PRESENTER \"WE'LL BE RIGHT BACK\". Pose 1: normal standing pose. Pose 2: one hand raised like a "
        "host presenting, big smile. Pose 3: both hands making a \"T\" (time-out) sign in front of the chest. Pose 4: hold the time-out "
        "sign, leaning slightly. Pose 5: a showy bow, one arm across the waist. Pose 6: coming up from the bow with a wink and a "
        "thumbs-up. Pose 7: pointing at the viewer with both index fingers. Pose 8: normal standing pose."),
}


def portrait_block(ch: str, cls: str) -> str:
    name, look = CHARS[ch]
    prompt = (f"{PORTRAIT} Character ({name}): {look}. Class: {CLASS_ES[cls]}. Equipment: {EQUIP[cls]}. "
              f"Pose: {POSE[cls]}. Keep the glasses as thin rectangular frames with the eyes visible. "
              f"Exactly ONE character, no copies, no extra weapons.")
    return "\n".join([
        f"### `portrait_{ch}_{cls}.png`",
        f"- Imagen 1: `REF_{ch}/ref_{ch}_abajo_frente.png` · Imagen 2: `_entregas_runway/{ch}_{cls}_special8_down.png`",
        "- Formato: vertical 3:4",
        "```", prompt, "```", ""])


def tech_block(ch: str, tid: str, d: str) -> str:
    name, look = CHARS[ch]
    view, ref = VIEW[d]
    parts = [HEAD8, f"Character ({name}): {look}. The character is {view}.", STOWED, TECH[tid][1], SAME]
    if d == "up":
        parts.insert(2, BACK_RULE)
    return "\n".join([
        f"### `{ch}_tech_{tid}8_{d}.png`",
        f"- Imagen 1: `REF_{ch}/ref_{ch}_{ref}.png` · Imagen 2: `_entregas_runway/{ch}_walk8_{d}.png`",
        "- Formato: horizontal 3:2",
        "```", " ".join(parts), "```", ""])


def main() -> None:
    out = ["# PROMPTS DE TÉCNICAS Y RETRATOS (24 hojas)", "",
           "Cada bloque: archivo a guardar, Imagen 1 (en `referencias_animacion/`), Imagen 2 (en "
           "`referencias_animacion/_entregas_runway/`) y el prompt.", "",
           "## A · Retratos detallados para el menú del personaje (6)",
           "Una sola pose grande por imagen. Vertical 3:4.", ""]
    items_a, items_b = [], []
    for ch in CHARS:
        for cls in CLASSES:
            out.append(portrait_block(ch, cls))
            items_a.append(f"portrait_{ch}_{cls}.png")
    out += ["## B · Ultimates de los bosses (18)",
            "8 poses en 4x2, MANOS VACÍAS (el arma no se dibuja) para que la misma hoja sirva a las 3 clases. "
            "Sin efectos: el juego dibuja la electricidad, los bloques y la pantalla de ajuste.", ""]
    for tid in TECH:
        out.append(f"#### {TECH[tid][0]}")
        for ch in CHARS:
            for d in VIEW:
                out.append(tech_block(ch, tid, d))
                items_b.append(f"{ch}_tech_{tid}8_{d}.png")
    (REFD / "PROMPTS_TECNICAS.md").write_text("\n".join(out), encoding="utf-8")

    task = REFD / "GROKBOT_TECNICAS.md"
    if task.exists():
        print("GROKBOT_TECNICAS.md ya existe: no se pisa el progreso")
        return
    L = ["# TAREA PARA GROKBOT — retratos del menú y ultimates de los bosses (24 hojas)", "",
         "Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a esa carpeta).",
         "Procedimiento igual que `GROKBOT_PULIDO_4.md`. Prompts: `referencias_animacion/PROMPTS_TECNICAS.md`.", "",
         "## Qué se pide",
         "- A: 6 retratos detallados (uno por personaje y clase) para el nuevo menú del personaje. Una sola pose grande, "
         "más detallada que el sprite del juego pero con la misma ropa, colores y estilo pixel art.",
         "- B: 18 hojas de 8 poses para las 3 ultimates que se consiguen al vencer bosses, en 3 direcciones (frente, espalda, "
         "derecha). Con las MANOS VACÍAS: así una sola hoja sirve para Guerrero, Mago y Chain.", "",
         "## Reglas clave",
         "- Fondo menta liso #A0EFA5, sin sombra ni suelo. A: vertical 3:4. B: horizontal 3:2.",
         "- MISMAS PROPORCIONES que la Imagen 2 en B (la cabeza no más grande, el cuerpo no más corto). Si ChatGPT lo hace "
         "más cabezón, usa Gemini.",
         "- A: pixel art de verdad (píxeles cuadrados, contorno de 1 px), NO ilustración pintada ni borrosa. Las gafas son "
         "finas y se ven los ojos. El arma de la clase en la mano DERECHA.",
         "- B: sin arma y sin efectos (ni rayos, ni bloques, ni televisores). Vista de espaldas: sin cara, gafas ni carnet.",
         "- Conversación nueva por hoja, Imagen 1 y luego Imagen 2, prompt completo sin cambios. No uses nada de `_rechazadas/`.", "",
         "## Guardado",
         "`referencias_animacion/_entregas_runway/<nombre exacto>.png` (o .jpg). Marca `[x]` al guardar; `[!]` con nota si "
         "falla 2 veces. No toques código, `assets/`, `scenes/` ni `scripts/`.", "",
         "## Progreso", "", "### A · Retratos (6)"]
    L += [f"- [ ] `{n}`" for n in items_a]
    L += ["", "### B · Ultimates de los bosses (18)"]
    L += [f"- [ ] `{n}`" for n in items_b]
    L += ["", "## Notas de grokbot", "(resumen al terminar: herramienta usada en cada hoja y qué falló)", ""]
    task.write_text("\n".join(L), encoding="utf-8")
    print("listo:", len(items_a) + len(items_b), "hojas")


if __name__ == "__main__":
    main()
