extends CharacterBody2D
## Boss 5 STACK OVERFLOW (Facultad de Ingeniería, Industria y Arquitectura): máquina de obra con orugas,
## cabina de excavadora, casco amarillo de cabeza, grúa en el brazo izquierdo y martillo neumático en el derecho.
## Lo único: LA TORRE. Después de cada ataque apila una pieza (dos en la fase 3) en una torre junto a él.
## Si llega a 8 pisos se desborda: se derrumba sobre la arena hacia el jugador.
## Con 2 pisos o más, 3 golpes a la base agrietada la tumban hacia el boss: si lo alcanza (más pisos = más alcance)
## queda aplastado, con el motor expuesto y daño x2 durante 1,5 s + 0,4 s por piso.
## Versión de prueba con figuras de código; cuando lleguen las hojas de grokbot (bosses/stack/) se cambian por sprites.
## Sin class_name: cargar con preload.

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Barrage := preload("res://scripts/combat/boss_barrage.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Fx := preload("res://scripts/combat/boss_stack_fx.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")
const Final := preload("res://scripts/combat/boss_final.gd")
const Roar := preload("res://scripts/combat/boss_roar.gd")

signal hp_changed(hp: int, max_hp: int)
signal phase_changed(phase: int, title: String)
signal stunned
signal staggered
signal intro_finished
signal defeated

const MAX_HP := 95
const PHASE_AT := [0.6, 0.3]
const MOVE_SPEED := 62.0
const KEEP_DIST := 230.0
const PAUSE := [1.2, 0.95, 0.75]
const POISE := [9, 12, 15]
const ENRAGE_AT := 0.12
const PHASE_NAMES := ["CIMIENTOS", "ESTRUCTURA", "ENTREGA URGENTE"]
const COMBOS := {
	2: [["belts", "gears"], ["blueprint", "ball"], ["poles", "anchor"]],
	3: [["belts", "gears", "ball"], ["blueprint", "ball"], ["poles", "anchor"], ["gears", "blueprint"]],
}

# La Torre
const TOWER_AT := Vector2(-370, 90)       # relativo al centro de la arena (a la izquierda, bajo para que 8 pisos no queden tapados por la barra del jefe)
const CRUSH_BASE := 1.5
const CRUSH_PER_FLOOR := 0.4
## La Torre por fase: F1 como siempre. F2 la torre SE BALANCEA: solo cuentan los golpes a la base cuando
## se inclina hacia el boss (flecha verde). F3 además cada viga de ACERO pide un golpe más (hasta +3).
const SWAY := [0.0, 0.075, 0.085]
const SWAY_SPEED := [0.0, 2.2, 2.8]
## Duelo final RECURSIÓN INFINITA: la torre crece sola hacia el desborde; golpéala al ritmo del balanceo
## (cuando se inclina hacia él) FINAL_LEAN veces para tumbársela encima. A destiempo = un piso más.
const FINAL_LEAN := 5

# pies en y 0
const SHOULDER_L := Vector2(-70, -178)
const SHOULDER_R := Vector2(70, -178)
const GRILLE := Vector2(0, -98)
const HEAD := Vector2(0, -204)
const CENTER := Vector2(0, -120)
const CRANE_LEN := 118.0
const HAMMER_LEN := 100.0
# con sprites (se mide al recortar boss_stack_body_0)
const SPR_SHOULDER_L := Vector2(-60, -123)   # tubo redondo del lado izquierdo de la cabina
const SPR_SHOULDER_R := Vector2(64, -134)
const SPR_GRILLE := Vector2(28, -106)        # hueco negro del frente (la cabina mira un poco a la derecha)
const SPR_HEAD := Vector2(7, -122)           # el casco calza sobre el que ya trae el cuerpo
const SPR_CRANE_LEN := 148.0
const REST_L := 0.25
const REST_R := -0.25

var hp: int = MAX_HP
var phase: int = 1
var state: String = "intro"
var arena_rect: Rect2 = Rect2(-500, -310, 1000, 620)
var player: CharacterBody2D
## El motor queda expuesto (daño x2). Mismo nombre que en los otros bosses para que la arena lo cuente.
var tank_open: bool = false
var enraged: bool = false

var tower: Fx.Tower
var _stack_due: int = 0
var crushes: int = 0
var overflows: int = 0
var crush_left: float = 0.0
var crush_total: float = 1.0
var final_victory: bool = false
var _lean_lv: int = 0
var _final_fail: bool = false

var _tok: int = 0
var _cd: float = 1.0
var _last: String = ""
var _queue: Array[String] = []
var _near_t: float = 0.0
var _poise: int = 0
var _t: float = 0.0
var _tweens: Array[Tween] = []
var _pose_tw: Tween
var _charging: bool = false
var _charge_cd: float = 0.0
var _anchor: Fx.Anchor
var _anchor_res: int = 0      # 0 nada, 1 enganchó, 2 parry
var rig_off: Vector2 = Vector2.ZERO
var panel: PlanPanel
var _holo: Holo
var _home: Dictionary = {}

var rig: Node2D
var tracks: Part
var cab: Part
var grille: Part
var head: Part
var crane: Part
var hammer: Part


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	z_index = 1
	collision_layer = 3
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(140, 34)
	shape.shape = r
	shape.position = Vector2(0, -17)
	add_child(shape)
	var hurt := Area2D.new()
	hurt.name = "Hurtbox"
	hurt.collision_layer = 2
	hurt.collision_mask = 0
	hurt.monitoring = false
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(140, 250)
	hs.shape = hr
	hs.position = Vector2(0, -125)
	hurt.add_child(hs)
	add_child(hurt)
	GameFeel.add_shadow(self, Vector2(0, -2), Vector2(86, 16))
	_build_rig()


func set_player(p: CharacterBody2D) -> void:
	player = p
	if tower:
		tower.player = p


## La arena llama esto: el plano de obra reemplaza la barra de vida.
func build_hud(layer: CanvasLayer) -> void:
	panel = PlanPanel.new()
	panel.boss = self
	panel.position = Vector2(340, 8)
	layer.add_child(panel)


# --- Piezas ----------------------------------------------------------------------

func _build_rig() -> void:
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)
	var spr := has_sprites()
	tracks = _part("tracks", Vector2.ZERO)
	cab = _part("cab", Vector2.ZERO)
	grille = _part("grille", SPR_GRILLE if spr else GRILLE)
	crane = _part("crane", SPR_SHOULDER_L if spr else SHOULDER_L)
	hammer = _part("hammer", SPR_SHOULDER_R if spr else SHOULDER_R)
	head = _part("head", SPR_HEAD if spr else HEAD)
	crane.rotation = REST_L
	hammer.rotation = REST_R
	_holo = Holo.new()
	_holo.position = Vector2(0, -300)
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
	return Spr.tex("boss_stack_body_0") != null


func _parts() -> Array:
	return [tracks, cab, grille, crane, hammer, head]


func _say(text: String, col: Color = Color(1, 0.85, 0.3), time: float = 1.1) -> void:
	if _holo:
		_holo.show_text(text, col, time)


## La torre se crea cuando el boss ya está en la arena.
func _ensure_tower() -> void:
	if tower and is_instance_valid(tower):
		return
	tower = Fx.Tower.new()
	tower.boss = self
	tower.player = player
	get_parent().add_child(tower)
	tower.global_position = arena_rect.get_center() + TOWER_AT


func _enter_tree() -> void:
	call_deferred("_ensure_tower")


