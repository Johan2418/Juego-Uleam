extends RefCounted
## Peligros y efectos del boss 9 SUDO, el Líder del Club IA.
## Usan los sprites de assets/sprites/bosses/sudo/ (tools/slice_sudo_sheets.py) y, si faltan, el dibujo por código.
## Fase 1 Supabase + Cursor (rayos verdes, cursores), fase 2 Grokbot + Clerk (bots, login, 2FA),
## fase 3 Terra · Luna · Sol, y las piezas de la cinemática ASTRA (espiral de estrellas, QTE).
## Las marcas reales no se dibujan: solo sus colores y formas genéricas.
## Sin class_name: cargar con preload("res://scripts/combat/boss_sudo_fx.gd").

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Final := preload("res://scripts/combat/boss_final.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")

const GREEN := Color(0.24, 0.81, 0.56)
const GREEN_HI := Color(0.7, 1.0, 0.85)
const CURSOR := Color(0.35, 0.62, 1.0)
const CLERK := Color(0.52, 0.4, 1.0)
const GROK := Color(0.88, 0.88, 0.93)
const SUN := Color(1.0, 0.72, 0.2)
const MOON := Color(0.82, 0.86, 0.95)
const EARTH := Color(0.3, 0.6, 1.0)


## Ayudas de dibujo comunes (en una clase interna: las clases internas no ven las funciones de afuera).
class U extends RefCounted:
	## Dibuja el sprite "boss_sudo_<name>" centrado en `at`. Devuelve false si no existe (y no dibuja nada).
	static func spr(ci: CanvasItem, name: String, at: Vector2, scale: float = 1.0, rot: float = 0.0, col: Color = Color.WHITE, flip: bool = false) -> bool:
		var tex: Texture2D = Spr.tex("boss_sudo_" + name)
		if tex == null:
			return false
		var sz := tex.get_size()
		ci.draw_set_transform(at, rot, Vector2(-scale if flip else scale, scale))
		ci.draw_texture(tex, -sz * 0.5, col)
		ci.draw_set_transform(Vector2.ZERO)
		return true

	## Igual, pero con la base (pies) en `at`.
	static func spr_feet(ci: CanvasItem, name: String, at: Vector2, scale: float = 1.0, col: Color = Color.WHITE, flip: bool = false, sy: float = 1.0) -> bool:
		var tex: Texture2D = Spr.tex("boss_sudo_" + name)
		if tex == null:
			return false
		var sz := tex.get_size()
		ci.draw_set_transform(at, 0.0, Vector2(-scale if flip else scale, scale * sy))
		ci.draw_texture(tex, Vector2(-sz.x * 0.5, -sz.y), col)
		ci.draw_set_transform(Vector2.ZERO)
		return true

	## Le pone una zona golpeable (capa 2) a un nodo: así los ataques del jugador lo encuentran.
	static func add_hurtbox(n: Node2D, size: Vector2, at: Vector2) -> void:
		var hurt := Area2D.new()
		hurt.name = "Hurtbox"
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = size
		cs.shape = r
		cs.position = at
		hurt.add_child(cs)
		n.add_child(hurt)


	static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, width: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT, outline: int = 4) -> void:
		var f := ThemeDB.fallback_font
		if outline > 0:
			ci.draw_string_outline(f, pos, s, align, width, size, outline, Color(0, 0, 0, col.a * 0.85))
		ci.draw_string(f, pos, s, align, width, size, col)


	static func dist_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
		var ab := b - a
		var l2 := ab.length_squared()
		if l2 < 0.001:
			return p.distance_to(a)
		var k := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		return p.distance_to(a + ab * k)


	## Rayo zigzag (lo usan el rayo de la base, la intro y los remates).
	static func zigzag(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float, seed_v: int, jag: float = 16.0) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var pts := PackedVector2Array([a])
		var n := 9
		var side := (b - a).orthogonal().normalized()
		for i in range(1, n):
			var k := float(i) / n
			pts.append(a.lerp(b, k) + side * rng.randf_range(-jag, jag))
		pts.append(b)
		ci.draw_polyline(pts, Color(col, col.a * 0.35), width * 2.6)
		ci.draw_polyline(pts, col, width)
		ci.draw_polyline(pts, Color(1, 1, 1, col.a), maxf(1.0, width * 0.35))


## Base de los peligros de SUDO. `fake` = alucinación (fase 2): se ve transparente y no hace daño.
class SHazard extends BossFx.Hazard:
	var fake := false

	func hurt(amount: int, unblockable: bool = true) -> void:
		if fake:
			return
		super.hurt(amount, unblockable)

	func fizzle() -> void:
		queue_free()

	func feet_in(center: Vector2, r: float) -> bool:
		if not player_ok():
			return false
		var d := player_feet() - center
		return Vector2(d.x, d.y * 2.0).length() < r


# ====================================================================================
# FASE 1 · SUPABASE
# ====================================================================================

## Rayo de la base: círculo verde en el piso y luego cae un rayo del techo. No se bloquea.
class Bolt extends SHazard:
	var warn := 0.9
	var r := 50.0
	var damage := 2
	var harmless := false
	var col := GREEN
	var big := true            ## false = sin destello ni quemadura (rayitos de decoración)
	var t := 0.0
	var _hit := false
	var _seed := 0
	var _branches: Array = []  # [punto de salida (0..1), ángulo, largo]
	var _spr := false          ## true = el rayo de abajo lo dibuja la animación (fxbolt)

	func _ready() -> void:
		z_index = -1
		_seed = randi()
		for i in 3:
			_branches.append([randf_range(0.25, 0.75), randf_range(-1.0, 1.0), randf_range(60.0, 140.0)])

	func _process(delta: float) -> void:
		t += delta
		if t >= warn and not _hit:
			_hit = true
			z_index = 4
			for v in victims():
				_victim = v
				if not harmless and feet_in(global_position, r):
					hurt(damage, true)
			_victim = null
			if is_inside_tree():
				GameFeel.dust(get_parent(), global_position, 6, Vector2.ZERO, 5.0, Vector2(r * 0.7, 6))
				if Anim.ok("fxbolt"):
					_spr = true
					var an := Anim.new()
					an.prefix = "fxbolt"
					an.frames = [2, 3, 3, 4, 4, 5, 6, 7]
					an.fps = 16.0
					an.ground = true
					an.k = r / 50.0
					an.glow = Color(col, 0.25)
					get_parent().add_child(an)
					an.global_position = global_position + Vector2(0, 6)
				if big:
					var b := Burst.new()
					b.col = col.lightened(0.3)
					b.count = 16
					get_parent().add_child(b)
					b.global_position = global_position
					var sc := Scorch.new()
					sc.r = r * 0.9
					sc.col = col
					get_parent().add_child(sc)
					sc.global_position = global_position
					var rg := Ring.new()
					rg.col = col
					rg.max_r = r * 2.4
					rg.life = 0.35
					get_parent().add_child(rg)
					rg.global_position = global_position
					if is_instance_valid(boss) and boss.has_method("_shake"):
						boss.call("_shake", 4.0, 0.16)
		if t >= warn + 0.45:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t < warn:
			var k := t / warn
			var blink := 0.6 + 0.4 * absf(sin(t * 16.0))
			# nube cargándose arriba
			for i in 4:
				ellipse(Vector2(sin(t * 3.0 + i) * 18.0, -440.0 + i * 6.0), Vector2(40.0 + 30.0 * k + i * 10.0, 14.0 + 6.0 * k), Color(0.05, 0.12, 0.08, 0.35 * k))
			if fmod(t * 9.0 + float(_seed % 7), 3.0) < 0.25 and k > 0.4:
				U.zigzag(self, Vector2(-30, -440), Vector2(30, -430), Color(GREEN_HI, 0.6), 1.5, _seed + int(t * 20.0), 8.0)
			# columna de luz y círculo con código girando
			draw_rect(Rect2(-r * 0.15 * k, -430, r * 0.3 * k, 430), Color(col, 0.08 * k))
			ellipse(Vector2.ZERO, Vector2(r, r * 0.5), Color(col, 0.12 * blink))
			ellipse(Vector2.ZERO, Vector2(r * k, r * k * 0.5), Color(col, 0.3))
			ellipse_line(Vector2.ZERO, Vector2(r, r * 0.5), Color(col.lightened(0.3), 0.85 * blink), 2.0)
			var glyphs := "{}<>01;=/"
			for i in 8:
				var ang := TAU * i / 8.0 + t * 2.5
				U.text(self, Vector2(cos(ang) * r * 0.78 - 4, sin(ang) * r * 0.39 + 4), glyphs[(i + _seed) % glyphs.length()], 11, Color(GREEN_HI, 0.7 * k), -1, HORIZONTAL_ALIGNMENT_LEFT, 0)
		else:
			var e := (t - warn) / 0.45
			var a := clampf(1.0 - e, 0.0, 1.0)
			var top := Vector2(randf_range(-6, 6), -540)
			if _spr:
				# con la animación: solo el tramo del cielo hasta lo alto del sprite, y el destello del piso
				if e < 0.35:
					var low := Vector2(0, -200.0 * r / 50.0)
					U.zigzag(self, top, low, Color(col, a * 0.6), 10.0, _seed + int(t * 30.0), 18.0)
					U.zigzag(self, top, low, Color(GREEN_HI, a), 5.0, _seed + int(t * 30.0), 18.0)
				ellipse(Vector2.ZERO, Vector2(r * (1.1 + e), r * (0.55 + e * 0.5)), Color(col, 0.35 * a))
				return
			# rayo principal grueso + ramas
			U.zigzag(self, top, Vector2.ZERO, Color(col, a * 0.6), 12.0 * a + 2.0, _seed + int(t * 30.0), 22.0)
			U.zigzag(self, top, Vector2.ZERO, Color(GREEN_HI, a), 6.0, _seed + int(t * 30.0), 22.0)
			for br in _branches:
				var from := top.lerp(Vector2.ZERO, float(br[0]))
				var to := from + Vector2.from_angle(PI * 0.5 + float(br[1])) * float(br[2])
				U.zigzag(self, from, to, Color(GREEN_HI, a * 0.8), 2.5, _seed + 3 + int(t * 40.0), 10.0)
			if col == GREEN:
				U.spr_feet(self, "projectiles_1", Vector2(0, 6), 1.0, Color(1, 1, 1, a))
			ellipse(Vector2.ZERO, Vector2(r * (1.1 + e), r * (0.55 + e * 0.5)), Color(col, 0.5 * a))
			ellipse(Vector2.ZERO, Vector2(r * 0.6, r * 0.3), Color(1, 1, 1, 0.9 * a))
			draw_circle(Vector2(0, -10), 26.0 * a, Color(1, 1, 1, 0.5 * a))


## Realtime: 3 "tablas" verdes unidas por láseres que giran. Rodar a través del láser.
class Realtime extends SHazard:
	var radius := 210.0
	var spin := 0.7
	var warm := 0.8
	var life := 4.6
	var nodes := 3
	var t := 0.0
	var _cd := 0.0
	var a0 := 0.0

	func _ready() -> void:
		z_index = 2
		a0 = randf() * TAU

	func _pts() -> Array:
		var out: Array = []
		var grow := clampf(t / 0.5, 0.0, 1.0)
		for i in nodes:
			var a := a0 + TAU * i / nodes + spin * maxf(0.0, t - warm)
			out.append(Vector2(cos(a), sin(a) * 0.62) * radius * grow)
		return out

	func _process(delta: float) -> void:
		t += delta
		_cd = maxf(0.0, _cd - delta)
		if t > warm and t < life:
			var pts := _pts()
			for v in victims():
				_victim = v
				var p := player_body() - global_position
				for i in pts.size():
					var a: Vector2 = pts[i]
					var b: Vector2 = pts[(i + 1) % pts.size()]
					if U.dist_to_seg(p, a, b) < 14.0:
						if cd_ok("arc", 0.7):
							hurt(1, true)
						break
			_victim = null
		if t > life + 0.3:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var pts := _pts()
		var fade := clampf((life + 0.3 - t) / 0.3, 0.0, 1.0)
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			if t < warm:
				draw_dashed_line(a, b, Color(GREEN, 0.55 * absf(sin(t * 14.0))), 2.0, 10.0)
			else:
				var w := 6.0 + 2.0 * sin(t * 30.0)
				draw_line(a, b, Color(GREEN, 0.22 * fade), w * 4.0)
				draw_line(a, b, Color(GREEN, 0.35 * fade), w * 2.4)
				draw_line(a, b, Color(GREEN_HI, 0.95 * fade), w)
				draw_line(a, b, Color(1, 1, 1, fade), 2.0)
				# arcos eléctricos que se retuercen alrededor del láser
				U.zigzag(self, a, b, Color(GREEN_HI, 0.55 * fade), 1.5, int(t * 24.0) + i * 13, 14.0)
				# pulsos de datos viajando entre las tablas
				for j in 3:
					var q := fmod(t * 1.6 + j / 3.0, 1.0)
					draw_circle(a.lerp(b, q), 5.0, Color(1, 1, 1, 0.9 * fade))
		for p in pts:
			_cube(p, fade)

	func _cube(c: Vector2, a: float) -> void:
		if U.spr(self, "props_0", c + Vector2(0, -10), 1.0, 0.0, Color(1, 1, 1, a)):
			return
		var s := 16.0
		var top := PackedVector2Array([c + Vector2(0, -s - 8), c + Vector2(s, -s * 0.5 - 8), c + Vector2(0, -8), c + Vector2(-s, -s * 0.5 - 8)])
		var left := PackedVector2Array([c + Vector2(-s, -s * 0.5 - 8), c + Vector2(0, -8), c + Vector2(0, s * 0.6), c + Vector2(-s, s * 0.1)])
		var right := PackedVector2Array([c + Vector2(s, -s * 0.5 - 8), c + Vector2(0, -8), c + Vector2(0, s * 0.6), c + Vector2(s, s * 0.1)])
		draw_colored_polygon(left, Color(0.08, 0.35, 0.22, a))
		draw_colored_polygon(right, Color(0.12, 0.5, 0.32, a))
		draw_colored_polygon(top, Color(GREEN_HI, a))
		draw_line(c + Vector2(-s * 0.5, -s * 0.25 - 8), c + Vector2(s * 0.5, -s * 0.25 - 8), Color(0.05, 0.3, 0.2, a), 1.0)


