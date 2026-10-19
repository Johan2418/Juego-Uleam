"""Genera GROKBOT_BOSS_5.md y PROMPTS_BOSS_5.md (boss 5 STACK OVERFLOW, Facultad de Ingeniería, Industria y Arquitectura).
Uso: python tools/gen_prompts_boss5.py  (escribe en referencias_animacion/, o en OUT si se define)."""
import os
OUT = os.environ.get("OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "referencias_animacion"))

STYLE = ("2D pixel art game asset for a top-down 3/4 view action-RPG, 16-bit SNES style, crisp 1-pixel black outline, "
         "hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. "
         "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. ")
NOTEXT = ("No text, no letters, no numbers, no labels, no UI, no screens with writing, no frame borders, "
          "no motion lines, no speed lines, no glow halos, no particle effects, no small human characters, no blood.")
BOSS = ("The boss is called STACK OVERFLOW: a huge, wide and heavy CONSTRUCTION MACHINE ROBOT, half crane and half excavator, intimidating and powerful, not cute. "
        "Bottom: instead of legs it has two thick TANK TRACKS (caterpillar treads with wheels), a bit muddy. "
        "Body: the square cabin of an excavator painted SAFETY YELLOW with black-and-yellow hazard stripes, dark tinted windows on the sides, two headlights, "
        "and in the center of the chest a big metal ENGINE GRILLE (vent slats). On top of the cabin, an orange rotating warning beacon light. "
        "Two short exhaust pipes on the back shoulders. "
        "Head: a giant yellow construction HARD HAT with a dark visor screen under the brim (the visor is plain dark, no text, no face). "
        "On the LEFT side of the image: a long CRANE BOOM arm (yellow lattice steel) ending in a steel cable with a big CRANE HOOK. "
        "On the RIGHT side of the image: a thick hydraulic excavator arm ending in a big JACKHAMMER (pneumatic drill). "
        "Colors: safety yellow, black stripes, orange, grey steel, a little mud brown. The silhouette is WIDE and HEAVY, a bit wider than tall. ")
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

FULL = "`_entregas_runway/bosses/boss_stack_full.png`"
B4 = "`_entregas_runway/bosses/boss_syntax_full.png`"
STUDENT = "`_entregas_runway/wadrid_idle_down.png`"

TASKS = [
 ("A", "boss_stack_full.png", STUDENT, B4,
  STYLE + BOSS + SAME +
  "Draw ONE single big pose of the whole boss assembled, centered, in a three-quarter FRONT view facing the viewer, standing still on its tank tracks, "
  "arms slightly apart from the body. The boss is about 3 times as tall as the student in the first attached image "
  "(the first image is ONLY a size and style reference: do NOT draw the student). Square image (1:1). " + NOTEXT,
  "Primera y más importante: las demás hojas copian esta. El visor del casco debe salir liso y oscuro (sin cara ni texto)."),
 ("B", "boss_stack_body.png", FULL, B4,
  STYLE + PARTS + grid(2, 2, 1) +
  "Item 1: the TANK TRACKS and the excavator CABIN TORSO only (with the warning beacon and exhaust pipes): NO arms, NO head, NO engine grille "
  "(leave an empty dark square hole in the chest where the grille goes, and empty round shoulder sockets). "
  "Item 2: the SAME tracks and cabin damaged: dents, a cracked window, the beacon broken, scratches and mud (no fire, no smoke). Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_stack_engine.png", FULL, B4,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is ONLY the square ENGINE GRILLE of the chest, seen from the front. "
  "Item 1: grille closed, metal vent slats. "
  "Item 2: the SAME grille OPEN (slats folded away): inside a glowing orange hot ENGINE with pistons (it is the weak point). "
  "Item 3: the SAME grille BROKEN: slats bent and missing, inside dark and burnt. Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_stack_head.png", FULL, B4,
  STYLE + PARTS + grid(3, 3, 1) +
  "Item 1: the hard hat head with its dark visor screen, normal. "
  "Item 2: the SAME head dented and scratched, with a cracked visor. "
  "Item 3: ONLY the yellow hard hat alone, empty, a bit dented (it falls off when the boss dies). Landscape image (3:2). " + NOTEXT,
  "El visor liso: la cara y los textos se dibujan por código."),
 ("B", "boss_stack_crane.png", FULL, B4,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the long CRANE BOOM ARM alone (the arm on the LEFT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the tool at the bottom. "
  "Item 1: ending in the steel cable and big CRANE HOOK. Item 2: ending in a heavy ship ANCHOR. Item 3: ending in a big black WRECKING BALL on a chain. "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Rectos hacia abajo y del mismo largo: el código los gira desde el hombro."),
 ("B", "boss_stack_hammer.png", FULL, B4,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the thick hydraulic ARM alone (the arm on the RIGHT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the tool at the bottom. "
  "Item 1: ending in the big JACKHAMMER. Item 2: ending in a WELDING TORCH with a small blue flame. Item 3: ending in a GIANT WRENCH. "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Igual: rectos hacia abajo y del mismo largo."),
 ("C", "boss_stack_tower.png", FULL, STUDENT,
  STYLE + SMALL + grid(6, 3, 2) +
  "Construction pieces to build a stacked TOWER, each seen in the same three-quarter view, each about as wide as 2 students in the second image "
  "(do NOT draw the student): 1 a red steel I-BEAM girder lying horizontally, 2 a grey CONCRETE BLOCK, 3 a short orange shipping CONTAINER, "
  "4 a concrete FOUNDATION slab, 5 the SAME foundation slab with big cracks, 6 the SAME foundation slab broken in pieces. "
  "All pieces the same width. Landscape image (3:2). " + NOTEXT,
  "Piezas de La Torre: se apilan una sobre otra; la base agrietada es la que golpea el jugador."),
 ("C", "boss_stack_projectiles.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Small projectiles, each about the size of the student's head in the second image (do NOT draw the student): "
  "1 a food tin can lying on its side (plain label, no text), 2 a round steel GEAR with saw teeth, 3 a short wooden ELECTRIC POLE with two insulators, "
  "4 an orange traffic cone, 5 a big steel hex NUT, 6 a blue WATER WAVE splash, 7 a rolled blue BLUEPRINT paper, 8 a yellow electric SPARK ball. "
  "Landscape image (3:2). " + NOTEXT,
  "Lata, engranaje-sierra, poste eléctrico, cono, tuerca, ola, plano y chispa."),
 ("C", "boss_stack_drone.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "A small WORKER DRONE enemy (a round yellow robot with a tiny hard hat, one wheel and two small arms holding a wrench), "
  "about half as tall as the student in the second image (do NOT draw the student). "
  "Items 1-2: idle. Items 3-4: rolling forward. Item 5: swinging the wrench. Item 6: hit, flinching. Item 7: knocked down. "
  "Item 8: defeated, broken in pieces with its hard hat off. "
  "Same scale in all 8, bottom on the same baseline per row. Landscape image (3:2). " + NOTEXT,
  "Esbirros obreros (los llama en fase 2 y 3)."),
 ("C", "boss_stack_debris.png", FULL, B4,
  STYLE + SMALL + grid(8, 4, 2) +
  "Small loose pieces for the boss death: 1 a steel bolt, 2 a hex nut, 3 a red brick, 4 a small gear, 5 a piece of yellow cabin panel with black stripes, "
  "6 a bent pipe, 7 an orange warning beacon light, 8 a dented yellow hard hat. Landscape image (3:2). " + NOTEXT,
  "Pedazos que salen volando al morir."),
]

md_t = ["# TAREA PARA GROKBOT — Boss 5: STACK OVERFLOW (10 hojas)", "",
"Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a `referencias_animacion/`).",
"Prompts: `referencias_animacion/PROMPTS_BOSS_5.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/c6fba194-8436-47ab-ae6c-c0227d20ae9d", "",
"## Qué se pide",
"El quinto boss, de la Facultad de Ingeniería, Industria y Arquitectura: una máquina de obra mitad grúa mitad excavadora, con orugas y casco. Se anima POR PIEZAS en el juego, igual que los bosses 1 a 4: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.",
"- A: el boss completo (1 hoja). **Hacerla primero y avisar**: esta define el diseño. Las de B y C usan esta como Imagen 1.",
"- B: piezas sueltas del boss (5 hojas).",
"- C: piezas de la torre, proyectiles, esbirro y pedazos (4 hojas).", "",
"## Reglas clave",
"- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.",
"- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.",
"- SIN TEXTO NI NÚMEROS en ningún lado (ni en el visor, ni en las latas, ni en los contenedores, ni en el plano). Sin humanos pequeños. Sin sangre.",
"- En la hoja A, el boss 4 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.",
"- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.",
"- Los brazos (crane y hammer) rectos hacia abajo, con el hombro arriba, mismo largo en las 3 poses.",
"- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.", "",
"## Guardado",
"`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.", "",
"## Progreso", ""]
md_p = ["# PROMPTS BOSS 5: STACK OVERFLOW (10 hojas)", "",
"Cada bloque: archivo a guardar en `_entregas_runway/bosses/`, Imagen 1 e Imagen 2 (rutas dentro de `referencias_animacion/`) y el prompt.", ""]
sec_names = {"A": "A · Boss completo (hacer primero)", "B": "B · Piezas sueltas del boss", "C": "C · Torre, proyectiles, esbirro y pedazos"}
last = None
for sec, name, i1, i2, prompt, note in TASKS:
    if sec != last:
        md_t += ["", f"### {sec_names[sec]}"]
        md_p += ["", f"## {sec_names[sec]}", ""]
        last = sec
    md_t.append(f"- [ ] `{name}`" + (f" — {note}" if note else ""))
    md_p += [f"### `{name}`", f"- Imagen 1: {i1} · Imagen 2: {i2}" + (f" ({note})" if note else ""), "```", prompt, "```", ""]
md_t += ["", "## Notas de grokbot", "(resumen al terminar: herramienta usada en cada hoja y qué falló)", ""]
open(os.path.join(OUT, "GROKBOT_BOSS_5.md"), "w", encoding="utf-8").write("\n".join(md_t))
open(os.path.join(OUT, "PROMPTS_BOSS_5.md"), "w", encoding="utf-8").write("\n".join(md_p))
print("ok")
