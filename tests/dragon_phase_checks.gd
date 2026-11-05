extends RefCounted

## Headless checks for the post-dragon enemy phase. Smoke and
## tests/dragon_phase_spawn.gd both call run().

func run() -> int:
	var failed := 0
	failed += _check_formula()
	failed += _check_art()
	failed += _check_returns()
	failed += _check_spawns()
	failed += _check_actors()
	failed += _check_elder_breath()
	failed += _check_lair_hp()
	failed += load("res://tests/lair_reset.gd").new().run()
	return failed

func run_live(tree: SceneTree) -> int:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(game)
	var failed := 0
	game.phase = game.PHASE_PLAY
	game.elapsed = 20.0
	game._boss_director.dragon_at = 100000.0
	game.invuln = 60.0
	game._player.invulnerable = true
	game._player.alive = true
	game._tutorial_active = false
	game.form_id = FormCatalog.Id.DRAGON
	game._player.adopt_dragon(1.0)
	game._begin_dragon_phase()
	var step := 1.0 / 60.0
	for _i in 150:
		game.invuln = 60.0
		game._process(step)
		if int(game.phase) != game.PHASE_PLAY:
			push_error("dragon phase killed the run early, killer %s" % game.killer_name)
			failed += 1
			break
	if failed == 0 and _dragon_count(game) <= 0:
		push_error("the dragon phase should replace regular spawns")
		failed += 1
	if failed == 0:
		game._dragon_phase_at = game.elapsed - 185.0
		game._dragon_spawns._origin = game._dragon_phase_at
		game._dragon_spawns.arm_at(185.0)
		game.invuln = 60.0
		game._process(step)
		if game._dragon_tier < 4:
			push_error("forcing the clock should unlock tier 4, tier %d time %.1f at %.1f elapsed %.1f phase %s" % [game._dragon_tier, game.dragon_phase_elapsed(), game._dragon_phase_at, game.elapsed, game.phase])
			failed += 1
		var saw_elder := false
		var cursor: float = game.elapsed
		var guard := 0
		while cursor < game.elapsed + 70.0 and not saw_elder and guard < 200:
			guard += 1
			cursor += 0.5
			for event in game._dragon_spawns.pop_due(cursor, false):
				if int(event["dragon_id"]) == DragonPhase.ELDER:
					saw_elder = true
		if not saw_elder:
			push_error("tier 4 should offer an Elder Drake")
			failed += 1
	tree.root.remove_child(game)
	game.free()
	failed += _check_boss_minion_spawns(tree)
	failed += load("res://tests/lair_reset.gd").new().run_live(tree)
	return failed

func _dragon_count(game) -> int:
	var count := 0
	for enemy in game._enemies:
		if enemy is DragonEnemy and enemy.alive:
			count += 1
	return count

func _check_formula() -> int:
	var failed := 0
	if absf(DragonPhase.hp_mul(0.0) - DragonPhase.HP_MULT_START) > 0.001 or absf(DragonPhase.HP_MULT_START - 2.0) > 0.001:
		push_error("dragon phase should open at 2x HP")
		failed += 1
	if absf(DragonPhase.spawn_rate_mul(0.0) - 1.5) > 0.001:
		push_error("dragon phase should open at 1.5x spawn rate")
		failed += 1
	if DragonPhase.hp_mul(90.0) <= DragonPhase.hp_mul(0.0) or DragonPhase.spawn_rate_mul(90.0) <= DragonPhase.spawn_rate_mul(0.0):
		push_error("HP and spawn rate should climb with time survived")
		failed += 1
	if DragonPhase.bullet_density(120.0) <= DragonPhase.bullet_density(0.0) or DragonPhase.shot_cap(200.0) < DragonPhase.shot_cap(0.0):
		push_error("bullet density and the shot cap should climb")
		failed += 1
	if DragonPhase.hp_mul(9999.0) > DragonPhase.HP_MULT_CAP + 0.001 or DragonPhase.spawn_rate_mul(9999.0) > DragonPhase.SPAWN_RATE_CAP + 0.001:
		push_error("the dragon-phase ramp should stay capped")
		failed += 1
	var run_at := 160.0
	var base := Difficulty.spawn_interval(run_at)
	var opened := DragonPhase.spawn_interval(run_at, 0.0)
	var ratio := base / opened
	if ratio + 0.02 < DragonPhase.SPAWN_RATE_START and opened > DragonPhase.SPAWN_INTERVAL_FLOOR + 0.001:
		push_error("opening spawn interval should be the run's interval / 1.5, got %.3f / %.3f" % [base, opened])
		failed += 1
	if opened + 0.001 < DragonPhase.SPAWN_INTERVAL_FLOOR:
		push_error("spawn interval went under the floor")
		failed += 1
	if DragonPhase.scaled_hp(DragonPhase.BAT, 0.0) != 8:
		push_error("an ember bat should open at 8 HP, got %d" % DragonPhase.scaled_hp(DragonPhase.BAT, 0.0))
		failed += 1
	if DragonPhase.tier_for(0.0) != 1 or DragonPhase.tier_for(59.9) != 1 or DragonPhase.tier_for(60.0) != 2:
		push_error("tier 2 should unlock at 60s")
		failed += 1
	if DragonPhase.tier_for(119.9) != 2 or DragonPhase.tier_for(120.0) != 3 or DragonPhase.tier_for(179.9) != 3 or DragonPhase.tier_for(180.0) != 4:
		push_error("tier 3 and 4 should unlock at 120s and 180s")
		failed += 1
	if DragonPhase.STATS.size() != 10 or DragonPhase.HOOKS.size() != 32:
		push_error("expected 10 enemies and 32 sound hooks, got %d / %d" % [DragonPhase.STATS.size(), DragonPhase.HOOKS.size()])
		failed += 1
	if not DragonPhase.is_hook(DragonPhase.HOOK_TIER) or not AudioCues.is_hook(DragonPhase.HOOK_EGG_HATCH) or AudioCues.is_hook("not_a_cue"):
		push_error("sound hooks should be named and silent until the samples exist")
		failed += 1
	return failed

