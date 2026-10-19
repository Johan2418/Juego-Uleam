# TAREA PARA GROKBOT — Boss 1: 0xDEADBEEF (10 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_BOSS_1.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/b298b2a5-70f0-4681-977e-03a9bae51608

## Qué se pide
El primer boss, de la Facultad de Ciencias de la Vida y Tecnología. Se anima POR PIEZAS en el juego: por eso se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.
- A: el boss completo (1 hoja). **Hacerla primero**: todas las de B usan esta como Imagen 2.
- B: piezas sueltas del boss (5 hojas).
- C: animales, esbirro, proyectiles y pedazos (4 hojas).

## Reglas clave
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.
- SIN TEXTO en ningún lado (ni en el monitor). Sin humanos pequeños (la referencia los tiene, no copiarlos).
- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.
- Los brazos (claw y grabber) rectos hacia abajo, con el hombro arriba, mismo largo en las 3 poses.
- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso


### A · Boss completo (hacer primero)
- [x] `boss_0xdeadbeef_full.png` — Primera y más importante: las demás hojas copian esta. Si sale con texto en el monitor o con humanos pequeños, repetir.

### B · Piezas sueltas del boss
- [x] `boss_0xdeadbeef_body.png`
- [x] `boss_0xdeadbeef_tank.png`
- [x] `boss_0xdeadbeef_head.png` — El monitor debe salir con la pantalla negra lisa: el texto y las caras se dibujan por código.
- [x] `boss_0xdeadbeef_claw.png` — Importante que los 3 brazos salgan rectos hacia abajo y del mismo largo: el código los gira desde el hombro.
- [x] `boss_0xdeadbeef_grabber.png` — Igual que la garra: rectos hacia abajo y del mismo largo.

### C · Animales, esbirro, proyectiles y pedazos
- [x] `boss_animals.png` — Para la estampida (como las vacas de la referencia).
- [x] `boss_minion_plant.png` — Esbirros que salen en la fase 2.
- [x] `boss_props.png` — Proyectiles de la lluvia de cajas y las raíces del suelo.
- [x] `boss_debris.png` — Pedazos que salen volando al morir; la flor y el pasto son para cuando la arena se limpia.

## Notas de grokbot
(resumen al terminar: herramienta usada en cada hoja y qué falló)

## Notas de grokbot

- 2026-10-16: las 10 hojas se hicieron en ChatGPT, modo Chat, cada una en un chat nuevo y al primer intento. Para boss_0xdeadbeef_full se generaron 2 versiones y se eligio la segunda por parecerse mas a la referencia.
- boss_0xdeadbeef_full y boss_0xdeadbeef_head salieron a 1254x1254, cuadradas, en vez de 1024. Las demas son 1536x1024.
- Revisado: ninguna tiene texto, el monitor de la cabeza es negro liso, la garra y el agarrador cuelgan rectos con el hombro arriba y no se dibujo al estudiante ni humanos pequenos.
