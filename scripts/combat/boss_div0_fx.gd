extends RefCounted
## Peligros y efectos del boss 3 #DIV/0! (Ciencias Administrativas, Contables y Comercio).
## Usan los sprites boss_div0_* cuando existen; si no, se dibujan por código.
## Sin class_name: cargar con preload("res://scripts/combat/boss_div0_fx.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")

const OUT := Color(0.05, 0.05, 0.06)
const GOLD := Color(0.98, 0.78, 0.2)
const MONEY := Color(0.35, 0.72, 0.4)


## Organigrama (Administración): caen cajas de jefes y se unen con láseres. Romper una caja corta sus láseres.
class OrgChart extends BossFx.Hazard:
	var spots: Array[Vector2] = []   # posiciones globales de las cajas, en orden de la cadena
	var warn := 0.8
	var laser_at := 1.5
	var life := 3.4
	var t := 0.0
	var boxes: Array[Node2D] = []
	var _hit_cd := 0.0
	var _landed := false

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		t += delta
		_hit_cd -= delta
		if not _landed and t >= warn:
			_landed = true
			for p in spots:
				var b := OrgBox.new()
				b.chart = self
				get_parent().add_child(b)
				b.global_position = p
				boxes.append(b)
				GameFeel.dust(get_parent(), p, 4, Vector2.ZERO, 4.0, Vector2(26, 6))
				for v in victims():
					_victim = v
					if player_feet().distance_to(p) < 34.0:
						hurt(1)
				_victim = null
		if t >= laser_at and t < life:
			for v in victims():
				_victim = v
				for i in boxes.size() - 1:
					if _alive(i) and _alive(i + 1):
						var a: Vector2 = boxes[i].global_position + Vector2(0, -16)
						var b: Vector2 = boxes[i + 1].global_position + Vector2(0, -16)
						var q := Geometry2D.get_closest_point_to_segment(player_body() + Vector2(0, 20), a, b)
						if q.distance_to(player_body() + Vector2(0, 20)) < 14.0:
							if cd_ok("laser", 0.8):
								hurt(1)
							break
			_victim = null
		if t >= life:
			for b in boxes:
				if is_instance_valid(b):
					b.queue_free()
			queue_free()
		queue_redraw()

	func _alive(i: int) -> bool:
		return is_instance_valid(boxes[i]) and not boxes[i].get("broken")

	func _draw() -> void:
		if not _landed:
			var k := clampf(t / warn, 0.0, 1.0)
			for p in spots:
				ellipse(p - global_position, Vector2(30, 12) * (0.4 + 0.6 * k), Color(0, 0, 0, 0.3))
			return
		for i in boxes.size() - 1:
			if not (_alive(i) and _alive(i + 1)):
				continue
			var a: Vector2 = boxes[i].global_position - global_position + Vector2(0, -16)
			var b: Vector2 = boxes[i + 1].global_position - global_position + Vector2(0, -16)
			if t < laser_at:
				# aviso: línea fina punteada
				var n := int(a.distance_to(b) / 14.0)
				for j in n:
					if j % 2 == 0:
						draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), Color(1, 0.3, 0.3, 0.6), 2.0)
			else:
				var w := 5.0 + 2.0 * sin(t * 30.0)
				draw_line(a, b, Color(1, 0.2, 0.2, 0.5), w + 6.0)
				draw_line(a, b, Color(1, 0.9, 0.9), w * 0.5)


## Caja de jefe del organigrama: se rompe con un golpe.
class OrgBox extends Node2D:
	var chart: Node
	var broken := false
	var t := 0.0

	func _ready() -> void:
		add_to_group("enemies")
		add_to_group("boss_hazard")
		z_index = 2
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := RectangleShape2D.new()
		hr.size = Vector2(36, 36)
		hs.shape = hr
		hs.position = Vector2(0, -16)
		hurt.add_child(hs)
		add_child(hurt)

	func take_hit(_amount: int, _from: Vector2) -> void:
		if broken:
			return
		broken = true
		remove_from_group("enemies")
		GameFeel.dust(get_parent(), global_position + Vector2(0, -16), 8, Vector2.ZERO, 5.0)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_div0_projectiles_3")
		if tx:
			Spr.draw_feet(self, tx, Vector2.ZERO, false, 1.1)
			return
		draw_rect(Rect2(-18, -34, 36, 34), Color(0.55, 0.57, 0.62))
		draw_rect(Rect2(-18, -34, 36, 8), Color(0.42, 0.44, 0.5))
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -26), Vector2(4, -26), Vector2(6, -8), Vector2(0, -4), Vector2(-6, -8)]), Color(0.85, 0.15, 0.15))
		draw_rect(Rect2(-18, -34, 36, 34), OUT, false, 2.0)


