extends CharacterBody2D
## Boss 9 SUDO, "El Líder del Club IA" (sin facultad: en el Salón aparece como "Club IA").
## El único boss humano: un expositor con clicker y una pantalla de proyector flotando detrás,
## que pelea con las tecnologías que presenta en sus charlas.
## Lo único: LA VENTANA DE CONTEXTO. Cada ataque suyo y, sobre todo, cada parry tuyo le suma tokens.
## Al llenarse: CONTEXT OVERFLOW, queda aturdido unos segundos con daño x2 y luego se "compacta".
##   Fase 1 Supabase + Cursor (rayos verdes, Tab Tab Tab, Cmd+K, agentes).
##   Fase 2 Grokbot + Clerk (bots que generan, login, sesión, 2FA, acceso revocado). ALUCINA: 1 de cada 4 ataques es falso.
##   Fase 3 Terra, Luna y Sol orbitándolo; cada astro que ataca suma tokens. Golpear un astro lo apaga 6 s.
## Duelo final ASTRA: cinemática con QTE (rodar, parry, machacar ataque). Fallar = muerte instantánea del jugador.
## Remate: su propio Astra le vuelve encima y se desvanece en polvo de estrellas.
## Sprites: hojas de 8 poses de grokbot recortadas con tools/slice_sudo_sheets.py en assets/sprites/bosses/sudo/.
## El cuerpo cambia de POSE (no se arma por piezas): pose_name() la elige según lo que esté haciendo
## (pistas con _hint(), brazos invisibles que siguen girando como antes, estado y ánimo).
## Si faltan los PNG, todo vuelve al dibujo por código.
## Sin class_name: cargar con preload.

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Barrage := preload("res://scripts/combat/boss_barrage.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Fx := preload("res://scripts/combat/boss_sudo_fx.gd")
const Final := preload("res://scripts/combat/boss_final.gd")
const Roar := preload("res://scripts/combat/boss_roar.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")

signal hp_changed(hp: int, max_hp: int)
signal phase_changed(phase: int, title: String)
signal stunned
signal staggered
signal intro_finished
signal defeated

const MAX_HP := 96
const PHASE_AT := [0.6, 0.3]
const MOVE_SPEED := 85.0
const KEEP_DIST := 240.0
const PAUSE := [1.1, 0.9, 0.75]
const POISE := [9, 12, 15]
const ENRAGE_AT := 0.12
const PHASE_NAMES := ["DEMO EN VIVO", "AGENTES Y AUTENTICACIÓN", "TERRA · LUNA · SOL"]
## Diapositiva de cada fase: [título, subtítulo]
const SLIDES := [["DEMO EN VIVO", "Supabase + Cursor"], ["AGENTES + AUTH", "Grokbot · Clerk"], ["GPT", "Terra · Luna · Sol"]]
const POOL := {
	1: ["bolt", "realtime", "rls", "edge", "tab", "cmdk", "agent"],
	2: ["gen", "imagine", "tasks", "login", "session", "twofa", "revoke", "bolt", "tab"],
	3: ["moons", "eclipse", "quake", "orbit", "flare", "nova", "tab", "bolt"],
}
const COMBOS := {
	1: [["tab", "bolt"], ["cmdk", "edge"]],
	2: [["login", "tasks"], ["imagine", "session"], ["gen", "bolt"]],
	3: [["quake", "flare"], ["eclipse", "moons"], ["orbit", "nova"]],
}
## Nombre en pantalla de cada ataque.
const NAMES := {
	"bolt": "RAYO DE LA BASE", "realtime": "REALTIME", "rls": "ROW LEVEL SECURITY", "edge": "EDGE FUNCTION",
	"tab": "TAB, TAB, TAB", "cmdk": "CMD + K", "agent": "MODO AGENTE", "pulse": "¡DEPLOY!",
	"gen": "GROKBOT: GENERA", "imagine": "IMAGINE", "tasks": "LOTE DE TAREAS", "login": "INICIA SESIÓN",
	"session": "SESIÓN EXPIRADA", "twofa": "VERIFICACIÓN 2FA", "revoke": "ACCESO REVOCADO",
	"moons": "LLUVIA DE LUNAS", "eclipse": "ECLIPSE", "quake": "PLACAS TECTÓNICAS", "orbit": "ÓRBITA",
	"flare": "LLAMARADA SOLAR", "nova": "SUPERNOVA",
}
## Qué astro usa cada ataque de la fase 3 (si está apagado, no lo usa).
const PLANET_OF := {"moons": "luna", "eclipse": "luna", "quake": "terra", "orbit": "terra", "flare": "sol", "nova": "sol"}
## Alucinación (fase 2+): ataques que pueden salir falsos y cuáles no.
const FAKE_CHANCE := 0.25
const NO_FAKE := ["twofa", "revoke", "pulse"]

# La Ventana de Contexto
const CTX_MAX := [100.0, 100.0, 130.0]
const CTX_ATTACK := 12.0
const CTX_PARRY := 9.0
const CTX_PLANET := 8.0
const CTX_2FA := 35.0
const OVERFLOW_TIME := 3.2
const REVOKE_TIME := 5.0

# Geometría (pies en y 0)
const CENTER := Vector2(0, -100)
const SHOULDER_L := Vector2(-33, -124)
const SHOULDER_R := Vector2(33, -124)
const HEAD := Vector2(0, -170)
const ARM_LEN := 54.0
const REST_L := 0.15
const REST_R := -0.15
const SCREEN_POS := Vector2(-150, -262)

var hp: int = MAX_HP
var phase: int = 1
var state: String = "intro"
var arena_rect: Rect2 = Rect2(-500, -310, 1000, 620)
var player: CharacterBody2D
## Punto débil abierto (daño x2). Mismo nombre que en los otros bosses para que la arena y el HUD lo lean.
var tank_open: bool = false
var enraged: bool = false
## Ventana de contexto (tokens).
var context: float = 0.0
var overflow_left: float = 0.0
var hallucinating: bool = false
var final_victory: bool = false

var _fake := false
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
var _dashing := false
var _dash_hit := false
var _codes: Array = []
var _code_done := false
var _revoked := ""
var _revoke_n := 0
var _lock_icon: Node2D
var _key: Node2D
var _planets: Dictionary = {}       # kind -> Planet
var _planet_pin: Dictionary = {}    # kind -> posición local fija (alineación, eclipse)
var _orbit_a := 0.0
# cinemática ASTRA
var _cinema: Array = []
var _cam_tw: Tween
# poses (sprites)
var sprites := false
var _hint_pose := ""
var _hint_left := 0.0
var _pose_cur := ""
var _pose_since := 0.0
var _death_pose := ""
var dash_flip := false
## Fuerza una imagen concreta (la usa el generador de la estatua).
var pose_force := ""

var rig: Node2D
var body: Body
var arm_l: Arm
var arm_r: Arm
var screen: Screen
var _bubble: Bubble


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	z_index = 1
	collision_layer = 3
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(60, 20)
	shape.shape = r
	shape.position = Vector2(0, -10)
	add_child(shape)
	var hurt := Area2D.new()
	hurt.name = "Hurtbox"
	hurt.collision_layer = 2
	hurt.collision_mask = 0
	hurt.monitoring = false
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(84, 200)
	hs.shape = hr
	hs.position = Vector2(0, -100)
	hurt.add_child(hs)
	add_child(hurt)
	GameFeel.add_shadow(self, Vector2(0, -2), Vector2(40, 10))
	_build_rig()


func set_player(p: CharacterBody2D) -> void:
	player = p


func lock_point() -> Vector2:
	return global_position + Vector2(0, -110)


func ctx_max() -> float:
	return CTX_MAX[phase - 1]


## Poses: [imágenes, cuadros por segundo, true = en bucle / false = se queda en la última]
const ANIMS := {
	"idle": [["idle_0", "idle_1", "idle_2", "idle_3"], 3.5, true],
	"walk": [["walk_0", "walk_1", "walk_2", "walk_3"], 8.0, true],
	"raise": [["raise_0", "raise_1"], 9.0, false],
	"point": [["point_0", "point_1"], 3.0, true],
	"spread": [["spread_0", "spread_1"], 3.0, true],
	"summon": [["summon_0", "summon_1"], 3.0, true],
	"crouch": [["crouch_0"], 1.0, false],
	"dash": [["dash_0"], 1.0, false],
	"stomp": [["stomp_0"], 1.0, false],
	"wave": [["wave_0", "stand_0"], 4.0, true],
	"present": [["present_0"], 1.0, false],
	"think": [["think_0"], 1.0, false],
	"laugh": [["laugh_0", "stand_0"], 5.0, true],
	"stand": [["stand_0"], 1.0, false],
	"flinch": [["flinch_0", "flinch_1"], 7.0, false],
	"dizzy": [["dizzy_0", "dizzy_1"], 3.0, true],
	"kneel": [["kneel_0", "kneel_1"], 2.0, false],
	"fade": [["fade_0", "fade_1"], 1.4, false],
	# poses de poder (ronda épica de grokbot)
	"charge": [["charge_0"], 1.0, false],
	"shout": [["shout_0"], 1.0, false],
	"leap": [["leap_0"], 1.0, false],
	"slam": [["slam_0"], 1.0, false],
	"invoke": [["invoke_0"], 1.0, false],
	"throw": [["throw_0"], 1.0, false],
	"push": [["push_0"], 1.0, false],
	"victory": [["victory_0", "laugh_0"], 2.5, true],
}
## Si faltan las poses de poder (hojas viejas), se usan estas.
const POSE_FALLBACK := {"charge": "crouch", "shout": "laugh", "leap": "dash", "slam": "stomp", "invoke": "summon", "throw": "point", "push": "point", "victory": "laugh"}
## Poses que tiemblan de tensión (cargar, gritar, forcejear).
const TREMBLE := ["charge", "shout", "push"]
## Poses en el aire: se dibujan un poco más arriba.
const AIR := {"leap": -18.0}
## Dónde queda la mano del clicker en cada pose (pies en 0); sirve para que salgan de ahí los rayos y el clicker.
const HAND := {
	"idle": Vector2(-38, -140), "walk": Vector2(-34, -132), "raise": Vector2(-30, -232), "point": Vector2(-14, -150),
	"spread": Vector2(-70, -136), "summon": Vector2(-40, -228), "flinch": Vector2(-52, -116), "dizzy": Vector2(-40, -92),
	"charge": Vector2(-36, -96), "shout": Vector2(-40, -118), "leap": Vector2(-52, -124), "slam": Vector2(-6, -8),
	"invoke": Vector2(-40, -232), "throw": Vector2(-2, -148), "push": Vector2(-6, -142), "victory": Vector2(-38, -214),
}


static func has_sprites() -> bool:
	return Spr.tex("boss_sudo_idle_0") != null


## Pista de pose por unos segundos (tiene prioridad sobre lo que dicen los brazos).
func _hint(pose: String, time: float) -> void:
	_hint_pose = pose
	_hint_left = time


## Qué pose toca ahora.
func pose_name() -> String:
	if state == "dead":
		return _death_pose if _death_pose != "" else "fade"
	if _hint_left > 0.0 and _hint_pose != "":
		return _hint_pose
	if body and body.mood == 3:
		return "dizzy"
	if state == "stunned":
		return "flinch"
	if _dashing:
		return "leap" if Spr.tex("boss_sudo_leap_0") else "dash"
	var l := arm_l.rotation
	var r := -arm_r.rotation
	var up_l := l > 1.9
	var up_r := r > 1.9
	if up_l and up_r:
		return "summon"
	if up_l or up_r:
		return "raise"
	if l > 0.9 and r > 0.9:
		return "spread"
	if l > 0.9 or r > 0.9:
		return "point"
	if body and body.walk_speed > 0.1:
		return "walk"
	return "idle"


## Nombre de la imagen de la pose actual (sin el prefijo boss_sudo_).
func pose_frame() -> String:
	if pose_force != "":
		return pose_force
	var p := pose_name()
	if p != _pose_cur:
		_pose_cur = p
		_pose_since = _t
	var a: Array = ANIMS.get(p, ANIMS["idle"])
	if Spr.tex("boss_sudo_" + str(a[0][0])) == null and POSE_FALLBACK.has(p):
		a = ANIMS[POSE_FALLBACK[p]]
	var frames: Array = a[0]
	var i := int((_t - _pose_since) * float(a[1]))
	i = i % frames.size() if bool(a[2]) else mini(i, frames.size() - 1)
	return str(frames[i])


func pose_flipped() -> bool:
	return (_pose_cur == "dash" or _pose_cur == "leap") and dash_flip


func _build_rig() -> void:
	sprites = has_sprites()
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)
	screen = Screen.new()
	screen.boss = self
	screen.position = SCREEN_POS
	rig.add_child(screen)
	body = Body.new()
	body.boss = self
	rig.add_child(body)
	arm_l = Arm.new()
	arm_l.side = -1
	arm_l.position = SHOULDER_L
	arm_l.rotation = REST_L
	rig.add_child(arm_l)
	arm_r = Arm.new()
	arm_r.side = 1
	arm_r.position = SHOULDER_R
	arm_r.rotation = REST_R
	rig.add_child(arm_r)
	if sprites:
		# con sprites los brazos ya vienen en cada pose: siguen girando (invisibles) para elegir la pose
		arm_l.sprite_mode = true
		arm_r.sprite_mode = true
		body.use_parent_material = true
	_bubble = Bubble.new()
	_bubble.position = Vector2(46, -236)
	rig.add_child(_bubble)
	_slide()


