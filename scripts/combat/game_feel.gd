extends RefCounted
## "Game feel" sin sprites nuevos: hit-stop, destello blanco, squash & stretch,
## sombra, polvo, fantasmas al rodar y destello de parry.
## Sin class_name (evita el caché de clases): cargar con
##   const GameFeel := preload("res://scripts/combat/game_feel.gd")

const FLASH_SHADER_CODE := """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash * c.a);
	COLOR = c;
}
"""

static var _flash_shader: Shader
static var _stop_until_ms: int = 0


# --- Hit-stop -------------------------------------------------------------------

## Congela el juego un instante (time_scale casi 0). Si ya hay uno activo no se encadena.
static func hit_stop(tree: SceneTree, duration: float, scale: float = 0.05) -> void:
	if tree == null or duration <= 0.0:
		return
	var now := Time.get_ticks_msec()
	if now < _stop_until_ms + 40:
		return
	_stop_until_ms = now + int(duration * 1000.0)
	Engine.time_scale = scale
	# temporizador que ignora time_scale
	tree.create_timer(duration, true, false, true).timeout.connect(_end_stop)


static func _end_stop() -> void:
	Engine.time_scale = 1.0


# --- Destello blanco ------------------------------------------------------------

static func _ensure_flash_material(item: CanvasItem) -> ShaderMaterial:
	if item.material is ShaderMaterial and (item.material as ShaderMaterial).shader == _flash_shader and _flash_shader != null:
		return item.material as ShaderMaterial
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = FLASH_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _flash_shader
	item.material = mat
	return mat


## El sprite se pone blanco puro y vuelve a su color en `duration`.
static func flash(item: CanvasItem, duration: float = 0.14, color: Color = Color.WHITE) -> void:
	if item == null:
		return
	var mat := _ensure_flash_material(item)
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash", 1.0)
	var tw := item.create_tween()
	tw.tween_interval(duration * 0.4)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("flash", v), 1.0, 0.0, duration * 0.6)


# --- Squash & stretch -----------------------------------------------------------

## Deforma el sprite (anclado a los pies) y lo devuelve a escala 1.
## feet_y = posición local de los pies respecto al sprite (p. ej. 72 si FOOT_OFFSET = -72).
static func squash(sprite: Node2D, amount: Vector2, duration: float, feet_y: float = 72.0) -> void:
	if sprite == null:
		return
	if sprite.has_meta("gf_tween"):
		var old: Tween = sprite.get_meta("gf_tween")
		if old and old.is_valid():
			old.kill()
	if not sprite.has_meta("gf_base_y"):
		sprite.set_meta("gf_base_y", sprite.position.y)
	var base_y: float = sprite.get_meta("gf_base_y")
	var apply := func(s: Vector2) -> void:
		sprite.scale = s
		sprite.position.y = base_y + feet_y * (1.0 - s.y)
	apply.call(amount)
	var tw := sprite.create_tween()
	tw.tween_method(apply, amount, Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sprite.set_meta("gf_tween", tw)


# --- Sombra ---------------------------------------------------------------------

class Shadow extends Node2D:
	var radius := Vector2(18.0, 6.0)
	var alpha := 0.32

	func _ready() -> void:
		show_behind_parent = true
		z_as_relative = true
		z_index = 0

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(Vector2(cos(a) * radius.x, sin(a) * radius.y))
		draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, alpha))


## Añade una sombra ovalada bajo los pies (primer hijo: se dibuja debajo del sprite).
static func add_shadow(owner: Node2D, feet: Vector2, radius: Vector2 = Vector2(18.0, 6.0)) -> Node2D:
	var s := Shadow.new()
	s.name = "Shadow"
	s.radius = radius
	s.position = feet
	owner.add_child(s)
	owner.move_child(s, 0)
	return s


# --- Polvo ----------------------------------------------------------------------

class Dust extends Node2D:
	var t := 0.0
	var duration := 0.38
	var puffs: Array = []   # [pos, vel, r]
	var tint := Color(0.86, 0.82, 0.72)

	func setup(count: int, spread: Vector2, push: Vector2, size: float) -> void:
		for i in count:
			var p := Vector2(randf_range(-spread.x, spread.x), randf_range(-spread.y, spread.y))
			var v := push + Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, -2.0))
			puffs.append([p, v, size * randf_range(0.6, 1.1)])

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		t += delta
		if t >= duration:
			queue_free()
			return
		for p in puffs:
			p[0] += p[1] * delta
			p[1] *= 0.9
		queue_redraw()

	func _draw() -> void:
		var k := t / duration
		for p in puffs:
			draw_circle(p[0], p[2] * (0.6 + 0.6 * k), Color(tint, 0.55 * (1.0 - k)))


## Nubecita de polvo en `at` (coordenadas globales). push = hacia dónde se va el polvo.
static func dust(parent: Node, at: Vector2, count: int = 3, push: Vector2 = Vector2.ZERO,
		size: float = 3.5, spread: Vector2 = Vector2(6.0, 2.0)) -> void:
	if parent == null:
		return
	var d := Dust.new()
	d.setup(count, spread, push, size)
	parent.add_child(d)
	d.global_position = at
	d.global_position = at


# --- Fantasmas (afterimage) -------------------------------------------------------

class AfterImage extends Sprite2D:
	var t := 0.0
	var duration := 0.22
	var start_alpha := 0.5

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _process(delta: float) -> void:
		t += delta
		if t >= duration:
			queue_free()
			return
		modulate.a = start_alpha * (1.0 - t / duration)


## Copia el frame actual del AnimatedSprite2D y lo desvanece en el sitio.
static func afterimage(parent: Node, sprite: AnimatedSprite2D, tint: Color = Color(0.55, 0.8, 1.0)) -> void:
	if parent == null or sprite == null or sprite.sprite_frames == null:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var g := AfterImage.new()
	g.texture = tex
	g.flip_h = sprite.flip_h
	g.centered = sprite.centered
	g.offset = sprite.offset
	g.scale = sprite.scale
	g.modulate = Color(tint, 0.5)
	g.z_index = 1
	parent.add_child(g)
	g.global_position = sprite.global_position


# --- Destello de parry ----------------------------------------------------------

class ParryBurst extends Node2D:
	var t := 0.0
	const DURATION := 0.3
	var size := 34.0

	func _ready() -> void:
		z_index = 22
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
		var gold := Color(1.0, 0.86, 0.35, 1.0 - k)
		var white := Color(1.0, 1.0, 1.0, 1.0 - k)
		var r := lerpf(size * 0.3, size, sqrt(k))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, gold, 3.0 * (1.0 - k) + 1.0)
		draw_circle(Vector2.ZERO, size * 0.3 * (1.0 - k), white)
		for i in 12:
			var d := Vector2.from_angle(TAU * i / 12.0)
			var l := r * (1.35 if i % 3 == 0 else 1.0)
			draw_line(d * r * 0.55, d * l, white if i % 2 == 0 else gold, 2.0)


static func parry_burst(parent: Node, at: Vector2, size: float = 34.0) -> void:
	if parent == null:
		return
	var b := ParryBurst.new()
	b.size = size
	parent.add_child(b)
	b.global_position = at
