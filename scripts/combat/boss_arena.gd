extends Node2D
## Arena de los bosses. Abrir scenes/combat/boss_test.tscn y pulsar F6 (o entrar por la puerta del campus).
## Qué boss sale lo decide `boss_kind` (la puerta del campus lo pone antes de cambiar de escena).
## F2 = saltar a la siguiente fase (solo para probar). R = reintentar al ganar/perder.

const PlayerScene := preload("res://scenes/combat/player.tscn")
const BossHud := preload("res://scripts/combat/boss_hud.gd")
const ArenaFx := preload("res://scripts/combat/boss_arena_fx.gd")
const Coop := preload("res://scripts/coop.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Epic := preload("res://scripts/combat/epic_fx.gd")
const GameFeel := preload("res://scripts/combat/game_feel.gd")
## Color de acento de cada boss (efectos épicos de aturdido, cambio de fase y victoria).
const ACCENT := {
	"deadbeef": Color(1.0, 0.3, 0.2), "bsod": Color(0.3, 0.6, 1.0), "div0": Color(1.0, 0.78, 0.2),
	"syntax": Color(0.45, 0.9, 0.55), "stack": Color(1.0, 0.6, 0.15), "judge": Color(0.9, 0.3, 0.3),
	"tex": Color(1.0, 0.3, 1.0), "kp": Color(1.0, 0.65, 0.2), "sudo": Color(0.3, 0.9, 0.6),
}
## Multijugador: segundos que el compañero tiene que quedarse al lado para levantar a un caído.
const REVIVE_TIME := 2.0
const REVIVE_RANGE := 80.0
const REVIVE_HP := 5
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
	"sudo": {
		"script": "res://scripts/combat/boss_sudo.gd",
		"name": "SUDO",
		"title": ["> sudo: LÍDER DEL CLUB IA", "La charla que no te puedes saltar", "Club IA"],
		"win": "> SESIÓN TERMINADA",
		"floor": "auditorio",
	},
}

## Boss de esta arena ("deadbeef", "bsod", "div0", "syntax", "stack", "judge", "tex", "kp" o "sudo").
static var boss_kind: String = "deadbeef"

## Al salir (Esc, o tras ganar/perder) se vuelve al Salón de las Facultades.
const CAMPUS_SCENE := "res://scenes/combat/boss_hall.tscn"
const ARENA := Rect2(-520, -330, 1040, 660)
## Música de cada boss: <boss>_p1/_p2/_p3 (una por fase, cada vez más intensa), _win al vencerlo y lose.ogg al perder.
## Generada por tools/boss_music.py. La fase 1 trae una intro de 2 compases y hace loop desde aquí (segundos).
const MUSIC_DIR := "res://assets/audio/bosses/"
const MUSIC_INTRO := {"deadbeef": 3.2, "bsod": 4.0, "div0": 3.75, "syntax": 3.8095, "stack": 3.3333, "judge": 4.0678, "tex": 2.4, "kp": 3.2877, "sudo": 3.4783}
const MUSIC_DB := -6.0
const WALL := 40.0

## true = reintento: se salta la aparición larga y la presentación.
static var retry: bool = false

var player: CharacterBody2D
## 1 o 2 jugadores (player = el primero).
var players: Array = []
var _revive := {}
var _revive_fx: Node2D
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
	players = Coop.spawn(self, Vector2(0, 230), CAMPUS_SCENE)
	player = players[0]
	for pl in players:
		pl.set("ko_mode", players.size() > 1)
		var cam := pl.get_node_or_null("Camera2D") as Camera2D
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
	# con 2 jugadores se conectan los dos (parry, etc.); el objetivo inicial es el jugador 1
	for i in range(players.size() - 1, -1, -1):
		boss.call("set_player", players[i])
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
	for pl in players:
		pl.connect("hp_changed", _on_player_hp)
	if players.size() > 1:
		_revive_fx = ReviveFx.new()
		_revive_fx.arena = self
		add_child(_revive_fx)
	_lock_player(true)
	if not retry:
		_dim.color = Color(0.5, 0.5, 0.6)
	if not retry:
		_start_rumble()
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
	for pl in players:
		if not is_instance_valid(pl):
			continue
		pl.set_physics_process(not on)
		pl.set_process_unhandled_input(not on)
		if on:
			pl.velocity = Vector2.ZERO


## Multijugador: el compañero se queda al lado del caído para levantarlo.
func _process(delta: float) -> void:
	if players.size() < 2 or _over:
		return
	for pl in players:
		if not is_instance_valid(pl) or not bool(pl.get("coop_ko")):
			_revive.erase(pl)
			continue
		var helper := false
		for other in players:
			if other != pl and is_instance_valid(other) and not bool(other.get("coop_ko")) \
					and (other as Node2D).global_position.distance_to((pl as Node2D).global_position) < REVIVE_RANGE:
				helper = true
		var k: float = _revive.get(pl, 0.0)
		k = k + delta if helper else maxf(0.0, k - delta * 0.5)
		_revive[pl] = k
		if k >= REVIVE_TIME:
			_revive.erase(pl)
			pl.call("revive", REVIVE_HP)


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


