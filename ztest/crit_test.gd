extends Node
## Bot del GOLPE CRÍTICO: con el QTE acertado, el personaje debe ir en dash hasta el boss (sin teletransporte),
## golpearlo y devolver el control. Uso: godot --headless --fixed-fps 60 --path . res://ztest/crit_test.tscn -- [boss...] [frames] [2p]
const ArenaScript := preload("res://scripts/combat/boss_arena.gd")
const Epic := preload("res://scripts/combat/epic_fx.gd")
const ORDER := ["deadbeef", "bsod", "div0", "syntax", "stack", "judge", "tex", "kp", "sudo"]
var _res: Array = []
var capture := false
var _frame := 0
var _cap := 0
var _max_step := 0.0
var _last := {}

func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	capture = args.has("frames")
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ztest/frames_crit/"))
	var kinds: Array = args.filter(func(a: String) -> bool: return ORDER.has(a))
	if kinds.is_empty():
		kinds = ORDER.duplicate()
	if args.has("2p"):
		GameState.setup_coop(true, -1, 0)
	else:
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
			img.save_jpg("res://ztest/frames_crit/f_%05d.jpg" % _cap, 0.85)
			_cap += 1

func _physics_process(_d: float) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		var pos: Vector2 = (p as Node2D).global_position
		if _last.has(p):
			_max_step = maxf(_max_step, pos.distance_to(_last[p]))
		_last[p] = pos

func _check(n: String, ok: bool) -> void:
	_res.append(ok)
	print(("PASS " if ok else "FAIL ") + n)

func _run(kinds: Array) -> void:
	for k in kinds:
		ArenaScript.boss_kind = k
		ArenaScript.retry = true
		get_tree().change_scene_to_file("res://scenes/combat/boss_test.tscn")
		await get_tree().create_timer(0.5).timeout
		var arena := get_tree().current_scene
		while not bool(arena.get("_fighting")):
			await get_tree().create_timer(0.2).timeout
		var boss: Node2D = arena.get("boss")
		var pl: Node2D = arena.get("player")
		boss.call("pause_ai")
		boss.set("state", "idle")
		pl.global_position = boss.global_position + Vector2(-260, 230)
		await get_tree().create_timer(0.3).timeout
		var hp0 := int(boss.get("hp"))
		_last.clear()
		_max_step = 0.0
		Epic.EpicAuto.v = 1
		arena.call("_crit_qte")
		var t := 0.0
		var min_d := INF
		while t < 4.0:
			await get_tree().create_timer(0.05).timeout
			t += 0.05
			min_d = minf(min_d, pl.global_position.distance_to(boss.global_position))
		Epic.EpicAuto.v = 0
		_check("%s: el crítico le quita vida (%d -> %d)" % [k, hp0, int(boss.get("hp"))], int(boss.get("hp")) < hp0)
		_check("%s: dash hasta el boss (%.0f px)" % [k, min_d], min_d < 175.0)
		_check("%s: sin teletransporte (paso máx %.0f px)" % [k, _max_step], _max_step < 30.0)
		_check("%s: devuelve el control" % k, pl.is_physics_processing() and pl.is_processing_unhandled_input())
	print("RESUMEN: %d pruebas, %d fallos" % [_res.size(), _res.count(false)])
	get_tree().quit()
