extends Node
## Autoload: guarda el personaje personalizado y lo persiste en user://.

const InputSetup := preload("res://scripts/input_setup.gd")

const SAVE_PATH := "user://player_appearance.cfg"
const SAVE_SECTION := "appearance"

var appearance: CharacterAppearance = CharacterAppearance.new()
var has_confirmed: bool = false
## true si lo último que se tocó fue el mando (los textos de ayuda muestran sus botones).
var using_pad: bool = false

## Bosses vencidos (Salón de las Facultades): kind -> {"rank": "A", "time": 123}. Se guarda en user://.
const PROGRESS_PATH := "user://progress.cfg"
const RANK_ORDER := "CBAS"
var bosses_defeated: Dictionary = {}
## Boss recién vencido: el salón dora su estatua al volver.
var last_won: String = ""
## Técnicas equipadas por clase: "guerrero" -> {"combo": id, "special": id, "ultimate": id}; "" = la de serie.
## Las técnicas salen de scripts/combat/techniques.gd y se desbloquean al vencer a su boss.
var loadout: Dictionary = {}

## Multijugador local (misma pantalla; se divide si se alejan). Lo activa la portada (2 JUGADORES).
var coop: bool = false
## Personaje del jugador 2.
var appearance2: CharacterAppearance = CharacterAppearance.new()
## Dispositivo de cada jugador: -1 teclado, >= 0 mando. En 1 jugador no se usa (todo responde).
var devices: Array = [-1, 0]
## Ya terminó la sala de entrenamiento alguna vez (la puerta al salón queda abierta).
var training_done: bool = false


func _ready() -> void:
	InputSetup.ensure()
	if Input.get_connected_joypads().size() > 0:
		using_pad = true
	load_appearance()
	load_progress()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		using_pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false


## Texto del botón de una acción ("J" con teclado, "X" con mando).
func btn(action: String) -> String:
	return InputSetup.label(action, using_pad)


func set_appearance(new_appearance: CharacterAppearance) -> void:
	appearance = new_appearance.duplicate_appearance()


func confirm_and_save(new_appearance: CharacterAppearance) -> void:
	set_appearance(new_appearance)
	has_confirmed = true
	save_appearance()


func save_appearance() -> void:
	var cfg := ConfigFile.new()
	var data := appearance.to_dict()
	for key in data.keys():
		cfg.set_value(SAVE_SECTION, str(key), data[key])
	cfg.set_value(SAVE_SECTION, "has_confirmed", has_confirmed)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("GameState: no se pudo guardar apariencia (%s)" % error_string(err))


func load_appearance() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return
	var data := {}
	for key in ["name", "look_preset", "look_id", "class_id", "skin_tone", "hair_style", "hair_color", "outfit", "accessory"]:
		if cfg.has_section_key(SAVE_SECTION, key):
			data[key] = cfg.get_value(SAVE_SECTION, key)
	appearance.apply_dict(data)
	has_confirmed = bool(cfg.get_value(SAVE_SECTION, "has_confirmed", false))


## Apariencia del jugador `slot` (0/1 = jugador 1, 2 = jugador 2).
func player_appearance(slot: int) -> CharacterAppearance:
	return appearance2 if slot == 2 else appearance


## Arma las acciones p1_/p2_ con los dispositivos elegidos.
func setup_coop(on: bool, dev1: int = -1, dev2: int = 0) -> void:
	coop = on
	devices = [dev1, dev2]
	if on:
		InputSetup.build_player(1, dev1)
		InputSetup.build_player(2, dev2)


## Botón de una acción para el jugador según su dispositivo (o el último usado en 1 jugador).
func btn_for(slot: int, action: String) -> String:
	if not coop or slot <= 0:
		return btn(action)
	return InputSetup.label(action, int(devices[slot - 1]) >= 0)


func get_summary_text() -> String:
	return "\n".join(appearance.summary_lines())


# --- Progreso: bosses vencidos ------------------------------------------------------

func is_defeated(kind: String) -> bool:
	return bosses_defeated.has(kind)


## Guarda la victoria; si ya estaba vencido, se queda con el mejor rango (y el mejor tiempo).
func record_victory(kind: String, rank: String, secs: int) -> void:
	var old: Dictionary = bosses_defeated.get(kind, {})
	var best_rank := rank
	var best_time := secs
	if not old.is_empty():
		if RANK_ORDER.find(str(old.get("rank", "C"))) > RANK_ORDER.find(rank):
			best_rank = str(old.get("rank", "C"))
		best_time = mini(int(old.get("time", secs)), secs)
	bosses_defeated[kind] = {"rank": best_rank, "time": best_time}
	if old.is_empty():
		last_won = kind
	save_progress()


func save_progress() -> void:
	var cfg := ConfigFile.new()
	for k in bosses_defeated.keys():
		var d: Dictionary = bosses_defeated[k]
		cfg.set_value("defeated", str(k), "%s|%d" % [d.get("rank", "C"), int(d.get("time", 0))])
	for c in loadout.keys():
		var lo: Dictionary = loadout[c]
		for slot in lo.keys():
			cfg.set_value("loadout", "%s.%s" % [c, slot], str(lo[slot]))
	cfg.set_value("misc", "training_done", training_done)
	var err := cfg.save(PROGRESS_PATH)
	if err != OK:
		push_warning("GameState: no se pudo guardar el progreso (%s)" % error_string(err))


func load_progress() -> void:
	bosses_defeated.clear()
	loadout.clear()
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	training_done = bool(cfg.get_value("misc", "training_done", false))
	if cfg.has_section("loadout"):
		for key in cfg.get_section_keys("loadout"):
			var parts2 := str(key).split(".")
			if parts2.size() == 2:
				if not loadout.has(parts2[0]):
					loadout[parts2[0]] = {}
				loadout[parts2[0]][parts2[1]] = str(cfg.get_value("loadout", key, ""))
	if not cfg.has_section("defeated"):
		return
	for k in cfg.get_section_keys("defeated"):
		var parts := str(cfg.get_value("defeated", k, "C|0")).split("|")
		bosses_defeated[k] = {"rank": parts[0], "time": int(parts[1]) if parts.size() > 1 else 0}


# --- Técnicas equipadas ------------------------------------------------------------

const Techniques := preload("res://scripts/combat/techniques.gd")


## ¿Ya se consiguió esta técnica? (se vence a su boss)
func tech_unlocked(id: String) -> bool:
	if id == "":
		return true
	var d: Dictionary = Techniques.info(id)
	return not d.is_empty() and is_defeated(str(d["boss"]))


## Técnica equipada en una ranura de una clase ("" = la de serie). Si dejó de estar disponible, vuelve a la de serie.
func equipped(class_id: String, slot: String) -> String:
	var lo: Dictionary = loadout.get(class_id, {})
	var id := str(lo.get(slot, ""))
	if id != "" and (not tech_unlocked(id) or str(Techniques.info(id).get("slot", "")) != slot):
		return ""
	return id


func equip(class_id: String, slot: String, id: String) -> void:
	if not loadout.has(class_id):
		loadout[class_id] = {}
	loadout[class_id][slot] = id
	save_progress()
