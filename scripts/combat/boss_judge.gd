extends CharacterBody2D
## Boss 6 403 FORBIDDEN (Facultad de Ciencias Sociales, Derecho y Bienestar): juez robot que flota en su estrado,
## con toga, peluca de juez sobre un monitor viejo, un mazo gigante y la balanza de la justicia.
## Lo único: LA EVIDENCIA. Tiene un escudo 403 (ACCESO DENEGADO) que deja pasar un cuarto del daño.
## Tras cada ataque cae una prueba en la arena; con 3 pruebas lo llevas a juicio: golpea el mazo y lanza
## un sello DENEGADO. Parry al sello = ¡OBJECIÓN!: se rompe el escudo y queda aturdido 4 s con daño x2.
## Fallar = pierdes las pruebas y castigo. En la fase 3 lanza dos sellos.
## Versión de prueba con figuras de código; cuando lleguen las hojas de grokbot (bosses/judge/) se cambian por sprites.
## Sin class_name: cargar con preload.

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Epic := preload("res://scripts/combat/epic_fx.gd")
const Barrage := preload("res://scripts/combat/boss_barrage.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Fx := preload("res://scripts/combat/boss_judge_fx.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")
const Final := preload("res://scripts/combat/boss_final.gd")
const Roar := preload("res://scripts/combat/boss_roar.gd")

signal hp_changed(hp: int, max_hp: int)
signal phase_changed(phase: int, title: String)
signal stunned
signal staggered
signal intro_finished
signal defeated

const MAX_HP := 90
const PHASE_AT := [0.6, 0.3]
const MOVE_SPEED := 75.0
const KEEP_DIST := 230.0
const PAUSE := [1.15, 0.9, 0.7]
const POISE := [9, 12, 15]
const ENRAGE_AT := 0.12
const PHASE_NAMES := ["AUDIENCIA PRELIMINAR", "JUICIO ORAL", "SENTENCIA"]
const COMBOS := {
	2: [["borders", "books"], ["live", "market"], ["crime", "folders"]],
	3: [["borders", "books", "market"], ["live", "market"], ["crime", "folders"], ["books", "live"]],
}

# La Evidencia
## Juicio por fase: [espera tras lanzar, velocidad, parry preciso (s, 0 = normal), curva, lado (-1/0/1), amago]
## Fase 1: un sello. Fase 2: tres seguidos, hay que hacerles parry a TODOS. Fase 3: cinco más rápidos,
## con ritmo irregular, un amago, curvas y parry preciso.
const TRIAL_PLAN := {
	1: [[0.0, 330.0, 0.0, 0.0, 0, false]],
	2: [[0.75, 380.0, 0.0, 0.0, 0, false], [0.75, 380.0, 0.0, 0.0, -1, false], [0.0, 390.0, 0.0, 0.0, 1, false]],
	3: [[0.55, 440.0, 0.17, 0.0, -1, false], [0.9, 0.0, 0.0, 0.0, 0, true], [0.5, 440.0, 0.17, 70.0, 1, false],
		[0.8, 450.0, 0.17, 0.0, 0, false], [0.6, 450.0, 0.17, 80.0, -1, false], [0.0, 460.0, 0.17, 0.0, 1, false]],
}
## Duelo final (OBJECIÓN FINAL): cuántas veces hay que devolverle el sello en el peloteo.
const FINAL_RALLY := 6
const NEED := 3
const SHIELD_DIV := 4
const GUILTY_TIME := 4.0

# pies en y 0
const SHOULDER_L := Vector2(-64, -186)
const SHOULDER_R := Vector2(64, -186)
const CORE := Vector2(0, -142)
const HEAD := Vector2(0, -204)
const CENTER := Vector2(0, -130)
const ARM_LEN := 100.0
# con sprites (se mide al recortar boss_judge_body_0)
const SPR_SHOULDER_L := Vector2(-47, -163)   # hombreras redondas de la toga
const SPR_SHOULDER_R := Vector2(57, -167)
const SPR_CORE := Vector2(13, -147)          # hueco del pecho (el cuerpo mira un poco a la derecha)
const SPR_HEAD := Vector2(5, -186)           # cuello
const REST_L := 0.3
const REST_R := -0.3

var hp: int = MAX_HP
var phase: int = 1
var state: String = "intro"
var arena_rect: Rect2 = Rect2(-500, -310, 1000, 620)
var player: CharacterBody2D
## Núcleo expuesto (daño x2). Mismo nombre que en los otros bosses para que la arena lo cuente.
var tank_open: bool = false
var enraged: bool = false

var shield: bool = true
var evidence: int = 0
var trials_won: int = 0
var trials_lost: int = 0
var guilty_left: float = 0.0
var _chip_acc: int = 0
var _seals_left: int = 0
var _seal_fail: bool = false
var _seal_done: int = 0
## Duelo final
var final_victory: bool = false
var _rally_n: int = 0
var _rally_fail: bool = false
var _rally_done: bool = false
var _swing_tw: Tween

var _tok: int = 0
var _cd: float = 1.0
var _last: String = ""
var _queue: Array[String] = []
var _near_t: float = 0.0
var _poise: int = 0
var _t: float = 0.0
var _tweens: Array[Tween] = []
var _pose_tw: Tween
var rig_off: Vector2 = Vector2.ZERO
var panel: CasePanel
var _holo: Holo
var _home: Dictionary = {}

var rig: Node2D
var bench: Part
var robe: Part
var core: Part
var head: Part
var gavel: Part
var hand: Part


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	z_index = 1
	collision_layer = 3
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(150, 30)
	shape.shape = r
	shape.position = Vector2(0, -15)
	add_child(shape)
	var hurt := Area2D.new()
	hurt.name = "Hurtbox"
	hurt.collision_layer = 2
	hurt.collision_mask = 0
	hurt.monitoring = false
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(160, 280)   # flota: el estrado se puede golpear también desde abajo
	hs.shape = hr
	hs.position = Vector2(0, -112)
	hurt.add_child(hs)
	add_child(hurt)
	GameFeel.add_shadow(self, Vector2(0, -2), Vector2(84, 15))
	_build_rig()


func set_player(p: CharacterBody2D) -> void:
	player = p


## La arena llama esto: el expediente reemplaza la barra de vida.
func build_hud(layer: CanvasLayer) -> void:
	panel = CasePanel.new()
	panel.boss = self
	panel.position = Vector2(340, 8)
	layer.add_child(panel)


# --- Piezas ----------------------------------------------------------------------

func _build_rig() -> void:
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)
	var spr := has_sprites()
	bench = _part("bench", Vector2.ZERO)
	robe = _part("robe", Vector2.ZERO)
	core = _part("core", SPR_CORE if spr else CORE)
	gavel = _part("gavel", SPR_SHOULDER_L if spr else SHOULDER_L)
	hand = _part("hand", SPR_SHOULDER_R if spr else SHOULDER_R)
	head = _part("head", SPR_HEAD if spr else HEAD)
	gavel.rotation = REST_L
	hand.rotation = REST_R
	var sh := ShieldFx.new()
	sh.boss = self
	sh.position = Vector2(0, -120)
	rig.add_child(sh)
	_holo = Holo.new()
	_holo.position = Vector2(0, -310)
	rig.add_child(_holo)


func _part(kind: String, pos: Vector2) -> Part:
	var p := Part.new()
	p.kind = kind
	p.name = kind
	p.position = pos
	p.boss = self
	p.use_parent_material = true
	rig.add_child(p)
	_home[p] = pos
	return p


static func has_sprites() -> bool:
	return Spr.tex("boss_judge_body_0") != null


func _parts() -> Array:
	return [bench, robe, core, gavel, hand, head]


func _say(text: String, col: Color = Color(1, 0.85, 0.4), time: float = 1.1) -> void:
	if _holo:
		_holo.show_text(text, col, time)


# --- Bucle ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	if state != "dead":
		var bob := sin(_t * 1.8) * 4.0 - 8.0
		rig.position = rig_off + Vector2(0, bob)
		head.anim_off = head.anim_off.lerp(Vector2(0, sin(_t * 1.8 - 0.7) * 1.5), minf(1.0, delta * 8.0))
		gavel.anim_rot = sin(_t * 1.5) * 0.05 if state == "idle" else 0.0
		hand.anim_rot = sin(_t * 1.5 + 1.2) * 0.05 if state == "idle" else 0.0
		if enraged:
			var k := 0.75 + 0.25 * absf(sin(_t * 9.0))
			rig.modulate = Color(1.0, k, k * 0.6)
		else:
			rig.modulate = Color.WHITE
		if guilty_left > 0.0:
			guilty_left -= delta
	if _player_ok():
		z_index = 3 if _player_feet().y < global_position.y else 1
	match state:
		"idle":
			_ai_move(delta)
			if _player_ok() and _player_feet().distance_to(global_position) < 150.0:
				_near_t += delta
			else:
				_near_t = maxf(0.0, _near_t - delta)
			_cd -= delta
			if _cd <= 0.0:
				_choose_attack()
		_:
			velocity = Vector2.ZERO


func _ai_move(_delta: float) -> void:
	if not _player_ok():
		return
	var to := player.global_position - global_position
	var dist := to.length()
	var dir := Vector2.ZERO
	if dist > KEEP_DIST + 30.0:
		dir = to.normalized()
	elif dist < KEEP_DIST - 80.0:
		dir = -to.normalized() * 0.6
	velocity = dir * MOVE_SPEED * (1.0 + 0.2 * (phase - 1))
	move_and_slide()
	rig.skew = lerpf(rig.skew, clampf(velocity.x / 800.0, -0.05, 0.05), 0.1)
	_clamp_inside()


func _clamp_inside() -> void:
	global_position.x = clampf(global_position.x, arena_rect.position.x + 100.0, arena_rect.end.x - 100.0)
	global_position.y = clampf(global_position.y, arena_rect.position.y + 340.0, arena_rect.end.y - 30.0)


func _choose_attack() -> void:
	CoopBoss.retarget(self)
	var pick := ""
	if shield and evidence >= NEED:
		pick = "trial"
	elif not _queue.is_empty():
		pick = _queue.pop_front()
	elif _near_t > 1.3:
		pick = "slam"
	elif phase >= 2 and randf() < (0.3 if phase == 2 else 0.45):
		var list: Array = COMBOS[phase]
		_queue.assign(list[randi() % list.size()])
		pick = _queue.pop_front()
	else:
		var pool: Array[String] = ["live", "borders", "books", "crime"]
		if phase >= 2:
			pool.append_array(["market", "folders"])
		var bag: Array[String] = []
		for a in pool:
			if a != _last:
				bag.append(a)
		pick = bag[randi() % bag.size()]
	if pick != "trial":
		_near_t = 0.0
		_last = pick
	_tok += 1
	state = "attack"
	velocity = Vector2.ZERO
	call("_atk_" + pick, _tok)


func _end_attack(tok: int, drops: bool = true) -> void:
	if tok != _tok:
		return
	state = "idle"
	_rest_pose()
	_rest_arms()
	head.mood = 0
	if drops and shield:
		_spawn_evidence()
	_cd = PAUSE[phase - 1] * (0.6 if enraged else 1.0)
	if not _queue.is_empty():
		_cd = 0.2


