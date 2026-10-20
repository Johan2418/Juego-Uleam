# CONTEXTO DEL PROYECTO — Prototipo Campus (Godot 4.6)

> **Documento compartido entre sesiones/cuentas de Claude.** Varias cuentas trabajan en este mismo proyecto, en el mismo PC, por turnos (cuando una se queda sin uso, sigue la otra).
> **Regla de oro:** ANTES de tocar nada, lee este archivo completo. AL TERMINAR cada tarea (o antes de que se corte la sesión), actualiza las secciones **Estado actual**, **Trabajo en curso** y **Bitácora**. Si no queda escrito aquí, la otra sesión no lo sabe.

- Ruta del archivo: `C:\Users\leopo\Documents\Juegos\Godot\prototipo\CONTEXTO_PROYECTO.md`
- Última actualización: 2026-10-18 (noche) — hilo de bosses: los 8 bosses con mecánica por fase + DUELO FINAL + música de duelo

---

## 1. Protocolo de traspaso entre cuentas

**Al empezar una sesión:**
1. Leer este archivo entero.
2. Mirar **Trabajo en curso**: si hay algo a medias, verificar en disco qué quedó hecho (archivos, `[x]` en los `.md` de grokbot, `tools/scale_fix.json`, etc.) antes de continuar. No repetir pasos ya hechos.
3. Si algo del disco contradice este documento, manda el disco: corregir el documento y anotarlo en la Bitácora.

**Durante la sesión:**
- Actualizar **Trabajo en curso** cada vez que se termine un paso importante (no esperar al final: la sesión puede cortarse sin aviso por límite de uso).
- Antes de cambios grandes en scripts o JSON de calibración, hacer backup con fecha (`<archivo>_backup_AAAA-MM-DD.<ext>`).

**Al terminar:**
1. Mover lo hecho de *Trabajo en curso* a **Estado actual** (resumido) y a **Bitácora** (una entrada con fecha).
2. Dejar en *Trabajo en curso* el siguiente paso concreto, o "nada pendiente".
3. Fecha y cuenta en "Última actualización" arriba.

Formato de entrada de bitácora:
```
### AAAA-MM-DD — <tema corto>
- Qué se hizo / archivos tocados
- Cómo se verificó (gif/captura en `Claude outputs/`)
- Pendiente que deja
```

---

## 2. Qué es el proyecto

- Juego top-down estilo Zelda (*A Link to the Past* / *Minish Cap*) ambientado en un campus universitario (ULEAM). Para "casa abierta". Facultades como mazmorras (futuro).
- Godot **4.6** (GDScript). Binario: `Godot_v4.6.2-stable_win64.exe`. Ventana 1280×720.
- Flujo: creador de personaje (`scenes/character_creator.tscn`) → Confirmar → patio con combate (`scenes/main.tscn`). Datos del personaje en el autoload `GameState` (`user://player_appearance.cfg`).
- **2 personajes jugables** con animaciones dedicadas: **Wadrid** y **MarlonX-a**. (El sistema de cabeza+cuerpo compartido para 18 personajes se descartó porque se veía mal; su código sigue: `character_rig.gd`, `character_catalog.gd`, `shaders/outfit_recolor.gdshader`; `CharacterCatalog.ONLY_PLAYABLE = true` filtra a los 2).
- **3 clases:** Guerrero, Mago, Chain.

### Controles
J ataque leve (combo) · K especial (cooldown) · L parry · Espacio ultimate (medidor) · Shift rodar (i-frames, igual en las 3 clases; MANTENERLO = correr al terminar de rodar) · Q / R3 fijar objetivo (Tab / stick der. cambia) · E entrar a puerta · R reintentar (fin del boss) · F1 llenar ultimate (debug) · F2 saltar fase (debug) · Esc volver. WASD/flechas mover.
**Mando (desde 2026-10-18, estilo Xbox):** stick izq./cruceta mover · X combo · Y especial · LB parry · B rodar · RB ultimate · A entrar a puerta · Start (o A) reintentar · Select volver. Todo en `scripts/input_setup.gd` (lo llama `GameState._ready`). `GameState.using_pad` dice si lo último tocado fue el mando y `GameState.btn("<acción>")` da el texto del botón; los textos de ayuda (campus, puerta, HUD, pantalla final del boss) cambian solos. En el creador: cruceta mueve el foco, A pulsa, LB/RB cambian personaje, Start confirma. Usar acciones (`is_action_pressed("interact"/"back"/"retry")`), NO teclas fijas ni `ui_cancel` (en mando ui_cancel = B = rodar).

### Diseño de combate (decidido por el usuario)
- **Ataque leve = combo** (pulsaciones seguidas encadenan golpes distintos) con **remate** propio en las 3 clases.
- **Parry solo cubre el FRENTE** (cono ±75°). Golpe por espalda/costado entra igual. **El parry es solo parry** (decisión del usuario 2026-10-18): un parry exitoso abre `COUNTER_WINDOW` = 0,55 s; si el jugador pulsa ataque (J / X) en ese tiempo sale el contraataque (`ClassController._start_counter`, daño 2); si no, solo bloquea. El HUD muestra "¡J CONTRAATAQUE!" durante la ventana (`counter_window_left()`).
- Mago: barrera solo al frente. Chain: escudo de cable más grande.
- **Cada ultimate es única:**
  - Guerrero: espadazo con la regla que libera un haz/explosión hacia el frente (`_ult_beam`).
  - Mago: rayos que caen en puntos al azar, la mitad busca enemigos (`_ult_lightning`).
  - Chain: cables que se extienden mientras gira; el jugador puede caminar (`_ult_cable_storm`; rodar la cancela).
- Guerrero: tajo con regla / embestida con borrador / parry con borrador. Mago: orbe / abanico de 3 orbes / barrera. Chain: latigazo corto / latigazo largo que atrae / cable girando como escudo.

---

## 3. Mapa del código y herramientas

**Godot (`scripts/`):**
- `character/character_sprites.gd` — arma todas las animaciones desde los frames recortados (5 direcciones: down, up, right, down_right, up_right; izquierdas por espejo). Constantes clave: `USE_WALK_MID = false`, `MID_ALLOW = ["guerrero_attack"]`, `MID_SKIP`, `MIRROR_SHEETS = ["roll_up_right"]`, `_breathe()`. Prioridad: hoja `<base>8_<dir>` (8 poses) > hoja de 4 poses.
- `combat/class_controller.gd` — combo J, especial K, parry L (`parry_covers(from)`), ultimates, contraataque, hitbox (rotada en diagonal).
- `combat/player.gd` — vida 10, `take_hit`, flinch/knockdown, i-frames, HUD (Vida / K / Ultimate), `_action_dir`, `idle_long` tras 7 s quieto.
- `combat/dummy_enemy.gd` — grupo "enemies", ataca cada 2.2 s (aviso amarillo 0.45 s), HP 8 regenera, `pull_toward()`, knockback 125+60·daño. Hay 2 dummies en la escena.
- `combat/ult_fx.gd` (FrontBarrier, CableShield, BeamFx, LightningStrike, CableStorm) y `combat/game_feel.gd` (hit-stop, destellos, squash & stretch, sombra, polvo, fantasmas al rodar, ParryBurst). **Ambos SIN `class_name`, cargados con `preload`.**

**Python (`tools/`):**
- `slice_character_sheets.py [personaje] [filtro]` — recorta hojas → `assets/sprites/characters_anim/<id>/<anim>_<dir>_<i>.png` (lienzo 160×160, pies en y=152). Soporta 2x2 (4 poses) y GRID8 (4×2, 8 poses), `COLOR_MATCH`, `render_pose(..., aspect)` (estira solo el cuerpo, HEAD_FRAC=0.42), `_drop_neighbor_spill`.
- `scale_fix.json` (factor de escala por hoja, ~190 entradas) y `aspect_fix.json` (estiramiento vertical por hoja). Backups con fecha en `tools/`.
- `gen_prompts_pulido*.py` — generan los `.md` de prompts/tareas de grokbot (re-ejecutables, no pisan el progreso).
- `split_block.py`, `crop_agent20_presets.py`, etc.

**Arte y tareas (`referencias_animacion/`):**
- `_entregas_runway/` — hojas entregadas (Runway / grokbot). `_rechazadas/` — hojas rechazadas (sufijo `_r1`, `_r2`).
- `GROKBOT_*.md` — listas de tareas de grokbot con progreso `[x]` hecho / `[!]` problema / `[ ]` pendiente. `PROMPTS_*.md` — prompts.

**Verificación:** `Claude outputs/` — gifs y capturas de cada cambio (p. ej. `consistencia_<id>.png`, `ataques_en_juego_v2.gif`, `diagonales_rodar_atacar.gif`). Los `.tgz` ahí son paquetes de trabajo de sesiones anteriores (no hace falta abrirlos).

---

## 4. Forma de trabajar (preferencias del usuario y lecciones aprendidas)

**Con el usuario:**
- Hablar en **español**, directo. El usuario prueba en su editor y da feedback visual ("se encogen al atacar", "mini salto", etc.) → diagnosticar la causa real antes de parchar.
- Trabajar por **fases/rondas**: preparar → el usuario (o grokbot) entrega → integrar → verificar → reportar con un gif/captura.
- Mostrar siempre el resultado con un gif o tira visual en `Claude outputs/`.

**Generación de sprites:**
- **grokbot** = agente del usuario con acceso a su Gemini / ChatGPT Plus que lee y edita archivos del proyecto. Se le deja un `GROKBOT_*.md` con la lista de tareas y él guarda las hojas en `_entregas_runway/` y marca `[x]`.
- ChatGPT copia muy bien el diseño pero: colores más saturados, algo más cabezón, y en vistas de espaldas espeja el 2.º golpe (arma a la mano izquierda) → usar HAND RULE o Gemini para esas.
- Hojas de 8 poses = UNA imagen 4×2 (3:2); la pose 8 siempre de pie (referencia de altura). Las poses intermedias generadas por separado NO sirven para intercalar.
- Vistas de espaldas: añadir "CRITICAL VIEW RULE" (sin cara, sin carnet visible).
- Runway (nano-banana-pro, 3:4, ~20 créditos/imagen): cuenta "Johan" activa; "Alyson" sin créditos. El proxy de la sesión no puede subir/descargar directo a Runway: el usuario descarga y pasa las hojas.
- Plantilla de prompt base: *"2D pixel art character sheet of @tag, top-down 3/4 view action-RPG, 16-bit SNES style, chibi proportions, crisp 1-pixel black outline, hard pixels, no anti-aliasing, no blur. Flat solid mint green background (#A0EFA5). Exactly 4 full-body poses of the SAME character arranged in a 2x2 grid with lots of empty space between them, wide empty margin, nothing touching the image edges."* + personaje + equipo + poses + *"No effects, no motion lines, no text."* Refuerzo: *"keep EXACTLY the same character design, head size, body width, hair color and skin color as the second attached image"*.
  - Wadrid: big curly dark brown afro, black rectangular glasses, warm medium-brown skin, dark green polo, blue lanyard + grey ID, blue jeans, brown shoes.
  - MarlonX-a: short straight black hair, black rectangular glasses, light-brown skin, charcoal dark grey polo with small gold badge, blue lanyard + light ID, blue jeans, black shoes.
  - Guerrero: long wooden school ruler as a sword (RIGHT hand) + big pink rubber eraser strapped to LEFT forearm. Mago: gnarled wooden branch staff with small glowing blue crystal (RIGHT hand), "Do NOT draw any projectile". Chain: black phone charger cable as a whip, held by the plug in the RIGHT hand.

