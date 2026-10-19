# Personajes seleccionables + método de animación compartida + prompts

## Personajes seleccionables (los 2 del creador)
| id | Rasgos que lo identifican |
|----|---------------------------|
| wadrid | Afro grande marrón oscuro, gafas negras rectangulares, polo verde oscuro, lanyard azul con credencial gris, jeans, zapatos marrones, piel morena media |
| marlonx_a | Pelo negro corto tipo casco, gafas negras, polo gris carbón con insignia dorada, lanyard azul, jeans, zapatos negros, piel morena clara |

Cada carpeta tiene: sprite 128×192 del juego, preview, hoja original de Runway (4 vistas) y una vista rápida.
`_animaciones_actuales_compartidas/` = los frames que usa hoy el combate (ver `_contacto_todas.png`).

### Por qué las actuales se ven mal
- Mezclan personajes: el cast del Mago usa a Wadrid, el guard del Guerrero es otro chico (pelo castaño, chaqueta).
- Escala distinta entre frames (el personaje crece/encoge), pies a distinta altura.
- Frames basura: un frame solo de jeans+lanyard, un destello amarillo suelto, el proyectil pegado en un frame.
- Ataques solo de frente/lado; todo sale de hojas distintas con estilos distintos.

---

## Método: UNA animación por clase que sirva a TODOS los personajes

**Recomendado: cuerpo compartido + cabeza intercambiable + recoloreo por paleta**

En estilo chibi la identidad está en la CABEZA (pelo, gafas, cara). El cuerpo es casi igual: polo, jeans, lanyard.

1. **Cuerpo-maniquí por clase (1 sola vez):** un estudiante genérico SIN pelo distintivo, con colores planos "clave":
   - polo = **magenta `#FF00FF`** (no verde, porque el fondo ya es verde menta)
   - piel = `#FFCC99`, pantalón = azul jeans, zapatos = marrón.
2. **Shader de paleta en Godot:** reemplaza el magenta por el color del polo de cada personaje (verde oscuro Wadrid, gris carbón MarlonX) y ajusta el tono de piel. Un solo set de frames → N personajes.
3. **Cabeza por personaje (Sprite2D hijo):** 3 vistas por personaje (frente, espalda, lado; el otro lado = `flip_h`). Se coloca en un **punto ancla** por frame (`head_offset`) que yo calculo automáticamente detectando la cabeza del maniquí en cada frame y guardo en un JSON.
4. **Lanyard/credencial** como overlay opcional o dibujado ya en el maniquí.

Resultado: nuevo personaje = 3 PNG de cabeza + 2 colores. Nueva clase = 1 hoja de maniquí.

**Alternativas descartadas:**
- *Paper-doll por capas completo* (cuerpo, ropa, pelo por separado en cada frame): la IA no mantiene capas alineadas entre frames.
- *Esqueleto 2D (Skeleton2D/Spine)*: una animación para todos, pero hay que despiezar y riggear; pierde el look pixel-art "a mano".
- *Hojas por personaje y clase*: 2 personajes × 3 clases × ~5 animaciones = 30 hojas que la IA no hará consistentes.

---

## Reglas para TODAS las generaciones (Runway)
- Adjunta la imagen de referencia (maniquí o personaje) en cada generación.
- **Una animación y una dirección por generación.** Pedir 4 filas × 3 direcciones rompe la consistencia.
- Direcciones: **abajo (frente), arriba (espalda), derecha**. Izquierda = espejo en Godot.
- Fondo menta liso `#A8E6A1`, sin sombras en el piso, sin texto, sin efectos sueltos fuera del personaje.
- Mismo tamaño en todas: pídelo explícito ("same scale in every frame, feet on the same baseline").
- Proyectiles y efectos (orbe, estela del tajo) en **hoja aparte**.

### Bloque de estilo (pegar al inicio de cada prompt)
```
2D pixel art sprite sheet, top-down 3/4 view action-RPG, 16-bit SNES style like A Link to the Past / Minish Cap, chibi proportions (head about 1/3 of body height), crisp 1-pixel dark outline, limited palette, no anti-aliasing, flat mint green background (#A8E6A1), single horizontal row of evenly spaced frames on a clear grid, identical character scale in every frame, feet on the same baseline, no ground shadow, no text, no UI.
```

