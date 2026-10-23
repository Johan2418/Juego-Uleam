extends CharacterBody2D
## Boss 7 MISSING TEXTURE (Facultad de Artes, Humanidades y Patrimonio): estatua de mármol gigante que escapó
## del museo, sobre su pedestal, con pincel y paleta. Partes de su cuerpo salen con la textura que falta
## (cuadriculado magenta y negro).
## Lo único: LA MIRADA. Si el jugador lo mira (hacia donde caminó o atacó por última vez), se congela en piedra:
## no se mueve y tarda más en empezar su siguiente ataque. Si le das la espalda se vuelve glitch, avanza a saltos
## y ataca. Mirarlo llena la barra de petrificación: llena = ¡ESTATUA!, aturdido 4 s con daño x2.
## Si pasan 3 s sin mirarlo, aparece pegado a ti y te agarra (POSE FINAL): 1 s petrificado y 2 de daño.
## Versión de prueba con figuras de código; cuando lleguen las hojas de grokbot (bosses/tex/) se cambian por sprites.
## Sin class_name: cargar con preload.

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Epic := preload("res://scripts/combat/epic_fx.gd")
const Barrage := preload("res://scripts/combat/boss_barrage.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Fx := preload("res://scripts/combat/boss_tex_fx.gd")
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
const MOVE_SPEED := 70.0
const KEEP_DIST := 220.0
const PAUSE := [1.15, 0.9, 0.7]
const POISE := [9, 12, 15]
const ENRAGE_AT := 0.12
const PHASE_NAMES := ["SALA PERMANENTE", "EXPOSICIÓN TEMPORAL", "RESTAURACIÓN FALLIDA"]
const COMBOS := {
	2: [["masks", "mannequins"], ["brush", "sew"], ["dig", "masks"]],
	3: [["masks", "mannequins"], ["brush", "sew"], ["dig", "masks"], ["mannequins", "brush"]],
}

# La Mirada
const GAZE_DOT := 0.5                     # cono de unos 120° delante del jugador
const FILL_TIME := [4.0, 4.4, 5.2]        # segundos de mirada seguida para la ESTATUA
const DECAY := 0.12                       # lo que baja por segundo sin mirarlo
const STATUE_TIME := 4.0
const GRAB_AFTER := [3.0, 3.0, 2.0]       # segundos sin mirarlo hasta la pose final
const COVER := [0.22, 0.42, 0.62]         # cuánto del cuerpo es textura faltante
## La Mirada por fase: F1 como siempre. F2 los MANIQUÍES te tapan la vista (si hay uno entre tú y él, no cuenta).
## F3 la piedra se le despinta rápido si dejas de mirarlo (DECAY_F3 por segundo).
const DECAY_F3 := 0.45
const BLOCK_DIST := 34.0
## Duelo final RENDER FINAL: sala a oscuras, solo tu foco. Aparece en la oscuridad (ojos) y se lanza:
## parry al lanzarse. Si lo estás MIRANDO cuando se lanza, va más lento. FINAL_ROUNDS aciertos = se hace mármol.
const FINAL_ROUNDS := 6

# pies en y 0
const SHOULDER_L := Vector2(-56, -190)
const SHOULDER_R := Vector2(56, -190)
const CORE := Vector2(0, -158)
const HEAD := Vector2(0, -208)
const CENTER := Vector2(0, -130)
const ARM_LEN := 118.0
# con sprites (medido en boss_tex_body_0: 178x215, pies abajo al centro)
const SPR_SHOULDER_L := Vector2(-44, -175)
const SPR_SHOULDER_R := Vector2(54, -175)
const SPR_CORE := Vector2(5, -177)
const SPR_HEAD := Vector2(6, -200)
# hombro (centro de la bola) dentro de cada sprite de brazo
const ARM_PIVOT := {
	"boss_tex_brush_0": Vector2(51, 25), "boss_tex_brush_1": Vector2(37, 12), "boss_tex_brush_2": Vector2(20, 12),
	"boss_tex_palette_0": Vector2(38, 12), "boss_tex_palette_1": Vector2(40, 12), "boss_tex_palette_2": Vector2(24, 12),
}
const REST_L := 0.25
const REST_R := -0.25

const SKIN_SHADER := """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float glitch = 0.0;
uniform float stone = 0.0;
uniform float seed = 0.0;
varying vec2 lpos;
void vertex() { lpos = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	c.rgb = mix(c.rgb, vec3(l * 0.8 + 0.12), stone * 0.8);
	vec2 cell = floor(lpos / 22.0);
	float m = step(hash(cell + vec2(seed, seed * 0.37)), glitch);
	vec2 sq = floor(lpos / 6.0);
	float chk = mod(sq.x + sq.y, 2.0);
	c.rgb = mix(c.rgb, mix(vec3(0.0), vec3(1.0, 0.0, 1.0), chk), m);
	c.rgb = mix(c.rgb, flash_color.rgb, flash * c.a);
	COLOR = c;
}
"""
static var _skin_shader: Shader

var hp: int = MAX_HP
var phase: int = 1
var state: String = "intro"
var arena_rect: Rect2 = Rect2(-500, -310, 1000, 620)
var player: CharacterBody2D
## Núcleo expuesto (daño x2). Mismo nombre que en los otros bosses para que la arena lo cuente.
var tank_open: bool = false
var enraged: bool = false

var watched: bool = false
var petrify: float = 0.0
var stone_k: float = 0.0
var statue_left: float = 0.0
var statues: int = 0
var grabs: int = 0
var unseen_t: float = 0.0
var _gaze_lock: float = 0.0
var _step_t: float = 0.0
var _seed_t: float = 0.0
var _pose_lock: float = 0.0
var blocked: bool = false
var final_victory: bool = false
var _final_hits: int = 0
var _final_fail: bool = false
var _final_wait: bool = false
var _fdark: Node2D

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
var panel: Placard
var _holo: Holo
var _home: Dictionary = {}
var _skin: ShaderMaterial

var rig: Node2D
var pedestal: Part
var body: Part
var core: Part
var head: Part
var brush: Part
var palette: Part


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	z_index = 1
	collision_layer = 3
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(140, 30)
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
	hr.size = Vector2(150, 270)
	hs.shape = hr
	hs.position = Vector2(0, -112)
	hurt.add_child(hs)
	add_child(hurt)
	GameFeel.add_shadow(self, Vector2(0, -2), Vector2(80, 15))
	_build_rig()


func set_player(p: CharacterBody2D) -> void:
	player = p


## La arena llama esto: la ficha técnica reemplaza la barra de vida.
func build_hud(layer: CanvasLayer) -> void:
	panel = Placard.new()
	panel.boss = self
	panel.position = Vector2(340, 8)
	layer.add_child(panel)


# --- Piezas ----------------------------------------------------------------------

func _build_rig() -> void:
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)
	if _skin_shader == null:
		_skin_shader = Shader.new()
		_skin_shader.code = SKIN_SHADER
	_skin = ShaderMaterial.new()
	_skin.shader = _skin_shader
	rig.material = _skin
	var spr := has_sprites()
	pedestal = _part("pedestal", Vector2.ZERO)
	body = _part("body", Vector2.ZERO)
	core = _part("core", SPR_CORE if spr else CORE)
	brush = _part("brush", SPR_SHOULDER_L if spr else SHOULDER_L)
	palette = _part("palette", SPR_SHOULDER_R if spr else SHOULDER_R)
	head = _part("head", SPR_HEAD if spr else HEAD)
	brush.rotation = REST_L
	palette.rotation = REST_R
	_holo = Holo.new()
	_holo.position = Vector2(0, -320)
	add_child(_holo)


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
	return Spr.tex("boss_tex_body_0") != null


func _parts() -> Array:
	return [pedestal, body, core, brush, palette, head]


func _say(text: String, col: Color = Color(1, 0.85, 0.4), time: float = 1.1) -> void:
	if _holo:
		_holo.show_text(text, col, time)


## Destello propio (el material del rig es el de la textura faltante, no el de GameFeel).
func _flash(time: float, col: Color = Color.WHITE) -> void:
	_skin.set_shader_parameter("flash_color", col)
	_skin.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_interval(time * 0.4)
	tw.tween_method(func(v: float) -> void: _skin.set_shader_parameter("flash", v), 1.0, 0.0, time * 0.6)


