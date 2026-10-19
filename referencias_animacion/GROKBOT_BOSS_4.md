# TAREA PARA GROKBOT — Boss 4: SYNTAX ERROR (10 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_BOSS_4.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/000be033-2dfe-4815-8127-624a20758492

## Qué se pide
El cuarto boss, de la Facultad de Educación, Turismo y Humanidades: un robot profesor con pizarra en el pecho. Se anima POR PIEZAS en el juego, igual que los bosses 1, 2 y 3: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.
- A: el boss completo (1 hoja). **Hacerla primero y avisar**: esta define el diseño. Las de B y C usan esta como Imagen 1.
- B: piezas sueltas del boss (5 hojas).
- C: proyectiles, pupitres, esbirro y pedazos (4 hojas).

## Reglas clave
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.
- SIN TEXTO NI NÚMEROS en ningún lado (ni en la pizarra, ni en los pupitres, ni en los bloques, ni en los globos de diálogo). Sin humanos pequeños. Sin sangre.
- En la hoja A, el boss 3 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.
- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.
- Los brazos (pointer y hand) rectos hacia abajo, con el hombro arriba, mismo largo en las 3 poses.
- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso


### A · Boss completo (hacer primero)
- [x] `boss_syntax_full.png` — Primera y más importante: las demás hojas copian esta. La pizarra debe salir LIMPIA (sin escritura): el texto lo pone el código.

### B · Piezas sueltas del boss
- [x] `boss_syntax_body.png`
- [x] `boss_syntax_board.png` — Sin escritura: el nombre, la secuencia y APROBADO/REPROBADO los escribe el código.
- [x] `boss_syntax_head.png` — Los ojos (puntos) y las expresiones se dibujan por código encima de las gafas.
- [x] `boss_syntax_pointer.png` — Rectos hacia abajo y del mismo largo: el código los gira desde el hombro.
- [x] `boss_syntax_hand.png` — Igual: rectos hacia abajo y del mismo largo.

### C · Proyectiles, pupitres, esbirro y pedazos
- [x] `boss_syntax_projectiles.png` — Tiza, bloque ABC (las letras por código), página, globo de diálogo, avión-boleto, punto final, púa braille y cono.
- [x] `boss_syntax_desks.png` — Pupitres de La Lección: los símbolos ▲●■★ los pinta el código en el panel del respaldo.
- [x] `boss_syntax_bellhop.png` — Esbirros botones-robot del ataque de Gestión Hotelera.
- [x] `boss_syntax_debris.png` — Pedazos que salen volando al morir.

## Notas de grokbot
(resumen al terminar: herramienta usada en cada hoja y qué falló)
- boss_syntax_full: ChatGPT, 2 versiones; se eligio la 2, 1254x1254. Pizarra limpia sin texto; la regla solo tiene rayitas, sin numeros. Aprobada.
- boss_syntax_body: ChatGPT, primer intento. Tenis rojo con blanco y chaleco iguales a la hoja A.
- boss_syntax_board: ChatGPT, primer intento. Dio 2 opciones y se eligio la primera; pizarras sin escritura.
- boss_syntax_head: ChatGPT, primer intento. Globo con lentes y birrete; el birrete suelto va aparte.
- boss_syntax_pointer: ChatGPT, primer intento. La regla solo tiene rayitas, sin numeros.
- boss_syntax_hand: ChatGPT, primer intento.
- boss_syntax_projectiles: ChatGPT, primer intento. El bloque ABC salio sin letras y el globo de dialogo vacio.
- boss_syntax_desks: ChatGPT, primer intento.
- boss_syntax_bellhop: ChatGPT, primer intento.
- boss_syntax_debris: ChatGPT, primer intento.