## Auditoría: el haz de la lupa barre la arena. Si te encuentra te marca (OBSERVACIÓN).
class AuditLens extends BossFx.Hazard:
	var path_a := Vector2.ZERO
	var path_b := Vector2.ZERO
	var time := 2.6
	var radius := 64.0
	var t := 0.0
	var _seen := 0.0
	var _caught := false

	func _ready() -> void:
		z_index = -1
		global_position = path_a

	func _process(delta: float) -> void:
		t += delta
		var k := clampf(t / time, 0.0, 1.0)
		var wob := Vector2(0, sin(k * TAU * 2.0) * 110.0)
		global_position = path_a.lerp(path_b, k) + wob
		if not _caught:
			var spotted: Node2D = null
			for v in victims():
				_victim = v
				var d := player_feet() - global_position
				if Vector2(d.x, d.y * 1.6).length() < radius:
					spotted = v
			_victim = null
			if spotted != null:
				_seen += delta
				if _seen > 0.25:
					_caught = true
					_victim = spotted
					hurt(1)
					_victim = null
					if is_instance_valid(boss):
						boss.set("player", spotted)   # el foco marca al que encontró
						boss.call("mark_player")
			else:
				_seen = maxf(0.0, _seen - delta)
		if t >= time:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 0.22 + 0.1 * sin(t * 12.0)
		ellipse(Vector2.ZERO, Vector2(radius, radius / 1.6), Color(1, 0.95, 0.6, a))
		ellipse_line(Vector2.ZERO, Vector2(radius, radius / 1.6), Color(1, 0.85, 0.3, 0.9), 3.0)
		if _seen > 0.0 and not _caught:
			ellipse_line(Vector2.ZERO, Vector2(radius, radius / 1.6) * (1.0 - _seen / 0.25 * 0.5), Color(1, 0.3, 0.2, 0.9), 3.0)


## Marca "OBSERVACIÓN" sobre el jugador.
class Mark extends Node2D:
	var target: Node2D
	var life := 3.0
	var t := 0.0

	func _ready() -> void:
		z_index = 30

	func _process(delta: float) -> void:
		t += delta
		if t > life or not is_instance_valid(target):
			queue_free()
			return
		global_position = target.global_position + Vector2(0, -78)
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var s := "OBSERVACIÓN"
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var blink := 0.6 + 0.4 * absf(sin(t * 8.0))
		draw_rect(Rect2(-w * 0.5 - 5, -12, w + 10, 17), Color(0.6, 0.05, 0.05, 0.85 * blink))
		draw_string(f, Vector2(-w * 0.5, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.9))


