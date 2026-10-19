# TAREA PARA GROKBOT — pulido 4 (23 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a esa carpeta).
Procedimiento igual que `GROKBOT_PULIDO_3.md`. Prompts: `referencias_animacion/PROMPTS_PULIDO_4.md`.

## Qué se pide
- A: rehacer las 2 rechazadas del pulido 3 (faltaba el borrador) y reintentar la `[!]` (sin líneas de movimiento).
- B: combos J de 8 poses en UNA imagen para las direcciones que faltan. Las hojas intermedias viejas de mago y chain hacían que el personaje "saltara" y cambiara de tamaño; con 8 poses del mismo dibujo el golpe queda fluido y estable.
- C: rodar arriba-derecha bien orientado (que se lance hacia la DERECHA). Formato 2x2 vertical 3:4.

## Reglas clave (además de la lista de control del pulido 3)
- MISMAS PROPORCIONES que la Imagen 2: la cabeza NO debe salir más grande ni el cuerpo más corto (ChatGPT tiende a hacerlo más cabezón; si pasa, usa Gemini).
- Mago y chain: de pie todo el combo, sin saltar ni agacharse.
- Vistas de espaldas: sin cara/gafas/carnet y el arma en la mano derecha (lado derecho de la imagen). Si ChatGPT cambia de mano, Gemini.
- Fondo menta liso #A0EFA5, sin sombra. Horizontal 3:2 para A y B; vertical 3:4 para C.
- Conversación nueva por hoja, Imagen 1 y luego Imagen 2, prompt completo sin cambios. No uses nada de `_rechazadas/`.

## Guardado
`referencias_animacion/_entregas_runway/<nombre exacto>.png` (o .jpg). Marca `[x]` al guardar; `[!]` con nota si falla 2 veces. No toques código, `assets/`, `scenes/` ni `scripts/`. (Para Claude: al integrar C, quitar `roll_up_right` de MIRROR_SHEETS.)

### D · Caminata hacia arriba (pies virados) — añadido 16-10
- [x] `wadrid_walk8_up.png` — los pies salen girados hacia los lados; deben apuntar hacia arriba/lejos (ver FEET RULE). Sobrescribe la actual (la vieja está copiada en `_rechazadas/` como `_r1`).
- [x] `marlonx_a_walk8_up.png` — RECHAZADA r2 (Claude 16-10): el pie levantado sale MÁS ABAJO y más grande que el pie apoyado (bola negra) → parece que camina hacia la cámara. Repetir con la Imagen 3 (`wadrid_walk8_up.png`, que está bien) como referencia del movimiento de pies y la LIFTED FOOT RULE.

## Progreso

### A · Pendientes del pulido 3 (2 rechazadas + 1 [!])
- [x] `marlonx_a_guerrero_counter8_down_right.png`
- [x] `wadrid_guerrero_ultimate8_up_right.png`
- [x] `wadrid_chain_counter8_up.png`

### B · Combos J de 8 poses que faltan (mago y chain sin saltito; guerrero de espaldas de Wadrid)
- [x] `wadrid_guerrero_attack8_up.png`
- [x] `wadrid_guerrero_attack8_up_right.png`
- [x] `wadrid_mago_cast8_down.png`
- [x] `wadrid_mago_cast8_up.png`
- [x] `wadrid_mago_cast8_right.png`
- [x] `wadrid_mago_cast8_down_right.png`
- [x] `wadrid_chain_whip8_down.png`
- [x] `wadrid_chain_whip8_right.png`
- [x] `wadrid_chain_whip8_down_right.png`
- [x] `wadrid_chain_whip8_up_right.png` — RECHAZADA r1 (Claude 16-10): pelo no es el afro rizado grande, dibujo borroso/no pixel art y estela de movimiento en el cable. Repetir con Gemini/ChatGPT, sin estelas.
- [x] `marlonx_a_mago_cast8_down.png`
- [x] `marlonx_a_mago_cast8_right.png`
- [x] `marlonx_a_mago_cast8_down_right.png` — RECHAZADA r1 (Claude 16-10): las gafas salen como un antifaz negro (no se ven los ojos) y el bastón cambia de mano. Repetir: gafas rectangulares finas con ojos visibles, bastón siempre en la mano derecha.
- [x] `marlonx_a_mago_cast8_up_right.png`
- [x] `marlonx_a_chain_whip8_down.png`
- [x] `marlonx_a_chain_whip8_up.png`
- [x] `marlonx_a_chain_whip8_right.png`
- [x] `marlonx_a_chain_whip8_down_right.png` — RECHAZADA r1 (Claude 16-10): el cable sale demasiado fino y desaparece al reducir la hoja al tamaño del juego. Repetir con el cable GRUESO y bien negro (como en `marlonx_a_chain_whip8_down`).