# --- Bucle ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_update_gaze(delta)
	_update_skin(delta)
	if _pose_lock > 0.0:
		_pose_lock -= delta
		if _pose_lock <= 0.0:
			_free_player()
	if state != "dead":
		var shiver := Vector2.ZERO
		if stone_k < 0.5 and state in ["idle", "attack"]:
			shiver = Vector2(randf_range(-1.5, 1.5), 0) if fmod(_t, 0.5) < 0.08 else Vector2.ZERO
		rig.position = rig_off + shiver
		var breathe := 1.0 - stone_k
		head.anim_off = head.anim_off.lerp(Vector2(0, sin(_t * 1.6) * 1.5 * breathe), minf(1.0, delta * 8.0))
		brush.anim_rot = sin(_t * 1.4) * 0.05 * breathe if state == "idle" else 0.0
		palette.anim_rot = sin(_t * 1.4 + 1.2) * 0.05 * breathe if state == "idle" else 0.0
		if enraged:
			var k := 0.8 + 0.2 * absf(sin(_t * 9.0))
			rig.modulate = Color(1.0, k, 1.0)
		else:
			rig.modulate = Color.WHITE
		if statue_left > 0.0:
			statue_left -= delta
	if _player_ok():
		z_index = 3 if _player_feet().y < global_position.y else 1
	match state:
		"idle":
			_ai_move(delta)
			if _player_ok() and _player_feet().distance_to(global_position) < 150.0:
				_near_t += delta
			else:
				_near_t = maxf(0.0, _near_t - delta)
			# mirarlo lo frena: tarda el doble en empezar el siguiente ataque
			_cd -= delta * (0.5 if watched else 1.0)
			if _cd <= 0.0:
				_choose_attack()
		_:
			velocity = Vector2.ZERO


## ¿El jugador mira hacia este punto? (cono delante de hacia donde caminó o atacó)
func sees(at: Vector2) -> bool:
	if not _player_ok():
		return false
	var f: Vector2 = player.get("facing_vec")
	var to := at - player.global_position
	if to.length() < 1.0:
		return true
	return f.normalized().dot(to.normalized()) > GAZE_DOT


## F2+: ¿hay un maniquí tapando la línea entre el jugador y el boss?
func _view_blocked() -> bool:
	if phase < 2 or not _player_ok():
		return false
	var a := player.global_position + Vector2(0, -30)
	var b := global_position + CENTER
	for m in get_tree().get_nodes_in_group("boss_minion"):
		if not is_instance_valid(m) or bool(m.get("_dead")):
			continue
		var c: Vector2 = m.global_position + Vector2(0, -38)
		if c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)) < BLOCK_DIST:
			return true
	return false


func _update_gaze(delta: float) -> void:
	var active := state in ["idle", "attack"]
	var looking := active and sees(global_position + CENTER)
	blocked = looking and _view_blocked()
	watched = looking and not blocked
	if blocked and fmod(_t, 1.5) < delta:
		_say("¡TE TAPAN LA VISTA!", Color(1, 0.5, 0.9), 0.8)
	if _gaze_lock > 0.0:
		_gaze_lock -= delta
	if active:
		if watched:
			unseen_t = 0.0
			if _gaze_lock <= 0.0:
				var fill: float = FILL_TIME[phase - 1] * (1.5 if enraged else 1.0)
				petrify = minf(1.0, petrify + delta / fill)
				if petrify >= 1.0:
					_statue()
		else:
			unseen_t += delta
			petrify = maxf(0.0, petrify - (DECAY_F3 if phase >= 3 else DECAY) * delta)
	# piedra visible: rápida al mirarlo, lenta al soltarlo
	var want := 1.0 if (watched or state == "stunned") else 0.0
	if state == "dead":
		want = 1.0
	stone_k = move_toward(stone_k, want, delta * (6.0 if want > stone_k else 2.5))
	# los tweens del ataque en curso van más lento mientras está en piedra
	var sp := 1.0
	if watched and state == "attack":
		sp = 0.6 if enraged else 0.35
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.set_speed_scale(sp)


func _update_skin(delta: float) -> void:
	var cover: float = COVER[phase - 1]
	if enraged:
		cover = 0.85
	if state == "dead":
		cover = 0.0
	var g := cover * (1.0 - stone_k)
	if state == "stunned":
		g = 0.0
	_seed_t -= delta
	if _seed_t <= 0.0:
		# parpadea más cuando se mueve sin que lo miren
		_seed_t = 0.08 if stone_k < 0.3 else 0.5
		_skin.set_shader_parameter("seed", randf() * 100.0)
	_skin.set_shader_parameter("glitch", g)
	_skin.set_shader_parameter("stone", stone_k * 0.7 + (0.3 if state == "stunned" else 0.0))


func _ai_move(delta: float) -> void:
	if not _player_ok():
		return
	if watched and not enraged:
		velocity = Vector2.ZERO
		return
	# avanza a saltos, como un juego que se salta cuadros
	_step_t -= delta * (0.4 if watched else 1.0)
	if _step_t > 0.0:
		return
	_step_t = [0.42, 0.36, 0.3][phase - 1] * (0.8 if enraged else 1.0)
	var to := player.global_position - global_position
	var dist := to.length()
	var dir := Vector2.ZERO
	if dist > KEEP_DIST + 30.0:
		dir = to.normalized()
	elif dist < KEEP_DIST - 80.0:
		dir = -to.normalized() * 0.6
	if dir == Vector2.ZERO:
		return
	var jump := dir * (MOVE_SPEED * (1.0 + 0.2 * (phase - 1)) * _step_t * 2.2)
	_glitch_ghost()
	global_position += jump
	_clamp_inside()


## Deja una imagen glitch donde estaba (al saltar de cuadro).
func _glitch_ghost() -> void:
	var g := Fx.Ghost.new()
	get_parent().add_child(g)
	g.global_position = global_position


func _clamp_inside() -> void:
	global_position.x = clampf(global_position.x, arena_rect.position.x + 100.0, arena_rect.end.x - 100.0)
	global_position.y = clampf(global_position.y, arena_rect.position.y + 330.0, arena_rect.end.y - 30.0)


func _choose_attack() -> void:
	CoopBoss.retarget(self)
	var pick := ""
	if unseen_t > GRAB_AFTER[phase - 1] and _player_ok():
		pick = "grab"
	elif not _queue.is_empty():
		pick = _queue.pop_front()
	elif _near_t > 1.3:
		pick = "slam"
	elif phase >= 2 and randf() < (0.3 if phase == 2 else 0.45):
		var list: Array = COMBOS[phase]
		_queue.assign(list[randi() % list.size()])
		pick = _queue.pop_front()
	else:
		var pool: Array[String] = ["dig", "masks", "brush", "sew"]
		if phase >= 2:
			pool.append("mannequins")
		var bag: Array[String] = []
		for a in pool:
			if a != _last:
				bag.append(a)
		pick = bag[randi() % bag.size()]
	if pick != "grab":
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
	head.mood = 0
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


## Espera del ataque. Mientras lo miran va más lento (está en piedra).
func _wait(time: float, tok: int) -> bool:
	var left := time
	while left > 0.0:
		await get_tree().physics_frame
		if tok != _tok or not is_inside_tree():
			return false
		var sp := 1.0
		if watched and state == "attack":
			sp = 0.6 if enraged else 0.35
		left -= get_physics_process_delta_time() * sp
	return true


## Espera fija (no le afecta la mirada).
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
	_tw(brush, "rotation", REST_L, 0.3)
	_tw(palette, "rotation", REST_R, 0.3)
	brush.tool = 0
	palette.tool = 0


## Color de los efectos épicos de este boss.
func _accent() -> Color:
	return Color(1.0, 0.3, 1.0)


func _impact(at: Vector2, strength: float) -> void:
	_shake(strength, 0.1 + strength * 0.03)
	Epic.big_hit(get_parent(), at, _accent(), strength, "tex", "fxglitch")
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


# --- La Mirada ------------------------------------------------------------------

## ¡ESTATUA!: barra llena. Se vuelve piedra entera, se agrieta y queda aturdido con daño x2.
func _statue() -> void:
	statues += 1
	_interrupt()
	var tok := _tok
	state = "stunned"
	petrify = 1.0
	tank_open = true
	core.open = true
	head.mood = 2
	statue_left = STATUE_TIME
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.set("stunned_t", 2.0)
	var card := Fx.Card.new()
	card.text = "¡ESTATUA!"
	get_parent().add_child(card)
	card.global_position = global_position
	_tw(brush, "rotation", 0.5, 0.25)
	_tw(palette, "rotation", -0.5, 0.25)
	_pose(Vector2(0, 6), 0.0, 0.2)
	_shake(6.0, 0.4)
	_flash(0.3, Color(0.85, 0.85, 0.9))
	GameFeel.parry_burst(get_parent(), global_position + Vector2(0, -130), 60.0)
	stunned.emit()
	var steps := int(STATUE_TIME / 0.5)
	for i in steps:
		if i == 2:
			pedestal.cracked = true
		if not await _hold(0.5, tok):
			_statue_end()
			return
	_statue_end()
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.6
	head.mood = 0


