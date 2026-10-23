extends CharacterBody2D
## Boss 4 SYNTAX ERROR (Facultad de Educación, Turismo y Humanidades): robot profesor con una pizarra en el pecho.
## Lo único: LA LECCIÓN. Cada cierto tiempo escribe en su pizarra una secuencia de símbolos (▲ ● ■ ★)
## y aparecen 4 pupitres. Golpear los pupitres en el mismo orden = APROBADO: queda aturdido 4 s con daño x2.
## Equivocarse o quedarse sin tiempo = REPROBADO: ráfaga de tizas y la próxima lección llega antes.
## Largo de la secuencia: 3, 4 y 5 según la fase.
## Versión de prueba con figuras de código; cuando lleguen las hojas de grokbot (bosses/syntax/) se cambian por sprites.
## Sin class_name: cargar con preload.

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Epic := preload("res://scripts/combat/epic_fx.gd")
const Barrage := preload("res://scripts/combat/boss_barrage.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Fx := preload("res://scripts/combat/boss_syntax_fx.gd")
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
const MOVE_SPEED := 70.0
const KEEP_DIST := 220.0
const PAUSE := [1.15, 0.9, 0.7]
const POISE := [8, 11, 14]
const ENRAGE_AT := 0.12
const PHASE_NAMES := ["CLASE INAUGURAL", "EXAMEN PARCIAL", "EXAMEN FINAL"]
const COMBOS := {
	2: [["whistle", "blocks"], ["bell", "planes"], ["period", "chalk"], ["braille", "bubbles"]],
	3: [["whistle", "chalk", "blocks"], ["bell", "planes"], ["rorschach", "chalk"], ["laps", "period"], ["braille", "planes"]],
}

# La Lección
const LESSON_FIRST := 8.0
const LESSON_EVERY := 18.0
const LESSON_RETRY := 11.0
const PASS_TIME := 4.0
const DESK_SPOTS := [Vector2(-330, 130), Vector2(-115, 220), Vector2(115, 220), Vector2(330, 130)]
## La lección por fase: F1 = 3 símbolos. F2 = 4 y SE BORRA de la pizarra al poco (memorizar).
## F3 = 5 escritos, uno TACHADO (trampa: no cuenta) y se leen AL REVÉS (de derecha a izquierda).
const ERASE_AFTER := 1.4
## Duelo final EXAMEN FINAL: preguntas dictadas una a una; pupitres girando por el aula.
const EXAM_QUESTIONS := 8
const EXAM_TIME := [2.6, 1.5]      # segundos para responder (primera → última)
const EXAM_ORBIT := 210.0

# pies en y 0
const SHOULDER_L := Vector2(-50, -194)
const SHOULDER_R := Vector2(50, -194)
const BOARD := Vector2(0, -148)
const HEAD := Vector2(0, -204)
const CENTER := Vector2(0, -130)
const ARM_HAND := 92.0
# con sprites (medido sobre boss_syntax_body_0, 133x206, pies abajo al centro)
const SPR_SHOULDER_L := Vector2(-51, -180)
const SPR_SHOULDER_R := Vector2(48, -181)
const SPR_BOARD := Vector2(0, -153)
const SPR_HEAD := Vector2(0, -199)
const REST_L := 0.2
const REST_R := -0.2

var hp: int = MAX_HP
var phase: int = 1
var state: String = "intro"
var arena_rect: Rect2 = Rect2(-500, -310, 1000, 620)
var player: CharacterBody2D
## La pizarra queda expuesta (daño x2). Mismo nombre que en los otros bosses para que la arena lo cuente.
var tank_open: bool = false
var enraged: bool = false

var lesson: bool = false
var _seq: Array[int] = []
var _seq_i: int = 0
var _seq_shown: int = 0
var _lesson_left: float = 0.0
var _lesson_total: float = 1.0
var _lesson_t: float = LESSON_FIRST
var passes: int = 0
## cómo se ve la lección: orden de respuesta (índices de _seq), trampa tachada, borrada, al revés
var _order: Array[int] = []
var _trap: int = -1
var _erased: bool = false
var _reverse: bool = false
## duelo final
var final_victory: bool = false
var _exam_sym: int = -1
var _exam_q: int = 0
var exam_n: int = EXAM_QUESTIONS
var _exam_left: float = 0.0
var _exam_total: float = 1.0
var _exam_ok: bool = false
var _exam_fail: bool = false
var _orbit_a: float = 0.0
var fails: int = 0

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
var _invert_t: float = 0.0
var rig_off: Vector2 = Vector2.ZERO
var panel: GradePanel
var _holo: Holo
var _home: Dictionary = {}

var rig: Node2D
var legs: Part
var torso: Part
var board: Part
var head: Part
var pointer: Part
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
	r.size = Vector2(80, 30)
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
	hr.size = Vector2(110, 250)
	hs.shape = hr
	hs.position = Vector2(0, -125)
	hurt.add_child(hs)
	add_child(hurt)
	GameFeel.add_shadow(self, Vector2(0, -2), Vector2(60, 13))
	_build_rig()


func set_player(p: CharacterBody2D) -> void:
	player = p


## La arena llama esto: la libreta de calificaciones reemplaza la barra de vida.
func build_hud(layer: CanvasLayer) -> void:
	panel = GradePanel.new()
	panel.boss = self
	panel.position = Vector2(340, 8)
	layer.add_child(panel)


# --- Piezas ----------------------------------------------------------------------

func _build_rig() -> void:
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)
	var spr := has_sprites()
	legs = _part("legs", Vector2.ZERO)
	torso = _part("torso", Vector2.ZERO)
	board = _part("board", SPR_BOARD if spr else BOARD)
	pointer = _part("pointer", SPR_SHOULDER_L if spr else SHOULDER_L)
	hand = _part("hand", SPR_SHOULDER_R if spr else SHOULDER_R)
	head = _part("head", SPR_HEAD if spr else HEAD)
	pointer.rotation = REST_L
	hand.rotation = REST_R
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
	return Spr.tex("boss_syntax_body_0") != null


func _parts() -> Array:
	return [legs, torso, board, pointer, hand, head]


## Cartel sobre la cabeza (también lo usa el semáforo del silbato).
func _say(text: String, col: Color = Color(0.95, 0.95, 0.85), time: float = 1.1) -> void:
	if _holo:
		_holo.show_text(text, col, time)


# --- Bucle ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_charge_cd -= delta
	if _invert_t > 0.0:
		_invert_t -= delta
		if _invert_t <= 0.0:
			_set_invert(false)
	if state != "dead":
		var bob := sin(_t * 2.0) * 1.5
		rig.position = rig_off + Vector2(0, bob)
		head.anim_off = head.anim_off.lerp(Vector2(0, sin(_t * 2.0 - 0.7) * 1.5), minf(1.0, delta * 8.0))
		pointer.anim_rot = sin(_t * 1.8) * 0.06 if state == "idle" else 0.0
		hand.anim_rot = sin(_t * 1.8 + 1.2) * 0.06 if state == "idle" else 0.0
		legs.step += velocity.length() * delta
		if enraged:
			var k := 0.75 + 0.25 * absf(sin(_t * 9.0))
			rig.modulate = Color(1.0, k, k * 0.6)
		else:
			rig.modulate = Color.WHITE
	if _charging:
		for v in _victims():
			_victim = v
			if _player_feet().distance_to(global_position) < 70.0 and CoopBoss.ready_for(self, "charge", v, 0.6):
				hurt_player(2, global_position, true)
		_victim = null
	if state == "final":
		_orbit_a += delta * (0.35 + 0.12 * _exam_q)
		var k := 0
		for d in get_tree().get_nodes_in_group("syntax_desk"):
			d.global_position = _orbit_pos(k)
			k += 1
	if _player_ok():
		z_index = 3 if _player_feet().y < global_position.y else 1
	match state:
		"idle":
			_ai_move(delta)
			if _player_ok() and _player_feet().distance_to(global_position) < 140.0:
				_near_t += delta
			else:
				_near_t = maxf(0.0, _near_t - delta)
			_lesson_t -= delta
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
	elif dist < KEEP_DIST - 70.0:
		dir = -to.normalized() * 0.6
	velocity = dir * MOVE_SPEED * (1.0 + 0.2 * (phase - 1))
	move_and_slide()
	rig.skew = lerpf(rig.skew, clampf(velocity.x / 700.0, -0.06, 0.06), 0.1)
	_clamp_inside()


func _clamp_inside() -> void:
	global_position.x = clampf(global_position.x, arena_rect.position.x + 80.0, arena_rect.end.x - 80.0)
	global_position.y = clampf(global_position.y, arena_rect.position.y + 310.0, arena_rect.end.y - 30.0)   # la cabeza no se mete bajo el panel


func _choose_attack() -> void:
	CoopBoss.retarget(self)
	var pick := ""
	if not _queue.is_empty():
		pick = _queue.pop_front()
	elif _lesson_t <= 0.0:
		pick = "lesson"
	elif _near_t > 1.3:
		pick = "stomp"
	elif phase >= 2 and randf() < (0.3 if phase == 2 else 0.45):
		var list: Array = COMBOS[phase]
		_queue.assign(list[randi() % list.size()])
		pick = _queue.pop_front()
	else:
		var pool: Array[String] = ["chalk", "blocks", "braille", "bubbles", "planes"]
		if phase >= 2:
			pool.append_array(["whistle", "bell", "period"])
		if phase >= 3:
			pool.append_array(["laps", "rorschach"])
		var bag: Array[String] = []
		for a in pool:
			if a != _last:
				bag.append(a)
		pick = bag[randi() % bag.size()]
	_near_t = 0.0
	_last = pick
	_tok += 1
	state = "attack"
	velocity = Vector2.ZERO
	call("_atk_" + pick, _tok)


