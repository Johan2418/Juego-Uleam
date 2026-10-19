"""Genera GROKBOT_BOSS_2.md y PROMPTS_BOSS_2.md (boss 2 B.S.O.D., Facultad de Ciencias de la Salud).
Uso: python tools/gen_prompts_boss2.py  (escribe en referencias_animacion/, o en OUT si se define)."""
import os
OUT = os.environ.get("OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "referencias_animacion"))

STYLE = ("2D pixel art game asset for a top-down 3/4 view action-RPG, 16-bit SNES style, crisp 1-pixel black outline, "
         "hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. "
         "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. ")
NOTEXT = ("No text, no letters, no numbers, no labels, no UI, no screens with writing, no frame borders, "
          "no motion lines, no speed lines, no glow halos, no particle effects, no small human characters, no blood.")
BOSS = ("The boss is called B.S.O.D.: a huge, tall and slim malfunctioning HOSPITAL SURGEON ROBOT, a little creepy but not gory. "
        "Bottom: a white HOSPITAL GURNEY base with four small black caster wheels and a white sheet hanging from it; the robot body rises out of the gurney. "
        "Body: a slim upright torso of white and surgical teal-green plastic panels, a red cross on the left shoulder plate, a grey stethoscope hanging around the neck, "
        "and two clear IV fluid bags hanging from a metal pole on its back. "
        "Center of the chest: a glass RIBCAGE window with a red MECHANICAL HEART inside (metal heart with tubes coming out of it). "
        "Head: an old boxy medical VITAL-SIGNS MONITOR wearing a teal surgical cap, a white surgical face mask over the lower part of the screen, "
        "and a round silver doctor's head mirror on the cap; the screen is plain dark (no text, no lines). "
        "Behind the head: a small glass jar with a pink brain inside, fixed to its back. "
        "On the LEFT side of the image: a long thin robotic SURGICAL ARM ending in a glowing red laser SCALPEL blade. "
        "On the RIGHT side of the image: a thicker robotic MULTI-TOOL arm ending in a GIANT SYRINGE. "
        "Colors: white, light grey, surgical teal-green, red accents. The silhouette is TALL and SLIM, about twice as tall as wide. ")
SAME = ("STYLE RULE: copy ONLY the pixel size, outline thickness, shading style and level of detail of the boss in the second attached image; "
        "do NOT copy its design, shapes or colors (it is a different boss). ")
PARTS = ("EXPLODED PARTS RULE: copy the EXACT design, palette, pixel size and scale of the boss in the first attached image. "
         "Draw each listed item SEPARATELY, not touching and not connected to anything else, complete (also draw the parts that were hidden behind other parts, "
         "for example the full round shoulder joint), all in the SAME scale as the first image and the SAME three-quarter FRONT view. "
         "Lots of empty space between items, wide margin, nothing touching the image edges. ")
SMALL = "Copy the pixel size, outline and palette style of the first attached image (it is ONLY a style reference). "

def grid(n, cols, rows):
    return (f"Exactly {n} items in ONE image, arranged in a grid of {cols} columns and {rows} rows "
            f"(read left to right, top row first), evenly spaced. ")

FULL = "`_entregas_runway/bosses/boss_bsod_full.png`"
B1 = "`_entregas_runway/bosses/boss_0xdeadbeef_full.png`"
STUDENT = "`_entregas_runway/wadrid_idle_down.png`"

TASKS = [
 ("A", "boss_bsod_full.png", STUDENT, B1,
  STYLE + BOSS + SAME +
  "Draw ONE single big pose of the whole boss assembled, centered, in a three-quarter FRONT view facing the viewer, standing still on its gurney, "
  "arms slightly apart from the body. The boss is about 3 times as tall as the student in the first attached image "
  "(the first image is ONLY a size and style reference: do NOT draw the student). Square image (1:1). " + NOTEXT,
  "Primera y más importante: las demás hojas copian esta. No hay imagen de referencia del diseño: revisar con Johan antes de seguir. Repetir si sale con texto, sangre o humanos pequeños."),
 ("B", "boss_bsod_body.png", FULL, B1,
  STYLE + PARTS + grid(2, 2, 1) +
  "Item 1: the GURNEY BASE and TORSO only: NO arms, NO head, NO heart (leave an empty dark ribcage window in the chest and empty round shoulder sockets), "
  "with the IV bags pole and the stethoscope. "
  "Item 2: the SAME gurney and torso damaged: cracked panels, dirty stains, one IV bag torn and empty, a bent wheel (no blood, no sparks, no smoke). Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_bsod_heart.png", FULL, B1,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the glass RIBCAGE window with the red mechanical heart inside, seen from the front. "
  "Item 1: ribcage closed, heart normal. "
  "Item 2: the SAME ribcage OPEN: the glass ribs swung apart to both sides, the heart glowing bright red-orange and slightly bigger (it is the weak point). "
  "Item 3: the SAME ribcage BROKEN: glass shattered, the heart dark grey and stopped. Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_bsod_head.png", FULL, B1,
  STYLE + PARTS + grid(4, 2, 2) +
  "Item 1: the monitor head with surgical cap, face mask and head mirror, screen plain black. "
  "Item 2: the SAME head WITHOUT the face mask (the mask fell off), screen plain black. "
  "Item 3: the SAME head without mask, cracked screen corner and the cap torn, screen plain black. "
  "Item 4: ONLY the small glass jar with the pink brain inside. Square image (1:1). " + NOTEXT,
  "Las pantallas deben salir negras lisas: el electrocardiograma y las caras se dibujan por código."),
 ("B", "boss_bsod_scalpel.png", FULL, B1,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the thin SURGICAL ARM alone (the arm on the LEFT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the tool at the bottom. "
  "Item 1: laser scalpel blade OFF (short metal tip). Item 2: laser scalpel blade ON, a long red blade. Item 3: a small rotating saw instead of the blade. "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Rectos hacia abajo y del mismo largo: el código los gira desde el hombro (igual que la garra del boss 1)."),
 ("B", "boss_bsod_tool.png", FULL, B1,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the thick MULTI-TOOL ARM alone (the arm on the RIGHT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the tool at the bottom. "
  "Item 1: ending in the GIANT SYRINGE full of red liquid. Item 2: ending in a big DENTAL DRILL. Item 3: ending in a three-finger metal GRABBER pincer. "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Igual: rectos hacia abajo y del mismo largo."),
 ("C", "boss_bsod_projectiles.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Small projectiles, each about the size of the student's head in the second image (do NOT draw the student): "
  "1 a flying syringe pointing RIGHT, 2 a red blood-test tube, 3 a blue test tube, 4 a yellow test tube, 5 a round petri dish with green bacteria, "
  "6 a big teal therapy exercise ball, 7 a wooden toy puzzle block, 8 a flat colorful liquid puddle seen from above (flat oval on the ground). Landscape image (3:2). " + NOTEXT,
  "Jeringas, tubos de laboratorio, placa de Petri, pelota de terapia, bloque de rompecabezas y charco."),
 ("C", "boss_bsod_food.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Food items, each small (about the size of the student's head in the second image; do NOT draw the student). "
  "Top row, HEALTHY food: 1 a red apple, 2 a carrot, 3 a broccoli, 4 a banana. "
  "Bottom row, JUNK food: 5 a hamburger, 6 a soda cup with a straw, 7 french fries in a red box, 8 a pink donut. Landscape image (3:2). " + NOTEXT,
  "Para la pirámide alimenticia: arriba la comida sana (cura), abajo la chatarra (daña)."),
 ("C", "boss_bsod_bacteria.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "A small round BACTERIA enemy (a cute but angry green blob with little cilia hairs, two eyes and a small mouth), about half as tall as the student in the second image "
  "(do NOT draw the student). "
  "Items 1-2: idle, squishing up and down. Item 3: squashed flat (about to jump). Item 4: stretched tall in the air (jumping). Item 5: landing. "
  "Item 6: hit, flinching. Item 7: splitting in two halves. Item 8: popped, a small flat green splat. Same scale in all 8, bottom on the same baseline per row. Landscape image (3:2). " + NOTEXT,
  "Esbirros que salen de la placa de Petri; se dividen al primer golpe."),
 ("C", "boss_bsod_debris.png", FULL, B1,
  STYLE + SMALL + grid(8, 4, 2) +
  "Small loose pieces for the boss death: 1 a roll of white bandage, 2 a small empty syringe, 3 a broken test tube, 4 a white plastic panel piece with a red cross, "
  "5 a caster wheel, 6 a short broken grey tube, 7 a surgical face mask, 8 a small pill capsule (half red, half white). Landscape image (3:2). " + NOTEXT,
  "Pedazos que salen volando al morir."),
]

md_t = ["# TAREA PARA GROKBOT — Boss 2: B.S.O.D. (10 hojas)", "",
"Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a `referencias_animacion/`).",
"Prompts: `referencias_animacion/PROMPTS_BOSS_2.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/af1330c1-50d1-45a8-9e11-805d2cccb65f", "",
"## Qué se pide",
"El segundo boss, de la Facultad de Ciencias de la Salud: un robot cirujano. Se anima POR PIEZAS en el juego, igual que el boss 1: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.",
"- A: el boss completo (1 hoja). **Hacerla primero y avisar a Johan**: no hay imagen de referencia, así que esta define el diseño. Las de B y C usan esta como Imagen 1.",
"- B: piezas sueltas del boss (5 hojas).",
"- C: proyectiles, comida, esbirro y pedazos (4 hojas).", "",
"## Reglas clave",
"- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.",
"- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.",
"- SIN TEXTO en ningún lado (ni en el monitor). Sin humanos pequeños. Sin sangre.",
"- En la hoja A, el boss 1 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.",
"- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.",
"- Los brazos (scalpel y tool) rectos hacia abajo, con el hombro arriba, mismo largo en las 3 poses.",
"- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.", "",
"## Guardado",
"`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.", "",
"## Progreso", ""]
md_p = ["# PROMPTS BOSS 2: B.S.O.D. (10 hojas)", "",
"Cada bloque: archivo a guardar en `_entregas_runway/bosses/`, Imagen 1 e Imagen 2 (rutas dentro de `referencias_animacion/`) y el prompt.", ""]
sec_names = {"A": "A · Boss completo (hacer primero)", "B": "B · Piezas sueltas del boss", "C": "C · Proyectiles, comida, esbirro y pedazos"}
last = None
for sec, name, i1, i2, prompt, note in TASKS:
    if sec != last:
        md_t += ["", f"### {sec_names[sec]}"]
        md_p += ["", f"## {sec_names[sec]}", ""]
        last = sec
    md_t.append(f"- [ ] `{name}`" + (f" — {note}" if note else ""))
    md_p += [f"### `{name}`", f"- Imagen 1: {i1} · Imagen 2: {i2}" + (f" ({note})" if note else ""), "```", prompt, "```", ""]
md_t += ["", "## Notas de grokbot", "(resumen al terminar: herramienta usada en cada hoja y qué falló)", ""]
open(os.path.join(OUT, "GROKBOT_BOSS_2.md"), "w", encoding="utf-8").write("\n".join(md_t))
open(os.path.join(OUT, "PROMPTS_BOSS_2.md"), "w", encoding="utf-8").write("\n".join(md_p))
print("ok")
