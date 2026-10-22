extends Control
## Portada (sin nombre todavía): de noche, la fachada de la universidad iluminada por reflectores
## y delante las SOMBRAS de los 9 bosses (siluetas sacadas de sus estatuas, con luz de borde de su color).
## "PRESIONA START" -> menú 1 JUGADOR / 2 JUGADORES -> selección de personaje.
## Arte: si existe assets/sprites/title/title_bg.png (fachada pintada por grokbot) se usa en lugar
## del edificio dibujado por código.
## Escena: scenes/title.tscn (escena principal del proyecto).

const Style := preload("res://scripts/ui/ui_style.gd")
const InputSetup := preload("res://scripts/input_setup.gd")
const SILHOUETTE := preload("res://shaders/silhouette.gdshader")
const SELECT_SCENE := "res://scenes/player_select.tscn"
const BG_ART := "res://assets/sprites/title/title_bg.png"
const MUSIC := "res://assets/audio/title_theme.ogg"
const MUSIC_FALLBACK := "res://assets/audio/hall/hall_ambient.ogg"
const STATUE := "res://assets/sprites/statues/statue_%s.png"

## [boss, x, y de los pies, escala, color del borde]. El del centro va adelante y más grande.
const LINEUP := [
	["tex", 120, 560, 0.62, Color(1.0, 0.3, 1.0)],
	["sudo", 1160, 560, 0.62, Color(0.3, 0.9, 0.6)],
	["stack", 255, 600, 0.78, Color(1.0, 0.6, 0.15)],
	["kp", 1025, 600, 0.78, Color(1.0, 0.65, 0.2)],
	["div0", 390, 630, 0.9, Color(1.0, 0.78, 0.2)],
	["judge", 890, 630, 0.9, Color(0.9, 0.3, 0.3)],
	["bsod", 520, 660, 1.0, Color(0.3, 0.6, 1.0)],
	["syntax", 760, 660, 1.0, Color(0.45, 0.9, 0.55)],
	["deadbeef", 640, 700, 1.22, Color(1.0, 0.3, 0.2)],
]
const OPTIONS := ["1 JUGADOR", "2 JUGADORES"]

var _t := 0.0
var _phase := "press"     # press -> menu -> going
var _sel := 0
var _p1_device := -1
var _bg: Backdrop
var _front: Front
var _music: AudioStreamPlayer
var _figs: Array = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(1280, 720)
	_bg = Backdrop.new()
	add_child(_bg)
	var figs := Node2D.new()
	add_child(figs)
	for row in LINEUP:
		var path: String = STATUE % row[0]
		if not ResourceLoader.exists(path):
			continue
		var sp := Sprite2D.new()
		sp.texture = load(path)
		sp.centered = false
		var sc: float = row[3]
		sp.scale = Vector2(sc, sc)
		var tex_size: Vector2 = sp.texture.get_size()
		# los pies de la estatua están ~12 % arriba del borde de la imagen (pedestal)
		sp.position = Vector2(float(row[1]) - tex_size.x * sc * 0.5, float(row[2]) - tex_size.y * sc * 0.9)
		var mat := ShaderMaterial.new()
		mat.shader = SILHOUETTE
		mat.set_shader_parameter("rim_color", row[4])
		mat.set_shader_parameter("rim_px", 3.0 / sc)
		mat.set_shader_parameter("light_dir", Vector2(0.0, -1.0))
		sp.material = mat
		figs.add_child(sp)
		_figs.append([sp, mat, sp.position, randf() * TAU])
	_front = Front.new()
	_front.screen = self
	add_child(_front)
	_play_music()
	modulate = Color.BLACK
	create_tween().tween_property(self, "modulate", Color.WHITE, 1.2)


func _play_music() -> void:
	var path := MUSIC if ResourceLoader.exists(MUSIC) else MUSIC_FALLBACK
	if not ResourceLoader.exists(path):
		return
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = st
	_music.volume_db = -6.0
	add_child(_music)
	_music.play()


func _process(delta: float) -> void:
	_t += delta
	_bg.t = _t
	_front.t = _t
	# las sombras "respiran" y el borde late con los reflectores
	for f in _figs:
		var sp: Sprite2D = f[0]
		var mat: ShaderMaterial = f[1]
		var base: Vector2 = f[2]
		var ph: float = f[3]
		sp.position = base + Vector2(0, sin(_t * 1.3 + ph) * 1.5)
		mat.set_shader_parameter("rim", 0.75 + 0.25 * sin(_t * 2.0 + ph))
	_bg.queue_redraw()
	_front.queue_redraw()


