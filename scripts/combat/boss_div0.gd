extends CharacterBody2D
## Boss 3 #DIV/0! (Facultad de Ciencias Administrativas, Contables y Comercio): robot bóveda de la bolsa.
## Lo único: LA BOLSA. Su precio de acción reemplaza la barra de vida en el HUD.
## Cada golpe del jugador baja el precio; cada golpe del boss lo sube; solo se recupera de a poco.
## Bajo la línea roja: QUIEBRA (campana, la bóveda se abre, daño x2 por 4 s, queda torpe).
## Arriba del todo: BURBUJA (ataca más rápido y alarga los combos).
## Tras cada quiebra el precio vuelve arriba y la línea roja baja un poco.
## Usa los sprites de grokbot (assets/sprites/bosses/div0/); si falta alguno, esa pieza se dibuja por código.
## Sin class_name: cargar con preload.

const GameFeel := preload("res://scripts/combat/game_feel.gd")
const CoopBoss := preload("res://scripts/combat/coop_boss.gd")
const Barrage := preload("res://scripts/combat/boss_barrage.gd")
const BossFx := preload("res://scripts/combat/boss_fx.gd")
const Fx := preload("res://scripts/combat/boss_div0_fx.gd")
const Spr := preload("res://scripts/combat/boss_sprites.gd")
const Final := preload("res://scripts/combat/boss_final.gd")
const Roar := preload("res://scripts/combat/boss_roar.gd")

signal hp_changed(hp: int, max_hp: int)
signal phase_changed(phase: int, title: String)
signal stunned
signal staggered
signal intro_finished
signal defeated

const MAX_HP := 90
const PHASE_AT := [0.6, 0.3]
const MOVE_SPEED := 62.0
const KEEP_DIST := 210.0
const PAUSE := [1.2, 0.95, 0.7]
const POISE := [8, 11, 14]
const ENRAGE_AT := 0.12
const COMBOS := {
	2: [["stamp", "coins"], ["containers", "ledger"], ["org", "stamp"], ["audit", "coins"]],
	3: [["spam", "stamp", "stomp"], ["containers", "coins"], ["ledger", "org"], ["audit", "stamp", "stamp"]],
}

# bolsa
const START_PRICE := 70.0
const BUBBLE := 95.0
const BUBBLE_END := 80.0
const DROP_PER_DMG := 4.5
const RISE_PER_HIT := 6.0
const RECOVER := 1.2
const CRASH_TIME := 4.0
## La Bolsa por fase: F1 como siempre. F2 caen NOTICIAS: un periódico en la arena; si lo recoges es un
## ESCÁNDALO (la acción se hunde), si lo dejas caducar son BUENAS NOTICIAS (sube). F3: la BURBUJA es un
## peligro: tienes BUBBLE_TIME s para pincharla (bajar de BUBBLE_END) o entra en MERCADO ALCISTA (se cura y dispara).
const NEWS_EVERY := 11.0
const NEWS_SWING := 18.0
const BUBBLE_TIME := 5.0
const BULL_HEAL := 6
## Duelo final MARGIN CALL: la acción empieza en 100; cada parry a un lingote VENDE (-SELL), cada lingote que
## te pega la sube (+BUY). Llévala a 0 antes de la campana de cierre (FINAL_TIME s).
const FINAL_TIME := 22.0
const SELL := 10.0
const BUY := 8.0

# pies = patas en y 0
const SHOULDER_L := Vector2(-68, -160)
const SHOULDER_R := Vector2(68, -160)
const VAULT := Vector2(0, -110)
const HEAD := Vector2(0, -186)
const CENTER := Vector2(0, -100)
const ARM_LEN := 118.0
const REST_L := 0.25
const REST_R := -0.25
# con sprites (medido sobre boss_div0_body_0, 191x210, pies abajo al centro)
const SPR_SHOULDER_L := Vector2(-63, -173)
const SPR_SHOULDER_R := Vector2(66, -174)
const SPR_VAULT := Vector2(9, -138)
const SPR_HEAD := Vector2(9, -190)
const BODY_H := 210.0

var hp: int = MAX_HP
var phase: int = 1
var state: String = "intro"
var arena_rect: Rect2 = Rect2(-500, -310, 1000, 620)
var player: CharacterBody2D
## La bóveda está abierta (daño x2). Mismo nombre que en el boss 1 para que la arena lo cuente.
var tank_open: bool = false
var enraged: bool = false

var price: float = START_PRICE
var crash_line: float = 35.0
var bubble: bool = false
var crashed: bool = false
var _news_t: float = NEWS_EVERY
var _bubble_t: float = 0.0
var final_victory: bool = false
var final_left: float = 0.0
var _final_fail: bool = false

var _tok: int = 0
var _cd: float = 1.0
var _last: String = ""
var _parry_watch: bool = false
var _was_parried: bool = false
var _queue: Array[String] = []
var _near_t: float = 0.0
var _poise: int = 0
var _marked: bool = false
var _t: float = 0.0
var _tweens: Array[Tween] = []
var _pose_tw: Tween
var rig_off: Vector2 = Vector2.ZERO
var panel: StockPanel
var _holo: Holo

## Patas plegadas (1), de pie (0) o estiradas (negativo). Mueve todo el cuerpo.
var fold: float = 0.0:
	set(v):
		fold = v
		_apply_fold()
var _home: Dictionary = {}

var rig: Node2D
var legs: Part
var torso: Part
var vault: Part
var ticker: Part
var head: Part
var stamp: Part
var calc: Part


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	z_index = 1
	collision_layer = 3
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(150, 34)
	shape.shape = r
	shape.position = Vector2(0, -17)
	add_child(shape)
	var hurt := Area2D.new()
	hurt.name = "Hurtbox"
	hurt.collision_layer = 2
	hurt.collision_mask = 0
	hurt.monitoring = false
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(140, 230)
	hs.shape = hr
	hs.position = Vector2(0, -115)
	hurt.add_child(hs)
	add_child(hurt)
	GameFeel.add_shadow(self, Vector2(0, -2), Vector2(100, 16) if has_sprites() else Vector2(90, 15))
	_build_rig()


func set_player(p: CharacterBody2D) -> void:
	player = p
	var cc = p.get("class_controller")
	if cc != null and cc.has_signal("parried"):
		cc.connect("parried", _on_player_parried)
	if p.has_signal("hurt"):
		p.connect("hurt", _on_player_hurt)


## La arena llama esto: el panel de la bolsa reemplaza la barra de vida.
func build_hud(layer: CanvasLayer) -> void:
	panel = StockPanel.new()
	panel.boss = self
	panel.position = Vector2(340, 8)
	layer.add_child(panel)


# --- Piezas ----------------------------------------------------------------------

func _build_rig() -> void:
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)
	var spr := has_sprites()
	legs = _part("legs", Vector2.ZERO)
	torso = _part("torso", Vector2.ZERO)
	vault = _part("vault", SPR_VAULT if spr else VAULT)
	ticker = _part("ticker", Vector2(0, -66))
	stamp = _part("stamp", SPR_SHOULDER_L if spr else SHOULDER_L)
	calc = _part("calc", SPR_SHOULDER_R if spr else SHOULDER_R)
	head = _part("head", SPR_HEAD if spr else HEAD)
	stamp.rotation = REST_L
	calc.rotation = REST_R
	_holo = Holo.new()
	_holo.position = Vector2(0, -268)
	rig.add_child(_holo)


func _part(kind: String, pos: Vector2) -> Part:
	var p := Part.new()
	p.kind = kind
	p.name = kind
	p.position = pos
	p.boss = self
	p.use_parent_material = true
	rig.add_child(p)
	_home[p] = pos
	return p


static func has_sprites() -> bool:
	return Spr.tex("boss_div0_body_0") != null


static func leg_height(f: float) -> float:
	return 58.0 * (1.0 - clampf(f, 0.0, 1.0) * 0.75) + maxf(0.0, -f) * 26.0


func _apply_fold() -> void:
	var lift := 58.0 - leg_height(fold)
	var spr := has_sprites()
	for p in _home:
		if p != legs and is_instance_valid(p):
			if spr:
				# el sprite del cuerpo se aplasta desde los pies: cada pieza baja según su altura
				p.position = Vector2(_home[p].x, _home[p].y * (1.0 - lift / BODY_H))
			else:
				p.position = _home[p] + Vector2(0, lift)


## Ángulo del brazo derecho para apuntar. El megáfono y el cañón del sprite apuntan de lado, no hacia abajo.
func _tool_rot(aim: Vector2) -> float:
	var name := "boss_div0_tool_%d" % calc.tool
	if calc.tool == 0 or Spr.tex(name) == null:
		return _rot_for(aim)
	return aim.angle() - 0.35 + Spr.lean(name)


func _parts() -> Array:
	return [legs, torso, vault, ticker, stamp, calc, head]


func _face(text: String, col: Color = Color(0.45, 1.0, 0.5)) -> void:
	head.face = text
	head.face_color = col
	if _holo and text != "":
		_holo.show_text(text, col)


func _clear_face() -> void:
	head.face = ""


# --- Bolsa ----------------------------------------------------------------------

func _price_step(delta: float) -> void:
	if state == "final":
		return
	# F2+: noticias
	if phase >= 2 and state in ["idle", "attack"] and not crashed:
		_news_t -= delta
		if _news_t <= 0.0:
			_news_t = NEWS_EVERY
			_drop_news()
	# F3: burbuja con tiempo para pincharla
	if phase >= 3 and bubble and not crashed and state in ["idle", "attack"]:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bull_market()
	if state in ["idle", "attack"] and not crashed:
		var k := RECOVER * (2.5 if enraged else 1.0)
		price = minf(100.0, price + k * delta)
	if not bubble and price >= BUBBLE and state in ["idle", "attack"]:
		bubble = true
		_bubble_t = BUBBLE_TIME
		_holo.show_text("¡BURBUJA! PÍNCHALA" if phase >= 3 else "BURBUJA", Color(1, 0.85, 0.3), 1.4)
		GameFeel.flash(rig, 0.2, Color(1, 0.9, 0.5))
	elif bubble and price < BUBBLE_END:
		bubble = false


