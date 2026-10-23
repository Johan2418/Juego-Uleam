extends RefCounted
## Peligros y efectos del boss 0xDEADBEEF (versión de prueba, dibujados por código).
## Sin class_name: cargar con preload("res://scripts/combat/boss_fx.gd").
## Cuando lleguen las hojas de grokbot (boss_props, boss_animals...), cada _draw se cambia por su sprite.

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")


## Base: algo que puede dañar al jugador. El daño pasa por boss.hurt_player().
class Hazard extends Node2D:
	var boss: Node2D
	## Objetivo del boss (a quién apunta / persigue el peligro).
	var player: Node2D
	## Multijugador: jugador que se está revisando en un `for v in victims()`. Mientras está
	## puesto, player_ok/feet/body y hurt() se refieren a él (el daño es para todos).
	var _victim: Node2D = null

	func _init() -> void:
		add_to_group("boss_hazard")

	## Todos los jugadores que pueden recibir daño (1 o 2).
	func victims() -> Array:
		return CoopBoss.targets(get_tree()) if is_inside_tree() else []

	func _who() -> Node2D:
		return _victim if _victim != null else player

	func hurt(amount: int, unblockable: bool = true) -> void:
		if not is_instance_valid(boss) or not boss.has_method("hurt_player"):
			return
		if _victim != null and is_instance_valid(_victim):
			CoopBoss.hurt_to(boss, _victim, amount, global_position, unblockable)
		else:
			boss.call("hurt_player", amount, global_position, unblockable)

	func player_ok() -> bool:
		var p := _who()
		return p != null and is_instance_valid(p)

	func player_feet() -> Vector2:
		return _who().global_position + Vector2(0.0, 12.0)

	func player_body() -> Vector2:
		return _who().global_position + Vector2(0.0, -32.0)

	## Proyectil: true si toca el cuerpo de algún jugador (queda como _victim para el parry y el daño).
	func touch_any(radius: float) -> bool:
		for v in victims():
			_victim = v
			if player_body().distance_to(global_position) < radius:
				return true
		_victim = null
		return false

	## Un golpe por jugador (antes: un golpe por peligro).
	func first_hit(key: String = "hit") -> bool:
		return CoopBoss.once(self, key, _who())

	## Enfriamiento por jugador (antes: uno solo para el peligro).
	func cd_ok(key: String, secs: float) -> bool:
		return CoopBoss.ready_for(self, key, _who(), secs)

	func ellipse(center: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)

	func ellipse_line(center: Vector2, r: Vector2, col: Color, width: float = 2.0) -> void:
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_polyline(pts, col, width)


## Lluvia de cajas y frutas (Agronegocios): sombra que crece y luego cae el objeto.
class FallingCrate extends Hazard:
	const RADIUS := 36.0
	var delay := 0.0
	var warn := 0.9
	var kind := 0   # 0 caja, 1 tomate, 2 manzana
	var t := 0.0
	var _landed := false

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		t += delta
		var lt := t - delay
		if lt < 0.0:
			return
		if not _landed and lt >= warn:
			_landed = true
			for v in victims():
				_victim = v
				if player_feet().distance_to(global_position) <= RADIUS:
					hurt(1)
			_victim = null
			GameFeel.dust(get_parent(), global_position, 6, Vector2.ZERO, 5.0, Vector2(18.0, 5.0))
		if lt >= warn + 0.55:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var lt := t - delay
		if lt < 0.0:
			return
		var k := clampf(lt / warn, 0.0, 1.0)
		ellipse(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.42) * (0.35 + 0.65 * k), Color(0, 0, 0, 0.18 + 0.25 * k))
		ellipse_line(Vector2.ZERO, Vector2(RADIUS, RADIUS * 0.42), Color(1.0, 0.25, 0.2, 0.25 + 0.5 * k), 2.0)
		# el objeto cae en los últimos 0.22 s del aviso
		var fall := clampf((lt - (warn - 0.22)) / 0.22, 0.0, 1.0)
		if lt < warn - 0.22:
			return
		var y := lerpf(-340.0, -10.0, fall)
		var a := 1.0 if lt < warn + 0.3 else clampf(1.0 - (lt - warn - 0.3) / 0.25, 0.0, 1.0)
		var tx := Spr.tex("boss_props_%d" % kind)
		if tx:
			Spr.draw_feet(self, tx, Vector2(0, y + 10.0), false, 0.8, Color(1, 1, 1, a))
			return
		match kind:
			0:
				draw_rect(Rect2(-16, y - 14, 32, 24), Color(0.72, 0.52, 0.3, a))
				draw_rect(Rect2(-16, y - 14, 32, 24), Color(0, 0, 0, a), false, 2.0)
				draw_line(Vector2(-16, y - 6), Vector2(16, y - 6), Color(0.45, 0.3, 0.15, a), 2.0)
				draw_circle(Vector2(-7, y - 16), 5, Color(0.3, 0.75, 0.3, a))
				draw_circle(Vector2(6, y - 17), 5, Color(0.95, 0.35, 0.2, a))
			1:
				draw_circle(Vector2(0, y - 4), 12, Color(0.9, 0.18, 0.15, a))
				draw_circle(Vector2(-4, y - 8), 3, Color(1, 0.6, 0.55, a))
				draw_line(Vector2(0, y - 16), Vector2(0, y - 12), Color(0.2, 0.6, 0.2, a), 3.0)
			_:
				draw_circle(Vector2(0, y - 4), 11, Color(0.5, 0.85, 0.25, a))
				draw_line(Vector2(0, y - 15), Vector2(3, y - 19), Color(0.35, 0.22, 0.1, a), 2.0)


