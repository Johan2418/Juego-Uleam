extends Node2D
## Salón de las Facultades (como el Salón de los Dioses de Hollow Knight).
## Galería a oscuras con una estatua de piedra de cada boss bajo un haz de luz. Al acercarse,
## la luz se intensifica y aparece el título de su facultad; con interact (E / A) se entra al combate.
## Las estatuas de los bosses vencidos son de oro y muestran el mejor rango y tiempo.
## Escena: scenes/combat/boss_hall.tscn. Se llega desde la puerta grande del campus y la arena vuelve aquí.

const PlayerScene := preload("res://scenes/combat/player.tscn")
const Arena := preload("res://scripts/combat/boss_arena.gd")
const GameFeel := preload("res://scripts/combat/game_feel.gd")
const StoneShader := preload("res://shaders/statue_stone.gdshader")

const ARENA_SCENE := "res://scenes/combat/boss_test.tscn"
const MENU_SCENE := "res://scenes/character_creator.tscn"
const HALL_SCENE := "res://scenes/combat/boss_hall.tscn"
const LOCKER_POS := Vector2(-230, 236)
const CAMPUS_SCENE := "res://scenes/main.tscn"
const MUSIC := "res://assets/audio/hall/hall_ambient.ogg"
const STATUE_DIR := "res://assets/sprites/statues/statue_%s.png"

## Orden de las estatuas, de izquierda a derecha.
const ORDER := ["deadbeef", "bsod", "div0", "syntax", "stack", "judge", "tex", "kp"]
## Color de acento de cada facultad (el mismo de las antiguas puertas del campus).
const ACCENT := {
	"deadbeef": Color(1.0, 0.3, 0.2), "bsod": Color(0.3, 0.6, 1.0), "div0": Color(1.0, 0.78, 0.2),
	"syntax": Color(0.45, 0.9, 0.55), "stack": Color(1.0, 0.6, 0.15), "judge": Color(0.9, 0.3, 0.3),
	"tex": Color(1.0, 0.3, 1.0), "kp": Color(1.0, 0.65, 0.2),
}

const SPACING := 300.0
const FEET_Y := -124.0          ## pies de la estatua (arriba del pedestal)
const FRONT_Y := -84.0          ## frente del pedestal / borde del piso caminable
const HALL := Rect2(-1290, -470, 2580, 740)
const STATUE_SCALE := 0.8
const NEAR_X := 115.0
const NEAR_Y := 70.0

## Estatua por la que se entró al último combate (para aparecer delante de ella al volver).
static var last_kind: String = ""

var player: CharacterBody2D
var statues: Array = []          # Statue
var _focus: Statue = null
var _going := false
var _ui: HallUi
var _exit_near := false
var _locker_near := false
var _locker: Locker
var _music: AudioStreamPlayer


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg := Backdrop.new()
	bg.hall = self
	add_child(bg)
	for i in ORDER.size():
		var kind: String = ORDER[i]
		var st := Statue.new()
		st.kind = kind
		st.accent = ACCENT[kind]
		st.boss_name = str(Arena.BOSSES[kind]["name"])
		st.position = Vector2(_statue_x(i), FEET_Y)
		st.defeated = GameState.is_defeated(kind)
		add_child(st)
		statues.append(st)
		var beam := Beam.new()
		beam.statue = st
		beam.position = st.position
		add_child(beam)
		st.beam = beam
	var door := ExitDoor.new()
	door.position = Vector2(0, HALL.end.y - 6)
	add_child(door)
	_locker = Locker.new()
	_locker.position = LOCKER_POS
	add_child(_locker)
	_build_walls()
	# jugador
	player = PlayerScene.instantiate()
	player.set("exit_scene", CAMPUS_SCENE)
	var from_arena := last_kind != "" and ORDER.has(last_kind)
	if from_arena:
		player.position = Vector2(_statue_x(ORDER.find(last_kind)), FRONT_Y + 70)
	else:
		player.position = Vector2(0, HALL.end.y - 70)
	add_child(player)
	# sin vida ni medidores: aquí no se pelea
	for c in player.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.zoom = Vector2.ONE
		cam.limit_left = int(HALL.position.x)
		cam.limit_right = int(HALL.end.x)
		cam.limit_top = int(HALL.position.y)
		cam.limit_bottom = int(HALL.end.y)
		cam.reset_smoothing()
	var vig := Vignette.new()
	add_child(vig)
	_ui = HallUi.new()
	add_child(_ui)
	_play_music()
	# recién vencido: la estatua se vuelve de oro delante del jugador
	var won: String = GameState.last_won
	if won != "" and ORDER.has(won):
		GameState.last_won = ""
		var st2: Statue = statues[ORDER.find(won)]
		st2.defeated = true
		st2.gild()
	if not from_arena:
		_ui.area_title()
	last_kind = ""


