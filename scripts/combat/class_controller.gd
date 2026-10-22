class_name ClassController
extends Node

const CombatSpriteLoader := preload("res://scripts/combat/combat_sprite_loader.gd")
const UltFx := preload("res://scripts/combat/ult_fx.gd")
const GameFeel := preload("res://scripts/combat/game_feel.gd")
const Tech := preload("res://scripts/combat/techniques.gd")
const LockOn := preload("res://scripts/combat/lock_on.gd")
## Mapea primary/secondary a la clase actual del jugador.
## Primary (J) = combo de 3 golpes: golpe 1, golpe 2 y remate. Pulsar J durante un golpe
## lo deja en cola; si pasa COMBO_WINDOW sin pulsar, el combo vuelve al golpe 1.

signal attack_started(kind: String)
signal attack_finished(kind: String)
signal guard_changed(active: bool)
signal combo_step_changed(step: int)
signal meter_changed(value: float)
signal parried(from: Vector2)

const COMBO_WINDOW := 0.45
const FINISHER_COOLDOWN := 0.25
## Enfriamiento del especial (K) por clase, en segundos.
const SPECIAL_COOLDOWN := {"guerrero": 2.5, "mago": 3.0, "chain": 3.0}
## Parry (L): ventana activa y recuperación.
const PARRY_WINDOW := 0.28
const PARRY_RECOVER := 0.30
## Tras un parry exitoso: tiempo para pulsar ataque (J / X) y contraatacar.
## Si no se pulsa, el parry queda solo como bloqueo.
const COUNTER_WINDOW := 0.55
## Medidor de ultimate: se llena golpeando (y más con parries).
const METER_MAX := 100.0
const METER_PER_HIT := 8.0
const METER_PER_PARRY := 20.0

var player: CharacterBody2D
var anim: AnimatedSprite2D
var hitbox: Area2D
var hit_shape: CollisionShape2D
var class_id: String = "guerrero"

var busy: bool = false
var guarding: bool = false
var facing: Vector2 = Vector2.DOWN
## Multiplica alcances/grosores de los golpes (el jugador lo ajusta al tamaño de su sprite).
var reach_scale: float = 1.0
## Altura (y local) del centro del cuerpo; los golpes laterales salen a esta altura.
var center_y: float = -8.0
## Duración total de la acción en curso (el jugador ajusta la velocidad de la animación).
var action_time: float = 0.3
## Desplazamiento durante un golpe (p. ej. el salto del remate del guerrero).
var lunge_velocity: Vector2 = Vector2.ZERO

var parrying: bool = false
## Hasta cuándo (segundos de _now()) se puede contraatacar después de un parry exitoso.
var _counter_until: float = 0.0
## Momento en que empezó el último parry y si ya bloqueó algo (para parries seguidos y "parry preciso").
var _parry_started: float = -10.0
## Reloj en tiempo de JUEGO (respeta hit-stop y cámara lenta), para medir el parry preciso.
var _game_t: float = 0.0
var _parry_hit: bool = false
var special_ready_at: float = 0.0
var ultimate_meter: float = 0.0
var _hit_pull: bool = false
var _hit_gives_meter: bool = true

var combo_step: int = 0
var _combo_deadline: float = 0.0
var _combo_buffered: bool = false
var _primary_ready_at: float = 0.0
var _in_primary: bool = false

## Tamaño/dirección de la última hitbox rectangular (para dibujar el tajo encima).
var _hit_len: float = 0.0
var _hit_w: float = 0.0
var _hit_dir: Vector2 = Vector2.RIGHT
var _hit_damage: int = 1
var _hit_active: bool = false
var _hit_targets: Dictionary = {}
var _action_token: int = 0

## Técnicas equipadas (techniques.gd): "" = la de serie de la clase.
var tech: Dictionary = {"combo": "", "special": "", "ultimate": ""}
var _cur_kind: String = ""
var _parasite_used: bool = false
var _echo_used: bool = false
## SUDO (Clerk) puede bloquear la ultimate unos segundos: hasta este segundo (reloj de _now()).
var ult_locked_until: float = 0.0
var _interest: int = 0
var _interest_idle: float = 0.0
var _badge: Node2D = null
## Enemigos marcados con la tiza: instance_id -> segundo (de juego) en que vence la marca.
var _marks: Dictionary = {}
var _objection: bool = false


func setup(p_player: CharacterBody2D, p_anim: AnimatedSprite2D, p_hitbox: Area2D) -> void:
	player = p_player
	anim = p_anim
	hitbox = p_hitbox
	hit_shape = hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body)
	hitbox.area_entered.connect(_on_hitbox_area)


func set_class(id: String) -> void:
	class_id = CharacterAppearance.normalize_class_id(id)
	load_loadout()


## Lee de GameState las técnicas equipadas para esta clase.
func load_loadout() -> void:
	for slot in Tech.SLOTS:
		tech[slot] = GameState.equipped(class_id, slot) if GameState else ""


func set_facing(dir: Vector2) -> void:
	if dir.length() > 0.01:
		facing = dir.normalized()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Primary: combo ------------------------------------------------------------

func try_primary() -> void:
	# contraataque: solo si el jugador pulsa ataque justo después de un parry exitoso
	if counter_window_left() > 0.0:
		_counter_until = 0.0
		_action_token += 1   # corta la recuperación del parry
		busy = false
		_start_counter(player.global_position + facing * 40.0)
		return
	if guarding:
		return
	if busy:
		if _in_primary:
			_combo_buffered = true
		return
	if _now() < _primary_ready_at:
		return
	_do_combo_step()


