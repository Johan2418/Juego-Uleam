extends RefCounted
## Técnicas que se consiguen al vencer a cada boss (una por boss, en una ranura fija).
## Sirven para las 3 clases; cada clase las ejecuta con sus propias animaciones.
## Se equipan desde el menú del personaje (scenes/character_creator.tscn) y se guardan en GameState.
## La lógica en combate está en class_controller.gd (_tech_*); los efectos visuales, aquí abajo.
## Sin class_name: cargar con preload("res://scripts/combat/techniques.gd").
##
## Animaciones: si el personaje tiene una hoja "<clase>_tech_<id>" (generada con Grok), se usa esa;
## si no, se reutiliza la animación de la clase indicada en FALLBACK_ANIM.

const GameFeel := preload("res://scripts/combat/game_feel.gd")

const SLOTS := ["combo", "special", "ultimate"]
const SLOT_LABEL := {"combo": "COMBO", "special": "ESPECIAL", "ultimate": "ULTIMATE"}
const SLOT_ACTION := {"combo": "action_primary", "special": "action_secondary", "ultimate": "ultimate"}

## id -> datos. "boss" = quién la da al ser vencido.
const DATA := {
	"parasito": {
		"slot": "combo", "boss": "deadbeef", "name": "Parásito", "color": Color(0.45, 1.0, 0.45),
		"what": "El remate del combo roba vida: si conecta, recuperas 1 corazón (una vez por combo).",
		"tip": "Para aguantar peleas largas sin depender de esquivarlo todo.",
	},
	"interes": {
		"slot": "combo", "boss": "div0", "name": "Interés compuesto", "color": Color(1.0, 0.82, 0.25),
		"what": "Cada golpe del combo que conecta suma 1 moneda de interés (máx. 4). Con 2 monedas tus golpes hacen +1 de daño y con 4, +2. Si te golpean o pasas 2 s sin pegar, lo pierdes todo.",
		"tip": "Premia atacar seguido sin recibir daño: ideal si ya dominas el parry.",
	},
	"autocompletar": {
		"slot": "combo", "boss": "sudo", "name": "Autocompletar", "color": Color(0.45, 1.0, 0.7),
		"what": "Cuando el remate del combo conecta, un golpe fantasma (texto gris de autocompletado) lo repite 0,4 s después con el mismo daño.",
		"tip": "Más daño por combo sin quedarte más tiempo pegado al enemigo.",
	},
	"objecion": {
		"slot": "special", "boss": "judge", "name": "Objeción", "color": Color(1.0, 0.4, 0.35), "cooldown": 3.5,
		"what": "Postura de bloqueo de 1 s que cubre todo tu frente. Si bloquea un golpe, responde con una onda que hace 3 de daño delante de ti.",
		"tip": "Contra bosses que atacan mucho de frente o con ráfagas de proyectiles.",
	},
	"tiza": {
		"slot": "special", "boss": "syntax", "name": "Tiza roja", "color": Color(1.0, 0.3, 0.3), "cooldown": 4.0,
		"what": "Lanzas una tiza que marca al primer enemigo que toca: durante 5 s recibe el doble de daño de todos tus ataques.",
		"tip": "Úsala justo antes de un combo largo o de tu ultimate.",
	},
	"glitch": {
		"slot": "special", "boss": "tex", "name": "Glitch", "color": Color(1.0, 0.25, 1.0), "cooldown": 3.0,
		"what": "Te teletransportas hacia donde miras (o detrás del objetivo fijado) y dejas una copia que explota: 2 de daño alrededor. Eres invulnerable durante el salto.",
		"tip": "Para salir de una esquina o pasar al otro lado del boss.",
	},
	"desfibrilador": {
		"slot": "ultimate", "boss": "bsod", "name": "Desfibrilador", "color": Color(0.5, 0.8, 1.0),
		"what": "Cargas las paletas y das una descarga a tu alrededor (3 de daño) que además te cura 2 corazones.",
		"tip": "Tu salvavidas: guárdala para cuando te quede poca vida.",
	},
	"pushpop": {
		"slot": "ultimate", "boss": "stack", "name": "Push / Pop", "color": Color(1.0, 0.65, 0.2),
		"what": "Caen 3 bloques (PUSH) sobre los enemigos más cercanos, 2 de daño cada uno, y al final un bloque gigante (POP) que hace 4.",
		"tip": "Mucho daño a un solo blanco; mejor con el objetivo fijado.",
	},
	"comercial": {
		"slot": "ultimate", "boss": "kp", "name": "Corte comercial", "color": Color(1.0, 0.7, 0.25),
		"what": "Pantalla de ajuste: durante 3 s nada te hace daño. Al volver de la pausa, todos los enemigos en pantalla reciben 3 de daño.",
		"tip": "Para sobrevivir a las lluvias de ataques de los cambios de fase.",
	},
}