func _end_attack(tok: int) -> void:
	if tok != _tok:
		return
	state = "idle"
	_charging = false
	_rest_pose()
	_rest_arms()
	head.mood = 0
	if board.mode != "name":
		board.mode = ""
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


func _hand_pos() -> Vector2:
	return global_position + _home[hand]


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
	_tw(pointer, "rotation", REST_L, 0.3)
	_tw(hand, "rotation", REST_R, 0.3)
	hand.tool = 0


## Color de los efectos épicos de este boss.
func _accent() -> Color:
	return Color(0.45, 0.9, 0.55)


func _impact(at: Vector2, strength: float) -> void:
	_shake(strength, 0.1 + strength * 0.03)
	Epic.big_hit(get_parent(), at, _accent(), strength, "syntax", "fxchalk")
	GameFeel.dust(get_parent(), at, int(4 + strength), Vector2.ZERO, 5.0, Vector2(20 + strength * 3.0, 6))
	GameFeel.hit_stop(get_tree(), 0.04)


func _warn_zone(at: Vector2, dir: Vector2, reach: float, half_angle: float, life: float) -> void:
	if reach >= 120.0:
		Epic.charge(get_parent(), global_position + CENTER, _accent(), life * 0.85, 110.0, self, CENTER)
	var z := BossFx.TeleZone.new()
	z.dir = dir
	z.reach = reach
	z.half_angle = half_angle
	z.life = life
	_add_fx(z, at)


func _chalk_fan(n: int, spread: float, speed: float) -> void:
	var from := _hand_pos() + Vector2(0, 60)
	var aim := _dir_to_player(from)
	for i in n:
		var c := Fx.Chalk.new()
		var k := 0.0 if n == 1 else (float(i) / (n - 1) - 0.5)
		c.vel = aim.rotated(k * spread) * speed
		_add_fx(c, from)


func _set_invert(on: bool) -> void:
	# multijugador: los controles se invierten para todos
	for p in CoopBoss.targets(get_tree()):
		if on:
			p.set("speed_mult", -1.0)
		elif float(p.get("speed_mult")) < 0.0:
			p.set("speed_mult", 1.0)


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
	if lesson:
		lesson = false
		_clear_desks(false)


func _clear_desks(broken: bool) -> void:
	for d in get_tree().get_nodes_in_group("syntax_desk"):
		d.call("vanish", broken)


func hurt_player(amount: int, from: Vector2, unblockable: bool = false) -> void:
	if not _player_ok() or state == "dead" or state == "paused":
		return
	_who().call("take_hit", amount, from, unblockable)


# --- La Lección ---------------------------------------------------------------------

## Escribe la secuencia en la pizarra, saca los pupitres y espera.
func _atk_lesson(tok: int) -> void:
	_say("LA LECCIÓN", Color(0.95, 0.95, 0.8), 1.4)
	head.mood = 0
	board.mode = "lesson"
	lesson = true
	_seq.clear()
	_seq_i = 0
	_seq_shown = 0
	_erased = false
	_reverse = phase >= 3
	_trap = -1
	var n: int = [3, 4, 5][phase - 1]
	var prev := -1
	for i in n:
		var s := randi() % 4
		while s == prev:
			s = randi() % 4
		_seq.append(s)
		prev = s
	if phase >= 3:
		_trap = 1 + randi() % (n - 2)   # nunca el primero ni el último
	_order.clear()
	for i in n:
		if i != _trap:
			_order.append(i)
	if _reverse:
		_order.reverse()
	# se planta frente al pizarrón del aula
	var spot := Vector2(clampf(global_position.x * 0.3, -120.0, 120.0), arena_rect.position.y + 310.0)
	_tw(self, "global_position", spot, 0.5)
	_tw(hand, "rotation", -PI * 0.75, 0.3)
	if not await _wait(0.55, tok):
		return
	# escribe un símbolo a la vez, con la tiza
	for i in n:
		_seq_shown = i + 1
		_tw(hand, "rotation", -PI * 0.75 + (0.25 if i % 2 == 0 else -0.25), 0.15)
		GameFeel.dust(get_parent(), global_position + BOARD + Vector2(-30 + i * 14, 0), 2, Vector2.ZERO, 2.0, Vector2(4, 4))
		if not await _wait(0.4, tok):
			return
	# aparecen los pupitres, cada uno con un símbolo
	var syms: Array[int] = [0, 1, 2, 3]
	syms.shuffle()
	for i in 4:
		var d := Fx.Desk.new()
		d.symbol = syms[i]
		var at: Vector2 = DESK_SPOTS[i]
		_add_fx(d, _clamp_arena(arena_rect.get_center() + at))
	_rest_arms()
	_lesson_total = 5.0 + 2.0 * n
	_lesson_left = _lesson_total
	var chalk_t := 0.0
	var erase_t := 0.0
	if _reverse:
		_say("¡AL REVÉS! Y SIN LO TACHADO", Color(1, 0.75, 0.35), 1.6)
	while lesson:
		if not await _wait(0.1, tok):
			return
		_lesson_left -= 0.1
		chalk_t += 0.1
		erase_t += 0.1
		if phase == 2 and not _erased and erase_t >= ERASE_AFTER:
			_erase_board()
		if phase >= 2 and chalk_t >= 1.7:
			chalk_t = 0.0
			_chalk_fan(1, 0.0, 300.0)
		if _lesson_left <= 0.0:
			_lesson_fail()
			return


## Lo llama cada pupitre al recibir un golpe.
func desk_hit(d: Node2D) -> void:
	if state == "final":
		_exam_answer(d)
		return
	if not lesson or _seq_shown < _seq.size() or state == "dead":
		return
	var sym: int = d.get("symbol")
	if sym == _seq[_order[_seq_i]]:
		d.call("mark", true)
		_seq_i += 1
		if _seq_i >= _order.size():
			_lesson_pass()
	else:
		d.call("mark", false)
		_lesson_fail()


## Cómo dibujar la lección (pizarra y barra del jefe), en el orden en que está escrita:
## [{sym, done, next, trap, hidden}] y si se lee al revés.
func lesson_view() -> Array:
	var out := []
	var done_set := {}
	for k in _seq_i:
		done_set[_order[k]] = true
	var nxt: int = _order[_seq_i] if _seq_i < _order.size() else -1
	for i in mini(_seq_shown, _seq.size()):
		out.append({"sym": _seq[i], "done": done_set.has(i), "next": i == nxt and not _erased,
			"trap": i == _trap, "hidden": _erased and not done_set.has(i)})
	return out


func lesson_reverse() -> bool:
	return _reverse


## Fase 2: borra la pizarra con el borrador (hay que recordar la secuencia).
func _erase_board() -> void:
	_erased = true
	_say("¡A MEMORIA!", Color(0.95, 0.95, 0.8), 1.0)
	var tw := create_tween()
	tw.tween_property(hand, "rotation", -PI * 0.75 + 0.35, 0.1)
	tw.tween_property(hand, "rotation", -PI * 0.75 - 0.35, 0.1)
	tw.tween_property(hand, "rotation", -PI * 0.75 + 0.35, 0.1)
	tw.tween_property(hand, "rotation", REST_R, 0.2)
	for i in 6:
		GameFeel.dust(get_parent(), global_position + BOARD + Vector2(-30 + i * 12, randf_range(-8, 8)), 2, Vector2.ZERO, 2.0, Vector2(6, 6))


## APROBADO: queda aturdido con la pizarra expuesta (daño x2).
func _lesson_pass() -> void:
	lesson = false
	passes += 1
	_clear_desks(false)
	_interrupt()
	var tok := _tok
	state = "stunned"
	board.mode = "pass"
	tank_open = true
	board.open = true
	head.mood = 2
	_say("¡APROBADO!", Color(0.45, 1.0, 0.5), 1.6)
	_tw(pointer, "rotation", 0.9, 0.3)
	_tw(hand, "rotation", -0.9, 0.3)
	_pose(Vector2(0, 12), 0.07, 0.3)
	_shake(5.0, 0.3)
	GameFeel.flash(rig, 0.3, Color(0.6, 1.0, 0.6))
	stunned.emit()
	var steps := int(PASS_TIME / 0.5)
	for i in steps:
		_pose(Vector2(0, 12), 0.07 * (1.0 if i % 2 == 0 else -1.0), 0.45)
		if not await _wait(0.5, tok):
			_close_board()
			return
	_close_board()
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.6
	head.mood = 0
	board.mode = ""
	_lesson_t = LESSON_EVERY


func _close_board() -> void:
	tank_open = false
	board.open = false
	if board.mode == "pass":
		board.mode = ""
	_lesson_t = LESSON_EVERY


## REPROBADO: castigo con ráfagas de tiza y la próxima lección llega antes.
func _lesson_fail() -> void:
	lesson = false
	fails += 1
	_clear_desks(true)
	_interrupt()
	var tok := _tok
	state = "attack"
	board.mode = "fail"
	head.mood = 1
	_lesson_t = LESSON_RETRY
	_say("¡REPROBADO!", Color(1, 0.3, 0.25), 1.4)
	GameFeel.flash(rig, 0.25, Color(1, 0.4, 0.3))
	_shake(4.0, 0.3)
	if not await _wait(0.5, tok):
		return
	hand.tool = 0
	for i in 3:
		_tw(hand, "rotation", _rot_for(_dir_to_player(_hand_pos())), 0.12)
		_chalk_fan(7 + 2 * (phase - 1), 1.1, 360.0)
		_pose(Vector2(0, -6), 0.0, 0.08)
		if not await _wait(0.45, tok):
			return
	if not await _wait(0.4, tok):
		return
	_end_attack(tok)