func _statue_x(i: int) -> float:
	return (i - (ORDER.size() - 1) * 0.5) * SPACING


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var top := FRONT_Y + 10.0
	for r in [
		Rect2(HALL.position.x - 50, top - 60, HALL.size.x + 100, 60),          # pedestales y muro del fondo
		Rect2(HALL.position.x - 50, HALL.end.y - 20, HALL.size.x + 100, 60),    # abajo
		Rect2(HALL.position.x - 50, top - 60, 60, HALL.end.y - top + 120),     # izquierda
		Rect2(HALL.end.x - 10, top - 60, 60, HALL.end.y - top + 120),           # derecha
	]:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = (r as Rect2).size
		cs.shape = sh
		cs.position = (r as Rect2).get_center()
		walls.add_child(cs)


func _play_music() -> void:
	if not ResourceLoader.exists(MUSIC):
		return
	var st: AudioStream = load(MUSIC)
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = st
	_music.volume_db = -40.0
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", -8.0, 2.0)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var pf := player.global_position
	# estatua más cercana delante del jugador
	var best: Statue = null
	var best_d := INF
	for st in statues:
		var s: Statue = st
		var dx := absf(pf.x - s.position.x)
		if dx < NEAR_X and pf.y - FRONT_Y < NEAR_Y + 60.0 and dx < best_d:
			best_d = dx
			best = s
	if best != _focus and not _going:
		if _focus:
			_focus.focused = false
		_focus = best
		if _focus:
			_focus.focused = true
			_ui.show_statue(_focus)
		else:
			_ui.hide_statue()
	_exit_near = absf(pf.x) < 90.0 and pf.y > HALL.end.y - 70.0
	_locker_near = pf.distance_to(LOCKER_POS) < 85.0 and not _exit_near
	_locker.near = _locker_near and not _going
	_ui.set_exit_prompt(_exit_near and not _going)
	# el jugador queda en penumbra salvo bajo los haces de luz
	var light := 0.5
	for st in statues:
		var s2: Statue = st
		var k := clampf(1.0 - absf(pf.x - s2.position.x) / 190.0, 0.0, 1.0) * clampf(1.0 - (pf.y - FRONT_Y) / 330.0, 0.0, 1.0)
		light = maxf(light, 0.5 + 0.5 * k * (0.6 + 0.4 * s2.glow))
	if _exit_near:
		light = maxf(light, 0.8)
	var c := Color(light * 0.95, light * 0.95, light)
	player.modulate = player.modulate.lerp(c, minf(1.0, delta * 6.0))


func _unhandled_input(event: InputEvent) -> void:
	if _going or event.is_echo():
		return
	if event.is_action_pressed("interact"):
		if _focus:
			get_viewport().set_input_as_handled()
			_challenge(_focus)
		elif _exit_near:
			get_viewport().set_input_as_handled()
			_leave(CAMPUS_SCENE, Color.BLACK)
		elif _locker_near:
			get_viewport().set_input_as_handled()
			var menu_script = load("res://scripts/ui/character_menu.gd")
			menu_script.return_scene = HALL_SCENE
			_leave(MENU_SCENE, Color.BLACK)


func _challenge(st: Statue) -> void:
	_going = true
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.velocity = Vector2.ZERO
	_ui.set_exit_prompt(false)
	st.awaken()
	GameFeel.dust(self, st.global_position + Vector2(0, 30), 14, Vector2.ZERO, 6.0, Vector2(110, 10))
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		var tw := create_tween()
		for i in 14:
			var s := 6.0 * (1.0 - i / 14.0)
			tw.tween_property(cam, "offset", Vector2(randf_range(-s, s), randf_range(-s, s)), 0.04)
		tw.tween_property(cam, "offset", Vector2.ZERO, 0.04)
	if _music:
		create_tween().tween_property(_music, "volume_db", -40.0, 1.2)
	Arena.retry = false
	Arena.boss_kind = st.kind
	last_kind = st.kind
	await get_tree().create_timer(0.9).timeout
	_leave(ARENA_SCENE, Color.WHITE)


