"""Genera GROKBOT_BOSS_4.md y PROMPTS_BOSS_4.md (boss 4 SYNTAX ERROR, Facultad de Educación, Turismo y Humanidades).
Uso: python tools/gen_prompts_boss4.py  (escribe en referencias_animacion/, o en OUT si se define)."""
import os
OUT = os.environ.get("OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "referencias_animacion"))

STYLE = ("2D pixel art game asset for a top-down 3/4 view action-RPG, 16-bit SNES style, crisp 1-pixel black outline, "
         "hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. "
         "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. ")
NOTEXT = ("No text, no letters, no numbers, no labels, no UI, no screens with writing, no frame borders, "
          "no motion lines, no speed lines, no glow halos, no particle effects, no small human characters, no blood.")
BOSS = ("The boss is called SYNTAX ERROR: a huge, tall and thin old ROBOT TEACHER, strict, severe and intimidating, not cute. "
        "Head: a metal desk GLOBE (world globe with blue oceans and green continents, no country names) used as a head, wearing round black-rimmed GLASSES "
        "with plain dark screen lenses (two simple glowing white dot eyes) and a black GRADUATION CAP (mortarboard) with a gold tassel; a few cables come out of the neck. "
        "Torso: a big rectangular green SCHOOL CHALKBOARD with a thick wooden frame and a small chalk tray at the bottom, completely clean and empty (no writing); "
        "around it a grey metal robotic chest frame with a brown tweed jacket collar, a dark red necktie and a pocket with red pens. "
        "Legs: long thin robotic legs in grey dress trousers ending in big white-and-red SPORTS SNEAKERS. "
        "On the LEFT side of the image: a long thin robotic arm holding a GIANT wooden POINTER / RULER, as long as the body. "
        "On the RIGHT side of the image: a robotic arm with a big hand holding a white CHALK stick and a felt BLACKBOARD ERASER. "
        "Colors: chalkboard green, wood brown, grey metal, brown tweed, dark red, white sneakers. The silhouette is TALL and THIN, about twice as tall as wide. ")
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

FULL = "`_entregas_runway/bosses/boss_syntax_full.png`"
B3 = "`_entregas_runway/bosses/boss_div0_full.png`"
STUDENT = "`_entregas_runway/wadrid_idle_down.png`"

TASKS = [
 ("A", "boss_syntax_full.png", STUDENT, B3,
  STYLE + BOSS + SAME +
  "Draw ONE single big pose of the whole boss assembled, centered, in a three-quarter FRONT view facing the viewer, standing still, "
  "arms slightly apart from the body. The boss is about 3 times as tall as the student in the first attached image "
  "(the first image is ONLY a size and style reference: do NOT draw the student). Square image (1:1). " + NOTEXT,
  "Primera y más importante: las demás hojas copian esta. La pizarra debe salir LIMPIA (sin escritura): el texto lo pone el código."),
 ("B", "boss_syntax_body.png", FULL, B3,
  STYLE + PARTS + grid(2, 2, 1) +
  "Item 1: the LEGS with sneakers and the TORSO frame with jacket collar and tie only: NO arms, NO head, NO chalkboard (leave an empty dark rectangular hole in the chest "
  "where the chalkboard goes, and empty round shoulder sockets). "
  "Item 2: the SAME legs and torso damaged: dented metal, torn jacket, tie loose, one sneaker untied, scratches (no fire, no smoke). Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_syntax_board.png", FULL, B3,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is ONLY the rectangular CHALKBOARD of the chest with its wooden frame and chalk tray, seen from the front, completely clean with no writing. "
  "Item 1: clean dark green chalkboard. "
  "Item 2: the SAME chalkboard glowing a bit brighter green with a faint white chalk dust smear (it is the weak point, open to damage). "
  "Item 3: the SAME chalkboard BROKEN: big cracks across it, a corner of the frame snapped, a piece missing. Landscape image (3:2). " + NOTEXT,
  "Sin escritura: el nombre, la secuencia y APROBADO/REPROBADO los escribe el código."),
 ("B", "boss_syntax_head.png", FULL, B3,
  STYLE + PARTS + grid(4, 2, 2) +
  "Item 1: the globe head with glasses and graduation cap, normal. "
  "Item 2: the SAME head WITHOUT the cap (the cap fell off). "
  "Item 3: the SAME head without cap, one glasses lens cracked and the globe dented. "
  "Item 4: ONLY the black graduation cap alone with its tassel. Square image (1:1). " + NOTEXT,
  "Los ojos (puntos) y las expresiones se dibujan por código encima de las gafas."),
 ("B", "boss_syntax_pointer.png", FULL, B3,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the long thin LEFT ARM alone (the arm on the LEFT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the tool at the bottom. "
  "Item 1: holding the GIANT wooden POINTER / RULER pointing down. Item 2: holding a big wooden ruler with measurement marks (no numbers). "
  "Item 3: holding a long rolled paper MAP. "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Rectos hacia abajo y del mismo largo: el código los gira desde el hombro."),
 ("B", "boss_syntax_hand.png", FULL, B3,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the RIGHT ARM alone (the arm on the RIGHT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the hand at the bottom. "
  "Item 1: the hand holding a white CHALK stick and a felt ERASER. Item 2: the hand holding a silver sports WHISTLE on a red cord. "
  "Item 3: the hand holding a gold hotel reception BELL (service bell). "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Igual: rectos hacia abajo y del mismo largo."),
 ("C", "boss_syntax_projectiles.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Small projectiles, each about the size of the student's head in the second image (do NOT draw the student): "
  "1 a white chalk stick, 2 a wooden toy building block (plain colored cube, no letters), 3 a flying open book page (blank paper), "
  "4 an empty white speech bubble (comic balloon, no text), 5 a folded white paper airplane, 6 a big round black ink dot seen from above (flat on the ground), "
  "7 a short grey metal spike with round dots on top (braille), 8 an orange traffic cone. Landscape image (3:2). " + NOTEXT,
  "Tiza, bloque ABC (las letras por código), página, globo de diálogo, avión-boleto, punto final, púa braille y cono."),
 ("C", "boss_syntax_desks.png", FULL, STUDENT,
  STYLE + SMALL + grid(6, 3, 2) +
  "A single wooden SCHOOL DESK with attached chair (student desk), seen in the same three-quarter view, about as tall as the student in the second image "
  "(do NOT draw the student). The backrest has an empty light rectangle panel (no symbol). "
  "Item 1: normal. Item 2: normal, a bit brighter (highlighted). Item 3: hit, tilted and shaking. Item 4: broken in pieces. "
  "Item 5: a pile of three desks stacked. Item 6: an old wooden teacher's desk. "
  "Same scale in all, bottom on the same baseline per row. Landscape image (3:2). " + NOTEXT,
  "Pupitres de La Lección: los símbolos ▲●■★ los pinta el código en el panel del respaldo."),
 ("C", "boss_syntax_bellhop.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "A small BELLHOP ROBOT enemy (a short round robot in a red hotel bellboy uniform with a little round hat, pushing a gold luggage cart with suitcases), "
  "about as tall as the student in the second image (do NOT draw the student). "
  "Items 1-2: idle. Items 3-4: rolling forward with the cart. Item 5: ramming (leaning forward). Item 6: hit, flinching. Item 7: knocked down. "
  "Item 8: defeated, cart tipped over and suitcases spilled. "
  "Same scale in all 8, bottom on the same baseline per row. Landscape image (3:2). " + NOTEXT,
  "Esbirros botones-robot del ataque de Gestión Hotelera."),
 ("C", "boss_syntax_debris.png", FULL, B3,
  STYLE + SMALL + grid(8, 4, 2) +
  "Small loose pieces for the boss death: 1 a broken piece of chalkboard, 2 a wooden frame splinter, 3 a dark red necktie, 4 a pair of round glasses, "
  "5 a white sneaker, 6 a crumpled paper sheet, 7 a red pen, 8 a dented black graduation cap. Landscape image (3:2). " + NOTEXT,
  "Pedazos que salen volando al morir."),
]

md_t = ["# TAREA PARA GROKBOT — Boss 4: SYNTAX ERROR (10 hojas)", "",
"Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a `referencias_animacion/`).",
"Prompts: `referencias_animacion/PROMPTS_BOSS_4.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/000be033-2dfe-4815-8127-624a20758492", "",
"## Qué se pide",
"El cuarto boss, de la Facultad de Educación, Turismo y Humanidades: un robot profesor con pizarra en el pecho. Se anima POR PIEZAS en el juego, igual que los bosses 1, 2 y 3: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.",
"- A: el boss completo (1 hoja). **Hacerla primero y avisar**: esta define el diseño. Las de B y C usan esta como Imagen 1.",
"- B: piezas sueltas del boss (5 hojas).",
"- C: proyectiles, pupitres, esbirro y pedazos (4 hojas).", "",
"## Reglas clave",
"- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.",
"- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.",
"- SIN TEXTO NI NÚMEROS en ningún lado (ni en la pizarra, ni en los pupitres, ni en los bloques, ni en los globos de diálogo). Sin humanos pequeños. Sin sangre.",
"- En la hoja A, el boss 3 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.",
"- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.",
"- Los brazos (pointer y hand) rectos hacia abajo, con el hombro arriba, mismo largo en las 3 poses.",
"- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.", "",
"## Guardado",
"`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.", "",
"## Progreso", ""]
md_p = ["# PROMPTS BOSS 4: SYNTAX ERROR (10 hojas)", "",
"Cada bloque: archivo a guardar en `_entregas_runway/bosses/`, Imagen 1 e Imagen 2 (rutas dentro de `referencias_animacion/`) y el prompt.", ""]
sec_names = {"A": "A · Boss completo (hacer primero)", "B": "B · Piezas sueltas del boss", "C": "C · Proyectiles, pupitres, esbirro y pedazos"}
last = None
for sec, name, i1, i2, prompt, note in TASKS:
    if sec != last:
        md_t += ["", f"### {sec_names[sec]}"]
        md_p += ["", f"## {sec_names[sec]}", ""]
        last = sec
    md_t.append(f"- [ ] `{name}`" + (f" — {note}" if note else ""))
    md_p += [f"### `{name}`", f"- Imagen 1: {i1} · Imagen 2: {i2}" + (f" ({note})" if note else ""), "```", prompt, "```", ""]
md_t += ["", "## Notas de grokbot", "(resumen al terminar: herramienta usada en cada hoja y qué falló)", ""]
open(os.path.join(OUT, "GROKBOT_BOSS_4.md"), "w", encoding="utf-8").write("\n".join(md_t))
open(os.path.join(OUT, "PROMPTS_BOSS_4.md"), "w", encoding="utf-8").write("\n".join(md_p))
print("ok")
