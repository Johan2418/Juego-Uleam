# TAREA PARA GROKBOT — pulido de sprites (128 hojas)

Proyecto: `C:\Users\leopo\Documents\Juegos\Godot\prototipo` (rutas relativas a esa carpeta).
Mismo procedimiento y lista de control que `referencias_animacion/GROKBOT_TAREA.md` (léelo primero), con estas reglas:

## Cómo trabajar
1. Sigue el orden de las fases (F1 → F5). F5 usa hojas que se generan en F4.
2. Para cada hoja pendiente, busca su bloque en `referencias_animacion/PROMPTS_PULIDO.md` por el nombre de archivo.
3. En Gemini, en una conversación NUEVA, adjunta Imagen 1 y luego Imagen 2 del bloque y pega el prompt completo, sin cambios. Proporción vertical 3:4.
4. Revisa el resultado (lista de control abajo). Si falla, regenera una vez. Si vuelve a fallar, marca `[!]` con una nota corta y sigue.
5. Guarda en `referencias_animacion/_entregas_runway/<nombre>.png` (o `.jpg` si Gemini solo da jpg), con el nombre EXACTO del bloque.
6. Marca `[x]` aquí al guardar cada hoja (así se puede retomar si se corta).
7. No toques código, `assets/`, `scenes/` ni `scripts/`. No sobrescribas hojas que no estén en esta lista.

## Lista de control (además de la de GROKBOT_TAREA.md)
- El personaje es IDÉNTICO al de la Imagen 2: mismo tamaño de cabeza, mismo alto y grosor, mismo pelo y piel.
- Las 4 poses tienen el MISMO tamaño entre sí (no una más alta o más grande que las otras).
- Vista correcta: `_right` perfil; `_down` de frente; `_up` de espaldas sin carnet; `_down_right` 3/4 de frente girado a la derecha; `_up_right` 3/4 de espaldas girado a la derecha.
- Hojas "intermedias" (`_b_`): las poses deben quedar ENTRE las de la Imagen 2, no repetirlas.
- Torbellino (`chain_ultimate_spin`): mismo pie y misma postura en las 4 poses; solo gira el cable.

## Progreso
Leyenda: `[ ]` pendiente · `[x]` hecha · `[!]` falló 2 veces (con nota)


### F1 · Caminata con 8 frames (poses intermedias)
- [x] `wadrid_walk_b_down.png`
- [x] `wadrid_walk_b_up.png`
- [x] `wadrid_walk_b_right.png`
- [x] `wadrid_walk_b_down_right.png`
- [x] `wadrid_walk_b_up_right.png`
- [x] `marlonx_a_walk_b_down.png`
- [x] `marlonx_a_walk_b_up.png`
- [x] `marlonx_a_walk_b_right.png`
- [x] `marlonx_a_walk_b_down_right.png`
- [x] `marlonx_a_walk_b_up_right.png`

### F2 · Combo J con 4 frames por golpe
- [x] `wadrid_guerrero_attack_b_right.png`
- [x] `wadrid_guerrero_attack_b_down.png`
- [x] `wadrid_guerrero_attack_b_up.png`
- [x] `wadrid_mago_cast_b_right.png`
- [x] `wadrid_mago_cast_b_down.png`
- [x] `wadrid_mago_cast_b_up.png`
- [x] `wadrid_chain_whip_b_right.png`
- [x] `wadrid_chain_whip_b_down.png`
- [x] `wadrid_chain_whip_b_up.png`
- [x] `marlonx_a_guerrero_attack_b_right.png`
- [!] `marlonx_a_guerrero_attack_b_down.png` - 2 intentos: la regla sale doblada (pose 3 en el 1.º, pose 2 en el 2.º). Se guardó el 1.º.
- [x] `marlonx_a_guerrero_attack_b_up.png`
- [x] `marlonx_a_mago_cast_b_right.png`
- [x] `marlonx_a_mago_cast_b_down.png`
- [x] `marlonx_a_mago_cast_b_up.png`
- [x] `marlonx_a_chain_whip_b_right.png`
- [x] `marlonx_a_chain_whip_b_down.png`
- [x] `marlonx_a_chain_whip_b_up.png`

