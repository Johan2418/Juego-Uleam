extends RefCounted
## Peligros y efectos del boss 5 STACK OVERFLOW (Ingeniería, Industria y Arquitectura).
## Usan los sprites boss_stack_* cuando existen; si no, se dibujan por código.
## Sin class_name: cargar con preload("res://scripts/combat/boss_stack_fx.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")

const OUT := Color(0.05, 0.05, 0.06)
const YELLOW := Color(0.98, 0.76, 0.12)
const ORANGE := Color(1.0, 0.5, 0.12)
const STEEL := Color(0.55, 0.58, 0.62)
const CONCRETE := Color(0.62, 0.6, 0.56)
const BLUEPRINT := Color(0.25, 0.55, 1.0)


static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## La torre de La Torre. Se golpea su base agrietada (3 golpes, con 2 pisos o más) para tumbarla hacia el boss.
class Tower extends Node2D:
	const FLOOR_H := 34.0     # los sprites se ven en 3/4: cada piso tapa la cara de arriba del anterior
	const MAX := 8
	var boss: Node
	var player: Node2D
	var floors := 0
	var kinds: Array[int] = []    # 0 viga, 1 bloque, 2 contenedor
	var hits := 0
	var state := "idle"           # idle, wobble, fall
	var fall_dir := Vector2.RIGHT
	var fall_k := 0.0
	var t := 0.0
	var _drop := 1.0
	var _shake := 0.0
	var _cd := 0.0
	## balanceo (fase 2+ y duelo final): solo cae si se le pega cuando se inclina hacia el boss
	var sway_amp := 0.0
	var sway_speed := 2.4
	var bias := 0.0            # inclinación fija acumulada (duelo final)
	var need := 3              # golpes para tumbarla

	func _init() -> void:
		add_to_group("stack_tower")

	## -1..1: hacia dónde se inclina ahora (+ = derecha).
	func lean() -> float:
		return sin(t * sway_speed) if sway_amp > 0.0 else 0.0

	## Lado del boss respecto a la torre (+1 derecha, -1 izquierda).
	func boss_side() -> float:
		if boss == null or not is_instance_valid(boss):
			return 1.0
		return 1.0 if boss.global_position.x >= global_position.x else -1.0

	func _ready() -> void:
		z_index = 1
		add_to_group("enemies")
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := RectangleShape2D.new()
		hr.size = Vector2(90, 60)
		hs.shape = hr
		hs.position = Vector2(0, -24)
		hurt.add_child(hs)
		add_child(hurt)
		GameFeel.add_shadow(self, Vector2(0, 0), Vector2(52, 12))

	func add_piece(kind: int) -> void:
		if floors >= MAX or state != "idle":
			return
		floors += 1
		kinds.append(kind)
		_drop = 0.0
		_shake = 0.15
		GameFeel.dust(get_parent(), global_position + Vector2(0, -FLOOR_H * floors), 3, Vector2.ZERO, 3.0, Vector2(26, 4))

	func reset() -> void:
		floors = 0
		kinds.clear()
		hits = 0
		state = "idle"
		fall_k = 0.0
		modulate.a = 1.0

	## El jugador le pega a la base.
	func take_hit(_amount: int, _from: Vector2) -> void:
		if _cd > 0.0 or state != "idle" or boss == null or not is_instance_valid(boss):
			return
		_cd = 0.25
		_shake = 0.3
		if boss.has_method("tower_hit"):
			boss.call("tower_hit", self)
			return
		if floors < 2:
			GameFeel.flash(self, 0.08, Color(0.7, 0.7, 0.75))
			return
		hits += 1
		GameFeel.dust(get_parent(), global_position, 5, Vector2.ZERO, 4.0, Vector2(30, 6))
		GameFeel.flash(self, 0.1, Color(1, 0.9, 0.6))
		if hits >= 3:
			boss.call("tower_toppled")

	## Animación de caída hacia `dir`. Al terminar queda en el piso hasta que el boss la reinicia.
	func fall(dir: Vector2, time: float) -> void:
		state = "fall"
		fall_dir = dir.normalized()
		fall_k = 0.0
		var tw := create_tween()
		tw.tween_property(self, "fall_k", 1.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	## Los pisos quedan tirados un momento y desaparecen.
	func scatter() -> void:
		for i in floors:
			var d := BossFx.Debris.new()
			d.kind = i % 8
			d.prefix = "boss_stack_debris_"
			d.vel = Vector2(randf_range(-200, 200), randf_range(-360, -160))
			get_parent().add_child(d)
			d.global_position = global_position + fall_dir * (60.0 + 40.0 * i)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(func() -> void:
			reset()
			_drop = 0.0)

	## Largo de la torre en el piso al caer (lo usa el boss para ver si lo alcanza).
	func reach() -> float:
		return 80.0 + 40.0 * floors

	func _process(delta: float) -> void:
		t += delta
		_cd -= delta
		_shake = maxf(0.0, _shake - delta)
		_drop = minf(1.0, _drop + delta * 5.0)
		if state == "fall" and fall_k >= 1.0 and modulate.a >= 1.0:
			pass
		queue_redraw()

	func _piece_rect(kind: int) -> Rect2:
		match kind:
			0:
				return Rect2(-40, -FLOOR_H, 80, FLOOR_H)
			1:
				return Rect2(-32, -FLOOR_H, 64, FLOOR_H)
			_:
				return Rect2(-44, -FLOOR_H, 88, FLOOR_H)

	func _draw_piece(kind: int, at: Vector2, rot: float, a: float) -> void:
		draw_set_transform(at, rot, Vector2.ONE)
		var tx := Spr.tex("boss_stack_tower_%d" % kind)
		if tx:
			draw_texture(tx, Vector2(-tx.get_width() * 0.5, -tx.get_height()), Color(1, 1, 1, a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		var r := _piece_rect(kind)
		match kind:
			0:   # viga I naranja
				draw_rect(r, Color(0.85, 0.35, 0.12, a))
				draw_rect(Rect2(r.position.x, r.position.y + 7, r.size.x, r.size.y - 14), Color(0.65, 0.25, 0.08, a))
				for i in 5:
					draw_circle(Vector2(r.position.x + 8 + i * 16, r.position.y + 4), 2, Color(0.3, 0.12, 0.05, a))
			1:   # bloque de concreto
				draw_rect(r, Color(CONCRETE, a))
				draw_rect(Rect2(r.position.x + 6, r.position.y + 6, 18, r.size.y - 12), Color(0.45, 0.44, 0.4, a))
				draw_rect(Rect2(r.end.x - 24, r.position.y + 6, 18, r.size.y - 12), Color(0.45, 0.44, 0.4, a))
			_:   # contenedor
				draw_rect(r, Color(0.2, 0.45, 0.75, a))
				for i in 8:
					draw_line(Vector2(r.position.x + 6 + i * 11, r.position.y + 3), Vector2(r.position.x + 6 + i * 11, r.end.y - 3), Color(0.12, 0.3, 0.55, a), 2.0)
		draw_rect(r, Color(OUT, a), false, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw() -> void:
		var sh := sin(t * 50.0) * 3.0 * (_shake / 0.3)
		var wob := 0.0
		var swaying := state == "idle" and (sway_amp > 0.0 or bias != 0.0)
		if state == "wobble":
			wob = sin(t * 14.0) * 0.06
		elif swaying:
			wob = lean() * sway_amp + bias
		# base agrietada
		# cimiento: entero, agrietado (golpeado) o roto (al caer)
		var bi := 5 if state == "fall" else (4 if hits >= 1 else 3)
		var base := Spr.tex("boss_stack_tower_%d" % bi)
		if base:
			draw_texture(base, Vector2(-base.get_width() * 0.5 + sh, -base.get_height() * 0.6))
		else:
			draw_rect(Rect2(-52 + sh, -18, 104, 26), CONCRETE.darkened(0.15))
			draw_rect(Rect2(-52 + sh, -18, 104, 26), OUT, false, 2.0)
		# grietas según los golpes
		var cr := Color(0.1, 0.08, 0.06)
		if base:
			pass
		elif hits >= 1 or floors >= 2:
			draw_polyline(PackedVector2Array([Vector2(-30 + sh, -18), Vector2(-22 + sh, -6), Vector2(-28 + sh, 6)]), cr, 2.0)
		if hits >= 1 and base == null:
			draw_polyline(PackedVector2Array([Vector2(8 + sh, -18), Vector2(2 + sh, -4), Vector2(14 + sh, 8)]), cr, 2.5)
		if hits >= 2 and base == null:
			draw_polyline(PackedVector2Array([Vector2(30 + sh, -18), Vector2(40 + sh, -2), Vector2(34 + sh, 8)]), cr, 3.0)
			draw_polyline(PackedVector2Array([Vector2(-22 + sh, -6), Vector2(2 + sh, -4)]), cr, 2.0)
		# aviso de que se puede tumbar
		if state == "idle" and floors >= 2:
			var k := 0.5 + 0.5 * absf(sin(t * 4.0))
			draw_arc(Vector2(sh, -4), 60.0, PI * 0.15, PI * 0.85, 16, Color(1, 0.85, 0.3, 0.5 * k), 3.0)
		# pisos
		for i in floors:
			var up := Vector2(sh, -18.0 - FLOOR_H * i)
			if i == floors - 1 and _drop < 1.0:
				up.y -= (1.0 - _drop) * 60.0
			var pos := up
			var rot := 0.0
			if state == "wobble" or swaying:
				pos = Vector2(up.x + sin(wob) * (18.0 + FLOOR_H * i), up.y)
				rot = wob
			elif state == "fall":
				var e := fall_k * fall_k
				var flat := Vector2(fall_dir.x, fall_dir.y * 0.6) * (60.0 + 40.0 * i) + Vector2(0, FLOOR_H * 0.5)
				pos = up.lerp(flat, e)
				rot = lerpf(0.0, signf(fall_dir.x if absf(fall_dir.x) > 0.2 else 1.0) * PI * 0.5 * (1.0 - absf(fall_dir.y) * 0.6), e)
			_draw_piece(kinds[i], pos, rot, 1.0)
		if swaying and floors >= 2:
			# flecha: hacia dónde se inclina; verde = hacia el boss (¡ahora!)
			var good := lean() * boss_side() > 0.45
			var dx := lean() * 40.0
			var col := Color(0.4, 1.0, 0.45) if good else Color(1, 0.6, 0.3, 0.7)
			draw_line(Vector2(0, 20), Vector2(dx, 20), col, 4.0)
			draw_circle(Vector2(dx, 20), 6.0 if good else 4.0, col)
		if state == "idle" and floors >= 2 and need > 3:
			var f := ThemeDB.fallback_font
			var txt := "%d/%d" % [hits, need]
			draw_string_outline(f, Vector2(-40, 44), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, 4, Color(0, 0, 0, 0.8))
			draw_string(f, Vector2(-40, 44), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(0.8, 0.85, 0.95))


## Pieza que la grúa lanza en arco a la torre.
class FlyPiece extends Node2D:
	var kind := 0
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var time := 0.45
	var t := 0.0
	var tower: Node

	func _ready() -> void:
		z_index = 5

	func _process(delta: float) -> void:
		t += delta
		var k := clampf(t / time, 0.0, 1.0)
		global_position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 120.0)
		rotation = sin(k * PI * 2.0) * 0.2
		if k >= 1.0:
			if tower and is_instance_valid(tower):
				tower.call("add_piece", kind)
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_stack_tower_%d" % kind)
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO)
			return
		var col: Color = [Color(0.85, 0.35, 0.12), CONCRETE, Color(0.2, 0.45, 0.75)][kind]
		draw_rect(Rect2(-34, -12, 68, 24), col)
		draw_rect(Rect2(-34, -12, 68, 24), OUT, false, 2.0)
		draw_line(Vector2(0, -12), Vector2(0, -60), Color(0.2, 0.2, 0.22), 2.0)


## Franja roja del derrumbe: la torre cae a lo largo de ella. Daño fuerte al terminar el aviso.
class CollapseStrip extends BossFx.Hazard:
	var dir := Vector2.RIGHT
	var length := 1100.0
	var width := 120.0
	var warn := 1.0
	var t := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = -1

	func _inside(p: Vector2) -> bool:
		var d := p - global_position
		var along := d.dot(dir)
		var side := absf(d.dot(dir.orthogonal()))
		return along > -30.0 and along < length and side < width * 0.5

	func _process(delta: float) -> void:
		t += delta
		if not _hit and t >= warn and t < warn + 0.25 and player_ok() and _inside(player_feet()):
			_hit = true
			hurt(3)
		if t > warn + 0.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / warn, 0.0, 1.0)
		var blink := 0.55 + 0.45 * absf(sin(t * 16.0))
		var n := dir.orthogonal() * width * 0.5
		var a := Vector2.ZERO
		var b := dir * length
		draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), Color(1, 0.15, 0.1, 0.12 * blink))
		var c := dir * length * k
		draw_colored_polygon(PackedVector2Array([a + n, c + n, c - n, a - n]), Color(1, 0.25, 0.1, 0.25))
		draw_polyline(PackedVector2Array([a + n, b + n, b - n, a - n, a + n]), Color(1, 0.4, 0.25, 0.8 * blink), 2.0)
		if t >= warn:
			var dk := clampf((t - warn) / 0.3, 0.0, 1.0)
			draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), Color(0.6, 0.55, 0.5, 0.5 * (1.0 - dk)))


