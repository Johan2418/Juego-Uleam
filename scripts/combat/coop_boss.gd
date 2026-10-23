extends RefCounted
## Ayudas para que los bosses peleen contra 1 o 2 jugadores.
##   - El boss tiene UN objetivo (`player`): a quién apunta, persigue o agarra. Se elige al
##     empezar cada ataque con retarget() (el más cercano, a veces el otro, nunca uno caído).
##   - El DAÑO es para todos: los peligros revisan cada jugador con targets() y golpean con
##     hurt_to(), que pasa por el hurt_player() del boss (parry, pausa, etc. funcionan igual).
##   - once()/ready_for(): "un golpe por jugador" y enfriamiento por jugador (antes eran por peligro).
## Con 1 jugador todo se comporta igual que antes.
## Sin class_name: cargar con preload("res://scripts/combat/coop_boss.gd").


## Jugadores que pueden recibir daño ahora (en el árbol y no caídos).
static func targets(tree: SceneTree) -> Array:
	if tree == null:
		return []
	var out: Array = []
	for p in tree.get_nodes_in_group("player"):
		if is_instance_valid(p) and (p as Node).is_inside_tree() and not bool(p.get("coop_ko")):
			out.append(p)
	return out


## Elige el objetivo del próximo ataque. Lo llama cada boss al empezar _choose_attack().
static func retarget(boss: Node) -> void:
	var ps := targets(boss.get_tree())
	if ps.size() < 2:
		if ps.size() == 1 and ps[0] != boss.get("player"):
			boss.set("player", ps[0])
		return
	var cur: Node2D = boss.get("player")
	var bpos: Vector2 = (boss as Node2D).global_position
	ps.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_to(bpos) < b.global_position.distance_to(bpos))
	var pick: Node2D = ps[0]
	# 35 %: cambia al otro jugador (así los dos tienen que esquivar)
	if randf() < 0.35:
		pick = ps[1]
	# si el actual ya no está (cayó), cambia sí o sí
	if cur == null or not is_instance_valid(cur) or not ps.has(cur):
		pick = ps[0]
	boss.set("player", pick)


## Golpea al jugador p usando el hurt_player() del boss (lo apunta a p un instante).
static func hurt_to(boss: Node, p: Node, amount: int, from: Vector2, unblockable: bool = false) -> void:
	if boss == null or not is_instance_valid(boss) or p == null or not is_instance_valid(p):
		return
	var orig: Variant = boss.get("player")
	boss.set("player", p)
	boss.call("hurt_player", amount, from, unblockable)
	if orig != null and is_instance_valid(orig):
		boss.set("player", orig)


## true la primera vez para (obj, clave, jugador): "este peligro ya golpeó a este jugador".
static func once(obj: Object, key: String, p: Object) -> bool:
	var meta: Dictionary = obj.get_meta("_coop_once", {})
	var k := "%s:%d" % [key, p.get_instance_id()]
	if meta.has(k):
		return false
	meta[k] = true
	obj.set_meta("_coop_once", meta)
	return true


## Vuelve a permitir los golpes de una clave (para peligros que se reinician).
static func reset_once(obj: Object, key: String = "") -> void:
	if key == "":
		obj.set_meta("_coop_once", {})
		return
	var meta: Dictionary = obj.get_meta("_coop_once", {})
	for k in meta.keys():
		if str(k).begins_with(key + ":"):
			meta.erase(k)
	obj.set_meta("_coop_once", meta)


## Enfriamiento por jugador: true (y reinicia) si ya pasaron `secs` desde el último golpe a p.
static func ready_for(obj: Object, key: String, p: Object, secs: float) -> bool:
	var meta: Dictionary = obj.get_meta("_coop_cd", {})
	var k := "%s:%d" % [key, p.get_instance_id()]
	var now := Time.get_ticks_msec()
	if now < int(meta.get(k, 0)):
		return false
	meta[k] = now + int(secs * 1000.0)
	obj.set_meta("_coop_cd", meta)
	return true


## Esbirros: devuelve el jugador más cercano a pos (se queda con `cur` si la diferencia es poca).
static func nearest_to(tree: SceneTree, pos: Vector2, cur: Node2D, margin: float = 20.0) -> Node2D:
	var best: Node2D = cur if cur != null and is_instance_valid(cur) and not bool(cur.get("coop_ko")) else null
	for p in targets(tree):
		if best == null or (p as Node2D).global_position.distance_to(pos) < best.global_position.distance_to(pos) - margin:
			best = p
	return best if best != null else cur


static func feet(p: Node2D) -> Vector2:
	return p.global_position + Vector2(0.0, 12.0)


static func body(p: Node2D) -> Vector2:
	return p.global_position + Vector2(0.0, -32.0)
