extends RefCounted
## Lluvia de ataques al cambiar de fase (común a los 8 bosses).
## Durante la lluvia el boss sigue en state "transition" (no recibe daño) y tiene una barrera visible.
## Lanza ataques por todos lados que solo se pueden ESQUIVAR (rodar / moverse) o PARRY:
##   - Orbes (parry o esquivar; 1 de daño): espirales desde el boss, abanicos y ráfagas desde los bordes.
##   - Zonas rojas en el piso (no se bloquean; rodar o salir; 2 de daño).
##   - Ondas de choque (no se bloquean; rodar a través; 2 de daño).
## Uso dentro de _enter_phase del boss:  if not await Barrage.run(self, n, tok): return
## Sin class_name: cargar con preload("res://scripts/combat/boss_barrage.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")

## Duración de la lluvia por fase (segundos, sin contar la limpieza final).
const DURATION := {2: 7.5, 3: 9.5}

## Color de cada boss (según su script).
const COLORS := {
	"deadbeef": Color(1.0, 0.3, 0.2), "bsod": Color(0.35, 0.6, 1.0), "div0": Color(1.0, 0.8, 0.25),
	"syntax": Color(0.45, 0.95, 0.5), "stack": Color(1.0, 0.6, 0.2), "judge": Color(1.0, 0.3, 0.3),
	"tex": Color(1.0, 0.25, 0.9), "kp": Color(1.0, 0.65, 0.15),
}

## Programa de cada fase: [segundo, ataque, parámetros]
const PLAN := {
	2: [
		[0.2, "ring", {}],
		[0.5, "spiral", {"arms": 5, "time": 2.0, "every": 0.2, "speed": 200.0, "spin": 0.35}],
		[2.8, "rain", {"count": 4, "warn": 0.95, "r": 62.0}],
		[3.6, "edges", {"count": 6, "every": 0.22, "speed": 260.0}],
		[5.1, "fan", {"count": 5, "spread": 0.9, "speed": 250.0}],
		[5.6, "fan", {"count": 5, "spread": 0.9, "speed": 250.0}],
		[6.2, "rain", {"count": 3, "warn": 0.9, "r": 62.0}],
		[6.4, "ring", {}],
	],
	3: [
		[0.2, "ring", {}],
		[0.4, "spiral", {"arms": 6, "time": 2.4, "every": 0.17, "speed": 220.0, "spin": 0.42}],
		[0.5, "spiral", {"arms": 3, "time": 2.2, "every": 0.26, "speed": 170.0, "spin": -0.6}],
		[2.9, "rain", {"count": 6, "warn": 0.8, "r": 66.0}],
		[3.4, "edges", {"count": 9, "every": 0.17, "speed": 290.0}],
		[4.4, "ring", {}],
		[5.2, "fan", {"count": 7, "spread": 1.1, "speed": 280.0}],
		[5.6, "fan", {"count": 7, "spread": 1.1, "speed": 280.0}],
		[6.0, "fan", {"count": 7, "spread": 1.1, "speed": 280.0}],
		[6.6, "rain", {"count": 5, "warn": 0.75, "r": 66.0}],
		[7.2, "spiral", {"arms": 8, "time": 1.6, "every": 0.2, "speed": 240.0, "spin": 0.3}],
		[8.6, "ring", {}],
		[8.8, "edges", {"count": 4, "every": 0.12, "speed": 300.0}],
	],
}


static func kind_of(boss: Node) -> String:
	var path: String = boss.get_script().resource_path if boss.get_script() else ""
	for k in COLORS:
		if path.ends_with("boss_%s.gd" % k):
			return k
	return "deadbeef"


## (sin tipo: si se sale de la arena en plena lluvia, boss ya puede estar liberado)
static func _alive(boss: Variant, tok: int) -> bool:
	return is_instance_valid(boss) and boss.is_inside_tree() and int(boss.get("_tok")) == tok


