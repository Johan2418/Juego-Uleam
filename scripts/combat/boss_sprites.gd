extends RefCounted
## Sprites de los bosses (recortados con tools/slice_boss_sheets.py).
## Los "boss_bsod_*" viven en bosses/bsod/, los "boss_div0_*" en bosses/div0/, los "boss_syntax_*" en bosses/syntax/, los "boss_stack_*" en bosses/stack/, los "boss_judge_*" en bosses/judge/, los "boss_tex_*" en bosses/tex/, los "boss_kp_*" en bosses/kp/, el resto en bosses/deadbeef/.
## Si falta un PNG, tex() devuelve null y cada pieza vuelve a su dibujo por código.
## Sin class_name: cargar con preload.

const DIR := "res://assets/sprites/bosses/deadbeef/"
const DIR_BSOD := "res://assets/sprites/bosses/bsod/"
const DIR_DIV0 := "res://assets/sprites/bosses/div0/"
const DIR_SYNTAX := "res://assets/sprites/bosses/syntax/"
const DIR_STACK := "res://assets/sprites/bosses/stack/"
const DIR_JUDGE := "res://assets/sprites/bosses/judge/"
const DIR_TEX := "res://assets/sprites/bosses/tex/"
const DIR_KP := "res://assets/sprites/bosses/kp/"

static var _cache: Dictionary = {}
static var _pivots: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var dir := DIR
	if name.begins_with("boss_bsod"):
		dir = DIR_BSOD
	elif name.begins_with("boss_div0"):
		dir = DIR_DIV0
	elif name.begins_with("boss_syntax"):
		dir = DIR_SYNTAX
	elif name.begins_with("boss_stack"):
		dir = DIR_STACK
	elif name.begins_with("boss_judge"):
		dir = DIR_JUDGE
	elif name.begins_with("boss_tex"):
		dir = DIR_TEX
	elif name.begins_with("boss_kp"):
		dir = DIR_KP
	var path := dir + name + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = t
	return t


## Punto de giro de un brazo: centro del hombro (las primeras filas opacas de la imagen).
static func top_pivot(name: String) -> Vector2:
	if _pivots.has(name):
		return _pivots[name]
	var t := tex(name)
	var p := Vector2.ZERO
	if t:
		var img := t.get_image()
		var lo := img.get_width()
		var hi := 0
		for y in mini(18, img.get_height()):
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					lo = mini(lo, x)
					hi = maxi(hi, x)
		p = Vector2((lo + hi) * 0.5, 14.0)
	_pivots[name] = p
	return p


## Inclinación propia de un brazo dibujado "colgando": ángulo del hombro a la punta.
## Restarla al dibujar deja el brazo apuntando recto hacia abajo (rotation 0 = abajo).
static func lean(name: String) -> float:
	var key := name + "#lean"
	if _pivots.has(key):
		return _pivots[key]
	var t := tex(name)
	var a := 0.0
	if t:
		var img := t.get_image()
		var piv := top_pivot(name)
		var h := img.get_height()
		var sx := 0.0
		var n := 0
		for y in range(maxi(0, h - 12), h):
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					sx += x
					n += 1
		if n > 0:
			a = atan2(piv.x - sx / n, float(h) - piv.y)
	_pivots[key] = a
	return a


## Dibuja la textura centrada en `at` (opcionalmente espejada y con escala).
static func draw_centered(item: CanvasItem, t: Texture2D, at: Vector2, flip: bool = false, s: float = 1.0, col: Color = Color.WHITE) -> void:
	item.draw_set_transform(at, 0.0, Vector2(-s if flip else s, s))
	item.draw_texture(t, -t.get_size() * 0.5, col)
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Igual pero con los pies (borde de abajo) en `at`.
static func draw_feet(item: CanvasItem, t: Texture2D, at: Vector2, flip: bool = false, s: float = 1.0, col: Color = Color.WHITE) -> void:
	item.draw_set_transform(at, 0.0, Vector2(-s if flip else s, s))
	item.draw_texture(t, Vector2(-t.get_width() * 0.5, -t.get_height()), col)
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
