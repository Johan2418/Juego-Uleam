extends RefCounted
## Base común de los DUELOS FINALES (cuando el boss queda a un golpe en la fase 3).
## Cada boss tiene su propio duelo, pero comparten:
##   - music_cue / music_final: cambiar a <boss>_final1..3, volver a _p3 o tocar <boss>_epic.
##   - Shot: proyectil al que hay que hacerle parry (opcionalmente PRECISO) y que vuelve al boss.
##   - Title: cartel grande en el centro de la pantalla.
## Música: tools/boss_final_music.py <carpeta> <boss>.
## Sin class_name: cargar con preload("res://scripts/combat/boss_final.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")


static func arena(boss: Node) -> Node:
	var a := boss.get_parent()
	return a if a != null and a.has_method("music_cue") else null


static func music_cue(boss: Node, part: String) -> void:
	var a := arena(boss)
	if a:
		a.call("music_cue", part)


static func music_final(boss: Node, part: String) -> void:
	var a := arena(boss)
	if a:
		a.call("music_final", part)


static func title(boss: Node, text: String, col: Color, sub: String = "", life: float = 1.6) -> void:
	var t := Title.new()
	t.text = text
	t.sub = sub
	t.col = col
	t.life = life
	boss.get_parent().add_child(t)


## ¿El jugador tiene un parry activo que cubre `from`? strict > 0: además, pulsado hace ≤ strict s.
static func parry_ok(player: Node, from: Vector2, strict: float = 0.0) -> int:
	## 1 = parry bueno, 0 = no hay parry, -1 = parry impreciso
	if player == null or not is_instance_valid(player):
		return 0
	var cc: Variant = player.get("class_controller")
	if cc == null or not is_instance_valid(cc):
		return 0
	if not (bool(cc.get("parrying")) and bool(cc.call("parry_covers", from))):
		return 0
	if strict > 0.0 and float(cc.call("parry_age")) > strict:
		return -1
	cc.call("on_parried", from)
	return 1


## Proyectil de duelo: viaja hacia el jugador; con parry vuelve al boss (`target`).
## Al resolverse llama boss.<on_result>(ok: bool, shot) y, al llegar de vuelta, boss.<on_back>(shot).
## `arrive_in` > 0: ajusta la velocidad para llegar al jugador justo en ese tiempo (ritmo).
class Shot extends BossFx.Hazard:
	var vel := Vector2.DOWN * 300.0
	var col := Color(0.5, 0.8, 1.0)
	var label := ""
	var strict := 0.0
	var damage := 2
	var target := Vector2.ZERO        # punto del boss (local al boss) adonde vuelve
	var on_result := "final_result"
	var on_back := "final_back"
	var size := 16.0
	var t := 0.0
	var back := false
	var _done := false

	func _init() -> void:
		super._init()
		add_to_group("final_shot")

	func _ready() -> void:
		z_index = 6

	func aim_at(to: Vector2, speed: float, arrive_in: float = 0.0) -> void:
		var d := to - global_position
		if arrive_in > 0.0:
			speed = maxf(120.0, (d.length() - 26.0) / arrive_in)
		vel = d.normalized() * speed

	func relaunch(to: Vector2, speed: float, arrive_in: float = 0.0) -> void:
		back = false
		_done = false
		t = 0.0
		aim_at(to, speed, arrive_in)

	func _process(delta: float) -> void:
		t += delta
		global_position += vel * delta
		if back:
			if is_instance_valid(boss) and global_position.distance_to(boss.global_position + target) < 40.0:
				if boss.has_method(on_back):
					boss.call(on_back, self)
				else:
					queue_free()
				return
		elif not _done and _touching():
			_done = true
			var r := _parry()
			if r == 1:
				back = true
				var to := boss.global_position + target if is_instance_valid(boss) else global_position
				vel = (to - global_position).normalized() * maxf(560.0, vel.length() * 1.3)
				GameFeel.parry_burst(get_parent(), global_position, 22.0)
			else:
				hurt(damage, true)
				if r == -1:
					var n := BossFx.DmgNumber.new()
					n.text = "¡IMPRECISO!"
					n.color = Color(1, 0.5, 0.3)
					get_parent().add_child(n)
					n.global_position = global_position + Vector2(0, -30)
			_victim = null
			if is_instance_valid(boss) and boss.has_method(on_result):
				boss.call(on_result, r == 1, self)
			if r != 1:
				queue_free()
				return
		if t > 4.0:
			if not _done and is_instance_valid(boss) and boss.has_method(on_result):
				_done = true
				boss.call(on_result, false, self)
			queue_free()
			return
		queue_redraw()

	## Multijugador: la bola choca con el primer jugador que toque (queda como _victim para el parry y el daño).
	func _touching() -> bool:
		for v in victims():
			_victim = v
			if player_body().distance_to(global_position) < 26.0:
				return true
		_victim = null
		return false

	## 1 = parry bueno, 0 = sin parry, -1 = parry impreciso (fuera de `strict`).
	func _parry() -> int:
		var cc: Variant = _who().get("class_controller")
		if cc == null or not is_instance_valid(cc):
			return 0
		if not (bool(cc.get("parrying")) and bool(cc.call("parry_covers", global_position))):
			return 0
		if strict > 0.0 and float(cc.call("parry_age")) > strict:
			return -1
		cc.call("on_parried", global_position)
		return 1

	func _draw() -> void:
		var c := Color(0.5, 1.0, 0.6) if back else col
		var glow := 0.5 + 0.5 * absf(sin(t * 18.0))
		var dir := vel.normalized()
		for i in 4:
			draw_circle(-dir * (8.0 + i * 9.0), size * (0.8 - i * 0.16), Color(c, 0.16))
		draw_circle(Vector2.ZERO, size + 6.0, Color(c, 0.18 * glow))
		draw_circle(Vector2.ZERO, size, c.darkened(0.25))
		draw_circle(Vector2.ZERO, size * 0.65, c.lightened(0.35))
		draw_circle(Vector2(-size * 0.25, -size * 0.25), size * 0.25, Color(1, 1, 1, 0.9))
		if strict > 0.0 and not back:
			draw_arc(Vector2.ZERO, size + 9.0, 0, TAU, 24, Color(1, 1, 1, 0.5 + 0.5 * glow), 2.0)
		if label != "":
			var f := ThemeDB.fallback_font
			draw_string_outline(f, Vector2(-40, size + 14), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, 3, Color(0, 0, 0, 0.8))
			draw_string(f, Vector2(-40, size + 14), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, c.lightened(0.3))