## Lo que trae cada clase de serie (ranura sin técnica equipada).
const BASE := {
	"guerrero": {
		"combo": ["Borrador", "Dos golpes rápidos y un remate con salto que hace 2 de daño."],
		"special": ["Embestida", "Avanzas con el borrador por delante y empujas: 2 de daño."],
		"ultimate": ["Haz de pizarra", "Cargas y disparas un haz enorme hacia el frente que golpea varias veces."],
	},
	"mago": {
		"combo": ["Orbes", "Dos orbes a distancia y un remate en área a tu alrededor."],
		"special": ["Abanico", "Lanzas 3 orbes en abanico."],
		"ultimate": ["Tormenta", "Caen 10 rayos; la mitad buscan a los enemigos cercanos."],
	},
	"chain": {
		"combo": ["Látigo", "Dos latigazos y un remate largo."],
		"special": ["Enganche", "Latigazo muy largo que atrae al enemigo hacia ti."],
		"ultimate": ["Tormenta de cables", "Giras con los cables extendidos y puedes moverte mientras golpean."],
	},
}

## Animación de la clase que se usa mientras no exista la hoja propia de la técnica.
const FALLBACK_ANIM := {
	"objecion": {"guerrero": "guerrero_parry", "mago": "mago_parry", "chain": "chain_parry"},
	"tiza": {"guerrero": "guerrero_attack_1", "mago": "mago_cast_1", "chain": "chain_whip_1"},
	"glitch": {"guerrero": "guerrero_parry", "mago": "mago_parry", "chain": "chain_parry"},
	"desfibrilador": {"guerrero": "guerrero_finisher", "mago": "mago_finisher", "chain": "chain_finisher"},
	"pushpop": {"guerrero": "guerrero_finisher", "mago": "mago_special", "chain": "chain_special"},
	"comercial": {"guerrero": "guerrero_counter", "mago": "mago_counter", "chain": "chain_counter"},
}


static func ids_for_slot(slot: String) -> Array:
	var out: Array = []
	for id in DATA.keys():
		if DATA[id]["slot"] == slot:
			out.append(id)
	return out


static func info(id: String) -> Dictionary:
	return DATA.get(id, {})


## Animación (sin dirección) para la acción "tech_<id>[_ultimate]" en la dirección dada.
## Orden: hoja propia de la clase "<clase>_tech_<id>", hoja común a las 3 clases "tech_<id>"
## (las ultimates de Grok se dibujan con el arma a la espalda y sirven para todas), y si no, la de la clase.
static func anim_base(kind: String, class_id: String, frames: SpriteFrames, dir: String = "down") -> String:
	var id := kind.trim_prefix("tech_").trim_suffix("_ultimate")
	for own in ["%s_tech_%s" % [class_id, id], "tech_%s" % id]:
		if frames and frames.has_animation("%s_%s" % [own, dir]):
			return own
	return fallback_anim(id, class_id)


static func fallback_anim(id: String, class_id: String) -> String:
	var fb: Dictionary = FALLBACK_ANIM.get(id, {})
	return str(fb.get(class_id, "%s_special" % class_id))


# ==================================================================================
## Número/etiqueta flotante (curas, "×2", etc.).
class FloatText extends Node2D:
	var text := ""
	var col := Color.WHITE
	var size := 18
	var t := 0.0

	func _ready() -> void:
		z_index = 40

	func _process(delta: float) -> void:
		t += delta
		position.y -= 30.0 * delta
		if t > 1.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - (t - 0.6) / 0.4, 0.0, 1.0)
		var f := ThemeDB.fallback_font
		draw_string_outline(f, Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, size, 4, Color(0, 0, 0, a))
		draw_string(f, Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, size, Color(col, a))


