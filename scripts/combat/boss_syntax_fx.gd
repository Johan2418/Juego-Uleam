extends RefCounted
## Peligros y efectos del boss 4 SYNTAX ERROR (Educación, Turismo y Humanidades).
## Usan los sprites boss_syntax_* cuando existen; si no, se dibujan por código.
## Sin class_name: cargar con preload("res://scripts/combat/boss_syntax_fx.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")

const OUT := Color(0.05, 0.05, 0.06)
const CHALK := Color(0.95, 0.95, 0.9)
const WOOD := Color(0.55, 0.36, 0.2)
const BOARD := Color(0.15, 0.36, 0.25)
## Colores de cada símbolo de La Lección: ▲ ● ■ ★
const SYM_COL := [Color(1.0, 0.45, 0.4), Color(0.45, 0.75, 1.0), Color(0.5, 0.95, 0.5), Color(1.0, 0.85, 0.3)]


## Dibuja un símbolo de La Lección (0 ▲, 1 ●, 2 ■, 3 ★) centrado en c, de tamaño s.
class Sym extends RefCounted:
	static func draw(ci: CanvasItem, kind: int, c: Vector2, s: float, col: Color, outline: bool = true) -> void:
		var pts := PackedVector2Array()
		match kind:
			0:
				pts = PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.95, s * 0.75), c + Vector2(-s * 0.95, s * 0.75)])
			1:
				for i in 20:
					var a := TAU * i / 20.0
					pts.append(c + Vector2(cos(a), sin(a)) * s * 0.85)
			2:
				pts = PackedVector2Array([c + Vector2(-s, -s) * 0.78, c + Vector2(s, -s) * 0.78, c + Vector2(s, s) * 0.78, c + Vector2(-s, s) * 0.78])
			_:
				for i in 10:
					var a := -PI * 0.5 + TAU * i / 10.0
					var r := s if i % 2 == 0 else s * 0.45
					pts.append(c + Vector2(cos(a), sin(a)) * r)
		ci.draw_colored_polygon(pts, col)
		if outline:
			pts.append(pts[0])
			ci.draw_polyline(pts, OUT, 1.5)


