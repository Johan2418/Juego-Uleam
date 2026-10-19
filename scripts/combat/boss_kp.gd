extends CharacterBody2D
## Boss 8 KERNEL PANIC (Unidad de Formación Técnicas y Tecnológicas): robot chef presentador de un programa
## de cocina en vivo, con un microondas por cabeza, sartén, micrófono y un carrito de cocina.
## Lo único: AL AIRE. Hay tres cámaras de TV en la arena y una transmite (luz roja). Mientras sale en cámara
## aguanta como un profesional (la mitad de daño). Si le rompes la cámara en vivo se queda SIN SEÑAL:
## ¡KERNEL PANIC!, le revientan palomitas de la cabeza y queda aturdido 4 s con daño x2. Luego corte comercial
## y la señal pasa a otra cámara. En la furia se graba con una cámara de mano.
## Versión de prueba con figuras de código; cuando lleguen las hojas de grokbot (bosses/kp/) se cambian por sprites.
## Sin class_name: cargar con preload.

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Fx := preload("res://scripts/combat/boss_kp_fx.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")
const Final := preload("res://scripts/combat/boss_final.gd")
const Roar := preload("res://scripts/combat/boss_roar.gd")
const Barrage := preload("res://scripts/combat/boss_barrage.gd")

signal hp_changed(hp: int, max_hp: int)
signal phase_changed(phase: int, title: String)
signal stunned
signal staggered
signal intro_finished
signal defeated

const MAX_HP := 95
const PHASE_AT := [0.6, 0.3]
const MOVE_SPEED := 80.0
const PAUSE := [1.1, 0.9, 0.7]
const POISE := [9, 12, 15]
const ENRAGE_AT := 0.12
const PHASE_NAMES := ["PRIMER BLOQUE", "SEGUNDO BLOQUE", "GRAN FINAL"]
const COMBOS := {
	2: [["carpet", "popcorn"], ["flambe", "julienne"], ["feedback", "charge"]],
	3: [["carpet", "popcorn"], ["flambe", "julienne"], ["feedback", "charge"], ["julienne", "popcorn"]],
}

# AL AIRE
const CAM_HP := [3, 3, 4]
const SWITCH_EVERY := [0.0, 15.0, 10.0]   # el director cambia de cámara solo (0 = solo tras un pánico)
const PANIC_TIME := 4.0
const DEFEND_DIST := 130.0
## Cámaras por fase: F1 una en vivo (cambia solo tras un pánico). F2 el director cambia solo.
## F3 DOS en vivo a la vez (hay que romper las dos) y la tercera es de UTILERÍA: tiene la luz roja
## pero no transmite (la barra de arriba dice cuáles están en vivo). Romperla = castigo.
## Duelo final ÚLTIMA TRANSMISIÓN: se enciende una cámara cada vez; rómpela antes de que se acabe su tiempo.
const FINAL_CAMS := 8
const FINAL_TIME := [3.0, 1.7]

# pies en y 0
const SHOULDER_L := Vector2(-62, -170)
const SHOULDER_R := Vector2(62, -170)
const CORE := Vector2(0, -132)
const HEAD := Vector2(0, -192)
const CENTER := Vector2(0, -120)
# con sprites (medido en boss_kp_body_0: hueco del pecho y enchufes de los hombros)
const SPR_SHOULDER_L := Vector2(-66, -170)
const SPR_SHOULDER_R := Vector2(69, -170)
const SPR_CORE := Vector2(-5, -170)
const SPR_HEAD := Vector2(-5, -210)
# boss_kp_head_*: cuello en x 37, se mete 16 px en el cuerpo; pantalla y borde del gorro
const HEAD_NECK := Vector2(37, 16)
const HEAD_SCREEN := Rect2(6, 47, 39, 27)
const HEAD_HAT_Y := 42
const REST_L := 0.3
const REST_R := -0.3

var hp: int = MAX_HP
var phase: int = 1
var state: String = "intro"
var arena_rect: Rect2 = Rect2(-500, -310, 1000, 620)
var player: CharacterBody2D
## Núcleo expuesto (daño x2). Mismo nombre que en los otros bosses.
var tank_open: bool = false
var enraged: bool = false

var cams: Array = []          # Fx.Camera
var live: Node2D = null       # la cámara que transmite
var live2: Node2D = null      # fase 3: la segunda en vivo
var final_victory: bool = false
var _final_hits: int = 0
var _final_fail: bool = false
var _final_target: Node2D = null
var _final_left: float = 0.0
var _final_total: float = 1.0
var _final_cams: Array = []
var panics: int = 0
var panic_left: float = 0.0
var on_air: bool = false
var _switch_t: float = 0.0
var _half: int = 0            # resto del daño a la mitad

var _tok: int = 0
var _cd: float = 1.0
var _last: String = ""
var _queue: Array[String] = []
var _near_t: float = 0.0
var _poise: int = 0
var _t: float = 0.0
var _pose_tw: Tween
var rig_off: Vector2 = Vector2.ZERO
var panel: Broadcast
var _holo: Holo

var rig: Node2D
var cart: Part
var body: Part
var core: Part
var head: Part
var pan: Part
var mic: Part


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
	hr.size = Vector2(160, 250)
	hs.shape = hr
	hs.position = Vector2(0, -110)
	hurt.add_child(hs)
	add_child(hurt)
	GameFeel.add_shadow(self, Vector2(0, -2), Vector2(85, 16))
	_build_rig()


func set_player(p: CharacterBody2D) -> void:
	player = p


## La arena llama esto: la franja de transmisión reemplaza la barra de vida.
func build_hud(layer: CanvasLayer) -> void:
	panel = Broadcast.new()
	panel.boss = self
	panel.position = Vector2(340, 8)
	layer.add_child(panel)


# --- Piezas ----------------------------------------------------------------------

func _build_rig() -> void:
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)
	var spr := has_sprites()
	cart = _part("cart", Vector2.ZERO)
	body = _part("body", Vector2.ZERO)
	core = _part("core", SPR_CORE if spr else CORE)
	pan = _part("pan", SPR_SHOULDER_L if spr else SHOULDER_L)
	mic = _part("mic", SPR_SHOULDER_R if spr else SHOULDER_R)
	head = _part("head", SPR_HEAD if spr else HEAD)
	pan.rotation = REST_L
	mic.rotation = REST_R
	_holo = Holo.new()
	_holo.position = Vector2(0, -330)
	add_child(_holo)


func _part(kind: String, pos: Vector2) -> Part:
	var p := Part.new()
	p.kind = kind
	p.name = kind
	p.position = pos
	p.boss = self
	p.use_parent_material = true
	rig.add_child(p)
	return p


static func has_sprites() -> bool:
	return Spr.tex("boss_kp_body_0") != null


func _parts() -> Array:
	return [cart, body, core, pan, mic, head]


func _say(text: String, col: Color = Color(1, 0.85, 0.4), time: float = 1.1) -> void:
	if _holo:
		_holo.show_text(text, col, time)


# --- Cámaras ---------------------------------------------------------------------

func _place_cams() -> void:
	var c := arena_rect.get_center()
	var spots := [
		Vector2(arena_rect.position.x + 90.0, c.y + 30.0),
		Vector2(arena_rect.end.x - 90.0, c.y + 30.0),
		Vector2(c.x, arena_rect.end.y - 50.0),
	]
	for i in 3:
		var cam := Fx.Camera.new()
		cam.idx = i
		cam.hp = CAM_HP[0]
		cam.max_hp = CAM_HP[0]
		cam.look = (c - spots[i]).normalized()
		_add_fx(cam, spots[i])
		cams.append(cam)
	_go_live(cams[randi() % 3])


func _go_live(cam: Node2D) -> void:
	live2 = null
	for c in cams:
		if is_instance_valid(c):
			c.set("live", c == cam)
			c.set("decoy", false)
	live = cam
	_switch_t = SWITCH_EVERY[phase - 1]
	# fase 3: otra cámara también en vivo y la que queda es de utilería (luz roja falsa)
	if phase >= 3 and not enraged and cam and not bool(cam.get("handheld")) and state != "final":
		var rest: Array = cams.filter(func(c): return is_instance_valid(c) and c != cam and not bool(c.get("broken")) and not bool(c.get("handheld")))
		rest.shuffle()
		if rest.size() >= 1:
			live2 = rest[0]
			live2.set("live", true)
		if rest.size() >= 2:
			rest[1].set("decoy", true)
		_say("EN VIVO: %s" % _live_names(), Color(1, 0.3, 0.3), 1.4)
		return
	if cam:
		_say("CAM %d EN VIVO" % (int(cam.get("idx")) + 1), Color(1, 0.3, 0.3), 1.0)


func _live_names() -> String:
	var n: Array[String] = []
	for c in [live, live2]:
		if c and is_instance_valid(c) and not bool(c.get("broken")):
			n.append("CAM %d" % (int(c.get("idx")) + 1))
	return " + ".join(n)


func live_cam() -> Node2D:
	if live and is_instance_valid(live) and not bool(live.get("broken")):
		return live
	if live2 and is_instance_valid(live2) and not bool(live2.get("broken")):
		return live2
	return null


