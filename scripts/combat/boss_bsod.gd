extends CharacterBody2D
## Boss 2 B.S.O.D. (Facultad de Ciencias de la Salud): robot cirujano.
## Lo único: TODO va al ritmo de su corazón. Ataca en el latido; el corazón (punto débil, x2)
## solo se abre entre latidos; un parry en el latido le provoca arritmia (aturdido 3 s, pecho abierto).
## El ritmo sube con las fases (60 / 90 / 140 BPM) y en FIBRILACIÓN late sin patrón.
## Si lo aturden 3 veces seguidas se aplica el desfibrilador: onda eléctrica en toda la arena.
## Usa los sprites de grokbot (assets/sprites/bosses/bsod/); si falta alguno, esa pieza se dibuja por código.
## Sin class_name: cargar con preload.

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Epic := preload("res://scripts/combat/epic_fx.gd")
const Barrage := preload("res://scripts/combat/boss_barrage.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Fx := preload("res://scripts/combat/boss_bsod_fx.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")
const Final := preload("res://scripts/combat/boss_final.gd")
const Roar := preload("res://scripts/combat/boss_roar.gd")

signal hp_changed(hp: int, max_hp: int)
signal phase_changed(phase: int, title: String)
signal stunned
signal staggered
signal intro_finished
signal defeated
signal beat

const MAX_HP := 90
const PHASE_AT := [0.6, 0.3]
const BPM := [60.0, 90.0, 140.0]
const MOVE_SPEED := 70.0
const KEEP_DIST := 200.0
const DRILL_SPEED := 640.0
const PAUSE := [1.2, 0.9, 0.6]
const POISE := [8, 11, 14]
const ENRAGE_AT := 0.12
## Fase 2: probabilidad de que un golpe caiga A CONTRATIEMPO (medio latido después).
const OFFBEAT_CHANCE := 0.5
## Fase 3: el ritmo cambia cada 4 latidos entre estos BPM (el monitor lo muestra).
const BPM3 := [110.0, 140.0, 175.0]
## Duelo final CÓDIGO AZUL: descargas a las que hay que hacer parry EN EL LATIDO.
const FINAL_PULSES := 12
const FINAL_BPM := [90.0, 185.0]
const COMBOS := {
	2: [["scalpel", "scalpel"], ["syringes", "drill"], ["tubes", "balls"], ["food", "scalpel"]],
	3: [["clones", "scalpel"], ["puzzle", "syringes"], ["drill", "balls", "stomp"], ["tubes", "food"]],
}

# medidas sobre boss_bsod_body_0 (pies = ruedas en y 0)
const SHOULDER_L := Vector2(-53, -175)
const SHOULDER_R := Vector2(42, -169)
const HEART := Vector2(-13, -152)
const HEAD := Vector2(-13, -221)
const CENTER := Vector2(0, -90)
const ARM_LEN := 150.0
const REST_L := 0.35
const REST_R := -0.3

var hp: int = MAX_HP
var phase: int = 1
var state: String = "intro"
var arena_rect: Rect2 = Rect2(-500, -310, 1000, 620)
var player: CharacterBody2D
## El corazón está expuesto (daño x2). El nombre es el mismo del boss 1 para que la arena lo cuente.
var tank_open: bool = false
var enraged: bool = false

var _tok: int = 0
var _cd: float = 1.0
var _last: String = ""
var _parry_watch: bool = false
var _was_parried: bool = false
var _queue: Array[String] = []
var _near_t: float = 0.0
var _poise: int = 0
var _stuns_in_row: int = 0
var _forced_open: bool = false
var _arrhythmia: bool = false
var _t: float = 0.0
var _tweens: Array[Tween] = []
var _pose_tw: Tween
var rig_off: Vector2 = Vector2.ZERO
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _charge_hit: bool = false

# latido
var _alive: bool = false
var _since_beat: float = 0.0
var _next_interval: float = 1.0
var _bpm3: float = 140.0
var _beats_in_bpm: int = 0
## duelo final
var final_victory: bool = false
var _final_bpm: float = 0.0
## Descargas devueltas que ya llegaron al corazón (la última dispara el remate en cámara lenta).
var _final_back_n: int = 0
const BLUE_FX := Color(0.4, 0.72, 1.0)
var _final_hits: int = 0
var _final_fail: bool = false
var _paddles: Array = []
var ecg: EcgPanel
var _lights: Lights
var _holo: Holo

var rig: Node2D
var gurney: Part
var torso: Part
var heart: Part
var brain: Part
var head: Part
var scalpel: Part
var tool: Part
var sheet: Part
var _home: Dictionary = {}


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	z_index = 1
	collision_layer = 3
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(150, 34)
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
	hr.size = Vector2(130, 250)
	hs.shape = hr
	hs.position = Vector2(0, -125)
	hurt.add_child(hs)
	add_child(hurt)
	GameFeel.add_shadow(self, Vector2(0, -2), Vector2(84, 14))
	_build_rig()


func set_player(p: CharacterBody2D) -> void:
	player = p
	var cc = p.get("class_controller")
	if cc != null and cc.has_signal("parried"):
		cc.connect("parried", _on_player_parried)


## La arena llama esto: el monitor de signos vitales reemplaza la barra de vida.
func build_hud(layer: CanvasLayer) -> void:
	ecg = EcgPanel.new()
	ecg.boss = self
	ecg.position = Vector2(340, 8)
	layer.add_child(ecg)


# --- Piezas ----------------------------------------------------------------------

func _build_rig() -> void:
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)
	gurney = _part("gurney", Vector2.ZERO)
	brain = _part("brain", Vector2(13, -229))
	torso = _part("torso", Vector2.ZERO)
	heart = _part("heart", HEART)
	scalpel = _part("scalpel", SHOULDER_L)
	tool = _part("tool", SHOULDER_R)
	head = _part("head", HEAD)
	sheet = _part("sheet", Vector2.ZERO)
	sheet.visible = false
	scalpel.rotation = REST_L
	tool.rotation = REST_R
	_holo = Holo.new()
	_holo.position = Vector2(0, -262)
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


func _parts() -> Array:
	return [gurney, brain, torso, heart, scalpel, tool, head]


func _face(text: String, col: Color = Color(0.45, 1.0, 0.5)) -> void:
	head.face = text
	head.face_color = col
	if _holo and text != "":
		_holo.show_text(text, col)


func _clear_face() -> void:
	head.face = ""


# --- Latido ------------------------------------------------------------------------

func interval() -> float:
	if _final_bpm > 0.0:
		return 60.0 / _final_bpm
	if enraged:
		return randf_range(0.28, 0.62)
	if phase >= 3:
		return 60.0 / _bpm3
	return 60.0 / BPM[phase - 1]


func bpm_text() -> String:
	if not _alive:
		return "--"
	if _arrhythmia:
		return "???"
	return str(int(60.0 / maxf(_next_interval, 0.05)))


func since_beat() -> float:
	return _since_beat


func is_alive() -> bool:
	return _alive


func is_arrhythmic() -> bool:
	return _arrhythmia


func _beat_step(delta: float) -> void:
	if not _alive:
		return
	_since_beat += delta
	if _since_beat >= _next_interval:
		_since_beat = 0.0
		# fase 3: cambio de ritmo cada 4 latidos (sin aviso, solo el monitor)
		if phase >= 3 and not enraged and _final_bpm <= 0.0:
			_beats_in_bpm += 1
			if _beats_in_bpm >= 4:
				_beats_in_bpm = 0
				var opts: Array = BPM3.filter(func(b): return b != _bpm3)
				_bpm3 = opts[randi() % opts.size()]
		_next_interval = randf_range(0.15, 0.45) if _arrhythmia else interval()
		heart.pulse = 1.0
		if _lights:
			_lights.pulse()
		beat.emit()
	# ventana del punto débil: entre latidos
	var win := clampf(_next_interval * 0.45, 0.18, 0.5)
	var open_now := _since_beat > 0.12 and _since_beat < 0.12 + win and state in ["idle", "attack"]
	tank_open = _forced_open or open_now
	heart.open = tank_open


## Espera al siguiente latido. false = el ataque se cortó.
func _on_beat(tok: int) -> bool:
	await beat
	return tok == _tok and is_inside_tree()


## Para pruebas: qué está pasando con el ritmo.
func probe() -> String:
	if head.face == "½":
		return "contratiempo"
	if phase >= 3:
		return "bpm%d" % int(_bpm3)
	return ""


## Momento del GOLPE: en el latido; en la fase 2, a veces A CONTRATIEMPO (medio latido después),
## avisado con "½" en la pantalla y el corazón en amarillo.
func _strike(tok: int) -> bool:
	if not await _on_beat(tok):
		return false
	if phase == 2 and randf() < OFFBEAT_CHANCE:
		_face("½", Color(1, 0.9, 0.3))
		heart.modulate = Color(1, 1, 0.4)
		var ok := await _wait(interval() * 0.5, tok)
		heart.modulate = Color.WHITE
		return ok
	return true