## Corre la lluvia completa. Devuelve false si el boss fue interrumpido (muerte, pausa, reintento).
static func run(boss: Node2D, phase: int, tok: int) -> bool:
	if not PLAN.has(phase):
		return true
	# cada boss trae su propia lluvia (barrage_plan + _bar_<ataque>); si no, la genérica
	var steps: Array = boss.call("barrage_plan", phase) if boss.has_method("barrage_plan") else PLAN[phase]
	var title: String = boss.call("barrage_title", phase) if boss.has_method("barrage_title") else ""
	var col: Color = COLORS[kind_of(boss)]
	var dur: float = DURATION[phase]
	var center: Vector2 = boss.get_script().get_script_constant_map().get("CENTER", Vector2(0, -110))
	var barrier := Barrier.new()
	barrier.col = col
	barrier.total = dur
	barrier.position = center
	barrier.radius = clampf(-center.y + 30.0, 110.0, 170.0)
	boss.add_child(barrier)
	var banner := Banner.new()
	banner.col = col
	banner.text2 = "¡INMUNE!  ESQUIVA O HAZ PARRY"
	banner.text1 = title
	boss.get_parent().add_child(banner)
	GameFeel.flash(boss, 0.25, col.lightened(0.4))
	var t := 0.0
	var i := 0
	while t < dur:
		while i < steps.size() and float(steps[i][0]) <= t:
			_fire(boss, String(steps[i][1]), steps[i][2], col, tok)
			i += 1
		await boss.get_tree().create_timer(0.05).timeout
		if not _alive(boss, tok):
			if is_instance_valid(barrier):
				barrier.queue_free()
			if is_instance_valid(boss):
				_clear(boss)
			return false
		t += 0.05
		barrier.left = dur - t
	# fin: la barrera se rompe y se limpian los orbes que queden
	barrier.shatter()
	_clear(boss)
	GameFeel.parry_burst(boss.get_parent(), boss.global_position + center, 70.0)
	if boss.has_method("_say"):
		boss.call("_say", "¡BARRERA ROTA!", Color(1, 1, 0.7), 1.0)
	await boss.get_tree().create_timer(0.5).timeout
	return _alive(boss, tok)


## Lo usa cada boss en sus _bar_*: agrega el peligro a la arena y lo marca como parte de la lluvia.
static func tag(n: Node) -> void:
	n.add_to_group("barrage_fx")


static func _clear(boss: Node) -> void:
	if not is_instance_valid(boss) or not boss.is_inside_tree():
		return
	for n in boss.get_tree().get_nodes_in_group("barrage_fx"):
		if n.has_method("fizzle"):
			n.call("fizzle")
		else:
			n.queue_free()


static func _add(boss: Node2D, n: Node2D, at: Vector2) -> void:
	if "boss" in n:
		n.set("boss", boss)
	if "player" in n:
		n.set("player", boss.get("player"))
	boss.get_parent().add_child(n)
	n.global_position = at


static func _player(boss: Node) -> Node2D:
	var p: Variant = boss.get("player")
	return p if p != null and is_instance_valid(p) else null


static func _fire(boss: Node2D, what: String, a: Dictionary, col: Color, tok: int) -> void:
	if boss.has_method("_bar_" + what):
		boss.call("_bar_" + what, a, tok)
		return
	var origin := boss.global_position + Vector2(0, -40)
	var rect: Rect2 = boss.get("arena_rect")
	match what:
		"ring":
			var ring := BossFx.ShockRing.new()
			ring.max_r = 430.0
			ring.speed = 380.0
			ring.add_to_group("barrage_fx")
			_add(boss, ring, boss.global_position)
			if boss.has_method("_shake"):
				boss.call("_shake", 4.0, 0.25)
		"spiral":
			_spiral(boss, origin, a, col, tok)
		"fan":
			var p := _player(boss)
			var aim := Vector2.DOWN if p == null else (p.global_position + Vector2(0, -32) - origin).normalized()
			var n: int = a["count"]
			for k in n:
				var off: float = (float(k) / float(n - 1) - 0.5) * float(a["spread"])
				_shot(boss, origin, aim.rotated(off) * float(a["speed"]), col)
		"edges":
			_edges(boss, rect, a, col, tok)
		"rain":
			var p := _player(boss)
			var n: int = a["count"]
			for k in n + 1:
				var at := Vector2(randf_range(rect.position.x + 60.0, rect.end.x - 60.0), randf_range(rect.position.y + 90.0, rect.end.y - 40.0))
				if k == 0 and p != null:
					at = p.global_position + Vector2(0, 12)   # siempre una debajo del jugador
				var z := Strike.new()
				z.col = col
				z.warn = float(a["warn"])
				z.r = float(a["r"])
				_add(boss, z, at)


static func _spiral(boss: Node2D, origin: Vector2, a: Dictionary, col: Color, tok: int) -> void:
	var t := 0.0
	var ang := randf() * TAU
	var arms: int = a["arms"]
	while t < float(a["time"]):
		if not _alive(boss, tok):
			return
		for k in arms:
			var d := Vector2.from_angle(ang + TAU * k / arms)
			_shot(boss, origin + d * 30.0, Vector2(d.x, d.y * 0.75).normalized() * float(a["speed"]), col)
		ang += float(a["spin"])
		await boss.get_tree().create_timer(float(a["every"])).timeout
		t += float(a["every"])


