# TAREA PARA GROKBOT — Boss 5: STACK OVERFLOW (10 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_BOSS_5.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/c6fba194-8436-47ab-ae6c-c0227d20ae9d

## Qué se pide
El quinto boss, de la Facultad de Ingeniería, Industria y Arquitectura: una máquina de obra mitad grúa mitad excavadora, con orugas y casco. Se anima POR PIEZAS en el juego, igual que los bosses 1 a 4: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.
- A: el boss completo (1 hoja). **Hacerla primero y avisar**: esta define el diseño. Las de B y C usan esta como Imagen 1.
- B: piezas sueltas del boss (5 hojas).
- C: piezas de la torre, proyectiles, esbirro y pedazos (4 hojas).

## Reglas clave
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.
- SIN TEXTO NI NÚMEROS en ningún lado (ni en el visor, ni en las latas, ni en los contenedores, ni en el plano). Sin humanos pequeños. Sin sangre.
- En la hoja A, el boss 4 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.
- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.
- Los brazos (crane y hammer) rectos hacia abajo, con el hombro arriba, mismo largo en las 3 poses.
- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso


### A · Boss completo (hacer primero)
- [x] `boss_stack_full.png` — Primera y más importante: las demás hojas copian esta. El visor del casco debe salir liso y oscuro (sin cara ni texto).

### B · Piezas sueltas del boss
- [x] `boss_stack_body.png`
- [x] `boss_stack_engine.png`
- [x] `boss_stack_head.png` — El visor liso: la cara y los textos se dibujan por código.
- [x] `boss_stack_crane.png` — Rectos hacia abajo y del mismo largo: el código los gira desde el hombro.
- [x] `boss_stack_hammer.png` — Igual: rectos hacia abajo y del mismo largo.

### C · Torre, proyectiles, esbirro y pedazos
- [x] `boss_stack_tower.png` — Piezas de La Torre: se apilan una sobre otra; la base agrietada es la que golpea el jugador.
- [x] `boss_stack_projectiles.png` — Lata, engranaje-sierra, poste eléctrico, cono, tuerca, ola, plano y chispa.
- [x] `boss_stack_drone.png` — Esbirros obreros (los llama en fase 2 y 3).
- [x] `boss_stack_debris.png` — Pedazos que salen volando al morir.

## Notas de grokbot
(resumen al terminar: herramienta usada en cada hoja y qué falló)
- boss_stack_full: ChatGPT, 2 versiones; se eligio la 2 porque la 1 se salia de los bordes. 1254x1254, visor del casco limpio sin letras.
- boss_stack_body: ChatGPT, primer intento. Orugas y cabina, limpio y danado.
- boss_stack_engine: ChatGPT, primer intento.
- boss_stack_head: ChatGPT, primer intento. Visor oscuro liso, sin texto.
- boss_stack_crane: Gemini. Los 2 intentos en ChatGPT salieron en diagonal; Gemini lo dio recto hacia abajo. Salio en JPEG 2752x1536 y se paso a PNG.
- boss_stack_hammer: ChatGPT, primer intento. El brazo se curva un poco cerca del hombro, pero la herramienta queda vertical.
- boss_stack_tower: ChatGPT, primer intento.
- boss_stack_projectiles: ChatGPT, primer intento.
- boss_stack_drone: ChatGPT, primer intento.
- boss_stack_debris: ChatGPT, primer intento.
