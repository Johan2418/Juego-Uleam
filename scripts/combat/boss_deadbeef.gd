extends CharacterBody2D
## Boss 0xDEADBEEF (Facultad de Ciencias de la Vida y Tecnología) — versión de PRUEBA con figuras.
## Se anima por piezas (Part): cuando lleguen las hojas de grokbot (GROKBOT_BOSS_1.md), cada Part
## se cambia por un Sprite2D en el mismo pivote y el resto del código sigue igual.
## Sin class_name: cargar con preload("res://scripts/combat/boss_deadbeef.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Epic := preload("res://scripts/combat/epic_fx.gd")
const Barrage := preload("res://scripts/combat/boss_barrage.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const MinionScript := preload("res://scripts/combat/boss_minion.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")
const Final := preload("res://scripts/combat/boss_final.gd")
const Roar := preload("res://scripts/combat/boss_roar.gd")

signal hp_changed(hp: int, max_hp: int)
signal phase_changed(phase: int, title: String)
signal stunned
signal intro_finished
signal defeated
signal staggered
signal arm_broken(arm: String)

const MAX_HP := 80
## Cambio de fase al bajar de estos porcentajes de vida.
const PHASE_AT := [0.6, 0.3]
const MOVE_SPEED := 58.0
const KEEP_DIST := 190.0
const CHARGE_SPEED := 560.0
## Pausa entre ataques por fase.
const PAUSE := [1.4, 1.0, 0.7]
## Daño (sin punto débil) que aguanta antes de tambalearse, por fase.
const POISE := [8, 11, 14]
## Vida (fracción) a la que entra en OVERCLOCK (fase 3 furiosa).
const ENRAGE_AT := 0.12
## Vida de cada brazo: si se rompe, deja de usar sus ataques.
const ARM_HP := 12
## Brazos por fase: F1 se rompen para siempre. F2 el brazo roto SE REGENERA a los REGEN_TIME s
## (cada golpe al muñón lo retrasa). F3 los brazos están blindados y solo reciben daño mientras atacan.
const REGEN_TIME := 9.0
const REGEN_DELAY_PER_HIT := 1.5
## Duelo final SEGMENTATION FAULT: lanza sus brazos; parry para clavárselos. El último va al cráneo.
const FINAL_THROWS := 6
## Ataques que necesitan cada brazo.
const ARM_ATTACKS := {"claw": ["claw", "roots"], "grabber": ["crates", "cable"]}
## Combos por fase: ataques que encadena seguidos.
const COMBOS := {
	2: [["claw", "claw"], ["cable", "charge"], ["gas", "claw"], ["crates", "roots"]],
	3: [["laser", "stampede"], ["claw", "claw", "stomp"], ["crates", "laser"], ["cable", "charge", "gas"]],
}
## Puntos del cuerpo (locales; el origen es el suelo, centro de las orugas).
const SHOULDER_L := Vector2(-66, -158)
const SHOULDER_R := Vector2(80, -152)
const MOUTH := Vector2(-45, -168)
const MONITOR := Vector2(12, -212)
const CENTER := Vector2(0, -60)
const ARM_LEN := 140.0
const TANK_POS := Vector2(-10, -50)
const SKULL_POS := Vector2(0, -160)
## Pantalla del monitor respecto al cráneo (en la hoja de grokbot van juntos).
const SCREEN_OFF := Vector2(12, -52)
const REST_L := 0.45
const REST_R := -0.35
## Torso sacado del sprite completo (tools/make_boss_torso.py): esquina sup. izq. respecto a los pies.
const TORSO_POS := Vector2(-81, -207)

var hp: int = MAX_HP
var phase: int = 1
## intro, idle, attack, charge, stunned, transition, paused, dead
var state: String = "intro"
var arena_rect: Rect2 = Rect2(-500, -310, 1000, 620)
var player: CharacterBody2D
var tank_open: bool = false

var _tok: int = 0
var _cd: float = 1.0
var _last: String = ""
var _parry_watch: bool = false
var _was_parried: bool = false
var _grabbed: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _charge_hit: bool = false
var _t: float = 0.0
var _tweens: Array[Tween] = []
var rig_off: Vector2 = Vector2.ZERO
var enraged: bool = false
var _pose_tw: Tween
var _poise: int = 0
var _queue: Array[String] = []
var _near_t: float = 0.0
var _step_t: float = 0.0
var _holo: Holo
var _kick: Vector2 = Vector2.ZERO     # retroceso de la cabeza al recibir golpes
var _lean: float = 0.0                # inclinación al moverse
var _fx_t: float = 0.0                # temporizador de vapor/chispas
var arm_hp: Dictionary = {"claw": ARM_HP, "grabber": ARM_HP}
var broken_arms: Array[String] = []
var _regen: Dictionary = {}          # brazo -> segundos que faltan para regenerarse
var final_victory: bool = false
var _final_hits: int = 0
var _final_fail: bool = false
var _thrown: int = 0

var rig: Node2D
var treads: Part
var chassis: Part
var tank: Part
var skull: Part
var monitor: Part
var claw: Part
var grabber: Part
var _home: Dictionary = {}


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	z_index = 1
	# capa 1 además de la 2: el jugador choca con él (no lo atraviesa)
	collision_layer = 3
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(190, 40)
	shape.shape = r
	shape.position = Vector2(0, -20)
	add_child(shape)
	# zona donde le pegan los ataques del jugador (todo el cuerpo)
	var hurt := Area2D.new()
	hurt.name = "Hurtbox"
	hurt.collision_layer = 2
	hurt.collision_mask = 0
	hurt.monitoring = false
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(200, 260)
	hs.shape = hr
	hs.position = Vector2(0, -130)
	hurt.add_child(hs)
	add_child(hurt)
	GameFeel.add_shadow(self, Vector2(0, -2), Vector2(104, 18))
	_build_rig()


func set_player(p: CharacterBody2D) -> void:
	player = p
	var cc = p.get("class_controller")
	if cc != null and cc.has_signal("parried"):
		cc.connect("parried", _on_player_parried)


# --- Piezas ----------------------------------------------------------------------

func _build_rig() -> void:
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)
	treads = _part("treads", Vector2.ZERO)
	chassis = _part("chassis", Vector2.ZERO)
	tank = _part("tank", TANK_POS)
	claw = _part("claw", SHOULDER_L)
	grabber = _part("grabber", SHOULDER_R)
	skull = _part("skull", SKULL_POS)
	monitor = _part("monitor", MONITOR)
	claw.rotation = REST_L
	grabber.rotation = REST_R
	skull.eyes_red = true
	_holo = Holo.new()
	_holo.position = Vector2(0, -292)
	rig.add_child(_holo)
	_face(_base_face()[0], _base_face()[1], _base_face()[2])


func _part(kind: String, pos: Vector2) -> Part:
	var p := Part.new()
	p.kind = kind
	p.name = kind
	p.position = pos
	p.use_parent_material = true   # el destello del rig se aplica a todas las piezas
	rig.add_child(p)
	_home[p] = pos
	p.sprites = Spr.tex("boss_0xdeadbeef_body_0") != null
	if p.sprites and kind == "treads":
		p.visible = false
	return p


func _parts() -> Array:
	return [treads, chassis, tank, claw, grabber, skull, monitor]


func _base_face() -> Array:
	if enraged:
		return ["!!!", Color(1, 0.25, 0.15), Color(0.25, 0.0, 0.0)]
	match phase:
		1:
			return ["^_^", Color(0.45, 1.0, 0.5), Color(0.04, 0.1, 0.05)]
		2:
			return [">_<", Color(1.0, 0.6, 0.2), Color(0.25, 0.03, 0.02)]
		_:
			return [":(", Color(1, 1, 1), Color(0.05, 0.2, 0.75)]


func _face(text: String, col: Color = Color(0.45, 1.0, 0.5), bg: Color = Color(-1, 0, 0)) -> void:
	monitor.face = text
	monitor.face_color = col
	monitor.screen = _base_face()[2] if bg.r < 0.0 else bg
	# la pantalla es pequeña: el texto de cada ataque sale también en grande sobre la cabeza
	if _holo and text != "" and text != _base_face()[0]:
		_holo.show_text(text, col)


# --- Bucle ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	if state != "dead":
		var bob := sin(_t * 3.0) * 1.5
		if state == "idle" and velocity.length() > 1.0:
			bob = -absf(sin(_t * 9.0)) * 2.5   # traqueteo de las orugas
		rig.position = rig_off + Vector2(0, bob)
		if enraged:
			var k := 0.7 + 0.3 * absf(sin(_t * 6.0))
			rig.modulate = Color(1.0, k, k)
		_secondary_motion(delta)
	_update_depth()
	_regen_step(delta)
	if monitor.sprites:
		monitor.position = skull.position + SCREEN_OFF
	match state:
		"idle":
			_ai_move(delta)
			if _player_ok() and _player_feet().distance_to(global_position) < 160.0:
				_near_t += delta
			else:
				_near_t = maxf(0.0, _near_t - delta)
			_cd -= delta
			if _cd <= 0.0:
				_choose_attack()
		"charge":
			_charge_step(delta)
		_:
			velocity = Vector2.ZERO


func _ai_move(delta: float) -> void:
	if not _player_ok():
		return
	var to := player.global_position - global_position
	var dist := to.length()
	var dir := Vector2.ZERO
	if dist > KEEP_DIST + 30.0:
		dir = to.normalized()
	elif dist < KEEP_DIST - 70.0:
		dir = -to.normalized() * 0.6
	velocity = dir * MOVE_SPEED * (1.0 + 0.25 * (phase - 1))
	move_and_slide()
	treads.scroll += velocity.length() * delta
	if velocity.length() > 1.0:
		_step_t += delta
		if _step_t > 0.2:
			_step_t = 0.0
			for sx in [-80.0, 80.0]:
				GameFeel.dust(get_parent(), global_position + Vector2(sx, -2), 1, -velocity.normalized() * 30.0, 4.0, Vector2(8, 2))
	_clamp_inside()


