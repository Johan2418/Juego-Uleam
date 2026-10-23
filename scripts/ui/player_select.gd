extends Control
## Selección de personaje estilo Mega Man X4: un panel inclinado por personaje con su retrato
## grande, su nombre en cursiva y el sprite del juego en la esquina. Cada jugador mueve su
## cursor (P1 azul, P2 amarillo), elige personaje y después CLASE (Guerrero / Mago / Chain: el
## sprite pequeño hace el ataque de esa clase). Cuando todos están LISTOS -> sala de entrenamiento.
## En 2 jugadores, el jugador 2 se une pulsando A / J desde otro mando o el teclado.
## Retratos: assets/sprites/portraits/<id>_select_hd.png (grokbot) o <id>_select.png (provisional).
## Escena: scenes/player_select.tscn.

const Style := preload("res://scripts/ui/ui_style.gd")
const InputSetup := preload("res://scripts/input_setup.gd")
const TRAINING_SCENE := "res://scenes/training.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const PORTRAIT := "res://assets/sprites/portraits/%s_select%s.png"

const CLASSES := [
	{"id": "guerrero", "label": "GUERRERO", "col": Color(1.0, 0.45, 0.25),
		"desc": "Espada. Combos cuerpo a cuerpo y contraataques potentes."},
	{"id": "mago", "label": "MAGO", "col": Color(0.45, 0.6, 1.0),
		"desc": "Hechizos a distancia. Controla el campo desde lejos."},
	{"id": "chain", "label": "CHAIN", "col": Color(0.4, 1.0, 0.6),
		"desc": "Cadena-látigo. Alcance medio y combos muy rápidos."},
]
## Colores del marco de cada panel (como los de X y Zero) y de cada jugador.
const PANEL_COLS := [Color(0.45, 0.2, 0.95), Color(0.8, 0.25, 0.6), Color(0.2, 0.6, 0.9), Color(0.9, 0.5, 0.2)]
const PLAYER_COLS := [Color(0.35, 0.75, 1.0), Color(1.0, 0.82, 0.2)]
const TOP := 78.0
const BOTTOM := 604.0
const SLANT := 70.0

var _chars: Array = []         # entradas del catálogo
var _panels: Array = []        # CharPanel
## Estado de cada jugador: {joined, device, cursor, cls, step ("char"|"class"|"ready")}
var _pl: Array = []
var _t := 0.0
var _going := false
var _hud: Overlay


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chars = CharacterCatalog.list()
	var bg := Background.new()
	bg.screen = self
	add_child(bg)
	var n := maxi(1, _chars.size())
	var gap := 18.0
	var w := (1280.0 - 60.0 - gap * (n - 1) + SLANT * (n - 1)) / n
	for i in _chars.size():
		var p := CharPanel.new()
		p.screen = self
		p.index = i
		p.entry = _chars[i]
		p.rect = Rect2(30.0 + i * (w + gap - SLANT), TOP, w, BOTTOM - TOP)
		p.col = PANEL_COLS[i % PANEL_COLS.size()]
		add_child(p)
		_panels.append(p)
	var a1: CharacterAppearance = GameState.appearance
	var c1 := maxi(0, CharacterCatalog.index_of(a1.get_preset_id()))
	_pl = [
		{"joined": true, "device": int(GameState.devices[0]) if GameState.coop else -2, "cursor": c1, "cls": _cls_index(a1.class_id), "step": "char"},
	]
	if GameState.coop:
		_pl.append({"joined": false, "device": -9, "cursor": mini(1, _chars.size() - 1), "cls": 0, "step": "char"})
	_hud = Overlay.new()
	_hud.screen = self
	add_child(_hud)
	modulate = Color.BLACK
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.4)


func _cls_index(id: String) -> int:
	for i in CLASSES.size():
		if CLASSES[i]["id"] == id:
			return i
	return 0


func _process(delta: float) -> void:
	_t += delta


## Qué jugador manda este evento (-1 = ninguno).
func _owner(ev: InputEvent) -> int:
	var dev := InputSetup.event_device(ev)
	if dev == -9:
		return -1
	if not GameState.coop:
		return 0
	for i in _pl.size():
		if _pl[i]["joined"] and int(_pl[i]["device"]) == dev:
			return i
	return -1