static func float_text(parent: Node, at: Vector2, text: String, col: Color, size: int = 18) -> void:
	if parent == null:
		return
	var ft := FloatText.new()
	ft.text = text
	ft.col = col
	ft.size = size
	parent.add_child(ft)
	ft.global_position = at


## Hilo verde que va del enemigo al jugador (Parásito).
class Drain extends Node2D:
	var from: Vector2
	var target: Node2D
	var t := 0.0

	func _ready() -> void:
		z_index = 30
		top_level = true

	func _process(delta: float) -> void:
		t += delta
		if t > 0.5 or not is_instance_valid(target):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var to := target.global_position + Vector2(0, -40)
		var k := t / 0.5
		for i in 6:
			var s := clampf(k * 1.4 - i * 0.08, 0.0, 1.0)
			var p := from.lerp(to, s) + Vector2(0, -sin(s * PI) * 30.0) + Vector2(sin(t * 20.0 + i) * 4.0, 0)
			draw_circle(p, 5.0 - i * 0.5, Color(0.4, 1.0, 0.45, 0.9 - i * 0.12))


## Autocompletar: golpe fantasma gris que repite el remate sobre el enemigo 0,4 s después.
class Echo extends Node2D:
	var target: Node2D
	var at := Vector2.ZERO
	var damage := 2
	var from := Vector2.ZERO
	var t := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = 30
		top_level = true
		global_position = at

	func _process(delta: float) -> void:
		t += delta
		if t >= 0.4 and not _hit:
			_hit = true
			if is_instance_valid(target) and target.is_in_group("enemies") and target.has_method("take_hit"):
				target.call("take_hit", damage, from)
				GameFeel.parry_burst(get_parent(), global_position, 16.0)
		if t > 0.75:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var a := clampf(1.0 - maxf(0.0, t - 0.4) / 0.35, 0.0, 1.0)
		if t < 0.4:
			# texto fantasma que "predice" el golpe
			var k := t / 0.4
			draw_string(f, Vector2(-34, -30), "Tab", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.88, 0.5 + 0.4 * k))
			draw_arc(Vector2.ZERO, 30.0, -2.4, -2.4 + 3.2 * k, 16, Color(0.8, 0.8, 0.9, 0.55), 5.0)
		else:
			draw_arc(Vector2.ZERO, 34.0, -2.4, 0.8, 16, Color(0.6, 1.0, 0.8, a), 6.0)
			draw_arc(Vector2.ZERO, 34.0, -2.4, 0.8, 16, Color(1, 1, 1, a), 2.0)


## Contador de monedas de interés sobre la cabeza del jugador.
class InterestBadge extends Node2D:
	var stacks := 0
	var t := 0.0
	var pop := 0.0

	func _ready() -> void:
		z_index = 35

	func set_stacks(n: int) -> void:
		if n > stacks:
			pop = 1.0
		stacks = n

	func _process(delta: float) -> void:
		t += delta
		pop = maxf(0.0, pop - delta * 4.0)
		visible = stacks > 0
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var w := stacks * 14.0
		for i in stacks:
			var p := Vector2(-w * 0.5 + 7 + i * 14.0, -sin(t * 4.0 + i) * 2.0 - (6.0 * pop if i == stacks - 1 else 0.0))
			draw_circle(p, 6.5, Color(0.35, 0.22, 0.02))
			draw_circle(p, 5.0, Color(1.0, 0.82, 0.2))
			draw_circle(p + Vector2(-1.5, -1.5), 1.5, Color(1, 1, 0.8))
		var bonus := 2 if stacks >= 4 else (1 if stacks >= 2 else 0)
		if bonus > 0:
			draw_string_outline(f, Vector2(-30, -12), "+%d" % bonus, HORIZONTAL_ALIGNMENT_CENTER, 60, 13, 3, Color.BLACK)
			draw_string(f, Vector2(-30, -12), "+%d" % bonus, HORIZONTAL_ALIGNMENT_CENTER, 60, 13, Color(1, 0.9, 0.4))


