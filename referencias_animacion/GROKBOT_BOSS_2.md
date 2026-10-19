# TAREA PARA GROKBOT — Boss 2: B.S.O.D. (10 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_BOSS_2.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/af1330c1-50d1-45a8-9e11-805d2cccb65f

## Qué se pide
El segundo boss, de la Facultad de Ciencias de la Salud: un robot cirujano. Se anima POR PIEZAS en el juego, igual que el boss 1: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.
- A: el boss completo (1 hoja). **Hacerla primero y avisar a Johan**: no hay imagen de referencia, así que esta define el diseño. Las de B y C usan esta como Imagen 1.
- B: piezas sueltas del boss (5 hojas).
- C: proyectiles, comida, esbirro y pedazos (4 hojas).

## Reglas clave
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.
- SIN TEXTO en ningún lado (ni en el monitor). Sin humanos pequeños. Sin sangre.
- En la hoja A, el boss 1 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.
- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.
- Los brazos (scalpel y tool) rectos hacia abajo, con el hombro arriba, mismo largo en las 3 poses.
- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso


### A · Boss completo (hacer primero)
- [x] `boss_bsod_full.png` — Primera y más importante: las demás hojas copian esta. No hay imagen de referencia del diseño: revisar con Johan antes de seguir. Repetir si sale con texto, sangre o humanos pequeños.

### B · Piezas sueltas del boss
- [x] `boss_bsod_body.png`
- [x] `boss_bsod_heart.png`
- [x] `boss_bsod_head.png` — Las pantallas deben salir negras lisas: el electrocardiograma y las caras se dibujan por código.
- [x] `boss_bsod_scalpel.png` — Rectos hacia abajo y del mismo largo: el código los gira desde el hombro (igual que la garra del boss 1).
- [x] `boss_bsod_tool.png` — Igual: rectos hacia abajo y del mismo largo.

### C · Proyectiles, comida, esbirro y pedazos
- [x] `boss_bsod_projectiles.png` — Jeringas, tubos de laboratorio, placa de Petri, pelota de terapia, bloque de rompecabezas y charco.
- [x] `boss_bsod_food.png` — Para la pirámide alimenticia: arriba la comida sana (cura), abajo la chatarra (daña).
- [x] `boss_bsod_bacteria.png` — Esbirros que salen de la placa de Petri; se dividen al primer golpe.
- [x] `boss_bsod_debris.png` — Pedazos que salen volando al morir.

## Notas de grokbot
- boss_bsod_full: ChatGPT. De 2 intentos, el 1 salio como copia del boss 1 y se descarto; el 2 es el guardado, 1254x1254. Aprobada por Johan.
(resumen al terminar: herramienta usada en cada hoja y qué falló)
- Hojas B y C: las 9 en ChatGPT, modo Chat, un chat nuevo por hoja, al primer intento. Imagen 1 boss_bsod_full; Imagen 2 boss_0xdeadbeef_full o wadrid_idle_down segun el prompt. Revisado: sin texto ni sangre, pantallas de la cabeza negras lisas, brazos con el hombro arriba y mismo largo. boss_bsod_head salio 1254x1254, las demas 1536x1024.
