extends RefCounted
## Peligros y efectos del boss 6 403 FORBIDDEN (Ciencias Sociales, Derecho y Bienestar).
## Usan los sprites boss_judge_* cuando existen; si no, se dibujan por código.
## Sin class_name: cargar con preload("res://scripts/combat/boss_judge_fx.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")

const OUT := Color(0.05, 0.05, 0.06)
const GOLD := Color(0.95, 0.75, 0.25)
const WOOD := Color(0.42, 0.26, 0.15)
const TAPE := Color(1.0, 0.85, 0.15)
const RED := Color(0.9, 0.2, 0.15)


## Prueba que cae al piso tras cada ataque. Se recoge caminando encima.
class Evidence extends Node2D:
	var boss: Node
	var player: Node2D
	var kind := 0          # 0 huella, 1 casquillo, 2 documento, 3 foto
	var life := 6.0
	var t := 0.0
	var _taken := false

	func _init() -> void:
		add_to_group("judge_evidence")

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		t += delta
		if not _taken and player != null and is_instance_valid(player):
			if (player.global_position + Vector2(0, 12)).distance_to(global_position) < 34.0:
				_taken = true
				if boss and is_instance_valid(boss):
					boss.call("evidence_got", self)
				GameFeel.parry_burst(get_parent(), global_position + Vector2(0, -16), 16.0)
				queue_free()
				return
		if t > life:
			modulate.a = clampf(1.0 - (t - life) / 0.3, 0.0, 1.0)
		if t > life + 0.3:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var bob := sin(t * 4.0) * 3.0
		var blink := 1.0 if t < life - 1.5 else (0.4 + 0.6 * absf(sin(t * 12.0)))
		draw_circle(Vector2(0, 0), 20, Color(1, 0.9, 0.4, 0.18 * blink))
		draw_arc(Vector2(0, 0), 20 + 4.0 * sin(t * 6.0), 0, TAU, 20, Color(1, 0.9, 0.4, 0.6 * blink), 2.0)
		var c := Vector2(0, -18 + bob)
		var tx := Spr.tex("boss_judge_evidence_%d" % kind)
		if tx:
			Spr.draw_centered(self, tx, c, false, 1.0, Color(1, 1, 1, blink))
			return
		var a := blink
		match kind:
			0:
				draw_rect(Rect2(c.x - 11, c.y - 13, 22, 26), Color(0.95, 0.95, 0.9, a))
				for i in 4:
					draw_arc(c + Vector2(0, 2), 3.0 + i * 2.5, PI * 1.1, PI * 1.9 + 0.8, 10, Color(0.2, 0.35, 0.8, a), 1.5)
			1:
				draw_rect(Rect2(c.x - 4, c.y - 10, 8, 20), Color(0.9, 0.7, 0.2, a))
				draw_rect(Rect2(c.x - 4, c.y - 10, 8, 4), Color(0.7, 0.5, 0.15, a))
			2:
				draw_rect(Rect2(c.x - 11, c.y - 14, 22, 28), Color(0.95, 0.92, 0.8, a))
				for i in 4:
					draw_line(Vector2(c.x - 7, c.y - 8 + i * 5), Vector2(c.x + 7, c.y - 8 + i * 5), Color(0.4, 0.4, 0.45, a), 1.0)
				draw_circle(c + Vector2(5, 9), 4, Color(0.8, 0.15, 0.15, a))
			_:
				draw_rect(Rect2(c.x - 12, c.y - 12, 24, 24), Color(0.95, 0.95, 0.95, a))
				draw_rect(Rect2(c.x - 9, c.y - 9, 18, 14), Color(0.35, 0.5, 0.6, a))
		draw_rect(Rect2(c.x - 12, c.y - 14, 24, 28), Color(OUT, a), false, 1.5)