## Row Level Security: el piso se parte en filas; se encienden las pares o las impares y descargan.
class Rows extends SHazard:
	var area := Rect2()
	var rows := 6
	var waves := 2
	var warn := 0.75
	var zap := 0.3
	var start := 0
	var t := 0.0
	var _hit_wave := -1

	func _ready() -> void:
		z_index = -2

	func _wave_t() -> float:
		return warn + zap + 0.15

	func _process(delta: float) -> void:
		t += delta
		var w := int(t / _wave_t())
		var local := t - w * _wave_t()
		if w < waves and local >= warn and _hit_wave != w:
			_hit_wave = w
			for v in victims():
				_victim = v
				var row := _row_of(player_feet().y)
				if row >= 0 and (row + start + w) % 2 == 0:
					hurt(2, true)
			_victim = null
		if t > waves * _wave_t():
			queue_free()
		queue_redraw()

	func _row_of(y: float) -> int:
		var h := area.size.y / rows
		var i := int((y - area.position.y) / h)
		return i if i >= 0 and i < rows else -1

	func _draw() -> void:
		var w := int(t / _wave_t())
		if w >= waves:
			return
		var local := t - w * _wave_t()
		var h := area.size.y / rows
		for i in rows:
			var r := Rect2(area.position.x, area.position.y + i * h, area.size.x, h)
			var lit := (i + start + w) % 2 == 0
			if lit:
				if local < warn:
					var blink := 0.5 + 0.5 * absf(sin(local * 14.0))
					draw_rect(r, Color(GREEN, 0.1 + 0.12 * blink))
					draw_rect(r.grow(-2), Color(GREEN, 0.6 * blink), false, 2.0)
					U.text(self, r.position + Vector2(12, h * 0.5 + 6), "DENY", 14, Color(GREEN_HI, 0.7 * blink))
				elif local < warn + zap:
					draw_rect(r, Color(GREEN_HI, 0.55))
					for k in 6:
						var x := r.position.x + (k + 0.5) * r.size.x / 6.0
						U.zigzag(self, Vector2(x, r.position.y + 4), Vector2(x + 30, r.end.y - 4), Color(1, 1, 1, 0.8), 2.0, k + w * 7, 10.0)
			else:
				if local < warn:
					U.text(self, r.position + Vector2(12, h * 0.5 + 6), "ALLOW", 12, Color(1, 1, 1, 0.25))


## Bola de Edge Function: sale de un borde y rebota. Con parry vuelve hacia SUDO y le hace daño.
class EdgeBall extends SHazard:
	var vel := Vector2.ZERO
	var area := Rect2()
	var bounces := 2
	var back := false
	var life := 5.0
	var t := 0.0
	var _done := false

	func _ready() -> void:
		z_index = 5

	func _process(delta: float) -> void:
		t += delta
		if back:
			if is_instance_valid(boss):
				var to: Vector2 = boss.global_position + Vector2(0, -100)
				vel = vel.lerp((to - global_position).normalized() * 620.0, minf(1.0, delta * 6.0))
				global_position += vel * delta
				if global_position.distance_to(to) < 50.0:
					boss.call("edge_reflected", self)
					queue_free()
					return
			else:
				queue_free()
				return
		else:
			global_position += vel * delta
			if bounces > 0:
				if global_position.x < area.position.x + 10 or global_position.x > area.end.x - 10:
					vel.x = -vel.x
					bounces -= 1
				if global_position.y < area.position.y + 10 or global_position.y > area.end.y - 10:
					vel.y = -vel.y
					bounces -= 1
			if not _done and touch_any(22.0):
				if bool(_who().get("rolling")):
					_victim = null
				elif fake:
					_done = true
					queue_free()
					return
				else:
					_done = true
					var r := Final.parry_ok(_who(), global_position)
					if r == 1:
						back = true
						_victim = null
						GameFeel.parry_burst(get_parent(), global_position, 22.0)
						if is_instance_valid(boss):
							boss.call("inject_context", "parry")
					else:
						hurt(1, false)
						queue_free()
						return
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var c := GREEN_HI if not back else Color(1, 1, 0.7)
		for i in 4:
			draw_circle(-vel.normalized() * (8.0 + i * 7.0), 8.0 - i * 1.6, Color(c, 0.25 - i * 0.05))
		if U.spr(self, "projectiles_0", Vector2.ZERO, 1.0, t * 6.0, Color(1, 1, 0.75) if back else Color.WHITE):
			return
		draw_circle(Vector2.ZERO, 13.0, Color(GREEN, 0.5))
		draw_circle(Vector2.ZERO, 9.0, c)
		for i in 3:
			var a := t * 9.0 + TAU * i / 3.0
			U.zigzag(self, Vector2.ZERO, Vector2.from_angle(a) * 20.0, Color(1, 1, 1, 0.8), 1.5, int(t * 20.0) + i, 4.0)


# ====================================================================================
# FASE 1 · CURSOR
# ====================================================================================

## Rastro de "texto fantasma" (autocompletado) que predice la embestida Tab.
class GhostTrail extends SHazard:
	var to := Vector2.ZERO        # punto final (local)
	var life := 0.8
	var t := 0.0
	var words := ["await", "supabase", ".from(", "'club'", ")", ".select()", "=>", "ia"]

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - maxf(0.0, t - life * 0.7) / (life * 0.3), 0.0, 1.0)
		var k := clampf(t / (life * 0.5), 0.0, 1.0)
		var end := to * k
		var dir := to.normalized()
		var side := dir.orthogonal()
		draw_line(Vector2.ZERO, end, Color(0.75, 0.75, 0.8, 0.25 * a), 46.0)
		var n := int(to.length() / 44.0)
		for i in n:
			var p := dir * (i * 44.0 + 22.0)
			if p.length() > end.length():
				break
			U.text(self, p + side * 4.0 - Vector2(18, -4), str(words[i % words.size()]), 11, Color(0.82, 0.82, 0.88, 0.55 * a), -1, HORIZONTAL_ALIGNMENT_LEFT, 0)
		# cursor parpadeante al final
		if fmod(t * 6.0, 1.0) > 0.4:
			if not U.spr(self, "projectiles_4", end + Vector2(0, -4), 1.0, 0.0, Color(1, 1, 1, a)):
				draw_rect(Rect2(end + Vector2(-3, -16), Vector2(6, 26)), Color(CURSOR, a))
		U.text(self, end + Vector2(10, -18), "Tab", 13, Color(1, 1, 1, 0.85 * a))


## Cmd+K: rectángulo de selección azul que te sigue y luego "reescribe" (explota) lo de adentro.
class Selection extends SHazard:
	var follow := 1.0
	var lock := 0.4
	var size := Vector2(170, 110)
	var t := 0.0
	var _hit := false
	var _chars: Array = []

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if t < follow and player_ok():
			global_position = global_position.lerp(player_feet() + Vector2(0, -20), minf(1.0, delta * 5.0))
		if t >= follow + lock and not _hit:
			_hit = true
			z_index = 4
			for v in victims():
				_victim = v
				var r := Rect2(global_position - size * 0.5, size)
				if r.has_point(player_feet()):
					hurt(2, true)
			_victim = null
			for i in 34:
				_chars.append([Vector2(randf_range(-size.x, size.x) * 0.45, randf_range(-size.y, size.y) * 0.45), Vector2(randf_range(-220, 220), randf_range(-280, -40)), "01{};=<>/"[randi() % 9], randf_range(-6.0, 6.0)])
			if is_inside_tree():
				if Anim.ok("fxdata"):
					var an := Anim.new()
					an.prefix = "fxdata"
					an.k = 1.05
					an.fps = 15.0
					an.glow = Color(CURSOR, 0.25)
					get_parent().add_child(an)
					an.global_position = global_position
				var b := Burst.new()
				b.col = Color(0.6, 0.8, 1.0)
				b.count = 22
				b.speed = 380.0
				get_parent().add_child(b)
				b.global_position = global_position
				var rg := Ring.new()
				rg.col = CURSOR
				rg.max_r = 200.0
				rg.life = 0.4
				get_parent().add_child(rg)
				rg.global_position = global_position + Vector2(0, 20)
				if is_instance_valid(boss) and boss.has_method("_shake"):
					boss.call("_shake", 5.0, 0.2)
		if t > follow + lock + 0.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(-size * 0.5, size)
		if not _hit:
			var locked := t >= follow
			var blink := 0.5 + 0.5 * absf(sin(t * (22.0 if locked else 8.0)))
			draw_rect(r, Color(CURSOR, 0.12 + (0.12 * blink if locked else 0.0)))
			draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), Color(CURSOR, 0.9), 2.0, 8.0)
			draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, Color(CURSOR, 0.9), 2.0, 8.0)
			draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), Color(CURSOR, 0.9), 2.0, 8.0)
			draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, Color(CURSOR, 0.9), 2.0, 8.0)
			# esquinas de mira que se cierran
			var c := 14.0 + (1.0 - clampf((t - follow) / lock, 0.0, 1.0)) * 18.0 if locked else 14.0
			for q in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				var sx := -1.0 if q.x > 0.0 else 1.0
				var sy := -1.0 if q.y > 0.0 else 1.0
				var qq: Vector2 = q - Vector2(sx, sy) * (c - 14.0)
				draw_line(qq, qq + Vector2(sx * c, 0), Color(1, 1, 1, 0.95), 3.0)
				draw_line(qq, qq + Vector2(0, sy * c), Color(1, 1, 1, 0.95), 3.0)
			if locked:
				# líneas de código reescribiéndose dentro
				for i in 5:
					var y := r.position.y + 14.0 + i * 18.0
					var w := fmod(t * 300.0 + i * 57.0, r.size.x - 20.0)
					draw_rect(Rect2(r.position.x + 10.0, y, w, 6), Color(0.6, 0.8, 1.0, 0.5))
			draw_rect(Rect2(r.position + Vector2(0, -22), Vector2(150, 20)), Color(0.06, 0.07, 0.12, 0.9))
			U.text(self, r.position + Vector2(6, -7), "Cmd+K  reescribiendo..." if locked else "Cmd+K", 12, Color(0.85, 0.9, 1))
		else:
			var k := clampf((t - follow - lock) / 0.5, 0.0, 1.0)
			draw_rect(r.grow(30.0 * k), Color(1, 1, 1, 0.85 * (1.0 - k) * (1.0 - k)))
			draw_rect(r, Color(CURSOR, 0.6 * (1.0 - k)))
			draw_rect(r.grow(10.0 + 40.0 * k), Color(CURSOR, 0.9 * (1.0 - k)), false, 4.0)
			for c in _chars:
				var p: Vector2 = c[0] + c[1] * k + Vector2(0, 260.0 * k * k)
				draw_set_transform(p, float(c[3]) * k)
				U.text(self, Vector2.ZERO, str(c[2]), 18, Color(0.7, 0.85, 1, 1.0 - k), -1, HORIZONTAL_ALIGNMENT_LEFT, 0)
			draw_set_transform(Vector2.ZERO)


