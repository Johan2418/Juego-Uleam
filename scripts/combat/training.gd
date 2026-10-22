extends Node2D
## Sala de entrenamiento (coliseo de la universidad). Primera parada después de elegir personaje.
## Una pizarra guía las mecánicas una por una (moverse, rodar, correr, combo, especial, fijar,
## parry, contraataque y ultimate); con 2 jugadores cuenta lo que haga cualquiera de los dos.
## Al terminar se abre la puerta al Salón de las Facultades (los bosses). Si ya se terminó antes,
## la puerta está abierta; manteniendo interact 1 s en la puerta se salta el entrenamiento.
## Escena: scenes/training.tscn. Esc vuelve a la portada.

const Coop := preload("res://scripts/coop.gd")
const DummyScene := preload("res://scenes/combat/dummy_enemy.tscn")
const GameFeel := preload("res://scripts/combat/game_feel.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const HALL_SCENE := "res://scenes/combat/boss_hall.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const MUSIC := "res://assets/audio/training_theme.ogg"
const MUSIC_FALLBACK := "res://assets/audio/hall/hall_ambient.ogg"

const ROOM := Rect2(-700, -340, 1400, 660)
const DOOR_POS := Vector2(0, -340)
const SKIP_HOLD := 1.0

## [id, título, instrucción con {acción} para el botón, meta]
const LESSONS := [
	["move", "MOVERSE", "Camina con {move}", 1.2],
	["roll", "RODAR", "Pulsa {roll} para rodar (eres invulnerable mientras ruedas)", 2],
	["run", "CORRER", "Mantén {roll} con dirección para correr", 1.0],
	["combo", "COMBO", "Golpea al muñeco: {action_primary} tres veces seguidas", 1],
	["special", "ESPECIAL", "Usa tu especial con {action_secondary}", 1],
	["lock", "FIJAR OBJETIVO", "Fija al muñeco con {lock_on} (tus golpes van hacia él)", 1],
	["parry", "PARRY", "El sparring brilla amarillo antes de golpear: pulsa {parry} justo a tiempo", 1],
	["counter", "CONTRAATAQUE", "Después de un parry, pulsa {action_primary} para contraatacar", 1],
	["ultimate", "ULTIMATE", "Tu medidor está lleno: suelta la ultimate con {ultimate}", 1],
]

var players: Array = []
var _lesson := 0
var _progress := 0.0
var _done := false
var _going := false
var _t := 0.0
var _door_near := false
var _skip := 0.0
var _ui: Ui
var _sparring: Node2D
var _dummies: Array = []
var _parry_t := -10.0
var _music: AudioStreamPlayer
var _cd_was := {}
var _roll_was := {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_done = GameState.training_done
	var floor_node := Floor.new()
	floor_node.room = self
	add_child(floor_node)
	_build_walls()
	var door := Door.new()
	door.room = self
	door.position = DOOR_POS
	add_child(door)
	# muñecos: dos quietos para combos y uno que ataca (sparring) para el parry
	for pos in [Vector2(-300, -60), Vector2(-120, -120)]:
		var d: Node2D = DummyScene.instantiate()
		d.position = pos
		d.set("attacks", false)
		add_child(d)
		d.connect("got_hit", _on_dummy_hit)
		_dummies.append(d)
	_sparring = DummyScene.instantiate()
	_sparring.position = Vector2(260, -70)
	_sparring.set("attacks", false)
	_sparring.set("attack_interval", 1.8)
	add_child(_sparring)
	_sparring.connect("got_hit", _on_dummy_hit)
	_dummies.append(_sparring)
	players = Coop.spawn(self, Vector2(0, 220), TITLE_SCENE)
	for p in players:
		var cam := p.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.zoom = Vector2(1.1, 1.1)
			if players.size() == 1:
				cam.limit_left = int(ROOM.position.x - 40)
				cam.limit_right = int(ROOM.end.x + 40)
				cam.limit_top = int(ROOM.position.y - 140)
				cam.limit_bottom = int(ROOM.end.y + 40)
			cam.reset_smoothing()
		var cc: Node = p.get("class_controller")
		cc.connect("attack_started", _on_attack.bind(p))
		cc.connect("combo_step_changed", _on_combo)
		cc.connect("parried", func(_from: Vector2) -> void: _on_parried())
	_ui = Ui.new()
	_ui.room = self
	add_child(_ui)
	_play_music()
	if _done:
		_lesson = LESSONS.size()
		_sparring.set("attacks", true)


func _play_music() -> void:
	var path := MUSIC if ResourceLoader.exists(MUSIC) else MUSIC_FALLBACK
	if not ResourceLoader.exists(path):
		return
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = st
	_music.volume_db = -40.0
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", -9.0, 1.5)


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var R := ROOM
	for r in [
		Rect2(R.position.x - 60, R.position.y - 60, R.size.x + 120, 60 + 40),   # arriba (gradas)
		Rect2(R.position.x - 60, R.end.y, R.size.x + 120, 60),
		Rect2(R.position.x - 60, R.position.y - 60, 60, R.size.y + 120),
		Rect2(R.end.x, R.position.y - 60, 60, R.size.y + 120),
	]:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = (r as Rect2).size
		cs.shape = sh
		cs.position = (r as Rect2).get_center()
		walls.add_child(cs)


func lesson() -> Array:
	return LESSONS[_lesson] if _lesson < LESSONS.size() else []


func lesson_id() -> String:
	var l := lesson()
	return str(l[0]) if not l.is_empty() else ""


func _advance(amount: float) -> void:
	if _lesson >= LESSONS.size():
		return
	_progress += amount
	if _progress >= float(LESSONS[_lesson][3]) - 0.001:
		_progress = 0.0
		_lesson += 1
		_ui.cheer()
		var id := lesson_id()
		if id == "parry" or id == "counter":
			_sparring.set("attacks", true)
		if id == "ultimate":
			for p in players:
				var cc: Node = p.get("class_controller")
				cc.call("debug_fill_meter")
		if _lesson >= LESSONS.size():
			_sparring.set("attacks", true)
			if not _done:
				_done = true
				GameState.training_done = true
				GameState.save_progress()
				_ui.unlocked()


func _process(delta: float) -> void:
	_t += delta
	var id := lesson_id()
	for p in players:
		if not is_instance_valid(p):
			continue
		match id:
			"move":
				if (p as CharacterBody2D).velocity.length() > 40.0:
					_advance(delta)
			"run":
				if bool(p.get("running")):
					_advance(delta)
			"roll":
				var r := bool(p.get("rolling"))
				if r and not _roll_was.get(p, false):
					_advance(1)
				_roll_was[p] = r
			"special":
				var cc: Node = p.get("class_controller")
				var cd := float(cc.call("special_cooldown_left"))
				if cd > 0.0 and float(_cd_was.get(p, 0.0)) <= 0.0:
					_advance(1)
				_cd_was[p] = cd
			"lock":
				if bool(p.call("locked_on")):
					_advance(1)
	# puerta al salón
	_door_near = false
	for p in players:
		if is_instance_valid(p) and (p as Node2D).global_position.distance_to(DOOR_POS + Vector2(0, 70)) < 110.0:
			_door_near = true
	if _door_near and not _going and Input.is_action_pressed("interact"):
		_skip += delta
		if _done and _skip > 0.05:
			_go_hall()
		elif _skip >= SKIP_HOLD:
			_done = true
			_go_hall()
	else:
		_skip = 0.0


func _on_dummy_hit(_amount: int, _from: Vector2) -> void:
	pass


func _on_combo(step: int) -> void:
	if lesson_id() == "combo" and step >= 2:
		_advance(1)


func _on_parried() -> void:
	_parry_t = _t
	if lesson_id() == "parry":
		_advance(1)


func _on_attack(kind: String, _p: Node) -> void:
	var id := lesson_id()
	if id == "counter" and (kind.ends_with("_counter") or _t - _parry_t < 1.5) and not kind.ends_with("_parry"):
		_advance(1)
	elif id == "ultimate" and kind.ends_with("_ultimate"):
		_advance(1)
	elif id == "combo" and kind.ends_with("_finisher"):
		_advance(1)


func _go_hall() -> void:
	if _going:
		return
	_going = true
	for p in players:
		p.set_physics_process(false)
		p.set_process_unhandled_input(false)
	if _music:
		create_tween().tween_property(_music, "volume_db", -40.0, 0.8)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = Vector2(1280, 720)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(HALL_SCENE))


## Texto de la instrucción con el botón de cada jugador ("J / X").
func instruction() -> String:
	var l := lesson()
	if l.is_empty():
		return "¡Listo! Ve a la puerta del fondo: el Salón de las Facultades"
	var s := str(l[2])
	var i := s.find("{")
	while i >= 0:
		var j := s.find("}", i)
		var action := s.substr(i + 1, j - i - 1)
		var key := GameState.btn(action)
		if GameState.coop:
			var k1 := GameState.btn_for(1, action)
			var k2 := GameState.btn_for(2, action)
			key = k1 if k1 == k2 else "%s / %s" % [k1, k2]
		s = s.substr(0, i) + "[" + key + "]" + s.substr(j + 1)
		i = s.find("{")
	return s


# ==================================================================================
## Coliseo: piso de madera con líneas de cancha, gradas al fondo y estandartes de las facultades.
class Floor extends Node2D:
	var room: Node

	func _ready() -> void:
		z_index = -10

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var R: Rect2 = ROOM
		var t: float = room.get("_t")
		# exterior oscuro
		draw_rect(R.grow(400), Color(0.05, 0.05, 0.09))
		# gradas (al fondo, arriba)
		for i in 5:
			var y := R.position.y - 150 + i * 26
			draw_rect(Rect2(R.position.x - 40, y, R.size.x + 80, 26), Color(0.16, 0.17, 0.26).lightened(i * 0.04))
			draw_rect(Rect2(R.position.x - 40, y + 22, R.size.x + 80, 4), Color(0.08, 0.08, 0.14))
			# público (cabecitas)
			for k in 40:
				var x := R.position.x - 20 + k * 36 + (i % 2) * 18
				var bob := sin(t * 3.0 + k * 1.3 + i) * 1.5
				var hue := fmod(k * 0.17 + i * 0.31, 1.0)
				draw_circle(Vector2(x, y + 10 + bob), 7, Color.from_hsv(hue, 0.35, 0.45))
		# estandartes de las 9 facultades (colores de los bosses)
		var cols := [Color(1.0, 0.3, 0.2), Color(0.3, 0.6, 1.0), Color(1.0, 0.78, 0.2), Color(0.45, 0.9, 0.55), Color(1.0, 0.6, 0.15),
			Color(0.9, 0.3, 0.3), Color(1.0, 0.3, 1.0), Color(1.0, 0.65, 0.2), Color(0.3, 0.9, 0.6)]
		for i in 9:
			var x := R.position.x + 80 + i * (R.size.x - 160) / 8.0
			if absf(x) < 120:
				continue
			var top := R.position.y - 170
			var sway := sin(t * 1.5 + i) * 3.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 18, top), Vector2(x + 18, top), Vector2(x + 18 + sway, top + 60), Vector2(x + sway, top + 72), Vector2(x - 18 + sway, top + 60)]), cols[i])
		# muro bajo de la cancha
		draw_rect(Rect2(R.position.x - 40, R.position.y - 22, R.size.x + 80, 22), Color(0.3, 0.12, 0.12))
		draw_rect(Rect2(R.position.x - 40, R.position.y - 4, R.size.x + 80, 4), Color(0.9, 0.85, 0.7))
		# piso de madera
		draw_rect(R, Color(0.72, 0.5, 0.3))
		for i in int(R.size.y / 22.0) + 1:
			var y2 := R.position.y + i * 22
			draw_line(Vector2(R.position.x, y2), Vector2(R.end.x, y2), Color(0.6, 0.4, 0.22), 1)
			var off := (i * 97) % 180
			for k in 9:
				var x2 := R.position.x + off + k * 180
				if x2 < R.end.x:
					draw_line(Vector2(x2, y2), Vector2(x2, y2 + 22), Color(0.6, 0.4, 0.22), 1)
		# líneas de cancha
		var line := Color(1, 1, 1, 0.75)
		draw_rect(R.grow(-30), line, false, 3)
		draw_line(Vector2(0, R.position.y + 30), Vector2(0, R.end.y - 30), line, 3)
		draw_arc(Vector2(0, -10), 90, 0, TAU, 48, line, 3)
		draw_circle(Vector2(0, -10), 60, Color(0.15, 0.25, 0.55, 0.45))
		draw_arc(Vector2(R.position.x + 30, -10), 160, -PI * 0.5, PI * 0.5, 32, line, 3)
		draw_arc(Vector2(R.end.x - 30, -10), 160, PI * 0.5, PI * 1.5, 32, line, 3)
		# zona de cada lección: círculo bajo los muñecos
		for d in room.get("_dummies"):
			var pos: Vector2 = (d as Node2D).position
			draw_circle(pos + Vector2(0, 14), 46, Color(0.9, 0.85, 0.3, 0.12))
			draw_arc(pos + Vector2(0, 14), 46, 0, TAU, 32, Color(0.9, 0.85, 0.3, 0.5), 2)