## 1. Alimentos: cinta transportadora que cruza la arena, empuja al jugador y lleva latas rodando.
class Belt extends BossFx.Hazard:
	var x0 := -500.0
	var x1 := 500.0
	var h := 70.0
	var dir := 1.0
	var warn := 0.6
	var life := 4.5
	var cans_every := 0.8
	var t := 0.0
	var _can_t := 0.0

	func _ready() -> void:
		z_index = -2

	func _on_belt(p: Vector2) -> bool:
		return absf(p.y - global_position.y) < h * 0.5 and p.x > x0 and p.x < x1

	func _process(delta: float) -> void:
		t += delta
		if t >= warn and t < life:
			if player_ok() and _on_belt(player_feet()):
				player.global_position.x += dir * 120.0 * delta
			_can_t -= delta
			if _can_t <= 0.0:
				_can_t = cans_every
				var c := Can.new()
				c.vel = Vector2(dir * 250.0, 0)
				c.x0 = x0
				c.x1 = x1
				c.boss = boss
				c.player = player
				get_parent().add_child(c)
				c.global_position = Vector2(x0 + 10.0 if dir > 0.0 else x1 - 10.0, global_position.y + randf_range(-h * 0.25, h * 0.25))
		if t > life:
			modulate.a = clampf(1.0 - (t - life) / 0.3, 0.0, 1.0)
		if t > life + 0.3:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(x0, -h * 0.5, x1 - x0, h)
		if t < warn:
			var blink := 0.5 + 0.5 * absf(sin(t * 14.0))
			draw_rect(r, Color(1, 0.6, 0.2, 0.15 * blink))
			draw_rect(r, Color(1, 0.6, 0.2, 0.7 * blink), false, 2.0)
			return
		draw_rect(r, Color(0.18, 0.18, 0.2))
		var off := fmod(t * 120.0 * dir, 28.0)
		var x := x0 + off - 28.0
		while x < x1:
			if x > x0:
				draw_line(Vector2(x, -h * 0.5 + 4), Vector2(x + 10.0 * dir, 0), Color(0.35, 0.35, 0.38), 3.0)
				draw_line(Vector2(x + 10.0 * dir, 0), Vector2(x, h * 0.5 - 4), Color(0.35, 0.35, 0.38), 3.0)
			x += 28.0
		draw_rect(Rect2(x0, -h * 0.5 - 5, x1 - x0, 5), YELLOW)
		draw_rect(Rect2(x0, h * 0.5, x1 - x0, 5), YELLOW)
		draw_rect(r, OUT, false, 2.0)


