"""Genera GROKBOT_BOSS_9_EPICO.md y PROMPTS_BOSS_9_EPICO.md: segunda ronda del boss 9 SUDO para ataques más épicos.
- E: una hoja de 8 POSES DE PODER de SUDO (misma escala que las poses de la primera ronda).
- F: 5 hojas de EFECTOS ANIMADOS (8 cuadros cada una, en orden de animación) que reemplazan los efectos dibujados por código:
     rayo verde, explosión de fuego, explosión cósmica (ASTRA), llamarada del sol y estallido digital.
Los efectos verdes van sobre fondo MAGENTA (el menta se confundiría con el verde); el resto sobre menta.
Uso: python tools/gen_prompts_boss9_epico.py  (escribe en referencias_animacion/, o en OUT si se define)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_prompts_boss9 as b9  # noqa: E402

OUT = os.environ.get("OUT", b9.OUT)

PIX = ("2D pixel art game asset for a top-down 3/4 view action-RPG, 16-bit SNES style, crisp black outline, "
       "hard square pixels, no anti-aliasing, no blur, no smooth gradients, no painterly shading. ")
BG_MINT = "Flat solid mint green background (#A0EFA5) everywhere, no ground, no shadows, no scenery. "
BG_MAGENTA = ("Flat solid pure MAGENTA background (#FF00FF) everywhere, no ground, no shadows, no scenery "
              "(the magenta is only the background: do NOT use magenta or pink anywhere in the effect). ")
NOTEXT_POSE = ("No text, no letters, no numbers, no logos, no brand marks, no UI, no frame borders, "
               "no motion lines, no glow halos, no energy, no particle effects, no blood.")
NOTEXT_FX = ("No text, no letters, no numbers, no symbols, no logos, no UI, no frame borders, no characters, no people, "
             "no hands, no blood.")

FRAMES8 = ("Exactly 8 animation FRAMES of the SAME effect in ONE image, arranged in a grid of 4 columns and 2 rows, in time order "
           "(read left to right, top row first: frame 1 is the start, frame 8 is the end). Every frame is centered in its own cell, "
           "all frames at the SAME scale and the SAME center point, lots of empty space between cells, nothing touching the image edges "
           "or crossing into another cell. Landscape image (3:2). ")
FXSTYLE = ("Copy the pixel size, outline thickness and palette style of the effects in the first attached image "
           "(style reference only: do NOT copy its items). The second attached image shows the boss only as a SIZE reference "
           "(do NOT draw him). Bold, bright, high-contrast and very dramatic, like the big boss attacks of Chrono Trigger and Secret of Mana. ")

FULL = b9.FULL
IDLE = "`_entregas_runway/bosses/boss_sudo_idle_walk8.png`"
FXREF = "`_entregas_runway/bosses/boss_sudo_projectiles.png`"

TASKS = [
 ("E", "boss_sudo_power8.png", FULL, IDLE,
  PIX + BG_MINT + b9.PERSON.replace("the man in the PHOTO attached as the first image", "the boss in the first attached image (the approved pixel version of the real man)").replace("exactly like the photo", "exactly like the first image").replace("as in the photo", "as in the first image") +
  "SAME CHARACTER RULE: copy the EXACT design, face, beard, hair, clothes, palette, pixel size and SCALE of the boss in the first attached image; "
  "the second attached image shows his other poses: his standing height must be the SAME as there. " + b9.POSES8 +
  "These are his most POWERFUL and DRAMATIC attack poses, full of tension, like a final boss of a 16-bit action RPG. "
  "Pose 1: power stance charging energy: legs wide apart and knees bent, both fists clenched at the waist, head down, intense frown. "
  "Pose 2: the same stance but head up SHOUTING with the mouth wide open, chest out, fists trembling. "
  "Pose 3: LEAPING DASH to the RIGHT of the image, body almost horizontal in the air, one knee forward, both feet off the ground, determined face. "
  "Pose 4: ground SLAM: down on one knee, the clicker hand punching the floor hard, the other arm back, angry face. "
  "Pose 5: SUMMONING: both arms stretched straight up to the sky, looking up, chest out, feet planted (clicker still in hand). "
  "Pose 6: THROWING: leaning forward, both arms thrust toward the viewer with the palms open, one foot forward. "
  "Pose 7: STRUGGLE / PUSHING: both palms forward, body leaning, feet braced and sliding, teeth gritted, sweating. "
  "Pose 8: VICTORY: confident big grin, the clicker hand raised high, the other hand in a fist at the chest. " + NOTEXT_POSE,
  "Poses de poder (cargar, gritar, embestida en el aire, golpe al piso, invocar, lanzar, forcejeo y victoria). Misma escala que las poses anteriores."),
 ("F", "boss_sudo_fx_bolt8.png", FXREF, FULL,
  PIX + BG_MAGENTA + FXSTYLE + FRAMES8 +
  "The effect is a huge GREEN LIGHTNING STRIKE (bright neon green #3ECF8E and white core, dark green outline) falling from the sky onto the ground. "
  "Each cell is TALL: the lightning comes from the TOP of the cell and hits the ground at the BOTTOM CENTER of the cell. "
  "Frame 1: a thin flickering green spark line starts at the top. Frame 2: a jagged thin bolt reaches halfway down. "
  "Frame 3: the full THICK jagged bolt with a white-hot core and 2-3 side branches hits the ground. Frame 4: the bolt at its brightest, wider, "
  "with a flat oval burst of electricity on the ground. Frame 5: the bolt thinning while a big flat ring of green electric arcs spreads on the ground. "
  "Frame 6: the bolt gone, only the electric ring and green sparks jumping on the ground. Frame 7: small fading green sparks. "
  "Frame 8: a few last tiny sparks. " + NOTEXT_FX,
  "Rayo verde de Supabase (fondo MAGENTA, no menta)."),
 ("F", "boss_sudo_fx_fire8.png", FXREF, FULL,
  PIX + BG_MINT + FXSTYLE + FRAMES8 +
  "The effect is a big FIRE EXPLOSION seen from a top-down 3/4 view, sitting on the ground (orange, yellow, red, white-hot center, dark red outline). "
  "Frame 1: a small bright white-yellow spark. Frame 2: a growing fireball. Frame 3: a big round fireball with flames bursting outward. "
  "Frame 4: the explosion at full size, a huge flaming burst with a flat ring of fire on the ground. "
  "Frame 5: the fireball breaking apart into flames and flying embers. Frame 6: flames shrinking, dark smoke puffs appearing. "
  "Frame 7: mostly grey-brown smoke with a few embers. Frame 8: thin fading smoke wisps. " + NOTEXT_FX,
  "Explosión de fuego (supernova, placas tectónicas)."),
 ("F", "boss_sudo_fx_cosmic8.png", FXREF, FULL,
  PIX + BG_MINT + FXSTYLE + FRAMES8 +
  "The effect is a COSMIC STAR EXPLOSION, the impact of a spiral galaxy attack: deep violet, purple, electric blue and white, with tiny star sparkles. "
  "Frame 1: a small bright white star point with 4 rays. Frame 2: a growing violet orb with a tiny spiral inside. "
  "Frame 3: a big glowing violet-blue sphere with a white spiral galaxy swirling inside and star rays. "
  "Frame 4: the explosion at full size: a huge starburst with long white rays, a violet shockwave ring and many star sparkles. "
  "Frame 5: the starburst breaking into a ring of stars spinning outward. Frame 6: a wide ring of fading stars and violet dust. "
  "Frame 7: scattered blue and white stardust. Frame 8: a few last twinkling stars. " + NOTEXT_FX,
  "Explosión cósmica (golpe final del ASTRA)."),
 ("F", "boss_sudo_fx_sun8.png", FXREF, FULL,
  PIX + BG_MINT + FXSTYLE + FRAMES8 +
  "The effect is the SUN about to fire a SOLAR FLARE: a blazing round sun core (white-yellow center, orange, red edges) with a fiery corona. "
  "Frames 1-4: CHARGING loop: the sun core with its flaming corona flickering and growing a little each frame, solar prominences "
  "(arcs of fire) looping around it. Frames 5-8: FIRING loop: the sun at its biggest, the corona flaring out wide and wild, "
  "a short thick burst of flame shooting out to the RIGHT of the cell (the start of a beam), flickering differently in each frame. "
  "All frames centered on the same point. " + NOTEXT_FX,
  "Sol cargando (1-4) y disparando la llamarada (5-8)."),
 ("F", "boss_sudo_fx_data8.png", FXREF, FULL,
  PIX + BG_MINT + FXSTYLE + FRAMES8 +
  "The effect is a DIGITAL GLITCH EXPLOSION, like computer code being rewritten and blown apart: electric blue (#4A9EFF), cyan and white, "
  "made of square pixels, small square blocks and thin scan lines (NO letters, NO numbers, NO symbols). "
  "Frame 1: a small bright white square flash. Frame 2: a growing blue square burst with glitchy horizontal offset lines. "
  "Frame 3: a big blast of blue and cyan pixel blocks flying outward from the center. Frame 4: full size: a square-ish shockwave of pixels "
  "and a flat ring on the ground. Frame 5: the blocks scattering in all directions. Frame 6: scattered blocks falling and fading. "
  "Frame 7: a few small glitchy blocks. Frame 8: tiny last pixels. " + NOTEXT_FX,
  "Estallido digital (Cmd+K, aterrizaje del Tab, golpe de Edge Function)."),
]

SECTIONS = {
    "E": "E · Poses de poder (8 poses, 4x2)",
    "F": "F · Efectos animados (8 cuadros cada uno, 4x2, en orden)",
}


def main():
    p = ["# PROMPTS BOSS 9 · RONDA ÉPICA: SUDO (%d hojas)\n" % len(TASKS),
         "Cada bloque: archivo a guardar en `_entregas_runway/bosses/`, Imagen 1 e Imagen 2 (rutas dentro de `referencias_animacion/`) y el prompt.\n"]
    g = ["# TAREA PARA GROKBOT — Boss 9 SUDO, ronda ÉPICA (%d hojas)\n" % len(TASKS),
         "Proyecto: `C:\\Users\\leopo\\Documents\\Juegos\\Godot\\prototipo` (rutas relativas a `referencias_animacion/`).",
         "Prompts: `referencias_animacion/PROMPTS_BOSS_9_EPICO.md`. Primera ronda (ya integrada): `GROKBOT_BOSS_9.md`.\n",
         "## Qué se pide",
         "Que los ataques de SUDO se vean más épicos: una hoja de poses de poder del boss y 5 hojas de efectos animados "
         "(8 cuadros cada una, en orden de animación) que reemplazan los efectos que hoy se dibujan con líneas.",
         "- E: poses de poder (1 hoja). **Hacerla primero y avisar**: Johan revisa que siga pareciéndose a él.",
         "- F: efectos animados (5 hojas): rayo verde, explosión de fuego, explosión cósmica, sol con llamarada y estallido digital.\n",
         "## Reglas clave",
         "- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.",
         "- E: mismo SUDO de la hoja aprobada (cara, barba, ropa) y la MISMA estatura que en `boss_sudo_idle_walk8.png`. Clicker en la mano del lado IZQUIERDO de la imagen y reloj en la muñeca del lado DERECHO. Sin efectos dibujados (la energía la pone el código).",
         "- F: los 8 cuadros en orden, todos centrados en el mismo punto y al mismo tamaño, cada uno dentro de su celda sin tocar a los vecinos.",
         "- **Fondo:** `boss_sudo_fx_bolt8` va sobre fondo MAGENTA #FF00FF (el rayo es verde); todas las demás sobre menta #A0EFA5.",
         "- Sin texto, números, símbolos ni logos en ningún lado (el estallido digital es solo de cuadritos, sin letras).",
         "- Si ChatGPT falla 2 veces (cuadros desordenados, cambia el personaje, mete texto), probar Gemini. Si falla otra vez, `[!]` con nota.\n",
         "## Guardado",
         "`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. "
         "No toques código, `assets/`, `scenes/` ni `scripts/`.\n",
         "## Progreso\n"]
    cur = None
    for sec, name, i1, i2, prompt, note in TASKS:
        if sec != cur:
            cur = sec
            p.append("\n## %s\n" % SECTIONS[sec])
            g.append("\n### %s" % SECTIONS[sec])
        extra = " (%s)" % note if note else ""
        p.append("### `%s`\n- Imagen 1: %s · Imagen 2: %s%s\n```\n%s\n```\n" % (name, i1, i2, extra, prompt))
        g.append("- [ ] `%s`%s" % (name, (" — " + note) if note else ""))
    g.append("\n## Notas de grokbot\n(resumen al terminar: herramienta usada en cada hoja y qué falló)\n")
    os.makedirs(OUT, exist_ok=True)
    for fn, lines in (("PROMPTS_BOSS_9_EPICO.md", p), ("GROKBOT_BOSS_9_EPICO.md", g)):
        path = os.path.join(OUT, fn)
        if fn.startswith("GROKBOT") and os.path.exists(path):
            print("ya existe (no se pisa el progreso):", path)
            continue
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        print("escrito", path)


if __name__ == "__main__":
    main()