# --- Bucle ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_beat_step(delta)
	if state != "dead":
		var bob := sin(_t * 2.5) * 1.5
		rig.position = rig_off + Vector2(0, bob)
		head.anim_off = Vector2(0, sin(_t * 2.5 - 0.7) * 1.5)
		brain.anim_off = head.anim_off
		scalpel.anim_rot = sin(_t * 2.0) * 0.05 if state == "idle" else 0.0
		tool.anim_rot = sin(_t * 2.0 + 1.2) * 0.05 if state == "idle" else 0.0
		gurney.scroll += velocity.length() * delta
		if enraged:
			var k := 0.75 + 0.25 * absf(sin(_t * 9.0))
			rig.modulate = Color(k, k, 1.0)
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
		"charge":
			_charge_step(delta)
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
	elif dist < KEEP_DIST - 70.0:
		dir = -to.normalized() * 0.6
	velocity = dir * MOVE_SPEED * (1.0 + 0.2 * (phase - 1))
	move_and_slide()
	rig.skew = lerpf(rig.skew, clampf(velocity.x / 700.0, -0.07, 0.07), 0.1)
	_clamp_inside()


func _clamp_inside() -> void:
	global_position.x = clampf(global_position.x, arena_rect.position.x + 90.0, arena_rect.end.x - 90.0)
	global_position.y = clampf(global_position.y, arena_rect.position.y + 320.0, arena_rect.end.y - 30.0)   # la cabeza no se mete bajo el monitor ECG


func _choose_attack() -> void:
	CoopBoss.retarget(self)
	var pick := ""
	if not _queue.is_empty():
		pick = _queue.pop_front()
	elif _near_t > 1.3:
		pick = "stomp"
	elif phase >= 2 and randf() < (0.3 if phase == 2 else 0.45):
		var list: Array = COMBOS[phase]
		_queue.assign(list[randi() % list.size()])
		pick = _queue.pop_front()
	else:
		var pool: Array[String] = ["scalpel", "syringes", "tubes"]
		if phase >= 2:
			pool.append_array(["drill", "balls", "food"])
		if phase >= 3:
			pool.append_array(["clones", "puzzle"])
		var near := _player_ok() and player.global_position.distance_to(global_position) < 220.0
		var bag: Array[String] = []
		for a in pool:
			if a == _last:
				continue
			bag.append(a)
			if a == "scalpel" and near:
				bag.append_array(["scalpel", "scalpel"])
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
	_clear_face()


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
	_tw(scalpel, "rotation", REST_L, 0.3)
	_tw(tool, "rotation", REST_R, 0.3)
	scalpel.blade = false
	scalpel.saw = false


## Color de los efectos épicos de este boss.
func _accent() -> Color:
	return Color(0.3, 0.6, 1.0)


func _impact(at: Vector2, strength: float) -> void:
	_shake(strength, 0.1 + strength * 0.03)
	Epic.big_hit(get_parent(), at, _accent(), strength, "bsod", "fxshock")
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


func _ghost(on: bool) -> void:
	if not _player_ok():
		return
	if on:
		add_collision_exception_with(player)
	else:
		remove_collision_exception_with(player)


func _interrupt() -> void:
	_tok += 1
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
	_queue.clear()
	velocity = Vector2.ZERO
	_ghost(false)
	_rest_pose(0.2)
	scalpel.blade = false
	scalpel.saw = false
	for p in _parts():
		p.modulate = Color.WHITE
	visible = true
	modulate.a = 1.0


func hurt_player(amount: int, from: Vector2, unblockable: bool = false) -> void:
	if not _player_ok() or state == "dead" or state == "paused":
		return
	_who().call("take_hit", amount, from, unblockable)


func _on_player_parried(_from: Vector2) -> void:
	if _parry_watch:
		_was_parried = true


# --- Recibir daño ----------------------------------------------------------------

func take_hit(amount: int, from: Vector2) -> void:
	if state in ["intro", "transition", "dead", "paused", "final"]:
		GameFeel.flash(rig, 0.08, Color(0.6, 0.6, 0.7))
		return
	var dmg := amount * (2 if tank_open else 1)
	# a un golpe de caer en la fase 3: CÓDIGO AZUL en vez de morir
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
	head.anim_off += -toward * (4.0 + 2.0 * dmg)
	var num := BossFx.DmgNumber.new()
	num.text = str(dmg) + ("!" if tank_open else "")
	num.big = tank_open
	num.color = Color(1, 0.5, 0.5) if tank_open else Color(1, 1, 1)
	get_parent().add_child(num)
	num.global_position = center + toward * 46.0 + Vector2(0, -40)
	if tank_open:
		GameFeel.parry_burst(get_parent(), global_position + HEART, 34.0)
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
	_rest_arms()
	state = "idle"
	_cd = 0.5
	_clear_face()


## Parry en el latido: arritmia. Queda aturdido con el pecho abierto. A la 3.ª seguida, desfibrilador.
func _arrhythmia_stun(time: float) -> void:
	_interrupt()
	var tok := _tok
	state = "stunned"
	_stuns_in_row += 1
	_arrhythmia = true
	_forced_open = true
	_face("@_@", Color(1, 1, 0.4))
	_tw(scalpel, "rotation", 0.8, 0.3)
	_tw(tool, "rotation", -0.8, 0.3)
	_pose(Vector2(0, 12), 0.06, 0.3)
	_shake(4.0, 0.25)
	stunned.emit()
	if not await _wait(time, tok):
		return
	_arrhythmia = false
	_forced_open = false
	_rest_pose()
	_rest_arms()
	if _stuns_in_row >= 3:
		_stuns_in_row = 0
		_tok += 1
		state = "attack"
		_atk_defib(_tok)
		return
	state = "idle"
	_cd = 0.8
	_clear_face()


## Choque contra la pared con el taladro: atascado (sin arritmia).
func _stuck(time: float) -> void:
	_interrupt()
	var tok := _tok
	state = "stunned"
	_forced_open = true
	_face("STUCK", Color(1, 0.9, 0.4))
	_pose(Vector2(0, 10), 0.05, 0.2)
	stunned.emit()
	if not await _wait(time, tok):
		return
	_forced_open = false
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.6
	_clear_face()


func _enter_phase(n: int) -> void:
	phase = n
	_forced_open = false
	_arrhythmia = false
	_interrupt()
	var tok := _tok
	state = "transition"
	if n == 2:
		head.mask = false
		torso.dirty = true
		_face("URG!", Color(1, 0.3, 0.2))
		if _lights:
			_lights.target = Color(1.0, 0.1, 0.1, 0.1)
	else:
		head.blue = true
		heart.sparks = true
		_face(":(", Color(1, 1, 1))
		if _lights:
			_lights.target = Color(0.1, 0.3, 1.0, 0.12)
	GameFeel.flash(rig, 0.3, Color(1.0, 0.3, 0.3))
	_pose(Vector2(0, -12), 0.0, 0.25)
	_shake(7.0, 0.8)
	phase_changed.emit(n, "URGENCIAS" if n == 2 else "PARO CRÍTICO")
	if not await _wait(1.6, tok):
		return
	# lluvia de ataques: inmune hasta que termine (esquivar o parry)
	if not await Barrage.run(self, n, tok):
		return
	_rest_pose()
	state = "idle"
	_cd = 0.4
	_clear_face()


func _enrage() -> void:
	enraged = true
	_interrupt()
	var tok := _tok
	state = "transition"
	_forced_open = false
	_face("FIBRIL", Color(0.6, 0.8, 1.0))
	_pose(Vector2(0, -14), 0.0, 0.3)
	GameFeel.flash(rig, 0.4, Color(0.4, 0.6, 1.0))
	_shake(9.0, 1.0)
	phase_changed.emit(3, "FIBRILACIÓN")
	if not await _wait(1.3, tok):
		return
	_rest_pose()
	state = "idle"
	_cd = 0.3
	_clear_face()


# --- Ataques (todos golpean en un latido) --------------------------------------------

## 1. Bisturí láser (Medicina): dos tajos en cruz. Parry en el latido = arritmia.
func _atk_scalpel(tok: int) -> void:
	if not await _on_beat(tok):
		return
	_face("BISTURÍ", Color(1, 0.4, 0.4))
	var origin := global_position + CENTER
	var aim := _dir_to_player(origin)
	scalpel.blade = true
	_tw(scalpel, "rotation", _rot_for(aim.rotated(-1.3)), interval() * 0.8)
	_pose(-aim * 12.0 + Vector2(0, 4), -aim.x * 0.06, interval() * 0.8)
	_warn_zone(global_position + Vector2(0, -10), aim, 200.0, 1.0, interval())
	if not await _strike(tok):
		return
	_tw(scalpel, "rotation", _rot_for(aim.rotated(1.0)), 0.12)
	_pose(aim * 22.0, aim.x * 0.08, 0.08)
	SlashFx.spawn(get_parent(), origin + aim * 90.0, aim.rotated(0.45), 180.0, 60.0, 0.18, 1.0, true, true)
	SlashFx.spawn(get_parent(), origin + aim * 90.0, aim.rotated(-0.45), 180.0, 60.0, 0.18, 1.0, true, true)
	_impact(origin + aim * 110.0, 3.0)
	if not await _wait(0.05, tok):
		return
	var _stun_any1 := false
	for v in _victims():
		_victim = v
		var to := _player_body() - origin
		if to.length() <= 190.0 and absf(aim.angle_to(to)) <= 1.1:
			_was_parried = false
			_parry_watch = true
			hurt_player(2, origin)
			_parry_watch = false
			_stun_any1 = _stun_any1 or _was_parried
	_victim = null
	if _stun_any1:
		_arrhythmia_stun(3.0)
		return
	if not await _wait(0.4, tok):
		return
	_end_attack(tok)