## Sello DENEGADO que lanza el juicio. Hay que hacerle parry (¡OBJECIÓN!).
## strict > 0: parry PRECISO (el parry tuvo que empezar hace menos de `strict` segundos).
## wobble: el sello viaja haciendo curvas (fase 3). rally: en el duelo final el juez lo devuelve.
class Seal extends BossFx.Hazard:
	var vel := Vector2.DOWN * 300.0
	var t := 0.0
	var back := false
	var strict := 0.0
	var wobble := 0.0
	var rally := false
	var power := 0          # golpes de peloteo (crece el brillo)
	var _done := false
	var _base := Vector2.ZERO
	var _late := false

	func _ready() -> void:
		z_index = 5
		_base = vel

	## El juez lo devuelve hacia el jugador (duelo final).
	func relaunch(v: Vector2) -> void:
		back = false
		_done = false
		_late = false
		t = 0.0
		vel = v
		_base = v
		power += 1

	func _process(delta: float) -> void:
		t += delta
		var v := vel
		if wobble > 0.0 and not back:
			v = _base + _base.orthogonal().normalized() * sin(t * 9.0) * wobble
		global_position += v * delta
		rotation = sin(t * 10.0) * 0.15
		if back:
			if boss and is_instance_valid(boss) and global_position.distance_to(boss.global_position + Vector2(0, -130)) < 50.0:
				if rally and boss.has_method("rally_back"):
					boss.call("rally_back", self)
					return
				GameFeel.parry_burst(get_parent(), global_position, 30.0)
				queue_free()
				return
		elif not _done and player_ok() and player_body().distance_to(global_position) < 30.0:
			_done = true
			var cc: Variant = player.get("class_controller")
			var parried := false
			if cc != null and is_instance_valid(cc) and bool(cc.get("parrying")) and bool(cc.call("parry_covers", global_position)):
				if strict <= 0.0 or float(cc.call("parry_age")) <= strict:
					parried = true
					cc.call("on_parried", global_position)
				else:
					_late = true
			if parried:
				back = true
				vel = (boss.global_position + Vector2(0, -130) - global_position).normalized() * (520.0 + 60.0 * power)
			else:
				hurt(2, true)
				if _late:
					var n := BossFx.DmgNumber.new()
					n.text = "¡IMPRECISO!"
					n.color = Color(1, 0.5, 0.3)
					get_parent().add_child(n)
					n.global_position = global_position + Vector2(0, -30)
			if is_instance_valid(boss):
				boss.call("rally_result" if rally else "seal_result", parried)
			if not parried:
				queue_free()
				return
		if t > 3.0:
			if not _done and is_instance_valid(boss):
				_done = true
				boss.call("rally_result" if rally else "seal_result", false)
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_judge_evidence_4")
		var col := Color(0.4, 1.0, 0.5) if back else RED
		if power > 0:
			var glow := 0.5 + 0.5 * absf(sin(t * 20.0))
			for k in mini(power, 6):
				draw_circle(Vector2.ZERO, 26.0 + k * 5.0, Color(col, 0.07 * glow))
			for i in 4:
				draw_circle(-vel.normalized() * (12.0 + i * 12.0), 14.0 - i * 3.0, Color(col, 0.18))
		if strict > 0.0 and not back:
			draw_arc(Vector2.ZERO, 30.0, 0, TAU, 24, Color(1, 1, 1, 0.5 + 0.5 * absf(sin(t * 14.0))), 2.0)
		var sc := 1.0 + 0.08 * mini(power, 6)
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO, false, sc, Color(0.6, 1, 0.6) if back else Color.WHITE)
		else:
			draw_circle(Vector2.ZERO, 22, Color(0.95, 0.9, 0.85))
			draw_arc(Vector2.ZERO, 22, 0, TAU, 24, col, 4.0)
			draw_arc(Vector2.ZERO, 16, 0, TAU, 24, col, 1.5)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(-30, 4), "OBJECIÓN" if back else "DENEGADO", HORIZONTAL_ALIGNMENT_CENTER, 60, 9, col)