## Contenedor de barco (Comercio Exterior): pasa por un carril a toda velocidad.
class ShipContainer extends BossFx.Hazard:
	var color := 0   # 0 rojo, 1 azul, 2 verde, 3 naranja
	var delay := 0.9
	var speed := 720.0
	var min_x := -800.0
	var max_x := 800.0
	var t := 0.0
	var _hit := false
	const COLS := [Color(0.75, 0.2, 0.18), Color(0.2, 0.4, 0.75), Color(0.25, 0.6, 0.3), Color(0.9, 0.5, 0.15)]

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		t += delta
		if t < delay:
			return
		position.x += speed * delta
		for v in victims():
			_victim = v
			var d := player_feet() - global_position
			if absf(d.x) < 86.0 and absf(d.y) < 26.0 and first_hit():
				_hit = true
				hurt(2)
		_victim = null
		if position.x < min_x or position.x > max_x:
			queue_free()
		if fmod(t, 0.1) < delta:
			GameFeel.dust(get_parent(), global_position + Vector2(-signf(speed) * 80.0, 0), 1, Vector2(-signf(speed) * 50.0, 0.0), 3.0)
		queue_redraw()

	func _draw() -> void:
		if t < delay:
			# aviso: el carril parpadea en rojo
			var blink := 0.5 + 0.5 * absf(sin(t * 12.0))
			var lane := Rect2(min_x - position.x, -30, max_x - min_x, 34)
			draw_rect(lane, Color(1, 0.2, 0.15, 0.08 + 0.1 * blink))
			draw_line(lane.position, lane.position + Vector2(lane.size.x, 0), Color(1, 0.3, 0.2, 0.6 * blink), 2.0)
			draw_line(lane.position + Vector2(0, lane.size.y), lane.end, Color(1, 0.3, 0.2, 0.6 * blink), 2.0)
			var ax := signf(speed)
			for k in 6:
				var cx := lane.position.x + lane.size.x * (k + 0.5) / 6.0
				draw_colored_polygon(PackedVector2Array([Vector2(cx + 12 * ax, -13), Vector2(cx - 8 * ax, -23), Vector2(cx - 8 * ax, -3)]), Color(1, 0.35, 0.25, 0.7 * blink))
			return
		var tx := Spr.tex("boss_div0_containers_%d" % color)
		if tx:
			Spr.draw_feet(self, tx, Vector2(0, 6), speed < 0.0, 170.0 / tx.get_width())
			return
		var c: Color = COLS[color]
		draw_rect(Rect2(-85, -50, 170, 52), c)
		for i in 16:
			draw_line(Vector2(-80 + i * 10.6, -46), Vector2(-80 + i * 10.6, -2), c.darkened(0.25), 2.0)
		draw_rect(Rect2(-85, -50, 170, 8), c.lightened(0.15))
		draw_rect(Rect2(-85, -50, 170, 52), OUT, false, 2.5)


## Partida doble (Contabilidad): llueven números en media arena (DEBE o HABER).
class NumberRain extends BossFx.Hazard:
	var rect := Rect2()   # en coordenadas globales
	var label := "DEBE"
	var warn := 0.9
	var active := 0.9
	var t := 0.0
	var _hit := false
	var _digits: Array = []

	func _ready() -> void:
		z_index = 4
		global_position = Vector2.ZERO
		for i in 46:
			_digits.append([Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y - 200, rect.position.y)), str(randi() % 10), randf_range(500, 800)])

	func _process(delta: float) -> void:
		t += delta
		if t > warn:
			for d in _digits:
				d[0].y += d[2] * delta
				if d[0].y > rect.end.y:
					d[0].y = rect.position.y - randf_range(0, 60)
			if t > warn + 0.1:
				for v in victims():
					_victim = v
					if rect.has_point(player_feet()) and first_hit():
						_hit = true
						hurt(1)
				_victim = null
		if t > warn + active:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var blink := 0.5 + 0.5 * absf(sin(t * 10.0))
		var f := ThemeDB.fallback_font
		if t <= warn:
			draw_rect(rect, Color(1, 0.2, 0.15, 0.1 + 0.08 * blink))
			draw_rect(rect, Color(1, 0.3, 0.2, 0.7 * blink), false, 3.0)
			draw_string(f, rect.get_center() + Vector2(-60, 10), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 34, Color(1, 0.35, 0.3, 0.8))
			return
		draw_rect(rect, Color(0.1, 0.4, 0.15, 0.18))
		for d in _digits:
			if rect.has_point(d[0]):
				draw_string(f, d[0], d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.55, 1.0, 0.55, 0.9))


