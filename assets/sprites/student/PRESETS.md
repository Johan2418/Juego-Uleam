# Character presets (Runway Agent ×20)

Canvas: **128×192** RGBA. Front view only. Shared NN scale + common foot baseline.

| id | file | label (ES) | suggested traits |
|----|------|------------|------------------|
| 00 | `variants/preset_00.png` | Gorra roja + camisa | gorra roja, camisa azul clara, pantalón azul |
| 01 | `variants/preset_01.png` | Chaqueta negra | chaqueta negra, look formal casual |
| 02 | `variants/preset_02.png` | Traje azul | traje / blazer azul, corbata |
| 03 | `variants/preset_03.png` | Traje negro | traje negro formal |
| 04 | `variants/preset_04.png` | Jersey deportivo | jersey rojo/blanco, shorts |
| 05 | `variants/preset_05.png` | Pelo rubio punta | pelo rubio en punta, camisa |
| 06 | `variants/preset_06.png` | Coleta negra | coleta / pelo recogido negro |
| 07 | `variants/preset_07.png` | Pelo castaño | pelo castaño corto (sheet sin trenza visible al frente) |
| 08 | `variants/preset_08.png` | Pelo gris | pelo gris / canoso |
| 09 | `variants/preset_09.png` | Mochila | mochila, camisa base |
| 10 | `variants/preset_10.png` | Afro / rizado grande | afro / rizado voluminoso naranja |
| 11 | `variants/preset_11.png` | Bufanda | bufanda rayada |
| 12 | `variants/preset_12.png` | Chaleco utilitario | chaleco utilitario / cargo |
| 13 | `variants/preset_13.png` | Pelo naranja rizado | pelo naranja rizado / desordenado |
| 14 | `variants/preset_14.png` | Hoodie rojo | hoodie rojo con cordones |
| 15 | `variants/preset_15.png` | Piel oscura + camisa | piel más oscura, camisa, pelo corto |
| 16 | `variants/preset_16.png` | Overalls / peto | peto verde, botas |
| 17 | `variants/preset_17.png` | Impermeable amarillo | impermeable amarillo |
| 18 | `variants/preset_18.png` | Coletas rubias | coletas / dos colas rubias |
| 19 | `variants/preset_19.png` | Gafas | gafas redondas, camisa base |

## Notes
- Uniform scale derived from tallest + widest front (median height reference, fit-to-canvas)
- Foot margin from canvas bottom: `3px` (all feet_y = 189 on 192 canvas)
- Contact sheet: `_previews/presets_contact.png`
- Per-preset 3× NN previews: `_previews/preset_XX.png`
- `default.png` and `base.png` ← `preset_00.png`
- Old base backed up as `base_old_camisa.png`
- Special handling: sheets **05** and **14** detected as denser `2×4` grids (projection isolate TL)
- Sheet **18** widest front (coletas) limited global scale via max width
- Label **07** adjusted from “Trenza larga” — front crop is short brown hair

| 20 | `variants/preset_20.png` / `wadrid.png` | Wadrid | polo verde, afro, gafas, credencial |
| 21 | `variants/preset_21.png` / `marlonx_a.png` | MarlonX-a | polo negro/gris, gafas, credencial |
