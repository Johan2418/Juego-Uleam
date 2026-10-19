extends Control
## Pantalla de creación: nombre + look + clase.

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var title_label: Label = %TitleLabel
@onready var name_edit: LineEdit = %NameEdit
@onready var preview: CharacterPreview = %CharacterPreview

@onready var look_label: Label = %LookValue
@onready var class_label: Label = %ClassValue
@onready var confirm_button: Button = %ConfirmButton
@onready var status_label: Label = %StatusLabel

var _draft: CharacterAppearance = CharacterAppearance.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_draft = GameState.appearance.duplicate_appearance()
	if _draft.student_name.strip_edges() == "":
		_draft.student_name = "Estudiante"
	name_edit.text = _draft.student_name
	name_edit.text_changed.connect(_on_name_changed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	_hide_legacy_rows()
	_clamp_playable_cast()
	_wire_cycle_buttons("LookPrev", "LookNext", _on_look_prev, _on_look_next)
	_wire_cycle_buttons("ClassPrev", "ClassNext", _on_class_prev, _on_class_next)
	_refresh_labels()
	_refresh_preview()
	status_label.text = ""
	title_label.text = "Crea tu universitario"
	var subtitle := get_node_or_null("%Subtitle") as Label
	if subtitle == null:
		subtitle = find_child("Subtitle", true, false) as Label
	if subtitle:
		subtitle.text = "Elige personaje (%d) y clase" % CharacterAppearance.preset_count()
	# mando: la cruceta/stick mueve el foco entre botones, A pulsa, Start confirma
	var first := find_child("LookNext", true, false) as Control
	if first and Input.get_connected_joypads().size() > 0:
		first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if confirm_button.disabled:
		return
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_START:
				get_viewport().set_input_as_handled()
				_on_confirm_pressed()
			JOY_BUTTON_LEFT_SHOULDER:
				get_viewport().set_input_as_handled()
				_on_look_prev()
			JOY_BUTTON_RIGHT_SHOULDER:
				get_viewport().set_input_as_handled()
				_on_look_next()
			_:
				# si nada tiene el foco, dárselo al primer botón para poder navegar
				if get_viewport().gui_get_focus_owner() == null:
					var first := find_child("LookNext", true, false) as Control
					if first:
						first.grab_focus()


func _wire_cycle_buttons(prev_name: String, next_name: String, prev_cb: Callable, next_cb: Callable) -> void:
	var look_prev := find_child(prev_name, true, false) as Button
	var look_next := find_child(next_name, true, false) as Button
	if look_prev and not look_prev.pressed.is_connected(prev_cb):
		look_prev.pressed.connect(prev_cb)
	if look_next and not look_next.pressed.is_connected(next_cb):
		look_next.pressed.connect(next_cb)


func _hide_legacy_rows() -> void:
	for row_name in ["SkinRow", "HairStyleRow", "HairColorRow", "OutfitRow", "AccessoryRow"]:
		var row := find_child(row_name, true, false) as CanvasItem
		if row:
			row.visible = false


func _on_name_changed(new_text: String) -> void:
	_draft.student_name = new_text.strip_edges()
	if _draft.student_name.is_empty():
		_draft.student_name = "Estudiante"


func _refresh_labels() -> void:
	if look_label:
		look_label.text = _draft.get_preset_label()
	if class_label:
		class_label.text = _draft.get_class_label()


func _refresh_preview() -> void:
	if preview:
		preview.set_appearance(_draft)


func _clamp_playable_cast() -> void:
	_draft.look_preset = clampi(_draft.look_preset, 0, CharacterAppearance.preset_count() - 1)
	_apply_named_preset_name()


func _cycle(current: int, size: int, delta: int) -> int:
	return posmod(current + delta, size)


func _on_look_prev() -> void:
	_draft.look_preset = _cycle(_draft.look_preset, CharacterAppearance.preset_count(), -1)
	_apply_named_preset_name()
	_refresh_labels()
	_refresh_preview()


func _on_look_next() -> void:
	_draft.look_preset = _cycle(_draft.look_preset, CharacterAppearance.preset_count(), 1)
	_apply_named_preset_name()
	_refresh_labels()
	_refresh_preview()


func _on_class_prev() -> void:
	_draft.set_class_index(_cycle(_draft.get_class_index(), CharacterAppearance.CLASSES.size(), -1))
	_refresh_labels()


func _on_class_next() -> void:
	_draft.set_class_index(_cycle(_draft.get_class_index(), CharacterAppearance.CLASSES.size(), 1))
	_refresh_labels()


func _apply_named_preset_name() -> void:
	var suggested: String = _draft.get_preset_default_name()
	if suggested.is_empty():
		return
	# Respetar un nombre escrito a mano; solo reemplazar nombres automáticos.
	if not CharacterAppearance.is_auto_name(_draft.student_name):
		return
	_draft.student_name = suggested
	if name_edit:
		name_edit.text = suggested


func _on_confirm_pressed() -> void:
	_on_name_changed(name_edit.text)
	GameState.confirm_and_save(_draft)
	status_label.text = "¡Guardado! Entrando al patio..."
	confirm_button.disabled = true
	await get_tree().create_timer(0.35).timeout
	get_tree().change_scene_to_file(MAIN_SCENE)
