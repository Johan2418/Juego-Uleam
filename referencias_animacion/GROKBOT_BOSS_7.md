# TAREA PARA GROKBOT — Boss 7: MISSING TEXTURE (10 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_BOSS_7.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/367bb970-b79f-4951-86b9-4bfb3813d0a3

## Qué se pide
El séptimo boss, de la Facultad de Artes, Humanidades y Patrimonio: una estatua de mármol gigante del museo, con pincel y paleta, sobre su pedestal. Se anima POR PIEZAS en el juego, igual que los bosses 1 a 6: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.
- A: el boss completo (1 hoja). **Hacerla primero y avisar**: esta define el diseño. Las de B y C usan esta como Imagen 1.
- B: piezas sueltas del boss (5 hojas).
- C: proyectiles, piezas del piso, esbirro y pedazos (4 hojas).

## Reglas clave
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.
- SIN TEXTO NI NÚMEROS en ningún lado (ni en la placa del pedestal ni en la etiqueta). Sin humanos pequeños. Sin sangre.
- SIN cuadriculado magenta/negro: todo el mármol normal (el efecto de textura faltante lo pone el código).
- En la hoja A, el boss 6 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.
- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.
- Los brazos (brush y palette) rectos hacia abajo, con el hombro arriba, mismo largo en todas las poses.
- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso


### A · Boss completo (hacer primero)
- [x] `boss_tex_full.png` — Primera y más importante: las demás hojas copian esta. Todo el mármol normal, SIN cuadriculado magenta (lo pone el código).

### B · Piezas sueltas del boss
- [x] `boss_tex_body.png`
- [x] `boss_tex_core.png`
- [x] `boss_tex_head.png` — Cara lisa: los ojos y el cuadriculado se dibujan por código.
- [x] `boss_tex_brush.png` — Rectos hacia abajo y del mismo largo: el código los gira desde el hombro.
- [x] `boss_tex_palette.png` — Igual: rectos hacia abajo y del mismo largo.

### C · Proyectiles, piezas del piso, esbirro y pedazos
- [x] `boss_tex_projectiles.png` — Máscaras, pintura, aguja, carrete, vasija, pedazo de vasija y hueso.
- [x] `boss_tex_props.png` — Sitios de excavación, trazos y charcos de pintura, marco, pedestal, poste e hilo.
- [x] `boss_tex_mannequin.png` — Esbirros maniquíes (Sociología): se congelan si los miras.
- [x] `boss_tex_debris.png` — Pedazos que salen volando al morir.

## Notas de grokbot
(resumen al terminar: herramienta usada en cada hoja y qué falló)

- boss_tex_full: ChatGPT, elegida entre 2 versiones; marmol normal sin cuadriculado, placa del pedestal sin texto.
- boss_tex_body, core, head, brush, palette, debris: ChatGPT al primer intento, coherentes con la hoja A; brazos rectos hacia abajo.
- boss_tex_projectiles, props, mannequin: ChatGPT al primer intento, sin texto ni numeros.
- Fondo menta en todas; Gemini no fue necesario.
