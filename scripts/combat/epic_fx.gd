extends RefCounted
## Efectos ÉPICOS comunes a todos los bosses (los mismos que estrenó SUDO, ahora compartidos) y
## los QTE de los clímax de los duelos finales.
##   Efectos (solo visuales): flash, burst, ring, charge, scorch, embers, speed_lines, shards, word,
##     cam_punch / cam_zoom (a las cámaras de TODOS los jugadores), cinema (barras de cine), whiteout.
##   Anim: efecto animado por cuadros de grokbot (assets/sprites/bosses/<boss>/boss_<boss>_<prefijo>_0..7);
##     si la hoja no está, quien lo use dibuja su versión por código (Anim.ok()).
##   Qte: "timing" (aro que se cierra), "mash" (machacar), "sequence" (botones en orden),
##     "rhythm" (varios aros al ritmo). Usa su propio reloj (sirve en cámara lenta) y en multijugador
##     vale el botón de cualquiera de los dos.
##   climax(boss, pasos): encadena QTE con cámara lenta, barras de cine y zoom. Devuelve true si se ganó.
## Sin class_name: cargar con preload("res://scripts/combat/epic_fx.gd").

const Spr := preload("res://scripts/combat/boss_sprites.gd")
const GameFeel := preload("res://scripts/combat/game_feel.gd")


# ---------------------------------------------------------------- atajos

static func flash(parent: Node, col: Color = Color.WHITE, peak: float = 0.35, life: float = 0.35) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var f := Flash.new()
	f.col = col
	f.peak = peak
	f.life = life
	parent.add_child(f)


static func burst(parent: Node, at: Vector2, col: Color, count: int = 18, speed: float = 320.0, up_bias: float = 0.6, life: float = 0.7) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var b := Burst.new()
	b.col = col
	b.count = count
	b.speed = speed
	b.up_bias = up_bias
	b.life = life
	parent.add_child(b)
	b.global_position = at


