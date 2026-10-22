extends Control
## Menú del personaje: nombre, personaje, clase y técnicas equipadas (una por ranura).
## Es la pantalla de inicio (scenes/character_creator.tscn) y también se abre desde el
## Salón de las Facultades para cambiar la build antes de un boss.
##
## Izquierda: retrato grande del personaje bajo un foco. Si existe el retrato detallado
## assets/sprites/portraits/<personaje>_<clase>.png (generado con Grok) se usa ese; si no,
## el sprite del juego ampliado, que hace la pose de su clase al cambiarla.
## Derecha: clase y las 3 ranuras (combo / especial / ultimate) con lo que hace cada técnica.
##
## Controles: ↑↓ elegir fila · ←→ cambiar · Enter / A confirmar · Esc / B volver.

const Tech := preload("res://scripts/combat/techniques.gd")
const Arena := preload("res://scripts/combat/boss_arena.gd")
const PORTRAIT_DIR := "res://assets/sprites/portraits/%s_%s.png"
const CAMPUS_SCENE := "res://scenes/main.tscn"

## A dónde vuelve al confirmar ("" = al campus). El salón lo pone antes de abrir el menú.
static var return_scene: String = ""

const CLASS_INFO := {
	"guerrero": {"color": Color(1.0, 0.72, 0.3), "role": "Cuerpo a cuerpo. Golpes fuertes y una embestida que empuja."},
	"mago": {"color": Color(0.45, 0.7, 1.0), "role": "A distancia. Orbes, abanicos y una tormenta de rayos."},
	"chain": {"color": Color(0.35, 0.9, 0.8), "role": "Alcance medio. Latigazos largos que atraen al enemigo."},
}
const ROWS := ["name", "look", "class", "combo", "special", "ultimate", "confirm"]

const BG := Color(0.035, 0.04, 0.06)
const PANEL := Color(0.075, 0.08, 0.11)
const LINE := Color(0.26, 0.24, 0.2)
const GOLD := Color(0.86, 0.74, 0.46)
const TEXT := Color(0.92, 0.91, 0.87)
const DIM := Color(0.56, 0.56, 0.6)

var _draft: CharacterAppearance
## Técnica elegida (aún sin guardar) por clase y ranura.
var _picks: Dictionary = {}
var _row := 2
var _t := 0.0
var _flash := 0.0
var _toast := ""
var _toast_t := 0.0

var _portrait_tex: TextureRect
var _sprite: AnimatedSprite2D
var _sprite_holder: Control
var _name_edit: LineEdit
var _canvas: Control
var _labels: Dictionary = {}
var _hit_rects: Array = []      # [Rect2, row, delta]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_draft = GameState.appearance.duplicate_appearance()
	if _draft.student_name.strip_edges() == "":
		_draft.student_name = "Estudiante"
	_draft.look_preset = clampi(_draft.look_preset, 0, CharacterAppearance.preset_count() - 1)
	for c in CharacterAppearance.CLASSES:
		var cid := str(c["id"])
		_picks[cid] = {}
		for slot in Tech.SLOTS:
			_picks[cid][slot] = GameState.equipped(cid, slot)
	_build()
	_refresh_character(true)