## Gas contaminante (Ingeniería ambiental): cono que sigue despacio al jugador.
class GasCone extends Hazard:
	var dir := Vector2.DOWN
	var length := 270.0
	var half_angle := 0.42
	var life := 1.4
	var track_speed := 0.55
	var t := 0.0
	var _tick := 0.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		t += delta
		_tick -= delta
		if player_ok():
			var want := (player_body() - global_position).angle()
			var cur := dir.angle()
			var diff := wrapf(want - cur, -PI, PI)
			dir = Vector2.from_angle(cur + clampf(diff, -track_speed * delta, track_speed * delta))
			for v in victims():
				_victim = v
				if _inside() and cd_ok("gas", 0.45):
					hurt(1)
			_victim = null
		if t >= life:
			queue_free()
		queue_redraw()

	func _inside() -> bool:
		var to := player_body() - global_position
		var reach := length * minf(1.0, t / 0.3)
		return to.length() <= reach and absf(dir.angle_to(to)) <= half_angle

	func _draw() -> void:
		var grow := minf(1.0, t / 0.3)
		var fade := clampf((life - t) / 0.3, 0.0, 1.0)
		for i in 16:
			var d := length * grow * (i + 1) / 16.0
			var r := d * tan(half_angle) * 0.95 + 6.0
			var wob := Vector2(sin(t * 9.0 + i) * 4.0, cos(t * 7.0 + i * 1.3) * 3.0)
			draw_circle(dir * d + wob, r, Color(0.45, 0.85, 0.25, 0.16 * fade))
			draw_circle(dir * d * 0.97 - wob, r * 0.55, Color(0.7, 1.0, 0.35, 0.12 * fade))


## Charco tóxico que deja el gas.
class Puddle extends Hazard:
	const RADIUS := 32.0
	var delay := 0.3
	var life := 4.5
	var t := 0.0
	var _tick := 0.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		_tick -= delta
		var lt := t - delay
		if lt >= 0.0:
			for v in victims():
				_victim = v
				if player_feet().distance_to(global_position) <= RADIUS and cd_ok("puddle", 0.7):
					hurt(1)
			_victim = null
		if lt >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var lt := t - delay
		if lt < 0.0:
			return
		var grow := minf(1.0, lt / 0.25)
		var a := clampf((life - lt) / 0.6, 0.0, 1.0)
		var r := Vector2(RADIUS, RADIUS * 0.45) * grow
		var tx := Spr.tex("boss_props_4")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO, false, RADIUS * 2.0 * grow / tx.get_width(), Color(1, 1, 1, a))
			return
		ellipse(Vector2.ZERO, r, Color(0.3, 0.7, 0.15, 0.75 * a))
		ellipse(Vector2(-6, -2), r * 0.5, Color(0.55, 0.95, 0.3, 0.6 * a))
		ellipse_line(Vector2.ZERO, r, Color(0.1, 0.3, 0.05, a), 2.0)
		var b := fmod(t * 1.7, 1.0)
		draw_circle(Vector2(8, -2 - b * 6), 3.0 * (1.0 - b), Color(0.7, 1.0, 0.4, a))