func _next_cam() -> void:
	var ok: Array = []
	for c in cams:
		if is_instance_valid(c) and not bool(c.get("broken")) and c != live:
			ok.append(c)
	if ok.is_empty():
		for c in cams:
			if is_instance_valid(c) and not bool(c.get("broken")):
				ok.append(c)
	if ok.is_empty():
		_repair_cams()
		ok = cams.filter(func(c): return is_instance_valid(c) and c != live)
		if ok.is_empty():
			ok = cams
	_go_live(ok[randi() % ok.size()])


func _repair_cams() -> void:
	for c in cams:
		if is_instance_valid(c) and not bool(c.get("handheld")):
			c.call("repair", CAM_HP[phase - 1])


## Una cámara recibió un golpe del jugador.
func camera_hit(cam: Node2D) -> void:
	if state == "final":
		_final_cam_hit(cam)
		return
	if state in ["intro", "transition", "dead", "paused"]:
		return
	if bool(cam.get("broken")):
		return
	cam.set("hp", int(cam.get("hp")) - 1)
	if int(cam.get("hp")) > 0:
		if (cam == live or cam == live2) and state == "idle":
			_cd = minf(_cd, 0.25)   # le duele: va a defenderla
		return
	var was_decoy := bool(cam.get("decoy"))
	cam.call("smash")
	if was_decoy:
		_decoy_broken(cam)
		return
	if cam == live or cam == live2:
		if live_cam() != null:
			# fase 3: queda la otra en vivo
			var card := Fx.Card.new()
			card.text = "SEÑAL DE RESPALDO"
			card.col = Color(1, 0.6, 0.3)
			card.life = 1.0
			get_parent().add_child(card)
			card.global_position = global_position
			_say("¡SIGUE EL SHOW!", Color(1, 0.6, 0.3), 1.0)
			return
		_panic()


## Fase 3: rompiste la cámara de utilería. Se ríe y te lanza una ráfaga.
func _decoy_broken(cam: Node2D) -> void:
	var card := Fx.Card.new()
	card.text = "¡ERA DE UTILERÍA!"
	card.col = Color(1, 0.85, 0.3)
	card.life = 1.0
	get_parent().add_child(card)
	card.global_position = global_position
	_say("¡JA, JA! ¡SONRÍAN!", Color(1, 0.8, 0.4), 1.0)
	if _player_ok():
		var from := global_position + CENTER
		var aim := _dir_to_player(from)
		for k in 7:
			var sh := Barrage.Shot.new()
			sh.col = Color(1, 0.7, 0.3)
			sh.vel = aim.rotated((k - 3) * 0.16) * 300.0
			_add_fx(sh, from)
	cam.call("repair", CAM_HP[phase - 1])


## ¡KERNEL PANIC!: sin señal. Aturdido con daño x2, palomitas por todos lados.
func _panic() -> void:
	panics += 1
	_interrupt()
	var tok := _tok
	state = "stunned"
	tank_open = true
	core.open = true
	head.screen = 2
	panic_left = PANIC_TIME
	live = null
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.set("stunned_t", 2.0)
	var card := Fx.Card.new()
	card.text = "SIN SEÑAL"
	card.col = Color(0.4, 0.9, 1.0)
	get_parent().add_child(card)
	card.global_position = global_position
	_tw(pan, "rotation", 0.9, 0.2)
	_tw(mic, "rotation", -0.9, 0.2)
	_pose(Vector2(0, 6), 0.0, 0.2)
	_shake(6.0, 0.4)
	GameFeel.flash(rig, 0.3, Color(0.6, 0.9, 1.0))
	GameFeel.parry_burst(get_parent(), global_position + HEAD, 60.0)
	stunned.emit()
	_say("¡KERNEL PANIC!", Color(1, 0.9, 0.3), 1.6)
	var steps := int(PANIC_TIME / 0.25)
	for i in steps:
		if i % 2 == 0:
			_pop_burst(3)
		_pose(Vector2(randf_range(-3, 3), 6), randf_range(-0.04, 0.04), 0.1)
		if not await _hold(0.25, tok):
			_panic_end()
			return
	_panic_end()
	# corte comercial y vuelve con otra cámara
	state = "transition"
	head.screen = 3
	_rest_pose()
	_rest_arms()
	var cd := Fx.Card.new()
	cd.text = "VOLVEMOS EN 3, 2, 1"
	cd.col = Color(1, 0.85, 0.3)
	cd.life = 1.2
	get_parent().add_child(cd)
	cd.global_position = global_position
	if not await _hold(1.3, tok):
		return
	if enraged:
		_handheld()
	else:
		_next_cam()
	head.screen = 0
	state = "idle"
	_cd = 0.6


func _panic_end() -> void:
	tank_open = false
	core.open = false
	panic_left = 0.0


func _pop_burst(n: int) -> void:
	for i in n:
		var p := Fx.Popped.new()
		p.vel = Vector2(randf_range(-260, 260), randf_range(-420, -200))
		get_parent().add_child(p)
		p.global_position = global_position + HEAD + Vector2(randf_range(-20, 20), -10)


## En la furia ya no hay cámaras: se graba él mismo con una de mano.
func _handheld() -> void:
	for c in cams:
		if is_instance_valid(c) and bool(c.get("handheld")):
			c.call("repair", 4)
			_go_live(c)
			return
	var cam := Fx.Camera.new()
	cam.handheld = true
	cam.idx = 3
	cam.hp = 4
	cam.max_hp = 4
	cam.follow = self
	_add_fx(cam, global_position + Vector2(110, -40))
	cams.append(cam)
	_go_live(cam)


# --- Bucle ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	on_air = live_cam() != null and state in ["idle", "attack"]
	if state != "dead":
		rig.position = rig_off
		head.anim_off = head.anim_off.lerp(Vector2(0, sin(_t * 2.0) * 1.5), minf(1.0, delta * 8.0))
		pan.anim_rot = sin(_t * 1.6) * 0.05 if state == "idle" else 0.0
		mic.anim_rot = sin(_t * 1.6 + 1.2) * 0.05 if state == "idle" else 0.0
		if enraged:
			var k := 0.8 + 0.2 * absf(sin(_t * 9.0))
			rig.modulate = Color(1.0, k, k)
		else:
			rig.modulate = Color.WHITE
		if panic_left > 0.0:
			panic_left -= delta
		# sonríe a la cámara cuando está al aire
		if state == "idle":
			head.screen = 0 if on_air else 1
	if _player_ok():
		z_index = 3 if _player_feet().y < global_position.y else 1
	match state:
		"idle":
			_ai_move(delta)
			if _player_ok() and _player_feet().distance_to(global_position) < 160.0:
				_near_t += delta
			else:
				_near_t = maxf(0.0, _near_t - delta)
			# el director cambia de cámara
			if SWITCH_EVERY[phase - 1] > 0.0 and not enraged:
				_switch_t -= delta
				if _switch_t <= 0.0:
					_next_cam()
			# si te acercas a la cámara en vivo, la defiende antes
			var lc := live_cam()
			if lc and _player_ok() and _player_feet().distance_to(lc.global_position) < DEFEND_DIST:
				_cd -= delta * 2.0
			_cd -= delta
			if _cd <= 0.0:
				_choose_attack()
		_:
			velocity = Vector2.ZERO


## Se acomoda de frente a la cámara en vivo, sin perder de vista al jugador.
func _ai_move(_delta: float) -> void:
	if not _player_ok():
		return
	var lc := live_cam()
	var want := _player_feet() + Vector2(0, -200)
	if lc and not bool(lc.get("handheld")):
		var front: Vector2 = lc.global_position + (lc.get("look") as Vector2) * 300.0
		want = front.lerp(_player_feet(), 0.3)
	var to := want - global_position
	if to.length() > 24.0:
		velocity = to.normalized() * MOVE_SPEED * (1.0 + 0.15 * (phase - 1)) * (1.3 if enraged else 1.0)
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_clamp_inside()


func _clamp_inside() -> void:
	global_position.x = clampf(global_position.x, arena_rect.position.x + 110.0, arena_rect.end.x - 110.0)
	global_position.y = clampf(global_position.y, arena_rect.position.y + 300.0, arena_rect.end.y - 40.0)


func _choose_attack() -> void:
	var pick := ""
	var lc := live_cam()
	if lc and not bool(lc.get("handheld")) and _player_ok() and _player_feet().distance_to(lc.global_position) < DEFEND_DIST:
		pick = "charge" if randf() < 0.5 else "flambe"
		_say("¡NO TOQUES MI CÁMARA!", Color(1, 0.4, 0.3), 1.0)
	elif not _queue.is_empty():
		pick = _queue.pop_front()
	elif _near_t > 1.3:
		pick = "feedback"
	elif phase >= 2 and randf() < (0.3 if phase == 2 else 0.45):
		var list: Array = COMBOS[phase]
		_queue.assign(list[randi() % list.size()])
		pick = _queue.pop_front()
	else:
		var pool: Array[String] = ["flambe", "carpet", "popcorn", "julienne", "charge"]
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
	_rest_pose()
	_rest_arms()
	_cd = PAUSE[phase - 1] * (0.6 if enraged else 1.0)
	if not _queue.is_empty():
		_cd = 0.2