func _check_art() -> int:
	var failed := 0
	var text := FileAccess.get_file_as_string("res://art/dragon_enemies/manifest.json")
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).size() != 40:
		push_error("dragon enemy manifest should list 40 sheets")
		return failed + 1
	for item in parsed:
		var entry: Dictionary = item
		var file_name := str(entry["file"])
		if not file_name.begins_with("dragon_enemies/") or str(entry.get("facing", "")) != "left":
			push_error("%s should live in dragon_enemies and face left" % file_name)
			failed += 1
		if not ArtLibrary.has_file(file_name):
			push_error("missing dragon sheet %s" % file_name)
			failed += 1
			continue
		var anchor: Array = entry["anchor"]
		var got := ArtLibrary.anchor(file_name)
		if absf(got.x - float(anchor[0])) > 0.01 or absf(got.y - float(anchor[1])) > 0.01:
			push_error("anchor mismatch for %s" % file_name)
			failed += 1
		var frame: Array = entry["frame_size"]
		var frames := int(entry["frames"])
		var tex := ArtLibrary.texture(file_name)
		if tex == null or tex.get_width() != int(frame[0]) * frames or tex.get_height() != int(frame[1]):
			push_error("%s strip size does not match its frame" % file_name)
			failed += 1
		if not HitLibrary.has_role(file_name, "body") or not HitLibrary.has_role(file_name, "threat"):
			push_error("%s needs a body and a threat shape" % file_name)
			failed += 1
	for id in DragonPhase.STATS.size():
		if DragonPhase.death_file(id) == "" or DragonPhase.move_file(id) == "":
			push_error("enemy %d is missing art" % id)
			failed += 1
	return failed

func _check_returns() -> int:
	var failed := 0
	if DragonPhase.has_return(0, 0) or not DragonPhase.has_return(1, 0) or DragonPhase.has_return(1, 1):
		push_error("the first return should add only the faster breath")
		failed += 1
	if not DragonPhase.has_return(5, 4) or DragonPhase.RETURN_ORDER.size() != 5:
		push_error("five return upgrades should stack")
		failed += 1
	if BossCatalog.max_hp("great_dragon", 0) != 10000 or BossCatalog.max_hp("great_dragon", 3) != 40000:
		push_error("return HP should stay 10000 plus 10000 per return")
		failed += 1
	var wind0 := BossCatalog.windup("hell_breath", 3, 0)
	var wind5 := BossCatalog.windup("hell_breath", 3, 5)
	if wind5 < 0.36 or wind5 > wind0 + 0.001:
		push_error("a return must not shorten the breath warning below a readable floor, %.2f -> %.2f" % [wind0, wind5])
		failed += 1
	for pattern in ["sky_breath", "hell_breath", "ember_fan", "dive", "boss_meteor", "wing_gust"]:
		if BossCatalog.windup(pattern, 3, 5) < 0.36:
			push_error("%s warning became unreadable" % pattern)
			failed += 1
	var origin := Vector2(410, 130)
	var aim := Vector2(140, 120)
	var speed := BossCatalog.bullet_speed(1, 0)
	var slow: Array[Dictionary] = BossCatalog.shot_plan("sky_breath", 1, 0, origin, aim, speed)
	var fast: Array[Dictionary] = BossCatalog.shot_plan("sky_breath", 1, 1, origin, aim, speed)
	if slow.is_empty() or fast.is_empty() or float((fast[0]["velocity"] as Vector2).x) >= float((slow[0]["velocity"] as Vector2).x):
		push_error("the first return should speed the breath")
		failed += 1
	var meteors0 := BossCatalog.shot_plan("boss_meteor", 2, 0, origin, aim, speed).size()
	var meteors2 := BossCatalog.shot_plan("boss_meteor", 2, 2, origin, aim, speed).size()
	if meteors0 != 3 or meteors2 != DragonPhase.RETURN_METEOR_COUNT:
		push_error("return 2 should add meteors, got %d then %d" % [meteors0, meteors2])
		failed += 1
	var gap2 := BossCatalog.cooldown("sky_breath", 2, 180.0, 2)
	var gap3 := BossCatalog.cooldown("sky_breath", 2, 180.0, 3)
	if gap3 > gap2 + 0.001 or gap3 + 0.001 < DragonPhase.RETURN_GAP_FLOOR:
		push_error("return 3 should shorten the gap between attacks without deleting it, %.2f -> %.2f" % [gap2, gap3])
		failed += 1
	if BossCatalog.hell_gap_speed(3) > 0.0 or BossCatalog.hell_gap_speed(4) <= 0.0:
		push_error("the moving safe gap should arrive on return 4")
		failed += 1
	var fan4 := BossCatalog.shot_plan("ember_fan", 1, 4, origin, aim, speed).size()
	var fan5 := BossCatalog.shot_plan("ember_fan", 1, 5, origin, aim, speed).size()
	if fan5 != fan4 * 2:
		push_error("return 5 should add a second fireball spread, %d -> %d" % [fan4, fan5])
		failed += 1
	if BossCatalog.attack_cycle("great_dragon", 1) != ["sky_breath", "ember_fan"] or BossCatalog.attack_cycle("great_dragon", 3) != ["hell_breath", "dive", "boss_meteor"]:
		push_error("the dragon's base attack list should stay put")
		failed += 1
	failed += _check_moving_gap()
	failed += _check_upgrade_cues()
	return failed