## Raíz que sale del suelo (Biología): grieta de aviso y luego la púa.
class RootSpike extends Hazard:
	const RADIUS := 24.0
	var delay := 0.0
	var warn := 0.45
	var t := 0.0
	var _hit := false

	func _process(delta: float) -> void:
		t += delta
		var lt := t - delay
		if lt >= warn and not _hit:
			_hit = true
			for v in victims():
				_victim = v
				if player_feet().distance_to(global_position) <= RADIUS:
					hurt(1)
			_victim = null
			GameFeel.dust(get_parent(), global_position, 3, Vector2.ZERO, 3.5, Vector2(10.0, 3.0))
		if lt >= warn + 0.75:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var lt := t - delay
		if lt < 0.0:
			return
		var k := clampf(lt / warn, 0.0, 1.0)
		var t5 := Spr.tex("boss_props_5")
		if t5:
			if lt < warn:
				Spr.draw_feet(self, t5, Vector2(0, 4), false, 0.5 + 0.5 * k, Color(1, 1, 1, 0.6 + 0.4 * k))
			else:
				var age := lt - warn
				var n := "boss_props_6" if age < 0.06 or age > 0.6 else "boss_props_7"
				var fade := clampf(1.0 - (age - 0.55) / 0.2, 0.0, 1.0)
				Spr.draw_feet(self, Spr.tex(n), Vector2(0, 4), false, 1.0, Color(1, 1, 1, fade))
			return
		draw_line(Vector2(-14 * k, -2), Vector2(14 * k, 2), Color(0.12, 0.08, 0.04, 0.8), 3.0)
		draw_line(Vector2(-4, -5 * k), Vector2(6, 5 * k), Color(0.12, 0.08, 0.04, 0.8), 2.0)
		if lt < warn:
			return
		var up := clampf((lt - warn) / 0.08, 0.0, 1.0)
		var down := clampf((lt - warn - 0.5) / 0.25, 0.0, 1.0)
		var h := 46.0 * up * (1.0 - down)
		var pts := PackedVector2Array([Vector2(-10, 2), Vector2(-3, -h * 0.6), Vector2(1, -h), Vector2(4, -h * 0.55), Vector2(11, 2)])
		draw_colored_polygon(pts, Color(0.2, 0.42, 0.15))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4]]), Color(0.05, 0.12, 0.04), 2.0)
		draw_line(Vector2(-2, -2), Vector2(1, -h * 0.8), Color(0.45, 0.75, 0.3), 2.0)


## Cable que lanza la pinza (TI). Avisa al boss con on_done(atrapado).
class CableShot extends Hazard:
	var dir := Vector2.DOWN
	var speed := 680.0
	var max_len := 380.0
	var on_done: Callable
	var tip := Vector2.ZERO
	var _back := false
	var _done := false

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		if _done:
			return
		if not _back:
			tip += dir * speed * delta
			if player_ok() and not bool(player.get("invulnerable")) \
					and player_body().distance_to(global_position + tip) < 34.0:
				_finish(true)
				return
			if tip.length() >= max_len:
				_back = true
		else:
			tip = tip.move_toward(Vector2.ZERO, speed * 1.5 * delta)
			if tip.length() < 4.0:
				_finish(false)
				return
		queue_redraw()

	func _finish(hit: bool) -> void:
		_done = true
		if on_done.is_valid():
			on_done.call(hit)
		queue_free()

	func _draw() -> void:
		draw_line(Vector2.ZERO, tip, Color(0.05, 0.05, 0.07), 6.0)
		draw_line(Vector2.ZERO, tip, Color(0.25, 0.25, 0.3), 2.0)
		var side := dir.orthogonal() * 6.0
		var pts := PackedVector2Array([tip - side, tip + side, tip + side + dir * 12.0, tip - side + dir * 12.0])
		draw_colored_polygon(pts, Color(0.85, 0.85, 0.9))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0), 2.0)