# --- Utilidades -----------------------------------------------------------------

func _player_ok() -> bool:
	return player != null and is_instance_valid(player)


func _player_body() -> Vector2:
	return player.global_position + Vector2(0, -32)


func _player_feet() -> Vector2:
	return player.global_position + Vector2(0, 12)


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
	return tw


func _wait(time: float, tok: int) -> bool:
	await get_tree().create_timer(time, false).timeout
	return tok == _tok and is_inside_tree()


func _hold(time: float, tok: int) -> bool:
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
	_tw(pan, "rotation", REST_L, 0.3)
	_tw(mic, "rotation", REST_R, 0.3)
	pan.tool = 0
	mic.tool = 3 if enraged else 0


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
	_queue.clear()
	velocity = Vector2.ZERO
	_rest_pose(0.2)
	visible = true
	modulate.a = 1.0


func hurt_player(amount: int, from: Vector2, unblockable: bool = false) -> void:
	if not _player_ok() or state == "dead" or state == "paused":
		return
	player.call("take_hit", amount, from, unblockable)


# --- Recibir daño ----------------------------------------------------------------

func take_hit(amount: int, from: Vector2) -> void:
	if state in ["intro", "transition", "dead", "paused", "final"]:
		GameFeel.flash(rig, 0.08, Color(0.6, 0.6, 0.7))
		return
	var dmg := amount * (2 if tank_open else 1)
	var pro := on_air and not tank_open
	if pro:
		# modo presentador: aguanta la mitad
		_half += dmg
		dmg = _half / 2
		_half = _half % 2
	var center := global_position + CENTER
	var toward := from - center
	toward = Vector2.DOWN if toward.length() < 0.01 else toward.normalized()
	# a un golpe de caer en la fase 3: ÚLTIMA TRANSMISIÓN en vez de morir
	if phase >= 3 and not final_victory and dmg > 0 and hp - dmg <= 0:
		hp = 1
		hp_changed.emit(hp, MAX_HP)
		_start_final()
		return
	hp = maxi(0, hp - dmg)
	hp_changed.emit(hp, MAX_HP)
	GameFeel.flash(rig, 0.1 + 0.02 * dmg, Color(1.0, 0.95, 0.9))
	GameFeel.squash(rig, Vector2(1.03, 0.97), 0.14, 0.0)
	GameFeel.hit_stop(get_tree(), 0.03 + 0.02 * mini(dmg, 3))
	head.anim_off += -toward * (4.0 + 2.0 * maxi(dmg, 1))
	var num := BossFx.DmgNumber.new()
	num.text = (str(dmg) + ("!" if tank_open else "")) if dmg > 0 else "½"
	num.big = tank_open
	num.color = Color(0.6, 1, 0.6) if tank_open else (Color(1, 0.6, 0.6) if pro else Color(1, 1, 1))
	get_parent().add_child(num)
	num.global_position = center + toward * 40.0 + Vector2(0, -40)
	if tank_open:
		GameFeel.parry_burst(get_parent(), global_position + CORE, 34.0)
	else:
		var sp := BossFx.Sparks.new()
		sp.dir = toward
		get_parent().add_child(sp)
		sp.global_position = center + toward * 50.0
	if pro and randf() < 0.3:
		_say("¡SONRÍAN!", Color(1, 0.8, 0.5), 0.6)
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
		_poise += maxi(dmg, 1)
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
		state = "idle"
		tank_open = false
		_half = 1   # que el golpe de prueba cuente aunque esté al aire
		take_hit(1, global_position)
		return
	hp = int(MAX_HP * PHASE_AT[phase - 1])
	hp_changed.emit(hp, MAX_HP)
	_enter_phase(phase + 1)


func _stagger() -> void:
	_interrupt()
	var tok := _tok
	state = "stunned"
	head.screen = 3
	_say("¿¡ERROR!?", Color(1, 0.6, 0.3))
	_pose(Vector2(0, 8), 0.06 * (1.0 if randf() < 0.5 else -1.0), 0.12)
	GameFeel.flash(rig, 0.2, Color(1, 0.9, 0.6))
	_shake(3.0, 0.2)
	staggered.emit()
	if not await _hold(0.9, tok):
		return
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.5


func _enter_phase(n: int) -> void:
	phase = n
	_interrupt()
	_panic_end()
	var tok := _tok
	state = "transition"
	if n == 2:
		body.cracked = true
	else:
		head.cracked = true
		cart.cracked = true
	head.screen = 1
	_say(PHASE_NAMES[n - 1], Color(1, 0.5, 0.3), 1.4)
	GameFeel.flash(rig, 0.3, Color(1.0, 0.5, 0.3))
	_pose(Vector2(0, -12), 0.0, 0.25)
	_shake(7.0, 0.8)
	phase_changed.emit(n, PHASE_NAMES[n - 1])
	# el tramoyista arregla las cámaras
	var fix := Fx.Card.new()
	fix.text = "TRAMOYISTA: CÁMARAS LISTAS"
	fix.col = Color(0.6, 1.0, 0.6)
	fix.life = 1.2
	get_parent().add_child(fix)
	fix.global_position = global_position + Vector2(0, 60)
	_repair_cams()
	if not await _hold(1.6, tok):
		return
	# lluvia de ataques: inmune hasta que termine (esquivar o parry)
	if not await Barrage.run(self, n, tok):
		return
	_next_cam()
	_rest_pose()
	state = "idle"
	_cd = 0.4


func _enrage() -> void:
	enraged = true
	_interrupt()
	_panic_end()
	var tok := _tok
	state = "transition"
	head.hat = false
	head.screen = 1
	_say("FUERA DE AIRE", Color(1, 0.25, 0.2), 1.4)
	_pose(Vector2(0, -14), 0.0, 0.3)
	GameFeel.flash(rig, 0.4, Color(1.0, 0.3, 0.2))
	_shake(9.0, 1.0)
	phase_changed.emit(3, "FUERA DE AIRE")
	var hat := HatFall.new()
	get_parent().add_child(hat)
	hat.global_position = global_position + HEAD + Vector2(0, -70)
	# se apagan todas las cámaras del estudio
	for c in cams:
		if is_instance_valid(c) and not bool(c.get("handheld")):
			c.call("smash")
	if not await _hold(1.3, tok):
		return
	mic.tool = 3
	_handheld()
	_rest_pose()
	state = "idle"
	_cd = 0.3


# --- ÚLTIMA TRANSMISIÓN (duelo final) -------------------------------------------------
## A un golpe de caer: el estudio entero lo graba. Cada vez se enciende UNA cámara (cuenta atrás encima):
## rómpela de un golpe antes de que se acabe su tiempo, mientras esquivas el flambé que te lanza.
## FINAL_CAMS seguidas = FIN DE LA EMISIÓN. Si una cámara llega a 0: ¡CORTEN!, vuelve la fase 3.
func _start_final() -> void:
	_interrupt()
	_panic_end()
	var tok := _tok
	state = "final"
	_final_hits = 0
	_final_fail = false
	_final_target = null
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.call("die")
	# todas las cámaras del estudio (y dos más) listas, ninguna en vivo
	var c := arena_rect.get_center()
	for at in [Vector2(arena_rect.position.x + 200.0, arena_rect.end.y - 120.0), Vector2(arena_rect.end.x - 200.0, arena_rect.end.y - 120.0)]:
		var cam := Fx.Camera.new()
		cam.idx = cams.size()
		cam.hp = 1
		cam.max_hp = 1
		cam.look = (c - at).normalized()
		_add_fx(cam, at)
		cams.append(cam)
		_final_cams.append(cam)
	for cam in cams:
		if is_instance_valid(cam):
			cam.call("repair", 1)
			cam.set("live", false)
			cam.set("decoy", false)
	live = null
	live2 = null
	head.screen = 0
	Final.title(self, "ÚLTIMA TRANSMISIÓN", Color(1.0, 0.55, 0.25), "Rompe la cámara que se encienda")
	Final.music_cue(self, "final1")
	var spot := Vector2(0.0, arena_rect.position.y + 330.0)
	_tw(self, "global_position", spot, 0.6)
	for k in ["3", "2", "1"]:
		_say("AL AIRE EN %s" % k, Color(1, 0.4, 0.3), 0.5)
		_tw(mic, "rotation", -PI * 0.7, 0.15)
		if not await _hold(0.25, tok):
			return
		_tw(mic, "rotation", REST_R, 0.15)
		if not await _hold(0.3, tok):
			return
	_say("¡AL AIRE!", Color(1, 0.3, 0.3), 0.8)
	var prev: Node2D = null
	var fire_t := 0.0
	while _final_hits < FINAL_CAMS and not _final_fail:
		var opts: Array = cams.filter(func(k): return is_instance_valid(k) and not bool(k.get("broken")) and k != prev and not bool(k.get("handheld")))
		if opts.is_empty():
			if not await _hold(0.1, tok):
				return
			continue
		_final_target = opts[randi() % opts.size()]
		prev = _final_target
		_final_target.set("live", true)
		_final_total = lerpf(FINAL_TIME[0], FINAL_TIME[1], float(_final_hits) / maxf(1.0, FINAL_CAMS - 1))
		_final_left = _final_total
		var timer := CamTimer.new()
		timer.boss = self
		_final_target.add_child(timer)
		timer.position = Vector2(0, -112)
		var tgt := _final_target
		while is_instance_valid(tgt) and tgt == _final_target and not bool(tgt.get("broken")) and not _final_fail:
			if not await _hold(0.05, tok):
				return
			_final_left -= 0.05
			fire_t -= 0.05
			if fire_t <= 0.0:
				fire_t = maxf(0.7, 1.4 - 0.08 * _final_hits)
				_final_flambe(tok)
			if _final_left <= 0.0:
				_final_fail = true
		if is_instance_valid(timer):
			timer.queue_free()
	_final_target = null
	if _final_fail:
		_final_lost(tok)
	else:
		_final_won()


