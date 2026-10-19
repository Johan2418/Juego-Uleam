extends Node2D
## Patio del campus — prototipo de combate por clases.

@onready var hud_name: Label = %HudName
@onready var hud_class: Label = %HudClass
@onready var hud_hint: Label = %HudHint
@onready var player: CharacterBody2D = %Player

const DOOR2_POS := Vector2(300, -262)
const DOOR3_POS := Vector2(-300, -262)
## La cuarta puerta va abajo (las de arriba ya están llenas).
const DOOR4_POS := Vector2(-300, 290)
const DOOR5_POS := Vector2(300, 290)
const DOOR6_POS := Vector2(0, 290)
## La séptima va en la pared izquierda.
const DOOR7_POS := Vector2(-410, 10)
## La octava, en la pared derecha.
const DOOR8_POS := Vector2(410, 10)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_input_map()
	var app := GameState.appearance
	if hud_name:
		hud_name.text = app.student_name
	if hud_class:
		hud_class.text = "Clase: %s  |  Look: %s" % [app.get_class_label(), app.get_preset_label()]
	_update_hint()
	if player and player.has_method("_ready"):
		pass
	# puerta grande al Salón de las Facultades (ahí están las estatuas de los 8 bosses)
	var hall := HallDoor.new()
	hall.position = Vector2(0, -262)
	add_child(hall)


func _ensure_input_map() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("action_primary", [KEY_J])
	_add_key_action("action_secondary", [KEY_K])
	_add_mouse_action("action_primary", MOUSE_BUTTON_LEFT)
	_add_mouse_action("action_secondary", MOUSE_BUTTON_RIGHT)


func _add_key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = k
		if not _action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


func _add_mouse_action(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	if not _action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


func _action_has_event(action: String, ev: InputEvent) -> bool:
	for existing in InputMap.action_get_events(action):
		if existing.as_text() == ev.as_text():
			return true
		if existing is InputEventKey and ev is InputEventKey:
			if existing.keycode == ev.keycode:
				return true
		if existing is InputEventMouseButton and ev is InputEventMouseButton:
			if existing.button_index == ev.button_index:
				return true
	return false


var _hint_pad := -1

func _process(_delta: float) -> void:
	if int(GameState.using_pad) != _hint_pad:
		_update_hint()


## Ayuda de controles abajo; cambia sola entre teclado y mando.
func _update_hint() -> void:
	_hint_pad = int(GameState.using_pad)
	if hud_hint == null:
		return
	var b := func(a: String) -> String: return GameState.btn(a)
	hud_hint.text = "%s mover · %s combo (x3) · %s especial · %s parry (luego %s = contraataque) · %s ultimate · %s rodar (mantén = correr) · %s fijar objetivo · %s creador" % [
		b.call("move"), b.call("action_primary"), b.call("action_secondary"), b.call("parry"),
		b.call("action_primary"), b.call("ultimate"), b.call("roll"), b.call("lock_on"), b.call("back")]
	if not GameState.using_pad:
		hud_hint.text += " · F1 llenar ultimate"


## Puerta grande al Salón de las Facultades: acercarse y pulsar E.
class HallDoor extends Area2D:
	const HALL_SCENE := "res://scenes/combat/boss_hall.tscn"
	var _inside := false
	var _going := false
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1
		monitoring = true
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(170, 80)
		cs.shape = r
		cs.position = Vector2(0, 24)
		add_child(cs)
		body_entered.connect(_on_body.bind(true))
		body_exited.connect(_on_body.bind(false))

	func _on_body(b: Node, inside: bool) -> void:
		if b.is_in_group("player"):
			_inside = inside

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _unhandled_input(event: InputEvent) -> void:
		if _inside and not _going and event.is_action_pressed("interact") and not event.is_echo():
			get_viewport().set_input_as_handled()
			_going = true
			var hall_script = load("res://scripts/combat/boss_hall.gd")
			hall_script.last_kind = ""
			var layer := CanvasLayer.new()
			layer.layer = 20
			get_tree().current_scene.add_child(layer)
			var fade := ColorRect.new()
			fade.color = Color(0, 0, 0, 0)
			fade.size = Vector2(4000, 4000)
			fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(fade)
			var tw := fade.create_tween()
			tw.tween_property(fade, "color:a", 1.0, 0.6)
			tw.tween_callback(func() -> void: get_tree().change_scene_to_file(HALL_SCENE))

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var glow := 0.6 + 0.4 * absf(sin(_t * 1.6))
		# arco de piedra oscura con la luz que sale de adentro
		var pts := PackedVector2Array([Vector2(-62, 14)])
		for k in 13:
			var a := PI + PI * k / 12.0
			pts.append(Vector2(cos(a) * 62.0, -46.0 + sin(a) * 62.0))
		pts.append(Vector2(62, 14))
		var frame := PackedVector2Array([Vector2(-80, 16)])
		for k in 13:
			var a2 := PI + PI * k / 12.0
			frame.append(Vector2(cos(a2) * 80.0, -46.0 + sin(a2) * 80.0))
		frame.append(Vector2(80, 16))
		draw_colored_polygon(frame, Color(0.2, 0.19, 0.22))
		draw_colored_polygon(pts, Color(0.02, 0.02, 0.03))
		draw_polyline(frame.slice(1, frame.size() - 1), Color(0.6, 0.5, 0.28), 3.0)
		draw_polygon(PackedVector2Array([Vector2(-14, -100), Vector2(14, -100), Vector2(40, 14), Vector2(-40, 14)]),
			PackedColorArray([Color(0.85, 0.9, 1.0, 0.0), Color(0.85, 0.9, 1.0, 0.0), Color(0.85, 0.9, 1.0, 0.35 * glow), Color(0.85, 0.9, 1.0, 0.35 * glow)]))
		# ocho rombos: los bosses vencidos brillan en dorado
		var order: Array = ["deadbeef", "bsod", "div0", "syntax", "stack", "judge", "tex", "kp"]
		for i in order.size():
			var p := Vector2(-56 + i * 16, -118)
			var won := GameState.is_defeated(order[i])
			var c := Color(1.0, 0.82, 0.35) if won else Color(0.3, 0.3, 0.34)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), c)
		# letrero
		draw_rect(Rect2(-130, -150, 260, 22), Color(0.08, 0.08, 0.1))
		draw_rect(Rect2(-130, -150, 260, 22), Color(0.6, 0.5, 0.28), false, 1.5)
		draw_string(f, Vector2(-130, -134), "SALÓN DE LAS FACULTADES", HORIZONTAL_ALIGNMENT_CENTER, 260, 13, Color(0.95, 0.9, 0.75))
		if _inside and not _going:
			var y := -60.0 + sin(_t * 5.0) * 2.0   # al lado del arco (arriba lo tapa el panel del campus)
			draw_rect(Rect2(92, y, 120, 22), Color(0, 0, 0, 0.75))
			draw_string(f, Vector2(92, y + 16), "%s  entrar" % GameState.btn("interact"), HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 0.95, 0.5))