## Agente: flechita-cursor que te persigue y hace clic (1 de daño, se puede parry). Se rompe de 2 golpes.
class CursorAgent extends Node2D:
	var boss: Node2D
	var player: Node2D
	var lockable := false
	var hp := 2
	var speed := 125.0
	var life := 7.5
	var t := 0.0
	var fake := false
	var _click := -1.0
	var _cd := 0.6
	var _dead := 0.0

	func _ready() -> void:
		add_to_group("enemies")
		add_to_group("boss_minion")
		z_index = 3
		U.add_hurtbox(self, Vector2(34, 34), Vector2(0, -10))

	func _process(delta: float) -> void:
		t += delta
		if _dead > 0.0:
			_dead += delta
			if _dead > 0.25:
				queue_free()
			queue_redraw()
			return
		if t > life:
			die()
			return
		if player != null and is_instance_valid(player):
			var target: Vector2 = player.global_position + Vector2(0, -24)
			var d := target - global_position
			if _click < 0.0:
				_cd -= delta
				if d.length() > 40.0:
					global_position += d.normalized() * speed * delta
				elif _cd <= 0.0:
					_click = 0.0
			else:
				_click += delta
				if _click >= 0.35:
					_click = -1.0
					_cd = 1.1
					if d.length() < 52.0 and not fake and is_instance_valid(boss):
						boss.call("hurt_player", 1, global_position, false)
					GameFeel.parry_burst(get_parent(), global_position + Vector2(0, -6), 12.0)
		queue_redraw()

	func take_hit(amount: int, _from: Vector2) -> void:
		if _dead > 0.0:
			return
		hp -= amount
		GameFeel.flash(self, 0.08, Color.WHITE)
		if hp <= 0:
			die()

	func die() -> void:
		if _dead > 0.0:
			return
		_dead = 0.001
		remove_from_group("enemies")
		if is_inside_tree():
			GameFeel.parry_burst(get_parent(), global_position, 18.0)

	func _draw() -> void:
		var a := (1.0 - clampf(_dead / 0.25, 0.0, 1.0)) * (0.45 if fake else 1.0)
		var s := 1.0 + (0.25 * sin(_click * 30.0) if _click >= 0.0 else 0.0)
		if U.spr(self, "minions_7" if _click >= 0.0 else "minions_6", Vector2(4, sin(t * 6.0) * 2.0 - 12.0), s, 0.0, Color(1, 1, 1, a)):
			if _click >= 0.0:
				draw_arc(Vector2(0, -10), 30.0 - 20.0 * _click / 0.35, 0, TAU, 20, Color(CURSOR, a), 2.0)
			return
		draw_set_transform(Vector2(0, sin(t * 6.0) * 2.0 - 10.0), -0.2, Vector2(s, s))
		var pts := PackedVector2Array([Vector2(0, -16), Vector2(0, 12), Vector2(6, 6), Vector2(11, 16), Vector2(15, 14), Vector2(10, 4), Vector2(18, 4)])
		var outline := PackedVector2Array(pts)
		outline.append(pts[0])
		draw_colored_polygon(pts, Color(1, 1, 1, a))
		draw_polyline(outline, Color(0.05, 0.05, 0.1, a), 2.0)
		draw_set_transform(Vector2.ZERO)
		U.text(self, Vector2(12, -22), "AI", 11, Color(CURSOR, a))
		if _click >= 0.0:
			draw_arc(Vector2(0, -10), 30.0 - 20.0 * _click / 0.35, 0, TAU, 20, Color(CURSOR, a), 2.0)


# ====================================================================================
# FASE 2 · GROKBOT
# ====================================================================================

## Proyectil que se puede bloquear con parry (bloque de píxeles, tarea [x], medialuna, candado, roca).
class PShot extends SHazard:
	var vel := Vector2.DOWN * 260.0
	var kind := "pixel"
	var col := GREEN
	var damage := 1
	var life := 4.0
	var out_time := -1.0          ## medialunas: vuelven al boss después de este tiempo
	var t := 0.0
	var _done := false
	var _spin := 0.0

	func _ready() -> void:
		z_index = 5
		_spin = randf_range(-8.0, 8.0)

	func _process(delta: float) -> void:
		t += delta
		if out_time > 0.0 and t > out_time and is_instance_valid(boss):
			var to: Vector2 = boss.global_position + Vector2(0, -110)
			vel = vel.lerp((to - global_position).normalized() * 380.0, minf(1.0, delta * 3.0))
			if global_position.distance_to(to) < 40.0:
				queue_free()
				return
		global_position += vel * delta
		if not _done and touch_any(20.0):
			if bool(_who().get("rolling")):
				_victim = null
			else:
				_done = true
				if fake:
					queue_free()
					return
				var who := _who()
				var r := Final.parry_ok(who, global_position)
				if r == 1:
					GameFeel.parry_burst(get_parent(), global_position, 18.0)
					if is_instance_valid(boss):
						boss.call("inject_context", "parry")
				else:
					var before := int(who.get("hp"))
					hurt(damage, false)
					if kind == "lock" and int(who.get("hp")) < before and is_instance_valid(boss):
						boss.set("player", who)   # le quita la técnica al que golpeó
						boss.call("revoke_player")
				queue_free()
				return
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var sp := {"pixel": "projectiles_2", "lock": "projectiles_5", "rock": "projectiles_3", "moon": "props_7"}
		if sp.has(kind):
			var rot := t * _spin
			if kind == "moon":
				rot = vel.angle() + t * 10.0
				draw_circle(Vector2.ZERO, 16.0, Color(MOON, 0.12))
			elif kind == "lock":
				draw_circle(Vector2.ZERO, 18.0, Color(CLERK, 0.25))
				rot = 0.0
			if U.spr(self, str(sp[kind]), Vector2.ZERO, 1.0, rot):
				return
		match kind:
			"pixel":
				draw_set_transform(Vector2.ZERO, t * _spin)
				for i in 4:
					var o := Vector2((i % 2) * 8.0 - 8.0, (i / 2) * 8.0 - 8.0)
					draw_rect(Rect2(o, Vector2(8, 8)), col if (i % 3) != 0 else col.lightened(0.35))
				draw_rect(Rect2(-8, -8, 16, 16), Color(0, 0, 0, 0.8), false, 2.0)
				draw_set_transform(Vector2.ZERO)
			"task":
				draw_rect(Rect2(-16, -11, 32, 22), Color(0.1, 0.1, 0.12))
				draw_rect(Rect2(-16, -11, 32, 22), Color(1, 1, 1, 0.9), false, 2.0)
				U.text(self, Vector2(-14, 6), "[x]", 13, Color(0.6, 1, 0.6), -1, HORIZONTAL_ALIGNMENT_LEFT, 0)
			"moon":
				var a := vel.angle()
				draw_set_transform(Vector2.ZERO, a + t * 10.0)
				draw_circle(Vector2.ZERO, 12.0, Color(MOON, 0.95))
				draw_circle(Vector2(5, -3), 11.0, Color(0.05, 0.06, 0.14))
				draw_set_transform(Vector2.ZERO)
				draw_circle(Vector2.ZERO, 16.0, Color(MOON, 0.12))
			"lock":
				draw_circle(Vector2.ZERO, 17.0, Color(CLERK, 0.25))
				draw_arc(Vector2(0, -6), 7.0, PI, TAU, 10, Color(0.9, 0.9, 1), 3.0)
				draw_rect(Rect2(-10, -6, 20, 15), CLERK)
				draw_rect(Rect2(-10, -6, 20, 15), Color(0, 0, 0, 0.8), false, 1.5)
				draw_circle(Vector2(0, 1), 2.5, Color(0.1, 0.05, 0.2))
			"rock":
				draw_set_transform(Vector2.ZERO, t * _spin)
				var pts := PackedVector2Array([Vector2(-12, -6), Vector2(-4, -13), Vector2(9, -10), Vector2(13, 2), Vector2(5, 12), Vector2(-9, 10)])
				draw_colored_polygon(pts, Color(0.45, 0.36, 0.28))
				pts.append(pts[0])
				draw_polyline(pts, Color(0.12, 0.08, 0.05), 2.0)
				draw_set_transform(Vector2.ZERO)
			_:
				draw_circle(Vector2.ZERO, 10.0, col)


## Grokbot: robotito negro con visor que "genera" bloques de píxeles y te los lanza (parry). 3 golpes lo rompen.
class Grokbot extends Node2D:
	var boss: Node2D
	var player: Node2D
	var lockable := false
	var hp := 3
	var spot := Vector2.ZERO
	var throws := 3
	var every := 1.0
	var t := 0.0
	var fake := false
	var _cd := 0.8
	var _dead := 0.0
	var _paint := 0.0
	var _walk := 0.0
	var _moving := false

	func _ready() -> void:
		add_to_group("enemies")
		add_to_group("boss_minion")
		z_index = 2
		U.add_hurtbox(self, Vector2(40, 46), Vector2(0, -24))
		GameFeel.add_shadow(self, Vector2(0, 0), Vector2(16, 5))

	func _process(delta: float) -> void:
		t += delta
		if _dead > 0.0:
			_dead += delta
			if _dead > 0.3:
				queue_free()
			queue_redraw()
			return
		var d := spot - global_position
		if d.length() > 6.0:
			global_position += d.normalized() * minf(d.length(), 180.0 * delta)
			_walk += delta * 12.0
			_moving = true
		else:
			_cd -= delta
			_paint = maxf(0.0, _paint - delta)
			if _cd <= 0.35 and _paint <= 0.0 and throws > 0:
				_paint = 0.35
			if _cd <= 0.0 and throws > 0:
				throws -= 1
				_cd = every
				_throw()
			if throws <= 0 and _cd <= 0.2:
				die(false)
		queue_redraw()

	func _throw() -> void:
		if player == null or not is_instance_valid(player) or not is_instance_valid(boss):
			return
		var s := PShot.new()
		s.kind = "pixel"
		s.col = [Color(0.95, 0.45, 0.6), Color(0.45, 0.85, 1.0), Color(1.0, 0.85, 0.35), Color(0.6, 1.0, 0.55)][randi() % 4]
		var from := global_position + Vector2(0, -30)
		s.vel = ((player.global_position + Vector2(0, -32)) - from).normalized() * 270.0
		s.fake = fake
		boss.call("_add_fx", s, from)

	func take_hit(amount: int, _from: Vector2) -> void:
		if _dead > 0.0:
			return
		hp -= amount
		GameFeel.flash(self, 0.08, Color.WHITE)
		if hp <= 0:
			die(true)

	func die(burst: bool = true) -> void:
		if _dead > 0.0:
			return
		_dead = 0.001
		remove_from_group("enemies")
		if burst and is_inside_tree():
			GameFeel.parry_burst(get_parent(), global_position + Vector2(0, -24), 22.0)

	func _draw() -> void:
		var a := (1.0 - clampf(_dead / 0.3, 0.0, 1.0)) * (0.45 if fake else 1.0)
		var fr := "minions_0"
		if _dead > 0.0:
			fr = "minions_5"
		elif _paint > 0.0:
			fr = "minions_4"
		elif _moving:
			fr = "minions_%d" % (int(_walk / 1.6) % 4)
		_moving = false
		if U.spr_feet(self, fr, Vector2.ZERO, 1.0, Color(1, 1, 1, a), spot.x < global_position.x):
			return
		var bob := absf(sin(_walk)) * 3.0
		# piernas
		draw_rect(Rect2(-11, -10 + bob * 0.3, 7, 10), Color(0.12, 0.12, 0.14, a))
		draw_rect(Rect2(4, -10 - bob * 0.3, 7, 10), Color(0.12, 0.12, 0.14, a))
		# cuerpo y cabeza
		draw_rect(Rect2(-15, -30 - bob, 30, 22), Color(0.08, 0.08, 0.1, a))
		draw_rect(Rect2(-15, -30 - bob, 30, 22), Color(0.4, 0.4, 0.45, a), false, 1.5)
		draw_circle(Vector2(0, -42 - bob), 15.0, Color(0.06, 0.06, 0.08, a))
		draw_arc(Vector2(0, -42 - bob), 15.0, 0, TAU, 20, Color(0.45, 0.45, 0.5, a), 1.5)
		# visor: una raya blanca en diagonal
		draw_line(Vector2(-9, -38 - bob), Vector2(9, -47 - bob), Color(GROK, a), 4.0)
		draw_circle(Vector2(6, -45 - bob), 2.0, Color(1, 1, 1, a))
		# antena
		draw_line(Vector2(0, -57 - bob), Vector2(0, -64 - bob), Color(0.5, 0.5, 0.55, a), 2.0)
		draw_circle(Vector2(0, -65 - bob), 3.0, Color(0.6, 1.0, 0.7, a) if _paint > 0.0 else Color(0.5, 0.5, 0.55, a))
		# "pintando" el bloque
		if _paint > 0.0:
			var k := 1.0 - _paint / 0.35
			draw_rect(Rect2(Vector2(14, -42 - bob) - Vector2(8, 8) * k, Vector2(16, 16) * k), Color(1, 1, 1, 0.8 * a))


