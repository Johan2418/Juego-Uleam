class_name CharacterAppearance
extends RefCounted
## Apariencia del universitario — presets visuales + clase de combate.

## Personajes seleccionables: vienen de CharacterCatalog (assets/sprites/characters/characters.json).
static func presets() -> Array:
	return CharacterCatalog.list()


static func preset_count() -> int:
	return maxi(CharacterCatalog.count(), 1)

const CLASSES: Array = [
	{"id": "guerrero", "label": "Guerrero"},
	{"id": "mago", "label": "Mago"},
	{"id": "chain", "label": "Chain"},
]

## Legado (compatibilidad de save); ya no impulsan el sprite.
const SKIN_TONES: Array = [
	{"id": "clara", "label": "Clara", "color": Color("f0c8a0")},
	{"id": "media", "label": "Media", "color": Color("d4a574")},
	{"id": "morena", "label": "Morena", "color": Color("a0673f")},
	{"id": "oscura", "label": "Oscura", "color": Color("6b3f2a")},
]

const HAIR_STYLES: Array = [
	{"id": "corto", "label": "Corto"},
	{"id": "medio", "label": "Medio"},
	{"id": "largo", "label": "Largo"},
	{"id": "recogido", "label": "Recogido"},
	{"id": "rizado", "label": "Rizado"},
]

const HAIR_COLORS: Array = [
	{"id": "negro", "label": "Negro", "color": Color("1a1a1a")},
	{"id": "castano", "label": "Castaño", "color": Color("5c3317")},
	{"id": "rubio", "label": "Rubio", "color": Color("e0c060")},
	{"id": "pelirrojo", "label": "Pelirrojo", "color": Color("c04020")},
	{"id": "azul", "label": "Azul", "color": Color("3060c0")},
	{"id": "rosa", "label": "Rosa", "color": Color("e060a0")},
]

const OUTFITS: Array = [
	{"id": "hoodie", "label": "Hoodie uni", "primary": Color("3a5a8c"), "secondary": Color("2a4060")},
	{"id": "camiseta", "label": "Camiseta uni", "primary": Color("c04040"), "secondary": Color("f0f0f0")},
	{"id": "camisa", "label": "Camisa", "primary": Color("e8e0d0"), "secondary": Color("4060a0")},
	{"id": "chaqueta", "label": "Chaqueta", "primary": Color("2a2a2a"), "secondary": Color("808080")},
	{"id": "lab", "label": "Bata de lab", "primary": Color("f5f5f5"), "secondary": Color("4050a0")},
]

const ACCESSORIES: Array = [
	{"id": "none", "label": "Ninguno"},
	{"id": "glasses", "label": "Gafas"},
	{"id": "backpack", "label": "Mochila"},
	{"id": "cap", "label": "Gorra"},
	{"id": "headphones", "label": "Auriculares"},
]

var student_name: String = "Estudiante"
var look_preset: int = 0
var class_id: String = "guerrero"
var skin_tone: int = 1
var hair_style: int = 1
var hair_color: int = 1
var outfit: int = 0
var accessory: int = 0


func _init(
		p_name: String = "Estudiante",
		p_look: int = 0,
		p_class: String = "guerrero",
		p_skin: int = 1,
		p_hair_style: int = 1,
		p_hair_color: int = 1,
		p_outfit: int = 0,
		p_accessory: int = 0
	) -> void:
	student_name = p_name
	look_preset = clampi(p_look, 0, preset_count() - 1)
	class_id = normalize_class_id(p_class)
	skin_tone = clampi(p_skin, 0, SKIN_TONES.size() - 1)
	hair_style = clampi(p_hair_style, 0, HAIR_STYLES.size() - 1)
	hair_color = clampi(p_hair_color, 0, HAIR_COLORS.size() - 1)
	outfit = clampi(p_outfit, 0, OUTFITS.size() - 1)
	accessory = clampi(p_accessory, 0, ACCESSORIES.size() - 1)


