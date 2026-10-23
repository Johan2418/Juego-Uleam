extends RefCounted
## Peligros y efectos del boss 2 B.S.O.D. (Ciencias de la Salud). Dibujados por código hasta tener las hojas de grokbot.
## Sin class_name: cargar con preload("res://scripts/combat/boss_bsod_fx.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")

const OUT := Color(0.05, 0.05, 0.06)


## Jeringa en línea recta (Enfermería). Si pega: 1 de daño y anestesia (jugador lento 2 s).
class Syringe extends BossFx.Hazard:
	var dir := Vector2.DOWN
	var speed := 380.0
	var delay := 0.0
	var t := 0.0
	var _done := false

	func _ready() -> void:
		z_index = 3
		rotation = dir.angle()

	func _process(delta: float) -> void:
		t += delta
		if t < delay:
			queue_redraw()
			return
		global_position += dir * speed * delta
		for v in victims():
			if _done or (v as Node2D).global_position.distance_to(global_position) > 200.0:
				continue
			_victim = v
			if player_body().distance_to(global_position) < 22.0:
				_done = true
				hurt(1, false)
				var who: Node2D = v
				if who.get("speed_mult") != null:
					who.set("speed_mult", 0.5)
					who.get_tree().create_timer(2.0).timeout.connect(func() -> void:
						if is_instance_valid(who):
							who.set("speed_mult", 1.0))
				_victim = null
				queue_free()
				return
		_victim = null
		if t > delay + 2.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t < delay:
			# aviso: línea punteada hacia donde va a salir
			for i in 8:
				draw_line(Vector2(20 + i * 30, 0), Vector2(34 + i * 30, 0), Color(1, 0.3, 0.3, 0.45), 2.0)
			return
		var tx := Spr.tex("boss_bsod_syringe_blue")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO, false, 0.8)
			return
		draw_rect(Rect2(-14, -4, 22, 8), Color(0.85, 0.95, 1.0))
		draw_rect(Rect2(-12, -3, 14, 6), Color(0.3, 0.6, 1.0))
		draw_rect(Rect2(-14, -4, 22, 8), OUT, false, 1.5)
		draw_line(Vector2(8, 0), Vector2(20, 0), Color(0.8, 0.8, 0.85), 2.0)
		draw_rect(Rect2(-18, -6, 4, 12), Color(0.7, 0.7, 0.75))


## Tubo de muestra lanzado en arco (Laboratorio Clínico): al caer deja un charco de color.
class Tube extends BossFx.Hazard:
	## Tubo de la hoja que más se parece al color (1 rojo, 2 azul, 3 amarillo).
	func _tube_index() -> int:
		if color.b > color.r and color.b > color.g:
			return 2
		if color.r > 0.7 and color.g > 0.6:
			return 3
		return 1

	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var time := 0.8
	var color := Color(0.9, 0.2, 0.2)
	var petri := false   # placa de Petri: suelta bacterias en vez de charco
	var on_land: Callable
	var t := 0.0

	func _ready() -> void:
		z_index = 4
		global_position = from

	func _process(delta: float) -> void:
		t += delta
		var k := clampf(t / time, 0.0, 1.0)
		global_position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 160.0)
		rotation += delta * 9.0
		if k >= 1.0:
			if on_land.is_valid():
				on_land.call(to, color, petri)
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_bsod_projectiles_%d" % (4 if petri else _tube_index()))
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO)
			return
		if petri:
			draw_circle(Vector2.ZERO, 10, Color(0.85, 0.95, 0.95, 0.9))
			draw_circle(Vector2(2, 1), 5, Color(0.3, 0.8, 0.3))
			draw_arc(Vector2.ZERO, 10, 0, TAU, 16, OUT, 1.5)
			return
		draw_rect(Rect2(-4, -10, 8, 20), Color(0.9, 0.95, 1.0, 0.9))
		draw_rect(Rect2(-4, 0, 8, 10), color)
		draw_rect(Rect2(-5, -12, 10, 4), Color(0.5, 0.5, 0.55))
		draw_rect(Rect2(-4, -10, 8, 20), OUT, false, 1.5)