## Imagine: un grokbot dibuja tu silueta en el piso y 1 s después cobra vida y ataca ese punto.
class Silhouette extends SHazard:
	var delay := 1.0
	var r := 62.0
	var t := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if t >= delay and not _hit:
			_hit = true
			z_index = 4
			for v in victims():
				_victim = v
				if feet_in(global_position, r):
					hurt(2, true)
			_victim = null
		if t > delay + 0.45:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / delay, 0.0, 1.0)
		if not _hit:
			ellipse(Vector2.ZERO, Vector2(r, r * 0.5), Color(GROK, 0.08 + 0.1 * k))
			ellipse_line(Vector2.ZERO, Vector2(r, r * 0.5), Color(GROK, 0.3 + 0.4 * k), 2.0)
			# silueta del estudiante que se va "dibujando" de abajo arriba
			var col := Color(0.85, 0.85, 1.0, 0.25 + 0.55 * k)
			var top := lerpf(0.0, -88.0, k)
			draw_rect(Rect2(-14, maxf(top, -50.0), 28, -maxf(top, -50.0)), Color(col, col.a * 0.4))
			draw_rect(Rect2(-14, -50, 28, 50), col, false, 2.0)
			if k > 0.55:
				draw_circle(Vector2(0, -66), 15.0, Color(col, col.a * 0.4))
				draw_arc(Vector2(0, -66), 15.0, 0, TAU, 20, col, 2.0)
			U.text(self, Vector2(-30, 20), "imagine...", 11, Color(GROK, 0.7 * k), -1, HORIZONTAL_ALIGNMENT_LEFT, 0)
		else:
			var e := clampf((t - delay) / 0.45, 0.0, 1.0)
			ellipse(Vector2.ZERO, Vector2(r * (0.7 + 0.5 * e), r * (0.35 + 0.25 * e)), Color(1, 1, 1, 0.6 * (1.0 - e)))
			for i in 3:
				var a := -PI * 0.8 + i * 0.5
				draw_arc(Vector2(0, -40), 40.0 + 20.0 * e, a, a + 1.2, 10, Color(GROK, 1.0 - e), 4.0)


## Lista de tareas flotante junto a SUDO; el boss va marcando [x] (cada marca dispara una tarea).
class TaskPanel extends Node2D:
	var items := ["generar sprites", "recortar hojas", "calibrar", "probar", "commit"]
	var done := 0
	var t := 0.0
	var life := 5.0
	var fake := false

	func _ready() -> void:
		z_index = 6

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(minf(t / 0.2, (life - t) / 0.3), 0.0, 1.0) * (0.5 if fake else 1.0)
		var r := Rect2(-80, -14, 160, 18 + items.size() * 16)
		draw_rect(r, Color(0.07, 0.07, 0.09, 0.92 * a))
		draw_rect(r, Color(GROK, 0.8 * a), false, 1.5)
		U.text(self, Vector2(-74, 0), "grokbot: tareas", 11, Color(GROK, a), -1, HORIZONTAL_ALIGNMENT_LEFT, 0)
		for i in items.size():
			var mark := "[x] " if i < done else "[ ] "
			U.text(self, Vector2(-74, 16 + i * 16), mark + str(items[i]), 11, Color(0.6, 1, 0.6, a) if i < done else Color(1, 1, 1, 0.75 * a), -1, HORIZONTAL_ALIGNMENT_LEFT, 0)


# ====================================================================================
# FASE 2 · CLERK
# ====================================================================================