# --- Utilidades -----------------------------------------------------------------

## Multijugador: jugador que se está revisando en un `for v in _victims()` (el daño es para todos).
var _victim: Node2D = null


func _victims() -> Array:
	return CoopBoss.targets(get_tree()) if is_inside_tree() else []


func _who() -> Node2D:
	return _victim if _victim != null else player


func _player_ok() -> bool:
	var w := _who()
	return w != null and is_instance_valid(w)


func _player_body() -> Vector2:
	return _who().global_position + Vector2(0, -32)


func _player_feet() -> Vector2:
	return _who().global_position + Vector2(0, 12)


func _dir_to_player(from: Vector2) -> Vector2:
	if not _player_ok():
		return Vector2.DOWN
	var d := _player_body() - from
	return Vector2.DOWN if d.length() < 0.01 else d.normalized()


func _rot_for(dir: Vector2) -> float:
	return dir.angle() - PI * 0.5


func _tw(node: Object, prop: String, val: Variant, time: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(node, prop, val, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tweens.append(tw)
	return tw


func _wait(time: float, tok: int) -> bool:
	await get_tree().create_timer(time).timeout
	return tok == _tok and is_inside_tree()


func _clamp_arena(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, arena_rect.position.x + 30.0, arena_rect.end.x - 30.0),
		clampf(p.y, arena_rect.position.y + 40.0, arena_rect.end.y - 20.0))


func _add_fx(n: Node2D, at: Vector2) -> void:
	if "boss" in n:
		n.set("boss", self)
	if "player" in n:
		n.set("player", player)
	get_parent().add_child(n)
	n.global_position = at


func _shake(strength: float, time: float) -> void:
	if not _player_ok():
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := cam.create_tween()
	var steps := maxi(1, int(time / 0.03))
	for i in steps:
		var s := strength * (1.0 - float(i) / steps)
		tw.tween_property(cam, "offset", Vector2(randf_range(-s, s), randf_range(-s, s)), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.03)


func _pose(off: Vector2, rot: float, time: float) -> void:
	if _pose_tw and _pose_tw.is_valid():
		_pose_tw.kill()
	_pose_tw = create_tween().set_parallel(true)
	_pose_tw.tween_property(self, "rig_off", off, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tw.tween_property(rig, "rotation", rot, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _rest_pose(time: float = 0.3) -> void:
	_pose(Vector2.ZERO, 0.0, time)


func _rest_arms() -> void:
	_tw(gavel, "rotation", REST_L, 0.3)
	_tw(hand, "rotation", REST_R, 0.3)
	hand.tool = 0


## Color de los efectos épicos de este boss.
func _accent() -> Color:
	return Color(0.9, 0.3, 0.3)


func _impact(at: Vector2, strength: float) -> void:
	_shake(strength, 0.1 + strength * 0.03)
	Epic.big_hit(get_parent(), at, _accent(), strength, "judge", "fxgavel")
	GameFeel.dust(get_parent(), at, int(4 + strength), Vector2.ZERO, 5.0, Vector2(20 + strength * 3.0, 6))
	GameFeel.hit_stop(get_tree(), 0.04)


## Golpe de mazo: levanta y baja el brazo izquierdo.
func _gavel_hit(tok: int, up_time: float = 0.25) -> bool:
	_tw(gavel, "rotation", PI * 0.95, up_time)
	_pose(Vector2(0, -6), -0.03, up_time)
	if not await _wait(up_time + 0.05, tok):
		return false
	_tw(gavel, "rotation", PI * 0.35, 0.07)
	_pose(Vector2(0, 4), 0.02, 0.07)
	if not await _wait(0.08, tok):
		return false
	_impact(global_position + Vector2(-90, 10), 4.0)
	return true


func _warn_zone(at: Vector2, dir: Vector2, reach: float, half_angle: float, life: float) -> void:
	if reach >= 120.0:
		Epic.charge(get_parent(), global_position + CENTER, _accent(), life * 0.85, 110.0, self, CENTER)
	var z := BossFx.TeleZone.new()
	z.dir = dir
	z.reach = reach
	z.half_angle = half_angle
	z.life = life
	_add_fx(z, at)


func _interrupt() -> void:
	_tok += 1
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
	_queue.clear()
	velocity = Vector2.ZERO
	_rest_pose(0.2)
	for p in _parts():
		p.modulate = Color.WHITE
	visible = true
	modulate.a = 1.0


func hurt_player(amount: int, from: Vector2, unblockable: bool = false) -> void:
	if not _player_ok() or state == "dead" or state == "paused":
		return
	_who().call("take_hit", amount, from, unblockable)


# --- La Evidencia -----------------------------------------------------------------

## Cae una prueba en un punto de la arena (lejos del boss, cerca o lejos del jugador según la fase).
func _spawn_evidence(at: Vector2 = Vector2.INF) -> void:
	if not shield or evidence >= NEED:
		return
	var on_floor := get_tree().get_nodes_in_group("judge_evidence").size()
	if evidence + on_floor >= NEED + 1:
		return
	var pos := at
	if pos == Vector2.INF:
		var best := Vector2.ZERO
		for i in 8:
			var cand := Vector2(randf_range(arena_rect.position.x + 60.0, arena_rect.end.x - 60.0), randf_range(arena_rect.position.y + 80.0, arena_rect.end.y - 40.0))
			if cand.distance_to(global_position) < 200.0:
				continue
			if _player_ok():
				var d := cand.distance_to(_player_feet())
				var want := 200.0 if phase == 1 else 340.0
				if absf(d - want) < absf(best.distance_to(_player_feet()) - want) or best == Vector2.ZERO:
					best = cand
			else:
				best = cand
		pos = best if best != Vector2.ZERO else arena_rect.get_center()
	var e := Fx.Evidence.new()
	e.kind = randi() % 4
	e.life = 6.0 if phase < 3 else 4.0
	_add_fx(e, _clamp_arena(pos))


## La llama un esbirro carpeta al romperse.
func drop_evidence(at: Vector2) -> void:
	_spawn_evidence(at)


## La llama la prueba al recogerla.
func evidence_got(_e: Node) -> void:
	if not shield:
		return
	evidence = mini(NEED, evidence + 1)
	_say("PRUEBA %d/%d" % [evidence, NEED], Color(1, 0.9, 0.4), 0.9)
	if evidence >= NEED:
		for n in get_tree().get_nodes_in_group("judge_evidence"):
			n.queue_free()


## EL JUICIO: vuelve al estrado, dos mazazos de ritmo y lanza los sellos de su fase (TRIAL_PLAN).
func _atk_trial(tok: int) -> void:
	_say("¡ORDEN EN LA SALA!", Color(1, 0.85, 0.4), 1.4)
	head.screen = "trial"
	hand.tool = 0
	var spot := Vector2(clampf(global_position.x * 0.3, -140.0, 140.0), arena_rect.position.y + 340.0)
	_tw(self, "global_position", spot, 0.6)
	if not await _wait(0.7, tok):
		return
	var plan: Array = TRIAL_PLAN[clampi(phase, 1, 3)]
	_seal_fail = false
	_seal_done = 0
	var sent := 0
	for i in 2:
		if not await _gavel_hit(tok, 0.3):
			return
		if not await _wait(0.25, tok):
			return
	if phase >= 2:
		_say("¡%d SELLOS! PARRY A TODOS" % plan.filter(func(x): return not x[5]).size(), Color(1, 0.6, 0.3), 1.2)
	for st in plan:
		if _seal_fail:
			break
		if bool(st[5]):
			# amago: levanta el mazo... y no lanza
			_tw(gavel, "rotation", PI * 0.95, 0.2)
			if not await _wait(float(st[0]), tok):
				return
			_tw(gavel, "rotation", REST_L, 0.15)
			continue
		if not await _throw_seal(tok, st):
			return
		sent += 1
		if float(st[0]) > 0.0 and not await _wait(float(st[0]), tok):
			return
	# espera a que todos los sellos resuelvan
	var w := 0.0
	while _seal_done < sent and not _seal_fail and w < 4.0:
		if not await _wait(0.05, tok):
			return
		w += 0.05
	if _seal_fail:
		_clear_seals()
		_objection_denied(tok)
	else:
		_verdict()


## Levanta el mazo y lanza un sello. st = una fila de TRIAL_PLAN.
func _throw_seal(tok: int, st: Array, rally: bool = false) -> bool:
	_tw(gavel, "rotation", PI * 0.95, 0.22)
	if not await _wait(0.25, tok):
		return false
	var from := global_position + Vector2(float(st[4]) * 90.0, -60)
	_tw(gavel, "rotation", _rot_for(_dir_to_player(global_position + SHOULDER_L)), 0.08)
	var seal := Fx.Seal.new()
	seal.vel = _dir_to_player(from) * float(st[1])
	seal.strict = float(st[2])
	seal.wobble = float(st[3])
	seal.rally = rally
	_add_fx(seal, from)
	GameFeel.squash(rig, Vector2(1.04, 0.96), 0.12, 0.0)
	return true


func _clear_seals() -> void:
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		if h is Fx.Seal:
			h.queue_free()


## Lo llama el sello: true si el jugador hizo parry.
func seal_result(parried: bool) -> void:
	_seal_done += 1
	if parried:
		var total: int = TRIAL_PLAN[clampi(phase, 1, 3)].filter(func(x): return not x[5]).size()
		_say("¡OBJECIÓN!" if total <= 1 or state == "final" else "¡OBJECIÓN! %d/%d" % [_seal_done, total], Color(0.4, 1.0, 0.5), 0.9)
		GameFeel.hit_stop(get_tree(), 0.08)
	else:
		_seal_fail = true


## CULPABLE: el escudo se rompe, núcleo expuesto (daño x2).
func _verdict() -> void:
	trials_won += 1
	_interrupt()
	var tok := _tok
	state = "stunned"
	shield = false
	evidence = 0
	tank_open = true
	core.open = true
	head.mood = 2
	head.screen = "guilty"
	guilty_left = GUILTY_TIME
	var v := Fx.Verdict.new()
	get_parent().add_child(v)
	v.global_position = global_position
	_tw(gavel, "rotation", 1.1, 0.3)
	_tw(hand, "rotation", -1.1, 0.3)
	_pose(Vector2(0, 14), 0.07, 0.25)
	_shake(6.0, 0.4)
	GameFeel.flash(rig, 0.3, Color(0.6, 1.0, 0.6))
	GameFeel.parry_burst(get_parent(), global_position + Vector2(0, -130), 60.0)
	stunned.emit()
	var steps := int(GUILTY_TIME / 0.5)
	for i in steps:
		_pose(Vector2(0, 14), 0.06 * (1.0 if i % 2 == 0 else -1.0), 0.45)
		if not await _wait(0.5, tok):
			_shield_back()
			return
	_shield_back()
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.6
	head.mood = 0


func _shield_back() -> void:
	tank_open = false
	core.open = false
	shield = true
	evidence = 0
	guilty_left = 0.0
	if head.screen == "guilty":
		head.screen = ""


## OBJECIÓN DENEGADA: pierde las pruebas y castigo de ondas de mazo.
func _objection_denied(tok: int) -> void:
	trials_lost += 1
	evidence = 0
	head.screen = "denied"
	head.mood = 1
	_say("OBJECIÓN DENEGADA", Color(1, 0.3, 0.25), 1.4)
	GameFeel.flash(rig, 0.25, Color(1, 0.4, 0.3))
	var v := Fx.Verdict.new()
	v.text = "DENEGADO"
	v.col = Color(1, 0.3, 0.25)
	v.life = 1.0
	get_parent().add_child(v)
	v.global_position = global_position
	for i in 2:
		if not await _gavel_hit(tok, 0.2):
			return
		var ring := BossFx.ShockRing.new()
		ring.max_r = 300.0
		_add_fx(ring, global_position)
		if not await _wait(0.35, tok):
			return
	if not await _wait(0.4, tok):
		return
	head.screen = ""
	if state == "final":
		return
	_end_attack(tok, false)


# --- OBJECIÓN FINAL ---------------------------------------------------------------
## Al quedar a un golpe en la fase 3: serie de sellos y el último se convierte en un peloteo.
## El juez devuelve el sello cada vez más rápido (y la música sube); tras FINAL_RALLY parries
## el sello lo golpea y pierde. Si fallas: OBJECIÓN DENEGADA, vuelve la música de la fase 3
## y la pelea sigue con el juez a 1 PV (el próximo golpe repite el duelo).
func _start_final() -> void:
	_interrupt()
	var tok := _tok
	state = "final"
	shield = true
	tank_open = false
	core.open = false
	evidence = 0
	guilty_left = 0.0
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for h in get_tree().get_nodes_in_group("judge_evidence"):
		h.queue_free()
	head.screen = "trial"
	head.mood = 1
	hand.tool = 0
	var v := Fx.Verdict.new()
	v.text = "OBJECIÓN FINAL"
	v.col = Color(1.0, 0.75, 0.3)
	v.life = 1.4
	get_parent().add_child(v)
	v.global_position = global_position
	GameFeel.flash(rig, 0.35, Color(1, 0.8, 0.4))
	_shake(8.0, 0.6)
	_music_cue("final1")
	var spot := Vector2(0.0, arena_rect.position.y + 340.0)
	_tw(self, "global_position", spot, 0.7)
	_pose(Vector2(0, -10), 0.0, 0.3)
	if not await _wait(1.6, tok):
		return
	_rest_pose()
	# serie como en la fase 3: dos sellos precisos...
	_seal_fail = false
	_seal_done = 0
	for i in 2:
		if not await _gavel_hit(tok, 0.25):
			return
		if not await _wait(0.2, tok):
			return
	var series := [[0.7, 430.0, 0.17, 0.0, -1, false], [0.75, 440.0, 0.17, 60.0, 1, false]]
	for st in series:
		if _seal_fail:
			break
		if not await _throw_seal(tok, st):
			return
		if not await _wait(float(st[0]), tok):
			return
	var w := 0.0
	while _seal_done < series.size() and not _seal_fail and w < 3.0:
		if not await _wait(0.05, tok):
			return
		w += 0.05
	if _seal_fail:
		_clear_seals()
		_final_fail(tok)
		return
	# ...y el último: EL PELOTEO
	_say("¡A VER SI PUEDES CON ESTE!", Color(1, 0.5, 0.3), 1.0)
	if not await _wait(0.3, tok):
		return
	_rally_n = 0
	_rally_fail = false
	_rally_done = false
	if not await _throw_seal(tok, [0.0, 440.0, 0.2, 0.0, 0, false], true):
		return
	w = 0.0
	while not _rally_done and not _rally_fail and w < 40.0:
		if not await _wait(0.05, tok):
			return
		w += 0.05
	if _rally_done:
		_final_win()
	else:
		_clear_seals()
		_final_fail(tok)


## Lo llama el sello del peloteo cuando llega al jugador.
func rally_result(parried: bool) -> void:
	if state != "final":
		return
	if not parried:
		_rally_fail = true
		return
	_rally_n += 1
	_say("¡OBJECIÓN! %d/%d" % [_rally_n, FINAL_RALLY], Color(0.4, 1.0, 0.5), 0.7)
	GameFeel.hit_stop(get_tree(), 0.06 + 0.01 * _rally_n)
	if _rally_n == 2:
		_music_cue("final2")
	elif _rally_n == 4:
		_music_cue("final3")
	if _rally_n >= FINAL_RALLY:
		_brace()
	else:
		_windup()


## ANTICIPACIÓN: mientras el sello vuelve, el juez echa el mazo atrás por encima de la cabeza
## y se inclina hacia atrás, para golpear justo cuando llega.
func _windup() -> void:
	var seal: Node2D = null
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		if h is Fx.Seal and h.rally:
			seal = h
	var travel := 0.3
	if seal:
		var sp: float = maxf(1.0, (seal.get("vel") as Vector2).length())
		travel = seal.global_position.distance_to(global_position + Vector2(0, -130)) / sp
	var up := clampf(travel * 0.75, 0.12, 0.3)
	_kill_swing()
	_swing_tw = create_tween().set_parallel(true)
	_swing_tw.tween_property(gavel, "rotation", PI * 1.05, up).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swing_tw.tween_property(hand, "rotation", -0.9, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose(Vector2(6, -12), -0.08, up)
	head.mood = 1
	head.anim_off += Vector2(4, -3)
	# destello en la cabeza del mazo cuando está listo
	var gl := Glint.new()
	gl.delay = up * 0.8
	gavel.add_child(gl)
	gl.position = Vector2(0, 118)


## El último parry: ya no puede devolverlo. Se cubre asustado.
func _brace() -> void:
	_kill_swing()
	_swing_tw = create_tween().set_parallel(true)
	_swing_tw.tween_property(gavel, "rotation", -0.6, 0.15)
	_swing_tw.tween_property(hand, "rotation", 0.7, 0.15)
	_pose(Vector2(0, -6), -0.1, 0.15)
	head.mood = 2
	_say("¡¿QUÉ?!", Color(1, 0.9, 0.4), 0.6)


func _kill_swing() -> void:
	if _swing_tw and _swing_tw.is_valid():
		_swing_tw.kill()


## El sello vuelve al juez: lo devuelve con el mazo (más rápido cada vez) o, al final, lo golpea.
func rally_back(seal: Node2D) -> void:
	if state != "final" or _rally_fail:
		seal.queue_free()
		return
	if _rally_n >= FINAL_RALLY:
		seal.queue_free()
		GameFeel.parry_burst(get_parent(), global_position + CORE, 90.0)
		_rally_done = true
		return
	_swing(seal)


## EL GOLPE: el mazo baja de golpe en arco hacia el jugador, el cuerpo se lanza adelante,
## estela del mazo, destello de impacto y el sello sale disparado desde la cabeza del mazo.
func _swing(seal: Node2D) -> void:
	var aim := _rot_for(_dir_to_player(gavel.global_position))
	var from_rot := gavel.rotation
	var over := aim + signf(aim - from_rot) * 0.45   # sigue de largo tras el golpe
	_kill_swing()
	gavel.rotation = aim
	# estela del mazo (de donde estaba a donde golpea)
	var arc := SwingArc.new()
	arc.a0 = from_rot + PI * 0.5
	arc.a1 = aim + PI * 0.5
	arc.power = _rally_n
	gavel.get_parent().add_child(arc)
	arc.position = gavel.position
	# cuerpo hacia delante y aplastado por el esfuerzo
	_pose(Vector2(-4, 10), 0.07, 0.06)
	GameFeel.squash(rig, Vector2(1.06, 0.94), 0.16, 0.0)
	head.anim_off += Vector2(-3, 5)
	# impacto en la cabeza del mazo
	var hit_at := gavel.to_global(Vector2(0, 118))
	seal.global_position = hit_at
	var star := ImpactStar.new()
	star.power = _rally_n
	get_parent().add_child(star)
	star.global_position = hit_at
	GameFeel.parry_burst(get_parent(), hit_at, 30.0 + 5.0 * _rally_n)
	GameFeel.hit_stop(get_tree(), 0.05 + 0.008 * _rally_n)
	_shake(3.0 + _rally_n, 0.18)
	_say("¡DENEGADO!", Color(1, 0.35, 0.3), 0.5)
	var speed := 460.0 + 50.0 * _rally_n
	seal.set("strict", maxf(0.13, 0.2 - 0.012 * _rally_n))
	seal.set("wobble", 50.0 if _rally_n % 2 == 1 and _rally_n >= 3 else 0.0)
	seal.call("relaunch", _dir_to_player(hit_at) * speed)
	# seguir de largo y volver a la guardia
	_swing_tw = create_tween()
	_swing_tw.tween_property(gavel, "rotation", over, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tw.tween_interval(0.08)
	_swing_tw.tween_property(gavel, "rotation", lerpf(REST_L, aim, 0.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swing_tw.parallel().tween_property(hand, "rotation", REST_R, 0.3)
	var back := create_tween()
	back.tween_interval(0.12)
	back.tween_callback(func() -> void: _pose(Vector2.ZERO, 0.0, 0.3))


## Ganaste el duelo: el sello lo golpea, ¡CULPABLE! y cae.
func _final_win() -> void:
	# clímax con QTE antes del remate; si se falla, vuelve la fase 3 como al perder el duelo
	if not await _climax():
		_final_fail(_tok)
		return
	final_victory = true
	_music_final("epic")
	GameFeel.flash(rig, 0.5, Color(0.7, 1.0, 0.7))
	await _finisher()
	_shake(12.0, 0.8)
	hp = 0
	hp_changed.emit(hp, MAX_HP)
	_die()


## Perdiste el duelo: OBJECIÓN DENEGADA, vuelve la fase 3 (el juez queda a 1 PV).
func _final_fail(tok: int) -> void:
	_music_cue("p3")
	await _objection_denied(tok)
	if tok != _tok:
		return
	shield = true
	evidence = 0
	state = "idle"
	_cd = 1.2


func _arena() -> Node:
	var a := get_parent()
	return a if a != null and a.has_method("music_cue") else null


func _music_cue(part: String) -> void:
	var a := _arena()
	if a:
		a.call("music_cue", part)


func _music_final(part: String) -> void:
	var a := _arena()
	if a:
		a.call("music_final", part)


# --- Recibir daño ----------------------------------------------------------------

func take_hit(amount: int, from: Vector2) -> void:
	if state in ["intro", "transition", "dead", "paused", "final"]:
		GameFeel.flash(rig, 0.08, Color(0.6, 0.6, 0.7))
		return
	var dmg := amount * (2 if tank_open else 1)
	var center := global_position + CENTER
	var toward := from - center
	toward = Vector2.DOWN if toward.length() < 0.01 else toward.normalized()
	if shield:
		# el escudo 403 deja pasar un cuarto del daño
		_chip_acc += amount
		dmg = _chip_acc / SHIELD_DIV
		_chip_acc = _chip_acc % SHIELD_DIV
		var blk := BossFx.DmgNumber.new()
		blk.text = "403"
		blk.color = Color(1, 0.35, 0.3)
		get_parent().add_child(blk)
		blk.global_position = center + toward * 50.0 + Vector2(0, -30)
		GameFeel.flash(rig, 0.06, Color(1, 0.5, 0.5))
		if dmg <= 0:
			return
	# a un golpe de caer en la fase 3: OBJECIÓN FINAL en vez de morir
	if phase >= 3 and not final_victory and hp - dmg <= 0:
		hp = 1
		hp_changed.emit(hp, MAX_HP)
		_start_final()
		return
	hp = maxi(0, hp - dmg)
	hp_changed.emit(hp, MAX_HP)
	GameFeel.flash(rig, 0.1 + 0.02 * dmg, Color(1.0, 0.95, 0.9))
	GameFeel.squash(rig, Vector2(1.03, 0.97), 0.14, 0.0)
	GameFeel.hit_stop(get_tree(), 0.03 + 0.02 * mini(dmg, 3))
	head.anim_off += -toward * (4.0 + 2.0 * dmg)
	var num := BossFx.DmgNumber.new()
	num.text = str(dmg) + ("!" if tank_open else "")
	num.big = tank_open
	num.color = Color(0.6, 1, 0.6) if tank_open else Color(1, 1, 1)
	get_parent().add_child(num)
	num.global_position = center + toward * 40.0 + Vector2(0, -40)
	if tank_open:
		GameFeel.parry_burst(get_parent(), global_position + CORE, 34.0)
	else:
		var sp := BossFx.Sparks.new()
		sp.dir = toward
		get_parent().add_child(sp)
		sp.global_position = center + toward * 50.0
	if hp <= 0:
		_die()
		return
	if phase < 3 and hp <= int(MAX_HP * PHASE_AT[phase - 1]):
		_enter_phase(phase + 1)
		return
	if phase >= 3 and not enraged and hp <= int(MAX_HP * ENRAGE_AT):
		_enrage()
		return
	if not tank_open and state in ["idle", "attack"] and _last != "trial":
		_poise += dmg
		if _poise >= POISE[phase - 1]:
			_poise = 0
			_stagger()


func pull_toward(_dest: Vector2) -> void:
	GameFeel.flash(rig, 0.06, Color(0.7, 0.7, 0.8))


func debug_next_phase() -> void:
	if state in ["intro", "transition", "dead", "paused", "final"]:
		return
	if phase >= 3:
		hp = 1
		var was := shield
		shield = false
		take_hit(1, global_position)
		shield = was
		return
	hp = int(MAX_HP * PHASE_AT[phase - 1])
	hp_changed.emit(hp, MAX_HP)
	_enter_phase(phase + 1)


func _stagger() -> void:
	_interrupt()
	var tok := _tok
	state = "stunned"
	head.mood = 2
	_say("ERR?", Color(1, 0.8, 0.4))
	_pose(Vector2(0, 8), 0.06 * (1.0 if randf() < 0.5 else -1.0), 0.12)
	GameFeel.flash(rig, 0.2, Color(1, 0.9, 0.6))
	_shake(3.0, 0.2)
	staggered.emit()
	if not await _wait(0.9, tok):
		return
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.5
	head.mood = 0


func _enter_phase(n: int) -> void:
	phase = n
	_interrupt()
	_shield_back()
	var tok := _tok
	state = "transition"
	if n == 2:
		head.wig = 1
		robe.dirty = true
	else:
		head.cracked = true
		robe.dirty = true
		bench.cracked = true
	head.mood = 1
	_say(PHASE_NAMES[n - 1], Color(1, 0.45, 0.3), 1.4)
	GameFeel.flash(rig, 0.3, Color(1.0, 0.3, 0.3))
	_pose(Vector2(0, -12), 0.0, 0.25)
	_shake(7.0, 0.8)
	phase_changed.emit(n, PHASE_NAMES[n - 1])
	if not await _wait(1.6, tok):
		return
	# lluvia de ataques: inmune hasta que termine (esquivar o parry)
	if not await Barrage.run(self, n, tok):
		return
	_rest_pose()
	state = "idle"
	_cd = 0.4
	head.mood = 0


func _enrage() -> void:
	enraged = true
	_interrupt()
	_shield_back()
	var tok := _tok
	state = "transition"
	head.wig = 2
	head.mood = 1
	_say("APELACIÓN DENEGADA", Color(1, 0.3, 0.2), 1.4)
	_pose(Vector2(0, -14), 0.0, 0.3)
	GameFeel.flash(rig, 0.4, Color(1.0, 0.5, 0.3))
	_shake(9.0, 1.0)
	phase_changed.emit(3, "APELACIÓN DENEGADA")
	# la peluca se cae
	var w := WigFall.new()
	get_parent().add_child(w)
	w.global_position = global_position + HEAD + Vector2(0, -40)
	if not await _wait(1.3, tok):
		return
	_rest_pose()
	state = "idle"
	_cd = 0.3
	head.mood = 0


# --- Ataques ---------------------------------------------------------------------------

## 1. Comunicación: EN VIVO. Un foco persigue al jugador; si lo deja quieto, rayo de ÚLTIMA HORA.
func _atk_live(tok: int) -> void:
	_say("¡EN VIVO!", Color(1, 0.35, 0.3))
	hand.tool = 1
	_tw(hand, "rotation", -PI * 0.6, 0.3)
	var s := Fx.Spotlight.new()
	s.life = [4.5, 5.0, 5.5][phase - 1]
	s.lock_need = [1.1, 0.9, 0.75][phase - 1]
	_add_fx(s, _player_feet() if _player_ok() else arena_rect.get_center())
	var t := 0.0
	while t < s.life:
		if not await _wait(0.5, tok):
			return
		t += 0.5
		_tw(hand, "rotation", _rot_for(_dir_to_player(global_position + SHOULDER_R)), 0.3)
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)


## 2. Ciencias Políticas: Fronteras. Sanciones en 3 territorios; la bandera blanca marca el seguro.
func _atk_borders(tok: int) -> void:
	_say("SANCIONES", Color(1, 0.5, 0.3))
	_tw(gavel, "rotation", PI * 0.8, 0.3)
	_tw(hand, "rotation", -PI * 0.8, 0.3)
	_pose(Vector2(0, -8), 0.0, 0.3)
	var rounds: int = [1, 2, 2][phase - 1]
	for r in rounds:
		var b := Fx.Borders.new()
		b.area = arena_rect
		var mine := 0
		if _player_ok():
			var c := arena_rect.get_center()
			var f := _player_feet()
			mine = (0 if f.x < c.x else 1) + (0 if f.y < c.y else 2)
		# el seguro nunca es donde está parado el jugador
		var safe := randi() % 4
		while safe == mine:
			safe = randi() % 4
		b.safe = safe
		b.warn = 1.4 if phase == 1 else 1.2
		_add_fx(b, Vector2.ZERO)
		if not await _wait(b.warn, tok):
			return
		_impact(global_position, 6.0)
		if not await _wait(0.5, tok):
			return
	if not await _wait(0.3, tok):
		return
	_end_attack(tok)


## 3. Criminología: escena del crimen. La cinta encierra al jugador y el láser forense la barre.
func _atk_crime(tok: int) -> void:
	_say("ESCENA DEL CRIMEN", Color(1, 0.85, 0.2))
	hand.tool = 2
	_tw(hand, "rotation", _rot_for(_dir_to_player(global_position + SHOULDER_R)), 0.3)
	var b := Fx.TapeBox.new()
	b.half = 120.0 if phase < 3 else 100.0
	b.scan_time = 1.2 if phase < 3 else 0.9
	_add_fx(b, _player_feet() if _player_ok() else arena_rect.get_center())
	if not await _wait(b.life + 0.2, tok):
		return
	_end_attack(tok)


## 4. Derecho: código penal. Filas de libros de leyes que caen.
func _atk_books(tok: int) -> void:
	_say("CÓDIGO PENAL", Color(0.95, 0.85, 0.6))
	var rows: int = [2, 3, 3][phase - 1]
	var per := 5
	var py := _player_feet().y if _player_ok() else 100.0
	for r in rows:
		if not await _gavel_hit(tok, 0.2):
			return
		var y := clampf(py + (r - rows / 2) * 110.0, arena_rect.position.y + 60.0, arena_rect.end.y - 30.0)
		var x0 := arena_rect.position.x + 80.0
		var step := (arena_rect.size.x - 160.0) / (per - 1)
		var off := randf_range(-40, 40)
		for i in per:
			var bk := Fx.Book.new()
			bk.delay = 0.08 * i
			bk.warn = 0.85 if phase == 1 else 0.7
			_add_fx(bk, _clamp_arena(Vector2(x0 + step * i + off, y)))
		if not await _wait(0.45, tok):
			return
	if not await _wait(1.0, tok):
		return
	_end_attack(tok)


## 5. Economía: oferta y demanda. Líneas en X y el punto de equilibrio que explota.
func _atk_market(tok: int) -> void:
	_say("OFERTA Y DEMANDA", Color(0.6, 0.85, 1.0))
	hand.tool = 0
	_tw(hand, "rotation", -PI * 0.5, 0.3)
	var m := Fx.Market.new()
	m.spin = (0.6 + 0.15 * phase) * (1.0 if randf() < 0.5 else -1.0)
	var at := arena_rect.get_center()
	if _player_ok():
		at = _player_feet().lerp(global_position, 0.5)
	_add_fx(m, at)
	if not await _wait(m.life + 0.5, tok):
		return
	_end_attack(tok)


## 6. Trabajo Social: casos. Carpetas con patas que agarran; rotas sueltan una prueba.
func _atk_folders(tok: int) -> void:
	_say("CASOS PENDIENTES", Color(0.9, 0.75, 0.5))
	hand.tool = 0
	if not await _gavel_hit(tok, 0.3):
		return
	var n: int = [2, 2, 3][phase - 1]
	var have := get_tree().get_nodes_in_group("boss_minion").size()
	for i in mini(n, 4 - have):
		var f := Fx.Folder.new()
		var side := -1.0 if i % 2 == 0 else 1.0
		_add_fx(f, _clamp_arena(global_position + Vector2(side * 150.0, 60.0 + 30.0 * i)))
		GameFeel.dust(get_parent(), f.global_position, 5, Vector2.ZERO, 4.0, Vector2(20, 6))
	if not await _wait(1.0, tok):
		return
	_end_attack(tok)


## Mazazo con onda de choque (si el jugador se queda pegado).
func _atk_slam(tok: int) -> void:
	_say("!!", Color(1, 0.5, 0.3))
	var max_r := 250.0 if phase < 3 else 320.0
	_warn_zone(global_position, Vector2.DOWN, max_r, 0.0, 0.8)
	_tw(gavel, "rotation", PI * 1.0, 0.6)
	_pose(Vector2(0, -30), 0.0, 0.6)
	if not await _wait(0.8, tok):
		return
	_tw(gavel, "rotation", PI * 0.3, 0.07)
	_pose(Vector2(0, 6), 0.0, 0.07)
	_impact(global_position, 9.0)
	var ring := BossFx.ShockRing.new()
	ring.max_r = max_r
	_add_fx(ring, global_position)
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)



# --- Lluvia de cambio de fase propia: DESACATO ---------------------------------------------
## Filas de libros del código penal, sanciones por cuadrantes, ráfagas de sellos DENEGADO (parry o esquivar)
## y el cruce de oferta y demanda en el centro.
func barrage_title(_n: int) -> String:
	return "¡DESACATO!"


func barrage_plan(n: int) -> Array:
	if n == 2:
		return [[0.2, "books", {"rows": 2}], [1.6, "seals", {"n": 3}], [3.0, "borders", {}],
			[4.8, "market", {}], [5.6, "seals", {"n": 3}]]
	return [[0.2, "books", {"rows": 3}], [1.4, "seals", {"n": 5}], [2.8, "borders", {}],
		[4.4, "market", {}], [5.2, "books", {"rows": 2}], [6.4, "seals", {"n": 4}], [7.6, "books", {"rows": 2}]]


func _bfx(n: Node2D, at: Vector2) -> void:
	_add_fx(n, at)
	Barrage.tag(n)


func _bar_books(a: Dictionary, tok: int) -> void:
	var py := _player_feet().y if _player_ok() else 100.0
	var rows: int = a["rows"]
	for r in rows:
		_tw(gavel, "rotation", PI * 0.95, 0.12)
		var y := clampf(py + (r - rows / 2) * 110.0, arena_rect.position.y + 60.0, arena_rect.end.y - 30.0)
		var x0 := arena_rect.position.x + 80.0
		var step := (arena_rect.size.x - 160.0) / 5.0
		var off := randf_range(-40, 40)
		for i in 6:
			var bk := Fx.Book.new()
			bk.delay = 0.07 * i
			bk.warn = 0.75
			_bfx(bk, _clamp_arena(Vector2(x0 + step * i + off, y)))
		_tw(gavel, "rotation", PI * 0.35, 0.06)
		if not await _wait(0.4, tok):
			return


func _bar_seals(a: Dictionary, tok: int) -> void:
	for i in int(a["n"]):
		if not _player_ok():
			return
		var from := global_position + Vector2((i % 3 - 1) * 90.0, -60)
		var seal := Fx.Seal.new()
		seal.vel = _dir_to_player(from) * 380.0
		_bfx(seal, from)
		_tw(gavel, "rotation", PI * 0.95 if i % 2 == 0 else PI * 0.35, 0.08)
		if not await _wait(0.42, tok):
			return


func _bar_borders(_a: Dictionary, _tok: int) -> void:
	var b := Fx.Borders.new()
	b.area = arena_rect
	var mine := 0
	if _player_ok():
		var c := arena_rect.get_center()
		var f := _player_feet()
		mine = (0 if f.x < c.x else 1) + (0 if f.y < c.y else 2)
	var safe := randi() % 4
	while safe == mine:
		safe = randi() % 4
	b.safe = safe
	b.warn = 1.1
	_bfx(b, Vector2.ZERO)


func _bar_market(_a: Dictionary, _tok: int) -> void:
	var m := Fx.Market.new()
	m.spin = 0.9 * (1.0 if randf() < 0.5 else -1.0)
	_bfx(m, arena_rect.get_center() + Vector2(0, 60))


## REMATE: el sello devuelto vuelve gigante como CULPABLE y le cae encima; luego bajan los barrotes de la celda.
func _finisher() -> void:
	var st := Final.StampSlam.new()
	st.text = "CULPABLE"
	st.col = Color(0.85, 0.15, 0.15)
	get_parent().add_child(st)
	st.global_position = global_position
	await get_tree().create_timer(0.36).timeout
	_shake(10.0, 0.4)
	_pose(Vector2(0, 14), 0.07, 0.1)
	head.mood = 2
	head.screen = "guilty"
	var bars := Cell.new()
	add_child(bars)
	bars.position = Vector2(0, -10)
	await get_tree().create_timer(1.0).timeout


## Barrotes de celda que bajan sobre el juez (remate).
class Cell extends Node2D:
	var t := 0.0

	func _ready() -> void:
		z_index = 6

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / 0.35, 0.0, 1.0)
		var top := lerpf(-560.0, -300.0, k * k)
		var a := 1.0 if t < 2.0 else clampf(1.0 - (t - 2.0) / 0.5, 0.0, 1.0)
		for i in 9:
			var x := -110.0 + i * 27.5
			draw_line(Vector2(x, top), Vector2(x, top + 300.0), Color(0.15, 0.15, 0.18, a), 7.0)
			draw_line(Vector2(x - 2, top), Vector2(x - 2, top + 300.0), Color(0.55, 0.55, 0.6, a), 2.0)
		draw_rect(Rect2(-118, top - 8, 236, 12), Color(0.2, 0.2, 0.24, a))
		draw_rect(Rect2(-118, top + 290, 236, 12), Color(0.2, 0.2, 0.24, a))


# --- Aparición y muerte -----------------------------------------------------------

func start_intro(skip: bool) -> void:
	state = "intro"
	if skip:
		await get_tree().create_timer(0.6).timeout
		intro_finished.emit()
		return
	# 1. se apagan las luces y suena "¡De pie!"
	var home := position
	rig.visible = false
	var dark := Dark.new()
	dark.area = arena_rect
	get_parent().add_child(dark)
	dark.global_position = Vector2.ZERO
	await get_tree().create_timer(0.6).timeout
	_say("¡DE PIE!", Color(1, 0.9, 0.6), 1.2)
	_holo.position = Vector2(0, -150)
	await get_tree().create_timer(1.0).timeout
	_holo.position = Vector2(0, -310)
	# 2. el estrado entra flotando desde el fondo
	rig.visible = true
	position = home + Vector2(0, -260)
	modulate.a = 0.0
	var walk := create_tween().set_parallel(true)
	walk.tween_property(self, "position", home, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	walk.tween_property(self, "modulate:a", 1.0, 0.5)
	await get_tree().create_timer(1.55).timeout
	position = home
	dark.fade()
	# 3. tres mazazos y la pantalla muestra 403
	head.screen = "name"
	for i in 3:
		_tw(gavel, "rotation", PI * 0.95, 0.2)
		await get_tree().create_timer(0.22).timeout
		_tw(gavel, "rotation", PI * 0.35, 0.06)
		await get_tree().create_timer(0.08).timeout
		_shake(3.0 + i * 2.0, 0.15)
		GameFeel.dust(get_parent(), global_position + Vector2(-90, 10), 4, Vector2.ZERO, 4.0, Vector2(20, 6))
		await get_tree().create_timer(0.25).timeout
	# 4. firma: SENTENCIA. Señala al acusado, se echa atrás con el mazo bien alto (carga lenta)
	#    y da UN mazazo enorme: el sello 403 cae al suelo y sale una onda dorada.
	head.mood = 1
	_tw(hand, "rotation", 0.95, 0.3)            # señala hacia el jugador
	_tw(gavel, "rotation", PI * 1.12, 0.6)      # mazo muy atrás
	_pose(Vector2(6, -14), 0.07, 0.6)
	_say("¡SILENCIO EN LA SALA!", Color(1, 0.9, 0.6), 0.9)
	await get_tree().create_timer(0.75).timeout
	_tw(gavel, "rotation", PI * 0.18, 0.07)
	_pose(Vector2(-4, 10), -0.06, 0.07)
	await get_tree().create_timer(0.08).timeout
	var slam_at := global_position + Vector2(-70, 14)
	var w := Roar.Waves.new()
	w.col = Color(1, 0.8, 0.35)
	w.count = 3
	w.max_r = 420.0
	Roar.spawn(get_parent(), w, slam_at)
	var st := Final.StampSlam.new()
	st.text = "403"
	st.w = 190.0
	st.fall = 0.14
	st.life = 1.2
	Roar.spawn(get_parent(), st, global_position + Vector2(0, 150))
	_impact(slam_at, 10.0)
	GameFeel.hit_stop(get_tree(), 0.12)
	_say("ACCESO DENEGADO", Color(1, 0.35, 0.3), 1.3)
	await get_tree().create_timer(1.3).timeout
	_rest_pose()
	_rest_arms()
	head.mood = 0
	head.screen = ""
	intro_finished.emit()


func begin_fight() -> void:
	state = "idle"
	_cd = 1.0


func pause_ai() -> void:
	_interrupt()
	state = "paused"
	_free_player()


func _free_player() -> void:
	if _player_ok() and float(player.get("speed_mult")) < 1.0 and float(player.get("speed_mult")) > 0.0:
		player.set("speed_mult", 1.0)


func _die() -> void:
	_interrupt()
	state = "dead"
	tank_open = false
	shield = false
	remove_from_group("enemies")
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for h in get_tree().get_nodes_in_group("judge_evidence"):
		h.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.call("die")
	_free_player()
	Engine.time_scale = 0.2
	head.screen = "closed"
	head.mood = 2
	await get_tree().create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 1.0
	# el mazo se parte y la balanza se inclina del lado del jugador
	gavel.broken = true
	hand.tool = 0
	hand.tilt = 1.0
	var v := Fx.Verdict.new()
	v.text = "CASO CERRADO"
	v.col = Color(0.95, 0.85, 0.5)
	v.life = 2.4
	get_parent().add_child(v)
	v.global_position = global_position
	_pose(Vector2(0, 8), 0.0, 0.4)
	await get_tree().create_timer(2.2).timeout
	# el estrado se desploma soltando papeles
	core.broken = true
	GameFeel.parry_burst(get_parent(), global_position + CORE, 70.0)
	for i in 18:
		var d := BossFx.Debris.new()
		d.kind = i % 8
		d.prefix = "boss_judge_debris_"
		d.vel = Vector2(randf_range(-300, 300), randf_range(-460, -200))
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(randf_range(-60, 60), randf_range(-200, -60))
	for p in [gavel, hand]:
		var tw := create_tween()
		tw.tween_property(p, "rotation", (1.0 if p == gavel else -1.0) * 1.6, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(self, "rig_off", Vector2(0, 26), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(rig, "rotation", -0.1, 0.5)
	_shake(8.0, 0.4)
	GameFeel.dust(get_parent(), global_position, 16, Vector2.ZERO, 7.0, Vector2(90, 10))
	await get_tree().create_timer(1.4).timeout
	create_tween().tween_property(rig, "modulate", Color(0.4, 0.4, 0.45, 0.0), 1.2)
	await get_tree().create_timer(1.0).timeout
	defeated.emit()


# --- Dibujo (provisional, hasta tener los sprites) --------------------------------------

class Part extends Node2D:
	var kind := ""
	var boss: Node
	var t := 0.0
	var anim_off := Vector2.ZERO
	var anim_rot := 0.0
	# estados
	var open := false         # núcleo expuesto
	var broken := false
	var cracked := false
	var dirty := false
	var wig := 0              # 0 bien, 1 torcida, 2 sin peluca
	var screen := ""          # "", name, trial, guilty, denied, closed
	var mood := 0             # 0 normal, 1 enojado, 2 aturdido
	var tool := 0             # mano: 0 balanza, 1 micrófono, 2 lupa
	var tilt := 0.0           # balanza inclinada (muerte)

	const OUT := Color(0.05, 0.05, 0.06)
	const WOOD := Color(0.42, 0.26, 0.15)
	const WOOD_D := Color(0.3, 0.18, 0.1)
	const WOOD_L := Color(0.55, 0.36, 0.2)
	const ROBE := Color(0.1, 0.1, 0.12)
	const ROBE_L := Color(0.2, 0.2, 0.24)
	const GOLD := Color(0.95, 0.75, 0.25)
	const STEEL := Color(0.55, 0.58, 0.62)
	const STEEL_D := Color(0.36, 0.38, 0.42)
	const WIG := Color(0.95, 0.94, 0.9)
	const WIG_D := Color(0.78, 0.76, 0.72)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _box(r: Rect2, col: Color, w: float = 2.0) -> void:
		draw_rect(r, col)
		draw_rect(r, OUT, false, w)

	func _draw() -> void:
		draw_set_transform(anim_off, anim_rot, Vector2.ONE)
		if _draw_sprite():
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		match kind:
			"bench":
				_bench()
			"robe":
				_robe()
			"core":
				_core()
			"head":
				_head()
			"gavel":
				_gavel()
			"hand":
				_hand()

	## Con sprites de grokbot (boss_judge_*). El cuerpo trae estrado y toga juntos.
	func _draw_sprite() -> bool:
		var body := Spr.tex("boss_judge_body_0")
		if body == null:
			return false
		match kind:
			"bench":
				var tx: Texture2D = Spr.tex("boss_judge_body_1") if (cracked or dirty) else body
				if tx == null:
					tx = body
				var bob := sin(t * 2.2) * 2.0
				draw_texture(tx, anim_off + Vector2(-tx.get_width() * 0.5, -tx.get_height() + bob))
				# llamitas de los propulsores
				for x in [-62.0, -36.0, -4.0, 26.0, 50.0]:
					var fl := 4.0 + 3.0 * sin(t * 25.0 + x)
					var p := anim_off + Vector2(x, 2 + bob)
					draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(4, 0), p + Vector2(0, fl)]), Color(0.5, 0.8, 1.0, 0.7))
				return true
			"robe":
				return true
			"core":
				var idx := 2 if broken else (1 if open else 0)
				var tx := Spr.tex("boss_judge_core_%d" % idx)
				if tx == null:
					return false
				if open:
					draw_circle(anim_off, 26.0 + 3.0 * sin(t * 10.0), Color(0.6, 1.0, 0.5, 0.25))
				var off := Vector2(5, 0) if idx == 1 else Vector2.ZERO   # la puerta abierta sobresale a la derecha
				draw_texture(tx, anim_off + off - tx.get_size() * 0.5)
				return true
			"head":
				var idx := 2 if (cracked or wig == 2) else (1 if wig == 1 else 0)
				var tx := Spr.tex("boss_judge_head_%d" % idx)
				if tx == null:
					return false
				var at := anim_off + Vector2(-tx.get_width() * 0.5, -tx.get_height())
				if wig == 2:
					# sin peluca: solo el monitor y el cuello (columnas del centro de la imagen)
					var src := Rect2(22, 15, 42, tx.get_height() - 15)
					draw_texture_rect_region(tx, Rect2(at + src.position, src.size), src)
				else:
					draw_texture(tx, at)
				# la pantalla del monitor: se dibuja en grande y se achica al tamaño del sprite
				var sc := Rect2(anim_off + Vector2(-8, -50), Vector2(27, 24))
				var k := sc.size.x / 62.0
				draw_set_transform(sc.get_center(), anim_rot, Vector2(k, k))
				_screen(Rect2(-31, -27, 62, 54))
				draw_set_transform(anim_off, anim_rot, Vector2.ONE)
				return true
			"gavel", "hand":
				var name := "boss_judge_gavel_%d" % (1 if broken else 0) if kind == "gavel" else "boss_judge_hand_%d" % tool
				var tx := Spr.tex(name)
				if tx == null:
					return false
				var piv := Spr.top_pivot(name)
				var extra := tilt * 0.3 if kind == "hand" else 0.0
				draw_set_transform(anim_off, anim_rot - Spr.lean(name) + extra, Vector2.ONE)
				draw_texture(tx, -piv)
				return true
		return false

	func _bench() -> void:
		# propulsores bajo el estrado
		for s in [-1.0, 1.0]:
			var p := Vector2(55 * s, -6)
			draw_rect(Rect2(p.x - 10, p.y - 6, 20, 8), STEEL_D)
			var fl := 6.0 + 3.0 * sin(t * 25.0 + s)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 2), p + Vector2(7, 2), p + Vector2(0, 2 + fl)]), Color(0.5, 0.8, 1.0, 0.8))
		# estrado
		var r := Rect2(-88, -92, 176, 82)
		_box(r, WOOD, 3.0)
		draw_rect(Rect2(r.position.x - 6, r.position.y - 8, r.size.x + 12, 10), WOOD_L)
		draw_rect(Rect2(r.position.x - 6, r.position.y - 8, r.size.x + 12, 10), OUT, false, 2.0)
		for x in [-60.0, 60.0]:
			draw_rect(Rect2(x - 18, -78, 36, 56), WOOD_D)
			draw_rect(Rect2(x - 18, -78, 36, 56), OUT, false, 1.5)
		# emblema de la balanza
		var e := Vector2(0, -52)
		draw_circle(e, 20, GOLD)
		draw_arc(e, 20, 0, TAU, 20, OUT, 2.0)
		draw_line(e + Vector2(0, -12), e + Vector2(0, 10), WOOD_D, 2.0)
		draw_line(e + Vector2(-12, -8), e + Vector2(12, -8), WOOD_D, 2.0)
		draw_arc(e + Vector2(-12, 0), 5, 0, PI, 8, WOOD_D, 2.0)
		draw_arc(e + Vector2(12, 0), 5, 0, PI, 8, WOOD_D, 2.0)
		# libros apilados y cinta
		for i in 3:
			_box(Rect2(48 - i * 3, -112 - i * 9, 34, 9), [Color(0.6, 0.12, 0.12), Color(0.15, 0.3, 0.55), Color(0.2, 0.45, 0.25)][i], 1.5)
		draw_line(Vector2(-88, -80), Vector2(-96, -40), Color(1, 0.85, 0.15), 4.0)
		if cracked:
			draw_polyline(PackedVector2Array([Vector2(-80, -88), Vector2(-60, -60), Vector2(-70, -30)]), OUT, 2.0)
			draw_polyline(PackedVector2Array([Vector2(70, -90), Vector2(50, -50)]), OUT, 2.0)

	func _robe() -> void:
		# toga negra que sale detrás del estrado
		var pts := PackedVector2Array([Vector2(-50, -196), Vector2(50, -196), Vector2(62, -96), Vector2(-62, -96)])
		draw_colored_polygon(pts, ROBE)
		pts.append(pts[0])
		draw_polyline(pts, OUT, 2.5)
		for x in [-30.0, 30.0]:
			draw_line(Vector2(x, -180), Vector2(x * 1.3, -100), ROBE_L, 2.0)
		# cuello blanco
		draw_colored_polygon(PackedVector2Array([Vector2(-22, -196), Vector2(22, -196), Vector2(8, -176), Vector2(-8, -176)]), Color(0.97, 0.97, 0.95))
		draw_rect(Rect2(-6, -178, 4, 14), Color(0.97, 0.97, 0.95))
		draw_rect(Rect2(2, -178, 4, 14), Color(0.97, 0.97, 0.95))
		# botones dorados
		for i in 2:
			draw_circle(Vector2(0, -116 + i * 12), 3, GOLD)
		# hombreras metálicas y banderitas
		for s in [-1.0, 1.0]:
			_box(Rect2(64 * s - 14, -198, 28, 20), STEEL_D)
			var fp := Vector2(48 * s, -200)
			draw_line(fp, fp + Vector2(0, -50), STEEL, 2.0)
			var fc := Color(0.85, 0.2, 0.2) if s < 0.0 else Color(0.2, 0.4, 0.85)
			var wave := sin(t * 4.0 + s) * 3.0
			draw_colored_polygon(PackedVector2Array([fp + Vector2(0, -50), fp + Vector2(22 * s, -46 + wave), fp + Vector2(0, -36)]), fc)
		if dirty:
			draw_line(Vector2(-40, -150), Vector2(-26, -130), ROBE_L, 3.0)
			draw_line(Vector2(36, -170), Vector2(28, -150), ROBE_L, 3.0)

	func _core() -> void:
		var r := 20.0
		if open:
			draw_circle(Vector2.ZERO, r + 8.0 + 3.0 * sin(t * 10.0), Color(0.6, 1.0, 0.5, 0.25))
			draw_circle(Vector2.ZERO, r, Color(0.2, 0.05, 0.05))
			draw_circle(Vector2.ZERO, r * 0.6, Color(1, 0.25 + 0.15 * sin(t * 12.0), 0.2))
			# puerta de la cerradura abierta a un lado
			draw_circle(Vector2(r + 14, 0), r * 0.8, GOLD.darkened(0.2))
			draw_arc(Vector2(r + 14, 0), r * 0.8, 0, TAU, 16, OUT, 2.0)
			return
		draw_circle(Vector2.ZERO, r, GOLD)
		draw_arc(Vector2.ZERO, r, 0, TAU, 20, OUT, 2.5)
		draw_circle(Vector2.ZERO, r * 0.65, GOLD.darkened(0.15))
		draw_circle(Vector2(0, -3), 4, OUT)
		draw_colored_polygon(PackedVector2Array([Vector2(-3, -1), Vector2(3, -1), Vector2(2, 9), Vector2(-2, 9)]), OUT)
		if broken:
			draw_polyline(PackedVector2Array([Vector2(-16, -12), Vector2(-2, 0), Vector2(-8, 14)]), OUT, 2.5)

	func _head() -> void:
		var g := Vector2(0, -32)
		draw_rect(Rect2(-8, -8, 16, 10), STEEL_D)
		# peluca detrás (rizos a los lados)
		if wig < 2:
			var tiltx := 6.0 if wig == 1 else 0.0
			for s in [-1.0, 1.0]:
				for k in 3:
					var c := g + Vector2(42 * s + tiltx, -12 + k * 14)
					draw_circle(c, 9, WIG)
					draw_arc(c, 9, 0, TAU, 12, WIG_D, 1.5)
		# monitor CRT
		var m := Rect2(g.x - 38, g.y - 30, 76, 60)
		_box(m, Color(0.78, 0.76, 0.7), 2.5)
		var sc := Rect2(m.position + Vector2(7, 7), m.size - Vector2(14, 18))
		_box(sc, Color(0.04, 0.06, 0.08), 1.5)
		draw_rect(Rect2(m.position.x + 10, m.end.y - 9, 10, 4), Color(0.3, 0.8, 0.4))
		if cracked:
			draw_polyline(PackedVector2Array([sc.position + Vector2(8, 4), sc.position + Vector2(20, 18), sc.position + Vector2(14, 30)]), Color(0.7, 0.7, 0.7), 1.5)
		_screen(sc)
		# peluca arriba
		if wig < 2:
			var tiltx2 := 8.0 if wig == 1 else 0.0
			var rot := 0.15 if wig == 1 else 0.0
			for k in 5:
				var c2 := g + Vector2(-32 + k * 16 + tiltx2, -36 - (rot * (k - 2) * 8.0))
				draw_circle(c2, 11, WIG)
				draw_arc(c2, 11, 0, TAU, 12, WIG_D, 1.5)

	## Lo que muestra la pantalla: la cara o un texto.
	func _screen(sc: Rect2) -> void:
		var f := ThemeDB.fallback_font
		var c := sc.get_center()
		match screen:
			"name":
				draw_string(f, Vector2(sc.position.x, c.y - 2), "403", HORIZONTAL_ALIGNMENT_CENTER, sc.size.x, 18, Color(1, 0.3, 0.25))
				draw_string(f, Vector2(sc.position.x, c.y + 12), "FORBIDDEN", HORIZONTAL_ALIGNMENT_CENTER, sc.size.x, 8, Color(1, 0.3, 0.25))
				return
			"trial":
				draw_string(f, Vector2(sc.position.x, c.y + 5), "JUICIO", HORIZONTAL_ALIGNMENT_CENTER, sc.size.x, 12, Color(1, 0.85, 0.4))
				return
			"guilty":
				draw_string(f, Vector2(sc.position.x, c.y + 5), "CULPABLE", HORIZONTAL_ALIGNMENT_CENTER, sc.size.x, 10, Color(0.5, 1, 0.5))
				return
			"denied":
				draw_string(f, Vector2(sc.position.x, c.y + 5), "DENEGADO", HORIZONTAL_ALIGNMENT_CENTER, sc.size.x, 10, Color(1, 0.3, 0.25))
				return
			"closed":
				draw_string(f, Vector2(sc.position.x, c.y + 5), "CERRADO", HORIZONTAL_ALIGNMENT_CENTER, sc.size.x, 11, Color(0.95, 0.85, 0.5))
				return
		var col := Color(1, 0.3, 0.25) if (boss and (boss.get("enraged") or boss.get("shield"))) else Color(0.5, 1, 0.5)
		for s in [-1.0, 1.0]:
			var e := c + Vector2(12 * s, -3)
			match mood:
				1:
					draw_line(e + Vector2(-6 * s, -5), e + Vector2(6 * s, 0), col, 2.5)
					draw_rect(Rect2(e.x - 3, e.y + 1, 6, 4), col)
				2:
					draw_line(e + Vector2(-4, -4), e + Vector2(4, 4), Color(1, 1, 0.5), 2.0)
					draw_line(e + Vector2(4, -4), e + Vector2(-4, 4), Color(1, 1, 0.5), 2.0)
				_:
					if fmod(t, 3.2) > 0.12:
						draw_rect(Rect2(e.x - 5, e.y - 2, 10, 4), col)
		draw_line(c + Vector2(-8, 10), c + Vector2(8, 10), col, 2.0)

	func _arm(len: float) -> void:
		draw_circle(Vector2.ZERO, 13, STEEL_D)
		# manga de toga
		var sl := PackedVector2Array([Vector2(-11, 0), Vector2(11, 0), Vector2(15, len * 0.6), Vector2(-15, len * 0.6)])
		draw_colored_polygon(sl, ROBE)
		sl.append(sl[0])
		draw_polyline(sl, OUT, 2.0)
		_box(Rect2(-6, len * 0.6, 12, len * 0.3), STEEL, 1.5)
		draw_circle(Vector2(0, len * 0.9), 9, STEEL)
		draw_arc(Vector2(0, len * 0.9), 9, 0, TAU, 12, OUT, 1.5)
		draw_arc(Vector2.ZERO, 13, 0, TAU, 14, OUT, 2.0)

	func _gavel() -> void:
		_arm(90.0)
		# mango y cabeza del mazo (horizontal)
		draw_line(Vector2(0, 80), Vector2(0, 112), OUT, 7.0)
		draw_line(Vector2(0, 80), Vector2(0, 112), WOOD_L, 4.0)
		if broken:
			_box(Rect2(-22, 108, 20, 22), WOOD, 2.0)
			return
		_box(Rect2(-26, 108, 52, 24), WOOD, 2.0)
		draw_rect(Rect2(-26, 112, 6, 16), GOLD)
		draw_rect(Rect2(20, 112, 6, 16), GOLD)

	func _hand() -> void:
		_arm(90.0)
		match tool:
			0:   # balanza
				var c := Vector2(0, 100)
				draw_line(c + Vector2(0, -10), c + Vector2(0, 20), GOLD, 3.0)
				var tl := tilt * 0.4 + sin(t * 1.5) * 0.05
				var a := c + Vector2(-26, -4).rotated(tl)
				var b := c + Vector2(26, -4).rotated(tl)
				draw_line(a, b, GOLD, 3.0)
				for p in [a, b]:
					draw_line(p, p + Vector2(-8, 16), GOLD, 1.0)
					draw_line(p, p + Vector2(8, 16), GOLD, 1.0)
					draw_arc(p + Vector2(0, 16), 9, 0, PI, 10, GOLD, 3.0)
			1:   # micrófono de prensa
				_box(Rect2(-4, 92, 8, 22), Color(0.2, 0.2, 0.22), 1.5)
				draw_circle(Vector2(0, 120), 9, Color(0.35, 0.35, 0.38))
				draw_arc(Vector2(0, 120), 9, 0, TAU, 12, OUT, 1.5)
				draw_rect(Rect2(-7, 100, 14, 8), Color(0.85, 0.2, 0.2))
			_:   # lupa
				draw_line(Vector2(0, 92), Vector2(0, 108), WOOD_D, 5.0)
				draw_circle(Vector2(0, 122), 14, Color(0.7, 0.9, 1.0, 0.5))
				draw_arc(Vector2(0, 122), 14, 0, TAU, 16, GOLD, 3.0)