## 1. Comunicación: foco de cámara EN VIVO que persigue al jugador. Si lo deja quieto, cae un rayo.
class Spotlight extends BossFx.Hazard:
	var life := 5.0
	var lock_need := 1.0
	var t := 0.0
	var lock := 0.0
	var _strike := -1.0
	var _strike_at := Vector2.ZERO
	const R := 64.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if player_ok() and t < life:
			global_position = global_position.lerp(player_feet(), minf(1.0, delta * 2.2))
			var d := player_feet() - global_position
			if Vector2(d.x, d.y * 2.0).length() < R and _strike < 0.0:
				lock += delta
			else:
				lock = maxf(0.0, lock - delta * 0.5)
			if lock >= lock_need and _strike < 0.0:
				_strike = 0.0
				_strike_at = global_position
				lock = 0.0
		if _strike >= 0.0:
			_strike += delta
			if _strike >= 0.4 and _strike - delta < 0.4:
				if player_ok():
					var d2 := player_feet() - _strike_at
					if Vector2(d2.x, d2.y * 2.0).length() < R + 6.0:
						hurt(2)
				GameFeel.dust(get_parent(), _strike_at, 6, Vector2.ZERO, 5.0, Vector2(30, 8))
			if _strike > 0.7:
				_strike = -1.0
		if t > life + 0.7:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf((life - t) / 0.3, 0.0, 1.0)
		ellipse(Vector2.ZERO, Vector2(R, R * 0.5), Color(1, 1, 0.8, 0.22 * a))
		ellipse_line(Vector2.ZERO, Vector2(R, R * 0.5), Color(1, 1, 0.8, 0.6 * a), 2.0)
		# cono de luz desde arriba
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -420), Vector2(12, -420), Vector2(R, 0), Vector2(-R, 0)]), Color(1, 1, 0.85, 0.08 * a))
		if lock > 0.0:
			draw_arc(Vector2(0, -50), 14, -PI * 0.5, -PI * 0.5 + TAU * lock / lock_need, 16, Color(1, 0.3, 0.2, a), 4.0)
			draw_string(ThemeDB.fallback_font, Vector2(-30, -70), "EN VIVO", HORIZONTAL_ALIGNMENT_CENTER, 60, 11, Color(1, 0.3, 0.2, a))
		if _strike >= 0.0:
			var p := _strike_at - global_position
			if _strike < 0.4:
				ellipse_line(p, Vector2(R, R * 0.5) * (1.0 - _strike / 0.4 * 0.5), Color(1, 0.3, 0.2, 0.9), 3.0)
			else:
				var pts := PackedVector2Array()
				for i in 9:
					pts.append(p + Vector2(randf_range(-10, 10) if i > 0 and i < 8 else 0.0, -420.0 + 420.0 * i / 8.0))
				draw_polyline(pts, Color(0.8, 0.9, 1.0), 6.0)
				draw_polyline(pts, Color.WHITE, 2.0)