static func ring(parent: Node, at: Vector2, col: Color, max_r: float = 220.0, life: float = 0.5, width: float = 10.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var r := Ring.new()
	r.col = col
	r.max_r = max_r
	r.life = life
	r.width = width
	parent.add_child(r)
	r.global_position = at


static func charge(parent: Node, at: Vector2, col: Color, dur: float = 0.6, radius: float = 120.0, follow: Node2D = null, offset: Vector2 = Vector2.ZERO) -> Node2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var c := Charge.new()
	c.col = col
	c.dur = dur
	c.radius = radius
	c.follow = follow
	c.offset = offset
	parent.add_child(c)
	c.global_position = at
	return c


static func scorch(parent: Node, at: Vector2, col: Color, r: float = 46.0, life: float = 3.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := Scorch.new()
	s.col = col
	s.r = r
	s.life = life
	parent.add_child(s)
	s.global_position = at


static func embers(parent: Node, at: Vector2, col: Color, area: Rect2 = Rect2(-40, -10, 80, 20), emit_for: float = 1.0, rate: float = 40.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var e := Embers.new()
	e.col = col
	e.area = area
	e.emit_for = emit_for
	e.rate = rate
	parent.add_child(e)
	e.global_position = at


static func speed_lines(parent: Node, life: float = 0.45, col: Color = Color(1, 1, 1, 0.5)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := SpeedLines.new()
	s.life = life
	s.col = col
	parent.add_child(s)


## Pedazos que salen volando girando (al romperse algo).
static func shards(parent: Node, at: Vector2, col: Color, count: int = 10, speed: float = 380.0, size: float = 7.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := Shards.new()
	s.col = col
	s.count = count
	s.speed = speed
	s.size = size
	parent.add_child(s)
	s.global_position = at


## Palabra grande que salta (¡CRACK!, ¡OBJECIÓN!...). Va en el mundo, sobre el punto.
static func word(parent: Node, at: Vector2, text: String, col: Color, size: int = 40, life: float = 0.9) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var w := Word.new()
	w.text = text
	w.col = col
	w.size = size
	w.life = life
	parent.add_child(w)
	w.global_position = at


static func whiteout(parent: Node, col: Color = Color.WHITE, life: float = 0.9, hold: float = 0.15) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var w := WhiteOut.new()
	w.col = col
	w.life = life
	w.hold = hold
	parent.add_child(w)


## Cámaras de todos los jugadores (la vista compartida copia el zoom y el sacudón del jugador 1).
static func cams(tree: SceneTree) -> Array:
	var out: Array = []
	if tree == null:
		return out
	for p in tree.get_nodes_in_group("player"):
		var c := (p as Node).get_node_or_null("Camera2D") as Camera2D
		if c:
			out.append(c)
	return out


## Zoom rápido de ida y vuelta (golpes grandes).
static func cam_punch(tree: SceneTree, amount: float = 0.06, time: float = 0.18) -> void:
	for c in cams(tree):
		var cam: Camera2D = c
		var base := cam.zoom
		var tw := cam.create_tween()
		tw.tween_property(cam, "zoom", base * (1.0 + amount), time * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(cam, "zoom", base, time * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Zoom sostenido (cinemáticas). Devuelve el zoom original del primero para volver.
static func cam_zoom(tree: SceneTree, z: float, time: float) -> void:
	for c in cams(tree):
		var cam: Camera2D = c
		if not cam.has_meta("epic_zoom0"):
			cam.set_meta("epic_zoom0", cam.zoom)
		var base: Vector2 = cam.get_meta("epic_zoom0")
		cam.create_tween().tween_property(cam, "zoom", base * z, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## La cámara de cada jugador se corre hacia un punto (lo usa lock_on.gd); null = deja de enfocar.
static func cam_focus(tree: SceneTree, at: Variant) -> void:
	for c in cams(tree):
		var cam: Camera2D = c
		if at == null:
			if cam.has_meta("epic_focus"):
				cam.remove_meta("epic_focus")
		else:
			cam.set_meta("epic_focus", at)


static func cam_reset(tree: SceneTree, time: float = 0.4) -> void:
	cam_focus(tree, null)
	for c in cams(tree):
		var cam: Camera2D = c
		if cam.has_meta("epic_zoom0"):
			var base: Vector2 = cam.get_meta("epic_zoom0")
			cam.remove_meta("epic_zoom0")
			cam.create_tween().tween_property(cam, "zoom", base, time)


static func cinema(parent: Node) -> CinemaBars:
	if parent == null or not parent.is_inside_tree():
		return null
	var b := CinemaBars.new()
	parent.add_child(b)
	return b


## Golpe grande "completo": onda, chispas, (flash y zoom si es fuerte) y quemadura.
## kind/prefix: efecto animado de grokbot del boss (si existe, sale encima en los golpes fuertes).
static func big_hit(parent: Node, at: Vector2, col: Color, strength: float, kind: String = "", prefix: String = "") -> void:
	if kind != "" and strength >= 4.0:
		anim(parent, kind, prefix, at + Vector2(0, -20), clampf(0.5 + strength * 0.08, 0.6, 1.3))
	ring(parent, at, col, 70.0 + strength * 24.0, 0.45, 6.0 + strength)
	burst(parent, at + Vector2(0, -10), col.lightened(0.25), int(8 + strength * 2.5), 220.0 + strength * 25.0, 0.7, 0.6)
	if strength >= 5.0:
		scorch(parent, at, col, 26.0 + strength * 4.0, 2.4)
		cam_punch(parent.get_tree(), 0.02 + strength * 0.006, 0.2)
	if strength >= 7.0:
		flash(parent, col.lightened(0.6), 0.18, 0.25)


# ---------------------------------------------------------------- QTE y clímax

## Pruebas: Epic.EpicAuto.v = 1 los QTE se ganan solos, -1 se pierden solos, 0 normal.
static func qte(parent: Node, mode: String, action: String, title: String, opts: Dictionary = {}) -> Qte:
	var q := Qte.new()
	q.mode = mode
	q.action = action
	q.title = title
	for k in opts.keys():
		q.set(k, opts[k])
	parent.add_child(q)
	return q


## Encadena pasos de QTE en cámara lenta con barras de cine. Cada paso es un diccionario:
##   {mode, action, title, ...opciones del Qte, "zoom": 1.15, "slow": 0.35,
##    "before": Callable (antes del QTE), "pressed": Callable (cada pulsación), "ok": Callable, "fail": Callable}
## Devuelve true si se superaron todos. Siempre deja el tiempo y la cámara como estaban.
static func climax(boss: Node, steps: Array) -> bool:
	var tree := boss.get_tree()
	var bars := cinema(boss.get_parent())
	var win := true
	for st in steps:
		var s: Dictionary = st
		if not is_instance_valid(boss) or not boss.is_inside_tree():
			win = false
			break
		if s.has("before"):
			await (s["before"] as Callable).call()
		if not is_instance_valid(boss) or not boss.is_inside_tree():
			win = false
			break
		cam_zoom(tree, float(s.get("zoom", 1.12)), 0.35)
		cam_focus(tree, (boss as Node2D).global_position + Vector2(0, -90))
		Engine.time_scale = float(s.get("slow", 0.35))
		var opts := s.duplicate()
		for k in ["mode", "action", "title", "zoom", "slow", "before", "pressed", "ok", "fail"]:
			opts.erase(k)
		var q := qte(boss.get_parent(), str(s.get("mode", "timing")), str(s.get("action", "action_primary")), str(s.get("title", "")), opts)
		if s.has("pressed"):
			q.pressed.connect(s["pressed"])
		var ok: bool = await q.done
		Engine.time_scale = 1.0
		if ok:
			if s.has("ok"):
				await (s["ok"] as Callable).call()
		else:
			if s.has("fail"):
				await (s["fail"] as Callable).call()
			win = false
			break
	Engine.time_scale = 1.0
	cam_reset(tree, 0.5)
	if bars and is_instance_valid(bars):
		bars.close()
	return win


# ================================================================== clases

class Flash extends CanvasLayer:
	var col := Color(1, 1, 1)
	var peak := 0.35
	var life := 0.35
	var t := 0.0
	var _r: ColorRect

	func _ready() -> void:
		layer = 4
		_r = ColorRect.new()
		_r.size = Vector2(1280, 720)
		_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_r.color = Color(col, peak)
		add_child(_r)

	func _process(delta: float) -> void:
		t += delta
		_r.color = Color(col, peak * clampf(1.0 - t / life, 0.0, 1.0))
		if t > life:
			queue_free()


## Ráfaga de chispas con gravedad.
class Burst extends Node2D:
	var col := Color(1, 0.8, 0.4)
	var count := 18
	var speed := 320.0
	var gravity := 520.0
	var life := 0.7
	var up_bias := 0.6
	var t := 0.0
	var _p: Array = []

	func _ready() -> void:
		z_index = 9
		for i in count:
			var d := Vector2.from_angle(randf() * TAU)
			d.y = lerpf(d.y, -absf(d.y), up_bias)
			_p.append([Vector2.ZERO, d.normalized() * speed * randf_range(0.35, 1.0), randf_range(1.5, 3.5)])

	func _process(delta: float) -> void:
		t += delta
		for p in _p:
			p[1].y += gravity * delta
			p[0] += p[1] * delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - t / life, 0.0, 1.0)
		for p in _p:
			var v: Vector2 = p[1]
			draw_line(p[0], p[0] - v * 0.03, Color(col, a), float(p[2]))
			draw_circle(p[0], float(p[2]) * 0.6, Color(1, 1, 1, a))


## Brasas que suben despacio desde una zona.
class Embers extends Node2D:
	var area := Rect2(-40, -10, 80, 20)
	var col := Color(1.0, 0.55, 0.15)
	var rate := 40.0
	var emit_for := 1.0
	var t := 0.0
	var _acc := 0.0
	var _p: Array = []

	func _ready() -> void:
		z_index = 8

	func _process(delta: float) -> void:
		t += delta
		if t < emit_for:
			_acc += delta * rate
			while _acc >= 1.0:
				_acc -= 1.0
				_p.append([Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)),
					Vector2(randf_range(-20, 20), randf_range(-90, -30)), randf_range(0.5, 1.3), randf_range(1.5, 3.0)])
		for p in _p:
			p[0] += p[1] * delta
			p[1].x += sin(t * 6.0 + p[0].y * 0.05) * 30.0 * delta
			p[2] -= delta
		_p = _p.filter(func(p: Array) -> bool: return float(p[2]) > 0.0)
		if t > emit_for and _p.is_empty():
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for p in _p:
			var a := clampf(float(p[2]) * 1.5, 0.0, 1.0)
			draw_circle(p[0], float(p[3]) * 2.0, Color(col, 0.18 * a))
			draw_circle(p[0], float(p[3]), Color(col.lightened(0.3), a))


## Marca quemada en el piso que se enfría.
class Scorch extends Node2D:
	var r := 46.0
	var col := Color(1, 0.5, 0.2)
	var life := 3.0
	var t := 0.0
	var _cracks: Array = []

	func _ready() -> void:
		z_index = -3
		for i in 7:
			_cracks.append([randf() * TAU, randf_range(0.7, 1.4)])

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - t / life, 0.0, 1.0)
		var hot := clampf(1.0 - t / (life * 0.4), 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 24:
			var ang := TAU * i / 24.0
			pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.5))
		draw_colored_polygon(pts, Color(0.05, 0.05, 0.06, 0.55 * a))
		for c in _cracks:
			var e := Vector2.from_angle(c[0]) * r * float(c[1])
			e.y *= 0.5
			draw_line(Vector2.ZERO, e, Color(col.lightened(0.2), 0.8 * hot * a), 2.0)
			draw_line(Vector2.ZERO, e * 0.6, Color(1, 1, 1, 0.6 * hot * a), 1.0)
		pts.append(pts[0])
		draw_polyline(pts, Color(col, 0.5 * hot * a), 2.0)


## Carga: partículas que se juntan en un punto y un brillo que crece.
class Charge extends Node2D:
	var col := Color(1, 0.9, 0.5)
	var dur := 0.6
	var radius := 120.0
	var follow: Node2D
	var offset := Vector2.ZERO
	var t := 0.0
	var _p: Array = []

	func _ready() -> void:
		z_index = 12
		for i in 26:
			_p.append([randf() * TAU, randf_range(0.6, 1.0) * radius, randf_range(0.0, 0.5)])

	func _process(delta: float) -> void:
		t += delta
		if follow != null and is_instance_valid(follow):
			global_position = follow.global_position + offset
		if t > dur + 0.15:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / dur, 0.0, 1.0)
		for p in _p:
			var s := clampf((t - float(p[2]) * dur) / (dur * 0.6), 0.0, 1.0)
			if s <= 0.0 or s >= 1.0:
				continue
			var d := Vector2.from_angle(float(p[0]) + s * 1.5)
			var a := d * float(p[1]) * (1.0 - s)
			draw_line(a, a - d * 14.0 * (1.0 - s), Color(col, 0.8), 2.0)
		for i in 3:
			draw_circle(Vector2.ZERO, (6.0 + 22.0 * k) * (1.0 + 0.4 * i), Color(col, 0.12 * k))
		draw_circle(Vector2.ZERO, 4.0 + 8.0 * k, Color(1, 1, 1, 0.9 * k))
		if t > dur:
			var e := clampf((t - dur) / 0.15, 0.0, 1.0)
			draw_arc(Vector2.ZERO, 20.0 + 80.0 * e, 0, TAU, 32, Color(col, 1.0 - e), 4.0)


## Anillo de onda (solo visual), achatado en perspectiva.
class Ring extends Node2D:
	var col := Color(1, 0.8, 0.4)
	var max_r := 260.0
	var life := 0.5
	var width := 10.0
	var flat := 0.5
	var t := 0.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / life, 0.0, 1.0)
		var r := max_r * (1.0 - pow(1.0 - k, 3.0))
		if r < 1.0:
			return
		var a := 1.0 - k
		var pts := PackedVector2Array()
		for i in 49:
			var ang := TAU * i / 48.0
			pts.append(Vector2(cos(ang) * r, sin(ang) * r * flat))
		draw_polyline(pts, Color(col, 0.35 * a), width * 2.2)
		draw_polyline(pts, Color(col.lightened(0.3), 0.9 * a), width * (1.0 - k * 0.6))
		draw_polyline(pts, Color(1, 1, 1, 0.8 * a), 2.0)


## Líneas de velocidad a pantalla completa.
class SpeedLines extends CanvasLayer:
	var life := 0.45
	var col := Color(1, 1, 1, 0.5)
	var t := 0.0
	var _c: Control
	var _l: Array = []

	func _ready() -> void:
		layer = 3
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_paint)
		add_child(_c)
		for i in 46:
			_l.append([randf() * TAU, randf_range(380.0, 520.0), randf_range(60.0, 220.0), randf_range(1.0, 3.0)])

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		_c.queue_redraw()

	func _paint() -> void:
		var a := col.a * clampf(1.0 - t / life, 0.0, 1.0)
		var c := Vector2(640, 360)
		for l in _l:
			var d := Vector2.from_angle(float(l[0]))
			var r0: float = float(l[1]) - fmod(t * 900.0, 120.0)
			_c.draw_line(c + d * r0, c + d * (r0 + float(l[2])), Color(col, a), float(l[3]))