func duplicate_appearance() -> CharacterAppearance:
	return CharacterAppearance.new(
		student_name, look_preset, class_id, skin_tone, hair_style, hair_color, outfit, accessory
	)


func to_dict() -> Dictionary:
	return {
		"name": student_name,
		"look_preset": look_preset,
		"look_id": get_preset_id(),
		"class_id": class_id,
		"skin_tone": skin_tone,
		"hair_style": hair_style,
		"hair_color": hair_color,
		"outfit": outfit,
		"accessory": accessory,
	}


func apply_dict(data: Dictionary) -> void:
	student_name = str(data.get("name", student_name))
	look_preset = clampi(int(data.get("look_preset", look_preset)), 0, preset_count() - 1)
	if data.has("look_id"):
		var idx := CharacterCatalog.index_of(str(data["look_id"]))
		if idx >= 0:
			look_preset = idx
	class_id = normalize_class_id(str(data.get("class_id", class_id)))
	skin_tone = clampi(int(data.get("skin_tone", skin_tone)), 0, SKIN_TONES.size() - 1)
	hair_style = clampi(int(data.get("hair_style", hair_style)), 0, HAIR_STYLES.size() - 1)
	hair_color = clampi(int(data.get("hair_color", hair_color)), 0, HAIR_COLORS.size() - 1)
	outfit = clampi(int(data.get("outfit", outfit)), 0, OUTFITS.size() - 1)
	accessory = clampi(int(data.get("accessory", accessory)), 0, ACCESSORIES.size() - 1)


func get_preset_label() -> String:
	var l := presets()
	if l.is_empty():
		return "?"
	return option_label(l, look_preset)


func get_preset_id() -> String:
	var l := presets()
	if l.is_empty():
		return ""
	return str(l[clampi(look_preset, 0, l.size() - 1)]["id"])


func get_class_index() -> int:
	for i in CLASSES.size():
		if str(CLASSES[i]["id"]) == class_id:
			return i
	return 0


func get_class_label() -> String:
	return option_label(CLASSES, get_class_index())


func set_class_index(index: int) -> void:
	index = clampi(index, 0, CLASSES.size() - 1)
	class_id = str(CLASSES[index]["id"])


func get_skin_color() -> Color:
	return SKIN_TONES[skin_tone]["color"]


func get_hair_color() -> Color:
	return HAIR_COLORS[hair_color]["color"]


func get_outfit_primary() -> Color:
	return OUTFITS[outfit]["primary"]


func get_outfit_secondary() -> Color:
	return OUTFITS[outfit]["secondary"]


func get_preset_default_name() -> String:
	var l := presets()
	if l.is_empty():
		return ""
	var entry: Dictionary = l[clampi(look_preset, 0, l.size() - 1)]
	if entry.has("default_name"):
		return str(entry["default_name"])
	# Sin default_name en characters.json: usar el nombre visible del preset.
	return str(entry.get("label", ""))


## ¿Es este nombre uno automático (vacío, "Estudiante" o el nombre de algún preset)?
static func is_auto_name(n: String) -> bool:
	var clean := n.strip_edges()
	if clean.is_empty() or clean == "Estudiante":
		return true
	for entry in presets():
		var d: Dictionary = entry
		if clean == str(d.get("default_name", "")) or clean == str(d.get("label", "")):
			return true
	return false


func summary_lines() -> PackedStringArray:
	return PackedStringArray([
		"Nombre: %s" % student_name,
		"Apariencia: %s" % get_preset_label(),
		"Clase: %s" % get_class_label(),
		"Personaje: %s" % get_preset_id(),
	])


static func normalize_class_id(id: String) -> String:
	var needle := id.strip_edges().to_lower()
	for entry in CLASSES:
		if str(entry["id"]) == needle:
			return needle
	return "guerrero"


static func option_label(options: Array, index: int) -> String:
	index = clampi(index, 0, options.size() - 1)
	return str(options[index]["label"])