## Pupitre de La Lección. Golpearlo le avisa al boss qué símbolo eligió el jugador.
class Desk extends Node2D:
	var boss: Node
	var player: Node2D
	var symbol := 0
	var t := 0.0
	var state := 0   # 0 normal, 1 acertado, 2 equivocado, 3 roto
	var _cd := 0.0
	var _shake := 0.0
	var _rise := 0.0

	func _init() -> void:
		add_to_group("boss_hazard")
		add_to_group("syntax_desk")

	func _ready() -> void:
		z_index = 1
		add_to_group("enemies")
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := RectangleShape2D.new()
		hr.size = Vector2(56, 60)
		hs.shape = hr
		hs.position = Vector2(0, -26)
		hurt.add_child(hs)
		add_child(hurt)
		GameFeel.add_shadow(self, Vector2(0, 0), Vector2(30, 8))
		GameFeel.dust(get_parent(), global_position, 5, Vector2.ZERO, 4.0, Vector2(30, 6))

	## El jugador le pega: el boss decide si era el pupitre correcto.
	func take_hit(_amount: int, _from: Vector2) -> void:
		if _cd > 0.0 or state == 3 or boss == null or not is_instance_valid(boss):
			return
		_cd = 0.7
		boss.call("desk_hit", self)

	func mark(ok: bool) -> void:
		state = 1 if ok else 2
		_shake = 0.3
		GameFeel.flash(self, 0.12, Color(0.6, 1, 0.6) if ok else Color(1, 0.5, 0.4))
		if ok:
			GameFeel.parry_burst(get_parent(), global_position + Vector2(0, -40), 18.0)

	func vanish(broken: bool) -> void:
		remove_from_group("enemies")
		remove_from_group("syntax_desk")
		if broken:
			state = 3
			for i in 4:
				var d := BossFx.Debris.new()
				d.kind = 1
				d.prefix = "boss_syntax_debris_"
				d.vel = Vector2(randf_range(-160, 160), randf_range(-300, -140))
				get_parent().add_child(d)
				d.global_position = global_position + Vector2(0, -20)
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)

	func _process(delta: float) -> void:
		t += delta
		_cd -= delta
		_shake = maxf(0.0, _shake - delta)
		_rise = minf(1.0, _rise + delta * 5.0)
		if state == 1 and _cd <= 0.0:
			state = 0
		queue_redraw()

	func _draw() -> void:
		var off := Vector2(sin(t * 60.0) * 3.0 * (_shake / 0.3), -(1.0 - _rise) * 30.0)
		var tx := Spr.tex("boss_syntax_desks_%d" % (3 if state == 3 else (2 if state == 2 else (1 if state == 1 else 0))))
		var panel_c := off + Vector2(0, -50)
		var sym_s := 10.0
		if tx:
			Spr.draw_feet(self, tx, off)
			# panel claro del respaldo (arriba a la izquierda del sprite)
			panel_c = off + Vector2(-tx.get_width() * 0.5 + 17.0, -tx.get_height() + 7.0)
			sym_s = 8.0
		else:
			# silla con respaldo atrás, mesa adelante
			draw_rect(Rect2(off.x - 22, off.y - 70, 44, 34), WOOD)
			draw_rect(Rect2(off.x - 22, off.y - 70, 44, 34), OUT, false, 2.0)
			draw_rect(Rect2(off.x - 16, off.y - 64, 32, 24), Color(0.92, 0.88, 0.75))
			draw_rect(Rect2(off.x - 26, off.y - 34, 52, 10), WOOD.lightened(0.15))
			draw_rect(Rect2(off.x - 26, off.y - 34, 52, 10), OUT, false, 2.0)
			for x in [-22.0, 20.0]:
				draw_rect(Rect2(off.x + x, off.y - 24, 4, 24), Color(0.35, 0.35, 0.38))
			panel_c = off + Vector2(0, -52)
		if state != 3:
			Sym.draw(self, symbol, panel_c, sym_s, SYM_COL[symbol])
		if state == 1:
			draw_arc(panel_c, sym_s * 2.0, 0, TAU, 20, Color(0.5, 1, 0.5), 3.0)
		elif state == 2:
			var q := sym_s * 1.4
			draw_line(panel_c + Vector2(-q, -q), panel_c + Vector2(q, q), Color(1, 0.25, 0.2), 3.0)
			draw_line(panel_c + Vector2(q, -q), panel_c + Vector2(-q, q), Color(1, 0.25, 0.2), 3.0)


## Tiza lanzada (Educación Básica). Se puede bloquear o hacer parry.
class Chalk extends BossFx.Hazard:
	var vel := Vector2.DOWN * 360.0
	var life := 2.6
	var t := 0.0

	func _ready() -> void:
		z_index = 4
		rotation = vel.angle()

	func _process(delta: float) -> void:
		t += delta
		global_position += vel * delta
		if player_ok() and player_body().distance_to(global_position) < 20.0:
			hurt(1, false)
			GameFeel.dust(get_parent(), global_position, 3, Vector2.ZERO, 3.0, Vector2(8, 4))
			queue_free()
			return
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_syntax_projectiles_0")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO)
			return
		draw_line(Vector2(-14, 0), Vector2(-26, 0), Color(1, 1, 1, 0.25), 4.0)
		draw_rect(Rect2(-9, -3, 18, 6), CHALK)
		draw_rect(Rect2(-9, -3, 18, 6), OUT, false, 1.0)


## Bloque ABC que cae (Educación Inicial): sombra que crece, cae y queda un momento.
class BlockDrop extends BossFx.Hazard:
	var delay := 0.0
	var warn := 0.85
	var letter := "A"
	var col := Color(1, 0.5, 0.4)
	var t := 0.0
	var _landed := false
	const R := 34.0

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		t += delta
		var k := t - delay
		if not _landed and k >= warn:
			_landed = true
			GameFeel.dust(get_parent(), global_position, 5, Vector2.ZERO, 4.0, Vector2(30, 6))
			if player_ok():
				var d := player_feet() - global_position
				if Vector2(d.x, d.y * 2.0).length() < R:
					hurt(2)
		if k > warn + 0.7:
			modulate.a = clampf(1.0 - (k - warn - 0.7) / 0.3, 0.0, 1.0)
		if k > warn + 1.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := t - delay
		if k < 0.0:
			return
		var p := clampf(k / warn, 0.0, 1.0)
		if not _landed:
			ellipse(Vector2.ZERO, Vector2(R, R * 0.5) * (0.4 + 0.6 * p), Color(0, 0, 0, 0.3))
			ellipse_line(Vector2.ZERO, Vector2(R, R * 0.5), Color(1, 0.3, 0.2, 0.5 + 0.4 * p), 2.0)
		var h := lerpf(320.0, 0.0, p * p) if not _landed else 0.0
		_block(Vector2(0, -h - 24))

	func _block(c: Vector2) -> void:
		var tx := Spr.tex("boss_syntax_projectiles_1")
		if tx:
			Spr.draw_centered(self, tx, c)
		else:
			draw_rect(Rect2(c.x - 22, c.y - 22, 44, 44), col)
			draw_rect(Rect2(c.x - 22, c.y - 22, 44, 8), col.lightened(0.25))
			draw_rect(Rect2(c.x - 22, c.y - 22, 44, 44), OUT, false, 2.0)
		draw_string(ThemeDB.fallback_font, c + Vector2(-22, 9), letter, HORIZONTAL_ALIGNMENT_CENTER, 44, 24, Color.WHITE)


