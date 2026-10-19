# Prompts de animación — cuerpo compartido (Prototipo Campus)

Todas las animaciones se hacen **una sola vez** con el personaje **rapado**. En el juego su cabeza se
reemplaza por la del personaje elegido y la ropa se recolorea, así que sirven para los 18 personajes.

---

## 1. Cómo generar (léelo antes)

1. **Adjunta siempre la referencia de la misma dirección** que pides (carpeta `01_REFERENCIA_PRINCIPAL_rapado/`):
   | Dirección | Imagen a adjuntar | Texto `{DIRECTION}` |
   |---|---|---|
   | Abajo (frente) | `ref_rapado_abajo_frente.png` | `facing down toward the camera (front view)` |
   | Arriba (espalda) | `ref_rapado_arriba_espalda.png` | `facing up away from the camera (back view)` |
   | Derecha (lado) | `ref_rapado_derecha_lado.png` | `facing right in side profile` |
   Izquierda NO se genera: el juego espeja la derecha.
2. **Una animación + una dirección por generación.** Nunca pidas varias filas o direcciones juntas.
3. Pega el **BLOQUE A (estilo)** + **BLOQUE B (personaje)** + el prompt de la animación, con `{DIRECTION}` reemplazado.
4. Guarda el resultado en `_entregas_runway/` con el nombre indicado (ej. `walk_down.png`). Yo recorto, limpio el fondo,
   alineo pies, calculo el cuello de cada frame y genero las máscaras de ropa.
5. Si una generación sale con el personaje de otro tamaño, otra ropa o frames desalineados: **repítela**, no la arregles.

---

## 2. Bloques fijos (copiar tal cual)

**BLOQUE A — estilo**
```
2D pixel art sprite sheet, top-down 3/4 view action-RPG, 16-bit SNES style like A Link to the Past / Minish Cap, chibi proportions (big head about 45% of body height), crisp 1-pixel black outline, limited palette, hard pixels, no anti-aliasing, no blur. Flat solid mint green background (#A0EFA5) filling the whole image. Single horizontal row of evenly spaced frames on a clear invisible grid, same character scale in every frame, feet on the same baseline, no ground shadow, no text, no numbers, no UI, no border.
```

**BLOQUE B — personaje (es el de la imagen adjunta)**
```
Same character as the reference image: short brown buzz-cut hair, simple face with two dot eyes, light blue short-sleeve button-up shirt, dark blue jeans, white sneakers, medium tan skin. Keep exactly the same proportions, head size, outline thickness and colors as the reference in every frame.
```

**Reglas para que encaje con las cabezas (agregar al final de cada prompt)**
```
Keep the head upright and the same size in every frame (only small 1-pixel bobbing). Do not tilt or rotate the head. Hands, weapons and effects must never cover the face or head. Nothing touches the frame edges.
```

**Prompt negativo** (si la herramienta lo permite)
```
blurry, anti-aliasing, gradient background, shadow, 3D, realistic, extra characters, text, watermark, different outfit, hat, glasses, long hair, cropped frames, inconsistent size
```

---

## 3. Lista completa (27 generaciones de cuerpo + 4 de efectos)

| # | Archivo | Animación | Frames | Direcciones |
|---|---|---|---|---|
| 1 | `idle_{dir}.png` | Respirar / esperar | 4 | down, up, right |
| 2 | `walk_{dir}.png` | Caminar | 6 | down, up, right |
| 3 | `hurt_{dir}.png` | Recibir golpe | 3 | down, up, right |
| 4 | `guerrero_attack_{dir}.png` | Tajo con regla | 6 | down, up, right |
| 5 | `guerrero_guard_{dir}.png` | Guardia con borrador | 3 | down, up, right |
| 6 | `mago_cast_{dir}.png` | Lanzar hechizo | 5 | down, up, right |
| 7 | `mago_melee_{dir}.png` | Golpe con bastón | 5 | down, up, right |
| 8 | `chain_whip_short_{dir}.png` | Latigazo corto | 5 | down, up, right |
| 9 | `chain_whip_long_{dir}.png` | Latigazo largo | 7 | down, up, right |
| E1 | `fx_slash.png` | Estela del tajo | 4 | — |
| E2 | `fx_orb.png` | Orbe mágico + impacto | 4 + 3 | — |
| E3 | `fx_whip_crack.png` | Chispa del látigo | 3 | — |
| E4 | `fx_hit.png` | Impacto genérico | 3 | — |

Orden recomendado: **2 (walk) → 1 (idle) → 4 → 6 → 8** (con eso ya se puede jugar), luego el resto.

---

## 4. Prompts de animación (BLOQUE A + BLOQUE B + esto + reglas)

### 1. Idle — `idle_{dir}.png`
```
Idle breathing animation, 4 frames, {DIRECTION}. Standing relaxed with arms at the sides, empty hands. The chest rises 1 pixel on frames 2-3 and returns. Loopable. Almost no movement.
```

