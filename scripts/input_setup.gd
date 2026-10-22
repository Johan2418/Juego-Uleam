extends RefCounted
## Controles del juego: teclado + mando (estilo Xbox; en PlayStation: A=X, B=O, X=□, Y=△).
## Lo llama GameState al arrancar, así todas las escenas tienen las acciones listas.
## Sin class_name: cargar con preload("res://scripts/input_setup.gd").
##
##   Acción            Teclado            Mando
##   mover             WASD / flechas     stick izquierdo / cruceta
##   action_primary    J / clic izq.      X   (combo; después de un parry = contraataque)
##   action_secondary  K / clic der.      Y   (especial)
##   parry             L                  LB
##   roll              Shift              B
##   ultimate          Espacio            RB
##   interact          E                  A   (entrar a la puerta del boss)
##   retry             R                  Start / A (pantalla final del boss)
##   back              Esc                Select (Back/View)
##   lock_on           Q / clic central   R3 (clic del stick derecho)   fijar objetivo
##   lock_next         Tab                stick derecho a un lado       cambiar de objetivo

const MOVE_DEADZONE := 0.25

## [acción, teclas, botones del mando]
const ACTIONS := [
	["move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT]],
	["move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT]],
	["move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP]],
	["move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN]],
	["action_primary", [KEY_J], [JOY_BUTTON_X]],
	["action_secondary", [KEY_K], [JOY_BUTTON_Y]],
	["parry", [KEY_L], [JOY_BUTTON_LEFT_SHOULDER]],
	["roll", [KEY_SHIFT], [JOY_BUTTON_B]],
	["ultimate", [KEY_SPACE], [JOY_BUTTON_RIGHT_SHOULDER]],
	["interact", [KEY_E], [JOY_BUTTON_A]],
	["retry", [KEY_R], [JOY_BUTTON_START, JOY_BUTTON_A]],
	["back", [KEY_ESCAPE], [JOY_BUTTON_BACK]],
	["lock_on", [KEY_Q], [JOY_BUTTON_RIGHT_STICK]],
	["lock_next", [KEY_TAB], []],
	["debug_fill_ultimate", [KEY_F1], []],
	["debug_next_phase", [KEY_F2], []],
]

## Stick izquierdo: [acción, eje, sentido]
const STICK := [
	["move_left", JOY_AXIS_LEFT_X, -1.0],
	["move_right", JOY_AXIS_LEFT_X, 1.0],
	["move_up", JOY_AXIS_LEFT_Y, -1.0],
	["move_down", JOY_AXIS_LEFT_Y, 1.0],
]

const KEY_LABELS := {
	"action_primary": "J", "action_secondary": "K", "parry": "L", "roll": "Shift",
	"ultimate": "Espacio", "interact": "E", "retry": "R", "back": "Esc", "move": "WASD",
	"lock_on": "Q", "lock_next": "Tab",
}
const PAD_LABELS := {
	"action_primary": "X", "action_secondary": "Y", "parry": "LB", "roll": "B",
	"ultimate": "RB", "interact": "A", "retry": "Start", "back": "Select", "move": "Stick",
	"lock_on": "R3", "lock_next": "Stick der.",
}


static func ensure() -> void:
	for a in ACTIONS:
		var action: String = a[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in a[1]:
			var ev := InputEventKey.new()
			ev.keycode = k as Key
			ev.physical_keycode = k as Key
			if not _has(action, ev):
				InputMap.action_add_event(action, ev)
		for b in a[2]:
			var jb := InputEventJoypadButton.new()
			jb.device = -1
			jb.button_index = b as JoyButton
			if not _has(action, jb):
				InputMap.action_add_event(action, jb)
	# clic central del ratón también fija
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_MIDDLE
	var has_mb := false
	for e in InputMap.action_get_events("lock_on"):
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE:
			has_mb = true
	if not has_mb:
		InputMap.action_add_event("lock_on", mb)
	for s in STICK:
		var jm := InputEventJoypadMotion.new()
		jm.device = -1
		jm.axis = s[1] as JoyAxis
		jm.axis_value = s[2]
		if not _has(s[0], jm):
			InputMap.action_add_event(s[0], jm)
		InputMap.action_set_deadzone(s[0], MOVE_DEADZONE)


## Multijugador local: acciones propias de cada jugador ("p1_move_left", "p2_parry"...).
## device = -1 teclado (+ ratón), >= 0 índice del mando. Las acciones genéricas siguen
## respondiendo a cualquier dispositivo (menús, puertas, salón).
const PLAYER_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "action_primary", "action_secondary",
	"parry", "roll", "ultimate", "interact", "back", "lock_on", "lock_next", "debug_fill_ultimate"]


static func pa(slot: int, action: String) -> String:
	return action if slot <= 0 else "p%d_%s" % [slot, action]


static func build_player(slot: int, device: int) -> void:
	for a in ACTIONS:
		var action: String = a[0]
		if not PLAYER_ACTIONS.has(action):
			continue
		var name := pa(slot, action)
		if InputMap.has_action(name):
			InputMap.erase_action(name)
		InputMap.add_action(name)
		if device < 0:
			for k in a[1]:
				var ev := InputEventKey.new()
				ev.keycode = k as Key
				ev.physical_keycode = k as Key
				InputMap.action_add_event(name, ev)
		else:
			for b in a[2]:
				var jb := InputEventJoypadButton.new()
				jb.device = device
				jb.button_index = b as JoyButton
				InputMap.action_add_event(name, jb)
	if device < 0:
		for pair in [["action_primary", MOUSE_BUTTON_LEFT], ["action_secondary", MOUSE_BUTTON_RIGHT], ["lock_on", MOUSE_BUTTON_MIDDLE]]:
			var mb := InputEventMouseButton.new()
			mb.button_index = pair[1]
			InputMap.action_add_event(pa(slot, pair[0]), mb)
	else:
		for st in STICK:
			var jm := InputEventJoypadMotion.new()
			jm.device = device
			jm.axis = st[1] as JoyAxis
			jm.axis_value = st[2]
			InputMap.action_add_event(pa(slot, st[0]), jm)
	for d in ["move_left", "move_right", "move_up", "move_down"]:
		InputMap.action_set_deadzone(pa(slot, d), MOVE_DEADZONE)


## Dispositivo de un evento: -1 teclado/ratón, >= 0 mando, -9 otro (toque, etc.).
static func event_device(ev: InputEvent) -> int:
	if ev is InputEventKey or ev is InputEventMouseButton:
		return -1
	if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
		return ev.device
	return -9


## Nombre del botón para mostrar en pantalla según lo último que se tocó (teclado o mando).
static func label(action: String, pad: bool) -> String:
	var d: Dictionary = PAD_LABELS if pad else KEY_LABELS
	return str(d.get(action, action))


static func _has(action: String, ev: InputEvent) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and ev is InputEventKey:
			var a := e as InputEventKey
			var b := ev as InputEventKey
			if (a.keycode != 0 and a.keycode == b.keycode) or (a.physical_keycode != 0 and a.physical_keycode == b.physical_keycode):
				return true
		elif e is InputEventJoypadButton and ev is InputEventJoypadButton:
			if (e as InputEventJoypadButton).button_index == (ev as InputEventJoypadButton).button_index:
				return true
		elif e is InputEventJoypadMotion and ev is InputEventJoypadMotion:
			var m := e as InputEventJoypadMotion
			var n := ev as InputEventJoypadMotion
			if m.axis == n.axis and signf(m.axis_value) == signf(n.axis_value):
				return true
	return false