## Lata rodando por la cinta. Se puede bloquear o hacer parry.
class Can extends BossFx.Hazard:
	var vel := Vector2.RIGHT * 250.0
	var x0 := -500.0
	var x1 := 500.0
	var t := 0.0

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		t += delta
		global_position += vel * delta
		if player_ok() and player_feet().distance_to(global_position) < 24.0:
			hurt(1, false)
			GameFeel.dust(get_parent(), global_position, 3, Vector2.ZERO, 3.0, Vector2(8, 4))
			queue_free()
			return
		if global_position.x < x0 - 20.0 or global_position.x > x1 + 20.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_stack_projectiles_0")
		if tx:
			draw_set_transform(Vector2(0, -12), t * 10.0 * signf(vel.x), Vector2.ONE)
			draw_texture(tx, -tx.get_size() * 0.5)
			return
		ellipse(Vector2(0, 2), Vector2(14, 5), Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2(0, -12), t * 10.0 * signf(vel.x), Vector2.ONE)
		draw_circle(Vector2.ZERO, 13, Color(0.75, 0.78, 0.8))
		draw_circle(Vector2.ZERO, 9, Color(0.85, 0.2, 0.15))
		draw_line(Vector2(-9, 0), Vector2(9, 0), Color(1, 0.9, 0.4), 2.0)
		draw_arc(Vector2.ZERO, 13, 0, TAU, 16, OUT, 2.0)