# --- Bucle ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_charge_cd -= delta
	if state != "dead":
		var rumble := sin(_t * 30.0) * 0.6
		rig.position = rig_off + Vector2(0, rumble)
		head.anim_off = head.anim_off.lerp(Vector2(0, sin(_t * 2.0) * 1.5), minf(1.0, delta * 8.0))
		crane.anim_rot = sin(_t * 1.6) * 0.05 if state == "idle" else 0.0
		hammer.anim_rot = sin(_t * 1.6 + 1.2) * 0.05 if state == "idle" else 0.0
		tracks.step += velocity.length() * delta
		if enraged:
			var k := 0.75 + 0.25 * absf(sin(_t * 9.0))
			rig.modulate = Color(1.0, k, k * 0.6)
		else:
			rig.modulate = Color.WHITE
		if state == "stunned" and crush_left > 0.0:
			crush_left -= delta
		if tower and is_instance_valid(tower) and state != "final":
			tower.sway_amp = SWAY[phase - 1]
			tower.sway_speed = SWAY_SPEED[phase - 1]
			tower.bias = 0.0
			tower.need = 3 + (mini(3, tower.kinds.count(0)) if phase >= 3 else 0)
	if _charging:
		for v in _victims():
			_victim = v
			if _player_feet().distance_to(global_position) < 80.0 and CoopBoss.ready_for(self, "charge", v, 0.6):
				hurt_player(2, global_position, true)
		_victim = null
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
			if not _charging:
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
		dir = -to.normalized() * 0.5
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
	if tower and tower.floors >= Fx.Tower.MAX and tower.state == "idle":
		pick = "overflow"
	elif _stack_due > 0 and tower and tower.state == "idle":
		pick = "stack"
	elif not _queue.is_empty():
		pick = _queue.pop_front()
	elif _near_t > 1.3:
		pick = "charge"
	elif phase >= 2 and randf() < (0.3 if phase == 2 else 0.45):
		var list: Array = COMBOS[phase]
		_queue.assign(list[randi() % list.size()])
		pick = _queue.pop_front()
	else:
		var pool: Array[String] = ["belts", "blueprint", "ball", "gears"]
		if phase >= 2:
			pool.append_array(["poles", "anchor"])
		var bag: Array[String] = []
		for a in pool:
			if a != _last:
				bag.append(a)
		pick = bag[randi() % bag.size()]
	if pick != "stack" and pick != "overflow":
		_near_t = 0.0
		_last = pick
	_tok += 1
	state = "attack"
	velocity = Vector2.ZERO
	call("_atk_" + pick, _tok)


func _end_attack(tok: int, stacks: bool = true) -> void:
	if tok != _tok:
		return
	state = "idle"
	_charging = false
	_rest_pose()
	_rest_arms()
	head.mood = 0
	if stacks:
		_stack_due += 2 if phase >= 3 else 1
	_cd = PAUSE[phase - 1] * (0.6 if enraged else 1.0)
	if _stack_due > 0:
		_cd = 0.25
	elif not _queue.is_empty():
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


## Punta de la grúa (donde cuelga el gancho), global.
func _crane_tip() -> Vector2:
	var sh: Vector2 = global_position + _home[crane]
	return sh + Vector2.DOWN.rotated(crane.rotation) * (SPR_CRANE_LEN if has_sprites() else CRANE_LEN)


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
	_tw(crane, "rotation", REST_L, 0.3)
	_tw(hammer, "rotation", REST_R, 0.3)
	crane.tool = 0
	hammer.tool = 0


func _impact(at: Vector2, strength: float) -> void:
	_shake(strength, 0.1 + strength * 0.03)
	GameFeel.dust(get_parent(), at, int(4 + strength), Vector2.ZERO, 5.0, Vector2(20 + strength * 3.0, 6))
	GameFeel.hit_stop(get_tree(), 0.04)


func _warn_zone(at: Vector2, dir: Vector2, reach: float, half_angle: float, life: float) -> void:
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
	_charging = false
	velocity = Vector2.ZERO
	_rest_pose(0.2)
	for p in _parts():
		p.modulate = Color.WHITE
	visible = true
	modulate.a = 1.0
	if _anchor and is_instance_valid(_anchor):
		_anchor.queue_free()
	_anchor = null


func hurt_player(amount: int, from: Vector2, unblockable: bool = false) -> void:
	if not _player_ok() or state == "dead" or state == "paused":
		return
	_who().call("take_hit", amount, from, unblockable)


# --- La Torre ---------------------------------------------------------------------

## Gira la grúa hacia la torre y le lanza piezas.
func _atk_stack(tok: int) -> void:
	_ensure_tower()
	var n := _stack_due
	_stack_due = 0
	var tp := tower.global_position
	# se acerca un poco a la torre (el mejor momento para tumbarla es justo después)
	var to := global_position - tp
	var spot := global_position
	if to.length() > 200.0:
		spot = _clamp_arena(tp + to.normalized() * 170.0)
		spot.y = maxf(spot.y, arena_rect.position.y + 340.0)
		_tw(self, "global_position", spot, 0.5)
		tracks.step += 80.0
		if not await _wait(0.5, tok):
			return
	for i in n:
		if tower.floors >= Fx.Tower.MAX:
			break
		var aim := (tp + Vector2(0, -60) - (global_position + SHOULDER_L)).normalized()
		crane.tool = 0
		_tw(crane, "rotation", _rot_for(aim) - 0.5, 0.2)
		if not await _wait(0.22, tok):
			return
		_tw(crane, "rotation", _rot_for(aim), 0.15)
		var p := Fx.FlyPiece.new()
		p.kind = randi() % 3
		p.from = _crane_tip()
		p.to = tp + Vector2(0, -Fx.Tower.FLOOR_H * (tower.floors + 1))
		p.tower = tower
		get_parent().add_child(p)
		p.global_position = p.from
		if not await _wait(0.5, tok):
			return
	# se queda mirando su obra un momento (la ventana para tumbarla)
	head.mood = 3
	_say("+%d PISO%s" % [n, "S" if n > 1 else ""], Color(1, 0.8, 0.3), 0.8)
	if not await _wait(0.8, tok):
		return
	_end_attack(tok, false)


## STACK OVERFLOW: la torre llena se tambalea y se derrumba hacia el jugador por toda la arena.
func _atk_overflow(tok: int) -> void:
	overflows += 1
	_say("STACK OVERFLOW", Color(1, 0.3, 0.2), 1.6)
	head.mood = 1
	_tw(crane, "rotation", PI * 0.8, 0.3)
	_tw(hammer, "rotation", -PI * 0.8, 0.3)
	_pose(Vector2(0, -10), 0.0, 0.3)
	var tp := tower.global_position
	var dir := Vector2.RIGHT
	if _player_ok():
		dir = (_player_feet() - tp).normalized()
	tower.state = "wobble"
	var strip := Fx.CollapseStrip.new()
	strip.dir = dir
	strip.warn = 1.0
	_add_fx(strip, tp)
	_shake(3.0, 1.0)
	if not await _wait(0.75, tok):
		tower.state = "idle"
		return
	tower.fall(dir, 0.25)
	if not await _wait(0.3, tok):
		return
	_impact(tp + dir * 300.0, 10.0)
	for i in 6:
		GameFeel.dust(get_parent(), tp + dir * (80.0 + i * 120.0), 5, Vector2.ZERO, 5.0, Vector2(40, 8))
	if not await _wait(0.5, tok):
		return
	tower.scatter()
	if not await _wait(0.6, tok):
		return
	_end_attack(tok, false)


## Lo llama la torre al recibir un golpe del jugador.
func tower_hit(tw: Fx.Tower) -> void:
	if state == "final":
		_final_tower_hit(tw)
		return
	if tw.floors < 2:
		GameFeel.flash(tw, 0.08, Color(0.7, 0.7, 0.8))
		return
	if phase >= 2 and tw.lean() * tw.boss_side() < 0.35:
		_num("¡SE ENDEREZA!", Color(1, 0.7, 0.4), tw.global_position + Vector2(0, -60))
		GameFeel.flash(tw, 0.08, Color(0.8, 0.8, 0.85))
		return
	tw.hits += 1
	GameFeel.dust(get_parent(), tw.global_position, 5, Vector2.ZERO, 4.0, Vector2(30, 6))
	GameFeel.flash(tw, 0.1, Color(1, 0.9, 0.6))
	if tw.hits >= tw.need:
		tower_toppled()


func _num(text: String, col: Color, at: Vector2) -> void:
	var n := BossFx.DmgNumber.new()
	n.text = text
	n.color = col
	get_parent().add_child(n)
	n.global_position = at


