extends RefCounted
## Barras de vida de los bosses: una por boss, cada una con la forma de su mecánica.
## Sin class_name: cargar con preload("res://scripts/combat/boss_hud.gd") y crear con make(kind, boss).
## Todas comparten Base (marco, nombre, fases, barra con "chip", destello al recibir daño,
## temblor, llenado inicial y aviso de punto débil x2); cada una dibuja su panel en _mech().

const SyntaxFx := preload("res://scripts/combat/boss_syntax_fx.gd")

const W := 680.0
const H := 96.0
## Umbrales de cambio de fase (fracción de vida), los mismos de los bosses.
const PHASE_AT := [0.6, 0.3]


static func make(kind: String, boss: Node) -> Control:
	var p: Base
	match kind:
		"bsod": p = Bsod.new()
		"div0": p = Div0.new()
		"syntax": p = Syntax.new()
		"stack": p = Stack.new()
		"judge": p = Judge.new()
		"tex": p = Tex.new()
		"kp": p = Kp.new()
		_: p = Deadbeef.new()
	p.boss = boss
	p.position = Vector2((1280.0 - W) * 0.5, 6)
	return p


## Ayudas de dibujo (pixel art: bordes biselados, texto con contorno, iconos).
class K extends RefCounted:
	static func bevel(ci: CanvasItem, r: Rect2, face: Color, light: Color, dark: Color, w: float = 2.0) -> void:
		ci.draw_rect(r, face)
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, w)), light)
		ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), light)
		ci.draw_rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), dark)
		ci.draw_rect(Rect2(r.end.x - w, r.position.y, w, r.size.y), dark)

	## Hueco hundido (al revés que bevel).
	static func inset(ci: CanvasItem, r: Rect2, face: Color, w: float = 2.0) -> void:
		ci.draw_rect(r, face)
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, w)), Color(0, 0, 0, 0.55))
		ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), Color(0, 0, 0, 0.55))
		ci.draw_rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), Color(1, 1, 1, 0.18))
		ci.draw_rect(Rect2(r.end.x - w, r.position.y, w, r.size.y), Color(1, 1, 1, 0.18))

	static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, outline: Color = Color(0, 0, 0, 0.9), align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
		var f := ThemeDB.fallback_font
		if outline.a > 0.0:
			ci.draw_string_outline(f, pos, s, align, width, size, 4, outline)
		ci.draw_string(f, pos, s, align, width, size, col)

	static func text_w(s: String, size: int) -> float:
		return ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

	static func rivet(ci: CanvasItem, c: Vector2, col: Color) -> void:
		ci.draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), col.darkened(0.5))
		ci.draw_rect(Rect2(c - Vector2(2, 2), Vector2(2, 2)), col.lightened(0.4))

	static func diamond(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)

	static func heart(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
		ci.draw_circle(c + Vector2(-s * 0.5, -s * 0.2), s * 0.55, col)
		ci.draw_circle(c + Vector2(s * 0.5, -s * 0.2), s * 0.55, col)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.05, 0), c + Vector2(s * 1.05, 0), c + Vector2(0, s * 1.1)]), col)

	## Rayas diagonales que se desplazan (relleno de "punto débil").
	static func stripes(ci: CanvasItem, r: Rect2, col: Color, t: float, gap: float = 12.0) -> void:
		var off := fmod(t * 40.0, gap)
		var x := r.position.x - r.size.y - gap + off
		while x < r.end.x:
			var x0 := x
			var x1 := x + gap * 0.5
			var pts := PackedVector2Array([
				Vector2(clampf(x0, r.position.x, r.end.x), r.end.y),
				Vector2(clampf(x1, r.position.x, r.end.x), r.end.y),
				Vector2(clampf(x1 + r.size.y, r.position.x, r.end.x), r.position.y),
				Vector2(clampf(x0 + r.size.y, r.position.x, r.end.x), r.position.y)])
			if pts[2].x > pts[3].x or pts[1].x > pts[0].x:
				ci.draw_colored_polygon(pts, col)
			x += gap


