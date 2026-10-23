extends RefCounted
## Peligros y efectos del boss 7 MISSING TEXTURE (Artes, Humanidades y Patrimonio).
## Usan los sprites boss_tex_* cuando existen; si no, se dibujan por código.
## Sin class_name: cargar con preload("res://scripts/combat/boss_tex_fx.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")

const OUT := Color(0.05, 0.05, 0.06)
const MARBLE := Color(0.88, 0.87, 0.84)
const MAGENTA := Color(1.0, 0.0, 1.0)
const CLAY := Color(0.78, 0.45, 0.25)
const SLOW := 0.55


## Imagen glitch que queda donde estaba la estatua cuando salta de cuadro.
class Ghost extends Node2D:
	var life := 0.35
	var t := 0.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - t / life, 0.0, 1.0) * 0.6
		var off := Vector2(randf_range(-4, 4), 0)
		BossFxTex.checker(self, Rect2(Vector2(-50, -240) + off, Vector2(100, 240)), 10.0, a)
		draw_rect(Rect2(Vector2(-50, -240) + off, Vector2(100, 240)), Color(1, 1, 1, a * 0.4), false, 2.0)


## Cuadriculado magenta/negro de "textura que falta" (inner class: las estáticas del script no se ven desde las demás inner classes).
class BossFxTex:
	static func checker(item: CanvasItem, r: Rect2, cell: float = 6.0, a: float = 1.0) -> void:
		var nx := int(ceil(r.size.x / cell))
		var ny := int(ceil(r.size.y / cell))
		for y in ny:
			for x in nx:
				var c := Color(1, 0, 1, a) if (x + y) % 2 == 0 else Color(0, 0, 0, a)
				var p := r.position + Vector2(x, y) * cell
				item.draw_rect(Rect2(p, Vector2(minf(cell, r.end.x - p.x), minf(cell, r.end.y - p.y))), c)


## 1. Arqueología: sitio de excavación. Marca en la arena, revienta y salen vasijas rotas y huesos.
class DigSite extends BossFx.Hazard:
	const RADIUS := 42.0
	var delay := 0.0
	var warn := 0.85
	var shards := 4
	var t := 0.0
	var _burst := false

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if not _burst and t >= delay + warn:
			_burst = true
			for v in victims():
				_victim = v
				var d := player_feet() - global_position
				if Vector2(d.x, d.y * 2.0).length() < RADIUS:
					hurt(1)
			_victim = null
			GameFeel.dust(get_parent(), global_position, 6, Vector2.ZERO, 5.0, Vector2(30, 8))
			var a0 := randf() * TAU
			for i in shards:
				var s := Shard.new()
				s.boss = boss
				s.player = player
				s.kind = i % 2
				s.vel = Vector2.RIGHT.rotated(a0 + TAU * i / shards) * 260.0
				get_parent().add_child(s)
				s.global_position = global_position + Vector2(0, -10)
		if t >= delay + warn + 1.2:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t < delay:
			return
		if not _burst:
			var k := clampf((t - delay) / warn, 0.0, 1.0)
			var tx := Spr.tex("boss_tex_props_0")
			if tx:
				Spr.draw_centered(self, tx, Vector2.ZERO, false, 0.6 + 0.4 * k, Color(1, 1, 1, 0.5 + 0.5 * k))
			else:
				ellipse(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.5) * k, Color(0.55, 0.38, 0.2, 0.55))
				draw_line(Vector2(-14, -7), Vector2(14, 7), Color(0.95, 0.85, 0.3), 3.0)
				draw_line(Vector2(-14, 7), Vector2(14, -7), Color(0.95, 0.85, 0.3), 3.0)
			ellipse_line(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.5), Color(1, 0.3, 0.2, 0.4 + 0.5 * k), 2.0)
		else:
			var a := clampf(1.0 - (t - delay - warn) / 1.2, 0.0, 1.0)
			var tx := Spr.tex("boss_tex_props_1")
			if tx:
				Spr.draw_centered(self, tx, Vector2.ZERO, false, 0.8, Color(1, 1, 1, a))
			else:
				ellipse(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.5), Color(0.25, 0.16, 0.08, a))