## Golpe a una cámara en el duelo: solo cuenta la que está encendida (una sola vez).
func _final_cam_hit(cam: Node2D) -> void:
	if cam != _final_target or bool(cam.get("broken")):
		return
	cam.call("smash")
	_final_hits += 1
	_final_target = null
	_say("¡CORTE %d/%d!" % [_final_hits, FINAL_CAMS], Color(0.6, 1, 0.6), 0.6)
	GameFeel.hit_stop(get_tree(), 0.05)
	head.screen = 2
	head.anim_off += Vector2(0, -6)
	_shake(3.0, 0.15)
	if _final_hits == 3:
		Final.music_cue(self, "final2")
	elif _final_hits == 6:
		Final.music_cue(self, "final3")
	# el tramoyista la arregla al rato
	var wc: WeakRef = weakref(cam)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(func() -> void:
		var cc: Variant = wc.get_ref()
		if cc != null and state == "final":
			cc.call("repair", 1)
			cc.set("live", false)
		head.screen = 0)


## Flambé del duelo: echa la sartén atrás (anticipación) y lanza comida en llamas hacia ti.
func _final_flambe(tok: int) -> void:
	pan.tool = 0
	var tw := create_tween()
	tw.tween_property(pan, "rotation", PI * 0.95, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if tok != _tok or not _player_ok():
			return
		var from := global_position + SHOULDER_L + Vector2(-20, -40)
		var aim := _player_feet()
		var base := (aim - from).normalized()
		pan.rotation = _rot_for(base)
		_pose(base * 10.0, 0.04, 0.06)
		for k in 3:
			var f := Fx.FireFood.new()
			f.from = from
			f.to = _clamp_arena(aim + Vector2(randf_range(-70, 70), randf_range(-40, 40)))
			f.flight = 0.6
			f.burn = 1.6
			_add_fx(f, from)
		GameFeel.parry_burst(get_parent(), from, 20.0))
	tw.tween_property(pan, "rotation", REST_L, 0.25)


func _final_won() -> void:
	final_victory = true
	Final.music_final(self, "epic")
	await _finisher()
	Final.title(self, "¡GRACIAS POR VERNOS!", Color(1.0, 0.85, 0.3), "", 1.4)
	_shake(10.0, 0.6)
	hp = 0
	hp_changed.emit(hp, MAX_HP)
	_die()


func _final_lost(tok: int) -> void:
	for k in _final_cams:
		if is_instance_valid(k):
			k.queue_free()
		cams.erase(k)
	_final_cams.clear()
	Final.title(self, "¡CORTEN!", Color(1.0, 0.35, 0.3), "", 1.1)
	Final.music_cue(self, "p3")
	head.screen = 1
	_rest_pose()
	_rest_arms()
	if not await _hold(1.0, tok):
		return
	_repair_cams()
	if enraged:
		_handheld()
	else:
		_next_cam()
	state = "idle"
	_cd = 1.0
	head.screen = 0


# --- Ataques ---------------------------------------------------------------------------

## 1. Gastronomía: flambé. Voltea la sartén y lanza comida en llamas en abanico; donde cae queda aceite ardiendo.
func _atk_flambe(tok: int) -> void:
	_say("¡FLAMBÉ!", Color(1, 0.55, 0.2))
	pan.tool = 0
	_tw(pan, "rotation", PI * 0.9, 0.35)
	_pose(Vector2(0, -6), -0.05, 0.35)
	if not await _wait(0.45, tok):
		return
	var waves: int = [1, 2, 2][phase - 1]
	var n: int = [3, 4, 5][phase - 1]
	for w in waves:
		var from := global_position + SHOULDER_L + Vector2(-20, -40)
		var aim := _player_feet() if _player_ok() else arena_rect.get_center()
		var base := (aim - from).normalized()
		var dist := clampf(from.distance_to(aim), 180.0, 420.0)
		_tw(pan, "rotation", _rot_for(base), 0.1)
		for i in n:
			var a := (i - (n - 1) * 0.5) * 0.32 + (0.16 if w % 2 == 1 else 0.0)
			var f := Fx.FireFood.new()
			f.from = from
			f.to = _clamp_arena(from + base.rotated(a) * dist)
			f.flight = 0.7
			f.burn = 3.5 if phase < 3 else 4.5
			_add_fx(f, from)
		GameFeel.parry_burst(get_parent(), from, 24.0)
		if not await _wait(0.6, tok):
			return
		_tw(pan, "rotation", PI * 0.9, 0.2)
		if not await _wait(0.25, tok):
			return
	if not await _wait(0.5, tok):
		return
	_end_attack(tok)


## 2. Comunicación para TV, RRPP y Protocolo: alfombra roja con cordones y paparazzi que disparan flashes.
func _atk_carpet(tok: int) -> void:
	_say("ALFOMBRA ROJA", Color(1, 0.3, 0.35))
	mic.tool = 1
	_tw(mic, "rotation", -PI * 0.8, 0.3)
	if not await _wait(0.4, tok):
		return
	_tw(mic, "rotation", -PI * 0.3, 0.08)   # ¡claqueta!
	_impact(global_position + Vector2(60, 0), 3.0)
	var c := Fx.Carpet.new()
	var y := _player_feet().y if _player_ok() else arena_rect.get_center().y
	c.area = arena_rect
	c.life = 7.0
	_add_fx(c, Vector2(arena_rect.get_center().x, clampf(y, arena_rect.position.y + 80.0, arena_rect.end.y - 60.0)))
	if not await _wait(0.6, tok):
		return
	var n: int = [2, 3, 3][phase - 1]
	var have := get_tree().get_nodes_in_group("boss_minion").size()
	for i in mini(n, 4 - have):
		var p := Fx.Paparazzi.new()
		var left := i % 2 == 0
		p.dir = 1.0 if left else -1.0
		p.lane_y = c.global_position.y
		p.min_x = arena_rect.position.x + 40.0
		p.max_x = arena_rect.end.x - 40.0
		var x := arena_rect.position.x + 60.0 if left else arena_rect.end.x - 60.0
		_add_fx(p, Vector2(x, c.global_position.y + (i - 1) * 18.0))
		if not await _wait(0.35, tok):
			return
	if not await _wait(0.8, tok):
		return
	_end_attack(tok)


## Palomitas: siembra granos de maíz que se inflan y revientan uno tras otro.
func _atk_popcorn(tok: int) -> void:
	_say("PALOMITAS", Color(1, 0.95, 0.6))
	pan.tool = 2
	_tw(pan, "rotation", PI * 0.7, 0.3)
	head.screen = 1
	if not await _wait(0.35, tok):
		return
	var n: int = [7, 9, 12][phase - 1]
	var c := _player_feet() if _player_ok() else arena_rect.get_center()
	for i in n:
		var k := Fx.Kernel.new()
		k.delay = 0.09 * i
		k.warn = 0.95 if phase == 1 else 0.8
		var a := randf() * TAU
		var r := 30.0 + sqrt(randf()) * 190.0
		_add_fx(k, _clamp_arena(c + Vector2(cos(a) * r, sin(a) * r * 0.6)))
	_pop_burst(4)
	_tw(pan, "rotation", PI * 0.2, 0.15)
	if not await _wait(0.95 + 0.09 * n + 0.5, tok):
		return
	_end_attack(tok)