func _say(text: String, col: Color = Color(0.2, 0.8, 0.55), time: float = 1.1) -> void:
	if _bubble:
		_bubble.show_text(text, col, time)


func _slide() -> void:
	var s: Array = SLIDES[phase - 1]
	screen.show_slide(str(s[0]), str(s[1]), phase)


# --- Bucle ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_hint_left = maxf(0.0, _hint_left - delta)
	if state != "dead":
		var bob := sin(_t * 2.0) * 1.5
		rig.position = rig_off + Vector2(0, bob)
		if _player_ok():
			var d := _player_body() - (global_position + HEAD)
			body.look = body.look.lerp(Vector2(clampf(d.x / 120.0, -1.0, 1.0), clampf(d.y / 200.0, -1.0, 1.0)), minf(1.0, delta * 6.0))
		if state == "idle":
			arm_l.anim = sin(_t * 1.6) * 0.06
			arm_r.anim = sin(_t * 1.6 + 1.3) * 0.06
		else:
			arm_l.anim = 0.0
			arm_r.anim = 0.0
		if enraged and state != "final":
			var k := 0.8 + 0.2 * absf(sin(_t * 8.0))
			rig.modulate = Color(1.0, k, k * 0.75)
		elif state != "final":
			rig.modulate = Color.WHITE
		if overflow_left > 0.0:
			overflow_left -= delta
		_update_planets(delta)
	if _player_ok():
		z_index = 3 if _player_feet().y < global_position.y else 1
	if _dashing:
		for v in _victims():
			_victim = v
			if _player_body().distance_to(global_position + Vector2(0, -60)) < 52.0 and CoopBoss.once(self, "dash%d" % _tok, v):
				_dash_hit = true
				hurt_player(2, global_position + Vector2(0, -60), false)
		_victim = null
	match state:
		"idle":
			_ai_move(delta)
			if _player_ok() and _player_feet().distance_to(global_position) < 140.0:
				_near_t += delta
			else:
				_near_t = maxf(0.0, _near_t - delta)
			_cd -= delta
			if _cd <= 0.0:
				_choose_attack()
		_:
			if not _dashing:
				velocity = Vector2.ZERO
			body.walk_speed = 0.0 if not _dashing else 2.0


func _ai_move(_delta: float) -> void:
	if not _player_ok():
		return
	var to := player.global_position - global_position
	var dist := to.length()
	var dir := Vector2.ZERO
	if dist > KEEP_DIST + 30.0:
		dir = to.normalized()
	elif dist < KEEP_DIST - 90.0:
		dir = -to.normalized() * 0.7
	velocity = dir * MOVE_SPEED * (1.0 + 0.15 * (phase - 1))
	move_and_slide()
	body.walk_speed = clampf(velocity.length() / 60.0, 0.0, 1.5)
	rig.skew = lerpf(rig.skew, clampf(velocity.x / 900.0, -0.05, 0.05), 0.1)
	_clamp_inside()


func _clamp_inside() -> void:
	global_position.x = clampf(global_position.x, arena_rect.position.x + 80.0, arena_rect.end.x - 80.0)
	global_position.y = clampf(global_position.y, arena_rect.position.y + 300.0, arena_rect.end.y - 30.0)


func _choose_attack() -> void:
	CoopBoss.retarget(self)
	var pick := ""
	if not _queue.is_empty():
		pick = _queue.pop_front()
	elif _near_t > 1.3:
		pick = "pulse"
	elif randf() < (0.25 if phase == 1 else 0.35):
		var list: Array = COMBOS[phase]
		_queue.assign(list[randi() % list.size()])
		pick = _queue.pop_front()
	else:
		var bag: Array[String] = []
		for a in POOL[phase]:
			if a != _last and _can_use(a):
				bag.append(a)
		pick = bag[randi() % bag.size()] if not bag.is_empty() else "bolt"
	if not _can_use(pick):
		pick = "tab" if _last != "tab" else "bolt"
	_near_t = 0.0
	_last = pick
	_tok += 1
	state = "attack"
	velocity = Vector2.ZERO
	_fake = phase >= 2 and not NO_FAKE.has(pick) and randf() < FAKE_CHANCE
	hallucinating = _fake
	screen.fake = _fake
	_say(str(NAMES.get(pick, pick.to_upper())), Color(0.55, 0.6, 0.75) if _fake else _accent(), 1.0)
	call("_atk_" + pick, _tok)


func _can_use(a: String) -> bool:
	if PLANET_OF.has(a):
		return _planet_ok(str(PLANET_OF[a]))
	if a == "twofa" and not _codes.is_empty():
		return false
	if a == "revoke" and _revoked != "":
		return false
	return true


func _accent() -> Color:
	return [Color(0.15, 0.7, 0.45), Color(0.45, 0.32, 0.9), Color(0.95, 0.55, 0.15)][phase - 1]


func _end_attack(tok: int, ctx: float = CTX_ATTACK) -> void:
	if tok != _tok:
		return
	state = "idle"
	_rest_pose()
	_rest_arms()
	body.mood = 0
	_fake = false
	screen.fake = false
	hallucinating = false
	_cd = PAUSE[phase - 1] * (0.6 if enraged else 1.0)
	if not _queue.is_empty():
		_cd = 0.25
	_add_ctx(ctx)


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


func _clamp_arena(p: Vector2, margin: float = 30.0) -> Vector2:
	return Vector2(clampf(p.x, arena_rect.position.x + margin, arena_rect.end.x - margin),
		clampf(p.y, arena_rect.position.y + margin + 10.0, arena_rect.end.y - margin * 0.7))


func _add_fx(n: Node2D, at: Vector2) -> void:
	if "boss" in n:
		n.set("boss", self)
	if "player" in n:
		n.set("player", player)
	if _fake and "fake" in n:
		n.set("fake", true)
		n.modulate = Color(0.75, 0.85, 1.0, 0.5)
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
	_tw(arm_l, "rotation", REST_L, 0.3)
	_tw(arm_r, "rotation", REST_R, 0.3)


func _point(arm: Arm, at: Vector2, time: float = 0.2) -> void:
	_tw(arm, "rotation", _rot_for((at - arm.global_position).normalized()), time)
	_hint("point", time + 0.4)


## Pulsa el clicker: destello en la mano y la pantalla parpadea.
func _click() -> void:
	arm_r.click = 0.25
	screen.flick = 0.2


func _hand_pos(arm: Arm) -> Vector2:
	if sprites and arm == arm_r:
		var p := pose_name()
		return global_position + rig_off + HAND.get(p, HAND["idle"])
	return arm.to_global(Vector2(0, ARM_LEN))


## Efectos épicos -------------------------------------------------------------------
func _fx(n: Node2D, at: Vector2) -> Node2D:
	get_parent().add_child(n)
	n.global_position = at
	return n


func _flash(col: Color, peak: float = 0.3, life: float = 0.35) -> void:
	var f := Fx.Flash.new()
	f.col = col
	f.peak = peak
	f.life = life
	get_parent().add_child(f)


func _charge(at: Vector2, col: Color, dur: float, radius: float = 120.0, follow: Node2D = null) -> void:
	var c := Fx.Charge.new()
	c.col = col
	c.dur = dur
	c.radius = radius
	if follow:
		c.follow = follow
		c.offset = at - follow.global_position
	_fx(c, at)


func _ring(at: Vector2, col: Color, r: float, life: float = 0.45, width: float = 10.0) -> void:
	var g := Fx.Ring.new()
	g.col = col
	g.max_r = r
	g.life = life
	g.width = width
	_fx(g, at)


## Efecto animado de la ronda épica (fxbolt, fxfire, fxcosmic, fxsun, fxdata). No hace nada si falta la hoja.
func _anim(prefix: String, at: Vector2, k: float, fps: float = 14.0, glow: Color = Color(0, 0, 0, 0), frames: Array = []) -> Node2D:
	if not Fx.Anim.ok(prefix):
		return null
	var a := Fx.Anim.new()
	a.prefix = prefix
	a.k = k
	a.fps = fps
	a.glow = glow
	if not frames.is_empty():
		a.frames = frames
	return _fx(a, at)


func _burst(at: Vector2, col: Color, count: int = 18, speed: float = 320.0) -> void:
	var b := Fx.Burst.new()
	b.col = col
	b.count = count
	b.speed = speed
	_fx(b, at)


## Golpe de cámara: zoom rápido hacia adentro y de vuelta (no durante la cinemática, que mueve el zoom).
func _cam_punch(amount: float = 0.06, time: float = 0.28) -> void:
	if not _player_ok() or state == "final":
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := cam.create_tween()
	tw.tween_property(cam, "zoom", Vector2.ONE * (1.0 + amount), time * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "zoom", Vector2.ONE, time * 0.75).set_trans(Tween.TRANS_SINE)


## Copia fantasma de la pose actual (estela de la embestida).
func _ghost(tint: Color) -> void:
	if not sprites:
		return
	var g := Fx.Ghost.new()
	g.tex = Spr.tex("boss_sudo_" + pose_frame())
	g.tint = tint
	g.flip = pose_flipped()
	_fx(g, global_position + rig_off)


func _impact(at: Vector2, strength: float) -> void:
	_shake(strength, 0.1 + strength * 0.03)
	GameFeel.dust(get_parent(), at, int(4 + strength), Vector2.ZERO, 5.0, Vector2(20 + strength * 3.0, 6))


func _interrupt() -> void:
	_tok += 1
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
	_queue.clear()
	_dashing = false
	velocity = Vector2.ZERO
	_fake = false
	hallucinating = false
	screen.fake = false
	_rest_pose(0.2)
	visible = true
	modulate.a = 1.0


func hurt_player(amount: int, from: Vector2, unblockable: bool = false) -> void:
	if not _player_ok() or state in ["dead", "paused"]:
		return
	_who().call("take_hit", amount, from, unblockable)


func _random_floor(min_from_player: float = 0.0) -> Vector2:
	for i in 12:
		var p := Vector2(randf_range(arena_rect.position.x + 60.0, arena_rect.end.x - 60.0), randf_range(arena_rect.position.y + 80.0, arena_rect.end.y - 40.0))
		if not _player_ok() or p.distance_to(_player_feet()) >= min_from_player:
			return p
	return arena_rect.get_center()


# --- La Ventana de Contexto -------------------------------------------------------

func _add_ctx(v: float) -> void:
	if state in ["final", "dead", "intro", "paused"]:
		return
	context = clampf(context + v, 0.0, ctx_max())
	if context >= ctx_max() and state in ["idle", "attack"]:
		_overflow.call_deferred()


## Lo llaman los peligros cuando el jugador les hace parry (le "inyecta" contexto).
func inject_context(_kind: String = "parry") -> void:
	_add_ctx(CTX_PARRY)


func _overflow() -> void:
	if not state in ["idle", "attack"]:
		return
	_interrupt()
	var tok := _tok
	state = "stunned"
	tank_open = true
	overflow_left = OVERFLOW_TIME
	screen.mode = "overflow"
	body.mood = 3
	_say("...¿qué estaba diciendo?", Color(0.9, 0.3, 0.3), 1.6)
	GameFeel.flash(rig, 0.25, Color(1, 0.4, 0.4))
	_shake(5.0, 0.3)
	_pose(Vector2(0, 10), 0.08, 0.25)
	_tw(arm_l, "rotation", 0.05, 0.3)
	_tw(arm_r, "rotation", -0.05, 0.3)
	stunned.emit()
	var tx := Final.StampSlam.new()
	tx.text = "CONTEXT OVERFLOW"
	tx.w = 300.0
	tx.col = Color(0.9, 0.2, 0.2)
	tx.life = 1.2
	get_parent().add_child(tx)
	tx.global_position = global_position + Vector2(0, -60)
	if not await _wait(OVERFLOW_TIME, tok):
		return
	# se "compacta": la ventana vuelve a 0
	tank_open = false
	screen.mode = "compact"
	body.mood = 1
	_say("Compactando contexto...", Color(0.5, 0.6, 0.75), 0.9)
	_hint("think", 0.75)
	_tw(self, "context", 0.0, 0.6)
	_rest_pose(0.3)
	_rest_arms()
	if not await _wait(0.7, tok):
		return
	context = 0.0
	screen.mode = "slide"
	body.mood = 0
	state = "idle"
	_cd = 0.6


# --- Fase 1: Supabase + Cursor ---------------------------------------------------------

## Rayo de la base: círculos verdes en el piso y rayos del techo (el primero, donde estás).
func _atk_bolt(tok: int) -> void:
	_tw(arm_r, "rotation", -PI * 0.85, 0.25)
	_pose(Vector2(0, -6), -0.03, 0.25)
	body.mood = 1
	_charge(global_position + HAND["raise"], Fx.GREEN_HI, 0.45, 110.0, self)
	_hint("charge", 0.25)
	if not await _wait(0.5, tok):
		return
	_click()
	_ring(_hand_pos(arm_r), Fx.GREEN_HI, 90.0, 0.3, 6.0)
	_flash(Fx.GREEN_HI, 0.12, 0.25)
	var n: int = [3, 4, 5][phase - 1] + (1 if enraged else 0)
	for i in n:
		if not _player_ok():
			return
		var at := _player_feet() if i == 0 else _player_feet() + Vector2.from_angle(randf() * TAU) * randf_range(70.0, 200.0)
		var b := Fx.Bolt.new()
		b.warn = 0.85
		_add_fx(b, _clamp_arena(at))
		if not await _wait(0.2, tok):
			return
	if not await _wait(0.9, tok):
		return
	_end_attack(tok)


