extends Node2D
## Arena de los bosses. Abrir scenes/combat/boss_test.tscn y pulsar F6 (o entrar por la puerta del campus).
## Qué boss sale lo decide `boss_kind` (la puerta del campus lo pone antes de cambiar de escena).
## F2 = saltar a la siguiente fase (solo para probar). R = reintentar al ganar/perder.

const PlayerScene := preload("res://scenes/combat/player.tscn")
const BossHud := preload("res://scripts/combat/boss_hud.gd")
const ArenaFx := preload("res://scripts/combat/boss_arena_fx.gd")
## Datos de cada boss: script, nombre, presentación, texto de victoria y piso.
const BOSSES := {
	"deadbeef": {
		"script": "res://scripts/combat/boss_deadbeef.gd",
		"name": "0xDEADBEEF",
		"title": ["> FATAL: 0xDEADBEEF", "Sistema agroindustrial fuera de control", "Facultad de Ciencias de la Vida y Tecnología"],
		"win": "> SISTEMA RESTAURADO",
		"floor": "agro",
	},
	"bsod": {
		"script": "res://scripts/combat/boss_bsod.gd",
		"name": "B.S.O.D.",
		"title": ["> FATAL: B.S.O.D.", "Sistema de salud en paro crítico", "Facultad de Ciencias de la Salud"],
		"win": "> PACIENTE ESTABLE",
		"floor": "hospital",
	},
	"div0": {
		"script": "res://scripts/combat/boss_div0.gd",
		"name": "#DIV/0!",
		"title": ["> FATAL: #DIV/0!", "Mercado en caída libre", "Facultad de Ciencias Administrativas, Contables y Comercio"],
		"win": "> BALANCE CUADRADO",
		"floor": "bolsa",
	},
	"syntax": {
		"script": "res://scripts/combat/boss_syntax.gd",
		"name": "SYNTAX ERROR",
		"title": ["> ERROR: SYNTAX ERROR", "Clase obligatoria", "Facultad de Educación, Turismo y Humanidades"],
		"win": "> CURSO APROBADO",
		"floor": "aula",
	},
	"stack": {
		"script": "res://scripts/combat/boss_stack.gd",
		"name": "STACK OVERFLOW",
		"title": ["> FATAL: STACK OVERFLOW", "Obra fuera de control", "Facultad de Ingeniería, Industria y Arquitectura"],
		"win": "> OBRA ENTREGADA",
		"floor": "obra",
	},
	"judge": {
		"script": "res://scripts/combat/boss_judge.gd",
		"name": "403 FORBIDDEN",
		"title": ["> ERROR 403: FORBIDDEN", "Acceso denegado a la justicia", "Facultad de Ciencias Sociales, Derecho y Bienestar"],
		"win": "> CASO CERRADO",
		"floor": "juzgado",
	},
	"tex": {
		"script": "res://scripts/combat/boss_tex.gd",
		"name": "MISSING TEXTURE",
		"title": ["> ERROR: MISSING TEXTURE", "La obra que nadie terminó de cargar", "Facultad de Artes, Humanidades y Patrimonio"],
		"win": "> TEXTURA CARGADA",
		"floor": "museo",
	},
	"kp": {
		"script": "res://scripts/combat/boss_kp.gd",
		"name": "KERNEL PANIC",
		"title": ["> FATAL: KERNEL PANIC", "El programa que no se puede apagar", "Unidad de Formación Técnicas y Tecnológicas"],
		"win": "> SEÑAL RESTABLECIDA",
		"floor": "estudio",
	},
}

## Boss de esta arena ("deadbeef", "bsod", "div0", "syntax", "stack", "judge", "tex" o "kp").
static var boss_kind: String = "deadbeef"

## Al salir (Esc, o tras ganar/perder) se vuelve al Salón de las Facultades.
const CAMPUS_SCENE := "res://scenes/combat/boss_hall.tscn"
const ARENA := Rect2(-520, -330, 1040, 660)
## Música de cada boss: <boss>_p1/_p2/_p3 (una por fase, cada vez más intensa), _win al vencerlo y lose.ogg al perder.
## Generada por tools/boss_music.py. La fase 1 trae una intro de 2 compases y hace loop desde aquí (segundos).
const MUSIC_DIR := "res://assets/audio/bosses/"
const MUSIC_INTRO := {"deadbeef": 3.2, "bsod": 4.0, "div0": 3.75, "syntax": 3.8095, "stack": 3.3333, "judge": 4.0678, "tex": 2.4, "kp": 3.2877}
const MUSIC_DB := -6.0
const WALL := 40.0

## true = reintento: se salta la aparición larga y la presentación.
static var retry: bool = false

