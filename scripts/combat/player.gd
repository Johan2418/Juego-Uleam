extends CharacterBody2D
## Jugador del patio: movimiento 4-dir, rodar (Shift, i-frames) y acciones de clase.
## Visual: AnimatedSprite2D con las animaciones dedicadas del personaje (CharacterSprites).

signal hurt(amount: int)
signal hp_changed(hp: int, max_hp: int)

const SPEED := 150.0
const ROLL_SPEED := 330.0
var speed_mult := 1.0
const ROLL_TIME := 0.36
const ROLL_COOLDOWN := 0.25
## Posición de los pies respecto al origen del nodo (coincide con la colisión del cuerpo).
const FEET_Y := 12.0
## Escena a la que vuelve con Esc (la arena del boss la cambia al campus).
var exit_scene: String = "res://scenes/character_creator.tscn"
## Escala de los alcances de ataque (estaban pensados para un personaje de ~48 px; ahora mide 88).
const REACH_SCALE := 1.8
const ClassControllerScript := preload("res://scripts/combat/class_controller.gd")
const InputSetup := preload("res://scripts/input_setup.gd")
const GameFeel := preload("res://scripts/combat/game_feel.gd")
const PlayerHudScript := preload("res://scripts/combat/player_hud.gd")
const LockOnScript := preload("res://scripts/combat/lock_on.gd")
const AFTERIMAGE_EVERY := 0.045   ## fantasmas al rodar
const RECOVER_HOLD := 0.08        ## mantiene el último frame del ataque antes del reposo
const MAX_HP := 10
const HURT_TIME := 0.28          ## retroceso al recibir un golpe
const HURT_IFRAMES := 0.7        ## invulnerable (parpadeo) tras recibir un golpe
const KNOCKDOWN_TIME := 1.2      ## caído al quedarse sin vida (luego se levanta con la vida llena)
const KNOCKBACK := 260.0

## acción del ClassController -> animación del personaje (sin la dirección).
## La velocidad se ajusta sola para durar lo mismo que la acción (ClassController.action_time).
const ATTACK_ANIMS := {
	"guerrero_attack_1": "guerrero_attack_1",
	"guerrero_attack_2": "guerrero_attack_2",
	"guerrero_finisher": "guerrero_finisher",
	"mago_cast_1": "mago_cast_1",
	"mago_cast_2": "mago_cast_2",
	"mago_finisher": "mago_finisher",
	"mago_melee": "mago_cast",
	"chain_whip_1": "chain_whip_1",
	"chain_whip_2": "chain_whip_2",
	"chain_finisher": "chain_finisher",
	"chain_whip_long": "chain_whip",
	"guerrero_special": "guerrero_special",
	"mago_special": "mago_special",
	"chain_special": "chain_special",
	"guerrero_parry": "guerrero_parry",
	"mago_parry": "mago_parry",
	"chain_parry": "chain_parry",
	"guerrero_ultimate": "guerrero_ultimate_beam",
	"mago_ultimate": "mago_ultimate_storm",
	"chain_ultimate": "chain_ultimate_spin",
	"guerrero_counter": "guerrero_counter",
	"mago_counter": "mago_counter",
	"chain_counter": "chain_counter",
}
## Correr: mantener el botón de rodar. Al terminar de rodar, si sigue presionado, el personaje corre.
const RUN_MULT := 1.6
const RUN_ANIM_SPEED := 1.7
const RUN_DUST_EVERY := 0.11
const IDLE_LONG_AFTER := 7.0      ## segundos quieto antes del reposo largo (si existe la hoja)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var camera: Camera2D = $Camera2D

