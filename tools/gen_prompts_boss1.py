import os
OUT = os.environ.get("OUT", ".")

STYLE = ("2D pixel art game asset for a top-down 3/4 view action-RPG, 16-bit SNES style, crisp 1-pixel black outline, "
         "hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. "
         "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. ")
NOTEXT = ("No text, no letters, no numbers, no labels, no UI, no screens with writing, no frame borders, "
          "no motion lines, no speed lines, no glow halos, no particle effects, no small human characters.")
BOSS = ("The boss is called 0xDEADBEEF: a huge malfunctioning agricultural laboratory machine. Bottom: wide dark tank treads. "
        "Body: a boxy, mostly symmetrical industrial chassis of tan/beige metal with dark grey panels and a small server rack of tiny green status lights. "
        "Center of the chest: a big transparent glass bioreactor tank filled with bright glowing green liquid and a few bubbles. "
        "Head: a horned cow/bull skull sitting on top of a small boxy computer monitor; the monitor screen is plain dark (no text). "
        "From the back of the head: thick bundles of black cables and dark green roots hanging like hair. "
        "On the LEFT side of the image: an organic arm ending in a big three-fingered metal claw wrapped in roots, vines and a few leaves. "
        "On the RIGHT side of the image: a mechanical arm ending in a lab gripper pincer with a syringe. ")
SIMPLE = ("SIMPLIFIED DESIGN RULE: keep the SAME design and colors as the first attached image, but with bigger, cleaner shapes: "
          "fewer thin cables, fewer small leaves and fewer tiny details, 2 or 3 main colors per part, a readable silhouette even when shown small. ")
PARTS = ("EXPLODED PARTS RULE: copy the EXACT design, palette, pixel size and scale of the boss in the second attached image. "
         "Draw each listed item SEPARATELY, not touching and not connected to anything else, complete (also draw the parts that were hidden behind other parts, "
         "for example the full round joint), all in the SAME scale as the second image and the SAME three-quarter FRONT view. "
         "Lots of empty space between items, wide margin, nothing touching the image edges. ")

def grid(n, cols, rows):
    return (f"Exactly {n} items in ONE image, arranged in a grid of {cols} columns and {rows} rows "
            f"(read left to right, top row first), evenly spaced. ")