## 2. Ráfaga de jeringas (Enfermería): abanico de 5; la que pega deja al jugador lento.
func _atk_syringes(tok: int) -> void:
	if not await _on_beat(tok):
		return
	_face("ANESTESIA", Color(0.5, 0.8, 1.0))
	tool.tool = 0
	var hand := global_position + SHOULDER_R
	var aim := _dir_to_player(hand)
	_tw(tool, "rotation", _rot_for(aim), 0.25)
	_pose(-aim * 8.0, -0.04, 0.25)
	var n: int = [5, 6, 7][phase - 1]
	var spread := 0.9
	for i in n:
		var s := Fx.Syringe.new()
		s.dir = aim.rotated(-spread * 0.5 + spread * i / float(n - 1))
		s.delay = interval()
		s.speed = 360.0 + 40.0 * phase
		_add_fx(s, hand + aim * ARM_LEN)
	if not await _strike(tok):
		return
	_pose(aim * 10.0, 0.04, 0.08)
	_shake(2.0, 0.1)
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)


## 3. Tubos de muestra (Laboratorio Clínico): charcos de colores y una placa de Petri con bacterias.
func _atk_tubes(tok: int) -> void:
	if not await _on_beat(tok):
		return
	_face("MUESTRA", Color(1, 0.9, 0.4))
	tool.tool = 2
	_tw(tool, "rotation", _rot_for(Vector2(0.3, -1.0)), interval() * 0.8)
	_pose(Vector2(0, 8), 0.0, interval() * 0.8)
	if not await _on_beat(tok):
		return
	_pose(Vector2(0, -8), -0.03, 0.1)
	var cols := [Color(0.9, 0.2, 0.2), Color(0.25, 0.5, 1.0), Color(1, 0.85, 0.2)]
	var n: int = [3, 4, 5][phase - 1]
	for i in n + 1:
		if not _player_ok():
			break
		var tb := Fx.Tube.new()
		tb.from = global_position + SHOULDER_R + Vector2(0, -20)
		var target := _player_feet()
		if i > 0:
			target += Vector2.from_angle(randf() * TAU) * randf_range(60.0, 160.0)
		tb.to = _clamp_arena(target)
		tb.time = 0.7 + 0.1 * i
		tb.petri = i == n
		tb.color = cols[i % 3]
		tb.on_land = _on_tube_land
		_add_fx(tb, tb.from)
	if not await _wait(1.2, tok):
		return
	_end_attack(tok)


func _on_tube_land(at: Vector2, col: Color, petri: bool) -> void:
	if state == "dead":
		return
	GameFeel.dust(get_parent(), at, 5, Vector2.ZERO, 4.0, Vector2(14, 4))
	if petri:
		for s in [-1.0, 1.0]:
			if get_tree().get_nodes_in_group("boss_minion").size() >= 5:
				break
			var b := Fx.Bacteria.new()
			b.player = player
			b.position = at + Vector2(22.0 * s, 0)
			get_parent().add_child(b)
		return
	var pd := Fx.ColorPuddle.new()
	pd.color = col
	_add_fx(pd, at)


## 4. Taladro dental (Odontología): embiste en línea recta; contra la pared se atasca.
func _atk_drill(tok: int) -> void:
	if not await _on_beat(tok):
		return
	_face("DRILL", Color(1, 0.6, 0.3))
	tool.tool = 1
	var cdir := (player.global_position - global_position).normalized() if _player_ok() else Vector2.DOWN
	_tw(tool, "rotation", _rot_for(cdir), 0.2)
	_pose(-cdir * 18.0, -cdir.x * 0.1, interval())
	_warn_zone(global_position, cdir, 480.0, 0.16, interval())
	if not await _on_beat(tok):
		return
	_charge_dir = cdir
	_charge_left = 1.0
	_charge_hit = false
	_pose(cdir * 10.0, cdir.x * 0.1, 0.1)
	_ghost(true)
	state = "charge"


func _charge_step(delta: float) -> void:
	velocity = _charge_dir * DRILL_SPEED
	move_and_slide()
	gurney.scroll += DRILL_SPEED * delta
	if randf() < 0.5:
		GameFeel.dust(get_parent(), global_position + Vector2(randf_range(-60, 60), 0), 2, -_charge_dir * 60.0, 4.0)
	for v in _victims():
		_victim = v
		if _player_feet().distance_to(global_position + Vector2(0, -10)) < 80.0 and CoopBoss.once(self, "charge%d" % _tok, v):
			_charge_hit = true
			hurt_player(2, global_position, true)
	_victim = null
	_charge_left -= delta
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is StaticBody2D:
			velocity = Vector2.ZERO
			_shake(9.0, 0.4)
			GameFeel.dust(get_parent(), global_position + _charge_dir * 70.0, 10, Vector2.ZERO, 6.0, Vector2(30, 10))
			_stuck(2.5)
			return
	if _charge_left <= 0.0:
		velocity = Vector2.ZERO
		_ghost(false)
		state = "attack"
		var tok := _tok
		if await _wait(0.4, tok):
			_end_attack(tok)


## 5. Pelotas de terapia (Fisioterapia): una por latido, rebotan por la arena.
func _atk_balls(tok: int) -> void:
	_face("TERAPIA", Color(0.5, 1.0, 0.9))
	var n: int = 3 if phase < 3 else 4
	for i in n:
		if not await _on_beat(tok):
			return
		_pose(Vector2(0, 6 if i % 2 == 0 else -6), 0.0, 0.08)
		var b := Fx.Ball.new()
		b.arena = arena_rect
		var ang := randf_range(0.3, 1.2) * (1.0 if randf() < 0.5 else -1.0)
		b.vel = Vector2.DOWN.rotated(ang) * (240.0 + 30.0 * phase)
		_add_fx(b, global_position + Vector2(0, 30))
	if not await _wait(0.5, tok):
		return
	_end_attack(tok)


## 6. Pirámide alimenticia (Nutrición): cae comida; la sana cura, la chatarra daña.
func _atk_food(tok: int) -> void:
	if not await _on_beat(tok):
		return
	_face("DIETA", Color(0.6, 1.0, 0.4))
	_pose(Vector2(0, -10), 0.0, 0.3)
	_tw(tool, "rotation", _rot_for(Vector2(0.2, -1.0)), 0.3)
	_tw(scalpel, "rotation", _rot_for(Vector2(-0.2, -1.0)), 0.3)
	if not await _on_beat(tok):
		return
	if _player_ok():
		var base := _player_feet() + Vector2(0, 60)
		var i := 0
		for row in 4:
			var count := 4 - row
			for c in count:
				var f := Fx.Food.new()
				f.healthy = randf() < 0.35
				f.kind = randi() % 4
				f.delay = row * 0.12
				var pos := base + Vector2((c - (count - 1) * 0.5) * 70.0, -row * 50.0)
				_add_fx(f, _clamp_arena(pos))
				i += 1
	if not await _wait(1.6, tok):
		return
	_end_attack(tok)


## 7. Test de manchas (Psicología): manchas de tinta y 3 copias. Solo la real late.
func _atk_clones(tok: int) -> void:
	if not await _on_beat(tok):
		return
	_face("¿?", Color(0.8, 0.6, 1.0))
	brain.glow = true
	for i in 7:
		var ink := Fx.InkBlot.new()
		ink.size = randf_range(50.0, 90.0)
		get_parent().add_child(ink)
		ink.global_position = Vector2(randf_range(arena_rect.position.x + 60, arena_rect.end.x - 60), randf_range(arena_rect.position.y + 60, arena_rect.end.y - 40))
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	_tweens.append(tw)
	if not await _on_beat(tok):
		return
	var spots: Array[Vector2] = []
	for i in 4:
		spots.append(Vector2(randf_range(arena_rect.position.x + 120, arena_rect.end.x - 120), randf_range(arena_rect.position.y + 250, arena_rect.end.y - 60)))
	global_position = spots[0]
	for i in range(1, 4):
		var c := Fx.Clone.new()
		c.boss = self
		get_parent().add_child(c)
		c.global_position = spots[i]
	var tw2 := create_tween()
	tw2.tween_property(self, "modulate:a", 1.0, 0.25)
	_tweens.append(tw2)
	if not await _wait(1.0, tok):
		return
	brain.glow = false
	_end_attack(tok)


## 8. Rompecabezas (Terapia Ocupacional): bloques que se cierran sobre el jugador. Rompe el que brilla.
func _atk_puzzle(tok: int) -> void:
	if not await _on_beat(tok):
		return
	_face("ENCAJA", Color(1, 0.8, 0.3))
	tool.tool = 2
	_tw(tool, "rotation", _rot_for(_dir_to_player(global_position + SHOULDER_R)), 0.2)
	if not await _on_beat(tok):
		return
	if _player_ok():
		var trap := Fx.BlockTrap.new()
		trap.close_time = interval() * 4.0
		_add_fx(trap, _player_feet())
	_impact(global_position + Vector2(0, 20), 3.0)
	if not await _wait(1.0, tok):
		return
	_end_attack(tok)


## 9. Pisotón de camilla (si el jugador se queda pegado): onda de choque en el latido.
func _atk_stomp(tok: int) -> void:
	_face("!!", Color(1, 0.5, 0.3))
	var max_r := 260.0 if phase < 3 else 330.0
	_warn_zone(global_position, Vector2.DOWN, max_r, 0.0, interval() * 1.2)
	_pose(Vector2(0, -40), 0.0, interval() * 0.8)
	if not await _on_beat(tok):
		return
	if not await _strike(tok):
		return
	_pose(Vector2(0, 6), 0.0, 0.07)
	_impact(global_position, 9.0)
	var ring := BossFx.ShockRing.new()
	ring.max_r = max_r
	_add_fx(ring, global_position)
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)