## Sello "DESPEDIDO" (Talento Humano): la sombra sigue al jugador, se fija y el sello cae.
class StampDrop extends BossFx.Hazard:
	var follow := 0.7
	var lock := 0.3
	var t := 0.0
	var _done := false
	const R := 46.0

	func _ready() -> void:
		z_index = 5
		if player_ok():
			global_position = player_feet()

	func _process(delta: float) -> void:
		t += delta
		if t < follow and player_ok():
			global_position = global_position.lerp(player_feet(), minf(1.0, delta * 9.0))
		if not _done and t >= follow + lock:
			_done = true
			if is_instance_valid(boss):
				boss.call("stamp_landed", self)
			var m := InkMark.new()
			get_parent().add_child(m)
			m.global_position = global_position
			GameFeel.dust(get_parent(), global_position, 8, Vector2.ZERO, 6.0, Vector2(40, 10))
		if t > follow + lock + 0.25:
			queue_free()
		queue_redraw()

	func hits_player() -> bool:
		if not player_ok():
			return false
		var d := player_feet() - global_position
		return Vector2(d.x, d.y * 2.0).length() < R

	func _draw() -> void:
		var k := clampf(t / (follow + lock), 0.0, 1.0)
		var locked := t >= follow
		ellipse(Vector2.ZERO, Vector2(R, R * 0.5) * (0.5 + 0.5 * k), Color(0, 0, 0, 0.35))
		ellipse_line(Vector2.ZERO, Vector2(R, R * 0.5), Color(1, 0.2, 0.15, 0.9 if locked else 0.4), 2.0)
		if not _done:
			# el sello bajando desde arriba
			var h := lerpf(260.0, 0.0, clampf((t - follow) / lock, 0.0, 1.0)) if locked else 260.0
			_stamp(Vector2(0, -h))

	func _stamp(at: Vector2) -> void:
		draw_rect(Rect2(at.x - 8, at.y - 70, 16, 40), Color(0.55, 0.35, 0.2))
		draw_circle(at + Vector2(0, -74), 12, Color(0.6, 0.4, 0.22))
		draw_rect(Rect2(at.x - 40, at.y - 32, 80, 22), Color(0.45, 0.3, 0.18))
		draw_rect(Rect2(at.x - 42, at.y - 12, 84, 12), Color(0.55, 0.1, 0.1))
		draw_rect(Rect2(at.x - 42, at.y - 32, 84, 32), OUT, false, 2.0)


## Mancha del sello en el piso.
class InkMark extends Node2D:
	var t := 0.0

	func _ready() -> void:
		z_index = -2

	func _process(delta: float) -> void:
		t += delta
		if t > 2.5:
			modulate.a = clampf(1.0 - (t - 2.5) / 0.5, 0.0, 1.0)
		if t > 3.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_div0_ink")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO, false, 1.6)
		else:
			draw_rect(Rect2(-44, -14, 88, 28), Color(0.6, 0.08, 0.08, 0.6))
		draw_set_transform(Vector2.ZERO, -0.12, Vector2.ONE)
		draw_rect(Rect2(-46, -12, 92, 22), Color(0.8, 0.1, 0.1, 0.9), false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-46, 5), "DESPEDIDO", HORIZONTAL_ALIGNMENT_CENTER, 92, 14, Color(0.85, 0.12, 0.12))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Interés compuesto (Finanzas): moneda que rebota; en cada rebote se divide en dos.
