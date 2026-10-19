# Full-sprite variants (Runway drop zone)

`CharacterPreview` **no longer** composites `outfit/`, `skin/`, `hair/`, or `hair_style/` layers.
Those HSV-recolor composites destroyed silhouettes. Leave them on disk unused.

## How preview works now

Loads **one complete PNG per look**, nearest-neighbor scaled to 224×224.

Lookup order:

1. `variants/{skin}_{hair_style}_{hair_color}_{outfit}_{accessory}.png`
2. `variants/{outfit}_{accessory}.png`
3. `variants/outfit_{outfit}.png`
4. `variants/default.png`
5. `base.png` → `base_preview.png`
6. Thin procedural stub (emergency only)

## New base (2026-09-21 BOT, ~13:17 BOT)

| File | Notes |
|------|-------|
| `base.png` / `ref_new.png` / `ref_new_mint.png` / `ref_new_tight.png` | University student, **camisa** (light-blue button shirt), medium skin, medium brown hair, mint chroma cutout → 64×96 RGBA |
| `variants/default.png` | = base (camisa look) |
| `variants/media_medio_castano_camisa_none.png` | = base (this look IS the new default) |
| `variants/outfit_camisa.png` | = base |

## Seeded / READY (new-base Runway nano-banana-2-lite + careful mint chroma)

| File | Look |
|------|------|
| `media_medio_castano_hoodie_none.png` | same person, hoodie |
| `media_medio_castano_camiseta_none.png` | same person, tee |
| `media_medio_castano_chaqueta_none.png` | same person, jacket |
| `media_medio_castano_lab_glasses.png` | lab coat (+ glasses attempt) |
| `clara_corto_negro_camisa_none.png` | lighter skin, short black hair, camisa |
| `morena_largo_castano_camisa_none.png` | darker skin, long brown hair, camisa |
| `media_medio_rubio_camisa_cap.png` | blonde + cap, camisa |
| `oscura_recogido_azul_hoodie_backpack.png` | dark skin, blue bun, hoodie, backpack |
| `clara_rizado_rosa_camiseta_headphones.png` | fair, curly pink hair, tee, headphones |

Outfit-only fallbacks READY: `outfit_hoodie`, `outfit_camiseta`, `outfit_chaqueta`, `outfit_lab`, `outfit_camisa`.

Processing: edge-flood mint chroma only; enclosed green eye holes painted dark (not HSV body paint); tight bbox + pad; **nearest-neighbor** to 64×96. No stretch, no feather mush, no layer composite.

## IDs (must match `CharacterAppearance`)

- **skin:** `clara` `media` `morena` `oscura`
- **hair_style:** `corto` `medio` `largo` `recogido` `rizado`
- **hair_color:** `negro` `castano` `rubio` `pelirrojo` `azul` `rosa`
- **outfit:** `hoodie` `camiseta` `camisa` `chaqueta` `lab`
- **accessory:** `none` `glasses` `backpack` `cap` `headphones`

## Spec

- Style: top-down chibi university student idle front
- Canvas: 64×96 RGBA after mint removal
- Keep: clear silhouette, 1px dark outline, readable eyes
- Change only requested traits — full redraw via Runway, not HSV paint