### F3 · Torbellino de chain en bucle + reposo animado
- [x] `wadrid_chain_ultimate_spin_right.png`
- [!] `wadrid_chain_ultimate_spin_down.png` - 2 intentos: los pies y la postura cambian entre poses (solo debería moverse el cable). Se guardó el 2.º, que cambia menos.
- [x] `wadrid_chain_ultimate_spin_up.png`
- [x] `marlonx_a_chain_ultimate_spin_right.png`
- [x] `marlonx_a_chain_ultimate_spin_down.png`
- [x] `marlonx_a_chain_ultimate_spin_up.png`
- [x] `wadrid_idle_anim_down.png`
- [x] `wadrid_idle_anim_up.png` - rehecha 2026-09-28: espalda real, el afro cubre la cabeza (2.º intento)
- [x] `wadrid_idle_anim_right.png`
- [x] `wadrid_idle_anim_down_right.png`
- [x] `wadrid_idle_anim_up_right.png`
- [x] `marlonx_a_idle_anim_down.png`
- [x] `marlonx_a_idle_anim_up.png`
- [x] `marlonx_a_idle_anim_right.png`
- [x] `marlonx_a_idle_anim_down_right.png`
- [x] `marlonx_a_idle_anim_up_right.png`

### F4 · Diagonales de todas las acciones
- [x] `wadrid_roll_down_right.png`
- [x] `wadrid_roll_up_right.png`
- [x] `wadrid_guerrero_attack_down_right.png`
- [x] `wadrid_guerrero_attack_up_right.png`
- [x] `wadrid_guerrero_finisher_down_right.png`
- [x] `wadrid_guerrero_finisher_up_right.png`
- [!] `wadrid_guerrero_special_down_right.png` - 2 intentos: 1.º sin goma en pose 4, 2.º con estela marcada en pose 4 (se guarda el 2.º)
- [!] `wadrid_guerrero_special_up_right.png` - 2 intentos: gafas/cara de perfil en vista 3/4 espalda (se guarda el 2.º, leve)
- [x] `wadrid_guerrero_parry_down_right.png`
- [x] `wadrid_guerrero_parry_up_right.png`
- [x] `wadrid_guerrero_ultimate_down_right.png`
- [!] `wadrid_guerrero_ultimate_up_right.png` - 2 intentos: carnet visible en vista 3/4 espalda (se guarda el 2.º)
- [x] `wadrid_mago_cast_down_right.png`
- [x] `wadrid_mago_cast_up_right.png`
- [x] `wadrid_mago_finisher_down_right.png`
- [x] `wadrid_mago_finisher_up_right.png`
- [x] `wadrid_mago_special_down_right.png`
- [x] `wadrid_mago_special_up_right.png`
- [x] `wadrid_mago_parry_down_right.png`
- [x] `wadrid_mago_parry_up_right.png`
- [x] `wadrid_mago_ultimate_down_right.png`
- [x] `wadrid_mago_ultimate_up_right.png`
- [x] `wadrid_chain_whip_down_right.png`
- [x] `wadrid_chain_whip_up_right.png`
- [x] `wadrid_chain_finisher_down_right.png`
- [!] `wadrid_chain_finisher_up_right.png` - 2 intentos: cordon/carnet visible de espaldas (se guarda el 2.º)
- [x] `wadrid_chain_special_down_right.png`
- [x] `wadrid_chain_special_up_right.png`
- [x] `wadrid_chain_parry_down_right.png`
- [x] `wadrid_chain_parry_up_right.png`
- [x] `wadrid_chain_ultimate_down_right.png`
- [x] `wadrid_chain_ultimate_up_right.png`
- [x] `wadrid_hurt_down_right.png`
- [!] `wadrid_hurt_up_right.png` - 2 intentos: carnet asomando en pose 4 (se guarda el 2.º, leve)
- [x] `marlonx_a_roll_down_right.png`
- [x] `marlonx_a_roll_up_right.png`
- [x] `marlonx_a_guerrero_attack_down_right.png`
- [!] `marlonx_a_guerrero_attack_up_right.png` - 2 intentos: 1.º con estela marcada en pose 3, 2.º de frente con carnet (se guarda el 1.º)
- [x] `marlonx_a_guerrero_finisher_down_right.png`
- [x] `marlonx_a_guerrero_finisher_up_right.png`
- [x] `marlonx_a_guerrero_special_down_right.png`
- [!] `marlonx_a_guerrero_special_up_right.png` - 2 intentos: una pose sale de frente con carnet (se guarda el 2.º)
- [x] `marlonx_a_guerrero_parry_down_right.png`
- [x] `marlonx_a_guerrero_parry_up_right.png`
- [x] `marlonx_a_guerrero_ultimate_down_right.png`
- [x] `marlonx_a_guerrero_ultimate_up_right.png`
- [x] `marlonx_a_mago_cast_down_right.png`
- [!] `marlonx_a_mago_cast_up_right.png` - 2 intentos: cordon/carnet visible en vista 3/4 espalda (se guarda el 2.º, leve)
- [x] `marlonx_a_mago_finisher_down_right.png`
- [x] `marlonx_a_mago_finisher_up_right.png`
- [x] `marlonx_a_mago_special_down_right.png`
- [!] `marlonx_a_mago_special_up_right.png` - 2 intentos: cara/gafas y carnet visibles en vista 3/4 espalda (se guarda el 1.º)
- [x] `marlonx_a_mago_parry_down_right.png`
- [x] `marlonx_a_mago_parry_up_right.png` — REHECHA 2026-10-07 en GROKBOT_PULIDO_2 (ChatGPT, vista de espaldas sin cara ni gafas). Antes: — RECHAZADA (revisión 2026-09-29): poses 2-3 de frente con gafas y carnet; rehacer con CRITICAL VIEW RULE
- [x] `marlonx_a_mago_ultimate_down_right.png`
- [x] `marlonx_a_mago_ultimate_up_right.png`
- [x] `marlonx_a_chain_whip_down_right.png`
- [x] `marlonx_a_chain_whip_up_right.png` - rehecha 2026-09-28: espalda girada a la derecha, sin carnet (1.er intento)
- [x] `marlonx_a_chain_finisher_down_right.png`
- [x] `marlonx_a_chain_finisher_up_right.png`
- [x] `marlonx_a_chain_special_down_right.png`
- [x] `marlonx_a_chain_special_up_right.png`
- [x] `marlonx_a_chain_parry_down_right.png`
- [x] `marlonx_a_chain_parry_up_right.png` - rehecha 2026-09-28: espalda, sin cara, gafas ni carnet (1.er intento)
- [x] `marlonx_a_chain_ultimate_down_right.png`
- [x] `marlonx_a_chain_ultimate_up_right.png`
- [x] `marlonx_a_hurt_down_right.png`
- [x] `marlonx_a_hurt_up_right.png`