## Pantalla de presentación épica: dos franjas del color del boss entran cruzadas, se escribe la línea
## de terminal y el NOMBRE cae de golpe (letra arcade en cursiva) con destello, temblor y sonido.
func _title_card() -> void:
	var card := TitleCard.new()
	card.name_text = str(BOSSES[boss_kind]["name"])
	card.terminal = str(BOSSES[boss_kind]["title"][0])
	card.subtitle = str(BOSSES[boss_kind]["title"][1])
	card.faculty = str(BOSSES[boss_kind]["title"][2])
	card.accent = _accent()
	add_child(card)
	await get_tree().create_timer(TitleCard.SLAM_AT - 0.42).timeout
	play_sfx("title_slam", 0.0)
	await get_tree().create_timer(0.42).timeout
	Epic.flash(self, Color.WHITE, 0.45, 0.35)
	Epic.speed_lines(self, 0.5, Color(_accent().lightened(0.5), 0.6))
	Epic.cam_punch(get_tree(), 0.06, 0.3)
	if is_instance_valid(player):
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			var tw := cam.create_tween()
			for k in 8:
				var st := 9.0 * (1.0 - k / 8.0)
				tw.tween_property(cam, "offset", Vector2(randf_range(-st, st), randf_range(-st, st)), 0.035)
			tw.tween_property(cam, "offset", Vector2.ZERO, 0.04)
	await card.finished


# --- Sonidos (grito del boss, golpe de la tarjeta, tensión de la intro) ----------------------

var _rumble: AudioStreamPlayer
var _last_roar := -10000
var _roared := false


func play_sfx(sfx: String, db: float = 0.0) -> AudioStreamPlayer:
	var path: String = MUSIC_DIR + sfx + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Grito del boss (presentación y cambio de fase). Lo llaman también los efectos de "grito" (boss_roar.gd).
func boss_roar() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_roar < 2500:
		return
	_last_roar = now
	_roared = true
	_stop_rumble(0.4)
	play_sfx(boss_kind + "_roar", 1.0)


## Zumbido de tensión mientras el boss se presenta (antes había silencio).
func _start_rumble() -> void:
	var path: String = MUSIC_DIR + "intro_rumble.ogg"
	if not ResourceLoader.exists(path):
		return
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	_rumble = AudioStreamPlayer.new()
	_rumble.stream = st
	_rumble.volume_db = -36.0
	add_child(_rumble)
	_rumble.play()
	create_tween().tween_property(_rumble, "volume_db", -9.0, 1.6)


func _stop_rumble(time: float = 0.8) -> void:
	if _rumble and is_instance_valid(_rumble):
		var r := _rumble
		_rumble = null
		var tw := r.create_tween()
		tw.tween_property(r, "volume_db", -50.0, time)
		tw.tween_callback(r.queue_free)


# --- Eventos ----------------------------------------------------------------------

func _on_intro_done() -> void:
	if not _roared:
		boss_roar()
	_stop_rumble(0.6)
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


func _boss_core() -> Vector2:
	return boss.global_position + Vector2(0, -110) if is_instance_valid(boss) else Vector2.ZERO


func _accent() -> Color:
	return ACCENT.get(boss_kind, Color(1, 0.8, 0.4))


func _on_phase(phase: int, title: String) -> void:
	_phase_label.text = "Fase %d/3" % phase
	if phase >= 2:
		boss_roar()
	# cambio de fase épico: destello, onda doble, chispas, líneas de velocidad y zoom
	if phase >= 2 and boss_kind != "sudo":
		var c := _boss_core()
		Epic.flash(self, _accent().lightened(0.5), 0.3, 0.5)
		Epic.ring(self, c + Vector2(0, 100), _accent(), 420.0, 0.7, 14.0)
		Epic.ring(self, c + Vector2(0, 100), Color.WHITE, 260.0, 0.5, 6.0)
		Epic.burst(self, c, _accent().lightened(0.3), 40, 520.0, 0.5, 0.9)
		Epic.speed_lines(self, 0.6, Color(_accent().lightened(0.5), 0.55))
		Epic.cam_punch(get_tree(), 0.08, 0.4)
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
	if boss_kind != "sudo" and is_instance_valid(boss):
		var c := _boss_core()
		Epic.ring(self, c + Vector2(0, 100), Color(1, 0.95, 0.4), 300.0, 0.55, 10.0)
		Epic.burst(self, c, Color(1, 0.95, 0.5), 30, 420.0, 0.8, 0.8)
		Epic.word(self, c + Vector2(0, -60), "¡ATURDIDO!", Color(1, 0.95, 0.4), 34)
		Epic.cam_punch(get_tree(), 0.05, 0.25)
	_crit_qte()


## Premio de la mecánica de cada boss: al aturdirlo sale un QTE de GOLPE CRÍTICO (cámara lenta corta).
## Acertarlo le quita CRIT_DMG (x2 si tiene el punto débil abierto) con un golpe enorme.
const CRIT_DMG := 3
## Distancia a la que el golpe crítico deja al personaje del centro de cada boss (tamaño del boss).
const CRIT_RADIUS := {"deadbeef": 125.0, "bsod": 105.0, "div0": 115.0, "syntax": 100.0, "stack": 135.0,
	"judge": 115.0, "tex": 100.0, "kp": 110.0, "sudo": 62.0}
var _crit_busy := false