func _statue_end() -> void:
	tank_open = false
	core.open = false
	petrify = 0.0
	statue_left = 0.0
	unseen_t = 0.0
	_gaze_lock = 2.5   # se recupera: unos segundos sin que la mirada lo llene


## POSE FINAL: aparece pegado al jugador (por la espalda) y lo agarra.
func _atk_grab(tok: int) -> void:
	unseen_t = 0.0
	grabs += 1
	_say("POSE FINAL", Color(1, 0.3, 0.9), 1.0)
	var f: Vector2 = player.get("facing_vec")
	var spot := _clamp_arena(_player_feet() - f.normalized() * 95.0 + Vector2(0, 20))
	_glitch_ghost()
	global_position = spot
	_clamp_inside()
	_flash(0.15, Color(1, 0.2, 1))
	palette.tool = 2
	var hand_at := global_position + SHOULDER_R
	_tw(palette, "rotation", _rot_for(_dir_to_player(hand_at)), 0.2)
	_warn_zone(global_position, _dir_to_player(global_position), 150.0, 0.7, 0.6)
	var t := 0.0
	while t < 0.6:
		if not await _hold(0.05, tok):
			return
		t += 0.05
		if watched:
			# lo viste a tiempo: se congela con la mano abierta
			_say("¡TE VI!", Color(0.6, 1, 0.9), 0.8)
			petrify = minf(0.95, petrify + 0.2)
			if not await _hold(0.6, tok):
				return
			_end_attack(tok)
			return
	_tw(palette, "rotation", _rot_for(_dir_to_player(hand_at)) + 0.3, 0.08)
	_pose(_dir_to_player(global_position) * 16.0, 0.0, 0.08)
	if not await _hold(0.1, tok):
		return
	for v in _victims():
		_victim = v
		if _player_feet().distance_to(global_position) < 175.0 and not bool(v.get("rolling")):
			hurt_player(2, global_position, true)
			_petrify_player(1.0)
	_victim = null
	if not await _hold(0.5, tok):
		return
	_end_attack(tok)


## El jugador queda hecho piedra un momento (no se puede mover).
func _petrify_player(time: float) -> void:
	if not _player_ok():
		return
	var who := _who()
	who.set("speed_mult", 0.0)
	_pose_lock = time
	var p := Fx.PlayerStone.new()
	p.life = time
	who.add_child(p)


# --- Recibir daño ----------------------------------------------------------------

func take_hit(amount: int, from: Vector2) -> void:
	if state in ["intro", "transition", "dead", "paused", "final"]:
		_flash(0.08, Color(0.6, 0.6, 0.7))
		return
	var dmg := amount * (2 if tank_open else 1)
	var center := global_position + CENTER
	var toward := from - center
	toward = Vector2.DOWN if toward.length() < 0.01 else toward.normalized()
	# a un golpe de caer en la fase 3: RENDER FINAL en vez de morir
	if phase >= 3 and not final_victory and hp - dmg <= 0:
		hp = 1
		hp_changed.emit(hp, MAX_HP)
		_start_final()
		return
	hp = maxi(0, hp - dmg)
	hp_changed.emit(hp, MAX_HP)
	_flash(0.1 + 0.02 * dmg, Color(1.0, 0.95, 0.9))
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
	if not tank_open and state in ["idle", "attack"]:
		_poise += dmg
		if _poise >= POISE[phase - 1]:
			_poise = 0
			_stagger()


func pull_toward(_dest: Vector2) -> void:
	_flash(0.06, Color(0.7, 0.7, 0.8))


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
	_say("ERR?", Color(1, 0.6, 1))
	_pose(Vector2(0, 8), 0.06 * (1.0 if randf() < 0.5 else -1.0), 0.12)
	_flash(0.2, Color(1, 0.9, 0.6))
	_shake(3.0, 0.2)
	staggered.emit()
	if not await _hold(0.9, tok):
		return
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.5
	head.mood = 0


func _enter_phase(n: int) -> void:
	phase = n
	_interrupt()
	_statue_end()
	var tok := _tok
	state = "transition"
	if n == 2:
		body.cracked = true
	else:
		head.cracked = true
		pedestal.cracked = true
	head.mood = 1
	_say(PHASE_NAMES[n - 1], Color(1, 0.4, 0.9), 1.4)
	_flash(0.3, Color(1.0, 0.2, 1.0))
	_pose(Vector2(0, -12), 0.0, 0.25)
	_shake(7.0, 0.8)
	phase_changed.emit(n, PHASE_NAMES[n - 1])
	if not await _hold(1.6, tok):
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
	_statue_end()
	var tok := _tok
	state = "transition"
	head.laurel = false
	head.mood = 1
	_say("OBRA PERDIDA", Color(1, 0.2, 0.9), 1.4)
	_pose(Vector2(0, -14), 0.0, 0.3)
	_flash(0.4, Color(1.0, 0.2, 1.0))
	_shake(9.0, 1.0)
	phase_changed.emit(3, "OBRA PERDIDA")
	var w := LaurelFall.new()
	get_parent().add_child(w)
	w.global_position = global_position + HEAD + Vector2(0, -40)
	if not await _hold(1.3, tok):
		return
	_rest_pose()
	state = "idle"
	_cd = 0.3
	head.mood = 0


# --- Ataques ---------------------------------------------------------------------------

## 1. Arqueología: excavación. Sitios marcados en fila hacia el jugador; revientan con vasijas y huesos.
func _atk_dig(tok: int) -> void:
	_say("EXCAVACIÓN", Color(0.9, 0.7, 0.45))
	brush.tool = 2
	_tw(brush, "rotation", PI * 0.85, 0.3)
	if not await _wait(0.35, tok):
		return
	_tw(brush, "rotation", PI * 0.2, 0.08)
	_impact(global_position + Vector2(-60, 10), 4.0)
	var lines: int = [1, 2, 2][phase - 1]
	var n: int = [5, 6, 7][phase - 1]
	for l in lines:
		var from := global_position + Vector2(0, 20)
		var dir := _dir_to_player(from).rotated((l - (lines - 1) * 0.5) * 0.45)
		for i in n:
			var d := Fx.DigSite.new()
			d.delay = 0.13 * i
			d.warn = 0.85 if phase == 1 else 0.7
			d.shards = 4 if phase == 1 else 6
			_add_fx(d, _clamp_arena(from + dir * (90.0 + 80.0 * i)))
	if not await _wait(0.9 + 0.13 * n + 0.6, tok):
		return
	_end_attack(tok)


## 2. Artes Escénicas: comedia y tragedia. Dos máscaras bumerán que vuelven por la espalda del jugador.
func _atk_masks(tok: int) -> void:
	_say("COMEDIA Y TRAGEDIA", Color(1, 0.9, 0.6))
	palette.tool = 1
	_tw(palette, "rotation", -PI * 0.85, 0.35)
	if not await _wait(0.45, tok):
		return
	var rounds: int = [1, 1, 2][phase - 1]
	for r in rounds:
		_tw(palette, "rotation", _rot_for(_dir_to_player(global_position + SHOULDER_R)), 0.1)
		for i in 2:
			var m := Fx.Mask.new()
			m.kind = i
			m.side = -1.0 if i == 0 else 1.0
			m.out_time = 1.0 if phase < 3 else 0.85
			m.back_time = 0.8 if phase < 3 else 0.7
			m.origin = global_position + SHOULDER_R + Vector2(0, 60)
			m.target = _player_feet() + Vector2(0, -20) if _player_ok() else arena_rect.get_center()
			_add_fx(m, m.origin)
		if not await _wait(1.0, tok):
			return
		palette.tool = 0
		if not await _wait(0.9, tok):
			return
		palette.tool = 1
	if not await _wait(0.3, tok):
		return
	_end_attack(tok)


## 3. Artes Plásticas: brochazo. Trazos de pincel gigantes cruzan la arena y dejan pintura que frena.
func _atk_brush(tok: int) -> void:
	_say("BROCHAZO", Color(0.5, 0.75, 1.0))
	brush.tool = 0
	var strokes: int = [2, 3, 3][phase - 1]
	var cols := [Color(0.9, 0.2, 0.2), Color(0.2, 0.45, 0.95), Color(1.0, 0.8, 0.15)]
	for s in strokes:
		_tw(brush, "rotation", PI * 0.9 * (1.0 if s % 2 == 0 else 0.4), 0.25)
		var st := Fx.Stroke.new()
		var c := _player_feet() if _player_ok() else arena_rect.get_center()
		var ang: float = [0.0, PI * 0.5, PI * 0.25, -PI * 0.25][randi() % 4] if s > 0 else 0.0
		st.dir = Vector2.RIGHT.rotated(ang)
		st.area = arena_rect
		st.col = cols[s % 3]
		st.warn = 0.85 if phase == 1 else 0.7
		_add_fx(st, c)
		if not await _wait(st.warn, tok):
			return
		_tw(brush, "rotation", -PI * 0.2, 0.15)
		if not await _wait(0.45, tok):
			return
	if not await _wait(0.4, tok):
		return
	_end_attack(tok)