## Fila de púas braille (Educación Inclusiva): la fila se ilumina con sus puntos y luego brotan las púas.
## Los huecos (sin puntos) son seguros.
class BrailleRow extends BossFx.Hazard:
	var x0 := -500.0
	var x1 := 500.0
	var gaps: Array[Vector2] = []   # (desde, hasta) en x global, sin púas
	var warn := 0.8
	var active := 0.45
	var t := 0.0
	var _hit := false
	const CELL := 26.0

	func _ready() -> void:
		z_index = -1

	func _safe(x: float) -> bool:
		for g in gaps:
			if x >= g.x and x <= g.y:
				return true
		return false

	func _process(delta: float) -> void:
		t += delta
		if t >= warn and t < warn + active and not _hit and player_ok():
			var f := player_feet()
			if absf(f.y - global_position.y) < 18.0 and f.x > x0 and f.x < x1 and not _safe(f.x):
				_hit = true
				hurt(2)
		if t > warn + active + 0.2:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var up := t >= warn
		var blink := 0.5 + 0.5 * absf(sin(t * 14.0))
		var x := x0
		var i := 0
		while x < x1:
			var gx := x + CELL * 0.5
			if not _safe(gx):
				var lx := gx - global_position.x
				# celda braille: 2 columnas x 3 filas, algunos puntos encendidos
				for c in 2:
					for r in 3:
						if (i * 7 + c * 3 + r * 5) % 4 != 0:
							var p := Vector2(lx - 5 + c * 10, -8 + r * 8)
							if up:
								draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 2), p + Vector2(0, -16), p + Vector2(4, 2)]), Color(0.75, 0.78, 0.82))
								draw_polyline(PackedVector2Array([p + Vector2(-4, 2), p + Vector2(0, -16), p + Vector2(4, 2)]), OUT, 1.0)
							else:
								draw_circle(p, 3.0, Color(1, 0.85, 0.3, 0.35 + 0.5 * blink))
			x += CELL
			i += 1


## Silbato "¡ALTO!" (Entrenamiento Deportivo): luz verde para moverse, luz roja para quedarse quieto.
class RedLight extends BossFx.Hazard:
	var cycles := 3
	var green := 1.3
	var red := 1.1
	var area := Rect2()
	var t := 0.0
	var _hit_this := -1

	func _ready() -> void:
		z_index = 8

	func is_red() -> bool:
		var per := green + red
		return fmod(t, per) >= green and t < per * cycles

	func _process(delta: float) -> void:
		t += delta
		var per := green + red
		var idx := int(t / per)
		if is_red() and fmod(t, per) > green + 0.25 and _hit_this != idx and player_ok():
			var v: Vector2 = player.get("velocity")
			if v.length() > 30.0:
				_hit_this = idx
				hurt(1)
				if is_instance_valid(boss):
					boss.call("_say", "¡TE MOVISTE!", Color(1, 0.3, 0.25))
		if t > per * cycles:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var red_on := is_red()
		draw_rect(Rect2(area.position - global_position, area.size), Color(1, 0, 0, 0.1) if red_on else Color(0, 1, 0.3, 0.04))
		# semáforo en la pared de arriba
		var c := Vector2(area.position.x + 70, area.position.y + 150) - global_position
		draw_rect(Rect2(c.x - 22, c.y - 40, 44, 80), Color(0.1, 0.1, 0.12))
		draw_rect(Rect2(c.x - 22, c.y - 40, 44, 80), OUT, false, 2.0)
		draw_circle(c + Vector2(0, -18), 14, Color(1, 0.2, 0.15) if red_on else Color(0.3, 0.08, 0.08))
		draw_circle(c + Vector2(0, 18), 14, Color(0.3, 1, 0.4) if not red_on else Color(0.06, 0.25, 0.1))
		var txt := "¡ALTO!" if red_on else "¡SIGA!"
		draw_string(ThemeDB.fallback_font, c + Vector2(-80, 64), txt, HORIZONTAL_ALIGNMENT_CENTER, 160, 22, Color(1, 0.3, 0.25) if red_on else Color(0.4, 1, 0.5))