## Lo llama la torre al recibir el tercer golpe: cae hacia el boss.
func tower_toppled() -> void:
	if state in ["dead", "intro", "paused", "transition"]:
		return
	_interrupt()
	var tok := _tok
	state = "attack"
	var tp := tower.global_position
	var to := global_position - tp
	var dir := Vector2.RIGHT if to.length() < 1.0 else to.normalized()
	var reach := tower.reach()
	var floors := tower.floors
	head.mood = 2
	_say("!?", Color(1, 0.9, 0.4), 0.8)
	tower.fall(dir, 0.45)
	if not await _wait(0.5, tok):
		return
	_impact(tp + dir * reach * 0.6, 6.0)
	tower.scatter()
	# alcanza al boss si su cuerpo queda dentro del largo de la torre
	if to.length() - 70.0 <= reach:
		_crushed(floors)
	else:
		_say("¡FALLÓ!", Color(0.8, 0.8, 0.8), 0.9)
		if not await _wait(0.4, tok):
			return
		_end_attack(tok, false)


## Aplastado por su propia torre: motor expuesto (daño x2).
func _crushed(floors: int) -> void:
	crushes += 1
	_interrupt()
	var tok := _tok
	state = "stunned"
	tank_open = true
	grille.open = true
	head.mood = 2
	head.dented = true
	crush_total = CRUSH_BASE + CRUSH_PER_FLOOR * floors
	crush_left = crush_total
	_say("¡APLASTADO!", Color(0.5, 1.0, 0.5), 1.4)
	_tw(crane, "rotation", 1.0, 0.3)
	_tw(hammer, "rotation", -1.0, 0.3)
	_pose(Vector2(0, 16), 0.08, 0.25)
	_shake(7.0, 0.4)
	GameFeel.flash(rig, 0.3, Color(0.6, 1.0, 0.6))
	stunned.emit()
	var steps := int(ceil(crush_total / 0.5))
	for i in steps:
		_pose(Vector2(0, 16), 0.06 * (1.0 if i % 2 == 0 else -1.0), 0.45)
		if not await _wait(minf(0.5, crush_total - i * 0.5), tok):
			_close_grille()
			return
	_close_grille()
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.6
	head.mood = 0


func _close_grille() -> void:
	tank_open = false
	grille.open = false
	crush_left = 0.0


# --- Recibir daño ----------------------------------------------------------------

func take_hit(amount: int, from: Vector2) -> void:
	if state in ["intro", "transition", "dead", "paused", "final"]:
		GameFeel.flash(rig, 0.08, Color(0.6, 0.6, 0.7))
		return
	var dmg := amount * (2 if tank_open else 1)
	# a un golpe de caer en la fase 3: RECURSIÓN INFINITA en vez de morir
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
	var center := global_position + CENTER
	var toward := from - center
	toward = Vector2.DOWN if toward.length() < 0.01 else toward.normalized()
	head.anim_off += -toward * (3.0 + 2.0 * dmg)
	var num := BossFx.DmgNumber.new()
	num.text = str(dmg) + ("!" if tank_open else "")
	num.big = tank_open
	num.color = Color(0.6, 1, 0.6) if tank_open else Color(1, 1, 1)
	get_parent().add_child(num)
	num.global_position = center + toward * 40.0 + Vector2(0, -40)
	if tank_open:
		GameFeel.parry_burst(get_parent(), global_position + GRILLE, 34.0)
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
	if not tank_open and state in ["idle", "attack"]:
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
		take_hit(1, global_position)
		return
	hp = int(MAX_HP * PHASE_AT[phase - 1])
	hp_changed.emit(hp, MAX_HP)
	_enter_phase(phase + 1)


func _stagger(time: float = 0.9, text: String = "ERR?") -> void:
	_interrupt()
	var tok := _tok
	state = "stunned"
	head.mood = 2
	_say(text, Color(1, 0.8, 0.4))
	_pose(Vector2(0, 8), 0.06 * (1.0 if randf() < 0.5 else -1.0), 0.12)
	GameFeel.flash(rig, 0.2, Color(1, 0.9, 0.6))
	_shake(3.0, 0.2)
	staggered.emit()
	if not await _wait(time, tok):
		return
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.5
	head.mood = 0


func _enter_phase(n: int) -> void:
	phase = n
	_close_grille()
	_interrupt()
	var tok := _tok
	state = "transition"
	if n == 2:
		cab.dirty = true
		# la estructura arranca con 2 pisos
		_ensure_tower()
		if tower.state == "idle":
			while tower.floors < 2:
				tower.add_piece(randi() % 3)
	else:
		head.dented = true
		cab.dirty = true
		grille.cracked = true
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
	_close_grille()
	_interrupt()
	var tok := _tok
	state = "transition"
	head.mood = 1
	_say("DERRUMBE", Color(1, 0.3, 0.2), 1.4)
	_pose(Vector2(0, -14), 0.0, 0.3)
	GameFeel.flash(rig, 0.4, Color(1.0, 0.5, 0.3))
	_shake(9.0, 1.0)
	phase_changed.emit(3, "DERRUMBE")
	if not await _wait(1.3, tok):
		return
	_rest_pose()
	state = "idle"
	_cd = 0.3
	head.mood = 0


# --- Ataques ---------------------------------------------------------------------------

## 1. Alimentos: cintas transportadoras cruzan la arena, empujan y traen latas rodando.
func _atk_belts(tok: int) -> void:
	_say("LÍNEA DE PRODUCCIÓN", Color(1, 0.7, 0.35))
	hammer.tool = 2
	_tw(hammer, "rotation", -PI * 0.6, 0.3)
	_pose(Vector2(0, -6), 0.0, 0.3)
	var n: int = [2, 2, 3][phase - 1]
	var ys: Array[float] = []
	var py := _player_feet().y if _player_ok() else 0.0
	ys.append(clampf(py, arena_rect.position.y + 80.0, arena_rect.end.y - 50.0))
	for i in n - 1:
		var y := randf_range(arena_rect.position.y + 80.0, arena_rect.end.y - 50.0)
		var tries := 0
		while tries < 10 and absf(y - ys[ys.size() - 1]) < 110.0:
			y = randf_range(arena_rect.position.y + 80.0, arena_rect.end.y - 50.0)
			tries += 1
		ys.append(y)
	for i in n:
		var b := Fx.Belt.new()
		b.x0 = arena_rect.position.x
		b.x1 = arena_rect.end.x
		b.dir = 1.0 if i % 2 == 0 else -1.0
		b.cans_every = 0.8 if phase == 1 else 0.6
		_add_fx(b, Vector2(0, ys[i]))
	if not await _wait(0.6, tok):
		return
	for i in 4:
		_tw(hammer, "rotation", -PI * 0.6 + (0.25 if i % 2 == 0 else -0.25), 0.2)
		if not await _wait(0.6, tok):
			return
	if not await _wait(1.6, tok):
		return
	_end_attack(tok)


## 2. Arquitectura: el plano dibuja líneas azules que suben como muros.
func _atk_blueprint(tok: int) -> void:
	_say("PLANO APROBADO", Color(0.5, 0.75, 1.0))
	_tw(crane, "rotation", PI * 0.7, 0.3)
	_tw(hammer, "rotation", -PI * 0.7, 0.3)
	_pose(Vector2(0, -8), 0.0, 0.3)
	var n: int = [4, 5, 7][phase - 1]
	var c := _player_feet() if _player_ok() else arena_rect.get_center()
	for i in n:
		var l := Fx.BlueLine.new()
		var horiz := i % 2 == 0
		var len := randf_range(220.0, 340.0)
		l.size = Vector2(len, 24) if horiz else Vector2(24, len * 0.7)
		l.warn = 1.0 if phase == 1 else 0.85
		var at := c if i == 0 else c + Vector2(randf_range(-260, 260), randf_range(-160, 160))
		_add_fx(l, _clamp_arena(at))
	if not await _wait(1.0, tok):
		return
	_impact(global_position, 3.0)
	if not await _wait(2.6, tok):
		return
	_end_attack(tok)


