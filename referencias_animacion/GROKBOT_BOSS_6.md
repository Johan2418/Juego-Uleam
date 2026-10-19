# TAREA PARA GROKBOT — Boss 6: 403 FORBIDDEN (10 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_BOSS_6.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/b13b51de-e149-4c34-adfd-b43a3cf5561e

## Qué se pide
El sexto boss, de la Facultad de Ciencias Sociales, Derecho y Bienestar: un juez robot con toga, peluca y monitor de cabeza, flotando en su estrado. Se anima POR PIEZAS en el juego, igual que los bosses 1 a 5: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.
- A: el boss completo (1 hoja). **Hacerla primero y avisar**: esta define el diseño. Las de B y C usan esta como Imagen 1.
- B: piezas sueltas del boss (5 hojas).
- C: pruebas, proyectiles, esbirro y pedazos (4 hojas).

## Reglas clave
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.
- SIN TEXTO NI NÚMEROS en ningún lado (ni en la pantalla, ni en los libros, ni en los documentos, ni en el sello, ni en la cinta). Sin humanos pequeños. Sin sangre.
- En la hoja A, el boss 4 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.
- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.
- Los brazos (gavel y hand) rectos hacia abajo, con el hombro arriba, mismo largo en todas las poses.
- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso


### A · Boss completo (hacer primero)
- [x] `boss_judge_full.png` — Primera y más importante: las demás hojas copian esta. La pantalla del monitor debe salir lisa y oscura (sin cara ni texto).

### B · Piezas sueltas del boss
- [x] `boss_judge_body.png`
- [x] `boss_judge_core.png`
- [x] `boss_judge_head.png` — Pantalla lisa: la cara, el 403 y los textos se dibujan por código.
- [x] `boss_judge_gavel.png` — Rectos hacia abajo y del mismo largo: el código los gira desde el hombro.
- [x] `boss_judge_hand.png` — Igual: rectos hacia abajo y del mismo largo.

### C · Pruebas, proyectiles, esbirro y pedazos
- [x] `boss_judge_evidence.png` — Pruebas que recoge el jugador y el sello DENEGADO (el texto lo pone el código).
- [x] `boss_judge_projectiles.png` — Libro de leyes, misil, bandera blanca, foco, cinta, escáner, onda del mazo y papeles.
- [x] `boss_judge_folder.png` — Esbirros casos (Trabajo Social); al romperlos sueltan una prueba.
- [x] `boss_judge_debris.png` — Pedazos que salen volando al morir.

## Notas de grokbot
(resumen al terminar: herramienta usada en cada hoja y qué falló)

## Notas de grokbot
- boss_judge_full: ChatGPT, elegida entre 2 versiones; monitor liso y oscuro, sin cara ni texto.
- boss_judge_body, core, head, gavel, hand, debris: ChatGPT al primer intento, partes coherentes con la hoja A.
- boss_judge_evidence, projectiles, folder: ChatGPT al primer intento, sin texto ni numeros.
- Fondo menta en todas; Gemini no fue necesario.