## Realtime: tres tablas unidas por láseres que giran a tu alrededor.
func _atk_realtime(tok: int) -> void:
	_tw(arm_l, "rotation", PI * 0.55, 0.25)
	_tw(arm_r, "rotation", -PI * 0.55, 0.25)
	body.mood = 1
	if not await _wait(0.25, tok):
		return
	_click()
	var rt := Fx.Realtime.new()
	rt.radius = 190.0 + 20.0 * phase
	rt.spin = (0.65 + 0.15 * phase) * (1.0 if randf() < 0.5 else -1.0)
	rt.nodes = 3 if phase < 3 else 4
	_add_fx(rt, _clamp_arena(_player_feet(), 160.0) if _player_ok() else arena_rect.get_center())
	if not await _wait(1.8, tok):
		return
	_end_attack(tok)


## Row Level Security: el piso por filas; la tuya se enciende primero.
func _atk_rls(tok: int) -> void:
	_tw(arm_r, "rotation", -PI * 0.5, 0.2)
	if not await _wait(0.2, tok):
		return
	_click()
	var rows := Fx.Rows.new()
	rows.area = arena_rect
	rows.rows = 6
	rows.waves = [2, 3, 3][phase - 1]
	rows.warn = [0.8, 0.7, 0.6][phase - 1]
	if _player_ok():
		var h := arena_rect.size.y / rows.rows
		var row := clampi(int((_player_feet().y - arena_rect.position.y) / h), 0, rows.rows - 1)
		rows.start = row % 2
	_add_fx(rows, Vector2.ZERO)
	var total := rows.waves * (rows.warn + rows.zap + 0.15)
	if not await _wait(minf(total, 2.2), tok):
		return
	_end_attack(tok)


## Edge Function: bolas eléctricas desde los bordes que rebotan. Con parry vuelven hacia él.
func _atk_edge(tok: int) -> void:
	var n: int = [1, 2, 2][phase - 1]
	for i in n:
		if not _player_ok():
			return
		_point(arm_r, _player_body())
		_click()
		var side := randi() % 4
		var from := Vector2.ZERO
		match side:
			0: from = Vector2(randf_range(arena_rect.position.x, arena_rect.end.x), arena_rect.position.y + 20.0)
			1: from = Vector2(randf_range(arena_rect.position.x, arena_rect.end.x), arena_rect.end.y - 20.0)
			2: from = Vector2(arena_rect.position.x + 20.0, randf_range(arena_rect.position.y, arena_rect.end.y))
			_: from = Vector2(arena_rect.end.x - 20.0, randf_range(arena_rect.position.y, arena_rect.end.y))
		var ball := Fx.EdgeBall.new()
		ball.area = arena_rect
		ball.vel = (_player_body() - from).normalized() * (290.0 + 30.0 * phase)
		_add_fx(ball, from)
		if not await _wait(0.6, tok):
			return
	if not await _wait(0.4, tok):
		return
	_end_attack(tok)


## La bola devuelta llega a SUDO: le hace daño.
func edge_reflected(_ball: Node) -> void:
	if state in ["dead", "final", "intro", "transition"]:
		return
	GameFeel.parry_burst(get_parent(), global_position + CENTER, 40.0)
	_anim("fxdata", global_position + CENTER, 0.7, 16.0)
	take_hit(3, global_position + CENTER + Vector2(0, 40))


## Tab, Tab, Tab: un rastro de texto fantasma predice la embestida, y luego embiste por él.
func _atk_tab(tok: int) -> void:
	var n: int = [3, 3, 4][phase - 1]
	for i in n:
		if not _player_ok():
			return
		var target := _clamp_arena(player.global_position, 70.0)
		var from := global_position
		var trail := Fx.GhostTrail.new()
		trail.to = target - from
		trail.life = [0.75, 0.62, 0.52][phase - 1] + 0.2
		_add_fx(trail, from)
		_pose(Vector2(-8 * signf(target.x - from.x), 4), -0.12 * signf(target.x - from.x), 0.2)
		_tw(arm_r, "rotation", _rot_for((target - from).normalized()), 0.2)
		_tw(arm_l, "rotation", PI * 0.3, 0.2)
		_hint("crouch", [0.6, 0.5, 0.42][phase - 1])
		dash_flip = target.x < from.x
		_burst(global_position + Vector2(0, -20), Color(0.6, 0.8, 1.0), 10, 180.0)
		if not await _wait([0.6, 0.5, 0.42][phase - 1], tok):
			return
		# embestida
		var dist := from.distance_to(target)
		var dt := clampf(dist / 950.0, 0.12, 0.5)
		_dashing = not _fake
		_dash_hit = false
		_pose(Vector2(0, 6), 0.18 * signf(target.x - from.x), 0.06)
		var tw := _tw(self, "global_position", target, dt)
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		for k in 3:
			GameFeel.dust(get_parent(), from.lerp(target, k / 3.0), 2, Vector2.ZERO, 3.0)
		if i == n - 1 and not _fake:
			var sl := Fx.SpeedLines.new()
			sl.life = dt + 0.2
			sl.col = Color(0.8, 0.9, 1.0, 0.45)
			get_parent().add_child(sl)
		var gt := 0.0
		while gt < dt:
			_ghost(Color(0.45, 0.75, 1.0, 0.55))
			if not await _wait(0.03, tok):
				return
			gt += 0.03
		_dashing = false
		_clamp_inside()
		_impact(global_position, 3.0)
		_hint("slam" if i == n - 1 and not _fake else "stomp", 0.35 if i == n - 1 else 0.2)
		if not _fake:
			_ring(global_position, Color(0.55, 0.8, 1.0), 140.0, 0.3, 7.0)
			_burst(global_position + Vector2(0, -10), Color(0.7, 0.85, 1.0), 12, 260.0)
			if i == n - 1:
				_cam_punch(0.05)
				_anim("fxdata", global_position + Vector2(0, -30), 0.8, 16.0, Color(0.4, 0.6, 1.0, 0.2))
		if not await _wait(0.22, tok):
			return
	_end_attack(tok)


## Cmd+K: rectángulo de selección que te sigue y luego "reescribe" la zona.
func _atk_cmdk(tok: int) -> void:
	var n: int = 1 if phase == 1 else 2
	for i in n:
		if not _player_ok():
			return
		_point(arm_r, _player_body())
		_click()
		var s := Fx.Selection.new()
		s.follow = [1.0, 0.85, 0.75][phase - 1]
		s.lock = 0.4
		_add_fx(s, _player_feet() + Vector2(0, -20))
		if not await _wait(s.follow * 0.8, tok):
			return
	if not await _wait(0.8, tok):
		return
	_end_attack(tok)


## Modo agente: suelta flechitas-cursor que te persiguen y hacen clic.
func _atk_agent(tok: int) -> void:
	_tw(arm_l, "rotation", PI * 0.6, 0.2)
	_tw(arm_r, "rotation", -PI * 0.6, 0.2)
	if not await _wait(0.25, tok):
		return
	_click()
	var n := 2 + (1 if phase >= 2 else 0)
	for i in n:
		var c := Fx.CursorAgent.new()
		c.speed = 115.0 + 15.0 * phase
		_add_fx(c, global_position + Vector2((i - (n - 1) * 0.5) * 60.0, -150))
	if not await _wait(0.7, tok):
		return
	_end_attack(tok)


## Si te quedas pegado: pulso eléctrico verde alrededor (no se bloquea).
func _atk_pulse(tok: int) -> void:
	_pose(Vector2(0, -10), 0.0, 0.25)
	_tw(arm_l, "rotation", PI * 0.8, 0.25)
	_tw(arm_r, "rotation", -PI * 0.8, 0.25)
	var z := BossFx.TeleZone.new()
	z.half_angle = 0.0
	z.reach = 200.0
	z.life = 0.5
	_add_fx(z, global_position)
	if not await _wait(0.5, tok):
		return
	_pose(Vector2(0, 8), 0.0, 0.06)
	_tw(arm_l, "rotation", 0.4, 0.06)
	_tw(arm_r, "rotation", -0.4, 0.06)
	_hint("slam", 0.55)
	_ring(global_position, Fx.GREEN_HI, 250.0, 0.45, 12.0)
	_flash(Fx.GREEN_HI, 0.15, 0.25)
	_cam_punch(0.05)
	var ring := BossFx.ShockRing.new()
	ring.max_r = 240.0
	_add_fx(ring, global_position)
	var b := Fx.Bolt.new()
	b.warn = 0.01
	b.harmless = true
	b.r = 40.0
	_add_fx(b, global_position)
	_impact(global_position, 5.0)
	if not await _wait(0.5, tok):
		return
	_end_attack(tok, CTX_ATTACK * 0.5)


# --- Fase 2: Grokbot + Clerk ------------------------------------------------------

## Grokbot genera: robotitos que pintan bloques de píxeles y te los lanzan.
func _atk_gen(tok: int) -> void:
	_tw(arm_r, "rotation", -PI * 0.7, 0.2)
	if not await _wait(0.25, tok):
		return
	_click()
	var n := 2 if phase == 2 else 3
	for i in n:
		var g := Fx.Grokbot.new()
		var ang := (-0.6 if i % 2 == 0 else PI + 0.6) + randf_range(-0.3, 0.3)
		g.spot = _clamp_arena((_player_feet() if _player_ok() else arena_rect.get_center()) + Vector2(cos(ang), sin(ang) * 0.6) * 230.0, 50.0)
		g.every = 1.0 if not enraged else 0.75
		_add_fx(g, global_position + Vector2((i - 1) * 40.0, -10))
	if not await _wait(1.0, tok):
		return
	_end_attack(tok)


## Imagine: tu silueta dibujada en el piso cobra vida 1 s después donde estabas.
func _atk_imagine(tok: int) -> void:
	_tw(arm_l, "rotation", PI * 0.7, 0.2)
	for i in 3:
		if not _player_ok():
			return
		_click()
		var s := Fx.Silhouette.new()
		s.delay = 1.0
		_add_fx(s, _player_feet())
		if not await _wait(0.45, tok):
			return
	if not await _wait(0.8, tok):
		return
	_end_attack(tok)


## Lote de tareas: cada [x] que marca dispara una tarea hacia ti (parry al ritmo).
func _atk_tasks(tok: int) -> void:
	var panel := Fx.TaskPanel.new()
	var items := 5
	panel.life = 0.6 + items * 0.42 + 0.6
	_add_fx(panel, global_position + Vector2(130, -230))
	_tw(arm_r, "rotation", -PI * 0.6, 0.2)
	if not await _wait(0.6, tok):
		return
	for i in items:
		if not _player_ok() or not is_instance_valid(panel):
			return
		panel.done = i + 1
		_click()
		var from := panel.global_position + Vector2(0, 16 + i * 16)
		var s := Fx.PShot.new()
		s.kind = "task"
		s.vel = _dir_to_player(from) * (300.0 + 20.0 * phase)
		_add_fx(s, from)
		if not await _wait(0.42 if not enraged else 0.32, tok):
			return
	_end_attack(tok)


## Inicia sesión: muros con forma de formulario que cruzan la arena; solo se pasa por el hueco.
func _atk_login(tok: int) -> void:
	_tw(arm_l, "rotation", PI * 0.85, 0.2)
	_tw(arm_r, "rotation", -PI * 0.85, 0.2)
	if not await _wait(0.25, tok):
		return
	_click()
	var w := Fx.LoginWall.new()
	w.area = arena_rect
	var px := _player_feet().x if _player_ok() else 0.0
	w.gap = clampf(px + randf_range(-220.0, 220.0), arena_rect.position.x + 90.0, arena_rect.end.x - 90.0)
	w.speed = 165.0 + 15.0 * (phase - 2)
	_add_fx(w, Vector2.ZERO)
	if phase >= 3 or enraged or randf() < 0.4:
		if not await _wait(1.3, tok):
			return
		var v := Fx.LoginWall.new()
		v.area = arena_rect
		v.vertical = true
		var py := _player_feet().y if _player_ok() else 0.0
		v.gap = clampf(py + randf_range(-120.0, 120.0), arena_rect.position.y + 90.0, arena_rect.end.y - 90.0)
		_add_fx(v, Vector2.ZERO)
	if not await _wait(1.2, tok):
		return
	_end_attack(tok)


## Sesión expirada: anillo-candado alrededor tuyo con cuenta atrás.
func _atk_session(tok: int) -> void:
	_point(arm_r, _player_body() if _player_ok() else global_position)
	_click()
	var r := Fx.SessionRing.new()
	r.count = 2.4 if phase == 2 else 2.0
	_add_fx(r, _player_feet() if _player_ok() else arena_rect.get_center())
	if not await _wait(1.0, tok):
		return
	_end_attack(tok)