func _crit_qte() -> void:
	if _crit_busy or _over or not is_instance_valid(boss):
		return
	_crit_busy = true
	await get_tree().create_timer(0.35).timeout
	if _over or not is_instance_valid(boss) or str(boss.get("state")) in ["dead", "final", "transition", "paused"]:
		_crit_busy = false
		return
	var q := Epic.qte(self, "timing", "action_primary", "¡GOLPE CRÍTICO!", {"dur": 0.9, "col": _accent().lightened(0.3), "sub": "Pulsa cuando el aro llegue al verde"})
	Engine.time_scale = 0.55
	var ok: bool = await q.done
	Engine.time_scale = 1.0
	_crit_busy = false
	if not ok or _over or not is_instance_valid(boss) or str(boss.get("state")) in ["dead", "final", "transition", "paused"]:
		return
	# el personaje se lanza en un dash hasta el boss y le pega de cerca con su propio golpe
	var actors := Epic.grab(get_tree())
	if actors.is_empty():
		return
	var radius: float = CRIT_RADIUS.get(boss_kind, 105.0)
	var dests: Array = []
	for a in actors:
		dests.append(Epic.melee_spot(boss, (a as Node2D).global_position, radius, ARENA))
	if actors.size() == 2 and (dests[0] as Vector2).distance_to(dests[1]) < 70.0:
		dests[0] = (dests[0] as Vector2) + Vector2(-45, 0)
		dests[1] = (dests[1] as Vector2) + Vector2(45, 0)
	Epic.speed_lines(self, 0.3, Color(1, 1, 1, 0.45))
	await Epic.run_group(actors, dests, 1100.0, true)
	if _over or not is_instance_valid(boss):
		Epic.release(actors)
		return
	var c := _boss_core()
	for a in actors:
		Epic.act(a, "attack", c - (a as Node2D).global_position)
	await get_tree().create_timer(0.12).timeout
	if not _over and is_instance_valid(boss) and str(boss.get("state")) not in ["dead", "final", "transition", "paused"]:
		boss.call("take_hit", CRIT_DMG, (actors[0] as Node2D).global_position)
		c = _boss_core()
		Epic.big_hit(self, c + Vector2(0, 60), _accent(), 8.0)
		Epic.word(self, c + Vector2(0, -90), "¡CRÍTICO!", Color(1, 0.9, 0.3), 46)
		Epic.speed_lines(self, 0.35, Color(1, 1, 1, 0.5))
		GameFeel.hit_stop(get_tree(), 0.12)
	await get_tree().create_timer(0.3).timeout
	Epic.release(actors)


func _on_arm_broken(_arm: String) -> void:
	_show_banner("¡BRAZO DESTRUIDO!", Color(1, 0.6, 0.3), 1.0)


func _on_staggered() -> void:
	_show_banner("¡SE TAMBALEA!", Color(1, 0.8, 0.5), 0.6)
	if is_instance_valid(boss):
		Epic.burst(self, _boss_core(), Color(1, 0.85, 0.5), 14, 300.0, 0.7, 0.5)


func _on_player_hp(hp: int, _max_hp: int) -> void:
	if _last_player_hp >= 0 and hp < _last_player_hp and _fighting:
		_hits_taken += 1
	_last_player_hp = hp
	if hp > 0 or _over:
		return
	if players.size() > 1:
		_check_team_down.call_deferred()
		return
	_lose()


## Multijugador: se pierde solo si los dos están caídos a la vez.
func _check_team_down() -> void:
	if _over:
		return
	for pl in players:
		if is_instance_valid(pl) and not bool(pl.get("coop_ko")):
			return
	_lose()


func _lose() -> void:
	_over = true
	boss.call("pause_ai")
	_music_end("lose")
	_fighting = false
	# el personaje se queda tirado en el suelo (ya no se levanta)
	for pl in players:
		if is_instance_valid(pl) and pl.has_method("stay_fallen"):
			pl.call("stay_fallen")
	# momento de la derrota: cámara lenta, zoom al caído y el mundo se apaga en rojo
	_boss_hud.visible = false
	Epic.flash(self, Color(1, 0.15, 0.1), 0.45, 0.6)
	Epic.cam_zoom(get_tree(), 1.3, 0.6)
	if is_instance_valid(_dim):
		create_tween().tween_property(_dim, "color", Color(0.55, 0.38, 0.4), 0.8)
	Engine.time_scale = 0.35
	await get_tree().create_timer(0.9, true, false, true).timeout
	Engine.time_scale = 1.0
	_lock_player(true)
	for pl in players:
		if is_instance_valid(pl) and pl.has_method("stay_fallen"):
			pl.call("stay_fallen")
	var hp_left := 0.0
	var ph := 1
	if is_instance_valid(boss):
		hp_left = 100.0 * float(boss.get("hp")) / maxf(1.0, float(boss.get("MAX_HP")))
		ph = int(boss.get("phase"))
	var secs := int((Time.get_ticks_msec() - _t0) / 1000.0)
	var es := EndScreen.new()
	es.win = false
	es.title = "CRASH DEL ESTUDIANTE"
	es.accent = Color(1.0, 0.25, 0.22)
	es.lines = ["> ERROR FATAL: el estudiante dejó de responder",
		"> %s sigue en línea  ·  vida restante %d %%  ·  fase %d/3  ·  %d:%02d" % [BOSSES[boss_kind]["name"], int(ceil(hp_left)), ph, secs / 60, secs % 60]]
	es.tip = "CONSEJO: " + str(TIPS.get(boss_kind, "observa sus avisos rojos y rueda a tiempo."))
	es.keys = _end_keys("reintentar")
	_show_end(es)


