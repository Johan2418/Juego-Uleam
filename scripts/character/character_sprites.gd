class_name CharacterSprites
extends RefCounted
## Animaciones dedicadas por personaje (Wadrid / MarlonX-a).
## Frames: res://assets/sprites/characters_anim/<id>/<anim>_<dir>_<i>.png
## generados por tools/slice_character_sheets.py desde referencias_animacion/_entregas_runway/.
## Direcciones: down / up / right / down_right / up_right (izquierda = espejo con flip_h).
## Lienzo 160x160 con los pies en y=152 -> con centered=true, desplazar el sprite FOOT_OFFSET
## respecto al punto de los pies.

const ROOT := "res://assets/sprites/characters_anim/"
const PLAYABLE: Array[String] = ["wadrid", "marlonx_a"]
const DIRS: Array[String] = ["down", "up", "right"]
## La caminata también tiene diagonales (izquierda = espejo).
const WALK_DIRS: Array[String] = ["down", "up", "right", "down_right", "up_right"]
## Lienzo de los frames: 160×160 con los pies en y=152 -> offset = -(152 - 80)
const FOOT_OFFSET := Vector2(0, -72)
const CHARACTER_HEIGHT := 88.0
## Intercalar walk_b en la caminata (desactivado: ver build_frames).
const USE_WALK_MID := false
## Combos cuyas poses intermedias (<ataque>_b) no encajan con la hoja base (cambian de alto o de
## tamaño de cabeza entre frames): en esas se usa el ataque original de 4 poses.
const MID_SKIP: Array[String] = [
	"wadrid_guerrero_attack_down", "wadrid_guerrero_attack_down_right", "wadrid_mago_cast_up_right",
	"wadrid_chain_whip_up", "marlonx_a_guerrero_attack_up", "marlonx_a_guerrero_attack_right",
	"marlonx_a_mago_cast_up", "marlonx_a_chain_whip_up_right",
	"wadrid_guerrero_attack_up", "wadrid_guerrero_attack_up_right",
]
## Solo estos combos intercalan sus poses intermedias (_b). En mago y chain las hojas _b salieron con otro
## alto/tamaño de cabeza que la hoja base: al intercalarlas el personaje "saltaba" y cambiaba de tamaño.
const MID_ALLOW: Array[String] = ["guerrero_attack"]

## anim base -> [fps, loop]
const ANIMS := {
	"walk": [8.0, true],
	"roll": [11.0, false],
	"guerrero_attack": [10.0, false],
	"mago_cast": [10.0, false],
	"chain_whip": [12.0, false],
	# especial (K), parry (L), ultimate (Espacio): la velocidad real la ajusta el jugador
	"guerrero_special": [10.0, false],
	"guerrero_parry": [10.0, false],
	"guerrero_ultimate": [10.0, false],
	"mago_special": [10.0, false],
	"mago_parry": [10.0, false],
	"mago_ultimate": [10.0, false],
	"chain_special": [10.0, false],
	"chain_parry": [10.0, false],
	"chain_ultimate": [10.0, false],
	"hurt": [8.0, false],
}
## Ataque leve en combo: golpes 1 y 2 = mitades del ataque base; golpe 3 = remate
## (<clase>_finisher_<dir>, hoja propia; si falta esa dirección se usa el ataque completo).
const COMBO_BASES := {
	"guerrero": "guerrero_attack",
	"mago": "mago_cast",
	"chain": "chain_whip",
}

static var _cache: Dictionary = {}


static func is_playable(id: String) -> bool:
	return PLAYABLE.has(id)


## front/back/left/right (convención del jugador) -> down/up/right
static func dir_for_facing(facing: String) -> String:
	match facing:
		"back", "up":
			return "up"
		"left", "right":
			return "right"
		_:
			return "down"


static func is_flipped(facing: String) -> bool:
	return facing == "left"


## Dirección de caminata en 8 direcciones a partir del vector de movimiento.
## Devuelve [dir, flip]; dir ∈ WALK_DIRS.
static func walk_dir_for(v: Vector2, facing: String) -> Array:
	var ax := absf(v.x)
	var ay := absf(v.y)
	if ax > 0.2 and ay > 0.2 and absf(ax - ay) < 0.5 * maxf(ax, ay):
		return ["down_right" if v.y > 0.0 else "up_right", v.x < 0.0]
	return [dir_for_facing(facing), is_flipped(facing)]