## Cono de las vueltas (Actividad Física). Solo decoración; se borra al terminar.
class Cone extends Node2D:
	var t := 0.0

	func _init() -> void:
		add_to_group("boss_hazard")

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_syntax_projectiles_7")
		if tx:
			Spr.draw_feet(self, tx, Vector2.ZERO)
			return
		var pts := PackedVector2Array([Vector2(-14, 0), Vector2(-4, -34), Vector2(4, -34), Vector2(14, 0)])
		draw_colored_polygon(pts, Color(1, 0.5, 0.15))
		draw_rect(Rect2(-10, -18, 20, 5), Color.WHITE)
		pts.append(pts[0])
		draw_polyline(pts, OUT, 1.5)
		draw_rect(Rect2(-18, -3, 36, 5), Color(1, 0.45, 0.1))


## Esbirro botones-robot con carrito de maletas (Gestión Hotelera): embiste en línea recta.
class Bellhop extends CharacterBody2D:
	var player: Node2D
	var hp := 2
	var t := 0.0
	var _rest := 0.8
	var _dash := 0.0
	var _dir := Vector2.DOWN
	var _dead := false
	var _hit_t := 0.0
	var _bump_cd := 0.0

	func _ready() -> void:
		add_to_group("enemies")
		add_to_group("boss_minion")
		collision_layer = 2
		collision_mask = 1
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := CircleShape2D.new()
		hr.radius = 22.0
		hs.shape = hr
		hs.position = Vector2(0, -20)
		hurt.add_child(hs)
		add_child(hurt)
		GameFeel.add_shadow(self, Vector2(0, 0), Vector2(26, 8))

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
			d.prefix = "boss_syntax_debris_"
			d.vel = Vector2(randf_range(-160, 160), randf_range(-300, -150))
			get_parent().add_child(d)
			d.global_position = global_position + Vector2(0, -18)
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
			velocity = _dir * 300.0
			move_and_slide()
			if _bump_cd <= 0.0 and player.global_position.distance_to(global_position) < 34.0:
				_bump_cd = 0.8
				player.call("take_hit", 1, global_position)
			if _dash <= 0.0:
				_rest = randf_range(0.6, 0.9)
		else:
			_rest -= delta
			if _rest <= 0.0:
				_dash = 0.75
				var to := player.global_position - global_position
				_dir = Vector2.DOWN if to.length() < 1.0 else to.normalized()

	func _draw() -> void:
		var idx := 0
		if _dead:
			idx = 7
		elif _hit_t > 0.0:
			idx = 5
		elif _dash > 0.0:
			idx = 4 if _dash > 0.6 else 2 + int(t * 8.0) % 2
		else:
			idx = int(t * 3.0) % 2
		var tx := Spr.tex("boss_syntax_bellhop_%d" % idx)
		if tx:
			Spr.draw_feet(self, tx, Vector2.ZERO)
			return
		var fx := 1.0 if _dir.x >= 0.0 else -1.0
		# carrito
		draw_rect(Rect2(fx * 6 - 18, -30, 36, 22), Color(0.95, 0.75, 0.2))
		draw_rect(Rect2(fx * 6 - 14, -44, 14, 14), Color(0.5, 0.3, 0.6))
		draw_rect(Rect2(fx * 6, -40, 12, 10), Color(0.3, 0.5, 0.75))
		draw_rect(Rect2(fx * 6 - 18, -30, 36, 22), OUT, false, 2.0)
		draw_circle(Vector2(fx * 6 - 12, -6), 4, OUT)
		draw_circle(Vector2(fx * 6 + 12, -6), 4, OUT)
		# botones: bola roja con gorrito
		var b := Vector2(-fx * 16, -26)
		draw_circle(b, 13, Color(0.8, 0.15, 0.15))
		draw_arc(b, 13, 0, TAU, 16, OUT, 2.0)
		draw_rect(Rect2(b.x - 7, b.y - 20, 14, 7), Color(0.8, 0.15, 0.15))
		draw_rect(Rect2(b.x - 7, b.y - 20, 14, 7), OUT, false, 1.5)
		draw_circle(b + Vector2(-4, -2), 2.5, Color(0.6, 1, 0.9))
		draw_circle(b + Vector2(4, -2), 2.5, Color(0.6, 1, 0.9))


