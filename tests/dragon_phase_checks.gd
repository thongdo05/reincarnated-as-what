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
	if DragonPhase.scaled_hp(DragonPhase.BAT, 0.0) != 4:
		push_error("an ember bat should open at 4 HP, got %d" % DragonPhase.scaled_hp(DragonPhase.BAT, 0.0))
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
		push_error("a living Great Dragon should pause dragon-phase spawns")
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