---

## Prompt 0 — Maniquí base (hazlo primero; es la referencia de todo)
```
[ESTILO] Character turnaround, 3 frames in one row: facing down (front), facing up (back), facing right (side). A generic university student mannequin: short plain bald-ish head with neutral face and simple black rectangular glasses, flat magenta (#FF00FF) short-sleeve polo shirt with no details, blue lanyard with small grey ID card, blue jeans, brown shoes, light-tan skin (#FFCC99). Standing idle, arms relaxed at the sides.
```

## Prompt 1 — Caminar (todas las clases)
Repetir 3 veces cambiando `DIRECTION` por: `facing down toward the camera`, `facing up away from the camera`, `facing right in side profile`.
```
[ESTILO] Walk cycle, 6 frames, DIRECTION. Same mannequin as the reference image (magenta polo, lanyard, jeans). Arms swing opposite to legs, slight 1-pixel body bob, contact-passing-contact-passing poses, loopable. Hands empty.
```

## Prompt 2 — Guerrero (regla como espada, borrador como escudo)
**2a. Ataque (tajo)** — ×3 direcciones
```
[ESTILO] Melee attack, 6 frames, DIRECTION. Same mannequin as reference, holding a long wooden school ruler (30 cm, light yellow wood with black tick marks) as a sword in the right hand and a big pink rubber eraser as a small shield in the left hand. Frames: 1 ready stance, 2 wind-up ruler raised back, 3 fast horizontal slash, 4 follow-through with arm extended, 5 recover, 6 back to ready stance. No slash trail effects.
```
**2b. Guardia** — ×3 direcciones
```
[ESTILO] Guard / block, 3 frames, DIRECTION. Same mannequin holding the wooden ruler and the pink eraser shield. Frame 1 raising eraser, frame 2 eraser held firmly in front of the body, knees slightly bent (hold pose), frame 3 small recoil as if blocking a hit.
```
**2c. Efecto de tajo (hoja aparte)**
```
[ESTILO] Slash arc effect only, no character, 4 frames: white-light blue crescent swoosh that appears, widens and fades. Pixel art, 2-3 colors.
```

## Prompt 3 — Mago (bastón de rama, orbe azul)
**3a. Lanzar hechizo** — ×3 direcciones
```
[ESTILO] Spell cast, 5 frames, DIRECTION. Same mannequin holding a gnarled wooden branch staff with a small glowing blue crystal on top. Frames: 1 idle holding staff, 2 staff pulled back while crystal glows brighter, 3 staff thrust forward pointing in the facing direction, 4 hold pose, 5 return to idle. The orb projectile is NOT in this sheet.
```
**3b. Golpe con bastón** — ×3 direcciones
```
[ESTILO] Melee staff strike, 5 frames, DIRECTION. Same mannequin with the wooden branch staff held with both hands. Frames: 1 ready, 2 wind-up over the shoulder, 3 fast downward swing, 4 staff tip hitting forward, 5 recover.
```
**3c. Proyectil (hoja aparte)**
```
[ESTILO] Magic projectile only, no character, 4-frame loop: small glowing blue energy orb with white core and tiny sparkles trailing behind, flying to the right. Plus 3-frame impact burst in a second row.
```

## Prompt 4 — Chain (cable/látigo)
**4a. Látigo corto** — ×3 direcciones
```
[ESTILO] Quick whip attack, 5 frames, DIRECTION. Same mannequin holding a coiled black charger cable used as a whip in the right hand. Frames: 1 ready with cable coiled, 2 short wind-up, 3 fast crack with cable reaching about one body-length forward, 4 cable snapping back, 5 ready. Tight, fast motion.
```
**4b. Látigo largo** — ×3 direcciones
```
[ESTILO] Heavy long whip attack, 7 frames, DIRECTION. Same mannequin with the black charger cable whip. Frames: 1 ready, 2-3 big overhead wind-up spinning the cable, 4 wide forward lash, 5 cable fully extended about three body-lengths forward in a wide arc, 6 pulling back, 7 ready. Slower and wider than a quick whip.
```