func _check_moving_gap() -> int:
	var failed := 0
	var field := Vector2(480, 270)
	var still := _dragon(0, field)
	still.hp = int(float(still.max_hp) * 0.2)
	still.tick(0.05, Vector2(120, 110), 180.0, 1.0)
	if still._hell_gap_left > 0.0:
		push_error("the first dragon's enrage breath should not slide its gap")
		failed += 1
	still.free()
	var moved := _dragon(4, field)
	moved.hp = int(float(moved.max_hp) * 0.2)
	moved.tick(0.05, Vector2(120, 90), 180.0, 1.0)
	var started := moved._hell_gap_y
	if moved._hell_gap_left < 0.5 or started < 0.0:
		push_error("return 4 should telegraph a moving safe gap before the breath")
		failed += 1
	else:
		for _i in 8:
			moved.tick(0.05, Vector2(120, 90), 180.0, 1.0)
		if absf(moved._hell_gap_y - started) < 8.0:
			push_error("the safe gap should actually move")
			failed += 1
		if moved._hell_gap_left <= 0.0:
			push_error("the moving gap ate its own warning")
			failed += 1
	moved.free()
	return failed

## A gen-5 return plays each upgrade cue once, over the attack sound.
## A first fight plays none of them. The manifest says once, when the
## upgrade first appears, so a repeat of the same attack does not replay it.
func _check_upgrade_cues() -> int:
	var failed := 0
	var returned := _hear_return(5)
	var first := _hear_return(0)
	var cues := [
		DragonPhase.HOOK_RETURN_BREATH,
		DragonPhase.HOOK_RETURN_METEORS,
		DragonPhase.HOOK_RETURN_GAPS,
		DragonPhase.HOOK_RETURN_HELL,
		DragonPhase.HOOK_RETURN_FAN,
	]
	for cue in cues:
		if int(returned["upgrade"][cue]) != 1:
			push_error("a gen-5 return should play %s once, got %s" % [cue, returned["upgrade"][cue]])
			failed += 1
		if int(first["upgrade"][cue]) != 0:
			push_error("the first fight should stay silent on %s, got %s" % [cue, first["upgrade"][cue]])
			failed += 1
	if int(returned["early_gaps"]) != 0 or int(first["early_gaps"]) != 0:
		push_error("shorter gaps should wait for the phase roar, intro counts %s / %s" % [returned["early_gaps"], first["early_gaps"]])
		failed += 1
	if int(returned["phase2_dive"]) != 0:
		push_error("the fast-gap cue should not play on the phase-2 dive")
		failed += 1
	if int(returned["before_loop"]) != 0:
		push_error("the faster-breath cue should start with the breath loop, not the warning")
		failed += 1
	var layers := {
		DragonPhase.HOOK_SKY_BREATH: 2,
		"great_dragon_breath_loop": 2,
		DragonPhase.HOOK_EMBER_FAN: 2,
		"great_dragon_phase_roar": 2,
		DragonPhase.HOOK_METEOR: 2,
		DragonPhase.HOOK_HELL_BREATH: 2,
		DragonPhase.HOOK_DIVE: 1,
	}
	for event in layers.keys():
		if int(returned["base"][event]) < int(layers[event]):
			push_error("gen 5 should keep the base sound %s, got %s" % [event, returned["base"][event]])
			failed += 1
		if int(first["base"][event]) < 1:
			push_error("the first fight should still play %s" % event)
			failed += 1
	return failed