## 2FA: dos códigos flotando; golpea el que sale en su pantalla (le llena el contexto). El falso explota.
func _atk_twofa(tok: int) -> void:
	var good := "%06d" % (randi() % 1000000)
	var bad := good
	while bad == good:
		bad = "%06d" % (randi() % 1000000)
	screen.code = good
	screen.mode = "code"
	_click()
	_tw(arm_r, "rotation", -PI * 0.75, 0.2)
	_codes.clear()
	_code_done = false
	var base := _player_feet() if _player_ok() else arena_rect.get_center()
	var right_good := randf() < 0.5
	for i in 2:
		var c := Fx.Code.new()
		var is_good := (i == 1) == right_good
		c.code = good if is_good else bad
		c.correct = is_good
		c.life = 5.5 if phase == 2 else 4.5
		_add_fx(c, _clamp_arena(base + Vector2(-170.0 if i == 0 else 170.0, -40.0), 70.0))
		_codes.append(c)
	if not await _wait(1.0, tok):
		return
	_end_attack(tok)


func twofa_hit(c: Node) -> void:
	if not _codes.has(c):
		return
	if bool(c.get("correct")):
		_say("ACCESO CONCEDIDO", Color(0.3, 0.85, 0.45), 1.0)
		GameFeel.parry_burst(get_parent(), (c as Node2D).global_position, 30.0)
		_clear_codes()
		_add_ctx(CTX_2FA)
	else:
		_say("CÓDIGO INCORRECTO", Color(0.9, 0.3, 0.3), 1.0)
		var b := Fx.Boom.new()
		_add_fx(b, (c as Node2D).global_position + Vector2(0, 20))
		c.call("pop")
		_codes.erase(c)
		if _codes.is_empty():
			_clear_codes()


func twofa_timeout(_c: Node) -> void:
	_clear_codes()


func _clear_codes() -> void:
	for c in _codes:
		if is_instance_valid(c):
			c.call("pop")
	_codes.clear()
	if screen.mode == "code":
		screen.mode = "slide"


## Acceso revocado: lanza un candado (parry). Si te da, te bloquea K o la ultimate 5 s.
func _atk_revoke(tok: int) -> void:
	_tw(arm_r, "rotation", -PI * 0.8, 0.25)
	if not await _wait(0.35, tok):
		return
	if not _player_ok():
		return
	_click()
	var from := _hand_pos(arm_r)
	var s := Fx.PShot.new()
	s.kind = "lock"
	s.col = Fx.CLERK
	s.vel = _dir_to_player(from) * 330.0
	_add_fx(s, from)
	if not await _wait(0.8, tok):
		return
	_end_attack(tok)


## Te bloquea una habilidad (K o ultimate) y suelta una llave que la devuelve antes.
func revoke_player() -> void:
	if _revoked != "" or not _player_ok() or state in ["dead", "final"]:
		return
	var cc: Node = player.get("class_controller")
	if cc == null:
		return
	_revoke_n += 1
	var n := _revoke_n
	_revoked = "special" if randf() < 0.5 else "ultimate"
	var now := Time.get_ticks_msec() / 1000.0
	if _revoked == "special":
		cc.set("special_ready_at", maxf(float(cc.get("special_ready_at")), now + REVOKE_TIME))
	elif "ult_locked_until" in cc:
		cc.set("ult_locked_until", now + REVOKE_TIME)
	var icon := Fx.LockIcon.new()
	icon.life = REVOKE_TIME
	icon.label = GameState.btn("action_secondary" if _revoked == "special" else "ultimate") if GameState else "K"
	player.add_child(icon)
	_lock_icon = icon
	var k := Fx.Key.new()
	k.life = REVOKE_TIME
	_add_fx(k, _random_floor(260.0))
	_key = k
	_say("401 UNAUTHORIZED", Color(0.55, 0.4, 1.0), 1.2)
	await get_tree().create_timer(REVOKE_TIME).timeout
	if n == _revoke_n and _revoked != "":
		_revoked = ""


## La llave: devuelve la habilidad bloqueada.
func restore_player() -> void:
	if _revoked == "":
		return
	if _player_ok():
		var cc: Node = player.get("class_controller")
		if cc != null:
			var now := Time.get_ticks_msec() / 1000.0
			if _revoked == "special":
				cc.set("special_ready_at", minf(float(cc.get("special_ready_at")), now))
			elif "ult_locked_until" in cc:
				cc.set("ult_locked_until", 0.0)
	_revoked = ""
	if is_instance_valid(_lock_icon):
		_lock_icon.queue_free()
	if is_instance_valid(_key):
		_key.queue_free()


# --- Fase 3: Terra · Luna · Sol ---------------------------------------------------------

