extends RefCounted
## Peligros y efectos del boss 8 KERNEL PANIC (Unidad de Formación Técnicas y Tecnológicas).
## Usan los sprites boss_kp_* cuando existen; si no, se dibujan por código.
## Sin class_name: cargar con preload("res://scripts/combat/boss_kp_fx.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")

const OUT := Color(0.05, 0.05, 0.06)
const STEEL := Color(0.72, 0.75, 0.8)
const LIVE_RED := Color(1.0, 0.15, 0.15)
const FIRE := Color(1.0, 0.55, 0.15)


## Cámara del estudio. La que está EN VIVO le da medio daño al boss; romperla = SIN SEÑAL.
class Camera extends Node2D:
	var boss: Node2D
	var player: Node2D
	var idx := 0
	var hp := 3
	var max_hp := 3
	var look := Vector2.RIGHT
	var live := false
	var decoy := false        # fase 3: luz roja falsa (utilería), no transmite
	var broken := false
	var handheld := false
	var follow: Node2D
	var t := 0.0
	var _cd := 0.0
	var _hit_t := 0.0
	var _area: Area2D

	func _ready() -> void:
		add_to_group("enemies")
		z_index = 0
		_area = Area2D.new()
		_area.collision_layer = 2
		_area.collision_mask = 0
		_area.monitoring = false
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new()
		sh.radius = 26.0
		cs.shape = sh
		cs.position = Vector2(0, -40)
		_area.add_child(cs)
		add_child(_area)
		GameFeel.add_shadow(self, Vector2(0, 0), Vector2(22, 7))

	func take_hit(_amount: int, _from: Vector2) -> void:
		if broken or _cd > 0.0:
			return
		_cd = 0.25
		_hit_t = 0.15
		GameFeel.flash(self, 0.08, Color(1, 1, 1))
		if is_instance_valid(boss) and boss.has_method("camera_hit"):
			boss.call("camera_hit", self)

	func repair(n: int) -> void:
		hp = n
		max_hp = n
		broken = false
		_area.set_deferred("monitorable", true)
		if not is_in_group("enemies"):
			add_to_group("enemies")
		GameFeel.dust(get_parent(), global_position + Vector2(0, -30), 4, Vector2.ZERO, 3.0, Vector2(16, 16))

	func smash() -> void:
		if broken:
			return
		broken = true
		live = false
		hp = 0
		remove_from_group("enemies")
		_area.set_deferred("monitorable", false)
		GameFeel.parry_burst(get_parent(), global_position + Vector2(0, -40), 34.0)
		for i in 3:
			var d := BossFx.Debris.new()
			d.kind = [1, 2, 7][i]
			d.prefix = "boss_kp_debris_"
			d.vel = Vector2(randf_range(-180, 180), randf_range(-320, -160))
			get_parent().add_child(d)
			d.global_position = global_position + Vector2(0, -40)

	func _process(delta: float) -> void:
		t += delta
		_cd -= delta
		_hit_t -= delta
		if handheld and follow and is_instance_valid(follow):
			global_position = follow.global_position + Vector2(110, -40)
			if player and is_instance_valid(player):
				look = (player.global_position - global_position).normalized()
		queue_redraw()

	func _draw() -> void:
		var flip := look.x < 0.0
		var shows := live or decoy
		var name := "boss_kp_props_2" if broken else ("boss_kp_props_0" if shows else "boss_kp_props_1")
		var tx := Spr.tex(name)
		var off := Vector2(randf_range(-2, 2), 0) if _hit_t > 0.0 else Vector2.ZERO
		if tx:
			Spr.draw_feet(self, tx, off, flip)
		else:
			_draw_code(flip, off)
		if shows and not broken:
			# luz roja de EN VIVO y cono de lo que graba (la de utilería también, para engañar)
			var blink := 0.6 + 0.4 * sin(t * 8.0)
			draw_circle(Vector2(0, -78) + off, 6.0, Color(LIVE_RED, blink))
			var a := look.angle()
			var pts := PackedVector2Array([Vector2(0, -40)])
			for i in 7:
				pts.append(Vector2(0, -40) + Vector2.RIGHT.rotated(a - 0.3 + 0.1 * i) * 160.0)
			draw_colored_polygon(pts, Color(1, 0.3, 0.3, 0.08))
		# rayitas de vida
		if not broken:
			for i in max_hp:
				var c := Color(1, 0.9, 0.3) if i < hp else Color(0.25, 0.25, 0.3)
				draw_rect(Rect2(-max_hp * 5 + i * 10, -96, 8, 4), c)

	func _draw_code(flip: bool, off: Vector2) -> void:
		var s := -1.0 if flip else 1.0
		if not handheld:
			# trípode
			draw_line(Vector2(0, -30) + off, Vector2(-16, 0) + off, OUT, 3.0)
			draw_line(Vector2(0, -30) + off, Vector2(16, 0) + off, OUT, 3.0)
			draw_line(Vector2(0, -30) + off, Vector2(0, 0) + off, OUT, 3.0)
		var body := Color(0.2, 0.2, 0.24) if not broken else Color(0.12, 0.12, 0.13)
		var r := Rect2(Vector2(-20, -58) + off, Vector2(40, 28))
		draw_rect(r, body)
		draw_rect(r, OUT, false, 2.0)
		# lente
		var lens := Vector2(24 * s, -44) + off
		draw_rect(Rect2(lens - Vector2(6, 9), Vector2(12, 18)), Color(0.15, 0.15, 0.18))
		draw_circle(lens + Vector2(5 * s, 0), 7.0, Color(0.3, 0.5, 0.8) if not broken else OUT)
		draw_rect(Rect2(Vector2(-14, -70) + off, Vector2(20, 12)), body)
		if broken:
			draw_polyline(PackedVector2Array([Vector2(-14, -56), Vector2(-2, -44), Vector2(-8, -36), Vector2(8, -32)]), Color(1, 0.8, 0.3), 2.0)
			if int(t * 6.0) % 3 == 0:
				draw_circle(Vector2(randf_range(-14, 14), randf_range(-60, -34)), 2.5, Color(1, 0.9, 0.4))