## (Antigua) puerta directa a un boss. Ya no se usa: ahora se entra desde el Salón de las Facultades.
class BossDoor extends Area2D:
	const ARENA_SCENE := "res://scenes/combat/boss_test.tscn"
	var kind := "deadbeef"
	var label := "0xDEADBEEF"
	var sub := "FATAL"
	var faculty := "Fac. Ciencias de la Vida y Tecnología"
	var glow_col := Color(1.0, 0.2, 0.15)
	var _inside := false
	var _going := false
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1
		monitoring = true
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(120, 70)
		cs.shape = r
		cs.position = Vector2(0, 20)
		add_child(cs)
		body_entered.connect(_on_body.bind(true))
		body_exited.connect(_on_body.bind(false))

	func _on_body(b: Node, inside: bool) -> void:
		if b.is_in_group("player"):
			_inside = inside

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _unhandled_input(event: InputEvent) -> void:
		if _inside and not _going and event.is_action_pressed("interact") and not event.is_echo():
			get_viewport().set_input_as_handled()
			_enter()

	func _enter() -> void:
		_going = true
		# entrar desde el campus siempre muestra la aparición y la presentación completas
		var arena_script = load("res://scripts/combat/boss_arena.gd")
		arena_script.retry = false
		arena_script.boss_kind = kind
		var layer := CanvasLayer.new()
		layer.layer = 20
		get_tree().current_scene.add_child(layer)
		var fade := ColorRect.new()
		fade.color = Color(0, 0, 0, 0)
		fade.size = Vector2(4000, 4000)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(fade)
		var tw := fade.create_tween()
		tw.tween_property(fade, "color:a", 1.0, 0.45)
		tw.tween_callback(func() -> void: get_tree().change_scene_to_file(ARENA_SCENE))

	func _draw() -> void:
		var glow := 0.55 + 0.45 * absf(sin(_t * 3.0))
		# marco y hueco de la puerta
		draw_rect(Rect2(-56, -60, 112, 70), Color(0.32, 0.3, 0.28))
		draw_rect(Rect2(-44, -50, 88, 60), Color(0.05, 0.03, 0.03))
		draw_rect(Rect2(-44, -50, 88, 60), Color(glow_col, glow), false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-44, -22), label, HORIZONTAL_ALIGNMENT_CENTER, 88, 12, Color(glow_col.lightened(0.1), glow))
		draw_string(ThemeDB.fallback_font, Vector2(-44, -6), sub, HORIZONTAL_ALIGNMENT_CENTER, 88, 10, Color(0.45, 1.0, 0.5, glow))
		# letrero
		draw_rect(Rect2(-110, -84, 220, 20), Color(0.12, 0.14, 0.12))
		draw_string(ThemeDB.fallback_font, Vector2(-110, -70), faculty, HORIZONTAL_ALIGNMENT_CENTER, 220, 11, Color(0.9, 0.9, 0.8))
		if _inside and not _going:
			var y := -112.0 + sin(_t * 5.0) * 2.0   # encima del letrero (el jugador tapa la puerta)
			draw_rect(Rect2(-62, y, 124, 20), Color(0, 0, 0, 0.75))
			draw_string(ThemeDB.fallback_font, Vector2(-62, y + 14), "%s  entrar (boss)" % GameState.btn("interact"), HORIZONTAL_ALIGNMENT_CENTER, 124, 12, Color(1, 0.95, 0.5))
