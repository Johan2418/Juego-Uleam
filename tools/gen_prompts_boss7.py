"""Genera GROKBOT_BOSS_7.md y PROMPTS_BOSS_7.md (boss 7 MISSING TEXTURE, Facultad de Artes, Humanidades y Patrimonio).
Uso: python tools/gen_prompts_boss7.py  (escribe en referencias_animacion/, o en OUT si se define)."""
import os
OUT = os.environ.get("OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "referencias_animacion"))

STYLE = ("2D pixel art game asset for a top-down 3/4 view action-RPG, 16-bit SNES style, crisp 1-pixel black outline, "
         "hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. "
         "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. ")
NOTEXT = ("No text, no letters, no numbers, no labels, no UI, no screens with writing, no frame borders, "
          "no motion lines, no speed lines, no glow halos, no particle effects, no small human characters, no blood.")
BOSS = ("The boss is called MISSING TEXTURE: a huge, heavy and intimidating living MARBLE STATUE that escaped from a museum, not cute. "
        "It is a classical Greek-style sculpture: white marble with grey veins, bronze and old-gold details. "
        "Bottom: a big square stone MUSEUM PEDESTAL with a blank bronze plaque on the front (no letters) and two golden posts with a red velvet museum rope; "
        "the statue's thick marble legs rise out of the pedestal. "
        "Body: a muscular marble statue torso with a marble toga draped across; in the middle of the chest an ornate GOLDEN PICTURE FRAME covered by a marble plate (the core). "
        "Head: a classical statue head with a golden LAUREL CROWN and a calm marble MASK face with two narrow glowing cyan eye slits; behind the head an ornate golden museum frame like a halo. "
        "On the LEFT side of the image: a marble arm holding a GIANT PAINTBRUSH with a little colored paint on the bristles. "
        "On the RIGHT side of the image: a marble arm holding a big wooden PAINTER'S PALETTE like a shield, with blobs of color. "
        "Small splashes of colored paint and thin cracks on the marble, a small paper inventory tag hanging from one arm (blank). "
        "Draw ALL the marble normal and complete: NO checkerboard pattern, NO pink or magenta squares. "
        "Colors: white and light grey marble, gold, bronze, red rope, small touches of bright paint colors. The silhouette is TALL and imposing. ")
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

FULL = "`_entregas_runway/bosses/boss_tex_full.png`"
B6 = "`_entregas_runway/bosses/boss_judge_full.png`"
STUDENT = "`_entregas_runway/wadrid_idle_down.png`"

TASKS = [
 ("A", "boss_tex_full.png", STUDENT, B6,
  STYLE + BOSS + SAME +
  "Draw ONE single big pose of the whole boss assembled, centered, in a three-quarter FRONT view facing the viewer, standing in its pedestal, "
  "arms slightly apart from the body. The boss is about 3 times as tall as the student in the first attached image "
  "(the first image is ONLY a size and style reference: do NOT draw the student). Square image (1:1). " + NOTEXT,
  "Primera y más importante: las demás hojas copian esta. Todo el mármol normal, SIN cuadriculado magenta (lo pone el código)."),
 ("B", "boss_tex_body.png", FULL, B6,
  STYLE + PARTS + grid(2, 2, 1) +
  "Item 1: the PEDESTAL with the legs and the TORSO only (with the rope posts): NO arms, NO head, NO chest plate "
  "(leave the golden picture frame in the chest EMPTY and dark, and empty round shoulder sockets). "
  "Item 2: the SAME pedestal and torso damaged: many cracks, chipped marble, a broken rope post (no fire, no smoke). Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_tex_core.png", FULL, B6,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is ONLY the ornate golden picture FRAME of the chest, seen from the front. "
  "Item 1: the frame covered by its plain marble plate. "
  "Item 2: the SAME frame OPEN (the marble plate gone): inside a glowing colorful abstract PAINTING (it is the weak point). "
  "Item 3: the SAME frame BROKEN: bent gold, torn painting, inside dark. Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_tex_head.png", FULL, B6,
  STYLE + PARTS + grid(4, 4, 1) +
  "Item 1: the statue head with the laurel crown and the golden halo frame, normal. "
  "Item 2: the SAME head with cracks across the mask face. "
  "Item 3: the SAME head with HALF of the mask face broken off (dark hollow inside). "
  "Item 4: ONLY the golden laurel crown alone (it falls off in the last phase). Landscape image (3:2). " + NOTEXT,
  "Cara lisa: los ojos y el cuadriculado se dibujan por código."),
 ("B", "boss_tex_brush.png", FULL, B6,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the marble ARM alone (the arm on the LEFT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the tool at the bottom. "
  "Item 1: holding the GIANT PAINTBRUSH. Item 2: holding a GIANT SEWING NEEDLE with red thread. Item 3: holding an ARCHAEOLOGY TROWEL (small pointed digging shovel). "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Rectos hacia abajo y del mismo largo: el código los gira desde el hombro."),
 ("B", "boss_tex_palette.png", FULL, B6,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the other marble ARM alone (the arm on the RIGHT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the object at the bottom. "
  "Item 1: holding the PAINTER'S PALETTE. Item 2: holding the two THEATER MASKS (comedy and tragedy). Item 3: an OPEN marble HAND reaching, fingers spread. "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Igual: rectos hacia abajo y del mismo largo."),
 ("C", "boss_tex_projectiles.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Projectiles and props, each about as big as the student's head in the second image (do NOT draw the student): "
  "1 a white smiling COMEDY theater mask, 2 a dark sad TRAGEDY theater mask, 3 a big SPLASH of thick blue paint, 4 a giant silver SEWING NEEDLE stuck in the ground, "
  "5 a SPOOL of red thread, 6 an ancient clay AMPHORA vase, 7 a broken piece of clay pottery, 8 an old BONE. "
  "Landscape image (3:2). " + NOTEXT,
  "Máscaras, pintura, aguja, carrete, vasija, pedazo de vasija y hueso."),
 ("C", "boss_tex_props.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Floor props and attack pieces, seen from the same three-quarter top view, each about as big as the student in the second image (do NOT draw the student): "
  "1 a small ARCHAEOLOGY DIG SITE (a mound of dirt with a little red flag stuck in it), 2 a cracked dirt HOLE in the ground with dust, "
  "3 a long thick horizontal BRUSH STROKE of red paint on the floor, 4 a flat PUDDLE of blue paint, "
  "5 an empty ornate GOLDEN PICTURE FRAME, 6 an empty white marble museum PEDESTAL, 7 a golden museum ROPE POST, 8 a tangle of red THREAD. "
  "Landscape image (3:2). " + NOTEXT,
  "Sitios de excavación, trazos y charcos de pintura, marco, pedestal, poste e hilo."),
 ("C", "boss_tex_mannequin.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "A creepy MUSEUM MANNEQUIN enemy (a smooth white faceless mannequin with visible joints, standing on a small round base pole), "
  "about as tall as the student in the second image (do NOT draw the student). "
  "Item 1: standing still. Items 2-3: walking. Item 4: frozen in a dramatic pose with an arm up. Item 5: frozen pose reaching forward. "
  "Item 6: hit, flinching. Item 7: knocked down. Item 8: broken into pieces on the floor. "
  "Same scale in all 8, feet on the same baseline per row. Landscape image (3:2). " + NOTEXT,
  "Esbirros maniquíes (Sociología): se congelan si los miras."),
 ("C", "boss_tex_debris.png", FULL, B6,
  STYLE + SMALL + grid(8, 4, 2) +
  "Small loose pieces for the boss death: 1 a chunk of white marble, 2 a smaller marble chunk, 3 a marble finger, 4 a golden laurel leaf, "
  "5 a piece of golden frame, 6 a paint tube, 7 a piece of red velvet rope, 8 a piece of the marble mask with one eye slit. Landscape image (3:2). " + NOTEXT,
  "Pedazos que salen volando al morir."),
]

md_t = ["# TAREA PARA GROKBOT — Boss 7: MISSING TEXTURE (10 hojas)", "",
"Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a `referencias_animacion/`).",
"Prompts: `referencias_animacion/PROMPTS_BOSS_7.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/367bb970-b79f-4951-86b9-4bfb3813d0a3", "",
"## Qué se pide",
"El séptimo boss, de la Facultad de Artes, Humanidades y Patrimonio: una estatua de mármol gigante del museo, con pincel y paleta, sobre su pedestal. Se anima POR PIEZAS en el juego, igual que los bosses 1 a 6: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.",
"- A: el boss completo (1 hoja). **Hacerla primero y avisar**: esta define el diseño. Las de B y C usan esta como Imagen 1.",
"- B: piezas sueltas del boss (5 hojas).",
"- C: proyectiles, piezas del piso, esbirro y pedazos (4 hojas).", "",
"## Reglas clave",
"- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.",
"- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.",
"- SIN TEXTO NI NÚMEROS en ningún lado (ni en la placa del pedestal ni en la etiqueta). Sin humanos pequeños. Sin sangre.",
"- SIN cuadriculado magenta/negro: todo el mármol normal (el efecto de textura faltante lo pone el código).",
"- En la hoja A, el boss 6 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.",
"- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.",
"- Los brazos (brush y palette) rectos hacia abajo, con el hombro arriba, mismo largo en todas las poses.",
"- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.", "",
"## Guardado",
"`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.", "",
"## Progreso", ""]
md_p = ["# PROMPTS BOSS 7: MISSING TEXTURE (10 hojas)", "",
"Cada bloque: archivo a guardar en `_entregas_runway/bosses/`, Imagen 1 e Imagen 2 (rutas dentro de `referencias_animacion/`) y el prompt.", ""]
sec_names = {"A": "A · Boss completo (hacer primero)", "B": "B · Piezas sueltas del boss", "C": "C · Proyectiles, piezas del piso, esbirro y pedazos"}
last = None
for sec, name, i1, i2, prompt, note in TASKS:
    if sec != last:
        md_t += ["", f"### {sec_names[sec]}"]
        md_p += ["", f"## {sec_names[sec]}", ""]
        last = sec
    md_t.append(f"- [ ] `{name}`" + (f" — {note}" if note else ""))
    md_p += [f"### `{name}`", f"- Imagen 1: {i1} · Imagen 2: {i2}" + (f" ({note})" if note else ""), "```", prompt, "```", ""]
md_t += ["", "## Notas de grokbot", "(resumen al terminar: herramienta usada en cada hoja y qué falló)", ""]
open(os.path.join(OUT, "GROKBOT_BOSS_7.md"), "w", encoding="utf-8").write("\n".join(md_t))
open(os.path.join(OUT, "PROMPTS_BOSS_7.md"), "w", encoding="utf-8").write("\n".join(md_p))
print("ok")