## Cartel grande (SIN SEÑAL, VOLVEMOS EN 3, 2, 1, SEÑAL RESTABLECIDA).
class Card extends Node2D:
	var text := "SIN SEÑAL"
	var col := Color(0.4, 0.9, 1.0)
	var life := 1.6
	var t := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			modulate.a = clampf(1.0 - (t - life) / 0.3, 0.0, 1.0)
		if t > life + 0.3:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / 0.15, 0.0, 1.0)
		var s := lerpf(2.2, 1.0, k)
		var oy := -250.0
		var sy := get_global_transform_with_canvas().origin.y
		if sy + oy < 120.0:
			oy = 120.0 - sy
		draw_set_transform(Vector2(0, oy), -0.05, Vector2(s, s))
		var f := ThemeDB.fallback_font
		draw_rect(Rect2(-180, -30, 360, 60), Color(0.06, 0.06, 0.1, 0.92))
		# barras de color de "sin señal" en el borde de abajo
		var bars := [Color(1, 1, 1), Color(1, 1, 0), Color(0, 1, 1), Color(0, 1, 0), Color(1, 0, 1), Color(1, 0, 0), Color(0, 0, 1)]
		for i in bars.size():
			draw_rect(Rect2(-180 + i * 360.0 / bars.size(), 22, 360.0 / bars.size(), 8), bars[i])
		draw_rect(Rect2(-180, -30, 360, 60), col, false, 4.0)
		draw_string(f, Vector2(-180, 10), text, HORIZONTAL_ALIGNMENT_CENTER, 360, 28, col)


## Palomita que salta y cae (solo adorno).
class Popped extends Node2D:
	var vel := Vector2.ZERO
	var t := 0.0
	var _floor := 0.0
	var _spin := 0.0

	func _ready() -> void:
		z_index = 3
		_floor = global_position.y + randf_range(110, 190)
		_spin = randf_range(-8, 8)

	func _process(delta: float) -> void:
		t += delta
		if global_position.y < _floor:
			vel.y += 900.0 * delta
			global_position += vel * delta
			rotation += _spin * delta
		else:
			vel = Vector2.ZERO
		if t > 2.2:
			modulate.a = clampf(1.0 - (t - 2.2) / 0.4, 0.0, 1.0)
		if t > 2.6:
			queue_free()

	func _draw() -> void:
		var tx := Spr.tex("boss_kp_projectiles_4")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO, false, 0.5)
			return
		draw_circle(Vector2(-3, 0), 5, Color(1, 0.97, 0.85))
		draw_circle(Vector2(3, -2), 5, Color(1, 0.97, 0.85))
		draw_circle(Vector2(0, 3), 4, Color(1, 0.9, 0.55))


