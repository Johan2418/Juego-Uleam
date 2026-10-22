extends RefCounted
## Multijugador local (2 jugadores en la misma pantalla).
##   Coop.spawn(parent, pos, exit_scene) crea 1 o 2 jugadores según GameState.coop y, con 2,
##   añade la vista compartida: una sola cámara mientras están cerca; si se alejan, la pantalla
##   se parte con una línea que gira según dónde está cada uno (pantalla dividida dinámica tipo
##   Voronoi) y se vuelve a juntar sola cuando se acercan.
## Sin class_name: cargar con preload("res://scripts/coop.gd").

const PlayerScene := preload("res://scenes/combat/player.tscn")
const SPLIT_SHADER := preload("res://shaders/coop_split.gdshader")


## Crea los jugadores (1 o 2) y devuelve [jugador1, jugador2?].
static func spawn(parent: Node, pos: Vector2, exit_scene: String = "") -> Array:
	var out: Array = []
	var n := 2 if GameState.coop else 1
	for i in n:
		var p: Node2D = PlayerScene.instantiate()
		p.set("slot", i + 1 if GameState.coop else 0)
		if exit_scene != "":
			p.set("exit_scene", exit_scene)
		p.position = pos + (Vector2(-40.0 + 80.0 * i, 0.0) if n == 2 else Vector2.ZERO)
		parent.add_child(p)
		out.append(p)
	if n == 2:
		# los jugadores se atraviesan entre sí (si no, se estorban en los pasillos)
		(out[0] as PhysicsBody2D).add_collision_exception_with(out[1])
		var v := View.new()
		v.players = out
		parent.add_child(v)
	return out


## Todos los jugadores de la escena (los que estén vivos en el árbol).
static func players(tree: SceneTree) -> Array:
	return tree.get_nodes_in_group("player").filter(func(p: Node) -> bool: return is_instance_valid(p))


## El jugador más cercano a un punto (o null).
static func nearest(tree: SceneTree, at: Vector2) -> Node2D:
	var best: Node2D = null
	var bd := INF
	for p in players(tree):
		var d := (p as Node2D).global_position.distance_to(at)
		if d < bd:
			bd = d
			best = p
	return best


## Vista compartida / dividida. Va en una capa por debajo del HUD (5) y de la viñeta (2).
class View extends CanvasLayer:
	var players: Array = []
	## true mientras la pantalla está partida (la usan los HUD si quieren saberlo).
	var split := false
	var _vps: Array = []
	var _cams: Array = []
	var _rect: ColorRect
	var _mat: ShaderMaterial
	var _line := 0.0

	func _ready() -> void:
		layer = 1
		name = "CoopView"
		var size := Vector2(1280, 720)
		for i in 2:
			var vp := SubViewport.new()
			vp.size = Vector2i(size)
			vp.world_2d = get_viewport().world_2d
			vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			vp.audio_listener_enable_2d = false
			add_child(vp)
			var cam := Camera2D.new()
			vp.add_child(cam)
			cam.make_current()
			_vps.append(vp)
			_cams.append(cam)
		_rect = ColorRect.new()
		_rect.size = size
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mat = ShaderMaterial.new()
		_mat.shader = SPLIT_SHADER
		_mat.set_shader_parameter("view_a", (_vps[0] as SubViewport).get_texture())
		_mat.set_shader_parameter("view_b", (_vps[1] as SubViewport).get_texture())
		_mat.set_shader_parameter("size", size)
		_rect.material = _mat
		add_child(_rect)
		process_priority = 100   # después de que los jugadores se muevan

	func _process(delta: float) -> void:
		if players.size() < 2 or not is_instance_valid(players[0]) or not is_instance_valid(players[1]):
			return
		var p1: Node2D = players[0]
		var p2: Node2D = players[1]
		var c1 := p1.get_node_or_null("Camera2D") as Camera2D
		var c2 := p2.get_node_or_null("Camera2D") as Camera2D
		var zoom := c1.zoom if c1 else Vector2.ONE
		var a := p1.global_position + Vector2(0, -30) + (c1.position if c1 else Vector2.ZERO)
		var b := p2.global_position + Vector2(0, -30) + (c2.position if c2 else Vector2.ZERO)
		var d := b - a
		var dist := d.length()
		var n := d / dist if dist > 0.01 else Vector2.RIGHT
		# distancia del centro al borde de la pantalla en la dirección n; cada jugador queda a la mitad
		var half := Vector2(640, 360) / zoom
		var edge := minf(half.x / maxf(absf(n.x), 0.001), half.y / maxf(absf(n.y), 0.001))
		var r := edge * 0.5
		var k := minf(dist * 0.5, r)
		split = dist * 0.5 > r
		_line = move_toward(_line, 1.0 if split else 0.0, delta * 6.0)
		var cams := [c1, c2]
		var pos := [a + n * k, b - n * k]
		for i in 2:
			var cam: Camera2D = _cams[i]
			cam.zoom = zoom
			cam.position = pos[i]
			var src: Camera2D = cams[i]
			cam.offset = src.offset if src else Vector2.ZERO
		_mat.set_shader_parameter("normal", n)
		_mat.set_shader_parameter("split", 1.0 if split else 0.0)
		_mat.set_shader_parameter("line", _line)