## Pedazo de vasija o hueso que sale volando de la excavación.
class Shard extends BossFx.Hazard:
	var kind := 0
	var vel := Vector2.ZERO
	var t := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = 5

	func _process(delta: float) -> void:
		t += delta
		global_position += vel * delta
		rotation += delta * 9.0
		if not _hit and touch_any(22.0):
			_hit = true
			hurt(1, false)
			queue_free()
			return
		if t > 0.85:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_tex_projectiles_%d" % (6 + kind))
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO, false, 0.7)
			return
		if kind == 0:
			draw_colored_polygon(PackedVector2Array([Vector2(-9, -6), Vector2(8, -8), Vector2(5, 7), Vector2(-7, 5)]), CLAY)
			draw_polyline(PackedVector2Array([Vector2(-9, -6), Vector2(8, -8), Vector2(5, 7), Vector2(-7, 5), Vector2(-9, -6)]), OUT, 2.0)
		else:
			draw_line(Vector2(-10, 0), Vector2(10, 0), Color(0.95, 0.92, 0.82), 5.0)
			draw_circle(Vector2(-10, 0), 4, Color(0.95, 0.92, 0.82))
			draw_circle(Vector2(10, 0), 4, Color(0.95, 0.92, 0.82))


## 2. Artes Escénicas: máscara de comedia (0) o tragedia (1). Va en curva hasta pasar al jugador y vuelve.
class Mask extends BossFx.Hazard:
	var kind := 0
	var side := 1.0
	var out_time := 1.0
	var back_time := 0.8
	var origin := Vector2.ZERO
	var target := Vector2.ZERO
	var t := 0.0
	var _hit_cd := 0.0
	var _far := Vector2.ZERO

	func _ready() -> void:
		z_index = 6
		# pasa de largo detrás del jugador antes de volver
		_far = target + (target - origin).normalized() * 140.0

	func _bez(a: Vector2, c: Vector2, b: Vector2, k: float) -> Vector2:
		return a.lerp(c, k).lerp(c.lerp(b, k), k)

	func _process(delta: float) -> void:
		t += delta
		_hit_cd -= delta
		var perp := (target - origin).normalized().orthogonal() * side
		var len := origin.distance_to(_far)
		if t < out_time:
			var k := t / out_time
			global_position = _bez(origin, (origin + _far) * 0.5 + perp * len * 0.45, _far, k)
		elif t < out_time + back_time:
			var k := (t - out_time) / back_time
			var home := origin
			if boss and is_instance_valid(boss):
				home = boss.global_position + Vector2(40, -150)
			global_position = _bez(_far, (_far + home) * 0.5 - perp * len * 0.35, home, k)
		else:
			queue_free()
			return
		rotation = sin(t * 8.0) * 0.4
		for v in victims():
			_victim = v
			if player_body().distance_to(global_position) < 32.0 and cd_ok("brush", 0.6):
				hurt(1, false)
		_victim = null
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_tex_projectiles_%d" % kind)
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO, false, 0.9)
			return
		var col := Color(1.0, 0.85, 0.3) if kind == 0 else Color(0.45, 0.6, 1.0)
		ellipse(Vector2.ZERO, Vector2(22, 26), col)
		ellipse_line(Vector2.ZERO, Vector2(22, 26), OUT, 3.0)
		draw_circle(Vector2(-8, -6), 4, OUT)
		draw_circle(Vector2(8, -6), 4, OUT)
		if kind == 0:
			draw_arc(Vector2(0, 4), 10, 0.2, PI - 0.2, 10, OUT, 3.0)
		else:
			draw_arc(Vector2(0, 16), 10, PI + 0.2, TAU - 0.2, 10, OUT, 3.0)