## 1. Gastronomía: comida en llamas en arco. Donde cae deja un charco de aceite ardiendo.
class FireFood extends BossFx.Hazard:
	const RADIUS := 40.0
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var flight := 0.7
	var burn := 3.5
	var t := 0.0
	var _landed := false
	var _tick := 0.0
	var _pos := Vector2.ZERO

	func _ready() -> void:
		z_index = -1
		_pos = from

	func _process(delta: float) -> void:
		t += delta
		if not _landed:
			var k := clampf(t / flight, 0.0, 1.0)
			_pos = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 140.0)
			if k >= 1.0:
				_landed = true
				_tick = 0.0
				GameFeel.dust(get_parent(), to, 4, Vector2.ZERO, 4.0, Vector2(24, 8))
		else:
			_tick -= delta
			for v in victims():
				_victim = v
				var d := player_feet() - to
				if not bool(v.get("rolling")) and Vector2(d.x, d.y * 2.0).length() < RADIUS and cd_ok("burn", 0.8):
					hurt(1)
			_victim = null
			if t > flight + burn:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var base := to - global_position
		if not _landed:
			# sombra donde va a caer y la pieza en el aire
			var k := clampf(t / flight, 0.0, 1.0)
			ellipse(base, Vector2(RADIUS, RADIUS * 0.5) * (0.4 + 0.6 * k), Color(0, 0, 0, 0.3))
			ellipse_line(base, Vector2(RADIUS, RADIUS * 0.5), Color(1, 0.4, 0.1, 0.6), 2.0)
			var p := _pos - global_position
			var tx := Spr.tex("boss_kp_projectiles_0")
			if tx:
				draw_set_transform(p, t * 9.0, Vector2.ONE)
				draw_texture(tx, -tx.get_size() * 0.5)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_circle(p, 12, Color(0.7, 0.4, 0.15))
				draw_circle(p + Vector2(0, -6), 9, FIRE)
				draw_circle(p + Vector2(0, -10), 5, Color(1, 0.9, 0.3))
			return
		var left := flight + burn - t
		var a := clampf(left / 0.5, 0.0, 1.0)
		ellipse(base, Vector2(RADIUS, RADIUS * 0.5), Color(0.35, 0.22, 0.05, 0.8 * a))
		ellipse(base, Vector2(RADIUS, RADIUS * 0.5) * 0.7, Color(0.85, 0.6, 0.15, 0.45 * a))
		var tx2 := Spr.tex("boss_kp_projectiles_1")
		if tx2:
			var fl := 0.75 + 0.1 * sin(t * 14.0)
			Spr.draw_feet(self, tx2, base + Vector2(0, 6), false, fl, Color(1, 1, 1, a))
		# llamitas
		for i in 5:
			var ang := TAU * i / 5.0 + t
			var fp := base + Vector2(cos(ang) * RADIUS * 0.55, sin(ang) * RADIUS * 0.25)
			var h := 10.0 + 6.0 * sin(t * 12.0 + i * 1.7)
			var tri := PackedVector2Array([fp + Vector2(-6, 0), fp + Vector2(6, 0), fp + Vector2(0, -h)])
			draw_colored_polygon(tri, Color(FIRE, a))
			draw_colored_polygon(PackedVector2Array([fp + Vector2(-3, 0), fp + Vector2(3, 0), fp + Vector2(0, -h * 0.55)]), Color(1, 0.9, 0.3, a))


