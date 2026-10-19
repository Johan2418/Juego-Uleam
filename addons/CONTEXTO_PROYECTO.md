# CONTEXTO DEL PROYECTO — Prototipo Campus (Godot 4.6)

> **Documento compartido entre sesiones/cuentas de Claude.** Varias cuentas trabajan en este mismo proyecto, en el mismo PC, por turnos (cuando una se queda sin uso, sigue la otra).
> **Regla de oro:** ANTES de tocar nada, lee este archivo completo. AL TERMINAR cada tarea (o antes de que se corte la sesión), actualiza las secciones **Estado actual**, **Trabajo en curso** y **Bitácora**. Si no queda escrito aquí, la otra sesión no lo sabe.

- Ruta del archivo: `C:\Users\leopo\Documents\Juegos\Godot\prototipo\CONTEXTO_PROYECTO.md`
- Última actualización: 2026-10-15 — por la sesión de la cuenta sin acceso al PC (consolidación inicial del documento)

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
J ataque leve (combo) · K especial (cooldown) · L parry · Espacio ultimate (medidor) · Shift rodar (i-frames, igual en las 3 clases) · F1 llenar ultimate (debug) · Esc volver al creador. WASD/flechas mover.

### Diseño de combate (decidido por el usuario)
- **Ataque leve = combo** (pulsaciones seguidas encadenan golpes distintos) con **remate** propio en las 3 clases.
- **Parry solo cubre el FRENTE** (cono ±75°). Golpe por espalda/costado entra igual. Parry exitoso → contraataque automático (`ClassController._start_counter`, daño 2).
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

## 5. Estado actual (2026-10-15)

**Hecho y verificado en juego:**
- Set completo de sprites para ambos personajes: idle (animado), caminata de 8 frames a 16 fps en 5 direcciones, rodar, combos J (4 frames por golpe en guerrero; mago/chain con hoja `*8` donde existe, si no 2 poses por golpe), remates, especial/parry/ultimate (incl. hojas de 8 poses del pulido 3), contraataque, knockdown, idle_long (mira el celular), daño.
- Ataques diagonales de las 3 clases en ambas diagonales.
- Parry frontal funciona (frente bloquea, espalda no). Las 3 ultimates únicas funcionan.
- Game feel completo (hit-stop, destellos, polvo, fantasmas, squash).
- Tamaño unificado: walk/idle/ataques dentro de ±5 % (cabeza y alto), salvo `mago_ultimate8` (métrica falla, se deja).
- `roll_up_right` de ambos personajes se espeja al cargar (`MIRROR_SHEETS`) porque las hojas miran a la izquierda.

**Detalle histórico de rondas de pulido (resumen):** Pulido 1 (127/128 hojas), Pulido 2 (caminata 8 frames + combos 8 de espaldas con HAND RULE), corrección de color ChatGPT (COLOR_MATCH), unificación de escala, Pulido 3 (133/134; 131 aceptadas), fix "se encogen al atacar", fix proporciones diagonal, fix "mini salto" mago/chain (`MID_ALLOW`), tamaño estándar único.

---

## 6. Trabajo en curso / siguiente paso

**Pulido 4 — preparado el 2026-10-15, estado de entrega DESCONOCIDO** (revisar `referencias_animacion/GROKBOT_PULIDO_4.md` para ver cuántas `[x]`):
- 23 hojas: A = 2 rechazadas + 1 `[!]` del pulido 3 (`marlonx_a_guerrero_counter8_down_right`, `wadrid_guerrero_ultimate8_up_right` con ERASER RULE, `wadrid_chain_counter8_up` sin líneas de movimiento); B = 18 combos `<base>8_<dir>` que faltan (mago/chain de pie sin saltar + wadrid guerrero up/up_right), con regla de MISMAS PROPORCIONES que la Imagen 2; C = `roll_up_right` ×2 lanzándose a la DERECHA (2x2, 3:4).
- Al integrar: revisar → recortar → calibrar al tamaño estándar → verificar con gif → **quitar `roll_up_right` de `MIRROR_SHEETS`** si las nuevas están bien → actualizar este documento.

**Siguientes pasos generales (después del Pulido 4):**
1. Ajustar números a gusto del usuario: cooldowns, daño, ventana/cono del parry, duración de ultimates, frecuencia de ataque del dummy.
2. Enemigos reales (IA, varios tipos) en lugar del dummy; efectos de sonido.
3. Mapa del campus / facultades como mazmorras.

---

## 7. Bitácora

### 2026-10-15 — Consolidación del documento de contexto
- Creado este `CONTEXTO_PROYECTO.md` a partir del contexto anterior (`claude/CONTEXTO_prototipo_campus.md` del Project de claude.ai) y la memoria de la cuenta original, para trabajar entre varias cuentas en el mismo PC.
- Pendiente: la primera sesión que lo abra en el PC debe confirmar el estado real del Pulido 4 y corregir la sección 6.

### 2026-10-15 — (de la sesión anterior) Tamaño estándar, mini salto, rodar arriba-derecha, Pulido 4 preparado
- Ver sección 5. Verificaciones: `Claude outputs/mago_chain_en_juego.gif`, `Claude outputs/diagonales_rodar_atacar.gif`.
