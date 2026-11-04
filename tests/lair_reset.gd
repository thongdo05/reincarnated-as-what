extends RefCounted

## Dragon lair is outside the world rotation, the crack swap blocks spawns
## until the wipe finishes, and this build's score epoch wipes local bests once.

func run() -> int:
	var failed := 0
	failed += _check_catalog()
	failed += _check_art()
	failed += _check_audio()
	failed += _check_epoch()
	return failed

func run_live(tree: SceneTree) -> int:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(game)
	var failed := _check_swap(game)
	tree.root.remove_child(game)
	game.free()
	return failed

func _check_catalog() -> int:
	var failed := 0
	if WorldCatalog.ids().has(WorldCatalog.DRAGON_LAIR) or WorldCatalog.ORDER.has(WorldCatalog.DRAGON_LAIR):
		push_error("dragon lair must stay out of the world rotation")
		failed += 1
	if WorldCatalog.ids().size() != 7:
		push_error("the normal rotation should stay seven worlds")
		failed += 1
	for id in WorldCatalog.ids():
		if WorldCatalog.candidates(id).has(WorldCatalog.DRAGON_LAIR):
			push_error("a reincarnation can roll the dragon lair")
			failed += 1
			break
	WorldCatalog.last_id = ""
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in 40:
		if WorldCatalog.roll(rng) == WorldCatalog.DRAGON_LAIR:
			push_error("roll() returned the dragon lair")
			failed += 1
			break
	if WorldCatalog.flash_name(WorldCatalog.DRAGON_LAIR) != "DRAGON LAIR":
		push_error("dragon lair flash name drifted")
		failed += 1
	var speeds := WorldCatalog.factors(WorldCatalog.DRAGON_LAIR)
	if speeds.size() != 4 or absf(speeds[0] - 0.05) > 0.0001 or absf(speeds[1] - 0.15) > 0.0001 or absf(speeds[2] - 0.3) > 0.0001 or absf(speeds[3] - 0.6) > 0.0001:
		push_error("dragon lair scroll should be 0.05/0.15/0.3/0.6, got %s" % str(speeds))
		failed += 1
	var layers := WorldCatalog.layers(WorldCatalog.DRAGON_LAIR)
	if layers.size() != 4 or layers[0] == null or layers[3] == null:
		push_error("dragon lair is missing a layer")
		failed += 1
	else:
		var near := layers[3].get_image()
		var far := layers[2].get_image()
		var solid := 0
		if near != null:
			for x in range(0, 480, 8):
				if near.get_pixel(x, int(FieldBackground.GROUND_FEET)).a > 0.8:
					solid += 1
		if solid < 60:
			push_error("dragon lair ground line should be opaque at y=234, samples %d" % solid)
			failed += 1
		if far != null:
			for island in FieldBackground.ISLANDS:
				var grass := far.get_pixel(int(island.x), int(island.y))
				if grass.a < 0.5 or grass.g <= grass.r or grass.g <= grass.b:
					push_error("dragon lair deck missed the grass at %s" % str(island))
					failed += 1
	if absf(LairTransition.BANNER - 0.4) > 0.001 or absf(LairTransition.FLASH - 0.1) > 0.001:
		push_error("lair banner/flash timings drifted")
		failed += 1
	if absf(LairTransition.CRACKS - 0.6) > 0.001 or absf(LairTransition.WIPE - 0.6) > 0.001 or absf(LairTransition.SETTLE - 0.8) > 0.001:
		push_error("lair crack/wipe/settle timings drifted")
		failed += 1
	if not LairTransition.blocks_at(1.6) or not LairTransition.blocks_at(0.5) or LairTransition.blocks_at(LairTransition.SWAP_AT):
		push_error("spawns should wait until the wipe finishes")
		failed += 1
	if absf(LairTransition.TOTAL - 2.5) > 0.001:
		push_error("the lair transition should last 2.5 s, matching the sting")
		failed += 1
	return failed