## Marco común. Las subclases fijan colores en _theme() y dibujan su parte en _mech().
class Base extends Control:
	var boss: Node
	var t := 0.0
	var k := 1.0             # vida actual (0..1)
	var chip := 1.0          # lo recién perdido (blanco) que baja con retraso
	var shown := 0.0         # llenado de la presentación
	var flash := 0.0         # destello al recibir daño
	var shake := 0.0
	var glitch := 0.0        # nombre partido en rojo/cian
	var phase := 1
	var _chip_wait := 0.0
	var _last_hp := -1
	var _phase_pop := 0.0

	# colores (los cambia cada boss)
	var c_frame := Color(0.12, 0.13, 0.15)
	var c_light := Color(0.35, 0.37, 0.42)
	var c_dark := Color(0.03, 0.03, 0.05)
	var c_accent := Color(1, 0.35, 0.3)
	var c_fill := Color(0.85, 0.2, 0.25)
	var c_fill_hi := Color(1, 0.5, 0.45)
	var c_back := Color(0.07, 0.06, 0.08)
	var c_text := Color(0.95, 0.95, 0.95)
	var c_mech := Color(0.04, 0.05, 0.06, 0.92)
	var title := "BOSS"
	var bar_label := "INTEGRIDAD"
	var phase_names := ["Fase 1", "Fase 2", "Fase 3"]
	var enraged_name := "FURIA"

	func _ready() -> void:
		size = Vector2(W, H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_theme()
		if boss and is_instance_valid(boss):
			_last_hp = int(boss.get("hp"))
			if boss.has_signal("phase_changed"):
				boss.connect("phase_changed", func(p: int, _t: String) -> void:
					phase = p
					_phase_pop = 1.0
					shake = maxf(shake, 6.0))

	func _theme() -> void:
		pass

	func alive() -> bool:
		return boss != null and is_instance_valid(boss)

	func _process(delta: float) -> void:
		t += delta
		if visible:
			shown = minf(1.0, shown + delta * 0.9)
		flash = maxf(0.0, flash - delta * 4.0)
		shake = maxf(0.0, shake - delta * 30.0)
		glitch = maxf(0.0, glitch - delta * 5.0)
		_phase_pop = maxf(0.0, _phase_pop - delta * 1.2)
		if alive():
			var hp: int = int(boss.get("hp"))
			var mx: int = int(boss.get("MAX_HP"))
			k = clampf(float(hp) / float(maxi(1, mx)), 0.0, 1.0)
			phase = int(boss.get("phase"))
			if _last_hp >= 0 and hp < _last_hp:
				var dmg := float(_last_hp - hp) / float(maxi(1, mx))
				flash = 1.0
				glitch = 1.0
				shake = maxf(shake, clampf(dmg * 220.0, 2.0, 8.0))
				_chip_wait = 0.45
			_last_hp = hp
		if _chip_wait > 0.0:
			_chip_wait -= delta
		elif chip > k:
			chip = maxf(k, chip - delta * 0.5)
		if chip < k:
			chip = k
		_tick(delta)
		queue_redraw()

	func _tick(_delta: float) -> void:
		pass

	func weak() -> bool:
		return alive() and bool(boss.get("tank_open"))

	func enraged() -> bool:
		return alive() and bool(boss.get("enraged"))

	func _draw() -> void:
		var o := Vector2(randf_range(-shake, shake), randf_range(-shake, shake) * 0.5) if shake > 0.0 else Vector2.ZERO
		draw_set_transform(o)
		var r := Rect2(Vector2.ZERO, size)
		# sombra y marco
		draw_rect(Rect2(4, 5, W, H), Color(0, 0, 0, 0.35))
		K.bevel(self, r, c_frame, c_light, c_dark, 3.0)
		draw_rect(r, c_dark, false, 1.0)
		for p in [Vector2(6, 6), Vector2(W - 6, 6), Vector2(6, H - 6), Vector2(W - 6, H - 6)]:
			K.rivet(self, p, c_light)
		_header(Rect2(10, 5, W - 20, 20))
		var m := Rect2(10, 27, W - 20, 36)
		K.inset(self, m, c_mech)
		_mech(m.grow(-3.0))
		_bar(Rect2(10, 66, W - 20, 24))
		if _phase_pop > 0.0:
			draw_rect(r, Color(c_accent, _phase_pop * 0.35))
		draw_set_transform(Vector2.ZERO)

	func _header(r: Rect2) -> void:
		var name_w := K.text_w(title, 16) + 20.0
		var tag := Rect2(r.position, Vector2(name_w, r.size.y))
		K.bevel(self, tag, c_accent.darkened(0.35), c_accent, c_accent.darkened(0.7), 2.0)
		var np := tag.position + Vector2(10, 16)
		if glitch > 0.0:
			var g := glitch * 3.0
			K.text(self, np + Vector2(-g, 0), title, 16, Color(1, 0.1, 0.2, 0.7), Color(0, 0, 0, 0))
			K.text(self, np + Vector2(g, 0), title, 16, Color(0.1, 0.9, 1, 0.7), Color(0, 0, 0, 0))
		K.text(self, np, title, 16, Color.WHITE)
		var sub: String = phase_names[clampi(phase - 1, 0, 2)]
		if enraged():
			sub = enraged_name
		var sub_col := c_text if not enraged() else (Color(1, 0.3, 0.25) if fmod(t, 0.5) < 0.3 else Color(1, 0.8, 0.3))
		var sub_out := Color(0, 0, 0, 0.9) if c_text.v > 0.5 or enraged() else Color(0, 0, 0, 0)
		K.text(self, Vector2(tag.end.x + 10, r.position.y + 15), sub, 13, sub_col, sub_out)
		# rombos de fase
		for i in 3:
			var c := Vector2(r.end.x - 52 + i * 20, r.position.y + 10)
			K.diamond(self, c, 7.0, Color(0, 0, 0, 0.7))
			var lit := i < phase
			var col := c_accent if lit else Color(0.25, 0.25, 0.28)
			if i == phase - 1:
				col = col.lightened(0.25 + 0.25 * sin(t * 6.0))
			K.diamond(self, c, 5.0, col)
		_header_extra(r)

	func _header_extra(_r: Rect2) -> void:
		pass

	func _mech(_r: Rect2) -> void:
		pass

	## Relleno de la barra (las subclases pueden cambiarlo).
	func _fill(r: Rect2, frac: float) -> void:
		var fr := Rect2(r.position, Vector2(r.size.x * frac, r.size.y))
		var col := c_fill
		var hi := c_fill_hi
		if k < 0.3 and fmod(t, 0.6) < 0.3:
			col = col.lightened(0.15)
		draw_rect(fr, col)
		draw_rect(Rect2(fr.position, Vector2(fr.size.x, 4)), hi)
		draw_rect(Rect2(fr.position.x, fr.end.y - 4, fr.size.x, 4), col.darkened(0.35))

	func _bar(r: Rect2) -> void:
		K.inset(self, r, c_back, 2.0)
		var inner := r.grow(-3.0)
		var frac := k * ease(shown, 0.4)
		var cf := maxf(chip, frac) if shown >= 1.0 else frac
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * cf, inner.size.y)), Color(1, 0.96, 0.88))
		if frac > 0.0:
			_fill(inner, frac)
			if weak():
				var wr := Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y))
				draw_rect(wr, Color(1, 0.85, 0.2, 0.35 + 0.2 * sin(t * 10.0)))
				K.stripes(self, wr, Color(1, 1, 0.6, 0.35), t)
		if flash > 0.0:
			draw_rect(inner, Color(1, 1, 1, flash * 0.35))
		# muescas de cambio de fase
		for f in PHASE_AT:
			var x: float = inner.position.x + inner.size.x * float(f)
			draw_rect(Rect2(x - 2, r.position.y, 4, r.size.y), c_dark)
			draw_rect(Rect2(x - 1, r.position.y, 1, r.size.y), c_light)
		var lbl := bar_label
		if weak():
			lbl = "¡PUNTO DÉBIL!  DAÑO x2"
		K.text(self, inner.position + Vector2(6, 14), lbl, 12, Color.WHITE if not weak() else Color(1, 1, 0.6))
		K.text(self, Vector2(inner.end.x - 60, inner.position.y + 14), "%d%%" % int(ceil(k * 100.0)), 12, Color.WHITE, Color(0, 0, 0, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 54)


# --- 1 · 0xDEADBEEF: volcado de memoria y módulos de brazo ---------------------------

class Deadbeef extends Base:
	var _bytes: PackedStringArray = []
	var _scroll := 0.0

	func _theme() -> void:
		title = "0xDEADBEEF"
		bar_label = "MEMORIA"
		phase_names = ["Arranque del sistema", "Fuga de memoria", "Volcado fatal"]
		enraged_name = "SEGMENTATION FAULT"
		c_frame = Color(0.1, 0.16, 0.12)
		c_light = Color(0.3, 0.5, 0.35)
		c_dark = Color(0.02, 0.05, 0.03)
		c_accent = Color(0.3, 0.75, 0.35)
		c_fill = Color(0.25, 0.8, 0.35)
		c_fill_hi = Color(0.6, 1.0, 0.6)
		c_back = Color(0.02, 0.06, 0.03)
		c_mech = Color(0.01, 0.04, 0.02, 0.95)
		for i in 24:
			_bytes.append("%02X" % randi_range(0, 255))

	func _tick(delta: float) -> void:
		_scroll += delta * (1.0 + phase)
		if _scroll >= 0.12:
			_scroll = 0.0
			_bytes.remove_at(0)
			var pat := ["DE", "AD", "BE", "EF"]
			var b: String = pat[_bytes.size() % 4] if randf() < 0.55 else "%02X" % randi_range(0, 255)
			# cuanto menos vida, más bytes corruptos
			if randf() > k:
				b = "??"
			_bytes.append(b)

	func _arm(r: Rect2, label: String, hp: int, mx: int, broken: bool) -> void:
		K.bevel(self, r, Color(0.08, 0.12, 0.09), Color(0.25, 0.4, 0.3), Color(0.01, 0.03, 0.02), 2.0)
		if broken:
			K.text(self, r.position + Vector2(6, 13), label, 11, Color(1, 0.4, 0.3))
			var cx := r.position + Vector2(r.size.x - 18, r.size.y * 0.5)
			draw_line(cx + Vector2(-7, -7), cx + Vector2(7, 7), Color(1, 0.25, 0.2), 3.0)
			draw_line(cx + Vector2(-7, 7), cx + Vector2(7, -7), Color(1, 0.25, 0.2), 3.0)
			if fmod(t + r.position.x, 0.7) < 0.15:
				draw_circle(cx + Vector2(randf_range(-8, 8), randf_range(-6, 6)), 2.0, Color(1, 0.9, 0.4))
			K.text(self, r.position + Vector2(6, 26), "DESTRUIDO", 10, Color(1, 0.4, 0.3))
			return
		K.text(self, r.position + Vector2(6, 13), label, 11, Color(0.7, 1, 0.7))
		var n := 6
		var lit := int(ceil(float(hp) / float(maxi(1, mx)) * n))
		for i in n:
			var cell := Rect2(r.position.x + 6 + i * 13, r.position.y + 18, 10, 8)
			draw_rect(cell, Color(0.4, 1, 0.45) if i < lit else Color(0.1, 0.2, 0.12))

	func _mech(r: Rect2) -> void:
		var f_size := 12
		var x := r.position.x + 4
		var hex_end := r.end.x - 230
		var i := 0
		while x < hex_end and i < _bytes.size():
			var b: String = _bytes[i]
			var col := Color(0.35, 0.85, 0.4, 0.8)
			if b == "??":
				col = Color(1, 0.3, 0.25)
			elif b in ["DE", "AD", "BE", "EF"]:
				col = Color(0.75, 1, 0.75)
			K.text(self, Vector2(x, r.position.y + 13), b, f_size, col, Color(0, 0, 0, 0))
			x += 20.0
			i += 1
		var st := "TANQUE: SELLADO"
		var sc := Color(0.5, 0.75, 0.5)
		if weak():
			st = "TANQUE: ¡ABIERTO! x2"
			sc = Color(1, 0.9, 0.3) if fmod(t, 0.4) < 0.25 else Color(1, 0.6, 0.2)
		K.text(self, Vector2(r.position.x + 4, r.end.y - 3), st, 12, sc)
		if alive():
			var ah: Dictionary = boss.get("arm_hp")
			var broken: Array = boss.get("broken_arms")
			var mx := 12
			_arm(Rect2(r.end.x - 222, r.position.y, 106, r.size.y), "GARRA", int(ah.get("claw", 0)), mx, broken.has("claw"))
			_arm(Rect2(r.end.x - 110, r.position.y, 106, r.size.y), "PINZA", int(ah.get("grabber", 0)), mx, broken.has("grabber"))


# --- 2 · B.S.O.D.: monitor cardíaco; en fase 3 se vuelve pantalla azul ----------------

class Bsod extends Base:
	var _samples: Array[float] = []
	var _beat := 0.0

	func _theme() -> void:
		title = "B.S.O.D."
		bar_label = "SIGNOS VITALES"
		phase_names = ["Reposo", "Taquicardia", "Paro crítico"]
		enraged_name = "ARRITMIA"
		c_frame = Color(0.82, 0.86, 0.88)
		c_light = Color(1, 1, 1)
		c_dark = Color(0.4, 0.45, 0.5)
		c_accent = Color(0.85, 0.2, 0.25)
		c_fill = Color(0.9, 0.22, 0.3)
		c_fill_hi = Color(1, 0.6, 0.6)
		c_back = Color(0.1, 0.12, 0.14)
		c_text = Color(0.12, 0.15, 0.2)
		c_mech = Color(0.01, 0.06, 0.03, 0.97)
		for i in 330:
			_samples.append(0.0)
		if boss and boss.has_signal("beat"):
			boss.connect("beat", func() -> void: _beat = 1.0)

	func _wave(s: float) -> float:
		if s < 0.05:
			return -0.15 * sin(s / 0.05 * PI)
		if s < 0.07:
			return 0.15
		if s < 0.1:
			return -1.0
		if s < 0.13:
			return 0.45
		if s > 0.2 and s < 0.32:
			return -0.25 * sin((s - 0.2) / 0.12 * PI)
		return 0.0

	func _tick(delta: float) -> void:
		_beat = maxf(0.0, _beat - delta * 4.0)
		var v := 0.0
		if alive() and bool(boss.call("is_alive")):
			v = _wave(float(boss.call("since_beat")))
			if bool(boss.call("is_arrhythmic")):
				v = randf_range(-0.7, 0.7)
		_samples.pop_front()
		_samples.append(v)
		if phase >= 3:
			c_frame = Color(0.0, 0.2, 0.65)
			c_light = Color(0.3, 0.5, 1.0)
			c_dark = Color(0.0, 0.08, 0.3)
			c_text = Color(1, 1, 1)
			c_mech = Color(0.0, 0.18, 0.6, 0.97)

	func _header_extra(r: Rect2) -> void:
		if not alive():
			return
		var hc := Vector2(r.end.x - 160, r.position.y + 10)
		K.heart(self, hc, 6.0 + _beat * 3.0, Color(1, 0.2, 0.3))
		K.text(self, hc + Vector2(14, 6), "%s BPM" % boss.call("bpm_text"), 14, Color(1, 0.35, 0.4) if phase < 3 else Color.WHITE)

	func _mech(r: Rect2) -> void:
		var grid := Color(0.1, 0.35, 0.18, 0.6) if phase < 3 else Color(0.3, 0.5, 1.0, 0.35)
		var x := r.position.x
		while x < r.end.x:
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), grid, 1.0)
			x += 20.0
		var y := r.position.y
		while y < r.end.y:
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), grid, 1.0)
			y += 10.0
		if phase >= 3:
			K.text(self, Vector2(r.position.x + 8, r.end.y - 6), ":(", 26, Color(1, 1, 1, 0.85), Color(0, 0, 0, 0))
		var pts := PackedVector2Array()
		var n := _samples.size()
		var step := r.size.x / float(n - 1)
		var mid := r.position.y + r.size.y * 0.55
		for i in n:
			pts.append(Vector2(r.position.x + i * step, mid + _samples[i] * r.size.y * 0.45))
		var col := Color(0.4, 1.0, 0.5)
		if phase == 2:
			col = Color(1.0, 0.8, 0.3)
		elif phase >= 3:
			col = Color.WHITE
		draw_polyline(pts, Color(col, 0.25), 5.0)
		draw_polyline(pts, col, 2.0)
		draw_circle(pts[n - 1], 3.0 + _beat * 2.0, Color.WHITE)


