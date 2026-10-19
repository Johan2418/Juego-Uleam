# Student sprites — preset swap (Agent ×20)

## Source of truth
- Runway Agent turnaround sheets → `variants/preset_00.png` … `preset_19.png`
- Canvas: **128×192** RGBA, shared NN scale, common foot baseline (~3px margin)
- `default.png` / `base.png` ← `preset_00.png`
- Old base backup: `base_old_camisa.png`

## Preview architecture
`CharacterPreview` loads **complete** sprites from `variants/preset_XX.png`
via `CharacterAppearance.look_preset`. No HSV recolor. No layer composite.

See `PRESETS.md` for Spanish labels and crop notes.