func _input(event: InputEvent) -> void:
	if _phase == "going":
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.is_echo()) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if _phase == "press":
		if pressed:
			_p1_device = InputSetup.event_device(event)
			_phase = "menu"
			_front.pop = 1.0
			get_viewport().set_input_as_handled()
		return
	# menú
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_sel = (_sel + OPTIONS.size() - 1) % OPTIONS.size()
		_front.pop = 0.6
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % OPTIONS.size()
		_front.pop = 0.6
	elif event.is_action_pressed("interact") or event.is_action_pressed("action_primary") or event.is_action_pressed("ui_accept") \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START):
		_choose()
	elif event.is_action_pressed("back"):
		_phase = "press"
	else:
		return
	get_viewport().set_input_as_handled()


func _choose() -> void:
	_phase = "going"
	if _sel == 1:
		GameState.coop = true
		GameState.devices = [_p1_device if _p1_device >= -1 else -1, -9]   # el jugador 2 se une en la selección
	else:
		GameState.setup_coop(false)
	_front.flash = 1.0
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(self, "modulate", Color.BLACK, 0.5)
	if _music:
		create_tween().tween_property(_music, "volume_db", -40.0, 0.8)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(SELECT_SCENE))


# ==================================================================================
## Cielo, reflectores y la fachada de la universidad (o el arte de grokbot si existe).
class Backdrop extends Node2D:
	var t := 0.0
	var _art: Texture2D
	var _stars: Array = []

	func _ready() -> void:
		if ResourceLoader.exists(BG_ART):
			_art = load(BG_ART)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 90:
			_stars.append([Vector2(rng.randf() * 1280, rng.randf() * 330), rng.randf_range(0.6, 1.8), rng.randf() * TAU])

	func _draw() -> void:
		if _art:
			draw_texture_rect(_art, Rect2(0, 0, 1280, 720), false)
			_beams(0.5)
			return
		# cielo de anochecer: violeta arriba, naranja en el horizonte (Manta mira al mar)
		var top := Color(0.06, 0.04, 0.16)
		var mid := Color(0.24, 0.1, 0.3)
		var low := Color(0.85, 0.38, 0.22)
		for i in 72:
			var k := i / 71.0
			var c := top.lerp(mid, minf(1.0, k * 1.6)) if k < 0.62 else mid.lerp(low, (k - 0.62) / 0.38)
			draw_rect(Rect2(0, i * 6.0, 1280, 6.5), c)
		for s in _stars:
			var a := 0.35 + 0.35 * sin(t * 2.0 + float(s[2]))
			draw_circle(s[0], s[1], Color(1, 1, 1, a))
		# luna
		draw_circle(Vector2(1080, 92), 34, Color(1.0, 0.95, 0.85, 0.12))
		draw_circle(Vector2(1080, 92), 26, Color(1.0, 0.96, 0.88))
		draw_circle(Vector2(1070, 86), 6, Color(0.88, 0.85, 0.78))
		_beams(1.0)
		_building()

	## Reflectores que barren el cielo detrás del edificio.
	func _beams(alpha: float) -> void:
		for i in 4:
			var base := Vector2(260 + i * 250, 430)
			var ang := -PI * 0.5 + sin(t * 0.5 + i * 1.7) * 0.42
			var dir := Vector2(cos(ang), sin(ang))
			var side := Vector2(-dir.y, dir.x)
			var tip := base + dir * 700.0
			var col := Color(1.0, 0.95, 0.8, 0.07 * alpha)
			draw_colored_polygon(PackedVector2Array([base - side * 6, base + side * 6, tip + side * 70, tip - side * 70]), col)
			draw_colored_polygon(PackedVector2Array([base - side * 3, base + side * 3, tip + side * 25, tip - side * 25]), Color(col, col.a * 1.4))

	## Fachada inspirada en la ULEAM: bloque largo de aulas, pórtico de columnas con el escudo,
	## torre del reloj, banderas y palmeras de la costa.
	func _building() -> void:
		var wall := Color(0.13, 0.12, 0.25)
		var wall2 := Color(0.17, 0.15, 0.31)
		var trim := Color(0.28, 0.24, 0.42)
		var win_on := Color(1.0, 0.82, 0.45)
		var win_off := Color(0.08, 0.08, 0.16)
		# alas laterales (3 pisos)
		for side in [-1, 1]:
			var x0: float = 640.0 + side * 150.0
			var x1: float = 640.0 + side * 600.0
			var r := Rect2(minf(x0, x1), 330, absf(x1 - x0), 170)
			draw_rect(r, wall)
			draw_rect(Rect2(r.position.x, r.position.y - 8, r.size.x, 10), trim)
			for fl in 3:
				var y := r.position.y + 18 + fl * 50
				draw_rect(Rect2(r.position.x, y + 34, r.size.x, 4), wall2)
				var nwin := int(r.size.x / 36.0)
				for w in nwin:
					var wx := r.position.x + 10 + w * 36
					var lit := (int(wx * 7 + fl * 13) % 5) != 0
					var flick := lit and sin(t * 0.7 + wx) > -0.95
					draw_rect(Rect2(wx, y, 22, 28), win_on if flick else win_off)
					draw_rect(Rect2(wx, y + 13, 22, 2), wall)
		# cuerpo central con pórtico
		var c := Rect2(470, 270, 340, 230)
		draw_rect(c, wall2)
		draw_colored_polygon(PackedVector2Array([Vector2(450, 272), Vector2(640, 215), Vector2(830, 272)]), trim)
		draw_colored_polygon(PackedVector2Array([Vector2(472, 268), Vector2(640, 226), Vector2(808, 268)]), wall)
		# escudo (círculo con libro abierto y llama)
		var e := Vector2(640, 252)
		draw_circle(e, 15, Color(0.9, 0.75, 0.3))
		draw_circle(e, 12, Color(0.12, 0.2, 0.45))
		draw_colored_polygon(PackedVector2Array([e + Vector2(-8, 2), e + Vector2(0, 5), e + Vector2(8, 2), e + Vector2(8, 7), e + Vector2(0, 9), e + Vector2(-8, 7)]), Color(1, 1, 1))
		draw_colored_polygon(PackedVector2Array([e + Vector2(0, -9), e + Vector2(3, -2), e + Vector2(0, 2), e + Vector2(-3, -2)]), Color(1.0, 0.6, 0.2))
		for i in 6:
			var x := 492 + i * 58
			draw_rect(Rect2(x, 290, 16, 210), Color(0.32, 0.28, 0.48))
			draw_rect(Rect2(x - 3, 286, 22, 6), trim)
			draw_rect(Rect2(x + 11, 292, 3, 206), Color(0.2, 0.18, 0.32))
		# puerta iluminada
		draw_rect(Rect2(600, 410, 80, 90), Color(1.0, 0.78, 0.4))
		draw_rect(Rect2(638, 410, 4, 90), Color(0.5, 0.35, 0.2))
		# torre del reloj
		var tw := Rect2(700, 120, 70, 150)
		draw_rect(tw, wall)
		draw_rect(Rect2(tw.position.x - 6, tw.position.y - 10, tw.size.x + 12, 12), trim)
		draw_colored_polygon(PackedVector2Array([Vector2(694, 110), Vector2(735, 70), Vector2(776, 110)]), wall2)
		var ck := Vector2(735, 160)
		draw_circle(ck, 20, Color(1.0, 0.95, 0.75))
		draw_circle(ck, 17, Color(0.98, 0.9, 0.65))
		draw_line(ck, ck + Vector2.from_angle(t * 0.05 - PI * 0.5) * 12, Color(0.1, 0.1, 0.15), 2.5)
		draw_line(ck, ck + Vector2.from_angle(t * 0.6 - PI * 0.5) * 15, Color(0.1, 0.1, 0.15), 1.5)
		for i in 3:
			draw_rect(Rect2(712 + i * 18, 200, 10, 26), win_on)
		# banderas
		for i in 3:
			var px := 560 + i * 80
			draw_line(Vector2(px, 300), Vector2(px, 196), Color(0.6, 0.6, 0.65), 2)
			var cols := [Color(0.1, 0.35, 0.75), Color(1.0, 0.85, 0.2), Color(0.85, 0.15, 0.2)]
			var pts := PackedVector2Array()
			for k in 9:
				var u := k / 8.0
				pts.append(Vector2(px + u * 30, 198 + sin(t * 4.0 + u * 5.0 + i) * 2.5 * u))
			for k in range(8, -1, -1):
				var u2 := k / 8.0
				pts.append(Vector2(px + u2 * 30, 214 + sin(t * 4.0 + u2 * 5.0 + i) * 2.5 * u2))
			draw_colored_polygon(pts, cols[i])
		# piso / plaza
		draw_rect(Rect2(0, 498, 1280, 222), Color(0.07, 0.06, 0.12))
		for i in 12:
			draw_line(Vector2(640, 498), Vector2(-400 + i * 190, 720), Color(1, 1, 1, 0.03), 2)
		# palmeras a los lados
		for p in [Vector2(70, 500), Vector2(1215, 500), Vector2(330, 500), Vector2(960, 500)]:
			_palm(p, 0.8 if p.x < 300 or p.x > 1000 else 0.6)

	func _palm(base: Vector2, s: float) -> void:
		var col := Color(0.03, 0.03, 0.07)
		var top := base + Vector2(14 * s, -170 * s)
		var pts := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			pts.append(base.lerp(top, u) + Vector2(sin(u * 2.4) * 10 * s, 0) + Vector2(-4 * s * (1 - u), 0))
		for i in range(8, -1, -1):
			var u2 := i / 8.0
			pts.append(base.lerp(top, u2) + Vector2(sin(u2 * 2.4) * 10 * s, 0) + Vector2(4 * s * (1 - u2) + 2, 0))
		draw_colored_polygon(pts, col)
		for k in 7:
			var a := -PI + k * PI / 6.0 + sin(t * 1.2 + k) * 0.05
			var d := Vector2.from_angle(a)
			var mid := top + d * 40 * s + Vector2(0, -6 * s)
			var end := top + d * 75 * s + Vector2(0, 22 * s)
			draw_colored_polygon(PackedVector2Array([top, mid + d.orthogonal() * 7 * s, end, mid - d.orthogonal() * 4 * s]), col)