## Página de libro voladora (Lengua y Literatura): avanza ondulando.
class Page extends BossFx.Hazard:
	var vel := Vector2.DOWN * 230.0
	var life := 3.0
	var t := 0.0
	var _side := Vector2.ZERO

	func _ready() -> void:
		z_index = 4
		_side = vel.normalized().orthogonal()

	func _process(delta: float) -> void:
		t += delta
		global_position += vel * delta + _side * cos(t * 7.0) * 90.0 * delta
		if player_ok() and player_body().distance_to(global_position) < 22.0:
			hurt(1, false)
			queue_free()
			return
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var flap := sin(t * 14.0)
		var tx := Spr.tex("boss_syntax_projectiles_2")
		if tx:
			draw_set_transform(Vector2.ZERO, flap * 0.3, Vector2(1.0, 0.7 + 0.3 * absf(flap)))
			Spr.draw_centered(self, tx, Vector2.ZERO)
			return
		draw_set_transform(Vector2.ZERO, flap * 0.3, Vector2(1.0, 0.7 + 0.3 * absf(flap)))
		draw_rect(Rect2(-14, -10, 28, 20), Color(0.97, 0.95, 0.88))
		for k in 4:
			draw_line(Vector2(-10, -6 + k * 4), Vector2(10, -6 + k * 4), Color(0.5, 0.55, 0.7), 1.0)
		draw_rect(Rect2(-14, -10, 28, 20), OUT, false, 1.5)


## Punto final gigante (Lengua y Literatura): cae donde estaba el jugador.
class Period extends BossFx.Hazard:
	var warn := 1.1
	var t := 0.0
	var _landed := false
	const R := 70.0

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		t += delta
		if not _landed and t >= warn:
			_landed = true
			GameFeel.dust(get_parent(), global_position, 12, Vector2.ZERO, 7.0, Vector2(70, 10))
			if is_instance_valid(boss):
				boss.call("_impact", global_position, 7.0)
			if player_ok():
				var d := player_feet() - global_position
				if Vector2(d.x, d.y * 2.0).length() < R:
					hurt(3)
		if t > warn + 1.2:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var p := clampf(t / warn, 0.0, 1.0)
		if not _landed:
			ellipse(Vector2.ZERO, Vector2(R, R * 0.5) * (0.3 + 0.7 * p), Color(0, 0, 0, 0.35))
			ellipse_line(Vector2.ZERO, Vector2(R, R * 0.5), Color(1, 0.25, 0.2, 0.5 + 0.5 * p), 3.0)
			var h := lerpf(400.0, 0.0, p * p)
			var tx := Spr.tex("boss_syntax_projectiles_5")
			if tx:
				var k := R * 1.1 / tx.get_width()
				Spr.draw_centered(self, tx, Vector2(0, -h - R * 0.5), false, k)
			else:
				draw_circle(Vector2(0, -h - R * 0.5), R * 0.55, Color(0.05, 0.05, 0.08))
				draw_circle(Vector2(-12, -h - R * 0.5 - 14), 8, Color(1, 1, 1, 0.25))
		else:
			var a := clampf(1.0 - (t - warn - 0.6) / 0.6, 0.0, 1.0)
			ellipse(Vector2.ZERO, Vector2(R, R * 0.5), Color(0.05, 0.05, 0.08, 0.85 * a))