var class_controller: Node
var lock: Node   ## fijar objetivo (lock_on.gd)
var character_id: String = ""
var facing_name: String = "front"
var facing_vec: Vector2 = Vector2.DOWN
var rolling: bool = false
var running: bool = false
var _run_dust: float = 0.0
var invulnerable: bool = false
var _lock_anim: bool = false
var _roll_dir: Vector2 = Vector2.DOWN
var _roll_left: float = 0.0
var _roll_cd: float = 0.0
## Última dirección de caminata (8 direcciones) para el reposo: [dir, flip]
var _walk_dir: Array = ["down", false]
var hp: int = MAX_HP
var _hurt_left: float = 0.0
var _iframes_left: float = 0.0
var _knocked_down: bool = false
var _hurt_vel: Vector2 = Vector2.ZERO
var _ult_active: bool = false
var _ghost_left: float = 0.0
var _recover_left: float = 0.0
var _feet_base_y: float = 0.0
var _idle_time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("player")
	z_index = 2  # por encima del tajo (SlashFx z 1) para que se vea el arma
	if camera:
		camera.make_current()
		camera.zoom = Vector2(1.25, 1.25)
	_ensure_input_map()
	character_id = GameState.appearance.get_preset_id()
	anim.sprite_frames = CharacterSprites.build_frames(character_id)
	anim.centered = true
	anim.position = Vector2(0, FEET_Y) + CharacterSprites.FOOT_OFFSET
	anim.visible = true
	GameFeel.add_shadow(self, Vector2(0, FEET_Y - 1.0), Vector2(17.0, 5.5))
	anim.frame_changed.connect(_on_anim_frame)
	anim.animation_finished.connect(_on_anim_finished)
	class_controller = ClassControllerScript.new()
	add_child(class_controller)
	class_controller.setup(self, anim, hitbox)
	class_controller.reach_scale = REACH_SCALE
	class_controller.center_y = FEET_Y - CharacterSprites.CHARACTER_HEIGHT * 0.5
	class_controller.set_class(GameState.appearance.class_id)
	class_controller.attack_started.connect(_on_attack_started)
	class_controller.attack_finished.connect(_on_attack_finished)
	class_controller.guard_changed.connect(_on_guard_changed)
	lock = LockOnScript.new()
	lock.name = "LockOn"
	add_child(lock)
	lock.call("setup", self)
	_build_hud()
	_play_idle()


func _ensure_input_map() -> void:
	# teclado + mando: todo está en scripts/input_setup.gd (GameState ya lo llamó al arrancar)
	InputSetup.ensure()
	_add_mouse_action("action_primary", MOUSE_BUTTON_LEFT)
	_add_mouse_action("action_secondary", MOUSE_BUTTON_RIGHT)


func _add_key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = k as Key
		ev.physical_keycode = k as Key
		var exists := false
		for existing in InputMap.action_get_events(action):
			if existing is InputEventKey and (existing as InputEventKey).keycode == ev.keycode:
				exists = true
				break
		if not exists:
			InputMap.action_add_event(action, ev)