### F5 · Extras diagonales (hacer después de F4)
- [x] `wadrid_guerrero_attack_b_down_right.png`
- [!] `wadrid_guerrero_attack_b_up_right.png` - 2 intentos: 1º sin regla en pose 2, 2º poses 1-2 de frente con carnet; se guarda el 1º
- [!] `wadrid_mago_cast_b_down_right.png` - 2 intentos: 1º bastón duplicado en pose 1, 2º estelas de movimiento en poses 2-3; se guarda el 2º
- [x] `wadrid_mago_cast_b_up_right.png`
- [x] `wadrid_chain_whip_b_down_right.png`
- [x] `wadrid_chain_whip_b_up_right.png`
- [x] `wadrid_chain_ultimate_spin_down_right.png`
- [x] `wadrid_chain_ultimate_spin_up_right.png`
- [!] `marlonx_a_guerrero_attack_b_down_right.png` - 2 intentos: falta la goma en pose 2 (el 1º además tenía estela); se guarda el 2º
- [x] `marlonx_a_guerrero_attack_b_up_right.png`
- [!] `marlonx_a_mago_cast_b_down_right.png` - 2 intentos: estela en pose 3 y bastón duplicado en pose 4 (el 1º cambiaba el pelo); se guarda el 2º
- [x] `marlonx_a_mago_cast_b_up_right.png`
- [x] `marlonx_a_chain_whip_b_down_right.png`
- [x] `marlonx_a_chain_whip_b_up_right.png`
- [!] `marlonx_a_chain_ultimate_spin_down_right.png` - 2 intentos: los pies cambian de postura en el giro (pose 4); se guarda el 2º
- [x] `marlonx_a_chain_ultimate_spin_up_right.png`