## 2. Ciencias Políticas: la arena se parte en 4 territorios; 3 reciben sanciones. El de la bandera blanca es seguro.
class Borders extends BossFx.Hazard:
	var area := Rect2(-500, -310, 1000, 620)
	var safe := 0
	var warn := 1.3
	var t := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = -1

	func _quad(i: int) -> Rect2:
		var c := area.get_center()
		var h := area.size * 0.5
		var x := area.position.x if i % 2 == 0 else c.x
		var y := area.position.y if i < 2 else c.y
		return Rect2(x, y, h.x, h.y)

	func _process(delta: float) -> void:
		t += delta
		if not _hit and t >= warn and player_ok():
			_hit = true
			var f := player_feet()
			for i in 4:
				if i != safe and _quad(i).has_point(f):
					hurt(2)
			for i in 4:
				if i != safe:
					GameFeel.dust(get_parent(), _quad(i).get_center(), 8, Vector2.ZERO, 6.0, Vector2(120, 30))
		if t > warn + 0.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var o := -global_position
		var blink := 0.5 + 0.5 * absf(sin(t * 12.0))
		var c := area.get_center() + o
		draw_line(Vector2(c.x, area.position.y + o.y), Vector2(c.x, area.end.y + o.y), Color(1, 1, 1, 0.7), 3.0)
		draw_line(Vector2(area.position.x + o.x, c.y), Vector2(area.end.x + o.x, c.y), Color(1, 1, 1, 0.7), 3.0)
		for i in 4:
			var r := _quad(i)
			r.position += o
			if i == safe:
				draw_rect(r, Color(1, 1, 1, 0.12))
				var fp := r.get_center()
				var flag := Spr.tex("boss_judge_projectiles_2")
				if flag:
					Spr.draw_feet(self, flag, fp, false, 1.6)
					continue
				draw_line(fp, fp + Vector2(0, -60), Color(0.4, 0.3, 0.2), 3.0)
				draw_rect(Rect2(fp.x, fp.y - 60, 34, 22), Color(0.98, 0.98, 0.98))
				draw_rect(Rect2(fp.x, fp.y - 60, 34, 22), OUT, false, 1.5)
				continue
			if t < warn:
				draw_rect(r, Color(1, 0.15, 0.1, 0.12 + 0.12 * blink * t / warn))
				# misiles cayendo al final del aviso
				if t > warn - 0.35:
					var k := (t - (warn - 0.35)) / 0.35
					for j in 3:
						var mp := r.position + Vector2(r.size.x * (0.25 + 0.25 * j), r.size.y * 0.5)
						var tx := Spr.tex("boss_judge_projectiles_1")
						var at := mp + Vector2(0, lerpf(-400.0, 0.0, k))
						if tx:
							Spr.draw_centered(self, tx, at)
						else:
							draw_rect(Rect2(at.x - 5, at.y - 24, 10, 24), Color(0.5, 0.52, 0.55))
							draw_colored_polygon(PackedVector2Array([at + Vector2(-5, 0), at + Vector2(5, 0), at + Vector2(0, 8)]), RED)
			else:
				draw_rect(r, Color(1, 0.5, 0.2, 0.3 * clampf(1.0 - (t - warn) / 0.5, 0.0, 1.0)))


## 3. Criminología: un lado de la cinta de escena del crimen. Quema al tocarla; un golpe la rompe.
class Tape extends Node2D:
	var a := Vector2.ZERO      # extremos en global
	var b := Vector2.ZERO
	var box: Node
	var broken := false
	var t := 0.0

	func _ready() -> void:
		z_index = 2
		add_to_group("enemies")
		add_to_group("boss_hazard")
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := RectangleShape2D.new()
		var d := b - a
		hr.size = Vector2(maxf(absf(d.x), 26.0), maxf(absf(d.y), 26.0))
		hs.shape = hr
		hs.position = (a + b) * 0.5 - global_position + Vector2(0, -16)
		hurt.add_child(hs)
		add_child(hurt)

	func take_hit(_amount: int, _from: Vector2) -> void:
		if broken:
			return
		broken = true
		remove_from_group("enemies")
		GameFeel.dust(get_parent(), (a + b) * 0.5, 4, Vector2.ZERO, 3.0, Vector2(20, 5))

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if broken:
			return
		var o := -global_position
		var la := a + o + Vector2(0, -16)
		var lb := b + o + Vector2(0, -16)
		draw_line(la, lb, OUT, 8.0)
		draw_line(la, lb, TAPE, 6.0)
		var n := int(la.distance_to(lb) / 22.0)
		for i in n:
			var p := la.lerp(lb, (i + 0.5) / n)
			draw_rect(Rect2(p.x - 4, p.y - 2, 8, 4), Color(0.1, 0.1, 0.1))
		for p in [la, lb]:
			draw_rect(Rect2(p.x - 3, p.y - 4, 6, 24), Color(0.35, 0.35, 0.38))


