# TAREA PARA GROKBOT — pulido 2: ciclos de 8 poses (19 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a esa carpeta).
Base: `referencias_animacion/GROKBOT_TAREA.md` (procedimiento y lista de control). Prompts: `referencias_animacion/PROMPTS_PULIDO_2.md`.

## Por qué esta tarea
Las hojas "intermedias" (`walk_b`, `*_b`) se generaron aparte: salieron con otra altura y otro orden de piernas, y al intercalarlas el personaje vibraba. Ahora cada ciclo va COMPLETO (8 poses) en UNA sola imagen, así las 8 poses salen del mismo dibujo.

## Herramientas: Gemini Plus o ChatGPT Plus
- Puedes usar cualquiera de las dos. Lo único que importa es que el personaje se vea IDÉNTICO a la Imagen 2 (mismo diseño, colores, tamaño de cabeza, alto y estilo pixel art). Si uno de los dos lo cambia, prueba con el otro.
- Recomendado: intenta primero con el que mejor copie la Imagen 2; si al 1.er intento el estilo sale suave/pintado (sin píxeles duros) o cambia la cara, el pelo o la ropa, cambia de herramienta para el 2.º intento.
- En los dos: conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Formato: HORIZONTAL 3:2 para las hojas de 8 poses (en ChatGPT pide 1536x1024; en Gemini elige 3:2 o 16:9). La hoja de la sección C es vertical 3:4.
- Fondo verde menta liso (#A0EFA5), NO transparente (el recortador usa ese color).
- ChatGPT a veces agranda la imagen con bordes o añade sombra en el suelo: regenera si pasa.

## Lista de control de cada hoja de 8 poses (debe cumplir TODO)
- Exactamente 8 poses en 4 columnas x 2 filas, separadas, sin tocarse ni tocar los bordes, sin números ni texto.
- El personaje es el MISMO de la Imagen 2: cara, gafas, pelo, piel, polo, carnet, jeans y zapatos iguales; mismo estilo pixel art.
- Las 8 poses tienen el MISMO tamaño y la cabeza a la misma altura (pon las 8 una al lado de la otra mentalmente: no debe haber una más alta).
- Caminata: las piernas avanzan en orden (izq. delante → juntas → der. delante → juntas) y el cuerpo NO gira entre poses.
- Combos: el arma se ve en las 8 poses, una sola arma, sin estelas.
- Vista correcta en las 8: `_up` / `_up_right` de espaldas SIN cara, gafas ni carnet.

## Guardado
Guarda en `referencias_animacion/_entregas_runway/<nombre exacto>.png` (o .jpg). Marca `[x]` al guardar cada una. Si falla 2 veces (contando las dos herramientas), marca `[!]` con nota y sigue. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso

### A · Caminata de 8 poses (una imagen por dirección)
- [x] `wadrid_walk8_down.png`
- [x] `wadrid_walk8_up.png`
- [x] `wadrid_walk8_right.png`
- [x] `wadrid_walk8_down_right.png`
- [x] `wadrid_walk8_up_right.png`
- [x] `marlonx_a_walk8_down.png`
- [x] `marlonx_a_walk8_up.png`
- [x] `marlonx_a_walk8_right.png`
- [x] `marlonx_a_walk8_down_right.png`
- [x] `marlonx_a_walk8_up_right.png`

### B · Combos J de 8 poses (los 8 que no encajaban)
- [x] `wadrid_guerrero_attack8_down.png`
- [x] `wadrid_guerrero_attack8_down_right.png`
- [x] `wadrid_mago_cast8_up_right.png`
- [x] `wadrid_chain_whip8_up.png`
- [x] `marlonx_a_guerrero_attack8_up.png`
- [x] `marlonx_a_guerrero_attack8_right.png`
- [x] `marlonx_a_mago_cast8_up.png`
- [x] `marlonx_a_chain_whip8_up_right.png`

### C · Pendiente del pulido anterior
- [x] `marlonx_a_mago_parry_up_right.png`

## Notas de grokbot
Resumen PULIDO_2 (2026-10-06/07) — 15 [x], 4 [!], 0 pendientes.

Herramienta por hoja:
- Caminatas (10/10 [x]): todas con ChatGPT Plus (modo Chat), 1er intento. En `wadrid_walk8_down` Gemini dio error 2 veces sin generar imagen, por eso se hizo con ChatGPT.
- `wadrid_guerrero_attack8_down` [x] ChatGPT, 1er intento.
- `wadrid_guerrero_attack8_down_right` [x] ChatGPT, 1er intento.
- `wadrid_mago_cast8_up_right` [x] ChatGPT, 1er intento.
- `marlonx_a_guerrero_attack8_right` [x] ChatGPT, 1er intento.
- `marlonx_a_mago_parry_up_right` [x] ChatGPT (2x2 vertical 1024x1536), 1er intento válido; antes hubo un error de la herramienta de imagen sin generar nada.
- `wadrid_chain_whip8_up` [!] ChatGPT x2: en las poses 5-7 el cable pasa a la mano izquierda.
- `marlonx_a_guerrero_attack8_up` [!] ChatGPT x2: el segundo golpe sale espejado (regla en la izquierda, goma en la derecha) en las poses 6-7.
- `marlonx_a_mago_cast8_up` [!] ChatGPT x2: el segundo cast lleva el bastón en la mano izquierda (poses 5-7).
- `marlonx_a_chain_whip8_up_right` [!] ChatGPT x2 (Gemini dio error y no generó): pose 5 con el cable en la mano izquierda.

Qué falló: las 4 [!] son combos de espaldas. El prompt pide el segundo golpe "in the opposite direction" / "to the other side" y ChatGPT lo interpreta como cambiar de mano; vista de espaldas, sin cara ni lentes, estaba bien en todas. Sugerencia: para el 2.º golpe añadir "still in the RIGHT hand (on the viewer's right side, since we see his back)". Los intentos rechazados están guardados en la computadora de Grok Bot por si se quiere aprovechar alguno.
Gemini: dio error en todos los intentos de esta tanda y no ofrece 3:2.

### Ronda 2 (2026-10-08): 4 combos de espalda con REFUERZO DE MANO

Las 4 se hicieron con el prompt original más la HAND RULE al final, en un chat nuevo por hoja, con Imagen 1 y luego Imagen 2 y fondo menta #A0EFA5.

- `wadrid_chain_whip8_up.png`: [x] **Gemini** (16:9, 2752x1536, convertida a PNG). ChatGPT volvió a pasar el cable a la mano izquierda en las poses 5-7. Gemini lo mantuvo en la mano derecha en las 8.
- `marlonx_a_guerrero_attack8_up.png`: [x] **Gemini** (16:9, 1376x768, convertida a PNG). ChatGPT espejó al personaje en las poses 5-7: la regla pasaba a la mano izquierda y el borrador cambiaba de brazo. Gemini acertó, aunque salió más pequeña y algo más suave.
- `marlonx_a_mago_cast8_up.png`: [x] **ChatGPT** (1536x1024), al primer intento. El bastón queda en la mano derecha en las 8 poses.
- `marlonx_a_chain_whip8_up_right.png`: [x] **ChatGPT** (1536x1024), al primer intento. El cable queda en la mano derecha en las 8 poses. Se ve el cordón azul del lanyard en el cuello, que es parte del diseño (sin carnet visible). También probé Gemini, pero lo descarté: el cable salía con doble cola y el látigo quedaba rígido.

Conclusión: con la HAND RULE, ChatGPT acierta los ataques "al frente" (cast y látigo en diagonal), pero sigue espejando el segundo golpe de revés en la vista de espalda pura. En esos casos Gemini respeta mejor la mano derecha.
Ronda 2: 4 [x], 0 [!]. **Total PULIDO_2: 19 [x], 0 [!], 0 pendientes.**

## Revisión de Claude (2026-10-08)
- 15 hojas revisadas y ACEPTADAS, ya en el juego: las 10 caminatas `walk8` (8 frames, mismo diseño, la cabeza se mueve como mucho 1-4 px),
  `wadrid_guerrero_attack8_down`, `wadrid_guerrero_attack8_down_right`, `wadrid_mago_cast8_up_right`, `marlonx_a_guerrero_attack8_right`
  y `marlonx_a_mago_parry_up_right`.
- Quedan 4 combos de espaldas (vuelven a `[ ]`). Para ellos, AÑADE al final del prompt este REFUERZO DE MANO:
  `HAND RULE: the weapon stays in the character's RIGHT hand in ALL 8 poses. Because we see his back, his right hand is on the RIGHT side of the image. The second hit is a backhand swing with the SAME right hand (the arm crosses the body); never switch the weapon to the left hand and never mirror the character.`
  Si ChatGPT vuelve a cambiar de mano, prueba Gemini (relación 16:9 si no ofrece 3:2).

## Revisión final de Claude (2026-10-09)
- Las 4 combos de espaldas de la ronda 2 revisadas y ACEPTADAS (arma en la mano derecha en las 8 poses, de espaldas sin cara ni carnet). Escala: wadrid_chain_whip8_up x0.92, marlonx_a_guerrero_attack8_up x1.1, marlonx_a_chain_whip8_up_right x1.04, marlonx_a_mago_cast8_up x1.0.
- PULIDO_2 COMPLETO: 19/19 en el juego. Caminata de 8 frames en las 5 direcciones y combo J con 4 frames por golpe en todas las direcciones, ambos personajes.