## 3. Artes Plásticas: brochazo. Aviso fino, el trazo cruza la arena y deja pintura que frena.
class Stroke extends BossFx.Hazard:
	const HALF_W := 34.0
	var dir := Vector2.RIGHT
	var area := Rect2(-640, -360, 1280, 720)
	var col := Color(0.9, 0.2, 0.2)
	var warn := 0.85
	var paint_time := 0.25
	var life := 5.0
	var t := 0.0
	var _a := -600.0
	var _b := 600.0
	var _hit := false
	var _slowing := false

	func _ready() -> void:
		z_index = -1
		# hasta dónde llega el trazo sin salirse de la arena
		var lo := -INF
		var hi := INF
		var p := global_position
		for ax in 2:
			var d := dir[ax]
			var mn := area.position[ax] + 50.0
			var mx := area.end[ax] - 50.0
			if absf(d) < 0.0001:
				continue
			var t1 := (mn - p[ax]) / d
			var t2 := (mx - p[ax]) / d
			lo = maxf(lo, minf(t1, t2))
			hi = minf(hi, maxf(t1, t2))
		_a = maxf(lo, -900.0)
		_b = minf(hi, 900.0)

	func _local(at: Vector2) -> Vector2:
		var d := at - global_position
		return Vector2(d.dot(dir), d.dot(dir.orthogonal()))

	func _painted() -> float:
		var k := clampf((t - warn) / paint_time, 0.0, 1.0)
		return lerpf(_a, _b, k)

	func _process(delta: float) -> void:
		t += delta
		if t >= warn:
			for v in victims():
				_victim = v
				var l := _local(player_feet())
				var inside := absf(l.y) < HALF_W and l.x > _a and l.x < _painted()
				if t < warn + paint_time + 0.05 and inside and first_hit():
					_hit = true
					hurt(1)
				var sm := float(v.get("speed_mult"))
				if inside and t < warn + life:
					if sm == 1.0:
						v.set("speed_mult", SLOW)
						_slowed[v] = true
						_slowing = true
				elif _slowed.has(v):
					if float(v.get("speed_mult")) == SLOW:
						v.set("speed_mult", 1.0)
					_slowed.erase(v)
			_victim = null
		if t >= warn + life:
			modulate.a = clampf(1.0 - (t - warn - life) / 0.4, 0.0, 1.0)
		if t >= warn + life + 0.4:
			_release()
			queue_free()
		queue_redraw()

	var _slowed := {}

	func _release() -> void:
		for v in _slowed.keys():
			if is_instance_valid(v) and float(v.get("speed_mult")) == SLOW:
				v.set("speed_mult", 1.0)
		_slowed.clear()
		_slowing = false

	func _exit_tree() -> void:
		_release()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
		if t < warn:
			var k := t / warn
			var x := _a
			while x < _b:
				draw_line(Vector2(x, 0), Vector2(minf(x + 18, _b), 0), Color(col.r, col.g, col.b, 0.4 + 0.5 * k), 3.0)
				x += 32.0
			draw_rect(Rect2(_a, -HALF_W, _b - _a, HALF_W * 2), Color(col.r, col.g, col.b, 0.08 + 0.12 * k))
			return
		var end := _painted()
		var pts := PackedVector2Array()
		var n := maxi(2, int((end - _a) / 24.0))
		for i in n + 1:
			var x := lerpf(_a, end, float(i) / n)
			pts.append(Vector2(x, -HALF_W + sin(x * 0.07) * 5.0))
		for i in range(n, -1, -1):
			var x := lerpf(_a, end, float(i) / n)
			pts.append(Vector2(x, HALF_W + cos(x * 0.05) * 6.0))
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.8))
		for i in 3:
			var y := -HALF_W * 0.5 + HALF_W * 0.5 * i
			draw_line(Vector2(_a, y), Vector2(end, y), col.darkened(0.25), 2.0)
		if t < warn + paint_time:
			# la punta del pincel gigante
			draw_circle(Vector2(end, 0), HALF_W * 1.1, col.lightened(0.2))