## F2: cae un periódico. Recogerlo = escándalo (baja). Dejarlo = buenas noticias (sube).
func _drop_news() -> void:
	var n := News.new()
	n.boss = self
	var at := _clamp_arena(arena_rect.get_center() + Vector2(randf_range(-320, 320), randf_range(-60, 200)))
	get_parent().add_child(n)
	n.global_position = at
	_holo.show_text("¡ÚLTIMA HORA!", Color(1, 0.9, 0.5), 1.0)


func news_result(grabbed: bool) -> void:
	if state in ["dead", "final", "intro"]:
		return
	if grabbed:
		_move_price(-NEWS_SWING)
		_holo.show_text("¡ESCÁNDALO! ▼", Color(1, 0.35, 0.3), 1.2)
		GameFeel.flash(rig, 0.15, Color(1, 0.5, 0.4))
		if not crashed and price <= crash_line and state in ["idle", "attack"]:
			_crash()
	else:
		_move_price(NEWS_SWING)
		_holo.show_text("BUENAS NOTICIAS ▲", Color(0.5, 1, 0.5), 1.2)


## F3: no pinchaste la burbuja a tiempo: MERCADO ALCISTA (se cura un poco y lanza monedas).
func _bull_market() -> void:
	bubble = false
	price = 88.0
	var cap := int(MAX_HP * PHASE_AT[1])
	hp = mini(cap, hp + BULL_HEAL)
	hp_changed.emit(hp, MAX_HP)
	_holo.show_text("¡MERCADO ALCISTA!", Color(0.5, 1, 0.5), 1.4)
	GameFeel.flash(rig, 0.3, Color(0.6, 1.0, 0.6))
	_shake(4.0, 0.3)
	if _player_ok():
		var from := global_position + CENTER
		for k in 10:
			var c := Fx.Coin.new()
			c.arena = arena_rect
			c.max_gen = 1
			c.vel = Vector2.from_angle(TAU * k / 10.0) * 280.0
			_add_fx(c, from)


func _move_price(d: float) -> void:
	if state in ["intro", "dead", "paused", "transition"]:
		return
	price = clampf(price + d, 0.0, 100.0)


func _on_player_hurt(_amount: int) -> void:
	if crashed or state == "final":
		return
	_move_price(RISE_PER_HIT)


## QUIEBRA: suena la campana, la bóveda se abre (daño x2) y queda torpe unos segundos.
func _crash() -> void:
	_interrupt()
	var tok := _tok
	state = "stunned"
	crashed = true
	bubble = false
	tank_open = true
	vault.open = true
	_face("QUIEBRA", Color(1, 0.3, 0.25))
	_holo.show_text("¡QUIEBRA!", Color(1, 0.3, 0.25), 1.6)
	_tw(stamp, "rotation", 0.9, 0.3)
	_tw(calc, "rotation", -0.9, 0.3)
	_pose(Vector2(0, 14), 0.08, 0.3)
	_shake(6.0, 0.4)
	GameFeel.flash(rig, 0.3, Color(1, 0.5, 0.4))
	stunned.emit()
	# monedas que saltan de la bóveda abierta
	for i in 8:
		var d := BossFx.Debris.new()
		d.kind = 1 if i % 2 == 0 else 6
		d.prefix = "boss_div0_debris_"
		d.vel = Vector2(randf_range(-220, 220), randf_range(-380, -180))
		get_parent().add_child(d)
		d.global_position = global_position + _home[vault]
	# tambaleo torpe mientras dura
	var steps := int(CRASH_TIME / 0.5)
	for i in steps:
		_pose(Vector2(0, 14), 0.08 * (1.0 if i % 2 == 0 else -1.0), 0.45)
		if not await _wait(0.5, tok):
			_end_crash()
			return
	_end_crash()
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.6
	_clear_face()


func _end_crash() -> void:
	if not crashed:
		return
	crashed = false
	tank_open = false
	vault.open = false
	price = 75.0
	crash_line = maxf(22.0, crash_line - 3.0)


# --- Bucle ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_price_step(delta)
	if state != "dead":
		var bob := sin(_t * 2.2) * 1.5
		rig.position = rig_off + Vector2(0, bob)
		head.anim_off = head.anim_off.lerp(Vector2(0, sin(_t * 2.2 - 0.7) * 1.5), minf(1.0, delta * 8.0))
		stamp.anim_rot = sin(_t * 2.0) * 0.05 if state == "idle" else 0.0
		calc.anim_rot = sin(_t * 2.0 + 1.2) * 0.05 if state == "idle" else 0.0
		legs.step += velocity.length() * delta
		if enraged:
			var k := 0.75 + 0.25 * absf(sin(_t * 9.0))
			rig.modulate = Color(1.0, k, k * 0.6)
		elif bubble:
			var k := 0.85 + 0.15 * absf(sin(_t * 5.0))
			rig.modulate = Color(1.0, 1.0, k)
		else:
			rig.modulate = Color.WHITE
	if _player_ok():
		z_index = 3 if _player_feet().y < global_position.y else 1
	match state:
		"idle":
			_ai_move(delta)
			if _player_ok() and _player_feet().distance_to(global_position) < 150.0:
				_near_t += delta
			else:
				_near_t = maxf(0.0, _near_t - delta)
			_cd -= delta
			if _cd <= 0.0:
				_choose_attack()
		_:
			velocity = Vector2.ZERO


func _ai_move(_delta: float) -> void:
	if not _player_ok():
		return
	var to := player.global_position - global_position
	var dist := to.length()
	var dir := Vector2.ZERO
	if dist > KEEP_DIST + 30.0:
		dir = to.normalized()
	elif dist < KEEP_DIST - 70.0:
		dir = -to.normalized() * 0.6
	velocity = dir * MOVE_SPEED * (1.0 + 0.2 * (phase - 1)) * (1.3 if bubble else 1.0)
	move_and_slide()
	rig.skew = lerpf(rig.skew, clampf(velocity.x / 700.0, -0.06, 0.06), 0.1)
	_clamp_inside()


func _clamp_inside() -> void:
	global_position.x = clampf(global_position.x, arena_rect.position.x + 90.0, arena_rect.end.x - 90.0)
	global_position.y = clampf(global_position.y, arena_rect.position.y + 310.0, arena_rect.end.y - 30.0)   # la cabeza no se mete bajo el panel


func _choose_attack() -> void:
	CoopBoss.retarget(self)
	var pick := ""
	if not _queue.is_empty():
		pick = _queue.pop_front()
	elif _near_t > 1.3:
		pick = "stomp"
	elif phase >= 2 and randf() < (0.3 if phase == 2 else 0.45) + (0.2 if bubble else 0.0):
		var list: Array = COMBOS[phase]
		_queue.assign(list[randi() % list.size()])
		if bubble:
			_queue.append("coins" if _queue.back() != "coins" else "stamp")
		pick = _queue.pop_front()
	else:
		var pool: Array[String] = ["stamp", "coins", "containers", "ledger"]
		if phase >= 2:
			pool.append_array(["org", "audit"])
		if phase >= 3:
			pool.append("spam")
		var bag: Array[String] = []
		for a in pool:
			if a != _last:
				bag.append(a)
		pick = bag[randi() % bag.size()]
	_near_t = 0.0
	_last = pick
	_tok += 1
	state = "attack"
	velocity = Vector2.ZERO
	call("_atk_" + pick, _tok)


func _end_attack(tok: int) -> void:
	if tok != _tok:
		return
	state = "idle"
	_rest_pose()
	_rest_arms()
	_cd = PAUSE[phase - 1] * (0.6 if enraged else 1.0) * (0.6 if bubble else 1.0)
	if not _queue.is_empty():
		_cd = 0.2
	_clear_face()


# --- Utilidades -----------------------------------------------------------------

## Multijugador: jugador que se está revisando en un `for v in _victims()` (el daño es para todos).
var _victim: Node2D = null


func _victims() -> Array:
	return CoopBoss.targets(get_tree()) if is_inside_tree() else []


func _who() -> Node2D:
	return _victim if _victim != null else player


func _player_ok() -> bool:
	var w := _who()
	return w != null and is_instance_valid(w)


func _player_body() -> Vector2:
	return _who().global_position + Vector2(0, -32)


func _player_feet() -> Vector2:
	return _who().global_position + Vector2(0, 12)


func _dir_to_player(from: Vector2) -> Vector2:
	if not _player_ok():
		return Vector2.DOWN
	var d := _player_body() - from
	return Vector2.DOWN if d.length() < 0.01 else d.normalized()


func _rot_for(dir: Vector2) -> float:
	return dir.angle() - PI * 0.5