**Integrar hojas nuevas (receta):**
1. Revisar visualmente cada hoja (mismo personaje, vista correcta, mano correcta, sin efectos). Rechazadas → `_rechazadas/` con sufijo y reabrir en el `.md` de grokbot.
2. Recortar por filtro: `python tools/slice_character_sheets.py <id> <filtro>` (en tandas cortas; MarlonX-a completo tarda >3 min → por grupos).
3. Calibrar tamaño al **estándar = tamaño de los ataques** (ancho de cabeza + alto de pie) → `scale_fix.json` / `aspect_fix.json` (en sesiones con nube se usaba `calib.py report|apply`).
4. Verificar con una tira visual (caminata + 1 frame por animación) y un gif en juego. **Nunca aceptar factores automáticos sin mirarlos.**

**Reglas técnicas (no romper):**
- Scripts nuevos **sin `class_name`** si otros los referencian → usar `const X := preload("res://...")` (si el editor no re-escaneó, el jugador queda sin script y no se mueve).
- El PC del usuario **no tiene scipy**; no depender de él.
- Procesos en segundo plano no sobreviven entre llamadas: ejecutar en tandas <180 s.
- No lanzar copias y commits/escrituras del mismo archivo en paralelo (una vez se subió un `scale_fix` viejo).
- La sesión a veces no puede borrar archivos: sobrescribir o mover a `_to_delete/`.
- Antes de cambiar calibración o el slicer: backup con fecha.

---

## 5. Estado actual (2026-10-18)

**Hecho y verificado en juego:**
- Set completo de sprites para ambos personajes: idle (animado), caminata de 8 frames a 16 fps en 5 direcciones, rodar, combos J (4 frames por golpe en guerrero; mago/chain con hoja `*8` donde existe, si no 2 poses por golpe), remates, especial/parry/ultimate (incl. hojas de 8 poses del pulido 3), contraataque, knockdown, idle_long (mira el celular), daño.
- Ataques diagonales de las 3 clases en ambas diagonales.
- Parry frontal funciona (frente bloquea, espalda no). Las 3 ultimates únicas funcionan.
- Game feel completo (hit-stop, destellos, polvo, fantasmas, squash).
- Tamaño unificado: walk/idle/ataques dentro de ±5 % (cabeza y alto), salvo `mago_ultimate8` (métrica falla, se deja).
- `roll_up_right` de ambos personajes se espeja al cargar (`MIRROR_SHEETS`) porque las hojas miran a la izquierda.

**Bosses (2026-10-16 a 18), probados con el bot en la VM; falta la prueba de Johan en el editor:**
- 8 bosses, uno por facultad, cada uno con puerta en el campus (E para entrar, Esc vuelve), sprites reales, música propia por fase y su mecánica única: 0xDEADBEEF (brazos rompibles), B.S.O.D. (ritmo cardíaco), #DIV/0! (la Bolsa), SYNTAX ERROR (La Lección), STACK OVERFLOW (La Torre), 403 FORBIDDEN (La Evidencia), MISSING TEXTURE (La Mirada), KERNEL PANIC (AL AIRE). Resumen de cada boss: `referencias_animacion/GUIA_BOSSES.md`.
- HUD del jugador nuevo (`player_hud.gd`): retrato, nombre/clase, 10 corazones, anillo de K, ultimate, combo y PARRY.
- Barra de cada jefe con la forma de su mecánica (`boss_hud.gd`, la crea `boss_arena.gd`).
- Arenas pintadas por grokbot (16: normal + `_caos` en fase 3) en `assets/sprites/arenas/`, con partículas, viñeta y luz por fase (`boss_arena_fx.gd`).
- Falta: efectos de sonido.

**Detalle histórico de rondas de pulido (resumen):** Pulido 1 (127/128 hojas), Pulido 2 (caminata 8 frames + combos 8 de espaldas con HAND RULE), corrección de color ChatGPT (COLOR_MATCH), unificación de escala, Pulido 3 (133/134; 131 aceptadas), fix "se encogen al atacar", fix proporciones diagonal, fix "mini salto" mago/chain (`MID_ALLOW`), tamaño estándar único.

---

## 6. Trabajo en curso / siguiente paso

**Pulido 4 — preparado el 2026-10-15. Verificado en disco el 2026-10-16: 0 de 23 entregadas.**
- `GROKBOT_PULIDO_4.md`: las 23 tareas siguen `[ ]` (la única `[x]` y las `[!]` del archivo están en el texto de instrucciones, no son tareas). Nada en `referencias_animacion/` es más nuevo que ese `.md`.
- En `_entregas_runway/` solo existen versiones VIEJAS con esos nombres: las 3 de A (13-10, las del pulido 3 que se quieren rehacer) y `wadrid_roll_up_right.jpg` / `marlonx_a_roll_up_right.jpg` (28-09, las que miran a la izquierda). Ninguna de B existe. Al integrar, aceptar solo archivos con fecha ≥ 2026-10-15 (grokbot sobrescribe con el mismo nombre; ojo con `.jpg` viejo + `.png` nuevo de C: borrar/mover el `.jpg` viejo para que el slicer no lo tome).
- 2026-10-16 04:35: **ENTREGADAS 23/23** (`[x]` en el .md, archivos en `_entregas_runway/` con fecha 15-10 03:43–04:20). Siguiente: revisión visual → recortar → calibrar → gif. Progreso de la integración abajo en esta misma sección.
- Integración, paso 1 (revisión visual) HECHO 16-10: **21 aceptadas, 2 rechazadas** → movidas a `_rechazadas/` como `_r1` y reabiertas `[ ]` en `GROKBOT_PULIDO_4.md` con la razón: `wadrid_chain_whip8_up_right` (pelo no afro, borrosa, estela en el cable) y `marlonx_a_mago_cast8_down_right` (gafas como antifaz negro, bastón cambia de mano). Notas: en vistas de frente el arma sale en el lado derecho de la imagen igual que en las hojas viejas ya aceptadas (convención existente, OK). MarlonX-a lleva la placa dorada también en la espalda en whip8_up y roll (menor, aceptado). Los `roll_up_right.jpg` viejos siguen en `_entregas_runway/` pero el slicer prioriza `.png`.
- Backups antes de tocar nada: `Claude outputs/characters_anim_backup_2026-10-16.tgz` (todos los frames), `tools/scale_fix_backup_2026-10-16.json`, `tools/aspect_fix_backup_2026-10-16.json`, `Claude outputs/character_sprites_backup_2026-10-16.gd`.
- Paso 2 (recortar) HECHO: las 21 recortadas por filtro (≈20 s por tanda).
- Paso 3 (calibrar) HECHO: nuevo `tools/measure_p4.py <id> <anim...>` (alto de pie + ancho de cabeza; para hojas de 8 medir poses 1 y 8). Referencia de cabeza = caminata de la misma dirección; alto = 88. Ojo: en `render_pose` el alto total escala LINEAL con `aspect` (la cabeza se conserva, el cuerpo absorbe). Corregidas 6 hojas (scale/aspect): wadrid mago_cast8 up/right/down_right y marlonx_a chain_whip8 down/right (salieron cabezonas → scale ~0.90–0.95, aspect ~1.05–1.09), marlonx_a guerrero_counter8_down_right (cabeza chica → 1.048 / 0.954). Las demás ya entraban en ±5 %. Rodar arriba-derecha: tamaño similar a rodar arriba, sin cambios.
- Paso 4 (tira visual + gif) HECHO: `Claude outputs/p4_tira_wadrid.png`, `p4_tira_marlonx.png`, `pulido4_animaciones.gif` (frames animados; esta VM no tiene Godot, así que NO es captura en juego: falta que el usuario lo pruebe en el editor). En la tira se rechazó una 3.ª hoja: `marlonx_a_chain_whip8_down_right` (cable demasiado fino, desaparece al reducir; probado con menos erosión y no basta) → `_rechazadas/..._r1.png`, sus frames movidos a `Claude outputs/_to_delete/marlonx_a/`, reabierta en el .md de grokbot.
- `MIRROR_SHEETS` NO existe en el código del PC (ni en `character_sprites.gd` ni en el slicer): no hay nada que quitar. Las hojas nuevas de `roll_up_right` ya miran a la derecha y nada las espeja → correcto.
- **Resultado Pulido 4: 20/23 integradas.** Pendientes 3 (reabiertas `[ ]` en `GROKBOT_PULIDO_4.md`): `wadrid_chain_whip8_up_right`, `marlonx_a_mago_cast8_down_right`, `marlonx_a_chain_whip8_down_right`. Mientras tanto esas direcciones usan la hoja vieja de 4 poses (fallback automático).
- 16-10: añadidas reglas "(retry)" a los prompts de las 3 rechazadas en `PROMPTS_PULIDO_4.md` (backup `PROMPTS_PULIDO_4_backup_2026-10-16.md`); el usuario va a relanzar grokbot solo con esas 3.
- 16-10: el usuario reporta que al caminar hacia ARRIBA los pies se ven virados (las hojas `walk8_up` de ambos muestran los pies girados a los lados). Añadida sección D en `PROMPTS_PULIDO_4.md` (prompt del pulido 2 + FEET RULE) y 2 tareas `[ ]` en `GROKBOT_PULIDO_4.md`. Las viejas están copiadas en `_rechazadas/*_walk8_up_r1.png`. Al integrar: `slice_character_sheets.py <id> walk8` y revisar alto/cabeza con `measure_p4.py <id> walk walk8`.
- 16-10 05:40: grokbot rehízo las 5 (3 rechazadas + 2 `walk8_up` con FEET RULE). Revisadas: las 5 correctas (cable grueso, afro, gafas con ojos, pies hacia arriba). Recortadas; tamaño dentro de ±5 % sin tocar calibración (walk8_up conserva sus factores viejos 0.96/1.03 y da 88 px). Verificación: `Claude outputs/p4_tira_v2.png`, `pulido4_v2_animaciones.gif`.
- 16-10 06:05: el usuario vio en el gif que en `walk8_up` los pies parecían avanzar hacia ABAJO. Arreglo: ciclo invertido con `POSE_ORDER` en el slicer (solo `marlonx_a_walk8_up` = [0,7,6,5,4,3,2,1]; el usuario aclaró que Wadrid estaba bien, se dejó en orden normal; backup `tools/slice_character_sheets_backup_2026-10-16b.py`), re-recortado `walk8`. Frames anteriores en `Claude outputs/_review_p4/walk_old/`. Comparación: `Claude outputs/caminata_arriba_antes_ahora.gif`. Pendiente que el usuario confirme.
- 16-10 06:10: invertir el orden NO arregló a Marlon (revertido, el slicer vuelve a orden normal). Causa real (`Claude outputs/_review_p4/pies_comparar.png`): en `marlonx_a_walk8_up` el pie levantado está MÁS ABAJO y es más grande que el apoyado (bola negra) → parece que camina hacia la cámara; en Wadrid el pie levantado queda más arriba y chico, enseñando el talón. Hoja copiada a `_rechazadas/marlonx_a_walk8_up_r2.png`, reabierta en GROKBOT con Imagen 3 = `wadrid_walk8_up.png` + LIFTED FOOT RULE. Mientras tanto queda la hoja r2 (orden normal) en el juego.
- 16-10 06:30: `marlonx_a_walk8_up` rehecha (retry 2, Imagen 3 = Wadrid): pie levantado arriba y chico, correcto. Integrada (orden normal), alto 88. Gif: `Claude outputs/caminata_arriba_marlon_v3.gif`. Pendiente confirmación del usuario.
- **PULIDO 4 COMPLETO: 23/23 integradas + caminata hacia arriba corregida.**
- SIGUIENTE: el usuario prueba en el editor (Godot reimporta los PNG nuevos al abrir) y da feedback. Después: siguientes pasos generales (abajo).
- 2026-10-16: el usuario ELIGIÓ hacer el Pulido 4 (opción 1). Siguiente paso: el usuario lanza a grokbot con `GROKBOT_PULIDO_4.md`; cuando avise, Claude cuenta las `[x]`, revisa las hojas nuevas (fecha ≥ 2026-10-16) e integra según la receta de la sección 4.
- 23 hojas: A = 2 rechazadas + 1 `[!]` del pulido 3 (`marlonx_a_guerrero_counter8_down_right`, `wadrid_guerrero_ultimate8_up_right` con ERASER RULE, `wadrid_chain_counter8_up` sin líneas de movimiento); B = 18 combos `<base>8_<dir>` que faltan (mago/chain de pie sin saltar + wadrid guerrero up/up_right), con regla de MISMAS PROPORCIONES que la Imagen 2; C = `roll_up_right` ×2 lanzándose a la DERECHA (2x2, 3:4).
- Al integrar: revisar → recortar → calibrar al tamaño estándar → verificar con gif → **quitar `roll_up_right` de `MIRROR_SHEETS`** si las nuevas están bien → actualizar este documento.