## Cartel grande en el centro de la pantalla.
class Title extends CanvasLayer:
	var text := ""
	var sub := ""
	var col := Color.WHITE
	var life := 1.6
	var t := 0.0
	var _c: Control

	func _ready() -> void:
		layer = 7
		_c = Control.new()
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.size = Vector2(1280, 720)
		_c.draw.connect(_paint)
		add_child(_c)

	func _process(delta: float) -> void:
		t += delta
		if t > life + 0.3:
			queue_free()
		_c.queue_redraw()

	func _paint() -> void:
		var a := 1.0 if t < life else clampf(1.0 - (t - life) / 0.3, 0.0, 1.0)
		var s := lerpf(2.0, 1.0, clampf(t / 0.15, 0.0, 1.0))
		var f := ThemeDB.fallback_font
		_c.draw_set_transform(Vector2(640, 230), -0.05, Vector2(s, s))
		_c.draw_rect(Rect2(-260, -40, 520, 66), Color(0.05, 0.05, 0.08, 0.85 * a))
		_c.draw_rect(Rect2(-260, -40, 520, 66), Color(col, a), false, 4.0)
		_c.draw_string(f, Vector2(-260, 8), text, HORIZONTAL_ALIGNMENT_CENTER, 520, 38, Color(col, a))
		if sub != "":
			_c.draw_string_outline(f, Vector2(-300, 52), sub, HORIZONTAL_ALIGNMENT_CENTER, 600, 18, 5, Color(0, 0, 0, a))
			_c.draw_string(f, Vector2(-300, 52), sub, HORIZONTAL_ALIGNMENT_CENTER, 600, 18, Color(1, 1, 1, a))


# --- Remates (muerte según cómo lo venciste) --------------------------------------------

static func wait(boss: Node, t: float) -> void:
	await boss.get_tree().create_timer(t).timeout