static func _edges(boss: Node2D, rect: Rect2, a: Dictionary, col: Color, tok: int) -> void:
	for k in int(a["count"]):
		if not _alive(boss, tok):
			return
		var p := _player(boss)
		if p == null:
			return
		var side := randi() % 4
		var at := Vector2.ZERO
		match side:
			0: at = Vector2(rect.position.x + 10.0, randf_range(rect.position.y + 60.0, rect.end.y - 20.0))
			1: at = Vector2(rect.end.x - 10.0, randf_range(rect.position.y + 60.0, rect.end.y - 20.0))
			2: at = Vector2(randf_range(rect.position.x + 40.0, rect.end.x - 40.0), rect.position.y + 60.0)
			_: at = Vector2(randf_range(rect.position.x + 40.0, rect.end.x - 40.0), rect.end.y - 10.0)
		var aim := (p.global_position + Vector2(0, -32) - at).normalized()
		var s := _shot(boss, at, aim * float(a["speed"]), col)
		s.delay = 0.35   # aparece, avisa y luego sale disparado
		await boss.get_tree().create_timer(float(a["every"])).timeout


static func _shot(boss: Node2D, at: Vector2, vel: Vector2, col: Color) -> Shot:
	var s := Shot.new()
	s.vel = vel
	s.col = col
	_add(boss, s, at)
	return s


## Orbe: se puede hacer parry (de frente) o esquivar rodando. 1 de daño.
class Shot extends BossFx.Hazard:
	var vel := Vector2.DOWN * 200.0
	var col := Color.RED
	var t := 0.0
	var delay := 0.0
	var life := 4.0
	var _dead := 0.0

	func _init() -> void:
		super._init()
		add_to_group("barrage_fx")

	func _ready() -> void:
		z_index = 5

	func fizzle() -> void:
		if _dead <= 0.0:
			_dead = 0.001

	func _process(delta: float) -> void:
		t += delta
		if _dead > 0.0:
			_dead += delta
			if _dead > 0.2:
				queue_free()
			queue_redraw()
			return
		if t > delay:
			global_position += vel * delta
		if t > delay + life:
			queue_free()
			return
		if t > delay and player_ok() and player_body().distance_to(global_position) < 20.0:
			if bool(player.get("rolling")):
				pass   # rodando lo atraviesa
			else:
				hurt(1, false)   # el jugador decide: parry de frente lo bloquea
				GameFeel.parry_burst(get_parent(), global_position, 14.0)
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - clampf(_dead / 0.2, 0.0, 1.0)
		var k := 1.0 if t > delay else clampf(t / maxf(delay, 0.01), 0.2, 1.0)
		if t <= delay:
			var aim := vel.normalized() * 34.0
			draw_line(Vector2.ZERO, aim, Color(col, 0.6 * absf(sin(t * 30.0))), 2.0)
		else:
			var back := -vel.normalized()
			for i in 4:
				draw_circle(back * (6.0 + i * 6.0), 6.0 - i * 1.2, Color(col, 0.25 * a * (1.0 - i * 0.2)))
		draw_circle(Vector2.ZERO, 12.0 * k, Color(col.darkened(0.3), 0.9 * a))
		draw_circle(Vector2.ZERO, 8.5 * k, Color(col.lightened(0.3), a))
		draw_circle(Vector2(-2, -2), 3.0 * k, Color(1, 1, 1, 0.9 * a))


## Zona roja en el piso: avisa y explota. No se bloquea; hay que salir o rodar. 2 de daño.
class Strike extends BossFx.Hazard:
	var col := Color.RED
	var warn := 0.9
	var r := 60.0
	var t := 0.0
	var _boom := false

	func _init() -> void:
		super._init()
		add_to_group("barrage_fx")

	func _ready() -> void:
		z_index = -1

	func fizzle() -> void:
		if not _boom:
			queue_free()

	func _process(delta: float) -> void:
		t += delta
		if not _boom and t >= warn:
			_boom = true
			if player_ok():
				var d := player_feet() - global_position
				if Vector2(d.x, d.y * 2.0).length() < r:
					hurt(2, true)
			GameFeel.dust(get_parent(), global_position, 6, Vector2.ZERO, 3.0)
		if t >= warn + 0.3:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if not _boom:
			var k := clampf(t / warn, 0.0, 1.0)
			var blink := 0.6 + 0.4 * absf(sin(t * 16.0))
			ellipse(Vector2.ZERO, Vector2(r, r * 0.5), Color(col, 0.12 * blink))
			ellipse(Vector2.ZERO, Vector2(r * k, r * k * 0.5), Color(col, 0.3))
			ellipse_line(Vector2.ZERO, Vector2(r, r * 0.5), Color(col.lightened(0.2), 0.85 * blink), 2.0)
		else:
			var e := clampf((t - warn) / 0.3, 0.0, 1.0)
			ellipse(Vector2.ZERO, Vector2(r * (1.0 + e * 0.3), r * 0.5 * (1.0 + e * 0.3)), Color(1, 1, 0.85, 0.7 * (1.0 - e)))
			draw_line(Vector2(0, 0), Vector2(0, -220 * (1.0 - e)), Color(col.lightened(0.4), 1.0 - e), 10.0 * (1.0 - e))