### 2. Walk — `walk_{dir}.png`
```
Walk cycle animation, 6 frames, {DIRECTION}. Empty hands. Arms swing opposite to the legs, small 1-pixel body bob, classic contact-passing poses, smooth loop from frame 6 back to frame 1.
```

### 3. Hurt — `hurt_{dir}.png`
```
Hurt reaction animation, 3 frames, {DIRECTION}. Frame 1 normal stance, frame 2 body knocked back 2 pixels with arms flung slightly outward, frame 3 recovering to stance. Empty hands. No blood, no effects.
```

### 4. Guerrero — tajo con regla — `guerrero_attack_{dir}.png`
```
Melee sword attack animation, 6 frames, {DIRECTION}. The character holds a long wooden school ruler (light yellow wood with black tick marks) like a sword in the right hand and a pink rubber eraser like a small shield in the left hand. Frame 1 ready stance, frame 2 wind-up with the ruler pulled back to the side (never over the head), frame 3 fast horizontal slash toward the facing direction, frame 4 follow-through with the arm fully extended, frame 5 recover, frame 6 back to ready stance. No slash trail or effects.
```

### 5. Guerrero — guardia — `guerrero_guard_{dir}.png`
```
Block / guard animation, 3 frames, {DIRECTION}. Same wooden ruler in the right hand and pink eraser shield in the left hand. Frame 1 raising the eraser, frame 2 eraser held firmly in front of the chest with knees slightly bent (hold pose), frame 3 small recoil as if blocking a hit. The eraser stays below the face.
```

### 6. Mago — lanzar hechizo — `mago_cast_{dir}.png`
```
Spell casting animation, 5 frames, {DIRECTION}. The character holds a gnarled wooden branch staff with a small glowing blue crystal on the tip. Frame 1 idle holding the staff, frame 2 staff pulled back at chest height while the crystal glows brighter, frame 3 staff thrust forward pointing in the facing direction, frame 4 hold the pose, frame 5 return to idle. Do NOT draw the projectile.
```

### 7. Mago — golpe con bastón — `mago_melee_{dir}.png`
```
Staff melee attack animation, 5 frames, {DIRECTION}. Same wooden branch staff held with both hands. Frame 1 ready, frame 2 wind-up with the staff pulled back to the side at shoulder height, frame 3 fast forward swing, frame 4 staff tip striking forward in the facing direction, frame 5 recover. The staff never passes over the head.
```

### 8. Chain — latigazo corto — `chain_whip_short_{dir}.png`
```
Quick whip attack animation, 5 frames, {DIRECTION}. The character holds a coiled black phone charger cable used as a whip in the right hand. Frame 1 ready with the cable coiled, frame 2 short wind-up to the side, frame 3 fast crack with the cable reaching about one body-length forward in the facing direction, frame 4 cable snapping back, frame 5 ready. Tight and fast motion.
```

### 9. Chain — latigazo largo — `chain_whip_long_{dir}.png`
```
Heavy long whip attack animation, 7 frames, {DIRECTION}. Same black charger cable whip. Frame 1 ready, frames 2-3 big wind-up spinning the cable in a circle beside the body (not above the head), frame 4 wide forward lash, frame 5 cable fully extended about three body-lengths forward in a wide arc, frame 6 pulling the cable back, frame 7 ready. Slower and wider than a quick whip. Leave enough empty space in each frame for the long cable.
```

---

## 5. Efectos (sin personaje, BLOQUE A + esto)

### E1 — `fx_slash.png`
```
Slash arc effect only, no character, 4 frames: a white and light-blue crescent swoosh that appears, widens and fades out, oriented to the right. 2-3 colors.
```

### E2 — `fx_orb.png`
```
Magic projectile effect only, no character. Top row: 4-frame loop of a small glowing blue energy orb with a white core and tiny sparkles trailing to the left, flying to the right. Bottom row: 3-frame impact burst of the same blue energy.
```

### E3 — `fx_whip_crack.png`
```
Whip crack spark effect only, no character, 3 frames: a small white-yellow star burst that pops and fades.
```

### E4 — `fx_hit.png`
```
Generic hit impact effect only, no character, 3 frames: a white impact star with short speed lines that expands and fades.
```

---

## 6. Checklist al recibir cada hoja

- [ ] Personaje del mismo tamaño en todos los frames y pies alineados
- [ ] Misma ropa (camisa celeste, jeans, zapatillas blancas) y cabeza rapada
- [ ] La cabeza no rota ni queda tapada por brazos o armas
- [ ] Nada toca el borde ni se sale del frame
- [ ] Número de frames correcto
- [ ] Guardada en `_entregas_runway/` con su nombre (`walk_down.png`, `mago_cast_right.png`, …)

Con las hojas en `_entregas_runway/`, avísame y las integro al juego (recorte + máscaras + cuello por frame).
