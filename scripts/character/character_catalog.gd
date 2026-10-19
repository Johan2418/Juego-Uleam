class_name CharacterCatalog
extends RefCounted
## Catálogo de personajes seleccionables (cabeza intercambiable + cuerpo compartido).
## Datos: res://assets/sprites/characters/characters.json
## Regenerar con: tools/character_split/build_characters.py

const ROOT := "res://assets/sprites/characters/"
const JSON_PATH := ROOT + "characters.json"
const VIEWS := ["front", "back", "right"]
## false = volver a listar los 18 personajes del sistema cabeza+cuerpo (descartado).
const ONLY_PLAYABLE := true

static var _data: Dictionary = {}
static var _list: Array = []
static var _by_id: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func _ensure_loaded() -> void:
	if not _list.is_empty():
		return
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("CharacterCatalog: no se encontró %s" % JSON_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CharacterCatalog: JSON inválido")
		return
	_data = parsed
	for entry in _data.get("characters", []):
		# Solo personajes con animaciones dedicadas (ver CharacterSprites.PLAYABLE).
		if ONLY_PLAYABLE and not CharacterSprites.is_playable(str(entry["id"])):
			continue
		_list.append(entry)
		_by_id[str(entry["id"])] = entry


## Lista de {id, label, shirt, pants, heads{...}}
static func list() -> Array:
	_ensure_loaded()
	return _list


static func count() -> int:
	return list().size()


static func get_entry(id: String) -> Dictionary:
	_ensure_loaded()
	if _by_id.has(id):
		return _by_id[id]
	return _list[0] if not _list.is_empty() else {}


static func index_of(id: String) -> int:
	var l := list()
	for i in l.size():
		if str(l[i]["id"]) == id:
			return i
	return -1


## "left" usa la vista "right" espejada.
static func view_for(facing: String) -> String:
	return "right" if facing == "left" else facing


static func body_texture(view: String) -> Texture2D:
	return load_texture(ROOT + "body_base/%s.png" % view)


static func body_mask(view: String) -> Texture2D:
	return load_texture(ROOT + "body_base/%s_mask.png" % view)


## {neck: [x, y], shirt_ref, pants_ref}
static func body_info(view: String) -> Dictionary:
	_ensure_loaded()
	return _data.get("body", {}).get(view, {"neck": [0, 0], "shirt_ref": 0.833, "pants_ref": 0.377})


static func head_texture(id: String, view: String) -> Texture2D:
	var e := get_entry(id)
	if e.is_empty():
		return null
	return load_texture(ROOT + str(e["heads"][view]["file"]))


static func head_anchor(id: String, view: String) -> Vector2:
	var e := get_entry(id)
	if e.is_empty():
		return Vector2.ZERO
	var a: Array = e["heads"][view]["anchor"]
	return Vector2(float(a[0]), float(a[1]))


static func color_of(id: String, key: String) -> Color:
	var e := get_entry(id)
	var c: Variant = e.get(key, null)
	if c == null:
		return Color.WHITE
	return Color8(int(c[0]), int(c[1]), int(c[2]))


static func load_texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			tex = res
	if tex == null:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img := Image.new()
			if img.load(abs_path) == OK:
				tex = ImageTexture.create_from_image(img)
	if tex == null:
		push_warning("CharacterCatalog: falta textura %s" % path)
	_tex_cache[path] = tex
	return tex