class Coin extends BossFx.Hazard:
	var vel := Vector2(260, 200)
	var arena := Rect2()
	var gen := 0
	var max_gen := 3
	var life := 4.5
	var t := 0.0
	var _hit_cd := 0.0
	const R := 12.0

	func _ready() -> void:
		z_index = 3
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
		GameFeel.parry_burst(get_parent(), global_position, 14.0)
		queue_free()

	func _process(delta: float) -> void:
		t += delta
		_hit_cd -= delta
		global_position += vel * delta
		var p := global_position
		var bounced := false
		if p.x < arena.position.x + R or p.x > arena.end.x - R:
			vel.x = -vel.x
			bounced = true
		if p.y < arena.position.y + R + 20.0 or p.y > arena.end.y - R:
			vel.y = -vel.y
			bounced = true
		global_position = Vector2(clampf(p.x, arena.position.x + R, arena.end.x - R), clampf(p.y, arena.position.y + R + 20.0, arena.end.y - R))
		if bounced and gen < max_gen:
			# interés compuesto: se duplica
			gen += 1
			var c := Coin.new()
			c.boss = boss
			c.player = player
			c.arena = arena
			c.gen = gen
			c.max_gen = max_gen
			c.life = life - t
			c.vel = vel.rotated(randf_range(0.5, 0.9) * (1.0 if randf() < 0.5 else -1.0))
			get_parent().add_child.call_deferred(c)
			c.position = global_position
			vel = vel.rotated(randf_range(-0.3, 0.3))
		for v in victims():
			_victim = v
			if player_body().distance_to(global_position) < R + 14.0 and cd_ok("coin", 1.0):
				hurt(1)
		_victim = null
		if t > life:
			modulate.a = clampf(1.0 - (t - life) / 0.3, 0.0, 1.0)
			if t > life + 0.3:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var spin := absf(cos(t * 9.0))
		var tx := Spr.tex("boss_div0_projectiles_0")
		if tx:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(maxf(0.25, spin), 1.0) * (26.0 / tx.get_width()))
			draw_texture(tx, -tx.get_size() * 0.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(maxf(0.25, spin), 1.0))
		draw_circle(Vector2.ZERO, R, GOLD)
		draw_circle(Vector2.ZERO, R - 4, Color(1, 0.88, 0.4))
		draw_arc(Vector2.ZERO, R, 0, TAU, 18, OUT, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-5, 5), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.5, 0.1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Ventana emergente de publicidad (Marketing): tapa la vista; se cierra golpeándola.
