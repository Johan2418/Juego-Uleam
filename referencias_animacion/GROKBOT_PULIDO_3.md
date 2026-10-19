# TAREA PARA GROKBOT — pulido 3: animaciones nuevas de 8 poses (134 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a esa carpeta).
Base: `referencias_animacion/GROKBOT_TAREA.md` (procedimiento) y `GROKBOT_PULIDO_2.md` (lo aprendido con Gemini/ChatGPT). Prompts: `referencias_animacion/PROMPTS_PULIDO_3.md`.

## Qué se pide
Mismo formato que el pulido 2 (8 poses en 4 columnas x 2 filas, UNA imagen por hoja), para animaciones nuevas o más fluidas:
- A: derribo completo (golpe → cae → en el suelo → se levanta) y un reposo largo (saca el celular y lo mira).
- B: contraataque automático tras un parry exitoso (bloquea → abre la guardia → golpe fuerte).
- C: ultimates con carga real (4 poses de carga + 4 del golpe o del giro).
- D y E: especial (K) y parry (L) con 8 poses en vez de 4.
Orden de trabajo: A → B → C → D → E (lo más importante primero). El juego ya está preparado: cada hoja que falte usa la animación actual.

## Herramientas: Gemini Plus o ChatGPT Plus
- Lo único que importa: el personaje IDÉNTICO a la Imagen 2 (diseño, colores, tamaño de cabeza, alto, pixel art duro).
- Lección del pulido 2: ChatGPT copia muy bien el diseño, pero en vistas de espaldas (`_up`, `_up_right`) a veces pasa el arma a la mano izquierda. Si pasa, usa Gemini (relación 16:9 si no ofrece 3:2). Los prompts de espaldas ya incluyen la CRITICAL VIEW RULE y la HAND RULE.
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Formato HORIZONTAL 3:2 (ChatGPT: 1536x1024; Gemini: 3:2 o 16:9). Fondo verde menta liso #A0EFA5, NO transparente, sin sombra en el suelo.

## Lista de control de cada hoja (debe cumplir TODO)
- Exactamente 8 poses en 4 columnas x 2 filas, separadas, sin tocarse ni tocar los bordes, sin números ni texto.
- El personaje es el MISMO de la Imagen 2: cara, gafas, pelo, piel, polo, carnet, jeans y zapatos; mismo estilo pixel art.
- Las 8 poses con la MISMA cabeza (mismo tamaño). La pose 8 SIEMPRE de pie y tan alta como la Imagen 2 (se usa para medir la escala).
- El orden de las poses es el del prompt (p. ej. en el derribo: cae en las poses 2-3, en el suelo 4-5, se levanta 6-8).
- Arma correcta: una sola, en la mano derecha, visible en las 8 poses (salvo A, que va sin arma). Sin estelas, rayos ni efectos.
- Vista correcta en las 8: `_up` / `_up_right` de espaldas SIN cara, gafas ni carnet.
- Chain: el cable no debe invadir la celda de la pose vecina.

## Guardado
Guarda en `referencias_animacion/_entregas_runway/<nombre exacto>.png` (o .jpg). Marca `[x]` al guardar cada una. Si falla 2 veces (contando las dos herramientas), marca `[!]` con nota y sigue. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso

### A · Derribo (caer y levantarse) + reposo largo (mira el celular)
- [x] `wadrid_knockdown8_down.png`
- [x] `wadrid_knockdown8_up.png`
- [x] `wadrid_knockdown8_right.png`
- [x] `wadrid_knockdown8_down_right.png`
- [x] `wadrid_knockdown8_up_right.png`
- [x] `marlonx_a_knockdown8_down.png`
- [x] `marlonx_a_knockdown8_up.png`
- [x] `marlonx_a_knockdown8_right.png`
- [x] `marlonx_a_knockdown8_down_right.png`
- [x] `marlonx_a_knockdown8_up_right.png`
- [x] `wadrid_idle_long_down.png`
- [x] `wadrid_idle_long_right.png`
- [x] `marlonx_a_idle_long_down.png`
- [x] `marlonx_a_idle_long_right.png`

### B · Contraataque tras un parry exitoso
- [x] `wadrid_guerrero_counter8_down.png`
- [x] `wadrid_guerrero_counter8_up.png`
- [x] `wadrid_guerrero_counter8_right.png`
- [x] `wadrid_guerrero_counter8_down_right.png`
- [x] `wadrid_guerrero_counter8_up_right.png`
- [x] `wadrid_mago_counter8_down.png`
- [x] `wadrid_mago_counter8_up.png`
- [x] `wadrid_mago_counter8_right.png`
- [x] `wadrid_mago_counter8_down_right.png`
- [x] `wadrid_mago_counter8_up_right.png`
- [x] `wadrid_chain_counter8_down.png`
- [x] `wadrid_chain_counter8_up.png`
- [x] `wadrid_chain_counter8_right.png`
- [x] `wadrid_chain_counter8_down_right.png`
- [x] `wadrid_chain_counter8_up_right.png`
- [x] `marlonx_a_guerrero_counter8_down.png`
- [x] `marlonx_a_guerrero_counter8_up.png`
- [x] `marlonx_a_guerrero_counter8_right.png`
- [x] `marlonx_a_guerrero_counter8_down_right.png` — RECHAZADA (revisión Claude 2026-10-13): el borrador desaparece en las poses 5-8
- [x] `marlonx_a_guerrero_counter8_up_right.png`
- [x] `marlonx_a_mago_counter8_down.png`
- [x] `marlonx_a_mago_counter8_up.png`
- [x] `marlonx_a_mago_counter8_right.png`
- [x] `marlonx_a_mago_counter8_down_right.png`
- [x] `marlonx_a_mago_counter8_up_right.png`
- [x] `marlonx_a_chain_counter8_down.png`
- [x] `marlonx_a_chain_counter8_up.png`
- [x] `marlonx_a_chain_counter8_right.png`
- [x] `marlonx_a_chain_counter8_down_right.png`
- [x] `marlonx_a_chain_counter8_up_right.png`

