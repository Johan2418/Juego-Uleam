extends RefCounted
## Efectos del "grito" de presentación de cada boss (solo visuales, no hacen daño).
## Cada boss cierra su intro con una firma propia en vez de la pose común de brazos arriba:
##   juez   → mazazo único + sello 403 en el suelo + onda dorada
##   syntax → raya la pizarra: chirrido de tiza (rayas en zigzag) y la pantalla tiembla de lado
##   stack  → tres martillazos apilan bloques sobre su cabeza (PUSH) y el cuarto los desborda
##   tex    → brochazo de textura rota que cruza toda la pantalla
##   kp     → reverencia con cartel de APLAUSOS y acople del micrófono
##   bsod   → carga las paletas: arco eléctrico entre los brazos y "CLEAR"
##   deadbeef → el cráneo vomita bytes hexadecimales
##   div0   → se quita el sombrero y llueven monedas
## Sin class_name: cargar con preload("res://scripts/combat/boss_roar.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")


## Temblor solo de lado (chirrido de tiza).
static func shake_x(player: Node, strength: float, time: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := cam.create_tween()
	var steps := maxi(1, int(time / 0.025))
	for i in steps:
		var s := strength * (1.0 - float(i) / steps) * (1.0 if i % 2 == 0 else -1.0)
		tw.tween_property(cam, "offset", Vector2(s, 0), 0.025)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.03)


static func spawn(parent: Node, n: Node, at: Vector2) -> Node:
	parent.add_child(n)
	(n as Node2D).global_position = at
	return n


## Ondas que salen de un punto (sonido, impacto). jagged = chirrido en zigzag.
class Waves extends Node2D:
	var col := Color(1, 0.85, 0.4)
	var count := 4
	var gap := 0.12
	var speed := 520.0
	var max_r := 360.0
	var flat := 0.55          ## aplastado (perspectiva)
	var jagged := false
	var arc_from := 0.0
	var arc_to := TAU
	var width := 6.0
	var t := 0.0

	func _ready() -> void:
		z_index = 30

	func _process(delta: float) -> void:
		t += delta
		if t > count * gap + max_r / speed + 0.1:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for i in count:
			var r := (t - i * gap) * speed
			if r <= 4.0 or r > max_r:
				continue
			var a := clampf(1.0 - r / max_r, 0.0, 1.0)
			var pts := PackedVector2Array()
			var steps := 48
			for k in steps + 1:
				var ang := lerpf(arc_from, arc_to, float(k) / steps)
				var rr := r + ((7.0 if k % 2 == 0 else -7.0) if jagged else 0.0)
				pts.append(Vector2(cos(ang) * rr, sin(ang) * rr * flat))
			draw_polyline(pts, Color(0, 0, 0, 0.45 * a), width + 4.0)
			draw_polyline(pts, Color(col, a), width)


## Rayas de tiza que chirrían desde un punto (Syntax).
class Screech extends Node2D:
	var t := 0.0
	var life := 1.1
	var rays: Array = []

	func _ready() -> void:
		z_index = 31
		for i in 14:
			rays.append([randf() * TAU, randf_range(60, 150), randf_range(0.0, 0.5)])

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for r in rays:
			var k := clampf((t - float(r[2])) / 0.25, 0.0, 1.0)
			if k <= 0.0:
				continue
			var a := clampf((life - t) / 0.3, 0.0, 1.0)
			var dirv := Vector2.from_angle(float(r[0]))
			var side := dirv.orthogonal()
			var pts := PackedVector2Array()
			var len := float(r[1]) * k
			for s in 7:
				var d := 30.0 + len * s / 6.0
				pts.append(dirv * d + side * (5.0 if s % 2 == 0 else -5.0))
			draw_polyline(pts, Color(0.1, 0.1, 0.1, 0.5 * a), 5.0)
			draw_polyline(pts, Color(1, 1, 0.92, a), 2.5)