func _on_victory() -> void:
	_over = true
	if not _end_music_done:
		_music_end("win")
	_fighting = false
	retry = false
	_boss_hud.visible = false
	_lock_player(true)
	var secs := int((Time.get_ticks_msec() - _t0) / 1000.0)
	var rank := "S" if _hits_taken <= 2 else ("A" if _hits_taken <= 5 else ("B" if _hits_taken <= 9 else "C"))
	GameState.record_victory(boss_kind, rank, secs)   # el salón dora la estatua
	# momento de la victoria: zoom a los jugadores con luz dorada
	Epic.cam_zoom(get_tree(), 1.2, 0.8)
	Epic.flash(self, Color(1, 0.95, 0.7), 0.35, 0.5)
	await get_tree().create_timer(0.7).timeout
	var es := EndScreen.new()
	es.win = true
	es.title = "¡VICTORIA!"
	es.accent = _accent()
	es.lines = ["%s DERROTADO" % BOSSES[boss_kind]["name"], str(BOSSES[boss_kind]["win"])]
	es.rank = rank
	es.stats = [["TIEMPO", secs, "time"], ["GOLPES RECIBIDOS", _hits_taken, "int"], ["GOLPES AL PUNTO DÉBIL", _weak_hits, "int"]]
	# primera victoria: avisa la técnica que se acaba de conseguir
	if GameState.last_won == boss_kind:
		var Tech = load("res://scripts/combat/techniques.gd")
		for id in Tech.DATA.keys():
			if Tech.DATA[id]["boss"] == boss_kind:
				es.tip = "¡NUEVA TÉCNICA!  %s (%s) · equípala en el casillero" % [Tech.DATA[id]["name"], str(Tech.SLOT_LABEL[Tech.DATA[id]["slot"]]).to_lower()]
	es.keys = _end_keys("repetir")
	_show_end(es)


var _end_screen: EndScreen


func _show_end(es: EndScreen) -> void:
	for n in [_end_title, _end_sub]:
		if is_instance_valid(n):
			n.visible = false
	for c in _end_box.get_children():
		if c is ColorRect:
			(c as ColorRect).visible = false
	_end_screen = es
	_end_box.add_child(es)
	_end_box.visible = true
	es.stamp.connect(func() -> void:
		play_sfx("title_slam", -2.0)
		Epic.cam_punch(get_tree(), 0.05, 0.25))


## Consejo en la pantalla de derrota (la mecánica propia de cada boss).
const TIPS := {
	"deadbeef": "rompe sus brazos para quitarle ataques; en el duelo final, parry a los brazos que lanza.",
	"bsod": "ataca entre latidos: el corazón solo se abre ahí. Parry en el latido = arritmia.",
	"div0": "hunde su acción bajo la línea roja para que quiebre y reciba doble daño.",
	"syntax": "golpea los pupitres en el orden de la pizarra para aprobar la lección.",
	"stack": "golpea la base de la torre cuando se incline hacia él para tumbársela encima.",
	"judge": "junta 3 pruebas y hazle parry al sello DENEGADO: ¡OBJECIÓN!",
	"tex": "mírala para petrificarla; si le das la espalda, avanza a saltos.",
	"kp": "rompe la cámara que está al aire (luz roja) para dejarlo sin señal.",
	"sudo": "aprende sus tres fases; en el ASTRA, el QTE no perdona.",
}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("debug_next_phase") and _fighting and not _over:
		boss.call("debug_next_phase")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("retry") and _over and _end_box.visible and (_end_screen == null or _end_screen.input_ready()):
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
		if style == "auditorio":
			_auditorio()
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

	## Auditorio del Club IA: alfombra oscura, escenario de madera, pantalla gigante y butacas.
	func _auditorio() -> void:
		draw_rect(arena.grow(140.0), Color(0.07, 0.08, 0.1))
		var tile := 40.0
		var y := arena.position.y
		var row := 0
		while y < arena.end.y:
			var x := arena.position.x
			var col := 0
			while x < arena.end.x:
				var c := Color(0.17, 0.19, 0.24) if (row + col) % 2 == 0 else Color(0.15, 0.17, 0.22)
				draw_rect(Rect2(x, y, minf(tile, arena.end.x - x), minf(tile, arena.end.y - y)), c)
				x += tile
				col += 1
			y += tile
			row += 1
		# escenario de madera arriba
		var stage := Rect2(arena.position.x + 120, arena.position.y, arena.size.x - 240, 150)
		draw_rect(stage, Color(0.42, 0.29, 0.18))
		for i in 12:
			var sx := stage.position.x + i * stage.size.x / 12.0
			draw_line(Vector2(sx, stage.position.y), Vector2(sx, stage.end.y), Color(0.32, 0.21, 0.12), 2.0)
		draw_rect(Rect2(stage.position.x, stage.end.y - 8, stage.size.x, 8), Color(0.25, 0.16, 0.09))
		# pantalla gigante en la pared
		var scr := Rect2(arena.position.x + 300, arena.position.y - 96, arena.size.x - 600, 86)
		draw_rect(scr.grow(6), Color(0.1, 0.1, 0.12))
		draw_rect(scr, Color(0.05, 0.14, 0.1))
		draw_string(ThemeDB.fallback_font, scr.position + Vector2(0, 40), "CLUB IA", HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, 26, Color(0.4, 1.0, 0.65))
		draw_string(ThemeDB.fallback_font, scr.position + Vector2(0, 66), "charla abierta · casa abierta ULEAM", HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, 12, Color(0.85, 0.9, 0.9))
		# filas de butacas a los lados (decorado, abajo)
		for side in [-1.0, 1.0]:
			for r in 3:
				for k in 4:
					var bx := (arena.position.x + 30 + k * 34) if side < 0 else (arena.end.x - 64 - k * 34)
					var by := arena.end.y - 150 + r * 46
					draw_rect(Rect2(bx, by, 28, 22), Color(0.45, 0.1, 0.12))
					draw_rect(Rect2(bx, by - 8, 28, 10), Color(0.55, 0.14, 0.16))
		# focos
		for i in 4:
			var fx := arena.position.x + 200 + i * (arena.size.x - 400) / 3.0
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 8, arena.position.y - 10), Vector2(fx + 8, arena.position.y - 10), Vector2(fx + 90, arena.position.y + 220), Vector2(fx - 90, arena.position.y + 220)]), Color(1, 1, 0.9, 0.035))
		draw_rect(arena, Color(0.05, 0.05, 0.07), false, 4.0)