class AdPopup extends Node2D:
	const ADS := ["¡OFERTA!", "GANA $$$", "CLICK AQUÍ", "¡2x1!", "INVIERTE YA", "¡GRATIS!"]
	var life := 5.0
	var t := 0.0
	var ad := ""
	var tint := Color(0.95, 0.3, 0.6)

	func _ready() -> void:
		add_to_group("enemies")
		add_to_group("boss_hazard")
		z_index = 25
		ad = ADS[randi() % ADS.size()]
		tint = [Color(0.95, 0.3, 0.6), Color(0.3, 0.6, 0.95), Color(0.95, 0.7, 0.2), Color(0.4, 0.85, 0.4)][randi() % 4]
		scale = Vector2(0.1, 0.1)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var hurt := Area2D.new()
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var hs := CollisionShape2D.new()
		var hr := RectangleShape2D.new()
		hr.size = Vector2(170, 120)
		hs.shape = hr
		hurt.add_child(hs)
		add_child(hurt)

	func take_hit(_amount: int, _from: Vector2) -> void:
		remove_from_group("enemies")
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(0.05, 0.05), 0.12)
		tw.tween_callback(queue_free)

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(-85, -60, 170, 120)
		draw_rect(r, Color(0.97, 0.97, 0.98))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 18)), Color(0.2, 0.3, 0.6))
		draw_rect(Rect2(r.end.x - 18, r.position.y + 2, 15, 14), Color(0.85, 0.2, 0.2))
		draw_string(ThemeDB.fallback_font, Vector2(r.end.x - 15, r.position.y + 14), "x", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		var f := ThemeDB.fallback_font
		var pop := 1.0 + 0.08 * sin(t * 10.0)
		draw_set_transform(Vector2(0, 4), 0.0, Vector2(pop, pop))
		draw_string(f, Vector2(-80, 0), ad, HORIZONTAL_ALIGNMENT_CENTER, 160, 22, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(-40, 24, 80, 22), tint)
		draw_string(f, Vector2(-40, 40), "COMPRAR", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color.WHITE)
		draw_rect(r, OUT, false, 2.0)


## Onda del megáfono (Marketing): cono que golpea una vez.
class MegaCone extends BossFx.Hazard:
	var dir := Vector2.DOWN
	var reach := 330.0
	var half := 0.42
	var t := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		t += delta
		var r := reach * clampf(t / 0.35, 0.0, 1.0)
		for v in victims():
			_victim = v
			var d := player_feet() - global_position
			var dd := Vector2(d.x, d.y / 0.6)
			if dd.length() < r and absf(dir.angle_to(dd)) < half and first_hit():
				_hit = true
				hurt(2)
		_victim = null
		if t > 0.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := reach * clampf(t / 0.35, 0.0, 1.0)
		var a := clampf(1.0 - t / 0.5, 0.0, 1.0)
		for k in 3:
			var rr := r - k * 26.0
			if rr <= 0.0:
				continue
			var pts := PackedVector2Array()
			for i in 13:
				var v := Vector2.from_angle(dir.angle() - half + half * 2.0 * i / 12.0) * rr
				pts.append(Vector2(v.x, v.y * 0.6))
			draw_polyline(pts, Color(1, 0.4, 0.75, a * (1.0 - k * 0.25)), 6.0 - k)


## Maletín esbirro ("pasante", Talento Humano): salta hacia el jugador y muerde.
class Briefcase extends CharacterBody2D:
	var player: Node2D
	var hp := 2
	var t := 0.0
	var _hop_cd := 0.6
	var _hop_t := 0.0
	var _from := Vector2.ZERO
	var _to := Vector2.ZERO
	var _dead := false
	var _hit_t := 0.0

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
		hr.radius = 18.0
		hs.shape = hr
		hs.position = Vector2(0, -14)
		hurt.add_child(hs)
		add_child(hurt)
		GameFeel.add_shadow(self, Vector2(0, 0), Vector2(22, 7))

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
		for i in 5:
			var d := BossFx.Debris.new()
			d.kind = 5
			d.prefix = "boss_div0_debris_"
			d.vel = Vector2(randf_range(-160, 160), randf_range(-300, -150))
			get_parent().add_child(d)
			d.global_position = global_position + Vector2(0, -14)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)

	func pull_toward(dest: Vector2) -> void:
		create_tween().tween_property(self, "global_position", dest, 0.18)

	func _physics_process(delta: float) -> void:
		t += delta
		_hit_t -= delta
		if _dead:
			queue_redraw()
		if _hop_t <= 0.0:
			for p in CoopBoss.targets(get_tree()):
				if player == null or not is_instance_valid(player) or (p as Node2D).global_position.distance_to(global_position) < player.global_position.distance_to(global_position) - 20.0:
					player = p
		if _dead or player == null or not is_instance_valid(player):
			return
		if _hop_t > 0.0:
			_hop_t -= delta
			global_position = _from.lerp(_to, 1.0 - _hop_t / 0.4)
			if _hop_t <= 0.0 and player.global_position.distance_to(global_position) < 30.0:
				player.call("take_hit", 1, global_position)
		else:
			_hop_cd -= delta
			if _hop_cd <= 0.0:
				_hop_cd = randf_range(0.5, 0.9)
				_hop_t = 0.4
				_from = global_position
				var to := player.global_position - global_position
				_to = global_position + to.limit_length(110.0)
		queue_redraw()

	func _draw() -> void:
		var hop := sin((1.0 - _hop_t / 0.4) * PI) * 18.0 if _hop_t > 0.0 else 0.0
		var biting := _hop_t > 0.0 and _hop_t < 0.15
		var idx := 4 if biting else (2 + int(t * 6.0) % 2 if _hop_t > 0.0 else int(t * 3.0) % 2)
		if _dead:
			idx = 7
		elif _hit_t > 0.0:
			idx = 5
		var tx := Spr.tex("boss_div0_briefcase_%d" % idx)
		if tx:
			Spr.draw_feet(self, tx, Vector2(0, -hop))
			return
		var y := -hop
		draw_line(Vector2(-8, y - 6), Vector2(-10, y), OUT, 3.0)
		draw_line(Vector2(8, y - 6), Vector2(10, y), OUT, 3.0)
		draw_rect(Rect2(-18, y - 30, 36, 24), Color(0.5, 0.3, 0.15))
		draw_rect(Rect2(-6, y - 36, 12, 6), Color(0.35, 0.2, 0.1), false, 2.0)
		draw_rect(Rect2(-18, y - 30, 36, 24), OUT, false, 2.0)
		draw_circle(Vector2(-7, y - 21), 3, Color.WHITE)
		draw_circle(Vector2(7, y - 21), 3, Color.WHITE)
		draw_line(Vector2(-11, y - 26), Vector2(-4, y - 24), OUT, 2.0)
		draw_line(Vector2(11, y - 26), Vector2(4, y - 24), OUT, 2.0)
		if biting:
			draw_rect(Rect2(-12, y - 14, 24, 6), Color(0.6, 0.1, 0.1))