## Pedazos que salen volando y giran.
class Shards extends Node2D:
	var col := Color(0.7, 0.7, 0.75)
	var count := 10
	var speed := 380.0
	var size := 7.0
	var life := 0.9
	var t := 0.0
	var _p: Array = []   # [pos, vel, rot, spin, w, h]

	func _ready() -> void:
		z_index = 9
		for i in count:
			var d := Vector2.from_angle(randf() * TAU)
			d.y = -absf(d.y) * 0.8 - 0.2
			_p.append([Vector2.ZERO, d.normalized() * speed * randf_range(0.4, 1.0), randf() * TAU, randf_range(-14, 14), size * randf_range(0.6, 1.4), size * randf_range(0.4, 1.0)])

	func _process(delta: float) -> void:
		t += delta
		for p in _p:
			p[1].y += 900.0 * delta
			p[0] += p[1] * delta
			p[2] += float(p[3]) * delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - (t - life * 0.6) / (life * 0.4), 0.0, 1.0)
		for p in _p:
			draw_set_transform(p[0], float(p[2]), Vector2.ONE)
			var w: float = p[4]
			var h: float = p[5]
			draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(col, a))
			draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(0, 0, 0, 0.8 * a), false, 1.5)
		draw_set_transform(Vector2.ZERO)