func _add_mouse_action(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	var exists := false
	for existing in InputMap.action_get_events(action):
		if existing is InputEventMouseButton and (existing as InputEventMouseButton).button_index == button:
			exists = true
			break
	if not exists:
		InputMap.action_add_event(action, ev)


func _physics_process(delta: float) -> void:
	if class_controller == null:
		return
	_roll_cd = maxf(0.0, _roll_cd - delta)
	_recover_left = maxf(0.0, _recover_left - delta)
	_update_hurt(delta)
	if _hurt_left > 0.0 or _knocked_down:
		velocity = _hurt_vel
		_hurt_vel = _hurt_vel.move_toward(Vector2.ZERO, KNOCKBACK * 4.0 * delta)
		move_and_slide()
		return
	if rolling:
		_roll_left -= delta
		# arranque rápido, frenado suave al final
		var t := clampf(1.0 - _roll_left / ROLL_TIME, 0.0, 1.0)
		velocity = _roll_dir * ROLL_SPEED * lerpf(1.0, 0.45, t * t)
		move_and_slide()
		_ghost_left -= delta
		if _ghost_left <= 0.0:
			_ghost_left = AFTERIMAGE_EVERY
			GameFeel.afterimage(get_parent(), anim)
		if _roll_left <= 0.0:
			_end_roll()
		return
	var input_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if class_controller.busy and class_controller.mobile_speed > 0.0:
		# acción que permite caminar (torbellino de cables de chain)
		velocity = input_vec * SPEED * class_controller.mobile_speed * speed_mult
		if input_vec.length() > 0.1:
			_update_facing(input_vec)
			_walk_dir = CharacterSprites.walk_dir_for(input_vec, facing_name)
			if not (String(anim.animation).begins_with("chain_ultimate_start") and anim.is_playing()):
				_play(class_controller.mobile_anim)
	elif class_controller.busy or class_controller.guarding:
		velocity = class_controller.lunge_velocity
	else:
		# correr: solo mientras se mantiene el botón de rodar y hay dirección
		if running and (not Input.is_action_pressed("roll") or input_vec.length() < 0.1):
			running = false
			anim.speed_scale = 1.0
			anim.rotation = 0.0
		velocity = input_vec * SPEED * speed_mult * (RUN_MULT if running else 1.0)
		_idle_time = 0.0 if (input_vec.length() > 0.1 or _lock_anim) else _idle_time + delta
		# fijado: mira siempre al objetivo (salvo corriendo, que mira hacia donde corre)
		var locked := locked_on() and not running
		if locked:
			_face_lock()
		if input_vec.length() > 0.1:
			if not locked:
				_update_facing(input_vec)
				_walk_dir = CharacterSprites.walk_dir_for(input_vec, facing_name)
			if not _lock_anim:
				_play_walk()
				if running:
					anim.speed_scale = RUN_ANIM_SPEED
					# se inclina un poco hacia donde corre y levanta polvo
					anim.rotation = lerpf(anim.rotation, clampf(input_vec.x, -1.0, 1.0) * 0.08, 0.3)
					_run_dust -= delta
					if _run_dust <= 0.0:
						_run_dust = RUN_DUST_EVERY
						GameFeel.dust(get_parent(), _feet(), 2, -velocity * 0.15, 3.0, Vector2(6.0, 2.0))
		else:
			if not _lock_anim and _recover_left <= 0.0:
				if String(anim.animation).begins_with("idle_long") and anim.is_playing():
					pass
				elif _idle_time >= IDLE_LONG_AFTER and anim.sprite_frames.has_animation("idle_long_%s" % _walk_dir[0]):
					_play_named("idle_long_%s" % _walk_dir[0], _walk_dir[1])
				else:
					_play_idle()
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if class_controller == null:
		return
	if _hurt_left > 0.0 or _knocked_down:
		return
	if event.is_action_pressed("roll"):
		_try_roll()
		get_viewport().set_input_as_handled()
	elif rolling:
		return
	elif event.is_action_pressed("parry"):
		class_controller.set_facing(_action_vec())
		class_controller.try_parry()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ultimate"):
		class_controller.set_facing(_action_vec())
		class_controller.try_ultimate()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_fill_ultimate"):
		class_controller.debug_fill_meter()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action_primary"):
		class_controller.set_facing(_action_vec())
		class_controller.try_primary()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action_secondary"):
		class_controller.set_facing(_action_vec())
		class_controller.try_secondary_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("action_secondary"):
		class_controller.try_secondary_released()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("back"):
		# Marcar el input antes de cambiar de escena: change_scene_to_file saca la escena
		# del árbol al instante y get_viewport() pasaría a ser null.
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file.call_deferred(exit_scene)


# --- HUD (retrato, corazones, K especial, ultimate y combo: player_hud.gd) -----------

func _build_hud() -> void:
	var hud: CanvasLayer = PlayerHudScript.new()
	hud.set("player", self)
	add_child(hud)


# --- Rodar -------------------------------------------------------------------

func _try_roll() -> void:
	if rolling or _roll_cd > 0.0:
		return
	if class_controller.guarding:
		return
	# Rodar cancela el golpe en curso (y reinicia el combo).
	if class_controller.busy:
		class_controller.cancel_action()
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() < 0.1:
		dir = facing_vec
	else:
		_update_facing(dir)
		_walk_dir = CharacterSprites.walk_dir_for(dir, facing_name)
	_roll_dir = dir.normalized()
	_stop_run()
	_roll_left = ROLL_TIME
	rolling = true
	invulnerable = true
	_lock_anim = true
	_ghost_left = 0.0
	_play("roll", true)
	GameFeel.squash(anim, Vector2(1.18, 0.82), 0.2, -CharacterSprites.FOOT_OFFSET.y)
	GameFeel.dust(get_parent(), _feet(), 5, -_roll_dir * 60.0, 4.0, Vector2(8.0, 3.0))


func _end_roll() -> void:
	rolling = false
	invulnerable = false
	_lock_anim = false
	_roll_cd = ROLL_COOLDOWN
	velocity = Vector2.ZERO
	var held := Input.is_action_pressed("roll") and Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.1
	if held:
		# sale de la rodada corriendo: conserva el impulso
		running = true
		velocity = _roll_dir * SPEED * RUN_MULT
		_play_walk()
		anim.speed_scale = RUN_ANIM_SPEED
	else:
		_play_idle()
	GameFeel.squash(anim, Vector2(1.1, 0.9), 0.16, -CharacterSprites.FOOT_OFFSET.y)
	GameFeel.dust(get_parent(), _feet(), 3, _roll_dir * 30.0, 3.5)


func _feet() -> Vector2:
	return global_position + Vector2(0.0, FEET_Y)


## Polvo en los pasos: en los frames de apoyo de la caminata (inicio y mitad del ciclo).
func _on_anim_frame() -> void:
	if not String(anim.animation).begins_with("walk_") or velocity.length() < 20.0:
		return
	var n := anim.sprite_frames.get_frame_count(anim.animation)
	if anim.frame == 0 or anim.frame == n / 2:
		GameFeel.dust(get_parent(), _feet() + Vector2(randf_range(-4, 4), 0), 2, -velocity * 0.12, 2.6)


## Daño recibido. Se ignora rodando, en la ultimate y durante los i-frames;
## si llega durante la ventana de parry (L), se bloquea y carga el medidor.
## unblockable = golpe que el parry no detiene (p. ej. ataques en área del boss: hay que rodar).
func _stop_run() -> void:
	running = false
	anim.rotation = 0.0


func take_hit(amount: int, from: Vector2, unblockable: bool = false) -> void:
	if invulnerable or _ult_active or _iframes_left > 0.0 or _knocked_down:
		return
	# el parry solo cubre el frente: un golpe por la espalda o el costado entra igual
	if not unblockable and class_controller and class_controller.parrying and class_controller.parry_covers(from):
		class_controller.on_parried(from)
		return
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp, MAX_HP)
	hurt.emit(amount)
	_stop_run()
	if class_controller and class_controller.busy:
		class_controller.cancel_action()
	var away := (global_position - from)
	if away.length() < 0.01:
		away = -facing_vec
	_hurt_vel = away.normalized() * KNOCKBACK
	_lock_anim = true
	GameFeel.flash(anim, 0.16, Color(1.0, 0.85, 0.85))
	GameFeel.squash(anim, Vector2(1.14, 0.86), 0.22, -CharacterSprites.FOOT_OFFSET.y)
	GameFeel.hit_stop(get_tree(), 0.07)
	if hp <= 0:
		_knocked_down = true
		_hurt_left = KNOCKDOWN_TIME
		_play("knockdown", true, 1.0)
	else:
		_hurt_left = HURT_TIME
		_iframes_left = HURT_IFRAMES
		_play("flinch", true, 1.0)


