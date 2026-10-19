# TAREA PARA GROKBOT — Boss 3: #DIV/0! (10 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_BOSS_3.md`. Diseño completo (Claude Doc): https://claude.ai/code/artifact/5f8c0327-f173-4fb8-8efe-c76c93517939

## Qué se pide
El tercer boss, de la Facultad de Ciencias Administrativas, Contables y Comercio: un robot-bóveda ejecutivo. Se anima POR PIEZAS en el juego, igual que los bosses 1 y 2: se pide el boss completo una vez y luego cada pieza suelta, en la misma escala y vista.
- A: el boss completo (1 hoja). **Hacerla primero y avisar a Johan**: no hay imagen de referencia, así que esta define el diseño. Las de B y C usan esta como Imagen 1.
- B: piezas sueltas del boss (5 hojas).
- C: proyectiles, contenedores, esbirro y pedazos (4 hojas).

## Reglas clave
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.
- SIN TEXTO NI NÚMEROS en ningún lado (ni en el monitor, ni en la calculadora, ni en los billetes). Sin humanos pequeños. Sin sangre.
- En la hoja A, el boss 2 (Imagen 2) es SOLO referencia de estilo: no copiar su diseño ni sus colores.
- Las piezas (B) deben verse IGUAL que en la hoja A: mismos colores, mismo tamaño de píxel, misma vista de frente 3/4.
- Los brazos (stamp y tool) rectos hacia abajo, con el hombro arriba, mismo largo en las 3 poses.
- Si ChatGPT falla 2 veces (texto, cambia el diseño, mezcla piezas), probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso


### A · Boss completo (hacer primero)
- [x] `boss_div0_full.png` — Primera y más importante: las demás hojas copian esta. No hay imagen de referencia del diseño: revisar con Johan antes de seguir. Repetir si sale con texto, números o humanos pequeños.

### B · Piezas sueltas del boss
- [x] `boss_div0_body.png`
- [x] `boss_div0_vault.png`
- [x] `boss_div0_head.png` — Las pantallas deben salir lisas (verde oscuro): los errores #DIV/0! y las caras se dibujan por código.
- [x] `boss_div0_stamp.png` — Rectos hacia abajo y del mismo largo: el código los gira desde el hombro (igual que los brazos de los bosses 1 y 2).
- [x] `boss_div0_tool.png` — Igual: rectos hacia abajo y del mismo largo. Las teclas de la calculadora sin números.

### C · Proyectiles, contenedores, esbirro y pedazos
- [x] `boss_div0_projectiles.png` — Monedas, billete, caja del organigrama, lupa, ventana emergente, mancha de sello y recibo.
- [x] `boss_div0_containers.png` — Para el ataque de Comercio Exterior: pasan por carriles a toda velocidad.
- [x] `boss_div0_briefcase.png` — Esbirros "pasantes" que salen en el ataque de Talento Humano.
- [x] `boss_div0_debris.png` — Pedazos que salen volando al morir.

## Notas de grokbot
(resumen al terminar: herramienta usada en cada hoja y qué falló)
- boss_div0_full: ChatGPT, 2 versiones; se eligio la 2, mas ancha y pesada como pide el prompt, 1254x1254. Sin texto ni numeros. APROBADA por Johan (16-10 17:45): seguir con B y C.
- boss_div0_body: ChatGPT, primer intento. Cinta de papel como bufanda y maletin en el cinturon, igual que la hoja A.
- boss_div0_vault: ChatGPT, primer intento.
- boss_div0_head: ChatGPT, primer intento, 1254x1254. Pantallas verde oscuro lisas; el sombrero suelto lleva la banda roja.
- boss_div0_stamp: ChatGPT, segundo intento. El primero salio en blanco y turquesa, colores del boss 2; el segundo es gris y dorado como la hoja A.
- boss_div0_tool: Gemini, tras 2 intentos en ChatGPT con marcas parecidas a numeros en las teclas. La version de Gemini tiene los brazos mas rectos; las teclas crema aun muestran marquitas muy tenues, revisar. Salio en JPEG 2752x1536 y se paso a PNG.
- boss_div0_projectiles: ChatGPT, primer intento. El billete no lleva numeros; la mancha de sello es roja.
- boss_div0_containers: ChatGPT, primer intento.
- boss_div0_briefcase: ChatGPT, primer intento.
- boss_div0_debris: ChatGPT, primer intento.