## 2. Arquitectura: línea azul del plano que se vuelve muro unos segundos.
class BlueLine extends BossFx.Hazard:
	var size := Vector2(300, 24)
	var warn := 1.0
	var up := 2.4
	var t := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = 0

	func _rect() -> Rect2:
		return Rect2(global_position - size * 0.5, size)

	func _process(delta: float) -> void:
		t += delta
		if t >= warn and t < warn + up and player_ok():
			var f := player_feet()
			var r := _rect().grow(6.0)
			if r.has_point(f):
				if not _hit:
					_hit = true
					hurt(2)
				# el muro empuja hacia el borde más cercano
				var dl := f.x - r.position.x
				var dr := r.end.x - f.x
				var du := f.y - r.position.y
				var dd := r.end.y - f.y
				var m := minf(minf(dl, dr), minf(du, dd))
				if m == dl:
					player.global_position.x -= dl + 1.0
				elif m == dr:
					player.global_position.x += dr + 1.0
				elif m == du:
					player.global_position.y -= du + 1.0
				else:
					player.global_position.y += dd + 1.0
		if t > warn + up + 0.3:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(-size * 0.5, size)
		if t < warn:
			var k := t / warn
			var blink := 0.5 + 0.5 * absf(sin(t * 12.0))
			draw_rect(r, Color(BLUEPRINT, 0.15 + 0.2 * k))
			var dash := 14.0
			var horiz := size.x >= size.y
			var n := int((size.x if horiz else size.y) / dash)
			for i in n:
				if i % 2 == 0:
					if horiz:
						draw_line(Vector2(r.position.x + i * dash, 0), Vector2(r.position.x + (i + 1) * dash, 0), Color(0.75, 0.9, 1.0, blink), 3.0)
					else:
						draw_line(Vector2(0, r.position.y + i * dash), Vector2(0, r.position.y + (i + 1) * dash), Color(0.75, 0.9, 1.0, blink), 3.0)
			draw_rect(r, Color(0.5, 0.75, 1.0, 0.8 * blink), false, 1.5)
			return
		var rise := clampf((t - warn) / 0.15, 0.0, 1.0)
		var fall := clampf((t - warn - up) / 0.3, 0.0, 1.0)
		var hgt := 40.0 * rise * (1.0 - fall)
		var a := 1.0 - fall
		var top := Rect2(r.position + Vector2(0, -hgt), r.size)
		draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 4), Color(0, 0, 0, 0.3 * a))
		draw_rect(Rect2(r.position.x, top.end.y, r.size.x, hgt), Color(0.15, 0.3, 0.6, a))
		draw_rect(top, Color(0.3, 0.55, 0.95, a))
		var g := 12.0
		var x := top.position.x
		while x < top.end.x:
			draw_line(Vector2(x, top.position.y), Vector2(x, top.end.y), Color(0.8, 0.9, 1.0, 0.4 * a), 1.0)
			x += g
		draw_rect(top, Color(0.85, 0.95, 1.0, a), false, 2.0)


