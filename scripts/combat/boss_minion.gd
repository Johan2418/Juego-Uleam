extends CharacterBody2D
## Planta mutante (esbirro del boss 0xDEADBEEF, Biología). Versión de prueba dibujada por código.
## Sin class_name: cargar con preload.

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")

const BITE_RANGE := 70.0
const TELEGRAPH := 0.45

var player: Node2D
var hp: int = 3
var _cd: float = 1.0
var _tele: float = 0.0
var _dead: bool = false
var _kb: Vector2 = Vector2.ZERO
var _look: Look


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss_minion")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(30, 20)
	shape.shape = r
	shape.position = Vector2(0, -10)
	add_child(shape)
	var hurt := Area2D.new()
	hurt.collision_layer = 2
	hurt.collision_mask = 0
	hurt.monitoring = false
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(40, 58)
	hs.shape = hr
	hs.position = Vector2(0, -29)
	hurt.add_child(hs)
	add_child(hurt)
	GameFeel.add_shadow(self, Vector2(0, -1), Vector2(16, 5))
	_look = Look.new()
	_look.minion = self
	add_child(_look)
	# brota del suelo
	_look.scale = Vector2(0.1, 0.1)
	create_tween().tween_property(_look, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	GameFeel.dust(get_parent(), global_position, 5, Vector2.ZERO, 4.0, Vector2(14.0, 4.0))


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _kb.length() > 1.0:
		velocity = _kb
		move_and_slide()
		_kb = _kb.move_toward(Vector2.ZERO, 900.0 * delta)
	# multijugador: muerde al jugador más cercano
	var near: Node2D = null
	for p in CoopBoss.targets(get_tree()):
		if near == null or (p as Node2D).global_position.distance_to(global_position) < near.global_position.distance_to(global_position):
			near = p
	if near != null and _tele <= 0.0:
		player = near
	if player == null or not is_instance_valid(player):
		return
	if _tele > 0.0:
		_tele -= delta
		if _tele <= 0.0:
			_bite()
		return
	_cd -= delta
	if _cd <= 0.0 and _player_dist() < BITE_RANGE:
		_tele = TELEGRAPH
		_cd = 1.8


func _player_dist() -> float:
	return (player.global_position + Vector2(0, 12)).distance_to(global_position)


func _bite() -> void:
	var dir := (player.global_position - global_position).normalized()
	_look.bite_t = _look.t
	var tw := create_tween()
	tw.tween_property(_look, "position", dir * 10.0, 0.06)
	tw.tween_property(_look, "position", Vector2.ZERO, 0.15)
	if _player_dist() < BITE_RANGE + 8.0 and player.has_method("take_hit"):
		player.call("take_hit", 1, global_position + Vector2(0, -20))


func is_telegraphing() -> bool:
	return _tele > 0.0


func take_hit(amount: int, from: Vector2) -> void:
	if _dead:
		return
	hp -= amount
	_tele = 0.0
	_cd = maxf(_cd, 0.6)
	var away := global_position - from
	if away.length() > 0.01:
		_kb = away.normalized() * (140.0 + 60.0 * amount)
	_look.hurt_t = _look.t
	GameFeel.flash(_look, 0.12)
	GameFeel.squash(_look, Vector2(1.2, 0.8), 0.2, 0.0)
	if hp <= 0:
		die()


func die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("enemies")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_look, "scale", Vector2(1.3, 0.25), 0.4)
	tw.tween_property(_look, "modulate", Color(0.45, 0.4, 0.3, 0.0), 0.5)
	tw.chain().tween_callback(queue_free)


## Latigazo que atrae (Chain).
func pull_toward(dest: Vector2) -> void:
	_kb = Vector2.ZERO
	create_tween().tween_property(self, "global_position", dest, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


class Look extends Node2D:
	var minion: Node
	var t := 0.0
	var bite_t := 0.0
	var hurt_t := 0.0

	## 0-1 quieta, 2 abre la boca, 3 muerde, 5 golpeada, 6-7 se marchita.
	func _frame(tele: bool) -> int:
		if minion != null and bool(minion.get("_dead")):
			return 7 if t - hurt_t > 0.2 else 6
		if t - hurt_t < 0.2:
			return 5
		if t - bite_t < 0.25:
			return 3
		if tele:
			return 2
		return int(t * 3.0) % 2

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var tele: bool = minion != null and minion.call("is_telegraphing")
		var tx := Spr.tex("boss_minion_plant_%d" % _frame(tele))
		if tx:
			Spr.draw_feet(self, tx, Vector2(0, 2))
			return
		var sway := sin(t * 3.0) * 3.0
		# tubo de ensayo roto
		draw_rect(Rect2(-11, -16, 22, 16), Color(0.7, 0.9, 0.95, 0.85))
		draw_rect(Rect2(-11, -16, 22, 16), Color(0, 0, 0), false, 2.0)
		draw_line(Vector2(-5, -16), Vector2(-1, -9), Color(0, 0, 0), 1.0)
		# tallo y hojas
		var head := Vector2(sway - (4.0 if tele else 0.0), -44.0 - (4.0 if tele else 0.0))
		draw_line(Vector2(0, -16), head + Vector2(0, 10), Color(0.15, 0.45, 0.15), 5.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -24), Vector2(-16, -30 + sway), Vector2(-6, -22)]), Color(0.3, 0.7, 0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -28), Vector2(16, -34 - sway), Vector2(6, -26)]), Color(0.3, 0.7, 0.25))
		# cabeza de tomate con dientes
		var col := Color(1.0, 0.85, 0.3) if tele else Color(0.88, 0.18, 0.15)
		draw_circle(head, 14, col)
		draw_arc(head, 14, 0, TAU, 20, Color(0, 0, 0), 2.0)
		var mouth := 7.0 if tele else 3.0
		draw_rect(Rect2(head.x - 9, head.y + 1, 18, mouth), Color(0.2, 0.02, 0.02))
		for i in 4:
			var x := head.x - 8 + i * 5
			draw_colored_polygon(PackedVector2Array([Vector2(x, head.y + 1), Vector2(x + 4, head.y + 1), Vector2(x + 2, head.y + 4)]), Color(1, 1, 1))
		draw_circle(head + Vector2(-5, -5), 2.5, Color(0, 0, 0))
		draw_circle(head + Vector2(5, -5), 2.5, Color(0, 0, 0))
		draw_line(head + Vector2(0, -14), head + Vector2(3, -19), Color(0.2, 0.5, 0.2), 3.0)