## Lluvia de papel de la cinta de bolsa (intro y muerte).
class PaperRain extends Node2D:
	var area := Rect2()
	var life := 2.5
	var money := false
	var t := 0.0
	var _bits: Array = []

	func _ready() -> void:
		z_index = 20
		for i in 70:
			_bits.append([Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y - 300, area.position.y)), randf_range(120, 260), randf() * TAU])

	func _process(delta: float) -> void:
		t += delta
		for b in _bits:
			b[0].y += b[1] * delta
			b[0].x += sin(t * 3.0 + b[2]) * 30.0 * delta
			b[2] += delta * 4.0
		if t > life:
			modulate.a = clampf(1.0 - (t - life) / 0.6, 0.0, 1.0)
			if t > life + 0.6:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		for b in _bits:
			var p: Vector2 = b[0] - global_position
			draw_set_transform(p, b[2], Vector2(1.0, absf(sin(b[2]))))
			if money:
				draw_rect(Rect2(-9, -5, 18, 10), MONEY)
				draw_rect(Rect2(-9, -5, 18, 10), Color(0.15, 0.4, 0.2), false, 1.0)
			else:
				draw_rect(Rect2(-3, -8, 6, 16), Color(0.95, 0.95, 0.88))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Pantalla de bancarrota al morir: celda de hoja de cálculo con #DIV/0! y "BANCARROTA".
class Bankrupt extends CanvasLayer:
	var t := 0.0
	var _c: Control

	func _ready() -> void:
		layer = 40
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_draw_it)
		add_child(_c)

	func _process(delta: float) -> void:
		t += delta
		_c.queue_redraw()
		if t > 2.6:
			queue_free()

	func _draw_it() -> void:
		var a := clampf(t / 0.2, 0.0, 1.0) * clampf((2.6 - t) / 0.4, 0.0, 1.0)
		var f := ThemeDB.fallback_font
		var box := Rect2(340, 230, 600, 230)
		_c.draw_rect(box, Color(0.97, 0.97, 0.97, 0.95 * a))
		for i in 7:
			_c.draw_line(Vector2(box.position.x + i * 100, box.position.y), Vector2(box.position.x + i * 100, box.end.y), Color(0.75, 0.75, 0.78, a), 1.0)
		for j in 7:
			_c.draw_line(Vector2(box.position.x, box.position.y + j * 38), Vector2(box.end.x, box.position.y + j * 38), Color(0.75, 0.75, 0.78, a), 1.0)
		_c.draw_rect(Rect2(box.position.x, box.position.y, box.size.x, 22), Color(0.15, 0.45, 0.25, a))
		_c.draw_string(f, Vector2(box.position.x + 8, box.position.y + 16), "Balance_Final.xlsx", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a))
		_c.draw_rect(Rect2(box.position.x + 200, box.position.y + 76, 200, 38), Color(1, 0.85, 0.85, a))
		_c.draw_rect(Rect2(box.position.x + 200, box.position.y + 76, 200, 38), Color(0.2, 0.5, 0.25, a), false, 3.0)
		_c.draw_string(f, Vector2(box.position.x + 200, box.position.y + 103), "#DIV/0!", HORIZONTAL_ALIGNMENT_CENTER, 200, 24, Color(0.8, 0.1, 0.1, a))
		var pop := 1.0 + 0.15 * maxf(0.0, 0.6 - t)
		_c.draw_set_transform(Vector2(640, 410), -0.08, Vector2(pop, pop))
		_c.draw_string(f, Vector2(-300, 0), "BANCARROTA", HORIZONTAL_ALIGNMENT_CENTER, 600, 54, Color(0.85, 0.08, 0.08, a * clampf((t - 0.6) / 0.2, 0.0, 1.0)))
		_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