## Caja de cinta alrededor del jugador + barrido del láser forense.
class TapeBox extends BossFx.Hazard:
	var half := 120.0
	var warn := 0.6
	var scan_at := 1.1
	var scan_time := 1.2
	var life := 3.0
	var t := 0.0
	var tapes: Array[Tape] = []
	var _cd := 0.0
	var _scan_hit := false

	func _ready() -> void:
		z_index = 1

	func _make() -> void:
		var c := global_position
		var pts := [c + Vector2(-half, -half * 0.7), c + Vector2(half, -half * 0.7), c + Vector2(half, half * 0.7), c + Vector2(-half, half * 0.7)]
		for i in 4:
			var tp := Tape.new()
			tp.a = pts[i]
			tp.b = pts[(i + 1) % 4]
			tp.box = self
			get_parent().add_child(tp)
			tp.global_position = c
			tapes.append(tp)

	func _process(delta: float) -> void:
		t += delta
		_cd -= delta
		if t >= warn and tapes.is_empty():
			_make()
		if player_ok() and not tapes.is_empty() and _cd <= 0.0:
			var f := player_feet()
			for tp in tapes:
				if is_instance_valid(tp) and not tp.broken:
					if f.distance_to(Geometry2D.get_closest_point_to_segment(f, tp.a, tp.b)) < 12.0:
						_cd = 0.6
						hurt(1)
						# empuja hacia el centro
						player.global_position += (global_position - f).normalized() * 18.0
						break
		# láser forense: una línea vertical que cruza la caja
		if t >= scan_at and t < scan_at + scan_time and player_ok() and not _scan_hit:
			var x := _scan_x()
			var f2 := player_feet()
			if absf(f2.x - x) < 10.0 and absf(f2.y - global_position.y) < half * 0.7 + 10.0:
				_scan_hit = true
				hurt(2)
		if t > life:
			for tp in tapes:
				if is_instance_valid(tp):
					tp.queue_free()
			queue_free()
		queue_redraw()

	func _scan_x() -> float:
		var k := clampf((t - scan_at) / scan_time, 0.0, 1.0)
		return global_position.x - half + 2.0 * half * k

	func _draw() -> void:
		if t < warn:
			var blink := 0.5 + 0.5 * absf(sin(t * 14.0))
			draw_rect(Rect2(-half, -half * 0.7, half * 2.0, half * 1.4), Color(1, 0.85, 0.2, 0.5 * blink), false, 2.0)
			return
		draw_rect(Rect2(-half, -half * 0.7, half * 2.0, half * 1.4), Color(1, 0.85, 0.2, 0.06))
		if t >= scan_at - 0.4 and t < scan_at + scan_time:
			var x := _scan_x() - global_position.x
			var on := t >= scan_at
			var col := Color(0.3, 1.0, 0.4, 0.9) if on else Color(0.3, 1.0, 0.4, 0.3)
			draw_line(Vector2(x, -half * 0.7 - 20), Vector2(x, half * 0.7), col, 4.0 if on else 1.5)
			var sc := Spr.tex("boss_judge_projectiles_5")
			if sc:
				Spr.draw_centered(self, sc, Vector2(x, -half * 0.7 - 30))
			else:
				draw_circle(Vector2(x, -half * 0.7 - 24), 7, Color(0.4, 0.42, 0.45))


## 4. Derecho: libro de leyes gigante que cae con sombra previa.
class Book extends BossFx.Hazard:
	var delay := 0.0
	var warn := 0.85
	var t := 0.0
	var _landed := false
	const R := 40.0

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		t += delta
		var k := t - delay
		if not _landed and k >= warn:
			_landed = true
			GameFeel.dust(get_parent(), global_position, 5, Vector2.ZERO, 4.0, Vector2(34, 7))
			if player_ok():
				var d := player_feet() - global_position
				if Vector2(d.x, d.y * 2.0).length() < R:
					hurt(2)
		if k > warn + 0.6:
			modulate.a = clampf(1.0 - (k - warn - 0.6) / 0.3, 0.0, 1.0)
		if k > warn + 0.9:
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
		var h := lerpf(360.0, 0.0, p * p) if not _landed else 0.0
		var c := Vector2(0, -h - 18)
		var tx := Spr.tex("boss_judge_projectiles_0")
		if tx:
			Spr.draw_centered(self, tx, c)
			return
		draw_rect(Rect2(c.x - 30, c.y - 18, 60, 36), Color(0.6, 0.12, 0.12))
		draw_rect(Rect2(c.x - 30, c.y + 10, 60, 8), Color(0.95, 0.92, 0.82))
		draw_rect(Rect2(c.x - 22, c.y - 10, 44, 6), GOLD)
		draw_rect(Rect2(c.x - 30, c.y - 18, 60, 36), OUT, false, 2.0)