var player: CharacterBody2D
var boss: CharacterBody2D
var _dim: CanvasModulate
var _bar_box: VBoxContainer
var _bar: ProgressBar
var _chip: ProgressBar
var _hud_layer: CanvasLayer
var _chip_tw: Tween
var _t0: int = 0
var _hits_taken: int = 0
var _weak_hits: int = 0
var _last_player_hp: int = -1
var _phase_label: Label
var _banner: Label
var _end_box: Control
var _end_title: Label
var _end_sub: Label
var _over: bool = false
var _fighting: bool = false
var _music: AudioStreamPlayer
var _music_phase: int = 0
## true si un boss ya tocó su propio final (p. ej. el duelo final del juez) y no hay que tocar el _win normal.
var _end_music_done: bool = false
var _boss_hud: Control
var _backdrop: Node2D
var _motes: Node2D
var _vignette: CanvasLayer


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cfg: Dictionary = BOSSES.get(boss_kind, BOSSES["deadbeef"])
	# fondo pintado (GROKBOT_ARENAS.md) o, si todavía no está, el piso dibujado por código
	if ArenaFx.has_backdrop(boss_kind):
		_backdrop = ArenaFx.Backdrop.new()
		_backdrop.kind = boss_kind
		_backdrop.arena = ARENA
		add_child(_backdrop)
	else:
		var floor_node := Floor.new()
		floor_node.arena = ARENA
		floor_node.style = cfg["floor"]
		add_child(floor_node)
	_motes = ArenaFx.Motes.new()
	_motes.kind = boss_kind
	_motes.arena = ARENA
	add_child(_motes)
	_vignette = ArenaFx.Vignette.new()
	_vignette.kind = boss_kind
	add_child(_vignette)
	_build_walls()
	player = PlayerScene.instantiate()
	player.position = Vector2(0, 230)
	add_child(player)
	player.set("exit_scene", CAMPUS_SCENE)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		# boss grande: la cámara se aleja un poco para que entre entero
		cam.zoom = Vector2.ONE
		cam.limit_left = int(ARENA.position.x - WALL)
		cam.limit_top = int(ARENA.position.y - 110)
		cam.limit_right = int(ARENA.end.x + WALL)
		cam.limit_bottom = int(ARENA.end.y + WALL)
	boss = load(cfg["script"]).new()
	boss.name = "Boss"
	boss.position = Vector2(0, -40)
	boss.set("arena_rect", ARENA)
	add_child(boss)
	boss.call("set_player", player)
	_dim = CanvasModulate.new()
	add_child(_dim)
	_build_hud()
	# barra del boss con la forma de su mecánica (boss_hud.gd); reemplaza los paneles viejos de cada boss
	_boss_hud = BossHud.make(boss_kind, boss)
	_boss_hud.visible = false
	_hud_layer.add_child(_boss_hud)
	boss.connect("hp_changed", _on_boss_hp)
	boss.connect("phase_changed", _on_phase)
	boss.connect("stunned", _on_stunned)
	boss.connect("staggered", _on_staggered)
	if boss.has_signal("arm_broken"):
		boss.connect("arm_broken", _on_arm_broken)
	boss.connect("intro_finished", _on_intro_done)
	boss.connect("defeated", _on_victory)
	player.connect("hp_changed", _on_player_hp)
	_lock_player(true)
	if not retry:
		_dim.color = Color(0.5, 0.5, 0.6)
	boss.call("start_intro", retry)


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var c := ARENA.get_center()
	var rects := [
		Rect2(ARENA.position.x - WALL, ARENA.position.y - WALL, ARENA.size.x + WALL * 2, WALL),
		Rect2(ARENA.position.x - WALL, ARENA.end.y, ARENA.size.x + WALL * 2, WALL),
		Rect2(ARENA.position.x - WALL, ARENA.position.y, WALL, ARENA.size.y),
		Rect2(ARENA.end.x, ARENA.position.y, WALL, ARENA.size.y),
	]
	for r in rects:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.get_center()
		walls.add_child(cs)
	walls.position = Vector2.ZERO
	assert(c == ARENA.get_center())


func _lock_player(on: bool) -> void:
	if not is_instance_valid(player):
		return
	player.set_physics_process(not on)
	player.set_process_unhandled_input(not on)
	if on:
		player.velocity = Vector2.ZERO


# --- HUD --------------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud_layer = layer
	_bar_box = VBoxContainer.new()
	_bar_box.position = Vector2(340, 14)
	_bar_box.custom_minimum_size = Vector2(600, 0)
	_bar_box.visible = false
	layer.add_child(_bar_box)
	var row := HBoxContainer.new()
	_bar_box.add_child(row)
	var name_label := Label.new()
	name_label.text = BOSSES[boss_kind]["name"]
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1, 0.45, 0.35))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	_phase_label = Label.new()
	_phase_label.text = "Fase 1/3"
	_phase_label.add_theme_font_size_override("font_size", 14)
	row.add_child(_phase_label)
	# barra con "chip": lo que se acaba de perder queda en blanco un momento y luego baja
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(600, 16)
	_bar_box.add_child(stack)
	_chip = ProgressBar.new()
	_chip.size = Vector2(600, 16)
	_chip.show_percentage = false
	_chip.value = 100.0
	var chip_fill := StyleBoxFlat.new()
	chip_fill.bg_color = Color(1, 0.95, 0.85)
	_chip.add_theme_stylebox_override("fill", chip_fill)
	stack.add_child(_chip)
	_bar = ProgressBar.new()
	_bar.size = Vector2(600, 16)
	_bar.show_percentage = false
	_bar.value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.2, 0.25)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	stack.add_child(_bar)
	# marcas de cambio de fase
	for f in [0.6, 0.3]:
		var tick := ColorRect.new()
		tick.color = Color(0, 0, 0, 0.8)
		tick.size = Vector2(3, 16)
		tick.position = Vector2(600 * f - 1, 0)
		stack.add_child(tick)

	_banner = Label.new()
	_banner.position = Vector2(0, 150)
	_banner.size = Vector2(1280, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	layer.add_child(_banner)

	var hint := Label.new()
	hint.text = "Q / R3 fijar objetivo  ·  F2 saltar fase  ·  F1 llenar ultimate  ·  Esc volver"
	hint.position = Vector2(760, 694)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.7))
	layer.add_child(hint)

	_end_box = Control.new()
	_end_box.visible = false
	_end_box.size = Vector2(1280, 720)
	layer.add_child(_end_box)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.size = Vector2(1280, 720)
	_end_box.add_child(shade)
	_end_title = Label.new()
	_end_title.position = Vector2(0, 280)
	_end_title.size = Vector2(1280, 60)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override("font_size", 44)
	_end_box.add_child(_end_title)
	_end_sub = Label.new()
	_end_sub.position = Vector2(0, 350)
	_end_sub.size = Vector2(1280, 40)
	_end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_sub.add_theme_font_size_override("font_size", 18)
	_end_box.add_child(_end_sub)


