# TAREA PARA GROKBOT — Ronda ÉPICA de los bosses 1-8 (16 hojas de efectos)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_BOSSES_EPICO.md`.

## Qué se pide
Dos hojas de EFECTOS ANIMADOS por boss (8 cuadros cada una, en orden de animación, rejilla 4x2): el golpe/explosión principal y el efecto del clímax de su duelo final. Reemplazan los efectos dibujados por código. Mismo estilo que los efectos de SUDO (Imagen 1 de cada prompt).

## Reglas clave
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Los 8 cuadros en orden, todos centrados en el mismo punto y al mismo tamaño, cada uno dentro de su celda sin tocar a los vecinos.
- **Fondo:** `boss_deadbeef_fx_toxic8` va sobre fondo MAGENTA #FF00FF (el gas es verde); todas las demás sobre menta #A0EFA5.
- Sin texto, números, símbolos ni logos en ningún lado.
- Si ChatGPT falla 2 veces (cuadros desordenados, mete texto, fondo no plano), probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso

### 0xDEADBEEF
- [ ] `boss_deadbeef_fx_toxic8.png` — Explosión de gas tóxico verde (impactos fuertes).
- [ ] `boss_deadbeef_fx_core8.png` — Explosión del núcleo: chispas rojas, humo y piezas de metal (clímax).

### B.S.O.D.
- [ ] `boss_bsod_fx_shock8.png` — Descarga eléctrica azul (impactos fuertes).
- [ ] `boss_bsod_fx_pulse8.png` — Latido: onda roja de corazón (clímax, desfibrilación).

### #DIV/0!
- [ ] `boss_div0_fx_coins8.png` — Explosión de monedas de oro (impactos fuertes).
- [ ] `boss_div0_fx_crash8.png` — Crash: estallido rojo con billetes y vidrio (clímax).

### SYNTAX ERROR
- [ ] `boss_syntax_fx_chalk8.png` — Explosión de polvo de tiza blanca (impactos fuertes).
- [ ] `boss_syntax_fx_ink8.png` — Salpicadura de tinta roja de corrección (clímax).

### STACK OVERFLOW
- [ ] `boss_stack_fx_rubble8.png` — Escombros y polvo de concreto (impactos fuertes).
- [ ] `boss_stack_fx_weld8.png` — Chispas de soldadura (clímax, derrumbe).

### 403 FORBIDDEN
- [ ] `boss_judge_fx_gavel8.png` — Golpe de mazo: onda dorada (impactos fuertes).
- [ ] `boss_judge_fx_seal8.png` — Sello de lacre rojo que estalla (clímax, ¡OBJECIÓN!).

### MISSING TEXTURE
- [ ] `boss_tex_fx_glitch8.png` — Estallido glitch magenta y negro (impactos fuertes).
- [ ] `boss_tex_fx_marble8.png` — Mármol que se hace pedazos (clímax).

### KERNEL PANIC
- [ ] `boss_kp_fx_flame8.png` — Llamarada de flambé (impactos fuertes).
- [ ] `boss_kp_fx_static8.png` — Estática de TV: sin señal (clímax, corte).

## Notas de grokbot
(resumen al terminar: herramienta usada en cada hoja y qué falló)