func _check_art() -> int:
	var failed := 0
	var wraith := "dragon_enemies/ash_wraith_phase.png"
	var egg := "dragon_enemies/dragon_egg_break.png"
	var wraith_frame: Array = ArtLibrary.entry(wraith)["frame_size"]
	var egg_frame: Array = ArtLibrary.entry(egg)["frame_size"]
	if int(wraith_frame[0]) != 41 or int(wraith_frame[1]) != 54 or ArtLibrary.anchor(wraith) != Vector2(20, 27):
		push_error("ash wraith phase should be 41x54 at anchor (20, 27)")
		failed += 1
	if int(egg_frame[0]) != 38 or int(egg_frame[1]) != 36 or ArtLibrary.anchor(egg) != Vector2(19, 18):
		push_error("dragon egg break should be 38x36 at anchor (19, 18)")
		failed += 1
	var wraith_tex := ArtLibrary.texture(wraith)
	var egg_tex := ArtLibrary.texture(egg)
	if wraith_tex == null or wraith_tex.get_width() != 41 * 4 or wraith_tex.get_height() != 54:
		push_error("ash wraith phase strip did not import at 164x54")
		failed += 1
	if egg_tex == null or egg_tex.get_width() != 38 * 6 or egg_tex.get_height() != 36:
		push_error("dragon egg break strip did not import at 228x36")
		failed += 1
	return failed

func _check_audio() -> int:
	var failed := 0
	var text := FileAccess.get_file_as_string("res://audio/dragon_manifest.json")
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("dragon audio manifest did not parse")
		return 1
	var files: Array = parsed.get("files", [])
	if files.size() != 55:
		push_error("dragon audio manifest should list 55 entries, got %d" % files.size())
		failed += 1
	var seen := {}
	for item in files:
		var entry: Dictionary = item
		var event := str(entry.get("event", ""))
		seen[event] = true
		var spec := DragonAudio.spec(event)
		if spec.is_empty():
			push_error("no cue spec for %s" % event)
			failed += 1
			continue
		if not ResourceLoader.exists(str(spec.get("file", ""))):
			push_error("missing imported audio for %s" % event)
			failed += 1
	if DragonAudio.manifest_events().size() != 55:
		push_error("DragonAudio should expose all 55 events")
		failed += 1
	for event in seen.keys():
		if not DragonAudio.manifest_events().has(str(event)):
			push_error("manifest event %s is not in DragonAudio" % event)
			failed += 1
	if DragonAudio.canonical(DragonPhase.HOOK_TIER) != "dragon_tier_up":
		push_error("tier hook should map to the tier-up stinger")
		failed += 1
	if DragonAudio.canonical(DragonPhase.HOOK_EGG_HATCH) != "dragon_enemy_dragon_egg_hatch":
		push_error("egg hatch hook should map to its sample")
		failed += 1
	if not DragonAudio.spec(DragonPhase.HOOK_RETURN_BREATH).is_empty():
		push_error("return-upgrade hooks have no sample and should stay silent")
		failed += 1
	var breath: Dictionary = DragonAudio.spec("great_dragon_breath_loop")
	var puddle: Dictionary = DragonAudio.spec("dragon_enemy_magma_puddle_sizzle_loop")
	if int(breath.get("loop_begin", -1)) != 0 or int(breath.get("loop_end", -1)) != 96000:
		push_error("breath loop should use samples 0-96000")
		failed += 1
	if int(puddle.get("loop_begin", -1)) != 0 or int(puddle.get("loop_end", -1)) != 86400:
		push_error("puddle loop should use samples 0-86400")
		failed += 1
	var lair_stream := load("res://audio/sfx_dragon_lair_transition.wav") as AudioStream
	if lair_stream == null or lair_stream.get_length() < 2.4:
		push_error("lair transition should keep its lead silence, length %s" % (lair_stream.get_length() if lair_stream != null else -1))
		failed += 1
	var music := load(DragonAudio.MUSIC_PATH) as AudioStreamOggVorbis
	var prepared := AudioCues.prepare_stream(music, "dragon_phase_bgm") as AudioStreamOggVorbis
	if prepared == null or not prepared.loop or absf(prepared.loop_offset) > 0.001 or prepared.get_length() < 50.0:
		push_error("dragon phase music should loop the whole file")
		failed += 1
	var rig := SoundRig.new()
	rig.setup()
	rig.play_event(DragonPhase.HOOK_TIER)
	if rig.play_count(DragonPhase.HOOK_TIER) != 1:
		push_error("with no dragon music playing, the tier stinger should fire on the downbeat immediately")
		failed += 1
	rig.play_dragon_music()
	if not rig.dragon_music_active() or rig.music_path() != DragonAudio.MUSIC_PATH:
		push_error("dragon music should replace the world loop")
		failed += 1
	rig.play_world_music("neon_tokyo")
	if rig.music_path() != DragonAudio.MUSIC_PATH:
		push_error("a map change must not replace dragon-phase music")
		failed += 1
	rig.end_dragon_bed()
	if rig.dragon_music_active():
		push_error("death should release the dragon music lock")
		failed += 1
	rig.free()
	if AudioCues.spec("dragon_slain").get("file", "") != "res://audio/sting_dragon_slain.wav":
		push_error("DRAGON SLAIN should play sting_dragon_slain.wav")
		failed += 1
	return failed