func _update_hurt(delta: float) -> void:
	if _iframes_left > 0.0:
		_iframes_left -= delta
		anim.modulate.a = 0.45 if fmod(_iframes_left * 14.0, 1.0) > 0.5 else 1.0
		if _iframes_left <= 0.0:
			anim.modulate.a = 1.0
	if _hurt_left > 0.0:
		_hurt_left -= delta
		if _hurt_left <= 0.0:
			if _knocked_down:
				_knocked_down = false
				hp = MAX_HP
				hp_changed.emit(hp, MAX_HP)
				_iframes_left = HURT_IFRAMES
			_lock_anim = false
			_hurt_vel = Vector2.ZERO
			_play_idle()


# --- Animación ---------------------------------------------------------------

func _update_facing(v: Vector2) -> void:
	# En diagonal se conserva la dirección actual si coincide con uno de los dos ejes
	# (evita que el sprite salte entre "de frente" y "de lado"); si no coincide, se usa la vista lateral.
	var ax := absf(v.x)
	var ay := absf(v.y)
	if ax > 0.2 and ay > 0.2 and absf(ax - ay) < 0.35 * maxf(ax, ay):
		var keeps := (facing_name == "right" and v.x > 0.0) or (facing_name == "left" and v.x < 0.0) \
			or (facing_name == "front" and v.y > 0.0) or (facing_name == "back" and v.y < 0.0)
		if keeps:
			class_controller.set_facing(facing_vec)
			return
		ay = 0.0
	if ax > ay:
		facing_name = "right" if v.x > 0.0 else "left"
		facing_vec = Vector2.RIGHT if v.x > 0.0 else Vector2.LEFT
	else:
		facing_name = "front" if v.y > 0.0 else "back"
		facing_vec = Vector2.DOWN if v.y > 0.0 else Vector2.UP
	class_controller.set_facing(facing_vec)


func _play(base: String, restart: bool = false, speed: float = 1.0) -> void:
	var ad := _action_dir(base)
	var name := "%s_%s" % [base, ad[0]]
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(name):
		return
	anim.flip_h = ad[1]
	anim.speed_scale = speed
	if restart or anim.animation != name or not anim.is_playing():
		anim.play(name)
		if restart:
			anim.frame = 0