func _do_combo_step() -> void:
	if _now() > _combo_deadline:
		combo_step = 0
	var step := combo_step
	if step == 0:
		_parasite_used = false
		_echo_used = false
	combo_step = (combo_step + 1) % 3
	_in_primary = true
	_combo_buffered = false
	combo_step_changed.emit(step)
	var finisher := step == 2
	match class_id:
		"mago":
			if finisher:
				_start_area("mago_finisher", 2, 70.0, 0.30, 0.14, 0.22)
			else:
				_start_cast("mago_cast_%d" % (step + 1), 0.12, 0.20)
		"chain":
			if finisher:
				_start_melee("chain_finisher", 2, 100.0, 26.0, 0.26, 0.14, 0.18)
			else:
				_start_melee("chain_whip_%d" % (step + 1), 1, 54.0, 22.0, 0.06, 0.10, 0.06)
		_:
			if finisher:
				_start_melee("guerrero_finisher", 2, 56.0, 42.0, 0.26, 0.14, 0.18, 260.0)
			else:
				_start_melee("guerrero_attack_%d" % (step + 1), 1, 42.0, 28.0, 0.07, 0.11, 0.06)


func _primary_done(kind: String) -> void:
	busy = false
	lunge_velocity = Vector2.ZERO
	_in_primary = false
	var finished_combo := combo_step == 0
	if finished_combo:
		_combo_deadline = 0.0
		_primary_ready_at = _now() + FINISHER_COOLDOWN
		_combo_buffered = false
	else:
		_combo_deadline = _now() + COMBO_WINDOW
	attack_finished.emit(kind)
	if _combo_buffered:
		_combo_buffered = false
		_do_combo_step()


# --- Especial (K) ----------------------------------------------------------------

func special_cooldown_left() -> float:
	return maxf(0.0, special_ready_at - _now())


func try_secondary_pressed() -> void:
	if busy or guarding:
		return
	if _now() < special_ready_at:
		return
	var sp := str(tech.get("special", ""))
	if sp != "":
		special_ready_at = _now() + float(Tech.info(sp).get("cooldown", 3.0))
		match sp:
			"objecion":
				_tech_objection()
			"tiza":
				_tech_chalk()
			"glitch":
				_tech_glitch()
		return
	special_ready_at = _now() + float(SPECIAL_COOLDOWN.get(class_id, 3.0))
	match class_id:
		"mago":
			_start_fan("mago_special", 0.20, 0.30)
		"chain":
			# latigazo largo que atrae al enemigo hacia el jugador
			_start_melee("chain_special", 1, 140.0, 24.0, 0.22, 0.16, 0.24, 0.0, true)
		_:
			# embestida con el borrador: avanza y empuja
			_start_melee("guerrero_special", 2, 46.0, 46.0, 0.10, 0.22, 0.18, 380.0)


## Compatibilidad: K ya no se mantiene pulsado.
func try_secondary_released() -> void:
	pass


# --- Parry (L) --------------------------------------------------------------------

func try_parry() -> void:
	if busy:
		return
	_action_token += 1
	var token := _action_token
	var kind := "%s_parry" % class_id
	busy = true
	parrying = true
	_parry_started = _game_t
	_parry_hit = false
	action_time = PARRY_WINDOW + PARRY_RECOVER
	attack_started.emit(kind)
	_spawn_parry_fx(PARRY_WINDOW)
	await player.get_tree().create_timer(PARRY_WINDOW).timeout
	if token != _action_token:
		return
	parrying = false
	# parry exitoso = sin recuperación: se puede volver a hacer parry enseguida
	if not _parry_hit:
		await player.get_tree().create_timer(PARRY_RECOVER).timeout
	if token != _action_token:
		return
	_finish(kind)


## Lo llama el jugador cuando un golpe le llega durante la ventana de parry.
func on_parried(from: Vector2) -> void:
	_parry_hit = true
	_add_meter(METER_PER_PARRY)
	var parent := player.get_parent()
	if parent:
		var spark := SlashFx.HitSpark.new()
		spark.size = 30.0
		parent.add_child(spark)
		spark.global_position = player.global_position + Vector2(0.0, center_y) + (from - player.global_position).normalized() * 24.0
		GameFeel.parry_burst(parent, spark.global_position, 36.0)
	GameFeel.flash(anim, 0.18, Color(1.0, 0.9, 0.5))
	GameFeel.hit_stop(player.get_tree(), 0.12, 0.02)
	_shake(4.0, 0.18)
	parried.emit(from)
	if _objection:
		_objection_release()
		return
	# ya NO contraataca solo: abre la ventana para que el jugador pulse ataque
	_counter_until = _now() + COUNTER_WINDOW


## Segundos desde que se pulsó el parry en curso (para ataques que piden parry preciso).
func parry_age() -> float:
	return _game_t - _parry_started


## Segundos que quedan para contraatacar (0 = no hay ventana abierta).
func counter_window_left() -> float:
	return maxf(0.0, _counter_until - _now())


## Contraataque tras un parry exitoso si el jugador pulsa ataque a tiempo (más fuerte que un golpe normal).
const COUNTER := {
	"guerrero": [2, 54.0, 40.0, 0.12, 0.14, 0.22, 220.0],   # daño, alcance, grosor, retardo, activo, recupera, embestida
	"mago": [2, 62.0, 44.0, 0.14, 0.12, 0.24, 120.0],
	"chain": [2, 96.0, 24.0, 0.14, 0.12, 0.22, 0.0],
}

func _start_counter(_from: Vector2) -> void:
	if not is_instance_valid(player):
		return
	# el parry solo cubre el frente: el atacante ya está delante, se golpea hacia donde mira
	parrying = false
	_in_primary = false
	var c: Array = COUNTER.get(class_id, COUNTER["guerrero"])
	_start_melee("%s_counter" % class_id, c[0], c[1], c[2], c[3], c[4], c[5], c[6])