func _leave(scene: String, col: Color) -> void:
	_going = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var fade := ColorRect.new()
	fade.color = Color(col, 0.0)
	fade.size = Vector2(1280, 720)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	if col != Color.BLACK:
		tw.tween_property(fade, "color", Color.BLACK, 0.35)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(scene))


# ==================================================================================
## Piso, muro del fondo con nichos, pilares y el pedestal de cada estatua.
class Backdrop extends Node2D:
	var hall: Node

	func _ready() -> void:
		z_index = -10

	func _draw() -> void:
		var R: Rect2 = HALL
		# fondo: oscuridad total
		draw_rect(R.grow(600), Color(0.012, 0.012, 0.018))
		# piso de losas
		var fy := FRONT_Y
		var tile := 64.0
		var y := fy
		var row := 0
		while y < R.end.y + 40:
			var x := R.position.x - fmod(row * 32.0, tile)
			while x < R.end.x:
				var shade := 0.07 + 0.012 * float((int(x / tile) + row) % 3)
				var depth := clampf((y - fy) / 300.0, 0.0, 1.0)
				var c := Color(shade, shade, shade * 1.15) * (1.0 - 0.35 * depth)
				draw_rect(Rect2(x + 1, y + 1, tile - 2, 30), c)
				x += tile
			y += 32
			row += 1
		# alfombra central a lo largo de la galería
		draw_rect(Rect2(R.position.x, fy + 70, R.size.x, 46), Color(0.11, 0.04, 0.05))
		draw_rect(Rect2(R.position.x, fy + 72, R.size.x, 2), Color(0.45, 0.36, 0.2, 0.6))
		draw_rect(Rect2(R.position.x, fy + 112, R.size.x, 2), Color(0.45, 0.36, 0.2, 0.6))
		# muro del fondo
		draw_rect(Rect2(R.position.x, R.position.y, R.size.x, fy - R.position.y), Color(0.035, 0.035, 0.05))
		for i in ORDER.size():
			var cx := (i - (ORDER.size() - 1) * 0.5) * SPACING
			_niche(cx)
		# pilares entre nichos
		for i in ORDER.size() + 1:
			var px := (i - ORDER.size() * 0.5) * SPACING
			_pillar(px)
		# zócalo
		draw_rect(Rect2(R.position.x, fy - 8, R.size.x, 10), Color(0.09, 0.085, 0.1))
		draw_rect(Rect2(R.position.x, fy - 8, R.size.x, 2), Color(0.5, 0.42, 0.25, 0.5))

	func _niche(cx: float) -> void:
		var top := HALL.position.y + 40.0
		var w := 220.0
		var pts := PackedVector2Array()
		pts.append(Vector2(cx - w * 0.5, FRONT_Y))
		var arc_y := top + w * 0.5
		pts.append(Vector2(cx - w * 0.5, arc_y))
		for k in 17:
			var a := PI + PI * k / 16.0
			pts.append(Vector2(cx + cos(a) * w * 0.5, arc_y + sin(a) * w * 0.5))
		pts.append(Vector2(cx + w * 0.5, FRONT_Y))
		draw_colored_polygon(pts, Color(0.018, 0.018, 0.026))
		# moldura dorada apagada
		var trim := pts.slice(1, pts.size() - 1)
		draw_polyline(trim, Color(0.32, 0.26, 0.15, 0.7), 3.0)
		draw_polyline(trim, Color(0.12, 0.1, 0.07), 1.0)
		# rosetón arriba del arco
		var rc := Vector2(cx, top - 4)
		draw_circle(rc, 14, Color(0.06, 0.055, 0.07))
		draw_arc(rc, 14, 0, TAU, 20, Color(0.38, 0.3, 0.16, 0.7), 2.0)
		for k in 8:
			var a2 := TAU * k / 8.0
			draw_line(rc + Vector2.from_angle(a2) * 5, rc + Vector2.from_angle(a2) * 12, Color(0.32, 0.26, 0.14, 0.6), 1.5)

	func _pillar(px: float) -> void:
		var top := HALL.position.y
		draw_rect(Rect2(px - 26, top, 52, FRONT_Y - top), Color(0.055, 0.055, 0.07))
		draw_rect(Rect2(px - 26, top, 6, FRONT_Y - top), Color(0.08, 0.08, 0.1))
		draw_rect(Rect2(px + 20, top, 6, FRONT_Y - top), Color(0.03, 0.03, 0.04))
		for k in 3:
			draw_line(Vector2(px - 12 + k * 12, top + 30), Vector2(px - 12 + k * 12, FRONT_Y - 40), Color(0.035, 0.035, 0.045), 3.0)
		# capitel y base
		draw_rect(Rect2(px - 34, top + 6, 68, 16), Color(0.08, 0.075, 0.09))
		draw_rect(Rect2(px - 34, FRONT_Y - 30, 68, 22), Color(0.08, 0.075, 0.09))
		draw_rect(Rect2(px - 34, FRONT_Y - 30, 68, 2), Color(0.4, 0.33, 0.18, 0.5))


