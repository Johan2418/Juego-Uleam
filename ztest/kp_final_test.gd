extends Node
## Bot del duelo final de KERNEL PANIC con el GUERRERO caminando (sin correr ni rodar): va a la cámara
## encendida con los controles y le pega. Debe poder romper las 8 a tiempo.
## Uso: godot --headless --fixed-fps 60 --path . res://ztest/kp_final_test.tscn -- [run]
const ArenaScript := preload("res://scripts/combat/boss_arena.gd")
const Epic := preload("res://scripts/combat/epic_fx.gd")
var _arena: Node
var _boss: Node
var _cd := 0.0
var _min_left := INF
var _logged := {}
var _spot := {}

func _ready() -> void:
	GameState.setup_coop(false)
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()

func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)

func _physics_process(delta: float) -> void:
	if _boss == null or not is_instance_valid(_boss) or str(_boss.get("state")) != "final":
		return
	var pl: Node2D = _arena.get("player")
	pl.set("hp", 10)
	_cd -= delta
	var tgt: Variant = _boss.get("_final_target")
	_release_all()
	if tgt == null or not is_instance_valid(tgt):
		return
	_min_left = minf(_min_left, float(_boss.get("_final_left")))
	if not _logged.has(tgt):
		_logged[tgt] = true
		_spot.erase(tgt)
		print("  cámara en %s, jugador en %s, dist %.0f, tiempo %.2f" % [(tgt as Node2D).global_position, pl.global_position, pl.global_position.distance_to((tgt as Node2D).global_position), float(_boss.get("_final_total"))])
	if float(_boss.get("_final_left")) < 0.1 and not _logged.has("x%d" % tgt.get_instance_id()):
		_logged["x%d" % tgt.get_instance_id()] = true
		print("  se acaba: jugador en %s (dist %.0f)" % [pl.global_position, pl.global_position.distance_to((tgt as Node2D).global_position)])
	var cam := tgt as Node2D
	if not _spot.has(cam):
		var hurt := cam.global_position + Vector2(0, -28)
		var away := (pl.global_position - hurt).normalized()
		_spot[cam] = hurt + away * 40.0 + Vector2(0, 20)
	var spot: Vector2 = _spot[cam]
	var to := spot - pl.global_position
	if to.length() > 18.0:
		if to.x > 12.0:
			Input.action_press("move_right")
		elif to.x < -12.0:
			Input.action_press("move_left")
		if to.y > 12.0:
			Input.action_press("move_down")
		elif to.y < -12.0:
			Input.action_press("move_up")
	elif _cd <= 0.0:
		_cd = 0.35
		var cc: Node = pl.get("class_controller")
		var aim := (cam.global_position + Vector2(0, -40) - pl.global_position).normalized()
		pl.call("_update_facing", aim)
		cc.call("set_facing", aim)
		cc.call("try_primary")


func _run() -> void:
	ArenaScript.boss_kind = "kp"
	ArenaScript.retry = true
	get_tree().change_scene_to_file("res://scenes/combat/boss_test.tscn")
	await get_tree().create_timer(0.5).timeout
	_arena = get_tree().current_scene
	while not bool(_arena.get("_fighting")):
		await get_tree().create_timer(0.2).timeout
	_boss = _arena.get("boss")
	print("clase: ", (_arena.get("player").get("class_controller")).get("class_id"))
	Epic.EpicAuto.v = 1
	_boss.call("_start_final")
	var t := 0.0
	var fails := 0
	while not bool(_arena.get("_over")) and t < 90.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		if str(_boss.get("state")) != "final" and int(_boss.get("_final_hits")) < 8 and not bool(_arena.get("_over")):
			fails += 1
			break
	_release_all()
	print(("PASS" if bool(_arena.get("_over")) else "FAIL") + " kp: duelo final con el guerrero caminando (%.1f s, cortes %d, tiempo mínimo que sobró %.2f s)" % [t, int(_boss.get("_final_hits")), _min_left])
	Epic.EpicAuto.v = 0
	get_tree().quit()