## Sello/cartel gigante que cae del cielo y se estampa sobre el boss.
class StampSlam extends Node2D:
	var text := "CULPABLE"
	var col := Color(0.9, 0.15, 0.15)
	var t := 0.0
	var life := 2.0
	var fall := 0.35
	var w := 300.0
	var _hit := false

	func _ready() -> void:
		z_index = 30

	func _process(delta: float) -> void:
		t += delta
		if not _hit and t >= fall:
			_hit = true
			GameFeel.dust(get_parent(), global_position + Vector2(0, 40), 14, Vector2.ZERO, 7.0, Vector2(w * 0.4, 10))
		if t > life:
			modulate.a = clampf(1.0 - (t - life) / 0.4, 0.0, 1.0)
		if t > life + 0.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / fall, 0.0, 1.0)
		var y := lerpf(-520.0, -130.0, k * k)
		var s := lerpf(1.6, 1.0, k) * (1.0 + (0.06 * sin((t - fall) * 40.0) * maxf(0.0, 0.3 - (t - fall)) if _hit else 0.0))
		var oy := y
		var sy := get_global_transform_with_canvas().origin.y
		if sy + oy < 140.0 and _hit:
			oy = 140.0 - sy
		draw_set_transform(Vector2(0, oy), -0.12, Vector2(s, s))
		var f := ThemeDB.fallback_font
		var r := Rect2(-w * 0.5, -40, w, 80)
		draw_rect(r.grow(6), Color(col, 0.25))
		draw_rect(r, Color(1, 1, 1, 0.08))
		draw_rect(r, col, false, 7.0)
		draw_rect(r.grow(-8), col, false, 2.0)
		draw_string(f, Vector2(-w * 0.5, 16), text, HORIZONTAL_ALIGNMENT_CENTER, w, 44, col)


## Gráfico de la bolsa que se desploma cruzando toda la pantalla.
class CrashChart extends CanvasLayer:
	var t := 0.0
	var _c: Control
	var pts := PackedVector2Array()

	func _ready() -> void:
		layer = 8
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_paint)
		add_child(_c)
		var y := 180.0
		for i in 40:
			y += randf_range(-24, 10) if i < 26 else randf_range(20, 46)
			pts.append(Vector2(40 + i * 31.0, y))

	func _process(delta: float) -> void:
		t += delta
		if t > 2.6:
			queue_free()
		_c.queue_redraw()

	func _paint() -> void:
		var n := clampi(int(t / 1.2 * pts.size()), 2, pts.size())
		var a := clampf(2.6 - t, 0.0, 1.0)
		var sub := pts.slice(0, n)
		_c.draw_polyline(sub, Color(0, 0, 0, 0.6 * a), 12.0)
		_c.draw_polyline(sub, Color(1, 0.2, 0.2, a), 6.0)
		var tip: Vector2 = sub[sub.size() - 1]
		_c.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 26), tip + Vector2(-16, -4), tip + Vector2(16, -4)]), Color(1, 0.2, 0.2, a))


## Apagado de televisor viejo: la imagen se aplasta a una línea y luego a un punto.
class TvOff extends CanvasLayer:
	var t := 0.0
	var _c: Control

	func _ready() -> void:
		layer = 9
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_paint)
		add_child(_c)

	func _process(delta: float) -> void:
		t += delta
		if t > 2.2:
			queue_free()
		_c.queue_redraw()

	func _paint() -> void:
		var h := 360.0 * (1.0 - clampf(t / 0.35, 0.0, 1.0))
		var w := 640.0 * (1.0 - clampf((t - 0.35) / 0.25, 0.0, 1.0))
		var a := 1.0 if t < 1.6 else clampf(1.0 - (t - 1.6) / 0.6, 0.0, 1.0)
		# negro arriba y abajo (y a los lados al final)
		_c.draw_rect(Rect2(0, 0, 1280, 360 - h), Color(0, 0, 0, a))
		_c.draw_rect(Rect2(0, 360 + h, 1280, 360 - h), Color(0, 0, 0, a))
		if t > 0.35:
			_c.draw_rect(Rect2(0, 360 - h - 2, 640 - w, 2 * h + 4), Color(0, 0, 0, a))
			_c.draw_rect(Rect2(640 + w, 360 - h - 2, 640 - w, 2 * h + 4), Color(0, 0, 0, a))
		var lw := maxf(w, 3.0)
		if t < 1.2:
			_c.draw_rect(Rect2(640 - lw, 358, 2 * lw, 4), Color(1, 1, 1, 0.9 * a))
			_c.draw_circle(Vector2(640, 360), 6.0 * (1.0 - clampf((t - 0.6) / 0.6, 0.0, 1.0)), Color(1, 1, 1, a))


## Volcado de memoria: columnas de hexadecimal que caen desde un punto.
class HexDump extends Node2D:
	var t := 0.0
	var lines: Array[String] = []

	func _ready() -> void:
		z_index = 25
		for i in 14:
			lines.append("%08X  DE AD BE EF %02X %02X" % [randi() % 0xFFFFFF, randi() % 255, randi() % 255])

	func _process(delta: float) -> void:
		t += delta
		if t > 2.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var a := clampf(2.4 - t, 0.0, 1.0)
		var n := mini(lines.size(), int(t * 14.0))
		for i in n:
			var y := -160.0 + i * 16.0 + t * 30.0
			draw_string(f, Vector2(-130, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.3, 0.25, a * (0.4 + 0.6 * float(i) / lines.size())))