## Bloques apilándose sobre la cabeza (Stack). push() agrega uno; overflow() los tira.
class Blocks extends Node2D:
	var stack: Array = []   # [y, rot, color, vel_x, vel_y, spin, y_destino, x]
	var falling := false
	var t := 0.0
	const W := 46.0
	const H := 26.0
	const COLS := [Color(0.95, 0.75, 0.2), Color(0.3, 0.75, 0.95), Color(0.95, 0.4, 0.3), Color(0.55, 0.9, 0.45), Color(0.8, 0.55, 0.95)]

	func _ready() -> void:
		z_index = 32

	func push() -> void:
		var target := -H * stack.size()
		stack.append([target - 140.0, randf_range(-0.08, 0.08), COLS[stack.size() % COLS.size()], 0.0, 0.0, 0.0, target, 0.0])

	func overflow() -> void:
		falling = true
		for i in stack.size():
			var b: Array = stack[i]
			b[3] = randf_range(-260, 260)
			b[4] = randf_range(-420, -220) - i * 40.0
			b[5] = randf_range(-8, 8)

	func _process(delta: float) -> void:
		t += delta
		for b in stack:
			if falling:
				b[3] = float(b[3]) * 0.995
				b[4] = float(b[4]) + 1100.0 * delta
				b[0] = float(b[0]) + float(b[4]) * delta
				b[1] = float(b[1]) + float(b[5]) * delta
			else:
				b[0] = lerpf(float(b[0]), float(b[6]), minf(1.0, delta * 18.0))
		if falling:
			for b in stack:
				b[7] = float(b[7]) + float(b[3]) * delta
			if t > 0.0 and _all_gone():
				queue_free()
		queue_redraw()

	func _all_gone() -> bool:
		for b in stack:
			if float(b[0]) < 500.0:
				return false
		return true

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		for b in stack:
			draw_set_transform(Vector2(float(b[7]), float(b[0])), float(b[1]), Vector2.ONE)
			var r := Rect2(-W * 0.5, -H, W, H)
			draw_rect(r.grow(2), Color(0.05, 0.05, 0.06))
			draw_rect(r, b[2])
			draw_rect(Rect2(r.position, Vector2(W, 5)), Color(1, 1, 1, 0.35))
			draw_string(f, Vector2(-W * 0.5, -7), "PUSH", HORIZONTAL_ALIGNMENT_CENTER, W, 11, Color(0.05, 0.05, 0.06))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Brochazo de "textura no encontrada" que cruza la pantalla (Tex).
class Swipe extends CanvasLayer:
	var t := 0.0
	var y := 360.0
	var _c: Control

	func _ready() -> void:
		layer = 7
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_paint)
		add_child(_c)

	func _process(delta: float) -> void:
		t += delta
		if t > 1.6:
			queue_free()
		_c.queue_redraw()

	func _paint() -> void:
		var k := clampf(t / 0.28, 0.0, 1.0)
		var x1 := lerpf(-80.0, 1360.0, 1.0 - pow(1.0 - k, 3.0))
		var a := clampf((1.6 - t) / 0.6, 0.0, 1.0)
		var cell := 18.0
		var x := -80.0
		var i := 0
		while x < x1:
			# borde superior/inferior irregular del brochazo
			var top := y - 70.0 + 10.0 * sin(x * 0.03) + 8.0 * sin(x * 0.11)
			var bot := y + 70.0 + 10.0 * sin(x * 0.027 + 2.0)
			var yy := top
			var j := 0
			while yy < bot:
				var dis := 1.0 if t < 0.9 else clampf(1.0 - (t - 0.9) / 0.7 - fmod(float(i * 7 + j * 13), 10.0) * 0.06, 0.0, 1.0)
				if dis > 0.0:
					var c := Color(1, 0, 1) if (i + j) % 2 == 0 else Color(0.05, 0.0, 0.08)
					_c.draw_rect(Rect2(x, yy, cell, cell), Color(c, a * dis))
				yy += cell
				j += 1
			x += cell
			i += 1
		if t < 0.5:
			_c.draw_rect(Rect2(x1 - 10, y - 80, 20, 160), Color(1, 1, 1, 0.8 * (1.0 - t / 0.5)))


## Cartel que parpadea (APLAUSOS / AL AIRE).
class Sign extends Node2D:
	var text := "APLAUSOS"
	var col := Color(1, 0.3, 0.3)
	var t := 0.0
	var life := 1.6

	func _ready() -> void:
		z_index = 33

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var on := fmod(t, 0.24) < 0.16
		var f := ThemeDB.fallback_font
		var w := 210.0
		var r := Rect2(-w * 0.5, -26, w, 52)
		var a := clampf((life - t) / 0.25, 0.0, 1.0) * clampf(t / 0.1, 0.0, 1.0)
		draw_rect(r.grow(5), Color(0.05, 0.05, 0.06, a))
		draw_rect(r, Color(0.2, 0.05, 0.05, a) if not on else Color(col, 0.35 * a))
		draw_rect(r, Color(col, a), false, 3.0)
		draw_string(f, Vector2(-w * 0.5, 11), text, HORIZONTAL_ALIGNMENT_CENTER, w, 30, Color(col, a) if on else Color(col, 0.35 * a))