## Desfibrilador (tras 3 arritmias seguidas): dos descargas en toda la arena. Rodar a través.
func _atk_defib(tok: int) -> void:
	_face("CLEAR!", Color(1, 1, 0.4))
	_pose(Vector2(0, -10), 0.0, 0.3)
	for i in 2:
		if not await _on_beat(tok):
			return
		GameFeel.flash(rig, 0.25, Color(0.6, 0.8, 1.0))
		if _lights:
			_lights.flash(Color(0.7, 0.85, 1.0, 0.35))
		_impact(global_position, 7.0)
		var ring := BossFx.ShockRing.new()
		ring.max_r = 560.0
		ring.speed = 520.0
		_add_fx(ring, global_position)
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)


# --- CÓDIGO AZUL (duelo final) ---------------------------------------------------------
## A un golpe de caer: carga el desfibrilador y dispara descargas EN CADA LATIDO. Cada una llega
## justo en el siguiente latido: hay que hacerle parry a tiempo (preciso). El ritmo sube de 90 a 185 BPM
## y la música con él. FINAL_PULSES aciertos = el corazón se para (pantalla azul) y cae.
## Un fallo: RITMO PERDIDO, vuelve la fase 3 y el próximo golpe repite el duelo.
func _start_final() -> void:
	_interrupt()
	var tok := _tok
	state = "final"
	_forced_open = false
	_arrhythmia = false
	tank_open = false
	heart.open = false
	_final_hits = 0
	_final_back_n = 0
	_final_fail = false
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	Final.title(self, "CÓDIGO AZUL", Color(0.4, 0.7, 1.0), "Haz parry EN EL LATIDO")
	Final.music_cue(self, "final1")
	_face("CLEAR!", Color(0.6, 0.85, 1.0))
	if _lights:
		_lights.target = Color(0.1, 0.3, 1.0, 0.18)
	var spot := Vector2(0.0, arena_rect.position.y + 330.0)
	_tw(self, "global_position", spot, 0.7)
	# CARGA: frota las paletas (los dos brazos se juntan y se separan) con chispas crecientes
	_show_paddles(true)
	_final_bpm = FINAL_BPM[0]
	for k in 3:
		_tw(scalpel, "rotation", -0.5, 0.18)
		_tw(tool, "rotation", 0.5, 0.18)
		_pose(Vector2(0, -6), 0.0, 0.18)
		if not await _wait(0.2, tok):
			return
		for pd in _paddles:
			pd.charge = (k + 1) / 3.0
			pd.zap()
			Epic.ring(get_parent(), pd.global_position, BLUE_FX, 60.0 + 30.0 * k, 0.3, 5.0)
			Epic.burst(get_parent(), pd.global_position, Color(0.75, 0.9, 1.0), 6 + 3 * k, 220.0, 0.4, 0.4)
		Epic.charge(get_parent(), global_position + HEART, BLUE_FX, 0.4, 90.0 + 30.0 * k, self, HEART)
		GameFeel.flash(rig, 0.1, Color(0.6, 0.85, 1.0))
		_tw(scalpel, "rotation", REST_L + 0.4, 0.18)
		_tw(tool, "rotation", REST_R - 0.4, 0.18)
		if not await _wait(0.22, tok):
			return
	_say_big("¡CARGANDO!")
	Epic.flash(get_parent(), BLUE_FX, 0.2, 0.3)
	Epic.ring(get_parent(), global_position, BLUE_FX, 300.0, 0.5, 10.0)
	# DESCARGAS al ritmo del corazón
	var side := 0
	while _final_hits < FINAL_PULSES and not _final_fail:
		if not await _on_beat(tok):
			return
		if _final_fail:
			break
		var launched := _final_hits + get_tree().get_nodes_in_group("final_shot").size()
		if launched >= FINAL_PULSES:
			continue
		var arm: Part = scalpel if side == 0 else tool
		side = 1 - side
		await _discharge(arm, tok)
	# esperar a que se resuelvan las que van en el aire
	var w := 0.0
	while not _final_fail and _final_hits < FINAL_PULSES and w < 3.0:
		if not await _wait(0.05, tok):
			return
		w += 0.05
	if _final_fail:
		_final_lost(tok)
	else:
		# la última descarga devuelta tiene que llegar al corazón (es el golpe del remate)
		var w2 := 0.0
		while _final_back_n < FINAL_PULSES and w2 < 2.5:
			if not await _wait(0.05, tok):
				return
			w2 += 0.05
		_final_won()