func _hear_return(generation: int) -> Dictionary:
	var sound := SoundRig.new()
	sound.setup()
	var ear := _UpgradeEar.new()
	ear.sound = sound
	var boss := BossActor.new()
	ear.add_child(boss)
	var field := Vector2(480, 270)
	boss.setup(1, {
		"slug": "great_dragon",
		"hold_x": 410.0,
		"origin_y": 130.0,
		"phase": 0.2,
		"wave_amp": 8.0,
		"generation": generation,
	}, field, null)
	var aim := Vector2(120, 110)
	boss.tick(BossCatalog.DRAGON_INTRO + 0.05, aim, 180.0, 1.0)
	var early_gaps := sound.play_count(DragonPhase.HOOK_RETURN_GAPS)
	_set_phase(boss, 2)
	_poke(boss, 1, aim)
	var phase2_dive := sound.play_count(DragonPhase.HOOK_RETURN_HELL)
	_set_phase(boss, 1)
	_poke(boss, 0, aim)
	var before_loop := sound.play_count(DragonPhase.HOOK_RETURN_BREATH)
	sound._process(DragonAudio.BREATH_LOOP_DELAY)
	_set_phase(boss, 1)
	_poke(boss, 1, aim)
	_set_phase(boss, 2)
	boss.hurt(1)
	_poke(boss, 3, aim)
	var edge := int(floor(float(boss.max_hp) * 0.33)) + 1
	boss.hp = edge
	boss.hurt(1)
	_poke(boss, 0, aim)
	_set_phase(boss, 1)
	_poke(boss, 0, aim)
	sound._process(DragonAudio.BREATH_LOOP_DELAY)
	_set_phase(boss, 1)
	_poke(boss, 1, aim)
	_set_phase(boss, 2)
	_poke(boss, 3, aim)
	_set_phase(boss, 3)
	_poke(boss, 0, aim)
	_poke(boss, 1, aim)
	var upgrade := {}
	for cue in [
		DragonPhase.HOOK_RETURN_BREATH,
		DragonPhase.HOOK_RETURN_METEORS,
		DragonPhase.HOOK_RETURN_GAPS,
		DragonPhase.HOOK_RETURN_HELL,
		DragonPhase.HOOK_RETURN_FAN,
	]:
		upgrade[cue] = sound.play_count(cue)
	var base := {}
	for event in [
		DragonPhase.HOOK_SKY_BREATH,
		"great_dragon_breath_loop",
		DragonPhase.HOOK_EMBER_FAN,
		"great_dragon_phase_roar",
		DragonPhase.HOOK_METEOR,
		DragonPhase.HOOK_HELL_BREATH,
		DragonPhase.HOOK_DIVE,
	]:
		base[event] = sound.play_count(event)
	ear.free()
	sound.free()
	return {
		"upgrade": upgrade,
		"base": base,
		"early_gaps": early_gaps,
		"phase2_dive": phase2_dive,
		"before_loop": before_loop,
	}

func _set_phase(boss: BossActor, phase: int) -> void:
	var max_hp := float(boss.max_hp)
	if phase <= 1:
		boss.hp = boss.max_hp
	elif phase == 2:
		boss.hp = int(floor(max_hp * 0.5))
	else:
		boss.hp = int(floor(max_hp * 0.2))

func _poke(boss: BossActor, index: int, aim: Vector2) -> void:
	boss.telegraphs.clear()
	boss._row_left = 0.0
	boss._hell_gap_left = 0.0
	boss._gust_warn = 0.0
	boss.gust_left = 0.0
	boss._attack_cd = 0.0
	boss._attack_i = index
	boss.state = BossActor.HOLD
	boss.intro_left = 0.0
	boss.tick(0.05, aim, 180.0, 1.0)

func _dragon(generation: int, field: Vector2) -> BossActor:
	var boss := BossActor.new()
	boss.setup(1, {"slug": "great_dragon", "hold_x": 410.0, "origin_y": 130.0, "phase": 0.2, "wave_amp": 8.0, "generation": generation}, field, null)
	boss.intro_left = 0.0
	boss.state = BossActor.HOLD
	boss.position = Vector2(410, 130)
	boss._attack_cd = 0.0
	boss._attack_i = 0
	boss._summon_cd = 80.0
	return boss