## 3. Electricidad: postes unidos por arcos que giran. Romper un poste corta sus arcos.
func _atk_poles(tok: int) -> void:
	_say("ALTA TENSIÓN", Color(0.6, 0.85, 1.0))
	hammer.tool = 1
	_tw(hammer, "rotation", -PI * 0.5, 0.3)
	var s := Fx.ArcSet.new()
	s.radius = 190.0
	s.spin = (0.45 + 0.15 * phase) * (1.0 if randf() < 0.5 else -1.0)
	s.angle = randf() * TAU
	_add_fx(s, arena_rect.get_center() + Vector2(0, 60))
	s.setup([3, 3, 4][phase - 1])
	if not await _wait(0.9, tok):
		return
	_impact(global_position, 2.0)
	if not await _wait(3.8, tok):
		return
	_end_attack(tok)


## 4. Ingeniería Civil: bola de demolición en arco enorme.
func _atk_ball(tok: int) -> void:
	_say("¡DEMOLICIÓN!", Color(1, 0.55, 0.3))
	crane.tool = 2
	var swings: int = [1, 2, 2][phase - 1]
	for s in swings:
		var aim := _dir_to_player(global_position)
		var mid := atan2(aim.y / 0.6, aim.x)
		var a0 := mid - 1.5 * (1.0 if s % 2 == 0 else -1.0)
		var a1 := mid + 1.5 * (1.0 if s % 2 == 0 else -1.0)
		var r := 250.0
		_warn_zone(global_position, aim, r + 50.0, 1.5, 0.85)
		_tw(crane, "rotation", _rot_for(Vector2.from_angle(a0)), 0.5)
		_pose(-aim * 10.0, -0.05, 0.5)
		if not await _wait(0.85, tok):
			return
		var b := Fx.Ball.new()
		b.center = global_position
		b.radius = r
		b.a0 = a0
		b.a1 = a1
		b.dur = 0.55
		_add_fx(b, global_position)
		_tw(crane, "rotation", _rot_for(Vector2.from_angle(a1)), 0.55)
		_pose(aim * 10.0, 0.05, 0.4)
		if not await _wait(0.6, tok):
			return
		_impact(b.pos, 5.0)
		if not await _wait(0.4, tok):
			return
	if not await _wait(0.4, tok):
		return
	_end_attack(tok)


## 5. Ingeniería Industrial: engranajes-sierra que ruedan y rebotan.
func _atk_gears(tok: int) -> void:
	_say("CADENA DE MONTAJE", Color(0.85, 0.85, 0.9))
	hammer.tool = 2
	var n: int = [3, 4, 5][phase - 1]
	for i in n:
		var aim := _dir_to_player(global_position + SHOULDER_R).rotated(randf_range(-0.9, 0.9))
		_tw(hammer, "rotation", _rot_for(aim), 0.15)
		var g := Fx.Gear.new()
		g.vel = aim * (220.0 + 20.0 * phase)
		g.area = arena_rect
		_add_fx(g, global_position + SHOULDER_R + aim * HAMMER_LEN + Vector2(0, 150))
		_pose(aim * 6.0, 0.0, 0.08)
		if not await _wait(0.35, tok):
			return
	# en las fases 2 y 3 llama a los drones obreros
	if phase >= 2:
		var have := get_tree().get_nodes_in_group("boss_minion").size()
		for i in mini(2, 3 - have):
			var d := Fx.Drone.new()
			var side := -1.0 if i % 2 == 0 else 1.0
			_add_fx(d, _clamp_arena(global_position + Vector2(side * 160.0, 40.0)))
			GameFeel.dust(get_parent(), d.global_position, 5, Vector2.ZERO, 4.0, Vector2(20, 6))
	if not await _wait(1.6, tok):
		return
	_end_attack(tok)


## 6. Ingeniería Marítima: lanza el ancla (parry = aturdido) y luego una ola cruza la arena.
func _atk_anchor(tok: int) -> void:
	_say("¡ANCLA!", Color(0.5, 0.75, 1.0))
	crane.tool = 1
	var aim := _dir_to_player(global_position + SHOULDER_L)
	_tw(crane, "rotation", _rot_for(aim) - 0.7, 0.35)
	_warn_zone(global_position + SHOULDER_L + Vector2(0, 160), aim, 420.0, 0.12, 0.7)
	if not await _wait(0.7, tok):
		return
	aim = _dir_to_player(global_position + SHOULDER_L)
	_tw(crane, "rotation", _rot_for(aim), 0.1)
	_anchor_res = 0
	_anchor = Fx.Anchor.new()
	_anchor.dir = aim
	_anchor.origin = global_position + SHOULDER_L + Vector2(0, 160)
	_add_fx(_anchor, _anchor.origin)
	var t := 0.0
	while _anchor and is_instance_valid(_anchor) and t < 2.0:
		if not await _wait(0.05, tok):
			return
		t += 0.05
		if _anchor_res != 0:
			break
	if _anchor_res == 2:
		# parry: la cadena se tensa y lo tira
		_stagger(1.8, "¡CLANK!")
		return
	if _anchor_res == 1 and _player_ok():
		# arrastra al jugador hasta él
		var dest := _clamp_arena(global_position + Vector2(0, 110))
		var pt := create_tween()
		pt.tween_property(player, "global_position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tweens.append(pt)
		if not await _wait(0.4, tok):
			return
	# la ola
	crane.tool = 0
	_tw(crane, "rotation", REST_L, 0.3)
	_say("¡OLA!", Color(0.5, 0.8, 1.0))
	var waves: int = [1, 1, 2][phase - 1]
	for i in waves:
		var w := Fx.Wave.new()
		w.area = arena_rect
		w.dir = 1.0 if (i % 2 == 0) == (randf() < 0.5) else -1.0
		_add_fx(w, Vector2.ZERO)
		if not await _wait(0.9, tok):
			return
	if not await _wait(1.6, tok):
		return
	_end_attack(tok)


## Lo llama el ancla: true si el jugador hizo parry.
func anchor_result(parried: bool) -> void:
	_anchor_res = 2 if parried else 1
	if not parried:
		hurt_player(1, global_position, true)


## Embestida con las orugas (si el jugador se queda pegado).
func _atk_charge(tok: int) -> void:
	_say("!!", Color(1, 0.5, 0.3))
	var aim := _dir_to_player(global_position)
	aim = Vector2(aim.x, aim.y * 0.8).normalized()
	_warn_zone(global_position, aim, 380.0, 0.32, 0.7)
	_pose(-aim * 14.0, -aim.x * 0.06, 0.6)
	if not await _wait(0.7, tok):
		return
	_charging = true
	var dest := _clamp_arena(global_position + aim * 380.0)
	dest.y = maxf(dest.y, arena_rect.position.y + 340.0)
	var tw := _tw(self, "global_position", dest, 0.5)
	tw.set_trans(Tween.TRANS_LINEAR)
	tracks.step += 200.0
	GameFeel.dust(get_parent(), global_position, 6, -aim * 60.0, 5.0, Vector2(40, 8))
	if not await _wait(0.5, tok):
		return
	_charging = false
	_impact(global_position, 5.0)
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)


# --- Aparición y muerte -----------------------------------------------------------


# --- RECURSIÓN INFINITA (duelo final) -----------------------------------------------------
## A un golpe de caer: se planta junto a su torre y la hace crecer sin parar. Golpea la base cuando se
## inclina hacia él (flecha verde): se inclina más y pierde el piso de arriba. A destiempo: crece un piso.
## FINAL_LEAN aciertos = se le cae encima. Si llega a 8 pisos: STACK OVERFLOW, vuelve la fase 3.
func _start_final() -> void:
	_interrupt()
	_close_grille()
	var tok := _tok
	state = "final"
	_lean_lv = 0
	_final_fail = false
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	_ensure_tower()
	tower.reset()
	for k in 3:
		tower.add_piece(randi() % 3)
	tower.sway_amp = 0.09
	tower.sway_speed = 2.5
	tower.bias = 0.0
	Final.title(self, "RECURSIÓN INFINITA", Color(1.0, 0.6, 0.2), "Golpea la base cuando se incline hacia él")
	Final.music_cue(self, "final1")
	head.mood = 1
	# se pone al lado de la torre (para que le caiga encima)
	var spot := _clamp_arena(tower.global_position + Vector2(230, 30))
	spot.y = maxf(spot.y, arena_rect.position.y + 340.0)
	_tw(self, "global_position", spot, 0.7)
	tracks.step += 120.0
	if not await _wait(1.0, tok):
		return
	var grow := 1.6
	var slam := 3.0
	while _lean_lv < FINAL_LEAN and not _final_fail:
		if not await _wait(0.05, tok):
			return
		grow -= 0.05
		slam -= 0.05
		if grow <= 0.0:
			grow = maxf(0.9, 1.6 - 0.15 * _lean_lv)
			_crane_piece()
			if tower.floors >= Fx.Tower.MAX:
				_final_fail = true
		if slam <= 0.0:
			slam = 3.0
			_hammer_slam(tok)
	if _final_fail:
		_final_lost(tok)
	else:
		_final_won()