# --- Ultimate (Espacio) ------------------------------------------------------------

func ultimate_ready() -> bool:
	return ultimate_meter >= METER_MAX


func try_ultimate() -> void:
	if busy or not ultimate_ready():
		return
	if _now() < ult_locked_until:
		Tech.float_text(player.get_parent(), player.global_position + Vector2(0, -110), "401 BLOQUEADA", Color(0.6, 0.45, 1.0), 14)
		return
	ultimate_meter = 0.0
	meter_changed.emit(ultimate_meter)
	match str(tech.get("ultimate", "")):
		"desfibrilador":
			_tech_defib()
			return
		"pushpop":
			_tech_pushpop()
			return
		"comercial":
			_tech_commercial()
			return
	match class_id:
		"mago":
			_ult_lightning()
		"chain":
			_ult_cable_storm()
		_:
			_ult_beam()


# Guerrero: carga el espadazo y libera un haz con explosiones hacia el frente.
const BEAM_CHARGE := 0.5
const BEAM_FIRE := 0.75
const BEAM_LEN := 380.0
const BEAM_WIDTH := 84.0
const BEAM_TICKS := 4          # golpes del haz (daño 2 el primero, 1 los siguientes)

func _ult_beam() -> void:
	_action_token += 1
	var token := _action_token
	busy = true
	action_time = 1.5
	attack_started.emit("guerrero_ultimate")
	var dir := facing
	# sale desde delante del cuerpo (hacia abajo, desde los pies) para no tapar al personaje
	var origin := player.global_position + Vector2(0.0, center_y + 8.0) + dir * (58.0 if dir.y > 0.5 else 34.0)
	var fx := UltFx.BeamFx.new()
	fx.dir = dir
	fx.length = BEAM_LEN
	fx.width = BEAM_WIDTH
	fx.charge = BEAM_CHARGE
	fx.fire = BEAM_FIRE
	_ult_fx = fx
	player.get_parent().add_child(fx)
	fx.global_position = origin
	await player.get_tree().create_timer(BEAM_CHARGE).timeout
	if token != _action_token:
		return
	_shake(7.0, 0.45)
	for i in BEAM_TICKS:
		for e in _enemies():
			if _in_beam(e, origin, dir):
				_hit_node(e, 2 if i == 0 else 1)
		await player.get_tree().create_timer(BEAM_FIRE / BEAM_TICKS).timeout
		if token != _action_token:
			return
	await player.get_tree().create_timer(1.5 - BEAM_CHARGE - BEAM_FIRE).timeout
	if token != _action_token:
		return
	_ult_fx = null
	_finish("guerrero_ultimate")


## ¿El haz toca al enemigo? Se mira todo su cuerpo (de los pies al centro de su zona golpeable),
## no solo un punto: con el objetivo fijado el haz apunta al pecho y un boss alto quedaba fuera.
func _in_beam(e: Node, origin: Vector2, dir: Vector2) -> bool:
	var feet := (e as Node2D).global_position + Vector2(0.0, -10.0)
	var top := aim_of(e)
	for k in 7:
		var v: Vector2 = feet.lerp(top, k / 6.0) - origin
		var along := v.dot(dir)
		if along > -10.0 and along < BEAM_LEN and absf(v.dot(dir.orthogonal())) < BEAM_WIDTH * 0.5 + 10.0:
			return true
	return false


# Mago: rayos que caen en varios puntos (la mitad busca enemigos cercanos).
const STORM_TIME := 2.6
const STORM_STRIKES := 10
const STRIKE_RADIUS := 46.0
const STRIKE_RANGE := 260.0

func _ult_lightning() -> void:
	_action_token += 1
	var token := _action_token
	busy = true
	action_time = STORM_TIME
	attack_started.emit("mago_ultimate")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	await player.get_tree().create_timer(0.3).timeout
	for i in STORM_STRIKES:
		if token != _action_token:
			return
		var at := _pick_strike_point(rng, i % 2 == 0)
		_lightning_at(at, token)
		if i % 3 == 2:
			_shake(3.0, 0.15)
		await player.get_tree().create_timer(0.17).timeout
	await player.get_tree().create_timer(STORM_TIME - 0.3 - STORM_STRIKES * 0.17).timeout
	if token != _action_token:
		return
	_finish("mago_ultimate")


func _pick_strike_point(rng: RandomNumberGenerator, seek: bool) -> Vector2:
	var center := player.global_position
	if seek:
		var near := []
		for e in _enemies():
			if (e as Node2D).global_position.distance_to(center) < STRIKE_RANGE + 40.0:
				near.append(e)
		if not near.is_empty():
			var e: Node2D = near[rng.randi() % near.size()]
			return e.global_position + Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-12.0, 12.0))
	return center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(70.0, STRIKE_RANGE)


func _lightning_at(at: Vector2, token: int) -> void:
	var fx := UltFx.LightningStrike.new()
	fx.radius = STRIKE_RADIUS
	player.get_parent().add_child(fx)
	fx.global_position = at
	await player.get_tree().create_timer(fx.warn).timeout
	if token != _action_token:
		return
	for e in _enemies():
		# los pies del enemigo dentro del círculo marcado
		if (e as Node2D).global_position.distance_to(at) < STRIKE_RADIUS + 10.0:
			_hit_node(e, 2)


# Chain: los cables se extienden mientras gira; el jugador puede moverse.
const STORM_DURATION := 3.2
const STORM_RADIUS := 130.0
const STORM_TICK := 0.25
const STORM_MOVE := 0.8        ## fracción de la velocidad normal mientras gira