### C · Ultimates de 8 poses (carga + golpe)
- [x] `wadrid_guerrero_ultimate8_down.png`
- [x] `wadrid_guerrero_ultimate8_up.png`
- [x] `wadrid_guerrero_ultimate8_right.png`
- [x] `wadrid_guerrero_ultimate8_down_right.png`
- [x] `wadrid_guerrero_ultimate8_up_right.png` — RECHAZADA (revisión Claude 2026-10-13): falta el borrador en casi todas las poses
- [x] `wadrid_mago_ultimate8_down.png`
- [x] `wadrid_mago_ultimate8_up.png`
- [x] `wadrid_mago_ultimate8_right.png`
- [x] `wadrid_mago_ultimate8_down_right.png`
- [x] `wadrid_mago_ultimate8_up_right.png`
- [x] `wadrid_chain_ultimate8_down.png`
- [x] `wadrid_chain_ultimate8_up.png`
- [x] `wadrid_chain_ultimate8_right.png`
- [x] `wadrid_chain_ultimate8_down_right.png`
- [x] `wadrid_chain_ultimate8_up_right.png`
- [x] `marlonx_a_guerrero_ultimate8_down.png`
- [x] `marlonx_a_guerrero_ultimate8_up.png`
- [x] `marlonx_a_guerrero_ultimate8_right.png`
- [x] `marlonx_a_guerrero_ultimate8_down_right.png`
- [x] `marlonx_a_guerrero_ultimate8_up_right.png`
- [x] `marlonx_a_mago_ultimate8_down.png`
- [x] `marlonx_a_mago_ultimate8_up.png`
- [x] `marlonx_a_mago_ultimate8_right.png`
- [x] `marlonx_a_mago_ultimate8_down_right.png`
- [x] `marlonx_a_mago_ultimate8_up_right.png`
- [x] `marlonx_a_chain_ultimate8_down.png`
- [x] `marlonx_a_chain_ultimate8_up.png`
- [x] `marlonx_a_chain_ultimate8_right.png`
- [x] `marlonx_a_chain_ultimate8_down_right.png`
- [x] `marlonx_a_chain_ultimate8_up_right.png`

### D · Especiales (K) de 8 poses
- [x] `wadrid_guerrero_special8_down.png`
- [x] `wadrid_guerrero_special8_up.png`
- [x] `wadrid_guerrero_special8_right.png`
- [x] `wadrid_guerrero_special8_down_right.png`
- [x] `wadrid_guerrero_special8_up_right.png`
- [x] `wadrid_mago_special8_down.png`
- [x] `wadrid_mago_special8_up.png`
- [x] `wadrid_mago_special8_right.png`
- [x] `wadrid_mago_special8_down_right.png`
- [x] `wadrid_mago_special8_up_right.png`
- [x] `wadrid_chain_special8_down.png`
- [x] `wadrid_chain_special8_up.png`
- [x] `wadrid_chain_special8_right.png`
- [x] `wadrid_chain_special8_down_right.png`
- [x] `wadrid_chain_special8_up_right.png`
- [x] `marlonx_a_guerrero_special8_down.png`
- [x] `marlonx_a_guerrero_special8_up.png`
- [x] `marlonx_a_guerrero_special8_right.png`
- [x] `marlonx_a_guerrero_special8_down_right.png`
- [x] `marlonx_a_guerrero_special8_up_right.png`
- [x] `marlonx_a_mago_special8_down.png`
- [x] `marlonx_a_mago_special8_up.png`
- [x] `marlonx_a_mago_special8_right.png`
- [x] `marlonx_a_mago_special8_down_right.png`
- [x] `marlonx_a_mago_special8_up_right.png`
- [x] `marlonx_a_chain_special8_down.png`
- [x] `marlonx_a_chain_special8_up.png`
- [x] `marlonx_a_chain_special8_right.png`
- [x] `marlonx_a_chain_special8_down_right.png`
- [x] `marlonx_a_chain_special8_up_right.png`

