extends CanvasLayer
## HUD del jugador: retrato, nombre y clase, corazones de vida, K especial (anillo de
## enfriamiento), medidor de ultimate y pasos del combo. Lo crea Player._build_hud().
## Sin class_name: cargar con preload("res://scripts/combat/player_hud.gd").

const Kit := preload("res://scripts/combat/boss_hud.gd")

var player: Node

var _draw_node: HudPanel


func _ready() -> void:
	name = "PlayerHud"
	layer = 5
	_draw_node = HudPanel.new()
	_draw_node.player = player
	var sl: int = int(player.get("slot")) if player.get("slot") != null else 0
	_draw_node.position = Vector2(1280 - 14 - HudPanel.W, 720 - 118) if sl == 2 else Vector2(14, 720 - 118)
	add_child(_draw_node)


class HudPanel extends Control:
	const W := 380.0
	const H := 104.0
	const HEART_ROW := 5

	var player: Node
	var t := 0.0
	var _portrait: Texture2D
	var _src := Rect2()
	var _last_hp := -1
	var _hurt := 0.0
	var _shake := 0.0
	var _lost: Array = []          # [índice del corazón, tiempo] corazones que acaban de romperse
	var _k_ready_pop := 0.0
	var _k_was_ready := true
	var _ult_pop := 0.0
	var _ult_was_ready := false
	var _combo := 0
	var _combo_t := 0.0
	var _parry := 0.0
	var _name := "Estudiante"
	var _class := "Guerrero"

	func _ready() -> void:
		size = Vector2(W, H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var app: Variant = player.get("appearance")
		if app == null:
			app = GameState.get("appearance")
		if app != null:
			_name = str(app.get("student_name"))
			var cid: String = str(app.get("class_id"))
			for c in app.get("CLASSES"):
				if str(c["id"]) == cid:
					_class = str(c["label"])
		_find_portrait()
		var cc: Node = player.get("class_controller")
		if cc:
			cc.connect("combo_step_changed", func(step: int) -> void:
				_combo = step + 1
				_combo_t = 1.2)
			cc.connect("parried", func(_from: Vector2) -> void: _parry = 1.0)

	func _btn(action: String) -> String:
		var sl: Variant = player.get("slot")
		return GameState.btn_for(int(sl) if sl != null else 0, action)

	## Recorta la cabeza del primer cuadro de reposo mirando abajo.
	func _find_portrait() -> void:
		var anim: AnimatedSprite2D = player.get("anim")
		if anim == null or anim.sprite_frames == null:
			return
		var sf := anim.sprite_frames
		var pick := ""
		for a in sf.get_animation_names():
			var s := str(a)
			if s == "idle_down":
				pick = s
				break
			if pick == "" and s.begins_with("idle") and s.ends_with("down"):
				pick = s
		if pick == "" or sf.get_frame_count(pick) == 0:
			return
		_portrait = sf.get_frame_texture(pick, 0)
		var img := _portrait.get_image()
		if img == null:
			return
		var used := img.get_used_rect()
		var side := used.size.y * 0.48
		_src = Rect2(used.position.x + (used.size.x - side) * 0.5, used.position.y + used.size.y * 0.04, side, side)

	func _process(delta: float) -> void:
		t += delta
		_hurt = maxf(0.0, _hurt - delta * 2.5)
		_shake = maxf(0.0, _shake - delta * 25.0)
		_k_ready_pop = maxf(0.0, _k_ready_pop - delta * 2.0)
		_ult_pop = maxf(0.0, _ult_pop - delta * 1.5)
		_parry = maxf(0.0, _parry - delta * 1.6)
		_combo_t = maxf(0.0, _combo_t - delta)
		for l in _lost:
			l[1] = float(l[1]) + delta
		_lost = _lost.filter(func(l: Array) -> bool: return float(l[1]) < 0.6)
		var hp: int = int(player.get("hp"))
		if _last_hp >= 0 and hp < _last_hp:
			_hurt = 1.0
			_shake = 6.0
			for i in range(hp, _last_hp):
				_lost.append([i, 0.0])
		_last_hp = hp
		var cc: Node = player.get("class_controller")
		if cc:
			var ready := float(cc.call("special_cooldown_left")) <= 0.0
			if ready and not _k_was_ready:
				_k_ready_pop = 1.0
			_k_was_ready = ready
			var ur := bool(cc.call("ultimate_ready"))
			if ur and not _ult_was_ready:
				_ult_pop = 1.0
			_ult_was_ready = ur
		queue_redraw()

	func _draw() -> void:
		var o := Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.5) if _shake > 0.0 else Vector2.ZERO
		draw_set_transform(o)
		var hp: int = int(player.get("hp"))
		var mx: int = int(player.get("MAX_HP"))
		var low := hp <= 3 and hp > 0
		var frame := Color(0.13, 0.12, 0.18)
		var light := Color(0.42, 0.4, 0.55)
		var dark := Color(0.03, 0.03, 0.06)
		draw_rect(Rect2(4, 5, W, H), Color(0, 0, 0, 0.35))
		Kit.K.bevel(self, Rect2(0, 0, W, H), Color(frame, 0.94), light, dark, 3.0)
		# retrato
		var pr := Rect2(8, 8, 88, 88)
		Kit.K.inset(self, pr, Color(0.2, 0.28, 0.4))
		var bg_col := Color(0.25, 0.35, 0.55)
		if low:
			bg_col = bg_col.lerp(Color(0.7, 0.1, 0.1), 0.5 + 0.5 * sin(t * 8.0))
		draw_rect(pr.grow(-3), bg_col)
		for i in 4:
			draw_rect(Rect2(pr.position.x + 3, pr.position.y + 3 + i * 21, pr.size.x - 6, 10), Color(1, 1, 1, 0.04))
		if _portrait and _src.size.x > 0.0:
			var tint := Color.WHITE.lerp(Color(1, 0.3, 0.3), _hurt)
			var dst := pr.grow(-4)
			draw_texture_rect_region(_portrait, dst, _src, tint)
		if _hurt > 0.0:
			draw_rect(pr.grow(-3), Color(1, 0.1, 0.1, _hurt * 0.35))
		# insignia de clase
		var badge := Rect2(pr.position.x, pr.end.y - 16, pr.size.x, 16)
		draw_rect(badge, Color(0, 0, 0, 0.7))
		Kit.K.text(self, badge.position + Vector2(0, 12), _class.to_upper(), 11, Color(1, 0.85, 0.4), Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x)
		# nombre
		var x0 := 106.0
		var tag := ""
		if GameState.coop and player.get("slot") != null and int(player.get("slot")) >= 1:
			tag = "P%d  " % int(player.get("slot"))
		Kit.K.text(self, Vector2(x0, 21), tag + _name, 15, Color(1.0, 0.85, 0.3) if tag == "P2  " else (Color(0.5, 0.85, 1.0) if tag != "" else Color.WHITE))
		# combo
		if _combo_t > 0.0 and _combo > 0:
			for i in 3:
				var c := Vector2(W - 60 + i * 16, 15)
				Kit.K.diamond(self, c, 6.0, Color(0, 0, 0, 0.7))
				Kit.K.diamond(self, c, 4.5, Color(1, 0.85, 0.3) if i < _combo else Color(0.3, 0.3, 0.35))
		if _parry > 0.0:
			Kit.K.text(self, Vector2(x0 + 150, 21), "¡PARRY!", 15, Color(0.5, 0.95, 1.0, _parry))
		# ventana de contraataque: pulsar ataque ahora
		var cc2: Node = player.get("class_controller") if player else null
		if cc2 and float(cc2.call("counter_window_left")) > 0.0:
			var pulse := 0.6 + 0.4 * sin(t * 30.0)
			var ctext := "¡%s  CONTRAATAQUE!" % _btn("action_primary")
			var cw := Kit.K.text_w(ctext, 17) + 20.0
			draw_rect(Rect2(0, -34, cw, 28), Color(0, 0, 0, 0.8))
			draw_rect(Rect2(0, -34, cw, 28), Color(1.0, 0.85, 0.3, pulse), false, 2.0)
			Kit.K.text(self, Vector2(10, -14), ctext, 17, Color(1.0, 0.92, 0.45, 0.7 + 0.3 * pulse))
		# corazones (2 filas de 5)
		for i in mx:
			var row := i / HEART_ROW
			var colm := i % HEART_ROW
			var c := Vector2(x0 + 12 + colm * 26 + row * 13, 40 + row * 19)
			var s := 8.0
			var full := i < hp
			if full and low:
				s += 1.2 * maxf(0.0, sin(t * 10.0))
			Kit.K.heart(self, c + Vector2(1, 2), s + 1.5, Color(0, 0, 0, 0.8))
			Kit.K.heart(self, c, s, Color(0.95, 0.18, 0.25) if full else Color(0.22, 0.12, 0.15))
			if full:
				draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 0.5), Vector2(3, 3)), Color(1, 0.75, 0.75))
		for l in _lost:
			var i: int = int(l[0])
			var lt: float = float(l[1])
			var row := i / HEART_ROW
			var colm := i % HEART_ROW
			var c := Vector2(x0 + 12 + colm * 26 + row * 13, 40 + row * 19)
			var k := lt / 0.6
			Kit.K.heart(self, c + Vector2(-4 * k, 10 * k), 8.0 * (1.0 - k * 0.5), Color(1, 1, 1, 1.0 - k))
		# K especial: anillo de enfriamiento
		var cc: Node = player.get("class_controller")
		var kc := Vector2(W - 34, 56)
		var kfrac := 1.0
		if cc:
			var cd: float = float(cc.call("special_cooldown_left"))
			var cid: String = str(cc.get("class_id"))
			var tot_d: Dictionary = cc.get("SPECIAL_COOLDOWN")
			var total: float = float(tot_d.get(cid, 3.0))
			kfrac = clampf(1.0 - cd / total, 0.0, 1.0)
		draw_circle(kc, 21, Color(0, 0, 0, 0.8))
		draw_circle(kc, 17, Color(0.12, 0.2, 0.35) if kfrac < 1.0 else Color(0.2, 0.45, 0.85))
		if kfrac < 1.0:
			draw_arc(kc, 19, -PI * 0.5, -PI * 0.5 + TAU * kfrac, 32, Color(0.45, 0.75, 1.0), 4.0)
		else:
			draw_arc(kc, 19, 0, TAU, 32, Color(0.6, 0.9, 1.0), 4.0)
			if _k_ready_pop > 0.0:
				draw_arc(kc, 19 + 10 * (1.0 - _k_ready_pop), 0, TAU, 32, Color(0.7, 0.95, 1.0, _k_ready_pop), 3.0)
		Kit.K.text(self, kc + Vector2(-20, 6), _btn("action_secondary"), 18, Color.WHITE if kfrac >= 1.0 else Color(0.6, 0.65, 0.75), Color(0, 0, 0, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 40)
		# ultimate
		var ur := Rect2(x0, 82, W - x0 - 70, 14)
		Kit.K.inset(self, ur, Color(0.06, 0.05, 0.08))
		var inner := ur.grow(-2)
		var meter := 0.0
		var ready := false
		if cc:
			meter = clampf(float(cc.get("ultimate_meter")) / 100.0, 0.0, 1.0)
			ready = bool(cc.call("ultimate_ready"))
		var fr := Rect2(inner.position, Vector2(inner.size.x * meter, inner.size.y))
		var ucol := Color(1.0, 0.75, 0.2)
		if ready:
			ucol = Color.from_hsv(fmod(t * 0.6, 1.0), 0.55, 1.0)
		draw_rect(fr, ucol)
		draw_rect(Rect2(fr.position, Vector2(fr.size.x, 3)), ucol.lightened(0.45))
		Kit.K.stripes(self, fr, Color(1, 1, 1, 0.18), t, 10.0)
		for i in range(1, 4):
			var x := inner.position.x + inner.size.x * i / 4.0
			draw_rect(Rect2(x - 1, inner.position.y, 2, inner.size.y), Color(0, 0, 0, 0.6))
		var ul := "ULTIMATE" if not ready else "¡%s! ULTIMATE" % _btn("ultimate").to_upper()
		Kit.K.text(self, Vector2(inner.position.x + 4, inner.end.y - 1), ul, 11, Color.WHITE if not ready else Color(1, 1, 0.7))
		if _ult_pop > 0.0:
			draw_rect(ur.grow(6.0 * (1.0 - _ult_pop)), Color(1, 0.9, 0.4, _ult_pop), false, 2.0)
		draw_set_transform(Vector2.ZERO)