# --- EXAMEN FINAL (duelo final) --------------------------------------------------------
## A un golpe de caer: 4 pupitres giran por el aula y el profesor DICTA un símbolo cada vez
## (lo escribe en grande en la pizarra y lo señala con el puntero). Hay que golpear el pupitre de ese
## símbolo antes de que se acabe el tiempo, que es cada vez menor. EXAM_QUESTIONS aciertos = APROBADO.
## Un error o quedarse sin tiempo: REPROBADO, vuelve la fase 3 y el próximo golpe repite el examen.
func _start_exam() -> void:
	_interrupt()
	_set_invert(false)
	var tok := _tok
	state = "final"
	lesson = false
	tank_open = false
	board.open = false
	_clear_desks(false)
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	_exam_q = 0
	_exam_fail = false
	_exam_sym = -1
	Final.title(self, "EXAMEN FINAL", Color(0.95, 0.95, 0.8), "Golpea el pupitre del símbolo que dicta")
	Final.music_cue(self, "final1")
	head.mood = 1
	board.mode = "exam"
	var spot := Vector2(0.0, arena_rect.position.y + 310.0)
	_tw(self, "global_position", spot, 0.6)
	# reparte los exámenes: golpe de puntero en el escritorio
	_tw(pointer, "rotation", PI * 0.9, 0.25)
	_pose(Vector2(0, -8), -0.04, 0.25)
	if not await _wait(0.3, tok):
		return
	_tw(pointer, "rotation", 0.2, 0.07)
	_pose(Vector2(0, 6), 0.03, 0.07)
	_impact(global_position + Vector2(-60, 0), 6.0)
	# 4 pupitres que giran alrededor del centro del aula
	var syms: Array[int] = [0, 1, 2, 3]
	syms.shuffle()
	for k in 4:
		var d := Fx.Desk.new()
		d.symbol = syms[k]
		_add_fx(d, _orbit_pos(k))
	if not await _wait(0.8, tok):
		return
	while _exam_q < EXAM_QUESTIONS and not _exam_fail:
		# dicta: levanta la tiza, escribe el símbolo grande y lo señala
		var nsym := randi() % 4
		while nsym == _exam_sym:
			nsym = randi() % 4
		_exam_sym = -1
		_tw(hand, "rotation", -PI * 0.75, 0.12)
		if not await _wait(0.14, tok):
			return
		_exam_sym = nsym
		_exam_ok = false
		GameFeel.dust(get_parent(), global_position + BOARD, 4, Vector2.ZERO, 2.5, Vector2(10, 8))
		_tw(hand, "rotation", -PI * 0.75 + 0.3, 0.08)
		_exam_total = lerpf(EXAM_TIME[0], EXAM_TIME[1], float(_exam_q) / maxf(1.0, EXAM_QUESTIONS - 1))
		_exam_left = _exam_total
		# señala con el puntero el pupitre correcto un instante (solo en las primeras)
		var target := _desk_with(nsym)
		if target and _exam_q < 3:
			_tw(pointer, "rotation", _rot_for(_dir_to_player(global_position + SHOULDER_L) if target == null else (target.global_position - (global_position + SHOULDER_L)).normalized()), 0.15)
		while not _exam_ok and not _exam_fail:
			if not await _wait(0.05, tok):
				return
			_exam_left -= 0.05
			if _exam_left <= 0.0:
				_exam_fail = true
		if _exam_fail:
			break
		_exam_q += 1
		if _exam_q == 3:
			Final.music_cue(self, "final2")
		elif _exam_q == 6:
			Final.music_cue(self, "final3")
		_rest_arms()
		if not await _wait(0.18, tok):
			return
	_exam_sym = -1
	if _exam_fail:
		_exam_lost(tok)
	else:
		_exam_won()


## Posición del pupitre k en su órbita (gira más rápido con cada pregunta).
func _orbit_pos(k: int) -> Vector2:
	var c := arena_rect.get_center() + Vector2(0, 60)
	var a := _orbit_a + TAU * k / 4.0
	return c + Vector2(cos(a) * EXAM_ORBIT * 1.35, sin(a) * EXAM_ORBIT * 0.7)


func _desk_with(sym: int) -> Node2D:
	for d in get_tree().get_nodes_in_group("syntax_desk"):
		if int(d.get("symbol")) == sym:
			return d
	return null


func _exam_answer(d: Node2D) -> void:
	if _exam_sym < 0 or _exam_fail or _exam_ok:
		return
	if int(d.get("symbol")) == _exam_sym:
		d.call("mark", true)
		_exam_ok = true
		_say("✓ %d/%d" % [_exam_q + 1, EXAM_QUESTIONS], Color(0.5, 1, 0.55), 0.6)
		GameFeel.hit_stop(get_tree(), 0.04)
		# el profe se sobresalta
		head.anim_off += Vector2(0, -5)
		GameFeel.squash(rig, Vector2(0.97, 1.04), 0.12, 0.0)
		var wd: WeakRef = weakref(d)
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(func() -> void:
			var dd: Variant = wd.get_ref()
			if dd != null and dd.get("state") == 1:
				dd.set("state", 0))
	else:
		d.call("mark", false)
		_exam_fail = true


func _exam_won() -> void:
	# clímax con QTE antes del remate; si se falla, vuelve la fase 3 como al perder el duelo
	if not await _climax():
		_exam_lost(_tok)
		return
	final_victory = true
	_clear_desks(false)
	Final.music_final(self, "epic")
	Final.title(self, "¡APROBASTE!", Color(0.5, 1.0, 0.55), "10/10 para ti", 1.2)
	GameFeel.flash(rig, 0.4, Color(0.6, 1.0, 0.6))
	await _finisher()
	_shake(10.0, 0.6)
	hp = 0
	hp_changed.emit(hp, MAX_HP)
	_die()


func _exam_lost(tok: int) -> void:
	_clear_desks(true)
	Final.title(self, "¡REPROBADO!", Color(1.0, 0.35, 0.3), "", 1.1)
	Final.music_cue(self, "p3")
	board.mode = "fail"
	head.mood = 1
	hand.tool = 0
	for i in 2:
		_tw(hand, "rotation", _rot_for(_dir_to_player(_hand_pos())), 0.12)
		_chalk_fan(9, 1.1, 360.0)
		if not await _wait(0.4, tok):
			return
	if not await _wait(0.5, tok):
		return
	board.mode = ""
	_rest_arms()
	_rest_pose()
	head.mood = 0
	state = "idle"
	_cd = 1.0
	_lesson_t = LESSON_RETRY


# --- Recibir daño ----------------------------------------------------------------

func take_hit(amount: int, from: Vector2) -> void:
	if state in ["intro", "transition", "dead", "paused", "final"]:
		GameFeel.flash(rig, 0.08, Color(0.6, 0.6, 0.7))
		return
	var dmg := amount * (2 if tank_open else 1)
	# a un golpe de caer en la fase 3: EXAMEN FINAL en vez de morir
	if phase >= 3 and not final_victory and hp - dmg <= 0:
		hp = 1
		hp_changed.emit(hp, MAX_HP)
		_start_exam()
		return
	hp = maxi(0, hp - dmg)
	hp_changed.emit(hp, MAX_HP)
	GameFeel.flash(rig, 0.1 + 0.02 * dmg, Color(1.0, 0.95, 0.9))
	GameFeel.squash(rig, Vector2(1.03, 0.97), 0.14, 0.0)
	GameFeel.hit_stop(get_tree(), 0.03 + 0.02 * mini(dmg, 3))
	var center := global_position + CENTER
	var toward := from - center
	toward = Vector2.DOWN if toward.length() < 0.01 else toward.normalized()
	head.anim_off += -toward * (4.0 + 2.0 * dmg)
	var num := BossFx.DmgNumber.new()
	num.text = str(dmg) + ("!" if tank_open else "")
	num.big = tank_open
	num.color = Color(0.6, 1, 0.6) if tank_open else Color(1, 1, 1)
	get_parent().add_child(num)
	num.global_position = center + toward * 40.0 + Vector2(0, -40)
	if tank_open:
		GameFeel.parry_burst(get_parent(), global_position + BOARD, 34.0)
	else:
		var sp := BossFx.Sparks.new()
		sp.dir = toward
		get_parent().add_child(sp)
		sp.global_position = center + toward * 44.0
	if hp <= 0:
		_die()
		return
	if phase < 3 and hp <= int(MAX_HP * PHASE_AT[phase - 1]):
		_enter_phase(phase + 1)
		return
	if phase >= 3 and not enraged and hp <= int(MAX_HP * ENRAGE_AT):
		_enrage()
		return
	if not tank_open and not lesson and state in ["idle", "attack"]:
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


func _stagger() -> void:
	_interrupt()
	var tok := _tok
	state = "stunned"
	head.mood = 2
	_say("ERR?", Color(1, 0.8, 0.4))
	_pose(Vector2(0, 8), 0.07 * (1.0 if randf() < 0.5 else -1.0), 0.12)
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
	tank_open = false
	board.open = false
	_interrupt()
	var tok := _tok
	state = "transition"
	board.mode = ""
	if n == 2:
		head.cap = false
		torso.loose = true
		var c := Fx.CapFall.new()
		_add_fx(c, global_position + HEAD + Vector2(0, -60))
	else:
		head.cracked = true
		torso.dirty = true
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
	# cada examen empieza con una lección
	_lesson_t = minf(_lesson_t, 2.0)


