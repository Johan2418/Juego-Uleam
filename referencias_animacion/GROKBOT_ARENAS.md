# TAREA PARA GROKBOT — Arenas de los 8 bosses (16 imágenes)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_ARENAS.md`.

## Qué se pide
El fondo de la sala de combate de cada boss, en vista de arriba 3/4, para poner debajo del juego. Dos imágenes por boss:
- `arena_<boss>.png`: la sala normal (fases 1 y 2).
- `arena_<boss>_caos.png`: la MISMA sala destrozada para la fase 3. Se hace después de la normal y usa la normal como Imagen 1.

## Reglas clave
- Conversación NUEVA por imagen, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Es un FONDO completo (no fondo menta): la sala llena toda la imagen.
- Pared del fondo arriba (~15% del alto), paredes laterales finas, y el CENTRO es un piso grande, plano y vacío (ahí pelean los personajes). Si sale un mueble, columna o agujero en medio del piso, rehacer.
- SIN TEXTO NI NÚMEROS en ningún lado (pantallas, pizarra, carteles). Sin personas ni personajes. No dibujar al boss ni al estudiante.
- La versión _caos debe tener el mismo encuadre que la normal (mismas paredes en el mismo lugar).
- Si ChatGPT falla 2 veces, probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/arenas/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso

### 1 · 0xDEADBEEF (Vida y Tecnología)
- [x] `arena_deadbeef.png`
- [x] `arena_deadbeef_caos.png` — después de la normal, usándola como Imagen 1.

### 2 · B.S.O.D. (Ciencias de la Salud)
- [x] `arena_bsod.png`
- [x] `arena_bsod_caos.png` — después de la normal, usándola como Imagen 1.

### 3 · #DIV/0! (Ciencias Administrativas, Contables y Comercio)
- [x] `arena_div0.png`
- [x] `arena_div0_caos.png` — después de la normal, usándola como Imagen 1.

### 4 · SYNTAX ERROR (Educación, Turismo y Humanidades)
- [x] `arena_syntax.png`
- [x] `arena_syntax_caos.png` — después de la normal, usándola como Imagen 1.

### 5 · STACK OVERFLOW (Ingeniería, Industria y Arquitectura)
- [x] `arena_stack.png`
- [x] `arena_stack_caos.png` — después de la normal, usándola como Imagen 1.

### 6 · 403 FORBIDDEN (Ciencias Sociales, Derecho y Bienestar)
- [x] `arena_judge.png`
- [x] `arena_judge_caos.png` — después de la normal, usándola como Imagen 1.

### 7 · MISSING TEXTURE (Artes, Humanidades y Patrimonio)
- [x] `arena_tex.png`
- [x] `arena_tex_caos.png` — después de la normal, usándola como Imagen 1.

### 8 · KERNEL PANIC (Unidad de Formación Técnicas y Tecnológicas (Gastronomía, Comunicación TV y RRPP))
- [x] `arena_kp.png`
- [x] `arena_kp_caos.png` — después de la normal, usándola como Imagen 1.

## Notas de grokbot
(resumen al terminar: herramienta usada en cada imagen y qué falló)

- Las 16 arenas se hicieron con ChatGPT al primer intento, chat nuevo por imagen; Gemini no fue necesario.
- Cada _caos uso su normal como Imagen 1 y mantiene el mismo encuadre de paredes.
- Revisadas: centro del piso grande y vacio en todas, sin texto ni personajes. En arena_judge la alfombra roja del centro es plana, la pide el prompt.
- arena_tex_caos tiene parches magenta y negro en paredes y cuadros, como pide su prompt; el piso queda normal.