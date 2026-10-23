extends Node
## Bot de multijugador contra los bosses: 2 jugadores se mueven por la arena y golpean; revisa que el boss
## cambie de objetivo, que el daño le llegue a los DOS, que un caído se levante con el compañero al lado y
## que se pierda solo si caen los dos. Uso: godot --headless --fixed-fps 60 --path . res://ztest/coop_boss_test.tscn -- [boss ...] [1p]

const ArenaScript := preload("res://scripts/combat/boss_arena.gd")
const ORDER := ["deadbeef", "bsod", "div0", "syntax", "stack", "judge", "tex", "kp", "sudo"]
var FIGHT_TIME := 45.0

var _results: Array = []
var _kinds: Array = []
var _solo := false


func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	_solo = args.has("1p")
	for a in args:
		if ORDER.has(a):
			_kinds.append(a)
	if _kinds.is_empty():
		_kinds = ORDER.duplicate()
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func _check(name: String, ok: bool) -> void:
	_results.append([name, ok])
	print(("PASS " if ok else "FAIL ") + name)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	if _solo:
		GameState.setup_coop(false)
	else:
		GameState.setup_coop(true, -1, 0)
		var a2 := CharacterAppearance.new()
		a2.look_preset = 1
		a2.class_id = "mago"
		GameState.appearance2 = a2
	for kind in _kinds:
		await _fight(kind)
	var fails := _results.filter(func(r: Array) -> bool: return not r[1]).size()
	print("RESUMEN: %d pruebas, %d fallos" % [_results.size(), fails])
	get_tree().quit()


func _fight(kind: String) -> void:
	ArenaScript.boss_kind = kind
	ArenaScript.retry = true
	get_tree().change_scene_to_file("res://scenes/combat/boss_test.tscn")
	await _wait(0.5)
	var arena := get_tree().current_scene
	var t := 0.0
	while not bool(arena.get("_fighting")) and t < 15.0:
		await _wait(0.25)
		t += 0.25
	_check("%s: empieza la pelea" % kind, bool(arena.get("_fighting")))
	var players: Array = arena.get("players")
	var n := 1 if _solo else 2
	_check("%s: %d jugador(es)" % [kind, n], players.size() == n)
	var boss: Node2D = arena.get("boss")
	var targets := {}
	var hit := {}
	var last_hp := {}
	for p in players:
		last_hp[p] = int(p.get("hp"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	t = 0.0
	var move_t := 0.0
	var phased := 0
	while t < FIGHT_TIME and not bool(arena.get("_over")):
		await _wait(0.1)
		t += 0.1
		move_t -= 0.1
		if not is_instance_valid(boss):
			break
		if (phased == 0 and t > 15.0) or (phased == 1 and t > 30.0):
			phased += 1
			boss.call("debug_next_phase")
		var tg: Variant = boss.get("player")
		if tg != null and is_instance_valid(tg):
			targets[tg] = true
		for p in players:
			if not is_instance_valid(p):
				continue
			var hp := int(p.get("hp"))
			if hp < int(last_hp[p]):
				hit[p] = true
			if hp <= 4 and not bool(p.get("coop_ko")):
				p.set("hp", 10)
				p.emit_signal("hp_changed", 10, 10)
				hp = 10
			last_hp[p] = hp
		if move_t <= 0.0:
			move_t = 1.4
			var ar: Rect2 = arena.get("ARENA")
			for p in players:
				if is_instance_valid(p) and not bool(p.get("coop_ko")) and not (p as Node).has_meta("epic_puppet"):
					var at := boss.global_position + Vector2(rng.randf_range(-260, 260), rng.randf_range(80, 260))
					at.x = clampf(at.x, ar.position.x + 40, ar.end.x - 40)
					at.y = clampf(at.y, ar.position.y + 60, ar.end.y - 40)
					(p as Node2D).global_position = at
					var cc: Node = p.get("class_controller")
					if cc and rng.randf() < 0.6:
						cc.call("set_facing", ((boss.global_position - at).normalized()))
						cc.call("try_primary")
	_check("%s: sin terminar por error (%.0f s)" % [kind, t], t >= FIGHT_TIME - 0.2 or bool(arena.get("_over")))
	if not _solo:
		_check("%s: el boss cambió de objetivo (%d)" % [kind, targets.size()], targets.size() >= 2)
		_check("%s: el daño le llegó a los dos (%d/2)" % [kind, hit.size()], hit.size() >= 2)
		if not bool(arena.get("_over")):
			var p2: Node2D = players[1]
			var p1: Node2D = players[0]
			for p in players:
				Engine.time_scale = 1.0
				if (p as Node).has_meta("epic_puppet"):
					await _wait(1.5)
			p2.set("hp", 1)
			p2.set("_iframes_left", 0.0)
			p2.set("invulnerable", false)
			p2.set("_shield_left", 0.0)
			p2.call("take_hit", 5, p2.global_position + Vector2(10, 0), true)
			await _wait(0.2)
			_check("%s: el P2 queda caído" % kind, bool(p2.get("coop_ko")))
			_check("%s: no se pierde con uno caído" % kind, not bool(arena.get("_over")))
			var rv := 0.0
			while bool(p2.get("coop_ko")) and rv < 4.0:
				p1.global_position = p2.global_position + Vector2(30, 0)
				await _wait(0.1)
				rv += 0.1
			_check("%s: el compañero lo levanta (%.1f s)" % [kind, rv], not bool(p2.get("coop_ko")))
			for p in players:
				p.set("hp", 1)
				p.set("_iframes_left", 0.0)
				p.set("invulnerable", false)
				p.set("_shield_left", 0.0)
				p.set("_ult_active", false)
				p.set("rolling", false)
				p.call("take_hit", 5, (p as Node2D).global_position + Vector2(10, 0), true)
			await _wait(0.4)
			_check("%s: los dos caídos = derrota" % kind, bool(arena.get("_over")))
	Engine.time_scale = 1.0
	await _wait(0.3)
