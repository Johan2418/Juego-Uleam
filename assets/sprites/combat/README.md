# Combat sprites (Marlon shared set)

All combat walk/attack animations currently use the **Marlon-like** Runway sheets
(glasses + polo + lanyard). The look chosen in the character creator still shows
in the HUD; body animation is shared until per-look sheets exist.

## Canvas
- Target canvas: **128×192** RGBA
- Feet near bottom (`FOOT_PAD ≈ 8`)
- Nearest-neighbor downscale from sheet cells
- Background: mint green removed via **edge flood** only (no HSV body recolor)

## Layout
```
walk/{front,back,right,left}_0..3.png
guerrero/attack_0..n.png
guerrero/guard_0..n.png
guerrero/guard_idle.png
mago/cast_0..n.png
mago/melee_0..n.png
mago/projectile.png
chain/whip_short_0..n.png   # secondary reuses same frames (slower + longer hitbox)
```

## Source sheets used
| Role | Source |
|------|--------|
| Walk 4-dir | `runway_2gen1/raw` thumbs/02 |
| Mago cast + projectile | thumbs/00 |
| Mago melee | thumbs/04 |
| Chain whip | thumbs/01 |
| Guerrero attack | `runway_anim_check/named/19_00.png` |
| Guerrero guard | `19_10.png` (bottom-row guard poses; jacket look) |

Re-slice: `tools/slice_combat_sheets.py`

See also `NEEDS_FROM_USER.md`.