## Anillo de "levantando" sobre el jugador caído (multijugador).
class ReviveFx extends Node2D:
	var arena: Node

	func _ready() -> void:
		z_index = 50

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		for pl in arena.get("players"):
			if not is_instance_valid(pl) or not bool(pl.get("coop_ko")):
				continue
			var c: Vector2 = (pl as Node2D).global_position + Vector2(0, -70)
			var k: float = float(arena.get("_revive").get(pl, 0.0)) / REVIVE_TIME
			draw_arc(c, 22, 0, TAU, 32, Color(0, 0, 0, 0.6), 7)
			draw_arc(c, 22, -PI * 0.5, -PI * 0.5 + TAU * k, 32, Color(0.4, 1.0, 0.5), 5)
			var f := ThemeDB.fallback_font
			var msg := "¡LEVÁNTALO!" if k <= 0.0 else "%d%%" % int(k * 100)
			draw_string_outline(f, c + Vector2(-60, -32 + sin(t * 6.0) * 2.0), msg, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, 4, Color.BLACK)
			draw_string(f, c + Vector2(-60, -32 + sin(t * 6.0) * 2.0), msg, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color(1.0, 0.9, 0.4))


## Tarjeta de presentación épica (la dibuja con la letra arcade de la portada).
class TitleCard extends CanvasLayer:
	const Style := preload("res://scripts/ui/ui_style.gd")
	const SLAM_AT := 0.62
	const OUT_AT := 2.9
	const END := 3.3
	signal finished
	var name_text := "BOSS"
	var terminal := ""
	var subtitle := ""
	var faculty := ""
	var accent := Color(1, 0.4, 0.3)
	var t := 0.0
	var _c: Control
	var _done := false

	func _ready() -> void:
		layer = 7
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_paint)
		add_child(_c)

	func _process(delta: float) -> void:
		t += delta
		if t >= END and not _done:
			_done = true
			finished.emit()
			queue_free()
		_c.queue_redraw()

	static func _ease_out(k: float) -> float:
		k = clampf(k, 0.0, 1.0)
		return 1.0 - pow(1.0 - k, 3.0)

	func _paint() -> void:
		var out := clampf((t - OUT_AT) / (END - OUT_AT), 0.0, 1.0)
		# oscurece la arena
		var dark := clampf(t / 0.25, 0.0, 1.0) * (1.0 - out)
		_c.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5 * dark))
		# franjas cruzadas que entran desde los lados
		var kin := _ease_out(t / 0.28)
		var y0 := 250.0
		var band := Rect2(-200 + (1.0 - kin) * -1500.0 + out * 1700.0, y0, 1680, 190)
		_c.draw_colored_polygon(Style.slanted(band, 60), Color(0.03, 0.02, 0.06, 0.9))
		var top := Rect2(-200 + (1.0 - kin) * 1700.0 - out * 1700.0, y0 - 14, 1680, 12)
		var bot := Rect2(-200 + (1.0 - kin) * -1700.0 + out * 1700.0, y0 + 192, 1680, 12)
		_c.draw_colored_polygon(Style.slanted(top, 8), accent)
		_c.draw_colored_polygon(Style.slanted(bot, 8), accent)
		# rayas diagonales que corren dentro de la franja
		for i in 14:
			var x := fmod(t * 600.0 + i * 140.0, 1680.0) - 200.0 + band.position.x + 200.0
			_c.draw_line(Vector2(x, y0 + 4), Vector2(x - 60, y0 + 186), Color(accent, 0.07), 14.0)
		# línea de terminal que se escribe
		if t > 0.25 and terminal != "":
			var n := clampi(int((t - 0.25) / 0.02), 0, terminal.length())
			var tt := terminal.substr(0, n) + ("_" if fmod(t, 0.4) < 0.2 and n < terminal.length() else "")
			_c.draw_string(ThemeDB.fallback_font, Vector2(150 + out * 600.0, y0 + 30), tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.45, 1.0, 0.5, 1.0 - out))
		# NOMBRE: cae desde grande y golpea
		if t > SLAM_AT - 0.2:
			var k := clampf((t - (SLAM_AT - 0.2)) / 0.2, 0.0, 1.0)
			var sc := lerpf(3.0, 1.0, k * k)
			var a := clampf(k * 1.5, 0.0, 1.0) * (1.0 - out)
			var size := 104
			var w := Style.text_w(name_text, size)
			if w > 1080.0:
				size = int(size * 1080.0 / w)
			var c := Vector2(640, y0 + 82 + size * 0.36)
			var hit := clampf(1.0 - (t - SLAM_AT) / 0.5, 0.0, 1.0) if t >= SLAM_AT else 0.0
			var jitter := Vector2(randf_range(-6, 6), randf_range(-3, 3)) * hit
			var stretch := Vector2(1.0 + out * 1.4, 1.0 - out * 0.6)
			var base := Transform2D(0.0, Vector2(sc, sc) * stretch, 0.0, c + jitter)
			# copias desfasadas (rojo / cian) al golpear: efecto glitch
			if hit > 0.0:
				Style.title(_c, Vector2(-7 * hit, 0), name_text, size, Color(1, 0.2, 0.3, 0.6 * hit * a), Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, 1200, -0.18, base)
				Style.title(_c, Vector2(7 * hit, 0), name_text, size, Color(0.2, 0.9, 1.0, 0.6 * hit * a), Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, 1200, -0.18, base)
			Style.title(_c, Vector2.ZERO, name_text, size, Color(accent.lightened(0.35), a), Color(0.04, 0.02, 0.06, a), HORIZONTAL_ALIGNMENT_CENTER, 1200, -0.18, base)
			_c.draw_set_transform(Vector2.ZERO)
			# destello blanco sobre las letras al golpear
			if hit > 0.6:
				_c.draw_rect(Rect2(0, y0, 1280, 190), Color(1, 1, 1, (hit - 0.6) * 1.2))
		# subtítulo que entra desde la derecha y facultad
		if t > 0.85 and subtitle != "":
			var ks := _ease_out((t - 0.85) / 0.25)
			Style.title(_c, Vector2(640 + (1.0 - ks) * 700.0 - out * 900.0, y0 + 168), subtitle, 26, Color(1, 1, 1, 1.0 - out), Color(0.04, 0.02, 0.06, 1.0 - out), HORIZONTAL_ALIGNMENT_CENTER, 1100, -0.12)
		if t > 1.1 and faculty != "":
			var kf := clampf((t - 1.1) / 0.35, 0.0, 1.0) * (1.0 - out)
			Style.title(_c, Vector2(640, y0 + 232), faculty, 18, Color(accent.lightened(0.5), kf), Color(0, 0, 0, 0.8 * kf), HORIZONTAL_ALIGNMENT_CENTER, 1200, 0.0)


