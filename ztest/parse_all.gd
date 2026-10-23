extends Node
## Carga todos los scripts del proyecto y avisa los que no compilan.
func _ready() -> void:
	var bad := 0
	for dir in ["res://scripts/combat/", "res://scripts/", "res://scripts/ui/", "res://autoload/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var s: Script = load(dir + f)
				if s == null or not s.can_instantiate():
					print("MAL ", dir + f)
					bad += 1
	print("PARSE malos: ", bad)
	get_tree().quit()