## Movimiento secundario: cada pieza respira con un pequeño retraso, la cabeza retrocede al recibir
## golpes, el cuerpo se inclina hacia donde avanza y sale vapor/chispas según la fase.
func _secondary_motion(delta: float) -> void:
	var calm := state in ["idle", "intro"]
	_kick = _kick.lerp(Vector2.ZERO, minf(1.0, delta * 10.0))
	skull.anim_off = Vector2(0, sin(_t * 3.0 - 0.7) * 2.0) + _kick
	tank.anim_off = Vector2(0, sin(_t * 3.0 - 0.3) * 0.8)
	monitor.anim_off = skull.anim_off   # la pantalla va pegada al cráneo
	claw.anim_rot = sin(_t * 2.1) * 0.05 if calm else 0.0
	grabber.anim_rot = sin(_t * 2.1 + 1.3) * 0.05 if calm else 0.0
	var target := 0.0
	if state in ["idle", "charge"]:
		target = clampf(velocity.x / 600.0, -0.08, 0.08)
	_lean = lerpf(_lean, target, minf(1.0, delta * 6.0))
	rig.skew = _lean
	monitor.glitch = 0.0 if phase == 1 else (0.04 if phase == 2 else 0.1)
	if enraged:
		monitor.glitch = 0.2
	for arm in broken_arms:
		if randf() < delta * 3.0:
			var sp2 := BossFx.Sparks.new()
			sp2.dir = Vector2(-1 if arm == "claw" else 1, 0.4).normalized()
			get_parent().add_child(sp2)
			sp2.global_position = global_position + rig_off + (SHOULDER_L if arm == "claw" else SHOULDER_R)
	_fx_t -= delta
	if _fx_t <= 0.0 and state != "intro" and phase >= 2:
		_fx_t = randf_range(0.25, 0.6) / (1.0 if phase == 2 else 1.6)
		# vapor de los tubos de ensayo del hombro
		GameFeel.dust(get_parent(), global_position + rig_off + Vector2(randf_range(62, 90), -200), 1, Vector2(randf_range(-10, 10), -50), 4.0, Vector2(4, 2))
		if phase >= 3 and randf() < 0.5:
			var sp := BossFx.Sparks.new()
			sp.dir = Vector2.from_angle(randf_range(-PI, 0))
			get_parent().add_child(sp)
			sp.global_position = global_position + rig_off + Vector2(randf_range(-70, 70), randf_range(-170, -90))


## Orden de dibujo: si el jugador está detrás (más arriba en pantalla) el boss lo tapa.
func _update_depth() -> void:
	if _player_ok():
		z_index = 3 if _player_feet().y < global_position.y else 1


func _clamp_inside() -> void:
	global_position.x = clampf(global_position.x, arena_rect.position.x + 110.0, arena_rect.end.x - 110.0)
	global_position.y = clampf(global_position.y, arena_rect.position.y + 230.0, arena_rect.end.y - 30.0)


func _choose_attack() -> void:
	CoopBoss.retarget(self)
	var pick := ""
	if not _queue.is_empty():
		pick = _queue.pop_front()
	elif _near_t > 1.3:
		pick = "stomp"   # el jugador se quedó pegado: pisotón
	elif phase >= 2 and randf() < (0.3 if phase == 2 else 0.45) and _combo_ok():
		var list: Array = _usable_combos()
		_queue.assign(list[randi() % list.size()])
		pick = _queue.pop_front()
	else:
		pick = _pick_single()
	_near_t = 0.0
	_last = pick
	_tok += 1
	state = "attack"
	velocity = Vector2.ZERO
	call("_atk_" + pick, _tok)


func _pick_single() -> String:
	var pool: Array[String] = ["claw", "crates", "charge"]
	if phase >= 2:
		pool.append_array(["gas", "roots", "cable"])
	if phase >= 3:
		pool.append_array(["stampede", "laser"])
	if not broken_arms.is_empty():
		pool.append("stomp")   # sin brazos pelea más a lo bruto
	var near := _player_ok() and player.global_position.distance_to(global_position) < 210.0
	var bag: Array[String] = []
	for a in pool:
		if a == _last or not _can_use(a):
			continue
		bag.append(a)
		if a == "claw" and near:
			bag.append_array(["claw", "claw"])
	if bag.is_empty():
		return "charge" if _last != "charge" else "stomp"
	return bag[randi() % bag.size()]


func _can_use(attack: String) -> bool:
	for arm in broken_arms:
		if attack in ARM_ATTACKS[arm]:
			return false
	return true


func _usable_combos() -> Array:
	var out: Array = []
	for c in COMBOS[phase]:
		var ok := true
		for a in c:
			ok = ok and _can_use(a)
		if ok:
			out.append(c)
	return out


func _combo_ok() -> bool:
	return not _usable_combos().is_empty()


func _end_attack(tok: int) -> void:
	if tok != _tok:
		return
	state = "idle"
	_rest_pose()
	_cd = PAUSE[phase - 1] * (0.6 if enraged else 1.0)
	if not _queue.is_empty():
		_cd = 0.3   # sigue el combo
	elif phase >= 3 and randf() < 0.35:
		_cd = 0.2   # fase 3: a veces encadena dos ataques
	_face(_base_face()[0], _base_face()[1], _base_face()[2])


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


## Rotación de un brazo (que en reposo apunta hacia abajo) para que apunte a `dir`.
func _rot_for(dir: Vector2) -> float:
	return dir.angle() - PI * 0.5


## Tiempo de aviso según la fase (más corto en fases altas).
func _tele(t: float) -> float:
	return t * [1.0, 0.85, 0.72][phase - 1] * (0.85 if enraged else 1.0)