# --- 3 · #DIV/0!: la vida es la cotización de la bolsa --------------------------------

class Div0 extends Base:
	var _samples: Array[float] = []
	var _acc := 0.0

	func _theme() -> void:
		title = "#DIV/0!"
		bar_label = "CAPITAL"
		phase_names = ["Apertura de mercado", "Volatilidad", "Crisis financiera"]
		enraged_name = "BANCARROTA"
		c_frame = Color(0.18, 0.12, 0.24)
		c_light = Color(0.85, 0.7, 0.3)
		c_dark = Color(0.06, 0.03, 0.09)
		c_accent = Color(0.85, 0.65, 0.15)
		c_fill = Color(0.9, 0.7, 0.15)
		c_fill_hi = Color(1, 0.92, 0.5)
		c_back = Color(0.06, 0.04, 0.08)
		c_mech = Color(0.02, 0.03, 0.05, 0.96)
		for i in 160:
			_samples.append(70.0)

	func _tick(delta: float) -> void:
		_acc += delta
		if _acc >= 0.06 and alive():
			_acc = 0.0
			_samples.pop_front()
			_samples.append(float(boss.get("price")))

	func _y(r: Rect2, p: float) -> float:
		return r.end.y - 2.0 - clampf(p, 0.0, 110.0) / 110.0 * (r.size.y - 4.0)

	func _header_extra(r: Rect2) -> void:
		if not alive():
			return
		var last: float = _samples[_samples.size() - 1]
		var prev: float = _samples[maxi(0, _samples.size() - 12)]
		var up := last >= prev
		var col := Color(0.4, 1.0, 0.5) if up else Color(1, 0.35, 0.3)
		var txt := "%s %.1f" % ["▲" if up else "▼", last]
		K.text(self, Vector2(r.end.x - 170, r.position.y + 16), txt, 16, col, Color(0, 0, 0, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 100)

	func _mech(r: Rect2) -> void:
		if not alive():
			return
		var crashed := bool(boss.get("crashed"))
		var bubble := bool(boss.get("bubble"))
		var cy := _y(r, float(boss.get("crash_line")))
		var by := _y(r, 95.0)
		var x := r.position.x
		while x < r.end.x:
			draw_line(Vector2(x, cy), Vector2(x + 6, cy), Color(1, 0.25, 0.2, 0.9), 2.0)
			draw_line(Vector2(x, by), Vector2(x + 6, by), Color(1, 0.8, 0.3, 0.6), 1.0)
			x += 12.0
		# velas japonesas: una cada 8 muestras
		var n := _samples.size()
		var per := 8
		var cw := r.size.x / float(n / per)
		var ci := 0
		var i := 0
		while i + per <= n:
			var o: float = _samples[i]
			var c: float = _samples[i + per - 1]
			var hi := o
			var lo := o
			for j in per:
				hi = maxf(hi, _samples[i + j])
				lo = minf(lo, _samples[i + j])
			var cx := r.position.x + ci * cw + cw * 0.5
			var col := Color(0.35, 0.95, 0.45) if c >= o else Color(1, 0.3, 0.28)
			draw_line(Vector2(cx, _y(r, hi)), Vector2(cx, _y(r, lo)), col, 1.0)
			var top := _y(r, maxf(o, c))
			var bot := _y(r, minf(o, c))
			draw_rect(Rect2(cx - cw * 0.3, top, cw * 0.6, maxf(2.0, bot - top)), col)
			ci += 1
			i += per
		var tag := ""
		var tcol := Color.WHITE
		if crashed:
			tag = "¡QUIEBRA!  x2"
			tcol = Color(1, 0.3, 0.25) if fmod(t, 0.4) < 0.25 else Color(1, 1, 0.5)
		elif bubble:
			tag = "BURBUJA"
			tcol = Color(1, 0.85, 0.3)
		if tag != "":
			K.text(self, Vector2(r.end.x - 130, r.position.y + 14), tag, 14, tcol, Color(0, 0, 0, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 124)


# --- 4 · SYNTAX ERROR: pizarra con la lección y la nota -----------------------------

class Syntax extends Base:
	func _theme() -> void:
		title = "SYNTAX ERROR"
		bar_label = "ASISTENCIA"
		phase_names = ["Clase inaugural", "Examen parcial", "Examen final"]
		enraged_name = "RECUPERACIÓN"
		c_frame = Color(0.45, 0.28, 0.14)
		c_light = Color(0.7, 0.48, 0.26)
		c_dark = Color(0.2, 0.11, 0.05)
		c_accent = Color(0.75, 0.15, 0.15)
		c_fill = Color(0.9, 0.3, 0.28)
		c_fill_hi = Color(1, 0.65, 0.6)
		c_back = Color(0.08, 0.16, 0.1)
		c_text = Color(0.98, 0.95, 0.85)
		c_mech = Color(0.12, 0.26, 0.17, 0.98)

	func _mech(r: Rect2) -> void:
		if not alive():
			return
		var chalk := Color(0.95, 0.95, 0.9, 0.95)
		# polvo de tiza
		for i in 6:
			var p := Vector2(r.position.x + fmod(i * 97.0 + t * 7.0, r.size.x), r.position.y + fmod(i * 13.0, r.size.y))
			draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, 0.12))
		if str(boss.get("state")) == "final":
			var es: int = int(boss.get("_exam_sym"))
			K.text(self, Vector2(r.position.x + 6, r.position.y + 21), "EXAMEN FINAL  %d/%d" % [mini(int(boss.get("_exam_q")) + 1, int(boss.get("exam_n"))), int(boss.get("exam_n"))], 14, chalk, Color(0, 0, 0, 0))
			if es >= 0:
				SyntaxFx.Sym.draw(self, es, Vector2(r.position.x + 230, r.position.y + r.size.y * 0.5), 13.0, SyntaxFx.SYM_COL[es])
				var et: float = maxf(0.01, float(boss.get("_exam_total")))
				var tr2 := Rect2(r.position.x + 260, r.position.y + 12, 200, 8)
				draw_rect(tr2, Color(0, 0, 0, 0.3))
				draw_rect(Rect2(tr2.position, Vector2(tr2.size.x * clampf(float(boss.get("_exam_left")) / et, 0.0, 1.0), tr2.size.y)), Color(1, 0.55, 0.45))
		elif bool(boss.get("lesson")):
			var seq: Array = boss.get("_seq")
			var shown_n: int = int(boss.get("_seq_shown"))
			var view: Array = boss.call("lesson_view") if boss.has_method("lesson_view") else []
			K.text(self, Vector2(r.position.x + 6, r.position.y + 21), "LECCIÓN:" if not (boss.has_method("lesson_reverse") and boss.call("lesson_reverse")) else "LECCIÓN ←", 14, chalk, Color(0, 0, 0, 0))
			for i in view.size():
				var v: Dictionary = view[i]
				var s: int = int(v["sym"])
				var col: Color = SyntaxFx.SYM_COL[s]
				var c := Vector2(r.position.x + 100 + i * 34, r.position.y + r.size.y * 0.5)
				if v["hidden"]:
					K.text(self, c + Vector2(-6, 6), "?", 18, chalk, Color(0, 0, 0, 0))
					continue
				SyntaxFx.Sym.draw(self, s, c, 11.0, Color(col, 0.3) if v["done"] else col)
				if v["trap"]:
					draw_line(c + Vector2(-11, -11), c + Vector2(11, 11), Color(1, 0.3, 0.25), 3.0)
					draw_line(c + Vector2(11, -11), c + Vector2(-11, 11), Color(1, 0.3, 0.25), 3.0)
				if v["done"]:
					draw_line(c + Vector2(-8, 0), c + Vector2(-2, 7), Color(0.5, 1, 0.5), 3.0)
					draw_line(c + Vector2(-2, 7), c + Vector2(10, -8), Color(0.5, 1, 0.5), 3.0)
				elif v["next"]:
					draw_line(c + Vector2(-11, 14), c + Vector2(11, 14), chalk, 2.0)
			var left: float = float(boss.get("_lesson_left"))
			var total: float = maxf(0.01, float(boss.get("_lesson_total")))
			if shown_n >= seq.size():
				var tr := Rect2(r.position.x + 260, r.position.y + 12, 200, 8)
				draw_rect(tr, Color(0, 0, 0, 0.3))
				draw_rect(Rect2(tr.position, Vector2(tr.size.x * clampf(left / total, 0.0, 1.0), tr.size.y)), Color(1, 0.55, 0.45))
				K.text(self, Vector2(tr.position.x, tr.end.y + 12), "tiempo", 10, Color(chalk, 0.7), Color(0, 0, 0, 0))
		else:
			var p: int = int(boss.get("passes"))
			var q: int = int(boss.get("fails"))
			K.text(self, Vector2(r.position.x + 6, r.position.y + 21), "Aprobadas: %d     Reprobadas: %d" % [p, q], 14, chalk, Color(0, 0, 0, 0))
		# nota en círculo rojo, como en un examen corregido
		var grade := 10.0 * k
		var gc := Vector2(r.end.x - 40, r.position.y + r.size.y * 0.5)
		var gcol := Color(0.4, 0.9, 0.45) if grade >= 7.0 else (Color(1, 0.8, 0.3) if grade >= 4.0 else Color(1, 0.3, 0.3))
		draw_arc(gc, 17, 0, TAU, 28, gcol, 2.5)
		K.text(self, gc + Vector2(-30, 6), "%.1f" % grade, 16, gcol, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, 60)
		K.text(self, Vector2(r.end.x - 120, r.position.y + 22), "Nota", 12, Color(chalk, 0.8), Color(0, 0, 0, 0))