## 3. Electricidad: poste que se puede romper (2 golpes).
class Pole extends Node2D:
	var hp := 2
	var dead := false
	var t := 0.0
	var _rise := 0.0

	func _ready() -> void:
		z_index = 1
		add_to_group("enemies")
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := RectangleShape2D.new()
		hr.size = Vector2(36, 90)
		hs.shape = hr
		hs.position = Vector2(0, -45)
		hurt.add_child(hs)
		add_child(hurt)
		GameFeel.add_shadow(self, Vector2(0, 0), Vector2(16, 5))

	func take_hit(amount: int, _from: Vector2) -> void:
		if dead:
			return
		hp -= amount
		GameFeel.flash(self, 0.08, Color(1, 1, 0.7))
		if hp <= 0:
			dead = true
			remove_from_group("enemies")
			for i in 3:
				var d := BossFx.Debris.new()
				d.kind = 2
				d.prefix = "boss_stack_debris_"
				d.vel = Vector2(randf_range(-160, 160), randf_range(-300, -140))
				get_parent().add_child(d)
				d.global_position = global_position + Vector2(0, -40)
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.3)

	func top() -> Vector2:
		return global_position + Vector2(0, -78)

	func _process(delta: float) -> void:
		t += delta
		_rise = minf(1.0, _rise + delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		var off := Vector2(0, (1.0 - _rise) * 40.0)
		var tx := Spr.tex("boss_stack_projectiles_2")
		if tx:
			Spr.draw_feet(self, tx, off, false, 1.8)
			return
		draw_rect(Rect2(off.x - 5, off.y - 86, 10, 86), Color(0.45, 0.32, 0.2))
		draw_rect(Rect2(off.x - 5, off.y - 86, 10, 86), OUT, false, 2.0)
		draw_rect(Rect2(off.x - 20, off.y - 80, 40, 6), Color(0.35, 0.25, 0.15))
		for x in [-16.0, 16.0]:
			draw_circle(off + Vector2(x, -82), 4, Color(0.6, 0.85, 1.0))
		draw_rect(Rect2(off.x - 9, off.y - 60, 18, 14), Color(0.5, 0.52, 0.55))
		draw_rect(Rect2(off.x - 9, off.y - 60, 18, 14), OUT, false, 1.5)


## Postes unidos por arcos que giran alrededor de un centro. Romper un poste corta sus arcos.
class ArcSet extends BossFx.Hazard:
	var poles: Array[Pole] = []
	var radius := 170.0
	var spin := 0.5
	var angle := 0.0
	var warn := 0.9
	var life := 4.5
	var t := 0.0
	var _cd := 0.0

	func _ready() -> void:
		z_index = 3

	func setup(n: int) -> void:
		for i in n:
			var p := Pole.new()
			get_parent().add_child(p)
			poles.append(p)
		_place()

	func _place() -> void:
		for i in poles.size():
			var p := poles[i]
			if is_instance_valid(p):
				p.global_position = global_position + Vector2.from_angle(angle + TAU * i / poles.size()) * Vector2(radius, radius * 0.6)

	func _pairs() -> Array:
		var out := []
		var n := poles.size()
		for i in n:
			var a := poles[i]
			var b := poles[(i + 1) % n]
			if n == 2 and i == 1:
				break
			if is_instance_valid(a) and is_instance_valid(b) and not a.dead and not b.dead:
				out.append([a, b])
		return out

	func _process(delta: float) -> void:
		t += delta
		_cd -= delta
		if t >= warn:
			angle += spin * delta
		_place()
		if t >= warn and t < life and player_ok() and _cd <= 0.0:
			var pb := player_body()
			for pr in _pairs():
				var a: Pole = pr[0]
				var b: Pole = pr[1]
				var ya := Vector2(0, 40)
				if seg_dist_local(pb, a.top() + ya, b.top() + ya) < 18.0:
					_cd = 0.7
					hurt(1)
					break
		if t > life:
			for p in poles:
				if is_instance_valid(p):
					p.queue_free()
			queue_free()
		queue_redraw()

	func seg_dist_local(p: Vector2, a: Vector2, b: Vector2) -> float:
		return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))

	func _draw() -> void:
		for pr in _pairs():
			var a: Pole = pr[0]
			var b: Pole = pr[1]
			var pa := a.top() + Vector2(0, 40) - global_position
			var pb := b.top() + Vector2(0, 40) - global_position
			if t < warn:
				var blink := 0.3 + 0.3 * absf(sin(t * 20.0))
				draw_line(pa, pb, Color(0.6, 0.85, 1.0, blink), 1.5)
				continue
			var pts := PackedVector2Array()
			var steps := 10
			for i in steps + 1:
				var k := float(i) / steps
				var jit := Vector2.ZERO if i == 0 or i == steps else Vector2(randf_range(-6, 6), randf_range(-6, 6))
				pts.append(pa.lerp(pb, k) + jit)
			draw_polyline(pts, Color(0.5, 0.8, 1.0, 0.5), 7.0)
			draw_polyline(pts, Color(0.95, 0.98, 1.0), 2.5)