func _spawn_planets() -> void:
	if not _planets.is_empty():
		return
	for kind in ["terra", "luna", "sol"]:
		var p := Fx.Planet.new()
		p.kind = kind
		p.boss = self
		add_child(p)
		p.position = Vector2(0, -120)
		_planets[kind] = p
		var tw := create_tween()
		p.scale = Vector2.ZERO
		tw.tween_property(p, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _planet(kind: String) -> Node2D:
	var p: Variant = _planets.get(kind)
	return p if p != null and is_instance_valid(p) else null


func _planet_ok(kind: String) -> bool:
	var p := _planet(kind)
	return p != null and bool(p.call("active"))


func _update_planets(delta: float) -> void:
	if _planets.is_empty():
		return
	_orbit_a += delta * (0.9 if not enraged else 1.4)
	var kinds := ["terra", "luna", "sol"]
	for i in kinds.size():
		var p := _planet(kinds[i])
		if p == null:
			continue
		var want: Vector2
		if _planet_pin.has(kinds[i]):
			want = _planet_pin[kinds[i]]
		else:
			var a := _orbit_a + TAU * i / 3.0
			want = Vector2(0, -115) + Vector2(cos(a) * 125.0, sin(a) * 52.0)
		p.position = p.position.lerp(want, minf(1.0, delta * 6.0))
		# por delante o por detrás del cuerpo
		p.z_index = 4 if p.position.y > -115.0 else -1


func _planet_glow(kind: String) -> void:
	var p := _planet(kind)
	if p:
		p.set("glow", 1.0)
		GameFeel.flash(p, 0.15, Color(1, 1, 0.8))


## Golpear un astro lo apaga 6 s.
func planet_hit(p: Node) -> void:
	var nm: String = {"terra": "TERRA", "luna": "LUNA", "sol": "SOL"}.get(str(p.get("kind")), "?")
	_say("¡%s OFFLINE!" % nm, Color(0.9, 0.4, 0.3), 0.9)
	_add_ctx(4.0)


func _planet_pos(kind: String) -> Vector2:
	var p := _planet(kind)
	return p.global_position if p else global_position + Vector2(0, -150)


## Lluvia de lunas: medialunas rápidas en abanico que vuelven como boomerang.
func _atk_moons(tok: int) -> void:
	_planet_glow("luna")
	_tw(arm_l, "rotation", PI * 0.75, 0.2)
	if not await _wait(0.35, tok):
		return
	_hint("throw", 0.5)
	var from := _planet_pos("luna")
	var n := 8 if not enraged else 12
	var base := _dir_to_player(from).angle()
	for i in n:
		var s := Fx.PShot.new()
		s.kind = "moon"
		var a := base + (float(i) / (n - 1) - 0.5) * 1.3
		s.vel = Vector2.from_angle(a) * 330.0
		s.out_time = 0.95
		s.life = 3.5
		_add_fx(s, from)
	if not await _wait(1.2, tok):
		return
	_end_attack(tok, CTX_ATTACK + CTX_PLANET)


## Eclipse: la Luna tapa al Sol y la arena queda a oscuras; caen lunas y rayos.
func _atk_eclipse(tok: int) -> void:
	_planet_pin["sol"] = Vector2(0, -290)
	_planet_pin["luna"] = Vector2(0, -290)
	_tw(arm_l, "rotation", PI * 0.9, 0.3)
	_tw(arm_r, "rotation", -PI * 0.9, 0.3)
	if not await _wait(0.6, tok):
		_planet_pin.clear()
		return
	var sky := global_position + Vector2(0, -290)
	_hint("invoke", 3.8)
	_ring(sky, Color(0.85, 0.9, 1.0), 160.0, 0.6, 8.0)
	_burst(sky + Vector2(16, -14), Color(1, 1, 1), 14, 220.0)
	_flash(Color(1, 1, 1), 0.35, 0.3)
	var e := Fx.Eclipse.new()
	e.life = 4.5
	_add_fx(e, _player_body() if _player_ok() else global_position)
	for k in 2:
		if not await _wait(1.1, tok):
			_planet_pin.clear()
			return
		if not _player_ok():
			break
		var from := _planet_pos("luna")
		var base := _dir_to_player(from).angle()
		for i in 6:
			var s := Fx.PShot.new()
			s.kind = "moon"
			s.vel = Vector2.from_angle(base + (i / 5.0 - 0.5) * 0.9) * 290.0
			s.out_time = 1.1
			_add_fx(s, from)
	if not await _wait(0.8, tok):
		_planet_pin.clear()
		return
	for i in 3:
		var b := Fx.Bolt.new()
		b.warn = 0.8
		b.col = Color(0.75, 0.8, 1.0)
		_add_fx(b, _clamp_arena(_player_feet() + Vector2.from_angle(TAU * i / 3.0) * (0.0 if i == 0 else 110.0)))
	if not await _wait(1.0, tok):
		_planet_pin.clear()
		return
	_planet_pin.clear()
	_end_attack(tok, CTX_ATTACK + CTX_PLANET)


## Placas tectónicas: grietas desde la Tierra que levantan rocas (las rocas tapan la llamarada).
func _atk_quake(tok: int) -> void:
	_planet_glow("terra")
	_pose(Vector2(0, -8), 0.0, 0.2)
	_tw(arm_l, "rotation", PI * 0.85, 0.2)
	if _planet("terra"):
		_charge(_planet_pos("terra"), Color(1.0, 0.55, 0.2), 0.45, 100.0, _planet("terra"))
	_hint("charge", 0.5)
	if not await _wait(0.5, tok):
		return
	_pose(Vector2(0, 8), 0.0, 0.06)
	_tw(arm_l, "rotation", PI * 0.2, 0.06)
	_hint("slam", 0.55)
	_impact(global_position, 9.0)
	_ring(global_position, Color(1.0, 0.6, 0.25), 300.0, 0.5, 14.0)
	_flash(Color(1.0, 0.6, 0.3), 0.14, 0.3)
	_anim("fxfire", global_position + Vector2(0, -40), 0.85, 15.0, Color(1.0, 0.5, 0.1, 0.25))
	_cam_punch(0.07)
	var origin := global_position + Vector2(_planet(  "terra").position.x if _planet("terra") else 0.0, 0)
	var n := 3 if not enraged else 5
	var base := (_player_feet() - origin).angle() if _player_ok() else PI * 0.5
	for i in n:
		var c := Fx.Crack.new()
		var a := base + (float(i) / maxf(1.0, n - 1) - 0.5) * 1.1
		var to := Vector2.from_angle(a) * 560.0
		to.y *= 0.7
		c.to = _clamp_arena(origin + to, 20.0) - origin
		c.warn = 0.8
		c.rocks = 1
		_add_fx(c, origin)
	if not await _wait(1.3, tok):
		return
	_end_attack(tok, CTX_ATTACK + CTX_PLANET)


## Órbita: la Tierra se separa y da una vuelta completa a ras del piso (parry la desvía).
func _atk_orbit(tok: int) -> void:
	var terra := _planet("terra")
	_planet_glow("terra")
	_point(arm_l, _player_body() if _player_ok() else global_position)
	if not await _wait(0.35, tok):
		return
	if terra:
		terra.visible = false
	var o := Fx.OrbitRock.new()
	o.center = global_position
	var rel := (_player_feet() - global_position) if _player_ok() else Vector2(200, 0)
	o.radius = clampf(Vector2(rel.x, rel.y / 0.6).length(), 140.0, 380.0)
	o.a0 = atan2(rel.y / 0.6, rel.x) - 1.6
	o.dur = 2.6 if not enraged else 2.0
	_add_fx(o, global_position)
	if not await _wait(o.dur, tok):
		if terra and is_instance_valid(terra):
			terra.visible = true
		return
	if terra and is_instance_valid(terra):
		terra.visible = true
	_end_attack(tok, CTX_ATTACK + CTX_PLANET)


## Llamarada solar: rayo ancho que barre media arena. Detrás de una roca no te da.
func _atk_flare(tok: int) -> void:
	_planet_glow("sol")
	_planet_pin["sol"] = Vector2(0, -250)
	_tw(arm_r, "rotation", -PI * 0.9, 0.3)
	if not await _wait(0.4, tok):
		_planet_pin.erase("sol")
		return
	_charge(_planet_pos("sol"), Fx.SUN, 0.5, 150.0, _planet("sol"))
	_hint("invoke", 1.2)
	if not await _wait(0.3, tok):
		_planet_pin.erase("sol")
		return
	var f := Fx.Flare.new()
	f.sun = _planet("sol")
	var from := _planet_pos("sol")
	var to_p := _player_body() if _player_ok() else from + Vector2.DOWN
	var mid := (to_p - from).angle()
	var side := 1.0 if randf() < 0.5 else -1.0
	f.from_a = mid - 0.85 * side
	f.to_a = mid + 0.85 * side
	f.sweep = 2.2 if not enraged else 1.7
	_add_fx(f, from)
	var sweep := f.sweep
	if not await _wait(f.charge, tok):
		_planet_pin.erase("sol")
		return
	_flash(Color(1.0, 0.5, 0.1), 0.18, sweep + 0.3)
	_hint("shout", sweep)
	_cam_punch(0.04, 0.3)
	var st := 0.0
	while st < sweep:
		_shake(2.5, 0.12)
		if not await _wait(0.12, tok):
			_planet_pin.erase("sol")
			return
		st += 0.12
	if not await _wait(0.2, tok):
		_planet_pin.erase("sol")
		return
	_planet_pin.erase("sol")
	_end_attack(tok, CTX_ATTACK + CTX_PLANET)


## Supernova: el Sol crece y estalla en anillos (no se bloquean; rodar a través).
func _atk_nova(tok: int) -> void:
	var sol := _planet("sol")
	_planet_pin["sol"] = Vector2(0, -60)
	_hint("invoke", 0.85)
	_tw(arm_l, "rotation", PI * 0.9, 0.3)
	_tw(arm_r, "rotation", -PI * 0.9, 0.3)
	if sol:
		var grow := create_tween()
		for k in 4:
			grow.tween_property(sol, "scale", Vector2.ONE * (1.4 + 0.3 * k), 0.12)
			grow.tween_property(sol, "scale", Vector2.ONE * (1.25 + 0.3 * k), 0.08)
		_tweens.append(grow)
		_charge(global_position + Vector2(0, -60), Fx.SUN, 0.8, 220.0, self)
		var sa := _anim("fxsun", sol.global_position, 0.9, 8.0, Color(1.0, 0.6, 0.1, 0.25), [0, 1, 2, 3])
		if sa:
			sa.set("loop", true)
			sa.set("life", 0.85)
			sa.set("follow", sol)
	if not await _wait(0.85, tok):
		_planet_pin.erase("sol")
		return
	_flash(Color(1, 0.95, 0.8), 0.55, 0.45)
	_hint("shout", 1.5)
	_cam_punch(0.09, 0.35)
	var em := Fx.Embers.new()
	em.area = Rect2(-420, -320, 840, 560)
	em.emit_for = 1.8
	em.rate = 60.0
	_fx(em, global_position)
	for i in 3:
		var ring := BossFx.ShockRing.new()
		ring.max_r = 520.0
		ring.speed = 330.0
		_add_fx(ring, global_position)
		_ring(global_position, Color(1.0, 0.55, 0.15), 520.0, 520.0 / 330.0, 22.0)
		_burst(global_position + Vector2(0, -60), Fx.SUN, 20, 420.0)
		_anim("fxfire", global_position + Vector2(0, -50), 1.7 + 0.5 * i, 13.0, Color(1.0, 0.45, 0.1, 0.3))
		_planet_glow("sol")
		_shake(6.0, 0.2)
		if not await _wait(0.5, tok):
			_planet_pin.erase("sol")
			if sol and is_instance_valid(sol):
				sol.scale = Vector2.ONE
			return
	if sol and is_instance_valid(sol):
		_tw(sol, "scale", Vector2.ONE, 0.3)
	_planet_pin.erase("sol")
	if not await _wait(0.3, tok):
		return
	_end_attack(tok, CTX_ATTACK + CTX_PLANET)


# --- Lluvias de cambio de fase ---------------------------------------------------------

func barrage_title(n: int) -> String:
	return "DEPLOY A PRODUCCIÓN" if n == 2 else "ALINEACIÓN PLANETARIA"


func barrage_plan(n: int) -> Array:
	if n == 2:
		return [[0.2, "bolts", {"n": 6}], [1.5, "lanes", {"n": 3}], [3.0, "wall", {}],
			[4.6, "bolts", {"n": 7}], [5.6, "lanes", {"n": 2}], [6.3, "rocks", {"n": 4}]]
	return [[0.2, "moonring", {"n": 12}], [1.4, "rocks", {"n": 6}], [2.8, "rings", {}], [4.0, "moonring", {"n": 14}],
		[5.2, "rocks", {"n": 8}], [6.6, "lanes", {"n": 3}], [7.6, "rings", {}], [8.4, "moonring", {"n": 10}]]


func _bfx(n: Node2D, at: Vector2) -> void:
	_add_fx(n, at)
	Barrage.tag(n)


func _bar_bolts(a: Dictionary, tok: int) -> void:
	_click()
	var n: int = a["n"]
	var c := _player_feet() if _player_ok() else arena_rect.get_center()
	for i in n:
		var b := Fx.Bolt.new()
		b.warn = 0.9
		var at := c if i == 0 else c + Vector2.from_angle(TAU * i / (n - 1) + randf() * 0.4) * randf_range(110.0, 240.0)
		_bfx(b, _clamp_arena(at))
		if not await _wait(0.12, tok):
			return


func _bar_lanes(a: Dictionary, tok: int) -> void:
	var n: int = a["n"]
	var py := _player_feet().y if _player_ok() else 0.0
	for i in n:
		var l := Fx.LaneDash.new()
		l.area = arena_rect
		l.y = clampf(py + (i - n / 2) * 120.0, arena_rect.position.y + 40.0, arena_rect.end.y - 30.0)
		l.dir = 1.0 if i % 2 == 0 else -1.0
		l.warn = 0.8
		_bfx(l, Vector2.ZERO)
		if not await _wait(0.18, tok):
			return


func _bar_wall(_a: Dictionary, _tok: int) -> void:
	var w := Fx.LoginWall.new()
	w.area = arena_rect
	w.gap = randf_range(arena_rect.position.x + 120.0, arena_rect.end.x - 120.0)
	w.speed = 200.0
	_bfx(w, Vector2.ZERO)


func _bar_moonring(a: Dictionary, _tok: int) -> void:
	var n: int = a["n"]
	var from := _planet_pos("luna") if _planet("luna") else global_position + CENTER
	var off := randf() * TAU
	for i in n:
		var s := Fx.PShot.new()
		s.kind = "moon"
		s.vel = Vector2.from_angle(off + TAU * i / n) * 230.0
		s.out_time = 1.3
		s.life = 3.5
		_bfx(s, from)


func _bar_rocks(a: Dictionary, tok: int) -> void:
	for i in int(a["n"]):
		if not _player_ok():
			return
		var side := randi() % 4
		var from := Vector2.ZERO
		match side:
			0: from = Vector2(randf_range(arena_rect.position.x, arena_rect.end.x), arena_rect.position.y)
			1: from = Vector2(randf_range(arena_rect.position.x, arena_rect.end.x), arena_rect.end.y)
			2: from = Vector2(arena_rect.position.x, randf_range(arena_rect.position.y, arena_rect.end.y))
			_: from = Vector2(arena_rect.end.x, randf_range(arena_rect.position.y, arena_rect.end.y))
		var s := Fx.PShot.new()
		s.kind = "rock" if phase >= 3 else "pixel"
		s.col = Fx.GREEN
		s.vel = (_player_body() - from).normalized() * 300.0
		_bfx(s, from)
		if not await _wait(0.16, tok):
			return


func _bar_rings(_a: Dictionary, tok: int) -> void:
	for i in 2:
		var ring := BossFx.ShockRing.new()
		ring.max_r = 520.0
		ring.speed = 320.0
		_bfx(ring, global_position)
		if not await _wait(0.55, tok):
			return


# --- Recibir daño ----------------------------------------------------------------

func take_hit(amount: int, from: Vector2) -> void:
	if state in ["intro", "transition", "dead", "paused", "final"]:
		GameFeel.flash(rig, 0.08, Color(0.6, 0.6, 0.7))
		return
	var dmg := amount * (2 if tank_open else 1)
	var center := global_position + CENTER
	var toward := from - center
	toward = Vector2.DOWN if toward.length() < 0.01 else toward.normalized()
	# a un golpe de caer en la fase 3: ASTRA en vez de morir
	if phase >= 3 and not final_victory and hp - dmg <= 0:
		hp = 1
		hp_changed.emit(hp, MAX_HP)
		_start_final()
		return
	hp = maxi(0, hp - dmg)
	hp_changed.emit(hp, MAX_HP)
	GameFeel.flash(rig, 0.1 + 0.02 * dmg, Color(1.0, 0.95, 0.9))
	GameFeel.squash(rig, Vector2(1.04, 0.96), 0.14, 0.0)
	GameFeel.hit_stop(get_tree(), 0.03 + 0.02 * mini(dmg, 3))
	body.recoil = -toward * (4.0 + 2.0 * dmg)
	var num := BossFx.DmgNumber.new()
	num.text = str(dmg) + ("!" if tank_open else "")
	num.big = tank_open
	num.color = Color(0.6, 1, 0.6) if tank_open else Color(1, 1, 1)
	get_parent().add_child(num)
	num.global_position = center + toward * 40.0 + Vector2(0, -40)
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
	body.mood = 2
	_say("¡Ups! Error de red...", Color(0.9, 0.6, 0.3))
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
	body.mood = 0


func _clear_world() -> void:
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		if m.has_method("die"):
			m.call("die")
		elif m.has_method("pop"):
			m.call("pop")
		else:
			m.queue_free()
	for r in get_tree().get_nodes_in_group("sudo_rock"):
		r.queue_free()
	_codes.clear()


func _enter_phase(n: int) -> void:
	phase = n
	_interrupt()
	tank_open = false
	overflow_left = 0.0
	context = 0.0
	var tok := _tok
	state = "transition"
	body.mood = 1
	screen.mode = "slide"
	_slide()
	_click()
	if n == 2:
		body.sleeves = true
	_say(PHASE_NAMES[n - 1], Color(0.9, 0.35, 0.3), 1.4)
	_hint("shout", 1.5)
	GameFeel.flash(rig, 0.3, Color(1.0, 0.5, 0.4))
	_pose(Vector2(0, -12), 0.0, 0.25)
	_tw(arm_r, "rotation", -PI * 0.9, 0.25)
	_shake(7.0, 0.8)
	phase_changed.emit(n, PHASE_NAMES[n - 1])
	if n == 3:
		_spawn_planets()
	if not await _wait(1.6, tok):
		return
	if not await Barrage.run(self, n, tok):
		return
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.4
	body.mood = 0


func _enrage() -> void:
	enraged = true
	_interrupt()
	var tok := _tok
	state = "transition"
	body.mood = 1
	_say("¡SOL · MODO ULTRA!", Color(1, 0.55, 0.15), 1.4)
	_hint("shout", 1.3)
	_pose(Vector2(0, -14), 0.0, 0.3)
	GameFeel.flash(rig, 0.4, Color(1.0, 0.7, 0.3))
	_shake(9.0, 1.0)
	phase_changed.emit(3, "SOL · MODO ULTRA")
	var sol := _planet("sol")
	if sol:
		_tw(sol, "scale", Vector2(1.35, 1.35), 0.5)
	if not await _wait(1.3, tok):
		return
	_rest_pose()
	state = "idle"
	_cd = 0.3
	body.mood = 0


# --- DUELO FINAL: ASTRA ---------------------------------------------------------------
## Cinemática: Terra, Luna y Sol se alinean y se funden en una estrella; detrás se abre una
## espiral gigante de estrellas que se concentra en una bola de luz y te la lanza.
## QTE 1 ¡ESQUIVA! (rodar a tiempo) · QTE 2 ¡DEVUÉLVELO! (parry a tiempo) · QTE 3 ¡EMPUJA! (machacar ataque).
## Si fallas cualquiera: muerte instantánea (no se vuelve a la fase 3 como con los otros bosses).

func _start_final() -> void:
	_interrupt()
	var tok := _tok
	state = "final"
	tank_open = false
	context = 0.0
	overflow_left = 0.0
	restore_player()
	_clear_world()
	Barrage._clear(self)
	_set_player_locked(true)
	_boss_hud_visible(false)
	_music_cue("final1")
	var bars := Fx.CinemaBars.new()
	get_parent().add_child(bars)
	_cinema.append(bars)
	# cámara: se aleja para que entren los dos
	_cam_zoom(0.8, 1.0)
	var spot := Vector2(0.0, arena_rect.position.y + 300.0)
	_tw(self, "global_position", spot, 0.8)
	if _player_ok():
		var ptw := create_tween()
		ptw.tween_property(player, "global_position", Vector2(0.0, arena_rect.end.y - 150.0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tweens.append(ptw)
	screen.mode = "astra"
	body.mood = 1
	_say("Terra, Luna, Sol... ¡ALINEACIÓN!", Color(0.6, 0.5, 1.0), 1.6)
	_hint("charge", 1.0)
	if not await _wait(1.0, tok):
		return
	Final.title(self, "ASTRA", Color(0.8, 0.75, 1.0), "el modelo más fuerte", 1.6)
	# los tres astros se ponen en fila sobre su cabeza...
	_spawn_planets()
	_planet_pin["terra"] = Vector2(-90, -260)
	_planet_pin["luna"] = Vector2(0, -290)
	_planet_pin["sol"] = Vector2(90, -260)
	for k in _planets:
		var p := _planet(k)
		if p:
			p.set("off_left", 0.0)
			p.visible = true
	_tw(arm_l, "rotation", PI * 0.9, 0.6)
	_tw(arm_r, "rotation", -PI * 0.9, 0.6)
	_pose(Vector2(0, -16), 0.0, 0.6)
	if not await _wait(1.2, tok):
		return
	# ...y se funden en una sola estrella
	for k in _planets:
		_planet_pin[k] = Vector2(0, -300)
	if not await _wait(0.5, tok):
		return
	for k in _planets:
		var p := _planet(k)
		if p:
			p.visible = false
	var ball := Fx.AstraBall.new()
	ball.r = 18.0
	get_parent().add_child(ball)
	ball.global_position = global_position + Vector2(0, -300)
	_cinema.append(ball)
	GameFeel.parry_burst(get_parent(), ball.global_position, 60.0)
	_anim("fxcosmic", ball.global_position, 0.9, 14.0, Color(0.6, 0.4, 1.0, 0.3))
	_flash(Color(0.85, 0.8, 1.0), 0.5, 0.4)
	_ring(ball.global_position, Color(0.75, 0.65, 1.0), 360.0, 0.6, 14.0)
	_shake(6.0, 0.4)
	# la espiral de estrellas
	var spiral := Fx.StarSpiral.new()
	get_parent().add_child(spiral)
	spiral.global_position = global_position + Vector2(0, -220)
	_cinema.append(spiral)
	_music_cue("final2")
	_tw(spiral, "grow", 1.0, 2.2).set_trans(Tween.TRANS_SINE)
	_say("Les presento... ¡ASTRA!", Color(0.75, 0.65, 1.0), 2.0)
	_hint("invoke", 3.6)
	if not await _wait(2.6, tok):
		return
	# se concentra en la bola de luz
	_tw(spiral, "collapse", 1.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw(ball, "r", 62.0, 1.0)
	_music_cue("final3")
	if not await _wait(1.1, tok):
		return
	spiral.queue_free()
	GameFeel.parry_burst(get_parent(), ball.global_position, 80.0)
	_flash(Color(1, 1, 1), 0.45, 0.3)
	_ring(ball.global_position, Color(0.8, 0.7, 1.0), 420.0, 0.5, 18.0)
	_shake(8.0, 0.4)
	if not _player_ok():
		return
	# --- QTE 1: ¡ESQUIVA! ---
	_point(arm_r, _player_body(), 0.1)
	_tw(arm_l, "rotation", REST_L, 0.2)
	var target := _player_body()
	var sl := Fx.SpeedLines.new()
	sl.life = 1.6
	sl.col = Color(0.85, 0.8, 1.0, 0.5)
	get_parent().add_child(sl)
	_cinema.append(sl)
	Engine.time_scale = 0.35
	var throw := create_tween()
	throw.tween_property(ball, "global_position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tweens.append(throw)
	_hint("throw", 1.2)
	var q1 := _qte("timing", "roll", "¡ESQUIVA!", 1.2, 0.6, 0.86)
	q1.pressed.connect(_qte_roll)
	var ok1: bool = await q1.done
	if tok != _tok:
		return
	if not ok1:
		_astra_fail(tok, ball)
		return
	# pasa rozando y sigue de largo
	var past := target + (target - ball.global_position).normalized() * 40.0 + Vector2(0, 260)
	var miss := create_tween()
	miss.tween_property(ball, "global_position", _clamp_arena(past, -40.0), 0.25)
	_tweens.append(miss)
	if not await _wait(0.3, tok):
		return
	Engine.time_scale = 1.0
	_set_player_locked(true)
	_say("¡¿Lo esquivaste?!", Color(0.9, 0.85, 0.4), 1.0)
	_hint("think", 0.65)
	# la espiral da la vuelta y regresa
	var loop := create_tween()
	var side := Vector2(260.0 if player.global_position.x <= 0.0 else -260.0, 60.0)
	loop.tween_property(ball, "global_position", _clamp_arena(player.global_position + side, 20.0), 0.6).set_trans(Tween.TRANS_SINE)
	_tweens.append(loop)
	if not await _wait(0.65, tok):
		return
	# --- QTE 2: ¡DEVUÉLVELO! ---
	Engine.time_scale = 0.4
	var ret := create_tween()
	ret.tween_property(ball, "global_position", _player_body() + (ball.global_position - _player_body()).normalized() * 30.0, 0.44).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tweens.append(ret)
	var q2 := _qte("timing", "parry", "¡DEVUÉLVELO!", 1.1, 0.62, 0.88)
	q2.pressed.connect(_qte_parry.bind(ball))
	var ok2: bool = await q2.done
	if tok != _tok:
		return
	if not ok2:
		_astra_fail(tok, ball)
		return
	Engine.time_scale = 1.0
	_flash(Color(0.7, 0.9, 1.0), 0.35, 0.3)
	_ring(ball.global_position, Color(0.6, 0.85, 1.0), 260.0, 0.45, 12.0)
	_burst(ball.global_position, Color(0.8, 0.9, 1.0), 24, 420.0)
	_anim("fxcosmic", ball.global_position, 1.3, 15.0, Color(0.6, 0.4, 1.0, 0.3))
	GameFeel.parry_burst(get_parent(), ball.global_position, 50.0)
	GameFeel.hit_stop(get_tree(), 0.12)
	_shake(8.0, 0.3)
	if not await _wait(0.35, tok):
		return
	# --- QTE 3: ¡EMPUJA! (choque de rayos) ---
	var clash := Fx.Clash.new()
	clash.a = _player_body()
	clash.b = _hand_pos(arm_r)
	clash.ball = ball
	get_parent().add_child(clash)
	clash.global_position = Vector2.ZERO
	_cinema.append(clash)
	_point(arm_r, _player_body(), 0.1)
	_pose(Vector2(0, -4), 0.05, 0.2)
	body.mood = 1
	_say("¡NO PUEDES CONTRA EL MODELO MÁS FUERTE!", Color(0.75, 0.6, 1.0), 2.0)
	var q3 := _qte("mash", "action_primary", "¡EMPUJA!", 0.0, 0.0, 0.0)
	q3.pressed.connect(_qte_push)
	while is_instance_valid(q3) and q3.result == 0 and tok == _tok:
		clash.k = q3.meter
		clash.b = _hand_pos(arm_r)
		_hint("push" if Spr.tex("boss_sudo_push_0") else "point", 0.2)
		_shake(1.5, 0.05)
		if Engine.get_process_frames() % 6 == 0 and is_instance_valid(ball):
			_burst(ball.global_position, Color(0.85, 0.85, 1.0), 6, 300.0)
		await get_tree().process_frame
	if tok != _tok:
		return
	var ok3: bool = is_instance_valid(q3) and q3.result == 1
	if not ok3:
		_astra_fail(tok, ball)
		return
	clash.queue_free()
	_astra_win(tok, ball)


func _qte(mode: String, action: String, title: String, dur: float, from: float, to: float) -> Node:
	# el aviso anterior se quita ya (si no, los dos títulos se montan)
	for n in _cinema:
		if is_instance_valid(n) and n is Fx.Qte:
			n.queue_free()
	var q := Fx.Qte.new()
	q.mode = mode
	q.action = action
	q.title = title
	if mode == "timing":
		q.dur = dur
		q.win_from = from
		q.win_to = to
	get_parent().add_child(q)
	_cinema.append(q)
	return q


## QTE 1: el personaje rueda de verdad (cámara lenta) hacia un lado.
func _qte_roll() -> void:
	if not _player_ok():
		return
	var side := Vector2(1, 0) if player.global_position.x <= 0.0 else Vector2(-1, 0)
	player.set("facing_vec", side)
	player.set_physics_process(true)
	if player.has_method("_try_roll"):
		player.call("_try_roll")


## QTE 2: parry hacia la bola.
func _qte_parry(ball: Node2D) -> void:
	if not _player_ok():
		return
	var cc: Node = player.get("class_controller")
	if cc != null and is_instance_valid(ball):
		cc.call("set_facing", (ball.global_position - _player_body()).normalized())
		cc.call("try_parry")


## QTE 3: cada pulsación, un golpe hacia la espiral.
func _qte_push() -> void:
	if not _player_ok():
		return
	var cc: Node = player.get("class_controller")
	if cc != null and not bool(cc.get("busy")):
		cc.call("set_facing", _dir_to_player(global_position + CENTER) * -1.0)
		cc.call("try_primary")


func _boss_hud_visible(on: bool) -> void:
	var a := get_parent()
	if a == null:
		return
	var h: Variant = a.get("_boss_hud")
	if h is Control and is_instance_valid(h):
		(h as Control).visible = on


func _set_player_locked(on: bool) -> void:
	if not _player_ok():
		return
	var a := get_parent()
	if a != null and a.has_method("_lock_player"):
		a.call("_lock_player", on)
	else:
		player.set_physics_process(not on)
		player.set_process_unhandled_input(not on)


func _cam_zoom(z: float, time: float) -> void:
	if not _player_ok():
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	if _cam_tw and _cam_tw.is_valid():
		_cam_tw.kill()
	_cam_tw = cam.create_tween()
	_cam_tw.tween_property(cam, "zoom", Vector2(z, z), time).set_trans(Tween.TRANS_SINE)


func _clear_cinema() -> void:
	Engine.time_scale = 1.0
	for n in _cinema:
		if is_instance_valid(n):
			if n is Fx.CinemaBars:
				n.call("close")
			else:
				n.queue_free()
	_cinema.clear()
	_planet_pin.clear()
	_cam_zoom(1.0, 0.5)


## Ganaste: la espiral vuelve sobre él y se deshace en polvo de estrellas.
func _astra_win(tok: int, ball: Node2D) -> void:
	final_victory = true
	_music_final("epic")
	var hit := create_tween()
	hit.tween_property(ball, "global_position", global_position + CENTER, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await hit.finished
	if tok != _tok:
		return
	var w := Fx.WhiteOut.new()
	get_parent().add_child(w)
	_shake(14.0, 0.8)
	_clear_cinema()
	_anim("fxcosmic", global_position + CENTER, 2.6, 8.0, Color(0.6, 0.4, 1.0, 0.35))
	await _finisher()
	hp = 0
	hp_changed.emit(hp, MAX_HP)
	_die()


## Fallaste: la espiral te atraviesa. Muerte instantánea.
func _astra_fail(tok: int, ball: Node2D) -> void:
	_say("Sesión cerrada.", Color(0.6, 0.5, 1.0), 1.4)
	_hint("victory" if Spr.tex("boss_sudo_victory_0") else "laugh", 3.0)
	if _player_ok() and is_instance_valid(ball):
		var rush := create_tween()
		rush.tween_property(ball, "global_position", _player_body(), 0.15)
		await rush.finished
	if tok != _tok:
		return
	var w := Fx.WhiteOut.new()
	w.life = 1.2
	get_parent().add_child(w)
	_clear_cinema()
	_shake(12.0, 0.6)
	# multijugador: el ASTRA arrasa con todo el equipo
	for pv in get_tree().get_nodes_in_group("player"):
		var pl: Node2D = pv
		if not is_instance_valid(pl):
			continue
		pl.set("invulnerable", false)
		pl.set("_iframes_left", 0.0)
		pl.set("_shield_left", 0.0)
		pl.set("_ult_active", false)
		pl.set("rolling", false)
		var pcc: Node = pl.get("class_controller")
		if pcc != null and pcc.has_method("cancel_action"):
			pcc.call("cancel_action")
		pl.call("take_hit", 999, global_position + CENTER, true)
	# si por algo el jugador sigue vivo, vuelve la fase 3 con él a 1 PV
	await get_tree().create_timer(0.6).timeout
	if tok == _tok and state == "final":
		_set_player_locked(false)
		_boss_hud_visible(true)
		_music_cue("p3")
		_spawn_planets()
		for k in _planets:
			var p := _planet(k)
			if p:
				p.visible = true
		screen.mode = "slide"
		state = "idle"
		_cd = 1.2


## REMATE: se ilumina, se agrieta en luz y se deshace en polvo de estrellas. Se le cae el clicker.
func _finisher() -> void:
	state = "dead"
	_death_pose = "flinch"
	body.mood = 2
	_pose(Vector2(0, 10), 0.05, 0.3)
	_tw(arm_l, "rotation", 0.6, 0.4)
	_tw(arm_r, "rotation", -0.6, 0.4)
	var cracks := LightCracks.new()
	rig.add_child(cracks)
	cracks.position = CENTER + Vector2(0, -20)
	var clk := Fx.Clicker.new()
	get_parent().add_child(clk)
	clk.global_position = _hand_pos(arm_r)
	clk.ground = global_position.y + 4.0
	arm_r.holding = false
	await get_tree().create_timer(0.9).timeout
	_death_pose = "fade"
	var dust := Fx.StarDust.new()
	dust.area = Rect2(-45, -210, 90, 210)
	add_child(dust)
	var fade := create_tween()
	fade.tween_property(rig, "modulate", Color(2.0, 2.0, 2.4, 1.0), 0.6)
	fade.tween_property(rig, "modulate", Color(1.6, 1.6, 2.0, 0.0), 1.6)
	for k in _planets:
		var p := _planet(k)
		if p:
			p.visible = false
	Final.title(self, "SESIÓN TERMINADA", Color(0.75, 0.7, 1.0), "Gracias por asistir a la charla", 2.2)
	await get_tree().create_timer(2.4).timeout


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


# --- Aparición y muerte -----------------------------------------------------------

func start_intro(skip: bool) -> void:
	state = "intro"
	if skip:
		await get_tree().create_timer(0.6).timeout
		intro_finished.emit()
		return
	var home := position
	# 1. se enciende la pantalla del proyector
	rig.visible = true
	body.visible = false
	arm_l.visible = false
	arm_r.visible = false
	screen.mode = "loading"
	await get_tree().create_timer(1.2).timeout
	# 2. entra caminando desde el fondo
	body.visible = true
	arm_l.visible = true
	arm_r.visible = true
	position = home + Vector2(0, -200)
	modulate.a = 0.0
	body.walk_speed = 1.0
	var walk := create_tween().set_parallel(true)
	walk.tween_property(self, "position", home, 1.4).set_trans(Tween.TRANS_SINE)
	walk.tween_property(self, "modulate:a", 1.0, 0.5)
	await get_tree().create_timer(1.45).timeout
	position = home
	body.walk_speed = 0.0
	# 3. saluda
	_say("¡Hola a todos!", Color(0.2, 0.75, 0.5), 1.2)
	_hint("wave", 1.0)
	for i in 3:
		_tw(arm_l, "rotation", PI * 0.8, 0.15)
		await get_tree().create_timer(0.16).timeout
		_tw(arm_l, "rotation", PI * 0.6, 0.15)
		await get_tree().create_timer(0.16).timeout
	# 4. clic: bienvenidos y aplausos
	_click()
	screen.mode = "welcome"
	var s := Roar.Sign.new()
	s.text = "*APLAUSOS*"
	s.col = Color(0.3, 0.9, 0.55)
	Roar.spawn(get_parent(), s, global_position + Vector2(170, -200))
	_tw(arm_l, "rotation", REST_L, 0.3)
	_hint("present", 1.3)
	await get_tree().create_timer(1.3).timeout
	# 5. firma: levanta el clicker y un rayo verde le cae en la mano
	body.mood = 1
	_tw(arm_r, "rotation", -PI * 0.9, 0.3)
	_pose(Vector2(0, -8), 0.0, 0.3)
	await get_tree().create_timer(0.4).timeout
	var b := Fx.Bolt.new()
	b.warn = 0.25
	b.r = 30.0
	b.harmless = true
	b.big = false
	get_parent().add_child(b)
	b.global_position = _hand_pos(arm_r) + Vector2(0, 10)
	await get_tree().create_timer(0.26).timeout
	var w := Roar.Waves.new()
	w.col = Fx.GREEN
	w.count = 3
	w.max_r = 420.0
	w.jagged = true
	Roar.spawn(get_parent(), w, global_position)
	GameFeel.flash(rig, 0.3, Fx.GREEN_HI)
	_impact(global_position, 8.0)
	GameFeel.hit_stop(get_tree(), 0.1)
	arm_r.charge = 1.0
	_say("¡EMPECEMOS LA DEMO!", Color(0.15, 0.75, 0.45), 1.3)
	_hint("shout", 0.9)
	await get_tree().create_timer(1.3).timeout
	_rest_pose()
	_rest_arms()
	body.mood = 0
	screen.mode = "slide"
	_slide()
	intro_finished.emit()


func begin_fight() -> void:
	state = "idle"
	_cd = 1.0


func pause_ai() -> void:
	_interrupt()
	if state != "dead":
		state = "paused"
	_free_player()
	_clear_cinema()


func _free_player() -> void:
	restore_player()
	if _player_ok() and float(player.get("speed_mult")) < 1.0 and float(player.get("speed_mult")) > 0.0:
		player.set("speed_mult", 1.0)


func _die() -> void:
	_interrupt()
	state = "dead"
	tank_open = false
	remove_from_group("enemies")
	_clear_world()
	_free_player()
	for k in _planets:
		var p := _planet(k)
		if p:
			p.remove_from_group("enemies")
			p.visible = false
	if rig.modulate.a > 0.1:
		# muerte sin duelo (no debería pasar): se desvanece igual
		_death_pose = "fade"
		var dust := Fx.StarDust.new()
		add_child(dust)
		create_tween().tween_property(rig, "modulate:a", 0.0, 1.2)
		await get_tree().create_timer(1.3).timeout
	defeated.emit()


# --- Dibujo (provisional, hasta tener los sprites) --------------------------------------

## Cuerpo de SUDO: piernas (pantalón crema), tenis negros, camiseta negra "CLUB IA", cabeza con barba.
class Body extends Node2D:
	var boss: Node
	var mood := 0          ## 0 sonrisa, 1 concentrado, 2 dolor, 3 mareado (overflow)
	var look := Vector2.ZERO
	var walk_speed := 0.0
	var sleeves := false   ## fase 2+: se arremanga
	var recoil := Vector2.ZERO
	var t := 0.0
	var _walk := 0.0
	var _blink := 0.0

	const SKIN := Color(0.79, 0.6, 0.46)
	const SKIN_D := Color(0.66, 0.47, 0.35)
	const HAIR := Color(0.1, 0.075, 0.065)
	const TEE := Color(0.09, 0.09, 0.1)
	const TEE_L := Color(0.17, 0.17, 0.19)
	const PANTS := Color(0.91, 0.89, 0.81)
	const PANTS_D := Color(0.76, 0.73, 0.64)
	const SHOE := Color(0.08, 0.08, 0.09)
	const SOLE := Color(0.95, 0.95, 0.92)
	const INK := Color(0.03, 0.03, 0.04)

	func _process(delta: float) -> void:
		t += delta
		_walk += delta * 9.0 * walk_speed
		recoil = recoil.lerp(Vector2.ZERO, minf(1.0, delta * 10.0))
		_blink -= delta
		if _blink < -3.2:
			_blink = 0.12
		queue_redraw()

	func _poly(pts: PackedVector2Array, fill: Color, line: Color = INK, w: float = 2.0) -> void:
		draw_colored_polygon(pts, fill)
		var o := PackedVector2Array(pts)
		o.append(pts[0])
		draw_polyline(o, line, w)

	func _draw() -> void:
		if boss and bool(boss.get("sprites")):
			var tex: Texture2D = Spr.tex("boss_sudo_" + str(boss.call("pose_frame")))
			if tex:
				var sz := tex.get_size()
				var flip: bool = bool(boss.call("pose_flipped"))
				var off := recoil * 0.5
				var pn: String = str(boss.get("_pose_cur"))
				if TREMBLE.has(pn):
					off += Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
				off.y += float(AIR.get(pn, 0.0))
				draw_set_transform(off, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
				draw_texture(tex, Vector2(-sz.x * 0.5, -sz.y))
				draw_set_transform(Vector2.ZERO)
				return
		var sw := sin(_walk) * (5.0 if walk_speed > 0.05 else 0.0)
		_legs(sw)
		_torso()
		_head()

	func _legs(sw: float) -> void:
		var lift_l := maxf(0.0, sw) * 0.8
		var lift_r := maxf(0.0, -sw) * 0.8
		# pierna izquierda y derecha (pantalón crema ajustado)
		_poly(PackedVector2Array([Vector2(-22, -80), Vector2(-2, -80), Vector2(-5 + sw * 0.5, -14 - lift_l), Vector2(-19 + sw * 0.5, -14 - lift_l)]), PANTS)
		_poly(PackedVector2Array([Vector2(2, -80), Vector2(22, -80), Vector2(19 - sw * 0.5, -14 - lift_r), Vector2(5 - sw * 0.5, -14 - lift_r)]), PANTS)
		draw_line(Vector2(-6, -76), Vector2(-7 + sw * 0.5, -18 - lift_l), PANTS_D, 3.0)
		draw_line(Vector2(6, -76), Vector2(7 - sw * 0.5, -18 - lift_r), PANTS_D, 3.0)
		# tenis negros con suela blanca
		_shoe(Vector2(-12 + sw * 0.5, -lift_l), -1.0)
		_shoe(Vector2(12 - sw * 0.5, -lift_r), 1.0)

	func _shoe(c: Vector2, s: float) -> void:
		var r := Rect2(c + Vector2(-11 + s * 1.0, -15), Vector2(22, 12))
		draw_rect(r, SHOE)
		draw_circle(c + Vector2(s * 9.0, -8), 6.0, SHOE)
		draw_rect(Rect2(c + Vector2(-12 + s * 1.0, -5), Vector2(24, 5)), SOLE)
		draw_line(c + Vector2(-6, -11), c + Vector2(4, -13), Color(0.3, 0.3, 0.32), 1.0)
		draw_rect(r, INK, false, 1.5)

	func _torso() -> void:
		# cuello
		draw_rect(Rect2(-7, -150, 14, 18), SKIN_D)
		# camiseta negra
		var tee := PackedVector2Array([Vector2(-32, -136), Vector2(-12, -140), Vector2(12, -140), Vector2(32, -136), Vector2(30, -70), Vector2(-30, -70)])
		_poly(tee, TEE)
		draw_colored_polygon(PackedVector2Array([Vector2(-30, -134), Vector2(-20, -136), Vector2(-21, -72), Vector2(-29, -72)]), TEE_L)
		# cuello redondo
		draw_arc(Vector2(0, -141), 9.0, 0.1, PI - 0.1, 10, Color(0.22, 0.22, 0.24), 2.5)
		# mangas (o arremangado en la fase 2+)
		var sl := 116.0 if not sleeves else 122.0
		_poly(PackedVector2Array([Vector2(-32, -136), Vector2(-44, -sl + 2), Vector2(-36, -sl + 12), Vector2(-27, -122)]), TEE)
		_poly(PackedVector2Array([Vector2(32, -136), Vector2(44, -sl + 2), Vector2(36, -sl + 12), Vector2(27, -122)]), TEE)
		# texto chiquito del pecho: CLUB IA
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(2, -116), "CLUB IA", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.95, 0.95))
		draw_line(Vector2(3, -112), Vector2(24, -112), Color(0.8, 0.8, 0.8, 0.7), 1.0)
		draw_line(Vector2(3, -109), Vector2(16, -109), Color(0.8, 0.8, 0.8, 0.5), 1.0)

	func _head() -> void:
		var c := Vector2(0, -172) + recoil
		var f := ThemeDB.fallback_font
		# orejas
		draw_circle(c + Vector2(-27, 2), 6.0, SKIN_D)
		draw_circle(c + Vector2(27, 2), 6.0, SKIN_D)
		# cara (alargada)
		var face := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			face.append(c + Vector2(cos(a) * 27.0, sin(a) * 31.0))
		_poly(face, SKIN)
		# pelo oscuro corto, peinado atrás, con entradas
		_poly(PackedVector2Array([c + Vector2(-27, -4), c + Vector2(-28, -16), c + Vector2(-21, -28), c + Vector2(-8, -33),
			c + Vector2(8, -33), c + Vector2(21, -28), c + Vector2(28, -16), c + Vector2(27, -4),
			c + Vector2(23, -12), c + Vector2(15, -20), c + Vector2(6, -21), c + Vector2(0, -19), c + Vector2(-6, -21), c + Vector2(-15, -20), c + Vector2(-23, -12)]), HAIR, INK, 1.5)
		# barba completa y bigote
		var beard := PackedVector2Array([c + Vector2(-27, 0), c + Vector2(-25, 14), c + Vector2(-18, 26), c + Vector2(-8, 32),
			c + Vector2(8, 32), c + Vector2(18, 26), c + Vector2(25, 14), c + Vector2(27, 0),
			c + Vector2(22, 6), c + Vector2(14, 9), c + Vector2(8, 14), c + Vector2(-8, 14), c + Vector2(-14, 9), c + Vector2(-22, 6)])
		_poly(beard, HAIR, INK, 1.5)
		draw_rect(Rect2(c + Vector2(-10, 9), Vector2(20, 5)), HAIR)
		# boca
		match mood:
			2:
				draw_circle(c + Vector2(0, 19), 4.0, Color(0.35, 0.1, 0.1))
			3:
				draw_line(c + Vector2(-6, 19), c + Vector2(6, 17), Color(0.85, 0.85, 0.8), 2.0)
			1:
				draw_rect(Rect2(c + Vector2(-6, 16), Vector2(12, 3)), Color(0.95, 0.95, 0.9))
			_:
				draw_rect(Rect2(c + Vector2(-7, 15), Vector2(14, 4)), Color(0.97, 0.97, 0.92))
				draw_line(c + Vector2(-7, 19), c + Vector2(7, 19), Color(0.4, 0.15, 0.12), 1.0)
		# ojos
		var lk := look * Vector2(2.5, 1.5)
		for s in [-1.0, 1.0]:
			var e := c + Vector2(s * 10.0, -2)
			match mood:
				2:
					draw_line(e + Vector2(-4, -3), e + Vector2(4, 0), INK, 2.5)
					draw_line(e + Vector2(-4, 3), e + Vector2(4, 0), INK, 2.5)
				3:
					draw_arc(e, 4.0, t * 8.0 * s, t * 8.0 * s + 4.5, 8, INK, 2.0)
				_:
					if _blink > 0.0:
						draw_line(e + Vector2(-4, 0), e + Vector2(4, 0), INK, 2.0)
					else:
						draw_rect(Rect2(e + Vector2(-3, -4), Vector2(6, 8)), Color(0.98, 0.98, 0.96))
						draw_rect(Rect2(e + lk + Vector2(-2, -3), Vector2(4, 6)), INK)
			# cejas
			var tilt := 3.0 if mood == 1 else (-2.0 if mood == 2 else 0.0)
			draw_line(e + Vector2(-6, -9 + (tilt if s > 0 else 0.0)), e + Vector2(6, -9 + (tilt if s < 0 else 0.0)), HAIR, 3.0)
		if mood == 3:
			draw_string(f, c + Vector2(20, -34), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.4, 0.4))


## Brazo (rotación 0 = colgando). El del lado derecho de la pantalla (su mano izquierda) lleva el reloj y el clicker.
class Arm extends Node2D:
	var side := 1
	var anim := 0.0
	var click := 0.0
	var charge := 0.0
	var holding := true
	## Con sprites el brazo no se dibuja (viene en la pose), pero sigue girando para elegir la pose.
	var sprite_mode := false
	var _base := 0.0

	func _process(delta: float) -> void:
		click = maxf(0.0, click - delta)
		charge = maxf(0.0, charge - delta * 0.7)
		queue_redraw()

	func _draw() -> void:
		if sprite_mode:
			return
		draw_set_transform(Vector2.ZERO, anim)
		var ink := Color(0.03, 0.03, 0.04)
		# manga negra
		draw_rect(Rect2(-8, -2, 16, 16), Color(0.09, 0.09, 0.1))
		draw_rect(Rect2(-8, -2, 16, 16), ink, false, 1.5)
		# brazo (piel)
		draw_rect(Rect2(-5, 13, 10, 36), Color(0.79, 0.6, 0.46))
		draw_rect(Rect2(-5, 13, 10, 36), ink, false, 1.5)
		draw_circle(Vector2(0, 52), 7.0, Color(0.79, 0.6, 0.46))
		draw_arc(Vector2(0, 52), 7.0, 0, TAU, 14, ink, 1.5)
		if side > 0:
			# reloj inteligente negro (muñeca izquierda de él = lado derecho de la pantalla, como en la foto)
			draw_rect(Rect2(-6, 38, 12, 7), Color(0.05, 0.05, 0.06))
			draw_rect(Rect2(-3, 39, 6, 5), Color(0.2, 0.75, 0.5) if fmod(Time.get_ticks_msec() / 700.0, 2.0) > 1.0 else Color(0.1, 0.35, 0.25))
		if side > 0 and holding:
			# clicker con su LED
			draw_rect(Rect2(-4, 52, 8, 15), Color(0.1, 0.1, 0.12))
			draw_rect(Rect2(-4, 52, 8, 15), Color(0.45, 0.45, 0.5), false, 1.0)
			draw_circle(Vector2(0, 64), 2.0, Color(1, 0.25, 0.2) if click > 0.0 else Color(0.4, 0.06, 0.05))
			if click > 0.0:
				draw_circle(Vector2(0, 64), 6.0 + 30.0 * (0.25 - click), Color(1, 0.3, 0.25, click * 2.0))
			if charge > 0.0:
				draw_circle(Vector2(0, 58), 12.0 + 6.0 * sin(Time.get_ticks_msec() / 40.0), Color(0.3, 1.0, 0.65, 0.35 * charge))
		draw_set_transform(Vector2.ZERO)


## Pantalla de proyector flotante: muestra la diapositiva de la fase, el código 2FA o el CONTEXT OVERFLOW.
class Screen extends Node2D:
	var boss: Node
	var mode := "slide"
	var title := ""
	var sub := ""
	var slide_n := 1
	var code := ""
	var fake := false
	var flick := 0.0
	var t := 0.0

	func _ready() -> void:
		z_index = -1

	func show_slide(a: String, b: String, n: int) -> void:
		title = a
		sub = b
		slide_n = n
		flick = 0.3

	func _process(delta: float) -> void:
		t += delta
		flick = maxf(0.0, flick - delta)
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var bob := sin(t * 1.5) * 3.0
		draw_set_transform(Vector2(0, bob))
		var outer := Rect2(-88, -52, 176, 104)
		var inner := Rect2(-82, -46, 164, 86)
		# haz del proyector y soporte
		draw_colored_polygon(PackedVector2Array([Vector2(-60, 52), Vector2(60, 52), Vector2(20, 120), Vector2(-20, 120)]), Color(0.8, 0.9, 1.0, 0.05))
		# marco con sprite (boss_sudo_screen_0 normal, _1 agrietada en el modo ultra, _2 apagada al final)
		var idx := 0
		if boss and str(boss.get("state")) == "dead":
			idx = 2
		elif boss and bool(boss.get("enraged")):
			idx = 1
		var frame_tex: Texture2D = Spr.tex("boss_sudo_screen_%d" % idx)
		if frame_tex:
			var fs := frame_tex.get_size()
			draw_rect(Rect2(Vector2(-fs.x * 0.5 + 4, -fs.y * 0.5 + 4), fs), Color(0, 0, 0, 0.3))
			draw_texture(frame_tex, -fs * 0.5)
			# hueco de la pantalla dentro de la imagen (medido al recortar: 7,18 - 161,102 de 176x115)
			inner = Rect2(Vector2(-fs.x * 0.5, -fs.y * 0.5) + Vector2(7, 18) * fs.x / 176.0, Vector2(154, 84) * fs.x / 176.0)
			if idx == 2:
				draw_set_transform(Vector2.ZERO)
				return
		else:
			draw_rect(Rect2(outer.position + Vector2(4, 4), outer.size), Color(0, 0, 0, 0.35))
			draw_rect(outer, Color(0.16, 0.17, 0.19))
			draw_rect(outer, Color(0.03, 0.03, 0.04), false, 2.0)
		var bg := Color(0.04, 0.12, 0.08)
		var fg := Color(0.4, 1.0, 0.65)
		var phase_n := int(boss.get("phase")) if boss else 1
		if phase_n == 2:
			bg = Color(0.07, 0.06, 0.12)
			fg = Color(0.75, 0.68, 1.0)
		elif phase_n >= 3:
			bg = Color(0.03, 0.04, 0.12)
			fg = Color(1.0, 0.85, 0.5)
		match mode:
			"overflow":
				var on := fmod(t * 4.0, 1.0) > 0.5
				draw_rect(inner, Color(0.55, 0.05, 0.05) if on else Color(0.3, 0.02, 0.02))
				draw_string(f, inner.position + Vector2(0, 30), "CONTEXT", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 18, Color.WHITE)
				draw_string(f, inner.position + Vector2(0, 52), "OVERFLOW", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 18, Color.WHITE)
				draw_string(f, inner.position + Vector2(0, 76), "daño x2", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 12, Color(1, 0.9, 0.5))
			"compact":
				draw_rect(inner, Color(0.05, 0.06, 0.08))
				draw_string(f, inner.position + Vector2(0, 34), "Compactando...", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 13, Color(0.8, 0.85, 0.95))
				var k := fmod(t * 1.5, 1.0)
				draw_rect(Rect2(inner.position + Vector2(14, 50), Vector2((inner.size.x - 28) * k, 8)), Color(0.4, 0.8, 1.0))
				draw_rect(Rect2(inner.position + Vector2(14, 50), Vector2(inner.size.x - 28, 8)), Color(1, 1, 1, 0.5), false, 1.0)
			"code":
				draw_rect(inner, Color(0.97, 0.97, 1.0))
				draw_string(f, inner.position + Vector2(0, 22), "Verificación 2FA", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 12, Color(0.35, 0.25, 0.7))
				draw_string(f, inner.position + Vector2(0, 56), code, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 24, Color(0.15, 0.1, 0.3))
				draw_string(f, inner.position + Vector2(0, 76), "golpea este código", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 10, Color(0.4, 0.4, 0.5))
			"loading":
				draw_rect(inner, Color(0.04, 0.05, 0.06))
				if fmod(t * 6.0, 1.0) > 0.3:
					draw_string(f, inner.position + Vector2(0, 40), "CLUB IA", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 20, Color(0.4, 1.0, 0.65))
				draw_string(f, inner.position + Vector2(0, 64), "cargando presentación...", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 10, Color(0.7, 0.75, 0.8))
			"welcome":
				draw_rect(inner, Color(0.04, 0.12, 0.08))
				draw_string(f, inner.position + Vector2(0, 32), "BIENVENIDOS", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 16, Color(0.95, 0.95, 0.95))
				draw_string(f, inner.position + Vector2(0, 56), "AL CLUB IA", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 20, Color(0.4, 1.0, 0.65))
			"astra":
				draw_rect(inner, Color(0.06, 0.03, 0.14))
				for i in 14:
					var p := inner.position + Vector2(fmod(i * 37.0, inner.size.x), fmod(i * 23.0, inner.size.y))
					draw_circle(p, 1.2, Color(1, 1, 1, 0.5 + 0.5 * sin(t * 4.0 + i)))
				draw_string(f, inner.position + Vector2(0, 52), "ASTRA", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 26, Color(0.85, 0.8, 1.0))
			_:
				draw_rect(inner, bg)
				draw_string(f, inner.position + Vector2(0, 30), title, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 16, fg)
				draw_line(inner.position + Vector2(30, 38), inner.position + Vector2(inner.size.x - 30, 38), Color(fg, 0.5), 1.0)
				draw_string(f, inner.position + Vector2(0, 58), sub, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 12, Color(0.92, 0.92, 0.95))
				if phase_n >= 3:
					draw_circle(inner.position + Vector2(56, 72), 5.0, Color(0.3, 0.6, 1.0))
					draw_circle(inner.position + Vector2(82, 72), 4.0, Color(0.85, 0.87, 0.95))
					draw_circle(inner.position + Vector2(108, 72), 6.0, Color(1.0, 0.65, 0.2))
				draw_string(f, inner.position + Vector2(inner.size.x - 30, inner.size.y - 4), "%d/3" % slide_n, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.5))
				if fake:
					draw_string(f, inner.position + Vector2(4, inner.size.y - 4), "alucinando...", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.6, 0.6, 0.6 + 0.4 * sin(t * 10.0)))
		if idx == 1 and frame_tex:
			# grietas encima del contenido (modo ultra)
			var c := inner.position + inner.size * Vector2(0.72, 0.45)
			for a in [0.3, 1.4, 2.3, 3.5, 4.4, 5.4]:
				var d := Vector2.from_angle(a)
				draw_polyline(PackedVector2Array([c, c + d * 14.0 + d.orthogonal() * 3.0, c + d * 30.0]), Color(0.85, 0.9, 0.85, 0.75), 1.0)
			draw_circle(c, 2.5, Color(0, 0, 0, 0.9))
		if flick > 0.0:
			draw_rect(inner, Color(1, 1, 1, flick * 1.5))
		if fake:
			# interferencia: la pantalla se "corre" de lado
			for i in 3:
				var y := inner.position.y + fmod(t * 90.0 + i * 31.0, inner.size.y)
				draw_rect(Rect2(inner.position.x, y, inner.size.x, 2), Color(0.6, 0.8, 1.0, 0.35))
		draw_set_transform(Vector2.ZERO)


## Globo de texto sobre la cabeza.
class Bubble extends Node2D:
	var text := ""
	var col := Color(0.2, 0.8, 0.55)
	var left := 0.0
	var t := 0.0

	func _ready() -> void:
		z_index = 8

	func show_text(s: String, c: Color, d: float = 1.1) -> void:
		text = s
		col = c
		left = d
		t = 0.0

	func _process(delta: float) -> void:
		t += delta
		left -= delta
		queue_redraw()

	func _draw() -> void:
		if left <= 0.0 or text == "":
			return
		var f := ThemeDB.fallback_font
		var a := clampf(left / 0.2, 0.0, 1.0)
		var s := minf(1.0, t / 0.1)
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		var r := Rect2(-6, -26, w, 26)
		draw_rect(r, Color(1, 1, 1, 0.95 * a))
		draw_rect(r, Color(col, a), false, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(16, 0), Vector2(-4, 10)]), Color(1, 1, 1, 0.95 * a))
		draw_string(f, Vector2(3, -8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col.darkened(0.35), a))
		draw_set_transform(Vector2.ZERO)


## Grietas de luz del remate (rayos blancos que salen del pecho).
class LightCracks extends Node2D:
	var t := 0.0
	var _rays: Array = []

	func _ready() -> void:
		z_index = 9
		for i in 9:
			_rays.append([randf() * TAU, randf_range(40.0, 120.0), randf_range(0.0, 0.5)])

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		for r in _rays:
			var k := clampf((t - float(r[2])) / 0.4, 0.0, 1.0)
			if k <= 0.0:
				continue
			var d := Vector2.from_angle(r[0])
			var l := float(r[1]) * k
			draw_line(Vector2.ZERO, d * l, Color(0.8, 0.85, 1.0, 0.5), 8.0)
			draw_line(Vector2.ZERO, d * l, Color(1, 1, 1, 0.95), 3.0)
		draw_circle(Vector2.ZERO, 10.0 + 20.0 * clampf(t, 0.0, 1.0), Color(1, 1, 1, 0.8))