**Bosses — planificado el 2026-10-16 (hilo aparte del Pulido 4; NO toca hojas ni sprites del Pulido 4).**
- Hoy no existe nada de bosses: el único enemigo es `dummy_enemy.gd` (no se mueve, HP regenera, 1 ataque). Falta: IA con movimiento/estados, muerte de enemigos, patrones de ataque, barra de vida de boss, fases, arena/disparador, sprites propios.
- Plan propuesto: (1) boss de prueba solo en código, escena nueva `scenes/combat/boss_test.tscn` + `scripts/combat/boss.gd` (sin `class_name`, preload), reutiliza `take_hit`/parry/rodar/game feel y el sprite de un jugable escalado; 3 ataques (tajo frontal parryable, embestida que se esquiva rodando, golpe en área no parryable), aturdido tras parry, 2 fases (50 % HP), barra de vida arriba, victoria/derrota. (2) Diseño de bosses reales temáticos del campus con el usuario. (3) Sprites por grokbot cuando termine el Pulido 4. (4) Arenas por facultad.
- Estado: esperando que el usuario diga si arranca el paso 1.
- 16-10: el usuario mandó referencia del primer boss (`referencias_animacion/bosses/cosechadora_referencia.jpg`): máquina-monstruo de la facultad agro/alimentos/ambiental/biología/software/TI. Diseño propuesto "Cosechadora.EXE" en un Claude Doc: https://claude.ai/code/artifact/b298b2a5-70f0-4681-977e-03a9bae51608 (una sola vista 3/4, animación por piezas en código, monitor = cara, 8 ataques por carrera, 3 fases, tanque = punto débil tras parry, aparición ensamblándose, muerte desarmándose). Esperando aprobación del usuario (nombre, facultad, vista única).
- 16-10 06:35: el usuario APROBÓ el plan. Nombre del boss: **0xDEADBEEF** (pidió nombre raro de error informático; cráneo de toro = "dead beef"). Facultad: **Facultad de Ciencias de la Vida y Tecnología**. Creados `referencias_animacion/GROKBOT_BOSS_1.md` + `PROMPTS_BOSS_1.md` (10 hojas: A boss completo primero, B 5 piezas sueltas que usan A como Imagen 2, C animales/esbirro/proyectiles/pedazos; generador `tools/gen_prompts_boss1.py`). Entregas en `_entregas_runway/bosses/`. Monitor sin texto: caras y textos por código. SIGUIENTE: boss de prueba en código con figuras simples (escena aparte `scenes/combat/boss_test.tscn`), en paralelo con grokbot.
- 16-10 06:55: **BOSS DE PRUEBA HECHO** (figuras dibujadas por código). Abrir `scenes/combat/boss_test.tscn` y F6. Archivos nuevos: `scripts/combat/boss_deadbeef.gd` (boss: estados, 8 ataques `_atk_*`, 3 fases al 60/30 %, aturdido + tanque x2 tras parry o choque contra pared, intro armándose, muerte; piezas en clase `Part` → cambiar por Sprite2D cuando lleguen las hojas), `boss_fx.gd` (cajas, gas, charcos, raíces, cable, animales, láser, flores), `boss_minion.gd` (planta mutante), `boss_arena.gd` (arena, HUD barra, presentación, victoria/derrota, F2 saltar fase, R reintentar). Cambios en compartidos (backups en `Claude outputs/*_backup_2026-10-16.gd`): `player.take_hit(amount, from, unblockable=false)`; `GameFeel.dust` ahora sí pone el polvo en `at` (antes aparecía en el origen del mapa). Probado en una VM con Godot 4.6.2 + bot que juega la pelea completa sin errores; gif `Claude outputs/boss_prueba.gif`. Pendiente: que el usuario lo pruebe y ajuste números.
- 16-10 07:15: grokbot entregó las 10 hojas (`[x]` en GROKBOT_BOSS_1.md); revisadas, **10/10 aceptadas**. Recortadas con `tools/slice_boss_sheets.py` (numpy+PIL, parte por bandas vacías, quita fondo menta, reduce al tamaño del juego) → `assets/sprites/bosses/deadbeef/*.png` (48 piezas). Nuevo `scripts/combat/boss_sprites.gd` (carga y pivotes). Las piezas `Part` usan los sprites si existen (si no, vuelven a las figuras): body_0/1 (orugas incluidas), tank_0/1/2, head_0/1/2 (cráneo+monitor juntos; la cara se dibuja encima en `SCREEN_OFF`), claw/grabber con giro desde el hombro. Animales, planta, cajas/frutas, charco, raíces, pedazos y flores también con sprite. Verificado con el bot: `Claude outputs/boss_sprites.gif`. Pendiente: prueba del usuario.
- 16-10 08:20: **PASADA DE ROBUSTEZ** (el usuario sentía al boss incompleto y con el cuerpo "un solo tubo"). Sprite más fiel a la referencia: torso (hombreras, tubos de ensayo, rack, cables) sacado de `full_0` con `tools/make_boss_torso.py` → `torso_0/1.png`, se dibuja en `TORSO_POS`; brazos re-recortados más grandes (claw/grabber h166, reposo `claw_1` abierto hacia fuera); ojos rojos siempre. Jugabilidad: cuerpo sólido (capa 1+2; lo atraviesa solo en la embestida) y orden de dibujo según dónde esté el jugador; posturas de anticipación por ataque (`_pose`), zonas rojas de aviso en el piso (`TeleZone`), impactos con temblor; ataque nuevo `stomp` (onda `ShockRing`) si el jugador se queda pegado; combos por fase (`COMBOS`); tambaleo al acumular daño (`POISE` 8/11/14); OVERCLOCK al 12 % (más rápido, brilla rojo); números de daño y chispas en el blindaje; cartel grande sobre la cabeza con el texto del monitor (`Holo`); muerte con cámara lenta, explosiones en cadena y cráneo que cae; barra con "chip" y marcas de fase; victoria con rango/tiempo/golpes. MAX_HP 80. Backup de la versión anterior en `Claude outputs/boss_v1_backup/`. Verificado con el bot (sin errores): `Claude outputs/boss_robusto.gif`. Pendiente: prueba del usuario y sonido.
- 16-10 13:55: **BOSS JUGABLE DESDE EL JUEGO**: en el campus (`main.tscn`) hay una puerta "Fac. Ciencias de la Vida y Tecnología" al final del camino de arriba (clase `BossDoor` en `campus.gd`): acercarse y pulsar E → fundido → arena del boss con aparición completa. Esc en la arena vuelve al campus (nuevo `player.exit_scene`, por defecto el creador; la arena lo cambia a `main.tscn`). Backups en `Claude outputs/boss_puerta_backup/`. Probado en la VM: campus → E → BossTest → Esc → Campus.
- 16-10 14:10: **pulido de animaciones** (solo `boss_deadbeef.gd`): movimiento secundario por pieza (`Part.anim_off/anim_rot`, respiración desfasada, brazos se mecen), retroceso de cabeza al recibir golpes, inclinación (skew) al avanzar, garra se cierra (`claw_2`, `fist`) al impactar, burbujas en el tanque, vapor de los tubos desde fase 2, chispas en fase 3, interferencias en el monitor (`glitch`). Verificado con el bot: `Claude outputs/boss_animado.gif`. También se copiaron los `.import` del boss (Godot no los había importado y salían las figuras viejas).
- 16-10 14:30: **Boss 2 propuesto** para la Facultad de Ciencias de la Salud (Enfermería, Fisioterapia, Laboratorio Clínico, Medicina, Nutrición y Dietética, Odontología, Psicología, Terapia Ocupacional). Johan pidió que cada boss tenga "algo" único. Diseño en Claude Doc: https://claude.ai/code/artifact/af1330c1-50d1-45a8-9e11-805d2cccb65f (nombre propuesto B.S.O.D., robot cirujano; lo único = ritmo cardíaco: ataca en el latido, punto débil entre latidos, parry en el latido = arritmia). Esperando OK de Johan en nombre, mecánica única y la idea de romper brazos al boss 1.
- 16-10 14:35: Johan APROBÓ el boss 2 **B.S.O.D.** (nombre, ritmo cardíaco) y romper brazos al boss 1 (pendiente de programar). Creados `referencias_animacion/GROKBOT_BOSS_2.md` + `PROMPTS_BOSS_2.md` (10 hojas `boss_bsod_*.png`; A sin referencia de diseño, revisar con Johan antes de B/C; generador `tools/gen_prompts_boss2.py`). SIGUIENTE: boss 2 de prueba con figuras en paralelo.
- 16-10 15:58: **B.S.O.D. jugable con figuras de código** (`scripts/combat/boss_bsod.gd` + `boss_bsod_fx.gd`): intro código azul, 3 fases 60/90/140 BPM, 9 ataques + desfibrilación, HUD de ECG, muerte con pantalla azul. `boss_arena.gd` generalizado (`static var boss_kind`, dict `BOSSES`; un boss con `build_hud()` reemplaza la barra). 2ª puerta azul en el campus (300,-262) que pone `boss_kind = "bsod"`. `player.gd`: `speed_mult` (la jeringa ralentiza). Boss 1: **brazos rompibles** (12 PV c/u, golpes de costado; sin brazo pierde sus ataques, cae el brazo con chispas). Probado con bot en Godot 4.6.2 sin errores. Respaldo en `Claude outputs/boss2_backup/`. Grokbot entregó la hoja A `boss_bsod_full.png` (revisada, muy fiel); jeringa sale con líquido rojo → prompt de la hoja tool cambiado a rojo. SIGUIENTE: OK de Johan a la hoja A → hojas B y C → recortar e integrar sprites.
- 16-10 16:35: **Sprites del B.S.O.D. integrados.** Las 9 hojas B/C de grokbot revisadas (todas bien; la jeringa del brazo salió azul y se dejó así). `tools/slice_boss_sheets.py` ahora corta por boss (`python tools/slice_boss_sheets.py bsod` → `assets/sprites/bosses/bsod/`, más variantes `boss_bsod_syringe_blue` y `boss_bsod_puddle_grey`). `boss_bsod.gd` dibuja cuerpo, corazón (3 estados), cabeza (3 estados, ECG/caras sobre la pantalla) y brazos con sprites (`Spr.lean` endereza los brazos); hombros/corazón/cabeza recalculados sobre `boss_bsod_body_0`. Proyectiles, bloques, pelota, comida, bacteria y pedazos usan sprites (`BossFx.Debris.prefix`). Probado con bot sin errores. Respaldo en `Claude outputs/bsod_sprites_backup/`, gif en `Claude outputs/bsod_sprites.gif`. Pendiente: sonido; los clones de tinta siguen dibujados por código (a propósito).
- 16-10 17:15: **Boss 3 propuesto** para la Facultad de Ciencias Administrativas, Contables y Comercio: **#DIV/0!** (ejecutivo-bóveda, monitor de hoja de cálculo, 4 patas de archivador, sello y calculadora). Lo único = la Bolsa: precio de acción en el HUD; tus golpes lo bajan, bajo la línea roja = QUIEBRA (bóveda abierta, doble daño), arriba = BURBUJA (más agresivo). Doc: https://claude.ai/code/artifact/5f8c0327-f173-4fb8-8efe-c76c93517939 . Aprobado por Johan ("lo veo correcto, continua").
- 16-10 17:45: **Boss 3 #DIV/0! de prueba jugable** (figuras por código) por la **tercera puerta dorada** del campus (-300,-262). Archivos nuevos: scripts/combat/boss_div0.gd y boss_div0_fx.gd; tocados boss_arena.gd (entrada "div0", piso "bolsa"), campus.gd (puerta 3) y boss_sprites.gd (carpeta bosses/div0/). Respaldo en Claude outputs/div0_backup/, gif en Claude outputs/div0_prueba.gif. Prompts de grokbot en referencias_animacion/GROKBOT_BOSS_3.md y PROMPTS_BOSS_3.md. Siguiente: Johan prueba en el editor; cuando grokbot entregue boss_div0_full.png revisarla con Johan antes de B y C; luego recortar (agregar set "div0" al slicer) e integrar.
- 16-10 18:25: **Sprites de #DIV/0! integrados** (hojas B y C de grokbot revisadas, todas usables). `python tools/slice_boss_sheets.py div0` → assets/sprites/bosses/div0/ (la mancha del sello se pasa a tinta morada: boss_div0_ink.png). El código ajusta el megáfono y el cañón, que en el sprite apuntan de lado. Probado con el bot sin errores. Respaldo en Claude outputs/div0_sprites_backup/, gif en Claude outputs/div0_sprites.gif. Recargar el proyecto en Godot. Falta: prueba de Johan en el editor y sonido.
- 16-10 19:05: **Boss 4 SYNTAX ERROR de prueba jugable** (Facultad de Educación, Turismo y Humanidades; figuras por código) por la **cuarta puerta verde, abajo** del campus (-300,290), porque arriba ya no hay lugar. Diseño: https://claude.ai/code/artifact/000be033-2dfe-4815-8127-624a20758492 . Archivos nuevos: scripts/combat/boss_syntax.gd y boss_syntax_fx.gd; tocados boss_arena.gd (entrada "syntax", piso "aula"), campus.gd (puerta 4) y boss_sprites.gd (carpeta bosses/syntax/). Respaldo en Claude outputs/syntax_backup/, gif en Claude outputs/syntax_prueba.gif. Prompts en referencias_animacion/GROKBOT_BOSS_4.md (generados con tools/gen_prompts_boss4.py). Hoja A boss_syntax_full.png entregada 18:45 y aprobada; grokbot está haciendo B y C. Siguiente: recortar (set "syntax" en el slicer) e integrar. Después vienen los bosses 5-8.
- 16-10 20:25: **Boss 5 STACK OVERFLOW de prueba jugable** (Facultad de Ingeniería, Industria y Arquitectura; figuras por código) por la **quinta puerta naranja, abajo a la derecha** del campus (300,290). Diseño: https://claude.ai/code/artifact/c6fba194-8436-47ab-ae6c-c0227d20ae9d . Archivos nuevos: scripts/combat/boss_stack.gd y boss_stack_fx.gd; tocados boss_arena.gd (entrada "stack", piso "obra"), campus.gd (puerta 5) y boss_sprites.gd (carpeta bosses/stack/). Respaldo en Claude outputs/stack_backup/, gif en Claude outputs/stack_prueba.gif. Prompts en referencias_animacion/GROKBOT_BOSS_5.md (tools/gen_prompts_boss5.py); la tarea se mandó a Godot Forge 20:09 (hoja A primero). Desde 20:16 Johan pide que Claude NO use Grok Bot (le corta la música): dejarle el prompt en el hilo y avisarle al teléfono. Siguiente: cuando lleguen las hojas, recortar (set "stack" en el slicer) e integrar. Después, bosses 6-8.
- 16-10 ~21:10: **Boss 5 con sprites reales**: las 10 hojas de Godot Forge recortadas con `python tools/slice_boss_sheets.py stack` (set nuevo SHEETS_STACK + `stack_variants`, que saca la bola y el ancla sueltas de la punta de la grúa) en assets/sprites/bosses/stack/. boss_stack.gd dibuja cuerpo (con orugas), motor, casco con visor, grúa y martillo desde los sprites; boss_stack_fx.gd usa torre (viga, bloque, contenedor, cimiento entero/agrietado/roto; FLOOR_H 34), latas, engranajes, postes, bola, ancla, drones y escombros. Respaldo de los .gd anteriores en Claude outputs/stack_backup/; gif en Claude outputs/stack_sprites.gif. Godot necesita reabrir el proyecto para importar los PNG nuevos.
- 16-10 20:40: **Boss 6 403 FORBIDDEN de prueba jugable** (Facultad de Ciencias Sociales, Derecho y Bienestar; figuras por código) por la **sexta puerta roja, abajo al centro** del campus (0,290). Diseño: https://claude.ai/code/artifact/b13b51de-e149-4c34-adfd-b43a3cf5561e . Archivos nuevos: scripts/combat/boss_judge.gd y boss_judge_fx.gd; tocados boss_arena.gd (entrada "judge", piso "juzgado"), campus.gd (puerta 6) y boss_sprites.gd (carpeta bosses/judge/). Respaldo en Claude outputs/judge_backup/, gif en Claude outputs/judge_prueba.gif. Prompts en referencias_animacion/GROKBOT_BOSS_6.md y PROMPTS_BOSS_6.md (tools/gen_prompts_boss6.py, prefijo boss_judge_); Johan los pega él en Godot Forge. Siguiente: recortar e integrar esas hojas; luego bosses 7 (Artes/Humanidades/Patrimonio) y 8 (Unidad Técnicas y Tecnológicas).
- 16-10 ~23:25: **Boss 6 con sprites reales**: Johan mandó las 10 hojas a Godot Forge (llegaron 22:51-23:01, todas bien). Recortadas con `python tools/slice_boss_sheets.py judge` (set nuevo SHEETS_JUDGE) en assets/sprites/bosses/judge/. boss_judge.gd dibuja cuerpo (estrado + toga en una sola imagen; body_1 = dañado), núcleo/cerradura (cerrado, abierto, roto), monitor con peluca (normal, torcida, agrietado; sin peluca = solo el monitor recortado) con la pantalla dibujada por código encima, mazo (entero/roto) y mano (balanza, micrófono, lupa). boss_judge_fx.gd usa pruebas, sello, libro, misil, bandera blanca, escáner, carpetas esbirro (4 cuadros de caminar) y escombros. Probado con el bot. Respaldo en Claude outputs/judge_sprites_backup/; gif en Claude outputs/judge_sprites.gif. Siguiente: bosses 7 y 8.
- 16-10 ~23:50: **Boss 7 MISSING TEXTURE de prueba jugable** (Facultad de Artes, Humanidades y Patrimonio; figuras por código) por la **séptima puerta magenta, en la pared izquierda** del campus (-410,10). Estatua de mármol del museo sobre su pedestal, con cuadriculado magenta/negro de textura faltante puesto por shader. Diseño: https://claude.ai/code/artifact/367bb970-b79f-4951-86b9-4bfb3813d0a3 . Archivos nuevos: scripts/combat/boss_tex.gd y boss_tex_fx.gd; tocados boss_arena.gd (entrada "tex", piso "museo"), campus.gd (puerta 7) y boss_sprites.gd (carpeta bosses/tex/). Respaldo en Claude outputs/tex_backup/, gif en Claude outputs/tex_prueba.gif. Prompts en referencias_animacion/GROKBOT_BOSS_7.md y PROMPTS_BOSS_7.md (tools/gen_prompts_boss7.py, prefijo boss_tex_); Johan los pega en Godot Forge. Siguiente: recortar e integrar esas hojas (set nuevo "tex" en el slicer); luego boss 8 (Unidad Técnicas y Tecnológicas).
- 17-10 ~01:10: **Boss 7 con sprites reales**: Johan mandó las 10 hojas a Godot Forge (todas bien). Recortadas con `python tools/slice_boss_sheets.py tex` (set nuevo SHEETS_TEX; debris y maniquí se separan por manchas y se ordenan por fila con ROWS2) en assets/sprites/bosses/tex/. boss_tex.gd dibuja estatua+pedestal en una imagen (body_1 = agrietado), marco del pecho (tapado, cuadro, roto), cabeza con aureola (normal, agrietada, media cara rota) y brazos con hombro medido a mano (ARM_PIVOT): pincel/aguja/paleta de arqueólogo y paleta/máscaras/mano. El cuadriculado magenta y la piedra los sigue poniendo el shader del rig. boss_tex_fx.gd usa máscaras, aguja, vasija rota, hueso, sitio de excavación/hoyo, nudo de hilo, maniquí (8 cuadros) y escombros. Probado con el bot. Respaldo en Claude outputs/tex_sprites_backup/; gif en Claude outputs/tex_sprites.gif. Godot necesita reabrir el proyecto para importar los PNG. Siguiente: boss 8.
- 17-10 ~01:25: **Boss 8 KERNEL PANIC de prueba jugable** (Unidad de Formación Técnicas y Tecnológicas; figuras por código) por la **octava puerta naranja, en la pared derecha** del campus (410,10). Robot chef presentador de TV: cabeza de microondas con pantalla, gorro de chef, carrito de cocina, brazo sartén y brazo micrófono. Diseño: https://claude.ai/code/artifact/005ed015-f9c9-4542-9a6c-1ea32c304b9e . Archivos nuevos: scripts/combat/boss_kp.gd y boss_kp_fx.gd; tocados boss_arena.gd (entrada "kp", piso "estudio"), campus.gd (puerta 8) y boss_sprites.gd (carpeta bosses/kp/). Respaldo en Claude outputs/boss8_backup/, gif en Claude outputs/kp_test.gif. Prompts en referencias_animacion/GROKBOT_BOSS_8.md y PROMPTS_BOSS_8.md (tools/gen_prompts_boss8.py, prefijo boss_kp_); Johan los pega en Godot Forge. Siguiente: recortar e integrar esas hojas (set nuevo "kp" en el slicer). Con esto hay un boss por cada una de las 8 facultades.
- 17-10 ~02:00: **Boss 8 con sprites reales**: Johan mandó las 10 hojas a Godot Forge (todas bien). Recortadas con `python tools/slice_boss_sheets.py kp` (set nuevo SHEETS_KP; paparazzi y debris por manchas con ROWS2) en assets/sprites/bosses/kp/. boss_kp.gd dibuja carrito+torso en una imagen (body_1 = quemado), panel del pecho (cerrado, horno abierto, roto), cabeza de microondas con gorro (normal, abollada, rota; sin gorro en la furia se recorta la imagen arriba del microondas) y la cara se sigue dibujando por código en la pantalla. Brazos: sartén/cuchillo/cucharón y micrófono/claqueta/mano (la cámara de mano de la furia va en la mano). boss_kp_fx.gd usa cámaras (en vivo, apagada, rota), pierna en llamas, fuego, cuchillo, grano, palomita, flash, rollo de alfombra, postes con cordón, paparazzi (8 cuadros) y escombros. Probado con el bot. Respaldo en Claude outputs/kp_sprites_backup/; gif en Claude outputs/kp_sprites.gif. Godot necesita reabrir el proyecto para importar los PNG. Siguiente: que Johan pruebe los 8 bosses en el editor.
- 17-10 ~03:35: **Música de jefe**: tema original estilo SNES/Mega Man X (rock en Mi menor, 160 BPM; lead de pulso con vibrato, guitarra distorsionada, bajo en octavas, batería y eco tipo SNES). Lo genera `python tools/boss_theme.py assets/audio/boss_theme.wav` (numpy) y se convierte a assets/audio/boss_theme.ogg con ffmpeg. 51 s: intro de 3 s y loop desde ahí (A, A', B, puente). boss_arena.gd lo toca en todos los bosses al empezar la pelea (-6 dB, MUSIC_LOOP_FROM 3.0) y lo baja al ganar o perder. Respaldo en Claude outputs/music_backup/. Aún no hay efectos de sonido.
- 17-10 ~04:30: **Arreglo**: Johan no oía la música y los bosses 5-8 salían con figuras de código. Causa: Godot nunca importó esos archivos en el PC (faltaban los .ctex de stack, judge, tex y kp en .godot/imported, y la música ni tenía .import). Se copiaron los importados de la VM (mismos .import y PNG, md5 verificados) con Claude outputs/imports_fix.tgz. Regla: al entregar imágenes o audio nuevos, mandar también sus archivos de .godot/imported.
- 17-10 ~05:20: **Música propia por boss** (reemplaza el tema único; boss_theme.ogg ya no se usa): `python tools/boss_music.py <carpeta>` genera por boss 3 loops (_p1 con intro de 2 compases, _p2 con segunda voz y arpegios, _p3 más rápida y con todo) + _win al vencerlo, y lose al perder; van en assets/audio/bosses/ como .ogg. Estilos: 0xDEADBEEF rock en Mi frigio con bips hex y tartamudeo; B.S.O.D. sintetizador frío en Si menor con la batería como latido y bip de monitor (120/135/140 BPM); #DIV/0! funk con metales, swing y teletipo; SYNTAX ERROR marcha escolar con clavecín y timbre; STACK OVERFLOW metal industrial con yunques y arpegio que se apila; 403 FORBIDDEN órgano barroco con timbales y martillo; MISSING TEXTURE vals de caja de música que se traba; KERNEL PANIC funk de concurso de TV con aplausos y estática. boss_arena.gd cambia de loop con fundido al cambiar de fase y toca el cierre al ganar o perder (MUSIC_INTRO = segundos de intro por boss). Probado con el bot (tex y judge: p1→p2→p3→win). Copias para escuchar en Claude outputs/musica_bosses/.

- 18-10 ~03:45: **HUD y barras de jefe nuevos**: `scripts/combat/player_hud.gd` (retrato recortado del idle_down, nombre y clase, 10 corazones que se rompen y laten con poca vida, anillo de enfriamiento de K, barra de ultimate que brilla al estar lista, pasos del combo, aviso PARRY); `player.gd` solo lo crea. `scripts/combat/boss_hud.gd`: clase Base (marco, nombre con glitch al recibir daño, rombos de fase, barra con chip, temblor, llenado inicial, franjas doradas en x2) + una subclase por boss con su mecánica (volcado de memoria y brazos, monitor ECG que pasa a pantalla azul, velas de la bolsa, pizarra con lección y nota, plano con 8 pisos, expediente con pruebas/sello/balanza, barra de textura magenta con ojo y petrificación, rótulo de TV con cámaras y barras de color). `boss_arena.gd` la crea con `BossHud.make(kind, boss)` y ya NO llama a `build_hud` de los bosses (sus paneles viejos quedan sin uso en sus .gd). Backups: `tools/boss_arena_backup_2026-10-18.gd.txt`, `tools/player_backup_2026-10-18.gd.txt`. Probado con el bot: 8 peleas completas sin errores.
- 18-10 ~04:05: **Arenas pintadas integradas**: `scripts/combat/boss_arena_fx.gd` (Backdrop: dibuja `assets/sprites/arenas/arena_<boss>.png` y en fase 3 funde a `arena_<boss>_caos.png`; FLOOR_FRAC = rectángulo del piso dentro de cada imagen, ajustado a ojo por boss; Motes: partículas por boss que aumentan por fase; Vignette: viñeta de color que late en fase 3; además tinte de luz por fase con el CanvasModulate). Si falta la imagen, se usa el piso por código de antes. Prompts: `referencias_animacion/GROKBOT_ARENAS.md` + `PROMPTS_ARENAS.md` (16 imágenes, todas OK al primer intento). Entregadas con sus `.import` y `.godot/imported` (`tools/arenas_1..4.tgz`), 0 imports faltantes. Nota: en el juzgado las bancas laterales quedan dentro del área jugable (solo dibujo). SIGUIENTE: Johan prueba en el editor y da feedback; luego efectos de sonido.

**Siguientes pasos generales (después del Pulido 4):**
1. Ajustar números a gusto del usuario: cooldowns, daño, ventana/cono del parry, duración de ultimates, frecuencia de ataque del dummy.
2. Enemigos reales (IA, varios tipos) en lugar del dummy; efectos de sonido.
3. Mapa del campus / facultades como mazmorras.

---

## 7. Bitácora

### 2026-10-19 (4) — Técnicas de los bosses + nuevo menú del personaje
- **Técnicas** (`scripts/combat/techniques.gd`): cada boss vencido da UNA técnica en una ranura fija, válida para las 3 clases (cada clase la hace con sus animaciones). Combo: Parásito (0xDEADBEEF, el remate cura 1) e Interés compuesto (#DIV/0!, +1/+2 de daño acumulando golpes; se pierde al recibir daño o 2 s sin pegar). Especial: Objeción (403, postura de bloqueo 1 s que responde con 3 de daño en cono), Tiza roja (SYNTAX, marca: ×2 de daño 5 s), Glitch (MISSING TEXTURE, teletransporte detrás del objetivo fijado + copia que explota). Ultimate: Desfibrilador (B.S.O.D., 3 de daño en área + cura 2), Push/Pop (STACK, 3 bloques de 2 + uno de 4), Corte comercial (KERNEL PANIC, 3 s sin recibir daño y luego 3 de daño a todo lo que esté en pantalla). Objeción y Corte comercial NO borran proyectiles a propósito: varios bosses esperan a que sus peligros terminen (p. ej. los sellos del juez).
- Lógica en `class_controller.gd` (`tech`, `_tech_*`, marcas, interés; los orbes del mago pasan por `projectile_hit`). `player.gd`: `heal()`, `shield()`, y anima las técnicas con la hoja propia si existe (`<clase>_tech_<id>` o `tech_<id>`) o con la de la clase (`Techniques.FALLBACK_ANIM`).
- Guardado: `GameState.loadout` (por clase y ranura) en `user://progress.cfg`; `equipped()` devuelve "" (de serie) si la técnica aún no está conseguida. Al ganar, la pantalla final avisa "¡NUEVA TÉCNICA!".
- **Menú del personaje** (`scripts/ui/character_menu.gd`, ahora es `scenes/character_creator.tscn`; el creador viejo quedó en `character_creator_old.tscn`): retrato grande bajo un foco del color de la clase, nombre, personaje, 3 tarjetas de clase y las 3 ranuras con QUÉ HACE / PARA QUÉ SIRVE; las bloqueadas se ven con el boss que las da. Teclado/mando: ↑↓ ←→, Enter/Start confirma, Esc vuelve. Se abre también desde el **casillero** de la entrada del Salón (vuelve al salón).
- Retrato detallado: si existe `assets/sprites/portraits/<personaje>_<clase>.png` se usa ese (se generan con `tools/process_portraits.py` desde `_entregas_runway/portrait_*.png`); si no, el sprite del juego ×4.
- **Grok**: `referencias_animacion/GROKBOT_TECNICAS.md` + `PROMPTS_TECNICAS.md` (generados por `tools/gen_prompts_tecnicas.py`): 6 retratos y 18 hojas de 8 poses de las 3 ultimates (manos vacías, sirven a las 3 clases; `slice_character_sheets.py` ya conoce `tech_*8`).
- Arreglo: salir de la arena con Esc en plena lluvia de cambio de fase daba error (`boss_barrage._alive` con el boss ya liberado).
- Pruebas: `ztest/tech_test.gd` (8 técnicas × 3 clases), `menu_test.gd`, `hall_test.gd` (casillero). Video: `Claude outputs/tecnicas_demo.mp4`.

### 2026-10-19 (3) — Repositorio en GitHub: https://github.com/Johan2418/Juego-Uleam
- Rama `main`. Primer commit = estado del PC del 19/10 (sin `Claude outputs/`, `_backups/`, `_incoming/`, `.godot/`, `.tgz`, `.bak`/`_backup_` ni las imágenes de `referencias_animacion/`; ver `.gitignore`). Los `*.import` SÍ se suben.
- **Regla de trabajo (pedida por el usuario): después de cada cambio que se despliega al PC, hacer un commit y push al repo** con un mensaje en español que describa el cambio. La carpeta del PC NO es un repo git (el puente no deja borrar archivos y git los necesita), así que el commit se hace desde la nube: clonar el repo (`git clone --depth 1`), copiar ahí los mismos archivos que se despliegan al PC (incluido `CONTEXTO_PROYECTO.md`), commit y push. Autor: Johan2418 <Johan2418@users.noreply.github.com>.

### 2026-10-19 (2) — Salón de las Facultades (entrada a los bosses, estilo Salón de los Dioses)
- El campus ya no tiene 8 puertas: hay UNA puerta grande "SALÓN DE LAS FACULTADES" arriba (`campus.gd` → `HallDoor`; 8 rombos que se doran según los bosses vencidos). La clase `BossDoor` quedó sin usar.
- Escena nueva `scenes/combat/boss_hall.tscn` + `scripts/combat/boss_hall.gd`: galería a oscuras con la estatua de piedra de cada boss en un nicho, bajo un haz de luz con polvo flotando (aditivo). Al acercarse, el haz se intensifica, la estatua se ilumina y abajo aparece el título de su facultad, el nombre del boss y su subtítulo (de `Arena.BOSSES`). Con interact (E / A) la estatua destella y se entra al combate con la intro completa. Esc o el arco de abajo vuelven al campus. Título de área al entrar: "SALÓN DE LAS FACULTADES · x / 8 vencidos". Música ambiente propia (`assets/audio/hall/hall_ambient.ogg`, generada con `tools/hall_music.py`).
- Estatuas: `assets/sprites/statues/statue_<boss>.png`, capturadas del propio rig de cada boss con fondo transparente (`ztest/statue_gen.gd`; volver a correrlo si cambian los sprites). El shader `shaders/statue_stone.gdshader` las vuelve piedra (`lit` = luz, `gold` = vencido, `flash`).
- Progreso: `GameState.record_victory(kind, rank, secs)` se llama al ganar en la arena y se guarda en `user://progress.cfg` (mejor rango y tiempo). Las estatuas vencidas son de oro y muestran "VENCIDO · Mejor rango · tiempo"; al volver tras la primera victoria la estatua se dora delante del jugador (`GameState.last_won`).
- La arena ahora vuelve al salón (`boss_arena.CAMPUS_SCENE` apunta a `boss_hall.tscn`), y el jugador aparece frente a la estatua que desafió (`BossHall.last_kind`). Prueba: `ztest/hall_test.gd` (6/6). Video: `Claude outputs/salon_facultades.mp4`.
- Backups: `_backups/antes_salon/`. Quedó `_incoming/salon.tar` (paquete del despliegue; se puede borrar).

### 2026-10-19 — Fijar objetivo (estilo souls) + grito de entrada propio de cada boss
- **Fijar objetivo** (`scripts/combat/lock_on.gd`, hijo del jugador): Q / clic central / R3 fija o suelta; Tab o el stick derecho a un lado cambia de objetivo. Fijado: el personaje mira siempre al objetivo aunque camine en otra dirección (al correr mira hacia donde corre), los ataques/parry/ultimate salen apuntados justo al objetivo (dirección exacta, no solo 4/8), la cámara se corre un poco hacia él y una mira giratoria marca su zona golpeable (centro del Hurtbox, o `lock_point()` si el nodo lo define). Prioriza al jefe; se puede fijar cualquier cosa del grupo `enemies` que no sea un peligro/proyectil (`BossFx.Hazard`) ni tenga `lockable = false`. Si el objetivo muere o se aleja (>820 px) salta al más cercano o se suelta; se suelta solo cuando la arena bloquea al jugador. Acciones nuevas en `input_setup.gd`: `lock_on`, `lock_next`. Ayudas del campus y de la arena actualizadas.
- **Grito de entrada propio** (`scripts/combat/boss_roar.gd`, solo visual): se quitó la pose común de brazos arriba + temblor del final de cada intro. Ahora: Juez = señala, carga el mazo atrás y da un único mazazo con sello 403 y onda dorada; Syntax = raya la pizarra (chirrido de tiza, la pantalla tiembla de lado) y golpea con el puntero; Stack = tres martillazos apilan bloques PUSH sobre el casco y el cuarto los desborda; Tex = se tuerce como estatua y da un brochazo de textura rota que cruza la pantalla; KP = reverencia con cartel APLAUSOS y acople del micrófono; BSOD = junta los brazos como paletas, arco eléctrico y CLEAR!; DEADBEEF = el cráneo vomita bytes mientras chasquea las pinzas; DIV/0 = se quita el sombrero y llueven monedas. Captura: `Claude outputs/gritos_bosses.gif`.
- Backups: `_backups/antes_fijar_gritos/`.

### 2026-10-18 (noche, 5) — B.S.O.D.: copias del "test de manchas" con el sprite real
- Pedido del usuario: en la fase 3 de B.S.O.D. aparecían robots extra dibujados con las figuras de prueba (rectángulos morados). Eran las copias falsas del ataque `clones` (`Fx.Clone` en `boss_bsod_fx.gd`), que nunca se pasaron a sprites.
- Ahora `Clone._copy_rig()` copia las piezas reales del boss (mismos sprites, pose, herramientas y tinte). Lo que las delata sigue igual: monitor con línea plana y corazón sin latido. Llevan sombra para no distinguirse por eso. La silueta por código solo queda de respaldo si faltan los sprites. Backup: `_backups/boss_bsod_fx.gd.antes_clones`.

### 2026-10-18 (noche, 4) — Correr
- Pedido del usuario: mantener el botón de rodar (Shift / B) hace correr. Tocarlo = solo rodar (igual que antes); mantenerlo = al acabar la rodada sigue corriendo a `RUN_MULT` 1,6× (caminata acelerada a `RUN_ANIM_SPEED` 1,7, se inclina un poco y levanta polvo). Se deja de correr al soltar, al pararse, al atacar, al rodar otra vez o al recibir un golpe. Todo en `player.gd` (`running`, `_stop_run()`); ayuda del campus actualizada. No hay hoja de correr propia: usa la caminata de 8 frames acelerada.
- Verificado (nube): tocar = rodar, mantener = correr (124 vs 78 px en 0,5 s), soltar = caminar, también con el mando. Backup: `Claude outputs/correr_backup_2026-10-18/`.

### 2026-10-18 (noche, 3) — Lluvia de fase PROPIA de cada boss + REMATE según el duelo final
Pedido del usuario: la lluvia al cambiar de fase no puede ser la misma en todos, y la muerte debe ir según cómo lo derrotas.
- `boss_barrage.gd`: la barrera "INMUNE", el cartel y el arco de tiempo siguen siendo comunes, pero los ataques salen de cada boss: `barrage_title(fase)` (nombre en el cartel), `barrage_plan(fase)` (lista [segundo, ataque, parámetros]) y `_bar_<ataque>(params, tok)` en cada `boss_*.gd`. Lo que lanzan se marca con `Barrage.tag()` y se borra al romperse la barrera. La lluvia genérica de orbes solo queda de respaldo.
  - 0xDEADBEEF **COSECHA DE DATOS**: raíces en estrella, cajas y fruta, estampida por carriles, (F3) láser.
  - B.S.O.D. **CÓDIGO ROJO**: anillos de jeringas, tubos que dejan charcos, pelotas, y la línea del electro que barre la sala (`EcgSweep`, nuevo).
  - #DIV/0! **CRASH BURSÁTIL**: monedas que rebotan, contenedores por carriles, cifras DEBE/HABER, sellos de quiebra.
  - SYNTAX ERROR **EXAMEN SORPRESA**: anillos de tiza, letras que caen, braille con huecos, aviones de papel.
  - STACK OVERFLOW **DEMOLICIÓN**: planos-muro, engranajes, bola de demolición en vuelta completa, ola de concreto.
  - 403 FORBIDDEN **¡DESACATO!**: filas de libros, ráfagas de sellos DENEGADO (parry), sanciones por cuadrantes, oferta y demanda.
  - MISSING TEXTURE **VANDALISMO EN EL MUSEO**: baldosas de textura faltante que queman (`GlitchTile`, nuevo), brochazos, máscaras, excavaciones en estrella.
  - KERNEL PANIC **¡TRANSMISIÓN EN VIVO!**: palomitas, filas de cuchillos, anillos de acople, flambé en círculo.
- **Remates** (`_finisher()` de cada boss, antes de su `_die()`): 0xDEADBEEF el brazo en el cráneo → volcado de memoria hex (`Final.HexDump`) → CORE DUMPED. B.S.O.D. línea plana y las paletas le explotan → PARO CARDÍACO. #DIV/0! el gráfico se desploma por la pantalla (`Final.CrashChart`) + sello #DIV/0! + lluvia de monedas. SYNTAX "0/10" gigante estampado en su pizarra. STACK la torre se le cae encima. JUEZ sello CULPABLE gigante y bajan barrotes de celda (`Cell`). TEXTURE se vuelve mármol, se agrieta y se parte. KERNEL PANIC apagado de TV viejo (`Final.TvOff`) y FIN DE LA EMISIÓN. Efectos comunes nuevos en `boss_final.gd`: `StampSlam`, `CrashChart`, `TvOff`, `HexDump`.
- No hizo falta ninguna hoja nueva de grokbot (todo usa sprites existentes o se dibuja por código).
- Verificado (nube, bots): las 8 lluvias (inmune, ataques, termina), duelos y remates de los 8 hasta la pantalla de victoria. Backup: `Claude outputs/lluvias_remates_backup_2026-10-18/`.

### 2026-10-18 (noche, 2) — Los 7 bosses restantes: mecánica por fase + DUELO FINAL (como el juez)
Pedido del usuario: aplicar a todos la fórmula del juez. Para cada uno: (1) su mecánica sube por fase, (2) cuando el golpe lo dejaría a 0 PV en la fase 3 queda a 1 PV y empieza su DUELO FINAL (state "final", inmune) con música `<boss>_final1..3` que sube y `<boss>_epic` al ganar; si fallas vuelve `_p3` y el próximo golpe lo repite (`final_victory`), (3) animación de anticipación/golpe/recuperación en el duelo.
- **Base común** `scripts/combat/boss_final.gd`: `Final.music_cue/music_final/title` y `Final.Shot` (proyectil de parry, opcional PRECISO con `strict`, vuelve al boss y llama `final_result(ok, shot)` / `final_back(shot)`). Música: `tools/boss_final_music.py <carpeta> <boss...>` (usa los SPECS de `boss_music.py`; los .ogg + imports ya están en `assets/audio/bosses/`).
- **B.S.O.D.** F2: golpes A CONTRATIEMPO (½ latido, aviso "½" y corazón amarillo; `OFFBEAT_CHANCE`). F3: el ritmo cambia cada 4 latidos entre 110/140/175 BPM (`BPM3`). Duelo **CÓDIGO AZUL**: paletas del desfibrilador; una descarga por latido que llega justo en el siguiente: parry preciso en el latido; 12 aciertos, 90→185 BPM → PARO CARDÍACO.
- **SYNTAX ERROR** F1: 3 símbolos. F2: 4 y la pizarra SE BORRA a los 1,4 s (memorizar). F3: 5 escritos, uno TACHADO (trampa, no cuenta) y se leen AL REVÉS (flecha ←). `lesson_view()` alimenta pizarra y HUD. Duelo **EXAMEN FINAL**: 4 pupitres giran por el aula; dicta un símbolo y hay que golpear su pupitre antes del tiempo (2,6→1,5 s); 8 aciertos.
- **0xDEADBEEF** F1: brazo roto para siempre. F2: el brazo roto SE REGENERA a los 9 s (cada golpe al muñón +1,5 s). F3: brazos BLINDADOS salvo mientras atacan con ellos. Duelo **SEGMENTATION FAULT**: se arranca los brazos y los lanza girando; parry = se le clavan (y le vuelven a crecer); 6, el último al cráneo → CORE DUMPED.
- **KERNEL PANIC** F3: DOS cámaras en vivo (hay que romper las dos; la primera da "SEÑAL DE RESPALDO") y una de UTILERÍA con luz roja falsa (romperla = ráfaga). Duelo **ÚLTIMA TRANSMISIÓN**: "al aire en 3,2,1"; se enciende una cámara con cuenta atrás (3→1,7 s) y hay que romperla mientras lanza flambé; 8 seguidas → FIN DE LA EMISIÓN. Las 2 cámaras extra del duelo se quitan si fallas.
- **#DIV/0!** F2: NOTICIAS (periódico de ÚLTIMA HORA: recogerlo = escándalo −18; dejarlo caducar = buenas noticias +18). F3: la BURBUJA hay que pincharla en 5 s o MERCADO ALCISTA (+6 PV, abanico de monedas). Duelo **MARGIN CALL**: acción a 100, lingotes/monedas; parry = VENDE −10, golpe recibido = COMPRA +8; llevarla a 0 antes de la campana (22 s) → #DIV/0!.
- **STACK OVERFLOW** F2: la torre SE BALANCEA y solo cuentan los golpes cuando se inclina hacia el boss (flecha verde). F3: cada viga de acero pide un golpe más (hasta +3, contador en la base). Duelo **RECURSIÓN INFINITA**: la torre crece sola; golpe al ritmo = se inclina más y pierde un piso, a destiempo = +1 piso; 5 aciertos → le cae encima (STACK UNDERFLOW); 8 pisos = STACK OVERFLOW.
- **MISSING TEXTURE** F2: un MANIQUÍ entre tú y él tapa la mirada. F3: la piedra se despinta rápido sin mirarlo (`DECAY_F3`). Duelo **RENDER FINAL**: sala a oscuras con foco; aparece como dos ojos magenta (con amagos) y se lanza como fantasma glitch: parry preciso; si lo estás mirando va más lento; 6 → RENDER COMPLETO.
- Arreglos tras ver los gifs: la campana del duelo de #DIV/0! va bajo los pies del jefe (no tapa la cabeza) y la torre de STACK bajó (`TOWER_AT` = (-370, 90)) para que 8 pisos no queden bajo la barra del jefe.
- Verificado (nube, Godot 4.6.2, bots): lluvia de fase en los 8; pruebas por fase y duelo (fallar → vuelve p3 a 1 PV; repetir y ganar → música final3 + épica + victoria) en los 8; controles y juez sin cambios. Backups: `Claude outputs/bosses_duelos_backup_2026-10-18/`. Pendiente: que Johan los juegue y ajustar números (constantes al principio de cada `boss_*.gd`).

### 2026-10-18 (noche) — Bosses: lluvia de ataques en cada cambio de fase + 403 FORBIDDEN rehecho
- **Todos los bosses (pedido del usuario):** al pasar a fase 2 y a fase 3, después de la presentación (1,6 s) entran en una LLUVIA DE ATAQUES: siguen en state "transition" (inmunes), barrera hexagonal con "INMUNE" y arco de tiempo, cartel "¡INMUNE! ESQUIVA O HAZ PARRY". Orbes (parry de frente o rodar; 1 daño) en espirales, abanicos y desde los bordes; zonas rojas en el piso y ondas de choque (no se bloquean; 2 daño). Fase 2 ≈ 7,5 s, fase 3 ≈ 9,5 s (más denso). Al terminar: "¡BARRERA ROTA!". Archivo nuevo `scripts/combat/boss_barrage.gd` (PLAN por fase, COLORS por boss); cada `boss_*.gd` lo llama en `_enter_phase` con `if not await Barrage.run(self, n, tok): return`. El enrage (12 %) NO tiene lluvia. Jugador quieto recibe ~5-8 de daño en F2 y ~5-13 en F3 (hay que moverse).
- **Parry:** un parry exitoso ya no tiene recuperación (se puede encadenar otro enseguida). `ClassController.parry_age()` = segundos desde que se pulsó (para "parry preciso").
- **403 FORBIDDEN, el juicio por fase** (`TRIAL_PLAN` en `boss_judge.gd`): F1 = 1 sello. F2 = 3 sellos seguidos, hay que hacer parry a TODOS ("OBJECIÓN 2/3"). F3 = 5 sellos más rápidos, ritmo irregular, 1 amago (levanta el mazo y no lanza), 2 con curva, y parry PRECISO (`strict` 0,17 s: el parry tuvo que empezar hace ≤0,17 s; si no: "¡IMPRECISO!" y falla). Los sellos precisos llevan un aro blanco.
- **OBJECIÓN FINAL** (pedido del usuario): en fase 3, el golpe que lo dejaría a 0 PV lo deja a 1 PV y empieza el duelo (state "final", inmune): 2 sellos precisos y el tercero es el PELOTEO: cada parry lo manda al juez, que lo devuelve con el mazo más rápido (460 + 50·n px/s, preciso, con curva desde el 3.º). `FINAL_RALLY` = 6 parries → el sello lo golpea → ¡CULPABLE! → muere (`final_victory`). Música: `judge_final1` al empezar, `judge_final2` al 2.º parry, `judge_final3` al 4.º, y `judge_epic` (cierre épico en Re mayor) al ganar. Si fallas: OBJECIÓN DENEGADA, vuelve `judge_p3` y la pelea sigue con el juez a 1 PV; el próximo golpe repite el duelo.
- `boss_arena.gd`: `music_cue(part)` (cambia a un loop concreto) y `music_final(part)` (cierre propio; `_on_victory` ya no toca `_win` si se usó). `boss_judge_fx.gd`: `Seal` con `strict`, `wobble`, `rally`, `relaunch()`; `Verdict` ya no se sale por arriba de la pantalla.
- Música nueva: `tools/judge_final_music.py` (usa `boss_music.py`) → `assets/audio/bosses/judge_final1..3.ogg` + `judge_epic.ogg`, entregadas con `.import` y `.godot/imported`.
- Verificado en Godot 4.6.2 (nube, bot): lluvia en los 8 bosses (inmune, ataques, termina); juez F1/F2/F3 con 1/3/5 sellos; parry temprano en F3 = denegado; duelo final fallando (vuelve p3, 1 PV), repitiendo y ganando (6/6, música sube a final3, cierre épico, pantalla de victoria). 0 fallos.
- Backups: `Claude outputs/bosses_fases_backup_2026-10-18/`. Pendiente: que Johan lo pruebe y ajustar dificultad (densidad de la lluvia en `PLAN`, `strict`, `FINAL_RALLY`).
- Después (pedido del usuario): **animación del mazo al devolver el sello** en el peloteo. Al hacer parry, el juez echa el mazo atrás por encima de la cabeza y se inclina (`_windup`, dura según lo que tarda el sello en volver, con destello `Glint`); al llegar el sello, el mazo baja en arco hacia el jugador (`_swing`: estela `SwingArc`, estrella `ImpactStar`, hit-stop, cuerpo hacia delante) y el sello sale desde la cabeza del mazo; luego sigue de largo y vuelve a la guardia. En el 6.º parry se cubre asustado (`_brace`, "¡¿QUÉ?!"). Además `ClassController.parry_age()` ahora mide tiempo de JUEGO (`_game_t`), no reloj real (con hit-stop podía marcar IMPRECISO sin serlo). Backup: `Claude outputs/juez_mazo_backup_2026-10-18/`.

### 2026-10-18 (tarde) — Parry sin contraataque automático + jugar con mando
- `class_controller.gd`: `on_parried` ya no llama a `_start_counter`; abre `_counter_until` (COUNTER_WINDOW 0,55 s). `try_primary` contraataca si la ventana está abierta (corta la recuperación del parry); fuera de ella es combo normal. `cancel_action` cierra la ventana.
- Nuevo `scripts/input_setup.gd` (teclado + mando para todas las acciones; acciones nuevas `interact`, `retry`, `back`, `debug_next_phase`). `game_state.gd`: llama a `InputSetup.ensure()`, `using_pad`, `btn()`. `player.gd` usa `back` en vez de `ui_cancel`; `campus.gd` puerta con `interact` y ayuda dinámica; `boss_arena.gd` usa `retry`/`back`/`debug_next_phase`; `player_hud.gd` muestra botones según el control y el aviso de contraataque; `character_creator.gd` navegable con mando.
- Verificado en Godot 4.6.2 (nube, bot que simula el mando): 26/26 pruebas en las 3 clases (stick, X/Y/LB/B/RB, parry sin contraataque, parry+X = contraataque, X tarde = golpe normal, A entra al boss, Select vuelve, teclado sigue igual). Captura del HUD revisada.
- Backups: `Claude outputs/mando_parry_backup_2026-10-18/`. Pendiente: que Johan lo pruebe con su mando físico.

### 2026-10-18 — HUD del jugador, barras de jefe por mecánica y arenas
- Nuevo `scripts/combat/player_hud.gd` (retrato, nombre/clase, 10 corazones, anillo de K, ultimate, combo, PARRY); `player.gd` solo lo crea.
- Nuevo `scripts/combat/boss_hud.gd`: barra de cada boss con su mecánica (Base + 8 subclases). `boss_arena.gd` la crea y ya no llama a `build_hud` de los bosses (sus paneles viejos quedan sin uso).
- Nuevo `scripts/combat/boss_arena_fx.gd`: partículas, viñeta y luz por fase; fondo pintado `assets/sprites/arenas/arena_<boss>.png` y `_caos.png` (fase 3) si existen (FLOOR_FRAC ajusta el encuadre); si no, el piso por código.
- Tareas para grokbot: `referencias_animacion/GROKBOT_ARENAS.md` + `PROMPTS_ARENAS.md` (16 imágenes en `_entregas_runway/arenas/`).
- Verificado: bot en la VM, 8 peleas completas sin errores. Backups en `tools/*_backup_2026-10-18.gd.txt`.
- Arenas integradas (04:05): las 16 imágenes en `assets/sprites/arenas/` con sus imports (`tools/arenas_1..4.tgz`), FLOOR_FRAC ajustado por boss. Pendiente: prueba de Johan en el editor.


### 2026-10-17 — Música propia por boss (adaptativa)
- Ver sección 6: 8 temas originales, 3 fases + victoria cada uno, y jingle de derrota común.

### 2026-10-17 — Arreglo de importación (música y sprites de bosses 5-8)
- Ver sección 6: faltaban los importados de Godot; ahora no falta ninguno de los 895 .import.

### 2026-10-17 — Música de jefe 16 bits
- Tema original sintetizado por código (ver sección 6), el mismo para los 8 bosses. Probado con el bot: suena en loop desde 3.0 s.

### 2026-10-17 — Boss 8 KERNEL PANIC con sprites
- Las 10 hojas recortadas e integradas (ver sección 6). Probado con el bot: 3 KERNEL PANIC, 3 fases, furia y muerte (SEÑAL RESTABLECIDA) sin errores.

### 2026-10-17 — Boss 8 KERNEL PANIC de prueba (Al Aire)
- Lo único: AL AIRE: 3 cámaras en el estudio; la que está EN VIVO le da medio daño. Romperla (3 golpes, 4 en fase 3) = SIN SEÑAL → ¡KERNEL PANIC!, aturdido 4 s con daño x2; luego corte comercial y vuelve por otra cámara (cambia sola cada 15 s en fase 2 y 10 s en fase 3). Si te acercas a la cámara en vivo, la defiende. Furia FUERA DE AIRE: apaga el estudio y se graba con una cámara de mano. Ataques: flambé con aceite ardiendo (Gastronomía), alfombra roja con paparazzi que encandilan (TV, RRPP y Protocolo), palomitas, juliana de cuchillos, acople (anillo, se esquiva rodando) y embestida con el carrito. HUD = franja de transmisión de TV. Probado con el bot: 3 KERNEL PANIC, 3 fases, furia y muerte (SEÑAL RESTABLECIDA) sin errores de script.

### 2026-10-17 — Boss 7 MISSING TEXTURE con sprites
- Las 10 hojas recortadas e integradas (ver sección 6). Probado con el bot: ESTATUA, pose final, 3 fases, furia y muerte sin errores.

### 2026-10-16 — Boss 7 MISSING TEXTURE de prueba (La Mirada)
- Estatua de museo. Lo único: La Mirada: si el jugador lo mira (facing_vec, cono ~120°) queda en piedra (no se mueve, su ataque va a 35% de velocidad y el siguiente tarda más); mirarlo ~4 s llena la barra = ¡ESTATUA!, aturdido 4 s con daño x2; 3 s sin mirarlo (2 s en fase 3) = POSE FINAL, te agarra: 1 s petrificado y 2 de daño. Ataques: excavación (Arqueología), máscaras bumerán (Artes Escénicas), brochazos que dejan pintura que frena (Artes Plásticas), costura con hilo que se cierra (Diseño Textil), maniquíes que solo avanzan si no los miras (Sociología) y golpe de pedestal. HUD = ficha técnica del museo. Probado con el bot: 2 ESTATUAS, pose final, 3 fases, furia OBRA PERDIDA y muerte (OBRA RESTAURADA) sin errores de script.

### 2026-10-16 — Boss 6 403 FORBIDDEN con sprites
- Las 10 hojas recortadas e integradas (ver sección 6). Probado con el bot: juicio ganado en fase 1, otro en fase 3, 3 fases y muerte (CASO CERRADO) sin errores.

### 2026-10-16 — Boss 5 con sprites + Boss 6 403 FORBIDDEN de prueba (La Evidencia)
- Boss 5: sprites de las 10 hojas integrados (ver sección 6). Probado con el bot con sprites.
- Boss 6: juez robot (estrado, toga, peluca, monitor con cara). Lo único: La Evidencia: escudo "403" (daño /4) hasta juntar 3 pruebas que suelta tras sus ataques; entonces abre juicio (2 golpes de mazo y lanza un sello, 2 en fase 3): parry al sello = OBJECIÓN, CULPABLE, aturdido con daño x2 4 s; si no, vuelve el escudo. 7 ataques por carrera (en vivo/foco, fronteras, cinta de escena del crimen, libros, mercado, carpetas que atrapan) y mazazo. HUD = expediente. Probado con el bot: 3 fases, juicios ganados y perdidos, APELACIÓN DENEGADA y muerte sin errores; puerta campus → arena → Esc probada.

### 2026-10-16 — Boss 5 STACK OVERFLOW de prueba (La Torre)
- Máquina de obra (orugas, cabina de excavadora, casco con visor, grúa y martillo). Lo único: La Torre: tras cada ataque apila 1 pieza (2 en fase 3) en una torre arriba a la izquierda; a los 8 pisos se desborda y se derrumba hacia el jugador (franja roja, 3 de daño). Con 2+ pisos, 3 golpes a la base la tumban hacia el boss: si lo alcanza (80 + 40 px por piso) queda aplastado con el motor expuesto (x2) 1,5 s + 0,4 s por piso. 6 ataques por carrera (cintas con latas, plano que sube muros, postes con arcos, bola de demolición, engranajes + drones obreros, ancla con parry + ola) y embestida. HUD = plano azul con "avance de obra". Probado con el bot: 2 aplastamientos, desborde, 3 fases, DERRUMBE y muerte sin errores.

### 2026-10-16 — Boss 4 SYNTAX ERROR de prueba (La Lección)
- Robot profesor con pizarra en el pecho. Lo único: La Lección (cada 18 s, 11 s si reprobó, y al empezar cada examen): escribe 3/4/5 símbolos ▲●■★, salen 4 pupitres, hay que golpearlos en ese orden en 11/13/15 s. APROBADO = aturdido 4 s con daño x2; REPROBADO = 3 ráfagas de tiza. HUD = libreta con la nota (10 a 0). 10 ataques, uno por carrera, más el pisotón. Probado con el bot: pelea completa, 3 fases, RECUPERACIÓN y muerte sin errores.

### 2026-10-16 — Boss 3 #DIV/0! de prueba (La Bolsa)
- Precio de acción en el HUD en vez de la barra de vida: golpes del jugador -4.5/daño, golpes del boss +6, se recupera 1.2/s. Bajo la línea roja (35, baja 3 por quiebra hasta 22) = QUIEBRA 4 s con bóveda abierta (x2). Sobre 95 = BURBUJA. Parry al sello DESPEDIDO = aturdido 2.2 s. Probado con el bot: pelea completa, 3 fases, hiperinflación y muerte sin errores.

### 2026-10-16 — Boss 2 B.S.O.D. de prueba + brazos rompibles del boss 1
- Nuevos `boss_bsod.gd`, `boss_bsod_fx.gd`; cambiados `boss_arena.gd`, `boss_deadbeef.gd`, `boss_fx.gd` (FallingPart), `campus.gd` (2ª puerta), `player.gd` (`speed_mult`). Ver sección 6.

### 2026-10-16 — Puerta al boss en el campus
- `campus.gd` (BossDoor, tecla E), `player.gd` (`exit_scene`), `boss_arena.gd` (Esc → campus). Ver sección 6.

### 2026-10-16 — Boss 0xDEADBEEF: pasada de robustez y sprite más fiel
- Ver sección 6 (16-10 08:20). Cambia `boss_deadbeef.gd`, `boss_fx.gd`, `boss_arena.gd`, `boss_sprites.gd`, `tools/slice_boss_sheets.py`; nuevo `tools/make_boss_torso.py` y sprites torso/brazos. No toca player.gd ni el Pulido 4.

### 2026-10-16 — Boss de prueba 0xDEADBEEF jugable
- `scenes/combat/boss_test.tscn` + 4 scripts `boss_*.gd`; ver sección 6. Verificado con bot en Godot 4.6.2 (VM): `Claude outputs/boss_prueba.gif`.
- Pendiente: prueba del usuario; luego cambiar figuras por las hojas de grokbot.

### 2026-10-16 — Boss 1 0xDEADBEEF: diseño aprobado y tareas de grokbot
- Diseño en Claude Doc (link en sección 6). Archivos: `GROKBOT_BOSS_1.md`, `PROMPTS_BOSS_1.md`, `tools/gen_prompts_boss1.py`, `referencias_animacion/bosses/0xdeadbeef_referencia.jpg`.
- Pendiente: grokbot genera las 10 hojas; Claude programa el boss de prueba.

### 2026-10-16 — Bosses: análisis y plan
- Revisado el combate/enemigos actuales; añadido el plan de bosses en la sección 6. Sin cambios de código.
- Pendiente: OK del usuario para el boss de prueba.


### 2026-10-16 — Pulido 4 completo (23/23) + caminata arriba
- Rehechas por grokbot las 3 rechazadas y `walk8_up` de ambos (pies virados, pedido del usuario). Todas aceptadas e integradas. Verificación: `Claude outputs/p4_tira_v2.png`, `pulido4_v2_animaciones.gif`.
- Pendiente: prueba del usuario en el editor.

### 2026-10-16 — Pulido 4 integrado (20/23)
- grokbot entregó 23/23; revisión visual → 3 rechazadas (`_r1`), 20 recortadas y calibradas (6 con scale/aspect nuevos). Herramientas nuevas: `tools/measure_p4.py`, `tools/strip_p4.py`.
- Verificado con `Claude outputs/p4_tira_*.png` y `pulido4_animaciones.gif` (no es captura en juego).
- Backups: ver sección 6. Pendiente: prueba del usuario en el editor + 3 hojas por rehacer.

### 2026-10-16 — Verificación del Pulido 4 en disco
- Contadas las tareas de `GROKBOT_PULIDO_4.md` (0/23 hechas) y revisado `_entregas_runway/` (399 archivos; sin entregas posteriores al 15-10). Corregida la sección 6.
- Backup: `CONTEXTO_PROYECTO_backup_2026-10-16.md`.
- Decisión del usuario: hacer el Pulido 4. Pendiente: grokbot genera las 23 hojas; luego integrar.

### 2026-10-15 — Consolidación del documento de contexto
- Creado este `CONTEXTO_PROYECTO.md` a partir del contexto anterior (`claude/CONTEXTO_prototipo_campus.md` del Project de claude.ai) y la memoria de la cuenta original, para trabajar entre varias cuentas en el mismo PC.
- Pendiente: la primera sesión que lo abra en el PC debe confirmar el estado real del Pulido 4 y corregir la sección 6.

### 2026-10-15 — (de la sesión anterior) Tamaño estándar, mini salto, rodar arriba-derecha, Pulido 4 preparado
- Ver sección 5. Verificaciones: `Claude outputs/mago_chain_en_juego.gif`, `Claude outputs/diagonales_rodar_atacar.gif`.