## Muro con forma de formulario de login que cruza la arena. Solo se pasa por el hueco del botón.
class LoginWall extends SHazard:
	var area := Rect2()
	var vertical := false          ## false = baja de arriba abajo; true = cruza de izquierda a derecha
	var speed := 165.0
	var gap := 0.0                 ## centro del hueco (x si horizontal, y si vertical)
	var gap_w := 130.0
	var thick := 44.0
	var warn := 0.7
	var t := 0.0
	var pos := 0.0
	var _cd := 0.0

	func _ready() -> void:
		z_index = 3
		pos = area.position.x - thick if vertical else area.position.y - thick

	func _process(delta: float) -> void:
		t += delta
		_cd = maxf(0.0, _cd - delta)
		if t > warn:
			pos += speed * delta
		var end := area.end.x if vertical else area.end.y
		if pos > end + thick:
			queue_free()
			return
		if t > warn:
			for v in victims():
				_victim = v
				var f := player_feet()
				var along := f.y if vertical else f.x
				var across := f.x if vertical else f.y
				if across > pos - 6.0 and across < pos + thick + 6.0 and absf(along - gap) > gap_w * 0.5 - 6.0 and cd_ok("wall", 0.8):
					hurt(2, true)
			_victim = null
		queue_redraw()

	func _draw() -> void:
		if t < warn:
			var blink := 0.5 + 0.5 * absf(sin(t * 12.0))
			var arrow := "v  INICIAR SESIÓN  v" if not vertical else ">  INICIAR SESIÓN  >"
			if vertical:
				U.text(self, Vector2(area.position.x + 8, area.position.y + area.size.y * 0.5), arrow, 14, Color(CLERK.lightened(0.3), blink))
			else:
				U.text(self, Vector2(area.position.x, area.position.y + 22), arrow, 14, Color(CLERK.lightened(0.3), blink), area.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			return
		var segs: Array = []
		var lo := area.position.y if vertical else area.position.x
		var hi := area.end.y if vertical else area.end.x
		segs.append([lo, gap - gap_w * 0.5])
		segs.append([gap + gap_w * 0.5, hi])
		for s in segs:
			var a: float = s[0]
			var b: float = s[1]
			if b <= a:
				continue
			var r := Rect2(pos, a, thick, b - a) if vertical else Rect2(a, pos, b - a, thick)
			draw_rect(r, Color(0.96, 0.96, 0.99))
			draw_rect(r, CLERK, false, 3.0)
			# campos del formulario
			var n := int((b - a) / 120.0)
			for i in n:
				var off := a + 20.0 + i * 120.0
				var f := Rect2(pos + 8, off, thick - 16, 90) if vertical else Rect2(off, pos + 10, 90, 14)
				draw_rect(f, Color(0.85, 0.85, 0.92))
				draw_rect(f, Color(0.55, 0.55, 0.65), false, 1.0)
				if not vertical:
					U.text(self, f.position + Vector2(4, 11), "contraseña" if i % 2 else "usuario", 9, Color(0.4, 0.4, 0.5), -1, HORIZONTAL_ALIGNMENT_LEFT, 0)
		# el hueco = botón "Continuar" brillando
		var g := Rect2(pos, gap - gap_w * 0.5, thick, gap_w) if vertical else Rect2(gap - gap_w * 0.5, pos, gap_w, thick)
		draw_rect(g, Color(CLERK, 0.15 + 0.1 * sin(t * 8.0)))
		U.text(self, g.position + Vector2(0, g.size.y * 0.5 + 5), "OK", 13, Color(1, 1, 1, 0.8), g.size.x, HORIZONTAL_ALIGNMENT_CENTER, 0)


## Sesión expirada: anillo-candado alrededor del jugador con cuenta atrás. Hay que salir antes del 0.
class SessionRing extends SHazard:
	var r := 118.0
	var count := 2.4
	var t := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if t >= count and not _hit:
			_hit = true
			z_index = 4
			for v in victims():
				_victim = v
				if feet_in(global_position, r):
					hurt(2, true)
					var n := BossFx.DmgNumber.new()
					n.text = "SESIÓN EXPIRADA"
					n.color = CLERK.lightened(0.4)
					get_parent().add_child(n)
					n.global_position = player_body() + Vector2(0, -40)
			_victim = null
		if t > count + 0.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if not _hit:
			var blink := 0.5 + 0.5 * absf(sin(t * (8.0 + t * 6.0)))
			ellipse(Vector2.ZERO, Vector2(r, r * 0.5), Color(CLERK, 0.08 + 0.08 * blink))
			for i in 24:
				var a := TAU * i / 24.0 + t * 0.6
				var p := Vector2(cos(a) * r, sin(a) * r * 0.5)
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(CLERK.lightened(0.3), 0.9))
			_padlock(Vector2(0, -r * 0.5 - 30), 1.0, false)
			U.text(self, Vector2(-30, -r * 0.5 - 52), str(int(ceil(count - t))), 22, Color(1, 1, 1), 60, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var e := clampf((t - count) / 0.5, 0.0, 1.0)
			ellipse(Vector2.ZERO, Vector2(r * (1.0 - 0.6 * e), r * 0.5 * (1.0 - 0.6 * e)), Color(CLERK, 0.6 * (1.0 - e)))
			_padlock(Vector2(0, -r * 0.5 - 30), 1.0 - e, true)

	func _padlock(c: Vector2, a: float, closed: bool) -> void:
		if U.spr(self, "props_1" if closed else "props_2", c, 1.0, 0.0, Color(1, 1, 1, a)):
			return
		draw_arc(c + Vector2(0 if closed else 6, -10), 10.0, PI, TAU, 12, Color(0.9, 0.9, 1, a), 4.0)
		draw_rect(Rect2(c + Vector2(-14, -10), Vector2(28, 22)), Color(CLERK, a))
		draw_rect(Rect2(c + Vector2(-14, -10), Vector2(28, 22)), Color(0, 0, 0, 0.8 * a), false, 2.0)
		draw_circle(c, 3.0, Color(0.1, 0.05, 0.2, a))


## Código 2FA flotante. El correcto (el mismo de la pantalla de SUDO) se golpea; el falso explota.
class Code extends Node2D:
	var boss: Node2D
	var lockable := false
	var code := "000000"
	var correct := false
	var life := 5.5
	var t := 0.0
	var _dead := 0.0

	func _ready() -> void:
		add_to_group("enemies")
		add_to_group("boss_minion")
		z_index = 4
		U.add_hurtbox(self, Vector2(96, 38), Vector2(0, -6))

	func _process(delta: float) -> void:
		t += delta
		if _dead > 0.0:
			_dead += delta
			if _dead > 0.25:
				queue_free()
			queue_redraw()
			return
		if t > life:
			if is_instance_valid(boss):
				boss.call("twofa_timeout", self)
			pop()
		queue_redraw()

	func take_hit(_amount: int, _from: Vector2) -> void:
		if _dead > 0.0:
			return
		if is_instance_valid(boss):
			boss.call("twofa_hit", self)

	func pop() -> void:
		if _dead > 0.0:
			return
		_dead = 0.001
		remove_from_group("enemies")

	func _draw() -> void:
		var a := 1.0 - clampf(_dead / 0.25, 0.0, 1.0)
		var bob := sin(t * 3.0 + (1.0 if correct else 0.0) * 2.0) * 4.0
		var r := Rect2(-50, -24 + bob, 100, 34)
		var card: Texture2D = Spr.tex("boss_sudo_props_6")
		if card:
			draw_texture_rect(card, r.grow(3.0), false, Color(1, 1, 1, a))
		else:
			draw_rect(r, Color(0.98, 0.98, 1, a))
			draw_rect(r, Color(CLERK, a), false, 3.0)
		U.text(self, Vector2(-50, -1 + bob), code, 20, Color(0.15, 0.1, 0.3, a), 100, HORIZONTAL_ALIGNMENT_CENTER, 0)
		U.text(self, Vector2(-50, -30 + bob), "2FA", 11, Color(CLERK.lightened(0.4), a), 100, HORIZONTAL_ALIGNMENT_CENTER)
		draw_rect(Rect2(-50, 12 + bob, 100 * clampf(1.0 - t / life, 0.0, 1.0), 3), Color(CLERK, a))


## Explosión simple (el código falso del 2FA). No se bloquea.
class Boom extends SHazard:
	var r := 90.0
	var warn := 0.35
	var col := CLERK
	var t := 0.0
	var _hit := false

	func _process(delta: float) -> void:
		t += delta
		if t >= warn and not _hit:
			_hit = true
			for v in victims():
				_victim = v
				if feet_in(global_position, r):
					hurt(2, true)
			_victim = null
		if t > warn + 0.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t < warn:
			ellipse_line(Vector2.ZERO, Vector2(r, r * 0.5), Color(1, 0.3, 0.3, 0.6 + 0.4 * absf(sin(t * 30.0))), 3.0)
		else:
			var e := clampf((t - warn) / 0.4, 0.0, 1.0)
			ellipse(Vector2.ZERO, Vector2(r * (0.6 + 0.5 * e), r * (0.3 + 0.25 * e)), Color(col.lightened(0.3), 0.7 * (1.0 - e)))
			draw_circle(Vector2(0, -20), 30.0 * (1.0 - e) + 10.0, Color(1, 1, 1, 0.6 * (1.0 - e)))


## Candado sobre la cabeza del jugador: "401 UNAUTHORIZED" (una habilidad bloqueada).
class LockIcon extends Node2D:
	var life := 5.0
	var label := "K"
	var t := 0.0

	func _ready() -> void:
		z_index = 30
		position = Vector2(0, -118)

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var bob := sin(t * 5.0) * 2.0
		draw_rect(Rect2(-62, -36 + bob, 124, 16), Color(0, 0, 0, 0.7))
		U.text(self, Vector2(-62, -24 + bob), "401 UNAUTHORIZED", 11, Color(1, 0.5, 0.5), 124, HORIZONTAL_ALIGNMENT_CENTER, 0)
		if not U.spr(self, "props_1", Vector2(0, 0 + bob), 0.8):
			draw_arc(Vector2(0, -6 + bob), 7.0, PI, TAU, 10, Color(0.9, 0.9, 1), 3.0)
			draw_rect(Rect2(-10, -6 + bob, 20, 15), CLERK)
		U.text(self, Vector2(-10, 8 + bob), label, 11, Color.WHITE, 20, HORIZONTAL_ALIGNMENT_CENTER, 0)


## Llave que suelta SUDO al revocar: tocarla o golpearla devuelve la habilidad antes de tiempo.
class Key extends Node2D:
	var boss: Node2D
	var player: Node2D
	var lockable := false
	var life := 5.0
	var t := 0.0
	var _got := false

	func _ready() -> void:
		add_to_group("enemies")
		add_to_group("boss_minion")
		z_index = 2
		U.add_hurtbox(self, Vector2(34, 34), Vector2(0, -16))

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
			return
		if player != null and is_instance_valid(player) and (player.global_position + Vector2(0, 12)).distance_to(global_position) < 34.0:
			_take()
		queue_redraw()

	func take_hit(_amount: int, _from: Vector2) -> void:
		_take()

	func _take() -> void:
		if _got:
			return
		_got = true
		if is_instance_valid(boss):
			boss.call("restore_player")
		GameFeel.parry_burst(get_parent(), global_position + Vector2(0, -16), 20.0)
		queue_free()

	func _draw() -> void:
		var bob := sin(t * 4.0) * 4.0 - 18.0
		draw_circle(Vector2(0, bob), 20.0, Color(1, 0.85, 0.3, 0.15 + 0.1 * sin(t * 8.0)))
		if U.spr(self, "props_3", Vector2(0, bob), 1.0, sin(t * 3.0) * 0.2):
			return
		draw_arc(Vector2(-6, bob), 6.0, 0, TAU, 12, Color(1, 0.85, 0.3), 3.0)
		draw_line(Vector2(0, bob), Vector2(14, bob), Color(1, 0.85, 0.3), 3.0)
		draw_line(Vector2(10, bob), Vector2(10, bob + 5), Color(1, 0.85, 0.3), 3.0)
		draw_line(Vector2(14, bob), Vector2(14, bob + 6), Color(1, 0.85, 0.3), 3.0)


# ====================================================================================
# FASE 3 · TERRA · LUNA · SOL
# ====================================================================================

## Astro que orbita a SUDO. Golpearlo lo apaga 6 s (no puede atacar).
class Planet extends Node2D:
	var boss: Node2D
	var kind := "terra"
	var lockable := false
	var off_left := 0.0
	var t := 0.0
	var size := 18.0
	var glow := 0.0

	func _ready() -> void:
		add_to_group("enemies")
		z_index = 4
		size = float({"terra": 18.0, "luna": 13.0, "sol": 22.0}[kind])
		U.add_hurtbox(self, Vector2(size * 2.2, size * 2.2), Vector2.ZERO)

	func active() -> bool:
		return off_left <= 0.0 and visible

	func take_hit(_amount: int, _from: Vector2) -> void:
		if not is_instance_valid(boss) or str(boss.get("state")) in ["final", "dead", "intro"]:
			return
		if off_left > 0.0:
			return
		off_left = 6.0
		GameFeel.flash(self, 0.12, Color.WHITE)
		GameFeel.parry_burst(get_parent(), global_position, 20.0)
		boss.call("planet_hit", self)

	func _process(delta: float) -> void:
		t += delta
		glow = maxf(0.0, glow - delta * 2.0)
		if off_left > 0.0:
			off_left -= delta
		queue_redraw()

	func _draw() -> void:
		var dim := off_left > 0.0
		var a := 0.45 if dim else 1.0
		var idx: int = {"terra": 0, "luna": 1, "sol": 2}[kind] + (3 if dim else 0)
		var sc := 1.0 + 0.35 * glow
		var rot := t * 0.5 if kind == "sol" else 0.0
		if kind == "sol" and not dim:
			draw_circle(Vector2.ZERO, 30.0 * sc, Color(SUN, 0.18))
		elif kind == "terra":
			draw_circle(Vector2.ZERO, 24.0 * sc, Color(EARTH, 0.15 * a))
		if U.spr(self, "planets_%d" % idx, Vector2.ZERO, sc, rot):
			if dim:
				U.text(self, Vector2(-30, -size - 10), "OFFLINE", 9, Color(1, 0.5, 0.5), 60, HORIZONTAL_ALIGNMENT_CENTER, 0)
			var nm: String = {"terra": "TERRA", "luna": "LUNA", "sol": "SOL"}[kind]
			U.text(self, Vector2(-30, size + 16), nm, 9, Color(1, 1, 1, 0.55 * a), 60, HORIZONTAL_ALIGNMENT_CENTER, 0)
			return
		match kind:
			"sol":
				var s := size * (1.0 + 0.4 * glow)
				for i in 10:
					var ang := t * 0.8 + TAU * i / 10.0
					draw_line(Vector2.from_angle(ang) * (s + 2), Vector2.from_angle(ang) * (s + 9 + 3 * sin(t * 6.0 + i)), Color(SUN, a), 3.0)
				draw_circle(Vector2.ZERO, s + 6, Color(SUN, 0.2 * a))
				draw_circle(Vector2.ZERO, s, Color(1.0, 0.55, 0.12, a))
				draw_circle(Vector2(-4, -4), s * 0.6, Color(1.0, 0.9, 0.45, a))
			"luna":
				draw_circle(Vector2.ZERO, size + 4, Color(MOON, 0.15 * a))
				draw_circle(Vector2.ZERO, size, Color(MOON, a))
				draw_circle(Vector2(-4, -3), 3.0, Color(0.6, 0.62, 0.7, a))
				draw_circle(Vector2(5, 4), 2.5, Color(0.6, 0.62, 0.7, a))
				draw_circle(Vector2(2, -6), 1.8, Color(0.6, 0.62, 0.7, a))
			_:
				draw_circle(Vector2.ZERO, size + 4, Color(EARTH, 0.18 * a))
				draw_circle(Vector2.ZERO, size, Color(0.2, 0.45, 0.9, a))
				draw_colored_polygon(PackedVector2Array([Vector2(-10, -8), Vector2(-2, -12), Vector2(3, -6), Vector2(-2, 2), Vector2(-9, 0)]), Color(0.3, 0.75, 0.35, a))
				draw_colored_polygon(PackedVector2Array([Vector2(4, 2), Vector2(12, 0), Vector2(10, 10), Vector2(3, 9)]), Color(0.3, 0.75, 0.35, a))
				draw_arc(Vector2.ZERO, size, -0.4, 0.9, 8, Color(1, 1, 1, 0.5 * a), 2.0)
		if dim:
			U.text(self, Vector2(-30, -size - 8), "OFFLINE", 9, Color(1, 0.5, 0.5), 60, HORIZONTAL_ALIGNMENT_CENTER, 0)
		var name_s: String = {"terra": "TERRA", "luna": "LUNA", "sol": "SOL"}[kind]
		U.text(self, Vector2(-30, size + 14), name_s, 9, Color(1, 1, 1, 0.55 * a), 60, HORIZONTAL_ALIGNMENT_CENTER, 0)


## Grieta de Terra: una línea en el piso que luego levanta rocas. Deja pilares que tapan la llamarada del Sol.
class Crack extends SHazard:
	var to := Vector2.ZERO         ## punto final (local)
	var warn := 0.8
	var rocks := 1
	var t := 0.0
	var _hit := false
	var _seed := 0

	func _ready() -> void:
		z_index = -1
		_seed = randi()

	func _process(delta: float) -> void:
		t += delta
		if t >= warn and not _hit:
			_hit = true
			z_index = 2
			for v in victims():
				_victim = v
				if U.dist_to_seg(player_feet() - global_position, Vector2.ZERO, to) < 26.0:
					hurt(2, true)
			_victim = null
			var n := int(to.length() / 90.0) + 1
			for i in n:
				var at := global_position + to * (float(i) + 0.5) / n
				var b := Burst.new()
				b.col = Color(0.75, 0.55, 0.35)
				b.count = 8
				b.speed = 260.0
				b.up_bias = 0.9
				get_parent().add_child(b)
				b.global_position = at
				GameFeel.dust(get_parent(), at, 3, Vector2.ZERO, 4.0, Vector2(18, 5))
				if Anim.ok("fxfire"):
					var an := Anim.new()
					an.prefix = "fxfire"
					an.k = 0.38
					an.fps = 16.0
					get_parent().add_child(an)
					an.global_position = at + Vector2(0, -14)
				var em := Embers.new()
				em.area = Rect2(-20, -6, 40, 12)
				em.emit_for = 0.6
				em.rate = 18.0
				get_parent().add_child(em)
				em.global_position = at
			for i in rocks:
				var p := RockPillar.new()
				get_parent().add_child(p)
				p.global_position = global_position + to * randf_range(0.45, 0.95)
		if t > warn + 0.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if t < warn:
			var k := t / warn
			U.zigzag(self, Vector2.ZERO, to * k, Color(1.0, 0.35, 0.05, 0.35 * k), 12.0, _seed, 8.0)
			U.zigzag(self, Vector2.ZERO, to * k, Color(0.35, 0.22, 0.12, 0.9), 4.0, _seed, 8.0)
			U.zigzag(self, Vector2.ZERO, to * k, Color(1.0, 0.65, 0.2, 0.6 + 0.4 * absf(sin(t * 14.0))), 2.0, _seed, 8.0)
		else:
			var e := clampf((t - warn) / 0.5, 0.0, 1.0)
			# la grieta queda brillando como lava y se enfría
			U.zigzag(self, Vector2.ZERO, to, Color(1.0, 0.4, 0.05, 0.5 * (1.0 - e)), 10.0, _seed, 8.0)
			U.zigzag(self, Vector2.ZERO, to, Color(1.0, 0.85, 0.4, 0.9 * (1.0 - e)), 2.5, _seed, 8.0)
			var n := int(to.length() / 34.0)
			for i in n:
				var p := to * (float(i) + 0.5) / n
				var h := 26.0 * sin(PI * clampf(e * 2.0 - float(i) / n, 0.0, 1.0))
				if h < 2.0:
					continue
				var pts := PackedVector2Array([p + Vector2(-12, 0), p + Vector2(-5, -h), p + Vector2(4, -h * 0.8), p + Vector2(12, 0)])
				draw_colored_polygon(pts, Color(0.5, 0.38, 0.26))
				draw_polyline(pts, Color(0.15, 0.1, 0.05), 2.0)


## Pilar de roca (decorado): si queda entre el Sol y el jugador, lo protege de la llamarada.
class RockPillar extends Node2D:
	var r := 24.0
	var life := 7.0
	var t := 0.0

	func _ready() -> void:
		add_to_group("sudo_rock")
		z_index = 1

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var up := clampf(t / 0.2, 0.0, 1.0) * clampf((life - t) / 0.4, 0.0, 1.0)
		var h := 54.0 * up
		if h < 3.0:
			return
		if U.spr_feet(self, "props_4", Vector2.ZERO, 1.0, Color.WHITE, false, up):
			return
		draw_colored_polygon(PackedVector2Array([Vector2(-20, 0), Vector2(-15, -h), Vector2(-4, -h - 8), Vector2(12, -h + 2), Vector2(20, 0)]), Color(0.48, 0.37, 0.27))
		draw_colored_polygon(PackedVector2Array([Vector2(-15, -h), Vector2(-4, -h - 8), Vector2(12, -h + 2), Vector2(0, -h + 6)]), Color(0.62, 0.5, 0.38))
		draw_polyline(PackedVector2Array([Vector2(-20, 0), Vector2(-15, -h), Vector2(-4, -h - 8), Vector2(12, -h + 2), Vector2(20, 0)]), Color(0.15, 0.1, 0.05), 2.0)


## Órbita de Terra: la Tierra se separa y da una vuelta completa a ras del piso. Parry la desvía.
class OrbitRock extends SHazard:
	var center := Vector2.ZERO
	var radius := 220.0
	var a0 := 0.0
	var dur := 2.6
	var t := 0.0
	var _done := false
	var _bounce := Vector2.ZERO

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		t += delta
		if _bounce != Vector2.ZERO:
			global_position += _bounce * delta
			_bounce *= 0.96
			if t > dur:
				queue_free()
			queue_redraw()
			return
		var k := clampf(t / dur, 0.0, 1.0)
		var a := a0 + TAU * k
		global_position = center + Vector2(cos(a) * radius, sin(a) * radius * 0.6)
		var hit_who: Node2D = null
		if not _done:
			for v in victims():
				_victim = v
				if player_body().distance_to(global_position + Vector2(0, 10)) < 32.0 and not bool(v.get("rolling")):
					hit_who = v
					break
			_victim = null
		if hit_who != null:
			_done = true
			_victim = hit_who
			var r := Final.parry_ok(hit_who, global_position)
			if r == 1:
				GameFeel.parry_burst(get_parent(), global_position, 26.0)
				_bounce = (global_position - hit_who.global_position).normalized() * 420.0
				if is_instance_valid(boss):
					boss.call("inject_context", "parry")
			else:
				hurt(2, false)
			_victim = null
		if t > dur:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 30.0, Color(EARTH, 0.18))
		ellipse(Vector2(0, 34), Vector2(22, 7), Color(0, 0, 0, 0.3))
		if U.spr(self, "planets_0", Vector2.ZERO, 1.25, t * 2.0):
			return
		draw_circle(Vector2.ZERO, 22.0, Color(0.2, 0.45, 0.9))
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -9), Vector2(-2, -15), Vector2(4, -7), Vector2(-3, 3), Vector2(-11, 0)]), Color(0.3, 0.75, 0.35))
		draw_colored_polygon(PackedVector2Array([Vector2(5, 3), Vector2(15, 0), Vector2(12, 12), Vector2(4, 11)]), Color(0.3, 0.75, 0.35))
		ellipse(Vector2(0, 34), Vector2(22, 7), Color(0, 0, 0, 0.3))


