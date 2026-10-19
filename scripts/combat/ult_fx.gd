extends RefCounted
## Se carga con preload desde ClassController (sin class_name: no depende de la caché de clases del editor).
## Efectos procedurales de parry y ultimates (cada clase con su propia forma).
## Todos se dibujan con _draw(); lo que se ve coincide con la zona que protege o daña.

const CABLE_COL := Color(0.08, 0.08, 0.1)
const BEAM_GOLD := Color(1.0, 0.82, 0.35)


static func _add_mat(n: CanvasItem) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	n.material = mat


# --- Parry ------------------------------------------------------------------------

## Barrera mágica SOLO al frente (arco de ±FRONT_DEG grados).
class FrontBarrier extends Node2D:
	var target: Node2D
	var offset: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.RIGHT
	var duration: float = 0.38
	var half_angle: float = deg_to_rad(62.0)
	var radius: float = 40.0
	var t: float = 0.0

	func _ready() -> void:
		z_index = 3
		var _mat := CanvasItemMaterial.new()
		_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = _mat

	func _process(delta: float) -> void:
		t += delta
		if t >= duration or target == null or not is_instance_valid(target):
			queue_free()
			return
		global_position = target.global_position + offset
		rotation = dir.angle()
		queue_redraw()

	func _draw() -> void:
		var k := t / duration
		var a := 1.0 - k * k
		var grow := minf(1.0, k * 5.0)
		var r := radius * lerpf(0.75, 1.0, grow)
		var r_in := r - 11.0
		var pts := PackedVector2Array()
		var n := 20
		for i in n + 1:
			pts.append(Vector2.from_angle(lerpf(-half_angle, half_angle, float(i) / n)) * r)
		for i in n + 1:
			pts.append(Vector2.from_angle(lerpf(half_angle, -half_angle, float(i) / n)) * r_in)
		draw_colored_polygon(pts, Color(0.45, 0.75, 1.0, 0.35 * a))
		draw_arc(Vector2.ZERO, r, -half_angle, half_angle, 24, Color(0.85, 0.97, 1.0, 0.95 * a), 3.0, true)
		draw_arc(Vector2.ZERO, r_in, -half_angle, half_angle, 24, Color(0.6, 0.85, 1.0, 0.6 * a), 1.5, true)
		# runas / destellos que recorren la barrera
		for i in 5:
			var ang := lerpf(-half_angle, half_angle, fposmod(float(i) / 5.0 + t * 1.6, 1.0))
			var p := Vector2.from_angle(ang) * (r - 5.5)
			draw_circle(p, 2.2, Color(1, 1, 1, 0.8 * a))