## Postura del cuerpo entero (inclinarse, agacharse, echarse atrás). La nueva reemplaza a la anterior.
func _pose(off: Vector2, rot: float, time: float) -> void:
	if _pose_tw and _pose_tw.is_valid():
		_pose_tw.kill()
	_pose_tw = create_tween().set_parallel(true)
	_pose_tw.tween_property(self, "rig_off", off, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tw.tween_property(rig, "rotation", rot, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _rest_pose(time: float = 0.3) -> void:
	_pose(Vector2.ZERO, 0.0, time)


## Golpe contra el piso: temblor, polvo y una pausa muy corta.
## Color de los efectos épicos de este boss.
func _accent() -> Color:
	return Color(1.0, 0.3, 0.2)


func _impact(at: Vector2, strength: float) -> void:
	_shake(strength, 0.1 + strength * 0.03)
	Epic.big_hit(get_parent(), at, _accent(), strength, "deadbeef", "fxtoxic")
	GameFeel.dust(get_parent(), at, int(4 + strength), Vector2.ZERO, 5.0, Vector2(20 + strength * 3.0, 6))
	GameFeel.hit_stop(get_tree(), 0.04)


## Zona roja en el piso que avisa dónde va a pegar. half_angle = 0 -> círculo.
func _warn_zone(at: Vector2, dir: Vector2, reach: float, half_angle: float, life: float) -> void:
	if reach >= 120.0:
		Epic.charge(get_parent(), global_position + CENTER, _accent(), life * 0.85, 110.0, self, CENTER)
	var z := BossFx.TeleZone.new()
	z.dir = dir
	z.reach = reach
	z.half_angle = half_angle
	z.life = life
	_add_fx(z, at)


## Durante la embestida atraviesa al jugador (si no, se frena contra él).
func _ghost(on: bool) -> void:
	if not _player_ok():
		return
	if on:
		add_collision_exception_with(player)
	else:
		remove_collision_exception_with(player)


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
	if n.get("boss") != null or n.has_method("hurt"):
		n.set("boss", self)
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


## Corta el ataque en curso (aturdido, cambio de fase, muerte).
func _interrupt() -> void:
	_tok += 1
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
	_queue.clear()
	velocity = Vector2.ZERO
	_ghost(false)
	_release_player()
	_rest_pose(0.2)
	for p in _parts():
		p.modulate = Color.WHITE
	claw.open = false
	claw.fist = false
	grabber.open = false
	grabber.extra = false
	skull.open = false
	skull.position = _home[skull]
	skull.eyes_red = true


## Daño al jugador. unblockable = el parry no lo detiene (hay que rodar).
func hurt_player(amount: int, from: Vector2, unblockable: bool = false) -> void:
	if not _player_ok() or state == "dead" or state == "paused":
		return
	_who().call("take_hit", amount, from, unblockable)


func _on_player_parried(_from: Vector2) -> void:
	if _parry_watch:
		_was_parried = true


func _release_player() -> void:
	if _grabbed and _player_ok():
		player.set_physics_process(true)
	_grabbed = false


# --- Recibir daño ----------------------------------------------------------------

func take_hit(amount: int, from: Vector2) -> void:
	if state in ["intro", "transition", "dead", "paused", "final"]:
		GameFeel.flash(rig, 0.08, Color(0.6, 0.6, 0.7))
		return
	var dmg := amount * (2 if tank_open else 1)
	# a un golpe de caer en la fase 3: SEGMENTATION FAULT en vez de morir
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
	_kick = -toward * (5.0 + 3.0 * dmg)
	var num := BossFx.DmgNumber.new()
	num.text = str(dmg) + ("!" if tank_open else "")
	num.big = tank_open
	num.color = Color(1, 0.9, 0.3) if tank_open else Color(1, 1, 1)
	get_parent().add_child(num)
	num.global_position = center + toward * 50.0 + Vector2(0, -40)
	if tank_open:
		GameFeel.parry_burst(get_parent(), global_position + TANK_POS + Vector2(0, -56), 30.0)
	else:
		# pega en el blindaje: chispas
		var sp := BossFx.Sparks.new()
		sp.dir = toward
		get_parent().add_child(sp)
		sp.global_position = center + toward * 70.0
	_hurt_arm(from, dmg)
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


## Golpes desde un costado dañan el brazo de ese lado (garra a la izquierda, pinza a la derecha).
func _hurt_arm(from: Vector2, dmg: int) -> void:
	var dx := from.x - global_position.x
	if absf(dx) < 45.0:
		return
	var arm := "claw" if dx < 0.0 else "grabber"
	if arm in broken_arms:
		# golpear el muñón retrasa que vuelva a crecer
		if _regen.has(arm):
			_regen[arm] = minf(REGEN_TIME, float(_regen[arm]) + REGEN_DELAY_PER_HIT)
			_num("RETRASO", Color(0.6, 1, 0.6), global_position + rig_off + (SHOULDER_L if arm == "claw" else SHOULDER_R))
		return
	if phase >= 3 and not _arm_exposed(arm):
		_num("BLINDADO", Color(0.75, 0.8, 0.9), global_position + rig_off + (SHOULDER_L if arm == "claw" else SHOULDER_R) + Vector2(0, 60))
		return
	arm_hp[arm] -= dmg
	var part: Part = claw if arm == "claw" else grabber
	part.modulate = Color(1.8, 0.6, 0.5)
	create_tween().tween_property(part, "modulate", Color.WHITE, 0.2)
	if arm_hp[arm] <= 0:
		_break_arm(arm)


## Fase 3: el brazo solo es vulnerable mientras ataca con él (brilla).
func _arm_exposed(arm: String) -> bool:
	return state == "attack" and _last in ARM_ATTACKS[arm]


func _num(text: String, col: Color, at: Vector2) -> void:
	var n := BossFx.DmgNumber.new()
	n.text = text
	n.color = col
	get_parent().add_child(n)
	n.global_position = at


## Fase 2+: los brazos rotos vuelven a crecer.
func _regen_step(delta: float) -> void:
	if phase < 2 or state in ["dead", "final", "intro"]:
		return
	for arm in broken_arms.duplicate():
		if not _regen.has(arm):
			_regen[arm] = REGEN_TIME
		_regen[arm] = float(_regen[arm]) - delta
		var part: Part = claw if arm == "claw" else grabber
		var left: float = _regen[arm]
		# aviso: el muñón echa chispas verdes en los últimos 3 s
		if left < 3.0 and randf() < delta * 12.0:
			var sh: Vector2 = global_position + rig_off + (SHOULDER_L if arm == "claw" else SHOULDER_R)
			GameFeel.dust(get_parent(), sh + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 1, Vector2(0, -30), 3.0, Vector2(4, 4))
		if left <= 0.0:
			_regrow(arm)


func _regrow(arm: String) -> void:
	broken_arms.erase(arm)
	_regen.erase(arm)
	arm_hp[arm] = int(ARM_HP * 0.75)
	var part: Part = claw if arm == "claw" else grabber
	part.visible = true
	part.scale = Vector2(0.2, 0.2)
	part.modulate = Color(0.6, 1.8, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(part, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(part, "modulate", Color.WHITE, 0.6)
	if _holo:
		_holo.show_text("REGENERADO", Color(0.5, 1, 0.5))
	GameFeel.parry_burst(get_parent(), global_position + rig_off + (SHOULDER_L if arm == "claw" else SHOULDER_R), 34.0)
	_shake(3.0, 0.2)


func _break_arm(arm: String) -> void:
	broken_arms.append(arm)
	var part: Part = claw if arm == "claw" else grabber
	var shoulder: Vector2 = global_position + rig_off + (SHOULDER_L if arm == "claw" else SHOULDER_R)
	part.visible = false
	var n := ("boss_0xdeadbeef_claw_1" if arm == "claw" else "boss_0xdeadbeef_grabber_1")
	var f := BossFx.FallingPart.new()
	f.tex_name = n
	f.pivot = Spr.top_pivot(n)
	f.vel = Vector2(-160.0 if arm == "claw" else 160.0, -260.0)
	f.floor_y = global_position.y + 20.0
	get_parent().add_child(f)
	f.global_position = shoulder
	f.rotation = part.rotation
	for i in 3:
		GameFeel.parry_burst(get_parent(), shoulder + Vector2(randf_range(-12, 12), randf_range(-12, 12)), 30.0)
	_shake(7.0, 0.35)
	GameFeel.hit_stop(get_tree(), 0.12)
	arm_broken.emit(arm)
	# si estaba usando ese brazo, corta el ataque
	if state == "attack" and _last in ARM_ATTACKS[arm]:
		_stagger()


## Muchos golpes seguidos sin punto débil: se tambalea un momento (corta su ataque).
func _stagger() -> void:
	_interrupt()
	var tok := _tok
	state = "stunned"
	_face("ERR?", Color(1, 0.8, 0.4))
	_pose(Vector2(0, 8), 0.07 * (1.0 if randf() < 0.5 else -1.0), 0.12)
	GameFeel.flash(rig, 0.2, Color(1, 0.9, 0.6))
	_shake(3.0, 0.2)
	staggered.emit()
	if not await _wait(0.9, tok):
		return
	_rest_pose()
	state = "idle"
	_cd = 0.5
	_face(_base_face()[0], _base_face()[1], _base_face()[2])


## Fase 3 con poca vida: OVERCLOCK (más rápido, sin pausas largas, brilla en rojo).
func _enrage() -> void:
	enraged = true
	_interrupt()
	var tok := _tok
	state = "transition"
	tank_open = false
	tank.open = false
	skull.open = true
	_face("OVRCLK", Color(1, 0.2, 0.1), Color(0.2, 0, 0))
	_pose(Vector2(0, -14), 0.0, 0.3)
	GameFeel.flash(rig, 0.4, Color(1, 0.2, 0.1))
	_shake(9.0, 1.0)
	phase_changed.emit(3, "OVERCLOCK")
	for i in 6:
		GameFeel.dust(get_parent(), global_position + Vector2(randf_range(-80, 80), randf_range(-230, -150)), 3, Vector2(0, -60), 6.0, Vector2(10, 6))
		if not await _wait(0.2, tok):
			return
	skull.open = false
	_rest_pose()
	state = "idle"
	_cd = 0.3
	_face(_base_face()[0], _base_face()[1], _base_face()[2])


## El latigazo de Chain no mueve al boss (es muy pesado).
func pull_toward(_dest: Vector2) -> void:
	GameFeel.flash(rig, 0.06, Color(0.7, 0.7, 0.8))


## Solo para probar (F2 en la arena): baja la vida justo al cambio de fase siguiente.
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


func _stun(time: float) -> void:
	_interrupt()
	var tok := _tok
	state = "stunned"
	tank_open = true
	tank.open = true
	_face("@_@", Color(1, 1, 0.4))
	skull.eyes_red = false
	_tw(claw, "rotation", 0.7, 0.3)
	_tw(grabber, "rotation", -0.7, 0.3)
	_tw(skull, "position:y", (_home[skull] as Vector2).y + 10.0, 0.3)
	_pose(Vector2(0, 12), 0.05, 0.3)   # se desploma un poco
	_shake(4.0, 0.25)
	stunned.emit()
	if not await _wait(time, tok):
		return
	tank_open = false
	tank.open = false
	skull.eyes_red = true
	_rest_pose()
	_tw(claw, "rotation", REST_L, 0.3)
	_tw(grabber, "rotation", REST_R, 0.3)
	_tw(skull, "position:y", (_home[skull] as Vector2).y, 0.3)
	state = "idle"
	_cd = 0.8
	_face(_base_face()[0], _base_face()[1], _base_face()[2])


func _enter_phase(n: int) -> void:
	phase = n
	tank_open = false
	tank.open = false
	_interrupt()
	var tok := _tok
	state = "transition"
	skull.eyes_red = true
	skull.open = true
	claw.rotation = REST_L
	grabber.rotation = REST_R
	if n == 2:
		_face("ERROR", Color(1, 0.3, 0.2), Color(0.12, 0.0, 0.0))
	else:
		_face(":(", Color(1, 1, 1), Color(0.05, 0.2, 0.75))
		chassis.broken = true
	GameFeel.flash(rig, 0.3, Color(1.0, 0.3, 0.3))
	_pose(Vector2(0, -12), 0.0, 0.25)
	_shake(7.0, 0.8)
	phase_changed.emit(n, "ERROR SUMINISTRO" if n == 2 else "KERNEL PANIC")
	if not await _wait(1.6, tok):
		return
	# lluvia de ataques: inmune hasta que termine (esquivar o parry)
	if not await Barrage.run(self, n, tok):
		return
	skull.open = false
	_rest_pose()
	state = "idle"
	_cd = 0.4
	_face(_base_face()[0], _base_face()[1], _base_face()[2])


# --- Ataques ----------------------------------------------------------------------

## 1. Zarpazo de garra (Agropecuarias). Se puede bloquear con parry: queda aturdido.
func _atk_claw(tok: int) -> void:
	_face("!!", Color(1, 0.9, 0.3))
	var origin := global_position + CENTER
	var aim := _dir_to_player(origin)
	claw.open = true
	claw.modulate = Color(1.8, 1.6, 0.5)
	_tw(claw, "rotation", _rot_for(aim.rotated(-1.4)), _tele(0.5))
	_pose(-aim * 14.0 + Vector2(0, 4), -aim.x * 0.07, _tele(0.5))   # se echa atrás
	_warn_zone(global_position + Vector2(0, -10), aim, 210.0, 1.1, _tele(0.55))
	if not await _wait(_tele(0.55), tok):
		return
	claw.modulate = Color.WHITE
	_tw(claw, "rotation", _rot_for(aim.rotated(1.0)), 0.16)
	claw.open = false
	claw.fist = true   # la garra se cierra al golpear
	_pose(aim * 24.0, aim.x * 0.09, 0.08)   # embiste con el cuerpo
	var reach := 190.0
	SlashFx.spawn(get_parent(), origin + aim * 95.0, aim, reach, 80.0, 0.2, 1.0, true, false)
	_impact(origin + aim * 120.0, 4.0)
	if not await _wait(0.06, tok):
		return
	var stun := false
	for v in _victims():
		_victim = v
		var to := _player_body() - origin
		if to.length() <= reach and absf(aim.angle_to(to)) <= 1.15:
			_was_parried = false
			_parry_watch = true
			hurt_player(2, origin)
			_parry_watch = false
			stun = stun or _was_parried
	_victim = null
	if stun:
		_stun(3.0)
		return
	if not await _wait(0.5, tok):
		return
	claw.fist = false
	_tw(claw, "rotation", REST_L, 0.3)
	_end_attack(tok)


## 2. Lluvia de cajas y frutas (Agronegocios). Hay que salir de las sombras.
func _atk_crates(tok: int) -> void:
	_face("ENVIO", Color(1, 0.9, 0.4))
	grabber.open = true
	_tw(grabber, "rotation", _rot_for(Vector2(0.4, -1.0)), _tele(0.35))
	_pose(Vector2(0, 10), 0.0, _tele(0.35))   # se agacha
	if not await _wait(_tele(0.35), tok):
		return
	_pose(Vector2(0, -10), -0.04, 0.1)        # y lanza
	_shake(3.0, 0.15)
	var n: int = [5, 7, 9][phase - 1]
	for i in n:
		if not _player_ok():
			break
		var c := BossFx.FallingCrate.new()
		c.kind = randi() % 4
		c.delay = i * 0.12
		var target := _player_feet()
		if i > 0:
			target += Vector2.from_angle(randf() * TAU) * randf_range(50.0, 170.0)
		_add_fx(c, _clamp_arena(target))
	_tw(grabber, "rotation", REST_R, 0.4)
	grabber.open = false
	if not await _wait(1.3, tok):
		return
	_end_attack(tok)


## 3. Embestida con las orugas (Agroindustrias). Rodar de lado; si choca con la pared, aturdido.
func _atk_charge(tok: int) -> void:
	_face(">:(", Color(1, 0.3, 0.2))
	skull.eyes_red = true
	_tw(skull, "position:y", (_home[skull] as Vector2).y + 8.0, 0.2)
	var tele := _tele(0.75)
	var cdir := (player.global_position - global_position).normalized() if _player_ok() else Vector2.DOWN
	_pose(-cdir * 18.0 + Vector2(0, -4), -cdir.x * 0.1, tele)   # se echa atrás antes de salir
	_warn_zone(global_position, cdir, 460.0, 0.2, tele)
	for i in 4:
		GameFeel.dust(get_parent(), global_position + Vector2(randf_range(-90, 90), -2), 4, Vector2(0, -10), 5.0, Vector2(10, 3))
		treads.scroll += 6.0
		if not await _wait(tele / 4.0, tok):
			return
	if not _player_ok():
		_end_attack(tok)
		return
	_charge_dir = cdir   # la dirección queda fija desde el aviso (justo para el jugador)
	_charge_left = 1.1
	_charge_hit = false
	_pose(cdir * 10.0, cdir.x * 0.1, 0.1)
	_ghost(true)
	state = "charge"


func _charge_step(delta: float) -> void:
	velocity = _charge_dir * CHARGE_SPEED
	move_and_slide()
	treads.scroll += CHARGE_SPEED * delta
	if randf() < 0.4:
		GameFeel.dust(get_parent(), global_position + Vector2(randf_range(-80, 80), 0), 2, -_charge_dir * 60.0, 4.5)
	for v in _victims():
		_victim = v
		if _player_feet().distance_to(global_position + Vector2(0, -10)) < 95.0 and CoopBoss.once(self, "charge%d" % _tok, v):
			_charge_hit = true
			hurt_player(2, global_position, true)
	_victim = null
	_charge_left -= delta
	var hit_wall := false
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is StaticBody2D:
			hit_wall = true
	if hit_wall:
		velocity = Vector2.ZERO
		_shake(9.0, 0.4)
		GameFeel.dust(get_parent(), global_position + _charge_dir * 90.0, 10, Vector2.ZERO, 6.0, Vector2(30, 10))
		_stun(2.5)
		return
	if _charge_left <= 0.0:
		velocity = Vector2.ZERO
		_ghost(false)
		_rest_pose()
		state = "attack"
		_after_charge(_tok)


func _after_charge(tok: int) -> void:
	_tw(skull, "position:y", (_home[skull] as Vector2).y, 0.25)
	skull.eyes_red = true
	if not await _wait(0.5, tok):
		return
	_end_attack(tok)


## 4. Gas contaminante (Ingeniería ambiental). No se bloquea; deja charcos.
func _atk_gas(tok: int) -> void:
	_face("x_x", Color(0.6, 1.0, 0.3))
	skull.open = true
	skull.eyes_red = true
	skull.modulate = Color(0.8, 1.7, 0.7)
	_pose(Vector2(0, -8), 0.0, _tele(0.7))   # toma aire
	if not await _wait(_tele(0.7), tok):
		return
	skull.modulate = Color.WHITE
	_pose(Vector2(0, 6), 0.0, 0.12)
	var g := BossFx.GasCone.new()
	g.dir = _dir_to_player(global_position + MOUTH)
	_add_fx(g, global_position + MOUTH)
	if _player_ok():
		var from := global_position + Vector2(0, 10)
		var d := (_player_feet() - from).normalized()
		for k in 3:
			var pd := BossFx.Puddle.new()
			pd.delay = 0.25 + k * 0.15
			_add_fx(pd, _clamp_arena(from + d * (120.0 + 70.0 * k)))
	if not await _wait(1.5, tok):
		return
	skull.open = false
	_end_attack(tok)


## 5. Raíces del suelo (Biología) + plantas mutantes.
func _atk_roots(tok: int) -> void:
	_face("ROOT", Color(0.5, 1.0, 0.4))
	claw.modulate = Color(1.0, 1.7, 0.8)
	_tw(claw, "rotation", _rot_for(Vector2(-0.3, -1.0)), _tele(0.45))
	_pose(Vector2(6, -16), 0.06, _tele(0.45))   # se levanta para golpear el piso
	if not await _wait(_tele(0.45), tok):
		return
	claw.modulate = Color.WHITE
	_tw(claw, "rotation", 0.0, 0.08)
	claw.fist = true
	_pose(Vector2(-4, 8), -0.04, 0.07)
	var start := global_position + Vector2(-70, 20)
	_impact(start, 6.0)
	GameFeel.dust(get_parent(), start, 8, Vector2.ZERO, 5.0, Vector2(20, 6))
	if _player_ok():
		var base := (_player_feet() - start).normalized()
		var angles := [0.0] if phase < 3 else [-0.28, 0.28]
		for a in angles:
			var dir := base.rotated(a)
			for i in 9:
				var s := BossFx.RootSpike.new()
				s.delay = i * 0.08
				_add_fx(s, _clamp_arena(start + dir * (50.0 + i * 44.0)))
	_spawn_minions(2)
	if not await _wait(1.3, tok):
		return
	claw.fist = false
	_tw(claw, "rotation", REST_L, 0.3)
	_end_attack(tok)


func _spawn_minions(n: int) -> void:
	for i in n:
		if get_tree().get_nodes_in_group("boss_minion").size() >= 3 or not _player_ok():
			return
		var pos := Vector2.ZERO
		for attempt in 12:
			pos = Vector2(randf_range(arena_rect.position.x + 60, arena_rect.end.x - 60),
				randf_range(arena_rect.position.y + 80, arena_rect.end.y - 40))
			if pos.distance_to(player.global_position) > 150.0 and pos.distance_to(global_position) > 130.0:
				break
		var m: CharacterBody2D = MinionScript.new()
		m.set("player", player)
		m.position = pos
		get_parent().add_child(m)


## 6. Cable que agarra (TI). Rodar; si atrapa, jala al jugador y le pega con la garra (parry posible).
func _atk_cable(tok: int) -> void:
	_face("LINK..", Color(0.5, 0.9, 1.0))
	grabber.open = true
	var hand := global_position + SHOULDER_R
	_tw(grabber, "rotation", _rot_for(_dir_to_player(hand)), 0.25)
	_pose(-_dir_to_player(hand) * 10.0, -0.05, 0.25)
	grabber.modulate = Color(1.7, 1.6, 0.6)
	if not await _wait(_tele(0.6), tok):
		return
	grabber.modulate = Color.WHITE
	var aim := _dir_to_player(hand)
	_tw(grabber, "rotation", _rot_for(aim), 0.08)
	var c := BossFx.CableShot.new()
	c.dir = aim
	c.on_done = _on_cable_done.bind(tok)
	_add_fx(c, hand + aim * ARM_LEN)
	grabber.extra = true


func _on_cable_done(hit: bool, tok: int) -> void:
	if tok != _tok:
		return
	grabber.open = false
	grabber.extra = false
	if not hit or not _player_ok():
		_tw(grabber, "rotation", REST_R, 0.3)
		if await _wait(0.4, tok):
			_end_attack(tok)
		return
	_face(">:D", Color(1, 0.3, 0.2))
	_grabbed = true
	player.set_physics_process(false)
	var dest := _clamp_arena(global_position + Vector2(0, 85))
	var tw := create_tween()
	tw.tween_property(player, "global_position", dest, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tweens.append(tw)
	_tw(grabber, "rotation", REST_R, 0.28)
	if not await _wait(0.32, tok):
		return
	_release_player()
	claw.open = true
	claw.modulate = Color(1.8, 1.6, 0.5)
	_tw(claw, "rotation", _rot_for(Vector2(0.5, -1.0)), 0.18)
	if not await _wait(0.22, tok):
		return
	claw.modulate = Color.WHITE
	_tw(claw, "rotation", _rot_for(Vector2(0.4, 1.0)), 0.1)
	claw.open = false
	claw.fist = true
	_pose(Vector2(0, 14), 0.05, 0.07)
	_impact(global_position + Vector2(0, 60), 6.0)
	var origin := global_position + CENTER
	var stun2 := false
	for v in _victims():
		_victim = v
		if _player_body().distance_to(origin) < 170.0:
			_was_parried = false
			_parry_watch = true
			hurt_player(2, origin)
			_parry_watch = false
			stun2 = stun2 or _was_parried
	_victim = null
	if stun2:
		_stun(3.0)
		return
	if not await _wait(0.5, tok):
		return
	claw.fist = false
	_tw(claw, "rotation", REST_L, 0.3)
	_end_attack(tok)


## 7. Estampida (Agropecuarias). Ponerse en el carril vacío o rodar a través.
func _atk_stampede(tok: int) -> void:
	_face("MUUU", Color(1, 0.9, 0.4))
	skull.open = true
	_pose(Vector2(0, -12), 0.0, 0.25)   # ruge
	_shake(6.0, 0.6)
	var lanes := 6
	var top := arena_rect.position.y + 60.0
	var lane_h := (arena_rect.size.y - 90.0) / lanes
	var gap := randi() % lanes
	var from_left := randf() < 0.5
	var x0 := arena_rect.position.x - 40.0 if from_left else arena_rect.end.x + 40.0
	var warn := _tele(1.0)
	for i in lanes:
		if i == gap:
			continue
		var y := top + lane_h * (i + 0.5)
		var w := BossFx.LaneWarning.new()
		w.life = warn
		_add_fx(w, Vector2(arena_rect.position.x + 30.0 if from_left else arena_rect.end.x - 30.0, y))
		var a := BossFx.Animal.new()
		a.kind = randi() % 2
		a.delay = warn + randf() * 0.25
		a.speed = 470.0 if from_left else -470.0
		a.min_x = arena_rect.position.x - 90.0
		a.max_x = arena_rect.end.x + 90.0
		_add_fx(a, Vector2(x0, y))
	if not await _wait(warn * 0.5, tok):
		return
	skull.open = false
	if not await _wait(warn * 0.5 + 2.4, tok):
		return
	_end_attack(tok)


## 8. Láser de escaneo (Software). Rodar a través cuando barre.
func _atk_laser(tok: int) -> void:
	_face("SCAN", Color(1.0, 0.7, 1.0), Color(0.25, 0.05, 0.35))
	var l := BossFx.LaserBeam.new()
	l.telegraph = _tele(0.85)
	l.duration = 1.5
	l.sweep = 1.7
	l.dir_sign = 1.0 if randf() < 0.5 else -1.0
	var total := l.telegraph + l.duration + 0.4
	_add_fx(l, global_position + MONITOR)
	_pose(Vector2(0, -6), 0.0, l.telegraph)
	if not await _wait(total, tok):
		return
	_end_attack(tok)


## 9. Pisotón (si el jugador se queda pegado): salta y suelta una onda de choque. Rodar a través.
func _atk_stomp(tok: int) -> void:
	_face("!!", Color(1, 0.5, 0.3))
	var max_r := 280.0 if phase < 3 else 340.0
	_warn_zone(global_position, Vector2.DOWN, max_r, 0.0, _tele(0.7))
	_pose(Vector2(0, 10), 0.0, _tele(0.3))
	if not await _wait(_tele(0.3), tok):
		return
	_pose(Vector2(0, -48), 0.0, _tele(0.35))
	if not await _wait(_tele(0.4), tok):
		return
	_pose(Vector2(0, 6), 0.0, 0.07)
	if not await _wait(0.07, tok):
		return
	_impact(global_position, 9.0)
	var rings := 1 if phase < 3 else 2
	for i in rings:
		var ring := BossFx.ShockRing.new()
		ring.max_r = max_r
		_add_fx(ring, global_position)
		if not await _wait(0.35, tok):
			return
	if not await _wait(0.4, tok):
		return
	_end_attack(tok)


# --- Aparición y muerte -----------------------------------------------------------


# --- SEGMENTATION FAULT (duelo final) ---------------------------------------------------
## A un golpe de caer: se arranca los brazos y los lanza girando. Parry = el brazo vuelve y se le
## clava en el pecho; el brazo le vuelve a crecer y lo lanza otra vez, más rápido. El 6.º va al cráneo.
## Fallo: EXCEPCIÓN NO CONTROLADA, vuelve la fase 3 y el próximo golpe repite el duelo.
func _start_final() -> void:
	_interrupt()
	var tok := _tok
	state = "final"
	tank_open = false
	tank.open = false
	_final_hits = 0
	_final_fail = false
	_thrown = 0
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.call("die")
	# si tiene brazos rotos, le crecen de golpe para el duelo
	for arm in broken_arms.duplicate():
		_regrow(arm)
	Final.title(self, "SEGMENTATION FAULT", Color(1.0, 0.35, 0.25), "Parry a sus brazos para clavárselos")
	Final.music_cue(self, "final1")
	_face("SIGSEGV", Color(1, 0.3, 0.2), Color(0.15, 0, 0))
	var spot := Vector2(0.0, arena_rect.position.y + 320.0)
	_tw(self, "global_position", spot, 0.7)
	_pose(Vector2(0, -12), 0.0, 0.3)
	_shake(6.0, 0.5)
	if not await _wait(1.4, tok):
		return
	var arm := "claw"
	while _final_hits < FINAL_THROWS and not _final_fail:
		if not await _throw_arm(arm, tok):
			return
		# espera a que ese brazo se resuelva (clavado o fallo)
		var w := 0.0
		while not _final_fail and _final_hits < _thrown and w < 4.0:
			if not await _wait(0.05, tok):
				return
			w += 0.05
		arm = "grabber" if arm == "claw" else "claw"
	if _final_fail:
		_final_lost(tok)
	else:
		_final_won()


## ANTICIPACIÓN: tira del brazo hacia atrás, el hombro echa chispas y lo arranca; sale girando.
func _throw_arm(arm: String, tok: int) -> bool:
	var part: Part = claw if arm == "claw" else grabber
	var sh: Vector2 = SHOULDER_L if arm == "claw" else SHOULDER_R
	var side := -1.0 if arm == "claw" else 1.0
	var aim := _dir_to_player(global_position + sh)
	var wind := clampf(0.5 - 0.05 * _final_hits, 0.25, 0.5)
	part.modulate = Color(1.8, 1.4, 0.6)
	_tw(part, "rotation", _rot_for(aim.rotated(-side * 1.9)), wind)
	_pose(Vector2(-side * 10.0, -6), side * 0.08, wind)
	for k in 3:
		GameFeel.dust(get_parent(), global_position + rig_off + sh, 2, Vector2(0, -40), 3.0, Vector2(6, 6))
	if not await _wait(wind, tok):
		return false
	# ¡lo arranca!
	part.modulate = Color.WHITE
	part.visible = false
	_pose(Vector2(side * 14.0, 4), -side * 0.1, 0.07)
	GameFeel.parry_burst(get_parent(), global_position + rig_off + sh, 30.0)
	_shake(4.0, 0.15)
	var shot := ArmShot.new()
	shot.arm = arm
	shot.col = Color(1.0, 0.45, 0.3)
	shot.strict = 0.2 if _final_hits < 3 else 0.17
	shot.damage = 2
	shot.target = TANK_POS + Vector2(0, -56) if _final_hits < FINAL_THROWS - 1 else SKULL_POS
	shot.size = 26.0
	_add_fx(shot, global_position + rig_off + sh)
	var speed := 380.0 + 50.0 * _final_hits
	shot.aim_at(_player_body() if _player_ok() else global_position + Vector2.DOWN * 200.0, speed)
	_thrown += 1
	return true


func final_result(ok: bool, _shot: Node) -> void:
	if state != "final":
		return
	if not ok:
		_final_fail = true
		return
	GameFeel.hit_stop(get_tree(), 0.05)
	_face("%d/%d" % [_final_hits + 1, FINAL_THROWS], Color(0.6, 1, 0.6), Color(0, 0.12, 0))


## El brazo devuelto se le clava: en el pecho (y le vuelve a crecer) o, el último, en el cráneo.
func final_back(shot: Node2D) -> void:
	var arm: String = shot.get("arm")
	_final_hits += 1
	var at := shot.global_position
	shot.queue_free()
	GameFeel.parry_burst(get_parent(), at, 36.0 + 4.0 * _final_hits)
	GameFeel.flash(rig, 0.12, Color(1, 0.6, 0.4))
	_kick = Vector2(0, -10)
	_shake(4.0 + _final_hits, 0.2)
	if _final_hits == 2:
		Final.music_cue(self, "final2")
	elif _final_hits == 4:
		Final.music_cue(self, "final3")
	if _final_hits < FINAL_THROWS:
		_regrow(arm)


func _final_won() -> void:
	# clímax con QTE antes del remate; si se falla, vuelve la fase 3 como al perder el duelo
	if not await _climax():
		_final_lost(_tok)
		return
	final_victory = true
	Final.music_final(self, "epic")
	await _finisher()
	_shake(12.0, 0.8)
	hp = 0
	hp_changed.emit(hp, MAX_HP)
	_die()


func _final_lost(tok: int) -> void:
	for h in get_tree().get_nodes_in_group("final_shot"):
		h.queue_free()
	for arm in ["claw", "grabber"]:
		var part: Part = claw if arm == "claw" else grabber
		if not part.visible and not (arm in broken_arms):
			_regrow(arm)
	Final.title(self, "EXCEPCIÓN NO CONTROLADA", Color(1.0, 0.35, 0.3), "", 1.1)
	Final.music_cue(self, "p3")
	_face(_base_face()[0], _base_face()[1], _base_face()[2])
	_rest_pose()
	if not await _wait(1.0, tok):
		return
	state = "idle"
	_cd = 1.0



# --- Lluvia de cambio de fase propia: COSECHA DE DATOS ------------------------------------
## Cajas y fruta por toda la arena, filas de raíces desde el boss, estampida y (F3) el láser de escaneo.
func barrage_title(_n: int) -> String:
	return "COSECHA DE DATOS"


func barrage_plan(n: int) -> Array:
	if n == 2:
		return [[0.2, "roots", {"lines": 4}], [1.5, "crates", {"n": 8}], [2.9, "stampede", {}],
			[5.4, "crates", {"n": 10}], [6.2, "roots", {"lines": 3}]]
	return [[0.2, "roots", {"lines": 6}], [1.3, "crates", {"n": 10}], [2.6, "laser", {}],
		[3.4, "stampede", {}], [6.0, "crates", {"n": 12}], [6.6, "roots", {"lines": 5}], [8.0, "crates", {"n": 8}]]


func _bfx(n: Node2D, at: Vector2) -> void:
	_add_fx(n, at)
	Barrage.tag(n)


func _bar_crates(a: Dictionary, _tok: int) -> void:
	grabber.open = true
	_pose(Vector2(0, -10), -0.04, 0.1)
	for i in int(a["n"]):
		var c := BossFx.FallingCrate.new()
		c.kind = randi() % 4
		c.delay = i * 0.1
		var target := _player_feet() if (_player_ok() and i % 3 == 0) else Vector2(randf_range(arena_rect.position.x + 60, arena_rect.end.x - 60), randf_range(arena_rect.position.y + 100, arena_rect.end.y - 40))
		_bfx(c, _clamp_arena(target))


func _bar_roots(a: Dictionary, _tok: int) -> void:
	claw.fist = true
	_impact(global_position + Vector2(0, 20), 6.0)
	var base := _dir_to_player(global_position) if _player_ok() else Vector2.DOWN
	var n: int = a["lines"]
	for l in n:
		var dir := base.rotated(TAU * l / n + 0.2)
		for i in 10:
			var s := BossFx.RootSpike.new()
			s.delay = i * 0.07
			_bfx(s, _clamp_arena(global_position + Vector2(0, 20) + dir * (60.0 + i * 48.0)))


func _bar_stampede(_a: Dictionary, _tok: int) -> void:
	skull.open = true
	var lanes := 6
	var top := arena_rect.position.y + 60.0
	var lane_h := (arena_rect.size.y - 90.0) / lanes
	var gap := randi() % lanes
	for i in lanes:
		if i == gap:
			continue
		var from_left := i % 2 == 0
		var y := top + lane_h * (i + 0.5)
		var w := BossFx.LaneWarning.new()
		w.life = 0.9
		_bfx(w, Vector2(arena_rect.position.x + 30.0 if from_left else arena_rect.end.x - 30.0, y))
		var an := BossFx.Animal.new()
		an.kind = randi() % 2
		an.delay = 0.9 + randf() * 0.2
		an.speed = 520.0 if from_left else -520.0
		an.min_x = arena_rect.position.x - 90.0
		an.max_x = arena_rect.end.x + 90.0
		_bfx(an, Vector2(arena_rect.position.x - 40.0 if from_left else arena_rect.end.x + 40.0, y))


func _bar_laser(_a: Dictionary, _tok: int) -> void:
	var l := BossFx.LaserBeam.new()
	l.telegraph = 0.8
	l.duration = 1.6
	l.sweep = 2.4
	l.dir_sign = 1.0 if randf() < 0.5 else -1.0
	_bfx(l, global_position + MONITOR)


## REMATE: el sexto brazo se le clava en el cráneo: se agrieta y vomita su memoria en hexadecimal.
func _finisher() -> void:
	skull.open = true
	_face("0xDEAD", Color(1, 0.3, 0.2), Color(0.15, 0, 0))
	var hd := Final.HexDump.new()
	get_parent().add_child(hd)
	hd.global_position = global_position + SKULL_POS + Vector2(0, -40)
	for i in 6:
		GameFeel.parry_burst(get_parent(), global_position + SKULL_POS + Vector2(randf_range(-30, 30), randf_range(-20, 20)), 26.0)
		_kick = Vector2(randf_range(-6, 6), -8)
		GameFeel.flash(rig, 0.06, Color(1, 0.4, 0.3))
		_shake(3.0 + i, 0.12)
		await get_tree().create_timer(0.18).timeout
	Final.title(self, "CORE DUMPED", Color(1.0, 0.45, 0.3), "", 1.2)
	await get_tree().create_timer(0.4).timeout


## skip = reintento: se arma al instante.
func start_intro(skip: bool) -> void:
	state = "intro"
	if skip:
		skull.eyes_red = true
		await get_tree().create_timer(0.6).timeout
		intro_finished.emit()
		return
	for p in _parts():
		p.visible = false
	var spr := chassis.sprites
	_face("", Color.BLACK, Color(0.02, 0.02, 0.02))
	await get_tree().create_timer(0.6).timeout
	_shake(3.0, 0.6)
	# orugas (con sprites van dentro del chasis)
	treads.visible = not spr
	treads.position.y = 140.0
	treads.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(treads, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(treads, "modulate:a", 1.0, 0.4)
	tw.tween_property(treads, "scroll", 120.0, 0.6)
	await get_tree().create_timer(0.7).timeout
	# chasis cae
	chassis.visible = true
	await _drop(chassis, -320.0, 0.32)
	_shake(6.0, 0.3)
	GameFeel.dust(get_parent(), global_position, 10, Vector2.ZERO, 6.0, Vector2(80, 6))
	# tanque baja y se llena
	tank.visible = true
	tank.fill = 0.0
	await _drop(tank, -180.0, 0.3)
	create_tween().tween_property(tank, "fill", 1.0, 0.6)
	await get_tree().create_timer(0.5).timeout
	# brazos se enganchan
	claw.visible = true
	grabber.visible = true
	claw.position.x -= 240.0
	grabber.position.x += 240.0
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(claw, "position", _home[claw], 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(grabber, "position", _home[grabber], 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.3).timeout
	GameFeel.parry_burst(get_parent(), global_position + SHOULDER_L, 26.0)
	GameFeel.parry_burst(get_parent(), global_position + SHOULDER_R, 26.0)
	await get_tree().create_timer(0.3).timeout
	# cráneo y monitor
	skull.visible = true
	await _drop(skull, -280.0, 0.3)
	_shake(4.0, 0.2)
	monitor.visible = true
	if not spr:
		await _drop(monitor, -220.0, 0.25)
	await get_tree().create_timer(0.3).timeout
	_face("BOOT", Color(0.6, 0.6, 0.6), Color(0.02, 0.02, 0.02))
	await get_tree().create_timer(0.5).timeout
	_face("0xDEAD", Color(1, 0.3, 0.2), Color(0.02, 0.02, 0.02))
	await get_tree().create_timer(0.45).timeout
	# ruge
	_face(_base_face()[0], _base_face()[1], _base_face()[2])
	# firma: abre el cráneo y vomita bytes hexadecimales mientras chasquea las pinzas
	skull.eyes_red = true
	skull.open = true
	var by := Roar.Bytes.new()
	Roar.spawn(get_parent(), by, skull.global_position + Vector2(0, 26))
	_shake(8.0, 0.9)
	for i in 4:
		_tw(claw, "rotation", REST_L + (0.5 if i % 2 == 0 else -0.2), 0.08)
		_tw(grabber, "rotation", REST_R + (-0.5 if i % 2 == 0 else 0.2), 0.08)
		GameFeel.dust(get_parent(), global_position + Vector2(randf_range(-60, 60), 6), 2, Vector2(0, 20), 4.0, Vector2(30, 4))
		await get_tree().create_timer(0.16).timeout
	_tw(claw, "rotation", REST_L, 0.2)
	_tw(grabber, "rotation", REST_R, 0.2)
	await get_tree().create_timer(0.5).timeout
	skull.open = false
	intro_finished.emit()


## Destello de pantalla completa (por encima de todo).
func _screen_flash(col: Color, time: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	get_parent().add_child(layer)
	var r := ColorRect.new()
	r.color = col
	r.size = Vector2(4000, 4000)
	r.position = Vector2(-1000, -1000)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	var tw := r.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(r, "color:a", 0.0, time)
	tw.tween_callback(layer.queue_free)


func _drop(p: Part, from_y: float, time: float) -> void:
	var home: Vector2 = _home[p]
	p.position = home + Vector2(0, from_y)
	var tw := create_tween()
	tw.tween_property(p, "position", home, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


func begin_fight() -> void:
	state = "idle"
	_cd = 1.0


## Detiene la IA (el jugador perdió).
func pause_ai() -> void:
	_interrupt()
	state = "paused"


func _die() -> void:
	_interrupt()
	state = "dead"
	tank_open = false
	tank.open = false
	remove_from_group("enemies")
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.call("die")
	# cámara lenta en el golpe final
	Engine.time_scale = 0.2
	_screen_flash(Color(1, 1, 1, 0.7), 0.5)
	await get_tree().create_timer(0.9, true, false, true).timeout
	Engine.time_scale = 1.0
	_face("FATAL", Color(1, 0.3, 0.3), Color(0.15, 0, 0))
	skull.eyes_red = false
	_pose(Vector2(0, 6), 0.0, 0.3)
	await get_tree().create_timer(0.5).timeout
	# explosiones en cadena, cada vez más seguidas
	for i in 12:
		var at := global_position + Vector2(randf_range(-90, 90), randf_range(-230, -20))
		GameFeel.parry_burst(get_parent(), at, randf_range(28.0, 46.0))
		GameFeel.dust(get_parent(), at, 4, Vector2(0, -40), 6.0, Vector2(12, 8))
		GameFeel.flash(rig, 0.08, Color(1, 0.5, 0.3))
		rig_off = Vector2(randf_range(-5, 5), randf_range(-3, 3))
		_shake(3.0 + i * 0.5, 0.12)
		await get_tree().create_timer(maxf(0.06, 0.2 - i * 0.013)).timeout
	rig_off = Vector2.ZERO
	_screen_flash(Color(1, 1, 1, 0.9), 0.6)
	GameFeel.parry_burst(get_parent(), global_position + CENTER, 90.0)
	tank.broken = true
	chassis.broken = true
	_face("", Color.BLACK, Color(0.02, 0.02, 0.02))
	if monitor.sprites:
		monitor.visible = false
	for i in 14:
		var d := BossFx.Debris.new()
		d.kind = i % 6
		d.vel = Vector2(randf_range(-260, 260), randf_range(-420, -200))
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(randf_range(-60, 60), randf_range(-180, -60))
	# las piezas salen volando; el cráneo cae y rueda al piso
	var sk := create_tween()
	sk.tween_property(skull, "position", Vector2(-50, -30), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sk.parallel().tween_property(skull, "rotation", -1.6, 0.55)
	sk.tween_property(skull, "position", Vector2(-90, -40), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sk.tween_property(skull, "position", Vector2(-110, -28), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sk.parallel().tween_property(skull, "rotation", -2.0, 0.4)
	for p in [claw, grabber, monitor]:
		var tw := create_tween().set_parallel(true)
		var off := Vector2(randf_range(-180, 180), randf_range(60, 160))
		tw.tween_property(p, "position", p.position + off, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", randf_range(-3.0, 3.0), 0.7)
		tw.chain().tween_property(p, "modulate:a", 0.0, 0.9)
	_shake(10.0, 0.5)
	GameFeel.dust(get_parent(), global_position, 14, Vector2.ZERO, 7.0, Vector2(90, 10))
	# el líquido del tanque limpia la arena
	for i in 26:
		var b := BossFx.Bloom.new()
		b.delay = 0.2 + randf() * 1.3
		b.size = randf_range(18.0, 34.0)
		b.flower = randf() < 0.5
		get_parent().add_child(b)
		b.global_position = Vector2(randf_range(arena_rect.position.x + 30, arena_rect.end.x - 30),
			randf_range(arena_rect.position.y + 40, arena_rect.end.y - 20))
	await get_tree().create_timer(1.2).timeout
	create_tween().tween_property(rig, "modulate", Color(0.35, 0.35, 0.35, 0.0), 1.2)
	await get_tree().create_timer(1.0).timeout
	defeated.emit()


# --- Dibujo de las piezas (provisional, hasta tener los sprites) ----------------------

class Part extends Node2D:
	var kind: String = ""
	var open: bool = false       # garra/pinza abierta, tanque abierto, boca abierta
	var extra: bool = false      # jeringa fuera
	var eyes_red: bool = false
	var broken: bool = false
	var fill: float = 1.0
	var scroll: float = 0.0
	var face: String = ""
	var face_color: Color = Color(0.45, 1.0, 0.5)
	var screen: Color = Color(0.04, 0.1, 0.05)
	var t: float = 0.0
	## true = usa los sprites de grokbot (assets/sprites/bosses/deadbeef) en vez de las figuras.
	var sprites: bool = false
	var anim_off: Vector2 = Vector2.ZERO   # movimiento secundario (no toca position, que usan los tweens)
	var anim_rot: float = 0.0
	var fist: bool = false                 # garra cerrada (al golpear)
	var glitch: float = 0.0                # monitor: probabilidad de interferencia por cuadro
	var _bubbles: Array = []

	const OUT := Color(0.05, 0.05, 0.06)
	const TAN := Color(0.79, 0.7, 0.52)
	const TAN_D := Color(0.6, 0.5, 0.35)
	const METAL := Color(0.45, 0.47, 0.52)
	const METAL_D := Color(0.28, 0.29, 0.33)
	const BONE := Color(0.93, 0.88, 0.76)
	const VINE := Color(0.22, 0.48, 0.18)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(anim_off, anim_rot, Vector2.ONE)
		if sprites:
			_draw_sprite()
			return
		match kind:
			"treads":
				_treads()
			"chassis":
				_chassis()
			"tank":
				_tank()
			"skull":
				_skull()
			"monitor":
				_monitor()
			"claw":
				_claw()
			"grabber":
				_grabber()

	func _draw_sprite() -> void:
		var n := ""
		match kind:
			"chassis":
				n = "body_1" if broken else "body_0"
				var tb := Spr.tex("boss_0xdeadbeef_" + n)
				draw_texture(tb, Vector2(-tb.get_width() * 0.5, -tb.get_height()))
				# torso (hombreras, tubos, rack y cables) sacado del sprite completo
				var tt := Spr.tex("boss_0xdeadbeef_torso_1" if broken else "boss_0xdeadbeef_torso_0")
				if tt:
					draw_texture(tt, TORSO_POS)
			"tank":
				n = "tank_2" if broken else ("tank_1" if open else "tank_0")
				var tt := Spr.tex("boss_0xdeadbeef_" + n)
				draw_texture(tt, Vector2(-43, -112), Color(1, 1, 1, clampf(0.3 + fill, 0.0, 1.0)))
				if not broken:
					_draw_bubbles()
				if open and not broken:
					draw_rect(Rect2(-47, -116, 94, 120).grow(2.0 * sin(t * 12.0)), Color(1, 1, 0.5, 0.9), false, 2.0)
			"skull":
				n = "head_2" if open else ("head_1" if eyes_red else "head_0")
				var th := Spr.tex("boss_0xdeadbeef_" + n)
				draw_texture(th, Vector2(71 - th.get_width(), -110))
			"monitor":
				# solo la pantalla: el marco viene en el sprite de la cabeza
				draw_colored_polygon(PackedVector2Array([Vector2(-12, -12), Vector2(13, -14), Vector2(13, 12), Vector2(-12, 12)]), screen)
				if face != "":
					var fs := 10 if face.length() <= 3 else 7
					draw_string(ThemeDB.fallback_font, Vector2(-13, 1 + fs * 0.35), face, HORIZONTAL_ALIGNMENT_CENTER, 27, fs, face_color)
				var sy := -12.0 + fmod(t * 20.0, 24.0)
				draw_line(Vector2(-12, sy), Vector2(13, sy), Color(1, 1, 1, 0.08), 2.0)
				if glitch > 0.0 and randf() < glitch:
					# interferencia: franjas corridas de colores
					for i in 3:
						var gy := randf_range(-12.0, 10.0)
						var gc: Color = [Color(1, 0.2, 0.3, 0.7), Color(0.3, 1, 0.9, 0.7), Color(1, 1, 1, 0.6)][i]
						draw_rect(Rect2(-12 + randf_range(-3.0, 3.0), gy, 25, randf_range(1.0, 3.0)), gc)
			"claw":
				n = "boss_0xdeadbeef_" + ("claw_0" if open else ("claw_2" if fist else "claw_1"))
				draw_texture(Spr.tex(n), -Spr.top_pivot(n))
			"grabber":
				n = "boss_0xdeadbeef_" + ("grabber_2" if extra else ("grabber_0" if open else "grabber_1"))
				draw_texture(Spr.tex(n), -Spr.top_pivot(n))

	## Burbujas que suben dentro del vidrio del tanque (vidrio en x -27..23, y -91..-32).
	func _draw_bubbles() -> void:
		if _bubbles.size() < 9 and randf() < 0.25:
			_bubbles.append([randf_range(-24.0, 20.0), -34.0, randf_range(1.0, 2.6), randf_range(18.0, 40.0)])
		var dt := get_process_delta_time()
		for b in _bubbles:
			b[1] -= b[3] * dt * (2.5 if open else 1.0)
			b[0] += sin(t * 4.0 + b[3]) * 0.15
		_bubbles = _bubbles.filter(func(b): return b[1] > -88.0)
		for b in _bubbles:
			var a := clampf((b[1] + 88.0) / 20.0, 0.0, 1.0)
			draw_circle(Vector2(b[0], b[1]), b[2], Color(0.75, 1.0, 0.75, 0.75 * a))
			draw_circle(Vector2(b[0] - b[2] * 0.35, b[1] - b[2] * 0.35), maxf(0.6, b[2] * 0.35), Color(1, 1, 1, 0.8 * a))

	func _box(r: Rect2, col: Color, w: float = 2.0) -> void:
		draw_rect(r, col)
		draw_rect(r, OUT, false, w)

	func _treads() -> void:
		_box(Rect2(-98, -38, 196, 38), Color(0.2, 0.2, 0.23), 3.0)
		var off := fmod(scroll, 14.0)
		var x := -96.0 + off
		while x < 96.0:
			draw_line(Vector2(x, -36), Vector2(x, -2), Color(0.38, 0.38, 0.42), 3.0)
			x += 14.0
		for wx in [-72, -36, 0, 36, 72]:
			draw_circle(Vector2(wx, -19), 11, METAL_D)
			draw_circle(Vector2(wx, -19), 5, METAL)
			draw_arc(Vector2(wx, -19), 11, 0, TAU, 16, OUT, 2.0)

	func _chassis() -> void:
		_box(Rect2(-82, -154, 164, 120), TAN, 3.0)
		_box(Rect2(-82, -146, 22, 104), METAL_D)
		_box(Rect2(60, -146, 22, 104), METAL_D)
		for i in 7:
			var on := fmod(t * 2.0 + i * 0.37, 1.0) > 0.25
			var col := Color(0.3, 1.0, 0.4) if on else Color(0.1, 0.3, 0.12)
			if broken and i % 2 == 0:
				col = Color(0.9, 0.15, 0.1) if on else Color(0.2, 0.05, 0.05)
			draw_rect(Rect2(65, -138 + i * 13, 12, 5), col)
		_box(Rect2(-40, -144, 80, 104), Color(0.12, 0.12, 0.14))   # hueco del tanque
		_box(Rect2(-82, -42, 164, 10), TAN_D)
		for sx in [-86, 86]:
			draw_circle(Vector2(sx, -128), 15, METAL_D)
			draw_arc(Vector2(sx, -128), 15, 0, TAU, 16, OUT, 2.0)
		if broken:
			draw_colored_polygon(PackedVector2Array([Vector2(-58, -150), Vector2(-44, -128), Vector2(-56, -110), Vector2(-60, -132)]), Color(0.1, 0.08, 0.06, 0.8))
			draw_colored_polygon(PackedVector2Array([Vector2(44, -70), Vector2(58, -60), Vector2(50, -40), Vector2(42, -52)]), Color(0.1, 0.08, 0.06, 0.8))
			draw_line(Vector2(-20, -154), Vector2(-8, -140), OUT, 2.0)

	func _tank() -> void:
		var r := Rect2(-32, -46, 64, 92)
		draw_rect(r, Color(0.55, 0.85, 0.8, 0.35))
		if broken:
			draw_rect(Rect2(-30, 34, 60, 10), Color(0.2, 0.5, 0.2))
			for l in [[Vector2(-20, -40), Vector2(0, -5), Vector2(-12, 20)], [Vector2(18, -44), Vector2(6, -10), Vector2(24, 12)]]:
				draw_polyline(PackedVector2Array(l), Color(0.9, 1, 1), 2.0)
		else:
			var h := 86.0 * fill
			var col := Color(0.82, 1.0, 0.3) if open else Color(0.35, 1.0, 0.42)
			if open:
				col = col.lerp(Color(1, 1, 0.8), 0.35 * absf(sin(t * 10.0)))
			draw_rect(Rect2(-29, 43 - h, 58, h), col)
			for i in 5:
				var by := fmod(t * 30.0 + i * 19.0, maxf(h, 1.0))
				draw_circle(Vector2(-18 + i * 9, 40 - by), 2.5 + (i % 2), Color(0.85, 1, 0.85, 0.8))
			draw_line(Vector2(-22, -40), Vector2(-22, 30), Color(1, 1, 1, 0.45), 3.0)
		draw_rect(r, OUT, false, 3.0)
		if open and not broken:
			# panel frontal bajado: punto débil expuesto
			_box(Rect2(-34, 46, 68, 10), METAL)
			draw_rect(r.grow(4.0 + 2.0 * sin(t * 12.0)), Color(1, 1, 0.5, 0.9), false, 2.0)

	func _skull() -> void:
		# cables y raíces de "pelo" (detrás)
		for s in [-1.0, 1.0]:
			draw_polyline(PackedVector2Array([Vector2(16 * s, -20), Vector2(40 * s, -6), Vector2(52 * s, 22), Vector2(58 * s, 44)]), OUT, 6.0)
			draw_polyline(PackedVector2Array([Vector2(10 * s, -22), Vector2(30 * s, -2), Vector2(36 * s, 30)]), VINE, 4.0)
		# cuernos
		for s in [-1.0, 1.0]:
			var horn := PackedVector2Array([Vector2(20 * s, -14), Vector2(42 * s, -22), Vector2(60 * s, -36), Vector2(64 * s, -58)])
			draw_polyline(horn, OUT, 12.0)
			draw_polyline(horn, BONE, 8.0)
			draw_circle(Vector2(64 * s, -58), 4, Color(0.55, 0.5, 0.42))
		var jaw_y := 10.0 if open else 0.0
		if open:
			draw_rect(Rect2(-12, 22, 24, 12), Color(0.15, 0.02, 0.02))
		var jaw := PackedVector2Array([Vector2(-12, 22 + jaw_y), Vector2(12, 22 + jaw_y), Vector2(9, 32 + jaw_y), Vector2(-9, 32 + jaw_y)])
		draw_colored_polygon(jaw, BONE)
		draw_polyline(PackedVector2Array([jaw[0], jaw[1], jaw[2], jaw[3], jaw[0]]), OUT, 2.0)
		var head := PackedVector2Array([Vector2(-26, -22), Vector2(26, -22), Vector2(30, -6), Vector2(20, 12), Vector2(12, 26), Vector2(-12, 26), Vector2(-20, 12), Vector2(-30, -6)])
		draw_colored_polygon(head, BONE)
		draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[3], head[4], head[5], head[6], head[7], head[0]]), OUT, 3.0)
		for ex in [-12, 12]:
			draw_circle(Vector2(ex, -4), 7, OUT)
			if eyes_red:
				draw_circle(Vector2(ex, -4), 5, Color(1, 0.15, 0.1))
				draw_circle(Vector2(ex, -5), 2, Color(1, 0.8, 0.7))
		draw_circle(Vector2(-4, 15), 2.5, OUT)
		draw_circle(Vector2(4, 15), 2.5, OUT)

	func _monitor() -> void:
		_box(Rect2(-30, -24, 60, 44), METAL_D, 3.0)
		draw_rect(Rect2(-25, -19, 50, 33), screen)
		draw_rect(Rect2(-6, 20, 12, 7), METAL_D)
		if face != "":
			var fs := 13 if face.length() <= 4 else 10
			draw_string(ThemeDB.fallback_font, Vector2(-25, 2 + fs * 0.35), face, HORIZONTAL_ALIGNMENT_CENTER, 50, fs, face_color)
		# línea de barrido de pantalla vieja
		var sy := -19.0 + fmod(t * 25.0, 33.0)
		draw_line(Vector2(-25, sy), Vector2(25, sy), Color(1, 1, 1, 0.08), 2.0)

	func _claw() -> void:
		draw_circle(Vector2.ZERO, 13, METAL_D)
		_box(Rect2(-10, 0, 20, 64), TAN_D)
		draw_polyline(PackedVector2Array([Vector2(-10, 6), Vector2(8, 18), Vector2(-9, 32), Vector2(9, 46), Vector2(-8, 60)]), VINE, 4.0)
		draw_circle(Vector2(-6, 30), 4, Color(0.35, 0.7, 0.3))
		draw_circle(Vector2(0, 68), 10, METAL)
		draw_arc(Vector2(0, 68), 10, 0, TAU, 16, OUT, 2.0)
		var spread := 0.65 if open else 0.18
		for a in [-spread, 0.0, spread]:
			draw_set_transform(Vector2(0, 72), a, Vector2.ONE)
			var f := PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(4, 22), Vector2(0, 34), Vector2(-4, 22)])
			draw_colored_polygon(f, METAL)
			draw_polyline(PackedVector2Array([f[0], f[1], f[2], f[3], f[4], f[0]]), OUT, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, 13, 0, TAU, 16, OUT, 2.0)

	func _grabber() -> void:
		draw_circle(Vector2.ZERO, 13, METAL_D)
		_box(Rect2(-9, 0, 18, 58), METAL)
		draw_line(Vector2(0, 6), Vector2(0, 52), METAL_D, 3.0)
		_box(Rect2(-5, 56, 10, 12), METAL_D)
		var sp := 12.0 if open else 4.0
		for s in [-1.0, 1.0]:
			var pr := PackedVector2Array([Vector2(0, 66), Vector2(sp * s + 8 * s, 74), Vector2(sp * s + 6 * s, 96), Vector2(sp * s, 92), Vector2(sp * s + 2 * s, 78)])
			draw_colored_polygon(pr, METAL)
			draw_polyline(PackedVector2Array([pr[0], pr[1], pr[2], pr[3], pr[4], pr[0]]), OUT, 2.0)
		_box(Rect2(-3, 70, 6, 18), Color(0.6, 0.85, 1.0))
		if extra:
			draw_line(Vector2(0, 88), Vector2(0, 104), Color(0.85, 0.85, 0.9), 2.0)
		draw_arc(Vector2.ZERO, 13, 0, TAU, 16, OUT, 2.0)


## Cartel grande sobre la cabeza con el texto de la pantalla (la pantalla real es muy pequeña).
class Holo extends Node2D:
	var text := ""
	var col := Color.WHITE
	var t := 9.0

	func show_text(s: String, c: Color) -> void:
		text = s
		col = c
		t = 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if t > 1.1 or text == "":
			return
		var a := clampf((1.1 - t) / 0.25, 0.0, 1.0)
		var pop := 1.0 + 0.3 * maxf(0.0, 0.1 - t) / 0.1
		var f := ThemeDB.fallback_font
		var fs := 18
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
		var box := Rect2(-w * 0.5 - 8, -18, w + 16, 26)
		draw_rect(box, Color(0.02, 0.04, 0.03, 0.85 * a))
		draw_rect(box, Color(col.r, col.g, col.b, a), false, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 8), Vector2(6, 8), Vector2(0, 15)]), Color(col.r, col.g, col.b, a))
		draw_string(f, Vector2(-w * 0.5, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, a))


## Brazo arrancado que vuela girando (duelo final). Con parry vuelve y se clava en el boss.
class ArmShot extends Final.Shot:
	var arm := "claw"

	func _draw() -> void:
		var n := "boss_0xdeadbeef_%s_1" % arm
		var tx := Spr.tex(n)
		var spin := t * (14.0 if not back else -18.0)
		draw_circle(Vector2.ZERO, 34.0, Color(0.5, 1.0, 0.6, 0.15) if back else Color(1, 0.4, 0.3, 0.12))
		if strict > 0.0 and not back:
			draw_arc(Vector2.ZERO, 40.0, 0, TAU, 28, Color(1, 1, 1, 0.5 + 0.5 * absf(sin(t * 18.0))), 2.0)
		if tx:
			var c := tx.get_size() * 0.5
			draw_set_transform(Vector2.ZERO, spin, Vector2(0.7, 0.7))
			draw_texture(tx, -c)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
			draw_rect(Rect2(-8, -40, 16, 80), Color(0.5, 0.55, 0.6))
			draw_rect(Rect2(-18, 30, 36, 16), Color(0.8, 0.3, 0.2))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


func _gpos(part: Node2D) -> Vector2:
	return part.global_position if part and is_instance_valid(part) else global_position + CENTER


## VOLCADO DE MEMORIA: el último brazo quedó clavado en el cráneo. Machaca para hundirlo y
## haz parry a la mordida final del cráneo.
func _climax() -> bool:
	_climax_clear()
	var p := get_parent()
	var steps := [
		{"mode": "mash", "action": "action_primary", "title": "¡CLÁVALO HASTA EL FONDO!", "sub": "Machaca para hundir el brazo en el cráneo",
			"limit": 3.4, "gain": 0.075, "col": _accent(),
			"before": func() -> void:
				_face("SIGSEGV", Color(1, 0.3, 0.2), Color(0.15, 0, 0))
				Epic.charge(p, _gpos(skull), Color(1, 0.3, 0.2), 0.5, 140.0)
				await get_tree().create_timer(0.35).timeout,
			"pressed": func() -> void:
				var at := _gpos(skull)
				Epic.burst(p, at, Color(1, 0.4, 0.25), 8, 260.0, 0.5, 0.4)
				Epic.word(p, at + Vector2(randf_range(-70, 70), -40), "0x%X" % randi_range(0x1000, 0xFFFF), Color(0.4, 1.0, 0.4), 20, 0.5)
				_shake(2.5, 0.08),
			"ok": func() -> void:
				var at := _gpos(skull)
				Epic.shards(p, at, Color(0.85, 0.8, 0.7), 14, 420.0, 8.0)
				Epic.flash(p, Color(1, 0.3, 0.2), 0.3, 0.35)
				Epic.word(p, at + Vector2(0, -70), "¡CRACK!", Color(1, 0.9, 0.3), 46)},
		{"mode": "timing", "action": "parry", "title": "¡PARRY!", "sub": "El cráneo se lanza a morderte", "dur": 1.1, "col": Color(1, 0.4, 0.3),
			"before": func() -> void:
				_tw(skull, "position", skull.position + Vector2(0, 70), 0.5)
				Epic.charge(p, _gpos(skull), Color(1, 0.2, 0.15), 0.45, 100.0, skull),
			"ok": func() -> void:
				Epic.anim(p, "deadbeef", "fxcore", _gpos(skull), 1.4)
				GameFeel.parry_burst(p, _gpos(skull), 60.0)
				Epic.ring(p, _gpos(skull), Color.WHITE, 260.0, 0.45, 10.0)
				Epic.word(p, _gpos(skull) + Vector2(0, -60), "¡BLOQUEADO!", Color(0.6, 1.0, 0.6), 36)
				_tw(skull, "position", _home[skull], 0.3)
				await get_tree().create_timer(0.3).timeout,
			"fail": func() -> void:
				_climax_hurt(2, _gpos(skull))
				_tw(skull, "position", _home[skull], 0.3)},
	]
	return await Epic.climax(self, steps)
