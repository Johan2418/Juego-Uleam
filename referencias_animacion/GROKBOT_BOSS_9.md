# TAREA PARA GROKBOT — Boss 9: SUDO, el Líder del Club IA (12 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a `referencias_animacion/`).
Prompts: `referencias_animacion/PROMPTS_BOSS_9.md`. Diseño (Claude Doc): https://claude.ai/artifact/2JUPWg5GXDgzCFkxQMgdjT

## Qué se pide
El boss 9 del Club IA: un expositor (persona real, foto en `bosses/sudo_referencia.jpg`) con clicker y pantalla de proyector. Es el ÚNICO boss humano: NO se arma por piezas como los bosses 1 a 8, se anima por POSES (hojas de 8 poses en 4x2, como los personajes jugables).
- A: el boss completo (1 hoja). **Hacerla primero y avisar**: Johan revisa que se parezca a él. Las demás usan esta como Imagen 1.
- B: poses del boss (4 hojas de 8 poses).
- C: pantalla, esbirros, astros, objetos y proyectiles (5 hojas).
- D: arena pintada (2 imágenes, después de A).

## Reglas clave
- Conversación NUEVA por hoja, adjunta Imagen 1 y luego Imagen 2, pega el prompt completo sin cambios.
- Que se PAREZCA a la foto (cara, barba, pelo, ropa), pero en caricatura pixel art chibi, no realista.
- Fondo menta liso #A0EFA5, sin sombra. Pixel art duro, sin difuminado.
- SIN TEXTO NI LOGOS: nada de marcas (Supabase, Cursor, Clerk, Grok, OpenAI...). La camiseta solo lleva 2 rayitas blancas; el código escribe "CLUB IA".
- La pantalla del proyector va VACÍA: las diapositivas las dibuja el código.
- En las hojas de poses: reloj y clicker siempre en su mano IZQUIERDA (el brazo del lado DERECHO de la imagen, como en la foto); misma escala en las 8 poses.
- Si ChatGPT falla 2 veces (no se parece, cambia ropa, pone texto), probar Gemini. Si falla otra vez, `[!]` con nota.

## Guardado
`referencias_animacion/_entregas_runway/bosses/<nombre exacto>.png` (arenas en `_entregas_runway/arenas/`). Marca `[x]` al guardar; `[!]` con nota si falla. No toques código, `assets/`, `scenes/` ni `scripts/`.

## Progreso


### A · Boss completo (hacer primero y revisar con Johan)
- [ ] `boss_sudo_full.png` — Primera y más importante: las demás hojas copian esta. Revisarla con Johan (que se parezca a él) antes de seguir.

### B · Poses del boss (hojas de 8 poses, 4x2)
- [ ] `boss_sudo_idle_walk8.png`
- [ ] `boss_sudo_cast8.png`
- [ ] `boss_sudo_moves8.png`
- [ ] `boss_sudo_hurt8.png`

### C · Pantalla, esbirros, astros, objetos y proyectiles
- [ ] `boss_sudo_screen.png` — Pantalla vacía: los textos de la diapositiva los dibuja el código.
- [ ] `boss_sudo_minions.png` — Grokbot (1-6) y el cursor-agente (7-8). Sin logos.
- [ ] `boss_sudo_planets.png` — Terra, Luna y Sol que orbitan en la fase 3, normales y apagados.
- [ ] `boss_sudo_props.png`
- [ ] `boss_sudo_projectiles.png`

### D · Arena (fondo pintado, fase 1-2 y fase 3)
- [ ] `arena_sudo.png`
- [ ] `arena_sudo_caos.png`

## Notas de grokbot
(resumen al terminar: herramienta usada en cada hoja y qué falló)