func _enrage() -> void:
	enraged = true
	tank_open = false
	board.open = false
	_interrupt()
	var tok := _tok
	state = "transition"
	board.cracked = true
	head.mood = 1
	_say("RECUPERACIÓN", Color(1, 0.4, 0.3), 1.4)
	_pose(Vector2(0, -14), 0.0, 0.3)
	GameFeel.flash(rig, 0.4, Color(1.0, 0.5, 0.3))
	_shake(9.0, 1.0)
	phase_changed.emit(3, "RECUPERACIÓN")
	if not await _wait(1.3, tok):
		return
	_rest_pose()
	state = "idle"
	_cd = 0.3
	head.mood = 0


# --- Ataques ---------------------------------------------------------------------------

## 1. Educación Básica: ráfaga de tizas en abanico. Se pueden bloquear o hacer parry.
func _atk_chalk(tok: int) -> void:
	_say("¡ATENCIÓN!", Color(0.95, 0.95, 0.85))
	hand.tool = 0
	var volleys: int = [2, 2, 3][phase - 1]
	var n: int = [5, 7, 7][phase - 1]
	for v in volleys:
		var aim := _dir_to_player(_hand_pos())
		_tw(hand, "rotation", _rot_for(aim) - 0.6, 0.3)
		_pose(-aim * 8.0, -0.04, 0.3)
		if not await _wait(0.4, tok):
			return
		_tw(hand, "rotation", _rot_for(aim), 0.08)
		_chalk_fan(n, 0.9, 330.0 + 25.0 * phase)
		_pose(aim * 8.0, 0.03, 0.08)
		if not await _wait(0.45, tok):
			return
	if not await _wait(0.3, tok):
		return
	_end_attack(tok)


## 2. Educación Inicial: lluvia de bloques ABC con sombra previa.
func _atk_blocks(tok: int) -> void:
	_say("A B C", Color(1, 0.7, 0.4))
	_tw(pointer, "rotation", PI * 0.85, 0.3)
	_tw(hand, "rotation", -PI * 0.85, 0.3)
	_pose(Vector2(0, -8), 0.0, 0.3)
	var n: int = [6, 8, 10][phase - 1]
	var letters := ["A", "B", "C", "D", "E", "1", "2", "3"]
	var cols := [Color(0.95, 0.4, 0.35), Color(0.35, 0.6, 0.95), Color(0.4, 0.8, 0.4), Color(0.95, 0.75, 0.25)]
	var center := _player_feet() if _player_ok() else global_position + Vector2(0, 150)
	for i in n:
		var b := Fx.BlockDrop.new()
		b.delay = 0.12 * i
		b.letter = letters[i % letters.size()]
		b.col = cols[i % cols.size()]
		var at := center if i == 0 else center + Vector2(randf_range(-180, 180), randf_range(-110, 110))
		_add_fx(b, _clamp_arena(at))
	if not await _wait(0.12 * n + 0.85 + 0.4, tok):
		return
	_end_attack(tok)


## 3. Educación Inclusiva: filas de puntos braille que se convierten en púas. Los huecos son seguros.
func _atk_braille(tok: int) -> void:
	_say("BRAILLE", Color(1, 0.85, 0.4))
	_tw(pointer, "rotation", PI * 0.4, 0.3)
	var rows: int = [2, 3, 3][phase - 1]
	for i in rows:
		var r := Fx.BrailleRow.new()
		r.x0 = arena_rect.position.x + 20.0
		r.x1 = arena_rect.end.x - 20.0
		r.warn = 0.85 if phase == 1 else 0.7
		var gw := 80.0
		var g1 := randf_range(r.x0, r.x1 - gw)
		var g2 := randf_range(r.x0, r.x1 - gw)
		r.gaps = [Vector2(g1, g1 + gw), Vector2(g2, g2 + gw)]
		var y := _player_feet().y if _player_ok() else 100.0
		_add_fx(r, Vector2(0, clampf(y, arena_rect.position.y + 60.0, arena_rect.end.y - 20.0)))
		_pose(Vector2(0, 6), 0.0, 0.1)
		_impact(global_position, 2.0)
		if not await _wait(0.8, tok):
			return
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)


## 4. Entrenamiento Deportivo: silbato. Luz roja = quieto; si te mueves, daño.
func _atk_whistle(tok: int) -> void:
	_say("¡PRIIIT!", Color(1, 1, 1))
	hand.tool = 1
	_tw(hand, "rotation", -PI * 0.95, 0.3)
	var cycles: int = [2, 3, 3][phase - 1]
	var l := Fx.RedLight.new()
	l.cycles = cycles
	l.red = 1.1 if phase < 3 else 1.3
	l.area = arena_rect
	_add_fx(l, Vector2.ZERO)
	var per := l.green + l.red
	var green := l.green
	var total := per * cycles
	var t := 0.0
	var thrown := -1
	while t < total:
		if not await _wait(0.1, tok):
			return
		t += 0.1
		# en verde tira una tiza para obligar a moverse
		var cyc := int(t / per)
		if phase >= 2 and cyc < cycles and cyc != thrown and fmod(t, per) > 0.4 and fmod(t, per) < green:
			thrown = cyc
			_chalk_fan(3, 0.5, 320.0)
	_end_attack(tok)


## 5. Pedagogía de la Actividad Física: pone conos y da vueltas embistiendo. Al terminar queda mareado.
func _atk_laps(tok: int) -> void:
	_say("¡VUELTAS!", Color(1, 0.6, 0.3))
	var top := arena_rect.position.y + 310.0
	var pts: Array[Vector2] = [Vector2(-320, top), Vector2(320, top), Vector2(320, top + 230), Vector2(-320, top + 230)]
	for p in pts:
		var c := Fx.Cone.new()
		_add_fx(c, p)
	# empieza por el cono más cercano
	var start := 0
	for i in 4:
		if pts[i].distance_to(global_position) < pts[start].distance_to(global_position):
			start = i
	_pose(Vector2(0, 10), -0.08, 0.4)
	_tw(self, "global_position", pts[start], 0.45)
	if not await _wait(0.75, tok):
		return
	_charging = true
	var segs: int = [4, 5, 6][phase - 1]
	var seg_t := 0.42 if phase < 3 else 0.36
	for s in segs:
		var to := pts[(start + s + 1) % 4]
		var dir := (to - global_position).normalized()
		_pose(Vector2.ZERO, dir.x * 0.12, 0.1)
		legs.step += 60.0
		var tw := _tw(self, "global_position", to, seg_t)
		tw.set_trans(Tween.TRANS_LINEAR)
		GameFeel.dust(get_parent(), global_position, 4, -dir * 40.0, 4.0, Vector2(20, 6))
		if not await _wait(seg_t, tok):
			return
	_charging = false
	for c in get_tree().get_nodes_in_group("boss_hazard"):
		if c is Fx.Cone:
			c.queue_free()
	# mareado: ventana para pegarle
	head.mood = 2
	_say("@_@", Color(1, 1, 0.5))
	for i in 3:
		_pose(Vector2(0, 8), 0.08 * (1.0 if i % 2 == 0 else -1.0), 0.35)
		if not await _wait(0.4, tok):
			return
	_end_attack(tok)


## 6. Gestión Hotelera Internacional: la campanilla llama a los botones con sus carritos.
func _atk_bell(tok: int) -> void:
	_say("DING!", Color(1, 0.85, 0.3))
	hand.tool = 2
	_tw(hand, "rotation", -PI * 0.5, 0.25)
	if not await _wait(0.35, tok):
		return
	_pose(Vector2(0, 4), 0.0, 0.06)
	_shake(2.0, 0.1)
	var n: int = [2, 2, 3][phase - 1]
	var have := get_tree().get_nodes_in_group("boss_minion").size()
	for i in mini(n, 4 - have):
		var b := Fx.Bellhop.new()
		var side := -1.0 if i % 2 == 0 else 1.0
		_add_fx(b, _clamp_arena(Vector2(side * (arena_rect.size.x * 0.5 - 60.0), randf_range(-40, 200))))
		GameFeel.dust(get_parent(), b.global_position, 6, Vector2.ZERO, 4.0, Vector2(26, 6))
	if not await _wait(0.9, tok):
		return
	_end_attack(tok)


## 7. Lengua y Literatura: páginas voladoras y luego un PUNTO FINAL gigante.
func _atk_period(tok: int) -> void:
	_say("PUNTO FINAL.", Color(0.9, 0.9, 1.0))
	var aim := _dir_to_player(global_position + SHOULDER_L)
	_tw(pointer, "rotation", _rot_for(aim), 0.3)
	if not await _wait(0.35, tok):
		return
	var pages: int = [4, 6, 6][phase - 1]
	for i in pages:
		var p := Fx.Page.new()
		var a := _dir_to_player(global_position + SHOULDER_L).rotated(randf_range(-0.5, 0.5))
		p.vel = a * 230.0
		_add_fx(p, global_position + SHOULDER_L + aim * 100.0)
		if not await _wait(0.12, tok):
			return
	var dots := 1 if phase < 3 else 2
	for i in dots:
		var d := Fx.Period.new()
		_add_fx(d, _player_feet() if _player_ok() else global_position + Vector2(0, 160))
		_tw(pointer, "rotation", _rot_for(_dir_to_player(global_position + SHOULDER_L)), 0.2)
		if not await _wait(0.6, tok):
			return
	if not await _wait(1.0, tok):
		return
	_end_attack(tok)


## 8. Pedagogía de los Idiomas: globos de diálogo que rebotan por el aula. Se pueden romper.
func _atk_bubbles(tok: int) -> void:
	_say("Hello! Bonjour!", Color(0.6, 0.85, 1.0))
	var words := ["Hello", "Bonjour", "Hola", "Ciao", "Olá", "Hallo", "Konnichiwa"]
	words.shuffle()
	var n: int = [3, 4, 5][phase - 1]
	for i in n:
		var b := Fx.Bubble.new()
		b.arena = arena_rect
		b.text = words[i % words.size()]
		var a := Vector2.DOWN.rotated(randf_range(-1.2, 1.2))
		b.vel = a * randf_range(190.0, 230.0)
		_add_fx(b, global_position + HEAD + Vector2(randf_range(-30, 30), -30))
		_pose(Vector2(0, -6), 0.0, 0.08)
		if not await _wait(0.25, tok):
			return
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)