## Revisión de Claude (2026-09-28) — segunda ronda
Revisadas las 99 entregadas: **76 aceptadas y ya están en el juego**. **23 rechazadas** (vuelven a `[ ]`; las anteriores
se movieron a `referencias_animacion/_rechazadas/`, no las uses como referencia). Quedan además las 29 que no se habían hecho.

Casi todas las rechazadas fallaron por lo mismo: en vistas **`_up` / `_up_right` (de espaldas)** el personaje sale de frente
o se le ve la cara, las gafas o el carnet. Para esas hojas, **añade al final del prompt este refuerzo**:

`CRITICAL VIEW RULE: the character is seen FROM BEHIND (back view, turned slightly to the right for _up_right). We see the back of the head (hair only), the back of the polo and the back of the jeans. NO face, NO eyes, NO glasses, NO ID card, NO lanyard card visible in ANY of the 4 poses. If the second image shows a front view, ignore its orientation and only copy its style and size.`

Otras rechazadas:
- `wadrid_walk_b_down_right`: el cuerpo sale más girado de lado que la caminata actual; debe tener EXACTAMENTE el mismo ángulo 3/4 de frente que la Imagen 2.
- `marlonx_a_guerrero_attack_b_up`: la regla desaparece en una pose; el arma debe verse en las 4.

Si una rechazada vuelve a fallar 2 veces, márcala `[!]` y sigue (no pasa nada: el juego usa la versión anterior).

## Notas de grokbot

**Estado final (2026-09-28, ~16:00):** las 128 hojas están cerradas. Quedan 108 [x] y 20 [!]. Todas las hojas nuevas están en `_entregas_runway/` y no se tocó código, `assets/`, `scenes/` ni `scripts/`.

### Ronda 2 (tras la revisión de Claude)
- Se rehicieron las 23 RECHAZADAS con la CRITICAL VIEW RULE en las vistas `_up` y `_up_right`. Nunca se usaron como referencia los archivos de `_rechazadas/`.
- `wadrid_walk_b_down_right` salió con el mismo ángulo 3/4 que la Imagen 2, y `marlonx_a_guerrero_attack_b_up` tiene la regla en las 4 poses.
- También se repitieron con la regla las cuatro `_up_right` de F4 (P106, P108, P110, P112).
- Nuevas [!] de esta ronda:
  - `marlonx_a_chain_parry_up_right`: el carnet se ve de espaldas en los dos intentos.
  - `wadrid_idle_anim_up`: los dos intentos salieron de frente sin cara (se nota el cuello de la camisa). Se guardó el 2º.