func _check_spawns() -> int:
	var failed := 0
	failed += _expect_tier(0.0, 28.0, [DragonPhase.BAT, DragonPhase.KOBOLD, DragonPhase.EGG, DragonPhase.WHELP], [DragonPhase.WYVERN, DragonPhase.CULTIST, DragonPhase.ELDER])
	failed += _expect_tier(60.0, 98.0, [DragonPhase.WYVERN, DragonPhase.SLIME, DragonPhase.RIDER, DragonPhase.BAT], [DragonPhase.CULTIST, DragonPhase.WRAITH, DragonPhase.ELDER])
	failed += _expect_tier(120.0, 165.0, [DragonPhase.CULTIST, DragonPhase.WRAITH, DragonPhase.KOBOLD], [DragonPhase.ELDER])
	failed += _expect_tier(180.0, 240.0, [DragonPhase.ELDER, DragonPhase.WRAITH, DragonPhase.BAT], [])
	var director := DragonSpawnDirector.new(77)
	director.begin(150.0)
	director.arm_at(4.0)
	var held := director.pop_due(150.0 + 40.0, true)
	if not held.is_empty():
		push_error("a paused poll should drop dragon-phase spawns instead of banking them")
		failed += 1
	var after := director.pop_due(150.0 + 43.0, false)
	for event in after:
		if float(event["t"]) < 39.0:
			push_error("paused spawns were saved up and dumped, t %s" % event["t"])
			failed += 1
			break
	return failed

func _expect_tier(arm: float, until: float, want: Array, blocked: Array) -> int:
	var director := DragonSpawnDirector.new(20261104)
	director.begin(150.0)
	director.arm_at(arm)
	var seen := {}
	var cursor := arm
	while cursor < until - 0.001:
		cursor = minf(cursor + 0.5, until)
		for event in director.pop_due(150.0 + cursor, false):
			var id := int(event["dragon_id"])
			seen[id] = int(seen.get(id, 0)) + 1
			if float(event["t"]) + 0.001 < arm:
				push_error("a spawn was pulled from before the tier window")
				return 1
			if not bool(event.get("dragon", false)):
				push_error("dragon phase emitted a regular enemy")
				return 1
	for id in want:
		if int(seen.get(id, 0)) <= 0:
			push_error("tier window %.0f-%.0f missed %s (%s)" % [arm, until, DragonPhase.stat(id)["name"], str(seen)])
			return 1
	for id in blocked:
		if int(seen.get(id, 0)) > 0:
			push_error("%s spawned before its tier" % DragonPhase.stat(id)["name"])
			return 1
	return 0

func _check_actors() -> int:
	var failed := 0
	var field := Vector2(480, 270)
	var egg := _make(DragonPhase.EGG, 3, Vector2(320, 180), field)
	var guard := 0
	while egg.alive and guard < 400:
		egg.tick(1.0 / 60.0, Vector2(40, 120), 1.0, 1.0)
		guard += 1
	if egg.alive or guard < 200:
		push_error("the egg should hatch in about 4s, alive %s frames %d" % [egg.alive, guard])
		failed += 1
	else:
		var born := egg.take_spawns()
		var bye := egg.take_farewell()
		if born.size() != 1 or int(born[0]["dragon_id"]) != DragonPhase.WHELP:
			push_error("a hatch should produce one whelp")
			failed += 1
		if str(bye.get("cue", "")) != DragonPhase.HOOK_EGG_HATCH:
			push_error("the hatch should fire its sound hook")
			failed += 1
	egg.free()
	var bat := _make(DragonPhase.BAT, 4, Vector2(220, 140), field)
	var cult := _make(DragonPhase.CULTIST, 5, Vector2(250, 140), field)
	var allies: Array[EnemyActor] = [bat, cult]
	cult.bind_allies(allies)
	bat.bind_allies(allies)
	cult.tick(0.1, Vector2(40, 140), 1.0, 1.0)
	if bat.shield_hits != DragonPhase.SHIELD_HITS:
		push_error("the cultist should shield a nearby enemy, hits %d" % bat.shield_hits)
		failed += 1
	else:
		var pool := bat.hp
		bat.hurt(1)
		if bat.hp != pool or not bat.consume_block():
			push_error("the shield should absorb the hit")
			failed += 1
		cult.hurt(999)
		if cult.alive or bat.shield_hits != 0:
			push_error("the shield should end when the cultist dies")
			failed += 1
	bat.free()
	cult.free()
	var wraith := _make(DragonPhase.WRAITH, 6, Vector2(340, 120), field)
	var phased := false
	var ring := 0
	var clock := 0.0
	while clock < 8.0 and ring == 0:
		var fired := wraith.tick(0.05, Vector2(80, 130), 1.0, 1.0)
		if wraith.is_phased():
			phased = true
			var before := wraith.hp
			wraith.hurt(4)
			if wraith.hp != before:
				push_error("a phased wraith should not take damage")
				failed += 1
				break
		for spec in fired:
			if str(spec.get("sprite", "")) == DragonPhase.RING_BULLET:
				ring += 1
		clock += 0.05
	if not phased or ring < 6:
		push_error("the wraith should phase out, then fire a ring, phased %s shots %d" % [phased, ring])
		failed += 1
	wraith.free()
	var wyvern := _make(DragonPhase.WYVERN, 7, Vector2(400, 100), field)
	if not wyvern.is_telegraphing():
		push_error("the wyvern should warn before it dives")
		failed += 1
	var warned := 0.0
	while warned < 1.4 and wyvern.warn_left > 0.0:
		wyvern.tick(0.05, Vector2(80, 100), 1.0, 1.0)
		warned += 0.05
	if wyvern.warn_left > 0.0 or wyvern.position.x < field.x:
		push_error("the dive should start from the right after the marker")
		failed += 1
	wyvern.free()
	var elder := _make(DragonPhase.ELDER, 8, Vector2(360, 180), field)
	var telegraphed := false
	var puffs := 0
	clock = 0.0
	while clock < 3.5 and puffs == 0:
		if elder.is_telegraphing():
			telegraphed = true
		for spec in elder.tick(0.05, Vector2(80, 170), 1.0, 1.0):
			if str(spec.get("sprite", "")) == DragonPhase.BREATH_PUFF:
				puffs += 1
		clock += 0.05
	if not telegraphed or puffs < 4:
		push_error("the elder should telegraph a breath cone, puffs %d warned %s" % [puffs, telegraphed])
		failed += 1
	elder.hurt(elder.hp)
	var gem := elder.death_gem()
	if elder.alive or int(gem.get("bonus", 0)) != DragonPhase.ELDER_GEM_BONUS:
		push_error("the elder should drop the bonus gem")
		failed += 1
	var puddles := _make(DragonPhase.SLIME, 9, Vector2(300, 200), field)
	var pools := puddles.death_shots()
	if pools.size() != 2 or str(pools[0].get("sprite", "")) != DragonPhase.PUDDLE:
		push_error("a dead magma slime should leave fire puddles")
		failed += 1
	elder.free()
	puddles.free()
	return failed