## 5. Economía: oferta y demanda. Dos líneas láser en X que giran alrededor del punto de equilibrio,
## que persigue al jugador y al final explota.
class Market extends BossFx.Hazard:
	var life := 3.6
	var warn := 0.7
	var spin := 0.7
	var t := 0.0
	var ang := 0.0
	var _cd := 0.0
	var _boom := false
	const LEN := 900.0
	const BOOM_R := 90.0

	func _ready() -> void:
		z_index = 3
		ang = randf() * PI

	func _line(i: int) -> Array:
		var a := ang + (0.0 if i == 0 else PI * 0.5) + (0.0 if i == 0 else -2.0 * ang)
		var d := Vector2.from_angle(a)
		return [global_position - d * LEN, global_position + d * LEN]

	func _process(delta: float) -> void:
		t += delta
		_cd -= delta
		if t < life:
			ang += spin * delta
			if player_ok():
				global_position = global_position.move_toward(player_feet(), 55.0 * delta)
			if t >= warn and player_ok() and _cd <= 0.0:
				var f := player_feet()
				for i in 2:
					var l: Array = _line(i)
					var la: Vector2 = l[0]
					var lb: Vector2 = l[1]
					if f.distance_to(Geometry2D.get_closest_point_to_segment(f, la, lb)) < 10.0:
						_cd = 0.7
						hurt(1)
						break
		elif not _boom:
			_boom = true
			if player_ok():
				var d := player_feet() - global_position
				if Vector2(d.x, d.y * 2.0).length() < BOOM_R:
					hurt(2)
			GameFeel.dust(get_parent(), global_position, 10, Vector2.ZERO, 6.0, Vector2(BOOM_R, 20))
		if t > life + 0.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t < life:
			for i in 2:
				var l: Array = _line(i)
				var la: Vector2 = l[0] - global_position
				var lb: Vector2 = l[1] - global_position
				var col := Color(0.3, 0.6, 1.0) if i == 0 else Color(1.0, 0.4, 0.3)
				if t < warn:
					draw_line(la, lb, Color(col, 0.35), 1.5)
				else:
					draw_line(la, lb, Color(col, 0.35), 8.0)
					draw_line(la, lb, col.lightened(0.5), 2.5)
			var k := clampf(t / life, 0.0, 1.0)
			draw_circle(Vector2.ZERO, 10, GOLD)
			draw_arc(Vector2.ZERO, 10, 0, TAU, 14, OUT, 2.0)
			ellipse_line(Vector2.ZERO, Vector2(BOOM_R, BOOM_R * 0.5) * k, Color(1, 0.3, 0.2, 0.3 + 0.5 * k), 2.0)
		else:
			var e := clampf((t - life) / 0.4, 0.0, 1.0)
			ellipse(Vector2.ZERO, Vector2(BOOM_R, BOOM_R * 0.5) * (0.5 + e), Color(1, 0.75, 0.3, 0.6 * (1.0 - e)))