## Pantalla de VICTORIA o DERROTA (letra arcade de la portada, como la tarjeta de presentación).
class EndScreen extends Control:
	const Style := preload("res://scripts/ui/ui_style.gd")
	signal stamp
	var win := true
	var title := ""
	var lines: Array = []
	var stats: Array = []      # [nombre, valor, "int" | "time"]
	var rank := ""
	var tip := ""
	var keys := ""
	var accent := Color(1, 0.8, 0.3)
	var t := 0.0
	var _stamped := false
	var _bits: Array = []      # confeti / chispas
	const RANK_AT := 2.0

	func _ready() -> void:
		size = Vector2(1280, 720)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS
		for i in 70:
			_bits.append(_new_bit(true))

	func input_ready() -> bool:
		return t > (2.4 if win else 2.6)

	func _new_bit(spread: bool) -> Array:
		var cols := [accent, accent.lightened(0.4), Color(1, 0.95, 0.6), Color.WHITE] if win else [Color(1, 0.2, 0.15), Color(0.5, 0.05, 0.05), Color(0.9, 0.9, 0.9)]
		var y := randf_range(-720, 0) if spread else randf_range(-60, -10)
		# [pos, vel, giro, vel giro, color, tamaño]
		return [Vector2(randf_range(0, 1280), y), Vector2(randf_range(-40, 40), randf_range(90, 220)) * (1.0 if win else 0.6),
			randf() * TAU, randf_range(-6, 6), cols[randi() % cols.size()], randf_range(4, 9)]

	func _process(delta: float) -> void:
		t += delta
		for b in _bits:
			b[0] += b[1] * delta
			b[2] += b[3] * delta
			if b[0].y > 740:
				var nb := _new_bit(false)
				for k in nb.size():
					b[k] = nb[k]
		if win and not _stamped and t >= RANK_AT:
			_stamped = true
			stamp.emit()
		queue_redraw()

	static func _out3(k: float) -> float:
		k = clampf(k, 0.0, 1.0)
		return 1.0 - pow(1.0 - k, 3.0)

	func _draw() -> void:
		if win:
			_draw_win()
		else:
			_draw_lose()
		var f := ThemeDB.fallback_font
		if input_ready() and keys != "":
			var a := 0.55 + 0.45 * absf(sin(t * 3.0))
			Style.title(self, Vector2(640, 676), keys, 20, Color(1, 1, 1, a), Color(0.03, 0.02, 0.06, a), HORIZONTAL_ALIGNMENT_CENTER, 1200, 0.0)

	# ---------------------------------------------------------------- victoria
	func _draw_win() -> void:
		var k := _out3(t / 0.35)
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.05, 0.62 * k))
		# rayos de luz que giran detrás del título
		var c := Vector2(640, 190)
		for i in 16:
			var a0 := t * 0.25 + TAU * i / 16.0
			var pts := PackedVector2Array([c, c + Vector2.from_angle(a0) * 900.0, c + Vector2.from_angle(a0 + 0.09) * 900.0])
			draw_colored_polygon(pts, Color(accent, 0.07 * k))
		# confeti
		for b in _bits:
			draw_set_transform(b[0], b[2], Vector2.ONE)
			var sz: float = b[5]
			draw_rect(Rect2(-sz * 0.5, -sz * 0.25, sz, sz * 0.5), Color(b[4], 0.9 * k))
		draw_set_transform(Vector2.ZERO)
		# ¡VICTORIA! cae de grande y golpea
		if t > 0.1:
			var kk := clampf((t - 0.1) / 0.22, 0.0, 1.0)
			var sc := lerpf(3.2, 1.0, kk * kk)
			var hit := clampf(1.0 - (t - 0.32) / 0.4, 0.0, 1.0) if t > 0.32 else 0.0
			var base := Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(640, 220) + Vector2(randf_range(-4, 4), randf_range(-2, 2)) * hit)
			Style.title(self, Vector2.ZERO, title, 104, Color(1.0, 0.92, 0.45, kk), Color(0.18, 0.08, 0.0, kk), HORIZONTAL_ALIGNMENT_CENTER, 1200, -0.18, base)
			draw_set_transform(Vector2.ZERO)
			# brillo que cruza las letras
			var sx := fmod(t * 700.0, 2400.0) - 600.0
			draw_colored_polygon(PackedVector2Array([Vector2(sx, 130), Vector2(sx + 40, 130), Vector2(sx - 20, 240), Vector2(sx - 60, 240)]), Color(1, 1, 1, 0.18 * kk))
		# boss derrotado + línea de terminal
		if t > 0.55 and lines.size() > 0:
			var kl := _out3((t - 0.55) / 0.3)
			Style.title(self, Vector2(640 + (1.0 - kl) * 600.0, 280), str(lines[0]), 30, Color(accent.lightened(0.35), kl), Color(0.03, 0.02, 0.06, kl), HORIZONTAL_ALIGNMENT_CENTER, 1100, -0.12)
		if t > 0.8 and lines.size() > 1:
			var s1 := str(lines[1])
			var n := clampi(int((t - 0.8) / 0.025), 0, s1.length())
			draw_string(ThemeDB.fallback_font, Vector2(0, 318), s1.substr(0, n), HORIZONTAL_ALIGNMENT_CENTER, 1280, 20, Color(0.45, 1.0, 0.5))
		# panel de estadísticas (filas que entran y números que cuentan)
		if t > 1.0:
			var kp := _out3((t - 1.0) / 0.3)
			var panel := Rect2(250 - (1.0 - kp) * 700.0, 350, 560, 44.0 * stats.size() + 26.0)
			draw_colored_polygon(Style.slanted(panel, 26), Color(0.04, 0.03, 0.08, 0.88))
			draw_colored_polygon(Style.slanted(Rect2(panel.position.x, panel.position.y, panel.size.x, 4), 4), accent)
			for i in stats.size():
				var row_t := t - 1.15 - i * 0.22
				if row_t <= 0.0:
					continue
				var kr := clampf(row_t / 0.35, 0.0, 1.0)
				var st: Array = stats[i]
				var val := float(st[1]) * kr
				var txt := "%d:%02d" % [int(val) / 60, int(val) % 60] if str(st[2]) == "time" else str(int(round(val)))
				var y := panel.position.y + 44.0 + i * 44.0
				Style.title(self, Vector2(panel.position.x + 40, y), str(st[0]), 22, Color(0.85, 0.88, 1.0, kr), Color(0.02, 0.02, 0.05, kr), HORIZONTAL_ALIGNMENT_LEFT, -1, -0.1)
				Style.title(self, Vector2(panel.end.x - 70 - Style.text_w(txt, 28), y + 2), txt, 28, Color(1, 1, 1, kr), Color(0.02, 0.02, 0.05, kr), HORIZONTAL_ALIGNMENT_LEFT, -1, -0.1)
		# RANGO: sello que cae y golpea
		if rank != "" and t > RANK_AT - 0.18:
			var kk2 := clampf((t - (RANK_AT - 0.18)) / 0.18, 0.0, 1.0)
			var sc2 := lerpf(4.0, 1.0, kk2 * kk2)
			var rc := {"S": Color(1.0, 0.85, 0.2), "A": Color(0.45, 1.0, 0.5), "B": Color(0.45, 0.75, 1.0), "C": Color(0.8, 0.8, 0.85)}.get(rank, Color.WHITE) as Color
			var cpos := Vector2(985, 440)
			if t > RANK_AT:
				var e := clampf((t - RANK_AT) / 0.5, 0.0, 1.0)
				draw_arc(cpos + Vector2(0, -30), 60.0 + 140.0 * e, 0, TAU, 48, Color(rc, 1.0 - e), 8.0 * (1.0 - e) + 1.0)
			draw_set_transform(cpos + Vector2(0, -30), -0.18, Vector2(sc2, sc2))
			draw_circle(Vector2.ZERO, 74, Color(0.04, 0.03, 0.08, 0.92 * kk2))
			draw_arc(Vector2.ZERO, 74, 0, TAU, 48, Color(rc, kk2), 6.0)
			draw_arc(Vector2.ZERO, 64, 0, TAU, 48, Color(rc, 0.5 * kk2), 2.0)
			draw_set_transform(Vector2.ZERO)
			var base2 := Transform2D(-0.18, Vector2(sc2, sc2), 0.0, cpos + Vector2(0, 16))
			Style.title(self, Vector2.ZERO, rank, 104, Color(rc, kk2), Color(0.1, 0.05, 0.0, kk2), HORIZONTAL_ALIGNMENT_CENTER, 300, 0.0, base2)
			draw_set_transform(Vector2.ZERO)
			Style.title(self, cpos + Vector2(0, 74), "RANGO", 22, Color(rc, kk2), Color(0.03, 0.02, 0.06, kk2), HORIZONTAL_ALIGNMENT_CENTER, 300, 0.0)
		# nueva técnica
		if tip != "" and t > 2.3:
			var kt := _out3((t - 2.3) / 0.3)
			var r := Rect2(190, 560 + (1.0 - kt) * 60.0, 900, 52)
			var glow := 0.6 + 0.4 * absf(sin(t * 4.0))
			draw_colored_polygon(Style.slanted(r, 20), Color(0.12, 0.08, 0.0, 0.9 * kt))
			var edge := Style.slanted(r, 20)
			edge.append(edge[0])
			draw_polyline(edge, Color(1.0, 0.85, 0.3, glow * kt), 3.0)
			Style.title(self, Vector2(640, r.position.y + 35), tip, 22, Color(1.0, 0.92, 0.5, kt), Color(0.1, 0.05, 0.0, kt), HORIZONTAL_ALIGNMENT_CENTER, 880, -0.1)

	# ---------------------------------------------------------------- derrota
	func _draw_lose() -> void:
		var k := _out3(t / 0.5)
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.0, 0.02, 0.72 * k))
		# líneas de barrido (pantalla vieja) y bloques glitch
		var y := 0.0
		while y < 720.0:
			draw_rect(Rect2(0, y, 1280, 2), Color(0, 0, 0, 0.18 * k))
			y += 4.0
		if fmod(t, 0.9) < 0.12:
			for i in 6:
				draw_rect(Rect2(randf_range(0, 1200), randf_range(0, 700), randf_range(40, 260), randf_range(4, 16)), Color(1, 0.2, 0.2, 0.2 * k))
		# ceniza que cae despacio
		for b in _bits:
			draw_circle(b[0], float(b[5]) * 0.3, Color(b[4], 0.35 * k))
		# título con separación roja / cian que se va asentando
		if t > 0.2:
			var kt := clampf((t - 0.2) / 0.3, 0.0, 1.0)
			var g := clampf(1.0 - (t - 0.2) / 1.0, 0.0, 1.0) * 10.0 + (6.0 if fmod(t, 1.7) < 0.08 else 0.0)
			var base := Transform2D(0.0, Vector2.ONE, 0.0, Vector2(640, 250))
			Style.title(self, Vector2(-g, 0), title, 80, Color(1, 0.1, 0.2, 0.55 * kt), Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, 1200, -0.18, base)
			Style.title(self, Vector2(g, 0), title, 80, Color(0.2, 0.9, 1.0, 0.45 * kt), Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, 1200, -0.18, base)
			Style.title(self, Vector2.ZERO, title, 80, Color(1.0, 0.32, 0.28, kt), Color(0.08, 0.0, 0.0, kt), HORIZONTAL_ALIGNMENT_CENTER, 1200, -0.18, base)
			draw_set_transform(Vector2.ZERO)
		# líneas de terminal que se escriben
		var f := ThemeDB.fallback_font
		var start := 0.7
		for i in lines.size():
			var s1 := str(lines[i])
			var n := clampi(int((t - start) / 0.02), 0, s1.length())
			if n > 0:
				var cur := "_" if n < s1.length() and fmod(t, 0.3) < 0.15 else ""
				draw_string(f, Vector2(0, 320 + i * 30), s1.substr(0, n) + cur, HORIZONTAL_ALIGNMENT_CENTER, 1280, 20, Color(1, 0.55, 0.5) if i == 0 else Color(0.85, 0.85, 0.9))
			start += s1.length() * 0.02 + 0.15
		# consejo
		if tip != "" and t > start + 0.1:
			var kc := _out3((t - start - 0.1) / 0.3)
			var r := Rect2(220, 430, 840, 52)
			draw_colored_polygon(Style.slanted(r, 18), Color(0.05, 0.02, 0.04, 0.85 * kc))
			draw_colored_polygon(Style.slanted(Rect2(r.position.x, r.position.y, 6, r.size.y), 4), Color(1.0, 0.85, 0.3, kc))
			Style.title(self, Vector2(640, r.position.y + 33), tip, 19, Color(1, 0.93, 0.7, kc), Color(0.05, 0.02, 0.02, kc), HORIZONTAL_ALIGNMENT_CENTER, 820, 0.0)
		# ¿REINTENTAR?
		if input_ready():
			var a := 0.6 + 0.4 * absf(sin(t * 4.0))
			Style.title(self, Vector2(640, 600), "¿REINTENTAR?", 46, Color(1.0, 0.9, 0.4, a), Color(0.1, 0.03, 0.0, a), HORIZONTAL_ALIGNMENT_CENTER, 800)