## Globo de diálogo que rebota (Idiomas). Se puede romper.
class Bubble extends BossFx.Hazard:
	var vel := Vector2(200, 160)
	var arena := Rect2()
	var text := "Hello"
	var life := 5.5
	var t := 0.0
	var _hit_cd := 0.0
	const R := 24.0

	func _ready() -> void:
		z_index = 4
		add_to_group("enemies")
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := CircleShape2D.new()
		hr.radius = 26.0
		hs.shape = hr
		hurt.add_child(hs)
		add_child(hurt)

	func take_hit(_amount: int, _from: Vector2) -> void:
		GameFeel.parry_burst(get_parent(), global_position, 16.0)
		queue_free()

	func _process(delta: float) -> void:
		t += delta
		_hit_cd -= delta
		global_position += vel * delta
		var p := global_position
		if p.x < arena.position.x + R or p.x > arena.end.x - R:
			vel.x = -vel.x
		if p.y < arena.position.y + R + 20.0 or p.y > arena.end.y - R:
			vel.y = -vel.y
		global_position = Vector2(clampf(p.x, arena.position.x + R, arena.end.x - R), clampf(p.y, arena.position.y + R + 20.0, arena.end.y - R))
		if _hit_cd <= 0.0 and player_ok() and player_body().distance_to(global_position) < R + 8.0:
			_hit_cd = 0.9
			hurt(1, false)
		if t > life:
			modulate.a = clampf(1.0 - (t - life) / 0.3, 0.0, 1.0)
			if t > life + 0.3:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var s := 1.0 + 0.06 * sin(t * 8.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		var tx := Spr.tex("boss_syntax_projectiles_3")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO)
		else:
			ellipse(Vector2.ZERO, Vector2(R + 8, R * 0.75), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, 14), Vector2(6, 14), Vector2(-12, 28)]), Color.WHITE)
			ellipse_line(Vector2.ZERO, Vector2(R + 8, R * 0.75), OUT, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-30, 5), text, HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(0.15, 0.2, 0.45))


## Avión de papel que persigue (Turismo Sostenible). Se puede romper o hacer parry.
class PaperPlane extends BossFx.Hazard:
	var vel := Vector2.DOWN * 210.0
	var turn := 2.2
	var life := 4.5
	var t := 0.0

	func _ready() -> void:
		z_index = 4
		add_to_group("enemies")
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := CircleShape2D.new()
		hr.radius = 16.0
		hs.shape = hr
		hurt.add_child(hs)
		add_child(hurt)

	func take_hit(_amount: int, _from: Vector2) -> void:
		GameFeel.parry_burst(get_parent(), global_position, 12.0)
		queue_free()

	func _process(delta: float) -> void:
		t += delta
		if player_ok() and t > 0.3:
			var want := (player_body() - global_position).angle()
			var a := vel.angle()
			var diff := wrapf(want - a, -PI, PI)
			a += clampf(diff, -turn * delta, turn * delta)
			vel = Vector2.from_angle(a) * vel.length()
		global_position += vel * delta
		rotation = vel.angle()
		if player_ok() and player_body().distance_to(global_position) < 18.0:
			hurt(1, false)
			queue_free()
			return
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_syntax_projectiles_4")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO)
			return
		var pts := PackedVector2Array([Vector2(16, 0), Vector2(-12, -10), Vector2(-6, 0), Vector2(-12, 10)])
		draw_colored_polygon(pts, Color(0.97, 0.97, 0.95))
		pts.append(pts[0])
		draw_polyline(pts, OUT, 1.5)
		draw_line(Vector2(16, 0), Vector2(-6, 0), Color(0.6, 0.6, 0.65), 1.0)
		# franja de boleto
		draw_line(Vector2(-4, -5), Vector2(-4, 5), Color(0.2, 0.6, 0.9), 2.0)


## Mancha de Rorschach (Psicología Educativa): tapa la vista cerca del jugador mientras los controles están invertidos.
class InkBlot extends Node2D:
	var life := 3.0
	var target: Node2D
	var t := 0.0
	var _seed := 0.0

	func _init() -> void:
		add_to_group("boss_hazard")

	func _ready() -> void:
		z_index = 9
		_seed = randf() * 10.0

	func _process(delta: float) -> void:
		t += delta
		if target and is_instance_valid(target):
			global_position = target.global_position + Vector2(0, -150)
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(t / 0.25, 0.0, 1.0) * clampf((life - t) / 0.4, 0.0, 1.0)
		var col := Color(0.08, 0.06, 0.12, 0.85 * a)
		# figura simétrica (como las láminas del test)
		var grow := 0.6 + 0.4 * clampf(t / 0.5, 0.0, 1.0)
		for side in [-1.0, 1.0]:
			for i in 6:
				var ang := _seed + i * 1.3
				var c := Vector2(side * (14.0 + 16.0 * absf(sin(ang))), -20.0 + i * 9.0) * grow
				draw_circle(c, (14.0 + 8.0 * sin(ang * 2.0)) * grow, col)
		draw_string(ThemeDB.fallback_font, Vector2(-90, 74), "¿QUÉ VES?", HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color(0.85, 0.7, 1.0, a))