## Puerta doble al Salón de las Facultades; cerrada (con cadenas) hasta terminar.
class Door extends Node2D:
	var room: Node
	var _open := 0.0

	func _ready() -> void:
		z_index = -5

	func _process(delta: float) -> void:
		_open = move_toward(_open, 1.0 if bool(room.get("_done")) else 0.0, delta * 1.5)
		queue_redraw()

	func _draw() -> void:
		var t: float = room.get("_t")
		draw_rect(Rect2(-90, -150, 180, 150), Color(0.25, 0.2, 0.32))
		draw_rect(Rect2(-80, -140, 160, 140), Color(0.05, 0.04, 0.08))
		if _open > 0.0:
			# luz dorada que sale de la puerta
			draw_rect(Rect2(-80, -140, 160, 140), Color(1.0, 0.8, 0.4, 0.5 * _open))
			for i in 5:
				draw_colored_polygon(PackedVector2Array([Vector2(-60 + i * 30, 0), Vector2(-50 + i * 30, 0), Vector2(-80 + i * 40, 120), Vector2(-100 + i * 40, 120)]), Color(1.0, 0.85, 0.5, 0.06 * _open))
		var w := 80.0 * (1.0 - _open * 0.8)
		draw_rect(Rect2(-80, -140, w, 140), Color(0.42, 0.25, 0.15))
		draw_rect(Rect2(80 - w, -140, w, 140), Color(0.42, 0.25, 0.15))
		if _open < 0.5:
			# cadenas en X
			for s in [-1, 1]:
				for i in 9:
					var u := i / 8.0
					var p := Vector2(-70 * s + 140 * s * u, -125 + 110 * u)
					draw_circle(p, 5, Color(0.6, 0.62, 0.7))
					draw_circle(p, 2.5, Color(0.25, 0.25, 0.3))
			draw_rect(Rect2(-12, -78, 24, 22), Color(0.85, 0.7, 0.2))
		Style.title(self, Vector2(0, -160), "SALÓN DE LAS FACULTADES", 22, Color(1.0, 0.9, 0.5), Color(0.1, 0.05, 0.02), HORIZONTAL_ALIGNMENT_CENTER, 400)
		if bool(room.get("_door_near")):
			var msg := "%s  entrar" % GameState.btn("interact") if bool(room.get("_done")) else "Mantén %s para saltar el entrenamiento" % GameState.btn("interact")
			Style.title(self, Vector2(0, 40 + sin(t * 5.0) * 2.0), msg, 18, Color.WHITE, Color(0.05, 0.03, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 500, 0.0)
			var sk: float = room.get("_skip")
			if not bool(room.get("_done")) and sk > 0.0:
				draw_rect(Rect2(-80, 52, 160, 8), Color(0, 0, 0, 0.7))
				draw_rect(Rect2(-80, 52, 160 * clampf(sk / SKIP_HOLD, 0.0, 1.0), 8), Color(1.0, 0.85, 0.3))


## Pizarra de la lección actual (arriba) y lista de lecciones.
class Ui extends CanvasLayer:
	var room: Node
	var _draw_node: Node2D
	var _cheer := 0.0
	var _unlock := 0.0

	func _ready() -> void:
		layer = 6
		_draw_node = Node2D.new()
		_draw_node.draw.connect(_paint)
		add_child(_draw_node)

	func cheer() -> void:
		_cheer = 1.0

	func unlocked() -> void:
		_unlock = 3.0

	func _process(delta: float) -> void:
		_cheer = maxf(0.0, _cheer - delta * 1.2)
		_unlock = maxf(0.0, _unlock - delta)
		_draw_node.queue_redraw()

	func _paint() -> void:
		var ci := _draw_node
		var lessons: Array = LESSONS
		var cur: int = room.get("_lesson")
		# pizarra
		var r := Rect2(290, 14, 700, 92)
		ci.draw_colored_polygon(Style.slanted(r, 20), Color(0.06, 0.14, 0.1, 0.92))
		ci.draw_polyline(Style.slanted(r, 20) + PackedVector2Array([Style.slanted(r, 20)[0]]), Color(0.75, 0.6, 0.35), 4.0)
		var l: Array = room.call("lesson")
		var head := "ENTRENAMIENTO  %d/%d  ·  %s" % [mini(cur + 1, lessons.size()), lessons.size(), str(l[1])] if not l.is_empty() else "ENTRENAMIENTO COMPLETO"
		Style.title(ci, Vector2(640, 48), head, 26, Color(1.0, 0.9, 0.35), Color(0.04, 0.06, 0.03), HORIZONTAL_ALIGNMENT_CENTER, 680)
		Style.title(ci, Vector2(640, 84), str(room.call("instruction")), 17, Color.WHITE, Color(0.03, 0.05, 0.03), HORIZONTAL_ALIGNMENT_CENTER, 680, 0.0)
		# barra de progreso de la lección actual
		if not l.is_empty():
			var goal := float(l[3])
			var prog: float = room.get("_progress")
			ci.draw_rect(Rect2(420, 94, 440, 5), Color(0, 0, 0, 0.6))
			ci.draw_rect(Rect2(420, 94, 440 * clampf(prog / goal, 0.0, 1.0), 5), Color(0.5, 1.0, 0.6))
		# lista de lecciones (izquierda)
		for i in lessons.size():
			var y := 140.0 + i * 24.0
			var done := i < cur
			var col := Color(0.5, 1.0, 0.6) if done else (Color(1.0, 0.9, 0.35) if i == cur else Color(0.65, 0.65, 0.75))
			ci.draw_rect(Rect2(14, y - 15, 190, 21), Color(0, 0, 0, 0.45))
			Style.title(ci, Vector2(22, y), ("✓ " if done else ("► " if i == cur else "· ")) + str(lessons[i][1]), 15, col, Color(0.03, 0.03, 0.06), HORIZONTAL_ALIGNMENT_LEFT, -1, 0.0)
		if _cheer > 0.0:
			var a := minf(1.0, _cheer * 2.0)
			Style.title(ci, Vector2(640, 300 - (1.0 - _cheer) * 40), "¡BIEN!", 70, Color(1.0, 0.9, 0.3, a), Color(0.1, 0.05, 0.02, a), HORIZONTAL_ALIGNMENT_CENTER, 600)
		if _unlock > 0.0:
			var a2 := minf(1.0, _unlock)
			ci.draw_rect(Rect2(0, 330, 1280, 90), Color(0, 0, 0, 0.6 * a2))
			Style.title(ci, Vector2(640, 392), "¡LA PUERTA DEL SALÓN SE ABRIÓ!", 46, Color(1.0, 0.85, 0.35, a2), Color(0.1, 0.05, 0.02, a2), HORIZONTAL_ALIGNMENT_CENTER, 1200)