## Lair regulars, including the Elder Drake, open at twice the previous pools.
## The Great Dragon and the normal-world roster stay put.
func _check_lair_hp() -> int:
	var failed := 0
	var bases: Array[int] = [4, 8, 12, 6, 16, 14, 18, 16, 16, 320]
	var opens: Array[int] = [8, 16, 24, 12, 32, 28, 36, 32, 32, 640]
	if bases.size() != DragonPhase.STATS.size():
		push_error("lair HP table should cover every dragon-phase enemy")
		return 1
	for i in bases.size():
		if int(DragonPhase.stat(i)["hp"]) != bases[i]:
			push_error("%s base HP should be %d, got %s" % [DragonPhase.stat(i)["name"], bases[i], DragonPhase.stat(i)["hp"]])
			failed += 1
		if DragonPhase.scaled_hp(i, 0.0) != opens[i]:
			push_error("%s should open at %d HP, got %d" % [DragonPhase.stat(i)["name"], opens[i], DragonPhase.scaled_hp(i, 0.0)])
			failed += 1
	if DragonPhase.scaled_hp(DragonPhase.ELDER, 0.0) != 640:
		push_error("the elder should open at 640 HP")
		failed += 1
	if BossCatalog.max_hp("great_dragon", 0) != 10000 or BossCatalog.max_hp("great_dragon", 1) != 20000:
		push_error("the Great Dragon HP should stay 10000 then 20000")
		failed += 1
	if SpawnDirector.max_hp(SpawnDirector.EYE) != 2 or SpawnDirector.max_hp(SpawnDirector.ARCHER) != 4 or SpawnDirector.max_hp(SpawnDirector.WOLF) != 4 or SpawnDirector.max_hp(SpawnDirector.WYVERN) != 6:
		push_error("normal-world enemy HP should stay unchanged")
		failed += 1
	return failed

