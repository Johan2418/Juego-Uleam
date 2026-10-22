extends RefCounted
## Ambiente de las arenas de los bosses: fondo pintado, partículas, luz y viñeta por fase.
## Sin class_name: cargar con preload("res://scripts/combat/boss_arena_fx.gd").
##
## Fondos: assets/sprites/arenas/arena_<boss>.png (fases 1 y 2) y arena_<boss>_caos.png (fase 3),
## de GROKBOT_ARENAS.md. Si no están, la arena usa el piso dibujado por código (Floor de boss_arena.gd).

const ARENA_DIR := "res://assets/sprites/arenas/"

## Dónde está el piso jugable dentro de cada imagen, en fracciones (x0, y0, x1, y1).
## El fondo se estira para que ese rectángulo calce con ARENA. Ajustar al integrar cada imagen.
const FLOOR_FRAC := {
	"default": [0.08, 0.2, 0.92, 0.93],
	"deadbeef": [0.1, 0.2, 0.905, 0.93],
	"bsod": [0.087, 0.25, 0.92, 0.94],
	"div0": [0.07, 0.27, 0.93, 0.93],
	"syntax": [0.055, 0.21, 0.945, 0.96],
	"stack": [0.055, 0.24, 0.945, 0.92],
	"judge": [0.1, 0.3, 0.9, 0.9],
	"tex": [0.06, 0.24, 0.945, 0.95],
	"kp": [0.087, 0.26, 0.933, 0.96],
	"sudo": [0.08, 0.24, 0.92, 0.94],
}

## Ambiente de cada boss:
##  mote = color de las partículas, move = "up" (suben), "down" (caen), "drift" (flotan), "glitch" (parpadean)
##  count = partículas en fase 1/2/3, tint = color de la luz en fase 2 y 3, vig = color de la viñeta
const AMBIENT := {
	"deadbeef": {"mote": Color(0.55, 1.0, 0.45, 0.7), "move": "up", "count": [14, 26, 44], "tint": [Color(0.94, 1.0, 0.94), Color(0.92, 0.85, 0.82)], "vig": Color(0.1, 0.6, 0.15)},
	"bsod": {"mote": Color(0.75, 0.9, 1.0, 0.5), "move": "drift", "count": [10, 18, 30], "tint": [Color(1.0, 0.95, 0.95), Color(0.82, 0.88, 1.0)], "vig": Color(0.05, 0.25, 0.9)},
	"div0": {"mote": Color(1.0, 0.85, 0.3, 0.8), "move": "down", "count": [8, 18, 36], "tint": [Color(1.0, 0.97, 0.9), Color(1.0, 0.82, 0.8)], "vig": Color(0.85, 0.1, 0.1)},
	"syntax": {"mote": Color(1.0, 1.0, 0.95, 0.45), "move": "drift", "count": [16, 24, 36], "tint": [Color(1.0, 0.97, 0.92), Color(1.0, 0.88, 0.8)], "vig": Color(0.9, 0.45, 0.1)},
	"stack": {"mote": Color(0.75, 0.6, 0.4, 0.6), "move": "down", "count": [12, 26, 48], "tint": [Color(1.0, 0.96, 0.9), Color(1.0, 0.86, 0.75)], "vig": Color(1.0, 0.55, 0.05)},
	"judge": {"mote": Color(1.0, 0.9, 0.65, 0.4), "move": "drift", "count": [14, 22, 32], "tint": [Color(1.0, 0.95, 0.92), Color(1.0, 0.8, 0.8)], "vig": Color(0.75, 0.05, 0.05)},
	"tex": {"mote": Color(1.0, 0.0, 0.9, 0.85), "move": "glitch", "count": [6, 16, 34], "tint": [Color(0.98, 0.95, 1.0), Color(0.95, 0.85, 1.0)], "vig": Color(0.8, 0.0, 0.75)},
	"kp": {"mote": Color(1.0, 0.75, 0.3, 0.8), "move": "up", "count": [8, 20, 40], "tint": [Color(1.0, 0.96, 0.9), Color(1.0, 0.85, 0.8)], "vig": Color(0.95, 0.2, 0.1)},
	"sudo": {"mote": Color(0.55, 1.0, 0.75, 0.6), "move": "drift", "count": [10, 20, 40], "tint": [Color(0.96, 0.94, 1.0), Color(0.85, 0.85, 1.0)], "vig": Color(0.35, 0.2, 0.9)},
}


static func cfg(kind: String) -> Dictionary:
	return AMBIENT.get(kind, AMBIENT["deadbeef"])


static func has_backdrop(kind: String) -> bool:
	return ResourceLoader.exists(ARENA_DIR + "arena_%s.png" % kind)


## Fondo pintado. En fase 3 cambia con un fundido a la versión destrozada.
class Backdrop extends Node2D:
	var kind := ""
	var arena: Rect2
	var _a: Texture2D
	var _b: Texture2D
	var _mix := 0.0

	func _ready() -> void:
		z_index = -10
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_a = load(ARENA_DIR + "arena_%s.png" % kind)
		var caos := ARENA_DIR + "arena_%s_caos.png" % kind
		if ResourceLoader.exists(caos):
			_b = load(caos)

	func set_phase(p: int) -> void:
		if p >= 3 and _b != null and _mix < 1.0:
			var tw := create_tween()
			tw.tween_method(func(v: float) -> void:
				_mix = v
				queue_redraw(), _mix, 1.0, 1.2)

	func _dest(tex: Texture2D) -> Rect2:
		var f: Array = FLOOR_FRAC.get(kind, FLOOR_FRAC["default"])
		var sz := tex.get_size()
		var fx0: float = f[0]
		var fy0: float = f[1]
		var fx1: float = f[2]
		var fy1: float = f[3]
		var sx := arena.size.x / ((fx1 - fx0) * sz.x)
		var sy := arena.size.y / ((fy1 - fy0) * sz.y)
		var pos := arena.position - Vector2(fx0 * sz.x * sx, fy0 * sz.y * sy)
		return Rect2(pos, Vector2(sz.x * sx, sz.y * sy))

	func _draw() -> void:
		draw_rect(arena.grow(400.0), Color(0.03, 0.03, 0.04))
		if _a:
			draw_texture_rect(_a, _dest(_a), false)
		if _b and _mix > 0.0:
			draw_texture_rect(_b, _dest(_b), false, Color(1, 1, 1, _mix))