static func build_frames(id: String) -> SpriteFrames:
	if not is_playable(id):
		id = PLAYABLE[0]
	if _cache.has(id):
		return _cache[id]
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	# Todas las animaciones se construyen en las 5 direcciones si existe la hoja (izquierda = espejo).
	# Si falta una diagonal, el jugador usa la dirección de 4 más cercana (Player._action_dir).
	for base in ANIMS.keys():
		var fps: float = ANIMS[base][0]
		var loop: bool = ANIMS[base][1]
		for d in WALK_DIRS:
			var tex := _sequence(id, base, d)
			if tex.is_empty() and base == "roll" and d in DIRS:
				# Falta la hoja de esa dirección: usar el roll lateral mientras tanto.
				tex = _sequence(id, "roll", "right")
			if tex.is_empty():
				if d in DIRS:
					push_warning("CharacterSprites: faltan frames %s_%s de %s" % [base, d, id])
				continue
			# Hoja de poses intermedias (<base>_b_<dir>): duplica los frames (caminata y ataques del combo)
			var mid: Array[Texture2D] = []
			# La caminata NO usa las hojas walk_b: generadas aparte, salen más altas y sus poses no son
			# intermedias reales (las piernas van y vienen) -> el personaje "vibraba" al caminar.
			if ((base in COMBO_BASES.values() and MID_ALLOW.has(base)) or (base == "walk" and USE_WALK_MID)) \
					and not MID_SKIP.has("%s_%s_%s" % [id, base, d]):
				mid = _sequence(id, "%s_b" % base, d)
			var has_mid := tex.size() >= 4 and mid.size() >= 4
			# Ciclo completo de 8 poses en una sola hoja (<base>8_<dir>, GROKBOT_PULIDO_2.md):
			# tiene prioridad sobre las intermedias porque las 8 poses salen del mismo dibujo.
			var full8: Array[Texture2D] = []
			if base == "walk" or base in COMBO_BASES.values() or base.ends_with("_special") or base.ends_with("_parry"):
				full8 = _sequence(id, "%s8" % base, d)
			var has8 := full8.size() >= 8
			if has8:
				has_mid = false
			var full: Array = tex
			if has8:
				full = full8
			elif has_mid:
				full = _interleave(tex, mid)
			_add(frames, "%s_%s" % [base, d], full, fps * (2.0 if (has_mid or has8) else 1.0), loop)
			if base == "walk":
				# reposo: hoja animada "idle_anim" si existe; si no, pose de pie ("idle") con respiración de 1 px
				var idle_anim := _sequence(id, "idle_anim", d)
				if idle_anim.size() >= 4:
					_add(frames, "idle_%s" % d, idle_anim, 3.0, true)
				else:
					var idle := _sequence(id, "idle", d)
					var idle_tex: Texture2D = idle[0] if not idle.is_empty() else tex[mini(1, tex.size() - 1)]
					_add(frames, "idle_%s" % d, [idle_tex, idle_tex, _breathe(idle_tex, 1)], 2.0, true)
			if base == "guerrero_attack":
				_add(frames, "guard_%s" % d, [tex[0]], 1.0, true)
			if base == "hurt" and tex.size() >= 4:
				# recibir golpe = poses 1-2; caído y levantarse = poses 3-4
				_add(frames, "flinch_%s" % d, tex.slice(0, 2), 10.0, false)
				var kd8 := _sequence(id, "knockdown8", d)
				if kd8.size() >= 8:
					# pulido 3: golpe, cae, rebota, en el suelo (más tiempo), se incorpora, de rodillas, de pie (1.2 s)
					var kseq: Array = []
					for i in [0, 1, 2, 3, 3, 4, 4, 5, 6, 7]:
						kseq.append(kd8[i])
					_add(frames, "knockdown_%s" % d, kseq, kseq.size() / 1.2, false)
				else:
					_add(frames, "knockdown_%s" % d, [tex[2], tex[2], tex[3]], 2.5, false)
			if tex.size() >= 4 and base in COMBO_BASES.values():
				# golpe 1 = poses 1-2 (+ sus intermedias); golpe 2 = poses 3-4 (+ intermedias)
				if has8:
					_add(frames, "%s_1_%s" % [base, d], full8.slice(0, 4), fps * 2.0, false)
					_add(frames, "%s_2_%s" % [base, d], full8.slice(4, 8), fps * 2.0, false)
				elif has_mid:
					_add(frames, "%s_1_%s" % [base, d], [tex[0], mid[0], tex[1], mid[1]], fps * 2.0, false)
					_add(frames, "%s_2_%s" % [base, d], [tex[2], mid[2], tex[3], mid[3]], fps * 2.0, false)
				else:
					_add(frames, "%s_1_%s" % [base, d], tex.slice(0, 2), fps, false)
					_add(frames, "%s_2_%s" % [base, d], tex.slice(2, 4), fps, false)
	for cls in COMBO_BASES.keys():
		for d in WALK_DIRS:
			var fin := _sequence(id, "%s_finisher" % cls, d)
			if fin.is_empty():
				fin = _sequence(id, COMBO_BASES[cls], d)
			if not fin.is_empty():
				_add(frames, "%s_finisher_%s" % [cls, d], fin, 10.0, false)
			# contraataque tras parry exitoso: hoja propia de 8 poses o, si falta, el remate
			var counter := _sequence(id, "%s_counter8" % cls, d)
			if counter.size() >= 8:
				_add(frames, "%s_counter_%s" % [cls, d], counter, 16.0, false)
			elif not fin.is_empty():
				_add(frames, "%s_counter_%s" % [cls, d], fin, 10.0, false)
	# reposo largo (mira el celular), solo si existe la hoja
	for d in WALK_DIRS:
		var il := _sequence(id, "idle_long", d)
		if il.size() >= 8:
			var ilseq: Array = []
			for i in [0, 1, 2, 3, 3, 4, 4, 5, 5, 6, 7]:
				ilseq.append(il[i])
			_add(frames, "idle_long_%s" % d, ilseq, 4.0, false)
	# Ultimates (secuencias armadas con poses de varias hojas; duran lo que la acción)
	for d in WALK_DIRS:
		var ult := _sequence(id, "guerrero_ultimate", d)
		var fin := _sequence(id, "guerrero_finisher", d)
		var g8 := _sequence(id, "guerrero_ultimate8", d)
		if g8.size() >= 8:
			# pulido 3: carga 0.5 s (poses 1-4) -> espadazo sostenido 0.75 s (5-6) -> recupera (7-8)  (8 fps)
			var gseq: Array = []
			for i in [0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 6, 7]:
				gseq.append(g8[i])
			_add(frames, "guerrero_ultimate_beam_%s" % d, gseq, 8.0, false)
		elif ult.size() >= 4 and fin.size() >= 4:
			# carga (regla en alto) 0.5 s -> espadazo sostenido 0.75 s -> recupera 0.25 s  (8 fps)
			var seq: Array = []
			for i in 4: seq.append(ult[0])
			for i in 6: seq.append(fin[2])
			for i in 2: seq.append(fin[3])
			_add(frames, "guerrero_ultimate_beam_%s" % d, seq, 8.0, false)
		var mu := _sequence(id, "mago_ultimate", d)
		var m8 := _sequence(id, "mago_ultimate8", d)
		if m8.size() >= 8:
			# pulido 3: levanta el bastón -> llama los rayos (poses 5-6 alternadas) -> lo clava -> de pie  (5 fps = 2.6 s)
			var mseq: Array = []
			for i in [0, 1, 2, 3, 4, 5, 4, 5, 4, 5, 6, 6, 7]:
				mseq.append(m8[i])
			_add(frames, "mago_ultimate_storm_%s" % d, mseq, 5.0, false)
		elif mu.size() >= 4:
			# bastón en alto mientras caen los rayos -> clava el bastón -> de pie  (5 fps = 2.6 s)
			var seq2: Array = []
			for i in 10: seq2.append(mu[0])
			for i in 2: seq2.append(mu[2])
			seq2.append(mu[3])
			_add(frames, "mago_ultimate_storm_%s" % d, seq2, 5.0, false)
		# torbellino de chain (bucle mientras dura): hoja propia "chain_ultimate_spin" si existe;
		# si no, una sola pose de la ultimate + respiración (las poses 2 y 3 tienen alturas distintas)
		var spin := _sequence(id, "chain_ultimate_spin", d)
		var cu := _sequence(id, "chain_ultimate", d)
		var c8 := _sequence(id, "chain_ultimate8", d)
		if c8.size() >= 8:
			# pulido 3: arranque (poses 1-4) antes del giro; el giro usa su hoja propia o las poses 5-8
			_add(frames, "chain_ultimate_start_%s" % d, c8.slice(0, 4), 12.0, false)
			if spin.size() < 4:
				spin = c8.slice(4, 8)
		if spin.size() >= 4:
			_add(frames, "chain_ultimate_spin_%s" % d, spin, 12.0, true)
		elif cu.size() >= 4:
			_add(frames, "chain_ultimate_spin_%s" % d, [cu[1], _breathe(cu[1], 2)], 8.0, true)
	_cache[id] = frames
	return frames