## 4. Diseño Textil: costura. Agujas en círculo alrededor del jugador; el hilo las une y se cierra.
## Si el hilo te pasa por encima te corta (2). Se escapa saliendo del círculo o rodando sobre el hilo.
class Seam extends BossFx.Hazard:
	var r0 := 170.0
	var n := 6
	var close_time := 1.7
	var drop := 0.1
	var t := 0.0
	var _hit := false
	var _done := false
	var _knot := false

	func _ready() -> void:
		z_index = 4

	func _r() -> float:
		var start := drop * n + 0.35
		var k := clampf((t - start) / close_time, 0.0, 1.0)
		return lerpf(r0, 0.0, k * k)

	func _process(delta: float) -> void:
		t += delta
		var start := drop * n + 0.35
		if t >= start:
			for v in victims():
				_victim = v
				var d := player_feet() - global_position
				var e := Vector2(d.x, d.y * 2.0).length()
				if absf(e - _r()) < 14.0 and not bool(v.get("rolling")) and first_hit():
					_hit = true
					hurt(2)
			_victim = null
		if not _done and t >= start + close_time:
			_done = true
			_knot = true
			GameFeel.dust(get_parent(), global_position, 8, Vector2.ZERO, 5.0, Vector2(20, 6))
		if t >= start + close_time + 0.5:
			queue_free()
		queue_redraw()

	func _needle(i: int, r: float) -> Vector2:
		var a := TAU * i / n - PI * 0.5
		return Vector2(cos(a) * r, sin(a) * r * 0.5)

	func _draw() -> void:
		var start := drop * n + 0.35
		var r := _r()
		if _knot:
			# el hilo cerrado queda hecho un nudo
			var kt := Spr.tex("boss_tex_props_7")
			if kt:
				Spr.draw_centered(self, kt, Vector2(0, -10), false, 0.6)
			return
		var shown := mini(n, int(t / drop) + 1)
		# hilo
		if t >= start:
			var pts := PackedVector2Array()
			for i in n + 1:
				pts.append(_needle(i % n, r))
			draw_polyline(pts, Color(0.95, 0.15, 0.2), 3.0)
		else:
			ellipse_line(Vector2.ZERO, Vector2(r0, r0 * 0.5), Color(1, 0.3, 0.3, 0.35), 2.0)
			for i in range(1, shown):
				draw_line(_needle(i - 1, r0), _needle(i, r0), Color(0.95, 0.15, 0.2, 0.6), 2.0)
		# agujas clavadas
		var tx := Spr.tex("boss_tex_projectiles_3")
		for i in shown:
			var p := _needle(i, r)
			var fall := clampf((t - drop * i) / 0.12, 0.0, 1.0)
			var at := p + Vector2(0, -60.0 * (1.0 - fall))
			if tx:
				Spr.draw_feet(self, tx, at, false, 0.6)
			else:
				draw_line(at, at + Vector2(0, -34), Color(0.8, 0.82, 0.88), 4.0)
				draw_circle(at + Vector2(0, -30), 3, OUT)