## Long aimed breath: 7-puff waves, a sweep, and a gap that is not the whole screen.
func _check_elder_breath() -> int:
	var failed := 0
	if DragonPhase.ELDER_WARN != 0.8:
		push_error("the elder telegraph should stay 0.8s")
		failed += 1
	if DragonPhase.elder_reach() + 0.1 < 0.70 * 480.0:
		push_error("elder breath should cross at least 70%% of the field, reach %.1f" % DragonPhase.elder_reach())
		failed += 1
	if DragonPhase.ELDER_CONE != 7 or DragonPhase.ELDER_WAVES != 3:
		push_error("the elder cone should be 7 puffs across 3 waves")
		failed += 1
	if DragonPhase.elder_wave_gap(1.65) >= DragonPhase.elder_wave_gap(1.0) or DragonPhase.elder_wave_gap(1.65) + 0.001 < DragonPhase.ELDER_WAVE_GAP_FLOOR:
		push_error("wave spacing should tighten with bullet density and keep a floor")
		failed += 1
	if DragonPhase.attack_gap(DragonPhase.ELDER_INTERVAL, 1.65) >= DragonPhase.attack_gap(DragonPhase.ELDER_INTERVAL, 1.0):
		push_error("the breath wait should still use attack_gap")
		failed += 1
	var field := Vector2(480, 270)
	var aim := Vector2(80, 120)
	var elder := _make(DragonPhase.ELDER, 21, Vector2(360, 180), field)
	elder.fire_room = -1
	elder.bullet_density = 1.0
	elder._attack_wait = 0.0
	var ear := _CueEar.new()
	ear.add_child(elder)
	var dt := 0.05
	var telegraph := 0.0
	var clock := 0.0
	var puffs: Array[Dictionary] = []
	var wave_at: Array[float] = []
	var moved := false
	while clock < 4.0 and wave_at.size() < DragonPhase.ELDER_WAVES:
		var was := elder.is_telegraphing()
		var fired := elder.tick(dt, aim, 1.0, 1.0)
		if was:
			telegraph += dt
		var born := 0
		for spec in fired:
			if str(spec.get("sprite", "")) == DragonPhase.BREATH_PUFF:
				puffs.append(spec)
				born += 1
		if born > 0:
			wave_at.append(clock)
			if not moved:
				moved = true
				aim = Vector2(80, 30)
		clock += dt
	if absf(telegraph - DragonPhase.ELDER_WARN) > 0.06:
		push_error("the breath telegraph lasted %.2fs, wanted 0.80" % telegraph)
		failed += 1
	if puffs.size() != DragonPhase.ELDER_CONE * DragonPhase.ELDER_WAVES:
		push_error("the breath should fire %d puffs, got %d" % [DragonPhase.ELDER_CONE * DragonPhase.ELDER_WAVES, puffs.size()])
		failed += 1
	elif wave_at.size() == 3:
		if absf(wave_at[1] - wave_at[0] - DragonPhase.ELDER_WAVE_GAP) > 0.06 or absf(wave_at[2] - wave_at[1] - DragonPhase.ELDER_WAVE_GAP) > 0.06:
			push_error("waves should be 0.30s apart at density 1, got %s" % str(wave_at))
			failed += 1
		var origin: Vector2 = puffs[DragonPhase.ELDER_CONE + 3]["position"]
		var locked := Vector2(80, 120)
		var want := (locked - origin).angle()
		var mid: Vector2 = puffs[DragonPhase.ELDER_CONE + 3]["velocity"]
		if absf(angle_difference(mid.angle(), want)) > 0.08:
			push_error("the middle wave should aim where the player was at fire time")
			failed += 1
		var early: Vector2 = puffs[3]["velocity"]
		var late: Vector2 = puffs[DragonPhase.ELDER_CONE * 2 + 3]["velocity"]
		if absf(angle_difference(early.angle(), want + DragonPhase.ELDER_SWEEP * 0.5)) > 0.12 and absf(angle_difference(early.angle(), want - DragonPhase.ELDER_SWEEP * 0.5)) > 0.12:
			push_error("the first wave should sit off the locked aim")
			failed += 1
		if absf(angle_difference(late.angle(), early.angle())) < 0.05:
			push_error("the breath should sweep between the first and last wave")
			failed += 1
	var reach := 0.0
	var ys: Array[float] = []
	var radius := 0.0
	for spec in puffs:
		var vel: Vector2 = spec["velocity"]
		var life := float(spec["life"])
		reach = maxf(reach, vel.length() * life)
		radius = float(spec["radius"])
		if absf(float(spec.get("scale", 1.0)) - DragonPhase.ELDER_PUFF_SCALE) > 0.01:
			push_error("breath puffs should draw at %.2f" % DragonPhase.ELDER_PUFF_SCALE)
			failed += 1
			break
		var pos: Vector2 = spec["position"]
		if absf(vel.x) < 1.0:
			continue
		var cross_x := 140.0
		var t := (cross_x - pos.x) / vel.x
		if t >= 0.0 and t <= life:
			ys.append(pos.y + vel.y * t)
	if reach + 0.1 < 0.70 * 480.0:
		push_error("fired puffs only reach %.1f px" % reach)
		failed += 1
	if ys.size() < DragonPhase.ELDER_CONE:
		push_error("the breath should still be in the air at x=140, samples %d" % ys.size())
		failed += 1
	else:
		var band := float(ys.max()) - float(ys.min()) + radius * 2.0
		if band > 220.0:
			push_error("the breath covers %.0f px of the 270 px field and leaves no dodge gap" % band)
			failed += 1
	var telegraph_n := 0
	var attack_n := 0
	for cue in ear.cues:
		if cue == "dragon_enemy_elder_drake_breath_telegraph":
			telegraph_n += 1
		elif cue == DragonPhase.HOOK_ELDER_ATTACK:
			attack_n += 1
	if telegraph_n != 1 or attack_n != 1:
		push_error("breath hooks should fire once each, telegraph %d attack %d" % [telegraph_n, attack_n])
		failed += 1
	ear.free()
	return failed

