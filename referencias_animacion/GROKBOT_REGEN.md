# TAREA PARA GROKBOT — regenerar hojas que salieron con OTRO dibujo (Prototipo Campus)

Mismo procedimiento, carpetas y lista de control que `GROKBOT_TAREA.md` (léelo primero).
Estas hojas se generaron, pero el personaje salió distinto al resto (otra proporción, otro color de pelo,
más delgado/alto o con el carnet visible de espaldas). Hay que volver a generarlas.

## Cómo hacerlo
1. Para cada hoja de la lista, busca su bloque en `PROMPTS_GEMINI.md` (OPCIÓN A) por el nombre de **Archivo**.
2. Adjunta Imagen 1 e Imagen 2 **del bloque** (mismo orden), en una conversación NUEVA de Gemini.
3. Pega el prompt del bloque **y añade al final** el texto de "Refuerzo" de abajo (el de su vista).
4. Revisa con la lista de control + estos puntos extra:
   - La cabeza tiene el **mismo tamaño relativo** que en la Imagen 2 (chibi: cabeza grande, ~40 % de la altura).
   - Mismo color de pelo y piel que la Imagen 1 (Wadrid: afro castaño MUY oscuro; MarlonX-a: pelo negro).
   - Mismo grosor de cuerpo que la Imagen 2 (no más delgado ni más alto).
5. Guarda con el **mismo nombre** en `_entregas_runway/`, **sobrescribiendo** la versión anterior
   (si la anterior es `.jpg` y guardas `.png`, deja las dos: se usa la `.png`).
6. Marca `[x]` aquí. Si falla 2 veces, `[!]` con nota.

## Refuerzo (añadir al final del prompt)
- Vista `_down` o `_right`:
  `IMPORTANT: keep EXACTLY the same character design, head size, body width, hair color and skin color as the second attached image; only the pose changes. Big chibi head (about 40% of the total height), short stocky body.`
- Vista `_up` (de espaldas):
  `IMPORTANT: keep EXACTLY the same character design, head size, body width, hair color and skin color as the second attached image; only the pose changes. Big chibi head (about 40% of the total height), short stocky body. Seen strictly from BEHIND: the back of the head and the back of the polo only; the ID card is NOT visible (it hangs on the chest), no face, no glasses visible.`

## Lista (8 obligatorias)
- [x] `wadrid_mago_parry_down.png`
- [x] `wadrid_mago_parry_up.png`
- [x] `wadrid_mago_special_up.png`
- [x] `marlonx_a_mago_parry_right.png`
- [!] `marlonx_a_mago_parry_down.png` - 2 intentos: el personaje ya coincide, pero la pose 3 repite el lanzamiento de ataque en vez del parry. Se guardó el mejor intento.
- [!] `marlonx_a_mago_parry_up.png` - 2 intentos: el personaje ya coincide y no se ve el carnet, pero en la pose 2 el cristal queda tapado y las piernas salen raras. Se guardó el mejor intento.
- [x] `marlonx_a_mago_special_up.png`
- [!] `marlonx_a_mago_ultimate_up.png` - 2 intentos: el personaje ya coincide, pero en la pose 3 el bastón sale al revés (cristal abajo) y en la pose 2 los pies salen raros. Se guardó el mejor intento.

## Opcionales (el carnet se ve por la espalda en algunas poses; solo si sobra cuota)
- [x] `wadrid_chain_special_up.png`
- [x] `wadrid_chain_parry_up.png`
- [x] `wadrid_chain_ultimate_up.png`
- [x] `marlonx_a_chain_special_up.png`
- [x] `marlonx_a_chain_parry_up.png`
- [x] `marlonx_a_chain_ultimate_up.png`

## Notas de grokbot
Resumen (27 sep 2026). Se regeneraron las 14 hojas (8 obligatorias + 6 opcionales) en Gemini, cada una en chat nuevo, con la Imagen 1 y la Imagen 2 de su bloque de `PROMPTS_GEMINI.md` (OPCIÓN A), relación 3:4 y el prompt del bloque con el Refuerzo de su vista al final. Se guardaron en `_entregas_runway/` como `.jpg` con el mismo nombre, sobrescribiendo la versión anterior (las anteriores quedan respaldadas en la computadora de grokbot).
- **Obligatorias:** 5 `[x]` y 3 `[!]`. En las 8 el personaje ya coincide con la Imagen 2 (tamaño de cabeza, grosor, pelo y piel) y de espaldas no se ve el carnet. Las 3 `[!]` fallaron dos veces por la pose o el bastón, no por el personaje, y se dejó guardado el mejor intento.
- **Opcionales:** las 6 `[x]` al primer intento, sin carnet visible por la espalda.
- Detalle aceptado: en `wadrid_mago_special_up` (2.º intento) la punta del bastón queda cortada en el borde en la pose 2.
- En las hojas de cable vistas de espaldas, el enchufe que aparece arriba de la cabeza es la punta del cable yendo hacia el fondo, como pide el prompt ("cable in front"), y el disco del parry es el cable girando.

## Verificación Claude (2026-09-28)
- 14 hojas revisadas: el personaje ya coincide en todas. Recortadas, medida su escala (0.9–1.12) y añadidas a tools/scale_fix.json. Ya están en el juego.
- marlonx_a_mago_parry_down: la pose 3 (ataque) se reemplaza por la guardia (POSE_ORDER [0,1,1,3]).
- marlonx_a_mago_parry_up y marlonx_a_mago_ultimate_up: los detalles marcados [!] no se notan a tamaño de juego; aceptadas.
- Slicer: los pies se anclan en la última fila "gruesa" (la punta del cable ya no levanta al personaje).
