extends Node
## Fijar objetivo (estilo soulslike). Hijo del jugador.
##   lock_on    Q / clic central  ·  R3 (clic del stick derecho)   fija / suelta
##   lock_next  Tab               ·  stick derecho a un lado        cambia de objetivo
## Mientras está fijado: el jugador mira siempre al objetivo (camina de lado / de espaldas),
## los ataques salen apuntados a él y la cámara se corre hacia el objetivo.
## Si el objetivo muere o desaparece, salta solo al más cercano; si no hay otro, se suelta.
## Sin class_name: cargar con preload("res://scripts/combat/lock_on.gd").

const BossFx := preload("res://scripts/combat/boss_fx.gd")

const RANGE := 620.0          ## distancia máxima para fijar
const BREAK_RANGE := 820.0    ## se suelta si se aleja más que esto
const CAM_PULL := 0.38        ## cuánto se corre la cámara hacia el objetivo
const CAM_MAX := 170.0

signal changed(target: Node2D)

var player: Node2D
var target: Node2D = null
var _reticle: Reticle
var _stick_ready := true


func setup(p: Node2D) -> void:
	player = p


func active() -> bool:
	return target != null and is_instance_valid(target)


## Punto al que apuntar (centro de la zona golpeable del objetivo).
func point() -> Vector2:
	if not active():
		return player.global_position
	return aim_point(target)


## Dirección del jugador al objetivo.
func dir() -> Vector2:
	var d := point() - (player.global_position + Vector2(0, -14))
	return d.normalized() if d.length() > 1.0 else Vector2.DOWN


static func aim_point(n: Node2D) -> Vector2:
	if n.has_method("lock_point"):
		return n.call("lock_point")
	for c in n.get_children():
		if c is Area2D and ((c as Area2D).collision_layer & 2) != 0:
			for s in c.get_children():
				if s is CollisionShape2D:
					return (s as CollisionShape2D).global_position
	return n.global_position + Vector2(0, -28)


func _process(_delta: float) -> void:
	if player == null:
		return
	if not player.is_processing_unhandled_input() and active():
		release()
	if active() and not _valid(target, BREAK_RANGE):
		# el objetivo murió o se fue: pasa al más cercano (como en los souls) o se suelta
		var nxt := _best(null)
		if nxt:
			_set_target(nxt)
		else:
			release()
	elif target != null and not is_instance_valid(target):
		release()
	# stick derecho: cambiar de objetivo a ese lado
	var dev: int = int(player.call("pad_device")) if player.has_method("pad_device") else 0
	var rx := Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X) if dev >= 0 else 0.0
	if absf(rx) < 0.3:
		_stick_ready = true
	elif absf(rx) > 0.7 and _stick_ready and active():
		_stick_ready = false
		switch_side(signf(rx))
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.is_processing_unhandled_input():
		return
	var a_on := "lock_on"
	var a_next := "lock_next"
	if player.has_method("act"):
		a_on = player.call("act", a_on)
		a_next = player.call("act", a_next)
	if event.is_action_pressed(a_on):
		toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(a_next):
		if active():
			cycle()
		else:
			toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if active():
		release()
		return
	var t := _best(null)
	if t:
		_set_target(t)
	else:
		_no_target_feedback()


func release() -> void:
	target = null
	if _reticle and is_instance_valid(_reticle):
		_reticle.leave()
	_reticle = null
	changed.emit(null)


## Siguiente objetivo en el sentido de las agujas del reloj alrededor del jugador.
func cycle() -> void:
	var list := _candidates(RANGE)
	if list.size() < 2:
		return
	var here := player.global_position
	var a0 := (point() - here).angle()
	var best: Node2D = null
	var best_d := INF
	for n in list:
		if n == target:
			continue
		var d := fposmod((aim_point(n) - here).angle() - a0, TAU)
		if d < best_d:
			best_d = d
			best = n
	if best:
		_set_target(best)


## Objetivo más cercano hacia la izquierda (-1) o derecha (+1) de la pantalla.
func switch_side(side: float) -> void:
	var cur := point()
	var best: Node2D = null
	var best_d := INF
	for n in _candidates(RANGE):
		if n == target:
			continue
		var dx := aim_point(n).x - cur.x
		if signf(dx) != side:
			continue
		var d := aim_point(n).distance_to(cur)
		if d < best_d:
			best_d = d
			best = n
	if best:
		_set_target(best)