## El birrete que se cae al pasar de fase.
class CapFall extends Node2D:
	var t := 0.0
	var vel := Vector2(130, -260)

	func _ready() -> void:
		z_index = 6

	func _process(delta: float) -> void:
		t += delta
		vel.y += 900.0 * delta
		position += vel * delta
		rotation += delta * 7.0
		if t > 0.6:
			modulate.a = clampf(1.0 - (t - 0.6) / 0.4, 0.0, 1.0)
		if t > 1.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_syntax_head_3")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO)
			return
		draw_colored_polygon(PackedVector2Array([Vector2(-30, 0), Vector2(0, -12), Vector2(30, 0), Vector2(0, 12)]), Color(0.08, 0.08, 0.1))
		draw_rect(Rect2(-14, 2, 28, 10), Color(0.1, 0.1, 0.12))
		draw_line(Vector2(0, 0), Vector2(20, 14), Color(0.98, 0.78, 0.2), 2.0)


## Timbre escolar de la aparición: ondas que salen de la campana de la pared.
class SchoolBell extends Node2D:
	var t := 0.0
	var life := 1.6

	func _ready() -> void:
		z_index = 9

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var shake := sin(t * 70.0) * 3.0
		draw_circle(Vector2(shake, 0), 18, Color(0.85, 0.2, 0.15))
		draw_arc(Vector2(shake, 0), 18, 0, TAU, 18, OUT, 2.0)
		draw_circle(Vector2(shake, 0), 5, Color(0.95, 0.85, 0.3))
		for i in 3:
			var r := fmod(t * 90.0 + i * 25.0, 75.0) + 22.0
			var a := clampf(1.0 - r / 97.0, 0.0, 1.0)
			draw_arc(Vector2.ZERO, r, -PI * 0.85, -PI * 0.15, 12, Color(1, 0.9, 0.5, a), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-60, 46), "RIIIING", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(1, 0.9, 0.5))


## Pantalla final: libreta con 0/10 REPROBADO.
class FailCard extends CanvasLayer:
	var t := 0.0
	var _c: Control

	func _ready() -> void:
		layer = 6
		_c = Control.new()
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.set_anchors_preset(Control.PRESET_FULL_RECT)
		_c.draw.connect(_draw_card)
		add_child(_c)

	func _process(delta: float) -> void:
		t += delta
		_c.queue_redraw()
		if t > 2.6:
			queue_free()

	func _draw_card() -> void:
		var vs := _c.get_viewport_rect().size
		var a := clampf(t / 0.2, 0.0, 1.0) * clampf((2.6 - t) / 0.3, 0.0, 1.0)
		var r := Rect2(vs * 0.5 - Vector2(190, 90), Vector2(380, 180))
		_c.draw_rect(r, Color(0.96, 0.94, 0.86, a))
		_c.draw_rect(r, Color(0.2, 0.25, 0.5, a), false, 3.0)
		for i in 6:
			_c.draw_line(Vector2(r.position.x + 10, r.position.y + 40 + i * 22), Vector2(r.end.x - 10, r.position.y + 40 + i * 22), Color(0.5, 0.65, 0.9, 0.5 * a), 1.0)
		var f := ThemeDB.fallback_font
		_c.draw_string(f, r.position + Vector2(0, 32), "SYNTAX ERROR · Nota final", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(0.15, 0.15, 0.3, a))
		var pop := 1.0 + 0.4 * maxf(0.0, 0.3 - t) / 0.3
		_c.draw_set_transform(vs * 0.5 + Vector2(0, 30), -0.12, Vector2(pop, pop))
		_c.draw_string(f, Vector2(-180, 0), "0/10", HORIZONTAL_ALIGNMENT_CENTER, 360, 48, Color(0.85, 0.1, 0.1, a))
		_c.draw_string(f, Vector2(-180, 40), "REPROBADO", HORIZONTAL_ALIGNMENT_CENTER, 360, 28, Color(0.85, 0.1, 0.1, a))
		_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