## > 0 mientras una acción permite caminar (el jugador lee esto).
var mobile_speed: float = 0.0
var mobile_anim: String = ""
var _ult_fx: Node2D = null

func _ult_cable_storm() -> void:
	_action_token += 1
	var token := _action_token
	busy = true
	action_time = STORM_DURATION
	mobile_speed = STORM_MOVE
	mobile_anim = "chain_ultimate_spin"
	attack_started.emit("chain_ultimate")
	var fx := UltFx.CableStorm.new()
	fx.target = player
	fx.offset = Vector2(0.0, center_y + 14.0)
	_ult_fx = fx
	player.get_parent().add_child(fx)
	var t := 0.0
	var next_tick := 0.3
	while t < STORM_DURATION:
		await player.get_tree().process_frame
		if token != _action_token:
			return
		t += player.get_process_delta_time()
		# se extiende (0.6 s), gira a tope y se recoge al final (0.3 s)
		var grow := minf(1.0, t / 0.6)
		var shrink := clampf((STORM_DURATION - t) / 0.3, 0.0, 1.0)
		fx.radius = lerpf(24.0, STORM_RADIUS, grow * shrink)
		if t >= next_tick:
			next_tick += STORM_TICK
			var c := player.global_position + fx.offset
			for e in _enemies():
				if _body_of(e).distance_to(c) < fx.radius + 14.0:
					_hit_node(e, 1)
	fx.alive = false
	_ult_fx = null
	mobile_speed = 0.0
	_finish("chain_ultimate")


# --- utilidades de ultimates ----------------------------------------------------

func _enemies() -> Array:
	var out := []
	for n in player.get_tree().get_nodes_in_group("enemies"):
		if n != player and n is Node2D and n.has_method("take_hit"):
			out.append(n)
	return out


func _body_of(e: Node) -> Vector2:
	return (e as Node2D).global_position + Vector2(0.0, -28.0)


func _hit_node(e: Node, damage: int) -> void:
	e.call("take_hit", _marked_damage(e, damage), player.global_position)
	var parent := player.get_parent()
	if parent:
		var spark := SlashFx.HitSpark.new()
		spark.size = 22.0
		parent.add_child(spark)
		spark.global_position = _body_of(e)


## Sacude la cámara del jugador.
func _shake(strength: float, time: float) -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := player.create_tween()
	var steps := int(time / 0.03)
	for i in steps:
		var s := strength * (1.0 - float(i) / steps)
		tw.tween_property(cam, "offset", Vector2(randf_range(-s, s), randf_range(-s, s)), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.03)


## Solo para probar: llena el medidor.
func debug_fill_meter() -> void:
	_add_meter(METER_MAX)


func _add_meter(amount: float) -> void:
	ultimate_meter = minf(METER_MAX, ultimate_meter + amount)
	meter_changed.emit(ultimate_meter)


# --- Acciones -------------------------------------------------------------------

func _start_melee(kind: String, damage: int, reach: float, thickness: float,
		active_delay: float, active_time: float, recover: float, lunge: float = 0.0,
		pull: bool = false) -> void:
	_action_token += 1
	var token := _action_token
	busy = true
	_cur_kind = kind
	_hit_damage = damage
	_hit_pull = pull
	_hit_gives_meter = true
	_hit_targets.clear()
	action_time = active_delay + active_time + recover
	attack_started.emit(kind)
	_configure_hitbox(reach, thickness, false)
	await player.get_tree().create_timer(active_delay).timeout
	if token != _action_token:
		return
	if lunge > 0.0:
		lunge_velocity = facing * lunge
	_enable_hitbox()
	_spawn_slash(kind, active_time)
	await player.get_tree().create_timer(active_time).timeout
	if token != _action_token:
		return
	lunge_velocity = Vector2.ZERO
	_disable_hitbox()
	await player.get_tree().create_timer(recover).timeout
	if token != _action_token:
		return
	_finish(kind)


func _start_cast(kind: String, cast_delay: float, recover: float) -> void:
	_action_token += 1
	var token := _action_token
	busy = true
	_cur_kind = kind
	action_time = cast_delay + recover
	attack_started.emit(kind)
	await player.get_tree().create_timer(cast_delay).timeout
	if token != _action_token:
		return
	_spawn_projectile()
	await player.get_tree().create_timer(recover).timeout
	if token != _action_token:
		return
	_finish(kind)


## Especial del mago: 3 orbes en abanico.
func _start_fan(kind: String, cast_delay: float, recover: float) -> void:
	_action_token += 1
	var token := _action_token
	busy = true
	_cur_kind = kind
	action_time = cast_delay + recover
	attack_started.emit(kind)
	await player.get_tree().create_timer(cast_delay).timeout
	if token != _action_token:
		return
	for deg in [-20.0, 0.0, 20.0]:
		_spawn_projectile(facing.rotated(deg_to_rad(deg)))
	await player.get_tree().create_timer(recover).timeout
	if token != _action_token:
		return
	_finish(kind)


## Varios golpes en área seguidos (ultimates de guerrero y chain).
func _start_multi_area(kind: String, damage: int, radius: float, delay: float,
		hits: int, interval: float, recover: float) -> void:
	_action_token += 1
	var token := _action_token
	busy = true
	_hit_damage = damage
	_hit_pull = false
	_hit_gives_meter = false
	action_time = delay + hits * interval + recover
	attack_started.emit(kind)
	await player.get_tree().create_timer(delay).timeout
	if token != _action_token:
		return
	_set_circle_hitbox(radius)
	SlashFx.spawn_spin(player.get_parent(), hitbox.global_position, radius, hits * interval + 0.05, kind.begins_with("chain"))
	for i in hits:
		_hit_targets.clear()
		_enable_hitbox()
		await player.get_tree().create_timer(interval).timeout
		if token != _action_token:
			return
	_disable_hitbox()
	await player.get_tree().create_timer(recover).timeout
	if token != _action_token:
		return
	_finish(kind)