func _set_target(t: Node2D) -> void:
	target = t
	if _reticle == null or not is_instance_valid(_reticle):
		_reticle = Reticle.new()
		_reticle.lock = self
		player.get_parent().add_child(_reticle)
	_reticle.snap()
	changed.emit(t)


func _no_target_feedback() -> void:
	# nada a la vista: la cámara vuelve al centro (como en los souls)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.position = Vector2.ZERO


## Mejor objetivo para fijar: el jefe si está a la vista; si no, el más cercano hacia donde mira el jugador.
func _best(exclude: Node2D) -> Node2D:
	var here := player.global_position
	var fwd: Vector2 = player.get("facing_vec") if player.get("facing_vec") != null else Vector2.DOWN
	var best: Node2D = null
	var best_s := INF
	for n in _candidates(RANGE):
		if n == exclude:
			continue
		var to := aim_point(n) - here
		var s := to.length() * (1.25 - 0.35 * to.normalized().dot(fwd))
		if n.has_signal("phase_changed"):
			s -= 100000.0   # el jefe siempre primero si está a la vista (el resto, con Tab / stick)
		if s < best_s:
			best_s = s
			best = n
	return best


func _candidates(rng: float) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Node2D and _valid(n, rng):
			out.append(n)
	return out


func _valid(n: Node, rng: float) -> bool:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return false
	if not n.is_in_group("enemies"):
		return false
	if n is BossFx.Hazard:
		return false   # proyectiles y peligros: no se fijan
	if n.get("lockable") == false:
		return false
	var n2 := n as Node2D
	if not n2.is_visible_in_tree() or n2.modulate.a < 0.1:
		return false
	return aim_point(n2).distance_to(player.global_position) <= rng


func _update_camera() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var want := Vector2.ZERO
	if cam.has_meta("epic_focus"):
		# cinemática (clímax de los duelos finales): la cámara se corre hacia el boss
		var fp: Vector2 = cam.get_meta("epic_focus")
		want = ((fp - player.global_position) * 0.55).limit_length(320.0)
	elif active():
		want = ((point() - player.global_position) * CAM_PULL).limit_length(CAM_MAX)
	cam.position = cam.position.lerp(want, 0.08)


## Mira sobre el objetivo: cuatro esquinas que giran y se cierran al fijar.
class Reticle extends Node2D:
	var lock: Node
	var t := 0.0
	var _snap := 0.0
	var _leaving := false

	func _ready() -> void:
		z_index = 60
		z_as_relative = false

	func snap() -> void:
		_snap = 1.0
		_leaving = false
		modulate.a = 1.0

	func leave() -> void:
		_leaving = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.15)
		tw.tween_callback(queue_free)

	func _process(delta: float) -> void:
		t += delta
		_snap = maxf(0.0, _snap - delta * 4.0)
		if not _leaving and lock and is_instance_valid(lock) and lock.call("active"):
			global_position = lock.call("point")
		queue_redraw()

	func _draw() -> void:
		var r := 30.0 + 30.0 * _snap * _snap + 2.5 * sin(t * 6.0)
		var col := Color(1.0, 0.92, 0.55)
		var out := Color(0.05, 0.03, 0.02, 0.85)
		draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
		draw_set_transform(Vector2.ZERO, t * 1.2, Vector2.ONE)
		for i in 4:
			var a := i * TAU / 4.0
			var c := Vector2.from_angle(a) * r
			var s1 := Vector2.from_angle(a + PI * 0.75) * 13.0
			var s2 := Vector2.from_angle(a - PI * 0.75) * 13.0
			for pass_i in 2:
				var w := 6.5 if pass_i == 0 else 3.5
				var k := out if pass_i == 0 else col
				draw_line(c, c + s1, k, w)
				draw_line(c, c + s2, k, w)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# punto central en rombo
		var d := 5.5
		var pts := PackedVector2Array([Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0)])
		draw_colored_polygon(pts, out)
		var pts2 := PackedVector2Array([Vector2(0, -d + 1.5), Vector2(d - 1.5, 0), Vector2(0, d - 1.5), Vector2(-d + 1.5, 0)])
		draw_colored_polygon(pts2, Color(1.0, 0.35, 0.25))