## 4. Diseño Textil: costura. Agujas en círculo alrededor del jugador; el hilo las une y se cierra.
func _atk_sew(tok: int) -> void:
	_say("COSTURA", Color(1, 0.35, 0.35))
	brush.tool = 1
	_tw(brush, "rotation", PI * 0.8, 0.3)
	if not await _wait(0.35, tok):
		return
	var s := Fx.Seam.new()
	s.r0 = 170.0 if phase < 3 else 150.0
	s.n = [6, 7, 8][phase - 1]
	s.close_time = 1.7 if phase == 1 else 1.4
	_add_fx(s, _player_feet() if _player_ok() else arena_rect.get_center())
	for i in s.n:
		_tw(brush, "rotation", PI * (0.5 + 0.3 * (i % 2)), 0.1)
		if not await _wait(0.1, tok):
			return
	if not await _wait(s.close_time + 0.8, tok):
		return
	_end_attack(tok)


## 5. Sociología: la masa. Maniquíes que también se congelan si los miras.
func _atk_mannequins(tok: int) -> void:
	_say("LA MASA", Color(0.85, 0.85, 0.9))
	palette.tool = 2
	_tw(palette, "rotation", -PI * 0.9, 0.3)
	_pose(Vector2(0, -8), 0.0, 0.3)
	if not await _wait(0.4, tok):
		return
	var n: int = [2, 3, 3][phase - 1]
	var have := get_tree().get_nodes_in_group("boss_minion").size()
	for i in mini(n, 4 - have):
		var m := Fx.Mannequin.new()
		var at := arena_rect.get_center()
		if _player_ok():
			# aparecen detrás y a los lados del jugador
			var f: Vector2 = player.get("facing_vec")
			at = _player_feet() - f.normalized().rotated((i - (n - 1) * 0.5) * 0.9) * 230.0
		_add_fx(m, _clamp_arena(at))
		GameFeel.dust(get_parent(), m.global_position, 5, Vector2.ZERO, 4.0, Vector2(20, 6))
	if not await _wait(0.9, tok):
		return
	_end_attack(tok)


## Golpe de pedestal: salta y cae con onda de choque (si el jugador se queda pegado).
func _atk_slam(tok: int) -> void:
	_say("!!", Color(1, 0.5, 1))
	var max_r := 250.0 if phase < 3 else 320.0
	_warn_zone(global_position, Vector2.DOWN, max_r, 0.0, 0.8)
	_tw(brush, "rotation", PI * 0.9, 0.6)
	_tw(palette, "rotation", -PI * 0.9, 0.6)
	_pose(Vector2(0, -40), 0.0, 0.6)
	if not await _wait(0.8, tok):
		return
	_pose(Vector2(0, 4), 0.0, 0.07)
	_impact(global_position, 9.0)
	var ring := BossFx.ShockRing.new()
	ring.max_r = max_r
	_add_fx(ring, global_position)
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)


# --- Aparición y muerte -----------------------------------------------------------


# --- RENDER FINAL (duelo final) -----------------------------------------------------------
## A un golpe de caer: se apaga el museo y solo queda tu foco. La estatua se desvanece, aparece en la
## oscuridad (dos ojos magenta) y se lanza contra ti: parry al lanzarse. Si la estás mirando cuando se lanza,
## va más lenta. A veces amaga en un sitio y aparece en otro. FINAL_ROUNDS = se le carga la textura: mármol.
func _start_final() -> void:
	_interrupt()
	_statue_end()
	var tok := _tok
	state = "final"
	_final_hits = 0
	_final_fail = false
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.call("die")
	_free_player()
	Final.title(self, "RENDER FINAL", Color(1.0, 0.35, 0.9), "Mírala y haz parry cuando se lance")
	Final.music_cue(self, "final1")
	_fdark = Spotlight.new()
	_fdark.set("player", player)
	_fdark.set("area", arena_rect)
	get_parent().add_child(_fdark)
	if not await _hold(1.4, tok):
		return
	while _final_hits < FINAL_ROUNDS and not _final_fail:
		if not await _final_round(tok):
			return
	if is_instance_valid(_fdark):
		_fdark.call("fade")
	visible = true
	if _final_fail:
		_final_lost(tok)
	else:
		_final_won()


func _final_round(tok: int) -> bool:
	if not _player_ok():
		return false
	# se desvanece con un glitch
	_glitch_ghost()
	visible = false
	var feints := 0 if _final_hits < 3 else (1 if _final_hits < 5 else 2)
	for k in feints + 1:
		# un punto en la oscuridad a buena distancia (si el jugador está contra una pared, prueba otro)
		var at := player.global_position
		for tries in 12:
			at = _clamp_arena(player.global_position + Vector2.from_angle(randf() * TAU) * Vector2(300, 220))
			if at.distance_to(player.global_position) > 230.0:
				break
		global_position = at
		var eyes := Eyes.new()
		eyes.life = 0.45 if k < feints else lerpf(1.0, 0.55, float(_final_hits) / FINAL_ROUNDS)
		get_parent().add_child(eyes)
		eyes.global_position = at + Vector2(0, -150)
		if not await _hold(eyes.life, tok):
			return false
	# ¡se lanza! (un fantasma glitch de la estatua)
	var from := global_position + Vector2(0, -90)
	var slow := 0.65 if sees(global_position + CENTER) else 1.0
	var shot := Lunge.new()
	shot.col = Color(1.0, 0.3, 0.9)
	shot.strict = 0.2 if _final_hits < 3 else 0.17
	shot.damage = 2
	shot.target = Vector2(0, -90)
	shot.size = 30.0
	# el fantasma es grande: choca donde se ve (antes había que dejarlo llegar al centro y el parry se pasaba)
	shot.hit_r = 58.0
	shot.cover_deg = 110.0
	_add_fx(shot, from)
	shot.aim_at(_player_body(), lerpf(380.0, 620.0, float(_final_hits) / FINAL_ROUNDS) * slow)
	if slow < 1.0:
		_say("¡LA VES!", Color(0.6, 1, 0.9), 0.5)
	_final_wait = true
	var w := 0.0
	while _final_wait and w < 4.0:
		if not await _hold(0.05, tok):
			return false
		w += 0.05
	return true


func final_result(ok: bool, _shot: Node) -> void:
	if state != "final":
		return
	if not ok:
		_final_fail = true
		_final_wait = false
		_petrify_player(1.0)
		return
	GameFeel.hit_stop(get_tree(), 0.06)


## El fantasma rechazado vuelve a la estatua: aparece un instante en mármol.
func final_back(shot: Node2D) -> void:
	shot.queue_free()
	_final_hits += 1
	visible = true
	stone_k = 1.0
	_flash(0.2, Color(0.9, 0.9, 1.0))
	GameFeel.parry_burst(get_parent(), global_position + CENTER, 40.0)
	_shake(4.0, 0.2)
	_say("RENDER %d/%d" % [_final_hits, FINAL_ROUNDS], Color(0.9, 0.9, 1.0), 0.7)
	if _final_hits == 2:
		Final.music_cue(self, "final2")
	elif _final_hits == 4:
		Final.music_cue(self, "final3")
	if _fdark and is_instance_valid(_fdark):
		_fdark.call("reveal", global_position + CENTER)
	_final_wait = false


func _final_won() -> void:
	# clímax con QTE antes del remate; si se falla, vuelve la fase 3 como al perder el duelo
	if not await _climax():
		_final_lost(_tok)
		return
	final_victory = true
	Final.music_final(self, "epic")
	Final.title(self, "RENDER COMPLETO", Color(0.9, 0.9, 1.0), "Textura cargada: mármol puro", 1.6)
	await _finisher()
	_shake(10.0, 0.6)
	hp = 0
	hp_changed.emit(hp, MAX_HP)
	_die()


func _final_lost(tok: int) -> void:
	for h in get_tree().get_nodes_in_group("final_shot"):
		h.queue_free()
	Final.title(self, "POSE FINAL", Color(1.0, 0.3, 0.9), "", 1.1)
	Final.music_cue(self, "p3")
	visible = true
	if not await _hold(1.2, tok):
		return
	state = "idle"
	_cd = 1.0


# --- Lluvia de cambio de fase propia: VANDALISMO EN EL MUSEO -------------------------------
## Brochazos que cruzan la sala, máscaras bumerán, excavaciones en estrella y baldosas de textura
## faltante (cuadriculado magenta) que parpadean y queman.
func barrage_title(_n: int) -> String:
	return "VANDALISMO EN EL MUSEO"


