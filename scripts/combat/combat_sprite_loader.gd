class_name CombatSpriteLoader
extends RefCounted
## Carga SpriteFrames desde carpetas PNG en assets/sprites/combat/.

const ROOT := "res://assets/sprites/combat/"


static func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.new()
		if img.load(abs_path) == OK:
			return ImageTexture.create_from_image(img)
	return null


static func collect_sequence(folder: String, prefix: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var i := 0
	while true:
		var path := "%s%s/%s_%d.png" % [ROOT, folder, prefix, i]
		var tex := load_texture(path)
		if tex == null:
			break
		out.append(tex)
		i += 1
		if i > 64:
			break
	return out


static func add_anim(frames: SpriteFrames, anim: String, textures: Array[Texture2D], fps: float, loop: bool) -> void:
	if frames.has_animation(anim):
		frames.remove_animation(anim)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for tex in textures:
		frames.add_frame(anim, tex)


static func build_player_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	# Walk 4-dir
	for dir_name in ["front", "back", "right", "left"]:
		var walk_tex := collect_sequence("walk", dir_name)
		add_anim(frames, "walk_%s" % dir_name, walk_tex, 8.0, true)
		# idle = first walk frame
		var idle: Array[Texture2D] = []
		if walk_tex.size() > 0:
			idle.append(walk_tex[0])
		add_anim(frames, "idle_%s" % dir_name, idle, 1.0, true)

	# Guerrero
	add_anim(frames, "guerrero_attack", collect_sequence("guerrero", "attack"), 10.0, false)
	var guard := collect_sequence("guerrero", "guard")
	var guard_idle_tex := load_texture(ROOT + "guerrero/guard_idle.png")
	if guard_idle_tex:
		var gi: Array[Texture2D] = [guard_idle_tex]
		add_anim(frames, "guerrero_guard", gi, 1.0, true)
	elif guard.size() > 0:
		add_anim(frames, "guerrero_guard", guard, 1.0, true)

	# Mago
	add_anim(frames, "mago_cast", collect_sequence("mago", "cast"), 10.0, false)
	add_anim(frames, "mago_melee", collect_sequence("mago", "melee"), 10.0, false)

	# Chain — same art, different speeds registered separately
	var whip := collect_sequence("chain", "whip_short")
	add_anim(frames, "chain_whip_short", whip, 14.0, false)
	add_anim(frames, "chain_whip_long", whip, 7.0, false)

	return frames


static func load_projectile_texture() -> Texture2D:
	return load_texture(ROOT + "mago/projectile.png")