### E · Parry (L) de 8 poses
- [x] `wadrid_guerrero_parry8_down.png`
- [x] `wadrid_guerrero_parry8_up.png`
- [x] `wadrid_guerrero_parry8_right.png`
- [x] `wadrid_guerrero_parry8_down_right.png`
- [x] `wadrid_guerrero_parry8_up_right.png`
- [x] `wadrid_mago_parry8_down.png`
- [x] `wadrid_mago_parry8_up.png`
- [x] `wadrid_mago_parry8_right.png`
- [x] `wadrid_mago_parry8_down_right.png`
- [x] `wadrid_mago_parry8_up_right.png`
- [x] `wadrid_chain_parry8_down.png`
- [x] `wadrid_chain_parry8_up.png`
- [x] `wadrid_chain_parry8_right.png`
- [x] `wadrid_chain_parry8_down_right.png`
- [x] `wadrid_chain_parry8_up_right.png`
- [x] `marlonx_a_guerrero_parry8_down.png`
- [x] `marlonx_a_guerrero_parry8_up.png`
- [x] `marlonx_a_guerrero_parry8_right.png`
- [x] `marlonx_a_guerrero_parry8_down_right.png`
- [x] `marlonx_a_guerrero_parry8_up_right.png`
- [x] `marlonx_a_mago_parry8_down.png`
- [x] `marlonx_a_mago_parry8_up.png`
- [x] `marlonx_a_mago_parry8_right.png`
- [x] `marlonx_a_mago_parry8_down_right.png`
- [x] `marlonx_a_mago_parry8_up_right.png`
- [x] `marlonx_a_chain_parry8_down.png`
- [x] `marlonx_a_chain_parry8_up.png`
- [x] `marlonx_a_chain_parry8_right.png`
- [x] `marlonx_a_chain_parry8_down_right.png`
- [x] `marlonx_a_chain_parry8_up_right.png`

## Notas de grokbot
(resumen al terminar: qué herramienta usaste en cada hoja y qué falló)

## Notas de grokbot (Pulido 3, 2026-10-09 a 2026-10-12)

- Herramienta principal: ChatGPT Plus (modo Chat, 1536x1024). Gemini (16:9, convertido a PNG) se usó cuando ChatGPT se quedó sin adjuntos o cambió el arma de mano.
- Hechas con Gemini: `marlonx_a_guerrero_counter8_down`, `marlonx_a_guerrero_counter8_down_right` (ChatGPT espejaba al personaje), `marlonx_a_chain_counter8_right`, `marlonx_a_chain_counter8_down_right`, `wadrid_guerrero_ultimate8_up`, `wadrid_guerrero_ultimate8_up_right`, `wadrid_mago_ultimate8_down`, `wadrid_mago_ultimate8_right`, `wadrid_chain_ultimate8_up`.
- Reintentos que aprobaron en ChatGPT: varias ultimates de Gemini perdían el borrador/regla o duplicaban el bastón, y las cadenas de MarlonX-a de espalda perdían el cable.
- [x] `wadrid_chain_counter8_up.png`: ChatGPT y Gemini añadieron líneas de movimiento/ondas en los golpes; ninguna versión limpia.
- Revisar a ojo: `wadrid_guerrero_special8_up_right`, `wadrid_mago_special8_down` y `wadrid_mago_special8_up_right`, donde la mano del arma es dudosa en 1-2 poses.
- Total: 133 [x], 1 [!], 0 pendientes.

## Revisión de Claude (2026-10-13)
- 133 hojas recortadas (8 frames cada una), color igualado a la caminata, escala por la pose 8 (cabeza a ±2 px de la caminata en todas). 131 aceptadas e implementadas en el juego.
- Rechazadas y movidas a `_rechazadas/` (sufijo `_r1`), reabiertas arriba como `[ ]`:
  - `marlonx_a_guerrero_counter8_down_right`: el borrador desaparece en las poses 5-8.
  - `wadrid_guerrero_ultimate8_up_right`: falta el borrador en casi todas las poses.
- Pendiente del pulido: `wadrid_chain_counter8_up` ([!]): si se reintenta, añadir al final del prompt: `ABSOLUTELY NO motion lines, NO speed lines, NO wave marks, NO impact effects: only the character and the cable.`
- Para las 2 rechazadas, añadir al final del prompt: `ERASER RULE: the big pink rubber eraser stays strapped to the LEFT forearm and is clearly visible in ALL 8 poses (in back views it is on the LEFT side of the image).` Probar primero con ChatGPT; si cambia de mano, Gemini.
- Aceptadas con detalles menores (no hace falta rehacer): `wadrid_mago_special8_up_right` (bastón en la mano izquierda en las poses 2-3), `marlonx_a_chain_counter8_down_right` (cable tenue).

## Notas de grokbot (reintentos 2026-10-13)
- marlonx_a_guerrero_counter8_down_right, wadrid_guerrero_ultimate8_up_right y wadrid_chain_counter8_up se rehicieron en ChatGPT (chat nuevo, Imagen 1 + Imagen 2, sin referencias de _rechazadas), con la ERASER RULE en las dos primeras y la regla anti líneas de movimiento en la tercera. Las tres salieron a la primera y quedan [x]: el borrador está visible en el antebrazo izquierdo en las 8 poses y la hoja de cable no tiene líneas ni efectos.
