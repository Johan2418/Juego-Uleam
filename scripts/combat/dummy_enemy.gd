extends CharacterBody2D
## Dummy de entrenamiento — dibujado con las animaciones de un personaje jugable.

const GameFeel := preload("res://scripts/combat/game_feel.gd")

@onready var sprite: Node = $Sprite
@onready var label: Label = $Label

var hp: int = 8
var max_hp: int = 8
var _flash: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	_refresh_label()
	_try_apply_sprite()


## Vacío = el otro personaje jugable (el que no eligió el jugador).
@export var dummy_character: String = ""


func _try_apply_sprite() -> void:
	# Dummy = el otro estudiante jugable, con sus animaciones dedicadas.
	if sprite is CanvasItem:
		(sprite as CanvasItem).visible = false
	var id := dummy_character
	if id.is_empty():
		var player_id := GameState.appearance.get_preset_id()
		for candidate in CharacterSprites.PLAYABLE:
			if candidate != player_id:
				id = candidate
				break
	var body := AnimatedSprite2D.new()
	body.name = "Body"
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.sprite_frames = CharacterSprites.build_frames(id)
	body.centered = true
	body.position = Vector2(0, 16) + CharacterSprites.FOOT_OFFSET
	add_child(body)
	_body = body
	GameFeel.add_shadow(self, Vector2(0, 15), Vector2(17.0, 5.5))
	body.play("idle_down")
	if label:
		label.position.y -= 48.0


## El dummy ataca al jugador si está cerca (para probar parry, rodar y recibir daño).
@export var attacks: bool = true
@export var attack_range: float = 95.0
@export var attack_interval: float = 2.2
const TELEGRAPH := 0.45   # tiempo de aviso (brilla amarillo) antes de golpear

var _kb_vel: Vector2 = Vector2.ZERO
var _attack_cd: float = 1.5
var _telegraph: float = 0.0
var _body: AnimatedSprite2D


func _physics_process(delta: float) -> void:
	if _kb_vel.length() > 1.0:
		velocity = _kb_vel
		move_and_slide()
		_kb_vel = _kb_vel.move_toward(Vector2.ZERO, 1400.0 * delta)
	_update_attack(delta)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		modulate = Color.WHITE
	elif _telegraph > 0.0:
		modulate = Color(1.5, 1.4, 0.5)


func _find_player() -> Node2D:
	for n in get_tree().get_nodes_in_group("player"):
		return n as Node2D
	var p := get_parent().get_node_or_null("Player")
	return p as Node2D


func _update_attack(delta: float) -> void:
	if not attacks:
		return
	var p := _find_player()
	if p == null:
		return
	if _telegraph > 0.0:
		_telegraph -= delta
		if _telegraph <= 0.0:
			modulate = Color.WHITE
			_do_attack(p)
		return
	_attack_cd -= delta
	if _attack_cd <= 0.0 and global_position.distance_to(p.global_position) <= attack_range:
		_telegraph = TELEGRAPH
		_attack_cd = attack_interval


func _do_attack(p: Node2D) -> void:
	var dir := (p.global_position - global_position)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	# tajo blanco del dummy (mismo efecto que los del jugador)
	var reach_len := attack_range
	var at := global_position + Vector2(0, -28) + dir * (reach_len * 0.5)
	SlashFx.spawn(get_parent(), at, dir, reach_len, 50.0, 0.18, 1.0, false, false)
	if global_position.distance_to(p.global_position) <= attack_range + 10.0 and p.has_method("take_hit"):
		p.call("take_hit", 1, global_position)


func take_hit(amount: int, from: Vector2) -> void:
	hp = maxi(0, hp - amount)
	_flash = 0.35
	_telegraph = 0.0  # un golpe interrumpe su ataque
	_attack_cd = maxf(_attack_cd, 0.8)
	var away := global_position - from
	if away.length() > 0.01:
		_kb_vel = away.normalized() * (125.0 + 60.0 * amount)
	# destello blanco + aplastamiento + congelado breve (más fuerte si el golpe pega más)
	GameFeel.flash(_body, 0.12 + 0.03 * amount)
	GameFeel.squash(_body, Vector2(1.0 + 0.08 * amount, 1.0 - 0.07 * amount).clamp(Vector2(0.8, 0.75), Vector2(1.3, 1.0)), 0.2, -CharacterSprites.FOOT_OFFSET.y)
	GameFeel.hit_stop(get_tree(), 0.035 + 0.025 * mini(amount, 3))
	_refresh_label()
	if hp <= 0:
		hp = max_hp
		_refresh_label()


## Latigazo que atrae (especial de Chain).
func pull_toward(dest: Vector2) -> void:
	_kb_vel = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "global_position", dest, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _refresh_label() -> void:
	if label:
		label.text = "Entrenamiento\nHP %d/%d" % [hp, max_hp]
