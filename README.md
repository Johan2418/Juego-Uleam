# Juego ULEAM — Prototipo Campus

Juego top-down en **Godot 4.6** (GDScript) ambientado en la Universidad Laica Eloy Alfaro de Manabí:
creas a tu universitario, eliges clase (Guerrero, Mago o Chain) y te enfrentas a los 8 bosses de las facultades
desde el **Salón de las Facultades**.

## Cómo jugar
1. Abre la carpeta con Godot 4.6 (*Import* → `project.godot`) y pulsa **F5**.
2. Crea tu personaje → campus → puerta grande **SALÓN DE LAS FACULTADES** → acércate a una estatua y pulsa **E**.

| Acción | Teclado | Mando |
|---|---|---|
| Mover | WASD / flechas | Stick izq. / cruceta |
| Combo | J / clic izq. | X |
| Especial | K / clic der. | Y |
| Parry (luego ataque = contraataque) | L | LB |
| Rodar (mantener = correr) | Shift | B |
| Ultimate | Espacio | RB |
| Fijar objetivo / cambiar | Q, clic central / Tab | R3 / stick der. |
| Interactuar | E | A |
| Volver | Esc | Select |

## Bosses
0xDEADBEEF (Ciencias de la Vida y Tecnología) · B.S.O.D. (Ciencias de la Salud) · #DIV/0! (Ciencias Administrativas) ·
SYNTAX ERROR (Educación, Turismo y Humanidades) · STACK OVERFLOW (Ingeniería, Industria y Arquitectura) ·
403 FORBIDDEN (Ciencias Sociales, Derecho y Bienestar) · MISSING TEXTURE (Artes, Humanidades y Patrimonio) ·
KERNEL PANIC (Unidad Técnicas y Tecnológicas).
Cada uno tiene 3 fases con mecánica propia, una lluvia de ataques en cada cambio de fase y un duelo final a un golpe.
Detalle en `CONTEXTO_PROYECTO.md` y `referencias_animacion/GUIA_BOSSES.md`.

## Estructura
- `scripts/` — lógica (combate en `scripts/combat/`, un archivo por boss + sus efectos `_fx`)
- `scenes/` — escenas (`main.tscn` campus, `combat/boss_hall.tscn` salón, `combat/boss_test.tscn` arena)
- `assets/` — sprites, arenas y música (la música se genera con `tools/boss_music.py` y afines)
- `tools/` — scripts de Python para cortar hojas de sprites y generar música
- `personajes_seleccionables/`, `referencias_animacion/` — material de origen y prompts de arte

---

## Notas originales — Character Creator

Prototipo **Godot 4.6** (GDScript) con creador de personaje estilo Zelda top-down (*A Link to the Past* / *Minish Cap*).

## Cómo abrir / probar

1. Abre Godot 4.6 y elige **Import** / **Open** sobre esta carpeta (`prototipo`).
2. Pulsa **F5** (Play). Debe abrirse primero **Crea tu universitario**.
3. Cambia nombre, piel, peinado, color de pelo, ropa y accesorio; la vista previa (pixel 16×24 escalado) se actualiza en vivo.
4. **Confirmar** guarda en `user://player_appearance.cfg` (autoload `GameState`) y pasa a `scenes/main.tscn`, que muestra el resumen.

Binario de referencia: `Godot_v4.6.2-stable_win64.exe`.

## Estructura

- `autoload/game_state.gd` — datos del personaje + guardado
- `scripts/character/character_appearance.gd` — opciones (etiquetas en español)
- `scripts/character/character_preview.gd` — sprite procedural por capas
- `scenes/character_creator.tscn` — UI del creador (escena principal)
- `scenes/main.tscn` — aterrizaje post-creación

## Notas

- No hace falta arte externo: el preview se genera en GDScript.
- Resolución de ventana: 1280×720.
- Contexto de juego: campus universitario; facultades como mazmorras (aún no implementado).

## Combate (clases)
Tras Confirmar en el creador se entra al patio (`scenes/main.tscn`).
Clases: Guerrero, Mago, Chain — ver `DELIVER_COMBATE.txt`.
Sprites: `assets/sprites/combat/` (Marlon shared set). Anim body is shared until more sheets exist.


## Personajes en capas (18 seleccionables)
- Catálogo: `assets/sprites/characters/characters.json` → `CharacterCatalog`.
- Dibujo: `CharacterRig` = cuerpo compartido (`body_base/`, recoloreado con `shaders/outfit_recolor.gdshader` + máscara) + cabeza del personaje (`heads/`).
- Lo usan el creador (preview que gira), el jugador y los dummies.
- Agregar personaje: poner su hoja turnaround en `personajes_seleccionables/originales/<id>.png` y correr
  `python3 tools/character_split/build_characters.py personajes_seleccionables/originales assets/sprites/characters`
  (añadir el id a `ORDER`/`LABELS` del script).
- Las animaciones de combate del cuerpo aún no existen: el rig usa pose fija + balanceo y un empujón al atacar.