## Charco de color: daña al pisarlo (1 cada 0.8 s) y se seca.
class ColorPuddle extends BossFx.Hazard:
	var color := Color(0.9, 0.2, 0.2)
	var life := 5.0
	var t := 0.0
	var _cd := 0.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		_cd -= delta
		if t > 0.2:
			for v in victims():
				_victim = v
				var d := player_feet() - global_position
				if Vector2(d.x, d.y * 2.0).length() < 40.0 and cd_ok("puddle", 0.8):
					hurt(1)
			_victim = null
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf((life - t) / 0.8, 0.0, 1.0) * clampf(t / 0.15, 0.0, 1.0)
		var tx := Spr.tex("boss_bsod_puddle_grey")
		if tx:
			# charco de la hoja pasado a gris y teñido del color del tubo
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.2, 2.2))
			draw_texture(tx, -tx.get_size() * 0.5, Color(color.r, color.g, color.b, 0.85 * a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		ellipse(Vector2.ZERO, Vector2(42, 20), Color(color.r, color.g, color.b, 0.55 * a))
		ellipse(Vector2(-8, -3), Vector2(16, 6), Color(1, 1, 1, 0.25 * a))


## Pelota de terapia que rebota por la arena (Fisioterapia).
class Ball extends BossFx.Hazard:
	var vel := Vector2(220, 160)
	var arena := Rect2()
	var life := 5.5
	var t := 0.0
	var _cd := 0.0
	const R := 26.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		t += delta
		_cd -= delta
		global_position += vel * delta
		var p := global_position
		if p.x < arena.position.x + R or p.x > arena.end.x - R:
			vel.x = -vel.x
			GameFeel.dust(get_parent(), p, 3, Vector2.ZERO, 4.0)
		if p.y < arena.position.y + R + 20.0 or p.y > arena.end.y - 4.0:
			vel.y = -vel.y
			GameFeel.dust(get_parent(), p, 3, Vector2.ZERO, 4.0)
		global_position = Vector2(clampf(p.x, arena.position.x + R, arena.end.x - R), clampf(p.y, arena.position.y + R + 20.0, arena.end.y - 4.0))
		for v in victims():
			_victim = v
			if player_feet().distance_to(global_position) < R + 14.0 and cd_ok("ball", 0.8):
				hurt(1)
		_victim = null
		if t > life:
			modulate.a = clampf(1.0 - (t - life) / 0.4, 0.0, 1.0)
			if t > life + 0.4:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var bounce := absf(sin(t * 7.0)) * 14.0
		ellipse(Vector2.ZERO, Vector2(R * 0.9, R * 0.35), Color(0, 0, 0, 0.2))
		var c := Vector2(0, -R - bounce)
		var tx := Spr.tex("boss_bsod_projectiles_5")
		if tx:
			Spr.draw_centered(self, tx, c, false, R * 2.0 / tx.get_width())
			return
		draw_circle(c, R, Color(0.2, 0.7, 0.75))
		draw_arc(c, R - 6, -2.4, -0.6, 12, Color(0.6, 0.95, 0.95), 4.0)
		draw_arc(c, R, 0, TAU, 28, OUT, 2.5)


## Comida que cae (Nutrición y Dietética). Sana = cura 1; chatarra = 1 de daño.
class Food extends BossFx.Hazard:
	const RADIUS := 30.0
	var healthy := true
	var kind := 0
	var delay := 0.0
	var warn := 0.85
	var t := 0.0
	var _landed := false

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		t += delta
		var lt := t - delay
		if lt < 0.0:
			return
		if not _landed and lt >= warn:
			_landed = true
			for v in victims():
				_victim = v
				if player_feet().distance_to(global_position) <= RADIUS:
					if healthy:
						var mx: int = v.get("MAX_HP") if v.get("MAX_HP") != null else 10
						var hp: int = v.get("hp")
						if hp < mx:
							v.set("hp", hp + 1)
							v.emit_signal("hp_changed", hp + 1, mx)
						GameFeel.parry_burst(get_parent(), global_position + Vector2(0, -20), 22.0)
					else:
						hurt(1)
			_victim = null
			GameFeel.dust(get_parent(), global_position, 4, Vector2.ZERO, 4.0, Vector2(14, 4))
		if lt >= warn + 0.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var lt := t - delay
		if lt < 0.0:
			return
		var k := clampf(lt / warn, 0.0, 1.0)
		var ring := Color(0.3, 1.0, 0.4) if healthy else Color(1.0, 0.25, 0.2)
		ellipse(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.42) * (0.35 + 0.65 * k), Color(0, 0, 0, 0.15 + 0.2 * k))
		ellipse_line(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.42), Color(ring.r, ring.g, ring.b, 0.3 + 0.5 * k), 2.0)
		if lt < warn - 0.25:
			return
		var fall := clampf((lt - (warn - 0.25)) / 0.25, 0.0, 1.0)
		var y := lerpf(-320.0, -12.0, fall)
		var a := 1.0 if lt < warn + 0.25 else clampf(1.0 - (lt - warn - 0.25) / 0.25, 0.0, 1.0)
		var tx := Spr.tex("boss_bsod_food_%d" % (kind + (0 if healthy else 4)))
		if tx:
			Spr.draw_feet(self, tx, Vector2(0, y + 10.0), false, 0.8, Color(1, 1, 1, a))
			return
		if healthy:
			match kind:
				0:
					draw_circle(Vector2(0, y), 10, Color(0.9, 0.15, 0.15, a))
					draw_line(Vector2(0, y - 10), Vector2(2, y - 15), Color(0.4, 0.25, 0.1, a), 2.0)
				1:
					draw_colored_polygon(PackedVector2Array([Vector2(-5, y - 10), Vector2(5, y - 10), Vector2(0, y + 12)]), Color(1, 0.55, 0.1, a))
					draw_line(Vector2(0, y - 10), Vector2(0, y - 16), Color(0.2, 0.7, 0.2, a), 3.0)
				2:
					draw_circle(Vector2(0, y - 4), 10, Color(0.2, 0.6, 0.2, a))
					draw_rect(Rect2(-3, y + 4, 6, 8), Color(0.5, 0.8, 0.3, a))
				_:
					draw_arc(Vector2(0, y - 8), 12, 0.3, 2.6, 10, Color(1, 0.9, 0.2, a), 6.0)
		else:
			match kind:
				0:
					draw_rect(Rect2(-12, y - 6, 24, 5), Color(0.85, 0.6, 0.25, a))
					draw_rect(Rect2(-12, y - 1, 24, 4), Color(0.45, 0.2, 0.1, a))
					draw_rect(Rect2(-12, y + 3, 24, 5), Color(0.85, 0.6, 0.25, a))
				1:
					draw_rect(Rect2(-7, y - 10, 14, 20), Color(0.9, 0.15, 0.15, a))
					draw_line(Vector2(2, y - 10), Vector2(5, y - 18), Color(1, 1, 1, a), 2.0)
				2:
					draw_rect(Rect2(-8, y - 2, 16, 12), Color(0.9, 0.15, 0.15, a))
					for i in 4:
						draw_line(Vector2(-6 + i * 4, y - 2), Vector2(-6 + i * 4, y - 10), Color(1, 0.85, 0.3, a), 2.0)
				_:
					draw_circle(Vector2(0, y), 10, Color(1, 0.55, 0.75, a))
					draw_circle(Vector2(0, y), 4, Color(0.95, 0.85, 0.7, a))