## La grúa echa el brazo atrás y suelta un piso más en la torre (anticipación + caída).
func _crane_piece() -> void:
	var tp := tower.global_position
	var aim := (tp + Vector2(0, -60) - (global_position + SHOULDER_L)).normalized()
	crane.tool = 0
	var tw := create_tween()
	tw.tween_property(crane, "rotation", _rot_for(aim) - 0.6, 0.15)
	tw.tween_property(crane, "rotation", _rot_for(aim), 0.1)
	tower.add_piece(randi() % 3)
	_shake(1.5, 0.1)


## Pisotón con el martillo: onda que hay que saltar rodando (para que no te quedes quieto en la base).
func _hammer_slam(tok: int) -> void:
	var tw := create_tween()
	tw.tween_property(hammer, "rotation", -PI * 0.9, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if tok != _tok:
			return
		hammer.rotation = 0.2
		_pose(Vector2(0, 6), 0.03, 0.06)
		_impact(global_position + Vector2(60, 0), 6.0)
		var ring := BossFx.ShockRing.new()
		ring.max_r = 380.0
		_add_fx(ring, global_position))
	tw.tween_property(hammer, "rotation", REST_R, 0.3)


func _final_tower_hit(tw: Fx.Tower) -> void:
	if _final_fail or _lean_lv >= FINAL_LEAN:
		return
	var side: float = tw.boss_side()
	if tw.lean() * side > 0.45:
		_lean_lv += 1
		tw.bias = side * 0.035 * _lean_lv
		tw.sway_speed = 2.5 + 0.25 * _lean_lv
		if tw.floors > 2:
			tw.floors -= 1
			tw.kinds.pop_back()
		_num("¡INCLINADA %d/%d!" % [_lean_lv, FINAL_LEAN], Color(0.5, 1, 0.5), tw.global_position + Vector2(0, -70))
		GameFeel.dust(get_parent(), tw.global_position, 8, Vector2.ZERO, 5.0, Vector2(40, 8))
		GameFeel.hit_stop(get_tree(), 0.05)
		head.mood = 2
		if _lean_lv == 2:
			Final.music_cue(self, "final2")
		elif _lean_lv == 4:
			Final.music_cue(self, "final3")
	else:
		tw.add_piece(randi() % 3)
		_num("¡A DESTIEMPO! +1 PISO", Color(1, 0.5, 0.3), tw.global_position + Vector2(0, -70))
		if tw.floors >= Fx.Tower.MAX:
			_final_fail = true


func _final_won() -> void:
	final_victory = true
	Final.music_final(self, "epic")
	Final.title(self, "STACK UNDERFLOW", Color(0.5, 1.0, 0.55), "La torre le cayó encima", 1.6)
	await _finisher()
	_shake(12.0, 0.8)
	hp = 0
	hp_changed.emit(hp, MAX_HP)
	_die()


func _final_lost(tok: int) -> void:
	Final.title(self, "STACK OVERFLOW", Color(1.0, 0.35, 0.25), "", 1.1)
	Final.music_cue(self, "p3")
	var tp := tower.global_position
	var dir := (_player_feet() - tp).normalized() if _player_ok() else Vector2.RIGHT
	tower.bias = 0.0
	tower.state = "wobble"
	var strip := Fx.CollapseStrip.new()
	strip.dir = dir
	strip.warn = 0.9
	_add_fx(strip, tp)
	if not await _wait(0.75, tok):
		return
	tower.fall(dir, 0.25)
	if not await _wait(0.5, tok):
		return
	tower.scatter()
	if not await _wait(0.6, tok):
		return
	head.mood = 0
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 1.0


# --- Lluvia de cambio de fase propia: DEMOLICIÓN -------------------------------------------
## Planos que se vuelven muros, engranajes que ruedan por la obra, la bola de demolición dando la vuelta
## completa alrededor del boss y olas de concreto.
func barrage_title(_n: int) -> String:
	return "DEMOLICIÓN"


func barrage_plan(n: int) -> Array:
	if n == 2:
		return [[0.2, "blueprint", {"n": 6}], [1.6, "gears", {"n": 6}], [3.2, "ball", {}],
			[4.8, "wave", {}], [6.0, "blueprint", {"n": 5}]]
	return [[0.2, "blueprint", {"n": 8}], [1.2, "gears", {"n": 8}], [2.6, "ball", {}],
		[4.0, "wave", {}], [5.0, "gears", {"n": 8}], [6.2, "ball", {}], [7.6, "blueprint", {"n": 8}]]


func _bfx(n: Node2D, at: Vector2) -> void:
	_add_fx(n, at)
	Barrage.tag(n)


func _bar_blueprint(a: Dictionary, _tok: int) -> void:
	var c := _player_feet() if _player_ok() else arena_rect.get_center()
	for i in int(a["n"]):
		var l := Fx.BlueLine.new()
		var horiz := i % 2 == 0
		var len := randf_range(260.0, 420.0)
		l.size = Vector2(len, 24) if horiz else Vector2(24, len * 0.7)
		l.warn = 0.85
		var at := c if i == 0 else Vector2(randf_range(arena_rect.position.x + 80, arena_rect.end.x - 80), randf_range(arena_rect.position.y + 100, arena_rect.end.y - 40))
		_bfx(l, _clamp_arena(at))


func _bar_gears(a: Dictionary, _tok: int) -> void:
	var n: int = a["n"]
	for i in n:
		var g := Fx.Gear.new()
		g.vel = Vector2.from_angle(TAU * i / n + randf() * 0.3) * 250.0
		g.area = arena_rect
		_bfx(g, global_position + Vector2(0, 40))
	_impact(global_position, 4.0)


func _bar_ball(_a: Dictionary, _tok: int) -> void:
	crane.tool = 2
	var aim := _dir_to_player(global_position)
	var mid := atan2(aim.y / 0.6, aim.x)
	var b := Fx.Ball.new()
	b.center = global_position
	b.radius = 270.0
	b.a0 = mid - PI
	b.a1 = mid + PI
	b.dur = 1.3
	_bfx(b, global_position)
	_warn_zone(global_position, aim, 320.0, PI, 0.4)


func _bar_wave(_a: Dictionary, _tok: int) -> void:
	var w := Fx.Wave.new()
	w.area = arena_rect
	w.dir = 1.0 if randf() < 0.5 else -1.0
	_bfx(w, Vector2.ZERO)


## REMATE: la torre se le viene encima piso por piso; queda enterrado bajo los escombros con el casco aplastado.
func _finisher() -> void:
	if tower and is_instance_valid(tower):
		while tower.floors < 6:
			tower.add_piece(randi() % 3)
		tower.bias = 0.0
		tower.sway_amp = 0.0
		var to := global_position - tower.global_position
		tower.fall(Vector2.RIGHT if to.length() < 1.0 else to.normalized(), 0.55)
	head.mood = 2
	_say("!!!", Color(1, 0.9, 0.4), 0.6)
	await get_tree().create_timer(0.55).timeout
	head.dented = true
	_pose(Vector2(0, 22), 0.1, 0.08)
	_shake(12.0, 0.5)
	for i in 8:
		GameFeel.dust(get_parent(), global_position + Vector2(randf_range(-90, 90), randf_range(-60, 10)), 5, Vector2(0, -30), 6.0, Vector2(30, 8))
	await get_tree().create_timer(0.9).timeout