func _input(event: InputEvent) -> void:
	if _going or event.is_echo():
		return
	var who := _owner(event)
	# el jugador 2 se une con A / J / Enter desde un dispositivo libre
	if who < 0 and GameState.coop and _pl.size() > 1 and not _pl[1]["joined"]:
		if _is_confirm(event) or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START):
			var dev := InputSetup.event_device(event)
			if dev != -9 and dev != int(_pl[0]["device"]):
				_pl[1]["joined"] = true
				_pl[1]["device"] = dev
				_hud.pop(1)
				get_viewport().set_input_as_handled()
		return
	if who < 0:
		return
	var p: Dictionary = _pl[who]
	var dx := 0
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		dx = -1
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		dx = 1
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		dx = -1 if p["step"] == "class" else 0
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		dx = 1 if p["step"] == "class" else 0
	if dx != 0:
		if p["step"] == "char":
			p["cursor"] = (int(p["cursor"]) + dx + _chars.size()) % _chars.size()
			_hud.pop(who)
		elif p["step"] == "class":
			p["cls"] = (int(p["cls"]) + dx + CLASSES.size()) % CLASSES.size()
			_hud.pop(who)
		get_viewport().set_input_as_handled()
		return
	if _is_confirm(event):
		match p["step"]:
			"char":
				p["step"] = "class"
				(_panels[int(p["cursor"])] as CharPanel).flash = 1.0
			"class":
				p["step"] = "ready"
				(_panels[int(p["cursor"])] as CharPanel).flash = 1.0
				_check_all_ready()
		_hud.pop(who)
		get_viewport().set_input_as_handled()
	elif _is_back(event):
		match p["step"]:
			"ready":
				p["step"] = "class"
			"class":
				p["step"] = "char"
			"char":
				if who == 1:
					p["joined"] = false
					p["device"] = -9
				else:
					_leave(TITLE_SCENE)
		get_viewport().set_input_as_handled()


func _is_confirm(ev: InputEvent) -> bool:
	if ev.is_action_pressed("interact") or ev.is_action_pressed("action_primary") or ev.is_action_pressed("ui_accept"):
		return true
	return ev is InputEventJoypadButton and ev.pressed and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_START


func _is_back(ev: InputEvent) -> bool:
	if ev.is_action_pressed("back") or ev.is_action_pressed("roll") or ev.is_action_pressed("ui_cancel"):
		return true
	return ev is InputEventJoypadButton and ev.pressed and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_B


func _check_all_ready() -> void:
	for p in _pl:
		if not p["joined"] or p["step"] != "ready":
			return
	_going = true
	# guarda lo elegido
	var a1: CharacterAppearance = GameState.appearance.duplicate_appearance()
	a1.look_preset = int(_pl[0]["cursor"])
	a1.class_id = str(CLASSES[int(_pl[0]["cls"])]["id"])
	GameState.confirm_and_save(a1)
	if GameState.coop:
		var a2 := CharacterAppearance.new()
		a2.student_name = "Jugador 2"
		a2.look_preset = int(_pl[1]["cursor"])
		a2.class_id = str(CLASSES[int(_pl[1]["cls"])]["id"])
		GameState.appearance2 = a2
		GameState.setup_coop(true, int(_pl[0]["device"]), int(_pl[1]["device"]))
	_hud.go = 1.0
	await get_tree().create_timer(1.1).timeout
	_leave(TRAINING_SCENE)


func _leave(scene: String) -> void:
	_going = true
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.BLACK, 0.45)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(scene))


## Jugadores cuyo cursor está sobre el panel i.
func cursors_on(i: int) -> Array:
	var out: Array = []
	for k in _pl.size():
		if _pl[k]["joined"] and int(_pl[k]["cursor"]) == i:
			out.append(k)
	return out