## "!" en el borde del carril antes de la estampida.
class LaneWarning extends Node2D:
	var life := 0.9
	var t := 0.0

	func _init() -> void:
		add_to_group("boss_hazard")

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		t += delta
		if t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if fmod(t * 6.0, 1.0) > 0.7:
			return
		draw_circle(Vector2.ZERO, 16, Color(1.0, 0.85, 0.2))
		draw_arc(Vector2.ZERO, 16, 0, TAU, 24, Color(0, 0, 0), 2.0)
		draw_rect(Rect2(-2.5, -10, 5, 12), Color(0, 0, 0))
		draw_rect(Rect2(-2.5, 5, 5, 5), Color(0, 0, 0))


## Vaca o cerdo de la estampida (Agropecuarias).
class Animal extends Hazard:
	var kind := 0   # 0 vaca, 1 cerdo
	var delay := 0.9
	var speed := 470.0
	var min_x := -700.0
	var max_x := 700.0
	var t := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		t += delta
		if t < delay:
			return
		position.x += speed * delta
		for v in victims():
			_victim = v
			var d := player_feet() - global_position
			if absf(d.x) < 34.0 and absf(d.y) < 24.0 and first_hit():
				_hit = true
				hurt(1)
		_victim = null
		if position.x < min_x or position.x > max_x:
			queue_free()
		if fmod(t, 0.12) < delta:
			GameFeel.dust(get_parent(), global_position, 1, Vector2(-signf(speed) * 40.0, 0.0), 3.0)
		queue_redraw()

	func _draw() -> void:
		if t < delay:
			return
		var tx := Spr.tex("boss_animals_%d" % (kind * 4 + int(t * 12.0) % 4))
		if tx:
			Spr.draw_feet(self, tx, Vector2(0, 4), speed < 0.0)
			return
		var f := signf(speed)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, 1.0))
		var leg := sin(t * 28.0) * 5.0
		var body := Color(0.95, 0.95, 0.92) if kind == 0 else Color(0.98, 0.65, 0.7)
		var w := 52.0 if kind == 0 else 42.0
		var h := 28.0 if kind == 0 else 22.0
		for lx in [-w * 0.35, w * 0.3]:
			draw_line(Vector2(lx, -8), Vector2(lx + leg, 0), Color(0.15, 0.12, 0.1), 5.0)
			draw_line(Vector2(lx + 6, -8), Vector2(lx + 6 - leg, 0), Color(0.15, 0.12, 0.1), 5.0)
		draw_rect(Rect2(-w * 0.5, -8 - h, w, h), body)
		draw_rect(Rect2(-w * 0.5, -8 - h, w, h), Color(0, 0, 0), false, 2.0)
		if kind == 0:
			draw_circle(Vector2(-8, -26), 6, Color(0.1, 0.1, 0.1))
			draw_circle(Vector2(10, -20), 5, Color(0.1, 0.1, 0.1))
		var head := Vector2(w * 0.5 + 6, -8 - h + 4)
		draw_rect(Rect2(head.x - 8, head.y - 6, 18, 18), body)
		draw_rect(Rect2(head.x - 8, head.y - 6, 18, 18), Color(0, 0, 0), false, 2.0)
		draw_circle(head + Vector2(4, 0), 2, Color(0, 0, 0))
		draw_rect(Rect2(head.x - 6, head.y - 10, 5, 5), Color(1.0, 0.85, 0.1))  # arete
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Láser de escaneo (Software): línea fina de aviso y luego barrido.
class LaserBeam extends Hazard:
	var telegraph := 0.85
	var duration := 1.5
	var sweep := 1.7
	var dir_sign := 1.0
	var length := 900.0
	var angle := PI * 0.5
	var t := 0.0
	var _start_angle := 0.0
	var _started := false
	var _hit_cd := 0.0

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		t += delta
		_hit_cd -= delta
		if t < telegraph:
			if t < telegraph * 0.65 and player_ok():
				angle = (player_body() - global_position).angle()
		else:
			if not _started:
				_started = true
				_start_angle = angle - sweep * 0.5 * dir_sign
			var k := (t - telegraph) / duration
			angle = _start_angle + sweep * k * dir_sign
			for v in victims():
				_victim = v
				var a := global_position
				var b := a + Vector2.from_angle(angle) * length
				var p := player_body()
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < 18.0 and cd_ok("laser", 0.6):
					hurt(2)
			_victim = null
			if k >= 1.0:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var end := Vector2.from_angle(angle) * length
		if t < telegraph:
			var a := 0.35 + 0.4 * absf(sin(t * 14.0))
			draw_line(Vector2.ZERO, end, Color(0.85, 0.4, 1.0, a), 2.0)
			return
		draw_line(Vector2.ZERO, end, Color(0.6, 0.2, 1.0, 0.45), 26.0)
		draw_line(Vector2.ZERO, end, Color(0.85, 0.5, 1.0, 0.9), 12.0)
		draw_line(Vector2.ZERO, end, Color(1, 0.95, 1, 1), 4.0)
		draw_circle(Vector2.ZERO, 14, Color(0.9, 0.6, 1.0))