# --- 5 · STACK OVERFLOW: plano de obra con la torre que apila ------------------------

class Stack extends Base:
	func _theme() -> void:
		title = "STACK OVERFLOW"
		bar_label = "ESTRUCTURA"
		phase_names = ["Cimientos", "Estructura", "Entrega urgente"]
		enraged_name = "DERRUMBE"
		c_frame = Color(0.85, 0.65, 0.1)
		c_light = Color(1, 0.88, 0.4)
		c_dark = Color(0.35, 0.25, 0.02)
		c_accent = Color(0.1, 0.1, 0.12)
		c_fill = Color(1, 0.72, 0.15)
		c_fill_hi = Color(1, 0.9, 0.5)
		c_back = Color(0.05, 0.1, 0.22)
		c_mech = Color(0.07, 0.2, 0.45, 0.98)

	func _mech(r: Rect2) -> void:
		var grid := Color(0.6, 0.8, 1.0, 0.13)
		var x := r.position.x
		while x < r.end.x:
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), grid, 1.0)
			x += 15.0
		if not alive():
			return
		var floors := 0
		var tw: Variant = boss.get("tower")
		if tw != null and is_instance_valid(tw):
			floors = int((tw as Node).get("floors"))
		var wc := Color(0.88, 0.95, 1.0)
		K.text(self, Vector2(r.position.x + 6, r.position.y + 13), "AVANCE DE OBRA", 11, wc, Color(0, 0, 0, 0))
		# la torre de lado: 8 pisos de izquierda a derecha, cada vez más peligrosos
		for i in 8:
			var cell := Rect2(r.position.x + 6 + i * 42, r.position.y + 17, 38, 11)
			var col := Color(1, 0.75, 0.2) if i < 5 else (Color(1, 0.45, 0.15) if i < 7 else Color(1, 0.2, 0.15))
			if i < floors:
				draw_rect(cell, col)
				draw_rect(Rect2(cell.position, Vector2(cell.size.x, 2)), col.lightened(0.4))
				for w in 3:
					draw_rect(Rect2(cell.position.x + 5 + w * 11, cell.position.y + 4, 5, 4), Color(0.1, 0.15, 0.3))
			draw_rect(cell, wc, false, 1.0)
		if floors >= 6:
			K.stripes(self, Rect2(r.position.x + 350, r.position.y + 2, 120, 12), Color(1, 0.8, 0.1, 0.8), t, 10.0)
		var status := ""
		var sc := wc
		if floors >= 8:
			status = "¡DESBORDE!"
			sc = Color(1, 0.3, 0.25) if fmod(t, 0.4) < 0.25 else Color(1, 0.9, 0.3)
		elif floors >= 2:
			status = "base agrietada: ¡tírala!"
			sc = Color(0.6, 1.0, 0.6)
		var cl: float = float(boss.get("crush_left"))
		var ct: float = float(boss.get("crush_total"))
		if cl > 0.0 and ct > 0.0:
			status = "¡APLASTADO! x2"
			sc = Color(0.6, 1, 0.6)
			var br := Rect2(r.end.x - 150, r.position.y + 18, 144, 10)
			draw_rect(br, Color(0, 0, 0, 0.4))
			draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(cl / ct, 0.0, 1.0), br.size.y)), Color(0.5, 1.0, 0.5))
		K.text(self, Vector2(r.end.x - 156, r.position.y + 13), status, 12, sc, Color(0, 0, 0, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 150)
		K.text(self, Vector2(r.position.x + 350 + 126, r.position.y + 28), "%d/8" % floors, 14, wc)

	func _fill(r: Rect2, frac: float) -> void:
		super._fill(r, frac)
		# franjas de obra amarillo/negro en el relleno
		var fr := Rect2(r.position, Vector2(r.size.x * frac, r.size.y))
		K.stripes(self, Rect2(fr.position.x, fr.position.y + 5, fr.size.x, fr.size.y - 10), Color(0, 0, 0, 0.22), 0.0, 16.0)


# --- 6 · 403 FORBIDDEN: expediente con pruebas, escudo y balanza ----------------------

class Judge extends Base:
	func _theme() -> void:
		title = "403 FORBIDDEN"
		bar_label = "AUTORIDAD"
		phase_names = ["Audiencia preliminar", "Juicio oral", "Sentencia"]
		enraged_name = "APELACIÓN DENEGADA"
		c_frame = Color(0.35, 0.18, 0.1)
		c_light = Color(0.85, 0.65, 0.3)
		c_dark = Color(0.15, 0.06, 0.03)
		c_accent = Color(0.6, 0.1, 0.1)
		c_fill = Color(0.7, 0.12, 0.12)
		c_fill_hi = Color(1, 0.45, 0.4)
		c_back = Color(0.15, 0.08, 0.04)
		c_mech = Color(0.82, 0.68, 0.45, 0.98)

	func _mech(r: Rect2) -> void:
		if not alive():
			return
		var ink := Color(0.2, 0.12, 0.06)
		var ev: int = int(boss.get("evidence"))
		K.text(self, Vector2(r.position.x + 6, r.position.y + 20), "PRUEBAS", 12, ink, Color(0, 0, 0, 0))
		for i in 3:
			var cell := Rect2(r.position.x + 72 + i * 40, r.position.y + 2, 34, r.size.y - 4)
			draw_rect(cell, Color(0.97, 0.94, 0.85) if i < ev else Color(0.6, 0.48, 0.3, 0.6))
			draw_rect(cell, ink, false, 1.5)
			K.text(self, cell.position + Vector2(0, 13), "ABC"[i], 11, ink, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, cell.size.x)
			if i < ev:
				draw_line(cell.position + Vector2(8, 17), cell.position + Vector2(14, 23), Color(0.15, 0.5, 0.2), 3.0)
				draw_line(cell.position + Vector2(14, 23), cell.position + Vector2(27, 10), Color(0.15, 0.5, 0.2), 3.0)
		# sello / culpable
		var sx := r.position.x + 210
		var gl: float = float(boss.get("guilty_left"))
		if bool(boss.get("shield")):
			var c := Vector2(sx + 16, r.position.y + r.size.y * 0.5)
			var rot := sin(t * 2.0) * 0.08
			draw_set_transform(c + Vector2(randf_range(-shake, shake), 0), rot)
			draw_arc(Vector2.ZERO, 15, 0, TAU, 28, Color(0.75, 0.12, 0.1), 3.0)
			K.text(self, Vector2(-20, 5), "403", 13, Color(0.75, 0.12, 0.1), Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, 40)
			draw_set_transform(Vector2.ZERO)
			K.text(self, Vector2(sx + 38, r.position.y + 13), "ACCESO DENEGADO", 12, Color(0.6, 0.08, 0.08), Color(0, 0, 0, 0))
			K.text(self, Vector2(sx + 38, r.position.y + 27), "daño ÷4" if ev < 3 else "¡A JUICIO! para el sello", 11, ink, Color(0, 0, 0, 0))
		elif gl > 0.0:
			var gr := Rect2(sx, r.position.y + 4, 170, r.size.y - 8)
			draw_rect(gr, Color(0.2, 0.5, 0.25, 0.3))
			draw_rect(Rect2(gr.position, Vector2(gr.size.x * clampf(gl / 4.0, 0.0, 1.0), gr.size.y)), Color(0.25, 0.65, 0.3))
			draw_rect(gr, ink, false, 1.5)
			K.text(self, gr.position + Vector2(0, 17), "¡OBJECIÓN!  CULPABLE x2", 12, Color.WHITE, Color(0, 0, 0, 0.6), HORIZONTAL_ALIGNMENT_CENTER, gr.size.x)
		# balanza: se inclina según los juicios ganados y perdidos
		var w: int = int(boss.get("trials_won"))
		var l: int = int(boss.get("trials_lost"))
		var bc := Vector2(r.end.x - 70, r.position.y + 6)
		var tilt := clampf(float(l - w) * 0.18, -0.5, 0.5)
		draw_line(bc, bc + Vector2(0, 22), ink, 2.0)
		var a := bc + Vector2(-26, 0).rotated(tilt)
		var b := bc + Vector2(26, 0).rotated(tilt)
		draw_line(a, b, ink, 2.0)
		draw_arc(a + Vector2(0, 8), 7, 0, PI, 10, ink, 2.0)
		draw_arc(b + Vector2(0, 8), 7, 0, PI, 10, ink, 2.0)
		K.text(self, Vector2(r.end.x - 34, r.position.y + 20), "%d-%d" % [w, l], 13, ink, Color(0, 0, 0, 0))


# --- 7 · MISSING TEXTURE: placa de museo; la barra es la textura que falta ------------

class Tex extends Base:
	func _theme() -> void:
		title = "MISSING TEXTURE"
		bar_label = "TEXTURA"
		phase_names = ["Sala permanente", "Exposición temporal", "Restauración fallida"]
		enraged_name = "OBRA PERDIDA"
		c_frame = Color(0.62, 0.46, 0.15)
		c_light = Color(1, 0.85, 0.45)
		c_dark = Color(0.3, 0.2, 0.05)
		c_accent = Color(0.85, 0.1, 0.8)
		c_back = Color(0.08, 0.06, 0.08)
		c_mech = Color(0.93, 0.91, 0.86, 0.98)

	func _statue() -> bool:
		return alive() and str(boss.get("state")) == "stunned" and float(boss.get("statue_left")) > 0.0

	func _fill(r: Rect2, frac: float) -> void:
		var fr := Rect2(r.position, Vector2(r.size.x * frac, r.size.y))
		if _statue():
			draw_rect(fr, Color(0.6, 0.6, 0.65))
			draw_rect(Rect2(fr.position, Vector2(fr.size.x, 4)), Color(0.8, 0.8, 0.85))
			return
		# damero magenta/negro que se desplaza
		var cs := 9.0
		var off := fmod(t * 18.0, cs * 2.0)
		var y := fr.position.y
		var row := 0
		while y < fr.end.y:
			var x := fr.position.x - off
			var col := 0
			while x < fr.end.x:
				var x0 := maxf(x, fr.position.x)
				var x1 := minf(x + cs, fr.end.x)
				if x1 > x0:
					var c := Color(1, 0.0, 0.9) if (row + col) % 2 == 0 else Color(0.05, 0.0, 0.05)
					draw_rect(Rect2(x0, y, x1 - x0, minf(cs, fr.end.y - y)), c)
				x += cs
				col += 1
			y += cs
			row += 1
		draw_rect(Rect2(fr.position, Vector2(fr.size.x, 2)), Color(1, 0.6, 1, 0.6))

	func _mech(r: Rect2) -> void:
		if not alive():
			return
		var ink := Color(0.15, 0.13, 0.12)
		# el ojo: abierto si lo estás mirando
		var watched := bool(boss.get("watched"))
		var ec := Vector2(r.position.x + 24, r.position.y + r.size.y * 0.5)
		var open := 9.0 if watched else 1.5
		draw_colored_polygon(PackedVector2Array([ec + Vector2(-18, 0), ec + Vector2(0, -open), ec + Vector2(18, 0), ec + Vector2(0, open)]), Color.WHITE)
		if watched:
			draw_circle(ec, 6, Color(0.55, 0.1, 0.5))
			draw_circle(ec, 3, Color.BLACK)
		draw_polyline(PackedVector2Array([ec + Vector2(-18, 0), ec + Vector2(0, -open), ec + Vector2(18, 0), ec + Vector2(0, open), ec + Vector2(-18, 0)]), ink, 2.0)
		K.text(self, Vector2(r.position.x + 48, r.position.y + 13), "TE VE" if watched else "MÍRALO", 11, ink, Color(0, 0, 0, 0))
		# petrificación: barra de piedra que se agrieta
		var pk: float = float(boss.get("petrify"))
		var bar := Rect2(r.position.x + 48, r.position.y + 17, 230, 11)
		draw_rect(bar, Color(0.75, 0.72, 0.68))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * pk, bar.size.y)), Color(0.5, 0.5, 0.56))
		var cx := bar.position.x + 20.0
		while cx < bar.position.x + bar.size.x * pk:
			draw_line(Vector2(cx, bar.position.y), Vector2(cx + 5, bar.end.y), Color(0.3, 0.3, 0.35), 1.0)
			cx += 23.0
		draw_rect(bar, ink, false, 1.5)
		K.text(self, Vector2(bar.end.x + 6, bar.end.y), "petrificación", 10, ink, Color(0, 0, 0, 0))
		var label := "MISSING TEXTURE"
		var col := Color(0.85, 0.1, 0.8)
		if _statue():
			label = "¡ESTATUA! x2"
			col = Color(0.15, 0.55, 0.25)
		elif watched:
			label = "PIEDRA"
			col = Color(0.35, 0.35, 0.4)
		var st := Rect2(r.end.x - 190, r.position.y + 4, 130, r.size.y - 8)
		draw_rect(st, col)
		K.text(self, st.position + Vector2(0, 17), label, 12, Color.WHITE, Color(0, 0, 0, 0.5), HORIZONTAL_ALIGNMENT_CENTER, st.size.x)
		K.text(self, Vector2(r.end.x - 54, r.position.y + 13), "Estatuas", 10, ink, Color(0, 0, 0, 0))
		K.text(self, Vector2(r.end.x - 54, r.position.y + 28), "%d" % int(boss.get("statues")), 14, ink, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, 48)