## 6. Trabajo Social: carpeta con patas. Agarra al jugador (lo frena) y al romperla suelta una prueba.
class Folder extends CharacterBody2D:
	var player: Node2D
	var boss: Node
	var hp := 2
	var t := 0.0
	var _dead := false
	var _hit_t := 0.0
	var _grab_cd := 0.0
	var _slow_t := 0.0

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
		hs.position = Vector2(0, -22)
		hurt.add_child(hs)
		add_child(hurt)
		GameFeel.add_shadow(self, Vector2(0, 0), Vector2(20, 6))

	func take_hit(amount: int, _from_pos: Vector2) -> void:
		if _dead:
			return
		hp -= amount
		_hit_t = 0.25
		GameFeel.flash(self, 0.08, Color(1, 1, 1))
		if hp <= 0:
			die(true)

	func die(drop: bool = false) -> void:
		if _dead:
			return
		_dead = true
		_release()
		remove_from_group("enemies")
		remove_from_group("boss_minion")
		if drop and boss and is_instance_valid(boss):
			boss.call("drop_evidence", global_position)
		for i in 4:
			var d := BossFx.Debris.new()
			d.kind = 2
			d.prefix = "boss_judge_debris_"
			d.vel = Vector2(randf_range(-160, 160), randf_range(-300, -150))
			get_parent().add_child(d)
			d.global_position = global_position + Vector2(0, -20)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(queue_free)

	func _release() -> void:
		if _slow_t > 0.0 and player and is_instance_valid(player) and float(player.get("speed_mult")) > 0.0:
			player.set("speed_mult", 1.0)
		_slow_t = 0.0

	func pull_toward(dest: Vector2) -> void:
		create_tween().tween_property(self, "global_position", dest, 0.18)

	func _physics_process(delta: float) -> void:
		t += delta
		_hit_t -= delta
		_grab_cd -= delta
		queue_redraw()
		if _dead or player == null or not is_instance_valid(player):
			return
		if _slow_t > 0.0:
			_slow_t -= delta
			if _slow_t <= 0.0:
				_release()
		var to := player.global_position - global_position
		if to.length() > 30.0:
			velocity = to.normalized() * 95.0
			move_and_slide()
		if _grab_cd <= 0.0 and to.length() < 36.0:
			_grab_cd = 2.0
			player.call("take_hit", 1, global_position)
			if float(player.get("speed_mult")) > 0.0:
				player.set("speed_mult", 0.5)
				_slow_t = 1.5

	func _draw() -> void:
		var idx := 0
		if _dead:
			idx = 7
		elif _hit_t > 0.0:
			idx = 5
		elif _slow_t > 0.0:
			idx = 4
		else:
			idx = int(t * 6.0) % 4
		var tx := Spr.tex("boss_judge_folder_%d" % idx)
		if tx:
			Spr.draw_feet(self, tx, Vector2.ZERO)
			return
		var step := sin(t * 12.0) * 3.0
		draw_line(Vector2(-7, -8), Vector2(-9 + step, 0), OUT, 3.0)
		draw_line(Vector2(7, -8), Vector2(9 - step, 0), OUT, 3.0)
		draw_rect(Rect2(-18, -42, 36, 34), Color(0.75, 0.58, 0.32))
		draw_rect(Rect2(-18, -46, 16, 6), Color(0.75, 0.58, 0.32))
		draw_rect(Rect2(-14, -40, 28, 6), Color(0.97, 0.95, 0.88))
		draw_rect(Rect2(-18, -42, 36, 34), OUT, false, 2.0)
		draw_circle(Vector2(-6, -26), 4, Color.WHITE)
		draw_circle(Vector2(6, -26), 4, Color.WHITE)
		draw_circle(Vector2(-6, -26), 2, OUT)
		draw_circle(Vector2(6, -26), 2, OUT)
		if _slow_t > 0.0:
			draw_line(Vector2(-18, -28), Vector2(-30, -22), OUT, 3.0)
			draw_line(Vector2(18, -28), Vector2(30, -22), OUT, 3.0)


## Cartel CULPABLE / CASO CERRADO.
class Verdict extends Node2D:
	var text := "CULPABLE"
	var col := Color(0.4, 1.0, 0.5)
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
		# que no se salga por arriba de la pantalla cuando el juez está al fondo de la sala
		var oy := -260.0
		var sy := get_global_transform_with_canvas().origin.y
		if sy + oy < 120.0:
			oy = 120.0 - sy
		draw_set_transform(Vector2(0, oy), -0.08, Vector2(s, s))
		var f := ThemeDB.fallback_font
		draw_rect(Rect2(-150, -30, 300, 60), Color(0.1, 0.08, 0.06, 0.88))
		draw_rect(Rect2(-150, -30, 300, 60), col, false, 4.0)
		draw_string(f, Vector2(-150, 12), text, HORIZONTAL_ALIGNMENT_CENTER, 300, 32, col)