# ---------------------------------------------------------------------------------
func _build() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_paint)
	add_child(_canvas)
	# retrato: textura detallada (si existe) o sprite del juego ampliado
	_portrait_tex = TextureRect.new()
	_portrait_tex.position = Vector2(60, 70)
	_portrait_tex.size = Vector2(420, 470)
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_tex)
	_sprite_holder = Control.new()
	_sprite_holder.position = Vector2(270, 520)
	_sprite_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite_holder)
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	_sprite.scale = Vector2(4, 4)
	_sprite.position = Vector2(0, CharacterSprites.FOOT_OFFSET.y * 4.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.animation_finished.connect(_on_pose_done)
	_sprite_holder.add_child(_sprite)
	# nombre (editable)
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(110, 572)
	_name_edit.size = Vector2(320, 40)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.max_length = 18
	_name_edit.text = _draft.student_name
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.add_theme_color_override("font_color", TEXT)
	_name_edit.add_theme_color_override("caret_color", GOLD)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	_name_edit.add_theme_stylebox_override("normal", sb)
	_name_edit.add_theme_stylebox_override("focus", sb)
	_name_edit.text_changed.connect(func(tx: String) -> void:
		_draft.student_name = tx.strip_edges() if tx.strip_edges() != "" else "Estudiante")
	_name_edit.text_submitted.connect(func(_tx: String) -> void:
		_name_edit.release_focus()
		_row = 1)
	_name_edit.focus_entered.connect(func() -> void: _row = 0)
	add_child(_name_edit)


func _refresh_character(first: bool = false) -> void:
	var id := _draft.get_preset_id()
	var path := PORTRAIT_DIR % [id, _draft.class_id]
	if ResourceLoader.exists(path):
		_portrait_tex.texture = load(path)
		_portrait_tex.visible = true
		_sprite_holder.visible = false
	else:
		_portrait_tex.visible = false
		_sprite_holder.visible = true
		_sprite.sprite_frames = CharacterSprites.build_frames(id)
		# al cambiar de clase hace la pose de la clase (su especial) y vuelve al reposo
		var pose := "%s_special_down" % _draft.class_id
		if not first and _sprite.sprite_frames.has_animation(pose):
			_sprite.play(pose)
		else:
			_play_idle()
	_flash = 1.0


func _play_idle() -> void:
	for a in ["idle_down", "walk_down"]:
		if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(a):
			_sprite.play(a)
			return


func _on_pose_done() -> void:
	_play_idle()


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	_toast_t = maxf(0.0, _toast_t - delta)
	_canvas.queue_redraw()


# --- Entrada -----------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if _name_edit.has_focus():
		if event.is_action_pressed("back") or event.is_action_pressed("move_down"):
			_name_edit.release_focus()
			_row = 1
			get_viewport().set_input_as_handled()
		return
	if event.is_echo() and not (event.is_action("move_left") or event.is_action("move_right") or event.is_action("move_up") or event.is_action("move_down")):
		return
	var handled := true
	if event.is_action_pressed("move_up"):
		_row = posmod(_row - 1, ROWS.size())
	elif event.is_action_pressed("move_down"):
		_row = posmod(_row + 1, ROWS.size())
	elif event.is_action_pressed("move_left"):
		_change(-1)
	elif event.is_action_pressed("move_right"):
		_change(1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("action_primary") \
			or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START and event.pressed):
		if ROWS[_row] == "name":
			_name_edit.grab_focus()
			_name_edit.caret_column = _name_edit.text.length()
		elif ROWS[_row] == "confirm" or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START):
			_confirm()
		else:
			_change(1)
	elif event.is_action_pressed("back"):
		if return_scene != "":
			_leave(return_scene)
		else:
			handled = false
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mp := (event as InputEventMouseButton).position
		for h in _hit_rects:
			if (h[0] as Rect2).has_point(mp):
				_row = int(h[1])
				if int(h[2]) != 0:
					_change(int(h[2]))
				elif ROWS[_row] == "confirm":
					_confirm()
				elif ROWS[_row] == "name":
					_name_edit.grab_focus()
				break
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _change(d: int) -> void:
	match ROWS[_row]:
		"look":
			_draft.look_preset = posmod(_draft.look_preset + d, CharacterAppearance.preset_count())
			var suggested := _draft.get_preset_default_name()
			if suggested != "" and CharacterAppearance.is_auto_name(_draft.student_name):
				_draft.student_name = suggested
				_name_edit.text = suggested
			_refresh_character()
		"class":
			_draft.set_class_index(posmod(_draft.get_class_index() + d, CharacterAppearance.CLASSES.size()))
			_refresh_character()
		"combo", "special", "ultimate":
			var slot: String = ROWS[_row]
			var opts := _options(slot)
			var cur: String = _picks[_draft.class_id][slot]
			var i := opts.find(cur)
			# recorre todas (también las bloqueadas, para verlas), pero solo equipa las conseguidas
			i = posmod(i + d, opts.size())
			_picks[_draft.class_id][slot] = opts[i]
			if not GameState.tech_unlocked(opts[i]):
				_toast = "Bloqueada: vence a %s en el Salón de las Facultades" % Arena.BOSSES[Tech.info(opts[i])["boss"]]["name"]
				_toast_t = 2.0