## The Great Dragon does not pause lair spawns. The lair wipe still does.
func _check_boss_minion_spawns(tree: SceneTree) -> int:
	var failed := 0
	var free_run := _count_lair_spawns(tree, false)
	var boss_run := _count_lair_spawns(tree, true)
	if int(free_run.get("error", 0)) != 0 or int(boss_run.get("error", 0)) != 0:
		push_error("lair spawn probe died, free %s boss %s" % [free_run, boss_run])
		return 1
	var free_n := int(free_run["spawned"])
	var boss_n := int(boss_run["spawned"])
	if free_n < 4 or boss_n < 4:
		push_error("lair spawns should keep coming, free %d boss %d" % [free_n, boss_n])
		failed += 1
	if boss_n != free_n:
		push_error("boss fight should use the full lair rate, boss %d free %d" % [boss_n, free_n])
		failed += 1
	if int(boss_run["alive"]) <= 0 or not bool(boss_run["boss"]):
		push_error("regular monsters should be on screen with the Great Dragon, alive %s boss %s" % [boss_run["alive"], boss_run["boss"]])
		failed += 1
	if absf(float(boss_run["next"]) - float(free_run["next"])) > 0.001:
		push_error("the spawn clock should match with and without the boss, %.3f vs %.3f" % [float(boss_run["next"]), float(free_run["next"])])
		failed += 1
	var wiped := _count_lair_spawns(tree, false, true)
	if int(wiped.get("spawned", -1)) != 0:
		push_error("the lair wipe should still hold spawns, got %s" % wiped.get("spawned", -1))
		failed += 1
	return failed

func _count_lair_spawns(tree: SceneTree, with_boss: bool, lair_wipe: bool = false) -> Dictionary:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(game)
	game.phase = game.PHASE_PLAY
	game.day_seed = 20261105
	game.elapsed = 40.0
	game.invuln = 100.0
	game._player.invulnerable = true
	game._player.alive = true
	game._player.position = Vector2(48, 48)
	game._tutorial_active = false
	game._director._next_time = 100000.0
	game._boss_director.dragon_at = 100000.0
	game.form_id = FormCatalog.Id.DRAGON
	game._player.adopt_dragon(1.0)
	game._begin_dragon_phase()
	var field := Vector2(480, 270)
	if with_boss:
		if not game._spawn_boss({"slug": "great_dragon", "generation": 1, "hold_x": 404.0, "origin_y": 120.0, "phase": 0.2, "wave_amp": 8.0}, field):
			tree.root.remove_child(game)
			game.free()
			return {"error": 1}
		var boss: EnemyActor = game._living_boss()
		boss.intro_left = 0.0
		if boss is BossActor:
			(boss as BossActor).state = BossActor.HOLD
	if lair_wipe and game._lair != null:
		game._lair.begin()
	var id0: int = game.next_enemy_id
	var cursor := 0.0
	while cursor < 12.0:
		cursor += 0.05
		game.elapsed = 40.0 + cursor
		var living: EnemyActor = game._living_boss()
		game._spawn_dragon_minions(living, field)
	var spawned: int = game.next_enemy_id - id0
	var alive := 0
	for enemy in game._enemies:
		if enemy is DragonEnemy and enemy.alive:
			alive += 1
	var boss_up := false
	var living_boss: EnemyActor = game._living_boss()
	boss_up = living_boss != null and living_boss.boss_slug == "great_dragon"
	var next_t := 0.0
	if game._dragon_spawns != null:
		next_t = game._dragon_spawns._next_time
	tree.root.remove_child(game)
	game.free()
	return {"spawned": spawned, "alive": alive, "boss": boss_up, "next": next_t, "error": 0}

class _CueEar extends Node:
	var cues: PackedStringArray = PackedStringArray()

	func play_sfx_hook(cue: String, _delay: float = 0.0) -> void:
		cues.append(cue)

class _UpgradeEar extends Node:
	var sound: SoundRig

	func play_sfx_hook(cue: String, delay: float = 0.0) -> void:
		if sound == null:
			return
		if delay > 0.0:
			sound.play_later(cue, delay)
			return
		sound.play_event(cue)

	func _dragon_roar() -> void:
		if sound != null:
			sound.play_event("great_dragon_phase_roar")

func _make(id: int, spawn_id: int, at: Vector2, field: Vector2) -> DragonEnemy:
	var enemy := DragonEnemy.new()
	enemy.setup(spawn_id, {
		"dragon": true,
		"dragon_id": id,
		"kind": id,
		"hp_mul": 1.0,
		"x_ratio": 0.7,
		"phase": 0.4,
		"stop_ratio": 0.3,
		"wave_amp": 10.0,
		"y_bias": 0.0,
		"spawn_at": at,
	}, field, null)
	return enemy