## 4. Ingeniería Civil: bola de demolición que barre un arco alrededor del boss.
class Ball extends BossFx.Hazard:
	var center := Vector2.ZERO      # pivote (punta de la grúa), global
	var radius := 240.0
	var a0 := 0.0
	var a1 := PI
	var delay := 0.0
	var dur := 0.9
	var t := 0.0
	var pos := Vector2.ZERO
	var _hit := false

	func _ready() -> void:
		z_index = 4
		pos = center + Vector2.from_angle(a0) * Vector2(radius, radius * 0.6)

	func _process(delta: float) -> void:
		t += delta
		var k := clampf((t - delay) / dur, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var a := lerpf(a0, a1, e)
		pos = center + Vector2.from_angle(a) * Vector2(radius, radius * 0.6)
		global_position = center
		if t >= delay and not _hit and player_ok() and player_feet().distance_to(pos) < 46.0:
			_hit = true
			hurt(2)
		if t > delay + dur + 0.25:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var p := pos - global_position
		draw_line(Vector2(0, -150), p + Vector2(0, -30), Color(0.2, 0.2, 0.22), 3.0)
		ellipse(p + Vector2(0, 8), Vector2(34, 10), Color(0, 0, 0, 0.3))
		var tx := Spr.tex("boss_stack_ball")
		var c := p + Vector2(0, -24)
		if tx:
			draw_set_transform(c, t * 2.0, Vector2(2.0, 2.0))
			draw_texture(tx, -tx.get_size() * 0.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		draw_circle(c, 32, Color(0.22, 0.22, 0.25))
		draw_circle(c + Vector2(-10, -10), 9, Color(0.4, 0.4, 0.45))
		draw_arc(c, 32, 0, TAU, 24, OUT, 3.0)
		if tx == null:
			draw_rect(Rect2(c.x - 6, c.y - 40, 12, 10), Color(0.3, 0.3, 0.32))


## 5. Ingeniería Industrial: engranaje-sierra que rueda y rebota en las paredes. Se puede romper (2 golpes).
class Gear extends BossFx.Hazard:
	var vel := Vector2(220, 120)
	var area := Rect2(-500, -310, 1000, 620)
	var life := 4.5
	var hp := 2
	var t := 0.0
	var _cd := 0.0
	var _dead := false

	func _ready() -> void:
		z_index = 2
		add_to_group("enemies")
		var hurt_a := Area2D.new()
		hurt_a.collision_layer = 2
		hurt_a.collision_mask = 0
		hurt_a.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := CircleShape2D.new()
		hr.radius = 24.0
		hs.shape = hr
		hs.position = Vector2(0, -20)
		hurt_a.add_child(hs)
		add_child(hurt_a)

	func take_hit(amount: int, _from: Vector2) -> void:
		if _dead:
			return
		hp -= amount
		GameFeel.flash(self, 0.08, Color(1, 1, 1))
		vel = vel.rotated(randf_range(-0.8, 0.8)) * 0.8
		if hp <= 0:
			_die()

	func _die() -> void:
		_dead = true
		remove_from_group("enemies")
		for i in 3:
			var d := BossFx.Debris.new()
			d.kind = 4
			d.prefix = "boss_stack_debris_"
			d.vel = Vector2(randf_range(-160, 160), randf_range(-300, -140))
			get_parent().add_child(d)
			d.global_position = global_position + Vector2(0, -20)
		queue_free()

	func _process(delta: float) -> void:
		t += delta
		_cd -= delta
		if _dead:
			return
		global_position += vel * delta
		if global_position.x < area.position.x + 30.0 or global_position.x > area.end.x - 30.0:
			vel.x = -vel.x
			global_position.x = clampf(global_position.x, area.position.x + 30.0, area.end.x - 30.0)
		if global_position.y < area.position.y + 40.0 or global_position.y > area.end.y - 10.0:
			vel.y = -vel.y
			global_position.y = clampf(global_position.y, area.position.y + 40.0, area.end.y - 10.0)
		if _cd <= 0.0 and player_ok() and player_feet().distance_to(global_position) < 30.0:
			_cd = 0.7
			hurt(1, false)
		if t > life:
			modulate.a = clampf(1.0 - (t - life) / 0.3, 0.0, 1.0)
		if t > life + 0.3:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		ellipse(Vector2(0, 2), Vector2(24, 7), Color(0, 0, 0, 0.3))
		var tx := Spr.tex("boss_stack_projectiles_1")
		draw_set_transform(Vector2(0, -22), t * 12.0 * signf(vel.x if vel.x != 0.0 else 1.0), Vector2.ONE)
		if tx:
			draw_texture(tx, -tx.get_size() * 0.5)
			return
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			var r := 24.0 if i % 2 == 0 else 18.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, STEEL)
		pts.append(pts[0])
		draw_polyline(pts, OUT, 2.0)
		draw_circle(Vector2.ZERO, 8, Color(0.3, 0.32, 0.35))
		draw_circle(Vector2.ZERO, 3, OUT)


## 6. Ingeniería Marítima: ancla con cadena. Si engancha al jugador lo arrastra; con parry se aturde el boss.
class Anchor extends BossFx.Hazard:
	var origin := Vector2.ZERO      # punta de la grúa (global, se actualiza desde el boss)
	var dir := Vector2.DOWN
	var speed := 560.0
	var max_d := 440.0
	var d := 0.0
	var back := false
	var t := 0.0
	var _done := false

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		t += delta
		if not back:
			d += speed * delta
			if d >= max_d:
				back = true
		else:
			d -= speed * 1.3 * delta
			if d <= 0.0:
				queue_free()
				return
		global_position = origin + dir * d
		if not back and not _done and player_ok() and player_body().distance_to(global_position) < 30.0:
			_done = true
			back = true
			var cc: Variant = player.get("class_controller")
			var parried := false
			if cc != null and is_instance_valid(cc) and bool(cc.get("parrying")) and bool(cc.call("parry_covers", global_position)):
				parried = true
				cc.call("on_parried", global_position)
			if is_instance_valid(boss):
				boss.call("anchor_result", parried)
		queue_redraw()

	func _draw() -> void:
		var o := origin - global_position
		var n := int(d / 14.0)
		for i in n:
			var p := o.lerp(Vector2.ZERO, float(i) / maxf(1.0, n))
			draw_circle(p, 3.0, Color(0.3, 0.3, 0.33))
		draw_set_transform(Vector2.ZERO, dir.angle() - PI * 0.5, Vector2.ONE)
		var tx := Spr.tex("boss_stack_anchor")
		if tx:
			draw_texture(tx, Vector2(-tx.get_width() * 0.5, -tx.get_height() * 0.4))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		var c := Color(0.35, 0.37, 0.4)
		draw_rect(Rect2(-3, -14, 6, 26), c)
		draw_circle(Vector2(0, -16), 5, c)
		draw_arc(Vector2(0, 4), 16, 0.2, PI - 0.2, 12, c, 5.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-19, 4), Vector2(-12, 0), Vector2(-14, 10)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(19, 4), Vector2(12, 0), Vector2(14, 10)]), c)
		if tx == null:
			draw_arc(Vector2(0, 4), 16, 0.2, PI - 0.2, 12, OUT, 1.0)