## 9. Psicología Educativa: lámina de Rorschach. Controles invertidos 3 s.
func _atk_rorschach(tok: int) -> void:
	_say("¿QUÉ VES?", Color(0.85, 0.7, 1.0), 1.4)
	head.mood = 3
	_pose(Vector2(0, -6), 0.0, 0.3)
	if not await _wait(0.6, tok):
		return
	var ink := Fx.InkBlot.new()
	ink.target = player
	_add_fx(ink, _player_body() if _player_ok() else global_position)
	_set_invert(true)
	_invert_t = 3.0
	if not await _wait(0.8, tok):
		return
	_chalk_fan(5, 0.8, 300.0)
	if not await _wait(1.0, tok):
		return
	_end_attack(tok)


## 10. Turismo Sostenible: boletos-avión de papel que persiguen al jugador.
func _atk_planes(tok: int) -> void:
	_say("¡BUEN VIAJE!", Color(0.5, 0.85, 1.0))
	hand.tool = 0
	var n: int = [3, 4, 5][phase - 1]
	for i in n:
		var aim := _dir_to_player(_hand_pos())
		_tw(hand, "rotation", _rot_for(aim), 0.15)
		var p := Fx.PaperPlane.new()
		p.vel = aim.rotated(randf_range(-1.0, 1.0)) * (200.0 + 15.0 * phase)
		_add_fx(p, _hand_pos() + aim * ARM_HAND)
		if not await _wait(0.3, tok):
			return
	if not await _wait(0.8, tok):
		return
	_end_attack(tok)


## 11. Pisotón de zapatillas (si el jugador se queda pegado).
func _atk_stomp(tok: int) -> void:
	_say("!!", Color(1, 0.5, 0.3))
	var max_r := 240.0 if phase < 3 else 310.0
	_warn_zone(global_position, Vector2.DOWN, max_r, 0.0, 0.85)
	_pose(Vector2(0, -36), 0.0, 0.6)
	if not await _wait(0.85, tok):
		return
	_pose(Vector2(0, 6), 0.0, 0.07)
	_impact(global_position, 9.0)
	var ring := BossFx.ShockRing.new()
	ring.max_r = max_r
	_add_fx(ring, global_position)
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)



# --- Lluvia de cambio de fase propia: EXAMEN SORPRESA -------------------------------------
## Anillos de tizas, letras que caen del techo, filas de braille con huecos y aviones de papel.
func barrage_title(_n: int) -> String:
	return "EXAMEN SORPRESA"


func barrage_plan(n: int) -> Array:
	if n == 2:
		return [[0.2, "chalk", {"n": 14}], [1.2, "blocks", {"n": 8}], [2.8, "braille", {"rows": 2}],
			[4.6, "planes", {"n": 6}], [5.6, "chalk", {"n": 16}]]
	return [[0.2, "chalk", {"n": 16}], [1.0, "blocks", {"n": 10}], [2.4, "braille", {"rows": 3}],
		[4.4, "planes", {"n": 8}], [5.2, "chalk", {"n": 18}], [6.4, "blocks", {"n": 12}], [7.6, "chalk", {"n": 20}]]


func _bfx(n: Node2D, at: Vector2) -> void:
	_add_fx(n, at)
	Barrage.tag(n)


func _bar_chalk(a: Dictionary, _tok: int) -> void:
	var n: int = a["n"]
	var off := randf() * TAU
	hand.tool = 0
	_tw(hand, "rotation", -PI * 0.75, 0.1)
	for i in n:
		var c := Fx.Chalk.new()
		c.vel = Vector2.from_angle(off + TAU * i / n) * 300.0
		_bfx(c, global_position + BOARD)


func _bar_blocks(a: Dictionary, _tok: int) -> void:
	var letters := ["A", "B", "C", "D", "E", "1", "2", "3", "{", "}"]
	var cols := [Color(0.95, 0.4, 0.35), Color(0.35, 0.6, 0.95), Color(0.4, 0.8, 0.4), Color(0.95, 0.75, 0.25)]
	for i in int(a["n"]):
		var b := Fx.BlockDrop.new()
		b.delay = 0.1 * i
		b.letter = letters[i % letters.size()]
		b.col = cols[i % cols.size()]
		var at := _player_feet() if (_player_ok() and i % 3 == 0) else Vector2(randf_range(arena_rect.position.x + 60, arena_rect.end.x - 60), randf_range(arena_rect.position.y + 100, arena_rect.end.y - 40))
		_bfx(b, _clamp_arena(at))


func _bar_braille(a: Dictionary, tok: int) -> void:
	for i in int(a["rows"]):
		var r := Fx.BrailleRow.new()
		r.x0 = arena_rect.position.x + 20.0
		r.x1 = arena_rect.end.x - 20.0
		r.warn = 0.75
		var gw := 90.0
		var g1 := randf_range(r.x0, r.x1 - gw)
		r.gaps = [Vector2(g1, g1 + gw)]
		var y := _player_feet().y if _player_ok() else 100.0
		_bfx(r, Vector2(0, clampf(y, arena_rect.position.y + 60.0, arena_rect.end.y - 20.0)))
		_impact(global_position, 2.0)
		if not await _wait(0.75, tok):
			return


func _bar_planes(a: Dictionary, _tok: int) -> void:
	var n: int = a["n"]
	for i in n:
		var p := Fx.PaperPlane.new()
		p.vel = Vector2.from_angle(TAU * i / n) * 220.0
		_bfx(p, global_position + BOARD)


## REMATE: un 0/10 gigante en rojo se estampa sobre su pizarra; la tiza explota en polvo.
func _finisher() -> void:
	board.mode = "dead"
	var st := Final.StampSlam.new()
	st.text = "0/10"
	st.col = Color(0.9, 0.15, 0.15)
	st.w = 240.0
	st.life = 1.0   # se va antes de que salga la tarjeta con la nota final
	get_parent().add_child(st)
	st.global_position = global_position + Vector2(0, 30)
	await get_tree().create_timer(0.36).timeout
	_shake(8.0, 0.35)
	_pose(Vector2(0, 12), 0.05, 0.1)
	for i in 8:
		GameFeel.dust(get_parent(), global_position + BOARD + Vector2(randf_range(-40, 40), randf_range(-20, 20)), 3, Vector2(0, -40), 4.0, Vector2(10, 8))
	head.mood = 2
	await get_tree().create_timer(0.9).timeout


# --- Aparición y muerte -----------------------------------------------------------