## Manchas de tinta en el piso (Psicología): solo decoran, se desvanecen.
class InkBlot extends Node2D:
	var life := 6.0
	var size := 60.0
	var t := 0.0
	var _pts := PackedVector2Array()

	func _init() -> void:
		add_to_group("boss_hazard")

	func _ready() -> void:
		z_index = -1
		for i in 18:
			var a := TAU * i / 18.0
			var r := size * randf_range(0.6, 1.0)
			_pts.append(Vector2(cos(a) * r, sin(a) * r * 0.55))

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(t / 0.3, 0.0, 1.0) * clampf((life - t) / 0.6, 0.0, 1.0)
		draw_colored_polygon(_pts, Color(0.08, 0.06, 0.14, 0.7 * a))
		var mirror := PackedVector2Array()
		for p in _pts:
			mirror.append(Vector2(-p.x * 0.5, p.y * 0.5))
		draw_colored_polygon(mirror, Color(0.15, 0.1, 0.25, 0.6 * a))


## Copia falsa del boss (Psicología). Se rompe al primer golpe. No tiene latido.
class Clone extends Node2D:
	var boss: Node2D
	var _rig: Node2D
	var life := 7.0
	var t := 0.0
	var _dead := false

	func _init() -> void:
		add_to_group("boss_hazard")
		add_to_group("enemies")

	func _ready() -> void:
		z_index = 1
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := RectangleShape2D.new()
		hr.size = Vector2(110, 220)
		hs.shape = hr
		hs.position = Vector2(0, -110)
		hurt.add_child(hs)
		add_child(hurt)
		_copy_rig()

	## Copia las piezas reales del boss (mismos sprites), pero con el monitor plano y el corazón quieto.
	func _copy_rig() -> void:
		if boss == null or not is_instance_valid(boss):
			return
		var src: Variant = boss.get("rig")
		if not (src is Node2D):
			return
		var rig_src: Node2D = src
		GameFeel.add_shadow(self, Vector2(0, -2), Vector2(84, 14))
		_rig = Node2D.new()
		_rig.position = rig_src.position
		_rig.modulate = rig_src.modulate
		add_child(_rig)
		for c in rig_src.get_children():
			if c.get("kind") == null or not (c as Node2D).visible:
				continue
			var n: Node2D = c.get_script().new()
			for prop in ["kind", "mask", "tool", "dirty", "blade", "saw", "blue"]:
				n.set(prop, c.get(prop))
			n.set("flat", true)
			n.set("face", "")
			n.position = (c as Node2D).position
			n.rotation = (c as Node2D).rotation
			_rig.add_child(n)

	func take_hit(_amount: int, _from: Vector2) -> void:
		if _dead:
			return
		_dead = true
		remove_from_group("enemies")
		GameFeel.parry_burst(get_parent(), global_position + Vector2(0, -110), 50.0)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)

	func _process(delta: float) -> void:
		t += delta
		if t > life and not _dead:
			take_hit(0, global_position)
		queue_redraw()

	func _draw() -> void:
		if boss == null or not is_instance_valid(boss) or _rig != null:
			return   # con piezas copiadas no hace falta la silueta de respaldo
		# silueta del boss en tinta, sin latido en el monitor
		var a := 0.85 + 0.1 * sin(t * 8.0)
		var c := Color(0.25, 0.2, 0.45, a)
		draw_rect(Rect2(-50, -40, 100, 34), c)
		draw_rect(Rect2(-34, -150, 68, 112), c)
		draw_rect(Rect2(-30, -205, 60, 48), c)
		draw_rect(Rect2(-24, -199, 48, 34), Color(0.02, 0.08, 0.04, a))
		draw_line(Vector2(-22, -182), Vector2(22, -182), Color(0.4, 1.0, 0.5, a), 2.0)   # línea plana
		draw_line(Vector2(-34, -140), Vector2(-70, -60), c, 10.0)
		draw_line(Vector2(34, -140), Vector2(70, -60), c, 12.0)
		draw_rect(Rect2(-50, -40, 100, 34), Color(0, 0, 0, a), false, 2.0)


