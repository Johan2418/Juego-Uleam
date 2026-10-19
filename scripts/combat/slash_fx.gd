class_name SlashFx
extends Node2D
## Efecto de tajo blanco (estilo "media luna" con líneas de velocidad) que cubre EXACTAMENTE
## la zona que hace daño. Se crea con el mismo rectángulo que la hitbox del golpe.
## Local: +x = dirección del golpe. El rectángulo va de x=-half_len..half_len, y=-half_w..half_w.

const DURATION_MIN := 0.12

var half_len: float = 20.0
var half_w: float = 14.0
var duration: float = 0.16
## 1 = barre de arriba a abajo, -1 = al revés (se alterna entre golpes del combo).
var sweep: float = 1.0
var heavy: bool = false
var thin: bool = false  # latigazo: trazo recto y fino
var _t: float = 0.0


static func spawn(parent: Node, at: Vector2, dir: Vector2, length: float, width: float,
		time: float, p_sweep: float = 1.0, p_heavy: bool = false, p_thin: bool = false) -> SlashFx:
	var fx := SlashFx.new()
	fx.half_len = length * 0.5
	fx.half_w = width * 0.5
	fx.duration = maxf(time, DURATION_MIN)
	fx.sweep = p_sweep
	fx.heavy = p_heavy
	fx.thin = p_thin
	fx.rotation = dir.angle()
	# Entre el jugador (z 2) y los enemigos (z 0): el arma se ve encima del rastro
	# y el rastro se ve encima del enemigo golpeado.
	fx.z_index = 1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = mat
	parent.add_child(fx)
	fx.global_position = at
	return fx


## Remolino blanco para ultimates en área (giro del guerrero / torbellino de chain).
static func spawn_spin(parent: Node, at: Vector2, radius: float, time: float, cable: bool = false) -> Node2D:
	if parent == null:
		return null
	var fx := SpinFx.new()
	fx.radius = radius
	fx.duration = time
	fx.cable = cable
	parent.add_child(fx)
	fx.global_position = at
	return fx


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = clampf(_t / duration, 0.0, 1.0)
	var alpha: float = 1.0 - k * k
	var grow: float = lerpf(0.75, 1.0, sqrt(k))
	var a: float = half_len * grow
	var b: float = half_w * grow
	if thin:
		_draw_whip(a, b, alpha, k)
	else:
		_draw_crescent(a, b, alpha, k)


func _draw_crescent(a: float, b: float, alpha: float, k: float) -> void:
	# Media luna: arco exterior toca los bordes del rectángulo; el interior es más delgado.
	var n := 20
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var thick: float = 0.55 if heavy else 0.4
	for i in n + 1:
		var t: float = lerpf(-PI * 0.5, PI * 0.5, float(i) / n)
		outer.append(Vector2(-a + 2.0 * a * cos(t), b * sin(t) * sweep))
	for i in range(n, -1, -1):
		var t: float = lerpf(-PI * 0.5, PI * 0.5, float(i) / n)
		inner.append(Vector2(-a + 2.0 * a * (1.0 - thick) * cos(t), b * 0.82 * sin(t) * sweep))
	var poly := outer.duplicate()
	poly.append_array(inner)
	# halo suave + núcleo blanco
	var glow := Color(0.75, 0.9, 1.0, 0.35 * alpha)
	draw_colored_polygon(_scaled(poly, 1.12), glow)
	draw_colored_polygon(poly, Color(1, 1, 1, 0.8 * alpha))
	# borde brillante del filo
	draw_polyline(outer, Color(1, 1, 1, alpha), 2.0, true)
	# líneas de velocidad hacia delante
	var lines: int = 5 if heavy else 3
	for i in lines:
		var y: float = lerpf(-b * 0.6, b * 0.6, (float(i) + 0.5) / lines)
		var x0: float = lerpf(-a * 0.2, a * 0.4, k)
		var x1: float = a * (1.05 + 0.25 * float(i % 2))
		draw_line(Vector2(x0, y), Vector2(x1, y * 0.7), Color(1, 1, 1, 0.7 * alpha), 1.5)


