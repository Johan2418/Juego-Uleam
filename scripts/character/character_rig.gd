class_name CharacterRig
extends Node2D
## Personaje armado en capas: cuerpo compartido (recoloreado por shader) + cabeza del personaje.
## Origen del nodo = pies (centro). La cabeza se coloca sobre el cuello del cuerpo.
##
## Hoy el cuerpo es una pose fija por dirección (body_base/front|back|right) con balanceo al caminar.
## Cuando existan animaciones del cuerpo (assets/sprites/characters/body_anims/), se enchufan aquí
## sin tocar las cabezas: cada frame trae su textura, su máscara y su punto de cuello.

const OUTFIT_SHADER := preload("res://shaders/outfit_recolor.gdshader")

@export var character_id: String = "gorra"
@export var facing: String = "front"  # front | back | left | right

var _visual: Node2D
var _body: Sprite2D
var _head: Sprite2D
var _mat: ShaderMaterial
var _moving: bool = false
var _bob_time: float = 0.0
var _action_tween: Tween
var _guarding: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.centered = false
	_mat = ShaderMaterial.new()
	_mat.shader = OUTFIT_SHADER
	_body.material = _mat
	_visual.add_child(_body)
	_head = Sprite2D.new()
	_head.name = "Head"
	_head.centered = false
	_visual.add_child(_head)
	_refresh()


func set_character(id: String) -> void:
	character_id = id
	_refresh()


func set_facing(dir_name: String) -> void:
	if dir_name == facing:
		return
	facing = dir_name
	_refresh()


func set_moving(value: bool) -> void:
	_moving = value
	if not value:
		_bob_time = 0.0
		if _visual:
			_visual.position.y = 0.0


func set_guarding(value: bool) -> void:
	_guarding = value
	if _visual:
		_visual.modulate = Color(0.75, 0.85, 1.0) if value else Color.WHITE


## Feedback de acción mientras no haya animaciones del cuerpo: pequeño avance + destello.
func play_action(kind: String, dir: Vector2) -> void:
	if _visual == null:
		return
	if _action_tween and _action_tween.is_valid():
		_action_tween.kill()
	_visual.position = Vector2.ZERO
	var reach := 3.0 if kind.begins_with("mago_cast") else 5.0
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.DOWN
	_action_tween = create_tween()
	_action_tween.tween_property(_visual, "position", (d * reach).round(), 0.06)
	_action_tween.parallel().tween_property(_visual, "modulate", Color(1.4, 1.4, 1.4), 0.06)
	_action_tween.tween_property(_visual, "position", Vector2.ZERO, 0.12)
	_action_tween.parallel().tween_property(_visual, "modulate", Color.WHITE, 0.12)


func _process(delta: float) -> void:
	if not _moving or _visual == null:
		return
	_bob_time += delta
	# 2 pasos por ciclo a ~8 fps: sube 1 px en frames alternos
	_visual.position.y = -1.0 if int(_bob_time * 8.0) % 2 == 1 else 0.0


func _refresh() -> void:
	if _body == null:
		return
	var view := CharacterCatalog.view_for(facing)
	var flip := facing == "left"
	var body_tex := CharacterCatalog.body_texture(view)
	var info := CharacterCatalog.body_info(view)
	_body.texture = body_tex
	_body.flip_h = flip
	_mat.set_shader_parameter("mask_tex", CharacterCatalog.body_mask(view))
	_mat.set_shader_parameter("shirt_ref", float(info.get("shirt_ref", 0.833)))
	_mat.set_shader_parameter("pants_ref", float(info.get("pants_ref", 0.377)))
	var shirt := CharacterCatalog.color_of(character_id, "shirt")
	var pants := CharacterCatalog.color_of(character_id, "pants")
	_mat.set_shader_parameter("shirt_color", Vector3(shirt.r, shirt.g, shirt.b))
	_mat.set_shader_parameter("pants_color", Vector3(pants.r, pants.g, pants.b))

	var head_tex := CharacterCatalog.head_texture(character_id, view)
	_head.texture = head_tex
	_head.flip_h = flip
	if body_tex == null:
		return
	var bw := float(body_tex.get_width())
	var bh := float(body_tex.get_height())
	var neck: Array = info.get("neck", [bw * 0.5, 0])
	var nx := float(neck[0])
	var ny := float(neck[1])
	if flip:
		nx = bw - nx
	# Pies en el origen; columna del cuello en x = 0
	_body.position = Vector2(-round(nx), -bh)
	if head_tex:
		var anchor := CharacterCatalog.head_anchor(character_id, view)
		var ax := anchor.x
		if flip:
			ax = float(head_tex.get_width()) - ax
		_head.position = Vector2(-round(ax), -bh + ny - anchor.y)


## Alto aproximado del personaje (para encuadrar previews).
func get_visual_height() -> float:
	if _body == null or _body.texture == null:
		return 50.0
	var h := float(_body.texture.get_height())
	if _head and _head.texture:
		h += float(_head.texture.get_height())
	return h