func _show_banner(text: String, col: Color, hold: float = 1.2) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(1.0, 1.0)
	var tw := _banner.create_tween()
	tw.tween_interval(hold)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


## Pantalla de presentación: franja tipo terminal que escribe letra por letra.
func _title_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var strip := ColorRect.new()
	strip.color = Color(0.02, 0.03, 0.03, 0.92)
	strip.size = Vector2(1280, 180)
	strip.position = Vector2(-1280, 250)
	layer.add_child(strip)
	var lines := [
		[BOSSES[boss_kind]["title"][0], 44, Color(0.45, 1.0, 0.5)],
		[BOSSES[boss_kind]["title"][1], 20, Color(1, 0.6, 0.4)],
		[BOSSES[boss_kind]["title"][2], 16, Color(0.75, 0.75, 0.75)],
	]
	var labels: Array[Label] = []
	var y := 30.0
	for l in lines:
		var lb := Label.new()
		lb.text = l[0]
		lb.position = Vector2(140, y)
		lb.add_theme_font_size_override("font_size", l[1])
		lb.add_theme_color_override("font_color", l[2])
		lb.visible_ratio = 0.0
		strip.add_child(lb)
		labels.append(lb)
		y += float(l[1]) + 18.0
	var tw := create_tween()
	tw.tween_property(strip, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(labels[0], "visible_ratio", 1.0, 0.6)
	tw.tween_property(labels[1], "visible_ratio", 1.0, 0.45)
	tw.tween_property(labels[2], "visible_ratio", 1.0, 0.35)
	tw.tween_interval(0.9)
	tw.tween_property(strip, "position:x", 1280.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	layer.queue_free()


# --- Eventos ----------------------------------------------------------------------

func _on_intro_done() -> void:
	if not retry:
		await _title_card()
	_start_fight()


func _start_fight() -> void:
	create_tween().tween_property(_dim, "color", Color.WHITE, 0.5)
	_boss_hud.visible = true
	_lock_player(false)
	_fighting = true
	retry = true
	_t0 = Time.get_ticks_msec()
	boss.call("begin_fight")
	_play_music()


func _music_stream(part: String, loop: bool, loop_from: float = 0.0) -> AudioStream:
	var path: String = MUSIC_DIR + boss_kind + "_" + part + ".ogg"
	if part == "lose":
		path = MUSIC_DIR + "lose.ogg"
	if not ResourceLoader.exists(path):
		return null
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		st.loop = loop
		st.loop_offset = loop_from
	return st


## Toca la música de la fase (con fundido cruzado desde la anterior).
func _play_music(phase: int = 1) -> void:
	if phase <= _music_phase:
		return
	var st := _music_stream("p%d" % phase, true, MUSIC_INTRO.get(boss_kind, 0.0) if phase == 1 else 0.0)
	if st == null:
		return
	_music_phase = phase
	_stop_music(0.6)
	_music = AudioStreamPlayer.new()
	_music.stream = st
	_music.volume_db = -30.0 if phase == 1 else -12.0
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 0.6 if phase == 1 else 0.3)


func _stop_music(time: float) -> void:
	if _music == null:
		return
	var old := _music
	_music = null
	var tw := create_tween()
	tw.tween_property(old, "volume_db", -40.0, time)
	tw.tween_callback(old.queue_free)


## Lo llama un boss para cambiar a un loop concreto (p. ej. "final1".."final3" del duelo del juez, o volver a "p3").
func music_cue(part: String) -> void:
	if _over:
		return
	var st := _music_stream(part, true, 0.0)
	if st == null:
		return
	if part.begins_with("p") and part.substr(1).is_valid_int():
		_music_phase = int(part.substr(1))
	_stop_music(0.35)
	_music = AudioStreamPlayer.new()
	_music.stream = st
	_music.volume_db = -14.0
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 0.3)


## Lo llama un boss que trae su propio cierre (se toca ya, antes de la animación de muerte).
func music_final(part: String) -> void:
	_end_music_done = true
	_music_end(part)


## Final de la pelea: corta el loop y toca el cierre (victoria del boss o derrota del jugador).
func _music_end(part: String) -> void:
	_stop_music(0.25)
	_music_phase = 99
	var st := _music_stream(part, false)
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = MUSIC_DB
	add_child(p)
	p.play()