## Trampa de bloques (Terapia Ocupacional): un cuadro de bloques que se cierra sobre el jugador.
## Rompe el bloque que brilla (o rueda fuera a tiempo).
class BlockTrap extends BossFx.Hazard:
	var close_time := 3.0
	var r0 := 130.0
	var t := 0.0
	var _broken := false
	var _done := false
	var _key := 0
	var _key_node: Node2D

	func _ready() -> void:
		z_index = 2
		_key = randi() % 8
		_key_node = KeyBlock.new()
		_key_node.trap = self
		add_child(_key_node)

	func radius() -> float:
		return lerpf(r0, 34.0, clampf(t / close_time, 0.0, 1.0))

	func block_pos(i: int) -> Vector2:
		var a := TAU * i / 8.0 - PI * 0.5
		return Vector2(cos(a), sin(a) * 0.6) * radius()

	func break_key() -> void:
		if _broken:
			return
		_broken = true
		GameFeel.parry_burst(get_parent(), global_position + block_pos(_key), 40.0)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)

	func _process(delta: float) -> void:
		if _broken:
			return
		t += delta
		_key_node.position = block_pos(_key) + Vector2(0, -14)
		if not _done and t >= close_time:
			_done = true
			for v in victims():
				_victim = v
				var d := player_feet() - global_position
				if Vector2(d.x, d.y / 0.6).length() < r0 * 0.9:
					hurt(2)
			_victim = null
			GameFeel.dust(get_parent(), global_position, 10, Vector2.ZERO, 6.0, Vector2(40, 12))
			var tw := create_tween()
			tw.tween_interval(0.3)
			tw.tween_property(self, "modulate:a", 0.0, 0.3)
			tw.tween_callback(queue_free)
		queue_redraw()

	func _draw() -> void:
		var cols := [Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.95), Color(0.95, 0.85, 0.3), Color(0.35, 0.8, 0.4)]
		for i in 8:
			var p := block_pos(i)
			var col: Color = cols[i % 4]
			if i == _key:
				col = col.lerp(Color.WHITE, 0.4 + 0.4 * absf(sin(t * 10.0)))
			var tx := Spr.tex("boss_bsod_projectiles_6")
			if tx:
				Spr.draw_feet(self, tx, p, i % 2 == 1, 1.1, Color.WHITE.lerp(col, 0.35) if i != _key else col.lerp(Color.WHITE, 0.6))
				continue
			draw_rect(Rect2(p.x - 16, p.y - 30, 32, 30), col)
			draw_rect(Rect2(p.x - 16, p.y - 30, 32, 30), OUT, false, 2.0)
			draw_circle(Vector2(p.x, p.y - 15), 5, col.darkened(0.3))