func _set_circle_hitbox(radius: float) -> void:
	if hit_shape == null:
		return
	var circle := CircleShape2D.new()
	circle.radius = radius * reach_scale
	hit_shape.shape = circle
	hit_shape.rotation = 0.0
	hitbox.position = Vector2(0.0, center_y + 20.0)


## Golpe en área alrededor del jugador (remate del mago).
func _start_area(kind: String, damage: int, radius: float, active_delay: float,
		active_time: float, recover: float, gives_meter: bool = true) -> void:
	_action_token += 1
	var token := _action_token
	busy = true
	_cur_kind = kind
	_hit_damage = damage
	_hit_pull = false
	_hit_gives_meter = gives_meter
	_hit_targets.clear()
	action_time = active_delay + active_time + recover
	attack_started.emit(kind)
	await player.get_tree().create_timer(active_delay).timeout
	if token != _action_token:
		return
	_set_circle_hitbox(radius)
	_spawn_shockwave(radius * reach_scale)
	_enable_hitbox()
	await player.get_tree().create_timer(active_time).timeout
	if token != _action_token:
		return
	_disable_hitbox()
	await player.get_tree().create_timer(recover).timeout
	if token != _action_token:
		return
	_finish(kind)


func _finish(kind: String) -> void:
	if guarding:
		return
	if _in_primary:
		_primary_done(kind)
	else:
		busy = false
		attack_finished.emit(kind)


## Cancela lo que esté en curso (p. ej. al rodar).
func cancel_action() -> void:
	_action_token += 1
	_disable_hitbox()
	lunge_velocity = Vector2.ZERO
	busy = false
	parrying = false
	_objection = false
	_counter_until = 0.0
	mobile_speed = 0.0
	if _ult_fx != null and is_instance_valid(_ult_fx):
		if _ult_fx is UltFx.CableStorm:
			(_ult_fx as UltFx.CableStorm).alive = false
		else:
			_ult_fx.queue_free()
	_ult_fx = null
	_in_primary = false
	_combo_buffered = false
	combo_step = 0


func _spawn_projectile(dir_override: Vector2 = Vector2.ZERO) -> void:
	var packed: PackedScene = load("res://scenes/combat/mage_projectile.tscn") as PackedScene
	if packed == null:
		return
	var proj := packed.instantiate() as Area2D
	var dir := facing if dir_override == Vector2.ZERO else dir_override.normalized()
	if dir.length() < 0.01:
		dir = Vector2.RIGHT
	var parent := player.get_parent()
	if parent == null:
		return
	parent.add_child(proj)
	proj.global_position = player.global_position + Vector2(0.0, center_y + 8.0) + dir * 28.0 * reach_scale
	if proj.has_method("setup"):
		proj.call("setup", dir, CombatSpriteLoader.load_projectile_texture())
	proj.set("source", self)
	proj.set("from_combo", _in_primary)


## Tajo blanco dibujado sobre la hitbox activa: lo que se ve es exactamente lo que daña.
func _spawn_slash(kind: String, time: float) -> void:
	var parent := player.get_parent()
	if parent == null or _hit_len <= 0.0:
		return
	var thin := kind.begins_with("chain")
	var heavy := kind.ends_with("finisher")
	var sweep := -1.0 if kind.ends_with("_2") else 1.0
	# en vista lateral hacia la izquierda el barrido se espeja para que siga el arma
	if _hit_dir.x < 0.0:
		sweep = -sweep
	SlashFx.spawn(parent, hitbox.global_position, _hit_dir, _hit_len, _hit_w, time + 0.04, sweep, heavy, thin)


func _spawn_parry_fx(time: float) -> void:
	if class_id == "guerrero":
		return  # el borrador ya se ve en el sprite
	var parent := player.get_parent()
	if parent == null:
		return
	var body := Vector2(0.0, center_y + 6.0)
	if class_id == "mago":
		var fx := UltFx.FrontBarrier.new()
		fx.target = player
		fx.dir = facing
		fx.offset = body
		fx.duration = time + 0.1
		parent.add_child(fx)
	else:
		var fx2 := UltFx.CableShield.new()
		fx2.target = player
		fx2.dir = facing
		fx2.offset = body + facing * 30.0
		fx2.duration = time + 0.1
		parent.add_child(fx2)


## Cono frontal que cubre el parry (±PARRY_FRONT_DEG respecto a donde mira).
const PARRY_FRONT_DEG := 75.0

func parry_covers(from: Vector2) -> bool:
	var to := from - player.global_position
	if to.length() < 0.01:
		return true
	return to.normalized().dot(facing) >= cos(deg_to_rad(PARRY_FRONT_DEG))


func _spawn_spark(target: Node) -> void:
	var parent := player.get_parent()
	if parent == null or not (target is Node2D):
		return
	var spark := SlashFx.HitSpark.new()
	spark.size = 20.0 if _hit_damage > 1 else 14.0
	parent.add_child(spark)
	# entre el centro del golpe y el cuerpo del objetivo
	var body := (target as Node2D).global_position + Vector2(0.0, -30.0)
	spark.global_position = body.lerp(hitbox.global_position, 0.35)