## Onda en cono hacia el frente (Objeción).
class ConeWave extends Node2D:
	var dir := Vector2.RIGHT
	var radius := 150.0
	var half := 0.9
	var t := 0.0

	func _ready() -> void:
		z_index = 25

	func _process(delta: float) -> void:
		t += delta
		if t > 0.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := t / 0.4
		var r := lerpf(30.0, radius, 1.0 - pow(1.0 - k, 3.0))
		var a := 1.0 - k
		var ang := dir.angle()
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 17:
			pts.append(Vector2.from_angle(ang - half + 2.0 * half * i / 16.0) * r)
		draw_colored_polygon(pts, Color(1.0, 0.35, 0.3, 0.25 * a))
		draw_polyline(pts.slice(1), Color(1.0, 0.9, 0.8, a), 5.0)
		var f := ThemeDB.fallback_font
		var tp := dir * (r * 0.55) + Vector2(-80, -18)
		draw_string_outline(f, tp, "¡OBJECIÓN!", HORIZONTAL_ALIGNMENT_CENTER, 160, 22, 5, Color(0, 0, 0, a))
		draw_string(f, tp, "¡OBJECIÓN!", HORIZONTAL_ALIGNMENT_CENTER, 160, 22, Color(1, 0.4, 0.35, a))


## Tiza que vuela y marca al primer enemigo que toca (Tiza roja).
class ChalkShot extends Node2D:
	var ctrl: Node
	var dir := Vector2.RIGHT
	var speed := 640.0
	var max_dist := 560.0
	var _dist := 0.0
	var _trail: Array = []

	func _ready() -> void:
		z_index = 22

	func _process(delta: float) -> void:
		var step := dir * speed * delta
		global_position += step
		_dist += step.length()
		_trail.push_front(global_position)
		if _trail.size() > 10:
			_trail.pop_back()
		if ctrl and is_instance_valid(ctrl):
			for e in ctrl.call("_enemies"):
				var p: Vector2 = ctrl.call("aim_of", e)
				if p.distance_to(global_position) < 34.0:
					ctrl.call("mark_enemy", e)
					GameFeel.dust(get_parent(), global_position, 6, Vector2.ZERO, 3.0, Vector2(10, 6))
					queue_free()
					return
		if _dist > max_dist:
			GameFeel.dust(get_parent(), global_position, 3, Vector2.ZERO, 3.0, Vector2(6, 4))
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for i in _trail.size():
			var p: Vector2 = (_trail[i] as Vector2) - global_position
			if i % 2 == 0:
				draw_circle(p, 3.0 - i * 0.2, Color(1, 0.35, 0.3, 0.6 - i * 0.05))
		draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
		draw_rect(Rect2(-9, -3, 18, 6), Color(0.1, 0.02, 0.02))
		draw_rect(Rect2(-8, -2, 16, 4), Color(1, 0.3, 0.28))
		draw_rect(Rect2(4, -2, 4, 4), Color(1, 0.75, 0.7))


## Marca roja sobre un enemigo marcado con la tiza (×2), con su tiempo restante.
class Mark extends Node2D:
	var target: Node2D
	var ctrl: Node
	var life := 5.0
	var t := 0.0

	func _ready() -> void:
		z_index = 45
		top_level = true

	func _process(delta: float) -> void:
		t += delta
		if t > life or not is_instance_valid(target) or not target.is_inside_tree():
			queue_free()
			return
		if ctrl and is_instance_valid(ctrl):
			global_position = ctrl.call("aim_of", target)
		queue_redraw()

	func _draw() -> void:
		var k := 1.0 - t / life
		var f := ThemeDB.fallback_font
		var r := 26.0 + 3.0 * sin(t * 8.0)
		# círculo de tiza (como corrección de examen) + ×2
		var pts := PackedVector2Array()
		for i in 25:
			var a := -PI * 0.5 + TAU * 1.08 * i / 24.0
			pts.append(Vector2(cos(a) * r * 1.25, sin(a) * r) + Vector2(sin(i * 1.7) * 1.5, 0))
		draw_polyline(pts, Color(0, 0, 0, 0.5), 6.0)
		draw_polyline(pts, Color(1, 0.3, 0.28, 0.95), 3.0)
		draw_arc(Vector2(0, -r - 16), 9.0, -PI * 0.5, -PI * 0.5 + TAU * k, 20, Color(1, 0.3, 0.28), 3.0)
		draw_string_outline(f, Vector2(-30, -r - 30), "×2", HORIZONTAL_ALIGNMENT_CENTER, 60, 16, 4, Color.BLACK)
		draw_string(f, Vector2(-30, -r - 30), "×2", HORIZONTAL_ALIGNMENT_CENTER, 60, 16, Color(1, 0.4, 0.35))


