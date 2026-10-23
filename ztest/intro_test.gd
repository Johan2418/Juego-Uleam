extends Node
## Intro de los bosses con la tarjeta épica: revisa que suene el grito y que empiece la pelea.
## Uso: [xvfb-run] godot --path . res://ztest/intro_test.tscn -- [boss ...] [frames]
const ArenaScript := preload("res://scripts/combat/boss_arena.gd")
const ORDER := ["deadbeef", "bsod", "div0", "syntax", "stack", "judge", "tex", "kp", "sudo"]
var capture := false
var _frame := 0
var _cap := 0
var _res: Array = []

func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	capture = args.has("frames")
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ztest/frames_intro/"))
	var kinds: Array = args.filter(func(a: String) -> bool: return ORDER.has(a))
	if kinds.is_empty():
		kinds = ORDER.duplicate()
	GameState.setup_coop(false)
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred(kinds)

func _process(_d: float) -> void:
	_frame += 1
	if capture and _frame % 2 == 0:
		var img := get_viewport().get_texture().get_image()
		if img:
			img.resize(960, 540)
			img.save_jpg("res://ztest/frames_intro/f_%05d.jpg" % _cap, 0.85)
			_cap += 1

func _run(kinds: Array) -> void:
	for k in kinds:
		ArenaScript.boss_kind = k
		ArenaScript.retry = false
		get_tree().change_scene_to_file("res://scenes/combat/boss_test.tscn")
		await get_tree().create_timer(0.5).timeout
		var arena := get_tree().current_scene
		var t := 0.0
		while not bool(arena.get("_fighting")) and t < 30.0:
			await get_tree().create_timer(0.25).timeout
			t += 0.25
		var ok := bool(arena.get("_fighting")) and bool(arena.get("_roared"))
		_res.append(ok)
		print(("PASS" if ok else "FAIL") + " %s: intro + grito + tarjeta (%.1f s)" % [k, t])
		await get_tree().create_timer(0.8).timeout
	print("RESUMEN: %d pruebas, %d fallos" % [_res.size(), _res.count(false)])
	get_tree().quit()