## Llamarada del Sol: rayo ancho que barre media arena. Se tapa detrás de un pilar de roca.
class Flare extends SHazard:
	var sun: Node2D
	var from_a := 0.0
	var to_a := 1.6
	var charge := 0.9
	var sweep := 2.2
	var width := 58.0
	var length := 1400.0
	var t := 0.0
	var _cd := 0.0
	var _origin := Vector2.ZERO
	var _trail := 0.0

	func _ready() -> void:
		z_index = 5

	func _angle() -> float:
		return lerpf(from_a, to_a, clampf((t - charge) / sweep, 0.0, 1.0))

	func _process(delta: float) -> void:
		t += delta
		_cd = maxf(0.0, _cd - delta)
		if sun != null and is_instance_valid(sun):
			_origin = sun.global_position
		global_position = _origin
		if t > charge and t < charge + sweep:
			_trail -= delta
			if _trail <= 0.0 and is_inside_tree():
				_trail = 0.09
				var d := Vector2.from_angle(_angle())
				var at := _origin + d * randf_range(220.0, 760.0)
				var sc := Scorch.new()
				sc.r = 34.0
				sc.col = Color(1.0, 0.5, 0.1)
				sc.life = 2.2
				get_parent().add_child(sc)
				sc.global_position = at
				var em := Embers.new()
				em.emit_for = 0.25
				em.rate = 50.0
				get_parent().add_child(em)
				em.global_position = at
		if t > charge and t < charge + sweep:
			var dir := Vector2.from_angle(_angle())
			for v in victims():
				_victim = v
				var p := player_body() - _origin
				var along := p.dot(dir)
				if along > 0.0 and absf(p.dot(dir.orthogonal())) < width * 0.5 + 8.0 and not _shadowed() and cd_ok("flare", 0.6):
					hurt(2, true)
			_victim = null
		if t > charge + sweep + 0.3:
			queue_free()
		queue_redraw()

	func _shadowed() -> bool:
		var pb := player_body()
		for r in get_tree().get_nodes_in_group("sudo_rock"):
			var rp: Vector2 = (r as Node2D).global_position + Vector2(0, -24)
			if rp.distance_to(_origin) < pb.distance_to(_origin) and U.dist_to_seg(rp, _origin, pb) < 30.0:
				return true
		return false

	func _draw() -> void:
		var dir := Vector2.from_angle(_angle())
		var side := dir.orthogonal()
		_draw_beam(dir, side)
		# el sol animado encima de la boca del rayo (carga: cuadros 0-3, disparo: 4-6)
		var fr := -1
		var k := 1.0
		if t < charge:
			fr = int(t * 8.0) % 4
			k = 0.7 + 0.4 * clampf(t / charge, 0.0, 1.0)
		elif t < charge + sweep:
			fr = [4, 5, 6, 5][int(t * 10.0) % 4]
			k = 1.15
		if fr >= 0:
			var tex: Texture2D = Spr.tex("boss_sudo_fxsun_%d" % fr)
			if tex:
				var sz := tex.get_size()
				draw_set_transform(Vector2.ZERO, dir.angle(), Vector2(k, k))
				draw_texture(tex, -sz * 0.5)
				draw_set_transform(Vector2.ZERO)

	func _draw_beam(dir: Vector2, side: Vector2) -> void:
		if t < charge:
			var k := t / charge
			draw_line(Vector2.ZERO, dir * length, Color(SUN, 0.25 * absf(sin(t * 18.0))), width * k)
			draw_dashed_line(Vector2.ZERO, dir * length, Color(1, 0.9, 0.5, 0.8), 2.0, 14.0)
			for i in 3:
				draw_circle(Vector2.ZERO, (14.0 + 30.0 * k) * (1.0 + 0.5 * i), Color(SUN, 0.12 * k))
			draw_circle(Vector2.ZERO, 10.0 + 20.0 * k, Color(1, 0.95, 0.6, 0.7 * k))
		elif t < charge + sweep:
			var w := width * (1.0 + 0.1 * sin(t * 40.0))
			# halo de calor, capas de fuego y núcleo blanco
			draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.3, 0.05, 0.25), w * 2.4)
			draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.45, 0.1, 0.5), w * 1.5)
			draw_line(Vector2.ZERO, dir * length, Color(SUN, 0.95), w)
			draw_line(Vector2.ZERO, dir * length, Color(1, 1, 0.85), w * 0.35)
			# ondas de calor que corren por el rayo
			for i in 9:
				var d := fmod(t * 900.0 + i * 160.0, length)
				var o := side * sin(t * 25.0 + i) * w * 0.55
				draw_line(dir * d + o, dir * (d + 70.0) + o, Color(1, 1, 0.9, 0.55), 3.0)
			# boca del rayo en el sol
			draw_circle(Vector2.ZERO, w * 0.9, Color(1, 0.95, 0.7, 0.9))
			draw_circle(Vector2.ZERO, w * 1.4, Color(SUN, 0.3))
		else:
			var e := clampf((t - charge - sweep) / 0.3, 0.0, 1.0)
			draw_line(Vector2.ZERO, dir * length, Color(SUN, 0.6 * (1.0 - e)), width * (1.0 - e))


## Eclipse: la Luna tapa al Sol y la arena queda a oscuras salvo un círculo de luz alrededor del jugador.
class Eclipse extends Node2D:
	var player: Node2D
	var life := 4.5
	var t := 0.0
	var _stars: Array = []

	func _ready() -> void:
		z_index = 40
		add_to_group("barrage_fx")
		for i in 60:
			_stars.append([Vector2(randf_range(-900, 900), randf_range(-600, 600)), randf() * TAU, randf_range(1.0, 2.4)])

	func fizzle() -> void:
		if t < life - 0.4:
			t = life - 0.4

	func _process(delta: float) -> void:
		t += delta
		if player != null and is_instance_valid(player):
			global_position = player.global_position + Vector2(0, -20)
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(minf(t / 0.5, (life - t) / 0.4), 0.0, 1.0)
		var hole := 150.0 + sin(t * 3.0) * 6.0
		for i in 16:
			var r := hole + 40.0 + i * 120.0
			draw_arc(Vector2.ZERO, r, 0, TAU, 72, Color(0.01, 0.01, 0.05, 0.9 * a), 122.0)
		for i in 5:
			var r := hole + i * 8.0
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.01, 0.01, 0.05, 0.18 * (i + 1) * a), 8.0)
		# estrellas que aparecen en la oscuridad
		for st in _stars:
			var p: Vector2 = st[0]
			if p.length() < hole + 30.0:
				continue
			var tw := 0.5 + 0.5 * sin(t * 4.0 + float(st[1]))
			draw_circle(p, float(st[2]), Color(0.85, 0.9, 1.0, 0.8 * a * tw))
		# borde del círculo de luz: tenue halo lunar
		draw_arc(Vector2.ZERO, hole - 4.0, 0, TAU, 64, Color(0.7, 0.8, 1.0, 0.25 * a), 3.0)


# ====================================================================================
# LLUVIAS DE FASE
# ====================================================================================

## Cursor fantasma que cruza un carril entero (DEPLOY A PRODUCCIÓN). No se bloquea; rodar o salir del carril.
class LaneDash extends SHazard:
	var area := Rect2()
	var y := 0.0
	var warn := 0.75
	var speed := 1500.0
	var dir := 1.0
	var t := 0.0
	var x := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = 3
		x = area.position.x - 40.0 if dir > 0 else area.end.x + 40.0

	func _process(delta: float) -> void:
		t += delta
		if t > warn:
			x += speed * dir * delta
			for v in victims():
				_victim = v
				var f := player_feet()
				if absf(f.y - y) < 26.0 and absf(f.x - x) < 40.0 and first_hit():
					_hit = true
					hurt(2, true)
			_victim = null
		if t > warn + area.size.x / speed + 0.3:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var x0 := area.position.x
		var x1 := area.end.x
		if t < warn:
			var blink := 0.4 + 0.6 * absf(sin(t * 14.0))
			draw_rect(Rect2(x0, y - 22, x1 - x0, 44), Color(0.8, 0.8, 0.9, 0.12 * blink))
			draw_dashed_line(Vector2(x0, y), Vector2(x1, y), Color(CURSOR, 0.7 * blink), 2.0, 12.0)
			U.text(self, Vector2(x0 + 8 if dir > 0 else x1 - 60, y - 8), "Tab >>" if dir > 0 else "<< Tab", 13, Color(1, 1, 1, blink))
		else:
			var tail := x - dir * 260.0
			draw_line(Vector2(tail, y), Vector2(x, y), Color(0.8, 0.8, 0.9, 0.3), 30.0)
			if U.spr(self, "projectiles_4", Vector2(x, y - 3), 1.0, 0.0, Color.WHITE, dir < 0):
				return
			draw_rect(Rect2(x - 5, y - 20, 10, 34), CURSOR)
			draw_rect(Rect2(x - 5, y - 20, 10, 34), Color(1, 1, 1, 0.8), false, 2.0)


# ====================================================================================
# ASTRA: cinemática del duelo final
# ====================================================================================

