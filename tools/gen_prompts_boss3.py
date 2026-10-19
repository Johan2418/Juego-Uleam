"""Genera GROKBOT_BOSS_3.md y PROMPTS_BOSS_3.md (boss 3 #DIV/0!, Facultad de Ciencias Administrativas, Contables y Comercio).
Uso: python tools/gen_prompts_boss3.py  (escribe en referencias_animacion/, o en OUT si se define)."""
import os
OUT = os.environ.get("OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "referencias_animacion"))

STYLE = ("2D pixel art game asset for a top-down 3/4 view action-RPG, 16-bit SNES style, crisp 1-pixel black outline, "
         "hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. "
         "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. ")
NOTEXT = ("No text, no letters, no numbers, no labels, no UI, no screens with writing, no frame borders, "
          "no motion lines, no speed lines, no glow halos, no particle effects, no small human characters, no blood.")
BOSS = ("The boss is called #DIV/0!: a huge, wide and heavy CORPORATE BANK-VAULT ROBOT EXECUTIVE, intimidating and powerful, not cute. "
        "Bottom: it stands on FOUR thick mechanical spider-like LEGS made of grey metal FILING CABINETS (drawers with small handles), two at the front and two at the back. "
        "Body: a big square steel BANK VAULT as the torso, with a round vault door in the center of the chest with a gold combination wheel and thick bolts; "
        "over the vault it wears a dark grey business waistcoat with gold buttons and a red necktie. A brown leather briefcase hangs from its belt. "
        "Around its neck: a thin paper stock-ticker tape ring. "
        "Head: an old boxy computer MONITOR wearing a black TOP HAT; the screen is plain dark green with a faint spreadsheet grid only (no text, no numbers). "
        "On the LEFT side of the image: a thick robotic arm ending in a GIANT wooden RUBBER STAMP (handle up, flat rubber face down). "
        "On the RIGHT side of the image: a thick robotic arm ending in a huge desktop CALCULATOR used like a hammer, with a paper roll. "
        "Colors: steel grey, gold, money green, dark grey suit, red tie. The silhouette is WIDE and HEAVY, a bit wider than tall. ")
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

FULL = "`_entregas_runway/bosses/boss_div0_full.png`"
B2 = "`_entregas_runway/bosses/boss_bsod_full.png`"
STUDENT = "`_entregas_runway/wadrid_idle_down.png`"

TASKS = [
 ("A", "boss_div0_full.png", STUDENT, B2,
  STYLE + BOSS + SAME +
  "Draw ONE single big pose of the whole boss assembled, centered, in a three-quarter FRONT view facing the viewer, standing still on its four filing-cabinet legs, "
  "arms slightly apart from the body. The boss is about 3 times as tall as the student in the first attached image "
  "(the first image is ONLY a size and style reference: do NOT draw the student). Square image (1:1). " + NOTEXT,
  "Primera y más importante: las demás hojas copian esta. No hay imagen de referencia del diseño: revisar con Johan antes de seguir. Repetir si sale con texto, números o humanos pequeños."),
 ("B", "boss_div0_body.png", FULL, B2,
  STYLE + PARTS + grid(2, 2, 1) +
  "Item 1: the four filing-cabinet LEGS and the VAULT TORSO with waistcoat and tie only: NO arms, NO head, NO vault door (leave an empty dark round hole in the chest "
  "and empty round shoulder sockets), with the briefcase and the ticker tape. "
  "Item 2: the SAME legs and torso damaged: dented panels, a drawer hanging open, the tie loose and torn, scratches (no fire, no smoke). Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_div0_vault.png", FULL, B2,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is ONLY the round VAULT DOOR of the chest, seen from the front. "
  "Item 1: vault door closed, gold combination wheel and bolts. "
  "Item 2: the SAME vault OPEN: the door swung open to the side, inside a glowing pile of gold bars and green banknotes (it is the weak point). "
  "Item 3: the SAME vault BROKEN: door hanging bent, inside empty and dark, a few loose coins. Landscape image (3:2). " + NOTEXT, ""),
 ("B", "boss_div0_head.png", FULL, B2,
  STYLE + PARTS + grid(4, 2, 2) +
  "Item 1: the monitor head with the black top hat, screen plain dark green. "
  "Item 2: the SAME head WITHOUT the top hat (the hat fell off), screen plain dark green. "
  "Item 3: the SAME head without hat, cracked screen corner and a dented case, screen plain dark green. "
  "Item 4: ONLY the black top hat alone. Square image (1:1). " + NOTEXT,
  "Las pantallas deben salir lisas (verde oscuro): los errores #DIV/0! y las caras se dibujan por código."),
 ("B", "boss_div0_stamp.png", FULL, B2,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the thick STAMP ARM alone (the arm on the LEFT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the tool at the bottom. "
  "Item 1: ending in the GIANT RUBBER STAMP. Item 2: ending in a big golden MAGNIFYING GLASS. Item 3: ending in a heavy metal CRANE HOOK. "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Rectos hacia abajo y del mismo largo: el código los gira desde el hombro (igual que los brazos de los bosses 1 y 2)."),
 ("B", "boss_div0_tool.png", FULL, B2,
  STYLE + PARTS + grid(3, 3, 1) +
  "Each item is the thick CALCULATOR ARM alone (the arm on the RIGHT side of the first image), hanging STRAIGHT DOWN vertically, "
  "with its round shoulder joint at the TOP of the item and the tool at the bottom. "
  "Item 1: ending in the huge desktop CALCULATOR with a paper roll (keys without symbols). Item 2: ending in a big red MEGAPHONE. "
  "Item 3: ending in a gold COIN CANNON (a short wide cannon tube). "
  "Same arm, same length, same angle in the 3 items. Landscape image (3:2). " + NOTEXT,
  "Igual: rectos hacia abajo y del mismo largo. Las teclas de la calculadora sin números."),
 ("C", "boss_div0_projectiles.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Small projectiles, each about the size of the student's head in the second image (do NOT draw the student): "
  "1 a shiny gold coin, 2 a flying green banknote, 3 a small stack of gold coins, 4 a grey office box (a cube with a red tie painted on its front), "
  "5 a round magnifying-glass lens, 6 an empty computer pop-up window frame with a red close button and a plain white inside, "
  "7 a flat dark red ink splat seen from above (flat on the ground), 8 a curled paper receipt roll. Landscape image (3:2). " + NOTEXT,
  "Monedas, billete, caja del organigrama, lupa, ventana emergente, mancha de sello y recibo."),
 ("C", "boss_div0_containers.png", FULL, STUDENT,
  STYLE + SMALL + grid(4, 2, 2) +
  "Big metal SHIPPING CONTAINERS, each lying horizontally, seen from the side in the same three-quarter view, each about as long as 3 students and as tall as 1 student "
  "in the second image (do NOT draw the student): 1 a red container, 2 a blue container, 3 a green container, 4 an orange container. "
  "Corrugated metal sides, no logos. Landscape image (3:2). " + NOTEXT,
  "Para el ataque de Comercio Exterior: pasan por carriles a toda velocidad."),
 ("C", "boss_div0_briefcase.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "A small BRIEFCASE enemy (a brown leather briefcase with two little metal legs, two angry eyes on the front and a mouth where it opens), about half as tall as the student "
  "in the second image (do NOT draw the student). "
  "Items 1-2: idle, hopping. Items 3-4: walking. Item 5: biting (opened wide). Item 6: hit, flinching. Item 7: knocked down. Item 8: defeated, opened flat with papers spilling. "
  "Same scale in all 8, bottom on the same baseline per row. Landscape image (3:2). " + NOTEXT,
  "Esbirros \"pasantes\" que salen en el ataque de Talento Humano."),
 ("C", "boss_div0_debris.png", FULL, B2,
  STYLE + SMALL + grid(8, 4, 2) +
  "Small loose pieces for the boss death: 1 a green banknote, 2 a gold coin, 3 a red necktie, 4 a calculator key without symbol, 5 a small filing-cabinet drawer, "
  "6 a crumpled paper sheet, 7 a gold bar, 8 a dented black top hat. Landscape image (3:2). " + NOTEXT,
  "Pedazos que salen volando al morir."),
]

md_t = ["# TAREA PARA GROKBOT — Boss 3: #DIV/0! (10 hojas)", "",
"Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a `referencias_animacion/`).",
"Prompts: `referencias_animacion/PROMPTS_BOSS_3.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/5f8c0327-f173-4fb8-8efe-c76c93517939", "",
"## Qué se pide",
"El tercer boss, de la Facultad de Ciencias Administrativas, Contables y Comercio: un robot-bóveda ejecutivo. Se anima POR PIEZAS en el juego, igual que los bosses 1 y 2: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.",
"- A: el boss completo (1 hoja). **Hacerla primero y avisar a Johan**: no hay imagen de referencia, así que esta define el diseño. Las de B y C usan esta como Imagen 1.",
"- B: piezas sueltas del boss (5 hojas).",
"- C: proyectiles, contenedores, esbirro y pedazos (4 hojas).", "",
"## Reglas clave",
"- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.",
"- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.",
"- SIN TEXTO NI NÚMEROS en ningún lado (ni en el monitor, ni en la calculadora, ni en los billetes). Sin humanos pequeños. Sin sangre.",
"- En la hoja A, el boss 2 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.",
"- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.",
"- Los brazos (stamp y tool) rectos hacia abajo, con el hombro arriba, mismo largo en las 3 poses.",
"- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.", "",
"## Guardado",
"`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.", "",
"## Progreso", ""]
md_p = ["# PROMPTS BOSS 3: #DIV/0! (10 hojas)", "",
"Cada bloque: archivo a guardar en `_entregas_runway/bosses/`, Imagen 1 e Imagen 2 (rutas dentro de `referencias_animacion/`) y el prompt.", ""]
sec_names = {"A": "A · Boss completo (hacer primero)", "B": "B · Piezas sueltas del boss", "C": "C · Proyectiles, contenedores, esbirro y pedazos"}
last = None
for sec, name, i1, i2, prompt, note in TASKS:
    if sec != last:
        md_t += ["", f"### {sec_names[sec]}"]
        md_p += ["", f"## {sec_names[sec]}", ""]
        last = sec
    md_t.append(f"- [ ] `{name}`" + (f" — {note}" if note else ""))
    md_p += [f"### `{name}`", f"- Imagen 1: {i1} · Imagen 2: {i2}" + (f" ({note})" if note else ""), "```", prompt, "```", ""]
md_t += ["", "## Notas de grokbot", "(resumen al terminar: herramienta usada en cada hoja y qué falló)", ""]
open(os.path.join(OUT, "GROKBOT_BOSS_3.md"), "w", encoding="utf-8").write("\n".join(md_t))
open(os.path.join(OUT, "PROMPTS_BOSS_3.md"), "w", encoding="utf-8").write("\n".join(md_p))
print("ok")