## Holograma rojo del escudo 403 alrededor del boss.
class ShieldFx extends Node2D:
	var boss: Node
	var t := 0.0
	var _a := 1.0

	func _process(delta: float) -> void:
		t += delta
		var on: bool = boss != null and bool(boss.get("shield")) and str(boss.get("state")) != "dead"
		_a = move_toward(_a, 1.0 if on else 0.0, delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		if _a <= 0.01:
			return
		var pts := PackedVector2Array()
		for i in 7:
			var a := TAU * i / 6.0 + PI / 6.0
			pts.append(Vector2(cos(a) * 110.0, sin(a) * 140.0))
		var k := 0.6 + 0.4 * absf(sin(t * 3.0))
		draw_colored_polygon(pts, Color(1, 0.2, 0.15, 0.06 * _a))
		draw_polyline(pts, Color(1, 0.3, 0.25, 0.55 * k * _a), 2.0)
		var f := ThemeDB.fallback_font
		for i in 3:
			var y := -90.0 + i * 70.0 + fmod(t * 20.0, 70.0)
			if absf(y) < 120.0:
				draw_string(f, Vector2(-112, y), "403", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.35, 0.3, 0.45 * _a))
				draw_string(f, Vector2(92, y + 30), "403", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.35, 0.3, 0.45 * _a))