## Prompt 5 — Cabezas por personaje (para el método de cabeza intercambiable)
Adjuntar la hoja original del personaje como referencia.

**Wadrid**
```
[ESTILO] Head only, no body, 3 frames in one row: front view, back view, right side view. Large round dark-brown afro hair, black rectangular glasses, warm medium-brown skin, friendly smile, same proportions and pixel size as the reference character.
```
**MarlonX-a**
```
[ESTILO] Head only, no body, 3 frames in one row: front view, back view, right side view. Short straight black helmet-shaped hair, black rectangular glasses, light-brown skin, small smile, same proportions and pixel size as the reference character.
```

---

## Checklist al recibir cada hoja
- [ ] Mismo tamaño de personaje en todos los frames
- [ ] Pies alineados
- [ ] Polo realmente magenta liso (para el shader)
- [ ] Nada suelto fuera del personaje (efectos van aparte)
- [ ] Nombre de archivo: `<clase>_<anim>_<dir>.png`, ej. `guerrero_attack_down.png`

Con las hojas yo me encargo de: recortar, quitar el fondo, normalizar escala/baseline, calcular anclas de cabeza y montar el shader de paleta en Godot.

---

## ACTUALIZACIÓN — 16 personajes nuevos (originales/) integrados con cuerpo compartido

Los 16 personajes (`personajes_seleccionables/originales/`) ya comparten proporciones y cuerpo
(camisa celeste + jeans), así que el método de **cabeza intercambiable** funciona sin rehacerlos.
Prueba visual: `assets/sprites/characters/_preview_cabeza_cuerpo_compartido.png`
(columna 1 = original; columnas 2-4 = su cabeza sobre el cuerpo compartido, frente/espalda/lado).

### Qué se generó (automático, `tools/character_split/`)
- `assets/sprites/characters/heads/<id>_{front,back,right}.png` — 48 cabezas pixel-art limpias, escaladas al cuerpo base.
- `assets/sprites/characters/body_base/{front,back,right}.png` — cuerpo base (camisa celeste + jeans).
- `assets/sprites/characters/characters.json` — por personaje: nombre, color de camisa/pantalón y punto ancla del cuello de cada cabeza.

### Cómo se combinan en el juego
1. **Cuerpo animado** (uno por clase): AnimatedSprite2D con el cuerpo base.
2. **Ropa** = recoloreo por shader: la camisa celeste y los jeans se detectan por color y se pintan con `shirt`/`pants` del JSON
   (hoodie → rojo, trajes → azul/negro, chaqueta → negro + gris, futbolista → rojo + short negro, explorador → marrón + caqui).
3. **Cabeza** = Sprite2D encima, colocada en el ancla del cuello de cada frame.

### Qué se pierde / pendiente
- Detalles de ropa: rayas del futbolista, corbata, bolsillos del chaleco, cordones del hoodie → overlays pequeños opcionales.
- Pelo/accesorios que bajan por la espalda: **coleta, trenza, mochila, bufanda** → overlay "accesorio" aparte (se recorta de su hoja original).
- Solo 1 imagen por vista; para caminar/atacar hacen falta las hojas del cuerpo base animado (abajo).

### CAMBIO en los prompts de animación
Ya NO hace falta el maniquí magenta. La referencia a adjuntar es **`originales/rapado.png`**
(cabeza pequeña = cualquier cabeza lo tapa; camisa celeste y jeans = fáciles de recolorear).
En todos los prompts 1-4 reemplaza "Same mannequin…(magenta polo, lanyard, jeans)" por:
```
Same character as the reference image: short buzz-cut brown hair, light blue button-up shirt with short sleeves, dark blue jeans, white sneakers. Keep the exact same proportions, head size and colors in every frame.
```
Y NO pidas lanyard ni polo magenta. El Prompt 5 (cabezas) ya no es necesario: las cabezas salen de los 16 originales.