## Una descarga: el brazo se echa atrás y empuja la paleta hacia el jugador en el latido.
## La bola eléctrica llega al jugador justo en el SIGUIENTE latido.
func _discharge(arm: Part, tok: int) -> void:
	var from := arm.global_position + Vector2(0, ARM_LEN * 0.8).rotated(arm.global_rotation)
	var aim := _dir_to_player(arm.global_position)
	# empuje (anticipación ya hecha en el medio latido anterior)
	_tw(arm, "rotation", _rot_for(aim), 0.06)
	_pose(aim * 14.0 + Vector2(0, 4), aim.x * 0.06, 0.06)
	heart.pulse = 1.0
	var shot := Final.Shot.new()
	shot.col = Color(0.45, 0.75, 1.0)
	shot.label = "♥"
	shot.strict = 0.2 if _final_hits < 6 else 0.17
	shot.damage = 2
	shot.target = HEART
	_add_fx(shot, from)
	shot.aim_at(_player_body() if _player_ok() else from + Vector2.DOWN * 200.0, 400.0, _next_interval)
	for pd in _paddles:
		pd.zap()
	GameFeel.parry_burst(get_parent(), from, 18.0)
	Epic.burst(get_parent(), from, Color(0.7, 0.9, 1.0), 10, 260.0, 0.3, 0.4)
	Epic.ring(get_parent(), from, BLUE_FX, 90.0, 0.3, 5.0)
	_shake(2.0, 0.08)
	# recoge el brazo para el siguiente (anticipación)
	var back := create_tween()
	back.tween_interval(0.08)
	back.tween_property(arm, "rotation", (REST_L if arm == scalpel else REST_R) + (0.6 if arm == scalpel else -0.6), maxf(0.1, _next_interval * 0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	back.parallel().tween_property(self, "rig_off", Vector2(0, -4), maxf(0.1, _next_interval * 0.5))


## Lo llama la descarga al llegar al jugador.
func final_result(ok: bool, _shot: Node) -> void:
	if state != "final":
		return
	if not ok:
		_final_fail = true
		return
	_final_hits += 1
	_face("%d/%d" % [_final_hits, FINAL_PULSES], Color(0.6, 1.0, 0.7))
	# el ritmo sube con cada acierto
	_final_bpm = lerpf(FINAL_BPM[0], FINAL_BPM[1], float(_final_hits) / FINAL_PULSES)
	if _final_hits == 4:
		Final.music_cue(self, "final2")
	elif _final_hits == 8:
		Final.music_cue(self, "final3")
	GameFeel.hit_stop(get_tree(), 0.04)


## La descarga devuelta le pega en el corazón.
func final_back(shot: Node2D) -> void:
	_final_back_n += 1
	var at := global_position + HEART
	var k := float(_final_back_n) / FINAL_PULSES
	GameFeel.parry_burst(get_parent(), at, 26.0 + 2.0 * _final_hits)
	heart.pulse = 1.0
	GameFeel.flash(rig, 0.08, Color(0.6, 0.85, 1.0))
	head.anim_off += Vector2(0, -4)
	shot.queue_free()
	# cada choque devuelto pega más fuerte: onda, chispas, arcos y la cámara
	Epic.ring(get_parent(), at, BLUE_FX, 110.0 + 160.0 * k, 0.4, 6.0 + 8.0 * k)
	Epic.burst(get_parent(), at, Color(0.75, 0.9, 1.0), int(10 + 24 * k), 280.0 + 200.0 * k, 0.4, 0.5)
	Epic.anim(get_parent(), "bsod", "fxshock", at, 0.6 + 0.6 * k)
	Epic.word(get_parent(), at + Vector2(randf_range(-50, 50), -70), "%d/%d" % [_final_back_n, FINAL_PULSES], Color(0.7, 0.9, 1.0), int(20 + 18 * k), 0.6)
	Epic.cam_punch(get_tree(), 0.02 + 0.05 * k, 0.2)
	_shake(2.0 + 4.0 * k, 0.12)
	if _final_back_n >= FINAL_PULSES * 2 / 3:
		Epic.speed_lines(get_parent(), 0.3, Color(0.7, 0.9, 1.0, 0.45))


## REMATE en cámara lenta: la última descarga devuelta le atraviesa el corazón.
func _last_shock() -> void:
	var p := get_parent()
	var at := global_position + HEART
	var bars := Epic.cinema(p)
	Epic.cam_zoom(get_tree(), 1.22, 0.3)
	Epic.cam_focus(get_tree(), at)
	Engine.time_scale = 0.3
	Epic.whiteout(p, Color(0.7, 0.88, 1.0, 0.9), 0.7, 0.08)
	Epic.ring(p, at, BLUE_FX, 520.0, 0.8, 18.0)
	Epic.ring(p, at, Color.WHITE, 320.0, 0.6, 8.0)
	Epic.burst(p, at, Color(0.8, 0.95, 1.0), 60, 620.0, 0.4, 1.0)
	Epic.shards(p, at, Color(0.85, 0.2, 0.25), 14, 420.0, 7.0)
	Epic.anim(p, "bsod", "fxpulse", at, 1.5)
	Epic.word(p, at + Vector2(0, -100), "¡CLEAR!", Color(0.75, 0.92, 1.0), 64, 1.4)
	heart.pulse = 1.0
	GameFeel.flash(rig, 0.5, Color(0.7, 0.9, 1.0))
	_shake(10.0, 0.5)
	await get_tree().create_timer(1.1, true, false, true).timeout
	Engine.time_scale = 1.0
	Epic.cam_reset(get_tree(), 0.5)
	if bars:
		bars.close()


func _final_won() -> void:
	final_victory = true
	_final_bpm = 0.0
	Final.music_final(self, "epic")
	await _last_shock()
	await _finisher()
	_shake(12.0, 0.8)
	hp = 0
	hp_changed.emit(hp, MAX_HP)
	_die()


func _final_lost(tok: int) -> void:
	_final_bpm = 0.0
	_show_paddles(false)
	for h in get_tree().get_nodes_in_group("final_shot"):
		h.queue_free()
	Final.title(self, "RITMO PERDIDO", Color(1.0, 0.35, 0.3), "", 1.1)
	Final.music_cue(self, "p3")
	_face("TAQUI", Color(1, 0.4, 0.3))
	_rest_pose()
	_rest_arms()
	if _lights:
		_lights.target = Color(0.1, 0.3, 1.0, 0.12)
	if not await _wait(1.0, tok):
		return
	state = "idle"
	_cd = 1.0
	_clear_face()


func _show_paddles(on: bool) -> void:
	for pd in _paddles:
		if is_instance_valid(pd):
			pd.queue_free()
	_paddles.clear()
	if not on:
		return
	for arm in [scalpel, tool]:
		var pd := Paddle.new()
		arm.add_child(pd)
		pd.position = Vector2(0, ARM_LEN * 0.8)
		_paddles.append(pd)


func _say_big(text: String) -> void:
	if _holo:
		_holo.show_text(text, Color(0.6, 0.85, 1.0))



# --- Lluvia de cambio de fase propia: CÓDIGO ROJO -----------------------------------------
## Todo al latido: anillos de jeringas, tubos de muestra que dejan charcos, pelotas de terapia
## y la línea del electrocardiograma que barre la sala (rodar a través).
func barrage_title(_n: int) -> String:
	return "CÓDIGO ROJO"


func barrage_plan(n: int) -> Array:
	if n == 2:
		return [[0.2, "syringes", {"n": 10}], [1.2, "tubes", {"n": 5}], [2.4, "ecg", {"down": true}],
			[4.0, "syringes", {"n": 12}], [4.8, "balls", {"n": 3}], [6.0, "ecg", {"down": false}]]
	return [[0.2, "syringes", {"n": 12}], [1.0, "ecg", {"down": true}], [2.0, "tubes", {"n": 7}],
		[3.0, "balls", {"n": 4}], [4.0, "syringes", {"n": 14}], [5.0, "ecg", {"down": false}],
		[6.2, "tubes", {"n": 6}], [7.0, "syringes", {"n": 16}], [7.6, "ecg", {"down": true}]]


func _bfx(n: Node2D, at: Vector2) -> void:
	_add_fx(n, at)
	Barrage.tag(n)


func _bar_syringes(a: Dictionary, _tok: int) -> void:
	heart.pulse = 1.0
	var n: int = a["n"]
	var off := randf() * TAU
	for i in n:
		var s := Fx.Syringe.new()
		s.dir = Vector2.from_angle(off + TAU * i / n)
		s.delay = 0.35
		s.speed = 330.0
		_bfx(s, global_position + CENTER)
	_pose(Vector2(0, -6), 0.0, 0.1)


func _bar_tubes(a: Dictionary, _tok: int) -> void:
	var cols := [Color(0.9, 0.2, 0.2), Color(0.25, 0.5, 1.0), Color(1, 0.85, 0.2)]
	for i in int(a["n"]):
		var tb := Fx.Tube.new()
		tb.from = global_position + SHOULDER_R + Vector2(0, -20)
		var target := _player_feet() if (_player_ok() and i == 0) else Vector2(randf_range(arena_rect.position.x + 80, arena_rect.end.x - 80), randf_range(arena_rect.position.y + 120, arena_rect.end.y - 40))
		tb.to = _clamp_arena(target)
		tb.time = 0.7 + 0.08 * i
		tb.petri = false
		tb.color = cols[i % 3]
		tb.on_land = _on_tube_land
		_bfx(tb, tb.from)


func _bar_balls(a: Dictionary, _tok: int) -> void:
	for i in int(a["n"]):
		var b := Fx.Ball.new()
		b.arena = arena_rect
		b.vel = Vector2.DOWN.rotated(randf_range(-1.2, 1.2)) * 300.0
		_bfx(b, global_position + Vector2(0, 30))


func _bar_ecg(a: Dictionary, _tok: int) -> void:
	var e := EcgSweep.new()
	e.area = arena_rect
	e.down = bool(a["down"])
	_bfx(e, Vector2.ZERO)


## REMATE: el corazón se para: el monitor marca la línea plana con su pitido largo y las paletas
## del desfibrilador se sobrecargan y le explotan en las manos.
func _finisher() -> void:
	_alive = false
	heart.dead = true
	head.flat = true
	_face("", Color.WHITE)
	if _lights:
		_lights.flash(Color(0.7, 0.85, 1.0, 0.4))
	await get_tree().create_timer(0.7).timeout
	for pd in _paddles:
		if is_instance_valid(pd):
			pd.zap()
	for arm in [scalpel, tool]:
		var tip: Vector2 = arm.global_position + Vector2(0, ARM_LEN * 0.8).rotated(arm.global_rotation)
		GameFeel.parry_burst(get_parent(), tip, 44.0)
		Epic.burst(get_parent(), tip, Color(0.75, 0.9, 1.0), 26, 420.0, 0.5, 0.8)
		Epic.ring(get_parent(), tip, BLUE_FX, 200.0, 0.45, 10.0)
		Epic.shards(get_parent(), tip, Color(0.6, 0.65, 0.75), 10, 380.0, 7.0)
		Epic.anim(get_parent(), "bsod", "fxshock", tip, 1.1)
	Epic.flash(get_parent(), BLUE_FX, 0.35, 0.5)
	Epic.speed_lines(get_parent(), 0.5, Color(0.75, 0.9, 1.0, 0.5))
	GameFeel.flash(rig, 0.3, Color(0.6, 0.85, 1.0))
	_shake(8.0, 0.4)
	_show_paddles(false)
	Final.title(self, "PARO CARDÍACO", Color(0.45, 0.75, 1.0), "Asistolia", 1.2)
	await get_tree().create_timer(0.6).timeout


## Línea del electrocardiograma que barre la arena de arriba abajo (o al revés). Rodar a través.
class EcgSweep extends BossFx.Hazard:
	var area := Rect2(-500, -310, 1000, 620)
	var down := true
	var t := 0.0
	var warn := 0.7
	var time := 1.6
	var _hit := false

	func _ready() -> void:
		z_index = 4

	func _y() -> float:
		var k := clampf((t - warn) / time, 0.0, 1.0)
		return lerpf(area.position.y + 40.0, area.end.y - 10.0, k if down else 1.0 - k)

	func _process(delta: float) -> void:
		t += delta
		if t > warn:
			for v in victims():
				_victim = v
				if absf(player_feet().y - _y()) < 16.0 and first_hit():
					_hit = true
					hurt(2, true)
			_victim = null
		if t > warn + time + 0.2:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var y := _y()
		if t < warn:
			var blink := 0.5 + 0.5 * sin(t * 20.0)
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(1, 0.3, 0.3, 0.5 * blink), 3.0)
			return
		var pts := PackedVector2Array()
		var x := area.position.x
		var i := 0
		while x <= area.end.x:
			var ph := fmod(x + t * 400.0, 160.0)
			var dy := 0.0
			if ph > 60 and ph < 70:
				dy = -40.0
			elif ph >= 70 and ph < 78:
				dy = 30.0
			pts.append(Vector2(x, y + dy))
			x += 6.0
			i += 1
		draw_polyline(pts, Color(0.3, 1.0, 0.45, 0.35), 10.0)
		draw_polyline(pts, Color(0.5, 1.0, 0.6), 3.0)


# --- Aparición y muerte -----------------------------------------------------------

func start_intro(skip: bool) -> void:
	state = "intro"
	_lights = Lights.new()
	_lights.arena = arena_rect
	get_parent().add_child.call_deferred(_lights)
	if skip:
		_alive = true
		await get_tree().create_timer(0.6).timeout
		intro_finished.emit()
		return
	# 1. código azul: la camilla entra con una sábana encima
	for p in [torso, heart, scalpel, tool, head, brain]:
		p.visible = false
	sheet.visible = true
	var home := position
	position = home + Vector2(0, -320)
	await get_tree().create_timer(0.4).timeout
	_holo.show_text("CÓDIGO AZUL", Color(0.5, 0.7, 1.0), 2.4)
	for i in 3:
		if _lights:
			_lights.flash(Color(1.0, 0.1, 0.1, 0.25))
		await get_tree().create_timer(0.35).timeout
	var tw := create_tween()
	tw.tween_property(self, "position", home, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(gurney, "scroll", 300.0, 1.1)
	await tw.finished
	GameFeel.dust(get_parent(), global_position, 8, Vector2(0, 30), 5.0, Vector2(60, 6))
	_shake(3.0, 0.3)
	await get_tree().create_timer(0.9).timeout   # línea plana en el monitor de arriba
	# 2. desfibrilador: dos descargas; con la segunda, el primer latido
	for i in 2:
		_holo.show_text("CLEAR!", Color(1, 1, 0.4))
		await get_tree().create_timer(0.5).timeout
		if _lights:
			_lights.flash(Color(0.8, 0.9, 1.0, 0.5))
		GameFeel.parry_burst(get_parent(), global_position + Vector2(0, -40), 60.0)
		sheet.position.y = -18.0
		create_tween().tween_property(sheet, "position:y", 0.0, 0.2)
		_shake(6.0, 0.3)
		await get_tree().create_timer(0.7).timeout
	_alive = true
	_since_beat = 0.0
	_next_interval = interval()
	await get_tree().create_timer(0.8).timeout
	# 3. la sábana sale volando y se levanta pieza por pieza
	var st := create_tween().set_parallel(true)
	st.tween_property(sheet, "position", Vector2(80, -260), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	st.tween_property(sheet, "rotation", 1.4, 0.6)
	st.tween_property(sheet, "modulate:a", 0.0, 0.6)
	torso.visible = true
	heart.visible = true
	torso.scale = Vector2(1, 0.1)
	heart.scale = Vector2(1, 0.1)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(torso, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(heart, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await rise.finished
	scalpel.visible = true
	tool.visible = true
	scalpel.rotation = -1.4
	tool.rotation = 1.4
	_tw(scalpel, "rotation", REST_L, 0.3)
	_tw(tool, "rotation", REST_R, 0.3)
	await get_tree().create_timer(0.35).timeout
	head.visible = true
	brain.visible = true
	head.position = HEAD + Vector2(0, -200)
	var hd := create_tween()
	hd.tween_property(head, "position", HEAD, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await hd.finished
	_shake(4.0, 0.2)
	sheet.visible = false
	await get_tree().create_timer(0.3).timeout
	# 4. firma: junta los brazos como paletas de desfibrilador, carga un arco eléctrico
	#    y descarga: CLEAR!
	_tw(scalpel, "rotation", -0.75, 0.25)
	_tw(tool, "rotation", 0.75, 0.25)
	await get_tree().create_timer(0.25).timeout
	var arc := Roar.Arc.new()
	arc.a_node = scalpel
	arc.b_node = tool
	arc.a_off = Vector2(0, 80)
	arc.b_off = Vector2(0, 80)
	arc.life = 0.8
	get_parent().add_child(arc)
	_face("...", Color(0.5, 0.8, 1.0))
	for i in 3:
		heart.pulse = 1.0
		if _lights:
			_lights.flash(Color(0.5, 0.8, 1.0, 0.18))
		await get_tree().create_timer(0.25).timeout
	_tw(scalpel, "rotation", 1.2, 0.08)
	_tw(tool, "rotation", -1.2, 0.08)
	scalpel.blade = true
	_face(">:)", Color(1, 0.3, 0.3))
	_holo.show_text("CLEAR!", Color(1, 1, 0.4))
	if _lights:
		_lights.flash(Color(0.85, 0.95, 1.0, 0.55))
	var wv := Roar.Waves.new()
	wv.col = Color(0.55, 0.85, 1.0)
	wv.jagged = true
	wv.count = 3
	Roar.spawn(get_parent(), wv, heart.global_position)
	_shake(9.0, 0.6)
	await get_tree().create_timer(0.9).timeout
	scalpel.blade = false
	_clear_face()
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
	_forced_open = false
	heart.open = false
	remove_from_group("enemies")
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.call("die")
	# último latido en cámara lenta y luego línea plana
	Engine.time_scale = 0.2
	heart.pulse = 1.0
	await get_tree().create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 1.0
	_alive = false
	heart.dead = true
	_face("", Color.WHITE)
	head.flat = true
	_pose(Vector2(0, 6), 0.0, 0.4)
	await get_tree().create_timer(1.2).timeout
	# pantalla azul de la muerte
	var bs := Fx.BlueScreen.new()
	get_parent().add_child(bs)
	await get_tree().create_timer(2.6).timeout
	# se desploma sobre la camilla y salen volando los insumos
	head.blue = true
	for i in 12:
		var d := BossFx.Debris.new()
		d.kind = i % 8
		d.prefix = "boss_bsod_debris_"
		d.vel = Vector2(randf_range(-260, 260), randf_range(-420, -200))
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-180, -60))
	for p in [scalpel, tool]:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "rotation", (1.0 if p == scalpel else -1.0) * 1.6, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(head, "position", HEAD + Vector2(30, 120), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(head, "rotation", 1.2, 0.5)
	fall.tween_property(torso, "scale", Vector2(1.1, 0.55), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(heart, "position", HEART + Vector2(0, 50), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(brain, "modulate:a", 0.0, 0.4)
	_shake(8.0, 0.4)
	GameFeel.dust(get_parent(), global_position, 14, Vector2.ZERO, 7.0, Vector2(80, 10))
	if _lights:
		_lights.target = Color(1, 1, 1, 0)
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
	var scroll := 0.0
	# estados
	var open := false
	var pulse := 0.0
	var dead := false
	var sparks := false
	var mask := true
	var blue := false
	var flat := false
	var dirty := false
	var glow := false
	var blade := false
	var saw := false
	var tool := 0
	var face := ""
	var face_color := Color(0.45, 1.0, 0.5)

	const OUT := Color(0.05, 0.05, 0.06)
	const WHITE := Color(0.92, 0.94, 0.95)
	const GREY := Color(0.62, 0.66, 0.7)
	const TEAL := Color(0.28, 0.66, 0.62)
	const TEAL_D := Color(0.18, 0.46, 0.44)
	const RED := Color(0.85, 0.15, 0.15)

	func _process(delta: float) -> void:
		t += delta
		pulse = maxf(0.0, pulse - delta * 4.0)
		anim_off = anim_off.lerp(Vector2.ZERO, minf(1.0, delta * 8.0)) if kind == "head" and anim_off.length() > 3.0 else anim_off
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
			"gurney":
				_gurney()
			"torso":
				_torso()
			"heart":
				_heart()
			"head":
				_head()
			"brain":
				_brain()
			"scalpel":
				_scalpel()
			"tool":
				_tool()
			"sheet":
				_sheet()

	# --- con sprites de grokbot ---
	# pantalla negra de cada cabeza (x, y, ancho, alto) en px de la imagen
	const SCREENS := [Rect2(8, 23, 27, 15), Rect2(6, 24, 27, 17), Rect2(7, 24, 28, 18)]

	func _draw_sprite() -> bool:
		var body := Spr.tex("boss_bsod_body_0")
		match kind:
			"gurney":
				return body != null   # la camilla ya viene en el sprite del cuerpo
			"torso":
				if body == null:
					return false
				var tx: Texture2D = Spr.tex("boss_bsod_body_1") if dirty else body
				if tx == null:
					tx = body
				Spr.draw_feet(self, tx, anim_off)
				return true
			"brain":
				if body == null:
					return false
				# el frasco ya está en el cuerpo: aquí solo el brillo al usar Psicología
				if glow:
					draw_circle(Vector2.ZERO, 20.0 + 3.0 * sin(t * 10.0), Color(1, 0.6, 1.0, 0.25))
				return true
			"heart":
				var tx := Spr.tex("boss_bsod_heart_%d" % (2 if dead else (1 if open else 0)))
				if tx == null:
					return false
				var s := 1.0 + 0.16 * pulse
				if open and not dead:
					draw_rect(Rect2(-24, -34, 48, 68).grow(2.0 + 2.0 * sin(t * 12.0)), Color(1, 0.6, 0.3, 0.5), false, 2.0)
				Spr.draw_centered(self, tx, anim_off, false, s)
				if sparks and not dead and randf() < 0.2:
					var p := Vector2(randf_range(-18, 18), randf_range(-28, 28))
					draw_line(p, p + Vector2(randf_range(-6, 6), randf_range(-6, 6)), Color(1, 1, 0.6), 2.0)
				return true
			"head":
				var idx := 2 if blue else (0 if mask else 1)
				var tx := Spr.tex("boss_bsod_head_%d" % idx)
				if tx == null:
					return false
				var origin := anim_off + Vector2(-tx.get_width() * 0.5, 24.0 - tx.get_height())
				Spr.draw_feet(self, tx, anim_off + Vector2(0, 24))
				var scr: Rect2 = SCREENS[idx]
				scr.position += origin
				if blue:
					draw_rect(scr, Color(0.05, 0.25, 0.65))
					draw_string(ThemeDB.fallback_font, scr.position + Vector2(0, scr.size.y * 0.5 + 5), ":(", HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, 12, Color.WHITE)
				elif face != "":
					var fs := 11 if face.length() <= 4 else 7
					draw_string(ThemeDB.fallback_font, scr.position + Vector2(0, scr.size.y * 0.5 + fs * 0.35), face, HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, fs, face_color)
				else:
					_mini_ecg(scr.grow(-1.0))
				return true
			"scalpel", "tool":
				var idx: int = tool if kind == "tool" else (2 if saw else (1 if blade else 0))
				var name := "boss_bsod_%s_%d" % [kind, idx]
				var tx := Spr.tex(name)
				if tx == null:
					return false
				var piv := Spr.top_pivot(name)
				draw_set_transform(anim_off, anim_rot - Spr.lean(name), Vector2.ONE)
				draw_texture(tx, -piv)
				if kind == "scalpel" and blade:
					draw_set_transform(anim_off, anim_rot, Vector2.ONE)
					draw_line(Vector2(0, 120), Vector2(0, 166), Color(1, 0.3, 0.3, 0.25), 8.0)
				return true
		return false

	func _gurney() -> void:
		# patas y ruedas
		for x in [-58.0, 58.0]:
			draw_line(Vector2(x, -34), Vector2(x, -10), GREY, 4.0)
			var rot := scroll * 0.08
			draw_circle(Vector2(x, -7), 7, Color(0.15, 0.15, 0.17))
			draw_line(Vector2(x, -7), Vector2(x, -7) + Vector2.from_angle(rot) * 6.0, GREY, 2.0)
			draw_arc(Vector2(x, -7), 7, 0, TAU, 12, OUT, 1.5)
		draw_line(Vector2(-58, -22), Vector2(58, -22), GREY, 3.0)
		# colchón y sábana colgando
		_box(Rect2(-74, -46, 148, 14), WHITE, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-74, -32), Vector2(-66, -32), Vector2(-70, -18), Vector2(-76, -20)]), Color(0.85, 0.88, 0.9))
		draw_colored_polygon(PackedVector2Array([Vector2(74, -32), Vector2(66, -32), Vector2(70, -16), Vector2(76, -18)]), Color(0.85, 0.88, 0.9))
		draw_rect(Rect2(-74, -46, 148, 4), TEAL)

	func _torso() -> void:
		# poste de suero detrás con dos bolsas
		draw_line(Vector2(30, -40), Vector2(30, -232), GREY, 3.0)
		draw_line(Vector2(14, -232), Vector2(46, -232), GREY, 3.0)
		for bx in [14.0, 46.0]:
			var sway := sin(t * 2.0 + bx) * 2.0
			var bag := Rect2(bx - 8 + sway, -228, 16, 24)
			draw_rect(bag, Color(0.8, 0.95, 1.0, 0.75))
			draw_rect(Rect2(bag.position.x, bag.position.y + 10, 16, 14), Color(0.6, 0.85, 1.0, 0.8))
			draw_rect(bag, OUT, false, 1.5)
		# cuerpo
		var body := PackedVector2Array([Vector2(-34, -44), Vector2(34, -44), Vector2(42, -150), Vector2(-42, -150)])
		draw_colored_polygon(body, WHITE)
		draw_rect(Rect2(-34, -76, 68, 30), TEAL)
		draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), OUT, 2.5)
		# hombreras con cruz roja
		for s in [-1.0, 1.0]:
			_box(Rect2(46 * s - 14, -162, 28, 22), WHITE)
		draw_rect(Rect2(-50, -156, 8, 3), RED)
		draw_rect(Rect2(-47.5, -158.5, 3, 8), RED)
		# estetoscopio
		draw_arc(Vector2(0, -150), 22, 0.3, PI - 0.3, 16, Color(0.35, 0.35, 0.4), 3.0)
		draw_circle(Vector2(14, -126), 5, GREY)
		if dirty:
			draw_circle(Vector2(-20, -60), 7, Color(0.5, 0.45, 0.35, 0.6))
			draw_circle(Vector2(22, -96), 5, Color(0.5, 0.45, 0.35, 0.6))
			draw_line(Vector2(-30, -140), Vector2(-18, -120), OUT, 1.5)

	func _heart() -> void:
		# ventana de costillas de vidrio
		var r := Rect2(-22, -24, 44, 48)
		draw_rect(r, Color(0.15, 0.2, 0.22))
		var beat := pulse
		var s := 1.0 + 0.22 * beat + (0.12 if open else 0.0)
		var col := Color(0.35, 0.35, 0.38) if dead else (Color(1.0, 0.45, 0.2) if open else RED)
		if open and not dead:
			col = col.lerp(Color(1, 0.9, 0.5), 0.3 * absf(sin(t * 12.0)))
		draw_set_transform(anim_off, 0.0, Vector2(s, s))
		draw_circle(Vector2(-6, -4), 9, col)
		draw_circle(Vector2(6, -4), 9, col)
		draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(0, 16)]), col)
		draw_line(Vector2(-4, -12), Vector2(-6, -20), GREY, 3.0)
		draw_line(Vector2(5, -12), Vector2(8, -20), GREY, 3.0)
		draw_set_transform(anim_off, 0.0, Vector2.ONE)
		# costillas: se abren hacia los lados cuando está expuesto
		var spread := 14.0 if open else 0.0
		for i in 4:
			var y := -18.0 + i * 11.0
			draw_line(Vector2(-22 - spread, y), Vector2(-4 - spread, y + 3), Color(0.85, 0.95, 1.0, 0.8), 3.0)
			draw_line(Vector2(22 + spread, y), Vector2(4 + spread, y + 3), Color(0.85, 0.95, 1.0, 0.8), 3.0)
		draw_rect(r, OUT, false, 2.0)
		if open and not dead:
			draw_rect(r.grow(4.0 + 2.0 * sin(t * 12.0)), Color(1, 0.6, 0.3, 0.9), false, 2.0)
		if sparks and not dead and randf() < 0.2:
			var p := Vector2(randf_range(-20, 20), randf_range(-22, 22))
			draw_line(p, p + Vector2(randf_range(-6, 6), randf_range(-6, 6)), Color(1, 1, 0.6), 2.0)

	func _head() -> void:
		# monitor
		_box(Rect2(-32, -26, 64, 50), Color(0.82, 0.85, 0.86), 2.5)
		var scr := Rect2(-26, -20, 52, 36)
		var bg := Color(0.05, 0.25, 0.65) if blue else Color(0.02, 0.08, 0.04)
		draw_rect(scr, bg)
		if face != "":
			var fs := 13 if face.length() <= 4 else 9
			draw_string(ThemeDB.fallback_font, Vector2(-26, -2 + fs * 0.35), face, HORIZONTAL_ALIGNMENT_CENTER, 52, fs, face_color)
		elif blue:
			draw_string(ThemeDB.fallback_font, Vector2(-26, 2), ":(", HORIZONTAL_ALIGNMENT_CENTER, 52, 16, Color.WHITE)
		else:
			_mini_ecg(scr)
		# gorro de cirujano y espejo frontal
		draw_colored_polygon(PackedVector2Array([Vector2(-30, -26), Vector2(30, -26), Vector2(24, -40), Vector2(-24, -40)]), TEAL)
		draw_polyline(PackedVector2Array([Vector2(-30, -26), Vector2(-24, -40), Vector2(24, -40), Vector2(30, -26)]), OUT, 2.0)
		draw_circle(Vector2(0, -36), 7, Color(0.85, 0.88, 0.92))
		draw_circle(Vector2(0, -36), 3, Color(0.4, 0.45, 0.5))
		draw_arc(Vector2(0, -36), 7, 0, TAU, 14, OUT, 1.5)
		# mascarilla
		if mask:
			var m := PackedVector2Array([Vector2(-26, 2), Vector2(26, 2), Vector2(22, 16), Vector2(-22, 16)])
			draw_colored_polygon(m, Color(0.75, 0.88, 0.9))
			for i in 3:
				draw_line(Vector2(-20, 6 + i * 3.5), Vector2(20, 6 + i * 3.5), Color(0.55, 0.7, 0.72), 1.0)
			draw_line(Vector2(-26, 4), Vector2(-32, -4), Color(0.9, 0.9, 0.92), 1.5)
			draw_line(Vector2(26, 4), Vector2(32, -4), Color(0.9, 0.9, 0.92), 1.5)
		draw_rect(Rect2(-6, 24, 12, 8), Color(0.6, 0.62, 0.65))

	func _mini_ecg(scr: Rect2) -> void:
		var pts := PackedVector2Array()
		var mid := scr.position.y + scr.size.y * 0.45
		var sb: float = boss.call("since_beat") if boss else 1.0
		var alive: bool = boss.call("is_alive") if boss else false
		var k := scr.size.y / 36.0
		for i in 26:
			var x := scr.position.x + 1 + i * (scr.size.x - 2.0) / 25.0
			var y := mid
			if alive and not flat:
				var ph := sb * 4.0 - (25 - i) * 0.03
				if ph > 0.0 and ph < 0.08:
					y -= 12.0 * k * 1.4
				elif ph >= 0.08 and ph < 0.14:
					y += 5.0 * k * 1.4
			pts.append(Vector2(x, y))
		draw_polyline(pts, Color(0.4, 1.0, 0.5), 1.5)

	func _brain() -> void:
		draw_rect(Rect2(-12, -14, 24, 26), Color(0.8, 0.95, 1.0, 0.5))
		var c := Color(1.0, 0.6, 0.8) if not glow else Color(1.0, 0.75, 1.0).lerp(Color.WHITE, 0.3 * absf(sin(t * 10.0)))
		draw_circle(Vector2(-4, 0), 7, c)
		draw_circle(Vector2(4, 0), 7, c)
		draw_arc(Vector2(-4, 0), 4, 0.5, 3.0, 6, Color(0.8, 0.4, 0.55), 1.5)
		draw_arc(Vector2(4, 0), 4, 0.2, 2.6, 6, Color(0.8, 0.4, 0.55), 1.5)
		draw_rect(Rect2(-13, -17, 26, 5), GREY)
		draw_rect(Rect2(-12, -14, 24, 26), OUT, false, 1.5)
		if glow:
			draw_circle(Vector2.ZERO, 22, Color(1, 0.6, 1.0, 0.18))

	func _scalpel() -> void:
		draw_circle(Vector2.ZERO, 11, GREY)
		_box(Rect2(-6, 0, 12, 50), WHITE)
		draw_circle(Vector2(0, 50), 7, GREY)
		_box(Rect2(-4, 50, 8, 40), Color(0.75, 0.78, 0.8))
		_box(Rect2(-6, 88, 12, 8), TEAL_D)
		if saw:
			draw_circle(Vector2(0, 104), 12, Color(0.8, 0.82, 0.85))
			for i in 8:
				var d := Vector2.from_angle(t * 20.0 + TAU * i / 8.0)
				draw_line(Vector2(0, 104) + d * 12.0, Vector2(0, 104) + d * 15.0, Color(0.8, 0.82, 0.85), 2.0)
		elif blade:
			draw_rect(Rect2(-3, 96, 6, 48), Color(1.0, 0.3, 0.3, 0.85))
			draw_rect(Rect2(-1, 96, 2, 48), Color(1, 0.9, 0.9))
			draw_rect(Rect2(-6, 94, 12, 52), Color(1, 0.2, 0.2, 0.2))
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 96), Vector2(3, 96), Vector2(0, 108)]), Color(0.85, 0.88, 0.9))
		draw_arc(Vector2.ZERO, 11, 0, TAU, 14, OUT, 2.0)

	func _tool() -> void:
		draw_circle(Vector2.ZERO, 13, GREY)
		_box(Rect2(-9, 0, 18, 54), WHITE)
		draw_rect(Rect2(-9, 20, 18, 8), TEAL)
		draw_circle(Vector2(0, 54), 8, GREY)
		match tool:
			0:   # jeringa gigante
				_box(Rect2(-9, 58, 18, 36), Color(0.85, 0.95, 1.0))
				draw_rect(Rect2(-7, 70, 14, 22), Color(0.3, 0.55, 1.0))
				draw_line(Vector2(0, 94), Vector2(0, 116), Color(0.8, 0.82, 0.86), 2.0)
			1:   # taladro dental
				_box(Rect2(-7, 58, 14, 30), Color(0.75, 0.78, 0.82))
				var spin := fmod(t * 30.0, 6.0)
				for i in 4:
					var y := 88.0 + i * 6.0
					draw_line(Vector2(-5 + i, y + spin * 0.2), Vector2(5 - i, y + 3 + spin * 0.2), Color(0.9, 0.9, 0.95), 2.0)
				draw_colored_polygon(PackedVector2Array([Vector2(-2, 110), Vector2(2, 110), Vector2(0, 118)]), Color(0.9, 0.9, 0.95))
			_:   # pinza
				for s in [-1.0, 1.0]:
					draw_line(Vector2(0, 60), Vector2(12 * s, 80), GREY, 4.0)
					draw_line(Vector2(12 * s, 80), Vector2(6 * s, 96), GREY, 4.0)
		draw_arc(Vector2.ZERO, 13, 0, TAU, 14, OUT, 2.0)

	func _sheet() -> void:
		var pts := PackedVector2Array([Vector2(-72, -46), Vector2(-60, -74), Vector2(-20, -84), Vector2(10, -96), Vector2(40, -86), Vector2(66, -70), Vector2(74, -46)])
		draw_colored_polygon(pts, WHITE)
		pts.append(pts[0])
		draw_polyline(pts, OUT, 2.0)
		draw_line(Vector2(-30, -78), Vector2(-10, -60), Color(0.75, 0.78, 0.8), 1.5)
		draw_line(Vector2(20, -88), Vector2(30, -62), Color(0.75, 0.78, 0.8), 1.5)