## Pasto y flores que crecen cuando el boss muere (la arena queda limpia).
class Bloom extends Node2D:
	var delay := 0.0
	var t := 0.0
	var size := 26.0
	var flower := true

	func _ready() -> void:
		z_index = -2

	func _process(delta: float) -> void:
		t += delta
		if t > delay + 1.0:
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		var k := clampf((t - delay) / 0.5, 0.0, 1.0)
		if k <= 0.0:
			return
		var tx := Spr.tex("boss_debris_6" if flower else "boss_debris_7")
		if tx:
			Spr.draw_feet(self, tx, Vector2.ZERO, false, k)
			return
		var r := size * k
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
		draw_colored_polygon(pts, Color(0.35, 0.68, 0.3, 0.85))
		for i in 4:
			var x := (i - 1.5) * r * 0.45
			draw_line(Vector2(x, 0), Vector2(x + 2, -8 * k), Color(0.25, 0.55, 0.2), 2.0)
		if flower and k >= 1.0:
			draw_circle(Vector2(4, -10), 4, Color(1, 1, 0.95))
			draw_circle(Vector2(4, -10), 2, Color(1, 0.85, 0.2))


## Pedazos que salen volando cuando muere el boss.
class Debris extends Node2D:
	var kind := 0
	var prefix := "boss_debris_"   # el boss 2 usa "boss_bsod_debris_"
	var vel := Vector2.ZERO
	var spin := 0.0
	var t := 0.0
	var _floor_y := 0.0

	func _ready() -> void:
		z_index = 3
		spin = randf_range(-9.0, 9.0)
		_floor_y = global_position.y + randf_range(80.0, 200.0)

	func _process(delta: float) -> void:
		t += delta
		if global_position.y < _floor_y or vel.y < 0.0:
			vel.y += 900.0 * delta
			global_position += vel * delta
			rotation += spin * delta
		if t > 2.2:
			modulate.a = clampf(1.0 - (t - 2.2) / 0.6, 0.0, 1.0)
		if t > 2.8:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex(prefix + str(kind))
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO)
		else:
			draw_rect(Rect2(-5, -5, 10, 10), Color(0.5, 0.5, 0.55))


# --- Robustez: avisos en el piso, onda de pisotón, números de daño, chispas --------