## Juliana: lluvia de cuchillos en filas, como si picara la arena (con un hueco por fila).
func _atk_julienne(tok: int) -> void:
	_say("JULIANA", Color(0.85, 0.9, 1.0))
	pan.tool = 1
	var rows: int = [2, 3, 3][phase - 1]
	var y0 := _player_feet().y if _player_ok() else arena_rect.get_center().y
	for r in rows:
		_tw(pan, "rotation", PI * 0.85, 0.15)
		if not await _wait(0.2, tok):
			return
		_tw(pan, "rotation", PI * 0.15, 0.08)
		var y := clampf(y0 + (r - (rows - 1) * 0.5) * 110.0, arena_rect.position.y + 60.0, arena_rect.end.y - 30.0)
		var gap := randi_range(2, 11)
		var x := arena_rect.position.x + 40.0
		var i := 0
		while x < arena_rect.end.x - 30.0:
			if i != gap and i != gap + 1:
				var kn := Fx.Knife.new()
				kn.delay = 0.02 * i
				kn.warn = 0.75 if phase == 1 else 0.6
				_add_fx(kn, Vector2(x, y))
			x += 64.0
			i += 1
		if not await _wait(0.35, tok):
			return
	if not await _wait(0.9, tok):
		return
	_end_attack(tok)


## Acople: golpea el micrófono y sale una onda de sonido en anillo.
func _atk_feedback(tok: int) -> void:
	_say("¡ACOPLE!", Color(0.6, 0.9, 1.0))
	mic.tool = 0
	_tw(mic, "rotation", -PI * 0.6, 0.3)
	_warn_zone(global_position, Vector2.DOWN, 200.0, PI, 0.6)
	if not await _wait(0.6, tok):
		return
	var rings: int = [1, 1, 2][phase - 1]
	for i in rings:
		_tw(mic, "rotation", -PI * 0.3, 0.06)
		var ring := Fx.SoundRing.new()
		ring.max_r = 300.0 if phase < 3 else 380.0
		_add_fx(ring, global_position)
		_shake(4.0, 0.2)
		if not await _wait(0.55, tok):
			return
		_tw(mic, "rotation", -PI * 0.6, 0.1)
	if not await _wait(0.4, tok):
		return
	_end_attack(tok)


## ¡A la mesa!: embiste con el carrito en línea recta.
func _atk_charge(tok: int) -> void:
	_say("¡A LA MESA!", Color(1, 0.7, 0.3))
	var dir := _dir_to_player(global_position)
	dir = Vector2(dir.x, dir.y).normalized()
	var reach := 520.0
	var line := Fx.DashLine.new()
	line.dir = dir
	line.length = reach
	line.life = 0.75
	_add_fx(line, global_position)
	_tw(pan, "rotation", PI * 0.5, 0.3)
	_tw(mic, "rotation", -PI * 0.5, 0.3)
	_pose(-dir * 10.0, 0.0, 0.5)
	if not await _wait(0.75, tok):
		return
	var t := 0.0
	var speed := 620.0 if phase < 3 else 720.0
	var hit := false
	while t < reach / speed:
		await get_tree().physics_frame
		if tok != _tok:
			return
		var d := get_physics_process_delta_time()
		t += d
		global_position += dir * speed * d
		_clamp_inside()
		if int(t * 30.0) % 3 == 0:
			GameFeel.dust(get_parent(), global_position, 1, -dir * 40.0, 3.0, Vector2(30, 6))
		if not hit and _player_ok() and _player_feet().distance_to(global_position) < 80.0:
			hit = true
			hurt_player(2, global_position, false)
	_impact(global_position, 5.0)
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)



# --- Lluvia de cambio de fase propia: TRANSMISIÓN EN VIVO ----------------------------------
## Palomitas que revientan por todo el plató, filas de cuchillos en juliana, anillos de acople del micrófono
## y comida en llamas en arco.
func barrage_title(_n: int) -> String:
	return "¡TRANSMISIÓN EN VIVO!"


func barrage_plan(n: int) -> Array:
	if n == 2:
		return [[0.2, "popcorn", {"n": 14}], [1.6, "knives", {"rows": 2}], [3.2, "feedback", {"n": 2}],
			[4.6, "flambe", {"n": 6}], [6.0, "popcorn", {"n": 12}]]
	return [[0.2, "popcorn", {"n": 16}], [1.2, "knives", {"rows": 3}], [2.8, "feedback", {"n": 3}],
		[4.2, "flambe", {"n": 8}], [5.4, "popcorn", {"n": 16}], [6.6, "knives", {"rows": 2}], [8.0, "feedback", {"n": 2}]]


func _bfx(n: Node2D, at: Vector2) -> void:
	_add_fx(n, at)
	Barrage.tag(n)


func _bar_popcorn(a: Dictionary, _tok: int) -> void:
	pan.tool = 2
	_tw(pan, "rotation", PI * 0.7, 0.2)
	for i in int(a["n"]):
		var k := Fx.Kernel.new()
		k.delay = 0.06 * i
		k.warn = 0.8
		var at := _player_feet() if (_player_ok() and i % 4 == 0) else Vector2(randf_range(arena_rect.position.x + 60, arena_rect.end.x - 60), randf_range(arena_rect.position.y + 100, arena_rect.end.y - 40))
		_bfx(k, _clamp_arena(at))
	_pop_burst(4)


func _bar_knives(a: Dictionary, tok: int) -> void:
	pan.tool = 1
	var rows: int = a["rows"]
	var y0 := _player_feet().y if _player_ok() else arena_rect.get_center().y
	for r in rows:
		_tw(pan, "rotation", PI * 0.85, 0.12)
		var y := clampf(y0 + (r - (rows - 1) * 0.5) * 120.0, arena_rect.position.y + 60.0, arena_rect.end.y - 30.0)
		var gap := randi_range(2, 11)
		var x := arena_rect.position.x + 40.0
		var i := 0
		while x < arena_rect.end.x - 30.0:
			if i != gap and i != gap + 1:
				var kn := Fx.Knife.new()
				kn.delay = 0.02 * i
				kn.warn = 0.65
				_bfx(kn, Vector2(x, y))
			x += 64.0
			i += 1
		_tw(pan, "rotation", PI * 0.15, 0.06)
		if not await _hold(0.35, tok):
			return


func _bar_feedback(a: Dictionary, tok: int) -> void:
	mic.tool = 0
	for i in int(a["n"]):
		_tw(mic, "rotation", -PI * 0.7, 0.1)
		var ring := Fx.SoundRing.new()
		ring.max_r = 420.0
		_bfx(ring, global_position)
		_shake(3.0, 0.15)
		if not await _hold(0.7, tok):
			return


func _bar_flambe(a: Dictionary, _tok: int) -> void:
	pan.tool = 0
	var from := global_position + SHOULDER_L + Vector2(-20, -40)
	var n: int = a["n"]
	for i in n:
		var f := Fx.FireFood.new()
		f.from = from
		f.to = _clamp_arena(from + Vector2.from_angle(TAU * i / n) * Vector2(360, 240))
		f.flight = 0.75
		f.burn = 2.5
		_bfx(f, from)
	GameFeel.parry_burst(get_parent(), from, 24.0)


## REMATE: se va la señal: la imagen del estudio se apaga como un televisor viejo (línea y punto)
## y en su pantalla queda el patrón de barras de color.
func _finisher() -> void:
	head.screen = 3
	for c in cams:
		if is_instance_valid(c):
			c.call("smash")
	var tv := Final.TvOff.new()
	get_parent().add_child(tv)
	await get_tree().create_timer(1.3).timeout
	var card := Fx.Card.new()
	card.text = "FIN DE LA EMISIÓN"
	card.col = Color(1, 0.85, 0.3)
	card.life = 1.6
	get_parent().add_child(card)
	card.global_position = global_position
	await get_tree().create_timer(0.6).timeout


# --- Aparición y muerte -----------------------------------------------------------

