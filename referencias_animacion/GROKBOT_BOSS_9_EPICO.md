# TAREA PARA GROKBOT — Boss 9 SUDO, ronda ÉPICA (6 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_BOSS_9_EPICO.md`. Primera ronda (ya integrada): `GROKBOT_BOSS_9.md`.

## Qué se pide
Que los ataques de SUDO se vean más épicos: una hoja de poses de poder del boss y 5 hojas de efectos animados (8 cuadros cada una, en orden de animación) que reemplazan los efectos que hoy se dibujan con líneas.
- E: poses de poder (1 hoja). **Hacerla primero y avisar**: Johan revisa que siga pareciéndose a él.
- F: efectos animados (5 hojas): rayo verde, explosión de fuego, explosión cósmica, sol con llamarada y estallido digital.

## Reglas clave
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- E: mismo SUDO de la hoja aprobada (cara, barba, ropa) y la MISMA estatura que en `boss_sudo_idle_walk8.png`. Clicker en la mano del lado IZQUIERDO de la imagen y reloj en la muñeca del lado DERECHO. Sin efectos dibujados (la energía la pone el código).
- F: los 8 cuadros en orden, todos centrados en el mismo punto y al mismo tamaño, cada uno dentro de su celda sin tocar a los vecinos.
- **Fondo:** `boss_sudo_fx_bolt8` va sobre fondo MAGENTA #FF00FF (el rayo es verde); todas las demás sobre menta #A0EFA5.
- Sin texto, números, símbolos ni logos en ningún lado (el estallido digital es solo de cuadritos, sin letras).
- Si ChatGPT falla 2 veces (cuadros desordenados, cambia el personaje, mete texto), probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png`. Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso


### E · Poses de poder (8 poses, 4x2)
- [ ] `boss_sudo_power8.png` — Poses de poder (cargar, gritar, embestida en el aire, golpe al piso, invocar, lanzar, forcejeo y victoria). Misma escala que las poses anteriores.

### F · Efectos animados (8 cuadros cada uno, 4x2, en orden)
- [ ] `boss_sudo_fx_bolt8.png` — Rayo verde de Supabase (fondo MAGENTA, no menta).
- [ ] `boss_sudo_fx_fire8.png` — Explosión de fuego (supernova, placas tectónicas).
- [ ] `boss_sudo_fx_cosmic8.png` — Explosión cósmica (golpe final del ASTRA).
- [ ] `boss_sudo_fx_sun8.png` — Sol cargando (1-4) y disparando la llamarada (5-8).
- [ ] `boss_sudo_fx_data8.png` — Estallido digital (Cmd+K, aterrizaje del Tab, golpe de Edge Function).

## Notas de grokbot
(resumen al terminar: herramienta usada en cada hoja y qué falló)