func start_intro(skip: bool) -> void:
	state = "intro"
	if skip:
		await get_tree().create_timer(0.6).timeout
		intro_finished.emit()
		return
	# 1. suena el timbre de la escuela
	for p in _parts():
		p.visible = false
	head.cap = false
	var home := position
	await get_tree().create_timer(0.4).timeout
	var bell := Fx.SchoolBell.new()
	get_parent().add_child(bell)
	bell.global_position = Vector2(arena_rect.get_center().x, arena_rect.position.y + 40.0)
	_shake(2.0, 1.2)
	await get_tree().create_timer(1.4).timeout
	# 2. entra caminando desde el fondo del aula
	for p in [legs, torso, board, pointer, hand, head]:
		p.visible = true
	position = home + Vector2(0, -220)
	modulate.a = 0.0
	var walk := create_tween().set_parallel(true)
	walk.tween_property(self, "position", home, 1.4)
	walk.tween_property(self, "modulate:a", 1.0, 0.4)
	walk.tween_property(legs, "step", 300.0, 1.4)
	await walk.finished
	_shake(3.0, 0.2)
	# 3. escribe su nombre en la pizarra
	board.mode = "name"
	board.write_k = 0.0
	_tw(hand, "rotation", -PI * 0.75, 0.3)
	var wr := create_tween()
	wr.tween_property(board, "write_k", 1.0, 1.3)
	for i in 6:
		_tw(hand, "rotation", -PI * 0.75 + (0.2 if i % 2 == 0 else -0.2), 0.2)
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.2).timeout
	_tw(hand, "rotation", REST_R, 0.3)
	await get_tree().create_timer(0.5).timeout
	# 4. el birrete cae a la cabeza
	head.cap = true
	head.cap_y = -150.0
	var cap := create_tween()
	cap.tween_property(head, "cap_y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await cap.finished
	# 5. firma: raya la pizarra con las uñas. Chirrido de tiza y todo el salón tiembla de lado;
	#    luego golpea la pizarra con el puntero: SYNTAX ERROR.
	head.mood = 1
	_tw(hand, "rotation", 1.0, 0.2)              # la mano cruza hasta la pizarra
	_pose(Vector2(0, -4), 0.04, 0.2)
	await get_tree().create_timer(0.25).timeout
	var scr := Roar.Screech.new()
	Roar.spawn(get_parent(), scr, board.global_position)
	Roar.shake_x(player, 7.0, 0.8)
	_say("¡SILENCIO!", Color(0.95, 0.95, 0.85), 0.8)
	for i in 8:
		_tw(hand, "rotation", 0.75 if i % 2 == 0 else 1.25, 0.08)
		await get_tree().create_timer(0.09).timeout
	_tw(hand, "rotation", REST_R, 0.25)
	_tw(pointer, "rotation", -1.05, 0.12)       # el puntero golpea la pizarra
	await get_tree().create_timer(0.12).timeout
	GameFeel.parry_burst(get_parent(), board.global_position, 40.0)
	GameFeel.flash(board, 0.15, Color(1, 0.4, 0.35))
	_say("SYNTAX ERROR", Color(1, 0.35, 0.3), 1.2)
	_shake(6.0, 0.4)
	await get_tree().create_timer(1.0).timeout
	_rest_pose()
	_rest_arms()
	head.mood = 0
	board.mode = ""
	intro_finished.emit()


func begin_fight() -> void:
	state = "idle"
	_cd = 1.0
	_lesson_t = LESSON_FIRST


func pause_ai() -> void:
	_interrupt()
	_set_invert(false)
	state = "paused"


func _die() -> void:
	_interrupt()
	_set_invert(false)
	state = "dead"
	tank_open = false
	remove_from_group("enemies")
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.call("die")
	# la pizarra escribe la nota final en cámara lenta
	Engine.time_scale = 0.2
	board.mode = "dead"
	head.mood = 2
	await get_tree().create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 1.0
	_pose(Vector2(0, 8), 0.0, 0.4)
	var card := Fx.FailCard.new()
	get_parent().add_child(card)
	await get_tree().create_timer(2.6).timeout
	# la pizarra se parte, el globo rueda y el birrete sale volando
	board.broken = true
	GameFeel.parry_burst(get_parent(), global_position + BOARD, 70.0)
	if head.cap:
		head.cap = false
		var c := Fx.CapFall.new()
		_add_fx(c, global_position + HEAD + Vector2(0, -60))
	for i in 14:
		var d := BossFx.Debris.new()
		d.kind = i % 8
		d.prefix = "boss_syntax_debris_"
		d.vel = Vector2(randf_range(-280, 280), randf_range(-440, -200))
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-200, -80))
	for p in [pointer, hand]:
		var tw := create_tween()
		tw.tween_property(p, "rotation", (1.0 if p == pointer else -1.0) * 1.7, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(self, "rig_off", Vector2(0, 30), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(rig, "rotation", 0.12, 0.5)
	fall.tween_property(head, "anim_off", Vector2(90, 200), 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(head, "rotation", 4.0, 0.8)
	_shake(8.0, 0.4)
	GameFeel.dust(get_parent(), global_position, 14, Vector2.ZERO, 7.0, Vector2(80, 10))
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
	var step := 0.0
	# estados
	var mode := ""          # pizarra: "", name, lesson, pass, fail, dead
	var write_k := 1.0
	var open := false
	var broken := false
	var cracked := false
	var cap := true
	var cap_y := 0.0
	var loose := false
	var dirty := false
	var mood := 0           # cabeza: 0 normal, 1 enojado, 2 aturdido, 3 hipnótico
	var tool := 0           # mano: 0 tiza, 1 silbato, 2 campanilla

	const OUT := Color(0.05, 0.05, 0.06)
	const METAL := Color(0.55, 0.58, 0.62)
	const METAL_D := Color(0.38, 0.4, 0.45)
	const METAL_L := Color(0.72, 0.75, 0.78)
	const TWEED := Color(0.48, 0.34, 0.24)
	const TWEED_D := Color(0.36, 0.25, 0.17)
	const TIE := Color(0.6, 0.1, 0.12)
	const PANTS := Color(0.4, 0.42, 0.46)
	const WOOD := Color(0.55, 0.36, 0.2)
	const BOARD_C := Color(0.15, 0.36, 0.25)
	const CHALK := Color(0.95, 0.95, 0.9)

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
			"legs":
				_legs()
			"torso":
				_torso()
			"board":
				_board()
			"head":
				_head()
			"pointer":
				_pointer_arm()
			"hand":
				_hand_arm()

	func _legs() -> void:
		for j in 2:
			var s := -1.0 if j == 0 else 1.0
			var lift := maxf(0.0, sin(step * 0.06 + j * PI)) * 7.0
			var x := 18.0 * s
			# pierna larga de pantalón
			_box(Rect2(x - 9, -100 - lift, 18, 84), PANTS)
			draw_line(Vector2(x, -96 - lift), Vector2(x, -20 - lift), PANTS.darkened(0.2), 2.0)
			draw_circle(Vector2(x, -58 - lift), 6, METAL_D)
			# zapatilla deportiva
			var sh := Rect2(x - 14 + 4 * s, -18 - lift, 28, 16)
			_box(sh, Color(0.95, 0.95, 0.95))
			draw_rect(Rect2(sh.position.x, sh.end.y - 5, sh.size.x, 5), Color(0.85, 0.2, 0.2))
			draw_line(sh.position + Vector2(6, 5), sh.position + Vector2(16, 9), Color(0.85, 0.2, 0.2), 2.0)

	func _torso() -> void:
		# marco metálico del pecho
		_box(Rect2(-44, -204, 88, 110), METAL, 3.0)
		# saco de tweed a los lados
		for s in [-1.0, 1.0]:
			var v := PackedVector2Array([Vector2(44 * s, -204), Vector2(30 * s, -204), Vector2(40 * s, -180), Vector2(40 * s, -96), Vector2(46 * s, -96)])
			draw_colored_polygon(v, TWEED)
			v.append(v[0])
			draw_polyline(v, OUT, 2.0)
			# bolsillo con bolígrafos rojos (lado derecho)
			if s > 0:
				draw_rect(Rect2(32, -130, 10, 10), TWEED_D)
				draw_line(Vector2(35, -136), Vector2(35, -126), Color(0.9, 0.15, 0.15), 2.0)
				draw_line(Vector2(39, -137), Vector2(39, -126), Color(0.9, 0.15, 0.15), 2.0)
		# cuello y corbata arriba de la pizarra
		draw_colored_polygon(PackedVector2Array([Vector2(-14, -204), Vector2(14, -204), Vector2(0, -190)]), Color(0.95, 0.95, 0.92))
		var sway := sin(t * 3.0) * (5.0 if loose else 0.8)
		var tie := PackedVector2Array([Vector2(-4, -198), Vector2(4, -198), Vector2(6 + sway, -184), Vector2(sway, -180), Vector2(-6 + sway, -184)])
		draw_colored_polygon(tie, TIE)
		tie.append(tie[0])
		draw_polyline(tie, OUT, 1.5)
		# hombreras
		for s in [-1.0, 1.0]:
			_box(Rect2(50 * s - 12, -206, 24, 18), METAL_D)
		if dirty:
			draw_line(Vector2(-40, -110), Vector2(-28, -100), OUT, 2.0)
			draw_line(Vector2(30, -200), Vector2(22, -186), OUT, 2.0)

	# --- con sprites de grokbot ---
	# lentes de cada cabeza (centro en px de la imagen), para dibujar las expresiones encima
	const LENSES := [[Vector2(24, 32), Vector2(39, 32)], [Vector2(22, 20), Vector2(40, 20)], [Vector2(27, 24), Vector2(44, 24)]]
	# panel verde de la pizarra: centro relativo al centro del sprite y escala del texto
	const BOARD_IN := Vector2(0, -3)
	const BOARD_K := 0.6

	func _draw_sprite() -> bool:
		var body := Spr.tex("boss_syntax_body_0")
		if body == null:
			return false
		match kind:
			"legs":
				return true   # las piernas ya vienen en el sprite del cuerpo
			"torso":
				var tx: Texture2D = Spr.tex("boss_syntax_body_1") if dirty else body
				if tx == null:
					tx = body
				var bob := -absf(sin(step * 0.06)) * 3.0
				draw_texture(tx, anim_off + Vector2(-tx.get_width() * 0.5, -tx.get_height() + bob))
				return true
			"board":
				var idx := 2 if (broken or cracked) else (1 if open else 0)
				var tx := Spr.tex("boss_syntax_board_%d" % idx)
				if tx == null:
					return false
				if open:
					draw_rect(Rect2(-40, -36, 80, 72).grow(4.0 + 3.0 * sin(t * 10.0)), Color(0.6, 1.0, 0.5, 0.25))
				draw_texture(tx, anim_off - tx.get_size() * 0.5)
				draw_set_transform(anim_off + BOARD_IN, anim_rot, Vector2(BOARD_K, BOARD_K))
				_board_text(true)
				return true
			"head":
				var idx := 2 if cracked else (0 if cap else 1)
				var tx := Spr.tex("boss_syntax_head_%d" % idx)
				if tx == null:
					return false
				if idx == 0 and cap_y != 0.0:
					# el birrete cae durante la aparición: cabeza sin birrete + birrete suelto encima
					var bare := Spr.tex("boss_syntax_head_1")
					var h3 := Spr.tex("boss_syntax_head_3")
					if bare and h3:
						tx = bare
						idx = 1
						Spr.draw_centered(self, h3, anim_off + Vector2(4, -bare.get_height() - 4 + cap_y))
						draw_set_transform(anim_off, anim_rot, Vector2.ONE)
				var origin := anim_off + Vector2(-tx.get_width() * 0.5, -tx.get_height())
				draw_texture(tx, origin)
				if mood != 0:
					for e0 in LENSES[idx]:
						var e: Vector2 = origin + e0
						draw_circle(e, 5.0, Color(0.06, 0.08, 0.1))
						_eye(e, 1.0 if e0.x < tx.get_width() * 0.5 else -1.0)
				return true
			"pointer", "hand":
				var name := "boss_syntax_pointer_0" if kind == "pointer" else "boss_syntax_hand_%d" % tool
				var tx := Spr.tex(name)
				if tx == null:
					return false
				var piv := Spr.top_pivot(name)
				draw_set_transform(anim_off, anim_rot - Spr.lean(name), Vector2.ONE)
				draw_texture(tx, -piv)
				return true
		return false

	func _eye(e: Vector2, s: float) -> void:
		match mood:
			1:
				draw_line(e + Vector2(-4 * s, -4), e + Vector2(4 * s, -1), Color(1, 0.3, 0.25), 2.0)
				draw_circle(e + Vector2(0, 1.5), 2.0, Color(1, 0.35, 0.3))
			2:
				draw_line(e + Vector2(-3, -3), e + Vector2(3, 3), Color(1, 1, 0.5), 1.5)
				draw_line(e + Vector2(3, -3), e + Vector2(-3, 3), Color(1, 1, 0.5), 1.5)
			3:
				draw_arc(e, 3.5, t * 8.0, t * 8.0 + 4.5, 10, Color(0.85, 0.6, 1.0), 1.5)
			_:
				draw_circle(e, 2.0, Color.WHITE)

	# --- por código ---
	func _board() -> void:
		var r := Rect2(-40, -30, 80, 60)
		if open:
			draw_rect(r.grow(8.0 + 3.0 * sin(t * 10.0)), Color(0.6, 1.0, 0.5, 0.25))
		_box(r.grow(5), WOOD, 2.0)
		draw_rect(r, BOARD_C.lightened(0.15) if open else BOARD_C)
		# bandeja de tiza
		draw_rect(Rect2(-36, 34, 72, 4), WOOD.darkened(0.2))
		draw_rect(Rect2(-24, 31, 10, 3), CHALK)
		_board_text(false)

	## Lo que está escrito en la pizarra (en coordenadas de un panel de 80x60).
	func _board_text(spr: bool) -> void:
		var base := Transform2D(anim_rot, anim_off + (BOARD_IN if spr else Vector2.ZERO))
		var ks := BOARD_K if spr else 1.0
		var f := ThemeDB.fallback_font
		match mode:
			"name":
				var n := int(round(write_k * 12.0))
				var l1 := "SYNTAX".substr(0, mini(n, 6))
				var l2 := "ERROR".substr(0, maxi(0, n - 6))
				draw_string(f, Vector2(-40, -6), l1, HORIZONTAL_ALIGNMENT_CENTER, 80, 15, CHALK)
				draw_string(f, Vector2(-40, 14), l2, HORIZONTAL_ALIGNMENT_CENTER, 80, 15, CHALK)
			"exam":
				var es: int = boss.get("_exam_sym")
				if es >= 0:
					Fx.Sym.draw(self, es, Vector2(0, -4), 15.0, Fx.SYM_COL[es], false)
					var el: float = boss.get("_exam_left")
					var et: float = boss.get("_exam_total")
					draw_rect(Rect2(-34, 18, 68 * clampf(el / maxf(et, 0.01), 0.0, 1.0), 4), CHALK)
				draw_string(f, Vector2(-40, -18), "EXAMEN %d/%d" % [int(boss.get("_exam_q")) + 1, boss.get("exam_n")], HORIZONTAL_ALIGNMENT_CENTER, 80, 8, CHALK)
			"lesson":
				var view: Array = boss.call("lesson_view")
				var n: int = (boss.get("_seq") as Array).size()
				var gap := 15.0
				var x0 := -gap * (n - 1) * 0.5
				for i in view.size():
					var v: Dictionary = view[i]
					var c := Vector2(x0 + i * gap, -6)
					var k: int = v["sym"]
					var col: Color = Fx.SYM_COL[k]
					if v["done"]:
						col = Color(col, 0.35)
					if v["hidden"]:
						draw_string(f, c + Vector2(-6, 5), "?", HORIZONTAL_ALIGNMENT_CENTER, 12, 12, CHALK)
						continue
					Fx.Sym.draw(self, k, c, 6.0, col, false)
					if v["trap"]:
						draw_line(c + Vector2(-7, -7), c + Vector2(7, 7), Color(1, 0.3, 0.25), 2.5)
						draw_line(c + Vector2(7, -7), c + Vector2(-7, 7), Color(1, 0.3, 0.25), 2.5)
					if v["done"]:
						draw_line(c + Vector2(-5, 0), c + Vector2(-1, 4), Color(0.5, 1, 0.5), 2.0)
						draw_line(c + Vector2(-1, 4), c + Vector2(6, -5), Color(0.5, 1, 0.5), 2.0)
				if boss.call("lesson_reverse") and view.size() >= n:
					draw_line(Vector2(gap * n * 0.5, 7), Vector2(-gap * n * 0.5, 7), CHALK, 1.5)
					draw_line(Vector2(-gap * n * 0.5, 7), Vector2(-gap * n * 0.5 + 5, 4), CHALK, 1.5)
					draw_line(Vector2(-gap * n * 0.5, 7), Vector2(-gap * n * 0.5 + 5, 10), CHALK, 1.5)
				var left: float = boss.get("_lesson_left")
				var total: float = boss.get("_lesson_total")
				if view.size() >= n and total > 0.0 and not boss.get("_erased"):
					draw_rect(Rect2(-34, 16, 68 * clampf(left / total, 0.0, 1.0), 4), CHALK)
			"pass":
				draw_set_transform(base.origin, anim_rot - 0.15, Vector2(ks, ks))
				draw_rect(Rect2(-38, -11, 76, 22), Color(0.2, 0.75, 0.3), false, 2.0)
				draw_string(f, Vector2(-40, 5), "APROBADO", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(0.5, 1, 0.55))
				draw_set_transform(base.origin, anim_rot, Vector2(ks, ks))
			"fail":
				draw_set_transform(base.origin, anim_rot + 0.15, Vector2(ks, ks))
				draw_rect(Rect2(-38, -11, 76, 22), Color(0.9, 0.2, 0.2), false, 2.0)
				draw_string(f, Vector2(-40, 5), "REPROBADO", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(1, 0.35, 0.3))
				draw_set_transform(base.origin, anim_rot, Vector2(ks, ks))
			"dead":
				draw_string(f, Vector2(-40, -2), "0/10", HORIZONTAL_ALIGNMENT_CENTER, 80, 20, Color(1, 0.3, 0.25))
				draw_string(f, Vector2(-40, 16), "REPROBADO", HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color(1, 0.3, 0.25))
			_:
				# apuntes de clase según la fase
				var ph: int = boss.get("phase")
				var lines: Array = [["a + b = ?", "2x = 8"], ["PARCIAL", "x² = -1 ?"], ["FINAL", "1/0 = ?"]][ph - 1]
				draw_string(f, Vector2(-36, -8), lines[0], HORIZONTAL_ALIGNMENT_LEFT, 74, 11, Color(CHALK, 0.85))
				draw_string(f, Vector2(-36, 10), lines[1], HORIZONTAL_ALIGNMENT_LEFT, 74, 11, Color(CHALK, 0.85))
		if spr:
			return
		if cracked or broken:
			var w := 2.0 if not broken else 3.0
			draw_polyline(PackedVector2Array([Vector2(-30, -28), Vector2(-12, -6), Vector2(-20, 10), Vector2(-4, 28)]), Color(0.05, 0.08, 0.06), w)
			draw_polyline(PackedVector2Array([Vector2(-12, -6), Vector2(14, -14), Vector2(36, 2)]), Color(0.05, 0.08, 0.06), w)
		if broken:
			draw_polyline(PackedVector2Array([Vector2(10, 28), Vector2(18, 6), Vector2(38, -26)]), Color(0.05, 0.08, 0.06), 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(18, 6), Vector2(36, 2), Vector2(38, 26), Vector2(12, 28)]), Color(0.03, 0.03, 0.04))

	func _head() -> void:
		var g := Vector2(0, -30)
		# cuello con cables
		draw_rect(Rect2(-7, -8, 14, 10), METAL_D)
		draw_line(Vector2(-6, -4), Vector2(-14, 4), Color(0.85, 0.2, 0.2), 2.0)
		draw_line(Vector2(6, -4), Vector2(13, 5), Color(0.2, 0.45, 0.85), 2.0)
		# soporte de globo terráqueo
		draw_arc(g, 31.0, PI * 0.15, PI * 1.15, 16, Color(0.75, 0.6, 0.25), 3.0)
		# globo
		draw_circle(g, 26.0, Color(0.25, 0.5, 0.85))
		var spin := fmod(t * 6.0, 52.0)
		for c in [Vector2(-14, -8), Vector2(10, 6), Vector2(-4, 14), Vector2(18, -12)]:
			var cx: float = fmod(c.x + spin + 78.0, 52.0) - 26.0
			var p := g + Vector2(cx, c.y)
			if p.distance_to(g) < 22.0:
				draw_circle(p, 7.0, Color(0.35, 0.7, 0.35))
		draw_arc(g, 26.0, 0, TAU, 24, OUT, 2.0)
		draw_line(g + Vector2(-26, 0), g + Vector2(26, 0), Color(0.15, 0.3, 0.6, 0.6), 1.0)
		if cracked:
			draw_polyline(PackedVector2Array([g + Vector2(-18, -16), g + Vector2(-6, -4), g + Vector2(-10, 8)]), OUT, 1.5)
		# gafas
		for s in [-1.0, 1.0]:
			var e := g + Vector2(11 * s, -2)
			draw_circle(e, 9.0, Color(0.06, 0.08, 0.1))
			draw_arc(e, 9.0, 0, TAU, 16, OUT, 2.5)
			match mood:
				1:
					draw_line(e + Vector2(-5 * s, -5), e + Vector2(5 * s, -1), Color(1, 0.3, 0.25), 2.5)
					draw_circle(e + Vector2(0, 2), 2.5, Color(1, 0.35, 0.3))
				2:
					draw_line(e + Vector2(-4, -4), e + Vector2(4, 4), Color(1, 1, 0.5), 2.0)
					draw_line(e + Vector2(4, -4), e + Vector2(-4, 4), Color(1, 1, 0.5), 2.0)
				3:
					draw_arc(e, 5.0, t * 8.0, t * 8.0 + 4.5, 10, Color(0.85, 0.6, 1.0), 2.0)
				_:
					if fmod(t, 3.2) > 0.12:
						draw_circle(e, 3.0, Color(1, 1, 1))
		draw_line(g + Vector2(-2, -2), g + Vector2(2, -2), OUT, 2.0)
		# birrete
		if cap:
			var cy := g.y - 24.0 + cap_y
			draw_rect(Rect2(-14, cy - 2, 28, 10), Color(0.1, 0.1, 0.12))
			var top := PackedVector2Array([Vector2(-34, cy - 4), Vector2(0, cy - 16), Vector2(34, cy - 4), Vector2(0, cy + 8)])
			draw_colored_polygon(top, Color(0.08, 0.08, 0.1))
			top.append(top[0])
			draw_polyline(top, OUT, 1.5)
			var sw := sin(t * 2.5) * 3.0
			draw_line(Vector2(0, cy - 4), Vector2(24 + sw, cy + 4), Color(0.98, 0.78, 0.2), 2.0)
			draw_line(Vector2(24 + sw, cy + 4), Vector2(24 + sw, cy + 20), Color(0.98, 0.78, 0.2), 3.0)

	func _arm(upper: float) -> void:
		draw_circle(Vector2.ZERO, 11, METAL_D)
		_box(Rect2(-7, 0, 14, upper), TWEED)
		draw_circle(Vector2(0, upper), 7, METAL_D)
		_box(Rect2(-6, upper, 12, 30), METAL)
		draw_rect(Rect2(-8, upper + 2, 16, 5), Color(0.95, 0.95, 0.92))   # puño de camisa
		draw_arc(Vector2.ZERO, 11, 0, TAU, 14, OUT, 2.0)

	func _pointer_arm() -> void:
		_arm(46.0)
		# mano y puntero largo de madera
		draw_circle(Vector2(0, 82), 9, METAL_L)
		draw_arc(Vector2(0, 82), 9, 0, TAU, 14, OUT, 1.5)
		draw_line(Vector2(0, 70), Vector2(0, 180), OUT, 7.0)
		draw_line(Vector2(0, 70), Vector2(0, 180), WOOD.lightened(0.1), 4.0)
		draw_circle(Vector2(0, 182), 4, Color(0.85, 0.15, 0.15))

	func _hand_arm() -> void:
		_arm(46.0)
		draw_circle(Vector2(0, 84), 10, METAL_L)
		draw_arc(Vector2(0, 84), 10, 0, TAU, 14, OUT, 1.5)
		match tool:
			0:   # tiza y borrador
				draw_rect(Rect2(-3, 92, 6, 16), CHALK)
				draw_rect(Rect2(-3, 92, 6, 16), OUT, false, 1.0)
				_box(Rect2(6, 80, 18, 10), Color(0.3, 0.25, 0.2), 1.5)
				draw_rect(Rect2(6, 88, 18, 3), Color(0.8, 0.8, 0.8))
			1:   # silbato
				draw_line(Vector2(0, 84), Vector2(-10, 70), Color(0.85, 0.15, 0.15), 2.0)
				_box(Rect2(-8, 92, 18, 10), METAL_L, 1.5)
				draw_circle(Vector2(-6, 97), 6, METAL_L)
			_:   # campanilla de hotel
				draw_colored_polygon(PackedVector2Array([Vector2(-14, 112), Vector2(-10, 98), Vector2(0, 92), Vector2(10, 98), Vector2(14, 112)]), Color(0.98, 0.78, 0.2))
				draw_rect(Rect2(-17, 112, 34, 5), Color(0.2, 0.2, 0.22))
				draw_circle(Vector2(0, 90), 3, Color(0.98, 0.78, 0.2))


## Libreta de calificaciones: reemplaza la barra de vida (nota, fase y la lección en curso).
class GradePanel extends Control:
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
		draw_rect(r, Color(0.95, 0.93, 0.85, 0.94))
		for i in 4:
			draw_line(Vector2(0, 18 + i * 14), Vector2(600, 18 + i * 14), Color(0.55, 0.7, 0.95, 0.5), 1.0)
		draw_line(Vector2(40, 0), Vector2(40, 74), Color(0.9, 0.35, 0.35, 0.7), 1.5)
		if boss == null or not is_instance_valid(boss):
			return
		var f := ThemeDB.fallback_font
		var k: float = float(boss.get("hp")) / float(boss.get("MAX_HP"))
		var ph: int = boss.get("phase")
		draw_string(f, Vector2(48, 15), "SYNTAX ERROR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.15, 0.15))
		var names := ["Clase inaugural", "Examen parcial", "Examen final"]
		var tag: String = names[ph - 1]
		if boss.get("enraged"):
			tag = "RECUPERACIÓN"
		draw_string(f, Vector2(160, 15), "%s · Fase %d/3" % [tag, ph], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.25, 0.45))
		# nota grande a la derecha
		var grade := 10.0 * k
		var gcol := Color(0.15, 0.45, 0.2) if grade >= 7.0 else (Color(0.75, 0.5, 0.1) if grade >= 4.0 else Color(0.8, 0.15, 0.15))
		draw_string(f, Vector2(470, 40), "Nota: %.1f" % grade, HORIZONTAL_ALIGNMENT_RIGHT, 124, 20, gcol)
		# la lección en curso, o cuánto falta para la próxima
		if boss.get("lesson"):
			var seq: Array = boss.get("_seq")
			var shown: int = boss.get("_seq_shown")
			var done: int = boss.get("_seq_i")
			draw_string(f, Vector2(48, 40), "LECCIÓN:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.2, 0.25, 0.45))
			for i in mini(shown, seq.size()):
				var s: int = seq[i]
				var col: Color = Fx.SYM_COL[s]
				var c := Vector2(130 + i * 26, 35)
				Fx.Sym.draw(self, s, c, 9.0, Color(col, 0.35) if i < done else col)
				if i == done:
					draw_line(c + Vector2(-9, 13), c + Vector2(9, 13), Color(0.2, 0.25, 0.45), 2.0)
			var left: float = boss.get("_lesson_left")
			var total: float = boss.get("_lesson_total")
			if shown >= seq.size():
				draw_rect(Rect2(270, 30, 180 * clampf(left / total, 0.0, 1.0), 8), Color(0.85, 0.35, 0.3))
				draw_rect(Rect2(270, 30, 180, 8), Color(0.2, 0.25, 0.45), false, 1.0)
		else:
			var p: int = boss.get("passes")
			var q: int = boss.get("fails")
			draw_string(f, Vector2(48, 40), "Aprobadas: %d   Reprobadas: %d" % [p, q], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.25, 0.45))
		# barra de vida
		draw_rect(Rect2(0, 62, 600, 10), Color(0.25, 0.25, 0.28, 0.9))
		draw_rect(Rect2(0, 62, 600 * _chip, 10), Color(1, 0.95, 0.85))
		draw_rect(Rect2(0, 62, 600 * k, 10), Color(0.8, 0.2, 0.2))
		for fr in [0.6, 0.3]:
			draw_rect(Rect2(600 * fr - 1, 62, 2, 10), Color(0, 0, 0, 0.8))
		draw_rect(r, Color(0.2, 0.25, 0.45, 0.8), false, 1.5)


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
		# como un papelito pegado
		draw_rect(box, Color(0.12, 0.25, 0.18, 0.9 * a))
		draw_rect(box, Color(col.r, col.g, col.b, a), false, 2.0)
		draw_string(f, Vector2(-w * 0.5, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, a))


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


## PREGUNTA FINAL: el personaje corre hasta la pizarra; cada respuesta es un golpe a la pizarra
## (botones en orden) y el último golpe entrega el examen.
func _climax() -> bool:
	_climax_clear()
	var p := get_parent()
	var keys := ["action_primary", "action_secondary", "parry", "roll"]
	var seq: Array = []
	for i in 5:
		seq.append(keys[randi() % keys.size()])
	var chalk := Color(0.95, 0.95, 0.85)
	var steps := [
		{"mode": "sequence", "action": "action_primary", "title": "¡RESPONDE LA PREGUNTA FINAL!", "sub": "Pulsa los botones en orden",
			"seq": seq, "limit": 4.5, "col": Color(0.5, 1.0, 0.55),
			"go": func() -> Vector2: return _front(100.0),
			"look": func() -> Vector2: return _gpos(board),
			"act": "attack",
			"before": func() -> void:
				Epic.charge(p, _gpos(board), chalk, 0.5, 150.0, board)
				await get_tree().create_timer(0.3).timeout,
			"pressed": func() -> void:
				Epic.burst(p, _gpos(board), chalk, 10, 240.0, 0.3, 0.45)
				Epic.word(p, _gpos(board) + Vector2(randf_range(-70, 70), randf_range(-50, 10)), "✓", Color(0.5, 1.0, 0.55), 30, 0.5)
				_shake(1.5, 0.06),
			"ok": func() -> void:
				Epic.word(p, _gpos(board) + Vector2(0, -80), "¡CORRECTO!", Color(0.5, 1.0, 0.55), 44)},
		{"mode": "timing", "action": "action_primary", "title": "¡ENTREGA EL EXAMEN!", "sub": "Antes de que suene el timbre", "dur": 1.0, "col": chalk,
			"look": func() -> Vector2: return _gpos(board),
			"act": "attack",
			"ok": func() -> void:
				Epic.anim(p, "syntax", "fxink", _gpos(board), 1.4)
				Epic.ring(p, _gpos(board), Color(0.5, 1.0, 0.55), 320.0, 0.5, 12.0)
				Epic.word(p, _gpos(board) + Vector2(0, -80), "10/10", Color(0.5, 1.0, 0.55), 56)
				await get_tree().create_timer(0.3).timeout},
	]
	return await Epic.climax(self, steps)