# ==================================================================================
## Fondo: rejilla verde que se desplaza en diagonal (como el de X4) con franjas.
class Background extends Node2D:
	var screen: Node

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t: float = screen.get("_t")
		for i in 36:
			var k := i / 35.0
			draw_rect(Rect2(0, i * 20, 1280, 21), Color(0.08, 0.22, 0.12).lerp(Color(0.18, 0.36, 0.16), sin(k * PI)))
		var off := fmod(t * 30.0, 48.0)
		for i in 60:
			var x := -720.0 + i * 48.0 + off
			draw_line(Vector2(x, 0), Vector2(x + 720, 720), Color(1, 1, 1, 0.035), 10)
		for y in range(0, 720, 24):
			draw_line(Vector2(0, y), Vector2(1280, y), Color(0, 0, 0, 0.06), 1)


## CharPanel inclinado de un personaje.
class CharPanel extends Node2D:
	var screen: Node
	var index := 0
	var entry: Dictionary
	var rect: Rect2
	var col: Color
	var flash := 0.0
	var _clip: Polygon2D
	var _portrait: Sprite2D
	var _mini: AnimatedSprite2D
	var _mini_cls := -1
	var _hover := 0.0

	func _ready() -> void:
		var poly := Style.slanted(rect, SLANT)
		_clip = Polygon2D.new()
		_clip.polygon = poly
		_clip.color = Color(0.12, 0.3, 0.16)
		_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		_clip.show_behind_parent = true   # el marco, el nombre y las etiquetas P1/P2 van encima
		add_child(_clip)
		# rayos de fondo dentro del panel
		var rays := Rays.new()
		rays.panel = self
		_clip.add_child(rays)
		var id := str(entry.get("id", ""))
		var tex: Texture2D = null
		for suf in ["_hd", ""]:
			var path := PORTRAIT % [id, suf]
			if ResourceLoader.exists(path):
				tex = load(path)
				break
		if tex:
			_portrait = Sprite2D.new()
			_portrait.texture = tex
			var s := (rect.size.y * 0.98) / tex.get_size().y
			if suf_is_hd(id):
				s = (rect.size.y * 1.05) / tex.get_size().y
			_portrait.scale = Vector2(s, s)
			_portrait.position = rect.get_center() + Vector2(0, rect.size.y * 0.03)
			_clip.add_child(_portrait)
		_mini = AnimatedSprite2D.new()
		_mini.sprite_frames = CharacterSprites.build_frames(id)
		_mini.scale = Vector2(1.6, 1.6)
		_mini.position = Vector2(rect.end.x - SLANT - 70, rect.end.y - 36) + CharacterSprites.FOOT_OFFSET * 1.6
		add_child(_mini)
		# las animaciones de ataque no son en bucle (y son las mismas del juego): se repiten a mano
		_mini.animation_finished.connect(func() -> void:
			if _mini_cls >= 0:
				get_tree().create_timer(0.35).timeout.connect(func() -> void:
					if is_instance_valid(_mini) and _mini_cls >= 0:
						_mini.frame = 0
						_mini.play()))
		_play_mini("idle_down")

	func suf_is_hd(id: String) -> bool:
		return ResourceLoader.exists(PORTRAIT % [id, "_hd"])

	func _play_mini(name: String) -> void:
		if _mini.sprite_frames and _mini.sprite_frames.has_animation(name):
			if _mini.animation != name:
				_mini.play(name)

	func _process(delta: float) -> void:
		flash = maxf(0.0, flash - delta * 3.0)
		var on: Array = screen.call("cursors_on", index)
		_hover = move_toward(_hover, 1.0 if not on.is_empty() else 0.0, delta * 6.0)
		var dim := 0.45 + 0.55 * _hover
		_clip.modulate = Color(dim, dim, dim)
		if _portrait:
			_portrait.position.y = rect.get_center().y + rect.size.y * 0.03 + sin(float(screen.get("_t")) * 1.5 + index) * 2.0 * _hover
		# el sprite pequeño muestra la clase que está eligiendo (o reposo)
		var cls := -1
		for k in on:
			var p: Dictionary = screen.get("_pl")[k]
			if p["step"] != "char":
				cls = int(p["cls"])
		if cls != _mini_cls:
			_mini_cls = cls
			if cls < 0:
				_play_mini("idle_down")
			else:
				var cid: String = CLASSES[cls]["id"]
				var picked := false
				for nm in ["%s_special_down" % cid, "%s_finisher_down" % cid, "%s_down" % CharacterSprites.COMBO_BASES.get(cid, ""), "%s_attack_1_down" % cid, "%s_cast_1_down" % cid, "%s_whip_1_down" % cid]:
					if _mini.sprite_frames.has_animation(nm):
						_mini.play(nm)
						picked = true
						break
				if not picked:
					_play_mini("walk_down")
		queue_redraw()

	func _draw() -> void:
		var poly := Style.slanted(rect, SLANT)
		var on: Array = screen.call("cursors_on", index)
		var t: float = screen.get("_t")
		# marco grueso del color del personaje; con cursor, del color del jugador y latiendo
		var frame := col.darkened(0.35).lerp(col, _hover)
		var width := 12.0
		var closed := poly + PackedVector2Array([poly[0]])
		draw_polyline(closed, Color(0, 0, 0, 0.6), width + 6)
		draw_polyline(closed, frame, width)
		draw_polyline(closed, frame.lightened(0.35), 2.0)
		if not on.is_empty():
			var pc: Color = PLAYER_COLS[on[0]]
			var a := 0.55 + 0.45 * sin(t * 8.0)
			draw_polyline(Style.slanted(rect.grow(9), SLANT) + PackedVector2Array([Style.slanted(rect.grow(9), SLANT)[0]]), Color(pc, a), 4.0)
			if on.size() > 1:
				var pc2: Color = PLAYER_COLS[on[1]]
				draw_polyline(Style.slanted(rect.grow(15), SLANT) + PackedVector2Array([Style.slanted(rect.grow(15), SLANT)[0]]), Color(pc2, 1.0 - a * 0.5), 4.0)
		if flash > 0.0:
			draw_colored_polygon(poly, Color(1, 1, 1, flash * 0.5))
		# nombre en grande, abajo a la izquierda (como "MEGAMAN X")
		var label := str(entry.get("label", entry.get("id", ""))).to_upper()
		Style.title(self, Vector2(rect.position.x + 34, rect.end.y - 22), label, 52, Color.WHITE, Color(0.05, 0.03, 0.12), HORIZONTAL_ALIGNMENT_LEFT, -1)
		# etiquetas P1 / P2 arriba del panel
		for j in on.size():
			var k: int = on[j]
			var pc3: Color = PLAYER_COLS[k]
			var bx := rect.position.x + SLANT + 30 + j * 86
			var by := rect.position.y + 14 + sin(t * 5.0 + k) * 3.0
			draw_colored_polygon(Style.slanted(Rect2(bx, by, 76, 34), 10), Color(0.04, 0.03, 0.1, 0.9))
			draw_polyline(Style.slanted(Rect2(bx, by, 76, 34), 10) + PackedVector2Array([Style.slanted(Rect2(bx, by, 76, 34), 10)[0]]), pc3, 3.0)
			Style.title(self, Vector2(bx + 38, by + 28), "P%d" % (k + 1), 28, pc3, Color(0.04, 0.03, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 76)


## Rayos de luz que giran detrás del retrato.
class Rays extends Node2D:
	var panel: Node

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r: Rect2 = panel.get("rect")
		var c := r.get_center() + Vector2(0, -60)
		var t: float = panel.get("screen").get("_t")
		var col: Color = panel.get("col")
		draw_rect(r.grow(80), Color(0.1, 0.22, 0.14))
		for i in 14:
			var a := t * 0.25 + i * TAU / 14.0
			var d1 := Vector2.from_angle(a)
			var d2 := Vector2.from_angle(a + 0.16)
			draw_colored_polygon(PackedVector2Array([c, c + d1 * 900, c + d2 * 900]), Color(col.lightened(0.3), 0.12))
		draw_circle(c, 140, Color(1, 1, 1, 0.05))


## Títulos de arriba/abajo, clase de cada jugador, "únete" y "¡LISTOS!".
class Overlay extends Node2D:
	var screen: Node
	var go := 0.0
	var _pops := [0.0, 0.0]

	func pop(i: int) -> void:
		_pops[i] = 1.0

	func _process(delta: float) -> void:
		for i in 2:
			_pops[i] = maxf(0.0, _pops[i] - delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		var t: float = screen.get("_t")
		Style.title(self, Vector2(640, 60), "ELIGE TU PERSONAJE", 50, Color(1.0, 0.9, 0.2), Color(0.12, 0.08, 0.02), HORIZONTAL_ALIGNMENT_CENTER, 1100)
		var hint := "Técnicas: CASILLERO del entrenamiento y del salón"
		Style.title(self, Vector2(1262 - Style.text_w(hint, 13), 30), hint, 13, Color(0.85, 0.9, 1.0), Color(0.03, 0.03, 0.06), HORIZONTAL_ALIGNMENT_LEFT, -1, 0.0)
		var pl: Array = screen.get("_pl")
		var coop: bool = GameState.coop
		for k in pl.size():
			var p: Dictionary = pl[k]
			var pc: Color = PLAYER_COLS[k]
			# caja de cada jugador abajo (izquierda P1, derecha P2)
			var w := 600.0
			var x := 24.0 if k == 0 else 1280.0 - 24.0 - w
			if not coop:
				x = 340.0
			var r := Rect2(x, 616, w, 92).grow(3.0 * _pops[k])
			draw_colored_polygon(Style.slanted(r, 22), Color(0.03, 0.03, 0.08, 0.92))
			draw_polyline(Style.slanted(r, 22) + PackedVector2Array([Style.slanted(r, 22)[0]]), pc, 3.0)
			if not p["joined"]:
				if fmod(t, 1.0) < 0.7:
					Style.title(self, Vector2(r.get_center().x, r.position.y + 56), "P2: PULSA  A / J  PARA UNIRTE", 28, pc, Color(0.04, 0.03, 0.1), HORIZONTAL_ALIGNMENT_CENTER, w)
				continue
			var tag := "P%d" % (k + 1) if coop else "P1"
			Style.title(self, Vector2(r.position.x + 40, r.position.y + 38), tag, 30, pc, Color(0.04, 0.03, 0.1), HORIZONTAL_ALIGNMENT_LEFT, -1)
			var step: String = p["step"]
			if step == "char":
				Style.title(self, Vector2(r.position.x + 110, r.position.y + 38), "◄  PERSONAJE  ►", 26, Color.WHITE, Color(0.04, 0.03, 0.1), HORIZONTAL_ALIGNMENT_LEFT, -1, 0.0)
				Style.title(self, Vector2(r.position.x + 110, r.position.y + 72), "A / J confirmar", 18, Color(0.75, 0.8, 0.9), Color(0.04, 0.03, 0.1), HORIZONTAL_ALIGNMENT_LEFT, -1, 0.0)
			else:
				# pestañas de clase
				var ci: int = p["cls"]
				for i in CLASSES.size():
					var cc: Dictionary = CLASSES[i]
					var tr := Rect2(r.position.x + 100 + i * 150, r.position.y + 10, 140, 36)
					var on := i == ci
					draw_colored_polygon(Style.slanted(tr, 12), Color(cc["col"], 0.85) if on else Color(0.15, 0.15, 0.22, 0.9))
					Style.title(self, Vector2(tr.get_center().x, tr.position.y + 28), str(cc["label"]), 22 if on else 18,
						Color.WHITE if on else Color(0.6, 0.6, 0.7), Color(0.04, 0.03, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 140, -0.1)
				if step == "ready":
					Style.title(self, Vector2(r.position.x + w * 0.5 + 40, r.position.y + 78), "¡LISTO!", 30, Color(1.0, 0.9, 0.3), Color(0.12, 0.06, 0.02), HORIZONTAL_ALIGNMENT_CENTER, 300)
				else:
					Style.title(self, Vector2(r.position.x + 104, r.position.y + 74), str(CLASSES[ci]["desc"]), 17, Color(0.85, 0.9, 1.0), Color(0.04, 0.03, 0.1), HORIZONTAL_ALIGNMENT_LEFT, -1, 0.0)
		if go > 0.0:
			go = minf(1.0, go + 0.02)
			draw_rect(Rect2(0, 300, 1280, 120), Color(0, 0, 0, 0.75))
			Style.title(self, Vector2(640, 385), "¡A ENTRENAR!" if not coop else "¡LISTOS!  ¡A ENTRENAR!", 64, Color(1.0, 0.9, 0.2), Color(0.12, 0.06, 0.02), HORIZONTAL_ALIGNMENT_CENTER, 1200)