# ==================================================================================
## Estatua de un boss sobre su pedestal, con placa. glow sube con el foco.
class Statue extends Node2D:
	var kind := ""
	var boss_name := ""
	var accent := Color.WHITE
	var defeated := false
	var focused := false
	var glow := 0.0
	var beam: Node2D
	var t := 0.0
	var _spr: Sprite2D
	var _mat: ShaderMaterial
	var _gold := 0.0
	var _flash := 0.0
	var _sparks: Array = []

	func _ready() -> void:
		z_index = 0
		_mat = ShaderMaterial.new()
		_mat.shader = StoneShader
		_mat.set_shader_parameter("tint", accent)
		_spr = Sprite2D.new()
		var path := STATUE_DIR % kind
		if ResourceLoader.exists(path):
			_spr.texture = load(path)
		_spr.centered = false
		_spr.offset = Vector2(-210, -416)
		_spr.scale = Vector2(STATUE_SCALE, STATUE_SCALE)
		_spr.material = _mat
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_spr)
		_gold = 0.85 if defeated else 0.0

	## Animación al volver de una victoria: la piedra se cubre de oro.
	func gild() -> void:
		_gold = 0.0
		var tw := create_tween()
		tw.tween_interval(0.8)
		tw.tween_property(self, "_flash", 0.9, 0.25)
		tw.parallel().tween_property(self, "_gold", 0.85, 1.2)
		tw.tween_property(self, "_flash", 0.0, 0.6)
		for i in 30:
			_sparks.append([Vector2(randf_range(-80, 80), randf_range(-230, 0)), randf_range(0.8, 2.4), randf_range(0.0, 1.2)])

	## Al aceptar el desafío: destello y la estatua "despierta".
	func awaken() -> void:
		var tw := create_tween()
		tw.tween_property(self, "_flash", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		glow = 1.6

	func _process(delta: float) -> void:
		t += delta
		var want := 1.0 if focused else 0.0
		if _flash < 0.5:
			glow = lerpf(glow, want, minf(1.0, delta * 4.0))
		_mat.set_shader_parameter("lit", 0.45 + 0.75 * glow)
		_mat.set_shader_parameter("gold", _gold)
		_mat.set_shader_parameter("flash", _flash)
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		# pedestal
		var w := 190.0
		draw_rect(Rect2(-w * 0.5, 0, w, 40), Color(0.11, 0.105, 0.12))
		draw_rect(Rect2(-w * 0.5, 0, w, 6), Color(0.2, 0.19, 0.21))
		draw_rect(Rect2(-w * 0.5 - 8, 34, w + 16, 8), Color(0.08, 0.075, 0.09))
		draw_rect(Rect2(-w * 0.5, 0, w, 40), Color(0.02, 0.02, 0.03), false, 2.0)
		# placa con el nombre
		var gold_txt := Color(1.0, 0.82, 0.4)
		var plate := Rect2(-70, 12, 140, 20)
		var lit := 0.55 + 0.45 * glow
		draw_rect(plate, Color(0.16, 0.12, 0.06) if defeated else Color(0.06, 0.06, 0.07))
		draw_rect(plate, Color(0.5, 0.4, 0.2, lit), false, 1.5)
		draw_string(f, Vector2(-70, 27), boss_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 11, Color(gold_txt, lit) if defeated else Color(0.75, 0.75, 0.78, lit))
		# marca de vencido: estrella dorada sobre la placa
		if defeated:
			_star(Vector2(0, 4), 5.0, Color(1, 0.85, 0.35, lit))
		# chispas al dorarse
		for s in _sparks:
			var age: float = t - float(s[2])
			if age < 0.0 or age > float(s[1]):
				continue
			var p: Vector2 = s[0] + Vector2(0, -age * 30.0)
			var a := 1.0 - age / float(s[1])
			draw_circle(p, 2.0, Color(1, 0.9, 0.5, a))
		# indicador de interacción
		if focused and _flash < 0.1:
			var y := -312.0 + sin(t * 4.0) * 3.0
			var txt := "%s  desafiar" % GameState.btn("interact")
			draw_rect(Rect2(-70, y, 140, 24), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(-70, y, 140, 24), Color(accent, 0.6), false, 1.5)
			draw_string(f, Vector2(-70, y + 17), txt, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color(1, 0.95, 0.75))

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI * 0.5 + PI * k / 5.0
			pts.append(c + Vector2.from_angle(a) * (r if k % 2 == 0 else r * 0.45))
		draw_colored_polygon(pts, col)


# ==================================================================================
## Haz de luz que cae sobre la estatua, con motas de polvo flotando. Suma luz (aditivo).
class Beam extends Node2D:
	var statue: Statue
	var t := 0.0
	var motes: Array = []

	func _ready() -> void:
		z_index = 4
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
		for i in 16:
			motes.append([Vector2(randf_range(-80, 80), randf_range(-330, 20)), randf_range(4.0, 12.0), randf() * TAU, randf_range(1.0, 2.6)])

	func _process(delta: float) -> void:
		t += delta
		for m in motes:
			var p: Vector2 = m[0]
			p.y += float(m[1]) * delta
			p.x += sin(t * 0.7 + float(m[2])) * 6.0 * delta
			if p.y > 30.0:
				p = Vector2(randf_range(-60, 60), -330.0)
			m[0] = p
		queue_redraw()

	func _draw() -> void:
		var g: float = statue.glow if statue else 0.0
		var k := 0.45 + 0.55 * clampf(g, 0.0, 1.6)
		var top := HALL.position.y - 10.0 - position.y
		var bot := 36.0
		var tw := 46.0
		var bw := 150.0
		var flick := 0.92 + 0.08 * sin(t * 2.3) * sin(t * 3.7)
		var c_top := Color(0.85, 0.88, 1.0, 0.03 * k * flick)
		var c_bot := Color(0.85, 0.88, 1.0, 0.16 * k * flick)
		draw_polygon(PackedVector2Array([Vector2(-tw, top), Vector2(tw, top), Vector2(bw, bot), Vector2(-bw, bot)]),
			PackedColorArray([c_top, c_top, c_bot, c_bot]))
		# núcleo más brillante
		var tw2 := tw * 0.45
		var bw2 := bw * 0.45
		var c2t := Color(1, 1, 1, 0.02 * k)
		var c2b := Color(1, 1, 1, 0.09 * k)
		draw_polygon(PackedVector2Array([Vector2(-tw2, top), Vector2(tw2, top), Vector2(bw2, bot), Vector2(-bw2, bot)]),
			PackedColorArray([c2t, c2t, c2b, c2b]))
		# charco de luz en el piso
		for i in 5:
			var rr := 1.0 - i * 0.18
			draw_set_transform(Vector2(0, 52), 0.0, Vector2(1.0, 0.28))
			draw_circle(Vector2.ZERO, 170.0 * rr, Color(0.8, 0.85, 1.0, 0.025 * k))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# motas de polvo
		for m in motes:
			var p: Vector2 = m[0]
			var a := 0.25 + 0.35 * sin(t * 1.3 + float(m[2]))
			draw_circle(p, float(m[3]), Color(1, 1, 1, maxf(0.0, a) * k))


# ==================================================================================
## Arco de salida al campus (abajo, al centro).
class ExitDoor extends Node2D:
	var t := 0.0

	func _ready() -> void:
		z_index = -5

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-70, -14, 140, 40), Color(0.02, 0.02, 0.025))
		draw_rect(Rect2(-70, -14, 140, 3), Color(0.45, 0.38, 0.22, 0.6))
		var a := 0.35 + 0.15 * sin(t * 2.0)
		draw_polygon(PackedVector2Array([Vector2(-60, -12), Vector2(60, -12), Vector2(90, -90), Vector2(-90, -90)]),
			PackedColorArray([Color(0.6, 0.7, 0.9, 0.12 * a), Color(0.6, 0.7, 0.9, 0.12 * a), Color(0.6, 0.7, 0.9, 0.0), Color(0.6, 0.7, 0.9, 0.0)]))