## 5. Sociología: maniquí. Solo avanza cuando el jugador no lo mira; mirado se queda en pose.
class Mannequin extends CharacterBody2D:
	var player: Node2D
	var boss: Node
	var hp := 2
	var t := 0.0
	var stunned_t := 0.0
	var life := 14.0
	var _dead := false
	var _hit_t := 0.0
	var _hit_cd := 0.0
	var _moving := false
	var _pose := 3

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
		hr.radius = 16.0
		hr.height = 70.0
		hs.shape = hr
		hs.position = Vector2(0, -38)
		hurt.add_child(hs)
		add_child(hurt)
		GameFeel.add_shadow(self, Vector2(0, 0), Vector2(18, 6))

	func take_hit(amount: int, _from_pos: Vector2) -> void:
		if _dead:
			return
		hp -= amount
		_hit_t = 0.25
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
			d.kind = 1 + i % 2
			d.prefix = "boss_tex_debris_"
			d.vel = Vector2(randf_range(-160, 160), randf_range(-300, -150))
			get_parent().add_child(d)
			d.global_position = global_position + Vector2(0, -30)
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(queue_free)

	func pull_toward(dest: Vector2) -> void:
		create_tween().tween_property(self, "global_position", dest, 0.18)

	func _seen() -> bool:
		if boss and is_instance_valid(boss) and boss.has_method("sees"):
			return bool(boss.call("sees", global_position + Vector2(0, -40)))
		return false

	func _physics_process(delta: float) -> void:
		t += delta
		_hit_t -= delta
		_hit_cd -= delta
		stunned_t -= delta
		life -= delta
		queue_redraw()
		if _dead:
			return
		if life <= 0.0:
			die()
			return
		player = CoopBoss.nearest_to(get_tree(), global_position, player)   # multijugador: el más cercano
		if player == null or not is_instance_valid(player):
			return
		var was := _moving
		_moving = stunned_t <= 0.0 and not _seen()
		if was and not _moving:
			_pose = 3 + randi() % 2
		var to := player.global_position - global_position
		if _moving and to.length() > 26.0:
			velocity = to.normalized() * 120.0
			move_and_slide()
		if _hit_cd <= 0.0 and to.length() < 34.0 and _moving:
			_hit_cd = 1.2
			player.call("take_hit", 1, global_position)

	func _draw() -> void:
		var idx := 0
		if _dead:
			idx = 7
		elif _hit_t > 0.0:
			idx = 5
		elif stunned_t > 0.0:
			idx = 6
		elif _moving:
			idx = 1 + int(t * 6.0) % 2
		else:
			idx = _pose
		var tx := Spr.tex("boss_tex_mannequin_%d" % idx)
		var tint := Color(0.75, 0.75, 0.8) if not _moving and not _dead else Color.WHITE
		if tx:
			Spr.draw_feet(self, tx, Vector2.ZERO, to_flip(), 1.0, tint)
			return
		var body := Color(0.92, 0.88, 0.8) * tint
		var step := sin(t * 14.0) * 5.0 if _moving else 0.0
		var arm := 0.0 if _moving else (-14.0 if _pose == 3 else 14.0)
		draw_line(Vector2(0, -8), Vector2(0, 0), OUT, 3.0)
		draw_line(Vector2(-12, 0), Vector2(12, 0), OUT, 3.0)
		draw_line(Vector2(-5, -30), Vector2(-7 + step, -8), body, 6.0)
		draw_line(Vector2(5, -30), Vector2(7 - step, -8), body, 6.0)
		draw_rect(Rect2(-12, -62, 24, 34), body)
		draw_rect(Rect2(-12, -62, 24, 34), OUT, false, 2.0)
		draw_line(Vector2(-12, -58), Vector2(-24, -40 + arm), body, 5.0)
		draw_line(Vector2(12, -58), Vector2(24, -40 - arm), body, 5.0)
		draw_circle(Vector2(0, -72), 10, body)
		draw_arc(Vector2(0, -72), 10, 0, TAU, 16, OUT, 2.0)
		if not _moving:
			# lágrimas negras: está "llorando" quieto
			draw_line(Vector2(-4, -72), Vector2(-4, -64), OUT, 2.0)
			draw_line(Vector2(4, -72), Vector2(4, -64), OUT, 2.0)
		else:
			draw_rect(Rect2(-6, -76, 4, 4), MAGENTA)
			draw_rect(Rect2(2, -76, 4, 4), MAGENTA)

	func to_flip() -> bool:
		return player != null and is_instance_valid(player) and player.global_position.x < global_position.x


## Cartel grande (¡ESTATUA!, OBRA RESTAURADA).
class Card extends Node2D:
	var text := "¡ESTATUA!"
	var col := Color(1.0, 0.35, 1.0)
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
		draw_set_transform(Vector2(0, -290), -0.06, Vector2(s, s))
		var f := ThemeDB.fallback_font
		draw_rect(Rect2(-160, -30, 320, 60), Color(0.08, 0.06, 0.08, 0.9))
		draw_rect(Rect2(-160, -30, 320, 60), col, false, 4.0)
		draw_string(f, Vector2(-160, 12), text, HORIZONTAL_ALIGNMENT_CENTER, 320, 30, col)


## Capa de piedra encima del jugador mientras la POSE FINAL lo tiene petrificado.
class PlayerStone extends Node2D:
	var life := 1.0
	var t := 0.0

	func _ready() -> void:
		z_index = 8

	func _process(delta: float) -> void:
		t += delta
		if t >= life:
			GameFeel.dust(get_parent().get_parent(), global_position + Vector2(0, -20), 6, Vector2.ZERO, 4.0, Vector2(16, 20))
			# se libera solo (con 2 jugadores el boss solo suelta a su objetivo)
			var pl := get_parent()
			if pl != null and "speed_mult" in pl and float(pl.get("speed_mult")) == 0.0:
				pl.set("speed_mult", 1.0)
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / 0.15, 0.0, 1.0)
		var h := 70.0 * k
		draw_rect(Rect2(-18, 14 - h, 36, h), Color(0.62, 0.62, 0.65, 0.82))
		draw_rect(Rect2(-18, 14 - h, 36, h), OUT, false, 2.0)
		if t > life * 0.5:
			draw_polyline(PackedVector2Array([Vector2(-8, -50), Vector2(0, -34), Vector2(-4, -20), Vector2(6, -2)]), OUT, 2.0)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(-40, -64), "POSE FINAL", HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(1, 0.4, 1))
