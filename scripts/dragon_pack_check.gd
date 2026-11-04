extends SceneTree

## godot --headless --main-pack build/web/index.pck -s res://scripts/dragon_pack_check.gd
## ResourceLoader.exists is what the web build can see.

func _initialize() -> void:
	var failed := 0
	var paths: PackedStringArray = PackedStringArray()
	for event in DragonAudio.manifest_events():
		paths.append(str(DragonAudio.spec(event).get("file", "")))
	paths.append("res://art/worlds/dragon_lair/bg_sky.png")
	paths.append("res://art/worlds/dragon_lair/bg_clouds.png")
	paths.append("res://art/worlds/dragon_lair/bg_far.png")
	paths.append("res://art/worlds/dragon_lair/bg_near.png")
	paths.append("res://art/worlds/dragon_lair/transition/crack_mask_r1.png")
	paths.append("res://art/worlds/dragon_lair/transition/crack_mask_r8.png")
	paths.append("res://art/dragon_enemies/ash_wraith_phase.png")
	paths.append("res://art/dragon_enemies/dragon_egg_break.png")
	var seen := {}
	for path in paths:
		if path == "" or seen.has(path):
			continue
		seen[path] = true
		if not ResourceLoader.exists(path):
			push_error("export pack is missing %s" % path)
			failed += 1
			continue
		print("PACKED %s" % path)
	var music := load(DragonAudio.MUSIC_PATH) as AudioStreamOggVorbis
	if music == null or music.get_length() < 50.0:
		push_error("packed dragon music did not load")
		failed += 1
	var lair := load("res://audio/sfx_dragon_lair_transition.wav") as AudioStream
	if lair == null or lair.get_length() < 2.4:
		push_error("packed lair transition was trimmed, length %s" % (lair.get_length() if lair != null else -1))
		failed += 1
	if failed > 0:
		push_error("PACK_DRAGON_FAIL %d" % failed)
		quit(1)
		return
	print("PACK_DRAGON_OK %d" % seen.size())
	quit(0)
