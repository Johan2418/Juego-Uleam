"""Genera GROKBOT_BOSS_9.md y PROMPTS_BOSS_9.md (boss 9 SUDO, el Líder del Club IA).
A diferencia de los bosses 1-8 (robots armados por piezas), SUDO es una persona: se anima por POSES
(hojas de 8 poses en 4x2, como las de los personajes jugables), no por piezas sueltas.
Referencia de cara y ropa: referencias_animacion/bosses/sudo_referencia.jpg (foto que mandó Johan).
Uso: python tools/gen_prompts_boss9.py  (escribe en referencias_animacion/, o en OUT si se define)."""
import os
OUT = os.environ.get("OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "referencias_animacion"))

STYLE = ("2D pixel art game asset for a top-down 3/4 view action-RPG, 16-bit SNES style, crisp 1-pixel black outline, "
         "hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. "
         "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. ")
NOTEXT = ("No text, no letters, no numbers, no logos, no brand marks, no labels, no UI, no frame borders, "
          "no motion lines, no speed lines, no glow halos, no particle effects, no blood.")
PERSON = ("The boss is called SUDO, the leader of the university AI club: a friendly but confident adult man who gives tech talks. "
          "LIKENESS RULE: he must clearly look like the man in the PHOTO attached as the first image (same face shape, same short dark hair combed back "
          "with a slightly high forehead, same FULL DARK BEARD neatly trimmed, same warm light-brown skin, same calm smile), drawn as a pixel-art "
          "chibi caricature with a slightly big head, NOT realistic. "
          "Clothes exactly like the photo: plain BLACK crew-neck T-shirt with a TINY white print on the left chest (just 2 small white lines, no readable text), "
          "slim LIGHT CREAM / off-white pants, BLACK low sneakers with WHITE soles, a black SMARTWATCH on his LEFT wrist "
          "(the arm on the RIGHT side of the image, as in the photo). In his OTHER hand (the hand on the LEFT side of the image) he holds a small black "
          "presentation CLICKER (slide remote) with a tiny red light. ")
STYLE2 = ("STYLE RULE: copy ONLY the pixel size, outline thickness, proportions style and shading of the character in the second attached image; "
          "do NOT copy that character's face, hair, clothes or colors (it is a different person). ")
SAME = ("SAME CHARACTER RULE: copy the EXACT design, face, beard, hair, clothes, palette, pixel size and scale of the boss in the first attached image. "
        "The second attached image is the real PHOTO of the same man: use it only to keep the face and beard looking like him. ")
POSES8 = ("Exactly 8 full-body poses of the SAME character in ONE image, arranged in a grid of 4 columns and 2 rows (read left to right, top row first), "
          "all the same size and scale, all in the same three-quarter FRONT view facing the viewer, feet on the same baseline in each row, "
          "lots of empty space between them, nothing touching the image edges. Landscape image (3:2). ")
SMALL = "Copy the pixel size, outline and palette style of the boss in the first attached image (it is ONLY a style reference: do NOT draw him). "


def grid(n, cols, rows):
    return (f"Exactly {n} items in ONE image, arranged in a grid of {cols} columns and {rows} rows "
            f"(read left to right, top row first), evenly spaced, not touching, wide margin. ")


PHOTO = "`bosses/sudo_referencia.jpg`"
FULL = "`_entregas_runway/bosses/boss_sudo_full.png`"
STUDENT = "`_entregas_runway/wadrid_idle_down.png`"

TASKS = [
 ("A", "boss_sudo_full.png", PHOTO, STUDENT,
  STYLE + PERSON + STYLE2 +
  "Draw ONE single big full-body pose, centered, three-quarter FRONT view facing the viewer, standing relaxed and confident, "
  "the clicker hand slightly raised at chest height, the other arm relaxed. He is about 2 times as tall as the student in the second attached image "
  "(the second image is ONLY a size and style reference: do NOT draw the student). Portrait image (3:4). " + NOTEXT,
  "Primera y más importante: las demás hojas copian esta. Revisarla con Johan (que se parezca a él) antes de seguir."),
 ("B", "boss_sudo_idle_walk8.png", FULL, PHOTO,
  STYLE + SAME + POSES8 +
  "Poses 1-4: IDLE breathing loop, standing, tiny differences (chest up and down, clicker hand bobbing). "
  "Poses 5-8: WALKING loop toward the viewer (left foot forward, passing, right foot forward, passing), arms swinging gently. " + NOTEXT, ""),
 ("B", "boss_sudo_cast8.png", FULL, PHOTO,
  STYLE + SAME + POSES8 +
  "Poses 1-2: raising the clicker hand (LEFT side of the image) high above the head (anticipation, then fully up). "
  "Poses 3-4: pointing the clicker straight forward at the viewer like pressing next slide (arm extended). "
  "Poses 5-6: both arms spread wide open to the sides like presenting something big. "
  "Poses 7-8: BOTH arms raised high above the head, palms up, like summoning something huge in the sky (empty hands except the clicker). " + NOTEXT, ""),
 ("B", "boss_sudo_moves8.png", FULL, PHOTO,
  STYLE + SAME + POSES8 +
  "Pose 1: crouching and leaning forward ready to dash. Pose 2: dashing to the RIGHT, body leaning strongly, one leg back. "
  "Pose 3: stomping one foot hard on the floor, fists down. Pose 4: waving hello with the watch hand (RIGHT side of the image), smiling. "
  "Pose 5: presenting gesture, open palm of the watch hand (RIGHT side of the image) to the side. Pose 6: thinking, watch hand on the beard. "
  "Pose 7: laughing confidently, hands on hips. Pose 8: standing straight, neutral (height reference). " + NOTEXT, ""),
 ("B", "boss_sudo_hurt8.png", FULL, PHOTO,
  STYLE + SAME + POSES8 +
  "Poses 1-2: hurt flinch, leaning back, eyes squeezed shut. "
  "Poses 3-4: dizzy and confused, watch hand on his head, eyes as swirls (overloaded, CONTEXT OVERFLOW). "
  "Poses 5-6: down on one knee, tired, clicker hanging from the hand. "
  "Poses 7-8: standing with arms slightly open, head tilted up, body starting to turn pale and dissolve into tiny white and violet star pixels "
  "at the edges (his defeat: fading into stardust). " + NOTEXT, ""),
 ("C", "boss_sudo_screen.png", FULL, STUDENT,
  STYLE + SMALL + grid(3, 3, 1) +
  "Each item is a floating PROJECTOR SCREEN panel (a slim dark grey frame around a flat rectangular screen, landscape 16:9), seen from the front, "
  "no stand, no legs. Item 1: the screen ON with a plain dark green surface (EMPTY, nothing written). "
  "Item 2: the SAME screen with a crack and a dented frame (screen empty, dark). Item 3: the SAME screen turned OFF, black, frame bent. "
  "Landscape image (3:2). " + NOTEXT, "Pantalla vacía: los textos de la diapositiva los dibuja el código."),
 ("C", "boss_sudo_minions.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Items 1-4: a small cute black ROBOT helper about as tall as the student's knee: round black head with a single diagonal WHITE visor stripe, "
  "a small antenna with a green tip, a boxy black body and two short legs; 4 walking frames. "
  "Item 5: the SAME robot holding up a small glowing square of colored pixels (painting). "
  "Item 6: the SAME robot broken, visor cracked, sitting. "
  "Items 7-8: a white computer mouse-pointer ARROW with a black outline, floating, as a small creature with a tiny blue spark at the tip; "
  "item 8 the same arrow tilted, clicking. Landscape image (3:2). " + NOTEXT, "Grokbot (1-6) y el cursor-agente (7-8). Sin logos."),
 ("C", "boss_sudo_planets.png", FULL, STUDENT,
  STYLE + SMALL + grid(6, 3, 2) +
  "Top row: three small round celestial bodies, each about the size of the student's head: "
  "item 1 the EARTH (blue oceans, green continents, white clouds), item 2 the MOON (pale grey with craters), "
  "item 3 the SUN (orange-yellow ball with short pixel flame rays around it). "
  "Bottom row: the SAME three but turned OFF: darker, desaturated, with a small crack (items 4, 5, 6 in the same order). "
  "Landscape image (3:2). " + NOTEXT, "Terra, Luna y Sol que orbitan en la fase 3, normales y apagados."),
 ("C", "boss_sudo_props.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Item 1: a small glowing GREEN CUBE like a database block (isometric, bright green edges). "
  "Item 2: a purple PADLOCK, closed. Item 3: the SAME padlock open. Item 4: a small golden KEY. "
  "Item 5: a brown ROCK PILLAR coming out of the floor, about as tall as the student. "
  "Item 6: a black presentation CLICKER on the floor. Item 7: a white rounded CARD with a purple border (empty, nothing written). "
  "Item 8: a crescent MOON shape glowing pale blue (a boomerang projectile). Landscape image (3:2). " + NOTEXT, ""),
 ("C", "boss_sudo_projectiles.png", FULL, STUDENT,
  STYLE + SMALL + grid(8, 4, 2) +
  "Item 1: a round ball of GREEN ELECTRICITY with tiny lightning arcs. Item 2: a jagged GREEN LIGHTNING BOLT (vertical, long). "
  "Item 3: a small square block of 4 colored pixels (pink, cyan, yellow, green). Item 4: a small brown ROCK. "
  "Item 5: a white text-cursor block (a thin vertical bar) with a grey ghost trail. Item 6: a small purple padlock projectile. "
  "Item 7: a big glowing ball of white and violet light with a tiny spiral galaxy inside (the ASTRA attack). "
  "Item 8: a swirl of tiny white, blue and violet star pixels (stardust). Landscape image (3:2). " + NOTEXT, ""),
]

ARENAS = [
 ("D", "arena_sudo.png", FULL, STUDENT,
  "2D pixel art game background for a top-down 3/4 view action-RPG, 16-bit SNES style like the boss rooms of A Link to the Past and Secret of Mana, "
  "crisp black outlines, hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. ONE single closed BOSS ARENA ROOM seen from above "
  "in three-quarter top-down view, filling the whole image edge to edge, no black borders. LAYOUT RULE (very important): the BACK WALL runs across the TOP of the image "
  "and takes about the top 15 percent of the height, seen from the front, with all the big decorations; the LEFT and RIGHT walls are thin borders about 8 percent of the width each; "
  "the BOTTOM edge is a thin wall border about 5 percent of the height. Everything else (the big central area, about 84 percent wide and 80 percent tall) is ONE large OPEN FLOOR, "
  "flat and empty, with a calm low-contrast pattern: NO objects, NO furniture, NO characters, NO holes and NO big marks in it, so the game characters stay easy to see on top of it. "
  "Small decorations only along the walls and in the corners. Theme: a modern university TECH TALK AUDITORIUM of an AI club. Floor: dark blue-grey carpet. "
  "Back wall: a wide wooden stage edge with a huge BLANK projection screen glowing soft green, two speakers, a small podium with a laptop, and stage spotlights above. "
  "Side walls: rows of red auditorium seats in shadow (empty, no people), a camera tripod, cable runs, potted plants. "
  "Colors: dark blue-grey, warm wood, green screen glow, red seats, black. Scale: one carpet tile is about as wide as the student in the second attached image "
  "(the student is ONLY a scale reference: do NOT draw him). Copy the pixel size, outline thickness and palette style of the boss in the first attached image "
  "(style reference only: do NOT draw the boss). Landscape image (3:2). No text, no letters, no numbers, no logos, no signs with writing, no UI, no people, no characters, no creatures, no blood.",
  ""),
 ("D", "arena_sudo_caos.png", "`_entregas_runway/arenas/arena_sudo.png`", FULL,
  "2D pixel art game background for a top-down 3/4 view action-RPG, 16-bit SNES style like the boss rooms of A Link to the Past and Secret of Mana, "
  "crisp black outlines, hard square pixels, no anti-aliasing, no blur, no gradients, no painterly shading. The first attached image is the SAME room: copy it EXACTLY, "
  "same layout, same walls, same camera, same floor area, same size and same pixel style. Only change it into the FINAL PHASE version of the fight: "
  "the ceiling above the stage has OPENED to OUTER SPACE, showing a deep violet starry sky with a big spiral galaxy, small floating rocks, "
  "the projection screen glowing violet, seats lit by starlight. The central floor must stay OPEN and readable, with only small cracks and star sparkles near the walls. "
  "Landscape image (3:2). No text, no letters, no numbers, no logos, no signs with writing, no UI, no people, no characters, no creatures, no blood.",
  ""),
]

SECTIONS = {
 "A": "A · Boss completo (hacer primero y revisar con Johan)",
 "B": "B · Poses del boss (hojas de 8 poses, 4x2)",
 "C": "C · Pantalla, esbirros, astros, objetos y proyectiles",
 "D": "D · Arena (fondo pintado, fase 1-2 y fase 3)",
}


def main():
    allt = TASKS + ARENAS
    p = ["# PROMPTS BOSS 9: SUDO, el Líder del Club IA (%d hojas)\n" % len(allt),
         "Cada bloque: archivo a guardar en `_entregas_runway/bosses/` (las de D en `_entregas_runway/arenas/`), Imagen 1 e Imagen 2 (rutas dentro de `referencias_animacion/`) y el prompt.\n"]
    g = ["# TAREA PARA GROKBOT — Boss 9: SUDO, el Líder del Club IA (%d hojas)\n" % len(allt),
         "Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a `referencias_animacion/`).",
         "Prompts: `referencias_animacion/PROMPTS_BOSS_9.md`. Diseño (Claude Doc): https://claude.ai/artifact/2JUPWg5GXDgzCFkxQMgdjT\n",
         "## Qué se pide",
         "El boss 9 del Club IA: un expositor (persona real, foto en `bosses/sudo_referencia.jpg`) con clicker y pantalla de proyector. "
         "Es el ÚNICO boss humano: NO se arma por piezas como los bosses 1 a 8, se anima por POSES (hojas de 8 poses en 4x2, como los personajes jugables).",
         "- A: el boss completo (1 hoja). **Hacerla primero y avisar**: Johan revisa que se parezca a él. Las demás usan esta como Imagen 1.",
         "- B: poses del boss (4 hojas de 8 poses).",
         "- C: pantalla, esbirros, astros, objetos y proyectiles (5 hojas).",
         "- D: arena pintada (2 imágenes, después de A).\n",
         "## Reglas clave",
         "- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.",
         "- Que se PAREZCA a la foto (cara, barba, pelo, ropa), pero en caricatura pixel art chibi, no realista.",
         "- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.",
         "- SIN TEXTO NI LOGOS: nada de marcas (Supabase, Cursor, Clerk, Grok, OpenAI...). La camiseta solo lleva 2 rayitas blancas; el código escribe \"CLUB IA\".",
         "- La pantalla del proyector va VACÍA: las diapositivas las dibuja el código.",
         "- En las hojas de poses: como en la hoja A aprobada: clicker en la mano del lado IZQUIERDO de la imagen y reloj en la muñeca del lado DERECHO; misma escala en las 8 poses.",
         "- Si ChatGPT falla 2 veces (no se parece, cambia ropa, pone texto), probar Gemini. Si falla otra vez, `[!]` con nota.\n",
         "## Guardado",
         "`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png` (arenas en `_entregas_runway/arenas/`). Marca `[x]` al guardar; `[!]` con nota si falla. "
         "No toques código, `assets/`, `scenes/` ni `scripts/`.\n",
         "## Progreso\n"]
    cur = None
    for sec, name, i1, i2, prompt, note in allt:
        if sec != cur:
            cur = sec
            p.append("\n## %s\n" % SECTIONS[sec])
            g.append("\n### %s" % SECTIONS[sec])
        extra = " (%s)" % note if note else ""
        p.append("### `%s`\n- Imagen 1: %s · Imagen 2: %s%s\n```\n%s\n```\n" % (name, i1, i2, extra, prompt))
        g.append("- [ ] `%s`%s" % (name, (" — " + note) if note else ""))
    g.append("\n## Notas de grokbot\n(resumen al terminar: herramienta usada en cada hoja y qué falló)\n")
    os.makedirs(OUT, exist_ok=True)
    for fn, lines in (("PROMPTS_BOSS_9.md", p), ("GROKBOT_BOSS_9.md", g)):
        path = os.path.join(OUT, fn)
        if fn.startswith("GROKBOT") and os.path.exists(path):
            print("ya existe (no se pisa el progreso):", path)
            continue
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        print("escrito", path)


if __name__ == "__main__":
    main()