## Copia del jugador que explota (Glitch).
class Decoy extends Node2D:
	var tex: Texture2D
	var flip := false
	var offset := Vector2.ZERO
	var scale_k := Vector2.ONE
	var ctrl: Node
	var fuse := 0.55
	var t := 0.0
	var _boom := false

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		t += delta
		if not _boom and t >= fuse:
			_boom = true
			if ctrl and is_instance_valid(ctrl):
				ctrl.call("glitch_boom", global_position + Vector2(0, -30))
		if t > fuse + 0.45:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if not _boom:
			if tex:
				var a := 0.55 + 0.35 * sin(t * 40.0)
				var sz := tex.get_size() * scale_k
				draw_set_transform(offset, 0.0, Vector2(-1 if flip else 1, 1))
				draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, Color(1, 0.3, 1, a))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# cuadros de textura rota encima
			for i in 10:
				var p := Vector2(randf_range(-18, 18), randf_range(-70, 0))
				draw_rect(Rect2(p, Vector2(6, 6)), Color(1, 0, 1) if i % 2 == 0 else Color(0.05, 0, 0.08))
		else:
			var k := (t - fuse) / 0.45
			var r := lerpf(20.0, 90.0, k)
			var a2 := 1.0 - k
			for i in 40:
				var ang := TAU * i / 40.0
				var p2 := Vector2(cos(ang), sin(ang) * 0.6) * r * (0.6 + 0.4 * fmod(i * 0.37, 1.0)) + Vector2(0, -30)
				draw_rect(Rect2(p2, Vector2(7, 7)), Color(1, 0, 1, a2) if i % 2 == 0 else Color(0.05, 0, 0.08, a2))


## Arcos eléctricos alrededor del jugador mientras carga el desfibrilador.
class ShockRing extends Node2D:
	var target: Node2D
	var radius := 170.0
	var charge := 0.6
	var t := 0.0

	func _ready() -> void:
		z_index = 26
		top_level = true

	func _process(delta: float) -> void:
		t += delta
		if not is_instance_valid(target) or t > charge + 0.45:
			queue_free()
			return
		global_position = target.global_position + Vector2(0, -20)
		queue_redraw()

	func _draw() -> void:
		if t < charge:
			var k := t / charge
			# chispas que se juntan hacia el pecho
			for i in 3:
				var a := randf() * TAU
				var p1 := Vector2.from_angle(a) * 60.0 * (1.0 - k)
				var pts := PackedVector2Array([p1])
				for s in 4:
					pts.append(p1.lerp(Vector2.ZERO, (s + 1) / 4.0) + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
				draw_polyline(pts, Color(0.6, 0.9, 1.0, 0.9), 2.5)
			draw_circle(Vector2.ZERO, 6.0 + 8.0 * k, Color(0.8, 0.95, 1.0, 0.8))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(0.5, 0.8, 1.0, 0.25 * k), 2.0)
		else:
			var k2 := (t - charge) / 0.45
			var r := lerpf(20.0, radius, 1.0 - pow(1.0 - k2, 2.0))
			var a2 := 1.0 - k2
			var pts2 := PackedVector2Array()
			for i in 49:
				var ang := TAU * i / 48.0
				pts2.append(Vector2(cos(ang), sin(ang) * 0.6) * (r + randf_range(-6, 6)))
			draw_polyline(pts2, Color(0.55, 0.85, 1.0, a2), 6.0)
			draw_polyline(pts2, Color(1, 1, 1, a2), 2.0)


