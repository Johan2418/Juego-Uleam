extends Node
## Bot de los CLÍMAX (QTE) de los duelos finales: para cada boss llama al "ganaste el duelo"
## con los QTE perdiéndose solos (debe volver a la pelea) y luego ganándose solos (debe morir).
## Revisa además que el personaje se haya movido hasta el boss (sin teletransporte).
## Uso: godot --headless --fixed-fps 60 --path . res://ztest/climax_test.tscn -- [boss ...] [frames] [2p]

const ArenaScript := preload("res://scripts/combat/boss_arena.gd")
const Epic := preload("res://scripts/combat/epic_fx.gd")
const ORDER := ["deadbeef", "div0", "syntax", "stack", "judge", "tex", "kp"]
const WON := {"syntax": "_exam_won", "judge": "_final_win"}

var _results: Array = []
var _kinds: Array = []
var capture := false
var _frame := 0
var _cap := 0
var _max_step := 0.0
var _last_pos := {}


func _process(_d: float) -> void:
	_frame += 1
	if capture and _frame % 2 == 0:
		var img := get_viewport().get_texture().get_image()
		if img:
			img.resize(960, 540)
			img.save_jpg("res://ztest/frames_climax/f_%05d.jpg" % _cap, 0.85)
			_cap += 1


func _physics_process(_d: float) -> void:
	# el paso más grande que da un jugador en un cuadro (para detectar teletransportes)
	for p in get_tree().get_nodes_in_group("player"):
		var pos: Vector2 = (p as Node2D).global_position
		if _last_pos.has(p):
			_max_step = maxf(_max_step, pos.distance_to(_last_pos[p]))
		_last_pos[p] = pos


func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	capture = args.has("frames")
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ztest/frames_climax/"))
	for a in args:
		if ORDER.has(a):
			_kinds.append(a)
	if _kinds.is_empty():
		_kinds = ORDER.duplicate()
	if args.has("2p"):
		GameState.setup_coop(true, -1, 0)
	else:
		GameState.setup_coop(false)
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func _check(name: String, ok: bool) -> void:
	_results.append([name, ok])
	print(("PASS " if ok else "FAIL ") + name)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	for kind in _kinds:
		await _one(kind)
	Epic.EpicAuto.v = 0
	var fails := _results.filter(func(r: Array) -> bool: return not r[1]).size()
	print("RESUMEN: %d pruebas, %d fallos" % [_results.size(), fails])
	get_tree().quit()


func _start(kind: String) -> Node:
	ArenaScript.boss_kind = kind
	ArenaScript.retry = true
	get_tree().change_scene_to_file("res://scenes/combat/boss_test.tscn")
	await _wait(0.5)
	var arena := get_tree().current_scene
	var t := 0.0
	while not bool(arena.get("_fighting")) and t < 15.0:
		await _wait(0.25)
		t += 0.25
	return arena


func _one(kind: String) -> void:
	var won: String = WON.get(kind, "_final_won")
	if not capture:
		var arena: Node = await _start(kind)
		var boss: Node = arena.get("boss")
		boss.call("_interrupt")
		boss.set("state", "final")
		Epic.EpicAuto.v = -1
		boss.call(won)
		await _wait(7.0)
		_check("%s: QTE fallado -> sigue vivo" % kind, is_instance_valid(boss) and str(boss.get("state")) != "dead" and not bool(arena.get("_over")))
		var pl: Node2D = arena.get("player")
		_check("%s: QTE fallado -> devuelve el control" % kind, pl.is_physics_processing() and not pl.has_meta("epic_puppet"))
	var arena2: Node = await _start(kind)
	var boss2: Node2D = arena2.get("boss")
	var pl2: Node2D = arena2.get("player")
	# el personaje empieza lejos, abajo a la izquierda
	pl2.global_position = Vector2(-380, 260)
	boss2.call("_interrupt")
	boss2.set("state", "final")
	await _wait(0.3)
	_last_pos.clear()
	_max_step = 0.0
	var attacks := [0]
	(pl2.get("class_controller") as Node).connect("attack_started", func(_k: String) -> void: attacks[0] += 1)
	Epic.EpicAuto.v = 1
	boss2.call(won)
	var t := 0.0
	var min_d := INF
	while not bool(arena2.get("_over")) and t < 30.0:
		await _wait(0.1)
		t += 0.1
		if is_instance_valid(boss2) and is_instance_valid(pl2):
			min_d = minf(min_d, pl2.global_position.distance_to(boss2.global_position))
	_check("%s: QTE ganados -> victoria (%.1f s)" % [kind, t], bool(arena2.get("_over")))
	_check("%s: el personaje fue hasta el boss (%.0f px)" % [kind, min_d], min_d < 190.0 or kind == "stack" or (kind == "judge" and min_d < 300.0))
	_check("%s: sin teletransporte (paso máx %.0f px)" % [kind, _max_step], _max_step < 30.0)
	# en los QTE de machacar, un golpe por pulsación (el bot pulsa ~16 veces por segundo)
	_check("%s: golpes del personaje en el clímax: %d" % [kind, attacks[0]], attacks[0] >= (8 if kind in ["deadbeef", "div0", "stack", "tex", "kp"] else 2))
	Epic.EpicAuto.v = 0
	Engine.time_scale = 1.0
	await _wait(0.5 if not capture else 1.5)