## Partículas de ambiente (esporas, polvo, tiza, monedas, píxeles sin textura...).
## Más cantidad y más rápidas en cada fase.
class Motes extends Node2D:
	var kind := ""
	var arena: Rect2
	var phase := 1
	var _p: Array = []      # [pos, vel, size, life, seed]
	var _c: Dictionary
	var _t := 0.0

	func _ready() -> void:
		z_index = 40
		_c = AMBIENT.get(kind, AMBIENT["deadbeef"])
		for i in _target():
			_p.append(_spawn(true))

	func _target() -> int:
		var n: Array = _c["count"]
		return int(n[clampi(phase - 1, 0, 2)])

	func _spawn(anywhere: bool) -> Array:
		var mv: String = _c["move"]
		var pos := Vector2(randf_range(arena.position.x, arena.end.x), randf_range(arena.position.y - 80.0, arena.end.y))
		var speed := 1.0 + 0.35 * (phase - 1)
		var vel := Vector2.ZERO
		match mv:
			"up":
				vel = Vector2(randf_range(-8, 8), randf_range(-30, -14) * speed)
				if not anywhere:
					pos.y = arena.end.y + 10.0
			"down":
				vel = Vector2(randf_range(-10, 10), randf_range(26, 60) * speed)
				if not anywhere:
					pos.y = arena.position.y - 90.0
			"drift":
				vel = Vector2(randf_range(-12, 12), randf_range(-8, 8)) * speed
			_:
				vel = Vector2.ZERO
		var s := randf_range(2.0, 4.0)
		if mv == "glitch":
			s = [6.0, 8.0, 12.0][randi() % 3]
		return [pos, vel, s, randf_range(2.0, 6.0), randf() * TAU]

	func _process(delta: float) -> void:
		_t += delta
		while _p.size() < _target():
			_p.append(_spawn(true))
		for i in _p.size():
			var m: Array = _p[i]
			var pos: Vector2 = m[0]
			var vel: Vector2 = m[1]
			pos += vel * delta
			pos.x += sin(_t * 1.5 + float(m[4])) * 6.0 * delta
			m[0] = pos
			m[3] = float(m[3]) - delta
			if float(m[3]) <= 0.0 or not arena.grow(120.0).has_point(pos):
				_p[i] = _spawn(_c["move"] in ["drift", "glitch"])
		queue_redraw()

	func _draw() -> void:
		var col: Color = _c["mote"]
		var glitch: bool = _c["move"] == "glitch"
		for m in _p:
			var pos: Vector2 = m[0]
			var s: float = m[2]
			var life: float = m[3]
			var a := clampf(life, 0.0, 1.0)
			if glitch:
				if sin(_t * 9.0 + float(m[4]) * 5.0) < 0.3:
					continue
				var h := s * 0.5
				draw_rect(Rect2(pos, Vector2(h, h)), Color(col, a))
				draw_rect(Rect2(pos + Vector2(h, h), Vector2(h, h)), Color(col, a))
				draw_rect(Rect2(pos + Vector2(h, 0), Vector2(h, h)), Color(0, 0, 0, a * 0.9))
				draw_rect(Rect2(pos + Vector2(0, h), Vector2(h, h)), Color(0, 0, 0, a * 0.9))
			else:
				draw_rect(Rect2(pos.round(), Vector2(s, s)), Color(col, col.a * a))


## Viñeta de pantalla: casi nada en fase 1, marcada en fase 2 y latiendo en fase 3.
class Vignette extends CanvasLayer:
	var kind := ""
	var phase := 1
	var _rect: TextureRect
	var _t := 0.0
	var _alarm := 0.0

	func _ready() -> void:
		layer = 2
		var c: Color = AMBIENT.get(kind, AMBIENT["deadbeef"])["vig"]
		var g := Gradient.new()
		g.set_color(0, Color(c, 0.0))
		g.set_color(1, Color(c, 1.0))
		g.add_point(0.55, Color(c, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.05, 1.05)
		gt.width = 256
		gt.height = 144
		_rect = TextureRect.new()
		_rect.texture = gt
		_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_rect.size = Vector2(1280, 720)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rect.modulate.a = 0.0
		add_child(_rect)

	## Destello breve (golpe fuerte, cambio de fase).
	func alarm() -> void:
		_alarm = 1.0

	func _process(delta: float) -> void:
		_t += delta
		_alarm = maxf(0.0, _alarm - delta * 1.5)
		var base := 0.0
		if phase == 2:
			base = 0.22
		elif phase >= 3:
			base = 0.32 + 0.16 * (0.5 + 0.5 * sin(_t * TAU * 0.9))
		_rect.modulate.a = clampf(base + _alarm * 0.5, 0.0, 0.85)