### C · Rodar arriba-derecha (las actuales se lanzan hacia la izquierda)
- [x] `wadrid_roll_up_right.png`
- [x] `marlonx_a_roll_up_right.png`

## Notas de grokbot
(resumen al terminar: herramienta usada en cada hoja y qué falló)

## Notas de grokbot (Pulido 4, 2026-10-14)
- 23/23 hojas [x], 0 [!]. Cada una en chat nuevo, Imagen 1 y luego Imagen 2, prompt sin cambios; ninguna referencia de `_rechazadas`.
- ChatGPT (modo Chat, 1536x1024 en A y B, 1024x1536 en C): 21 hojas, todas aprobadas al primer intento.
- Gemini (16:9, 1376x768, convertidas a PNG): `wadrid_chain_whip8_up_right` y `marlonx_a_chain_whip8_up`. En ambas, la versión de ChatGPT pasaba el cable a la mano izquierda en una pose de espaldas; en Gemini el cable va en la mano derecha en las 8 poses.
- Revisé las proporciones contra la Imagen 2: ninguna hoja aprobada sale más cabezona ni más bajita.
- `wadrid_chain_whip8_down` y `marlonx_a_chain_whip8_down` (vistas de frente) llevan el cable en el mismo lado de la imagen que su Imagen 2, así que no las rehíce.
- Sección C: rolls en cuadrícula 2x2 vertical, igual que las hojas de roll originales.

## Notas de grokbot (reintentos 2026-10-16)
- [x] wadrid_chain_whip8_up_right: Gemini. Afro grande y rizado, pixel art nítido, cable en la mano derecha y sin estela. Detalle menor: en la pose 7 se ve un pequeño fragmento suelto del cable cerca de la punta, que se puede borrar al recortar. El segundo intento en Gemini salió con el afro liso, así que me quedé con el primero.
- [x] marlonx_a_chain_whip8_down_right: ChatGPT. El cable sale grueso y negro en las 8 poses.
- [x] wadrid_walk8_up y marlonx_a_walk8_up: ChatGPT, con la FEET RULE. Los zapatos apuntan hacia arriba, paralelos, y al levantar el pie se ve la suela. Sobrescriben las anteriores.
- [!] marlonx_a_mago_cast8_down_right: falló 2 veces. En ChatGPT las gafas salieron como antifaz oscuro y el bastón pasó a la otra mano en la pose 5. En Gemini volvió el antifaz y además añadió estelas blancas de movimiento. Ninguna versión cumple la GLASSES RULE.
- [x] marlonx_a_mago_cast8_down_right (3.er intento, a pedido de Alyson): ChatGPT con el prompt original más una regla extra al final (lentes claros del color de la piel con ojos y pupilas visibles, sin estelas, bastón siempre en el lado derecho de la imagen). Ya se ven los ojos a través de las gafas y el bastón no cambia de mano en las 8 poses.
- [x] marlonx_a_walk8_up (retry 2, 2026-10-16): ChatGPT con el prompt de la sección D (con la LIFTED FOOT RULE) y tres imágenes, Imagen 1, Imagen 2 y wadrid_walk8_up como Imagen 3. Salió bien al primer intento: el pie levantado queda más arriba y más chico que el apoyado y enseña el talón, sin bolas negras.
