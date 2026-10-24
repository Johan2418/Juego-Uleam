extends Node
## Pantallas de VICTORIA y DERROTA: el personaje derrotado se queda en el suelo y la pantalla aparece.
## Uso: [xvfb-run] godot --path . res://ztest/end_test.tscn -- [boss] [frames] [2p]
const ArenaScript := preload("res://scripts/combat/boss_arena.gd")
var capture := false
var _frame := 0
var _cap := 0
var _res: Array = []

func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	capture = args.has("frames")
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ztest/frames_end/"))
	if args.has("2p"):
		GameState.setup_coop(true, -1, 0)
	else:
		GameState.setup_coop(false)
	var kind := "deadbeef"
	for a in args:
		if a in ["deadbeef", "bsod", "div0", "syntax", "stack", "judge", "tex", "kp", "sudo"]:
			kind = a
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred(kind)

func _process(_d: float) -> void:
	_frame += 1
	if capture and _frame % 2 == 0:
		var img := get_viewport().get_texture().get_image()
		if img:
			img.resize(960, 540)
			img.save_jpg("res://ztest/frames_end/f_%05d.jpg" % _cap, 0.85)
			_cap += 1

func _check(n: String, ok: bool) -> void:
	_res.append(ok)
	print(("PASS " if ok else "FAIL ") + n)

func _start(kind: String) -> Node:
	ArenaScript.boss_kind = kind
	ArenaScript.retry = true
	get_tree().change_scene_to_file("res://scenes/combat/boss_test.tscn")
	await get_tree().create_timer(0.5).timeout
	var arena := get_tree().current_scene
	while not bool(arena.get("_fighting")):
		await get_tree().create_timer(0.2).timeout
	return arena

func _run(kind: String) -> void:
	# DERROTA
	var arena: Node = await _start(kind)
	await get_tree().create_timer(0.5).timeout
	for p in arena.get("players"):
		p.set("hp", 1)
		p.set("_iframes_left", 0.0)
		p.set("invulnerable", false)
		p.call("take_hit", 5, (p as Node2D).global_position + Vector2(20, 0), true)
	await get_tree().create_timer(6.0).timeout
	_check("derrota: termina", bool(arena.get("_over")))
	var es: Node = arena.get("_end_screen")
	_check("derrota: pantalla nueva", es != null and is_instance_valid(es) and bool(es.call("input_ready")))
	for p in arena.get("players"):
		var a := String((p.get("anim") as AnimatedSprite2D).animation)
		_check("derrota: el personaje sigue en el suelo (%s)" % a, a.begins_with("dead") and bool(p.get("_knocked_down")) and int(p.get("hp")) <= 0)
	# VICTORIA
	arena = await _start(kind)
	await get_tree().create_timer(0.5).timeout
	var boss: Node = arena.get("boss")
	boss.call("pause_ai")
	arena.set("_hits_taken", 3)
	boss.emit_signal("defeated")
	await get_tree().create_timer(4.0).timeout
	var es2: Node = arena.get("_end_screen")
	_check("victoria: pantalla nueva", es2 != null and is_instance_valid(es2) and bool(es2.get("win")) and str(es2.get("rank")) == "A")
	await get_tree().create_timer(1.0).timeout
	print("RESUMEN: %d pruebas, %d fallos" % [_res.size(), _res.count(false)])
	get_tree().quit()