func start_intro(skip: bool) -> void:
	state = "intro"
	_ensure_tower()
	if skip:
		await get_tree().create_timer(0.6).timeout
		intro_finished.emit()
		return
	# 1. sirena de obra y polvo cayendo
	var home := position
	rig.visible = false
	await get_tree().create_timer(0.3).timeout
	var siren := Fx.Siren.new()
	siren.area = arena_rect
	get_parent().add_child(siren)
	siren.global_position = Vector2.ZERO
	_shake(2.0, 1.4)
	for i in 6:
		GameFeel.dust(get_parent(), arena_rect.get_center() + Vector2(randf_range(-400, 400), randf_range(-200, 200)), 4, Vector2(0, 60), 4.0, Vector2(30, 6))
		await get_tree().create_timer(0.2).timeout
	# 2. sube desde abajo en el montacargas
	rig.visible = true
	head.beacon = false
	rig_off = Vector2(0, 160)
	rig.modulate.a = 0.0
	var up := create_tween().set_parallel(true)
	up.tween_property(self, "rig_off", Vector2.ZERO, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_property(rig, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(1.25).timeout
	position = home
	_impact(global_position, 4.0)
	# 3. se enciende la baliza y el visor escribe su nombre
	head.beacon = true
	head.visor = "name"
	head.write_k = 0.0
	var wr := create_tween()
	wr.tween_property(head, "write_k", 1.0, 1.0)
	await get_tree().create_timer(1.2).timeout
	# 4. firma: tres martillazos al suelo apilan bloques sobre el casco (PUSH, PUSH, PUSH);
	#    la grúa mete uno más y la pila se desborda: STACK OVERFLOW.
	head.mood = 1
	var blocks := Roar.Blocks.new()
	Roar.spawn(get_parent(), blocks, head.global_position + Vector2(0, -52))
	for i in 3:
		_tw(hammer, "rotation", -PI * 0.8, 0.16)
		_pose(Vector2(0, -6), -0.04, 0.16)
		await get_tree().create_timer(0.18).timeout
		_tw(hammer, "rotation", 0.1, 0.06)
		_pose(Vector2(0, 4), 0.03, 0.06)
		await get_tree().create_timer(0.07).timeout
		_impact(global_position + Vector2(90, 12), 4.0 + i * 1.5)
		blocks.push()
		await get_tree().create_timer(0.22).timeout
	_tw(crane, "rotation", PI * 0.7, 0.22)
	await get_tree().create_timer(0.22).timeout
	blocks.push()
	await get_tree().create_timer(0.25).timeout
	blocks.overflow()
	_say("STACK OVERFLOW", Color(1, 0.35, 0.3), 1.2)
	_pose(Vector2(0, -4), 0.09, 0.12)
	_shake(8.0, 0.6)
	await get_tree().create_timer(0.15).timeout
	_pose(Vector2(0, -4), -0.07, 0.15)
	await get_tree().create_timer(0.15).timeout
	_pose(Vector2.ZERO, 0.0, 0.2)
	await get_tree().create_timer(0.7).timeout
	_rest_pose()
	_rest_arms()
	head.mood = 0
	head.visor = ""
	intro_finished.emit()


func begin_fight() -> void:
	state = "idle"
	_cd = 1.0


func pause_ai() -> void:
	_interrupt()
	state = "paused"


func _die() -> void:
	_interrupt()
	state = "dead"
	tank_open = false
	remove_from_group("enemies")
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.call("die")
	Engine.time_scale = 0.2
	head.visor = "dead"
	head.mood = 2
	await get_tree().create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 1.0
	# la torre se le cae encima sola
	if tower and is_instance_valid(tower):
		while tower.floors < 5 and tower.state == "idle":
			tower.add_piece(randi() % 3)
		var to := global_position - tower.global_position
		if tower.state != "fall":
			tower.fall(Vector2.RIGHT if to.length() < 1.0 else to.normalized(), 0.5)
	await get_tree().create_timer(0.6).timeout
	_shake(9.0, 0.5)
	var card := Fx.DoneCard.new()
	get_parent().add_child(card)
	card.global_position = global_position
	if tower and is_instance_valid(tower):
		tower.scatter()
	# el motor revienta en humo y tuercas, el casco sale rodando
	grille.broken = true
	head.loose = true
	GameFeel.parry_burst(get_parent(), global_position + GRILLE, 70.0)
	for i in 16:
		var d := BossFx.Debris.new()
		d.kind = i % 8
		d.prefix = "boss_stack_debris_"
		d.vel = Vector2(randf_range(-300, 300), randf_range(-460, -200))
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-200, -80))
	for p in [crane, hammer]:
		var tw := create_tween()
		tw.tween_property(p, "rotation", (1.0 if p == crane else -1.0) * 1.6, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(self, "rig_off", Vector2(0, 30), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(rig, "rotation", 0.1, 0.5)
	fall.tween_property(head, "anim_off", Vector2(140, 210), 1.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(head, "rotation", 6.0, 1.0)
	GameFeel.dust(get_parent(), global_position, 16, Vector2.ZERO, 7.0, Vector2(90, 10))
	await get_tree().create_timer(2.4).timeout
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
	var step := 0.0
	# estados
	var open := false        # rejilla abierta (motor expuesto)
	var broken := false
	var cracked := false
	var dirty := false
	var dented := false      # casco abollado
	var loose := false       # el casco salió rodando (muerte)
	var beacon := true
	var visor := ""          # "", name, dead
	var write_k := 1.0
	var mood := 0            # 0 normal, 1 enojado, 2 aturdido, 3 contento (apiló)
	var tool := 0            # grúa: 0 gancho, 1 ancla, 2 bola · martillo: 0 martillo, 1 soplete, 2 llave

	const OUT := Color(0.05, 0.05, 0.06)
	const YELLOW := Color(0.98, 0.76, 0.12)
	const YELLOW_D := Color(0.78, 0.56, 0.06)
	const BLACK := Color(0.12, 0.12, 0.13)
	const STEEL := Color(0.55, 0.58, 0.62)
	const STEEL_D := Color(0.36, 0.38, 0.42)
	const GLASS := Color(0.12, 0.2, 0.26)
	const MUD := Color(0.36, 0.26, 0.16)

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
			"tracks":
				_tracks()
			"cab":
				_cab()
			"grille":
				_grille()
			"head":
				_head()
			"crane":
				_crane()
			"hammer":
				_hammer()

	## Con sprites de grokbot (boss_stack_*). Las orugas ya vienen en el cuerpo.
	func _draw_sprite() -> bool:
		var body := Spr.tex("boss_stack_body_0")
		if body == null:
			return false
		match kind:
			"tracks":
				return true
			"cab":
				var tx: Texture2D = Spr.tex("boss_stack_body_1") if dirty else body
				if tx == null:
					tx = body
				var bob := -absf(sin(step * 0.08)) * 2.0
				draw_texture(tx, anim_off + Vector2(-tx.get_width() * 0.5, -tx.get_height() + bob))
				_smoke(Vector2(-38, -186), Vector2(44, -186))
				return true
			"grille":
				var idx := 2 if (broken or cracked) else (1 if open else 0)
				var tx := Spr.tex("boss_stack_engine_%d" % idx)
				if tx == null:
					return false
				if open:
					draw_rect(Rect2(-36, -32, 72, 64).grow(4.0 + 3.0 * sin(t * 10.0)), Color(0.6, 1.0, 0.5, 0.25))
				draw_texture(tx, anim_off - tx.get_size() * 0.5, Color(1, 0.75, 0.6) if open and fmod(t * 6.0, 1.0) < 0.5 else Color.WHITE)
				return true
			"head":
				var idx := 2 if loose else (1 if dented else 0)
				var tx := Spr.tex("boss_stack_head_%d" % idx)
				if tx == null:
					return false
				draw_texture(tx, anim_off + Vector2(-tx.get_width() * 0.5, -tx.get_height()))
				if loose:
					return true
				# baliza que parpadea (roja con rabia)
				var on := beacon and (fmod(t * 3.0, 1.0) < 0.5)
				var bc := Color(1, 0.2, 0.15) if (boss and boss.get("enraged")) else Color(1, 0.55, 0.1)
				if on:
					draw_circle(anim_off + Vector2(0, -76), 16, Color(bc, 0.3))
				elif boss and boss.get("enraged"):
					draw_circle(anim_off + Vector2(0, -76), 7, Color(bc, 0.6))
				var v := Rect2(anim_off + Vector2(-12, -32), Vector2(40, 17))
				if visor == "name":
					var wide := Rect2(v.position.x - 16, v.position.y, v.size.x + 32, v.size.y)
					draw_rect(wide, Color(0.05, 0.08, 0.1))
					draw_rect(wide, OUT, false, 1.5)
					_face(wide)
				else:
					_face(v)
				return true
			"crane", "hammer":
				var name := ("boss_stack_crane_%d" if kind == "crane" else "boss_stack_hammer_%d") % tool
				var tx := Spr.tex(name)
				if tx == null:
					return false
				var piv := Spr.top_pivot(name)
				draw_set_transform(anim_off, anim_rot - Spr.lean(name), Vector2.ONE)
				draw_texture(tx, -piv)
				if kind == "hammer" and tool == 1:
					# llama del soplete
					var fl := 8.0 + 4.0 * sin(t * 30.0)
					var tip := Vector2(tx.get_width() * 0.5 - piv.x, tx.get_height() - piv.y)
					draw_colored_polygon(PackedVector2Array([tip + Vector2(-4, -2), tip + Vector2(4, -2), tip + Vector2(0, fl * 2.0)]), Color(0.5, 0.8, 1.0, 0.8))
				return true
		return false

	## Humo de los dos escapes.
	func _smoke(a: Vector2, b: Vector2) -> void:
		var smoke := Color(0.15, 0.15, 0.15, 0.5) if (boss and boss.get("enraged")) else Color(0.8, 0.8, 0.8, 0.35)
		for e in [a, b]:
			for k in 3:
				var ph := fmod(t * 0.9 + k * 0.33, 1.0)
				draw_circle(anim_off + e + Vector2(sin(t * 2.0 + k) * 4.0, -ph * 40.0), 4.0 + ph * 6.0, Color(smoke, smoke.a * (1.0 - ph)))

	func _tracks() -> void:
		for s in [-1.0, 1.0]:
			var r := Rect2(48 * s - 30, -46, 60, 46)
			_box(r, BLACK, 2.5)
			# eslabones que corren con el movimiento
			var off := fmod(step * 0.4, 10.0)
			var y := r.position.y + off
			while y < r.end.y:
				draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), Color(0.25, 0.25, 0.27), 2.0)
				y += 10.0
			for k in 3:
				draw_circle(Vector2(48 * s - 16 + k * 16, -23), 6, STEEL_D)
				draw_circle(Vector2(48 * s - 16 + k * 16, -23), 2, OUT)
			draw_rect(Rect2(r.position.x, r.end.y - 8, r.size.x, 8), MUD)
		# chasis entre las orugas
		_box(Rect2(-24, -52, 48, 26), STEEL_D)

	func _cab() -> void:
		var r := Rect2(-64, -200, 128, 150)
		_box(r, YELLOW, 3.0)
		# franjas de peligro abajo
		for i in 8:
			var x := r.position.x + i * 16
			draw_colored_polygon(PackedVector2Array([Vector2(x, -62), Vector2(x + 8, -62), Vector2(x + 16, -50), Vector2(x + 8, -50)]), BLACK)
		# ventanas oscuras de cabina
		_box(Rect2(-54, -188, 46, 40), GLASS)
		_box(Rect2(8, -188, 46, 40), GLASS)
		draw_line(Vector2(-48, -184), Vector2(-30, -158), Color(1, 1, 1, 0.15), 3.0)
		# faros
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(52 * s, -132), 8, Color(1, 0.95, 0.7))
			draw_arc(Vector2(52 * s, -132), 8, 0, TAU, 14, OUT, 2.0)
		# tubos de escape con humo
		for s in [-1.0, 1.0]:
			_box(Rect2(58 * s - 4, -224, 8, 26), STEEL_D, 1.5)
			var smoke := Color(0.15, 0.15, 0.15, 0.5) if (boss and boss.get("enraged")) else Color(0.8, 0.8, 0.8, 0.35)
			for k in 3:
				var ph := fmod(t * 0.9 + k * 0.33, 1.0)
				draw_circle(Vector2(58 * s + sin(t * 2.0 + k) * 4.0, -228 - ph * 40.0), 4.0 + ph * 6.0, Color(smoke, smoke.a * (1.0 - ph)))
		# conos colgando
		for s in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(66 * s, -110), Vector2(66 * s - 7, -88), Vector2(66 * s + 7, -88)]), Color(1, 0.5, 0.12))
		if dirty:
			draw_line(Vector2(-40, -80), Vector2(-22, -66), OUT, 2.0)
			draw_line(Vector2(30, -196), Vector2(20, -178), OUT, 2.0)
			draw_circle(Vector2(36, -76), 6, MUD)

	func _grille() -> void:
		var r := Rect2(-34, -24, 68, 48)
		if open:
			draw_rect(r.grow(8.0 + 3.0 * sin(t * 10.0)), Color(0.6, 1.0, 0.5, 0.25))
			# motor al rojo
			_box(r, Color(0.2, 0.1, 0.08))
			for k in 3:
				draw_circle(Vector2(-18 + k * 18, 0), 9, Color(1, 0.45 + 0.2 * sin(t * 12.0 + k), 0.15))
			draw_rect(Rect2(r.position.x - 6, r.position.y - 30, r.size.x + 12, 8), STEEL)
			return
		_box(r, STEEL_D, 2.5)
		for k in 6:
			draw_line(Vector2(-28, -18 + k * 7.5), Vector2(28, -18 + k * 7.5), BLACK, 3.0)
		if cracked or broken:
			draw_polyline(PackedVector2Array([Vector2(-26, -20), Vector2(-8, -4), Vector2(-16, 12), Vector2(4, 22)]), OUT, 2.5)
		if broken:
			draw_colored_polygon(PackedVector2Array([Vector2(-8, -4), Vector2(20, -10), Vector2(26, 18), Vector2(4, 22)]), Color(0.03, 0.03, 0.04))

	func _head() -> void:
		var g := Vector2(0, -26)
		# cuello hidráulico
		draw_rect(Rect2(-9, -8, 18, 12), STEEL_D)
		# casco (cúpula) con ala
		var dome := PackedVector2Array()
		for i in 17:
			var a := PI + PI * i / 16.0
			dome.append(g + Vector2(cos(a) * 40.0, sin(a) * 34.0))
		draw_colored_polygon(dome, YELLOW)
		dome.append(dome[0])
		draw_polyline(dome, OUT, 2.5)
		draw_line(g + Vector2(0, -34), g + Vector2(0, -4), YELLOW_D, 5.0)
		_box(Rect2(g.x - 50, g.y - 2, 100, 8), YELLOW_D, 2.0)
		if dented:
			draw_arc(g + Vector2(-20, -20), 9, 0.3, 2.6, 8, OUT, 2.0)
		# visor-pantalla debajo del ala
		var v := Rect2(g.x - 34, g.y + 8, 68, 26)
		_box(v, Color(0.05, 0.08, 0.1), 2.0)
		_face(v)
		# baliza naranja arriba
		var b := g + Vector2(0, -40)
		draw_rect(Rect2(b.x - 7, b.y - 2, 14, 6), STEEL_D)
		var on := beacon and (fmod(t * 3.0, 1.0) < 0.5)
		var bc := Color(1, 0.2, 0.15) if (boss and boss.get("enraged")) else Color(1, 0.55, 0.1)
		draw_circle(b + Vector2(0, -6), 8, bc if on else bc.darkened(0.5))
		if on:
			draw_circle(b + Vector2(0, -6), 16, Color(bc, 0.25))

	## Lo que muestra el visor: la cara o el nombre.
	func _face(v: Rect2) -> void:
		var f := ThemeDB.fallback_font
		var c := v.get_center()
		var col := Color(1, 0.75, 0.2)
		match visor:
			"name":
				var n := int(round(write_k * 14.0))
				var s := "STACK OVERFLOW".substr(0, n)
				draw_string(f, Vector2(v.position.x, c.y + 4), s, HORIZONTAL_ALIGNMENT_CENTER, v.size.x, 9, Color(1, 0.35, 0.3))
				return
			"dead":
				draw_string(f, Vector2(v.position.x, c.y + 5), "0 %", HORIZONTAL_ALIGNMENT_CENTER, v.size.x, 14, Color(1, 0.3, 0.25))
				return
		for s in [-1.0, 1.0]:
			var e := c + Vector2(14 * s, -1)
			match mood:
				1:
					draw_line(e + Vector2(-6 * s, -6), e + Vector2(6 * s, -1), Color(1, 0.3, 0.25), 2.5)
					draw_rect(Rect2(e.x - 4, e.y, 8, 4), Color(1, 0.3, 0.25))
				2:
					draw_line(e + Vector2(-4, -4), e + Vector2(4, 4), Color(1, 1, 0.5), 2.0)
					draw_line(e + Vector2(4, -4), e + Vector2(-4, 4), Color(1, 1, 0.5), 2.0)
				3:
					draw_arc(e + Vector2(0, 3), 5, PI, TAU, 8, col, 2.5)
				_:
					if fmod(t, 3.0) > 0.12:
						draw_rect(Rect2(e.x - 5, e.y - 3, 10, 6), col)

	func _crane() -> void:
		draw_circle(Vector2.ZERO, 13, STEEL_D)
		# pluma de celosía amarilla
		_box(Rect2(-9, 0, 18, 96), YELLOW, 2.0)
		for k in 6:
			var y := 6.0 + k * 15.0
			draw_line(Vector2(-8, y), Vector2(8, y + 12), YELLOW_D, 2.0)
		draw_arc(Vector2.ZERO, 13, 0, TAU, 14, OUT, 2.0)
		# cable
		draw_line(Vector2(0, 96), Vector2(0, 112), Color(0.2, 0.2, 0.22), 2.0)
		var e := Vector2(0, 118)
		match tool:
			0:   # gancho
				draw_rect(Rect2(-6, 108, 12, 8), STEEL_D)
				draw_arc(e + Vector2(0, 6), 8, -0.3, PI + 0.6, 12, STEEL, 4.0)
			1:   # ancla
				var c := Color(0.35, 0.37, 0.4)
				draw_rect(Rect2(-3, 110, 6, 22), c)
				draw_arc(Vector2(0, 126), 14, 0.2, PI - 0.2, 12, c, 5.0)
			_:   # bola de demolición
				draw_circle(e + Vector2(0, 16), 22, Color(0.22, 0.22, 0.25))
				draw_circle(e + Vector2(-7, 9), 6, Color(0.4, 0.4, 0.45))
				draw_arc(e + Vector2(0, 16), 22, 0, TAU, 20, OUT, 2.5)

	func _hammer() -> void:
		draw_circle(Vector2.ZERO, 13, STEEL_D)
		# brazo hidráulico
		_box(Rect2(-10, 0, 20, 52), YELLOW, 2.0)
		_box(Rect2(-5, 50, 10, 30), STEEL, 1.5)
		draw_arc(Vector2.ZERO, 13, 0, TAU, 14, OUT, 2.0)
		match tool:
			0:   # martillo neumático
				_box(Rect2(-12, 78, 24, 22), STEEL_D)
				draw_rect(Rect2(-4, 100, 8, 16), STEEL)
				draw_colored_polygon(PackedVector2Array([Vector2(-4, 116), Vector2(4, 116), Vector2(0, 124)]), STEEL)
			1:   # soplete de soldar
				_box(Rect2(-6, 78, 12, 26), Color(0.7, 0.15, 0.12))
				var fl := 6.0 + 3.0 * sin(t * 30.0)
				draw_colored_polygon(PackedVector2Array([Vector2(-4, 104), Vector2(4, 104), Vector2(0, 104 + fl * 2.0)]), Color(0.5, 0.8, 1.0))
			_:   # llave inglesa gigante
				_box(Rect2(-5, 78, 10, 30), STEEL)
				draw_arc(Vector2(0, 114), 11, PI * 0.15, PI * 1.85, 12, STEEL, 7.0)