## 2. Comunicación para TV, RRPP y Protocolo: alfombra roja de pared a pared con cordones.
class Carpet extends Node2D:
	var area := Rect2()
	var life := 7.0
	var t := 0.0

	func _ready() -> void:
		z_index = -2

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			modulate.a = clampf(1.0 - (t - life) / 0.4, 0.0, 1.0)
		if t > life + 0.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / 0.4, 0.0, 1.0)   # se desenrolla
		var x0 := area.position.x - global_position.x
		var w := area.size.x * k
		var r := Rect2(x0, -26, w, 52)
		draw_rect(r, Color(0.7, 0.08, 0.12))
		draw_rect(Rect2(x0, -26, w, 4), Color(0.95, 0.75, 0.3))
		draw_rect(Rect2(x0, 22, w, 4), Color(0.95, 0.75, 0.3))
		# el rollo que se va desenrollando
		var roll := Spr.tex("boss_kp_props_3")
		if roll and k < 1.0:
			Spr.draw_centered(self, roll, Vector2(x0 + w, 0), false, 0.8)
		# postes con cordón (el sprite trae dos postes con su cordón)
		var post := Spr.tex("boss_kp_props_4")
		if post:
			var px := x0 + 70.0
			while px < x0 + w - 40.0:
				for side in [-30.0, 38.0]:
					Spr.draw_feet(self, post, Vector2(px, side), false, 0.6)
				px += 150.0
			return
		var x := x0 + 40.0
		var last := Vector2.INF
		while x < x0 + w - 20.0:
			for side in [-34.0, 34.0]:
				var p := Vector2(x, side)
				draw_line(p, p + Vector2(0, -30), Color(0.85, 0.7, 0.25), 4.0)
				draw_circle(p + Vector2(0, -32), 4, Color(0.95, 0.8, 0.3))
			if last != Vector2.INF:
				for side in [-34.0, 34.0]:
					draw_line(Vector2(last.x, side - 26), Vector2(x, side - 26), Color(0.6, 0.05, 0.1), 3.0)
			last = Vector2(x, 0)
			x += 120.0