func _check_epoch() -> int:
	var failed := 0
	if BestScores.SCORE_EPOCH < 2:
		push_error("this build should bump the local score epoch")
		failed += 1
	var best_path := BestScores.SAVE_PATH
	var profile_path := Leaderboard.PROFILE_PATH
	var best_backup := FileAccess.get_file_as_string(best_path) if FileAccess.file_exists(best_path) else ""
	var profile_backup := FileAccess.get_file_as_string(profile_path) if FileAccess.file_exists(profile_path) else ""
	_write(best_path, JSON.stringify({
		"epoch": BestScores.SCORE_EPOCH - 1,
		"overall": 900,
		"SLIME": 900,
	}))
	_write(profile_path, JSON.stringify({
		"device_id": "device-keep",
		"name": "Gel Knight",
		"posted": true,
		"epoch": BestScores.SCORE_EPOCH - 1,
		"bests": {"slime": 900},
	}))
	var wiped := BestScores.read()
	if int(wiped.get("overall", -1)) != 0 or wiped.has("SLIME"):
		push_error("the previous score epoch should wipe local bests once, got %s" % wiped)
		failed += 1
	var again := BestScores.read()
	if int(again.get("overall", -1)) != 0 or again.has("SLIME"):
		push_error("a second read must not revive the wiped best")
		failed += 1
	var kept := BestScores.record("GOBLIN", 15)
	var third := BestScores.read()
	if int(kept.get("overall", 0)) != 15 or int(third.get("overall", 0)) != 15 or int(third.get("GOBLIN", 0)) != 15:
		push_error("scores saved after the wipe should stick, got %s / %s" % [kept, third])
		failed += 1
	var client := Leaderboard.new()
	var name := client.player_name()
	var device := client.device_id()
	client.free()
	if name != "Gel Knight" or device != "device-keep":
		push_error("the score wipe should keep the saved name, got %s / %s" % [name, device])
		failed += 1
	var profile: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	if typeof(profile) != TYPE_DICTIONARY or (profile as Dictionary).has("bests"):
		push_error("cached online bests should be dropped locally and not posted")
		failed += 1
	_write(best_path, best_backup)
	_write(profile_path, profile_backup)
	return failed

func _check_swap(game) -> int:
	var failed := 0
	game.phase = game.PHASE_PLAY
	game.elapsed = 30.0
	game.invuln = 60.0
	game._player.invulnerable = true
	game._player.alive = true
	game._tutorial_active = false
	game._boss_director.dragon_at = 100000.0
	var before := str(game._background.world_id)
	game._begin_lair_transition()
	game._begin_dragon_phase()
	var step := 1.0 / 60.0
	var saw_enemy := false
	for _i in 90:
		game._process(step)
		if _dragons(game) > 0:
			saw_enemy = true
	if saw_enemy or str(game._background.world_id) != before:
		push_error("dragon enemies or the lair arrived before the crack wipe")
		failed += 1
	if game._lair == null or game._lair.phase_name() == "idle":
		push_error("the crack transition should still be running")
		failed += 1
	for _i in 80:
		game._process(step)
	if str(game._background.world_id) != WorldCatalog.DRAGON_LAIR:
		push_error("the wipe should leave the run in the dragon lair, world %s phase %s" % [game._background.world_id, game._lair.phase_name() if game._lair != null else "?"])
		failed += 1
	if game._lair_blocks_spawns():
		push_error("spawns should open once the lair is on screen")
		failed += 1
	saw_enemy = false
	for _i in 80:
		game.invuln = 60.0
		game._process(step)
		if _dragons(game) > 0:
			saw_enemy = true
			break
	if not saw_enemy:
		push_error("dragon-phase enemies should spawn after the lair swap")
		failed += 1
	var locked := str(game._background.world_id)
	game._sound.play_dragon_music()
	game._sound.play_world_music("neon_tokyo")
	if game._sound.music_path() != DragonAudio.MUSIC_PATH or locked != WorldCatalog.DRAGON_LAIR:
		push_error("the lair and its music should hold for the rest of the run")
		failed += 1
	return failed

func _dragons(game) -> int:
	var count := 0
	for enemy in game._enemies:
		if enemy is DragonEnemy and enemy.alive:
			count += 1
	return count

func _write(path: String, body: String) -> void:
	if body == "":
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(body)
	file.close()