func barrage_plan(n: int) -> Array:
	if n == 2:
		return [[0.2, "tiles", {"n": 10}], [1.4, "strokes", {"n": 2}], [3.0, "masks", {}],
			[4.6, "dig", {"lines": 4}], [6.0, "tiles", {"n": 12}]]
	return [[0.2, "tiles", {"n": 12}], [1.2, "strokes", {"n": 3}], [2.8, "masks", {}],
		[4.0, "dig", {"lines": 6}], [5.2, "tiles", {"n": 16}], [6.4, "strokes", {"n": 3}], [7.8, "masks", {}]]


func _bfx(n: Node2D, at: Vector2) -> void:
	_add_fx(n, at)
	Barrage.tag(n)


func _bar_tiles(a: Dictionary, _tok: int) -> void:
	for i in int(a["n"]):
		var g := GlitchTile.new()
		g.delay = 0.06 * i
		var at := _player_feet() if (_player_ok() and i % 4 == 0) else Vector2(randf_range(arena_rect.position.x + 60, arena_rect.end.x - 60), randf_range(arena_rect.position.y + 100, arena_rect.end.y - 40))
		_bfx(g, _clamp_arena(at))


func _bar_strokes(a: Dictionary, tok: int) -> void:
	var cols := [Color(0.9, 0.2, 0.2), Color(0.2, 0.45, 0.95), Color(1.0, 0.8, 0.15)]
	for s in int(a["n"]):
		var st := Fx.Stroke.new()
		var c := _player_feet() if _player_ok() else arena_rect.get_center()
		st.dir = Vector2.RIGHT.rotated([0.0, PI * 0.5, PI * 0.25, -PI * 0.25][randi() % 4])
		st.area = arena_rect
		st.col = cols[s % 3]
		st.warn = 0.75
		_bfx(st, c)
		_tw(brush, "rotation", PI * 0.9 * (1.0 if s % 2 == 0 else 0.4), 0.2)
		if not await _hold(0.6, tok):
			return


func _bar_masks(_a: Dictionary, _tok: int) -> void:
	for i in 2:
		var m := Fx.Mask.new()
		m.kind = i
		m.side = -1.0 if i == 0 else 1.0
		m.out_time = 0.9
		m.back_time = 0.75
		m.origin = global_position + SHOULDER_R + Vector2(0, 60)
		m.target = _player_feet() + Vector2(0, -20) if _player_ok() else arena_rect.get_center()
		_bfx(m, m.origin)


func _bar_dig(a: Dictionary, _tok: int) -> void:
	var from := global_position + Vector2(0, 20)
	var base := _dir_to_player(from)
	var n: int = a["lines"]
	for l in n:
		var dir := base.rotated(TAU * l / n)
		for i in 6:
			var d := Fx.DigSite.new()
			d.delay = 0.1 * i
			d.warn = 0.75
			d.shards = 4
			_bfx(d, _clamp_arena(from + dir * (90.0 + 75.0 * i)))
	_impact(from, 4.0)


## REMATE: la textura termina de cargar: queda de mármol puro, se agrieta de arriba abajo y se parte en trozos.
func _finisher() -> void:
	stone_k = 1.0
	visible = true
	_flash(0.4, Color(1, 1, 1))
	pedestal.cracked = true
	await get_tree().create_timer(0.5).timeout
	for i in 5:
		GameFeel.parry_burst(get_parent(), global_position + Vector2(randf_range(-40, 40), -220 + i * 45), 22.0)
		_shake(2.0 + i, 0.1)
		await get_tree().create_timer(0.14).timeout
	for i in 12:
		var d := BossFx.Debris.new()
		d.kind = i % 8
		d.prefix = "boss_tex_debris_"
		d.vel = Vector2(randf_range(-260, 260), randf_range(-420, -180))
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-220, -60))
	await get_tree().create_timer(0.5).timeout


## Baldosa de textura faltante: parpadea en magenta y negro y luego quema (no se bloquea). 2 de daño.
class GlitchTile extends BossFx.Hazard:
	var delay := 0.0
	var warn := 0.8
	var t := 0.0
	var _boom := false
	const S := 70.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		var lt := t - delay
		if lt >= warn and not _boom:
			_boom = true
			for v in victims():
				_victim = v
				var d := player_feet() - global_position
				if absf(d.x) < S * 0.5 and absf(d.y) < S * 0.3:
					hurt(2, true)
			_victim = null
		if lt > warn + 0.35:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var lt := t - delay
		if lt < 0.0:
			return
		var r := Rect2(-S * 0.5, -S * 0.3, S, S * 0.6)
		var cell := S / 6.0
		var on := int(lt * 12.0) % 2 == 0
		var a := 0.35 if not _boom else 0.9 * (1.0 - clampf((lt - warn) / 0.35, 0.0, 1.0))
		for yy in 4:
			for xx in 6:
				var m := (xx + yy + (1 if on else 0)) % 2 == 0
				draw_rect(Rect2(r.position + Vector2(xx * cell, yy * r.size.y / 4.0), Vector2(cell, r.size.y / 4.0)), Color(1, 0, 1, a) if m else Color(0, 0, 0, a))
		draw_rect(r, Color(1, 0.3, 1, 0.8), false, 2.0)



func start_intro(skip: bool) -> void:
	state = "intro"
	if skip:
		await get_tree().create_timer(0.6).timeout
		intro_finished.emit()
		return
	# 1. las luces del museo se apagan; la estatua está quieta al fondo
	var home := position
	var dark := Dark.new()
	dark.area = arena_rect
	get_parent().add_child(dark)
	dark.global_position = Vector2.ZERO
	position = home + Vector2(0, -150)
	stone_k = 1.0
	_say("ALARMA DE SEGURIDAD", Color(1, 0.3, 0.3), 1.2)
	await get_tree().create_timer(1.4).timeout
	# 2. un parpadeo y ya está más cerca, con los ojos encendidos
	dark.blink()
	await get_tree().create_timer(0.18).timeout
	position = home
	head.mood = 1
	_flash(0.25, Color(1, 0.2, 1))
	_shake(6.0, 0.4)
	await get_tree().create_timer(0.7).timeout
	dark.fade()
	head.mood = 0
	stone_k = 0.0
	# 3. firma: se tuerce como estatua clásica con la brocha atrás y da un brochazo que
	#    pinta textura rota (cuadros magenta) cruzando toda la pantalla.
	_tw(brush, "rotation", PI * 0.8, 0.3)
	_tw(palette, "rotation", -0.5, 0.3)
	_pose(Vector2(-10, -6), -0.14, 0.3)
	await get_tree().create_timer(0.45).timeout
	_tw(brush, "rotation", -1.1, 0.12)
	_pose(Vector2(10, 2), 0.12, 0.12)
	await get_tree().create_timer(0.08).timeout
	var sw := Roar.Swipe.new()
	sw.y = clampf(head.get_global_transform_with_canvas().origin.y + 60.0, 140.0, 560.0)
	get_parent().add_child(sw)
	_flash(0.2, Color(1, 0.2, 1))
	_shake(7.0, 0.5)
	_say("MISSING TEXTURE", Color(1, 0.3, 1), 1.4)
	await get_tree().create_timer(1.3).timeout
	_rest_pose()
	_rest_arms()
	intro_finished.emit()


func begin_fight() -> void:
	state = "idle"
	_cd = 1.0


func pause_ai() -> void:
	_interrupt()
	state = "paused"
	_free_player()


func _free_player() -> void:
	_pose_lock = 0.0
	if _player_ok() and float(player.get("speed_mult")) < 1.0 and float(player.get("speed_mult")) >= 0.0:
		player.set("speed_mult", 1.0)


