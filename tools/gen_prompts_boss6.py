"""Genera GROKBOT_BOSS_6.md y PROMPTS_BOSS_6.md (boss 6 403 FORBIDDEN, Facultad de Ciencias Sociales, Derecho y Bienestar).
Uso: python tools/gen_prompts_boss6.py  (escribe en referencias_animacion/, o en OUT si se define)."""
import os
OUT = os.environ.get("OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "referencias_animacion"))

STYLE = ("2D pixel art game asset for a top-down 3/4 view action-RPG, 16-bit SNES style, crisp 1-pixel black outline, "
         "hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. "
         "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. ")
NOTEXT = ("No text, no letters, no numbers, no labels, no UI, no screens with writing, no frame borders, "
          "no motion lines, no speed lines, no glow halos, no particle effects, no small human characters, no blood.")
BOSS = ("The boss is called 403 FORBIDDEN: a huge, solemn and intimidating JUDGE ROBOT, not cute. "
        "Bottom: instead of legs it floats over its own heavy carved dark-wood JUDGE'S BENCH (a big wooden judge desk) with a golden scales-of-justice emblem on the front "
        "and small thrusters underneath. Some thick law books stacked on the bench and a strip of yellow crime-scene tape hanging from one side (tape without text). "
        "Body: a robot torso wearing a long BLACK JUDGE ROBE with a white collar and golden buttons; in the middle of the chest a metal plate with a big round golden LOCK (the core). "
        "Head: an old boxy CRT MONITOR with a big curly WHITE JUDGE WIG on top; the screen is plain dark (no text, no face). "
        "On the LEFT side of the image: a mechanical arm in a black robe sleeve holding a GIANT WOODEN JUDGE GAVEL. "
        "On the RIGHT side of the image: a mechanical arm holding golden SCALES OF JUSTICE. "
        "Two small flags on poles behind the shoulders. "
        "Colors: dark wood brown, black robe, white wig, gold, grey steel, a little red. The silhouette is TALL and imposing. ")
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

FULL = "`_entregas_runway/bosses/boss_judge_full.png`"
B4 = "`_entregas_runway/bosses/boss_syntax_full.png`"
STUDENT = "`_entregas_runway/wadrid_idle_down.png`"

TASKS = [
 ("A", "boss_judge_full.png", STUDENT, B4,
  STYLE + BOSS + SAME +
  "Draw ONE single big pose of the whole boss assembled, centered, in a three-quarter FRONT view facing the viewer, floating on its judge bench, "
  "arms slightly apart from the body. The boss is about 3 times as tall as the student in the first attached image "
  "(the first image is ONLY a size and style reference: do NOT draw the student). Square image (1:1). " + NOTEXT,
  "Primera y más importante: las demás hojas copian esta. La pantalla del monitor debe salir lisa y oscura (sin cara ni texto)."),
 ("B", "boss_judge_body.png", FULL, B4,
  STYLE + PARTS + grid(2, 2, 1) +
  "Item 1: the JUDGE BENCH and the robed TORSO only (with the flags): NO arms, NO head, NO chest lock "
  "(leave an empty dark round hole in the chest where the lock goes, and empty round shoulder sockets). "
  "Item 2: the SAME bench and torso damaged: cracked wood, torn robe, a broken flag, scattered papers (no fire, no smoke). Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_judge_core.png", FULL, B4,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is ONLY the round golden LOCK of the chest, seen from the front. "
  "Item 1: lock closed. "
  "Item 2: the SAME lock OPEN (the round door swung aside): inside a glowing red CORE with gears (it is the weak point). "
  "Item 3: the SAME lock BROKEN: bent, cracked, inside dark. Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_judge_head.png", FULL, B4,
  STYLE + PARTS + grid(4, 4, 1) +
  "Item 1: the CRT monitor head with the white judge wig, normal, plain dark screen. "
  "Item 2: the SAME head with the wig crooked and messy. "
  "Item 3: the SAME head with a cracked screen and the wig half burnt. "
  "Item 4: ONLY the white judge wig alone (it falls off in the last phase). Landscape image (3:2). " + NOTEXT,
  "Pantalla lisa: la cara, el 403 y los textos se dibujan por código."),
 ("B", "boss_judge_gavel.png", FULL, B4,
  STYLE + PARTS + grid(2, 2, 1) +
  "Each item is the GAVEL ARM alone (the arm on the LEFT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the gavel at the bottom, the gavel head horizontal. "
  "Item 1: the giant wooden gavel intact. Item 2: the SAME arm with the gavel BROKEN in half. "
  "Same arm, same length, same angle in both items. Landscape image (3:2). " + NOTEXT,
  "Rectos hacia abajo y del mismo largo: el código los gira desde el hombro."),
 ("B", "boss_judge_hand.png", FULL, B4,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the other mechanical ARM alone (the arm on the RIGHT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the object at the bottom. "
  "Item 1: holding the golden SCALES OF JUSTICE. Item 2: holding a big press MICROPHONE. Item 3: holding a big detective MAGNIFYING GLASS. "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Igual: rectos hacia abajo y del mismo largo."),
 ("C", "boss_judge_evidence.png", FULL, STUDENT,
  STYLE + SMALL + grid(6, 3, 2) +
  "Small collectible EVIDENCE items, each about the size of the student's head in the second image (do NOT draw the student): "
  "1 a big blue FINGERPRINT card, 2 a golden bullet CASING, 3 a sealed DOCUMENT with a red wax seal, 4 an instant PHOTO (blank picture), "
  "5 a red rubber STAMP seal (round, plain, no letters), 6 a brown cardboard CASE FILE folder. Landscape image (3:2). " + NOTEXT,
  "Pruebas que recoge el jugador y el sello DENEGADO (el texto lo pone el código)."),
 ("C", "boss_judge_projectiles.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Projectiles and props, each about as big as the student in the second image (do NOT draw the student): "
  "1 a giant thick red LAW BOOK falling, 2 a small grey SANCTION MISSILE pointing down, 3 a WHITE FLAG on a pole, 4 a big studio SPOTLIGHT lamp, "
  "5 a coil of yellow CRIME-SCENE TAPE (no text), 6 a forensic SCANNER device, 7 a round shockwave of the gavel (a flat ring of dust), 8 a pile of loose papers. "
  "Landscape image (3:2). " + NOTEXT,
  "Libro de leyes, misil, bandera blanca, foco, cinta, escáner, onda del mazo y papeles."),
 ("C", "boss_judge_folder.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "A small CASE FOLDER enemy (a brown cardboard file folder with little robot legs, two small arms and two round eyes peeking from inside), "
  "about half as tall as the student in the second image (do NOT draw the student). "
  "Items 1-2: idle. Items 3-4: walking. Item 5: grabbing forward with its arms. Item 6: hit, flinching. Item 7: knocked down. "
  "Item 8: defeated, papers scattered. "
  "Same scale in all 8, bottom on the same baseline per row. Landscape image (3:2). " + NOTEXT,
  "Esbirros casos (Trabajo Social); al romperlos sueltan una prueba."),
 ("C", "boss_judge_debris.png", FULL, B4,
  STYLE + SMALL + grid(8, 4, 2) +
  "Small loose pieces for the boss death: 1 a wooden splinter, 2 a golden button, 3 a sheet of paper, 4 a small gear, 5 a piece of black robe cloth, "
  "6 a broken piece of gavel, 7 a golden scales plate, 8 a curl of white wig. Landscape image (3:2). " + NOTEXT,
  "Pedazos que salen volando al morir."),
]

md_t = ["# TAREA PARA GROKBOT — Boss 6: 403 FORBIDDEN (10 hojas)", "",
"Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a `referencias_animacion/`).",
"Prompts: `referencias_animacion/PROMPTS_BOSS_6.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/b13b51de-e149-4c34-adfd-b43a3cf5561e", "",
"## Qué se pide",
"El sexto boss, de la Facultad de Ciencias Sociales, Derecho y Bienestar: un juez robot con toga, peluca y monitor de cabeza, flotando en su estrado. Se anima POR PIEZAS en el juego, igual que los bosses 1 a 5: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.",
"- A: el boss completo (1 hoja). **Hacerla primero y avisar**: esta define el diseño. Las de B y C usan esta como Imagen 1.",
"- B: piezas sueltas del boss (5 hojas).",
"- C: pruebas, proyectiles, esbirro y pedazos (4 hojas).", "",
"## Reglas clave",
"- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.",
"- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.",
"- SIN TEXTO NI NÚMEROS en ningún lado (ni en la pantalla, ni en los libros, ni en los documentos, ni en el sello, ni en la cinta). Sin humanos pequeños. Sin sangre.",
"- En la hoja A, el boss 4 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.",
"- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.",
"- Los brazos (gavel y hand) rectos hacia abajo, con el hombro arriba, mismo largo en todas las poses.",
"- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.", "",
"## Guardado",
"`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.", "",
"## Progreso", ""]
md_p = ["# PROMPTS BOSS 6: 403 FORBIDDEN (10 hojas)", "",
"Cada bloque: archivo a guardar en `_entregas_runway/bosses/`, Imagen 1 e Imagen 2 (rutas dentro de `referencias_animacion/`) y el prompt.", ""]
sec_names = {"A": "A · Boss completo (hacer primero)", "B": "B · Piezas sueltas del boss", "C": "C · Pruebas, proyectiles, esbirro y pedazos"}
last = None
for sec, name, i1, i2, prompt, note in TASKS:
    if sec != last:
        md_t += ["", f"### {sec_names[sec]}"]
        md_p += ["", f"## {sec_names[sec]}", ""]
        last = sec
    md_t.append(f"- [ ] `{name}`" + (f" — {note}" if note else ""))
    md_p += [f"### `{name}`", f"- Imagen 1: {i1} · Imagen 2: {i2}" + (f" ({note})" if note else ""), "```", prompt, "```", ""]
md_t += ["", "## Notas de grokbot", "(resumen al terminar: herramienta usada en cada hoja y qué falló)", ""]
open(os.path.join(OUT, "GROKBOT_BOSS_6.md"), "w", encoding="utf-8").write("\n".join(md_t))
open(os.path.join(OUT, "PROMPTS_BOSS_6.md"), "w", encoding="utf-8").write("\n".join(md_p))
print("ok")
