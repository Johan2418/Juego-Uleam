extends Node
## Bot del duelo final de MISSING TEXTURE: el personaje mira en 4 direcciones (como un jugador con
## teclado) hacia el fantasma y hace parry cuando lo ve tocarlo. Debe ganar el duelo.
const ArenaScript := preload("res://scripts/combat/boss_arena.gd")
const Epic := preload("res://scripts/combat/epic_fx.gd")
var _arena: Node
var _done := {}
var _parries := 0
var _seen := {}

func _ready() -> void:
	GameState.setup_coop(false)
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()

func _physics_process(_d: float) -> void:
	if _arena == null or not is_instance_valid(_arena):
		return
	var pl: Node2D = _arena.get("player")
	if pl == null:
		return
	pl.set("hp", 10)
	for s in get_tree().get_nodes_in_group("final_shot"):
		var sh := s as Node2D
		if sh == null or bool(sh.get("back")) or _done.has(sh):
			continue
		if not _seen.has(sh):
			# el jugador se acomoda un poco de lado mientras viene (el fantasma no lo sigue)
			_seen[sh] = true
			var v: Vector2 = (sh.get("vel") as Vector2).normalized()
			pl.global_position += v.orthogonal() * 38.0
		var body := pl.global_position + Vector2(0, -32)
		var d := sh.global_position.distance_to(body)
		var sp: float = (sh.get("vel") as Vector2).length()
		# pulsa cuando el fantasma (grande) ya "toca" al personaje en pantalla
		if d < 58.0 + sp * 0.07:
			_done[sh] = true
			_parries += 1
			var to := sh.global_position - pl.global_position
			# 4 direcciones, como un jugador con flechas
			var four := Vector2(signf(to.x), 0) if absf(to.x) > absf(to.y) else Vector2(0, signf(to.y))
			pl.call("_update_facing", four)
			var cc: Node = pl.get("class_controller")
			cc.call("set_facing", four)
			cc.call("try_parry")

func _run() -> void:
	ArenaScript.boss_kind = "tex"
	ArenaScript.retry = true
	get_tree().change_scene_to_file("res://scenes/combat/boss_test.tscn")
	await get_tree().create_timer(0.5).timeout
	_arena = get_tree().current_scene
	while not bool(_arena.get("_fighting")):
		await get_tree().create_timer(0.2).timeout
	var boss: Node = _arena.get("boss")
	Epic.EpicAuto.v = 1
	boss.call("_start_final")
	var t := 0.0
	while not bool(_arena.get("_over")) and t < 60.0 and str(boss.get("state")) == "final":
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	while not bool(_arena.get("_over")) and t < 70.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	print(("PASS" if bool(_arena.get("_over")) else "FAIL") + " tex: duelo final ganado con parry en 4 direcciones (%.1f s, parrys %d, devueltos %d)" % [t, _parries, int(boss.get("_final_hits"))])
	Epic.EpicAuto.v = 0
	get_tree().quit()