TASKS = [
 ("A", "boss_0xdeadbeef_full.png",
  "`bosses/0xdeadbeef_referencia.jpg`", "`_entregas_runway/wadrid_idle_down.png`",
  STYLE + BOSS + SIMPLE +
  "Draw ONE single big pose of the whole boss assembled, centered, in a three-quarter FRONT view facing the viewer (like the bottom-left drawing of the first image), "
  "standing still, arms hanging at its sides, claw open. Use the same chunky pixel size and outline thickness as the student sprite in the second attached image "
  "(the second image is ONLY a style reference: do NOT draw the student). Square image (1:1). " + NOTEXT,
  "Primera y más importante: las demás hojas copian esta. Si sale con texto en el monitor o con humanos pequeños, repetir."),
 ("B", "boss_0xdeadbeef_body.png",
  "`bosses/0xdeadbeef_referencia.jpg`", "`_entregas_runway/bosses/boss_0xdeadbeef_full.png`",
  STYLE + PARTS + grid(2, 2, 1) +
  "Item 1: the CHASIS ONLY with its tank treads: NO arms, NO head, NO glass tank (leave an empty round dark socket in the chest where the tank goes, and empty round shoulder sockets). "
  "Item 2: the SAME chassis badly damaged: dented panels, a broken panel, black burn stains, some status lights off (no sparks, no smoke). Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_0xdeadbeef_tank.png",
  "`bosses/0xdeadbeef_referencia.jpg`", "`_entregas_runway/bosses/boss_0xdeadbeef_full.png`",
  STYLE + PARTS + grid(3, 3, 1) +
  "Item 1: the glass bioreactor tank, normal, filled with glowing green liquid and bubbles. "
  "Item 2: the SAME tank OPEN: its front glass panel slid down, the liquid glowing extra bright yellow-green (it is the weak point). "
  "Item 3: the SAME tank BROKEN: glass shattered, empty, a little green liquid at the bottom. Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_0xdeadbeef_head.png",
  "`bosses/0xdeadbeef_referencia.jpg`", "`_entregas_runway/bosses/boss_0xdeadbeef_full.png`",
  STYLE + PARTS + grid(4, 2, 2) +
  "Item 1: the horned bull skull with its cable-and-root hair, jaw closed, dark empty eye sockets. "
  "Item 2: the SAME skull with both eyes glowing solid red. "
  "Item 3: the SAME skull with the jaw WIDE open (as if roaring), eyes red. "
  "Item 4: ONLY the small boxy computer monitor, without the skull, screen completely plain black. Square image (1:1). " + NOTEXT,
  "El monitor debe salir con la pantalla negra lisa: el texto y las caras se dibujan por código."),
 ("B", "boss_0xdeadbeef_claw.png",
  "`bosses/0xdeadbeef_referencia.jpg`", "`_entregas_runway/bosses/boss_0xdeadbeef_full.png`",
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the ORGANIC CLAW ARM alone (the arm on the LEFT side of the second image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the claw at the bottom. "
  "Item 1: claw wide open. Item 2: claw half closed. Item 3: claw closed like a fist. Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Importante que los 3 brazos salgan rectos hacia abajo y del mismo largo: el código los gira desde el hombro."),
 ("B", "boss_0xdeadbeef_grabber.png",
  "`bosses/0xdeadbeef_referencia.jpg`", "`_entregas_runway/bosses/boss_0xdeadbeef_full.png`",
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the MECHANICAL GRIPPER ARM alone (the arm on the RIGHT side of the second image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the pincer at the bottom. "
  "Item 1: pincer open. Item 2: pincer closed. Item 3: pincer open with the syringe needle pushed out. Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Igual que la garra: rectos hacia abajo y del mismo largo."),
 ("C", "boss_animals.png",
  "`bosses/0xdeadbeef_referencia.jpg`", "`_entregas_runway/wadrid_walk8_right.png`",
  STYLE + "Copy the pixel size, outline and palette style of the second attached image (it is ONLY a style reference: do NOT draw the student). " + grid(8, 4, 2) +
  "Top row (items 1-4): a black-and-white dairy COW running to the RIGHT, side view, 4-frame gallop cycle, with a small yellow ear tag. "
  "Bottom row (items 5-8): a pink PIG running to the RIGHT, side view, 4-frame run cycle, with a small yellow ear tag. "
  "The cow is about as tall as the student in the second image, the pig a bit smaller. Same size in all frames, feet on the same baseline per row. Landscape image (3:2). " + NOTEXT,
  "Para la estampida (como las vacas de la referencia)."),
 ("C", "boss_minion_plant.png",
  "`bosses/0xdeadbeef_referencia.jpg`", "`_entregas_runway/wadrid_idle_down.png`",
  STYLE + "Copy the pixel size, outline and palette style of the second attached image (it is ONLY a style reference: do NOT draw the student). " + grid(8, 4, 2) +
  "A small MUTANT LAB PLANT enemy, front view, about half as tall as the student: a carnivorous plant growing out of a cracked glass test tube base, "
  "with a round red tomato-like head with a mouth full of small sharp teeth and two leaf arms. "
  "Item 1-2: idle, swaying left and right. Item 3: leaning back with the mouth open (wind-up). Item 4: lunging forward, biting. Item 5: back to idle. "
  "Item 6: hit, flinching. Item 7: wilting, drooping down. Item 8: dead, dried and collapsed on the test tube. Same scale in all 8, base on the same baseline per row. Landscape image (3:2). " + NOTEXT,
  "Esbirros que salen en la fase 2."),
 ("C", "boss_props.png",
  "`bosses/0xdeadbeef_referencia.jpg`", "`_entregas_runway/bosses/boss_0xdeadbeef_full.png`",
  STYLE + "Copy the pixel size, outline and palette of the second attached image. " + grid(8, 4, 2) +
  "Item 1: a cardboard produce crate full of vegetables. Item 2: a big red tomato. Item 3: a green apple. Item 4: a corn cob. "
  "Item 5: a toxic green liquid puddle seen from above (flat oval on the ground). "
  "Items 6-8: a sharp dark green root bursting out of the ground, in 3 growth stages (6: small crack with only the tip, 7: half out, 8: tall pointed root fully out). "
  "Each item is small compared to the boss. Landscape image (3:2). " + NOTEXT,
  "Proyectiles de la lluvia de cajas y las raíces del suelo."),
 ("C", "boss_debris.png",
  "`bosses/0xdeadbeef_referencia.jpg`", "`_entregas_runway/bosses/boss_0xdeadbeef_full.png`",
  STYLE + "Copy the pixel size, outline and palette of the second attached image. " + grid(8, 4, 2) +
  "Small loose pieces for the boss death explosion: 1 a gear, 2 a bolt and nut, 3 a bent tan metal plate, 4 a broken green glass shard, "
  "5 a short broken black cable, 6 a small piece of the bull skull horn, 7 a small white-and-yellow flower, 8 a tuft of fresh green grass. Landscape image (3:2). " + NOTEXT,
  "Pedazos que salen volando al morir; la flor y el pasto son para cuando la arena se limpia."),
]

md_t = ["# TAREA PARA GROKBOT — Boss 1: 0xDEADBEEF (10 hojas)", "",
"Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a `referencias_animacion/`).",
"Prompts: `referencias_animacion/PROMPTS_BOSS_1.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/b298b2a5-70f0-4681-977e-03a9bae51608", "",
"## Qué se pide",
"El primer boss, de la Facultad de Ciencias de la Vida y Tecnología. Se anima POR PIEZAS en el juego: por eso se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.",
"- A: el boss completo (1 hoja). **Hacerla primero**: todas las de B usan esta como Imagen 2.",
"- B: piezas sueltas del boss (5 hojas).",
"- C: animales, esbirro, proyectiles y pedazos (4 hojas).", "",
"## Reglas clave",
"- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.",
"- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.",
"- SIN TEXTO en ningún lado (ni en el monitor). Sin humanos pequeños (la referencia los tiene, no copiarlos).",
"- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.",
"- Los brazos (claw y grabber) rectos hacia abajo, con el hombro arriba, mismo largo en las 3 poses.",
"- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.", "",
"## Guardado",
"`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.", "",
"## Progreso", ""]
md_p = ["# PROMPTS BOSS 1: 0xDEADBEEF (10 hojas)", "",
"Cada bloque: archivo a guardar en `_entregas_runway/bosses/`, Imagen 1 e Imagen 2 (rutas dentro de `referencias_animacion/`) y el prompt.", ""]
sec_names = {"A": "A · Boss completo (hacer primero)", "B": "B · Piezas sueltas del boss", "C": "C · Animales, esbirro, proyectiles y pedazos"}
last = None
for sec, name, i1, i2, prompt, note in TASKS:
    if sec != last:
        md_t += ["", f"### {sec_names[sec]}"]
        md_p += ["", f"## {sec_names[sec]}", ""]
        last = sec
    md_t.append(f"- [ ] `{name}`" + (f" — {note}" if note else ""))
    md_p += [f"### `{name}`", f"- Imagen 1: {i1} · Imagen 2: {i2}" + (f" ({note})" if note else ""), "```", prompt, "```", ""]
md_t += ["", "## Notas de grokbot", "(resumen al terminar: herramienta usada en cada hoja y qué falló)", ""]
open(os.path.join(OUT, "GROKBOT_BOSS_1.md"), "w", encoding="utf-8").write("\n".join(md_t))
open(os.path.join(OUT, "PROMPTS_BOSS_1.md"), "w", encoding="utf-8").write("\n".join(md_p))
print("ok")