func _options(slot: String) -> Array:
	var out: Array = [""]
	out.append_array(Tech.ids_for_slot(slot))
	return out


func _confirm() -> void:
	# las técnicas bloqueadas que se dejaron a la vista no se equipan
	for cid in _picks.keys():
		for slot in Tech.SLOTS:
			var id: String = _picks[cid][slot]
			GameState.equip(cid, slot, id if GameState.tech_unlocked(id) else "")
	_draft.student_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Estudiante"
	GameState.confirm_and_save(_draft)
	_toast = "¡Listo!"
	_toast_t = 1.0
	await get_tree().create_timer(0.25).timeout
	_leave(return_scene if return_scene != "" else CAMPUS_SCENE)


func _leave(scene: String) -> void:
	return_scene = ""
	get_tree().change_scene_to_file.call_deferred(scene)


# --- Dibujo -------------------------------------------------------------------------
func _paint() -> void:
	var c := _canvas
	var f := ThemeDB.fallback_font
	_hit_rects.clear()
	var cls: Dictionary = CLASS_INFO.get(_draft.class_id, CLASS_INFO["guerrero"])
	var ccol: Color = cls["color"]
	# fondo
	c.draw_rect(Rect2(0, 0, 1280, 720), BG)
	for x in range(0, 1280, 48):
		c.draw_line(Vector2(x, 0), Vector2(x, 720), Color(1, 1, 1, 0.018), 1.0)
	for y in range(0, 720, 48):
		c.draw_line(Vector2(0, y), Vector2(1280, y), Color(1, 1, 1, 0.018), 1.0)
	# --- izquierda: escenario del retrato
	var stage := Rect2(40, 40, 460, 640)
	c.draw_rect(stage, Color(0.02, 0.022, 0.03))
	# foco de luz desde arriba, del color de la clase
	var beam_top := Color(ccol, 0.0)
	var beam_bot := Color(ccol.lerp(Color.WHITE, 0.6), 0.16 + 0.08 * _flash)
	c.draw_polygon(PackedVector2Array([Vector2(230, 40), Vector2(310, 40), Vector2(430, 540), Vector2(110, 540)]),
		PackedColorArray([beam_top, beam_top, beam_bot, beam_bot]))
	for i in 5:
		var rr := 1.0 - i * 0.18
		c.draw_set_transform(Vector2(270, 530), 0.0, Vector2(1.0, 0.25))
		c.draw_circle(Vector2.ZERO, 180.0 * rr, Color(ccol.lerp(Color.WHITE, 0.5), 0.04 + 0.02 * _flash))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# pedestal
	c.draw_rect(Rect2(150, 530, 240, 16), Color(0.1, 0.1, 0.12))
	c.draw_rect(Rect2(150, 530, 240, 2), Color(GOLD, 0.6))
	_frame(stage, ccol)
	# nombre y personaje
	var name_row := Rect2(80, 566, 380, 50)
	_row_bg(name_row, 0)
	c.draw_string(f, Vector2(80, 562), "NOMBRE", HORIZONTAL_ALIGNMENT_CENTER, 380, 11, DIM)
	_hit_rects.append([name_row, 0, 0])
	var look_row := Rect2(80, 622, 380, 44)
	_row_bg(look_row, 1)
	_arrows(look_row, 1)
	c.draw_string(f, Vector2(80, 650), _draft.get_preset_label().to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 380, 20, TEXT)
	c.draw_string(f, Vector2(80, 664), "personaje %d / %d" % [_draft.look_preset + 1, CharacterAppearance.preset_count()], HORIZONTAL_ALIGNMENT_CENTER, 380, 10, DIM)
	# --- derecha
	var x0 := 540.0
	c.draw_string(f, Vector2(x0, 64), "TU UNIVERSITARIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)
	c.draw_string(f, Vector2(x0, 96), "Clase y técnicas", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TEXT)
	var won := GameState.bosses_defeated.size()
	c.draw_string(f, Vector2(x0, 96), "%d / %d técnicas conseguidas" % [mini(won, Tech.DATA.size()), Tech.DATA.size()], HORIZONTAL_ALIGNMENT_RIGHT, 700, 13, DIM)
	c.draw_line(Vector2(x0, 110), Vector2(1240, 110), LINE, 1.0)
	# clase: 3 tarjetas
	var cy := 124.0
	var cw := 224.0
	for i in CharacterAppearance.CLASSES.size():
		var cid := str(CharacterAppearance.CLASSES[i]["id"])
		var info: Dictionary = CLASS_INFO[cid]
		var r := Rect2(x0 + i * (cw + 14), cy, cw, 92)
		var sel := cid == _draft.class_id
		var col: Color = info["color"]
		c.draw_rect(r, Color(col, 0.14) if sel else PANEL)
		c.draw_rect(r, Color(col, 0.95) if sel else Color(LINE, 1.0), false, 2.0 if sel else 1.0)
		_class_icon(r.position + Vector2(30, 34), cid, col if sel else DIM)
		c.draw_string(f, r.position + Vector2(58, 38), str(CharacterAppearance.CLASSES[i]["label"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT if sel else DIM)
		_wrap(str(info["role"]), r.position + Vector2(14, 62), cw - 24, 11, Color(TEXT, 0.85) if sel else Color(DIM, 0.8), 2)
		_hit_rects.append([r, 2, i - _draft.get_class_index()])
	if _row == 2:
		c.draw_rect(Rect2(x0 - 6, cy - 6, 3 * cw + 28 + 12, 104), Color(GOLD, 0.6 + 0.3 * sin(_t * 5.0)), false, 2.0)
	# ranuras de técnicas
	var sy := 238.0
	for k in Tech.SLOTS.size():
		var slot: String = Tech.SLOTS[k]
		var row_i := 3 + k
		var r2 := Rect2(x0, sy + k * 70.0, 700, 60)
		_row_bg(r2, row_i)
		_arrows(r2, row_i)
		var id: String = _picks[_draft.class_id][slot]
		var locked := not GameState.tech_unlocked(id)
		var info2 := Tech.info(id)
		var tcol: Color = info2.get("color", GOLD) if id != "" else DIM
		c.draw_string(f, r2.position + Vector2(40, 22), Tech.SLOT_LABEL[slot], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
		c.draw_string(f, r2.position + Vector2(40, 36), GameState.btn(Tech.SLOT_ACTION[slot]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
		var tname: String = Tech.BASE[_draft.class_id][slot][0] if id == "" else str(info2["name"])
		c.draw_string(f, r2.position + Vector2(140, 38), tname, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(tcol, 0.45) if locked else (TEXT if id == "" else tcol))
		var tag := "DE SERIE" if id == "" else ("BLOQUEADA" if locked else str(Arena.BOSSES[info2["boss"]]["name"]))
		var tag_col := DIM if id == "" else (Color(1, 0.4, 0.35) if locked else tcol)
		var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16
		var tag_r := Rect2(r2.end.x - 40 - tw, r2.position.y + 20, tw, 20)
		c.draw_rect(tag_r, Color(tag_col, 0.12))
		c.draw_rect(tag_r, Color(tag_col, 0.7), false, 1.0)
		c.draw_string(f, tag_r.position + Vector2(8, 15), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tag_col)
		# puntos: cuántas opciones hay y cuál está elegida
		var opts := _options(slot)
		for j in opts.size():
			var dp := Vector2(r2.position.x + 140 + j * 12, r2.end.y - 8)
			var oid: String = opts[j]
			var dc := GOLD if oid == id else (Color(0.4, 0.4, 0.45) if GameState.tech_unlocked(oid) else Color(0.2, 0.2, 0.24))
			c.draw_circle(dp, 3.0, dc)
	# detalle de la ranura elegida (o de la clase)
	var dr := Rect2(x0, 458, 700, 170)
	c.draw_rect(dr, PANEL)
	c.draw_rect(dr, LINE, false, 1.0)
	_detail(dr)
	# confirmar
	var cr := Rect2(x0 + 470, 640, 230, 40)
	var csel := _row == 6
	c.draw_rect(cr, Color(GOLD, 0.25 if csel else 0.1))
	c.draw_rect(cr, Color(GOLD, 0.95 if csel else 0.5), false, 2.0)
	c.draw_string(f, cr.position + Vector2(0, 27), "CONFIRMAR", HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 18, TEXT)
	_hit_rects.append([cr, 6, 0])
	var hint := "↑↓ elegir  ·  ←→ cambiar  ·  %s confirmar" % ("Start" if GameState.using_pad else "Enter")
	if return_scene != "":
		hint += "  ·  %s volver" % GameState.btn("back")
	c.draw_string(f, Vector2(x0, 666), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)
	if _toast_t > 0.0:
		var ta := clampf(_toast_t / 0.3, 0.0, 1.0)
		c.draw_rect(Rect2(x0, 690, 700, 24), Color(0, 0, 0, 0.6 * ta))
		c.draw_string(f, Vector2(x0, 707), _toast, HORIZONTAL_ALIGNMENT_CENTER, 700, 13, Color(1, 0.85, 0.5, ta))


func _detail(r: Rect2) -> void:
	var c := _canvas
	var f := ThemeDB.fallback_font
	var p := r.position + Vector2(20, 0)
	var w := r.size.x - 40
	var slot := ""
	if _row >= 3 and _row <= 5:
		slot = Tech.SLOTS[_row - 3]
	if slot == "":
		# info general de la clase
		var info: Dictionary = CLASS_INFO[_draft.class_id]
		c.draw_string(f, p + Vector2(0, 30), _draft.get_class_label().to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, info["color"])
		_wrap(str(info["role"]), p + Vector2(0, 56), w, 14, TEXT, 2)
		var y := 100.0
		for s in Tech.SLOTS:
			var id: String = _picks[_draft.class_id][s]
			var nm: String = Tech.BASE[_draft.class_id][s][0] if id == "" or not GameState.tech_unlocked(id) else str(Tech.info(id)["name"])
			c.draw_string(f, p + Vector2(0, y), "%s · %s" % [Tech.SLOT_LABEL[s], nm], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
			y += 20.0
		return
	var id2: String = _picks[_draft.class_id][slot]
	if id2 == "":
		var base: Array = Tech.BASE[_draft.class_id][slot]
		c.draw_string(f, p + Vector2(0, 30), str(base[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT)
		c.draw_string(f, p + Vector2(0, 30), "DE SERIE · %s" % _draft.get_class_label().to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, w, 11, DIM)
		c.draw_string(f, p + Vector2(0, 58), "QUÉ HACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
		_wrap(str(base[1]), p + Vector2(0, 76), w, 14, TEXT, 3)
		var n_unlocked := 0
		for oid in Tech.ids_for_slot(slot):
			if GameState.tech_unlocked(oid):
				n_unlocked += 1
		c.draw_string(f, p + Vector2(0, 150), "%d técnica(s) de %s conseguidas · ←→ para cambiar" % [n_unlocked, Tech.SLOT_LABEL[slot].to_lower()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)
		return
	var info2 := Tech.info(id2)
	var col: Color = info2["color"]
	var locked := not GameState.tech_unlocked(id2)
	var boss: Dictionary = Arena.BOSSES[info2["boss"]]
	c.draw_string(f, p + Vector2(0, 30), str(info2["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(col, 0.6) if locked else col)
	c.draw_string(f, p + Vector2(0, 30), "de %s · %s" % [boss["name"], str(boss["title"][2])], HORIZONTAL_ALIGNMENT_RIGHT, w, 11, DIM)
	c.draw_string(f, p + Vector2(0, 58), "QUÉ HACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
	var lines := _wrap(str(info2["what"]), p + Vector2(0, 76), w, 14, Color(TEXT, 0.6) if locked else TEXT, 3)
	var y2 := 76.0 + lines * 18.0 + 8.0
	c.draw_string(f, p + Vector2(0, y2), "PARA QUÉ SIRVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
	_wrap(str(info2["tip"]), p + Vector2(0, y2 + 18), w, 14, Color(TEXT, 0.6) if locked else Color(TEXT, 0.9), 2)
	if locked:
		var lr := Rect2(r.position.x, r.end.y - 30, r.size.x, 30)
		c.draw_rect(lr, Color(0.35, 0.06, 0.05, 0.85))
		c.draw_string(f, lr.position + Vector2(0, 20), "BLOQUEADA · vence a %s en el Salón de las Facultades para conseguirla" % boss["name"], HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 13, Color(1, 0.8, 0.75))


## Texto en varias líneas; devuelve cuántas usó.
func _wrap(text: String, at: Vector2, width: float, size: int, col: Color, max_lines: int) -> int:
	var f := ThemeDB.fallback_font
	var words := text.split(" ")
	var line := ""
	var n := 0
	for wd in words:
		var test := wd if line == "" else line + " " + wd
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			_canvas.draw_string(f, at + Vector2(0, n * (size + 4)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			n += 1
			line = wd
			if n >= max_lines:
				return n
		else:
			line = test
	if line != "":
		_canvas.draw_string(f, at + Vector2(0, n * (size + 4)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		n += 1
	return n


func _row_bg(r: Rect2, row_i: int) -> void:
	var sel := _row == row_i
	_canvas.draw_rect(r, Color(1, 1, 1, 0.05) if sel else Color(0, 0, 0, 0.0))
	if sel:
		_canvas.draw_rect(r, Color(GOLD, 0.6 + 0.3 * sin(_t * 5.0)), false, 2.0)
		_canvas.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), GOLD)
	else:
		_canvas.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), LINE, 1.0)


func _arrows(r: Rect2, row_i: int) -> void:
	var f := ThemeDB.fallback_font
	var a := 1.0 if _row == row_i else 0.45
	var lr := Rect2(r.position.x + 4, r.position.y, 28, r.size.y)
	var rr := Rect2(r.end.x - 32, r.position.y, 28, r.size.y)
	_canvas.draw_string(f, Vector2(lr.position.x, r.get_center().y + 8), "◀", HORIZONTAL_ALIGNMENT_CENTER, 28, 18, Color(GOLD, a))
	_canvas.draw_string(f, Vector2(rr.position.x, r.get_center().y + 8), "▶", HORIZONTAL_ALIGNMENT_CENTER, 28, 18, Color(GOLD, a))
	_hit_rects.append([lr, row_i, -1])
	_hit_rects.append([rr, row_i, 1])
	_hit_rects.append([r, row_i, 0])


func _frame(r: Rect2, col: Color) -> void:
	_canvas.draw_rect(r, LINE, false, 1.0)
	var k := 18.0
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var cv: Vector2 = corner
		var sx := 1.0 if cv.x == r.position.x else -1.0
		var sy := 1.0 if cv.y == r.position.y else -1.0
		_canvas.draw_line(cv, cv + Vector2(k * sx, 0), Color(col, 0.9), 2.0)
		_canvas.draw_line(cv, cv + Vector2(0, k * sy), Color(col, 0.9), 2.0)


func _class_icon(at: Vector2, cid: String, col: Color) -> void:
	var c := _canvas
	match cid:
		"guerrero":
			# borrador de pizarra
			c.draw_rect(Rect2(at + Vector2(-14, -8), Vector2(28, 16)), col)
			c.draw_rect(Rect2(at + Vector2(-14, 2), Vector2(28, 6)), Color(col.darkened(0.5)))
		"mago":
			c.draw_circle(at, 10.0, Color(col, 0.35))
			c.draw_circle(at, 6.0, col)
			for i in 4:
				var a := _t * 2.0 + i * TAU / 4.0
				c.draw_circle(at + Vector2.from_angle(a) * 14.0, 2.0, col)
		_:
			for i in 3:
				c.draw_arc(at + Vector2(-10 + i * 10, 0), 6.0, 0, TAU, 12, col, 2.5)