## Luces apagadas de la aparición.
class Dark extends Node2D:
	var area := Rect2(-500, -310, 1000, 620)
	var a := 0.0
	var _fading := false

	func _ready() -> void:
		z_index = 15
		create_tween().tween_property(self, "a", 0.6, 0.4)

	func fade() -> void:
		_fading = true
		var tw := create_tween()
		tw.tween_property(self, "a", 0.0, 0.5)
		tw.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(area.grow(300.0), Color(0, 0, 0, a))


## Peluca que cae al entrar en furia.
class WigFall extends Node2D:
	var t := 0.0
	var vel := Vector2(140, -260)

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		t += delta
		if t < 0.8:
			vel.y += 900.0 * delta
			global_position += vel * delta
			rotation += 6.0 * delta
		if t > 2.5:
			modulate.a = clampf(1.0 - (t - 2.5) / 0.5, 0.0, 1.0)
		if t > 3.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_judge_head_3")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO)
			return
		for k in 5:
			draw_circle(Vector2(-24 + k * 12, 0), 9, Color(0.95, 0.94, 0.9))
			draw_arc(Vector2(-24 + k * 12, 0), 9, 0, TAU, 12, Color(0.78, 0.76, 0.72), 1.5)


## Expediente: reemplaza la barra de vida (vida, fase, pruebas y escudo).
class CasePanel extends Control:
	var boss: Node
	var _chip := 1.0

	func _ready() -> void:
		size = Vector2(600, 74)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if boss == null or not is_instance_valid(boss):
			return
		var k: float = float(boss.get("hp")) / float(boss.get("MAX_HP"))
		_chip = maxf(k, _chip - 0.004) if _chip > k else k
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.78, 0.62, 0.38, 0.95))
		draw_rect(Rect2(0, 0, 120, 10), Color(0.7, 0.54, 0.3))
		if boss == null or not is_instance_valid(boss):
			return
		var f := ThemeDB.fallback_font
		var ink := Color(0.18, 0.12, 0.08)
		var k: float = float(boss.get("hp")) / float(boss.get("MAX_HP"))
		var ph: int = boss.get("phase")
		draw_string(f, Vector2(10, 18), "EXPEDIENTE: 403 FORBIDDEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.08, 0.08))
		var names := ["Audiencia preliminar", "Juicio oral", "Sentencia"]
		var tag: String = names[ph - 1]
		if boss.get("enraged"):
			tag = "APELACIÓN DENEGADA"
		draw_string(f, Vector2(230, 18), "%s · Fase %d/3" % [tag, ph], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		# pruebas
		var ev: int = boss.get("evidence")
		draw_string(f, Vector2(10, 44), "Pruebas:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		for i in 3:
			var cell := Rect2(76 + i * 30, 30, 24, 20)
			draw_rect(cell, Color(0.95, 0.92, 0.82) if i < ev else Color(0.6, 0.48, 0.3))
			draw_rect(cell, ink, false, 1.5)
			if i < ev:
				draw_line(cell.position + Vector2(5, 10), cell.position + Vector2(10, 15), Color(0.15, 0.5, 0.2), 2.5)
				draw_line(cell.position + Vector2(10, 15), cell.position + Vector2(19, 5), Color(0.15, 0.5, 0.2), 2.5)
		# escudo / culpable
		var gl: float = boss.get("guilty_left")
		if bool(boss.get("shield")):
			draw_rect(Rect2(190, 30, 150, 20), Color(0.75, 0.15, 0.12))
			draw_string(f, Vector2(190, 45), "403 ACCESO DENEGADO", HORIZONTAL_ALIGNMENT_CENTER, 150, 11, Color(1, 0.92, 0.85))
			if ev >= 3:
				draw_string(f, Vector2(350, 45), "¡A JUICIO!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.08, 0.08))
		elif gl > 0.0:
			draw_rect(Rect2(190, 30, 150 * clampf(gl / 4.0, 0.0, 1.0), 20), Color(0.25, 0.65, 0.3))
			draw_rect(Rect2(190, 30, 150, 20), ink, false, 1.5)
			draw_string(f, Vector2(190, 45), "CULPABLE x2", HORIZONTAL_ALIGNMENT_CENTER, 150, 12, Color(1, 1, 0.95))
		var w: int = boss.get("trials_won")
		var l: int = boss.get("trials_lost")
		draw_string(f, Vector2(470, 45), "Juicios %d-%d" % [w, l], HORIZONTAL_ALIGNMENT_RIGHT, 120, 12, ink)
		# barra de vida
		draw_rect(Rect2(0, 62, 600, 10), Color(0.3, 0.22, 0.12, 0.9))
		draw_rect(Rect2(0, 62, 600 * _chip, 10), Color(1, 0.95, 0.85))
		draw_rect(Rect2(0, 62, 600 * k, 10), Color(0.6, 0.1, 0.1))
		for fr in [0.6, 0.3]:
			draw_rect(Rect2(600 * fr - 1, 62, 2, 10), Color(0, 0, 0, 0.8))
		draw_rect(r, ink, false, 1.5)


## Cartel sobre la cabeza con el texto del ataque.
class Holo extends Node2D:
	var text := ""
	var col := Color.WHITE
	var t := 9.0
	var dur := 1.1

	func show_text(s: String, c: Color, d: float = 1.1) -> void:
		text = s
		col = c
		dur = d
		t = 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if t > dur or text == "":
			return
		var a := clampf((dur - t) / 0.25, 0.0, 1.0)
		var pop := 1.0 + 0.3 * maxf(0.0, 0.1 - t) / 0.1
		var f := ThemeDB.fallback_font
		var fs := 18
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
		var box := Rect2(-w * 0.5 - 8, -18, w + 16, 26)
		# como una placa de tribunal
		draw_rect(box, Color(0.25, 0.15, 0.08, 0.92 * a))
		draw_rect(box, Color(0.95, 0.75, 0.25, a), false, 2.0)
		draw_string(f, Vector2(-w * 0.5, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, a))


## Estela del mazo al golpear (media luna que se desvanece).
class SwingArc extends Node2D:
	var a0 := 0.0
	var a1 := 1.0
	var power := 0
	var t := 0.0
	const LIFE := 0.2

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		t += delta
		if t > LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := 1.0 - t / LIFE
		var steps := 14
		var pts := PackedVector2Array()
		for i in steps + 1:
			var a := lerpf(a0, a1, float(i) / steps)
			pts.append(Vector2.from_angle(a) * 132.0)
		for i in range(steps, -1, -1):
			var a := lerpf(a0, a1, float(i) / steps)
			var inner := lerpf(132.0, 70.0, float(i) / steps)   # más grueso cerca del final del golpe
			pts.append(Vector2.from_angle(a) * inner)
		var col := Color(1.0, 0.95, 0.75).lerp(Color(1.0, 0.5, 0.3), clampf(power / 6.0, 0.0, 1.0))
		draw_colored_polygon(pts, Color(col, 0.45 * k))
		var edge := PackedVector2Array()
		for i in steps + 1:
			edge.append(Vector2.from_angle(lerpf(a0, a1, float(i) / steps)) * 132.0)
		draw_polyline(edge, Color(1, 1, 1, 0.9 * k), 3.0)


## Estrella de impacto donde el mazo le pega al sello.
class ImpactStar extends Node2D:
	var power := 0
	var t := 0.0
	const LIFE := 0.25

	func _ready() -> void:
		z_index = 8
		rotation = randf() * TAU

	func _process(delta: float) -> void:
		t += delta
		if t > LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := t / LIFE
		var r := (26.0 + 4.0 * power) * (0.6 + k)
		var a := 1.0 - k
		var pts := PackedVector2Array()
		for i in 16:
			var rr := r if i % 2 == 0 else r * 0.35
			pts.append(Vector2.from_angle(TAU * i / 16.0) * rr)
		draw_colored_polygon(pts, Color(1, 1, 0.85, a))
		draw_arc(Vector2.ZERO, r * 1.3, 0, TAU, 24, Color(1, 0.6, 0.3, a), 3.0)


## Brillo en la cabeza del mazo cuando está listo para golpear.
class Glint extends Node2D:
	var delay := 0.1
	var t := 0.0

	func _ready() -> void:
		z_index = 9

	func _process(delta: float) -> void:
		t += delta
		if t > delay + 0.18:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t < delay:
			return
		var k := (t - delay) / 0.18
		var r := 18.0 * sin(k * PI)
		draw_line(Vector2(-r, 0), Vector2(r, 0), Color(1, 1, 0.9, 0.9), 2.0)
		draw_line(Vector2(0, -r), Vector2(0, r), Color(1, 1, 0.9, 0.9), 2.0)
		draw_circle(Vector2.ZERO, r * 0.25, Color(1, 1, 1, 0.9))


# --- CLÍMAX del duelo final (QTE en cámara lenta) -------------------------------------------
## Golpe del clímax a todos los jugadores (si fallan el QTE de defensa).
func _climax_hurt(dmg: int, from: Vector2) -> void:
	for v in _victims():
		_victim = v
		hurt_player(dmg, from, true)
	_victim = null


func _climax_clear() -> void:
	for h in get_tree().get_nodes_in_group("final_shot"):
		h.queue_free()
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()


## Punto delante del boss (del lado de los jugadores) donde se paran a golpearlo en el clímax.
func _front(radius: float) -> Vector2:
	var at := global_position + Vector2(0, 160)
	var vs := _victims()
	if not vs.is_empty():
		at = Vector2.ZERO
		for v in vs:
			at += (v as Node2D).global_position
		at /= vs.size()
	# de frente (abajo del boss), apenas corrido hacia el lado de donde vienen
	var dx := clampf(at.x - global_position.x, -radius * 0.45, radius * 0.45)
	return Epic.melee_spot(self, global_position + Vector2(dx, radius * 2.0), radius, arena_rect)


## Centro de los jugadores (para apuntar lo que se les lanza en el clímax).
func _team_body() -> Vector2:
	var vs := _victims()
	if vs.is_empty():
		return global_position + Vector2(0, 160)
	var at := Vector2.ZERO
	for v in vs:
		at += (v as Node2D).global_position
	return at / vs.size() + Vector2(0, -34)


func _gpos(part: Node2D) -> Vector2:
	return part.global_position if part and is_instance_valid(part) else global_position + CENTER


## ¡OBJECIÓN!: peloteo final: el juez lanza sellos con el mazo al ritmo y el personaje hace parry a cada uno
## (se ven ir y volver); al final, un sello gigante: parry = ¡OBJECIÓN! y se le rompe el escudo.
func _climax() -> bool:
	_climax_clear()
	var p := get_parent()
	var red := Color(1.0, 0.35, 0.3)
	var beats := [1.0, 1.55, 2.0, 2.35, 2.65]
	var flying: Array = []
	var failed := [false]
	var big: Array = [null]
	var seal_tex: Texture2D = Spr.tex("boss_judge_evidence_4")
	var steps := [
		{"mode": "rhythm", "action": "parry", "title": "¡PELOTEO FINAL!", "sub": "Parry a cada sello cuando llegue", "beats": beats,
			"window": 0.17, "col": red,
			"go": func() -> Vector2: return _front(230.0),
			"look": func() -> Vector2: return _gpos(hand),
			"act": "parry",
			"before": func() -> void:
				await get_tree().create_timer(0.3).timeout
				# cada sello sale del mazo y llega al jugador justo en su pulso (tiempo real)
				for bt in beats:
					var when: float = float(bt) - 0.5
					get_tree().create_timer(maxf(0.01, when), true, false, true).timeout.connect(func() -> void:
						if failed[0] or not is_inside_tree():
							return
						_tw(gavel, "rotation", 0.2, 0.06)
						var s := Epic.fly(p, _gpos(hand), _team_body(), 0.5, "", seal_tex, 0.8, 9.0, 40.0)
						flying.append(s)
						s.arrived.connect(func() -> void:
							if failed[0] or not is_instance_valid(s):
								if is_instance_valid(s):
									s.pop()
								return
							GameFeel.parry_burst(p, s.global_position, 26.0)
							s.spin = -12.0
							s.go(_gpos(hand), 0.32, 30.0)
							s.arrived.connect(func() -> void:
								if is_instance_valid(s):
									GameFeel.parry_burst(p, s.global_position, 20.0)
									_tw(gavel, "rotation", PI * 0.95, 0.06)
									s.pop(), CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)),
			"pressed": func() -> void:
				Epic.ring(p, _team_body(), red, 120.0, 0.25, 5.0)
				_shake(2.0, 0.06),
			"fail": func() -> void:
				failed[0] = true
				for s in flying:
					if is_instance_valid(s):
						(s as Epic.Fly).pop()
				_climax_hurt(1, _gpos(hand))},
		{"mode": "timing", "action": "parry", "title": "¡OBJECIÓN!", "sub": "El sello final viene con todo", "dur": 1.0, "col": red,
			"look": func() -> Vector2: return _gpos(core),
			"act": "parry",
			"before": func() -> void:
				_tw(gavel, "rotation", PI * 0.95, 0.25)
				Epic.charge(p, _gpos(hand), red, 0.4, 140.0, hand)
				await get_tree().create_timer(0.45).timeout
				_tw(gavel, "rotation", 0.2, 0.08)
				var s := Epic.fly(p, _gpos(hand), _team_body(), 0.75, "", seal_tex, 1.6, 6.0, 50.0)
				big[0] = s,
			"ok": func() -> void:
				var s: Epic.Fly = big[0]
				GameFeel.parry_burst(p, s.global_position, 44.0)
				s.spin = -16.0
				s.go(_gpos(core), 0.3, 20.0)
				await s.arrived
				s.pop()
				Epic.anim(p, "judge", "fxseal", _gpos(core), 1.4)
				Epic.flash(p, Color(1, 1, 1), 0.5, 0.4)
				Epic.word(p, _gpos(core) + Vector2(0, -90), "¡OBJECIÓN!", red, 64, 1.2)
				Epic.shards(p, _gpos(core), Color(0.5, 0.75, 1.0), 18, 460.0, 9.0)
				Epic.ring(p, _gpos(core), Color.WHITE, 400.0, 0.5, 14.0)
				_shake(9.0, 0.35)
				await get_tree().create_timer(0.4).timeout,
			"fail": func() -> void:
				var s: Epic.Fly = big[0]
				if s and is_instance_valid(s):
					s.pop()
				_climax_hurt(2, _gpos(core))},
	]
	var won := await Epic.climax(self, steps)
	for s in flying:
		if is_instance_valid(s):
			(s as Node).queue_free()
	return won
