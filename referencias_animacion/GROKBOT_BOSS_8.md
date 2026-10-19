# TAREA PARA GROKBOT — Boss 8: KERNEL PANIC (10 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_BOSS_8.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/005ed015-f9c9-4542-9a6c-1ea32c304b9e

## Qué se pide
El octavo y último boss, de la Unidad de Formación Técnicas y Tecnológicas: un robot chef presentador de un programa de cocina en vivo, con cabeza de microondas, sartén y micrófono, sobre un carrito de cocina. Se anima POR PIEZAS en el juego, igual que los bosses 1 a 7: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.
- A: el boss completo (1 hoja). **Hacerla primero y avisar**: esta define el diseño. Las de B y C usan esta como Imagen 1.
- B: piezas sueltas del boss (5 hojas).
- C: proyectiles, utilería del estudio, esbirro y pedazos (4 hojas).

## Reglas clave
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.
- SIN TEXTO NI NÚMEROS en ningún lado (ni en la claqueta ni en el cartel de aplausos). Sin humanos pequeños. Sin sangre.
- La pantalla del microondas va LISA y oscura, sin cara: la cara la dibuja el código.
- En la hoja A, el boss 7 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.
- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.
- Los brazos (pan y mic) rectos hacia abajo, con el hombro arriba, mismo largo en todas las poses, y nada que sobresalga por encima del hombro.
- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso


### A · Boss completo (hacer primero)
- [x] `boss_kp_full.png` — Primera y más importante: las demás hojas copian esta. Pantalla de la cara en negro (la cara la dibuja el código).

### B · Piezas sueltas del boss
- [x] `boss_kp_body.png`
- [x] `boss_kp_core.png`
- [x] `boss_kp_head.png` — Pantalla lisa y oscura: la cara se dibuja por código.
- [x] `boss_kp_pan.png` — Rectos hacia abajo, mismo largo, y nada que sobresalga arriba del hombro: el código los gira desde el hombro.
- [x] `boss_kp_mic.png` — Igual: rectos hacia abajo y del mismo largo.

### C · Proyectiles, piezas del piso, esbirro y pedazos
- [x] `boss_kp_projectiles.png` — Comida en llamas, fuego, cuchillo, grano, palomita, flash, plato y gota de aceite.
- [x] `boss_kp_props.png` — Cámaras (en vivo, apagada, rota), alfombra roja, poste con cordón, cartel de aplausos, reflector y balde de palomitas.
- [x] `boss_kp_paparazzi.png` — Esbirros paparazzi de la alfombra roja (Comunicación/RRPP).
- [x] `boss_kp_debris.png` — Pedazos que salen volando al morir.

## Notas de grokbot
(resumen al terminar: herramienta usada en cada hoja y qué falló)

- boss_kp_full: ChatGPT, elegida entre 2 versiones; pantalla del microondas lisa y oscura sin cara, nada sobresale por encima de los hombros.
- boss_kp_body, core, head, pan, mic, debris: ChatGPT, coherentes con la hoja A; brazos rectos hacia abajo; claqueta sin texto. pan se rehizo en chat nuevo porque el primer intento no adjunto la hoja A.
- boss_kp_projectiles, props, paparazzi: ChatGPT al primer intento; cartel de aplausos en blanco, sin texto ni numeros.
- Fondo menta en todas; Gemini no fue necesario.
