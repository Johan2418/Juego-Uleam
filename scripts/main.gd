extends Control
## Pantalla de aterrizaje post-creador: muestra el personaje elegido.

@onready var title_label: Label = %TitleLabel
@onready var summary_label: Label = %SummaryLabel
@onready var preview: CharacterPreview = %CharacterPreview
@onready var recreate_button: Button = %RecreateButton


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_label.text = "Bienvenido al campus"
	summary_label.text = GameState.get_summary_text()
	if preview:
		preview.set_appearance(GameState.appearance)
	recreate_button.pressed.connect(_on_recreate)


func _on_recreate() -> void:
	get_tree().change_scene_to_file("res://scenes/character_creator.tscn")