## Palabra grande que salta y se desvanece.
class Word extends Node2D:
	var text := "¡CRACK!"
	var col := Color(1, 0.9, 0.3)
	var size := 40
	var life := 0.9
	var t := 0.0

	func _ready() -> void:
		z_index = 60
		z_as_relative = false

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var pop := 1.0 + 0.6 * clampf(1.0 - t / 0.12, 0.0, 1.0)
		var a := clampf((life - t) / 0.25, 0.0, 1.0)
		draw_set_transform(Vector2(0, -t * 30.0), -0.08, Vector2(pop, pop))
		draw_string_outline(f, Vector2(-300, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 600, size, 10, Color(0, 0, 0, 0.9 * a))
		draw_string(f, Vector2(-300, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 600, size, Color(col, a))
		draw_set_transform(Vector2.ZERO)


class CinemaBars extends CanvasLayer:
	var k := 0.0
	var _c: Control
	var _tw: Tween

	func _ready() -> void:
		layer = 8
		process_mode = Node.PROCESS_MODE_ALWAYS
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_paint)
		add_child(_c)
		_tw = create_tween()
		_tw.set_ignore_time_scale(true)
		_tw.tween_property(self, "k", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func close() -> void:
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween()
		_tw.set_ignore_time_scale(true)
		_tw.tween_property(self, "k", 0.0, 0.4)
		_tw.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		_c.queue_redraw()

	func _paint() -> void:
		var h := 80.0 * k
		_c.draw_rect(Rect2(0, 0, 1280, h), Color.BLACK)
		_c.draw_rect(Rect2(0, 720 - h, 1280, h), Color.BLACK)


class WhiteOut extends CanvasLayer:
	var life := 0.9
	var hold := 0.15
	var col := Color.WHITE
	var t := 0.0
	var _r: ColorRect

	func _ready() -> void:
		layer = 10
		process_mode = Node.PROCESS_MODE_ALWAYS
		_r = ColorRect.new()
		_r.size = Vector2(1280, 720)
		_r.color = col
		_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_r)

	func _process(delta: float) -> void:
		t += delta / maxf(0.05, Engine.time_scale)
		_r.color.a = col.a * (1.0 if t < hold else clampf(1.0 - (t - hold) / (life - hold), 0.0, 1.0))
		if t > life:
			queue_free()


## Efecto animado por cuadros de grokbot: boss_<kind>_<prefix>_0..7.
class Anim extends Node2D:
	var kind := "deadbeef"
	var prefix := "fxboom"
	var frames: Array = [0, 1, 2, 3, 4, 5, 6, 7]
	var fps := 14.0
	var k := 1.0
	var ground := false
	var loop := false
	var rot := 0.0
	var tint := Color.WHITE
	var follow: Node2D
	var offset := Vector2.ZERO
	var life := 0.0
	var t := 0.0

	static func ok(kind_: String, pre: String) -> bool:
		return Spr.tex("boss_%s_%s_0" % [kind_, pre]) != null

	func _ready() -> void:
		z_index = 10

	func _process(delta: float) -> void:
		t += delta
		if follow != null and is_instance_valid(follow):
			global_position = follow.global_position + offset
		if (not loop and int(t * fps) >= frames.size()) or (life > 0.0 and t > life):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var i := int(t * fps)
		i = i % frames.size() if loop else mini(i, frames.size() - 1)
		var tex: Texture2D = Spr.tex("boss_%s_%s_%d" % [kind, prefix, int(frames[i])])
		if tex == null:
			return
		var sz := tex.get_size()
		draw_set_transform(Vector2.ZERO, rot, Vector2(k, k))
		draw_texture(tex, Vector2(-sz.x * 0.5, -sz.y if ground else -sz.y * 0.5), tint)
		draw_set_transform(Vector2.ZERO)


## Efecto de grokbot si existe; si no, null (el que llama dibuja su versión por código).
static func anim(parent: Node, kind: String, prefix: String, at: Vector2, k: float = 1.0, ground: bool = false, fps: float = 14.0) -> Anim:
	if parent == null or not parent.is_inside_tree() or not Anim.ok(kind, prefix):
		return null
	var a := Anim.new()
	a.kind = kind
	a.prefix = prefix
	a.k = k
	a.ground = ground
	a.fps = fps
	parent.add_child(a)
	a.global_position = at
	return a


## QTE. Modos: timing / mash / sequence / rhythm. Reloj propio (vale en cámara lenta).
class Qte extends CanvasLayer:
	signal done(ok: bool)
	signal pressed

	const KEYS := ["action_primary", "action_secondary", "parry", "roll", "ultimate"]

	var mode := "timing"
	var action := "action_primary"
	var title := "¡AHORA!"
	var sub := ""
	var col := Color(1, 0.9, 0.4)
	var dur := 1.2            ## timing: tiempo que tarda el aro en cerrarse
	var win_from := 0.62      ## timing: ventana buena (fracción de dur)
	var win_to := 0.88
	var limit := 3.5          ## mash / sequence: tiempo máximo
	var gain := 0.08          ## mash
	var decay := 0.25
	var meter := 0.25
	var seq: Array = []       ## sequence: acciones en orden
	var beats: Array = []     ## rhythm: segundos (desde el inicio) en que hay que pulsar
	var window := 0.16        ## rhythm: margen (s) alrededor de cada pulso
	var result := 0
	var _i := 0               ## sequence / rhythm: siguiente
	var _tt := 0.0
	var _end_t := 0.0
	var _flash := 0.0
	var _c: Control

	func _ready() -> void:
		layer = 9
		process_mode = Node.PROCESS_MODE_ALWAYS
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_paint)
		add_child(_c)
		if mode == "sequence" and seq.is_empty():
			seq = ["action_primary", "action_secondary", "parry"]

	## Tiempo del QTE (mismo nombre que el Qte de SUDO, lo usan los bots de prueba).
	func _el() -> float:
		return _tt

	func _just(a: String) -> bool:
		return Input.is_action_just_pressed(a)

	func _process(delta: float) -> void:
		var dt := minf(delta / maxf(0.01, Engine.time_scale), 1.0 / 30.0)
		_tt += dt
		_flash = maxf(0.0, _flash - dt * 4.0)
		if result != 0:
			if _tt - _end_t > 0.35:
				queue_free()
			_c.queue_redraw()
			return
		var auto: int = int(EpicAuto.v)
		match mode:
			"timing":
				var k := _tt / dur
				if auto == 1 and k >= (win_from + win_to) * 0.5:
					_press(); _finish(true)
				elif _just(action):
					_press(); _finish(k >= win_from and k <= win_to)
				elif k > win_to + 0.02:
					_finish(false)
			"mash":
				if (auto == 1 and fmod(_tt, 0.06) < dt) or _just(action):
					meter += gain
					_press()
				meter = maxf(0.0, meter - decay * dt)
				if meter >= 1.0:
					meter = 1.0
					_finish(true)
				elif _tt > limit or auto == -1 and _tt > 0.5:
					_finish(false)
			"sequence":
				var want: String = seq[_i]
				var hit := ""
				if auto == 1 and _tt > 0.25 * (_i + 1):
					hit = want
				else:
					for a in KEYS:
						if _just(a):
							hit = a
							break
				if hit != "":
					_press()
					if hit == want:
						_i += 1
						if _i >= seq.size():
							_finish(true)
					else:
						_finish(false)
				elif _tt > limit:
					_finish(false)
			"rhythm":
				var bt: float = beats[_i]
				var press := _just(action) or (auto == 1 and absf(_tt - bt) < dt)
				if press:
					_press()
					if absf(_tt - bt) <= window:
						_i += 1
						if _i >= beats.size():
							_finish(true)
					else:
						_finish(false)
				elif _tt > bt + window:
					_finish(false)
		if auto == -1 and result == 0 and _tt > 0.6:
			_finish(false)
		_c.queue_redraw()

	func _press() -> void:
		_flash = 1.0
		pressed.emit()

	func _finish(ok: bool) -> void:
		if result != 0:
			return
		result = 1 if ok else -1
		_end_t = _tt
		done.emit(ok)

	func _key(a: String) -> String:
		return GameState.btn(a) if GameState else a

	func _button(c: Vector2, label: String, colr: Color, scale_: float = 1.0) -> void:
		var f := ThemeDB.fallback_font
		_c.draw_circle(c, 30.0 * scale_, Color(0.06, 0.06, 0.1, 0.95))
		_c.draw_arc(c, 30.0 * scale_, 0, TAU, 32, colr, 3.0)
		var fs := 22 if label.length() <= 2 else 13
		_c.draw_string(f, c + Vector2(-60, 8), label, HORIZONTAL_ALIGNMENT_CENTER, 120, fs, colr)

	func _paint() -> void:
		var f := ThemeDB.fallback_font
		var c := Vector2(640, 470)
		var rc := col
		if result == 1:
			rc = Color(0.5, 1.0, 0.6)
		elif result == -1:
			rc = Color(1, 0.35, 0.3)
		var pop := 1.0 + (0.25 * clampf(1.0 - (_tt - _end_t) / 0.3, 0.0, 1.0) if result != 0 else 0.0)
		_c.draw_set_transform(c, 0.0, Vector2(pop, pop))
		_c.draw_string_outline(f, Vector2(-400, -100), title, HORIZONTAL_ALIGNMENT_CENTER, 800, 42, 11, Color(0, 0, 0, 0.9))
		_c.draw_string(f, Vector2(-400, -100), title, HORIZONTAL_ALIGNMENT_CENTER, 800, 42, rc)
		if sub != "":
			_c.draw_string_outline(f, Vector2(-400, -66), sub, HORIZONTAL_ALIGNMENT_CENTER, 800, 18, 6, Color(0, 0, 0, 0.9))
			_c.draw_string(f, Vector2(-400, -66), sub, HORIZONTAL_ALIGNMENT_CENTER, 800, 18, Color(1, 1, 1, 0.9))
		match mode:
			"timing":
				var k := clampf((_tt if result == 0 else _end_t) / dur, 0.0, 1.0)
				var r_now := lerpf(120.0, 30.0, k)
				var r_a := lerpf(120.0, 30.0, win_from)
				var r_b := lerpf(120.0, 30.0, win_to)
				_c.draw_arc(Vector2.ZERO, (r_a + r_b) * 0.5, 0, TAU, 48, Color(0.3, 1.0, 0.45, 0.35), r_a - r_b)
				_c.draw_arc(Vector2.ZERO, r_now, 0, TAU, 48, rc, 5.0)
				_button(Vector2.ZERO, _key(action), rc)
			"mash":
				var bw := 440.0
				_c.draw_rect(Rect2(-bw * 0.5, 52, bw, 22), Color(0, 0, 0, 0.75))
				_c.draw_rect(Rect2(-bw * 0.5, 52, bw * meter, 22), col.lightened(0.2))
				_c.draw_rect(Rect2(-bw * 0.5, 52, bw, 22), Color(1, 1, 1, 0.8), false, 2.0)
				var left := maxf(0.0, limit - _tt) if result == 0 else 0.0
				_c.draw_string(f, Vector2(-bw * 0.5, 96), "%.1f s" % left, HORIZONTAL_ALIGNMENT_CENTER, bw, 16, Color(1, 1, 1, 0.8))
				_button(Vector2.ZERO, _key(action), rc, 1.0 + 0.15 * _flash)
			"sequence":
				var n := seq.size()
				for i in n:
					var x := (i - (n - 1) * 0.5) * 80.0
					var cc := Color(0.5, 1.0, 0.6) if i < _i else (rc if i == _i else Color(0.6, 0.6, 0.7))
					_button(Vector2(x, 0), _key(str(seq[i])), cc, 1.15 if i == _i and result == 0 else 0.9)
				var left2 := maxf(0.0, limit - _tt) if result == 0 else 0.0
				_c.draw_string(f, Vector2(-200, 70), "%.1f s" % left2, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, Color(1, 1, 1, 0.8))
			"rhythm":
				# los pulsos se acercan por una línea hacia el botón
				_c.draw_line(Vector2(-420, 0), Vector2(0, 0), Color(1, 1, 1, 0.3), 3.0)
				for i in range(_i, beats.size()):
					var dtb: float = float(beats[i]) - _tt
					if dtb < -window or dtb > 2.0:
						continue
					var x2 := -dtb * 210.0
					_c.draw_circle(Vector2(x2, 0), 14.0, Color(col, 0.9))
					_c.draw_arc(Vector2(x2, 0), 14.0, 0, TAU, 20, Color.WHITE, 2.0)
				_button(Vector2.ZERO, _key(action), rc, 1.0 + 0.2 * _flash)
		_c.draw_set_transform(Vector2.ZERO)


## Interruptor de pruebas compartido (static var de una clase interna: la lee Qte).
class EpicAuto extends RefCounted:
	static var v := 0