## Cable girando MUY rápido delante del jugador, como un escudo (disco visto de canto).
class CableShield extends Node2D:
	var target: Node2D
	var offset: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.RIGHT
	var duration: float = 0.38
	var radius: float = 40.0
	var t: float = 0.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		t += delta
		if t >= duration or target == null or not is_instance_valid(target):
			queue_free()
			return
		global_position = target.global_position + offset
		queue_redraw()

	func _draw() -> void:
		var k := t / duration
		var a := 1.0 - k * k * k
		var grow := minf(1.0, k * 6.0)
		var r := radius * lerpf(0.4, 1.0, grow)
		# plano del disco perpendicular a la dirección: aplastado a lo largo de "dir"
		var side := absf(dir.x) > absf(dir.y)
		var sx := 0.42 if side else 1.0
		var sy := 1.0 if side else 0.42
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
		draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 0.18 * a))
		var rot := t * 38.0
		for i in 4:
			var s0 := rot + TAU * i / 4.0
			draw_arc(Vector2.ZERO, r, s0, s0 + 1.3, 18, Color(Color(0.08, 0.08, 0.1), a), 3.0, true)
			draw_arc(Vector2.ZERO, r * 0.97, s0 + 1.3, s0 + 2.2, 12, Color(1, 1, 1, 0.55 * a), 2.0, true)
		for i in 2:
			var s1 := -rot * 0.8 + PI * i
			draw_arc(Vector2.ZERO, r * 0.62, s1, s1 + 2.0, 14, Color(Color(0.08, 0.08, 0.1), 0.85 * a), 2.0, true)
		draw_arc(Vector2.ZERO, r + 1.5, 0.0, TAU, 40, Color(1, 1, 1, 0.35 * a), 1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Ultimate del guerrero: espadazo que libera un haz y explosiones al frente ---------

class BeamFx extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var length: float = 380.0
	var width: float = 84.0
	var charge: float = 0.5
	var fire: float = 0.75
	var t: float = 0.0
	var _booms: Array = []   # [pos_x, pos_y, t0, size]
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		z_index = 1
		var _mat := CanvasItemMaterial.new()
		_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = _mat
		rotation = dir.angle()
		_rng.randomize()

	func _process(delta: float) -> void:
		t += delta
		if t >= charge + fire + 0.35:
			queue_free()
			return
		# explosiones a lo largo del haz mientras está activo
		if t > charge and t < charge + fire and _rng.randf() < 0.55:
			var along := _rng.randf_range(length * 0.15, length)
			_booms.append([along, _rng.randf_range(-width * 0.35, width * 0.35), t, _rng.randf_range(18.0, 34.0)])
		queue_redraw()

	func _draw() -> void:
		if t < charge:
			# carga: luz dorada que se concentra en la punta del arma
			var k := t / charge
			var r := lerpf(6.0, 22.0, k)
			draw_circle(Vector2.ZERO, r * 1.8, Color(Color(1.0, 0.82, 0.35), 0.18 * k))
			draw_circle(Vector2.ZERO, r, Color(1, 0.95, 0.8, 0.7 * k))
			for i in 10:
				var ang := TAU * i / 10.0 + t * 4.0
				var d := lerpf(70.0, 8.0, fposmod(k * 2.0 + i * 0.1, 1.0))
				draw_circle(Vector2.from_angle(ang) * d, 2.0, Color(1, 0.9, 0.5, 0.9))
			return
		var ft := t - charge
		var ext := minf(1.0, ft / 0.12)           # el haz sale disparado
		var fade := 1.0 if ft < fire else maxf(0.0, 1.0 - (ft - fire) / 0.35)
		var L := length * ext
		var pulse := 1.0 + 0.08 * sin(t * 50.0)
		var w := width * pulse * (0.6 + 0.4 * ext) * (0.4 + 0.6 * fade)
		# capas: halo dorado, cuerpo, núcleo blanco
		draw_rect(Rect2(0.0, -w * 0.5, L, w), Color(Color(1.0, 0.82, 0.35), 0.30 * fade))
		draw_rect(Rect2(0.0, -w * 0.33, L, w * 0.66), Color(1.0, 0.9, 0.6, 0.55 * fade))
		draw_rect(Rect2(0.0, -w * 0.14, L, w * 0.28), Color(1, 1, 1, 0.95 * fade))
		draw_circle(Vector2(L, 0.0), w * 0.55, Color(1, 0.95, 0.75, 0.6 * fade))
		draw_circle(Vector2.ZERO, w * 0.3, Color(1, 1, 1, 0.8 * fade))
		# líneas de velocidad
		for i in 6:
			var yy := (float(i) / 5.0 - 0.5) * w * 0.9
			var off := fposmod(t * 900.0 + i * 57.0, L + 1.0)
			draw_line(Vector2(off, yy), Vector2(minf(L, off + 60.0), yy), Color(1, 1, 1, 0.5 * fade), 2.0)
		for b in _booms:
			var bk: float = (t - float(b[2])) / 0.3
			if bk >= 1.0 or float(b[0]) > L:
				continue
			var br: float = float(b[3]) * (0.4 + bk)
			draw_circle(Vector2(b[0], b[1]), br, Color(1, 0.85, 0.5, 0.55 * (1.0 - bk)))
			draw_arc(Vector2(b[0], b[1]), br * 1.15, 0.0, TAU, 20, Color(1, 1, 1, 0.8 * (1.0 - bk)), 2.0, true)


# --- Ultimate del mago: rayos que caen en varios puntos --------------------------------

class LightningStrike extends Node2D:
	var warn: float = 0.35     # aviso en el suelo antes del impacto
	var radius: float = 46.0
	var t: float = 0.0
	var _rng := RandomNumberGenerator.new()
	const BOLT_TIME := 0.28

	func _ready() -> void:
		z_index = 4
		var _mat := CanvasItemMaterial.new()
		_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = _mat
		_rng.randomize()

	func _process(delta: float) -> void:
		t += delta
		if t >= warn + BOLT_TIME + 0.2:
			queue_free()
			return
		queue_redraw()

	func _bolt(width: float, col: Color) -> void:
		var pts := PackedVector2Array()
		var y := -460.0
		var x := _rng.randf_range(-30.0, 30.0)
		pts.append(Vector2(x, y))
		while y < -12.0:
			y += _rng.randf_range(26.0, 48.0)
			x = clampf(x + _rng.randf_range(-22.0, 22.0), -40.0, 40.0) * (1.0 - clampf((y + 120.0) / 120.0, 0.0, 1.0) * 0.8)
			pts.append(Vector2(x, minf(y, 0.0)))
		pts.append(Vector2.ZERO)
		draw_polyline(pts, col, width, true)

	func _draw() -> void:
		if t < warn:
			var k := t / warn
			# el círculo marca exactamente el radio de daño
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.6, 0.85, 1.0, 0.5 + 0.4 * k), 2.0, true)
			draw_circle(Vector2.ZERO, radius * k, Color(0.5, 0.75, 1.0, 0.18))
			return
		var bt := t - warn
		var fade := 1.0 - clampf((bt - BOLT_TIME) / 0.2, 0.0, 1.0)
		if bt < BOLT_TIME:
			_bolt(12.0, Color(0.45, 0.7, 1.0, 0.45))
			_bolt(4.0, Color(0.95, 0.98, 1.0, 1.0))
		var gr := radius * (0.6 + 0.6 * minf(1.0, bt / 0.15))
		draw_circle(Vector2.ZERO, gr, Color(0.6, 0.85, 1.0, 0.35 * fade))
		draw_arc(Vector2.ZERO, gr, 0.0, TAU, 32, Color(1, 1, 1, 0.9 * fade), 3.0, true)
		for i in 8:
			var d := Vector2.from_angle(TAU * i / 8.0 + 0.3)
			draw_line(d * gr * 0.3, d * gr * 1.15, Color(0.85, 0.95, 1.0, 0.7 * fade), 2.0)