func _spawn_shockwave(radius: float) -> void:
	var parent := player.get_parent()
	if parent == null:
		return
	var wave := Shockwave.new()
	wave.max_radius = radius
	parent.add_child(wave)
	wave.global_position = player.global_position + Vector2(0.0, center_y + 20.0)


func _configure_hitbox(reach: float, thickness: float, _blocking: bool) -> void:
	if hit_shape == null:
		return
	var rect := RectangleShape2D.new()
	var f := facing
	reach *= reach_scale
	thickness *= reach_scale
	hit_shape.rotation = 0.0
	if absf(absf(f.x) - absf(f.y)) < 0.35 * maxf(absf(f.x), absf(f.y)):
		# diagonal (hojas _down_right / _up_right): rectángulo girado a lo largo de la dirección
		rect.size = Vector2(reach, thickness)
		hit_shape.rotation = f.angle()
		hitbox.position = Vector2(0.0, center_y + (10.0 if f.y > 0.0 else -4.0)) + f * (8.0 + reach * 0.5)
		_hit_dir = f
	elif absf(f.x) >= absf(f.y):
		rect.size = Vector2(reach, thickness)
		# empieza en el borde del cuerpo y llega hasta el alcance
		hitbox.position = Vector2(signf(f.x) * (8.0 + reach * 0.5), center_y)
		_hit_dir = Vector2(signf(f.x), 0.0)
	else:
		rect.size = Vector2(thickness, reach)
		# abajo: desde la cintura hacia los pies y más allá; arriba: desde el pecho hacia arriba
		if f.y > 0.0:
			hitbox.position = Vector2(0.0, center_y + 20.0 + reach * 0.5)
		else:
			hitbox.position = Vector2(0.0, center_y - 10.0 - reach * 0.5)
		_hit_dir = Vector2(0.0, signf(f.y))
	_hit_len = reach
	_hit_w = thickness
	hit_shape.shape = rect


func _enable_hitbox() -> void:
	_hit_active = true
	hitbox.monitoring = true
	for body in hitbox.get_overlapping_bodies():
		_on_hitbox_body(body)


func _disable_hitbox() -> void:
	_hit_active = false
	hitbox.monitoring = false


func _on_hitbox_body(body: Node) -> void:
	if not _hit_active:
		return
	_apply_hit(body)


func _on_hitbox_area(area: Area2D) -> void:
	if not _hit_active:
		return
	_apply_hit(area.get_parent())


func _apply_hit(node: Node) -> void:
	if node == null or node == player:
		return
	var id := node.get_instance_id()
	if _hit_targets.has(id):
		return
	if node.has_method("take_hit"):
		_hit_targets[id] = true
		var dmg := _hit_damage
		if _in_primary:
			dmg += _interest_bonus()
		node.call("take_hit", _marked_damage(node, dmg), player.global_position)
		if _in_primary:
			_combo_landed(node)
		_spawn_spark(node)
		if _hit_damage > 1:
			_shake(2.5, 0.12)
		if _hit_pull and node.has_method("pull_toward"):
			node.call("pull_toward", player.global_position + facing * 44.0)
		if _hit_gives_meter:
			_add_meter(METER_PER_HIT)


## Onda expansiva simple (placeholder hasta tener hoja de efectos).
class Shockwave extends Node2D:
	var max_radius: float = 80.0
	var t: float = 0.0
	const DURATION := 0.32

	func _ready() -> void:
		z_index = 20
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _process(delta: float) -> void:
		t += delta
		if t >= DURATION:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / DURATION
		var r := lerpf(max_radius * 0.3, max_radius, k)
		var c := Color(1.0, 1.0, 1.0, 1.0 - k)
		# relleno tenue = radio real de daño
		draw_circle(Vector2.ZERO, max_radius, Color(0.85, 0.95, 1.0, 0.22 * (1.0 - k)))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, c, 4.0 * (1.0 - k) + 1.0)
		draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 32, Color(c, c.a * 0.5), 2.0)


func _process(delta: float) -> void:
	_game_t += delta
	if _interest > 0:
		_interest_idle += delta
		if _interest_idle > INTEREST_IDLE:
			_set_interest(0)


# ==================================================================================
# --- Técnicas de los bosses (techniques.gd) -----------------------------------------

const INTEREST_IDLE := 2.0
const INTEREST_MAX := 4
const MARK_TIME := 5.0


## Punto al que apuntar en un enemigo (centro de su zona golpeable).
func aim_of(e: Node) -> Vector2:
	if e is Node2D:
		return LockOn.aim_point(e as Node2D)
	return Vector2.ZERO


func _marked_damage(e: Node, dmg: int) -> int:
	var id := e.get_instance_id()
	if _marks.has(id):
		if float(_marks[id]) > _game_t:
			return dmg * 2
		_marks.erase(id)
	return dmg


func mark_enemy(e: Node) -> void:
	_marks[e.get_instance_id()] = _game_t + MARK_TIME
	var m := Tech.Mark.new()
	m.target = e as Node2D
	m.ctrl = self
	m.life = MARK_TIME
	player.get_parent().add_child(m)
	Tech.float_text(player.get_parent(), aim_of(e) + Vector2(0, -50), "¡MARCADO!", Color(1, 0.4, 0.35))


## Golpe de un orbe del mago (aplica marca e interés como los golpes cuerpo a cuerpo).
func projectile_hit(node: Node, dmg: int, _at: Vector2, from_combo: bool) -> void:
	var d := dmg
	if from_combo:
		d += _interest_bonus()
	node.call("take_hit", _marked_damage(node, d), player.global_position)
	if from_combo:
		_combo_landed(node)


func _interest_bonus() -> int:
	if str(tech.get("combo", "")) != "interes":
		return 0
	return 2 if _interest >= 4 else (1 if _interest >= 2 else 0)