func _draw_whip(a: float, b: float, alpha: float, k: float) -> void:
	# Latigazo: haz recto que recorre todo el alcance, más grueso en la punta.
	var tip := Vector2(a, 0)
	var base := Vector2(-a, 0)
	var w: float = maxf(b * 0.45, 2.0)
	var poly := PackedVector2Array([base + Vector2(0, -1), tip + Vector2(0, -w), tip + Vector2(a * 0.12, 0), tip + Vector2(0, w), base + Vector2(0, 1)])
	draw_colored_polygon(_scaled(poly, 1.3), Color(0.75, 0.9, 1.0, 0.3 * alpha))
	draw_colored_polygon(poly, Color(1, 1, 1, 0.95 * alpha))
	# chasquido en la punta
	var r: float = w * (1.5 + 2.0 * k)
	for i in 6:
		var ang: float = TAU * float(i) / 6.0 + 0.3
		draw_line(tip + Vector2.from_angle(ang) * r * 0.4, tip + Vector2.from_angle(ang) * r, Color(1, 1, 1, alpha), 1.5)


func _scaled(poly: PackedVector2Array, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(p * s)
	return out


## Chispa de impacto sobre el objetivo golpeado.
class HitSpark extends Node2D:
	var t: float = 0.0
	const DURATION := 0.14
	var size: float = 14.0

	func _ready() -> void:
		z_index = 21
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		rotation = randf() * TAU

	func _process(delta: float) -> void:
		t += delta
		if t >= DURATION:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / DURATION
		var c := Color(1, 1, 1, 1.0 - k)
		var r := lerpf(size * 0.4, size, k)
		draw_circle(Vector2.ZERO, size * 0.35 * (1.0 - k), c)
		for i in 8:
			var d := Vector2.from_angle(TAU * i / 8.0)
			var l := r * (1.0 if i % 2 == 0 else 0.6)
			draw_line(d * r * 0.3, d * l, c, 2.0)


## Anillos blancos girando: cubre el radio real del golpe en área.
class SpinFx extends Node2D:
	var radius: float = 90.0
	var duration: float = 0.5
	var cable: bool = false
	var t: float = 0.0

	func _ready() -> void:
		z_index = 1
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _process(delta: float) -> void:
		t += delta
		if t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / duration
		var a := 1.0 - k * k
		var rot := t * (18.0 if cable else 14.0)
		# relleno tenue = radio real de daño
		draw_circle(Vector2.ZERO, radius, Color(0.85, 0.95, 1.0, 0.16 * a))
		var arcs := 3 if cable else 2
		for i in arcs:
			var start := rot + TAU * float(i) / arcs
			var w := (3.0 if cable else 7.0)
			draw_arc(Vector2.ZERO, radius * 0.92, start, start + 1.9, 24, Color(1, 1, 1, 0.9 * a), w, true)
			draw_arc(Vector2.ZERO, radius * 0.6, start + 0.8, start + 2.2, 18, Color(1, 1, 1, 0.55 * a), w * 0.6, true)


## Efecto defensivo del parry: burbuja (mago) o disco de cable girando (chain).
class ParryFx extends Node2D:
	var kind: String = "mago"
	var duration: float = 0.35
	var target: Node2D
	var offset: Vector2 = Vector2.ZERO
	var t: float = 0.0

	func _ready() -> void:
		z_index = 3
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _process(delta: float) -> void:
		t += delta
		if t >= duration or target == null or not is_instance_valid(target):
			queue_free()
			return
		global_position = target.global_position + offset
		queue_redraw()

	func _draw() -> void:
		var k := t / duration
		var a := 1.0 - k * k
		if kind == "mago":
			var r := lerpf(34.0, 48.0, minf(1.0, k * 3.0))
			draw_circle(Vector2.ZERO, r, Color(0.55, 0.8, 1.0, 0.25 * a))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.8, 0.95, 1.0, 0.9 * a), 3.0, true)
			for i in 6:
				var ang := TAU * i / 6.0 + t * 3.0
				draw_line(Vector2.from_angle(ang) * r * 0.55, Vector2.from_angle(ang + 0.5) * r * 0.55, Color(1, 1, 1, 0.5 * a), 1.5)
		else:
			var r2 := 22.0
			var rot := t * 30.0
			draw_circle(Vector2.ZERO, r2, Color(1, 1, 1, 0.12 * a))
			for i in 3:
				var s0 := rot + TAU * i / 3.0
				draw_arc(Vector2.ZERO, r2, s0, s0 + 1.6, 16, Color(1, 1, 1, 0.9 * a), 2.0, true)