## Barras negras de cine (arriba y abajo).
class CinemaBars extends CanvasLayer:
	var k := 0.0
	var _c: Control
	var _tw: Tween

	func _ready() -> void:
		layer = 8
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_paint)
		add_child(_c)
		_tw = create_tween()
		_tw.tween_property(self, "k", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func close() -> void:
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween()
		_tw.tween_property(self, "k", 0.0, 0.4)
		_tw.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		_c.queue_redraw()

	func _paint() -> void:
		var h := 86.0 * k
		_c.draw_rect(Rect2(0, 0, 1280, h), Color.BLACK)
		_c.draw_rect(Rect2(0, 720 - h, 1280, h), Color.BLACK)


## Espiral gigante de estrellas (como una galaxia) que gira detrás de SUDO.
## grow: 0..1 tamaño; collapse: 0..1 las estrellas se van al centro (se vuelve la bola de luz).
class StarSpiral extends Node2D:
	var radius := 1300.0
	var grow := 0.0
	var collapse := 0.0
	var alpha := 1.0
	var spin := 0.5
	var arms := 5
	var t := 0.0
	var _stars: Array = []   # [brazo, s (0..1), jitter, tamaño, color, fase]

	func _ready() -> void:
		z_index = -3
		var cols := [Color(1, 1, 1), Color(0.75, 0.85, 1.0), Color(0.75, 0.6, 1.0), Color(1.0, 0.9, 0.6), Color(0.6, 1.0, 0.95)]
		for i in 900:
			var s := pow(randf(), 0.7)
			_stars.append([randi() % arms, s, randf_range(-0.22, 0.22), randf_range(1.2, 3.8) * (1.4 - s * 0.6), cols[randi() % cols.size()], randf() * TAU])

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var R := radius * grow * (1.0 - collapse)
		var rot := t * spin + collapse * 6.0
		# núcleo
		for i in 6:
			draw_circle(Vector2.ZERO, (60.0 + i * 26.0) * grow * (1.0 - collapse * 0.6) + 8.0, Color(0.7, 0.75, 1.0, 0.07 * alpha))
		draw_circle(Vector2.ZERO, 26.0 * grow + 30.0 * collapse, Color(1, 1, 1, 0.85 * alpha))
		# brazos de la galaxia: bandas de luz suaves por debajo de las estrellas
		for arm in arms:
			var pts := PackedVector2Array()
			for k in 40:
				var s := float(k) / 39.0
				var ang := float(arm) * TAU / arms + s * 4.2 + rot
				pts.append(Vector2(cos(ang), sin(ang) * 0.82) * (R * s))
			var cband := Color(0.55, 0.45, 1.0) if arm % 2 == 0 else Color(0.45, 0.7, 1.0)
			draw_polyline(pts, Color(cband, 0.07 * alpha), 70.0 * grow)
			draw_polyline(pts, Color(cband, 0.12 * alpha), 26.0 * grow)
			draw_polyline(pts, Color(1, 1, 1, 0.1 * alpha), 6.0)
		for st in _stars:
			var s: float = st[1]
			var ang: float = float(st[0]) * TAU / arms + s * 4.2 + rot + float(st[2]) * (1.0 - s * 0.5)
			var p := Vector2(cos(ang), sin(ang) * 0.82) * (R * s)
			var tw := 0.6 + 0.4 * sin(t * 5.0 + float(st[5]))
			var c: Color = st[4]
			var sz: float = float(st[3]) * (1.0 + collapse)
			var a := alpha * tw * clampf(grow * 2.0, 0.0, 1.0)
			draw_circle(p, sz, Color(c, a))
			if sz > 2.3:
				draw_line(p - Vector2(sz * 2.5, 0), p + Vector2(sz * 2.5, 0), Color(c, a * 0.7), 1.0)
				draw_line(p - Vector2(0, sz * 2.5), p + Vector2(0, sz * 2.5), Color(c, a * 0.7), 1.0)


## La bola de luz del Astra (la espiral concentrada). Solo visual: el boss la mueve.
class AstraBall extends Node2D:
	var r := 46.0
	var t := 0.0
	var tint := Color(0.8, 0.85, 1.0)

	func _ready() -> void:
		z_index = 12

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		for i in 5:
			draw_circle(Vector2.ZERO, r * (1.0 + 0.35 * i) + sin(t * 8.0 + i) * 3.0, Color(tint, 0.12))
		var nm := "fxcosmic_2" if Spr.tex("boss_sudo_fxcosmic_2") else "projectiles_6"
		var tex: Texture2D = Spr.tex("boss_sudo_" + nm)
		if tex:
			var k := r * (2.6 if nm == "fxcosmic_2" else 2.1) / tex.get_size().x
			U.spr(self, nm, Vector2.ZERO, k, t * 2.5)
			for i in 10:
				var a2 := t * 2.0 + TAU * i / 10.0
				draw_circle(Vector2.from_angle(a2) * r * 1.6, 2.0, Color(1, 1, 1, 0.8))
			return
		draw_circle(Vector2.ZERO, r, Color(tint.lightened(0.3), 0.95))
		draw_circle(Vector2.ZERO, r * 0.6, Color(1, 1, 1))
		for i in 3:
			var a0 := t * 4.0 + TAU * i / 3.0
			var pts := PackedVector2Array()
			for k in 12:
				var s := float(k) / 11.0
				pts.append(Vector2.from_angle(a0 + s * 3.0) * r * (0.3 + 1.1 * s))
			draw_polyline(pts, Color(0.75, 0.6, 1.0, 0.8), 3.0)
		for i in 10:
			var a := t * 2.0 + TAU * i / 10.0
			draw_circle(Vector2.from_angle(a) * r * 1.6, 2.0, Color(1, 1, 1, 0.8))


## Choque de rayos del QTE final: el rayo del jugador contra la espiral; `k` = cuánto empuja el jugador.
class Clash extends Node2D:
	var a := Vector2.ZERO      ## jugador (global)
	var b := Vector2.ZERO      ## boss (global)
	var k := 0.35
	var t := 0.0
	var ball: Node2D

	func _ready() -> void:
		z_index = 11

	func _process(delta: float) -> void:
		t += delta
		var mid := a.lerp(b, clampf(k, 0.0, 1.0) * 0.85 + 0.05)
		if ball != null and is_instance_valid(ball):
			ball.global_position = ball.global_position.lerp(mid, minf(1.0, delta * 10.0))
		queue_redraw()

	func _draw() -> void:
		var mid := a.lerp(b, clampf(k, 0.0, 1.0) * 0.85 + 0.05) - global_position
		var pa := a - global_position
		var pb := b - global_position
		var w := 16.0 + 4.0 * sin(t * 30.0)
		draw_line(pa, mid, Color(0.5, 0.85, 1.0, 0.35), w * 2.2)
		draw_line(pa, mid, Color(0.75, 0.95, 1.0), w)
		draw_line(pa, mid, Color(1, 1, 1), w * 0.35)
		draw_line(mid, pb, Color(0.7, 0.55, 1.0, 0.35), w * 2.6)
		draw_line(mid, pb, Color(0.85, 0.75, 1.0), w * 1.2)
		for i in 8:
			var ang := t * 9.0 + TAU * i / 8.0
			draw_line(mid, mid + Vector2.from_angle(ang) * (30.0 + 14.0 * sin(t * 20.0 + i)), Color(1, 1, 1, 0.8), 2.0)


## Aviso de botón (QTE). mode "timing": aro que se cierra, hay que pulsar con el aro en la zona verde.
## mode "mash": machacar el botón para llenar la barra antes del tiempo. Usa tiempo REAL (va en cámara lenta).
## Al terminar emite `done(ok)`. `pressed` se emite en cada pulsación correcta (para animar).
class Qte extends CanvasLayer:
	signal done(ok: bool)
	signal pressed

	var mode := "timing"
	var action := "roll"
	var title := "¡ESQUIVA!"
	var dur := 1.2               ## timing: lo que tarda el aro en cerrarse
	var win_from := 0.6          ## timing: ventana buena (fracción de dur)
	var win_to := 0.86
	var limit := 4.0             ## mash: tiempo máximo
	var gain := 0.075            ## mash: por pulsación
	var decay := 0.22            ## mash: lo que baja por segundo
	var meter := 0.3
	var result := 0              ## 0 en curso, 1 bien, -1 mal
	var _t0 := 0
	var _el_t := 0.0
	var _end_t := 0.0
	var _c: Control

	func _ready() -> void:
		layer = 9
		process_mode = Node.PROCESS_MODE_ALWAYS
		_t0 = Time.get_ticks_msec()
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_paint)
		add_child(_c)

	## Tiempo transcurrido sin cámara lenta. Cada cuadro cuenta como máximo 1/30 s: si el juego
	## se traba un momento, la ventana del QTE no se "salta" (importante en PCs lentos).
	func _el() -> float:
		return _el_t

	func _process(delta: float) -> void:
		var real_dt := minf(delta / maxf(0.01, Engine.time_scale), 1.0 / 30.0)
		_el_t += real_dt
		var e := _el()
		if result != 0:
			if e - _end_t > 0.3:
				queue_free()
			_c.queue_redraw()
			return
		if mode == "timing":
			var k := e / dur
			if Input.is_action_just_pressed(action):
				pressed.emit()
				_finish(k >= win_from and k <= win_to)
			elif k > win_to + 0.02:
				_finish(false)
		else:
			if Input.is_action_just_pressed(action):
				meter += gain
				pressed.emit()
			meter = maxf(0.0, meter - decay * real_dt)
			if meter >= 1.0:
				meter = 1.0
				_finish(true)
			elif e > limit:
				_finish(false)
		_c.queue_redraw()

	func _finish(ok: bool) -> void:
		result = 1 if ok else -1
		_end_t = _el()
		done.emit(ok)

	func _paint() -> void:
		var f := ThemeDB.fallback_font
		var e := _el()
		var c := Vector2(640, 470)
		var key := GameState.btn(action) if GameState else action
		var col := Color(1, 1, 1)
		if result == 1:
			col = Color(0.5, 1.0, 0.6)
		elif result == -1:
			col = Color(1, 0.35, 0.3)
		var pop := 1.0 + (0.25 * clampf(1.0 - (e - _end_t) / 0.3, 0.0, 1.0) if result != 0 else 0.0)
		_c.draw_set_transform(c, 0.0, Vector2(pop, pop))
		_c.draw_string_outline(f, Vector2(-300, -96), title, HORIZONTAL_ALIGNMENT_CENTER, 600, 40, 10, Color(0, 0, 0, 0.9))
		_c.draw_string(f, Vector2(-300, -96), title, HORIZONTAL_ALIGNMENT_CENTER, 600, 40, Color(1, 0.95, 0.6) if result == 0 else col)
		if mode == "timing":
			var k := clampf(e / dur, 0.0, 1.0) if result == 0 else clampf(_end_t / dur, 0.0, 1.0)
			var r_now := lerpf(120.0, 30.0, k)
			var r_a := lerpf(120.0, 30.0, win_from)
			var r_b := lerpf(120.0, 30.0, win_to)
			_c.draw_arc(Vector2.ZERO, (r_a + r_b) * 0.5, 0, TAU, 48, Color(0.3, 1.0, 0.45, 0.35), r_a - r_b)
			_c.draw_arc(Vector2.ZERO, r_now, 0, TAU, 48, col, 5.0)
		else:
			var bw := 420.0
			_c.draw_rect(Rect2(-bw * 0.5, 52, bw, 22), Color(0, 0, 0, 0.75))
			_c.draw_rect(Rect2(-bw * 0.5, 52, bw * meter, 22), Color(0.6, 0.85, 1.0))
			_c.draw_rect(Rect2(-bw * 0.5, 52, bw, 22), Color(1, 1, 1, 0.8), false, 2.0)
			var left := maxf(0.0, limit - e) if result == 0 else 0.0
			_c.draw_string(f, Vector2(-bw * 0.5, 96), "%.1f s" % left, HORIZONTAL_ALIGNMENT_CENTER, bw, 16, Color(1, 1, 1, 0.8))
		# botón
		var bs := 1.0 + (0.12 * absf(sin(e * 18.0)) if mode == "mash" and result == 0 else 0.0)
		_c.draw_circle(Vector2.ZERO, 30.0 * bs, Color(0.08, 0.08, 0.12, 0.95))
		_c.draw_arc(Vector2.ZERO, 30.0 * bs, 0, TAU, 32, col, 3.0)
		var fs := 22 if key.length() <= 2 else 14
		_c.draw_string(f, Vector2(-60, 8), key, HORIZONTAL_ALIGNMENT_CENTER, 120, fs, col)
		_c.draw_set_transform(Vector2.ZERO)


## Destello blanco a pantalla completa (golpe final o muerte instantánea).
class WhiteOut extends CanvasLayer:
	var life := 0.9
	var hold := 0.15
	var col := Color.WHITE
	var t := 0.0
	var _r: ColorRect

	func _ready() -> void:
		layer = 10
		process_mode = Node.PROCESS_MODE_ALWAYS
		_r = ColorRect.new()
		_r.size = Vector2(1280, 720)
		_r.color = col
		_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_r)

	func _process(delta: float) -> void:
		t += delta / maxf(0.05, Engine.time_scale)
		_r.color.a = 1.0 if t < hold else clampf(1.0 - (t - hold) / (life - hold), 0.0, 1.0)
		if t > life:
			queue_free()