## Arco eléctrico entre dos nodos (BSOD, desfibrilador).
class Arc extends Node2D:
	var a_node: Node2D
	var b_node: Node2D
	var a_off := Vector2.ZERO
	var b_off := Vector2.ZERO
	var t := 0.0
	var life := 1.0

	func _ready() -> void:
		z_index = 34
		top_level = true

	func _process(delta: float) -> void:
		t += delta
		if t > life or not is_instance_valid(a_node) or not is_instance_valid(b_node):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var p1 := a_node.to_global(a_off)
		var p2 := b_node.to_global(b_off)
		for layer_i in 2:
			var pts := PackedVector2Array()
			var n := 10
			for i in n + 1:
				var p := p1.lerp(p2, float(i) / n)
				if i > 0 and i < n:
					p += Vector2(randf_range(-14, 14), randf_range(-14, 14))
				pts.append(p)
			var c := Color(0.55, 0.85, 1.0) if layer_i == 0 else Color(1, 1, 1)
			draw_polyline(pts, Color(c, 0.9), 6.0 if layer_i == 0 else 2.0)
		draw_circle(p1, 7.0 + 3.0 * randf(), Color(0.8, 0.95, 1.0, 0.8))
		draw_circle(p2, 7.0 + 3.0 * randf(), Color(0.8, 0.95, 1.0, 0.8))


## Chorro de bytes que salen de un punto y caen (DEADBEEF).
class Bytes extends Node2D:
	var t := 0.0
	var parts: Array = []   # [pos, vel, text, life]
	var emit_for := 0.9
	var _acc := 0.0

	func _ready() -> void:
		z_index = 30

	func _process(delta: float) -> void:
		t += delta
		if t < emit_for:
			_acc += delta
			while _acc > 0.012:
				_acc -= 0.012
				var ang := randf_range(0.25, PI - 0.25)
				var v := Vector2(cos(ang), sin(ang) * 0.4 + 0.2) * randf_range(220, 520)
				var txt: String = ["DE", "AD", "BE", "EF", "0x", "FF", "00", "%02X" % (randi() % 256)].pick_random()
				parts.append([Vector2.ZERO, v, txt, 0.0])
		for p in parts:
			p[1] = (p[1] as Vector2) + Vector2(0, 700) * delta
			p[0] = (p[0] as Vector2) + (p[1] as Vector2) * delta
			p[3] = float(p[3]) + delta
		parts = parts.filter(func(p: Array) -> bool: return float(p[3]) < 1.1)
		if t > emit_for + 1.2:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		for p in parts:
			var a := clampf(1.1 - float(p[3]), 0.0, 1.0)
			var pos: Vector2 = p[0]
			draw_string(f, pos + Vector2(2, 2), p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0, 0, 0, 0.8 * a))
			draw_string(f, pos, p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.45 + 0.4 * a, 0.3, a))


## Lluvia de monedas que salen de un punto (DIV/0).
class Coins extends Node2D:
	var t := 0.0
	var coins: Array = []   # [pos, vel, spin, ground_y, bounces]
	var count := 26

	func _ready() -> void:
		z_index = 30
		for i in count:
			var ang := randf_range(-PI * 0.9, -PI * 0.1)
			var v := Vector2.from_angle(ang) * randf_range(200, 480)
			coins.append([Vector2.ZERO, v, randf() * TAU, randf_range(150, 260), 0])

	func _process(delta: float) -> void:
		t += delta
		for c in coins:
			var v: Vector2 = c[1]
			v.y += 1300.0 * delta
			var p: Vector2 = (c[0] as Vector2) + v * delta
			if p.y > float(c[3]) and v.y > 0.0:
				p.y = float(c[3])
				v = Vector2(v.x * 0.6, -v.y * 0.4) if int(c[4]) < 2 else Vector2.ZERO
				c[4] = int(c[4]) + 1
			c[0] = p
			c[1] = v
			c[2] = float(c[2]) + delta * 14.0
		if t > 2.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf((2.4 - t) / 0.5, 0.0, 1.0)
		for c in coins:
			var p: Vector2 = c[0]
			var w := absf(cos(float(c[2]))) * 8.0 + 1.5
			draw_set_transform(p, 0.0, Vector2(w / 9.0, 1.0))
			draw_circle(Vector2.ZERO, 10.0, Color(0.35, 0.22, 0.02, a))
			draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.82, 0.2, a))
			draw_circle(Vector2(-2, -2), 3.0, Color(1, 1, 0.8, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