# --- Ultimate de chain: cables que se extienden mientras gira (el jugador se mueve) ----

class CableStorm extends Node2D:
	var target: Node2D
	var offset: Vector2 = Vector2.ZERO
	var radius: float = 30.0   # lo actualiza ClassController (radio real de daño)
	var cables: int = 3
	var t: float = 0.0
	var alive: bool = true

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		t += delta
		if not alive or target == null or not is_instance_valid(target):
			queue_free()
			return
		global_position = target.global_position + offset
		queue_redraw()

	func _draw() -> void:
		var rot := t * 11.0
		# zona de daño
		draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, 0.08))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 1.5, true)
		for c in cables:
			var base := rot + TAU * c / cables
			# rastro blanco en la punta
			draw_arc(Vector2.ZERO, radius * 0.96, base - 1.1, base, 16, Color(1, 1, 1, 0.55), 3.0, true)
			# cable curvado (la punta va retrasada respecto a la mano)
			var pts := PackedVector2Array()
			for i in 13:
				var s := float(i) / 12.0
				pts.append(Vector2.from_angle(base - 0.55 * s * s) * (10.0 + (radius - 10.0) * s))
			draw_polyline(pts, Color(0.08, 0.08, 0.1), 3.0, true)
			var tip := pts[pts.size() - 1]
			var tang := (tip - pts[pts.size() - 2]).normalized()
			draw_line(tip, tip + tang * 7.0, Color(0.9, 0.9, 0.92), 5.0)   # enchufe
			draw_line(tip + tang * 7.0, tip + tang * 10.0, Color(0.75, 0.7, 0.4), 2.0)