## Dirección (8 dir) para una animación de acción: [dir, flip]. Usa la diagonal de la última
## caminata solo si existe la hoja diagonal de esa animación; si no, la dirección de 4 más cercana.
func _action_dir(base: String) -> Array:
	var wd: String = _walk_dir[0]
	if (wd == "down_right" or wd == "up_right") and anim.sprite_frames \
			and anim.sprite_frames.has_animation("%s_%s" % [base, wd]):
		return [wd, _walk_dir[1]]
	return [CharacterSprites.dir_for_facing(facing_name), CharacterSprites.is_flipped(facing_name)]


## Vector de ataque: diagonal si el personaje tiene las diagonales de su clase; si no, el de 4 dir.
## Fijado a un objetivo: apunta justo a él.
func _action_vec() -> Vector2:
	if locked_on():
		_face_lock()
		return lock.call("dir")
	var base: String = CharacterSprites.COMBO_BASES.get(class_controller.class_id, "guerrero_attack")
	var ad := _action_dir(base)
	var sx := -1.0 if ad[1] else 1.0
	match ad[0]:
		"down_right":
			return Vector2(sx, 1.0).normalized()
		"up_right":
			return Vector2(sx, -1.0).normalized()
	return facing_vec


func locked_on() -> bool:
	return lock != null and bool(lock.call("active"))


## Gira el sprite hacia el objetivo fijado.
func _face_lock() -> void:
	var d: Vector2 = lock.call("dir")
	_update_facing(d)
	_walk_dir = CharacterSprites.walk_dir_for(d, facing_name)
	class_controller.set_facing(d)   # el golpe va justo al objetivo, no solo en 4/8 direcciones


func _play_walk() -> void:
	_play_named("walk_%s" % _walk_dir[0], _walk_dir[1])


func _play_idle() -> void:
	_play_named("idle_%s" % _walk_dir[0], _walk_dir[1])


func _play_named(name: String, flip: bool) -> void:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(name):
		_play(name.split("_")[0])
		return
	anim.flip_h = flip
	anim.speed_scale = 1.0
	if anim.animation != name or not anim.is_playing():
		anim.play(name)


func _on_anim_finished() -> void:
	var a := String(anim.animation)
	if a.begins_with("idle_long"):
		_idle_time = 0.0
		_play_idle()
	elif a.begins_with("chain_ultimate_start") and class_controller.busy:
		_play("chain_ultimate_spin", true)


func _on_attack_started(kind: String) -> void:
	_stop_run()
	_lock_anim = true
	_idle_time = 0.0
	_ult_active = kind.ends_with("_ultimate")
	var base: String = ATTACK_ANIMS.get(kind, "guerrero_attack")
	# la acción fija la dirección (diagonal solo si existe su hoja); el reposo posterior la conserva
	_walk_dir = _action_dir(base)
	var name := "%s_%s" % [base, _walk_dir[0]]
	var speed := 1.0
	if anim.sprite_frames and anim.sprite_frames.has_animation(name):
		var frames := anim.sprite_frames.get_frame_count(name)
		var fps := anim.sprite_frames.get_animation_speed(name)
		var length := float(frames) / maxf(fps, 0.01)
		if not anim.sprite_frames.get_animation_loop(name):
			speed = clampf(length / maxf(class_controller.action_time, 0.05), 0.3, 3.0)
	if kind == "chain_ultimate" and anim.sprite_frames.has_animation("chain_ultimate_start_%s" % _walk_dir[0]):
		_play("chain_ultimate_start", true)
	else:
		_play(base, true, speed)
	if _ult_active:
		GameFeel.squash(anim, Vector2(0.88, 1.14), 0.28, -CharacterSprites.FOOT_OFFSET.y)
		GameFeel.flash(anim, 0.22, Color(1.0, 0.95, 0.7))


func _on_attack_finished(_kind: String) -> void:
	_ult_active = false
	if rolling:
		return
	_lock_anim = false
	anim.speed_scale = 1.0
	# recuperación: se queda un instante en la pose final y se asienta (si no se mueve)
	if Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.1:
		_recover_left = 0.0
		_play_walk()
		return
	# (sin aplastar el sprite: se veía como si el personaje "se encogiera" al terminar cada golpe)
	_recover_left = RECOVER_HOLD
	anim.pause()


func _on_guard_changed(active: bool) -> void:
	_lock_anim = active
	if active:
		_play("guard", true)
	else:
		_play_idle()