func _tw(node: Object, prop: String, val: Variant, time: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(node, prop, val, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tweens.append(tw)
	return tw


func _wait(time: float, tok: int) -> bool:
	await get_tree().create_timer(time).timeout
	return tok == _tok and is_inside_tree()


func _clamp_arena(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, arena_rect.position.x + 30.0, arena_rect.end.x - 30.0),
		clampf(p.y, arena_rect.position.y + 40.0, arena_rect.end.y - 20.0))


func _add_fx(n: Node2D, at: Vector2) -> void:
	if "boss" in n:
		n.set("boss", self)
	if "player" in n:
		n.set("player", player)
	get_parent().add_child(n)
	n.global_position = at


func _shake(strength: float, time: float) -> void:
	if not _player_ok():
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := cam.create_tween()
	var steps := maxi(1, int(time / 0.03))
	for i in steps:
		var s := strength * (1.0 - float(i) / steps)
		tw.tween_property(cam, "offset", Vector2(randf_range(-s, s), randf_range(-s, s)), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.03)


func _pose(off: Vector2, rot: float, time: float) -> void:
	if _pose_tw and _pose_tw.is_valid():
		_pose_tw.kill()
	_pose_tw = create_tween().set_parallel(true)
	_pose_tw.tween_property(self, "rig_off", off, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tw.tween_property(rig, "rotation", rot, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _rest_pose(time: float = 0.3) -> void:
	_pose(Vector2.ZERO, 0.0, time)


func _rest_arms() -> void:
	_tw(stamp, "rotation", REST_L, 0.3)
	_tw(calc, "rotation", REST_R, 0.3)
	stamp.tool = 0
	calc.tool = 0


func _impact(at: Vector2, strength: float) -> void:
	_shake(strength, 0.1 + strength * 0.03)
	GameFeel.dust(get_parent(), at, int(4 + strength), Vector2.ZERO, 5.0, Vector2(20 + strength * 3.0, 6))
	GameFeel.hit_stop(get_tree(), 0.04)


func _warn_zone(at: Vector2, dir: Vector2, reach: float, half_angle: float, life: float) -> void:
	var z := BossFx.TeleZone.new()
	z.dir = dir
	z.reach = reach
	z.half_angle = half_angle
	z.life = life
	_add_fx(z, at)


func _interrupt() -> void:
	_tok += 1
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
	_queue.clear()
	velocity = Vector2.ZERO
	_rest_pose(0.2)
	for p in _parts():
		p.modulate = Color.WHITE
	visible = true
	modulate.a = 1.0


func hurt_player(amount: int, from: Vector2, unblockable: bool = false) -> void:
	if not _player_ok() or state == "dead" or state == "paused":
		return
	_who().call("take_hit", amount, from, unblockable)


func _on_player_parried(_from: Vector2) -> void:
	if _parry_watch:
		_was_parried = true


## Lo llama la lupa de Auditoría al encontrar al jugador: queda marcado y el próximo ataque es el sello.
func mark_player() -> void:
	if not _player_ok() or state == "dead":
		return
	var m := Fx.Mark.new()
	m.target = player
	get_parent().add_child(m)
	_marked = true
	if _queue.is_empty() or _queue[0] != "stamp":
		_queue.push_front("stamp")


## Lo llama cada sello al caer. Se puede hacer parry (cualquier dirección): lo deja aturdido.
func stamp_landed(s: Node2D) -> void:
	if state == "dead":
		return
	_impact(s.global_position, 5.0)
	var stun := false
	var any := false
	for v in _victims():
		s.set("_victim", v)
		var hit := bool(s.call("hits_player"))
		s.set("_victim", null)
		if not hit:
			continue
		any = true
		_victim = v
		_was_parried = false
		_parry_watch = true
		hurt_player(3 if _marked else 2, v.global_position, false)
		_parry_watch = false
		stun = stun or _was_parried
	_victim = null
	if not any:
		return
	_marked = false
	if stun:
		_parry_stun(2.2)


# --- Recibir daño ----------------------------------------------------------------

func take_hit(amount: int, from: Vector2) -> void:
	if state in ["intro", "transition", "dead", "paused", "final"]:
		GameFeel.flash(rig, 0.08, Color(0.6, 0.6, 0.7))
		return
	var dmg := amount * (2 if tank_open else 1)
	# a un golpe de caer en la fase 3: MARGIN CALL en vez de morir
	if phase >= 3 and not final_victory and hp - dmg <= 0:
		hp = 1
		hp_changed.emit(hp, MAX_HP)
		_start_final()
		return
	hp = maxi(0, hp - dmg)
	hp_changed.emit(hp, MAX_HP)
	if not crashed:
		_move_price(-DROP_PER_DMG * dmg)
	GameFeel.flash(rig, 0.1 + 0.02 * dmg, Color(1.0, 0.95, 0.9))
	GameFeel.squash(rig, Vector2(1.03, 0.97), 0.14, 0.0)
	GameFeel.hit_stop(get_tree(), 0.03 + 0.02 * mini(dmg, 3))
	var center := global_position + CENTER
	var toward := from - center
	toward = Vector2.DOWN if toward.length() < 0.01 else toward.normalized()
	head.anim_off += -toward * (4.0 + 2.0 * dmg)
	var num := BossFx.DmgNumber.new()
	num.text = str(dmg) + ("!" if tank_open else "")
	num.big = tank_open
	num.color = Color(1, 0.85, 0.3) if tank_open else Color(1, 1, 1)
	get_parent().add_child(num)
	num.global_position = center + toward * 46.0 + Vector2(0, -40)
	if tank_open:
		GameFeel.parry_burst(get_parent(), global_position + _home[vault], 34.0)
	else:
		var sp := BossFx.Sparks.new()
		sp.dir = toward
		get_parent().add_child(sp)
		sp.global_position = center + toward * 50.0
	if hp <= 0:
		_die()
		return
	if phase < 3 and hp <= int(MAX_HP * PHASE_AT[phase - 1]):
		_enter_phase(phase + 1)
		return
	if phase >= 3 and not enraged and hp <= int(MAX_HP * ENRAGE_AT):
		_enrage()
		return
	if not crashed and price <= crash_line and state in ["idle", "attack", "stunned"]:
		_crash()
		return
	if not tank_open and state in ["idle", "attack"]:
		_poise += dmg
		if _poise >= POISE[phase - 1]:
			_poise = 0
			_stagger()


func pull_toward(_dest: Vector2) -> void:
	GameFeel.flash(rig, 0.06, Color(0.7, 0.7, 0.8))


func debug_next_phase() -> void:
	if state in ["intro", "transition", "dead", "paused", "final"]:
		return
	if phase >= 3:
		hp = 1
		take_hit(1, global_position)
		return
	hp = int(MAX_HP * PHASE_AT[phase - 1])
	hp_changed.emit(hp, MAX_HP)
	_enter_phase(phase + 1)


func _stagger() -> void:
	_interrupt()
	var tok := _tok
	state = "stunned"
	_face("ERR?", Color(1, 0.8, 0.4))
	_pose(Vector2(0, 8), 0.07 * (1.0 if randf() < 0.5 else -1.0), 0.12)
	GameFeel.flash(rig, 0.2, Color(1, 0.9, 0.6))
	_shake(3.0, 0.2)
	staggered.emit()
	if not await _wait(0.9, tok):
		return
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.5
	_clear_face()


## Parry al sello: se le cae el sello en la cabeza. Aturdido, bóveda abierta y el precio cae.
func _parry_stun(time: float) -> void:
	_interrupt()
	var tok := _tok
	state = "stunned"
	tank_open = true
	vault.open = true
	_face("@_@", Color(1, 1, 0.4))
	_tw(stamp, "rotation", 1.0, 0.3)
	_tw(calc, "rotation", -0.8, 0.3)
	_pose(Vector2(0, 12), 0.06, 0.3)
	_shake(4.0, 0.25)
	stunned.emit()
	price = maxf(crash_line + 1.0, price - 10.0)
	if not await _wait(time, tok):
		if not crashed:
			tank_open = false
			vault.open = false
		return
	tank_open = false
	vault.open = false
	_rest_pose()
	_rest_arms()
	state = "idle"
	_cd = 0.6
	_clear_face()


func _enter_phase(n: int) -> void:
	phase = n
	_end_crash()
	tank_open = false
	_interrupt()
	var tok := _tok
	state = "transition"
	if n == 2:
		head.hat = false
		torso.loose = true
		ticker.red = true
		_face("RECESIÓN", Color(1, 0.45, 0.3))
		var h := HatFall.new()
		_add_fx(h, global_position + _home[head] + Vector2(0, -50))
	else:
		head.cracked = true
		torso.dirty = true
		_face("CRISIS", Color(1, 0.25, 0.2))
	GameFeel.flash(rig, 0.3, Color(1.0, 0.3, 0.3))
	_pose(Vector2(0, -12), 0.0, 0.25)
	_shake(7.0, 0.8)
	phase_changed.emit(n, "RECESIÓN" if n == 2 else "CRISIS FINANCIERA")
	if not await _wait(1.6, tok):
		return
	# lluvia de ataques: inmune hasta que termine (esquivar o parry)
	if not await Barrage.run(self, n, tok):
		return
	_rest_pose()
	state = "idle"
	_cd = 0.4
	_clear_face()


func _enrage() -> void:
	enraged = true
	_end_crash()
	tank_open = false
	_interrupt()
	var tok := _tok
	state = "transition"
	price = 90.0
	_face("$$$$", Color(1, 0.4, 0.3))
	_pose(Vector2(0, -14), 0.0, 0.3)
	GameFeel.flash(rig, 0.4, Color(1.0, 0.5, 0.3))
	_shake(9.0, 1.0)
	phase_changed.emit(3, "HIPERINFLACIÓN")
	if not await _wait(1.3, tok):
		return
	_rest_pose()
	state = "idle"
	_cd = 0.3
	_clear_face()


# --- Ataques ---------------------------------------------------------------------------

## 1. Sello DESPEDIDO (Talento Humano): la sombra sigue al jugador y cae el sello, x3. Parry = aturdido.
func _atk_stamp(tok: int) -> void:
	_face("DESPEDIDO", Color(1, 0.35, 0.3))
	stamp.tool = 0
	var n := 2 if phase == 1 else 3
	if phase >= 2 and get_tree().get_nodes_in_group("boss_minion").size() < 3:
		for i in 2:
			var b := Fx.Briefcase.new()
			_add_fx(b, _clamp_arena(global_position + Vector2(-70 + 140 * i, 30)))
	for i in n:
		_tw(stamp, "rotation", PI * 0.85, 0.35)
		_pose(Vector2(0, -10), -0.04, 0.35)
		var s := Fx.StampDrop.new()
		s.follow = [0.75, 0.6, 0.5][phase - 1]
		_add_fx(s, _player_feet() if _player_ok() else global_position)
		if not await _wait(s.follow + s.lock - 0.12, tok):
			return
		_tw(stamp, "rotation", 0.2, 0.1)
		_pose(Vector2(0, 8), 0.05, 0.08)
		if not await _wait(0.35, tok):
			return
	_end_attack(tok)


## 2. Interés compuesto (Finanzas): el cañón dispara monedas que se duplican al rebotar.
func _atk_coins(tok: int) -> void:
	_face("INTERÉS", Color(1, 0.85, 0.3))
	calc.tool = 2
	var hand: Vector2 = global_position + _home[calc]
	var aim := _dir_to_player(hand)
	_tw(calc, "rotation", _tool_rot(aim), 0.3)
	_pose(-aim * 8.0, -0.04, 0.3)
	if not await _wait(0.5, tok):
		return
	var n: int = [2, 3, 3][phase - 1]
	for i in n:
		aim = _dir_to_player(hand)
		_tw(calc, "rotation", _tool_rot(aim), 0.1)
		var c := Fx.Coin.new()
		c.arena = arena_rect
		c.max_gen = 3 if enraged else 2
		c.vel = aim.rotated(randf_range(-0.25, 0.25)) * (260.0 + 30.0 * phase)
		_add_fx(c, hand + aim * ARM_LEN)
		_pose(-aim * 14.0, 0.0, 0.06)
		_shake(2.0, 0.08)
		if not await _wait(0.3, tok):
			return
	if not await _wait(0.5, tok):
		return
	_end_attack(tok)


## 3. Comercio Exterior: contenedores por carriles. Uno siempre pasa por donde está el jugador.
func _atk_containers(tok: int) -> void:
	_face("IMPORTA", Color(0.5, 0.75, 1.0))
	stamp.tool = 2
	_tw(stamp, "rotation", PI * 0.6, 0.3)
	var lanes: Array[float] = []
	var top := arena_rect.position.y + 70.0
	var bottom := arena_rect.end.y - 30.0
	var count := 6
	for i in count:
		lanes.append(lerpf(top, bottom, i / float(count - 1)))
	var picks: Array[float] = []
	if _player_ok():
		picks.append(clampf(_player_feet().y, top, bottom))
	lanes.shuffle()
	var want: int = [3, 4, 4][phase - 1]
	for y in lanes:
		if picks.size() >= want:
			break
		if picks.is_empty() or absf(y - picks[0]) > 60.0:
			picks.append(y)
	for i in picks.size():
		var c := Fx.ShipContainer.new()
		c.color = i % 4
		var right := i % 2 == 0
		c.speed = (-1.0 if right else 1.0) * (720.0 + 60.0 * (phase - 1))
		c.delay = 0.9 + 0.35 * i
		c.min_x = arena_rect.position.x - 140.0
		c.max_x = arena_rect.end.x + 140.0
		var x := arena_rect.end.x + 120.0 if right else arena_rect.position.x - 120.0
		_add_fx(c, Vector2(x, picks[i]))
	if not await _wait(0.9 + 0.35 * picks.size() + 1.2, tok):
		return
	_end_attack(tok)


## 4. Partida doble (Contabilidad): números en el DEBE y luego en el HABER. Hay que cruzar a tiempo.
func _atk_ledger(tok: int) -> void:
	_face("DEBE|HABER", Color(0.55, 1.0, 0.55))
	calc.tool = 0
	_tw(calc, "rotation", -PI * 0.7, 0.3)
	var half := arena_rect.size.x * 0.5
	var left := Rect2(arena_rect.position, Vector2(half, arena_rect.size.y))
	var right := Rect2(arena_rect.position + Vector2(half, 0), Vector2(half, arena_rect.size.y))
	var first_left := not _player_ok() or _player_feet().x < arena_rect.get_center().x
	var rounds := 2 if phase < 3 else 3
	var w := 0.9 if phase == 1 else 0.75
	for i in rounds:
		var r := Fx.NumberRain.new()
		var on_left := first_left if i % 2 == 0 else not first_left
		r.rect = left if on_left else right
		r.label = "DEBE" if on_left else "HABER"
		r.warn = w
		r.active = w
		_add_fx(r, Vector2.ZERO)
		_pose(Vector2(-6 if on_left else 6, 0), 0.0, 0.2)
		if not await _wait(w, tok):
			return
	if not await _wait(w + 0.4, tok):
		return
	_end_attack(tok)


## 5. Organigrama (Administración): caen cajas de jefes unidas por láser. Romper una corta la cadena.
func _atk_org(tok: int) -> void:
	_face("JERARQUÍA", Color(0.8, 0.7, 1.0))
	stamp.tool = 2
	_tw(stamp, "rotation", PI * 0.75, 0.3)
	_tw(calc, "rotation", -PI * 0.75, 0.3)
	var chains := 1 if phase < 3 else 2
	for c in chains:
		var o := Fx.OrgChart.new()
		var py := _player_feet().y if _player_ok() else 0.0
		var y0 := clampf(py + (0.0 if c == 0 else (140.0 if py < 0.0 else -140.0)), arena_rect.position.y + 80.0, arena_rect.end.y - 40.0)
		var n := 5
		for i in n:
			var x := lerpf(arena_rect.position.x + 70.0, arena_rect.end.x - 70.0, i / float(n - 1))
			var y := y0 + (-55.0 if i % 2 == 0 else 55.0)
			o.spots.append(_clamp_arena(Vector2(x, y)))
		_add_fx(o, Vector2.ZERO)
	if not await _wait(0.8, tok):
		return
	_impact(global_position, 4.0)
	if not await _wait(2.4, tok):
		return
	_end_attack(tok)


## 6. Auditoría: la lupa barre la arena. Si te encuentra: daño, marca de OBSERVACIÓN y sello directo.
func _atk_audit(tok: int) -> void:
	_face("AUDITORÍA", Color(1, 0.9, 0.4))
	stamp.tool = 1
	var n := 1 if phase < 3 else 2
	for i in n:
		var l := Fx.AuditLens.new()
		var py := _player_feet().y if _player_ok() else 0.0
		var y := clampf(py + (0.0 if i == 0 else 150.0), arena_rect.position.y + 80.0, arena_rect.end.y - 50.0)
		var from_left := randf() < 0.5
		l.path_a = Vector2(arena_rect.position.x + 40.0 if from_left else arena_rect.end.x - 40.0, y)
		l.path_b = Vector2(arena_rect.end.x - 40.0 if from_left else arena_rect.position.x + 40.0, y)
		l.time = 2.6 if phase < 3 else 2.2
		_add_fx(l, l.path_a)
	var t := 0.0
	while t < 2.6:
		_tw(stamp, "rotation", _rot_for(_dir_to_player(global_position + _home[stamp])), 0.2)
		if not await _wait(0.2, tok):
			return
		t += 0.2
	_end_attack(tok)


## 7. Marketing: ventanas emergentes que tapan la vista y luego el megáfono.
func _atk_spam(tok: int) -> void:
	_face("¡OFERTA!", Color(1, 0.45, 0.8))
	calc.tool = 1
	var n := 3 if not enraged else 4
	for i in n:
		var p := Fx.AdPopup.new()
		var at := global_position + Vector2(randf_range(-320, 320), randf_range(-200, 120))
		if _player_ok() and i == 0:
			at = player.global_position + Vector2(randf_range(-90, 90), randf_range(-140, -80))
		get_parent().add_child(p)
		p.global_position = _clamp_arena(at)
		if not await _wait(0.15, tok):
			return
	var hand: Vector2 = global_position + _home[calc]
	var aim := _dir_to_player(global_position)
	_tw(calc, "rotation", _tool_rot(aim), 0.3)
	_warn_zone(global_position + Vector2(0, -10), aim, 330.0, 0.42, 0.7)
	_pose(-aim * 10.0, 0.0, 0.5)
	if not await _wait(0.7, tok):
		return
	var cone := Fx.MegaCone.new()
	cone.dir = aim
	_add_fx(cone, global_position + Vector2(0, -10))
	_pose(aim * 12.0, 0.0, 0.08)
	_shake(4.0, 0.3)
	if not await _wait(0.8, tok):
		return
	_end_attack(tok)


## 8. Pisotón de los archivadores (si el jugador se queda pegado).
func _atk_stomp(tok: int) -> void:
	_face("!!", Color(1, 0.5, 0.3))
	var max_r := 260.0 if phase < 3 else 330.0
	_warn_zone(global_position, Vector2.DOWN, max_r, 0.0, 0.9)
	_pose(Vector2(0, -40), 0.0, 0.6)
	_tw(self, "fold", -0.4, 0.6)
	if not await _wait(0.9, tok):
		fold = 0.0
		return
	fold = 0.0
	_pose(Vector2(0, 6), 0.0, 0.07)
	_impact(global_position, 9.0)
	var ring := BossFx.ShockRing.new()
	ring.max_r = max_r
	_add_fx(ring, global_position)
	if not await _wait(0.6, tok):
		return
	_end_attack(tok)


# --- Aparición y muerte -----------------------------------------------------------


# --- MARGIN CALL (duelo final) ------------------------------------------------------------
## A un golpe de caer: abre la bóveda y te lanza lingotes y monedas. Cada parry VENDE (la acción baja);
## cada uno que te pega COMPRA (sube). Lleva la acción a 0 antes de la campana de cierre del mercado.
func _start_final() -> void:
	_interrupt()
	_end_crash()
	var tok := _tok
	state = "final"
	bubble = false
	_final_fail = false
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for n in get_tree().get_nodes_in_group("div0_news"):
		n.queue_free()
	price = 100.0
	final_left = FINAL_TIME
	Final.title(self, "MARGIN CALL", Color(1.0, 0.8, 0.3), "Parry a los lingotes para VENDER")
	Final.music_cue(self, "final1")
	_face("$$$", Color(1, 0.85, 0.3))
	var spot := Vector2(0.0, arena_rect.position.y + 330.0)
	_tw(self, "global_position", spot, 0.6)
	# la bóveda se abre de golpe (rebota)
	vault.open = true
	_pose(Vector2(0, -10), 0.0, 0.25)
	_shake(5.0, 0.4)
	var bell := Bell.new()
	bell.boss = self
	add_child(bell)
	bell.position = Vector2(0, 26)   # bajo los pies: no tapa la cabeza
	if not await _wait(1.2, tok):
		return
	var cd := 0.0
	var side := 1.0
	while price > 0.0 and final_left > 0.0 and not _final_fail:
		if not await _wait(0.05, tok):
			return
		final_left -= 0.05
		cd -= 0.05
		if cd <= 0.0:
			var heat := 1.0 - price / 100.0
			cd = lerpf(0.95, 0.5, heat)
			side = -side
			_throw_gold(side, tok)
			if heat > 0.5 and randf() < 0.35:
				_throw_gold(-side, tok)
	if is_instance_valid(bell):
		bell.queue_free()
	if price <= 0.0:
		_final_won()
	else:
		_final_lost(tok)


## ANTICIPACIÓN: echa la calculadora atrás y lanza un lingote (o moneda) desde la bóveda.
func _throw_gold(side: float, tok: int) -> void:
	var from: Vector2 = global_position + _home[vault] + Vector2(side * 30.0, 0)
	var arm: Part = calc if side > 0.0 else stamp
	var tw := create_tween()
	tw.tween_property(arm, "rotation", (-1.6 if side > 0.0 else 1.6), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if tok != _tok or state != "final" or not _player_ok():
			return
		var aim := _dir_to_player(from)
		arm.rotation = _tool_rot(aim)
		_pose(aim * 8.0, side * 0.03, 0.06)
		var g := GoldShot.new()
		g.bar = randf() < 0.6
		g.col = Color(1.0, 0.82, 0.3)
		g.damage = 1
		g.target = _home[vault]
		_add_fx(g, from)
		g.aim_at(_player_body(), lerpf(300.0, 430.0, 1.0 - price / 100.0))
		GameFeel.dust(get_parent(), from, 2, Vector2.ZERO, 2.0, Vector2(6, 6)))
	tw.tween_property(arm, "rotation", REST_R if side > 0.0 else REST_L, 0.3)


func final_result(ok: bool, _shot: Node) -> void:
	if state != "final":
		return
	if ok:
		price = maxf(0.0, price - SELL)
		_holo.show_text("VENDE ▼ %d" % int(price), Color(1, 0.4, 0.35), 0.5)
		GameFeel.hit_stop(get_tree(), 0.04)
	else:
		price = minf(100.0, price + BUY)
		_holo.show_text("COMPRA ▲ %d" % int(price), Color(0.5, 1, 0.5), 0.5)
	if price <= 66.0 and price + SELL > 66.0:
		Final.music_cue(self, "final2")
	elif price <= 33.0 and price + SELL > 33.0:
		Final.music_cue(self, "final3")


## El lingote devuelto entra en la bóveda.
func final_back(shot: Node2D) -> void:
	GameFeel.parry_burst(get_parent(), shot.global_position, 24.0)
	head.anim_off += Vector2(0, -4)
	GameFeel.flash(rig, 0.06, Color(1, 0.9, 0.5))
	shot.queue_free()


func _final_won() -> void:
	final_victory = true
	for h in get_tree().get_nodes_in_group("final_shot"):
		h.queue_free()
	Final.music_final(self, "epic")
	Final.title(self, "QUIEBRA TOTAL", Color(1.0, 0.35, 0.3), "La acción vale 0", 1.4)
	await _finisher()
	_shake(12.0, 0.8)
	hp = 0
	hp_changed.emit(hp, MAX_HP)
	_die()


func _final_lost(tok: int) -> void:
	for h in get_tree().get_nodes_in_group("final_shot"):
		h.queue_free()
	vault.open = false
	price = START_PRICE
	Final.title(self, "CIERRE DEL MERCADO", Color(1.0, 0.85, 0.3), "La acción sobrevivió", 1.1)
	Final.music_cue(self, "p3")
	_clear_face()
	_rest_pose()
	_rest_arms()
	if not await _wait(1.0, tok):
		return
	state = "idle"
	_cd = 1.0


# --- Lluvia de cambio de fase propia: CRASH BURSÁTIL --------------------------------------
## Monedas que rebotan por todos lados, contenedores por los carriles, lluvia de cifras en el DEBE y
## el HABER y sellos de QUIEBRA que te persiguen.
func barrage_title(_n: int) -> String:
	return "CRASH BURSÁTIL"


func barrage_plan(n: int) -> Array:
	if n == 2:
		return [[0.2, "coins", {"n": 8}], [1.2, "containers", {"n": 3}], [3.2, "ledger", {}],
			[4.8, "stamps", {"n": 2}], [6.0, "coins", {"n": 10}]]
	return [[0.2, "coins", {"n": 10}], [1.0, "containers", {"n": 4}], [2.6, "ledger", {}],
		[3.6, "stamps", {"n": 3}], [5.0, "coins", {"n": 12}], [5.6, "containers", {"n": 4}], [7.6, "ledger", {}]]


func _bfx(n: Node2D, at: Vector2) -> void:
	_add_fx(n, at)
	Barrage.tag(n)


func _bar_coins(a: Dictionary, _tok: int) -> void:
	var n: int = a["n"]
	for i in n:
		var c := Fx.Coin.new()
		c.arena = arena_rect
		c.max_gen = 1
		c.vel = Vector2.from_angle(TAU * i / n + randf() * 0.3) * 300.0
		_bfx(c, global_position + _home[vault])
	_shake(3.0, 0.15)


func _bar_containers(a: Dictionary, _tok: int) -> void:
	var top := arena_rect.position.y + 70.0
	var bottom := arena_rect.end.y - 30.0
	var n: int = a["n"]
	var ys: Array[float] = []
	if _player_ok():
		ys.append(clampf(_player_feet().y, top, bottom))
	while ys.size() < n:
		var y := randf_range(top, bottom)
		var ok := true
		for o in ys:
			ok = ok and absf(o - y) > 70.0
		if ok:
			ys.append(y)
	for i in n:
		var c := Fx.ShipContainer.new()
		c.color = i % 4
		var right := i % 2 == 0
		c.speed = (-1.0 if right else 1.0) * 760.0
		c.delay = 0.8 + 0.3 * i
		c.min_x = arena_rect.position.x - 140.0
		c.max_x = arena_rect.end.x + 140.0
		_bfx(c, Vector2(arena_rect.end.x + 120.0 if right else arena_rect.position.x - 120.0, ys[i]))


func _bar_ledger(_a: Dictionary, tok: int) -> void:
	var half := arena_rect.size.x * 0.5
	var left := Rect2(arena_rect.position, Vector2(half, arena_rect.size.y))
	var right := Rect2(arena_rect.position + Vector2(half, 0), Vector2(half, arena_rect.size.y))
	var on_left := not _player_ok() or _player_feet().x < arena_rect.get_center().x
	for i in 2:
		var r := Fx.NumberRain.new()
		r.rect = left if on_left else right
		r.label = "DEBE" if on_left else "HABER"
		r.warn = 0.75
		r.active = 0.75
		_bfx(r, Vector2.ZERO)
		on_left = not on_left
		if not await _wait(0.75, tok):
			return


func _bar_stamps(a: Dictionary, tok: int) -> void:
	for i in int(a["n"]):
		var s := Fx.StampDrop.new()
		s.follow = 0.6
		_bfx(s, _player_feet() if _player_ok() else global_position)
		if not await _wait(0.6, tok):
			return


## REMATE: el gráfico de la acción se desploma cruzando la pantalla, se estampa #DIV/0! en la bóveda
## y llueven las monedas que le quedaban.
func _finisher() -> void:
	var cc := Final.CrashChart.new()
	get_parent().add_child(cc)
	_face("▼▼▼", Color(1, 0.3, 0.25))
	await get_tree().create_timer(0.9).timeout
	var st := Final.StampSlam.new()
	st.text = "#DIV/0!"
	st.col = Color(0.95, 0.2, 0.2)
	get_parent().add_child(st)
	st.global_position = global_position
	await get_tree().create_timer(0.36).timeout
	_shake(9.0, 0.4)
	_pose(Vector2(0, 14), 0.06, 0.1)
	for i in 14:
		var d := BossFx.Debris.new()
		d.kind = 1 if i % 2 == 0 else 6
		d.prefix = "boss_div0_debris_"
		d.vel = Vector2(randf_range(-260, 260), randf_range(-460, -200))
		get_parent().add_child(d)
		d.global_position = global_position + _home[vault]
	await get_tree().create_timer(0.7).timeout



func start_intro(skip: bool) -> void:
	state = "intro"
	if skip:
		await get_tree().create_timer(0.6).timeout
		intro_finished.emit()
		return
	# 1. campana de apertura y lluvia de cinta de la bolsa
	for p in _parts():
		p.visible = false
	head.hat = false
	var home := position
	await get_tree().create_timer(0.4).timeout
	for i in 3:
		_holo.show_text("DING", Color(1, 0.85, 0.3), 0.3)
		_shake(2.0, 0.1)
		await get_tree().create_timer(0.38).timeout
	var rain := Fx.PaperRain.new()
	rain.area = arena_rect
	rain.life = 3.0
	get_parent().add_child(rain)
	await get_tree().create_timer(0.5).timeout
	# 2. la bóveda cae del cielo con las patas plegadas
	fold = 1.0
	for p in [legs, torso, vault, ticker]:
		p.visible = true
	position = home + Vector2(0, -360)
	var tw := create_tween()
	tw.tween_property(self, "position", home, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	GameFeel.dust(get_parent(), global_position, 12, Vector2(0, 30), 6.0, Vector2(80, 8))
	_shake(8.0, 0.4)
	await get_tree().create_timer(0.6).timeout
	# 3. el monitor se enciende con el error
	head.visible = true
	head.boot = 0.0
	create_tween().tween_property(head, "boot", 1.0, 0.8)
	await get_tree().create_timer(0.9).timeout
	_face("#DIV/0!", Color(1, 0.3, 0.25))
	await get_tree().create_timer(1.0).timeout
	# 4. se despliegan las patas y los brazos
	var up := create_tween()
	up.tween_property(self, "fold", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await up.finished
	_shake(3.0, 0.2)
	stamp.visible = true
	calc.visible = true
	stamp.rotation = -1.4
	calc.rotation = 1.4
	_tw(stamp, "rotation", REST_L, 0.3)
	_tw(calc, "rotation", REST_R, 0.3)
	await get_tree().create_timer(0.4).timeout
	# el sombrero de copa cae a la cabeza
	head.hat = true
	head.hat_y = -160.0
	var hat := create_tween()
	hat.tween_property(head, "hat_y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await hat.finished
	# firma: se quita el sombrero de copa como un mago y llueven monedas
	_face("$_$", Color(0.5, 1.0, 0.5))
	_tw(calc, "rotation", -2.75, 0.2)             # la mano va al sombrero
	await get_tree().create_timer(0.2).timeout
	var lift := create_tween()
	lift.tween_property(head, "hat_y", -46.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await lift.finished
	var co := Roar.Coins.new()
	Roar.spawn(get_parent(), co, head.global_position + Vector2(0, -60))
	_shake(6.0, 0.5)
	_tw(stamp, "rotation", 0.9, 0.15)
	await get_tree().create_timer(0.55).timeout
	var down := create_tween()
	down.tween_property(head, "hat_y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tw(calc, "rotation", REST_R, 0.25)
	_tw(stamp, "rotation", REST_L, 0.25)
	await get_tree().create_timer(0.7).timeout
	_clear_face()
	intro_finished.emit()


func begin_fight() -> void:
	state = "idle"
	_cd = 1.0


func pause_ai() -> void:
	_interrupt()
	state = "paused"


func _die() -> void:
	_interrupt()
	state = "dead"
	tank_open = false
	crashed = false
	remove_from_group("enemies")
	for h in get_tree().get_nodes_in_group("boss_hazard"):
		h.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		m.call("die")
	for c in get_tree().get_nodes_in_group("enemies"):
		if c is Fx.Coin:
			c.queue_free()
	# el gráfico se desploma a cero en cámara lenta
	Engine.time_scale = 0.2
	_face("#DIV/0!", Color(1, 0.3, 0.25))
	var fall_price := create_tween()
	fall_price.tween_property(self, "price", 0.0, 0.25)
	await get_tree().create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 1.0
	_pose(Vector2(0, 8), 0.0, 0.4)
	await get_tree().create_timer(0.8).timeout
	# pantalla de bancarrota
	var bk := Fx.Bankrupt.new()
	get_parent().add_child(bk)
	await get_tree().create_timer(2.6).timeout
	# la bóveda revienta en billetes y se desarma
	vault.broken = true
	head.cracked = true
	var money := Fx.PaperRain.new()
	money.money = true
	money.life = 2.0
	money.area = Rect2(global_position + Vector2(-260, -200), Vector2(520, 300))
	get_parent().add_child(money)
	GameFeel.parry_burst(get_parent(), global_position + _home[vault], 70.0)
	for i in 14:
		var d := BossFx.Debris.new()
		d.kind = i % 8
		d.prefix = "boss_div0_debris_"
		d.vel = Vector2(randf_range(-280, 280), randf_range(-440, -200))
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-180, -60))
	for p in [stamp, calc]:
		var tw := create_tween()
		tw.tween_property(p, "rotation", (1.0 if p == stamp else -1.0) * 1.6, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(self, "fold", 1.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(self, "rig_off", Vector2(0, 40), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(head, "anim_off", Vector2(40, 110), 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(head, "rotation", 1.3, 0.6)
	_shake(8.0, 0.4)
	GameFeel.dust(get_parent(), global_position, 14, Vector2.ZERO, 7.0, Vector2(80, 10))
	await get_tree().create_timer(1.4).timeout
	create_tween().tween_property(rig, "modulate", Color(0.4, 0.4, 0.45, 0.0), 1.2)
	await get_tree().create_timer(1.0).timeout
	defeated.emit()


# --- Dibujo (provisional, hasta tener los sprites) --------------------------------------

class Part extends Node2D:
	var kind := ""
	var boss: Node
	var t := 0.0
	var anim_off := Vector2.ZERO
	var anim_rot := 0.0
	var step := 0.0
	# estados
	var open := false
	var broken := false
	var hat := true
	var hat_y := 0.0
	var cracked := false
	var loose := false
	var dirty := false
	var red := false
	var boot := 1.0
	var tool := 0
	var face := ""
	var face_color := Color(0.45, 1.0, 0.5)

	const OUT := Color(0.05, 0.05, 0.06)
	const STEEL := Color(0.55, 0.58, 0.62)
	const STEEL_D := Color(0.38, 0.4, 0.45)
	const STEEL_L := Color(0.72, 0.75, 0.78)
	const GOLD := Color(0.98, 0.78, 0.2)
	const MONEY := Color(0.35, 0.72, 0.4)
	const NAVY := Color(0.16, 0.2, 0.32)
	const TIE := Color(0.8, 0.12, 0.14)
	const CAB := Color(0.42, 0.5, 0.46)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _box(r: Rect2, col: Color, w: float = 2.0) -> void:
		draw_rect(r, col)
		draw_rect(r, OUT, false, w)

	func _draw() -> void:
		draw_set_transform(anim_off, anim_rot, Vector2.ONE)
		if _draw_sprite():
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		match kind:
			"legs":
				_legs()
			"torso":
				_torso()
			"vault":
				_vault()
			"ticker":
				_ticker()
			"head":
				_head()
			"stamp":
				_stamp_arm()
			"calc":
				_calc_arm()

	# --- con sprites de grokbot (se ajusta al llegar las hojas) ---
	# pantalla de cada cabeza (x, y, ancho, alto) en px de la imagen, para el texto de la cara
	const SCREENS := [Rect2(20, 27, 27, 20), Rect2(20, 5, 27, 20), Rect2(23, 6, 29, 24)]
	# centro del círculo de la puerta en cada sprite de bóveda (la bisagra queda a un lado)
	const VAULT_C := [Vector2(37, 42), Vector2(31, 42), Vector2(39, 45)]

	func _draw_sprite() -> bool:
		var body := Spr.tex("boss_div0_body_0")
		if body == null:
			return false
		match kind:
			"legs", "ticker":
				return true   # las patas y la cinta ya vienen en el sprite del cuerpo
			"torso":
				var tx: Texture2D = Spr.tex("boss_div0_body_1") if dirty else body
				if tx == null:
					tx = body
				# se aplasta desde los pies (patas plegadas) y se estira en el pisotón
				var lift := position.y
				var k := BODY_H / tx.get_height()
				var sy := (1.0 - (58.0 - float(boss.call("leg_height", boss.get("fold")))) / BODY_H) * k
				draw_set_transform(anim_off + Vector2(0, -lift), anim_rot, Vector2(k, sy))
				draw_texture(tx, Vector2(-tx.get_width() * 0.5, -tx.get_height()))
				return true
			"vault":
				var idx := 2 if broken else (1 if open else 0)
				var tx := Spr.tex("boss_div0_vault_%d" % idx)
				if tx == null:
					return false
				if open and not broken:
					draw_circle(anim_off, 40.0 + 3.0 * sin(t * 10.0), Color(1, 0.85, 0.3, 0.25))
				draw_texture(tx, anim_off - VAULT_C[idx])
				return true
			"head":
				var idx := 2 if cracked else (0 if hat else 1)
				var tx := Spr.tex("boss_div0_head_%d" % idx)
				if tx == null:
					return false
				var hy := hat_y if idx == 0 else 0.0
				if idx == 0 and hat_y != 0.0:
					# el sombrero cae durante la aparición: cabeza sin sombrero + sombrero suelto encima
					var bare := Spr.tex("boss_div0_head_1")
					var h3 := Spr.tex("boss_div0_head_3")
					if bare and h3:
						tx = bare
						idx = 1
						Spr.draw_centered(self, h3, anim_off + Vector2(0, -bare.get_height() - 8 + hy))
				var origin := anim_off + Vector2(-tx.get_width() * 0.5, -tx.get_height())
				draw_texture(tx, origin)
				var scr: Rect2 = SCREENS[idx]
				scr.position += origin
				if face != "":
					var fs := 9 if face.length() <= 5 else 6
					draw_rect(scr, Color(0.04, 0.18, 0.1))
					draw_string(ThemeDB.fallback_font, scr.position + Vector2(0, scr.size.y * 0.5 + fs * 0.35), face, HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, fs, face_color)
				elif boot < 1.0:
					draw_rect(scr, Color(1, 1, 1, (1.0 - boot) * 0.5 * absf(sin(t * 40.0))))
				else:
					# ojos $ $ que parpadean
					var blink := fmod(t, 3.0) < 0.12
					if not blink:
						draw_string(ThemeDB.fallback_font, scr.position + Vector2(0, scr.size.y * 0.5 + 4), "$ $", HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, 11, Color(0.5, 1.0, 0.5))
				return true
			"stamp", "calc":
				var name := "boss_div0_%s_%d" % ["stamp" if kind == "stamp" else "tool", tool]
				var tx := Spr.tex(name)
				if tx == null:
					return false
				var piv := Spr.top_pivot(name)
				draw_set_transform(anim_off, anim_rot - Spr.lean(name), Vector2.ONE)
				draw_texture(tx, -piv)
				return true
		return false

	# --- por código ---
	func _legs() -> void:
		var h: float = boss.call("leg_height", boss.get("fold"))
		# atrás (más oscuras) y adelante
		for row in 2:
			var xs := [-52.0, 52.0] if row == 0 else [-22.0, 22.0]
			for j in 2:
				var x: float = xs[j]
				var lift := maxf(0.0, sin(step * 0.07 + (j + row) * PI)) * 6.0
				var base := -6.0 if row == 0 else 0.0
				var col := CAB.darkened(0.25) if row == 0 else CAB
				var r := Rect2(x - 15, base - h - lift, 30, h)
				_box(r, col)
				var drawers := 3
				for k in drawers:
					var dy := r.position.y + 4 + k * (h - 6) / drawers
					draw_rect(Rect2(x - 12, dy, 24, (h - 6) / drawers - 3), col.lightened(0.12))
					draw_rect(Rect2(x - 5, dy + 4, 10, 3), STEEL_L)
				draw_rect(Rect2(x - 16, base - 4 - lift, 32, 5), OUT)

	func _torso() -> void:
		draw_set_transform(anim_off, anim_rot, Vector2.ONE)
		# bóveda
		var body := Rect2(-60, -176, 120, 120)
		_box(body, STEEL, 3.0)
		draw_rect(Rect2(-60, -176, 120, 10), STEEL_L)
		draw_rect(Rect2(-60, -66, 120, 10), STEEL_D)
		for p in [Vector2(-52, -168), Vector2(52, -168), Vector2(-52, -64), Vector2(52, -64)]:
			draw_circle(p, 3, STEEL_D)
		# chaleco a los lados
		for s in [-1.0, 1.0]:
			var v := PackedVector2Array([Vector2(60 * s, -170), Vector2(36 * s, -170), Vector2(42 * s, -140), Vector2(46 * s, -60), Vector2(60 * s, -60)])
			draw_colored_polygon(v, NAVY)
			v.append(v[0])
			draw_polyline(v, OUT, 2.0)
			for k in 3:
				draw_circle(Vector2(50 * s, -128 + k * 22), 3, GOLD)
		# cuello de camisa y corbata
		draw_colored_polygon(PackedVector2Array([Vector2(-18, -176), Vector2(18, -176), Vector2(0, -160)]), Color(0.95, 0.95, 0.92))
		var sway := sin(t * 3.0) * (6.0 if loose else 1.0)
		var tie := PackedVector2Array([Vector2(-5, -166), Vector2(5, -166), Vector2(9 + sway, -140), Vector2(sway, -132), Vector2(-9 + sway, -140)])
		if loose:
			draw_set_transform(anim_off + Vector2(0, -166), anim_rot + 0.35, Vector2.ONE)
			tie = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(9 + sway, 26), Vector2(sway, 34), Vector2(-9 + sway, 26)])
		draw_colored_polygon(tie, TIE)
		tie.append(tie[0])
		draw_polyline(tie, OUT, 1.5)
		draw_set_transform(anim_off, anim_rot, Vector2.ONE)
		# hombreras
		for s in [-1.0, 1.0]:
			_box(Rect2(68 * s - 14, -172, 28, 22), STEEL_D)
		if dirty:
			draw_line(Vector2(-50, -150), Vector2(-30, -120), OUT, 2.0)
			draw_line(Vector2(-30, -120), Vector2(-38, -100), OUT, 2.0)
			draw_line(Vector2(40, -80), Vector2(28, -70), OUT, 2.0)

	func _vault() -> void:
		var o := anim_off
		draw_set_transform(o, 0.0, Vector2.ONE)
		var r := 32.0
		if open or broken:
			# interior con oro
			draw_circle(Vector2.ZERO, r, Color(0.12, 0.1, 0.06))
			if not broken:
				for k in 3:
					draw_rect(Rect2(-20 + k * 13, 8 - k % 2 * 8, 12, 8), GOLD)
					draw_rect(Rect2(-20 + k * 13, 8 - k % 2 * 8, 12, 8), OUT, false, 1.0)
				draw_circle(Vector2.ZERO, r + 6.0 + 3.0 * sin(t * 10.0), Color(1, 0.85, 0.3, 0.25))
			draw_arc(Vector2.ZERO, r, 0, TAU, 24, OUT, 2.5)
			# puerta abierta de lado
			draw_set_transform(o + Vector2(r + 6, 0), 0.0, Vector2(0.3, 1.0))
			draw_circle(Vector2.ZERO, r, STEEL_L)
			draw_arc(Vector2.ZERO, r, 0, TAU, 24, OUT, 3.0)
			draw_set_transform(o, 0.0, Vector2.ONE)
			if broken:
				for i in 5:
					var a := TAU * i / 5.0 + 0.3
					draw_line(Vector2.ZERO, Vector2.from_angle(a) * (r + 10), OUT, 2.0)
			return
		draw_circle(Vector2.ZERO, r, STEEL_L)
		draw_circle(Vector2.ZERO, r - 6, STEEL)
		draw_arc(Vector2.ZERO, r, 0, TAU, 24, OUT, 2.5)
		# rueda
		for i in 4:
			var d := Vector2.from_angle(TAU * i / 4.0 + t * 0.3)
			draw_line(-d * 18.0, d * 18.0, STEEL_D, 4.0)
			draw_circle(d * 18.0, 4, GOLD)
		draw_circle(Vector2.ZERO, 6, GOLD)

	func _ticker() -> void:
		draw_set_transform(anim_off, 0.0, Vector2.ONE)
		var band := Rect2(-64, -8, 128, 14)
		draw_rect(band, Color(0.05, 0.05, 0.06))
		draw_rect(band, STEEL_D, false, 2.0)
		var col := Color(1, 0.3, 0.25) if red else Color(0.4, 1.0, 0.5)
		var txt := "DIV0 ▼ -12.5%  CRASH  " if red else "DIV0 ▲ +3.2%  BOLSA  "
		var f := ThemeDB.fallback_font
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var x0 := -64.0 - fmod(t * 40.0, w)
		while x0 < 64.0:
			for ch in txt.length():
				var cx := x0 + f.get_string_size(txt.substr(0, ch), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				if cx > -64.0 and cx < 58.0:
					draw_string(f, Vector2(cx, 3), txt[ch], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
			x0 += w

	func _head() -> void:
		var o := anim_off
		draw_set_transform(o, anim_rot, Vector2.ONE)
		# cuello y monitor
		draw_rect(Rect2(-8, 8, 16, 14), STEEL_D)
		_box(Rect2(-38, -36, 76, 48), Color(0.2, 0.22, 0.25), 2.5)
		var scr := Rect2(-32, -30, 64, 36)
		draw_rect(scr, Color(0.02, 0.08, 0.04) if boot >= 1.0 else Color(0.02, 0.08, 0.04).lerp(Color.WHITE, (1.0 - boot) * 0.5 * absf(sin(t * 40.0))))
		if boot >= 0.3:
			# cuadrícula de hoja de cálculo
			for i in 5:
				draw_line(Vector2(-32 + i * 16, -30), Vector2(-32 + i * 16, 6), Color(0.1, 0.35, 0.15), 1.0)
			for j in 4:
				draw_line(Vector2(-32, -30 + j * 12), Vector2(32, -30 + j * 12), Color(0.1, 0.35, 0.15), 1.0)
		if face != "":
			var fs := 13 if face.length() <= 5 else 9
			draw_rect(Rect2(-32, -20, 64, 16), Color(0.02, 0.08, 0.04, 0.85))
			draw_string(ThemeDB.fallback_font, Vector2(-32, -12 + fs * 0.35), face, HORIZONTAL_ALIGNMENT_CENTER, 64, fs, face_color)
		elif boot >= 1.0:
			# ojos de signo $
			draw_string(ThemeDB.fallback_font, Vector2(-32, -6), "$   $", HORIZONTAL_ALIGNMENT_CENTER, 64, 14, Color(0.5, 1.0, 0.5))
		if cracked:
			draw_polyline(PackedVector2Array([Vector2(-20, -30), Vector2(-8, -16), Vector2(-14, -4), Vector2(2, 6)]), Color(0.85, 0.9, 0.9), 1.5)
			draw_polyline(PackedVector2Array([Vector2(-8, -16), Vector2(10, -20)]), Color(0.85, 0.9, 0.9), 1.5)
		draw_rect(Rect2(-38, 6, 76, 6), Color(0.3, 0.32, 0.35))
		draw_circle(Vector2(30, 9), 2, Color(0.4, 1.0, 0.5))
		# sombrero de copa
		if hat:
			var hy := -36.0 + hat_y
			_box(Rect2(-30, hy - 4, 60, 6), Color(0.08, 0.08, 0.1))
			_box(Rect2(-20, hy - 42, 40, 40), Color(0.08, 0.08, 0.1))
			draw_rect(Rect2(-20, hy - 12, 40, 7), GOLD)

	func _arm(len_up: float) -> void:
		draw_circle(Vector2.ZERO, 12, STEEL_D)
		_box(Rect2(-7, 0, 14, len_up), STEEL)
		draw_circle(Vector2(0, len_up), 8, STEEL_D)
		_box(Rect2(-6, len_up, 12, 30), STEEL_L)
		draw_rect(Rect2(-8, len_up + 26, 16, 6), NAVY)   # puño del traje
		draw_arc(Vector2.ZERO, 12, 0, TAU, 14, OUT, 2.0)

	func _stamp_arm() -> void:
		_arm(48.0)
		match tool:
			0:   # sello de goma gigante
				_box(Rect2(-6, 84, 12, 14), Color(0.55, 0.35, 0.2))
				_box(Rect2(-22, 96, 44, 14), Color(0.45, 0.3, 0.18))
				draw_rect(Rect2(-24, 110, 48, 8), Color(0.75, 0.1, 0.1))
				draw_rect(Rect2(-24, 110, 48, 8), OUT, false, 1.5)
			1:   # lupa
				draw_line(Vector2(0, 84), Vector2(0, 100), Color(0.4, 0.25, 0.15), 6.0)
				draw_circle(Vector2(0, 118), 20, Color(0.75, 0.9, 1.0, 0.45))
				draw_arc(Vector2(0, 118), 20, 0, TAU, 20, GOLD, 4.0)
				draw_arc(Vector2(0, 118), 22, 0, TAU, 20, OUT, 1.5)
				draw_line(Vector2(-8, 110), Vector2(-2, 104), Color(1, 1, 1, 0.8), 2.0)
			_:   # gancho de grúa
				draw_line(Vector2(0, 84), Vector2(0, 104), STEEL_D, 3.0)
				draw_arc(Vector2(0, 112), 10, -PI * 0.5, PI, 12, Color(0.95, 0.75, 0.15), 5.0)
				draw_arc(Vector2(0, 112), 12, -PI * 0.5, PI, 12, OUT, 1.5)

	func _calc_arm() -> void:
		_arm(48.0)
		match tool:
			0:   # calculadora
				_box(Rect2(-18, 84, 36, 46), Color(0.25, 0.27, 0.3))
				draw_rect(Rect2(-14, 88, 28, 10), Color(0.6, 0.75, 0.55))
				for i in 3:
					for j in 3:
						draw_rect(Rect2(-13 + i * 9, 102 + j * 9, 7, 6), Color(0.85, 0.85, 0.82) if (i + j) % 3 else Color(1, 0.6, 0.3))
			1:   # megáfono
				var cone := PackedVector2Array([Vector2(-7, 84), Vector2(7, 84), Vector2(22, 126), Vector2(-22, 126)])
				draw_colored_polygon(cone, Color(0.95, 0.35, 0.55))
				cone.append(cone[0])
				draw_polyline(cone, OUT, 2.0)
				draw_rect(Rect2(-22, 124, 44, 5), Color(0.98, 0.9, 0.9))
			_:   # cañón de monedas
				_box(Rect2(-13, 84, 26, 40), GOLD)
				draw_rect(Rect2(-15, 120, 30, 8), Color(0.8, 0.6, 0.15))
				draw_circle(Vector2(0, 124), 7, Color(0.1, 0.08, 0.04))
				for k in 2:
					draw_rect(Rect2(-13, 92 + k * 12, 26, 3), Color(0.8, 0.6, 0.15))


## El sombrero que se cae al pasar a RECESIÓN.
class HatFall extends Node2D:
	var t := 0.0
	var vel := Vector2(120, -260)

	func _ready() -> void:
		z_index = 6

	func _process(delta: float) -> void:
		t += delta
		vel.y += 900.0 * delta
		position += vel * delta
		rotation += delta * 6.0
		if t > 0.6:
			modulate.a = clampf(1.0 - (t - 0.6) / 0.4, 0.0, 1.0)
		if t > 1.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tx := Spr.tex("boss_div0_head_3")
		if tx:
			Spr.draw_centered(self, tx, Vector2.ZERO)
			return
		draw_rect(Rect2(-30, 0, 60, 6), Color(0.08, 0.08, 0.1))
		draw_rect(Rect2(-20, -38, 40, 40), Color(0.08, 0.08, 0.1))
		draw_rect(Rect2(-20, -8, 40, 7), Color(0.98, 0.78, 0.2))


## Panel de la bolsa: reemplaza la barra de vida (gráfico del precio, línea de quiebra, vida).
class StockPanel extends Control:
	var boss: Node
	var _samples: Array[float] = []
	var _chip := 1.0
	var _acc := 0.0

	func _ready() -> void:
		size = Vector2(600, 74)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 150:
			_samples.append(START_PRICE)

	func _process(delta: float) -> void:
		if boss == null or not is_instance_valid(boss):
			return
		_acc += delta
		if _acc >= 0.06:
			_acc = 0.0
			_samples.pop_front()
			_samples.append(float(boss.get("price")))
		var k: float = float(boss.get("hp")) / float(boss.get("MAX_HP"))
		_chip = maxf(k, _chip - 0.004) if _chip > k else k
		queue_redraw()

	func _y(p: float) -> float:
		return 58.0 - p / 100.0 * 42.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.03, 0.04, 0.06, 0.9))
		for i in 13:
			draw_line(Vector2(i * 50.0, 16), Vector2(i * 50.0, 58), Color(0.15, 0.2, 0.3, 0.6), 1.0)
		if boss == null or not is_instance_valid(boss):
			return
		var crash: float = boss.get("crash_line")
		var cy := _y(crash)
		var by := _y(BUBBLE)
		for x in range(0, 600, 12):
			draw_line(Vector2(x, cy), Vector2(x + 6, cy), Color(1, 0.25, 0.2, 0.9), 2.0)
			draw_line(Vector2(x, by), Vector2(x + 6, by), Color(1, 0.8, 0.3, 0.6), 1.0)
		var pts := PackedVector2Array()
		for i in _samples.size():
			pts.append(Vector2(i * 4.0, _y(_samples[i])))
		var last := _samples[_samples.size() - 1]
		var prev := _samples[maxi(0, _samples.size() - 12)]
		var up := last >= prev
		var col := Color(0.4, 1.0, 0.5) if up else Color(1, 0.35, 0.3)
		if boss.get("crashed"):
			col = Color(1, 0.25, 0.2)
		elif boss.get("bubble"):
			col = Color(1, 0.85, 0.3)
		# relleno bajo la línea
		var poly := pts.duplicate()
		poly.append(Vector2(596, 58))
		poly.append(Vector2(0, 58))
		draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.12))
		draw_polyline(pts, col, 2.0)
		draw_circle(pts[pts.size() - 1], 3.0, Color.WHITE)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(6, 13), "#DIV/0!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.4, 0.35))
		var tag := ""
		if boss.get("crashed"):
			tag = "QUIEBRA"
		elif boss.get("bubble"):
			tag = "BURBUJA"
		var txt := "%s %s %.1f   Fase %d/3" % [tag, "▲" if up else "▼", last, boss.get("phase")]
		draw_string(f, Vector2(594 - f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, 13), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		var k: float = float(boss.get("hp")) / float(boss.get("MAX_HP"))
		draw_rect(Rect2(0, 64, 600, 8), Color(0.15, 0.15, 0.15, 0.9))
		draw_rect(Rect2(0, 64, 600 * _chip, 8), Color(1, 0.95, 0.85))
		draw_rect(Rect2(0, 64, 600 * k, 8), Color(0.85, 0.65, 0.15))
		for fr in [0.6, 0.3]:
			draw_rect(Rect2(600 * fr - 1, 64, 2, 8), Color(0, 0, 0, 0.8))
		draw_rect(r, Color(0.35, 0.45, 0.6, 0.8), false, 1.5)


## Cartel sobre la cabeza con el texto del ataque.
class Holo extends Node2D:
	var text := ""
	var col := Color.WHITE
	var t := 9.0
	var dur := 1.1

	func show_text(s: String, c: Color, d: float = 1.1) -> void:
		text = s
		col = c
		dur = d
		t = 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if t > dur or text == "":
			return
		var a := clampf((dur - t) / 0.25, 0.0, 1.0)
		var pop := 1.0 + 0.3 * maxf(0.0, 0.1 - t) / 0.1
		var f := ThemeDB.fallback_font
		var fs := 18
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
		var box := Rect2(-w * 0.5 - 8, -18, w + 16, 26)
		draw_rect(box, Color(0.03, 0.04, 0.06, 0.85 * a))
		draw_rect(box, Color(col.r, col.g, col.b, a), false, 2.0)
		draw_string(f, Vector2(-w * 0.5, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, a))


## F2: periódico de ÚLTIMA HORA en la arena. Si el jugador lo pisa: escándalo. Si caduca: buenas noticias.
class News extends Node2D:
	var boss: Node
	var t := 0.0
	const LIFE := 5.0

	func _ready() -> void:
		z_index = 2
		add_to_group("div0_news")

	func _process(delta: float) -> void:
		t += delta
		if boss == null or not is_instance_valid(boss):
			queue_free()
			return
		var p: Variant = boss.get("player")
		if p != null and is_instance_valid(p) and (p.global_position + Vector2(0, 12)).distance_to(global_position) < 46.0:
			boss.call("news_result", true)
			GameFeel.parry_burst(get_parent(), global_position, 20.0)
			queue_free()
			return
		if t >= LIFE:
			boss.call("news_result", false)
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var bob := sin(t * 5.0) * 3.0
		var k := clampf(1.0 - t / LIFE, 0.0, 1.0)
		draw_circle(Vector2(0, 4), 24, Color(0, 0, 0, 0.25))
		draw_rect(Rect2(-22, -30 + bob, 44, 30), Color(0.95, 0.93, 0.86))
		draw_rect(Rect2(-22, -30 + bob, 44, 30), Color(0.15, 0.15, 0.15), false, 2.0)
		draw_rect(Rect2(-18, -26 + bob, 36, 6), Color(0.2, 0.2, 0.2))
		for i in 3:
			draw_line(Vector2(-18, -16 + i * 5 + bob), Vector2(18, -16 + i * 5 + bob), Color(0.5, 0.5, 0.5), 1.0)
		var f := ThemeDB.fallback_font
		draw_string_outline(f, Vector2(-50, -38 + bob), "ÚLTIMA HORA", HORIZONTAL_ALIGNMENT_CENTER, 100, 11, 3, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(-50, -38 + bob), "ÚLTIMA HORA", HORIZONTAL_ALIGNMENT_CENTER, 100, 11, Color(1, 0.85, 0.4))
		draw_arc(Vector2(0, -15 + bob), 30, -PI * 0.5, -PI * 0.5 + TAU * k, 24, Color(1, 0.85, 0.4, 0.8), 2.0)


## Lingote o moneda del duelo final (con parry vuelve a la bóveda).
class GoldShot extends Final.Shot:
	var bar := true

	func _draw() -> void:
		var c := Color(0.5, 1.0, 0.6) if back else col
		var dir := vel.normalized()
		for i in 3:
			draw_circle(-dir * (10.0 + i * 9.0), 8.0 - i * 2.0, Color(c, 0.18))
		draw_circle(Vector2.ZERO, 24.0, Color(c, 0.12 + 0.1 * absf(sin(t * 16.0))))
		if bar:
			draw_set_transform(Vector2.ZERO, t * 6.0, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(-16, 6), Vector2(16, 6), Vector2(11, -6), Vector2(-11, -6)]), c.darkened(0.15))
			draw_colored_polygon(PackedVector2Array([Vector2(-11, -6), Vector2(11, -6), Vector2(8, -9), Vector2(-8, -9)]), c.lightened(0.35))
			draw_polyline(PackedVector2Array([Vector2(-16, 6), Vector2(16, 6), Vector2(11, -6), Vector2(-11, -6), Vector2(-16, 6)]), Color(0.35, 0.25, 0.05), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var tx := Spr.tex("boss_div0_projectiles_0")
			var spin := maxf(0.25, absf(cos(t * 12.0)))
			if tx:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(spin, 1.0) * (30.0 / tx.get_width()))
				draw_texture(tx, -tx.get_size() * 0.5, Color(0.6, 1, 0.6) if back else Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_circle(Vector2.ZERO, 12, c)


## Campana de cierre del mercado sobre el boss: cuenta atrás del duelo.
class Bell extends Node2D:
	var boss: Node
	var t := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if boss == null or not is_instance_valid(boss):
			return
		var left: float = boss.get("final_left")
		var price: float = boss.get("price")
		var oy := 0.0
		var f := ThemeDB.fallback_font
		var ring := left < 5.0 and fmod(t, 0.4) < 0.2
		draw_set_transform(Vector2(0, oy), sin(t * 20.0) * 0.15 if ring else 0.0, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-14, 8), Vector2(14, 8), Vector2(10, -10), Vector2(0, -16), Vector2(-10, -10)]), Color(1, 0.8, 0.3))
		draw_circle(Vector2(0, 10), 4, Color(0.6, 0.45, 0.1))
		draw_set_transform(Vector2(0, oy), 0.0, Vector2.ONE)
		draw_string_outline(f, Vector2(-80, 34), "CIERRE EN %.1f s" % maxf(0.0, left), HORIZONTAL_ALIGNMENT_CENTER, 160, 15, 4, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(-80, 34), "CIERRE EN %.1f s" % maxf(0.0, left), HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(1, 0.4, 0.3) if left < 5.0 else Color(1, 0.9, 0.6))
		draw_string_outline(f, Vector2(-80, 54), "ACCIÓN: %d" % int(price), HORIZONTAL_ALIGNMENT_CENTER, 160, 15, 4, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(-80, 54), "ACCIÓN: %d" % int(price), HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(0.6, 1, 0.6))