## Intercala dos listas de frames: a0, b0, a1, b1, ...
static func _interleave(a: Array, b: Array) -> Array:
	var out: Array = []
	for i in a.size():
		out.append(a[i])
		if i < b.size():
			out.append(b[i])
	return out


## Textura suelta (para vistas previas).
static func idle_texture(id: String, facing: String) -> Texture2D:
	var frames := build_frames(id)
	var anim := "idle_%s" % dir_for_facing(facing)
	if frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
		return frames.get_frame_texture(anim, 0)
	return null


## Copia del frame con la parte superior del cuerpo bajada `px` píxeles (respiración).
## Los pies no se mueven: solo se desplazan las filas por encima de la cintura.
static func _breathe(tex: Texture2D, px: int) -> Texture2D:
	var src := tex.get_image()
	if src == null:
		return tex
	if src.is_compressed():
		src.decompress()
	var w := src.get_width()
	var h := src.get_height()
	var waist := int(h * 0.95) - int(CHARACTER_HEIGHT * 0.42)
	var out := Image.create(w, h, false, src.get_format())
	out.blit_rect(src, Rect2i(0, waist, w, h - waist), Vector2i(0, waist))
	out.blit_rect(src, Rect2i(0, 0, w, waist - px), Vector2i(0, px))
	return ImageTexture.create_from_image(out)


static func _add(frames: SpriteFrames, anim: String, tex: Array, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for t in tex:
		frames.add_frame(anim, t)


static func _sequence(id: String, base: String, d: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in 16:
		var tex := _load("%s%s/%s_%s_%d.png" % [ROOT, id, base, d, i])
		if tex == null:
			break
		out.append(tex)
	return out


static func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			return res
	# Aún sin importar (p. ej. frames recién generados): cargar el PNG directo.
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	return null