### F5 (16 hojas down_right/up_right de ataque, cast, látigo y giro)
- La Imagen 2 salió de las hojas F4 aceptadas. Para P082, P092 y P102 se usaron las [!] que Claude dio por buenas.
- Salieron bien 12: P113, P116–P120, P122, P124–P126, P128.
- Quedaron [!] 4, con el intento menos malo guardado:
  - `wadrid_guerrero_attack_b_up_right`: el 1º no tiene regla en la pose 2 y el 2º sale de frente con carnet. Se guardó el 1º.
  - `wadrid_mago_cast_b_down_right`: el 1º tiene el bastón duplicado y el 2º estelas en las poses 2-3. Se guardó el 2º.
  - `marlonx_a_guerrero_attack_b_down_right`: falta la goma en la pose 2.
  - `marlonx_a_mago_cast_b_down_right`: hay estela en la pose 3 y un bastón duplicado en la pose 4.
- Pasó a [!] una hoja más: `marlonx_a_chain_ultimate_spin_down_right`. En la pose 4 cambia la postura de los pies (la del 1º intento cambiaba más).

### Patrones observados
- El fallo más común con diferencia es la vista de espaldas que sale con cara, gafas, carnet o cordón, o directamente de frente.
- La CRITICAL VIEW RULE mejoró mucho las `_up_right`. La mayoría pasó a la primera o a la segunda.
- En `idle_anim_up` sigue fallando: Gemini tiende a dibujar al personaje de frente sin cara.
- En ataques y casts de 3/4 los fallos típicos son estelas de movimiento, arma duplicada o goma ausente en alguna pose.
- Las [!] que ya estaban antes y Claude aceptó se dejaron tal cual.

- 2026-09-28 (noche) - rehechas las 3 rechazadas en la revisión final, con CRITICAL VIEW RULE y sin referencias de `_rechazadas/`:
  - `marlonx_a_chain_parry_up_right`: [x] al 1.er intento. Espalda en las 4 poses, sin cara, gafas ni carnet (solo la cinta azul y una etiqueta pequeña en el cuello).
  - `marlonx_a_chain_whip_up_right`: [x] al 1.er intento. Espalda girada a la derecha, sin carnet; el cable va en la mano derecha.
  - `wadrid_idle_anim_up`: [x] al 2.º intento. El 1.º volvió a salir de frente con cara en blanco y carnet; el 2.º (con una línea extra "BACK VIEW ONLY" al inicio) sale de espaldas con el afro cubriendo toda la cabeza.
  - Checklist tras esto: 111 [x], 17 [!], 0 [ ].


## Revisión final de Claude (2026-09-29)
- Ronda 2: 50 hojas revisadas → 47 aceptadas e implementadas; 3 rechazadas (movidas a `_rechazadas/` con sufijo `_r2`):
  `marlonx_a_chain_parry_up_right` y `marlonx_a_chain_whip_up_right` (carnet visible de espaldas), `wadrid_idle_anim_up` (sale de frente sin cara).
- Total en el juego: 123 de 128 hojas de pulido. Las 3 rechazadas usan la versión anterior (el juego cae a la dirección de 4 más cercana o a la respiración de 1 px).
- Opcional (si se quiere el 100 %): rehacer esas 3 con la CRITICAL VIEW RULE. Para `wadrid_idle_anim_up` conviene usar como Imagen 2 `wadrid_walk_up` y pedir "back of the head covered by the afro, no skin visible on the head".

- 2026-09-29 (Claude): las 3 rehechas revisadas y ACEPTADAS; escala medida (chain_parry_up_right x1.2, chain_whip_up_right x1.08, idle_anim_up x1.0). Además se revisaron 2 que habían quedado sin revisar: marlonx_a_mago_special_up_right ACEPTADA (x1.2) y marlonx_a_mago_parry_up_right RECHAZADA (poses 2-3 de frente con gafas y carnet; movida a _rechazadas/ con sufijo _r3; el juego usa la vista de espaldas normal). Resultado: 127 de 128 hojas en el juego.
