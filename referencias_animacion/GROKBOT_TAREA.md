# TAREA PARA GROKBOT — generar los sprites que faltan (Prototipo Campus)

Eres un agente con acceso a Gemini (generación de imágenes) y a los archivos de este proyecto de Godot.
Tu trabajo: generar **58 hojas de sprites** que faltan para los 2 personajes jugables (Wadrid y MarlonX-a),
guardarlas con el nombre exacto indicado y marcar el progreso en este archivo. **No modifiques código ni otros archivos.**

Raíz del proyecto (donde está `project.godot`): `C:\Users\leopo\Documents\Juegos\Godot\prototipo`
Todas las rutas de abajo son relativas a esa raíz.

## Archivos que vas a usar
| Qué | Ruta |
|---|---|
| Prompts (uno por hoja, copiar tal cual) | `referencias_animacion/PROMPTS_GEMINI.md` → sección **"OPCIÓN A — Una hoja por animación"** (ignora la opción B) |
| Imagen 1 de cada prompt (referencia del personaje) | `referencias_animacion/REF_wadrid/` y `referencias_animacion/REF_marlonx_a/` |
| Imagen 2 de cada prompt (referencia de estilo) | `referencias_animacion/_entregas_runway/` |
| **Dónde guardar cada imagen generada** | `referencias_animacion/_entregas_runway/<nombre de archivo>.png` |
| Registro de progreso | este archivo (lista de abajo) |

En `PROMPTS_GEMINI.md`, cada hoja tiene un bloque así:
```
### Wadrid · derecha (izquierda = espejo)
- Archivo: `wadrid_guerrero_ultimate_right.png`
- Imagen 1: `REF_wadrid/ref_wadrid_derecha_lado.png` · Imagen 2 (estilo): `_entregas_runway/wadrid_guerrero_attack_right.png`
(prompt en un bloque de código)
```
- `REF_...` está dentro de `referencias_animacion/`. `_entregas_runway/...` también.

## Procedimiento por cada hoja pendiente
1. Busca en `PROMPTS_GEMINI.md` (OPCIÓN A) el bloque cuyo **Archivo** coincide con la hoja pendiente.
2. En Gemini, en una **conversación nueva** (para que no mezcle personajes), adjunta **exactamente 2 imágenes en este orden**: Imagen 1 y luego Imagen 2 (estilo).
3. Pega el prompt **completo y sin cambios** (el texto dentro del bloque de código). Si Gemini permite elegir proporción, usa **vertical 3:4**.
4. Revisa el resultado con la **lista de control** (abajo). Si falla, regenera **una vez** con el mismo prompt en una conversación nueva. Si falla de nuevo, marca la hoja como `[!]` con una nota corta y pasa a la siguiente.
5. Descarga la imagen a **resolución completa** y guárdala en `referencias_animacion/_entregas_runway/` con el nombre exacto (minúsculas, guiones bajos). Preferible `.png`; si Gemini solo da `.jpg` o `.webp`, guárdala con esa extensión y el mismo nombre base.
6. Marca la hoja como `[x]` en la lista de progreso de este archivo.
7. **No sobrescribas** ninguna imagen que ya exista en `_entregas_runway/` salvo que sea una de esta lista.