## El bloque que se puede romper (recibe golpes del jugador).
class KeyBlock extends Node2D:
	var trap: Node

	func _ready() -> void:
		add_to_group("enemies")
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := RectangleShape2D.new()
		hr.size = Vector2(40, 40)
		hs.shape = hr
		hurt.add_child(hs)
		add_child(hurt)

	func take_hit(_amount: int, _from: Vector2) -> void:
		if trap and is_instance_valid(trap):
			trap.call("break_key")


## Bacteria (esbirro): salta hacia el jugador; al primer golpe se divide en dos más pequeñas.
class Bacteria extends CharacterBody2D:
	var player: Node2D
	var small := false
	var hp := 2
	var t := 0.0
	var _jump_cd := 0.8
	var _jump_t := 0.0
	var _jump_from := Vector2.ZERO
	var _jump_to := Vector2.ZERO
	var _dead := false

	func _ready() -> void:
		add_to_group("enemies")
		add_to_group("boss_minion")
		collision_layer = 2
		collision_mask = 1
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		hp = 1 if small else 2
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := CircleShape2D.new()
		hr.radius = 12.0 if small else 18.0
		hs.shape = hr
		hs.position = Vector2(0, -14)
		hurt.add_child(hs)
		add_child(hurt)
		GameFeel.add_shadow(self, Vector2(0, -1), Vector2(10, 4) if small else Vector2(15, 5))
		scale = Vector2(0.1, 0.1)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _physics_process(delta: float) -> void:
		t += delta
		# multijugador: persigue al jugador más cercano (cuando no está saltando)
		if _jump_t <= 0.0:
			for p in CoopBoss.targets(get_tree()):
				if player == null or not is_instance_valid(player) or (p as Node2D).global_position.distance_to(global_position) < player.global_position.distance_to(global_position) - 20.0:
					player = p
		if _dead or player == null or not is_instance_valid(player):
			return
		if _jump_t > 0.0:
			_jump_t -= delta
			var k := 1.0 - _jump_t / 0.45
			global_position = _jump_from.lerp(_jump_to, k)
			if _jump_t <= 0.0 and (player.global_position + Vector2(0, 12)).distance_to(global_position) < (26.0 if small else 34.0):
				player.call("take_hit", 1, global_position)
			queue_redraw()
			return
		_jump_cd -= delta
		if _jump_cd <= 0.0:
			_jump_cd = randf_range(0.9, 1.4)
			_jump_from = global_position
			var to := player.global_position + Vector2(0, 12) - global_position
			_jump_to = global_position + to.limit_length(110.0)
			_jump_t = 0.45
		queue_redraw()

	func take_hit(amount: int, from: Vector2) -> void:
		if _dead:
			return
		hp -= amount
		GameFeel.flash(self, 0.1)
		if hp > 0:
			global_position += (global_position - from).normalized() * 20.0
			return
		_dead = true
		remove_from_group("enemies")
		if not small and get_tree().get_nodes_in_group("boss_minion").size() < 6:
			for s in [-1.0, 1.0]:
				var b := Bacteria.new()
				b.small = true
				b.player = player
				b.position = position + Vector2(18.0 * s, 0)
				get_parent().add_child.call_deferred(b)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.5, 0.2), 0.15)
		tw.tween_callback(queue_free)

	func die() -> void:
		take_hit(99, global_position)

	func pull_toward(dest: Vector2) -> void:
		create_tween().tween_property(self, "global_position", dest, 0.18)

	func _draw() -> void:
		var r := 12.0 if small else 18.0
		var hop := 0.0
		if _jump_t > 0.0:
			hop = sin((1.0 - _jump_t / 0.45) * PI) * 26.0
		var sq := 1.0 + 0.08 * sin(t * 9.0)
		var c := Vector2(0, -r - hop)
		var tx := Spr.tex("boss_bsod_bacteria_%d" % (3 if hop > 2.0 else int(t * 4.0) % 2))
		if tx:
			Spr.draw_feet(self, tx, Vector2(0, -hop), false, 0.8 if small else 1.25)
			return
		for i in 10:
			var d := Vector2.from_angle(TAU * i / 10.0 + t)
			draw_line(c + d * r, c + d * (r + 4), Color(0.25, 0.6, 0.2), 2.0)
		draw_set_transform(c, 0.0, Vector2(sq, 2.0 - sq))
		draw_circle(Vector2.ZERO, r, Color(0.45, 0.85, 0.35))
		draw_arc(Vector2.ZERO, r, 0, TAU, 20, OUT, 2.0)
		draw_circle(Vector2(-r * 0.35, -r * 0.2), r * 0.18, Color.WHITE)
		draw_circle(Vector2(r * 0.35, -r * 0.2), r * 0.18, Color.WHITE)
		draw_circle(Vector2(-r * 0.35, -r * 0.15), r * 0.09, OUT)
		draw_circle(Vector2(r * 0.35, -r * 0.15), r * 0.09, OUT)
		draw_line(Vector2(-r * 0.3, r * 0.3), Vector2(r * 0.3, r * 0.25), OUT, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Pantalla azul de la muerte (al morir el boss): ":(" y porcentaje que sube.
class BlueScreen extends CanvasLayer:
	var t := 0.0
	var dur := 2.4
	var _rect: ColorRect
	var _label: Label

	func _ready() -> void:
		layer = 9
		process_mode = Node.PROCESS_MODE_ALWAYS
		_rect = ColorRect.new()
		_rect.color = Color(0.07, 0.38, 0.75)
		_rect.size = Vector2(1280, 720)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rect)
		_label = Label.new()
		_label.position = Vector2(180, 180)
		_label.add_theme_font_size_override("font_size", 30)
		_label.add_theme_color_override("font_color", Color.WHITE)
		_rect.add_child(_label)

	func _process(delta: float) -> void:
		t += delta
		var pct := int(clampf(t / dur, 0.0, 1.0) * 100.0)
		_label.text = ":(\n\nTu facultad tuvo un problema y necesita reiniciarse.\nEstamos recopilando información sobre el error.\n\n%d %% completado\n\nCódigo de detención: B.S.O.D." % pct
		if t > dur + 0.4:
			_rect.modulate.a = clampf(1.0 - (t - dur - 0.4) / 0.5, 0.0, 1.0)
		if t > dur + 0.9:
			queue_free()