# --- 8 · KERNEL PANIC: rótulo de TV en vivo con las cámaras ---------------------------

class Kp extends Base:
	func _theme() -> void:
		title = "KERNEL PANIC"
		bar_label = "AUDIENCIA"
		phase_names = ["Primer bloque", "Segundo bloque", "Gran final"]
		enraged_name = "FUERA DE AIRE"
		c_frame = Color(0.1, 0.1, 0.16)
		c_light = Color(0.4, 0.4, 0.55)
		c_dark = Color(0.02, 0.02, 0.05)
		c_accent = Color(0.85, 0.12, 0.12)
		c_fill = Color(0.95, 0.3, 0.2)
		c_fill_hi = Color(1, 0.7, 0.5)
		c_back = Color(0.06, 0.06, 0.1)
		c_mech = Color(0.03, 0.03, 0.06, 0.96)

	func _header_extra(r: Rect2) -> void:
		if not alive():
			return
		var on_air := bool(boss.get("on_air"))
		var x := r.end.x - 190
		if on_air:
			if fmod(t, 1.0) < 0.6:
				draw_circle(Vector2(x, r.position.y + 10), 6, Color(1, 0.15, 0.15))
			K.text(self, Vector2(x + 10, r.position.y + 15), "EN VIVO", 12, Color(1, 0.45, 0.45))
		else:
			K.text(self, Vector2(x - 6, r.position.y + 15), "SIN SEÑAL", 12, Color(0.6, 0.9, 1.0))

	func _mech(r: Rect2) -> void:
		if not alive():
			return
		var st: String = str(boss.get("state"))
		var stunned := st == "stunned" and float(boss.get("panic_left")) > 0.0
		if stunned:
			# barras de color de "sin señal"
			var bars := [Color(0.9, 0.9, 0.9), Color(0.9, 0.9, 0.1), Color(0.1, 0.9, 0.9), Color(0.1, 0.9, 0.1), Color(0.9, 0.1, 0.9), Color(0.9, 0.1, 0.1), Color(0.1, 0.1, 0.9)]
			var bw := r.size.x / bars.size()
			for i in bars.size():
				draw_rect(Rect2(r.position.x + i * bw, r.position.y, bw + 1, r.size.y), bars[i])
			var lbl := Rect2(r.position.x + r.size.x * 0.5 - 130, r.position.y + 5, 260, r.size.y - 10)
			draw_rect(lbl, Color(0, 0, 0, 0.85))
			K.text(self, lbl.position + Vector2(0, 18), "¡KERNEL PANIC!  DAÑO x2", 14, Color(1, 1, 0.5) if fmod(t, 0.3) < 0.2 else Color.WHITE, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, lbl.size.x)
			return
		var cams: Array = boss.get("cams")
		var x := r.position.x + 2
		for c in cams:
			if not is_instance_valid(c):
				continue
			var cam := c as Node
			var live := bool(cam.get("live")) and not bool(cam.get("broken"))
			var broken := bool(cam.get("broken"))
			var box := Rect2(x, r.position.y + 1, 96, r.size.y - 2)
			var scr := Rect2(box.position + Vector2(3, 3), Vector2(36, box.size.y - 6))
			draw_rect(box, Color(0.85, 0.12, 0.12) if live and fmod(t, 0.8) < 0.5 else Color(0.18, 0.18, 0.24))
			draw_rect(scr, Color(0.05, 0.05, 0.08))
			if broken:
				for n in 14:
					var p := scr.position + Vector2(randf() * (scr.size.x - 3), randf() * (scr.size.y - 3))
					draw_rect(Rect2(p, Vector2(3, 2)), Color(1, 1, 1, randf() * 0.8))
			elif live:
				draw_circle(scr.get_center(), 5, Color(1, 0.3, 0.3))
			var lbl := "MANO" if bool(cam.get("handheld")) else "CAM %d" % (int(cam.get("idx")) + 1)
			K.text(self, Vector2(scr.end.x + 4, box.position.y + 13), lbl, 11, Color.WHITE)
			var mx: int = int(cam.get("max_hp"))
			var hpc: int = int(cam.get("hp"))
			for i in mx:
				draw_rect(Rect2(scr.end.x + 5 + i * 9, box.position.y + 18, 7, 8), Color.WHITE if i < hpc and not broken else Color(0.35, 0.35, 0.4))
			draw_rect(box, Color.BLACK, false, 1.5)
			x += 102.0
		var label := "AL AIRE · daño ½"
		var col := Color(0.75, 0.2, 0.2)
		if st == "transition":
			label = "CORTE COMERCIAL"
			col = Color(0.5, 0.45, 0.2)
		elif not bool(boss.get("on_air")):
			label = "SIN CÁMARA"
			col = Color(0.3, 0.4, 0.55)
		var sr := Rect2(r.end.x - 200, r.position.y + 3, 150, r.size.y - 6)
		draw_rect(sr, col)
		K.text(self, sr.position + Vector2(0, 17), label, 12, Color.WHITE, Color(0, 0, 0, 0.5), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x)
		K.text(self, Vector2(r.end.x - 46, r.position.y + 13), "Pánicos", 10, Color(0.8, 0.8, 0.9), Color(0, 0, 0, 0))
		K.text(self, Vector2(r.end.x - 46, r.position.y + 28), "%d" % int(boss.get("panics")), 14, Color.WHITE, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, 42)