## Plano azul: reemplaza la barra de vida (vida, fase y avance de obra de la torre).
class PlanPanel extends Control:
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
		draw_rect(r, Color(0.08, 0.22, 0.48, 0.94))
		for i in 25:
			draw_line(Vector2(i * 25, 0), Vector2(i * 25, 74), Color(0.6, 0.8, 1.0, 0.12), 1.0)
		for i in 4:
			draw_line(Vector2(0, i * 20), Vector2(600, i * 20), Color(0.6, 0.8, 1.0, 0.12), 1.0)
		if boss == null or not is_instance_valid(boss):
			return
		var f := ThemeDB.fallback_font
		var wc := Color(0.88, 0.95, 1.0)
		var k: float = float(boss.get("hp")) / float(boss.get("MAX_HP"))
		var ph: int = boss.get("phase")
		draw_string(f, Vector2(10, 16), "STACK OVERFLOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.8, 0.25))
		var names := ["Cimientos", "Estructura", "Entrega urgente"]
		var tag: String = names[ph - 1]
		if boss.get("enraged"):
			tag = "DERRUMBE"
		draw_string(f, Vector2(150, 16), "%s · Fase %d/3" % [tag, ph], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, wc)
		# avance de obra: pisos de la torre
		var tw: Node = boss.get("tower")
		var floors := 0
		if tw != null and is_instance_valid(tw):
			floors = int(tw.get("floors"))
		draw_string(f, Vector2(10, 42), "Avance de obra:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, wc)
		for i in 8:
			var cell := Rect2(120 + i * 30, 30, 26, 16)
			var full := i < floors
			var col := Color(1, 0.75, 0.2) if i < 5 else (Color(1, 0.45, 0.15) if i < 7 else Color(1, 0.2, 0.15))
			if full:
				draw_rect(cell, col)
			draw_rect(cell, wc, false, 1.0)
		if floors >= 8:
			draw_string(f, Vector2(370, 43), "¡DESBORDE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.3, 0.25))
		elif floors >= 2:
			draw_string(f, Vector2(370, 43), "base agrietada", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 1.0, 0.6))
		# tiempo de aplastado
		var cl: float = boss.get("crush_left")
		var ct: float = boss.get("crush_total")
		if cl > 0.0 and ct > 0.0:
			draw_rect(Rect2(480, 30, 110 * clampf(cl / ct, 0.0, 1.0), 14), Color(0.5, 1.0, 0.5))
			draw_rect(Rect2(480, 30, 110, 14), wc, false, 1.0)
		else:
			draw_string(f, Vector2(480, 42), "%d%%" % int(round(k * 100.0)), HORIZONTAL_ALIGNMENT_RIGHT, 110, 14, wc)
		# barra de vida
		draw_rect(Rect2(0, 62, 600, 10), Color(0.05, 0.1, 0.2, 0.9))
		draw_rect(Rect2(0, 62, 600 * _chip, 10), Color(1, 0.95, 0.85))
		draw_rect(Rect2(0, 62, 600 * k, 10), Color(1, 0.7, 0.15))
		for fr in [0.6, 0.3]:
			draw_rect(Rect2(600 * fr - 1, 62, 2, 10), Color(0, 0, 0, 0.8))
		draw_rect(r, wc, false, 1.5)


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
		# como un letrero de obra
		draw_rect(box, Color(0.1, 0.1, 0.1, 0.9 * a))
		draw_rect(box, Color(0.98, 0.76, 0.12, a), false, 3.0)
		draw_string(f, Vector2(-w * 0.5, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, a))