## Luces de la arena: blanco normal, rojo en urgencias, azul en paro. Laten con el corazón.
class Lights extends Node2D:
	var arena := Rect2()
	var color := Color(1, 1, 1, 0)
	var target := Color(1, 1, 1, 0)
	var _flash := Color(0, 0, 0, 0)
	var _pulse := 0.0

	func _ready() -> void:
		z_index = 15
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func pulse() -> void:
		_pulse = 1.0

	func flash(c: Color) -> void:
		_flash = c

	func _process(delta: float) -> void:
		color = color.lerp(target, minf(1.0, delta * 2.0))
		_pulse = maxf(0.0, _pulse - delta * 3.0)
		_flash.a = maxf(0.0, _flash.a - delta * 1.6)
		queue_redraw()

	func _draw() -> void:
		var r := arena.grow(200.0)
		if color.a > 0.005:
			draw_rect(r, Color(color.r, color.g, color.b, color.a * (0.7 + 0.6 * _pulse)))
		if _flash.a > 0.005:
			draw_rect(r, _flash)


## Monitor de signos vitales: reemplaza la barra de vida (línea de ECG, BPM, vida).
class EcgPanel extends Control:
	var boss: Node
	var _samples: Array[float] = []
	var _chip := 1.0

	func _ready() -> void:
		size = Vector2(600, 74)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 300:
			_samples.append(0.0)

	func _wave(s: float) -> float:
		# P, QRS y T simplificados (s = segundos desde el latido)
		if s < 0.05:
			return -0.15 * sin(s / 0.05 * PI)
		if s < 0.07:
			return 0.15
		if s < 0.1:
			return -1.0
		if s < 0.13:
			return 0.45
		if s > 0.2 and s < 0.32:
			return -0.25 * sin((s - 0.2) / 0.12 * PI)
		return 0.0

	func _process(_delta: float) -> void:
		var v := 0.0
		if boss and is_instance_valid(boss) and boss.call("is_alive"):
			v = _wave(boss.call("since_beat"))
			if boss.call("is_arrhythmic"):
				v = randf_range(-0.7, 0.7)
		_samples.pop_front()
		_samples.append(v)
		if boss and is_instance_valid(boss):
			var k: float = float(boss.get("hp")) / float(boss.get("MAX_HP"))
			_chip = maxf(k, _chip - 0.004) if _chip > k else k
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.01, 0.05, 0.03, 0.88))
		for i in 13:
			draw_line(Vector2(i * 50.0, 16), Vector2(i * 50.0, 58), Color(0.1, 0.3, 0.15, 0.6), 1.0)
		for j in 4:
			draw_line(Vector2(0, 16 + j * 14.0), Vector2(600, 16 + j * 14.0), Color(0.1, 0.3, 0.15, 0.6), 1.0)
		var pts := PackedVector2Array()
		for i in _samples.size():
			pts.append(Vector2(i * 2.0, 40.0 + _samples[i] * 20.0))
		var col := Color(0.4, 1.0, 0.5)
		if boss and is_instance_valid(boss):
			if boss.get("phase") == 2:
				col = Color(1.0, 0.75, 0.3)
			elif boss.get("phase") == 3:
				col = Color(0.5, 0.75, 1.0)
		draw_polyline(pts, col, 2.0)
		draw_circle(pts[pts.size() - 1], 3.0, Color.WHITE)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(6, 13), "B.S.O.D.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.5, 0.45))
		if boss and is_instance_valid(boss):
			var txt := "Fase %d/3   %s BPM" % [boss.get("phase"), boss.call("bpm_text")]
			draw_string(f, Vector2(594 - f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, 13), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
			var k: float = float(boss.get("hp")) / float(boss.get("MAX_HP"))
			draw_rect(Rect2(0, 64, 600, 8), Color(0.15, 0.15, 0.15, 0.9))
			draw_rect(Rect2(0, 64, 600 * _chip, 8), Color(1, 0.95, 0.85))
			draw_rect(Rect2(0, 64, 600 * k, 8), Color(0.85, 0.2, 0.25))
			for fr in [0.6, 0.3]:
				draw_rect(Rect2(600 * fr - 1, 64, 2, 8), Color(0, 0, 0, 0.8))
		draw_rect(r, Color(0.3, 0.6, 0.4, 0.8), false, 1.5)


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
		draw_rect(box, Color(0.02, 0.04, 0.03, 0.85 * a))
		draw_rect(box, Color(col.r, col.g, col.b, a), false, 2.0)
		draw_string(f, Vector2(-w * 0.5, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, a))


## Paleta del desfibrilador en la punta del brazo (duelo final): placa azul con rayos que crecen al cargar.
class Paddle extends Node2D:
	var charge := 0.0
	var t := 0.0
	var _zap := 0.0

	func _ready() -> void:
		z_index = 3

	func zap() -> void:
		_zap = 1.0

	func _process(delta: float) -> void:
		t += delta
		_zap = maxf(0.0, _zap - delta * 5.0)
		queue_redraw()

	func _draw() -> void:
		var glow := 0.4 + 0.6 * charge
		draw_circle(Vector2.ZERO, 22.0 + 10.0 * _zap, Color(0.4, 0.7, 1.0, 0.15 * glow + 0.3 * _zap))
		draw_rect(Rect2(-14, -6, 28, 12), Color(0.85, 0.9, 1.0))
		draw_rect(Rect2(-14, -6, 28, 12), Color(0.2, 0.35, 0.7), false, 2.0)
		draw_rect(Rect2(-11, -3, 22, 6), Color(0.5, 0.8, 1.0, glow))
		var n := 2 + int(charge * 3.0) + (3 if _zap > 0.1 else 0)
		for i in n:
			var a := randf() * TAU
			var p0 := Vector2.from_angle(a) * 10.0
			var p1 := p0 + Vector2.from_angle(a + randf_range(-0.6, 0.6)) * randf_range(10.0, 26.0 + 16.0 * _zap)
			var mid := (p0 + p1) * 0.5 + Vector2(randf_range(-5, 5), randf_range(-5, 5))
			draw_polyline(PackedVector2Array([p0, mid, p1]), Color(0.75, 0.9, 1.0, 0.9), 1.5)


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