## Barrera alrededor del boss: le dice al jugador que ahora no se le puede pegar.
class Barrier extends Node2D:
	var col := Color.RED
	var radius := 130.0
	var total := 8.0
	var left := 8.0
	var t := 0.0
	var _break := -1.0

	func _ready() -> void:
		z_index = 4

	func shatter() -> void:
		_break = 0.0

	func _process(delta: float) -> void:
		t += delta
		if _break >= 0.0:
			_break += delta
			if _break > 0.45:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 if _break < 0.0 else 1.0 - _break / 0.45
		var grow := 1.0 if _break < 0.0 else 1.0 + _break
		var r := radius * grow * (1.0 + 0.02 * sin(t * 6.0))
		var pts := PackedVector2Array()
		for i in 7:
			var ang := TAU * i / 6.0 + t * 0.4
			pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.9))
		draw_colored_polygon(pts, Color(col, 0.08 * a))
		draw_polyline(pts, Color(col.lightened(0.3), (0.5 + 0.3 * sin(t * 9.0)) * a), 3.0)
		for i in 6:
			draw_line(Vector2.ZERO, pts[i] * 0.3, Color(col, 0.15 * a), 1.0)
		# tiempo que queda: arco alrededor
		if _break < 0.0:
			var frac := clampf(left / total, 0.0, 1.0)
			draw_arc(Vector2.ZERO, r + 10.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, Color(1, 1, 1, 0.55), 3.0)
			var f := ThemeDB.fallback_font
			var ly := r + 30.0   # debajo del boss (arriba se taparía con la barra del jefe)
			draw_string_outline(f, Vector2(-80, ly), "INMUNE", HORIZONTAL_ALIGNMENT_CENTER, 160, 16, 4, Color(0, 0, 0, 0.9))
			draw_string(f, Vector2(-80, ly), "INMUNE", HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(col.lightened(0.4), 0.7 + 0.3 * sin(t * 8.0)))


## Cartel grande en el centro de la pantalla que avisa al empezar la lluvia.
class Banner extends CanvasLayer:
	var col := Color.RED
	var text1 := ""
	var text2 := ""
	var t := 0.0
	var _c: Control

	func _ready() -> void:
		layer = 6
		_c = Control.new()
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.size = Vector2(1280, 720)
		_c.draw.connect(_paint)
		add_child(_c)

	func _process(delta: float) -> void:
		t += delta
		if t > 2.2:
			queue_free()
		_c.queue_redraw()

	func _paint() -> void:
		var a := clampf(2.2 - t, 0.0, 1.0) if t > 1.2 else 1.0
		var s := 1.0 + maxf(0.0, 0.3 - t)
		var f := ThemeDB.fallback_font
		_c.draw_set_transform(Vector2(640, 250 - t * 10.0), 0.0, Vector2(s, s))
		_c.draw_rect(Rect2(-300, -34, 600, 48), Color(0, 0, 0, 0.6 * a))
		_c.draw_string_outline(f, Vector2(-300, 0), text2, HORIZONTAL_ALIGNMENT_CENTER, 600, 26, 6, Color(0, 0, 0, a))
		_c.draw_string(f, Vector2(-300, 0), text2, HORIZONTAL_ALIGNMENT_CENTER, 600, 26, Color(col.lightened(0.5), a))
		if text1 != "":
			_c.draw_rect(Rect2(-300, -78, 600, 40), Color(0, 0, 0, 0.6 * a))
			_c.draw_string_outline(f, Vector2(-300, -48), text1, HORIZONTAL_ALIGNMENT_CENTER, 600, 30, 6, Color(0, 0, 0, a))
			_c.draw_string(f, Vector2(-300, -48), text1, HORIZONTAL_ALIGNMENT_CENTER, 600, 30, Color(col.lightened(0.2), a))