## Paparazzi (esbirro): camina por la alfombra, apunta y dispara un flash que ciega (te frena un momento).
class Paparazzi extends CharacterBody2D:
	const FLASH_R := 110.0
	var player: Node2D
	var boss: Node
	var dir := 1.0
	var lane_y := 0.0
	var min_x := 0.0
	var max_x := 0.0
	var hp := 2
	var t := 0.0
	var stunned_t := 0.0
	var life := 10.0
	var _dead := false
	var _hit_t := 0.0
	var _shot_t := 1.2
	var _aim := 0.0
	var _flash := 0.0

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
		var hr := CapsuleShape2D.new()
		hr.radius = 15.0
		hr.height = 60.0
		hs.shape = hr
		hs.position = Vector2(0, -32)
		hurt.add_child(hs)
		add_child(hurt)
		GameFeel.add_shadow(self, Vector2(0, 0), Vector2(16, 6))
		_shot_t = randf_range(0.8, 1.4)

	func take_hit(amount: int, _from_pos: Vector2) -> void:
		if _dead:
			return
		hp -= amount
		_hit_t = 0.25
		_aim = 0.0
		GameFeel.flash(self, 0.08, Color(1, 1, 1))
		if hp <= 0:
			die()

	func die() -> void:
		if _dead:
			return
		_dead = true
		remove_from_group("enemies")
		remove_from_group("boss_minion")
		for i in 3:
			var d := BossFx.Debris.new()
			d.kind = 1 + i % 2
			d.prefix = "boss_kp_debris_"
			d.vel = Vector2(randf_range(-160, 160), randf_range(-300, -150))
			get_parent().add_child(d)
			d.global_position = global_position + Vector2(0, -30)
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(queue_free)

	func pull_toward(dest: Vector2) -> void:
		create_tween().tween_property(self, "global_position", dest, 0.18)

	func _physics_process(delta: float) -> void:
		t += delta
		_hit_t -= delta
		_flash -= delta
		stunned_t -= delta
		life -= delta
		queue_redraw()
		if _dead:
			return
		if life <= 0.0:
			die()
			return
		if stunned_t > 0.0 or _hit_t > 0.0:
			return
		if _aim > 0.0:
			_aim -= delta
			if _aim <= 0.0:
				_shoot()
			return
		velocity = Vector2(dir * 90.0, (lane_y - global_position.y) * 2.0)
		move_and_slide()
		if global_position.x < min_x:
			dir = 1.0
		elif global_position.x > max_x:
			dir = -1.0
		_shot_t -= delta
		if _shot_t <= 0.0 and player and is_instance_valid(player):
			_shot_t = 1.6
			_aim = 0.5
			dir = signf(player.global_position.x - global_position.x)

	func _shoot() -> void:
		_flash = 0.25
		# el flash ciega a todos los que estén cerca
		for who in CoopBoss.targets(get_tree()):
			var pl: Node2D = who
			var d := pl.global_position - global_position
			if Vector2(d.x, d.y * 1.6).length() < FLASH_R and not bool(pl.get("rolling")):
				pl.call("take_hit", 1, global_position)
				if "speed_mult" in pl:
					pl.set("speed_mult", 0.0)
					var tw := pl.create_tween()
					tw.tween_interval(0.4)
					tw.tween_callback(func():
						if is_instance_valid(pl) and float(pl.get("speed_mult")) == 0.0:
							pl.set("speed_mult", 1.0))

	func _draw() -> void:
		var idx := 0
		if _dead:
			idx = 7
		elif _hit_t > 0.0:
			idx = 5
		elif stunned_t > 0.0:
			idx = 6
		elif _flash > 0.0:
			idx = 4
		elif _aim > 0.0:
			idx = 3
		else:
			idx = 1 + int(t * 6.0) % 2
		var flip := dir < 0.0
		# aviso del flash: anillo que se cierra
		if _aim > 0.0:
			var k := 1.0 - _aim / 0.5
			var pts := PackedVector2Array()
			for i in 25:
				var a := TAU * i / 24.0
				pts.append(Vector2(cos(a) * FLASH_R, sin(a) * FLASH_R / 1.6))
			draw_polyline(pts, Color(1, 1, 0.7, 0.3 + 0.5 * k), 2.0)
		if _flash > 0.0:
			var a2 := _flash / 0.25
			draw_circle(Vector2(0, -40), FLASH_R * (1.0 - a2 * 0.3), Color(1, 1, 0.9, 0.35 * a2))
			var fl := Spr.tex("boss_kp_projectiles_5")
			if fl:
				Spr.draw_centered(self, fl, Vector2(18 * (-1.0 if dir < 0.0 else 1.0), -50), false, 0.8 + a2 * 0.6, Color(1, 1, 1, a2))
		var tx := Spr.tex("boss_kp_paparazzi_%d" % idx)
		if tx:
			Spr.draw_feet(self, tx, Vector2.ZERO, flip)
			return
		var s := -1.0 if flip else 1.0
		var step := sin(t * 14.0) * 5.0 if idx in [1, 2] else 0.0
		var suit := Color(0.18, 0.18, 0.22) if idx < 6 else Color(0.3, 0.3, 0.32)
		draw_line(Vector2(-4, -26), Vector2(-6 + step, 0), OUT, 5.0)
		draw_line(Vector2(4, -26), Vector2(6 - step, 0), OUT, 5.0)
		draw_rect(Rect2(-11, -56, 22, 32), suit)
		draw_rect(Rect2(-11, -56, 22, 32), OUT, false, 2.0)
		# cabeza de robot con visera
		draw_rect(Rect2(-9, -72, 18, 16), STEEL)
		draw_rect(Rect2(-9, -72, 18, 16), OUT, false, 2.0)
		draw_rect(Rect2(-6 + 3 * s, -67, 8, 4), Color(0.3, 0.9, 1.0))
		# cámara de fotos
		var cam := Vector2(14 * s, -50 if idx >= 3 else -40)
		draw_rect(Rect2(cam - Vector2(7, 5), Vector2(14, 10)), Color(0.1, 0.1, 0.12))
		draw_circle(cam + Vector2(6 * s, 0), 3.5, Color(0.4, 0.6, 0.9))
		if idx == 4:
			draw_circle(cam + Vector2(0, -8), 7, Color(1, 1, 0.8))