func _die() -> void:
	_interrupt()
	state = "dead"
	tank_open = false
	remove_from_group("enemies")
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.call("die")
	_free_player()
	Engine.time_scale = 0.2
	head.mood = 2
	await get_tree().create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 1.0
	# la textura se apaga y se agrieta entera
	body.cracked = true
	pedestal.cracked = true
	head.cracked = true
	head.broken = true
	var card := Fx.Card.new()
	card.text = "OBRA RESTAURADA"
	card.life = 2.4
	get_parent().add_child(card)
	card.global_position = global_position
	_pose(Vector2(0, 6), 0.0, 0.4)
	await get_tree().create_timer(2.0).timeout
	# la cabeza cae y rueda, el cuerpo se derrumba en pedazos de mármol
	core.broken = true
	GameFeel.parry_burst(get_parent(), global_position + CORE, 70.0)
	for i in 18:
		var d := BossFx.Debris.new()
		d.kind = i % 8
		d.prefix = "boss_tex_debris_"
		d.vel = Vector2(randf_range(-300, 300), randf_range(-460, -200))
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(randf_range(-60, 60), randf_range(-200, -60))
	for p in [brush, palette]:
		var tw := create_tween()
		tw.tween_property(p, "rotation", (1.0 if p == brush else -1.0) * 1.6, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(self, "rig_off", Vector2(0, 26), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(rig, "rotation", 0.12, 0.5)
	fall.tween_property(head, "anim_off", Vector2(150, 200), 1.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(head, "rotation", 5.0, 1.0)
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
	var open := false         # núcleo expuesto
	var broken := false
	var cracked := false
	var laurel := true
	var mood := 0             # 0 normal, 1 enojado, 2 aturdido
	var tool := 0             # pincel: 0 pincel, 1 aguja, 2 paleta de arqueólogo · paleta: 0 paleta, 1 máscaras, 2 mano

	const OUT := Color(0.08, 0.07, 0.08)
	const MARBLE := Color(0.93, 0.92, 0.89)
	const MARBLE_D := Color(0.76, 0.75, 0.73)
	const VEIN := Color(0.6, 0.6, 0.62)
	const STONE := Color(0.6, 0.58, 0.55)
	const STONE_D := Color(0.45, 0.43, 0.41)
	const GOLD := Color(0.92, 0.74, 0.28)
	const BRONZE := Color(0.62, 0.42, 0.2)
	const ROPE := Color(0.72, 0.1, 0.14)
	const EYE := Color(0.4, 1.0, 1.0)

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
			"pedestal":
				_pedestal()
			"body":
				_body()
			"core":
				_core()
			"head":
				_head()
			"brush":
				_brush()
			"palette":
				_palette()

	## Con sprites de grokbot (bosses/tex/). El cuadriculado y la piedra los pone el shader del rig.
	func _draw_sprite() -> bool:
		var base := Spr.tex("boss_tex_body_0")
		if base == null:
			return false
		match kind:
			"pedestal":
				# el pedestal viene en la misma imagen que el cuerpo
				return true
			"body":
				var hurt: bool = cracked or (boss != null and bool(boss.get("pedestal").get("cracked")))
				var tx: Texture2D = Spr.tex("boss_tex_body_1") if hurt else base
				if tx == null:
					tx = base
				draw_texture(tx, Vector2(-tx.get_width() * 0.5, -tx.get_height()))
				return true
			"core":
				var idx := 2 if broken else (1 if open else 0)
				var tx := Spr.tex("boss_tex_core_%d" % idx)
				if tx == null:
					return false
				if open and not broken:
					draw_circle(Vector2.ZERO, 30.0 + 3.0 * sin(t * 10.0), Color(1.0, 0.9, 0.5, 0.25))
				draw_texture(tx, -tx.get_size() * 0.5)
				return true
			"head":
				var idx := 2 if broken else (1 if cracked else 0)
				var tx := Spr.tex("boss_tex_head_%d" % idx)
				if tx == null:
					return false
				draw_texture(tx, Vector2(-tx.get_width() * 0.5, -tx.get_height()))
				# ojos: magenta cuando ataca, apagados cuando es estatua
				if mood != 0:
					var col := Color(1.0, 0.2, 1.0, 0.75) if mood == 1 else Color(0.35, 0.35, 0.4, 0.85)
					for ex in [-2.0, 9.0]:
						draw_circle(Vector2(ex, -47), 3.0, col)
				return true
			"brush", "palette":
				var name := "boss_tex_%s_%d" % [kind, tool]
				var tx := Spr.tex(name)
				if tx == null:
					return false
				var piv: Vector2 = ARM_PIVOT.get(name, Spr.top_pivot(name))
				draw_texture(tx, -piv)
				return true
		return false

	func _pedestal() -> void:
		# postes dorados con la cuerda roja de museo
		for s in [-1.0, 1.0]:
			var p := Vector2(96 * s, 0)
			draw_line(p, p + Vector2(0, -52), OUT, 6.0)
			draw_line(p, p + Vector2(0, -52), GOLD, 3.0)
			draw_circle(p + Vector2(0, -54), 5, GOLD)
			draw_rect(Rect2(p.x - 9, -4, 18, 5), GOLD.darkened(0.2))
			var a := p + Vector2(0, -48)
			var b := Vector2(66 * s, -40)
			var pts := PackedVector2Array()
			for i in 9:
				var k := i / 8.0
				pts.append(a.lerp(b, k) + Vector2(0, sin(k * PI) * 12.0))
			draw_polyline(pts, ROPE, 4.0)
		# pedestal de piedra
		_box(Rect2(-70, -62, 140, 60), STONE, 3.0)
		_box(Rect2(-78, -70, 156, 12), STONE.lightened(0.15), 2.0)
		_box(Rect2(-76, -6, 152, 8), STONE_D, 2.0)
		# placa de bronce
		_box(Rect2(-26, -46, 52, 20), BRONZE, 1.5)
		draw_rect(Rect2(-22, -42, 44, 12), BRONZE.lightened(0.15))
		if cracked:
			draw_polyline(PackedVector2Array([Vector2(-60, -60), Vector2(-46, -36), Vector2(-54, -12)]), OUT, 2.0)
			draw_polyline(PackedVector2Array([Vector2(52, -62), Vector2(40, -30), Vector2(48, -8)]), OUT, 2.0)

	func _body() -> void:
		# piernas de mármol que salen del pedestal
		for s in [-1.0, 1.0]:
			_box(Rect2(20 * s - 13, -118, 26, 52), MARBLE, 2.0)
			draw_line(Vector2(20 * s - 4, -112), Vector2(20 * s + 2, -76), VEIN, 1.0)
		# torso de estatua griega
		var torso := PackedVector2Array([Vector2(-50, -204), Vector2(50, -204), Vector2(42, -150), Vector2(34, -112), Vector2(-34, -112), Vector2(-42, -150)])
		_poly(torso, MARBLE, 3.0)
		# músculos
		draw_arc(Vector2(-18, -182), 14, 0.2, PI - 0.2, 8, MARBLE_D, 2.0)
		draw_arc(Vector2(18, -182), 14, 0.2, PI - 0.2, 8, MARBLE_D, 2.0)
		for i in 3:
			draw_line(Vector2(-12, -140 + i * 10), Vector2(12, -140 + i * 10), MARBLE_D, 1.5)
		# toga cruzada
		_poly(PackedVector2Array([Vector2(-50, -204), Vector2(-28, -204), Vector2(40, -118), Vector2(34, -112), Vector2(14, -112)]), MARBLE_D.lightened(0.1), 2.0)
		for k in 3:
			draw_line(Vector2(-36 + k * 8, -198), Vector2(22 + k * 6, -122), VEIN, 1.0)
		# manchas de pintura
		draw_circle(Vector2(-30, -130), 4, Color(0.9, 0.2, 0.2))
		draw_circle(Vector2(26, -190), 3, Color(0.2, 0.45, 0.95))
		draw_circle(Vector2(-8, -120), 3, Color(1.0, 0.8, 0.15))
		# hombros redondos
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(56 * s, -190), 15, MARBLE)
			draw_arc(Vector2(56 * s, -190), 15, 0, TAU, 16, OUT, 2.0)
		if cracked:
			draw_polyline(PackedVector2Array([Vector2(-40, -196), Vector2(-24, -172), Vector2(-34, -150), Vector2(-20, -128)]), OUT, 2.0)
			draw_polyline(PackedVector2Array([Vector2(36, -200), Vector2(26, -180), Vector2(34, -166)]), OUT, 1.5)

	func _core() -> void:
		var r := Rect2(-20, -16, 40, 32)
		if open:
			draw_rect(r.grow(8.0 + 3.0 * sin(t * 10.0)), Color(0.6, 1.0, 0.5, 0.25))
		_box(r.grow(4.0), GOLD, 2.0)
		if broken:
			_box(r, Color(0.08, 0.06, 0.06), 1.5)
			draw_polyline(PackedVector2Array([r.position, r.get_center(), r.end]), GOLD.darkened(0.3), 2.0)
			return
		if open:
			# un cuadro abstracto brillante (el punto débil)
			draw_rect(r, Color(0.1, 0.1, 0.25))
			draw_circle(r.get_center() + Vector2(-6, -3), 8, Color(1, 0.3 + 0.2 * sin(t * 8.0), 0.3))
			draw_rect(Rect2(r.position + Vector2(18, 6), Vector2(14, 20)), Color(0.2, 0.6, 1.0))
			draw_line(r.position + Vector2(4, 26), r.position + Vector2(36, 8), Color(1, 0.85, 0.2), 3.0)
			return
		_box(r, MARBLE, 1.5)
		draw_line(r.position + Vector2(6, 8), r.position + Vector2(30, 22), VEIN, 1.0)

	func _head() -> void:
		var g := Vector2(0, -34)
		# marco dorado de museo detrás, como aureola
		draw_rect(Rect2(g.x - 40, g.y - 46, 80, 92), GOLD.darkened(0.15))
		draw_rect(Rect2(g.x - 40, g.y - 46, 80, 92), OUT, false, 2.0)
		draw_rect(Rect2(g.x - 32, g.y - 38, 64, 76), Color(0.25, 0.12, 0.1))
		# cuello
		_box(Rect2(-10, -10, 20, 14), MARBLE_D, 1.5)
		# cabeza de estatua
		var face := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			face.append(g + Vector2(cos(a) * 24.0, sin(a) * 29.0))
		_poly(face, MARBLE, 2.5)
		# pelo de rizos de mármol
		for k in 5:
			draw_circle(g + Vector2(-20 + k * 10, -24), 7, MARBLE_D)
		if laurel:
			for s in [-1.0, 1.0]:
				for k in 4:
					var lp := g + Vector2(s * (8 + k * 6), -24 + k * 4)
					draw_colored_polygon(PackedVector2Array([lp, lp + Vector2(s * 7, -4), lp + Vector2(s * 3, 4)]), GOLD)
		# máscara serena con ranuras de ojos
		var ec := EYE
		match mood:
			1:
				ec = Color(1, 0.25, 0.9)
			2:
				ec = Color(0.5, 0.5, 0.55)
		for s in [-1.0, 1.0]:
			var e := g + Vector2(9 * s, -2)
			if mood == 1:
				draw_line(e + Vector2(-6, -3 * s), e + Vector2(6, 3 * s), ec, 3.0)
			else:
				draw_line(e + Vector2(-6, 0), e + Vector2(6, 0), ec, 3.0)
		draw_line(g + Vector2(0, 0), g + Vector2(-2, 10), MARBLE_D, 2.0)
		draw_line(g + Vector2(-6, 16), g + Vector2(6, 16), MARBLE_D, 2.0)
		if cracked:
			draw_polyline(PackedVector2Array([g + Vector2(-14, -20), g + Vector2(-4, -6), g + Vector2(-12, 8), g + Vector2(-2, 22)]), OUT, 1.5)
		if broken:
			draw_colored_polygon(PackedVector2Array([g + Vector2(2, -28), g + Vector2(24, -10), g + Vector2(20, 20), g + Vector2(4, 12), g + Vector2(10, -4)]), Color(0.15, 0.13, 0.14))

	func _arm(len: float) -> void:
		draw_circle(Vector2.ZERO, 14, MARBLE)
		_box(Rect2(-10, 0, 20, len * 0.55), MARBLE, 2.0)
		_box(Rect2(-8, len * 0.55, 16, len * 0.35), MARBLE, 2.0)
		draw_line(Vector2(-4, 8), Vector2(2, len * 0.5), VEIN, 1.0)
		draw_circle(Vector2(0, len * 0.92), 10, MARBLE)
		draw_arc(Vector2(0, len * 0.92), 10, 0, TAU, 12, OUT, 1.5)
		draw_arc(Vector2.ZERO, 14, 0, TAU, 14, OUT, 2.0)

	func _brush() -> void:
		_arm(104.0)
		match tool:
			0:   # pincel gigante
				draw_line(Vector2(0, 92), Vector2(0, 150), OUT, 8.0)
				draw_line(Vector2(0, 92), Vector2(0, 150), Color(0.55, 0.35, 0.18), 5.0)
				_box(Rect2(-7, 146, 14, 8), Color(0.7, 0.7, 0.72), 1.5)
				_poly(PackedVector2Array([Vector2(-9, 154), Vector2(9, 154), Vector2(4, 178), Vector2(-4, 178)]), Color(0.9, 0.2, 0.2), 1.5)
			1:   # aguja de coser con hilo
				draw_line(Vector2(0, 90), Vector2(0, 170), OUT, 6.0)
				draw_line(Vector2(0, 90), Vector2(0, 170), Color(0.82, 0.84, 0.88), 3.0)
				draw_arc(Vector2(0, 96), 4, 0, TAU, 8, OUT, 2.0)
				var pts := PackedVector2Array()
				for i in 8:
					pts.append(Vector2(4 + sin(i * 0.9 + t * 3.0) * 6.0, 96 + i * 8))
				draw_polyline(pts, ROPE, 2.0)
			_:   # paleta de arqueólogo
				draw_line(Vector2(0, 92), Vector2(0, 128), Color(0.45, 0.28, 0.14), 6.0)
				_poly(PackedVector2Array([Vector2(0, 126), Vector2(14, 140), Vector2(0, 168), Vector2(-14, 140)]), Color(0.7, 0.72, 0.75), 2.0)

	func _palette() -> void:
		_arm(104.0)
		match tool:
			0:   # paleta de pintor como escudo
				var c := Vector2(0, 112)
				var pts := PackedVector2Array()
				for i in 18:
					var a := TAU * i / 18.0
					pts.append(c + Vector2(cos(a) * 30.0, sin(a) * 22.0))
				_poly(pts, Color(0.68, 0.48, 0.28), 2.0)
				for k in 5:
					var cc: Color = [Color(0.9, 0.2, 0.2), Color(0.2, 0.45, 0.95), Color(1, 0.8, 0.15), Color(0.2, 0.75, 0.3), Color(0.95, 0.95, 0.95)][k]
					draw_circle(c + Vector2(cos(k * 1.2 - 2.2) * 18.0, sin(k * 1.2 - 2.2) * 12.0), 5, cc)
				draw_circle(c + Vector2(14, 8), 5, Color(0.3, 0.2, 0.12))
			1:   # las dos máscaras de teatro
				for s in [-1.0, 1.0]:
					var m := Vector2(14 * s, 112 + 4 * s)
					draw_circle(m, 13, Color(0.97, 0.95, 0.9) if s < 0.0 else Color(0.2, 0.18, 0.22))
					draw_arc(m, 13, 0, TAU, 14, OUT, 1.5)
					var ec := OUT if s < 0.0 else Color(0.9, 0.9, 0.9)
					draw_circle(m + Vector2(-5, -3), 2, ec)
					draw_circle(m + Vector2(5, -3), 2, ec)
					if s < 0.0:
						draw_arc(m + Vector2(0, 2), 6, 0.3, PI - 0.3, 8, ec, 2.0)
					else:
						draw_arc(m + Vector2(0, 9), 6, PI + 0.3, TAU - 0.3, 8, ec, 2.0)
			_:   # mano abierta que agarra
				var h := Vector2(0, 112)
				draw_circle(h, 15, MARBLE)
				draw_arc(h, 15, 0, TAU, 14, OUT, 2.0)
				for k in 5:
					var a := PI * 0.5 + (k - 2) * 0.38
					var f := h + Vector2(cos(a), sin(a)) * 14.0
					draw_line(f, f + Vector2(cos(a), sin(a)) * 16.0, OUT, 8.0)
					draw_line(f, f + Vector2(cos(a), sin(a)) * 16.0, MARBLE, 5.0)


## Luces apagadas de la aparición (con un parpadeo).
class Dark extends Node2D:
	var area := Rect2(-500, -310, 1000, 620)
	var a := 0.0

	func _ready() -> void:
		z_index = 15
		create_tween().tween_property(self, "a", 0.65, 0.5)

	func blink() -> void:
		var tw := create_tween()
		tw.tween_property(self, "a", 1.0, 0.06)
		tw.tween_interval(0.12)
		tw.tween_property(self, "a", 0.65, 0.06)

	func fade() -> void:
		var tw := create_tween()
		tw.tween_property(self, "a", 0.0, 0.5)
		tw.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(area.grow(300.0), Color(0, 0, 0, a))


## Corona de laurel que cae al entrar en furia.
class LaurelFall extends Node2D:
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
		var tx := Spr.tex("boss_tex_head_3")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO)
			return
		draw_arc(Vector2.ZERO, 18, PI * 1.1, PI * 1.9, 12, Color(0.92, 0.74, 0.28), 5.0)
		for k in 6:
			var a := PI * 1.1 + k * 0.16
			var p := Vector2(cos(a), sin(a)) * 18.0
			draw_circle(p, 4, Color(0.92, 0.74, 0.28))


## Ficha técnica del museo: reemplaza la barra de vida (vida, fase, petrificación y estado).
class Placard extends Control:
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
		draw_rect(r, Color(0.93, 0.91, 0.86, 0.95))
		if boss == null or not is_instance_valid(boss):
			return
		var f := ThemeDB.fallback_font
		var ink := Color(0.15, 0.13, 0.12)
		var k: float = float(boss.get("hp")) / float(boss.get("MAX_HP"))
		var ph: int = boss.get("phase")
		draw_string(f, Vector2(10, 18), "«Sin título» · MISSING TEXTURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.1, 0.5))
		var names := ["Sala permanente", "Exposición temporal", "Restauración fallida"]
		var tag: String = names[ph - 1]
		if boss.get("enraged"):
			tag = "OBRA PERDIDA"
		draw_string(f, Vector2(260, 18), "%s · Fase %d/3" % [tag, ph], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		# petrificación
		var pk: float = boss.get("petrify")
		draw_string(f, Vector2(10, 45), "Petrificación:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		var bar := Rect2(104, 32, 200, 18)
		draw_rect(bar, Color(0.75, 0.72, 0.68))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * pk, bar.size.y)), Color(0.55, 0.55, 0.6))
		draw_rect(bar, ink, false, 1.5)
		# estado
		var st: String = boss.get("state")
		var sl: float = boss.get("statue_left")
		var label := "MISSING TEXTURE"
		var col := Color(0.85, 0.1, 0.8)
		if st == "stunned" and sl > 0.0:
			label = "¡ESTATUA! x2"
			col = Color(0.15, 0.55, 0.25)
		elif bool(boss.get("watched")):
			label = "PIEDRA (te ve)"
			col = Color(0.35, 0.35, 0.4)
		draw_rect(Rect2(316, 32, 160, 18), col)
		draw_string(f, Vector2(316, 46), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 11, Color(1, 1, 1))
		draw_string(f, Vector2(480, 45), "Estatuas %d" % int(boss.get("statues")), HORIZONTAL_ALIGNMENT_RIGHT, 110, 12, ink)
		# barra de vida
		draw_rect(Rect2(0, 62, 600, 10), Color(0.3, 0.28, 0.26, 0.9))
		draw_rect(Rect2(0, 62, 600 * _chip, 10), Color(1, 0.95, 0.9))
		draw_rect(Rect2(0, 62, 600 * k, 10), Color(0.75, 0.15, 0.65))
		for fr in [0.6, 0.3]:
			draw_rect(Rect2(600 * fr - 1, 62, 2, 10), Color(0, 0, 0, 0.8))
		draw_rect(r, Color(0.72, 0.58, 0.25), false, 2.0)


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
		# como una placa de museo
		draw_rect(box, Color(0.12, 0.1, 0.1, 0.92 * a))
		draw_rect(box, Color(0.92, 0.74, 0.28, a), false, 2.0)
		draw_string(f, Vector2(-w * 0.5, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, a))


## Duelo final: sala a oscuras con un foco que sigue al jugador.
class Spotlight extends Node2D:
	var player: Node2D
	var area := Rect2(-500, -310, 1000, 620)
	var a := 0.0
	var r := 175.0
	var _flash := 0.0
	var _flash_at := Vector2.ZERO

	func _ready() -> void:
		z_index = 15
		create_tween().tween_property(self, "a", 0.88, 0.6)

	func reveal(at: Vector2) -> void:
		_flash = 1.0
		_flash_at = at

	func fade() -> void:
		var tw := create_tween()
		tw.tween_property(self, "a", 0.0, 0.5)
		tw.tween_callback(queue_free)

	func _process(delta: float) -> void:
		_flash = maxf(0.0, _flash - delta * 2.5)
		queue_redraw()

	func _draw() -> void:
		if player == null or not is_instance_valid(player):
			return
		var p := player.global_position + Vector2(0, -20) - global_position
		var big := area.grow(400.0)
		big.position -= global_position
		var col := Color(0, 0, 0, a)
		# todo oscuro menos un cuadrado alrededor del jugador...
		draw_rect(Rect2(big.position, Vector2(big.size.x, p.y - r - big.position.y)), col)
		draw_rect(Rect2(Vector2(big.position.x, p.y + r), Vector2(big.size.x, big.end.y - p.y - r)), col)
		draw_rect(Rect2(Vector2(big.position.x, p.y - r), Vector2(p.x - r - big.position.x, 2 * r)), col)
		draw_rect(Rect2(Vector2(p.x + r, p.y - r), Vector2(big.end.x - p.x - r, 2 * r)), col)
		# ...y las esquinas del cuadrado, para que el foco sea redondo (con borde suave)
		draw_arc(p, r * 1.21, 0, TAU, 48, col, r * 0.42)
		for k in 4:
			draw_arc(p, r * (0.92 + k * 0.03), 0, TAU, 48, Color(0, 0, 0, a * 0.2), r * 0.04)
		if _flash > 0.0:
			draw_circle(_flash_at - global_position, 120.0, Color(1, 1, 1, 0.25 * _flash))


## Dos ojos magenta en la oscuridad: ahí aparece la estatua.
class Eyes extends Node2D:
	var life := 0.8
	var t := 0.0

	func _ready() -> void:
		z_index = 16

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / 0.15, 0.0, 1.0) * (0.7 + 0.3 * sin(t * 30.0))
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(12 * s, 0), 9.0, Color(1, 0.2, 0.9, 0.25 * k))
			draw_circle(Vector2(12 * s, 0), 4.0, Color(1, 0.5, 1.0, k))
		var g := 1.0 - clampf(t / life, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 30.0 + 40.0 * g, 0, TAU, 24, Color(1, 0.3, 0.9, 0.5 * k), 2.0)