# ==================================================================================
## Casillero junto a la entrada: abre el menú del personaje (clase y técnicas).
class Locker extends Node2D:
	var near := false
	var t := 0.0

	func _ready() -> void:
		z_index = -4

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		# casillero metálico de dos puertas con una luz encima
		var glow := 0.35 + 0.15 * sin(t * 2.0) + (0.3 if near else 0.0)
		draw_polygon(PackedVector2Array([Vector2(-24, -150), Vector2(24, -150), Vector2(70, -2), Vector2(-70, -2)]),
			PackedColorArray([Color(0.9, 0.85, 0.6, 0.0), Color(0.9, 0.85, 0.6, 0.0), Color(0.9, 0.85, 0.6, 0.10 * glow), Color(0.9, 0.85, 0.6, 0.10 * glow)]))
		draw_rect(Rect2(-40, -96, 80, 96), Color(0.14, 0.16, 0.2))
		draw_rect(Rect2(-40, -96, 80, 96), Color(0.03, 0.03, 0.04), false, 2.0)
		draw_line(Vector2(0, -94), Vector2(0, -2), Color(0.05, 0.05, 0.06), 2.0)
		for sx in [-1.0, 1.0]:
			for k in 3:
				draw_line(Vector2(sx * 20 - 10, -86 + k * 5), Vector2(sx * 20 + 10, -86 + k * 5), Color(0.05, 0.05, 0.07), 2.0)
			draw_rect(Rect2(sx * 6 - 2, -50, 4, 10), Color(0.6, 0.55, 0.4))
		draw_rect(Rect2(-24, -66, 48, 12), Color(0.85, 0.8, 0.6, 0.85))
		draw_string(f, Vector2(-24, -57), "TÉCNICAS", HORIZONTAL_ALIGNMENT_CENTER, 48, 8, Color(0.1, 0.1, 0.12))
		if near:
			var y := -128.0 + sin(t * 5.0) * 2.0
			var txt := "%s  personaje y técnicas" % GameState.btn("interact")
			draw_rect(Rect2(-95, y, 190, 22), Color(0, 0, 0, 0.75))
			draw_rect(Rect2(-95, y, 190, 22), Color(0.86, 0.74, 0.46, 0.7), false, 1.5)
			draw_string(f, Vector2(-95, y + 16), txt, HORIZONTAL_ALIGNMENT_CENTER, 190, 13, Color(1, 0.95, 0.75))