## Bloque que cae del cielo sobre un punto (Push / Pop).
class FallBlock extends Node2D:
	var ctrl: Node
	var text := "PUSH"
	var big := false
	var col := Color(0.95, 0.75, 0.2)
	var warn := 0.4
	var damage := 2
	var radius := 64.0
	var t := 0.0
	var _hit := false

	func _ready() -> void:
		z_index = 28

	func _process(delta: float) -> void:
		t += delta
		if not _hit and t >= warn:
			_hit = true
			if ctrl and is_instance_valid(ctrl):
				ctrl.call("area_damage", global_position, radius, damage)
				ctrl.call("_shake", 7.0 if big else 4.0, 0.25)
			GameFeel.dust(get_parent(), global_position, 12 if big else 7, Vector2.ZERO, 6.0, Vector2(radius, 12))
		if t > warn + 0.7:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var s := 1.7 if big else 1.0
		var w := 70.0 * s
		var h := 42.0 * s
		# sombra / aviso en el suelo
		var k := clampf(t / warn, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, radius * (0.5 + 0.5 * k), Color(0, 0, 0, 0.35 + 0.25 * k))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(col, 0.6), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var y := lerpf(-560.0, -h, k * k) if t < warn else -h
		var a := 1.0 if t < warn + 0.4 else clampf(1.0 - (t - warn - 0.4) / 0.3, 0.0, 1.0)
		var r := Rect2(-w * 0.5, y, w, h)
		draw_rect(r.grow(3), Color(0.05, 0.05, 0.06, a))
		draw_rect(r, Color(col, a))
		draw_rect(Rect2(r.position, Vector2(w, 8 * s)), Color(1, 1, 1, 0.35 * a))
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(-w * 0.5, y + h * 0.5 + 7 * s), text, HORIZONTAL_ALIGNMENT_CENTER, w, int(18 * s), Color(0.05, 0.05, 0.06, a))


## Pantalla de ajuste (barras de color) + franja "PAUSA COMERCIAL" (Corte comercial).
class CommercialScreen extends CanvasLayer:
	var life := 3.0
	var t := 0.0
	var _c: Control

	func _ready() -> void:
		layer = 7
		_c = Control.new()
		_c.size = Vector2(1280, 720)
		_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c.draw.connect(_paint)
		add_child(_c)

	func _process(delta: float) -> void:
		t += delta
		if t > life + 0.3:
			queue_free()
		_c.queue_redraw()

	func _paint() -> void:
		var bars := [Color(0.75, 0.75, 0.75), Color(0.75, 0.75, 0), Color(0, 0.75, 0.75), Color(0, 0.75, 0), Color(0.75, 0, 0.75), Color(0.75, 0, 0), Color(0, 0, 0.75)]
		var f := ThemeDB.fallback_font
		if t < 0.3:
			# destello de barras a pantalla completa
			var a := 1.0 - t / 0.3
			for i in bars.size():
				_c.draw_rect(Rect2(i * 1280.0 / bars.size(), 0, 1280.0 / bars.size() + 1, 720), Color(bars[i], 0.85 * a))
			return
		var fade := clampf((life + 0.3 - t) / 0.3, 0.0, 1.0)
		# barras finitas arriba y abajo + franja central
		for i in bars.size():
			_c.draw_rect(Rect2(i * 1280.0 / bars.size(), 0, 1280.0 / bars.size() + 1, 18), Color(bars[i], 0.9 * fade))
			_c.draw_rect(Rect2(i * 1280.0 / bars.size(), 702, 1280.0 / bars.size() + 1, 18), Color(bars[i], 0.9 * fade))
		_c.draw_rect(Rect2(0, 36, 1280, 46), Color(0.05, 0.05, 0.08, 0.8 * fade))
		var left := maxf(0.0, life - t)
		var txt := "PAUSA COMERCIAL · VOLVEMOS EN %d" % int(ceil(left)) if t < life else "¡VOLVEMOS AL AIRE!"
		_c.draw_string(f, Vector2(0, 68), txt, HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color(1, 0.8, 0.3, fade))