## Palomitas: grano que se infla en el piso y revienta.
class Kernel extends BossFx.Hazard:
	const RADIUS := 34.0
	var delay := 0.0
	var warn := 0.95
	var t := 0.0
	var _popped := false

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if not _popped and t >= delay + warn:
			_popped = true
			for v in victims():
				_victim = v
				var d := player_feet() - global_position
				if Vector2(d.x, d.y * 2.0).length() < RADIUS:
					hurt(1)
			_victim = null
			for i in 3:
				var p := Popped.new()
				p.vel = Vector2(randf_range(-160, 160), randf_range(-320, -160))
				get_parent().add_child(p)
				p.global_position = global_position + Vector2(0, -6)
		if t >= delay + warn + 0.35:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t < delay:
			return
		if not _popped:
			var k := clampf((t - delay) / warn, 0.0, 1.0)
			ellipse(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.5) * k, Color(1, 0.85, 0.3, 0.25))
			ellipse_line(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.5), Color(1, 0.45, 0.15, 0.4 + 0.5 * k), 2.0)
			var s := 0.5 + 0.7 * k + (sin(t * 40.0) * 0.06 if k > 0.7 else 0.0)
			var tx := Spr.tex("boss_kp_projectiles_3")
			if tx:
				Spr.draw_centered(self, tx, Vector2(0, -6), false, s)
			else:
				draw_circle(Vector2(0, -6), 6 * s, Color(1, 0.75, 0.2))
				draw_circle(Vector2(-2, -8), 2 * s, Color(1, 0.95, 0.6))
		else:
			var a := clampf(1.0 - (t - delay - warn) / 0.35, 0.0, 1.0)
			ellipse_line(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.5) * (1.0 + (1.0 - a) * 0.3), Color(1, 1, 0.9, a), 4.0)


## Juliana: cuchillo que cae del techo sobre su sombra.
class Knife extends BossFx.Hazard:
	const RADIUS := 22.0
	var delay := 0.0
	var warn := 0.75
	var t := 0.0
	var _landed := false

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		t += delta
		if not _landed and t >= delay + warn:
			_landed = true
			for v in victims():
				_victim = v
				var d := player_feet() - global_position
				if Vector2(d.x, d.y * 2.0).length() < RADIUS + 10.0:
					hurt(1)
			_victim = null
		if t >= delay + warn + 0.6:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t < delay:
			return
		var k := clampf((t - delay) / warn, 0.0, 1.0)
		var a := 1.0 if not _landed else clampf(1.0 - (t - delay - warn) / 0.6, 0.0, 1.0)
		ellipse(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.45) * (0.4 + 0.6 * k), Color(0, 0, 0, 0.35 * a))
		if not _landed:
			ellipse_line(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.45), Color(0.85, 0.9, 1.0, 0.3 + 0.5 * k), 2.0)
		var y := -320.0 * (1.0 - k * k)
		if k < 0.35:
			return
		var tx := Spr.tex("boss_kp_projectiles_2")
		if tx:
			# el sprite ya trae la hoja hacia abajo
			draw_set_transform(Vector2(0, y - 22), 0.0, Vector2.ONE)
			draw_texture(tx, -tx.get_size() * 0.5, Color(1, 1, 1, a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(-5, y - 30), Vector2(5, y - 30), Vector2(0, y)]), Color(0.85, 0.88, 0.95, a))
			draw_rect(Rect2(-4, y - 46, 8, 16), Color(0.25, 0.15, 0.1, a))


## Acople: onda de sonido en anillo. Hay que rodar para pasarla.
class SoundRing extends BossFx.Hazard:
	var max_r := 300.0
	var speed := 400.0
	var r := 24.0
	var _hit := false

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		r += speed * delta
		for v in victims():
			_victim = v
			var d := player_feet() - global_position
			var e := Vector2(d.x, d.y * 2.0).length()
			if not bool(v.get("rolling")) and absf(e - r) < 20.0 and first_hit():
				_hit = true
				hurt(1)
		_victim = null
		if r >= max_r:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - r / max_r, 0.0, 1.0)
		for i in 3:
			var rr := r - i * 10.0
			if rr > 0.0:
				ellipse_line(Vector2.ZERO, Vector2(rr, rr * 0.5), Color(0.5, 0.9, 1.0, a * (1.0 - i * 0.3)), 5.0 - i)


## Aviso de la embestida con el carrito.
class DashLine extends Node2D:
	var dir := Vector2.RIGHT
	var length := 520.0
	var life := 0.75
	var t := 0.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / life, 0.0, 1.0)
		var n := Vector2(-dir.y, dir.x) * 40.0
		var end := dir * length * minf(1.0, k * 1.6)
		draw_colored_polygon(PackedVector2Array([n, end + n, end - n, -n]), Color(1, 0.5, 0.2, 0.15 + 0.2 * k))
		draw_line(n, end + n, Color(1, 0.6, 0.2, 0.7), 2.0)
		draw_line(-n, end - n, Color(1, 0.6, 0.2, 0.7), 2.0)