## Un golpe del combo acertó: Parásito (remate) o Interés compuesto (suma moneda).
func _combo_landed(node: Node) -> void:
	match str(tech.get("combo", "")):
		"interes":
			_set_interest(mini(INTEREST_MAX, _interest + 1))
		"parasito":
			if _cur_kind.ends_with("finisher") and not _parasite_used:
				_parasite_used = true
				var dr := Tech.Drain.new()
				dr.from = aim_of(node)
				dr.target = player
				player.get_parent().add_child(dr)
				if player.has_method("heal"):
					player.call("heal", 1)
		"autocompletar":
			if _cur_kind.ends_with("finisher") and not _echo_used and node is Node2D:
				_echo_used = true
				var e := Tech.Echo.new()
				e.target = node as Node2D
				e.at = aim_of(node)
				e.damage = maxi(1, _hit_damage)
				e.from = player.global_position
				player.get_parent().add_child(e)


func _set_interest(n: int) -> void:
	if n < _interest and _interest > 0 and n == 0:
		Tech.float_text(player.get_parent(), player.global_position + Vector2(0, -110), "−$", Color(1, 0.4, 0.3), 16)
	_interest = n
	_interest_idle = 0.0
	if _badge == null or not is_instance_valid(_badge):
		_badge = Tech.InterestBadge.new()
		_badge.position = Vector2(0, -112)
		player.add_child(_badge)
	_badge.call("set_stacks", n)


## El jugador recibió un golpe: se pierde el interés.
func on_player_hurt() -> void:
	if _interest > 0:
		_set_interest(0)


# --- Especiales -------------------------------------------------------------------

const OBJECTION_TIME := 1.0
const OBJECTION_RADIUS := 170.0

func _tech_objection() -> void:
	_action_token += 1
	var token := _action_token
	var kind := "tech_objecion"
	busy = true
	parrying = true
	_objection = true
	_parry_started = _game_t
	_parry_hit = false
	action_time = OBJECTION_TIME
	attack_started.emit(kind)
	_spawn_parry_fx(OBJECTION_TIME)
	Tech.float_text(player.get_parent(), player.global_position + Vector2(0, -100), "¡PROTESTO!", Color(1, 0.5, 0.4), 15)
	await player.get_tree().create_timer(OBJECTION_TIME).timeout
	if token != _action_token:
		return
	parrying = false
	_objection = false
	_finish(kind)


## La postura bloqueó algo: onda en cono que daña al frente.
func _objection_release() -> void:
	_objection = false
	parrying = false
	var origin := player.global_position + Vector2(0.0, center_y)
	var cw := Tech.ConeWave.new()
	cw.dir = facing
	cw.radius = OBJECTION_RADIUS
	player.get_parent().add_child(cw)
	cw.global_position = origin
	for e in _enemies():
		var v: Vector2 = aim_of(e) - origin
		if v.length() < OBJECTION_RADIUS + 40.0 and v.normalized().dot(facing) > cos(1.0):
			_hit_node(e, 3)
	_shake(6.0, 0.3)
	GameFeel.hit_stop(player.get_tree(), 0.08)
	# termina la postura enseguida
	_action_token += 1
	var kind := "tech_objecion"
	var tok := _action_token
	await player.get_tree().create_timer(0.2).timeout
	if tok == _action_token:
		_finish(kind)


func _tech_chalk() -> void:
	_action_token += 1
	var token := _action_token
	var kind := "tech_tiza"
	busy = true
	action_time = 0.32
	attack_started.emit(kind)
	await player.get_tree().create_timer(0.1).timeout
	if token != _action_token:
		return
	var ch := Tech.ChalkShot.new()
	ch.ctrl = self
	ch.dir = facing
	player.get_parent().add_child(ch)
	ch.global_position = player.global_position + Vector2(0.0, center_y) + facing * 26.0
	await player.get_tree().create_timer(0.22).timeout
	if token != _action_token:
		return
	_finish(kind)


const GLITCH_DIST := 190.0

func _tech_glitch() -> void:
	_action_token += 1
	var token := _action_token
	var kind := "tech_glitch"
	busy = true
	action_time = 0.3
	attack_started.emit(kind)
	var from := player.global_position
	# destino: detrás del objetivo fijado, o hacia donde mira
	var dest := from + facing * GLITCH_DIST
	var lk: Node = player.get("lock")
	if lk and bool(lk.call("active")):
		var tg: Node2D = lk.get("target")
		var away := (tg.global_position - from)
		if away.length() > 1.0:
			dest = tg.global_position + away.normalized() * 90.0
	dest = _free_spot(from, dest)
	# la copia que explota se queda donde estaba el jugador
	var dc := Tech.Decoy.new()
	dc.ctrl = self
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation(anim.animation):
		dc.tex = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
		dc.flip = anim.flip_h
		dc.offset = anim.position
		dc.scale_k = anim.scale
	player.get_parent().add_child(dc)
	dc.global_position = from
	player.set("invulnerable", true)
	GameFeel.afterimage(player.get_parent(), anim, Color(1, 0.3, 1))
	player.global_position = dest
	GameFeel.afterimage(player.get_parent(), anim, Color(1, 0.3, 1))
	await player.get_tree().create_timer(0.3).timeout
	player.set("invulnerable", false)
	if token != _action_token:
		return
	_finish(kind)


## Punto libre más lejano en el camino hacia dest (no queda dentro de una pared ni del boss).
func _free_spot(from: Vector2, dest: Vector2) -> Vector2:
	var steps := 12
	for i in steps + 1:
		var p := dest.lerp(from, float(i) / steps)
		var tr := Transform2D(0.0, p)
		if not player.test_move(tr, Vector2(0, 0.5)) and not player.test_move(tr, Vector2(0, -0.5)):
			return p
	return from