## Fantasma glitch de la estatua que se lanza contra el jugador (duelo final).
class Lunge extends Final.Shot:
	func _ready() -> void:
		z_index = 17

	func _draw() -> void:
		var c := Color(0.9, 0.9, 1.0) if back else col
		var dir := vel.normalized()
		for i in 5:
			var off := -dir * (12.0 + i * 14.0)
			draw_rect(Rect2(off + Vector2(-16, -46), Vector2(32, 92)), Color(c, 0.12 - i * 0.02))
		# silueta de estatua con cuadriculado magenta y negro
		var body := Rect2(-18, -50, 36, 100)
		var cell := 9.0
		for yy in int(body.size.y / cell):
			for xx in int(body.size.x / cell):
				var on := (xx + yy + int(t * 12.0)) % 2 == 0
				draw_rect(Rect2(body.position + Vector2(xx, yy) * cell, Vector2(cell, cell)), (c if on else Color(0.05, 0.02, 0.05)) if not back else Color(0.85, 0.85, 0.9))
		draw_circle(Vector2(0, -60), 14.0, c if not back else Color(0.9, 0.9, 0.95))
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(5 * s, -62), 2.5, Color(1, 1, 1))
		if strict > 0.0 and not back:
			draw_arc(Vector2.ZERO, 62.0, 0, TAU, 32, Color(1, 1, 1, 0.5 + 0.5 * absf(sin(t * 18.0))), 2.0)


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