## Lista de control de cada imagen (debe cumplir TODO)
- Fondo verde menta liso (#A0EFA5), sin degradados ni escenario.
- **Exactamente 4 poses** en cuadrícula **2×2**, separadas, sin tocarse entre sí ni los bordes.
- Es el **mismo personaje** que la Imagen 1 (pelo, gafas, polo del color correcto, jeans, zapatos).
  - Wadrid: afro rizado castaño oscuro, polo verde oscuro, zapatos marrones.
  - MarlonX-a: pelo negro corto y liso, polo gris carbón con insignia dorada, zapatos negros.
- **Vista correcta en las 4 poses**: `_right` = de perfil mirando a la derecha; `_down` = de frente; `_up` = de espaldas (sin cara visible).
- Arma correcta según la clase: guerrero = regla amarilla en la mano derecha + borrador rosa atado al antebrazo izquierdo; mago = bastón de rama con cristal azul; chain = cable negro de cargador. En `hurt` = manos vacías.
- Pixel art con contorno negro, mismo estilo y tamaño que la Imagen 2. Sin texto, sin efectos (sin orbes, explosiones ni estelas).
- Las 4 poses siguen el orden descrito en el prompt (arriba-izq, arriba-der, abajo-izq, abajo-der).

## Orden recomendado
Por clase y personaje, en este orden: Guerrero → Mago → Chain → Recibir daño. Dentro de cada una: Wadrid (derecha, abajo, arriba) y luego MarlonX-a (derecha, abajo, arriba).

## Al terminar (o si paras a mitad)
Deja al final de este archivo, en "Notas de grokbot", un resumen: cuántas hechas, cuáles marcaste `[!]` y por qué.
Claude (en Cowork) se encarga después de recortarlas (`tools/slice_character_sheets.py`), revisarlas y programarlas en Godot. **Tú no ejecutes scripts ni toques `assets/`, `scripts/` ni `scenes/`.**

## Progreso (58 pendientes)
Leyenda: `[ ]` pendiente · `[x]` hecha y guardada · `[!]` falló 2 veces (con nota)

### Guerrero · Ultimate (giro 360 con regla gigante)

- [x] `wadrid_guerrero_ultimate_right.png` (guardada como .jpg)
- [x] `wadrid_guerrero_ultimate_down.png` (guardada como .jpg)
- [x] `wadrid_guerrero_ultimate_up.png` (guardada como .jpg)
- [x] `marlonx_a_guerrero_ultimate_right.png` (guardada como .jpg)
- [x] `marlonx_a_guerrero_ultimate_down.png` (guardada como .jpg)
- [x] `marlonx_a_guerrero_ultimate_up.png` (guardada como .jpg)

### Guerrero · Especial K (embestida con borrador)

- [x] `wadrid_guerrero_special_right.png` (ya hecha)
- [x] `wadrid_guerrero_special_down.png` (guardada como .jpg)
- [x] `wadrid_guerrero_special_up.png` (guardada como .jpg)
- [x] `marlonx_a_guerrero_special_right.png` (guardada como .jpg)
- [x] `marlonx_a_guerrero_special_down.png` (guardada como .jpg)
- [x] `marlonx_a_guerrero_special_up.png` (guardada como .jpg)

### Guerrero · Parry L (bloqueo con borrador)

- [x] `wadrid_guerrero_parry_right.png` (ya hecha)
- [x] `wadrid_guerrero_parry_down.png` (guardada como .jpg)
- [x] `wadrid_guerrero_parry_up.png` (guardada como .jpg)
- [x] `marlonx_a_guerrero_parry_right.png` (guardada como .jpg)
- [x] `marlonx_a_guerrero_parry_down.png` (guardada como .jpg)
- [x] `marlonx_a_guerrero_parry_up.png` (guardada como .jpg)

### Mago · Especial K (3 orbes en abanico)

- [x] `wadrid_mago_special_right.png` (guardada como .jpg)
- [x] `wadrid_mago_special_down.png` (guardada como .jpg)
- [x] `wadrid_mago_special_up.png` (guardada como .jpg)
- [x] `marlonx_a_mago_special_right.png` (guardada como .jpg)
- [x] `marlonx_a_mago_special_down.png` (guardada como .jpg)
- [x] `marlonx_a_mago_special_up.png` (guardada como .jpg)

### Mago · Parry L (barrera mágica)

- [x] `wadrid_mago_parry_right.png` (guardada como .jpg)
- [x] `wadrid_mago_parry_down.png` (guardada como .jpg)
- [x] `wadrid_mago_parry_up.png` (guardada como .jpg)
- [x] `marlonx_a_mago_parry_right.png` (guardada como .jpg)
- [x] `marlonx_a_mago_parry_down.png` (guardada como .jpg)
- [x] `marlonx_a_mago_parry_up.png` (guardada como .jpg)

### Mago · Ultimate (explosión en área)

- [x] `wadrid_mago_ultimate_right.png` (guardada como .jpg)
- [x] `wadrid_mago_ultimate_down.png` (guardada como .jpg)
- [x] `wadrid_mago_ultimate_up.png` (guardada como .jpg)
- [x] `marlonx_a_mago_ultimate_right.png` (guardada como .jpg)
- [x] `marlonx_a_mago_ultimate_down.png` (guardada como .jpg)
- [x] `marlonx_a_mago_ultimate_up.png` (guardada como .jpg)

### Chain · Especial K (latigazo largo que atrae)

- [x] `wadrid_chain_special_right.png` (guardada como .jpg)
- [x] `wadrid_chain_special_down.png` (guardada como .jpg)
- [x] `wadrid_chain_special_up.png` (guardada como .jpg)
- [x] `marlonx_a_chain_special_right.png` (guardada como .jpg)
- [x] `marlonx_a_chain_special_down.png` (guardada como .jpg)
- [x] `marlonx_a_chain_special_up.png` (guardada como .jpg)

### Chain · Parry L (cable girando como escudo)

- [x] `wadrid_chain_parry_right.png` (guardada como .jpg)
- [x] `wadrid_chain_parry_down.png` (guardada como .jpg)
- [x] `wadrid_chain_parry_up.png` (guardada como .jpg)
- [x] `marlonx_a_chain_parry_right.png` (guardada como .jpg)
- [x] `marlonx_a_chain_parry_down.png` (guardada como .jpg)
- [x] `marlonx_a_chain_parry_up.png` (guardada como .jpg)

### Chain · Ultimate (torbellino de cable)

- [x] `wadrid_chain_ultimate_right.png` (guardada como .jpg)
- [x] `wadrid_chain_ultimate_down.png` (guardada como .jpg)
- [x] `wadrid_chain_ultimate_up.png` (guardada como .jpg)
- [x] `marlonx_a_chain_ultimate_right.png` (guardada como .jpg)
- [x] `marlonx_a_chain_ultimate_down.png` (guardada como .jpg)
- [x] `marlonx_a_chain_ultimate_up.png` (guardada como .jpg)

### Recibir daño y caer

- [x] `wadrid_hurt_right.png` (guardada como .jpg)
- [x] `wadrid_hurt_down.png` (guardada como .jpg)
- [x] `wadrid_hurt_up.png` (guardada como .jpg)
- [x] `marlonx_a_hurt_right.png` (guardada como .jpg)
- [x] `marlonx_a_hurt_down.png` (guardada como .jpg)
- [x] `marlonx_a_hurt_up.png` (guardada como .jpg)

## Notas de grokbot
Resumen final (27 sep 2026, última hoja resuelta ~3:00 PM). Se procesaron las 58 hojas de la OPCIÓN A en Gemini (cuenta Plus). Cada una en chat nuevo con Imagen 1 (REF) e Imagen 2 (estilo `_entregas_runway/`), prompt sin cambios y relación 3:4. Se rehicieron las 9 `[!]` con prompts ajustados.
- **58 aprobadas** en total (las de este paquete van a `_entregas_runway/` en **.jpg**; el nombre pedido solo cambia la extensión). Todas están copiadas en `_entregas_runway/`.
- **0 marcadas `[!]`**. La hoja 14 (`marlonx_a_guerrero_parry_right`) se resolvió calcando las poses de `wadrid_guerrero_parry_right.png` con MarlonX-a.
- Detalles aceptados sin repetir: carnet visible en algunas espaldas; arcos sutiles en especiales; parry de Mago un poco más alto.
- Intentos fallidos no se copiaron; quedan en la computadora de grokbot.

## Verificación Claude (2026-09-27)
- 58 hojas revisadas y recortadas: 4 frames cada una, ambos personajes. Todas aptas.
- Implementadas en Godot: K especial, L parry, Espacio ultimate, hurt (flinch + knockdown). Probado en headless + capturas.