func start_intro(skip: bool) -> void:
	state = "intro"
	_place_cams()
	if skip:
		await get_tree().create_timer(0.6).timeout
		intro_finished.emit()
		return
	# 1. estudio a oscuras, se prenden los reflectores
	var home := position
	var dark := Dark.new()
	dark.area = arena_rect
	get_parent().add_child(dark)
	dark.global_position = Vector2.ZERO
	position = home + Vector2(0, -260)
	visible = false
	await get_tree().create_timer(0.5).timeout
	for i in 3:
		dark.light(i)
		_shake(2.0, 0.1)
		await get_tree().create_timer(0.4).timeout
	# 2. cuenta regresiva
	for s in ["3", "2", "1", "¡AL AIRE!"]:
		var cd := Fx.Card.new()
		cd.text = s
		cd.col = Color(1, 0.3, 0.3)
		cd.life = 0.45
		get_parent().add_child(cd)
		cd.global_position = home + Vector2(0, 40)
		await get_tree().create_timer(0.55).timeout
	dark.fade()
	# 3. llega rodando y saluda a la cámara
	visible = true
	mic.tool = 2
	var tw := create_tween()
	tw.tween_property(self, "position", home, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_say("¡BIENVENIDOS!", Color(1, 0.85, 0.4), 1.4)
	for i in 3:
		_tw(mic, "rotation", -PI * 0.75, 0.15)
		await get_tree().create_timer(0.18).timeout
		_tw(mic, "rotation", -PI * 0.55, 0.15)
		await get_tree().create_timer(0.18).timeout
	# 4. firma: reverencia al público con cartel de APLAUSOS; se levanta, grita al micrófono
	#    y el acople sale en ondas rojas.
	_pose(Vector2(0, 18), 0.0, 0.25)
	_tw(pan, "rotation", -0.5, 0.25)
	_tw(mic, "rotation", 0.5, 0.25)
	var sg := Roar.Sign.new()
	sg.life = 1.1
	Roar.spawn(get_parent(), sg, global_position + Vector2(200, -150))
	await get_tree().create_timer(1.0).timeout
	_pose(Vector2(0, -8), 0.0, 0.15)
	_tw(mic, "rotation", -2.3, 0.15)             # micrófono a la boca
	_tw(pan, "rotation", REST_L, 0.15)
	await get_tree().create_timer(0.15).timeout
	var wv := Roar.Waves.new()
	wv.col = Color(1, 0.35, 0.3)
	wv.jagged = true
	wv.count = 5
	wv.gap = 0.1
	wv.flat = 0.8
	Roar.spawn(get_parent(), wv, head.global_position + Vector2(0, -20))
	_say("KERNEL PANIC", Color(1, 0.4, 0.3), 1.2)
	_shake(7.0, 0.6)
	await get_tree().create_timer(0.9).timeout
	_rest_pose()
	_rest_arms()
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
	for c in cams:
		if is_instance_valid(c):
			c.call("smash")
	Engine.time_scale = 0.2
	head.screen = 2
	await get_tree().create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 1.0
	body.cracked = true
	cart.cracked = true
	head.cracked = true
	var card := Fx.Card.new()
	card.text = "FIN DE LA TRANSMISIÓN"
	card.col = Color(0.5, 0.9, 1.0)
	card.life = 2.4
	get_parent().add_child(card)
	card.global_position = global_position
	_say("*DING*", Color(1, 1, 1), 1.0)
	_pose(Vector2(0, 6), 0.0, 0.4)
	for i in 4:
		_pop_burst(6)
		_shake(3.0, 0.15)
		await get_tree().create_timer(0.35).timeout
	core.broken = true
	head.broken = true
	head.hat = false
	var hat := HatFall.new()
	get_parent().add_child(hat)
	hat.global_position = global_position + HEAD + Vector2(0, -70)
	GameFeel.parry_burst(get_parent(), global_position + HEAD, 70.0)
	for i in 18:
		var d := BossFx.Debris.new()
		d.kind = i % 8
		d.prefix = "boss_kp_debris_"
		d.vel = Vector2(randf_range(-300, 300), randf_range(-460, -200))
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(randf_range(-60, 60), randf_range(-200, -60))
	for p in [pan, mic]:
		var tw := create_tween()
		tw.tween_property(p, "rotation", (1.0 if p == pan else -1.0) * 1.6, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(self, "rig_off", Vector2(0, 20), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(rig, "rotation", -0.1, 0.5)
	fall.tween_property(head, "anim_off", Vector2(-40, 150), 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_shake(8.0, 0.4)
	GameFeel.dust(get_parent(), global_position, 16, Vector2.ZERO, 7.0, Vector2(90, 10))
	await get_tree().create_timer(1.6).timeout
	create_tween().tween_property(rig, "modulate", Color(0.6, 0.6, 0.65, 0.0), 1.2)
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
	var open := false         # panel del pecho expuesto
	var broken := false
	var cracked := false
	var hat := true
	var screen := 0           # cara: 0 sonrisa, 1 enojado, 2 SIN SEÑAL, 3 mareado
	var tool := 0             # sartén: 0 sartén, 1 cuchillo, 2 cucharón · micro: 0 micrófono, 1 claqueta, 2 mano, 3 cámara de mano

	const OUT := Color(0.06, 0.06, 0.08)
	const STEEL := Color(0.72, 0.75, 0.8)
	const STEEL_D := Color(0.5, 0.53, 0.58)
	const CHROME := Color(0.88, 0.9, 0.94)
	const RED := Color(0.85, 0.15, 0.15)
	const WHITE := Color(0.96, 0.95, 0.92)
	const WOOD := Color(0.62, 0.42, 0.22)
	const SAUCE := Color(0.75, 0.2, 0.1)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _box(r: Rect2, col: Color, w: float = 2.0) -> void:
		draw_rect(r, col)
		draw_rect(r, OUT, false, w)

	func _poly(pts: PackedVector2Array, col: Color, w: float = 2.0) -> void:
		draw_colored_polygon(pts, col)
		var c := pts.duplicate()
		c.append(pts[0])
		draw_polyline(c, OUT, w)

	func _draw() -> void:
		draw_set_transform(anim_off, anim_rot, Vector2.ONE)
		if _draw_sprite():
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		match kind:
			"cart":
				_cart()
			"body":
				_body()
			"core":
				_core()
			"head":
				_head()
			"pan":
				_pan()
			"mic":
				_mic()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## Con sprites de grokbot: el cuerpo trae el carrito y los hombros; brazos rectos hacia abajo desde el hombro.
	func _draw_sprite() -> bool:
		match kind:
			"cart":
				return Spr.tex("boss_kp_body_0") != null
			"body":
				var base := Spr.tex("boss_kp_body_0")
				if base == null:
					return false
				var hurt: bool = cracked or (boss != null and bool(boss.get("cart").get("cracked")))
				var tx: Texture2D = Spr.tex("boss_kp_body_1") if hurt else base
				if tx == null:
					tx = base
				draw_texture(tx, Vector2(-tx.get_width() * 0.5, -tx.get_height()))
				return true
			"core":
				var idx := 2 if broken else (1 if open else 0)
				var tx := Spr.tex("boss_kp_core_%d" % idx)
				if tx == null:
					return false
				if open and not broken:
					draw_circle(Vector2.ZERO, 32.0 + 3.0 * sin(t * 10.0), Color(1.0, 0.6, 0.2, 0.28))
				draw_texture(tx, -tx.get_size() * 0.5)
				return true
			"head":
				var idx := 2 if broken else (1 if cracked else 0)
				var tx := Spr.tex("boss_kp_head_%d" % idx)
				if tx == null:
					return false
				var at := -Vector2(HEAD_NECK.x, tx.get_height() - HEAD_NECK.y)
				if hat:
					draw_texture(tx, at)
				else:
					# sin gorro: se dibuja solo del microondas para abajo
					var top := float(HEAD_HAT_Y)
					draw_texture_rect_region(tx, Rect2(at + Vector2(0, top), Vector2(tx.get_width(), tx.get_height() - top)), Rect2(0, top, tx.get_width(), tx.get_height() - top))
				var scr := Rect2(at + HEAD_SCREEN.position, HEAD_SCREEN.size)
				if not broken or screen == 2:
					_face(scr)
				return true
			"pan", "mic":
				var tl := mini(tool, 2)
				var name := "boss_kp_%s_%d" % [kind, tl]
				var tx := Spr.tex(name)
				if tx == null:
					return false
				var piv := Spr.top_pivot(name)
				draw_texture(tx, -piv)
				if kind == "mic" and tool == 3:
					# cámara de mano (furia) en la mano abierta
					var cam := Spr.tex("boss_kp_props_1")
					var h := Vector2(0, tx.get_height() - piv.y - 18)
					if cam:
						draw_texture_rect(cam, Rect2(h - Vector2(22, 34), Vector2(44, 60)), false)
					else:
						_box(Rect2(h + Vector2(-22, -15), Vector2(44, 30)), Color(0.15, 0.15, 0.18), 2.0)
					if fmod(t, 0.6) < 0.3:
						draw_circle(h + Vector2(14, -26), 4, RED)
				return true
		return false

	func _cart() -> void:
		# ruedas
		for x in [-64.0, 64.0]:
			draw_circle(Vector2(x, -8), 9, OUT)
			draw_circle(Vector2(x, -8), 5, STEEL_D)
		# carrito con cajones y perillas
		_box(Rect2(-82, -78, 164, 66), STEEL, 3.0)
		_box(Rect2(-88, -86, 176, 12), WOOD, 2.0)   # tabla de picar
		for k in 3:
			_box(Rect2(-72 + k * 50, -66, 44, 22), STEEL_D, 1.5)
			draw_line(Vector2(-58 + k * 50, -55), Vector2(-42 + k * 50, -55), CHROME, 3.0)
		for k in 4:
			draw_circle(Vector2(-54 + k * 36, -30), 6, CHROME)
			draw_arc(Vector2(-54 + k * 36, -30), 6, 0, TAU, 10, OUT, 1.5)
		if cracked:
			draw_polyline(PackedVector2Array([Vector2(-70, -76), Vector2(-56, -50), Vector2(-64, -20)]), OUT, 2.0)
			draw_circle(Vector2(40, -60), 10, Color(0.1, 0.08, 0.06, 0.6))

	func _body() -> void:
		# torso de acero
		var torso := PackedVector2Array([Vector2(-62, -186), Vector2(62, -186), Vector2(56, -120), Vector2(44, -86), Vector2(-44, -86), Vector2(-56, -120)])
		_poly(torso, STEEL, 3.0)
		# delantal manchado
		_poly(PackedVector2Array([Vector2(-36, -150), Vector2(36, -150), Vector2(42, -86), Vector2(-42, -86)]), WHITE, 2.0)
		draw_line(Vector2(-36, -150), Vector2(-56, -180), WHITE, 3.0)
		draw_line(Vector2(36, -150), Vector2(56, -180), WHITE, 3.0)
		draw_circle(Vector2(-18, -104), 6, SAUCE)
		draw_circle(Vector2(20, -120), 4, SAUCE)
		# moño rojo de presentador
		_poly(PackedVector2Array([Vector2(0, -178), Vector2(-16, -186), Vector2(-16, -170)]), RED, 1.5)
		_poly(PackedVector2Array([Vector2(0, -178), Vector2(16, -186), Vector2(16, -170)]), RED, 1.5)
		draw_circle(Vector2(0, -178), 4, RED.darkened(0.2))
		# remaches y hombros
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(62 * s, -170), 16, STEEL_D)
			draw_arc(Vector2(62 * s, -170), 16, 0, TAU, 16, OUT, 2.0)
			draw_circle(Vector2(46 * s, -100), 3, CHROME)
		if cracked:
			draw_polyline(PackedVector2Array([Vector2(-50, -180), Vector2(-36, -160), Vector2(-46, -140)]), OUT, 2.0)
			draw_circle(Vector2(30, -170), 9, Color(0.15, 0.1, 0.08, 0.55))

	func _core() -> void:
		var c := Vector2.ZERO
		if open:
			draw_circle(c, 26.0 + 3.0 * sin(t * 10.0), Color(1.0, 0.6, 0.2, 0.3))
		draw_circle(c, 17, STEEL_D)
		draw_arc(c, 17, 0, TAU, 20, OUT, 2.0)
		if broken:
			draw_circle(c, 12, Color(0.08, 0.06, 0.06))
			draw_line(c + Vector2(-10, -8), c + Vector2(8, 10), CHROME, 2.0)
			return
		if open:
			# horno al rojo con granos que saltan
			draw_circle(c, 12, Color(1.0, 0.55 + 0.2 * sin(t * 12.0), 0.15))
			for k in 4:
				draw_circle(c + Vector2(cos(k * 1.6 + t * 6.0) * 6.0, sin(k * 1.6 + t * 6.0) * 6.0), 2.5, Color(1, 0.95, 0.5))
			return
		# perilla del horno y lucecitas
		draw_circle(c, 11, CHROME)
		draw_arc(c, 11, 0, TAU, 16, OUT, 1.5)
		draw_line(c, c + Vector2(cos(t) * 9.0, sin(t) * 9.0), OUT, 2.0)
		for k in 3:
			draw_circle(c + Vector2(-10 + k * 10, 22), 2.5, [Color(1, 0.2, 0.2), Color(1, 0.85, 0.2), Color(0.3, 1, 0.4)][k])

	func _head() -> void:
		var g := Vector2(0, -34)
		# cuello
		_box(Rect2(-10, -8, 20, 12), STEEL_D, 1.5)
		# microondas
		_box(Rect2(g.x - 46, g.y - 30, 92, 58), STEEL, 3.0)
		var scr := Rect2(g.x - 38, g.y - 22, 58, 42)
		_box(scr, Color(0.06, 0.08, 0.1), 2.0)
		# panel de botones a la derecha
		for k in 3:
			draw_rect(Rect2(g.x + 26, g.y - 18 + k * 12, 12, 7), CHROME)
		_face(scr)
		# antenita
		draw_line(g + Vector2(30, -30), g + Vector2(40, -54), OUT, 2.0)
		draw_circle(g + Vector2(40, -55), 3, RED)
		# gorro de chef
		if hat:
			_box(Rect2(g.x - 30, g.y - 44, 60, 16), WHITE, 2.0)
			for k in 3:
				draw_circle(g + Vector2(-20 + k * 20, -56), 15, WHITE)
				draw_arc(g + Vector2(-20 + k * 20, -56), 15, PI, TAU, 10, OUT, 2.0)
		if cracked:
			draw_polyline(PackedVector2Array([g + Vector2(-44, -26), g + Vector2(-30, -10), g + Vector2(-40, 8)]), OUT, 2.0)
		if broken:
			for k in 4:
				var a := randf() * TAU
				draw_line(g + Vector2(0, 0), g + Vector2(cos(a), sin(a)) * 20.0, Color(1, 0.9, 0.3), 2.0)

	## La cara en la pantalla del microondas.
	func _face(scr: Rect2) -> void:
		var c := scr.get_center()
		var glow := Color(0.4, 1.0, 0.8)
		match screen:
			0:   # sonrisa de presentador
				draw_circle(c + Vector2(-12, -6), 4, glow)
				draw_circle(c + Vector2(12, -6), 4, glow)
				draw_arc(c + Vector2(0, 2), 14, 0.3, PI - 0.3, 10, glow, 3.0)
			1:   # enojado
				glow = Color(1, 0.35, 0.25)
				draw_line(c + Vector2(-18, -12), c + Vector2(-6, -6), glow, 3.0)
				draw_line(c + Vector2(18, -12), c + Vector2(6, -6), glow, 3.0)
				draw_line(c + Vector2(-10, 10), c + Vector2(10, 10), glow, 3.0)
			2:   # SIN SEÑAL: barras de colores
				var cols := [Color(1, 1, 1), Color(1, 1, 0), Color(0, 1, 1), Color(0, 1, 0), Color(1, 0, 1), Color(1, 0, 0), Color(0, 0, 1)]
				var w := scr.size.x / 7.0
				for k in 7:
					draw_rect(Rect2(scr.position.x + k * w, scr.position.y + 2, w, scr.size.y - 4), cols[k])
				if fmod(t, 0.3) < 0.15:
					draw_rect(Rect2(scr.position + Vector2(0, scr.size.y * 0.5), Vector2(scr.size.x, 3)), Color(0, 0, 0, 0.6))
			_:   # mareado
				glow = Color(1, 0.9, 0.3)
				for s in [-1.0, 1.0]:
					var e := c + Vector2(12 * s, -6)
					draw_line(e + Vector2(-4, -4), e + Vector2(4, 4), glow, 2.0)
					draw_line(e + Vector2(-4, 4), e + Vector2(4, -4), glow, 2.0)
				draw_arc(c + Vector2(0, 10), 6, 0, TAU, 10, glow, 2.0)

	func _arm(len: float) -> void:
		draw_circle(Vector2.ZERO, 15, STEEL_D)
		_box(Rect2(-11, 0, 22, len * 0.55), STEEL, 2.0)
		_box(Rect2(-9, len * 0.55, 18, len * 0.35), STEEL, 2.0)
		draw_circle(Vector2(0, len * 0.55), 7, CHROME)
		draw_circle(Vector2(0, len * 0.92), 11, STEEL_D)
		draw_arc(Vector2(0, len * 0.92), 11, 0, TAU, 12, OUT, 1.5)
		draw_arc(Vector2.ZERO, 15, 0, TAU, 14, OUT, 2.0)

	func _pan() -> void:
		_arm(96.0)
		match tool:
			0:   # sartén gigante
				draw_line(Vector2(0, 86), Vector2(0, 120), OUT, 8.0)
				draw_line(Vector2(0, 86), Vector2(0, 120), WOOD, 5.0)
				var c := Vector2(0, 146)
				var pts := PackedVector2Array()
				for i in 18:
					var a := TAU * i / 18.0
					pts.append(c + Vector2(cos(a) * 30.0, sin(a) * 24.0))
				_poly(pts, Color(0.18, 0.18, 0.2), 2.5)
				draw_circle(c, 18, Color(0.28, 0.28, 0.3))
			1:   # cuchillo de chef
				draw_line(Vector2(0, 84), Vector2(0, 110), OUT, 9.0)
				draw_line(Vector2(0, 84), Vector2(0, 110), Color(0.15, 0.12, 0.1), 6.0)
				_poly(PackedVector2Array([Vector2(-10, 110), Vector2(10, 110), Vector2(4, 182), Vector2(-10, 160)]), CHROME, 2.0)
			_:   # cucharón
				draw_line(Vector2(0, 84), Vector2(0, 150), OUT, 6.0)
				draw_line(Vector2(0, 84), Vector2(0, 150), CHROME, 3.0)
				draw_circle(Vector2(0, 160), 14, CHROME)
				draw_arc(Vector2(0, 160), 14, 0, TAU, 14, OUT, 2.0)
				draw_circle(Vector2(0, 160), 8, Color(1, 0.9, 0.5))

	func _mic() -> void:
		_arm(96.0)
		match tool:
			0:   # micrófono
				draw_line(Vector2(0, 84), Vector2(0, 124), OUT, 8.0)
				draw_line(Vector2(0, 84), Vector2(0, 124), Color(0.2, 0.2, 0.22), 5.0)
				draw_circle(Vector2(0, 132), 11, CHROME)
				draw_arc(Vector2(0, 132), 11, 0, TAU, 12, OUT, 2.0)
				draw_rect(Rect2(-8, 116, 16, 5), RED)
			1:   # claqueta
				_box(Rect2(-24, 96, 48, 34), Color(0.1, 0.1, 0.12), 2.0)
				var open_k := 0.3 + 0.2 * sin(t * 6.0)
				draw_set_transform(anim_off + Vector2(-24, 96).rotated(anim_rot), anim_rot - open_k, Vector2.ONE)
				_box(Rect2(0, -10, 48, 10), WHITE, 2.0)
				for k in 4:
					draw_rect(Rect2(4 + k * 12, -10, 6, 10), OUT)
				draw_set_transform(anim_off, anim_rot, Vector2.ONE)
			2:   # mano saludando
				var h := Vector2(0, 100)
				draw_circle(h, 15, STEEL)
				draw_arc(h, 15, 0, TAU, 14, OUT, 2.0)
				for k in 5:
					var a := PI * 0.5 + (k - 2) * 0.38
					var f := h + Vector2(cos(a), sin(a)) * 14.0
					draw_line(f, f + Vector2(cos(a), sin(a)) * 14.0, OUT, 8.0)
					draw_line(f, f + Vector2(cos(a), sin(a)) * 14.0, STEEL, 5.0)
			_:   # cámara de mano (furia)
				_box(Rect2(-22, 96, 44, 30), Color(0.15, 0.15, 0.18), 2.0)
				draw_circle(Vector2(-22, 111), 9, OUT)
				draw_circle(Vector2(-22, 111), 5, Color(0.3, 0.5, 0.9))
				if fmod(t, 0.6) < 0.3:
					draw_circle(Vector2(16, 102), 4, RED)


## Estudio a oscuras de la aparición (se prenden los reflectores uno por uno).
class Dark extends Node2D:
	var area := Rect2(-500, -310, 1000, 620)
	var a := 0.85
	var lights := [false, false, false]

	func _ready() -> void:
		z_index = 15

	func light(i: int) -> void:
		lights[i] = true

	func fade() -> void:
		var tw := create_tween()
		tw.tween_property(self, "a", 0.0, 0.5)
		tw.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(area.grow(300.0), Color(0, 0, 0, a))
		var c := area.get_center()
		for i in 3:
			if lights[i]:
				var x := c.x + (i - 1) * 300.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 20, area.position.y - 40), Vector2(x + 20, area.position.y - 40),
					Vector2(x + 140, c.y + 120), Vector2(x - 140, c.y + 120)]), Color(1, 0.95, 0.7, 0.18 * a / 0.85))