## MIRADA FINAL: la estatua se lanza desde la oscuridad; el personaje la mira (fijar justo a tiempo) y
## luego corre hasta ella y la rompe a golpes.
func _climax() -> bool:
	_climax_clear()
	var p := get_parent()
	var marble := Color(0.92, 0.9, 0.95)
	var steps := [
		{"mode": "timing", "action": "lock_on", "title": "¡MÍRALO A LOS OJOS!", "sub": "Fija la mirada justo cuando se lanza", "dur": 1.1, "col": Color(1, 0.3, 1.0),
			"look": func() -> Vector2: return _gpos(core),
			"before": func() -> void:
				visible = true
				Epic.charge(p, _gpos(head), Color(1, 0.3, 1.0), 0.5, 140.0, head)
				await get_tree().create_timer(0.25).timeout,
			"ok": func() -> void:
				stone_k = 1.0
				Epic.flash(p, marble, 0.4, 0.35)
				Epic.word(p, _gpos(head) + Vector2(0, -70), "¡PETRIFICADO!", marble, 42)
				GameFeel.flash(rig, 0.3, Color(0.8, 0.8, 0.85)),
			"fail": func() -> void:
				_climax_hurt(2, _gpos(head))},
		{"mode": "mash", "action": "action_primary", "title": "¡ROMPE LA ESTATUA!", "sub": "Machaca antes de que se mueva otra vez",
			"limit": 3.6, "gain": 0.075, "col": marble,
			"go": func() -> Vector2: return _front(95.0),
			"look": func() -> Vector2: return _gpos(core),
			"act": "attack",
			"before": func() -> void:
				stone_k = 1.0,
			"pressed": func() -> void:
				stone_k = 1.0
				Epic.shards(p, _gpos(core) + Vector2(randf_range(-40, 40), randf_range(-40, 40)), marble if randf() < 0.6 else Color(1, 0.2, 1.0), 4, 260.0, 7.0)
				_shake(2.0, 0.06),
			"ok": func() -> void:
				Epic.anim(p, "tex", "fxmarble", _gpos(core), 1.4)
				Epic.shards(p, _gpos(core), marble, 24, 520.0, 10.0)
				Epic.word(p, _gpos(core) + Vector2(0, -80), "¡CRASH!", marble, 50)
				await get_tree().create_timer(0.3).timeout},
	]
	return await Epic.climax(self, steps)