## Polvo de estrellas: partículas que suben desde el cuerpo de SUDO mientras se desvanece.
class StarDust extends Node2D:
	var area := Rect2(-40, -200, 80, 200)
	var emit_for := 2.4
	var t := 0.0
	var _p: Array = []   # [pos, vel, life, size, color]
	var _acc := 0.0

	func _ready() -> void:
		z_index = 14

	func _process(delta: float) -> void:
		t += delta
		if t < emit_for:
			_acc += delta * 90.0
			while _acc >= 1.0:
				_acc -= 1.0
				var cols := [Color(1, 1, 1), Color(0.8, 0.85, 1.0), Color(0.75, 0.6, 1.0), Color(1, 0.9, 0.6)]
				_p.append([Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)),
					Vector2(randf_range(-30, 30), randf_range(-90, -30)), randf_range(0.8, 1.8), randf_range(1.0, 2.6), cols[randi() % cols.size()]])
		for p in _p:
			p[0] += p[1] * delta
			p[1] *= 0.99
			p[2] -= delta
		_p = _p.filter(func(p: Array) -> bool: return float(p[2]) > 0.0)
		if t > emit_for and _p.is_empty():
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for p in _p:
			var a := clampf(float(p[2]), 0.0, 1.0)
			var c: Color = p[4]
			draw_circle(p[0], p[3], Color(c, a))
			if float(p[3]) > 2.0:
				draw_line(p[0] - Vector2(5, 0), p[0] + Vector2(5, 0), Color(c, a * 0.6), 1.0)
				draw_line(p[0] - Vector2(0, 5), p[0] + Vector2(0, 5), Color(c, a * 0.6), 1.0)


## El clicker que se le cae a SUDO al final.
class Clicker extends Node2D:
	var vel := Vector2(60, -260)
	var ground := 0.0
	var t := 0.0
	var spin := 9.0
	var _rest := false

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		t += delta
		if not _rest:
			vel.y += 900.0 * delta
			position += vel * delta
			rotation += spin * delta
			if position.y >= ground and vel.y > 0.0:
				position.y = ground
				vel = Vector2(vel.x * 0.4, -vel.y * 0.3)
				spin *= 0.4
				if absf(vel.y) < 40.0:
					_rest = true
					rotation = 0.3
		queue_redraw()

	func _draw() -> void:
		if U.spr(self, "props_5", Vector2.ZERO, 0.8):
			return
		draw_rect(Rect2(-9, -4, 18, 8), Color(0.1, 0.1, 0.12))
		draw_rect(Rect2(-9, -4, 18, 8), Color(0.5, 0.5, 0.55), false, 1.0)
		draw_circle(Vector2(-4, 0), 1.6, Color(1, 0.2, 0.2) if fmod(t * 3.0, 1.0) > 0.5 else Color(0.3, 0.05, 0.05))


# ====================================================================================
# EFECTOS ÉPICOS (comunes): destellos, chispas, brasas, quemaduras, fantasmas, carga
# ====================================================================================

## Destello de color a pantalla completa (golpes grandes). No bloquea nada.
class Flash extends CanvasLayer:
	var col := Color(1, 1, 1)
	var peak := 0.35
	var life := 0.35
	var t := 0.0
	var _r: ColorRect

	func _ready() -> void:
		layer = 4
		_r = ColorRect.new()
		_r.size = Vector2(1280, 720)
		_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_r.color = Color(col, peak)
		add_child(_r)

	func _process(delta: float) -> void:
		t += delta
		_r.color = Color(col, peak * clampf(1.0 - t / life, 0.0, 1.0))
		if t > life:
			queue_free()


## Ráfaga de chispas con gravedad (rayos, choques, impactos).
class Burst extends Node2D:
	var col := GREEN_HI
	var count := 18
	var speed := 320.0
	var gravity := 520.0
	var life := 0.7
	var up_bias := 0.6      ## 0 = en todas direcciones, 1 = hacia arriba
	var t := 0.0
	var _p: Array = []     # [pos, vel, size]

	func _ready() -> void:
		z_index = 9
		for i in count:
			var a := randf() * TAU
			var d := Vector2.from_angle(a)
			d.y = lerpf(d.y, -absf(d.y), up_bias)
			_p.append([Vector2.ZERO, d.normalized() * speed * randf_range(0.35, 1.0), randf_range(1.5, 3.5)])

	func _process(delta: float) -> void:
		t += delta
		for p in _p:
			p[1].y += gravity * delta
			p[0] += p[1] * delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - t / life, 0.0, 1.0)
		for p in _p:
			var v: Vector2 = p[1]
			draw_line(p[0], p[0] - v * 0.03, Color(col, a), float(p[2]))
			draw_circle(p[0], float(p[2]) * 0.6, Color(1, 1, 1, a))


## Brasas o chispas que suben despacio desde una zona (se apagan solas).
class Embers extends Node2D:
	var area := Rect2(-40, -10, 80, 20)
	var col := Color(1.0, 0.55, 0.15)
	var rate := 40.0
	var emit_for := 1.0
	var t := 0.0
	var _acc := 0.0
	var _p: Array = []   # [pos, vel, life, size]

	func _ready() -> void:
		z_index = 8

	func _process(delta: float) -> void:
		t += delta
		if t < emit_for:
			_acc += delta * rate
			while _acc >= 1.0:
				_acc -= 1.0
				_p.append([Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)),
					Vector2(randf_range(-20, 20), randf_range(-90, -30)), randf_range(0.5, 1.3), randf_range(1.5, 3.0)])
		for p in _p:
			p[0] += p[1] * delta
			p[1].x += sin(t * 6.0 + p[0].y * 0.05) * 30.0 * delta
			p[2] -= delta
		_p = _p.filter(func(p: Array) -> bool: return float(p[2]) > 0.0)
		if t > emit_for and _p.is_empty():
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for p in _p:
			var a := clampf(float(p[2]) * 1.5, 0.0, 1.0)
			draw_circle(p[0], float(p[3]) * 2.0, Color(col, 0.18 * a))
			draw_circle(p[0], float(p[3]), Color(col.lightened(0.3), a))


## Marca quemada en el piso que se enfría poco a poco (solo visual).
class Scorch extends Node2D:
	var r := 46.0
	var col := GREEN
	var life := 3.0
	var t := 0.0
	var _cracks: Array = []

	func _ready() -> void:
		z_index = -3
		for i in 7:
			_cracks.append([randf() * TAU, randf_range(0.7, 1.4)])

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - t / life, 0.0, 1.0)
		var hot := clampf(1.0 - t / (life * 0.4), 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 24:
			var ang := TAU * i / 24.0
			pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.5))
		draw_colored_polygon(pts, Color(0.05, 0.05, 0.06, 0.55 * a))
		for c in _cracks:
			var d := Vector2.from_angle(c[0])
			var e := d * r * float(c[1])
			e.y *= 0.5
			draw_line(Vector2.ZERO, e, Color(col.lightened(0.2), 0.8 * hot * a), 2.0)
			draw_line(Vector2.ZERO, e * 0.6, Color(1, 1, 1, 0.6 * hot * a), 1.0)
		pts.append(pts[0])
		draw_polyline(pts, Color(col, 0.5 * hot * a), 2.0)


## Copia fantasma de la pose del boss (al embestir o teletransportarse).
class Ghost extends Node2D:
	var tex: Texture2D
	var tint := Color(0.45, 0.75, 1.0, 0.7)
	var flip := false
	var life := 0.3
	var t := 0.0

	func _ready() -> void:
		z_index = 0

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if tex == null:
			return
		var sz := tex.get_size()
		var a := tint.a * clampf(1.0 - t / life, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
		draw_texture(tex, Vector2(-sz.x * 0.5, -sz.y), Color(tint, a))
		draw_set_transform(Vector2.ZERO)


## Carga: partículas que se juntan en un punto y un brillo que crece (antes de un golpe grande).
class Charge extends Node2D:
	var col := GREEN_HI
	var dur := 0.6
	var radius := 120.0
	var follow: Node2D           ## si existe, sigue a este nodo + offset
	var offset := Vector2.ZERO
	var t := 0.0
	var _p: Array = []   # [ángulo, distancia inicial, retraso]

	func _ready() -> void:
		z_index = 12
		for i in 26:
			_p.append([randf() * TAU, randf_range(0.6, 1.0) * radius, randf_range(0.0, 0.5)])

	func _process(delta: float) -> void:
		t += delta
		if follow != null and is_instance_valid(follow):
			global_position = follow.global_position + offset
		if t > dur + 0.15:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / dur, 0.0, 1.0)
		for p in _p:
			var s := clampf((t - float(p[2]) * dur) / (dur * 0.6), 0.0, 1.0)
			if s <= 0.0 or s >= 1.0:
				continue
			var d := Vector2.from_angle(float(p[0]) + s * 1.5)
			var a := d * float(p[1]) * (1.0 - s)
			draw_line(a, a - d * 14.0 * (1.0 - s), Color(col, 0.8), 2.0)
		for i in 3:
			draw_circle(Vector2.ZERO, (6.0 + 22.0 * k) * (1.0 + 0.4 * i), Color(col, 0.12 * k))
		draw_circle(Vector2.ZERO, 4.0 + 8.0 * k, Color(1, 1, 1, 0.9 * k))
		if t > dur:
			var e := clampf((t - dur) / 0.15, 0.0, 1.0)
			draw_arc(Vector2.ZERO, 20.0 + 80.0 * e, 0, TAU, 32, Color(col, 1.0 - e), 4.0)


## Anillo de onda solo visual (grueso, con brillo), para acompañar golpes.
class Ring extends Node2D:
	var col := GREEN_HI
	var max_r := 260.0
	var life := 0.5
	var width := 10.0
	var flat := 0.5
	var t := 0.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / life, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var r := max_r * e
		var a := 1.0 - k
		var pts := PackedVector2Array()
		for i in 49:
			var ang := TAU * i / 48.0
			pts.append(Vector2(cos(ang) * r, sin(ang) * r * flat))
		draw_polyline(pts, Color(col, 0.35 * a), width * 2.2)
		draw_polyline(pts, Color(col.lightened(0.3), 0.9 * a), width * (1.0 - k * 0.6))
		draw_polyline(pts, Color(1, 1, 1, 0.8 * a), 2.0)


## Líneas de velocidad a pantalla completa hacia un punto (embestidas, ASTRA).
class SpeedLines extends CanvasLayer:
	var life := 0.45
	var col := Color(1, 1, 1, 0.5)
	var t := 0.0
	var _c: Control
	var _l: Array = []

	func _ready() -> void:
		layer = 3
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_paint)
		add_child(_c)
		for i in 46:
			_l.append([randf() * TAU, randf_range(380.0, 520.0), randf_range(60.0, 220.0), randf_range(1.0, 3.0)])

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
		_c.queue_redraw()

	func _paint() -> void:
		var a := col.a * clampf(1.0 - t / life, 0.0, 1.0)
		var c := Vector2(640, 360)
		for l in _l:
			var d := Vector2.from_angle(float(l[0]))
			var r0: float = float(l[1]) - fmod(t * 900.0, 120.0)
			_c.draw_line(c + d * r0, c + d * (r0 + float(l[2])), Color(col, a), float(l[3]))


## Efecto animado por cuadros (hojas boss_sudo_fx*_0..7 de la ronda épica).
## Cada cuadro trae su ancla en el centro del lienzo ("ground": abajo al centro).
class Anim extends Node2D:
	var prefix := "fxfire"
	var frames: Array = [0, 1, 2, 3, 4, 5, 6, 7]
	var fps := 14.0
	var k := 1.0
	var ground := false
	var loop := false
	var rot := 0.0
	var tint := Color.WHITE
	var follow: Node2D
	var offset := Vector2.ZERO
	var glow := Color(0, 0, 0, 0)     ## halo de color debajo (alfa 0 = sin halo)
	var life := 0.0                   ## > 0: se borra a los `life` s (para los que van en bucle)
	var t := 0.0

	static func ok(pre: String) -> bool:
		return Spr.tex("boss_sudo_%s_0" % pre) != null

	func _ready() -> void:
		z_index = 10

	func _process(delta: float) -> void:
		t += delta
		if follow != null and is_instance_valid(follow):
			global_position = follow.global_position + offset
		if (not loop and int(t * fps) >= frames.size()) or (life > 0.0 and t > life):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var i := int(t * fps)
		i = i % frames.size() if loop else mini(i, frames.size() - 1)
		var tex: Texture2D = Spr.tex("boss_sudo_%s_%d" % [prefix, int(frames[i])])
		if tex == null:
			return
		var sz := tex.get_size()
		if glow.a > 0.0:
			var gr := maxf(sz.x, sz.y) * 0.45 * k
			var c := Vector2(0, -sz.y * 0.35 * k) if ground else Vector2.ZERO
			for j in 3:
				draw_circle(c, gr * (0.6 + 0.3 * j), Color(glow, glow.a * (0.5 - 0.15 * j)))
		draw_set_transform(Vector2.ZERO, rot, Vector2(k, k))
		draw_texture(tex, Vector2(-sz.x * 0.5, -sz.y if ground else -sz.y * 0.5), tint)
		draw_set_transform(Vector2.ZERO)