## Zona de aviso en el piso: cono (dir + reach + half_angle) o círculo (half_angle = 0).
## Se va llenando de rojo durante `life` y desaparece.
class TeleZone extends Node2D:
	var dir := Vector2.DOWN
	var reach := 190.0
	var half_angle := 1.1
	var life := 0.5
	var t := 0.0

	func _init() -> void:
		add_to_group("boss_hazard")

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if t >= life + 0.08:
			queue_free()
		queue_redraw()

	func _shape(r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		# círculo si no es cono (o si el cono es casi una vuelta entera: se cruzaría y no se puede dibujar)
		if half_angle <= 0.0 or half_angle >= PI * 0.95 or not dir.is_finite():
			for i in 32:
				var a := TAU * i / 32.0
				pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
			return pts
		pts.append(Vector2.ZERO)
		var a0 := dir.angle() - half_angle
		for i in 17:
			var v := Vector2.from_angle(a0 + half_angle * 2.0 * i / 16.0) * r
			pts.append(Vector2(v.x, v.y * 0.6))
		return pts

	func _draw() -> void:
		var k := clampf(t / life, 0.0, 1.0)
		var blink := 0.6 + 0.4 * absf(sin(t * 18.0))
		if reach < 1.0 or not is_finite(reach):
			return
		draw_colored_polygon(_shape(reach), Color(1.0, 0.15, 0.1, 0.12 * blink))
		if reach * k > 1.0:   # con radio 0 el polígono no se puede triangular
			draw_colored_polygon(_shape(reach * k), Color(1.0, 0.2, 0.1, 0.28))
		var edge := _shape(reach)
		edge.append(edge[0])
		draw_polyline(edge, Color(1.0, 0.35, 0.25, 0.8 * blink), 2.0)


## Onda de choque del pisotón: anillo que crece. Golpea si los pies del jugador están en el borde.
class ShockRing extends Hazard:
	var max_r := 260.0
	var speed := 420.0
	var r := 20.0
	var _hit := false

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		r += speed * delta
		for v in victims():
			_victim = v
			var d := player_feet() - global_position
			var e := Vector2(d.x, d.y * 2.0).length()   # anillo aplastado (perspectiva)
			if absf(e - r) < 22.0 and first_hit():
				_hit = true
				hurt(2)
		_victim = null
		if r >= max_r:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - r / max_r, 0.0, 1.0)
		ellipse_line(Vector2.ZERO, Vector2(r, r * 0.5), Color(1.0, 0.85, 0.5, a), 7.0)
		ellipse_line(Vector2.ZERO, Vector2(r - 8.0, (r - 8.0) * 0.5), Color(1.0, 1.0, 1.0, a * 0.7), 3.0)


## Número de daño que sube y se desvanece.
class DmgNumber extends Node2D:
	var text := "1"
	var color := Color.WHITE
	var big := false
	var t := 0.0
	var _vx := 0.0

	func _ready() -> void:
		z_index = 30
		_vx = randf_range(-30.0, 30.0)

	func _process(delta: float) -> void:
		t += delta
		position += Vector2(_vx, -70.0 * (1.0 - t)) * delta
		if t >= 0.9:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var fs := 26 if big else 17
		var s := 1.0 + 0.5 * maxf(0.0, 0.12 - t) / 0.12
		var a := clampf(1.6 - t * 1.8, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		var f := ThemeDB.fallback_font
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, a))
		draw_string(f, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color.r, color.g, color.b, a))


## Chispas de metal: el golpe pega en el blindaje.
class Sparks extends Node2D:
	var dir := Vector2.UP
	var t := 0.0
	var _rays: Array = []

	func _ready() -> void:
		z_index = 22
		for i in 7:
			_rays.append([dir.rotated(randf_range(-1.1, 1.1)), randf_range(160.0, 320.0)])

	func _process(delta: float) -> void:
		t += delta
		if t >= 0.22:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - t / 0.22
		for ray in _rays:
			var d: Vector2 = ray[0]
			var sp: float = ray[1]
			var p := d * sp * t
			draw_line(p, p + d * 9.0, Color(1.0, 0.9, 0.55, a), 2.0)


## Brazo arrancado: cae girando, rebota en el piso y se queda un rato antes de desvanecerse.
class FallingPart extends Node2D:
	var tex_name := ""
	var pivot := Vector2.ZERO
	var vel := Vector2.ZERO
	var floor_y := 0.0
	var t := 0.0
	var _spin := 0.0
	var _landed := false

	func _ready() -> void:
		z_index = 2
		_spin = 6.0 if vel.x > 0.0 else -6.0

	func _process(delta: float) -> void:
		t += delta
		if not _landed:
			vel.y += 900.0 * delta
			global_position += vel * delta
			rotation += _spin * delta
			if global_position.y >= floor_y and vel.y > 0.0:
				if absf(vel.y) > 200.0:
					vel = Vector2(vel.x * 0.4, -vel.y * 0.3)
					_spin *= 0.4
					GameFeel.dust(get_parent(), global_position, 5, Vector2.ZERO, 5.0, Vector2(16, 5))
				else:
					_landed = true
					rotation = PI * 0.5 * signf(_spin)
		if t > 6.0:
			modulate.a = clampf(1.0 - (t - 6.0) / 1.0, 0.0, 1.0)
		if t > 7.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex(tex_name)
		if tx:
			draw_texture(tx, -pivot, Color(0.75, 0.7, 0.7))
		else:
			draw_rect(Rect2(-10, 0, 20, 90), Color(0.5, 0.5, 0.55))