func glitch_boom(at: Vector2) -> void:
	for e in _enemies():
		if aim_of(e).distance_to(at) < 95.0 or (e as Node2D).global_position.distance_to(at) < 80.0:
			_hit_node(e, 2)
	_shake(4.0, 0.2)


## Daño en un círculo (bloques de Push / Pop).
func area_damage(at: Vector2, radius: float, dmg: int) -> void:
	for e in _enemies():
		var feet := (e as Node2D).global_position
		if Vector2(feet.x - at.x, (feet.y - at.y) * 1.6).length() < radius + 40.0:
			_hit_node(e, dmg)


# --- Ultimates ------------------------------------------------------------------------

const DEFIB_CHARGE := 0.6
const DEFIB_RADIUS := 170.0

func _tech_defib() -> void:
	_action_token += 1
	var token := _action_token
	var kind := "tech_desfibrilador_ultimate"
	busy = true
	action_time = DEFIB_CHARGE + 0.5
	attack_started.emit(kind)
	var ring := Tech.ShockRing.new()
	ring.target = player
	ring.radius = DEFIB_RADIUS
	ring.charge = DEFIB_CHARGE
	player.get_parent().add_child(ring)
	Tech.float_text(player.get_parent(), player.global_position + Vector2(0, -105), "CARGANDO...", Color(0.6, 0.85, 1.0), 14)
	await player.get_tree().create_timer(DEFIB_CHARGE).timeout
	if token != _action_token:
		return
	Tech.float_text(player.get_parent(), player.global_position + Vector2(0, -105), "¡CLEAR!", Color(1, 1, 0.5), 22)
	var c := player.global_position + Vector2(0, -20)
	for e in _enemies():
		var feet := (e as Node2D).global_position
		if feet.distance_to(c) < DEFIB_RADIUS + 50.0 or aim_of(e).distance_to(c) < DEFIB_RADIUS + 30.0:
			_hit_node(e, 3)
	if player.has_method("heal"):
		player.call("heal", 2)
	_shake(8.0, 0.35)
	GameFeel.flash(anim, 0.25, Color(0.7, 0.9, 1.0))
	await player.get_tree().create_timer(0.5).timeout
	if token != _action_token:
		return
	_finish(kind)


func _tech_pushpop() -> void:
	_action_token += 1
	var token := _action_token
	var kind := "tech_pushpop_ultimate"
	busy = true
	action_time = 0.6
	attack_started.emit(kind)
	# blancos: el objetivo fijado (si hay) y si no los enemigos más cercanos; si no hay nadie, al frente
	var targets: Array = []
	var lk: Node = player.get("lock")
	if lk and bool(lk.call("active")):
		targets.append(lk.get("target"))
	var near := _enemies()
	near.sort_custom(func(a: Node, b: Node) -> bool:
		return (a as Node2D).global_position.distance_to(player.global_position) < (b as Node2D).global_position.distance_to(player.global_position))
	for e in near:
		if not targets.has(e) and (e as Node2D).global_position.distance_to(player.global_position) < 700.0:
			targets.append(e)
	var parent := player.get_parent()
	for i in 4:
		var big := i == 3
		var at: Vector2
		if targets.is_empty():
			at = player.global_position + facing * (120.0 + 40.0 * i)
		else:
			var tg: Node2D = targets[0 if big else i % targets.size()]
			at = tg.global_position + (Vector2.ZERO if big else Vector2(randf_range(-20, 20), randf_range(-8, 8)))
		var fb := Tech.FallBlock.new()
		fb.ctrl = self
		fb.big = big
		fb.text = "POP" if big else "PUSH"
		fb.damage = 4 if big else 2
		fb.radius = 90.0 if big else 60.0
		fb.col = [Color(0.95, 0.75, 0.2), Color(0.3, 0.75, 0.95), Color(0.55, 0.9, 0.45), Color(0.95, 0.4, 0.3)][i]
		fb.warn = 0.45 if not big else 0.6
		parent.add_child(fb)
		fb.global_position = at
		await player.get_tree().create_timer(0.3 if i < 2 else 0.4).timeout
		if i == 1 and token == _action_token:
			_finish(kind)   # el jugador ya puede moverse; los bloques siguen cayendo


const COMMERCIAL_TIME := 3.0

func _tech_commercial() -> void:
	_action_token += 1
	var token := _action_token
	var kind := "tech_comercial_ultimate"
	busy = true
	action_time = 0.5
	attack_started.emit(kind)
	var scr := Tech.CommercialScreen.new()
	scr.life = COMMERCIAL_TIME
	player.get_parent().add_child(scr)
	if player.has_method("shield"):
		player.call("shield", COMMERCIAL_TIME)
	await player.get_tree().create_timer(0.5).timeout
	if token == _action_token:
		_finish(kind)
	await player.get_tree().create_timer(COMMERCIAL_TIME - 0.5).timeout
	if not is_instance_valid(player):
		return
	# "¡volvemos al aire!": golpe a todos los enemigos en pantalla
	var view := player.get_viewport().get_visible_rect()
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	var center := cam.get_screen_center_position() if cam else player.global_position
	var half := view.size * 0.5 / (cam.zoom if cam else Vector2.ONE)
	for e in _enemies():
		var p := (e as Node2D).global_position
		if absf(p.x - center.x) < half.x + 40.0 and absf(p.y - center.y) < half.y + 80.0:
			_hit_node(e, 3)
	_shake(6.0, 0.3)
