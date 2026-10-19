"""Genera GROKBOT_BOSS_8.md y PROMPTS_BOSS_8.md (boss 8 KERNEL PANIC, Unidad de Formación Técnicas y Tecnológicas).
Uso: python tools/gen_prompts_boss8.py  (escribe en referencias_animacion/, o en OUT si se define)."""
import os
OUT = os.environ.get("OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "referencias_animacion"))

STYLE = ("2D pixel art game asset for a top-down 3/4 view action-RPG, 16-bit SNES style, crisp 1-pixel black outline, "
         "hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. "
         "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. ")
NOTEXT = ("No text, no letters, no numbers, no labels, no UI, no screens with writing, no frame borders, "
          "no motion lines, no speed lines, no glow halos, no particle effects, no small human characters, no blood.")
BOSS = ("The boss is called KERNEL PANIC: a huge, heavy and intimidating ROBOT CHEF who hosts a live TV cooking show, not cute. "
        "Made of brushed stainless steel with chrome and red details, half kitchen appliance and half TV star. "
        "Bottom: a big industrial KITCHEN CART on small wheels, with drawers, oven knobs and a wooden cutting board on top; the torso rises out of the cart. "
        "Body: a wide metal robot chest with a stained white chef APRON, a red presenter BOW TIE, and in the middle of the chest an OVEN CONTROL PANEL (a big round dial and small lights) that is the core. "
        "Head: a MICROWAVE OVEN as a head, its door window is a plain DARK SCREEN (blank, no face drawn), a tall white CHEF HAT on top and a small TV antenna. "
        "On the LEFT side of the image: a thick robot arm holding a GIANT FRYING PAN. "
        "On the RIGHT side of the image: a thick robot arm holding a big presenter MICROPHONE. "
        "Small details: steam vents, sauce stains, a studio cable plugged into its back, rivets and dents. "
        "Colors: steel grey, chrome, white apron, red bow tie and accents, black. The silhouette is BIG, WIDE and imposing. ")
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


FULL = "`_entregas_runway/bosses/boss_kp_full.png`"
B7 = "`_entregas_runway/bosses/boss_tex_full.png`"
STUDENT = "`_entregas_runway/wadrid_idle_down.png`"
ARM = ("hanging STRAIGHT DOWN vertically, with its round shoulder joint at the TOP of the item and the object held at the BOTTOM; "
       "the object must NOT stick up above the shoulder. ")

TASKS = [
 ("A", "boss_kp_full.png", STUDENT, B7,
  STYLE + BOSS + SAME +
  "Draw ONE single big pose of the whole boss assembled, centered, in a three-quarter FRONT view facing the viewer, standing in its kitchen cart, "
  "arms slightly apart from the body. The boss is about 3 times as tall as the student in the first attached image "
  "(the first image is ONLY a size and style reference: do NOT draw the student). Square image (1:1). " + NOTEXT,
  "Primera y más importante: las demás hojas copian esta. Pantalla de la cara en negro (la cara la dibuja el código)."),
 ("B", "boss_kp_body.png", FULL, B7,
  STYLE + PARTS + grid(2, 2, 1) +
  "Item 1: the KITCHEN CART with the TORSO only (apron and bow tie): NO arms, NO head, NO control panel "
  "(leave an EMPTY dark round hole in the chest where the panel goes, and empty round shoulder sockets). "
  "Item 2: the SAME cart and torso burned and damaged: scorch marks, dents, a loose drawer (no fire, no smoke). Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_kp_core.png", FULL, B7,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is ONLY the round OVEN CONTROL PANEL of the chest, seen from the front. "
  "Item 1: closed, with the big dial and small lights off. "
  "Item 2: the SAME panel OPEN, a hatch swung aside showing a glowing hot orange interior with popcorn kernels (it is the weak point). "
  "Item 3: the SAME panel BROKEN: bent metal, cracked dial, dark inside. Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_kp_head.png", FULL, B7,
  STYLE + PARTS + grid(4, 4, 1) +
  "Item 1: the microwave head with the chef hat and antenna, normal, with the plain dark screen. "
  "Item 2: the SAME head dented, the hat a bit crooked. "
  "Item 3: the SAME head cracked open with a broken screen and sparks of wires. "
  "Item 4: ONLY the white chef hat alone (it flies off in the last phase). Landscape image (3:2). " + NOTEXT,
  "Pantalla lisa y oscura: la cara se dibuja por código."),
 ("B", "boss_kp_pan.png", FULL, B7,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the robot ARM alone (the arm on the LEFT side of the first image), " + ARM +
  "Item 1: holding the GIANT FRYING PAN. Item 2: holding a GIANT CHEF KNIFE pointing down. Item 3: holding a big soup LADLE. "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Rectos hacia abajo, mismo largo, y nada que sobresalga arriba del hombro: el código los gira desde el hombro."),
 ("B", "boss_kp_mic.png", FULL, B7,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the other robot ARM alone (the arm on the RIGHT side of the first image), " + ARM +
  "Item 1: holding the presenter MICROPHONE. Item 2: holding a black and white movie CLAPPERBOARD (blank, no writing). Item 3: an OPEN robot HAND waving, fingers spread. "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Igual: rectos hacia abajo y del mismo largo."),
 ("C", "boss_kp_projectiles.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Projectiles, each about as big as the student's head in the second image (do NOT draw the student): "
  "1 a roasted CHICKEN LEG on fire, 2 a round FIREBALL, 3 a big CHEF KNIFE flying point down, 4 a single yellow CORN KERNEL, "
  "5 a white fluffy POPCORN, 6 a bright white CAMERA FLASH star burst, 7 a white dinner PLATE, 8 a drop of hot cooking OIL. "
  "Landscape image (3:2). " + NOTEXT,
  "Comida en llamas, fuego, cuchillo, grano, palomita, flash, plato y gota de aceite."),
 ("C", "boss_kp_props.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "TV studio props, seen from the same three-quarter top view, each about as big as the student in the second image (do NOT draw the student): "
  "1 a big professional TV CAMERA on a tripod with its red light ON, 2 the SAME camera with the light off, 3 the SAME camera BROKEN (cracked lens, bent tripod), "
  "4 a section of RED CARPET lying flat on the floor, 5 a golden POST with a red velvet ROPE, 6 a red studio APPLAUSE sign box (blank, no letters), "
  "7 a studio SPOTLIGHT on a stand, 8 a striped BUCKET full of popcorn. "
  "Landscape image (3:2). " + NOTEXT,
  "Cámaras (en vivo, apagada, rota), alfombra roja, poste con cordón, cartel de aplausos, reflector y balde de palomitas."),
 ("C", "boss_kp_paparazzi.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "A small PAPARAZZI ROBOT enemy (a short boxy robot with a big photo camera as its face and two thin legs, holding a flash), "
  "about as tall as the student in the second image (do NOT draw the student). "
  "Item 1: standing. Items 2-3: walking. Item 4: aiming the camera. Item 5: taking a photo with the flash firing. "
  "Item 6: hit, flinching. Item 7: knocked down. Item 8: broken into pieces on the floor. "
  "Same scale in all 8, feet on the same baseline per row. Landscape image (3:2). " + NOTEXT,
  "Esbirros paparazzi de la alfombra roja (Comunicación/RRPP)."),
 ("C", "boss_kp_debris.png", FULL, B7,
  STYLE + SMALL + grid(8, 4, 2) +
  "Small loose pieces for the boss death: 1 a steel plate piece, 2 a small bolt, 3 a gear, 4 an oven knob, "
  "5 a popcorn, 6 a piece of white apron cloth, 7 a red bow tie, 8 a piece of the cracked microwave screen. Landscape image (3:2). " + NOTEXT,
  "Pedazos que salen volando al morir."),
]

md_t = ["# TAREA PARA GROKBOT — Boss 8: KERNEL PANIC (10 hojas)", "",
"Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a `referencias_animacion/`).",
"Prompts: `referencias_animacion/PROMPTS_BOSS_8.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/005ed015-f9c9-4542-9a6c-1ea32c304b9e", "",
"## Qué se pide",
"El octavo y último boss, de la Unidad de Formación Técnicas y Tecnológicas: un robot chef presentador de un programa de cocina en vivo, con cabeza de microondas, sartén y micrófono, sobre un carrito de cocina. Se anima POR PIEZAS en el juego, igual que los bosses 1 a 7: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.",
"- A: el boss completo (1 hoja). **Hacerla primero y avisar**: esta define el diseño. Las de B y C usan esta como Imagen 1.",
"- B: piezas sueltas del boss (5 hojas).",
"- C: proyectiles, utilería del estudio, esbirro y pedazos (4 hojas).", "",
"## Reglas clave",
"- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.",
"- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.",
"- SIN TEXTO NI NÚMEROS en ningún lado (ni en la claqueta ni en el cartel de aplausos). Sin humanos pequeños. Sin sangre.",
"- La pantalla del microondas va LISA y oscura, sin cara: la cara la dibuja el código.",
"- En la hoja A, el boss 7 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.",
"- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.",
"- Los brazos (pan y mic) rectos hacia abajo, con el hombro arriba, mismo largo en todas las poses, y nada que sobresalga por encima del hombro.",
"- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.", "",
"## Guardado",
"`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.", "",
"## Progreso", ""]
md_p = ["# PROMPTS BOSS 8: KERNEL PANIC (10 hojas)", "",
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
open(os.path.join(OUT, "GROKBOT_BOSS_8.md"), "w", encoding="utf-8").write("\n".join(md_t))
open(os.path.join(OUT, "PROMPTS_BOSS_8.md"), "w", encoding="utf-8").write("\n".join(md_p))
print("ok")