# ==================================================================================
## Oscurece los bordes de la pantalla.
class Vignette extends CanvasLayer:
	func _ready() -> void:
		layer = 4
		var tr := TextureRect.new()
		tr.size = Vector2(1280, 720)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0, 0, 0, 0.9))
		g.add_point(0.55, Color(0, 0, 0, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.45)
		gt.fill_to = Vector2(1.08, 1.0)
		gt.width = 256
		gt.height = 144
		tr.texture = gt
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(tr)


# ==================================================================================
## Textos: título del salón al entrar y título de la facultad al acercarse a una estatua.
class HallUi extends CanvasLayer:
	var _box: Control
	var _fac: Label
	var _name: Label
	var _sub: Label
	var _best: Label
	var _orn_top: Ornament
	var _orn_bot: Ornament
	var _exit: Label
	var _tw: Tween

	func _ready() -> void:
		layer = 6
		_box = Control.new()
		_box.size = Vector2(1280, 200)
		_box.position = Vector2(0, 448)
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.modulate.a = 0.0
		add_child(_box)
		_fac = _label(15, Color(0.78, 0.76, 0.7), 0, 3)
		_orn_top = Ornament.new()
		_orn_top.position = Vector2(440, 30)
		_orn_top.size = Vector2(400, 12)
		_box.add_child(_orn_top)
		_name = _label(46, Color(0.96, 0.95, 0.92), 42, 6)
		_sub = _label(16, Color(0.66, 0.66, 0.7), 104, 1)
		_orn_bot = Ornament.new()
		_orn_bot.position = Vector2(500, 132)
		_orn_bot.size = Vector2(280, 12)
		_box.add_child(_orn_bot)
		_best = _label(14, Color(1, 0.82, 0.4), 150, 1)
		_exit = Label.new()
		_exit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_exit.size = Vector2(1280, 30)
		_exit.position = Vector2(0, 410)
		_exit.add_theme_font_size_override("font_size", 16)
		_exit.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		_exit.add_theme_color_override("font_outline_color", Color.BLACK)
		_exit.add_theme_constant_override("outline_size", 6)
		_exit.visible = false
		add_child(_exit)
		var hint := Label.new()
		hint.text = "Acércate a una estatua y pulsa %s para desafiarla  ·  casillero de la entrada: clase y técnicas  ·  %s volver al campus" % [GameState.btn("interact"), GameState.btn("back")]
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size = Vector2(1280, 20)
		hint.position = Vector2(0, 694)
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		add_child(hint)

	func _label(fs: int, col: Color, y: float, spacing: int) -> Label:
		var lb := Label.new()
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.size = Vector2(1280, fs + 12)
		lb.position = Vector2(0, y)
		var fv := FontVariation.new()
		fv.base_font = ThemeDB.fallback_font
		fv.spacing_glyph = spacing
		lb.add_theme_font_override("font", fv)
		lb.add_theme_font_size_override("font_size", fs)
		lb.add_theme_color_override("font_color", col)
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lb.add_theme_constant_override("outline_size", 6)
		_box.add_child(lb)
		return lb

	func _fade(to: float, time: float) -> void:
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween()
		_tw.tween_property(_box, "modulate:a", to, time)

	func area_title() -> void:
		_fac.text = "UNIVERSIDAD LAICA ELOY ALFARO DE MANABÍ"
		_name.text = "SALÓN DE LAS FACULTADES"
		_name.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
		_sub.text = "Ocho estatuas. Ocho errores fatales."
		_best.text = "%d / %d vencidos" % [GameState.bosses_defeated.size(), ORDER.size()]
		_orn_top.accent = Color(0.75, 0.65, 0.4)
		_orn_bot.accent = Color(0.75, 0.65, 0.4)
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween()
		_tw.tween_interval(0.4)
		_tw.tween_property(_box, "modulate:a", 1.0, 1.2)
		_tw.tween_interval(2.4)
		_tw.tween_property(_box, "modulate:a", 0.0, 1.2)

	func show_statue(st: Statue) -> void:
		var info: Array = Arena.BOSSES[st.kind]["title"]
		_fac.text = str(info[2]).to_upper()
		_name.text = st.boss_name
		_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5) if st.defeated else Color(0.96, 0.95, 0.92))
		_sub.text = str(info[1])
		_orn_top.accent = st.accent
		_orn_bot.accent = st.accent
		if st.defeated:
			var d: Dictionary = GameState.bosses_defeated.get(st.kind, {})
			var secs := int(d.get("time", 0))
			_best.text = "— VENCIDO —   Mejor rango %s  ·  %d:%02d" % [d.get("rank", "?"), secs / 60, secs % 60]
		else:
			_best.text = ""
		_fade(1.0, 0.45)

	func hide_statue() -> void:
		_fade(0.0, 0.35)

	func set_exit_prompt(on: bool) -> void:
		_exit.visible = on
		_exit.text = "%s  volver al campus" % GameState.btn("interact")


## Línea ornamental con un rombo al centro (estilo grabado).
class Ornament extends Control:
	var accent := Color(0.75, 0.65, 0.4)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var cy := size.y * 0.5
		var cx := size.x * 0.5
		var c := Color(0.78, 0.74, 0.62, 0.85)
		draw_line(Vector2(0, cy), Vector2(cx - 16, cy), c, 1.5)
		draw_line(Vector2(cx + 16, cy), Vector2(size.x, cy), c, 1.5)
		draw_circle(Vector2(0, cy), 2.0, c)
		draw_circle(Vector2(size.x, cy), 2.0, c)
		var d := 7.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - d), Vector2(cx + d, cy), Vector2(cx, cy + d), Vector2(cx - d, cy)]), accent)
		draw_polyline(PackedVector2Array([Vector2(cx, cy - d - 3), Vector2(cx + d + 3, cy), Vector2(cx, cy + d + 3), Vector2(cx - d - 3, cy), Vector2(cx, cy - d - 3)]), c, 1.0)