func _on_boss_hp(hp: int, max_hp: int) -> void:
	_bar.value = 100.0 * hp / max_hp
	if _chip_tw and _chip_tw.is_valid():
		_chip_tw.kill()
	_chip_tw = create_tween()
	_chip_tw.tween_interval(0.45)
	_chip_tw.tween_property(_chip, "value", _bar.value, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if boss.get("tank_open"):
		_weak_hits += 1


func _on_phase(phase: int, title: String) -> void:
	_phase_label.text = "Fase %d/3" % phase
	_show_banner(title, Color(1, 0.35, 0.3), 1.0)
	_set_ambient_phase(phase)
	if _fighting and not _over:
		_play_music(phase)


## Luz, viñeta, partículas y fondo de la fase.
func _set_ambient_phase(phase: int) -> void:
	_motes.set("phase", phase)
	_vignette.set("phase", phase)
	_vignette.call("alarm")
	if _backdrop:
		_backdrop.call("set_phase", phase)
	if _over or phase < 2:
		return
	var tints: Array = ArenaFx.cfg(boss_kind)["tint"]
	create_tween().tween_property(_dim, "color", tints[mini(phase, 3) - 2], 1.0)


func _on_stunned() -> void:
	_show_banner("¡PUNTO DÉBIL!  daño x2", Color(1, 0.95, 0.4), 1.4)


func _on_arm_broken(_arm: String) -> void:
	_show_banner("¡BRAZO DESTRUIDO!", Color(1, 0.6, 0.3), 1.0)


func _on_staggered() -> void:
	_show_banner("¡SE TAMBALEA!", Color(1, 0.8, 0.5), 0.6)


func _on_player_hp(hp: int, _max_hp: int) -> void:
	if _last_player_hp >= 0 and hp < _last_player_hp and _fighting:
		_hits_taken += 1
	_last_player_hp = hp
	if hp > 0 or _over:
		return
	_over = true
	boss.call("pause_ai")
	_music_end("lose")
	_end_title.text = "CRASH DEL ESTUDIANTE"
	_end_title.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	_end_sub.text = _end_keys("reintentar")
	await get_tree().create_timer(1.0).timeout
	_lock_player(true)
	_end_box.visible = true


func _on_victory() -> void:
	_over = true
	if not _end_music_done:
		_music_end("win")
	_fighting = false
	retry = false
	_boss_hud.visible = false
	_lock_player(true)
	_end_title.text = BOSSES[boss_kind]["win"]
	_end_title.add_theme_color_override("font_color", Color(0.45, 1.0, 0.5))
	var secs := int((Time.get_ticks_msec() - _t0) / 1000.0)
	var rank := "S" if _hits_taken <= 2 else ("A" if _hits_taken <= 5 else ("B" if _hits_taken <= 9 else "C"))
	GameState.record_victory(boss_kind, rank, secs)   # el salón dora la estatua
	_end_sub.text = "Rango %s  ·  Tiempo %d:%02d  ·  Golpes recibidos %d  ·  Golpes al punto débil %d\n%s" % [rank, secs / 60, secs % 60, _hits_taken, _weak_hits, _end_keys("repetir")]
	_end_sub.size.y = 60
	_end_box.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("debug_next_phase") and _fighting and not _over:
		boss.call("debug_next_phase")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("retry") and _over and _end_box.visible:
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene.call_deferred()
	elif event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file.call_deferred(CAMPUS_SCENE)


## "R reintentar · Esc volver" o "Start reintentar · Select volver" según el control.
func _end_keys(word: String) -> String:
	return "%s %s  ·  %s volver al salón" % [GameState.btn("retry"), word, GameState.btn("back")]


## Piso de invernadero/laboratorio (provisional).
class Floor extends Node2D:
	var arena: Rect2
	var style := "agro"

	func _ready() -> void:
		z_index = -10

	func _draw() -> void:
		if style == "hospital":
			_hospital()
			return
		if style == "bolsa":
			_bolsa()
			return
		if style == "aula":
			_aula()
			return
		if style == "obra":
			_obra()
			return
		if style == "juzgado":
			_juzgado()
			return
		if style == "museo":
			_museo()
			return
		if style == "estudio":
			_estudio()
			return
		draw_rect(arena.grow(140.0), Color(0.16, 0.18, 0.17))
		var tile := 48.0
		var y := arena.position.y
		var row := 0
		while y < arena.end.y:
			var x := arena.position.x
			var col := 0
			while x < arena.end.x:
				var c := Color(0.36, 0.42, 0.38) if (row + col) % 2 == 0 else Color(0.33, 0.39, 0.35)
				draw_rect(Rect2(x, y, minf(tile, arena.end.x - x), minf(tile, arena.end.y - y)), c)
				x += tile
				col += 1
			y += tile
			row += 1
		# muro con jardineras y monitores (decoración)
		draw_rect(Rect2(arena.position.x - 40, arena.position.y - 100, arena.size.x + 80, 100), Color(0.5, 0.52, 0.55))
		for i in 6:
			var px := arena.position.x + 60 + i * 170
			draw_rect(Rect2(px, arena.position.y - 34, 110, 30), Color(0.45, 0.3, 0.18))
			for j in 5:
				draw_circle(Vector2(px + 12 + j * 22, arena.position.y - 38), 9, Color(0.3, 0.6, 0.25))
		for i in 3:
			var mx := arena.position.x + 200 + i * 320
			draw_rect(Rect2(mx, arena.position.y - 92, 70, 44), Color(0.1, 0.1, 0.12))
			draw_rect(Rect2(mx + 5, arena.position.y - 87, 60, 34), Color(0.15, 0.05, 0.05))
			draw_string(ThemeDB.fallback_font, Vector2(mx + 5, arena.position.y - 64), "ERROR", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1, 0.3, 0.25))
		draw_rect(arena, Color(0.1, 0.12, 0.1), false, 4.0)

	## Quirófano: baldosas blancas y verde agua, cortinas, lámparas y monitores.
	func _hospital() -> void:
		draw_rect(arena.grow(140.0), Color(0.14, 0.17, 0.18))
		var tile := 40.0
		var y := arena.position.y
		var row := 0
		while y < arena.end.y:
			var x := arena.position.x
			var col := 0
			while x < arena.end.x:
				var c := Color(0.78, 0.84, 0.84) if (row + col) % 2 == 0 else Color(0.62, 0.78, 0.76)
				draw_rect(Rect2(x, y, minf(tile, arena.end.x - x), minf(tile, arena.end.y - y)), c)
				x += tile
				col += 1
			y += tile
			row += 1
		# línea guía del piso (como en los pasillos de hospital)
		draw_rect(Rect2(arena.position.x, arena.get_center().y - 3, arena.size.x, 6), Color(0.3, 0.6, 0.85, 0.5))
		# pared con cortinas verdes y monitores
		draw_rect(Rect2(arena.position.x - 40, arena.position.y - 100, arena.size.x + 80, 100), Color(0.85, 0.88, 0.88))
		for i in 7:
			var px := arena.position.x + 20 + i * 150
			for j in 6:
				draw_rect(Rect2(px + j * 16, arena.position.y - 92, 14, 78), Color(0.35, 0.62, 0.55) if j % 2 == 0 else Color(0.3, 0.55, 0.49))
			draw_rect(Rect2(px - 4, arena.position.y - 96, 104, 4), Color(0.6, 0.6, 0.62))
		for i in 3:
			var mx := arena.position.x + 230 + i * 300
			draw_rect(Rect2(mx, arena.position.y - 88, 70, 44), Color(0.1, 0.1, 0.12))
			draw_rect(Rect2(mx + 5, arena.position.y - 83, 60, 34), Color(0.02, 0.1, 0.05))
			var pts := PackedVector2Array()
			for k in 13:
				var kx := mx + 6 + k * 4.8
				var ky := arena.position.y - 66 + (-12.0 if k == 6 else (8.0 if k == 7 else 0.0))
				pts.append(Vector2(kx, ky))
			draw_polyline(pts, Color(0.4, 1.0, 0.5), 2.0)
		# lámparas quirúrgicas en las esquinas
		for c in [Vector2(arena.position.x + 70, arena.position.y + 60), Vector2(arena.end.x - 70, arena.position.y + 60)]:
			draw_circle(c, 34, Color(1, 1, 0.9, 0.12))
			draw_circle(c, 20, Color(0.75, 0.78, 0.8))
			draw_circle(c, 14, Color(1, 1, 0.92))
		draw_rect(arena, Color(0.2, 0.3, 0.32), false, 4.0)


	## Piso de la bolsa: alfombra de oficina, pared con pizarras de cotizaciones.
	func _bolsa() -> void:
		draw_rect(arena.grow(140.0), Color(0.1, 0.1, 0.13))
		draw_rect(arena, Color(0.26, 0.2, 0.3))
		var tile := 52.0
		var y := arena.position.y
		var row := 0
		while y < arena.end.y:
			var x := arena.position.x
			var col := 0
			while x < arena.end.x:
				if (row + col) % 2 == 0:
					draw_rect(Rect2(x, y, minf(tile, arena.end.x - x), minf(tile, arena.end.y - y)), Color(0.29, 0.22, 0.33))
				x += tile
				col += 1
			y += tile
			row += 1
		# círculo del piso de remates
		var c := arena.get_center()
		var pts := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a) * 230.0, sin(a) * 120.0))
		draw_polyline(pts, Color(0.98, 0.78, 0.2, 0.35), 4.0)
		# pared con pizarras de cotizaciones
		draw_rect(Rect2(arena.position.x - 40, arena.position.y - 100, arena.size.x + 80, 100), Color(0.18, 0.2, 0.24))
		var names := ["ULEAM", "DIV0", "CAFE", "ATUN", "BANANO", "CACAO"]
		var f := ThemeDB.fallback_font
		for i in 6:
			var bx := arena.position.x + 20 + i * 170
			draw_rect(Rect2(bx, arena.position.y - 90, 150, 70), Color(0.03, 0.04, 0.05))
			draw_rect(Rect2(bx, arena.position.y - 90, 150, 70), Color(0.4, 0.42, 0.45), false, 2.0)
			var up := i % 3 != 1
			var col := Color(0.4, 1.0, 0.5) if up else Color(1, 0.35, 0.3)
			draw_string(f, Vector2(bx + 8, arena.position.y - 72), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.85, 0.35))
			draw_string(f, Vector2(bx + 80, arena.position.y - 72), ("▲" if up else "▼") + str(10 + i * 7 % 13) + "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
			var gp := PackedVector2Array()
			for k in 10:
				var v := sin(i * 1.7 + k * 0.9) * 8.0 + (-k if up else k) * 1.6
				gp.append(Vector2(bx + 10 + k * 14.5, arena.position.y - 40 + v))
			draw_polyline(gp, col, 2.0)
		draw_rect(arena, Color(0.55, 0.45, 0.2), false, 4.0)


	## Aula: baldosas, pizarrón enorme en la pared, reloj, ventanas y pupitres arrumados a los lados.
	func _aula() -> void:
		draw_rect(arena.grow(140.0), Color(0.12, 0.12, 0.14))
		var tile := 44.0
		var y := arena.position.y
		var row := 0
		while y < arena.end.y:
			var x := arena.position.x
			var col := 0
			while x < arena.end.x:
				var c := Color(0.78, 0.72, 0.6) if (row + col) % 2 == 0 else Color(0.7, 0.64, 0.53)
				draw_rect(Rect2(x, y, minf(tile, arena.end.x - x), minf(tile, arena.end.y - y)), c)
				x += tile
				col += 1
			y += tile
			row += 1
		# pared con pizarrón, ventanas y reloj
		var top := arena.position.y
		draw_rect(Rect2(arena.position.x - 40, top - 100, arena.size.x + 80, 100), Color(0.85, 0.82, 0.68))
		draw_rect(Rect2(arena.position.x - 40, top - 16, arena.size.x + 80, 16), Color(0.45, 0.33, 0.2))
		var f := ThemeDB.fallback_font
		draw_rect(Rect2(-260, top - 92, 520, 72), Color(0.45, 0.3, 0.16))
		draw_rect(Rect2(-252, top - 86, 504, 60), Color(0.15, 0.36, 0.25))
		draw_string(f, Vector2(-240, top - 64), "ULEAM · Facultad de Educación", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.95, 0.9, 0.85))
		draw_string(f, Vector2(-240, top - 40), "print(\"hola\"   <- falta )", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.6, 0.55, 0.9))
		draw_string(f, Vector2(60, top - 52), "▲ ● ■ ★ = ?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.5, 0.9))
		for wx in [arena.position.x + 30.0, arena.end.x - 200.0]:
			draw_rect(Rect2(wx, top - 88, 170, 62), Color(0.55, 0.75, 0.9))
			draw_rect(Rect2(wx, top - 88, 170, 62), Color(0.95, 0.95, 0.95), false, 4.0)
			draw_line(Vector2(wx + 85, top - 88), Vector2(wx + 85, top - 26), Color(0.95, 0.95, 0.95), 3.0)
		draw_circle(Vector2(arena.end.x - 260, top - 64), 18, Color(0.98, 0.98, 0.95))
		draw_arc(Vector2(arena.end.x - 260, top - 64), 18, 0, TAU, 20, Color(0.1, 0.1, 0.1), 2.0)
		draw_line(Vector2(arena.end.x - 260, top - 64), Vector2(arena.end.x - 260, top - 76), Color(0.1, 0.1, 0.1), 2.0)
		draw_line(Vector2(arena.end.x - 260, top - 64), Vector2(arena.end.x - 250, top - 64), Color(0.1, 0.1, 0.1), 2.0)
		# pupitres arrumados en las esquinas de abajo (decoración)
		for cx in [arena.position.x + 40.0, arena.end.x - 100.0]:
			for k in 2:
				var d := Rect2(cx + k * 30, arena.end.y - 60 - k * 18, 44, 28)
				draw_rect(d, Color(0.5, 0.34, 0.2))
				draw_rect(d, Color(0.2, 0.13, 0.08), false, 2.0)
		draw_rect(arena, Color(0.4, 0.3, 0.2), false, 4.0)


	## Obra en construcción: tierra y losas de concreto, andamios al fondo, vallas naranjas.
	func _obra() -> void:
		draw_rect(arena.grow(140.0), Color(0.13, 0.12, 0.1))
		draw_rect(arena, Color(0.52, 0.42, 0.3))
		var tile := 120.0
		var y := arena.position.y
		var row := 0
		while y < arena.end.y:
			var x := arena.position.x
			var col := 0
			while x < arena.end.x:
				if (row * 3 + col) % 4 != 1:
					var r := Rect2(x + 4, y + 4, minf(tile, arena.end.x - x) - 8, minf(tile * 0.7, arena.end.y - y) - 8)
					draw_rect(r, Color(0.6, 0.59, 0.55))
					draw_rect(r, Color(0.45, 0.44, 0.4), false, 2.0)
				x += tile
				col += 1
			y += tile * 0.7
			row += 1
		# charcos de barro
		for c in [Vector2(arena.position.x + 260, arena.end.y - 90), Vector2(arena.end.x - 300, arena.position.y + 220), Vector2(120, 140)]:
			var pts := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				pts.append(c + Vector2(cos(a) * 46.0, sin(a) * 16.0))
			draw_colored_polygon(pts, Color(0.38, 0.28, 0.18))
		# pared del fondo con andamios
		var top := arena.position.y
		draw_rect(Rect2(arena.position.x - 40, top - 100, arena.size.x + 80, 100), Color(0.55, 0.53, 0.5))
		for i in 12:
			var bx := arena.position.x - 20 + i * 90
			draw_line(Vector2(bx, top - 100), Vector2(bx, top), Color(0.3, 0.32, 0.36), 4.0)
		for j in 3:
			draw_line(Vector2(arena.position.x - 40, top - 90 + j * 34), Vector2(arena.end.x + 40, top - 90 + j * 34), Color(0.3, 0.32, 0.36), 3.0)
			for i in 11:
				var bx2 := arena.position.x - 20 + i * 90
				draw_line(Vector2(bx2, top - 90 + j * 34), Vector2(bx2 + 90, top - 56 + j * 34), Color(0.4, 0.42, 0.46), 2.0)
		draw_rect(Rect2(arena.position.x + 380, top - 86, 240, 50), Color(0.08, 0.2, 0.45))
		draw_string(ThemeDB.fallback_font, Vector2(arena.position.x + 390, top - 56), "ULEAM · OBRA FACULTAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.95, 1.0))
		# vallas naranjas en los bordes de abajo
		var x2 := arena.position.x + 20
		while x2 < arena.end.x - 40:
			draw_rect(Rect2(x2, arena.end.y + 6, 40, 14), Color(1, 0.5, 0.12))
			draw_rect(Rect2(x2 + 6, arena.end.y + 10, 10, 6), Color(0.98, 0.95, 0.9))
			draw_rect(Rect2(x2 + 24, arena.end.y + 10, 10, 6), Color(0.98, 0.95, 0.9))
			x2 += 52
		draw_rect(arena, Color(0.98, 0.76, 0.12), false, 4.0)


	## Sala de museo: mármol en damero, alfombra al pedestal, cordones y cuadros (algunos sin cargar).
	func _museo() -> void:
		draw_rect(arena.grow(140.0), Color(0.09, 0.08, 0.1))
		# piso de mármol en damero
		var tile := 64.0
		var y := arena.position.y
		var row := 0
		while y < arena.end.y:
			var x := arena.position.x
			var col := 0
			while x < arena.end.x:
				var r := Rect2(x, y, minf(tile, arena.end.x - x), minf(tile, arena.end.y - y))
				draw_rect(r, Color(0.82, 0.8, 0.76) if (row + col) % 2 == 0 else Color(0.62, 0.6, 0.58))
				x += tile
				col += 1
			y += tile
			row += 1
		# una baldosa sin textura (se le cayó al museo)
		var c := arena.get_center()
		var miss := Rect2(c.x + 192, c.y + 64, tile, tile)
		for i in 8:
			for j in 8:
				draw_rect(Rect2(miss.position + Vector2(i, j) * 8.0, Vector2(8, 8)), Color(1, 0, 1) if (i + j) % 2 == 0 else Color(0, 0, 0))
		# alfombra hacia el pedestal
		draw_rect(Rect2(c.x - 70, arena.position.y, 140, arena.size.y), Color(0.45, 0.1, 0.18, 0.8))
		# cordones de seguridad a los lados
		for sx in [arena.position.x + 60.0, arena.end.x - 60.0]:
			for k in 5:
				var py := arena.position.y + 110 + k * 110
				draw_line(Vector2(sx, py), Vector2(sx, py - 34), Color(0.85, 0.7, 0.3), 4.0)
				draw_circle(Vector2(sx, py - 36), 5, Color(0.95, 0.8, 0.35))
				if k < 4:
					draw_arc(Vector2(sx, py - 30 + 55), 55, -PI * 0.5 - 0.6, -PI * 0.5 + 0.6, 10, Color(0.6, 0.08, 0.12), 3.0)
		# pared con cuadros (algunos sin cargar)
		var top := arena.position.y
		draw_rect(Rect2(arena.position.x - 40, top - 100, arena.size.x + 80, 100), Color(0.42, 0.12, 0.16))
		for i in 7:
			var px := arena.position.x + 30 + i * 150
			var fr := Rect2(px, top - 86, 96, 64)
			draw_rect(fr.grow(5), Color(0.85, 0.65, 0.25))
			if i % 3 == 1:
				for a in 12:
					for b in 8:
						draw_rect(Rect2(fr.position + Vector2(a, b) * 8.0, Vector2(8, 8)), Color(1, 0, 1) if (a + b) % 2 == 0 else Color(0, 0, 0))
			else:
				draw_rect(fr, [Color(0.25, 0.4, 0.6), Color(0.55, 0.45, 0.25), Color(0.3, 0.5, 0.3)][i % 3])
				draw_circle(fr.get_center() + Vector2(-14, 4), 14, Color(0.9, 0.8, 0.5, 0.8))
		draw_string(ThemeDB.fallback_font, Vector2(c.x - 300, top - 6), "ULEAM · MUSEO DE LA FACULTAD", HORIZONTAL_ALIGNMENT_CENTER, 600, 13, Color(0.95, 0.85, 0.6))
		draw_rect(arena, Color(0.85, 0.65, 0.25), false, 4.0)

	## Set de TV de cocina: baldosas rojas y blancas, cocina al fondo, cartel de APLAUSOS y focos.
	func _estudio() -> void:
		draw_rect(arena.grow(140.0), Color(0.06, 0.05, 0.08))
		var tile := 48.0
		var y := arena.position.y
		var row := 0
		while y < arena.end.y:
			var x := arena.position.x
			var col := 0
			while x < arena.end.x:
				var r := Rect2(x, y, minf(tile, arena.end.x - x), minf(tile, arena.end.y - y))
				draw_rect(r, Color(0.78, 0.16, 0.16) if (row + col) % 2 == 0 else Color(0.92, 0.9, 0.86))
				x += tile
				col += 1
			y += tile
			row += 1
		# cables de las cámaras por el piso
		var c := arena.get_center()
		for k in 3:
			var a := Vector2(arena.position.x + 40, c.y + 60 + k * 14)
			var pts := PackedVector2Array()
			for i in 21:
				var px := lerpf(a.x, arena.end.x - 40, i / 20.0)
				pts.append(Vector2(px, a.y + sin(i * 0.9 + k) * 10.0))
			draw_polyline(pts, Color(0.08, 0.08, 0.1, 0.6), 3.0)
		# pared del fondo: cocina del programa
		var top := arena.position.y
		draw_rect(Rect2(arena.position.x - 40, top - 100, arena.size.x + 80, 100), Color(0.2, 0.22, 0.3))
		draw_rect(Rect2(arena.position.x - 40, top - 30, arena.size.x + 80, 30), Color(0.55, 0.58, 0.62))
		for i in 6:
			var px := arena.position.x + 40 + i * 170
			# hornos y estantes
			draw_rect(Rect2(px, top - 28, 90, 26), Color(0.3, 0.3, 0.34))
			draw_rect(Rect2(px + 10, top - 24, 70, 16), Color(0.95, 0.55, 0.15, 0.6) if i % 2 == 0 else Color(0.1, 0.1, 0.12))
			draw_rect(Rect2(px, top - 80, 100, 6), Color(0.5, 0.35, 0.2))
			for j in 3:
				draw_circle(Vector2(px + 18 + j * 30, top - 88), 8, [Color(0.9, 0.3, 0.2), Color(0.9, 0.85, 0.3), Color(0.3, 0.7, 0.35)][(i + j) % 3])
		# cartel de APLAUSOS
		var sign := Rect2(c.x - 90, top - 96, 180, 34)
		draw_rect(sign, Color(0.1, 0.02, 0.02))
		draw_rect(sign, Color(1, 0.25, 0.2), false, 3.0)
		draw_string(ThemeDB.fallback_font, sign.position + Vector2(0, 25), "APLAUSOS", HORIZONTAL_ALIGNMENT_CENTER, 180, 22, Color(1, 0.35, 0.3))
		# focos de luz en el piso
		for fx in [c.x - 260.0, c.x + 260.0, c.x]:
			var fc := Vector2(fx, c.y - 40 if fx == c.x else c.y + 20)
			var pts2 := PackedVector2Array()
			for i in 24:
				var a2 := TAU * i / 24.0
				pts2.append(fc + Vector2(cos(a2) * 120.0, sin(a2) * 55.0))
			draw_colored_polygon(pts2, Color(1, 0.95, 0.75, 0.08))
		draw_rect(arena, Color(0.95, 0.8, 0.3), false, 4.0)

	## Sala de juicio: piso de madera, bancas a los lados, estrado del secretario y banderas en la pared.
	func _juzgado() -> void:
		draw_rect(arena.grow(140.0), Color(0.1, 0.08, 0.07))
		var y := arena.position.y
		var row := 0
		while y < arena.end.y:
			var h := minf(28.0, arena.end.y - y)
			draw_rect(Rect2(arena.position.x, y, arena.size.x, h), Color(0.5, 0.33, 0.2) if row % 2 == 0 else Color(0.46, 0.3, 0.18))
			var x := arena.position.x + (row % 3) * 60.0
			while x < arena.end.x:
				draw_line(Vector2(x, y), Vector2(x, y + h), Color(0.35, 0.22, 0.12), 1.0)
				x += 180.0
			y += 28.0
			row += 1
		# alfombra roja al centro
		var c := arena.get_center()
		draw_rect(Rect2(c.x - 90, arena.position.y, 180, arena.size.y), Color(0.55, 0.12, 0.12, 0.85))
		draw_rect(Rect2(c.x - 90, arena.position.y, 180, arena.size.y), Color(0.85, 0.65, 0.25), false, 3.0)
		# bancas a los lados
		for sx in [arena.position.x + 30.0, arena.end.x - 150.0]:
			for k in 4:
				var b := Rect2(sx, arena.position.y + 120 + k * 110, 120, 22)
				draw_rect(b, Color(0.35, 0.22, 0.12))
				draw_rect(b, Color(0.18, 0.1, 0.05), false, 2.0)
		# pared con paneles de madera, banderas y escudo
		var top := arena.position.y
		draw_rect(Rect2(arena.position.x - 40, top - 100, arena.size.x + 80, 100), Color(0.32, 0.2, 0.12))
		for i in 10:
			var px := arena.position.x - 20 + i * 106
			draw_rect(Rect2(px, top - 90, 90, 76), Color(0.4, 0.26, 0.15))
			draw_rect(Rect2(px, top - 90, 90, 76), Color(0.22, 0.13, 0.07), false, 2.0)
		draw_circle(Vector2(c.x, top - 56), 34, Color(0.95, 0.75, 0.25))
		draw_arc(Vector2(c.x, top - 56), 34, 0, TAU, 24, Color(0.25, 0.15, 0.08), 3.0)
		draw_line(Vector2(c.x, top - 78), Vector2(c.x, top - 36), Color(0.3, 0.18, 0.08), 3.0)
		draw_line(Vector2(c.x - 20, top - 70), Vector2(c.x + 20, top - 70), Color(0.3, 0.18, 0.08), 3.0)
		for fx in [c.x - 180.0, c.x + 150.0]:
			draw_line(Vector2(fx, top - 95), Vector2(fx, top - 10), Color(0.75, 0.6, 0.3), 3.0)
			draw_rect(Rect2(fx + 2, top - 92, 34, 12), Color(0.98, 0.85, 0.2))
			draw_rect(Rect2(fx + 2, top - 80, 34, 8), Color(0.15, 0.3, 0.7))
			draw_rect(Rect2(fx + 2, top - 72, 34, 8), Color(0.85, 0.15, 0.15))
		draw_string(ThemeDB.fallback_font, Vector2(c.x - 300, top - 20), "ULEAM · TRIBUNAL DE LA FACULTAD", HORIZONTAL_ALIGNMENT_CENTER, 600, 13, Color(0.95, 0.85, 0.55))
		draw_rect(arena, Color(0.85, 0.65, 0.25), false, 4.0)