## Gorro de chef que sale volando.
class HatFall extends Node2D:
	var t := 0.0
	var vel := Vector2(-150, -300)

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		t += delta
		if t < 0.9:
			vel.y += 900.0 * delta
			global_position += vel * delta
			rotation -= 5.0 * delta
		if t > 2.5:
			modulate.a = clampf(1.0 - (t - 2.5) / 0.5, 0.0, 1.0)
		if t > 3.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_kp_head_3")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO)
			return
		var w := Color(0.96, 0.95, 0.92)
		draw_rect(Rect2(-30, 0, 60, 16), w)
		draw_rect(Rect2(-30, 0, 60, 16), Color(0.06, 0.06, 0.08), false, 2.0)
		for k in 3:
			draw_circle(Vector2(-20 + k * 20, -10), 15, w)


## Franja de transmisión de TV: reemplaza la barra de vida (vida, fase, cámaras y estado).
class Broadcast extends Control:
	var boss: Node
	var _chip := 1.0
	var t := 0.0

	func _ready() -> void:
		size = Vector2(600, 74)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		if boss == null or not is_instance_valid(boss):
			return
		var k: float = float(boss.get("hp")) / float(boss.get("MAX_HP"))
		_chip = maxf(k, _chip - 0.004) if _chip > k else k
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.08, 0.09, 0.14, 0.92))
		if boss == null or not is_instance_valid(boss):
			return
		var f := ThemeDB.fallback_font
		var ink := Color(0.95, 0.95, 1.0)
		var k: float = float(boss.get("hp")) / float(boss.get("MAX_HP"))
		var ph: int = boss.get("phase")
		var st: String = boss.get("state")
		var stunned := st == "stunned" and float(boss.get("panic_left")) > 0.0
		# punto rojo EN VIVO
		var on_air: bool = boss.get("on_air")
		if on_air and fmod(t, 1.0) < 0.6:
			draw_circle(Vector2(16, 14), 6, Color(1, 0.15, 0.15))
		draw_string(f, Vector2(28, 19), "EN VIVO" if on_air else "SIN SEÑAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.4, 0.4) if on_air else Color(0.6, 0.9, 1.0))
		draw_string(f, Vector2(110, 19), "¡Cocinando al Aire! · KERNEL PANIC", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.85, 0.4))
		var names := ["Primer bloque", "Segundo bloque", "Gran final"]
		var tag: String = names[ph - 1]
		if boss.get("enraged"):
			tag = "FUERA DE AIRE"
		draw_string(f, Vector2(400, 19), "%s · %d/3" % [tag, ph], HORIZONTAL_ALIGNMENT_RIGHT, 190, 12, ink)
		# cámaras
		var cams: Array = boss.get("cams")
		var x := 10.0
		for c in cams:
			if not is_instance_valid(c):
				continue
			var live := bool(c.get("live")) and not bool(c.get("broken"))
			var box := Rect2(x, 28, 92, 22)
			draw_rect(box, Color(0.85, 0.15, 0.15) if live else Color(0.2, 0.22, 0.28))
			var lbl := "MANO" if bool(c.get("handheld")) else "CAM %d" % (int(c.get("idx")) + 1)
			if bool(c.get("broken")):
				lbl += " ✕"
			draw_string(f, Vector2(x + 4, 43), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
			var mx: int = c.get("max_hp")
			var hpc: int = c.get("hp")
			for i in mx:
				draw_rect(Rect2(x + 56 + i * 8, 34, 6, 10), Color(1, 1, 1) if i < hpc and not bool(c.get("broken")) else Color(0.35, 0.35, 0.4))
			draw_rect(box, Color(0, 0, 0), false, 1.5)
			x += 98.0
		# estado
		var label := "AL AIRE ·  daño ½"
		var col := Color(0.75, 0.2, 0.2)
		if stunned:
			label = "¡KERNEL PANIC! x2"
			col = Color(0.15, 0.6, 0.3)
		elif st == "transition":
			label = "CORTE COMERCIAL"
			col = Color(0.5, 0.45, 0.2)
		elif not on_air:
			label = "SIN CÁMARA"
			col = Color(0.3, 0.4, 0.55)
		draw_rect(Rect2(410, 28, 130, 22), col)
		draw_string(f, Vector2(410, 43), label, HORIZONTAL_ALIGNMENT_CENTER, 130, 11, Color(1, 1, 1))
		draw_string(f, Vector2(540, 43), "P %d" % int(boss.get("panics")), HORIZONTAL_ALIGNMENT_RIGHT, 52, 12, ink)
		# barra de vida (tiempo al aire)
		draw_rect(Rect2(0, 62, 600, 10), Color(0.2, 0.2, 0.25, 0.9))
		draw_rect(Rect2(0, 62, 600 * _chip, 10), Color(1, 0.95, 0.9))
		draw_rect(Rect2(0, 62, 600 * k, 10), Color(0.95, 0.3, 0.2))
		for fr in [0.6, 0.3]:
			draw_rect(Rect2(600 * fr - 1, 62, 2, 10), Color(0, 0, 0, 0.8))
		draw_rect(r, Color(0.85, 0.15, 0.15), false, 2.0)


## Cartel sobre la cabeza con el texto del ataque.
class Holo extends Node2D:
	var text := ""
	var col := Color.WHITE
	var t := 9.0
	var dur := 1.1

	func _ready() -> void:
		z_index = 6

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
		draw_rect(box, Color(0.08, 0.09, 0.14, 0.92 * a))
		draw_rect(box, Color(col.r, col.g, col.b, a), false, 2.0)
		draw_string(f, Vector2(-w * 0.5, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, a))


## Cuenta atrás sobre la cámara encendida en el duelo final.
class CamTimer extends Node2D:
	var boss: Node
	var t := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if boss == null or not is_instance_valid(boss):
			return
		var left: float = boss.get("_final_left")
		var total: float = maxf(0.01, float(boss.get("_final_total")))
		var k := clampf(left / total, 0.0, 1.0)
		var col := Color(1, 0.3, 0.3) if k < 0.35 else Color(1, 0.85, 0.3)
		draw_circle(Vector2.ZERO, 20, Color(0, 0, 0, 0.7))
		draw_arc(Vector2.ZERO, 20, -PI * 0.5, -PI * 0.5 + TAU * k, 32, col, 4.0)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(-20, 6), "%.1f" % left, HORIZONTAL_ALIGNMENT_CENTER, 40, 14, Color.WHITE)
		var a := 0.6 + 0.4 * sin(t * 12.0)
		draw_string_outline(f, Vector2(-40, -28), "¡EN VIVO!", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, 4, Color(0, 0, 0, a))
		draw_string(f, Vector2(-40, -28), "¡EN VIVO!", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(1, 0.35, 0.3, a))