# ==================================================================================
## Niebla del piso, viñeta y menú.
class Front extends Node2D:
	var screen: Node
	var t := 0.0
	var pop := 0.0
	var flash := 0.0

	func _process(delta: float) -> void:
		pop = maxf(0.0, pop - delta * 3.0)
		flash = maxf(0.0, flash - delta * 2.5)

	func _draw() -> void:
		# niebla que se mueve entre las sombras
		for i in 6:
			var y := 600.0 + i * 22.0
			var x := fmod(t * (14.0 + i * 5.0), 400.0)
			for k in 5:
				draw_circle(Vector2(-200 + k * 400 + x, y), 150 - i * 8, Color(0.6, 0.55, 0.85, 0.035))
		# viñeta
		for i in 10:
			var a := 0.05 * (10 - i) / 10.0
			draw_rect(Rect2(0, 0, 1280, 26 - i * 2), Color(0, 0, 0, a * 4))
			draw_rect(Rect2(0, 694 + i * 2, 1280, 26), Color(0, 0, 0, a * 4))
		var phase: String = screen.get("_phase")
		if phase == "press":
			if fmod(t, 1.1) < 0.75:
				Style.title(self, Vector2(640, 610), "PRESIONA START", 40, Color(1.0, 0.92, 0.35), Color(0.08, 0.04, 0.12), HORIZONTAL_ALIGNMENT_CENTER, 800)
			Style.title(self, Vector2(640, 650), "Enter  ·  A", 18, Color(0.85, 0.85, 0.95), Color(0.05, 0.03, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 400, 0.0)
		else:
			var sel: int = screen.get("_sel")
			for i in OPTIONS.size():
				var y := 585.0 + i * 58.0
				var on := i == sel
				var r := Rect2(440, y - 40, 400, 50)
				if on:
					var grow := 6.0 * pop
					var rr := r.grow(grow)
					draw_colored_polygon(Style.slanted(rr, 18), Color(0.05, 0.03, 0.12, 0.85))
					draw_polyline(Style.slanted(rr, 18) + PackedVector2Array([Style.slanted(rr, 18)[0]]), Color(1.0, 0.85, 0.3), 3.0)
					var ax := 420.0 + sin(t * 8.0) * 5.0
					draw_colored_polygon(PackedVector2Array([Vector2(ax, y - 25), Vector2(ax + 16, y - 15), Vector2(ax, y - 5)]), Color(1.0, 0.85, 0.3))
				Style.title(self, Vector2(640, y), OPTIONS[i], 34 if on else 28,
					Color(1.0, 0.92, 0.35) if on else Color(0.7, 0.7, 0.85), Color(0.08, 0.04, 0.12), HORIZONTAL_ALIGNMENT_CENTER, 400)
			if sel == 1:
				Style.title(self, Vector2(640, 706), "Pantalla compartida: si se alejan, se divide sola", 16, Color(0.8, 0.85, 1.0), Color(0.05, 0.03, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 700, 0.0)
		if flash > 0.0:
			draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, flash * 0.6))
