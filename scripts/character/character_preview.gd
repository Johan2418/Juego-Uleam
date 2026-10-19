class_name CharacterPreview
extends Control
## Vista previa del creador: muestra al personaje elegido (Wadrid / MarlonX-a) con sus
## animaciones dedicadas, caminando y girando por las 4 direcciones.

const DISPLAY_SIZE: int = 224
const TURN_SECONDS: float = 1.6
const TURN_ORDER := ["front", "right", "back", "left"]

@export var auto_turn: bool = true

var _appearance: CharacterAppearance = CharacterAppearance.new()
var _sprite: AnimatedSprite2D
var _turn_idx: int = 0
var _turn_time: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(DISPLAY_SIZE, DISPLAY_SIZE)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	var legacy := get_node_or_null("Sprite")
	if legacy:
		legacy.visible = false
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Body"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	refresh()


func set_appearance(appearance: CharacterAppearance) -> void:
	_appearance = appearance.duplicate_appearance()
	refresh()


func refresh() -> void:
	if _sprite == null:
		return
	_sprite.sprite_frames = CharacterSprites.build_frames(_appearance.get_preset_id())
	_apply_facing()
	_layout()


func _apply_facing() -> void:
	var facing: String = TURN_ORDER[_turn_idx]
	_sprite.flip_h = CharacterSprites.is_flipped(facing)
	var anim := "walk_%s" % CharacterSprites.dir_for_facing(facing)
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


func _layout() -> void:
	# escala entera para que el pixel art se vea nítido (lienzo de 128 px con pies en y=124)
	var s: float = maxf(1.0, floorf((DISPLAY_SIZE - 16.0) / CharacterSprites.CHARACTER_HEIGHT))
	_sprite.scale = Vector2(s, s)
	var cx: float = round(size.x * 0.5) if size.x > 0 else DISPLAY_SIZE * 0.5
	var feet_y: float = (size.y if size.y > 0 else DISPLAY_SIZE) - 8.0
	_sprite.position = Vector2(cx, feet_y) + CharacterSprites.FOOT_OFFSET * s


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _sprite:
		_layout()


func _process(delta: float) -> void:
	if not auto_turn or _sprite == null:
		return
	_turn_time += delta
	if _turn_time >= TURN_SECONDS:
		_turn_time = 0.0
		_turn_idx = (_turn_idx + 1) % TURN_ORDER.size()
		_apply_facing()