## Ola que cruza la arena de lado a lado. Hay que rodar a través de ella.
class Wave extends BossFx.Hazard:
	var area := Rect2(-500, -310, 1000, 620)
	var dir := 1.0
	var speed := 430.0
	var warn := 0.7
	var t := 0.0
	var x := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = 3
		x = area.position.x if dir > 0.0 else area.end.x

	func _process(delta: float) -> void:
		t += delta
		if t >= warn:
			x += dir * speed * delta
			if not _hit and player_ok() and absf(player_feet().x - x) < 28.0:
				_hit = true
				hurt(2)
		if (dir > 0.0 and x > area.end.x + 60.0) or (dir < 0.0 and x < area.position.x - 60.0):
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var top := area.position.y
		var bot := area.end.y
		if t < warn:
			var blink := 0.4 + 0.6 * absf(sin(t * 14.0))
			draw_rect(Rect2(x - 4 if dir > 0.0 else x - 4, top, 8, bot - top), Color(0.5, 0.8, 1.0, 0.6 * blink))
			return
		var w := 46.0
		var x0 := x - w * 0.5
		draw_rect(Rect2(x0 - dir * 60.0, top, 60.0, bot - top), Color(0.2, 0.45, 0.8, 0.25))
		draw_rect(Rect2(x0, top, w, bot - top), Color(0.25, 0.55, 0.9, 0.75))
		var y := top
		while y < bot:
			var fx := x + dir * w * 0.5 + sin(y * 0.08 + t * 10.0) * 6.0
			draw_circle(Vector2(fx, y), 7.0, Color(0.92, 0.97, 1.0, 0.9))
			y += 16.0


## Sirena de obra (aparición): luces naranjas girando en las esquinas.
class Siren extends Node2D:
	var area := Rect2(-500, -310, 1000, 620)
	var life := 2.6
	var t := 0.0

	func _ready() -> void:
		z_index = 6

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf((life - t) / 0.4, 0.0, 1.0)
		for c: Vector2 in [area.position + Vector2(30, 30), Vector2(area.end.x - 30, area.position.y + 30)]:
			var ang := t * 9.0
			draw_circle(c, 14, Color(1, 0.55, 0.1, a))
			var p1 := c + Vector2.from_angle(ang) * 120.0
			var p2 := c + Vector2.from_angle(ang + 0.4) * 120.0
			draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(1, 0.6, 0.15, 0.25 * a))
		var k := 0.5 + 0.5 * sin(t * 12.0)
		draw_rect(Rect2(area.position, Vector2(area.size.x, 10)), Color(1, 0.5, 0.1, 0.5 * k * a))


## Cartel final: OBRA ENTREGADA con sello.
class DoneCard extends Node2D:
	var t := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(delta: float) -> void:
		t += delta
		if t > 2.8:
			modulate.a = clampf(1.0 - (t - 2.8) / 0.4, 0.0, 1.0)
		if t > 3.2:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / 0.2, 0.0, 1.0)
		var s := lerpf(2.0, 1.0, k)
		draw_set_transform(Vector2(0, -200), -0.12, Vector2(s, s))
		var f := ThemeDB.fallback_font
		draw_rect(Rect2(-170, -34, 340, 68), Color(0.1, 0.25, 0.55, 0.85))
		draw_rect(Rect2(-170, -34, 340, 68), Color(0.85, 0.95, 1.0), false, 4.0)
		draw_string(f, Vector2(-170, 12), "OBRA DETENIDA", HORIZONTAL_ALIGNMENT_CENTER, 340, 34, Color(0.9, 0.97, 1.0))


## Dron obrero (fases 2 y 3): vuela hacia el jugador y lo embiste. 2 golpes lo tiran.
class Drone extends CharacterBody2D:
	var player: Node2D
	var hp := 2
	var t := 0.0
	var _rest := 0.9
	var _dash := 0.0
	var _dir := Vector2.DOWN
	var _dead := false
	var _hit_t := 0.0
	var _bump_cd := 0.0

	func _ready() -> void:
		add_to_group("enemies")
		add_to_group("boss_minion")
		collision_layer = 2
		collision_mask = 0
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := CircleShape2D.new()
		hr.radius = 22.0
		hs.shape = hr
		hs.position = Vector2(0, -34)
		hurt.add_child(hs)
		add_child(hurt)
		GameFeel.add_shadow(self, Vector2(0, 0), Vector2(18, 6))

	func take_hit(amount: int, _from_pos: Vector2) -> void:
		if _dead:
			return
		hp -= amount
		_hit_t = 0.25
		_dash = 0.0
		_rest = 0.6
		GameFeel.flash(self, 0.08, Color(1, 1, 1))
		if hp <= 0:
			die()

	func die() -> void:
		if _dead:
			return
		_dead = true
		remove_from_group("enemies")
		remove_from_group("boss_minion")
		for i in 4:
			var d := BossFx.Debris.new()
			d.kind = 5
			d.prefix = "boss_stack_debris_"
			d.vel = Vector2(randf_range(-160, 160), randf_range(-300, -150))
			get_parent().add_child(d)
			d.global_position = global_position + Vector2(0, -30)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(queue_free)

	func pull_toward(dest: Vector2) -> void:
		create_tween().tween_property(self, "global_position", dest, 0.18)

	func _physics_process(delta: float) -> void:
		t += delta
		_hit_t -= delta
		_bump_cd -= delta
		queue_redraw()
		if _dead or player == null or not is_instance_valid(player):
			return
		if _dash > 0.0:
			_dash -= delta
			velocity = _dir * 320.0
			move_and_slide()
			if _bump_cd <= 0.0 and player.global_position.distance_to(global_position) < 34.0:
				_bump_cd = 0.8
				player.call("take_hit", 1, global_position)
			if _dash <= 0.0:
				_rest = randf_range(0.7, 1.0)
		else:
			_rest -= delta
			# flota acercándose despacio
			var to := player.global_position - global_position
			if to.length() > 140.0:
				velocity = to.normalized() * 70.0
				move_and_slide()
			if _rest <= 0.0:
				_dash = 0.6
				_dir = Vector2.DOWN if to.length() < 1.0 else to.normalized()

	func _draw() -> void:
		var idx := 0
		if _dead:
			idx = 7
		elif _hit_t > 0.0:
			idx = 5
		elif _dash > 0.5:
			idx = 4
		elif _dash > 0.0:
			idx = 2 + int(t * 8.0) % 2
		else:
			idx = int(t * 6.0) % 2
		var hover := sin(t * 5.0) * 3.0
		var tx := Spr.tex("boss_stack_drone_%d" % idx)
		if tx:
			Spr.draw_feet(self, tx, Vector2(0, -14 + hover))
			return
		var c := Vector2(0, -36 + hover)
		# hélices
		for s in [-1.0, 1.0]:
			var p: Vector2 = c + Vector2(22 * s, -12)
			draw_line(p + Vector2(-12 * absf(sin(t * 40.0)), 0), p + Vector2(12 * absf(sin(t * 40.0)), 0), Color(0.8, 0.8, 0.85), 2.0)
			draw_line(c + Vector2(10 * s, -4), p, STEEL, 2.0)
		# cuerpo con casquito amarillo
		draw_circle(c, 14, Color(0.3, 0.32, 0.36))
		draw_arc(c, 14, 0, TAU, 16, OUT, 2.0)
		var dome := PackedVector2Array()
		for i in 9:
			var a := PI + PI * i / 8.0
			dome.append(c + Vector2(cos(a) * 14.0, sin(a) * 12.0 - 2.0))
		draw_colored_polygon(dome, YELLOW)
		draw_rect(Rect2(c.x - 8, c.y - 1, 16, 6), Color(0.05, 0.08, 0.1))
		draw_rect(Rect2(c.x - 5, c.y + 1, 3, 2), Color(1, 0.75, 0.2))
		draw_rect(Rect2(c.x + 2, c.y + 1, 3, 2), Color(1, 0.75, 0.2))
		# llave colgando
		draw_line(c + Vector2(0, 14), c + Vector2(0, 26), STEEL, 3.0)
