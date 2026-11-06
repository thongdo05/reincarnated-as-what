extends SceneTree

## Headless checks for the daily order, the shared spawn timeline, score rules,
## and relative-drag movement. Run with: godot --headless -s res://tests/smoke.gd

var _unit_failed := 0
var _done := false

func _initialize() -> void:
	_unit_failed += _check_forms()
	_unit_failed += _check_spawns()
	_unit_failed += _check_pattern_gap()
	_unit_failed += _check_score()
	_unit_failed += _check_score_epoch()
	_unit_failed += _check_drag()
	_unit_failed += _check_traits()
	_unit_failed += _check_art()
	_unit_failed += _check_idle()
	_unit_failed += _check_parallax()
	_unit_failed += _check_worlds()
	_unit_failed += _check_titles()
	_unit_failed += _check_facing()
	_unit_failed += _check_polish()
	_unit_failed += _check_shapes()
	_unit_failed += _check_loot()
	_unit_failed += _check_hud()
	_unit_failed += _check_death_sequence()
	_unit_failed += _check_share_card()
	_unit_failed += _check_icons()
	_unit_failed += _check_pressure()
	_unit_failed += _check_audio()
	_unit_failed += _check_motion()
	_unit_failed += _check_replay_rules()
	_unit_failed += _check_leaderboard()
	_unit_failed += _check_lb_parse()
	_unit_failed += _check_bosses()
	_unit_failed += load("res://tests/dragon_phase_checks.gd").new().run()
	_unit_failed += _check_ad_policy()
	_unit_failed += _check_safe_insets()
	if _unit_failed > 0:
		push_error("%d smoke checks failed" % _unit_failed)
		quit(1)

func _process(_delta: float) -> bool:
	if _done or _unit_failed > 0:
		return false
	_done = true
	# Death cards read bests and wipe a stale epoch. Put the player's file back after.
	var saved_bests := "user://best_scores.json"
	var saved_bests_body := FileAccess.get_file_as_string(saved_bests) if FileAccess.file_exists(saved_bests) else ""
	var live_failed: int = load("res://tests/dragon_phase_checks.gd").new().run_live(self)
	var failed := _unit_failed + live_failed + _check_hurt_kills() + _check_goblin_magnet() + _check_play() + _check_death_card() + _check_pause() + _check_death_play() + _check_evolve_play() + _check_audio_play() + _check_replay() + _check_roster_play() + _check_vending_gem_meter() + _check_cat_swipe() + _check_name_entry() + _check_board_rows() + _check_rank_fallback() + _check_boss_play() + _check_boss_arrives() + _check_dragon_displaces_regular() + _check_meteor_rain() + _check_meteor_shake() + _check_dragon_death()
	_restore_user_file(saved_bests, saved_bests_body)
	if failed > 0:
		push_error("%d smoke checks failed" % failed)
		quit(1)
		return true
	print("SMOKE_OK")
	quit(0)
	return true

func _check_forms() -> int:
	var failed := 0
	var first := FormCatalog.id_for_run(20261101, 0)
	if FormCatalog.id_for_run(20261101, 0) != first:
		push_error("form order is not stable for a seed")
		failed += 1
	var previous := first
	for run in range(1, 16):
		var rolled := FormCatalog.id_for_run(20261101, run)
		if rolled == previous:
			push_error("run %d repeated the form from run %d" % [run, run - 1])
			failed += 1
			break
		previous = rolled
	for seed_value in [7, 99, 20270101]:
		var prior := -1
		for run in 12:
			var rolled := FormCatalog.id_for_run(seed_value, run)
			if run > 0 and rolled == prior:
				push_error("seed %d run %d repeated the previous form" % [seed_value, run])
				failed += 1
				break
			prior = rolled
	var slime := FormCatalog.player_shots(FormCatalog.Id.SLIME, Vector2.ZERO)
	var goblin := FormCatalog.player_shots(FormCatalog.Id.GOBLIN, Vector2.ZERO)
	if slime.size() != 1 or int(slime[0]["splits"]) != 1 or float(slime[0]["gravity"]) != 0.0:
		push_error("slime shot should be one straight bullet that splits")
		failed += 1
	else:
		var slime_velocity: Vector2 = slime[0]["velocity"]
		if slime_velocity.x <= 0.0 or absf(slime_velocity.y) > 1.0:
			push_error("slime shots should fly right")
			failed += 1
		var slime_color: Color = slime[0]["color"]
		if slime_color.b <= slime_color.g:
			push_error("slime shots should be blue")
			failed += 1
	var accent := FormCatalog.title_color(FormCatalog.Id.SLIME)
	if accent.b <= accent.g:
		push_error("slime title accent should be blue")
		failed += 1
	if goblin.size() != 3:
		push_error("goblin should fire a 3-stone burst")
		failed += 1
	else:
		var spreads: Array[float] = []
		for shot in goblin:
			var stone_velocity: Vector2 = shot["velocity"]
			spreads.append(stone_velocity.y)
			if stone_velocity.x <= 0.0:
				push_error("goblin stones should fly forward")
				failed += 1
			if float(shot["gravity"]) <= 0.0:
				push_error("goblin stones should arc")
				failed += 1
		if absf(spreads[1]) > 0.01 or spreads[0] >= 0.0 or spreads[2] <= 0.0:
			push_error("goblin spread is not a slingshot fan")
			failed += 1
	var split := FormCatalog.split_shots(Vector2(0, -700), Vector2(10, 10))
	if split.size() != 2 or int(split[0]["splits"]) != 0:
		push_error("slime split should produce two child shots")
		failed += 1
	if absf(FormCatalog.SLIME_FIRE_INTERVAL - 0.16) > 0.001:
		push_error("slime fire interval should stay 0.16")
		failed += 1
	# The arc misses, so the volley is allowed to outpace the slime stream.
	# A single rock still has to be a rock, not a delete button.
	if FormCatalog.goblin_rank_f("fire_interval", 0) > 0.48:
		push_error("goblin should not fire slower than the old 0.48s rank 1")
		failed += 1
	if int(FormCatalog.goblin_f("damage")) < 1 or int(FormCatalog.goblin_f("damage")) > 3:
		push_error("goblin rock damage should stay in the tuned 1-3 range")
		failed += 1
	if goblin.is_empty() or int(goblin[0]["damage"]) != int(FormCatalog.goblin_f("damage")) or int(goblin[0]["pierce"]) != int(FormCatalog.goblin_f("pierce")):
		push_error("goblin stones should use the tuning table's damage and pierce")
		failed += 1
	if FormCatalog.weapon_line(FormCatalog.Id.SLIME, 0).find("%.2fs" % FormCatalog.SLIME_FIRE_INTERVAL) < 0:
		push_error("slime weapon line should quote the real fire interval")
		failed += 1
	var slime_trait := FormCatalog.trait_line(FormCatalog.Id.SLIME, true)
	if slime_trait.find("Split ready.") < 0 or slime_trait.find("regrows in 15s.") < 0:
		push_error("slime trait should say the split is ready and regrows in 15s")
		failed += 1
	if FormCatalog.trait_line(FormCatalog.Id.SLIME, false).find("Split used.") < 0:
		push_error("slime trait should say when the split is used")
		failed += 1
	var goblin_trait := FormCatalog.trait_line(FormCatalog.Id.GOBLIN, true)
	if goblin_trait.find("Gems nearby get pulled in.") < 0 or goblin_trait.find("Later ranks throw more rocks that hit harder.") < 0:
		push_error("goblin trait should describe the gem magnet and harder rocks")
		failed += 1
	if FormCatalog.next_rank_text(4, Difficulty.GATE_RANK5) != "FINAL FORM":
		push_error("rank 5 pause card should read FINAL FORM")
		failed += 1
	if FormCatalog.next_rank_text(2, Difficulty.GATE_RANK3).find("FINAL FORM") >= 0:
		push_error("rank 3 should still have two ranks above it")
		failed += 1
	if FormCatalog.card_heading(FormCatalog.Id.SLIME, 1) != "SLIME, Gel Knight (rank 2/5)":
		push_error("pause heading should name the form and the rank, got %s" % FormCatalog.card_heading(FormCatalog.Id.SLIME, 1))
		failed += 1
	if FormCatalog.core_radius(FormCatalog.Id.SLIME, 0, false) <= FormCatalog.core_radius(FormCatalog.Id.GOBLIN, 0, false):
		push_error("slime's core should be a bigger target than the goblin's")
		failed += 1
	var cans := FormCatalog.player_shots(FormCatalog.Id.VENDING, Vector2.ZERO, 0)
	if cans.size() != 3:
		push_error("vending machine should fire a 3-can spread, got %d" % cans.size())
		failed += 1
	else:
		var ys: Array[float] = []
		for shot in cans:
			if str(shot["sprite"]) != "vending_can.png":
				push_error("vending shots should be cans")
				failed += 1
			var vel: Vector2 = shot["velocity"]
			ys.append(vel.y)
			if vel.x <= 0.0:
				push_error("cans should fly forward")
				failed += 1
		if ys[0] >= -1.0 or absf(ys[1]) > 0.01 or ys[2] <= 1.0:
			push_error("can spread should be up, forward, and down, got %s" % str(ys))
			failed += 1
	if FormCatalog.player_shots(FormCatalog.Id.VENDING, Vector2.ZERO, 2).size() != 3:
		push_error("vending fortress should stay a 3-can spread with no extra burst")
		failed += 1
	var swipe := FormCatalog.player_shots(FormCatalog.Id.CAT, Vector2.ZERO, 0)
	if swipe.size() != 1 or str(swipe[0]["sprite"]) != "cat_swipe.png" or str(swipe[0]["style"]) != "swipe":
		push_error("cat should fire one swipe")
		failed += 1
	var orb := FormCatalog.player_shots(FormCatalog.Id.DEMON, Vector2.ZERO, 0)
	if orb.size() != 1 or str(orb[0]["sprite"]) != "demon_orb_r1.png" or float(orb[0]["homing"]) <= 0.0:
		push_error("demon lord should fire one homing orb")
		failed += 1
	if str(FormCatalog.player_shots(FormCatalog.Id.DEMON, Vector2.ZERO, 2)[0]["sprite"]) != "demon_orb_r3.png":
		push_error("true demon king should fire the rank 3 orb")
		failed += 1
	if FormCatalog.demon_damage(0, 6) <= FormCatalog.demon_damage(0, 0):
		push_error("demon damage should rise with the crowd")
		failed += 1
	if FormCatalog.weapon_line(FormCatalog.Id.VENDING, 0).find("cans") < 0 or FormCatalog.weapon_line(FormCatalog.Id.VENDING, 0).find("WINNER!") < 0:
		push_error("vending weapon line should name the cans and no burst")
		failed += 1
	if FormCatalog.VENDING_WINNER_KILLS != 10:
		push_error("vending winner fallback should be 10 kills")
		failed += 1
	var winner_kills := [10, 11, 12, 13, 14]
	var winner_damage := [2, 4, 6, 8, 10]
	for rank_i in 5:
		if FormCatalog.vending_winner_kills(rank_i) != winner_kills[rank_i]:
			push_error("vending winner meter should be 10, 11, 12, 13, 14, rank %d is %d" % [rank_i + 1, FormCatalog.vending_winner_kills(rank_i)])
			failed += 1
		if FormCatalog.vending_winner_damage(rank_i) != winner_damage[rank_i]:
			push_error("vending winner blast should be 2, 4, 6, 8, 10, rank %d is %d" % [rank_i + 1, FormCatalog.vending_winner_damage(rank_i)])
			failed += 1
		var winner_line := "WINNER! in %d" % winner_kills[rank_i]
		if FormCatalog.weapon_line(FormCatalog.Id.VENDING, rank_i).find(winner_line) < 0:
			push_error("rank %d weapon line should quote %s, got %s" % [rank_i + 1, winner_line, FormCatalog.weapon_line(FormCatalog.Id.VENDING, rank_i)])
			failed += 1
	if FormCatalog.weapon_line(FormCatalog.Id.VENDING, 0).find("Blast 2") < 0:
		push_error("rank 1 weapon line should quote a 2 blast, got %s" % FormCatalog.weapon_line(FormCatalog.Id.VENDING, 0))
		failed += 1
	if FormCatalog.weapon_line(FormCatalog.Id.VENDING, 4).find("Blast 10") < 0:
		push_error("rank 5 weapon line should quote a 10 blast, got %s" % FormCatalog.weapon_line(FormCatalog.Id.VENDING, 4))
		failed += 1
	if FormCatalog.trait_line(FormCatalog.Id.VENDING, true).find("10, then 11, 12, 13, and 14") < 0:
		push_error("vending card should list the meter at 10 through 14, got %s" % FormCatalog.trait_line(FormCatalog.Id.VENDING, true))
		failed += 1
	if FormCatalog.trait_line(FormCatalog.Id.VENDING, true).find("drop loot") < 0 or FormCatalog.trait_line(FormCatalog.Id.VENDING, true).find("blast harder") < 0:
		push_error("vending trait should say the blast scores loot and later ranks hit harder")
		failed += 1
	if FormCatalog.trait_line(FormCatalog.Id.VENDING, true).find("WINNER!") < 0:
		push_error("vending trait should name the WINNER meter")
		failed += 1
	if FormCatalog.trait_line(FormCatalog.Id.CAT, true) != "A hard flick blinks a short dash. Swipes pierce 2 and knock bullets away. Later ranks dash farther and swipe bigger. The final form crosses the screen." or FormCatalog.weapon_line(FormCatalog.Id.CAT, 0).find("Reflects") < 0:
		push_error("cat card should describe the blink dash, the piercing swipe, and the reflect")
		failed += 1
	var swipe_scale := [1.0, 1.05, 1.1, 1.15, 1.25]
	var swipe_damage := [1, 2, 3, 4, 5]
	var swipe_radius := HitLibrary.bounds_radius("cat_swipe.png", "body")
	var rank_lives := [0.58 * 1.10, 0.60 * 1.10, 0.64 * 1.10, 0.70 * 1.10]
	for rank_i in 5:
		var spec: Dictionary = FormCatalog.player_shots(FormCatalog.Id.CAT, Vector2.ZERO, rank_i)[0]
		if absf(float(spec["scale"]) - swipe_scale[rank_i]) > 0.001 or absf(FormCatalog.cat_swipe_scale(rank_i) - swipe_scale[rank_i]) > 0.001:
			push_error("cat swipe scale rank %d should be %s, got %s" % [rank_i + 1, swipe_scale[rank_i], spec["scale"]])
			failed += 1
		if absf(FormCatalog.cat_reflect_reach(swipe_scale[rank_i]) - 64.0 * swipe_scale[rank_i]) > 0.001:
			push_error("cat reflect reach should scale with the swipe")
			failed += 1
		if absf(float(spec["radius"]) - swipe_radius * swipe_scale[rank_i]) > 0.001:
			push_error("cat swipe hit radius rank %d should match scale %s, got %s" % [rank_i + 1, swipe_scale[rank_i], spec["radius"]])
			failed += 1
		if int(spec["damage"]) != swipe_damage[rank_i] or int(FormCatalog.cat_pierce(rank_i)) != 2:
			push_error("cat swipe rank %d should deal %d and pierce 2, damage %s pierce %s" % [rank_i + 1, swipe_damage[rank_i], spec["damage"], spec["pierce"]])
			failed += 1
		var weapon := FormCatalog.weapon_line(FormCatalog.Id.CAT, rank_i)
		if swipe_damage[rank_i] == 1:
			if weapon.find("Dmg") >= 0:
				push_error("rank 1 cat card should not quote a damage number, got %s" % weapon)
				failed += 1
		elif weapon.find("Dmg %d." % swipe_damage[rank_i]) < 0:
			push_error("cat card rank %d should quote dmg %d, got %s" % [rank_i + 1, swipe_damage[rank_i], weapon])
			failed += 1
		if rank_i < 4:
			if absf(FormCatalog.cat_life(rank_i) - rank_lives[rank_i]) > 0.001 or absf(float(spec["life"]) - rank_lives[rank_i]) > 0.001 or not bool(spec["expires"]) or int(spec["pierce"]) != 2:
				push_error("ranks 1-4 should keep their life and pierce 2, rank %d life %s expires %s pierce %s" % [rank_i + 1, spec["life"], spec["expires"], spec["pierce"]])
				failed += 1
		elif bool(spec["expires"]) or int(spec["pierce"]) != 2 or not bool(spec.get("exit_right", false)) or absf(float(spec["scale"]) - 1.25) > 0.001:
			push_error("rank 5 swipe should pierce 2, stay full-screen at 1.25 scale, and not expire by life, pierce %s expires %s scale %s exit %s" % [spec["pierce"], spec["expires"], spec["scale"], spec.get("exit_right", false)])
			failed += 1
	var bolt_at := Vector2(0, -18)
	if HitLibrary.overlaps(Vector2.ZERO, "cat_swipe.png", "body", bolt_at, "floating_eye_bolt.png", "threat", 1.0):
		push_error("a rank 1 swipe should miss a bolt just outside the claw")
		failed += 1
	if not HitLibrary.overlaps(Vector2.ZERO, "cat_swipe.png", "body", bolt_at, "floating_eye_bolt.png", "threat", 1.1):
		push_error("a larger swipe should hit a bolt the rank 1 claw misses")
		failed += 1
	if FormCatalog.trait_line(FormCatalog.Id.DEMON, true).find("enemies") < 0:
		push_error("demon trait should scale with enemies on screen")
		failed += 1
	if FormCatalog.card_heading(FormCatalog.Id.CAT, 0) != "CAT, Cat (ex-CEO) (rank 1/5)":
		push_error("cat pause heading should name the form and the rank, got %s" % FormCatalog.card_heading(FormCatalog.Id.CAT, 0))
		failed += 1
	var today := DailyRun.date_seed()
	if today < 20260101 or today > 21000101:
		push_error("daily seed %d is not a UTC date" % today)
		failed += 1
	return failed

func _check_spawns() -> int:
	var slow := _pull(20261101, 0.5, 8.0)
	var fast := _pull(20261101, 1.0 / 60.0, 8.0)
	if slow.size() < 4 or slow.size() != fast.size():
		push_error("spawn count changed with the timestep (%d vs %d)" % [slow.size(), fast.size()])
		return 1
	for i in slow.size():
		if int(slow[i]["kind"]) != int(fast[i]["kind"]):
			push_error("spawn kind drifted with the timestep")
			return 1
		if absf(float(slow[i]["x_ratio"]) - float(fast[i]["x_ratio"])) > 0.0001:
			push_error("spawn lane drifted with the timestep")
			return 1
	var other := _pull(20261102, 0.5, 8.0)
	var same := true
	var limit := mini(slow.size(), other.size())
	for i in limit:
		if int(slow[i]["kind"]) != int(other[i]["kind"]):
			same = false
			break
	if same:
		push_error("a different date produced the same opening spawns")
		return 1
	var early_fang := false
	for event in slow:
		if float(event["t"]) < 8.0 and int(event["kind"]) == SpawnDirector.WYVERN and float(event["t"]) < 1.2:
			early_fang = true
	if early_fang:
		push_error("a fang spawned immediately")
		return 1
	var long := SpawnDirector.new(20261101)
	long.pop_due(90.0)
	if long.max_heavies > SpawnDirector.HEAVY_CAP:
		push_error("dire wolf + wyvern exceeded the on-screen cap (%d)" % long.max_heavies)
		return 1
	if long.max_heavies < 1:
		push_error("the heavy cap ate every dire wolf and wyvern")
		return 1
	var other_day := SpawnDirector.new(20261102)
	other_day.pop_due(90.0)
	if other_day.max_heavies > SpawnDirector.HEAVY_CAP:
		push_error("heavy cap depends on the date")
		return 1
	if float(slow[0]["t"]) > 1.0:
		push_error("the first enemy should arrive within 1 s, got %s" % str(slow[0]["t"]))
		return 1
	var at_10 := Difficulty.spawn_interval(10.0)
	var opening_spawn := lerpf(Difficulty.SPAWN_INTERVAL_START, Difficulty.SPAWN_INTERVAL_AT_20, 10.0 / Difficulty.SPAWN_EASE_SECONDS)
	if absf(at_10 - opening_spawn) > 0.001:
		push_error("the first 10 s of spawns should stay on the old opening, got %s" % at_10)
		return 1
	var opening_speed := lerpf(1.0, Difficulty.SPEED_AT_20, 10.0 / Difficulty.SPEED_EASE_SECONDS)
	if absf(Difficulty.speed_scale(10.0) - opening_speed) > 0.001:
		push_error("the first 10 s of speed should stay on the old opening, got %s" % Difficulty.speed_scale(10.0))
		return 1
	if Difficulty.spawn_interval(20.0) >= at_10 or Difficulty.speed_scale(20.0) <= Difficulty.speed_scale(10.0):
		push_error("after 10 s the field should already be harder than the opening")
		return 1
	if Difficulty.spawn_interval(180.0) > Difficulty.SPAWN_EXTREME + 0.001:
		push_error("spawns should be at the 3:00 extreme, got %s" % Difficulty.spawn_interval(180.0))
		return 1
	if Difficulty.speed_scale(180.0) + 0.001 < Difficulty.SPEED_EXTREME:
		push_error("speed should be at the 3:00 extreme, got %s" % Difficulty.speed_scale(180.0))
		return 1
	var paired := false
	var seen := {}
	for event in SpawnDirector.new(20261101).pop_due(40.0):
		var key := str(event["t"])
		if seen.has(key):
			paired = true
			break
		seen[key] = true
	if not paired:
		push_error("after 15 s a beat should sometimes hold more than one threat")
		return 1
	var plain_kill: Dictionary = ScoreRules.on_kill(100, 1, 1.0, 0)
	var ranked_kill: Dictionary = ScoreRules.on_kill(100, 1, 1.0, 1)
	# Opening form: 100 * combo 2 = 200. Rank 2 throttles the raw kill and pays
	# for the chain, so a lone x1 is worth less and a chain is the way forward.
	var lone: Dictionary = ScoreRules.on_kill(100, 0, 0.0, 1)
	if int(plain_kill["points"]) != 200 or int(lone["points"]) >= 100 or int(ranked_kill["points"]) <= int(lone["points"]):
		push_error("rank 2 should pay for the chain, not a bigger flat kill (%s lone %s chain %s)" % [plain_kill["points"], lone["points"], ranked_kill["points"]])
		return 1
	if ScoreRules.graze_points(0) != Difficulty.GRAZE_BASE or ScoreRules.graze_points(1) <= ScoreRules.graze_points(0):
		push_error("a near-miss at rank 2 should be worth more than one at the start")
		return 1
	if Difficulty.spawn_interval(60.0) >= Difficulty.spawn_interval(20.0) or Difficulty.spawn_interval(180.0) >= Difficulty.spawn_interval(60.0):
		push_error("spawns should keep tightening from 20 s through 3:00")
		return 1
	if Difficulty.speed_scale(180.0) <= Difficulty.speed_scale(60.0):
		push_error("speed should still be climbing at 3:00")
		return 1
	if Difficulty.spawn_interval(180.0) - Difficulty.spawn_interval(240.0) > 0.03:
		push_error("after 3:00 the spawn rate should only creep")
		return 1
	if Difficulty.speed_scale(240.0) - Difficulty.speed_scale(180.0) > 0.12:
		push_error("after 3:00 speed should only creep")
		return 1
	if Difficulty.spawn_interval(240.0) > Difficulty.spawn_interval(180.0) + 0.001:
		push_error("the hold after 3:00 should not get easier")
		return 1
	if Difficulty.telegraph_for(90.0) < 0.15 or Difficulty.telegraph_for(400.0) < 0.15:
		push_error("aimed shots need a visible warning before they exist")
		return 1
	return 0

## The sweeping rake and the aimed fan stay wider than every form's hurtbox,
## including the late ranks, and a legal anchor can sit in that lane.
func _check_pattern_gap() -> int:
	var failed := 0
	var bolt := HitLibrary.vertical_span(Difficulty.RAKE_BOLT, "threat")
	var shot_h := 0.0
	for sprite in ["floating_eye_bolt.png", "arrow.png", "wyvern_shot.png"]:
		shot_h = maxf(shot_h, HitLibrary.vertical_extent(sprite, "threat"))
	var anchor_floor := 232.0
	for id in FormCatalog.IDS:
		for rank in 5:
			var file := str(FormCatalog.rank_spec(id, rank)["sprite"])
			var hurt := HitLibrary.vertical_extent(file, "hurt")
			var span := HitLibrary.vertical_span(file, "hurt")
			var radius := HitLibrary.bounds_radius(file, "hurt")
			var anchor_min := 10.0 + radius
			var anchor_max := anchor_floor - radius
			for elapsed in [10.0, 60.0, 120.0, 180.0, 210.0, 240.0]:
				for player_y in [50.0, 90.0, 130.0, 170.0, 200.0]:
					var plan: Dictionary = Difficulty.build_rake(elapsed, player_y, hurt)
					var lane_top := float(plan["lane_top"])
					var lane_bottom := float(plan["lane_bottom"])
					if lane_bottom - lane_top <= hurt:
						push_error("%s rake lane %.1f is not wider than the hurtbox %.1f at %.0fs" % [file, lane_bottom - lane_top, hurt, elapsed])
						failed += 1
					for y in plan["ys"]:
						var top := float(y) + bolt.x
						var bottom := float(y) + bolt.y
						if bottom > lane_top + 0.01 and top < lane_bottom - 0.01:
							push_error("%s rake bullet at %.1f cuts the lane" % [file, float(y)])
							failed += 1
							break
					var lo := maxf(anchor_min, lane_top - span.x)
					var hi := minf(anchor_max, lane_bottom - span.y)
					if hi - lo < 4.0:
						push_error("%s cannot sit in the rake lane (room %.1f)" % [file, hi - lo])
						failed += 1
	for elapsed in [10.0, 40.0, 90.0, 180.0, 240.0]:
		var spacing := Difficulty.fan_min_spacing(elapsed)
		var open := spacing - shot_h
		for id in FormCatalog.IDS:
			for rank in 5:
				var file := str(FormCatalog.rank_spec(id, rank)["sprite"])
				var hurt := HitLibrary.vertical_extent(file, "hurt")
				if open <= hurt:
					push_error("fan gap %.1f is not wider than %s (%.1f) at %.0fs" % [open, file, hurt, elapsed])
					failed += 1
	return failed

func _check_pressure() -> int:
	var failed := 0
	var bg := FieldBackground.new()
	var hazard := EnemyActor.new()
	hazard.setup(1, {
		"kind": SpawnDirector.ANVIL,
		"x_ratio": 0.4,
		"phase": 0.2,
		"stop_ratio": 0.3,
	}, Vector2(480, 270), bg)
	if absf(hazard.warn_left - Difficulty.HAZARD_WARN) > 0.001:
		push_error("a falling hazard should telegraph for 0.4 s")
		failed += 1
	var warned_y := hazard.position.y
	hazard.tick(0.2, Vector2(80, 120), 12.0, 1.0)
	if absf(hazard.position.y - warned_y) > 0.01 or hazard.warn_left <= 0.0:
		push_error("the hazard should hold still during the warning")
		failed += 1
	hazard.tick(0.25, Vector2(80, 120), 12.0, 1.0)
	if hazard.position.y <= warned_y + 1.0:
		push_error("the hazard should fall once the shadow ends")
		failed += 1
	hazard.free()
	var wolf := EnemyActor.new()
	wolf.setup(2, {
		"kind": SpawnDirector.WOLF,
		"x_ratio": 0.2,
		"phase": 0.1,
		"stop_ratio": 0.3,
	}, Vector2(480, 270), bg)
	var wolf_y := wolf.position.y
	wolf.tick(0.5, Vector2(80, wolf_y + 40.0), 20.0, 1.0)
	if absf(wolf.position.y - wolf_y) < 1.0:
		push_error("the dire wolf should chase the player's Y")
		failed += 1
	wolf.free()
	var eye := EnemyActor.new()
	eye.setup(3, {
		"kind": SpawnDirector.EYE,
		"x_ratio": 0.5,
		"phase": 0.0,
		"stop_ratio": 0.3,
		"wave_amp": 6.0,
	}, Vector2(480, 270), bg)
	eye.position = Vector2(300, 80)
	eye.shot_cooldown = 0.0
	var bolts: Array[Dictionary] = []
	for _step in 14:
		bolts = eye.tick(0.05, Vector2(40, 140), 20.0, 1.0)
		if not bolts.is_empty():
			break
	if bolts.is_empty() or float(bolts[0]["velocity"].y) <= 0.0:
		push_error("the floating eye should lead toward the player, got %s" % str(bolts))
		failed += 1
	eye.free()
	bg.free()
	return failed

func _pull(seed_value: int, step: float, until: float) -> Array[Dictionary]:
	var director := SpawnDirector.new(seed_value)
	var events: Array[Dictionary] = []
	var t := 0.0
	while t < until:
		t += step
		for event in director.pop_due(t):
			events.append(event)
	return events

func _check_art() -> int:
	var failed := 0
	if ArtLibrary.file_count() != 203:
		push_error("art manifest should have 203 entries, found %d" % ArtLibrary.file_count())
		failed += 1
	var text := FileAccess.get_file_as_string("res://art/manifest.json")
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("art manifest did not parse")
		return failed + 1
	for item in parsed:
		var entry: Dictionary = item
		var file_name := str(entry["file"])
		if not FileAccess.file_exists("res://art/" + file_name):
			push_error("missing art file %s" % file_name)
			failed += 1
		var anchor: Array = entry["anchor"]
		var got := ArtLibrary.anchor(file_name)
		if absf(got.x - float(anchor[0])) > 0.01 or absf(got.y - float(anchor[1])) > 0.01:
			push_error("anchor mismatch for %s" % file_name)
			failed += 1
		var category := str(entry.get("category", ""))
		if category == "player_form" or category == "player_form_split" or category == "fx_form_overlay":
			var tex := ArtLibrary.texture(file_name)
			var size: Array = entry["size"]
			if tex == null or tex.get_width() != int(size[0]) or tex.get_height() != int(size[1]):
				push_error("%s did not import at its manifest size" % file_name)
				failed += 1
	for parked in ["vending_machine_r1.png", "vending_machine_r3.png", "cat_r2.png", "demon_lord_r1.png", "demon_lord_r3.png"]:
		if not ArtLibrary.has_file(parked):
			push_error("parked form art missing: %s" % parked)
			failed += 1
	if FormCatalog.IDS.size() != 5:
		push_error("roster should be slime, goblin, vending, cat, and demon lord, got %d" % FormCatalog.IDS.size())
		failed += 1
	var slime_r1 := str(FormCatalog.rank_spec(FormCatalog.Id.SLIME, 0)["sprite"])
	var slime_r3 := str(FormCatalog.rank_spec(FormCatalog.Id.SLIME, 2)["sprite"])
	var small_r2 := str(FormCatalog.rank_spec(FormCatalog.Id.SLIME, 1)["sprite_small"])
	if slime_r1 != "slime_r1.png" or slime_r3 != "slime_r3.png" or small_r2 != "slime_small_r2.png":
		push_error("slime ranks should swap r1/r2/r3 sprites, including the split")
		failed += 1
	var stones := [
		str(FormCatalog.player_shots(FormCatalog.Id.GOBLIN, Vector2.ZERO, 0)[0]["sprite"]),
		str(FormCatalog.player_shots(FormCatalog.Id.GOBLIN, Vector2.ZERO, 1)[0]["sprite"]),
		str(FormCatalog.player_shots(FormCatalog.Id.GOBLIN, Vector2.ZERO, 2)[0]["sprite"]),
	]
	if stones != ["slingshot_stone.png", "slingshot_stone_l2.png", "slingshot_stone_l3.png"]:
		push_error("goblin stones should step l1/l2/l3 with rank, got %s" % str(stones))
		failed += 1
	if str(FormCatalog.player_shots(FormCatalog.Id.SLIME, Vector2.ZERO, 2)[0]["sprite"]) != "slime_shot.png":
		push_error("slime should fire slime_shot")
		failed += 1
	for id in [FormCatalog.Id.SLIME, FormCatalog.Id.GOBLIN]:
		var prev := 0.0
		for rank in 3:
			var radius := FormCatalog.core_radius(id, rank, false)
			var box := ArtLibrary.art_bbox(str(FormCatalog.rank_spec(id, rank)["sprite"]))
			if radius * 2.0 > minf(box.x, box.y):
				push_error("the core should stay inside the sprite for %s rank %d" % [FormCatalog.display_name(id), rank])
				failed += 1
			if rank > 0 and radius <= prev:
				push_error("hitbox should grow with rank")
				failed += 1
			if rank > 0 and radius > prev * 1.35:
				push_error("hitbox grew more than a modest step")
				failed += 1
			prev = radius
			if id == FormCatalog.Id.SLIME:
				var small := FormCatalog.core_radius(id, rank, true)
				if small >= radius:
					push_error("split slime hitbox should be smaller than the current rank")
					failed += 1
	if FormCatalog.core_radius(FormCatalog.Id.SLIME, 0, false) <= FormCatalog.core_radius(FormCatalog.Id.GOBLIN, 0, false):
		push_error("slime's hitbox should stay larger than the goblin's")
		failed += 1
	var kept := ArtLibrary.radius_for("vending_machine_r1.png", 0.62)
	var from_old := 0.62 * (23.0 + 40.0) * 0.25
	if absf(kept - from_old) > 0.01:
		push_error("a radius taken from art_bbox should stay on the pre-ring box")
		failed += 1
	var wolf := SpawnDirector.body_radius(SpawnDirector.WOLF)
	var eye := SpawnDirector.body_radius(SpawnDirector.EYE)
	if wolf <= eye:
		push_error("the dire wolf hitbox should be larger than the floating eye")
		failed += 1
	return failed

func _check_idle() -> int:
	var failed := 0
	var text := FileAccess.get_file_as_string("res://art/manifest.json")
	var parsed: Variant = JSON.parse_string(text)
	var static_by_file := {}
	var idle_count := 0
	for item in parsed:
		var entry: Dictionary = item
		var file_name := str(entry["file"])
		if file_name.ends_with("_idle.png"):
			idle_count += 1
			var frames := int(entry["frames"])
			var fps := float(entry["fps"])
			var expect_frames := 8 if file_name == "floating_eye_idle.png" else 4
			if frames != expect_frames or absf(fps - 6.0) > 0.01 or not bool(entry["loop"]):
				push_error("idle sheet %s should be a %d-frame loop at 6 fps" % [file_name, expect_frames])
				failed += 1
			var base := str(entry.get("base_sprite", "")).get_file()
			if not ArtLibrary.has_file(base):
				base = file_name.trim_suffix("_idle.png") + ".png"
			var static_entry: Dictionary = ArtLibrary.entry(base)
			if static_entry.is_empty():
				push_error("idle sheet %s has no static sprite" % file_name)
				failed += 1
				continue
			var idle_anchor: Array = entry["anchor"]
			var static_anchor: Array = static_entry["anchor"]
			if int(idle_anchor[0]) != int(static_anchor[0]) or int(idle_anchor[1]) != int(static_anchor[1]):
				push_error("idle anchor drifted from %s" % base)
				failed += 1
			var frame_size: Array = entry["frame_size"]
			var static_size: Array = static_entry["size"]
			if int(frame_size[0]) != int(static_size[0]) or int(frame_size[1]) != int(static_size[1]):
				push_error("idle frame size drifted from %s" % base)
				failed += 1
			if ArtLibrary.loop_file(base) != file_name:
				push_error("loop file for %s was %s" % [base, ArtLibrary.loop_file(base)])
				failed += 1
		else:
			static_by_file[file_name] = entry
	if idle_count != 22:
		push_error("expected 22 idle sheets, found %d" % idle_count)
		failed += 1
	for file_name in static_by_file:
		var entry: Dictionary = static_by_file[file_name]
		var category := str(entry.get("category", ""))
		var wants_idle := (category == "player_form" or category == "player_form_split" or category == "enemy") and bool(entry.get("idle", true))
		var idle := ArtLibrary.loop_file(file_name)
		if wants_idle and idle == file_name:
			push_error("%s should play an idle sheet" % file_name)
			failed += 1
		if not wants_idle and idle != file_name:
			push_error("%s should stay a static sprite" % file_name)
			failed += 1
	if ArtLibrary.loop_file("anvil.png") != "anvil.png" or ArtLibrary.loop_file("piano.png") != "piano.png":
		push_error("hazards should not loop")
		failed += 1
	var ship := PlayerShip.new()
	ship.setup(FormCatalog.Id.SLIME, Vector2(40, 40))
	if ArtLibrary.loop_file(ship.sprite_name()) != "slime_r1_idle.png":
		push_error("rank 0 slime should idle on slime_r1")
		failed += 1
	ship.set_rank(2)
	if ArtLibrary.loop_file(ship.sprite_name()) != "slime_r3_idle.png":
		push_error("a rank-up should swap to that rank's idle sheet")
		failed += 1
	var full := FormCatalog.hit_radius_for(FormCatalog.Id.SLIME, 2, false)
	if absf(ship.radius - full) > 0.05:
		push_error("ranking up should keep the static-sprite hitbox")
		failed += 1
	if not ship.absorb_lethal_hit() or ArtLibrary.loop_file(ship.sprite_name()) != "slime_small_r3_idle.png":
		push_error("a split slime should play the small idle sheet of that rank")
		failed += 1
	if ship.radius >= full:
		push_error("the split hitbox should stay inside the static art box")
		failed += 1
	ship.free()
	for kind in [SpawnDirector.EYE, SpawnDirector.WOLF, SpawnDirector.ARCHER, SpawnDirector.WYVERN]:
		var base := SpawnDirector.sprite_for(kind)
		if ArtLibrary.loop_file(base) != base.trim_suffix(".png") + "_idle.png":
			push_error("%s should loop its idle sheet" % base)
			failed += 1
		var body := SpawnDirector.body_radius(kind)
		var box := ArtLibrary.art_bbox(base)
		if absf(body - HitLibrary.bounds_radius(base, "body")) > 0.05:
			push_error("enemy hitbox should come from the static sprite shape")
			failed += 1
		if body > maxf(box.x, box.y) * 1.25:
			push_error("enemy hitbox should stay on the static sprite, not an idle strip")
			failed += 1
	return failed

func _check_parallax() -> int:
	var failed := 0
	var bg := FieldBackground.new()
	bg.tick(1.0, Vector2(480, 270))
	if absf(bg.scroll_near - 28.0) > 0.02:
		push_error("near layer should still scroll at 28 px/s, got %s" % str(bg.scroll_near))
		failed += 1
	if absf(bg.scroll_far - 14.0) > 0.02:
		push_error("far layer should scroll at 0.3 of the base, got %s" % str(bg.scroll_far))
		failed += 1
	if absf(bg.scroll_clouds - 7.0) > 0.02:
		push_error("clouds should scroll between sky and far, got %s" % str(bg.scroll_clouds))
		failed += 1
	var sky := 28.0 * FieldBackground.SKY_FACTOR / FieldBackground.NEAR_FACTOR
	if absf(bg.scroll_sky - sky) > 0.02:
		push_error("sky factor should be 0.05, got %s" % str(bg.scroll_sky))
		failed += 1
	if bg.scroll_sky >= bg.scroll_clouds or bg.scroll_clouds >= bg.scroll_far or bg.scroll_far >= bg.scroll_near:
		push_error("parallax should speed up from sky to clouds to far to near")
		failed += 1
	if not ArtLibrary.has_file("bg_clouds.png"):
		push_error("cloud layer art missing")
		failed += 1
	bg.free()
	return failed

func _check_worlds() -> int:
	var failed := 0
	var ids := WorldCatalog.ids()
	if ids.size() != 7 or ids[0] != WorldCatalog.SKY_CASTLE:
		push_error("sky castle should be world 1 of 7, got %s" % str(ids))
		failed += 1
	if WorldCatalog.flash_name("neon_tokyo") != "NEON TOKYO" or WorldCatalog.flash_name("sunken_ruins") != "SUNKEN RUINS":
		push_error("world flash should be short capitals, got %s / %s" % [WorldCatalog.flash_name("neon_tokyo"), WorldCatalog.flash_name("sunken_ruins")])
		failed += 1
	if absf(FieldBackground.GROUND_FEET - 234.0) > 0.01 or FieldBackground.ISLANDS[0] != Vector2(63, 43) or FieldBackground.ISLANDS[1] != Vector2(227, 59):
		push_error("decks or the ground line moved")
		failed += 1
	for id in ids:
		var choices := WorldCatalog.candidates(id)
		if choices.has(id) or choices.size() != ids.size() - 1:
			push_error("the next world should skip %s" % id)
			failed += 1
		var set := WorldCatalog.layers(id)
		if set.size() != 4 or set[0] == null or set[2] == null or set[3] == null:
			push_error("%s is missing a background layer" % id)
			failed += 1
			continue
		var far := set[2].get_image()
		var near := set[3].get_image()
		if far == null or near == null:
			push_error("%s layer did not decode" % id)
			failed += 1
			continue
		for island in FieldBackground.ISLANDS:
			var grass := far.get_pixel(int(island.x), int(island.y))
			if grass.a < 0.5 or grass.g <= grass.r or grass.g <= grass.b:
				push_error("%s deck feet missed the grass at %s (%s)" % [id, str(island), str(grass)])
				failed += 1
		var solid := 0
		for sample_x in range(0, 480, 8):
			if near.get_pixel(sample_x, int(FieldBackground.GROUND_FEET)).a > 0.8:
				solid += 1
		if solid < 50:
			push_error("%s ground feet should sit in the near layer" % id)
			failed += 1
		var speeds := WorldCatalog.factors(id)
		if speeds.size() != 4 or absf(speeds[0] - 0.05) > 0.0001 or absf(speeds[1] - 0.15) > 0.0001 or absf(speeds[2] - 0.3) > 0.0001 or absf(speeds[3] - 0.6) > 0.0001:
			push_error("%s scroll factors drifted from the manifest: %s" % [id, str(speeds)])
			failed += 1
		var bg := FieldBackground.new()
		bg.apply_world(id)
		bg.tick(1.0, Vector2(480, 270))
		if absf(bg.scroll_near - 28.0) > 0.02 or absf(bg.scroll_far - 14.0) > 0.02:
			push_error("%s parallax drifted (near %s far %s)" % [id, bg.scroll_near, bg.scroll_far])
			failed += 1
		bg.free()
		var own := "res://audio/music/world_%s.ogg" % id
		var music := WorldCatalog.music_path(id)
		if id == WorldCatalog.SKY_CASTLE:
			if music != WorldCatalog.FALLBACK_MUSIC:
				push_error("sky castle should keep the current music loop")
				failed += 1
		elif ResourceLoader.exists(own):
			if music != own:
				push_error("%s should play %s" % [id, own])
				failed += 1
		elif music != WorldCatalog.FALLBACK_MUSIC:
			push_error("a missing %s track should fall back to the current loop" % id)
			failed += 1
	WorldCatalog.last_id = ""
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var previous := ""
	for _i in 80:
		var rolled := WorldCatalog.roll(rng)
		if rolled == previous:
			push_error("rolled %s twice in a row" % rolled)
			failed += 1
			break
		previous = rolled
	if SoundRig.CROSSFADE_SECONDS < 0.3 or SoundRig.CROSSFADE_SECONDS > 0.5:
		push_error("world music crossfade should be about 0.3 to 0.5 s")
		failed += 1
	var fade_start := SoundRig.crossfade_db(0.0)
	var fade_mid := SoundRig.crossfade_db(0.5)
	var fade_end := SoundRig.crossfade_db(1.0)
	if absf(fade_start.x) > 0.05 or fade_start.y > -40.0 or absf(fade_end.y) > 0.05 or fade_end.x > -40.0 or absf(fade_mid.x - fade_mid.y) > 0.05:
		push_error("crossfade should hand the old track to the new one, got %s %s %s" % [fade_start, fade_mid, fade_end])
		failed += 1
	var rig := SoundRig.new()
	rig.setup()
	rig.play_world_music(WorldCatalog.SKY_CASTLE)
	if rig.music_path() != WorldCatalog.FALLBACK_MUSIC:
		push_error("the opening track should be the current loop")
		failed += 1
	var music_player := rig.player_for("gameplay_music")
	var opening := rig.music_stream() as AudioStreamOggVorbis
	if music_player == null or opening == null or not opening.loop or absf(opening.loop_offset) > 0.001 or absf(music_player.volume_db) > 0.01:
		push_error("world music should keep the loop, the offset, and the bus trim")
		failed += 1
	if WorldCatalog.music_path("missing_world") != WorldCatalog.FALLBACK_MUSIC:
		push_error("an unknown world should fall back to the current loop")
		failed += 1
	var music_text := FileAccess.get_file_as_string("res://audio/music/manifest.json")
	var music_parsed: Variant = JSON.parse_string(music_text)
	if typeof(music_parsed) != TYPE_DICTIONARY:
		push_error("world music manifest did not parse")
		failed += 1
	else:
		var music_body: Dictionary = music_parsed
		var listed: Array = music_body.get("files", [])
		if listed.size() != 6:
			push_error("world music manifest should list 6 tracks")
			failed += 1
		for entry in listed:
			var spec: Dictionary = entry
			var file_name := str(spec.get("file", ""))
			var track_path := "res://audio/music/" + file_name
			if not ResourceLoader.exists(track_path):
				push_error("world track missing from the import: %s" % track_path)
				failed += 1
				continue
			var track := load(track_path) as AudioStreamOggVorbis
			if track == null or not track.loop or absf(track.loop_offset) > 0.001:
				push_error("%s should loop from the start" % file_name)
				failed += 1
			elif absf(track.get_length() - float(spec.get("duration", -1))) > 0.05:
				push_error("%s length should match its manifest" % file_name)
				failed += 1
			elif int(spec.get("loop_start", -1)) != 0:
				push_error("%s loop tag should start at 0" % file_name)
				failed += 1
			elif absf(float(spec.get("loop_length", 0)) / 48000.0 - track.get_length()) > 0.05:
				push_error("%s loop length should cover the whole file" % file_name)
				failed += 1
	if WorldCatalog.music_path("neon_tokyo") == WorldCatalog.FALLBACK_MUSIC:
		rig.play_world_music("neon_tokyo")
		if rig.is_crossfading():
			push_error("a missing world track should keep the loop that is already playing")
			failed += 1
	elif opening != null and music_player != null:
		rig.play_world_music("neon_tokyo")
		var incoming := rig.music_stream() as AudioStreamOggVorbis
		var leaving := rig.fade_player()
		if not rig.is_crossfading() or rig.music_path() != "res://audio/music/world_neon_tokyo.ogg":
			push_error("neon tokyo should crossfade onto its own loop")
			failed += 1
		elif incoming == null or not incoming.loop or absf(incoming.loop_offset) > 0.001 or leaving == null or absf(leaving.volume_db) > 0.05 or music_player.volume_db > -40.0:
			push_error("crossfade should start with the sky castle loop up and the new loop down")
			failed += 1
		else:
			rig.tick_crossfade_for_test(SoundRig.CROSSFADE_SECONDS)
			if rig.is_crossfading() or absf(music_player.volume_db) > 0.05 or rig.music_stream() != incoming or leaving.playing:
				push_error("crossfade should end on the new world track at full volume")
				failed += 1
	var named := 0
	for child in rig.get_children():
		if str(child.name) == "gameplay_music":
			named += 1
	if named != 1:
		push_error("a run should still have one gameplay_music player")
		failed += 1
	rig.free()
	var wolf := EnemyActor.new()
	var wolf_bg := FieldBackground.new()
	wolf.setup(9, {
		"kind": SpawnDirector.WOLF,
		"x_ratio": 0.5,
		"phase": 0.2,
		"stop_ratio": 0.4,
	}, Vector2(480, 270), wolf_bg)
	var anchor := ArtLibrary.anchor("dire_wolf.png")
	var wolf_size: Array = ArtLibrary.entry("dire_wolf.png")["size"]
	var feet_offset := float(wolf_size[1]) - 1.0 - anchor.y
	var lowest_feet := (270.0 - 78.0) + feet_offset
	if absf(anchor.x - 28.0) > 0.01 or absf(anchor.y - 20.0) > 0.01:
		push_error("dire wolf anchor should stay the centre (28, 20)")
		failed += 1
	if absf(wolf.position.y - FieldBackground.GROUND_FEET) < 1.0 or lowest_feet >= FieldBackground.GROUND_FEET - 0.5:
		push_error("dire wolf is planted on the ground (pos %.1f, lowest feet %.1f)" % [wolf.position.y, lowest_feet])
		failed += 1
	wolf.free()
	wolf_bg.free()
	return failed

func _check_titles() -> int:
	var failed := 0
	for id in [FormCatalog.Id.SLIME, FormCatalog.Id.GOBLIN]:
		var file_name := FormCatalog.title_card(id)
		if not ArtLibrary.has_file(file_name):
			push_error("missing title card %s" % file_name)
			failed += 1
			continue
		var size: Array = ArtLibrary.entry(file_name)["size"]
		if int(size[0]) != 480 or int(size[1]) != 270:
			push_error("title card %s should fill 480x270" % file_name)
			failed += 1
	if FormCatalog.title_card(FormCatalog.Id.SLIME) == FormCatalog.title_card(FormCatalog.Id.GOBLIN):
		push_error("slime and goblin should reveal different cards")
		failed += 1
	return failed

func _check_facing() -> int:
	var failed := 0
	var text := FileAccess.get_file_as_string("res://art/manifest.json")
	var parsed: Variant = JSON.parse_string(text)
	for item in parsed:
		var entry: Dictionary = item
		var category := str(entry.get("category", ""))
		var facing := str(entry.get("facing", ""))
		var file_name := str(entry["file"])
		if category == "enemy" and facing != "left":
			push_error("%s should face left and stay unflipped" % file_name)
			failed += 1
		if (category == "player_form" or category == "player_form_split") and facing != "right":
			push_error("%s should face right" % file_name)
			failed += 1
	for shot_name in ["arrow.png", "floating_eye_bolt.png", "wyvern_shot.png"]:
		if str(ArtLibrary.entry(shot_name).get("facing", "")) != "left":
			push_error("%s should face left" % shot_name)
			failed += 1
	var anchor := ArtLibrary.anchor("skeleton_archer.png")
	var size: Array = ArtLibrary.entry("skeleton_archer.png")["size"]
	if absf(anchor.y - float(size[1])) > 0.5:
		push_error("the archer anchor should stay on its feet")
		failed += 1
	var far := ArtLibrary.texture("bg_far.png").get_image()
	if far == null:
		push_error("far layer did not decode")
		return failed + 1
	for island in FieldBackground.ISLANDS:
		var x := int(island.x)
		var y := int(island.y)
		if y < 40:
			push_error("island %s clips a 44px archer" % str(island))
			failed += 1
		var grass := far.get_pixel(x, y)
		if grass.a < 0.5 or grass.g <= grass.r or grass.g <= grass.b:
			push_error("archer feet missed the grass at %s (%s)" % [str(island), str(grass)])
			failed += 1
		var left := x
		while left > 0 and far.get_pixel(left - 1, y).a > 0.4:
			left -= 1
		var right := x
		while right < far.get_width() - 1 and far.get_pixel(right + 1, y).a > 0.4:
			right += 1
		if right - left + 1 < 28:
			push_error("island %s is narrower than the archer" % str(island))
			failed += 1
	var near := ArtLibrary.texture("bg_near.png").get_image()
	var solid := 0
	for sample_x in range(0, 480, 8):
		if near.get_pixel(sample_x, int(FieldBackground.GROUND_FEET)).a > 0.8:
			solid += 1
	if solid < 50:
		push_error("ground feet should sit in the near-layer grass")
		failed += 1
	return failed

func _check_polish() -> int:
	var failed := 0
	var sheets: Array = [
		["demon_orb_r1.png", 48, 12, 12, 12],
		["demon_orb_r2.png", 56, 14, 14, 14],
		["demon_orb_r3.png", 72, 18, 18, 18],
	]
	for spec in sheets:
		var file_name := str(spec[0])
		var data := ArtLibrary.entry(file_name)
		if int(data.get("frames", 0)) != 4 or absf(float(data.get("fps", 0)) - 6.0) > 0.01 or not bool(data.get("loop", false)):
			push_error("%s should be a 4-frame loop at 6 fps" % file_name)
			failed += 1
		var size: Array = data["size"]
		var frame: Array = data["frame_size"]
		if int(size[0]) != int(spec[1]) or int(size[1]) != int(spec[2]) or int(frame[0]) != int(spec[3]) or int(frame[1]) != int(spec[4]):
			push_error("%s sheet size drifted" % file_name)
			failed += 1
		var box := ArtLibrary.art_bbox(file_name)
		if absf(box.x - float(spec[3])) > 0.01 or absf(box.y - float(spec[4])) > 0.01:
			push_error("%s hit box used the strip width (%s)" % [file_name, box])
			failed += 1
		var first := ArtLibrary.frame_source(file_name, 0.0)
		var second := ArtLibrary.frame_source(file_name, 1.0 / 6.0)
		var wrapped := ArtLibrary.frame_source(file_name, 4.0 / 6.0)
		if first.position != Vector2.ZERO or absf(first.size.x - float(spec[3])) > 0.01 or absf(first.size.y - float(spec[4])) > 0.01:
			push_error("%s frame 0 should be one cell, got %s" % [file_name, first])
			failed += 1
		if absf(second.position.x - float(spec[3])) > 0.01 or absf(second.size.x - float(spec[3])) > 0.01:
			push_error("%s frame 1 was not the next cell (%s)" % [file_name, second])
			failed += 1
		if wrapped.position != Vector2.ZERO:
			push_error("%s did not loop after 4 frames (%s)" % [file_name, wrapped])
			failed += 1
		var tex := ArtLibrary.texture(file_name)
		if tex == null or tex.get_width() != int(spec[1]) or tex.get_height() != int(spec[2]):
			push_error("%s texture is not the pulse strip" % file_name)
			failed += 1
		var shot := Shot.new()
		shot.sprite_name = file_name
		shot.age = 1.0 / 6.0
		var drawn := shot.drawn_frame()
		if absf(drawn.position.x - float(spec[3])) > 0.01 or absf(drawn.size.x - float(spec[3])) > 0.01:
			push_error("%s shot drew the strip instead of one pulsing cell (%s)" % [file_name, drawn])
			failed += 1
		shot.free()
	var eye := ArtLibrary.frame_source("floating_eye.png", 0.0)
	var blink := ArtLibrary.frame_source("floating_eye.png", 6.0 / 6.0)
	var closed := ArtLibrary.frame_source("floating_eye.png", 7.0 / 6.0)
	var after := ArtLibrary.frame_source("floating_eye.png", 8.0 / 6.0)
	if absf(eye.size.x - 20.0) > 0.01 or eye.position != Vector2.ZERO:
		push_error("eye frame 0 should be 20px, got %s" % eye)
		failed += 1
	if absf(blink.position.x - 120.0) > 0.01 or absf(closed.position.x - 140.0) > 0.01:
		push_error("eye blink should be frames 7 and 8, got %s and %s" % [blink, closed])
		failed += 1
	if after.position != Vector2.ZERO:
		push_error("eye idle should loop after 8 frames, got %s" % after)
		failed += 1
	var eye_tex := ArtLibrary.texture("floating_eye_idle.png")
	if eye_tex == null or eye_tex.get_width() != 160 or eye_tex.get_height() != 20:
		push_error("floating eye idle strip should be 160x20")
		failed += 1
	if ArtLibrary.anchor("slime_shot.png") != Vector2(4, 2) or ArtLibrary.art_bbox("slime_shot.png") != Vector2(8, 5):
		push_error("slime shot should be 8x5 anchored at (4, 2)")
		failed += 1
	if ArtLibrary.anchor("slingshot_stone.png") != Vector2(3, 3) or ArtLibrary.art_bbox("slingshot_stone.png") != Vector2(6, 6):
		push_error("slingshot stone should be 6x6 anchored at (3, 3)")
		failed += 1
	if not HitLibrary.contains_local("slime_shot.png", "body", Vector2(2, 0)) or not HitLibrary.contains_local("slingshot_stone.png", "body", Vector2(1, 1)):
		push_error("shot shapes should cover the redrawn sprites")
		failed += 1
	var slime_radius := HitLibrary.bounds_radius("slime_shot.png", "body")
	var stone_radius := HitLibrary.bounds_radius("slingshot_stone.png", "body")
	var slime_shot: Dictionary = FormCatalog.player_shots(FormCatalog.Id.SLIME, Vector2.ZERO, 0)[0]
	var stone_shot: Dictionary = FormCatalog.player_shots(FormCatalog.Id.GOBLIN, Vector2.ZERO, 0)[0]
	if absf(float(slime_shot["radius"]) - slime_radius) > 0.05:
		push_error("slime shot radius was not retuned")
		failed += 1
	if absf(float(stone_shot["radius"]) - stone_radius) > 0.05:
		push_error("slingshot radius was not retuned")
		failed += 1
	var old_slime := FormCatalog.SHOT_PCT * (6.0 + 4.0) * 0.25
	var old_stone := FormCatalog.SHOT_PCT * (5.0 + 5.0) * 0.25
	if slime_radius <= old_slime or stone_radius <= old_stone:
		push_error("bigger sprites should have bigger hitboxes")
		failed += 1
	var slime_tex := ArtLibrary.texture("slime_shot.png")
	var stone_tex := ArtLibrary.texture("slingshot_stone.png")
	if slime_tex == null or slime_tex.get_width() != 8 or slime_tex.get_height() != 5:
		push_error("slime shot texture should be 8x5")
		failed += 1
	if stone_tex == null or stone_tex.get_width() != 6 or stone_tex.get_height() != 6:
		push_error("slingshot stone texture should be 6x6")
		failed += 1
	return failed

func _check_shapes() -> int:
	var failed := 0
	var needed := {
		"slime_r1.png": "hurt",
		"slime_r2.png": "hurt",
		"slime_r3.png": "hurt",
		"slime_small_r1.png": "hurt",
		"goblin_r1.png": "hurt",
		"goblin_r2.png": "hurt",
		"goblin_r3.png": "hurt",
		"dire_wolf.png": "body",
		"floating_eye.png": "body",
		"skeleton_archer.png": "body",
		"wyvern.png": "body",
		"anvil.png": "body",
		"piano.png": "body",
		"slime_shot.png": "body",
		"slingshot_stone.png": "body",
		"arrow.png": "threat",
		"floating_eye_bolt.png": "threat",
		"wyvern_shot.png": "threat",
	}
	for file_name in needed:
		var role := str(needed[file_name])
		if not HitLibrary.has_role(file_name, role):
			push_error("%s is missing a %s shape" % [file_name, role])
			failed += 1
	# The old circle sat on the anchor, so the wolf's nose and the archer's chest missed.
	if not HitLibrary.contains_local("dire_wolf.png", "body", Vector2(-20, 0)):
		push_error("a shot on the wolf's nose should hit the body")
		failed += 1
	if not HitLibrary.contains_local("dire_wolf.png", "body", Vector2(18, 0)):
		push_error("a shot on the wolf's rear should hit the body")
		failed += 1
	if HitLibrary.contains_local("dire_wolf.png", "body", Vector2(0, -26)):
		push_error("empty space above the wolf should not be a hit")
		failed += 1
	if not HitLibrary.contains_local("skeleton_archer.png", "body", Vector2(0, -30)):
		push_error("a shot on the archer's chest should hit")
		failed += 1
	if not HitLibrary.contains_local("skeleton_archer.png", "body", Vector2(0, -40)):
		push_error("a shot on the archer's skull should hit")
		failed += 1
	if HitLibrary.contains_local("skeleton_archer.png", "body", Vector2(18, 0)):
		push_error("the archer hitbox should not be a circle around the feet")
		failed += 1
	var wing := Vector2(-20, -16)
	if not HitLibrary.contains_local("wyvern.png", "body", wing):
		push_error("a shot on the wyvern's wing should hit the body")
		failed += 1
	if HitLibrary.contains_local("wyvern.png", "threat", wing):
		push_error("a wing tip should not kill the player")
		failed += 1
	if not HitLibrary.contains_local("floating_eye.png", "body", Vector2(7, 0)):
		push_error("the outer eye should catch a shot")
		failed += 1
	if HitLibrary.contains_local("floating_eye.png", "threat", Vector2(7, 0)):
		push_error("the outer eye should not kill on a brush")
		failed += 1
	if not HitLibrary.contains_local("piano.png", "body", Vector2(26, -1)):
		push_error("the piano cabinet should be a solid body")
		failed += 1
	if HitLibrary.contains_local("piano.png", "threat", Vector2(26, -1)):
		push_error("the piano's outer edge should forgive a brush")
		failed += 1
	if not HitLibrary.contains_local("slime_r1.png", "hurt", Vector2.ZERO):
		push_error("the slime body should include the anchor")
		failed += 1
	if HitLibrary.contains_local("slime_r1.png", "hurt", Vector2(10, 10)):
		push_error("empty space beside the slime drips should not be a hurt")
		failed += 1
	if not HitLibrary.contains_local("goblin_r1.png", "hurt", Vector2(0, -14)):
		push_error("the goblin crown should be part of the hurtbox")
		failed += 1
	var wolf := Vector2(120, 80)
	if not HitLibrary.overlaps(wolf + Vector2(-20, 0), "slime_shot.png", "body", wolf, "dire_wolf.png", "body"):
		push_error("a slime shot on the wolf's nose should connect")
		failed += 1
	if HitLibrary.overlaps(wolf + Vector2(0, -40), "slime_shot.png", "body", wolf, "dire_wolf.png", "body"):
		push_error("a slime shot over the wolf should miss")
		failed += 1
	var eye := Vector2(40, 40)
	var clear := HitLibrary.gap(eye + Vector2(36, 0), "slime_r1.png", "hurt", eye, "floating_eye.png", "threat")
	if clear <= 0.0:
		push_error("a slime that is clear of the eye should live (gap %s)" % clear)
		failed += 1
	var fatal := HitLibrary.gap(eye + Vector2(6, 0), "slime_r1.png", "hurt", eye, "floating_eye.png", "threat")
	if fatal > 0.0:
		push_error("a slime body inside the eye should be fatal (gap %s)" % fatal)
		failed += 1
	var prev_slime := 0.0
	var prev_goblin := 0.0
	for rank in 5:
		var slime_file := str(FormCatalog.rank_spec(FormCatalog.Id.SLIME, rank)["sprite"])
		var goblin_file := str(FormCatalog.rank_spec(FormCatalog.Id.GOBLIN, rank)["sprite"])
		var small_file := str(FormCatalog.rank_spec(FormCatalog.Id.SLIME, rank)["sprite_small"])
		var slime_r := HitLibrary.max_part_radius(slime_file, "hurt")
		var goblin_r := HitLibrary.max_part_radius(goblin_file, "hurt")
		var small_r := HitLibrary.max_part_radius(small_file, "hurt")
		if slime_r <= goblin_r:
			push_error("the slime body should stay a bigger target than the goblin")
			failed += 1
		if rank > 0 and rank < 3 and (slime_r <= prev_slime or goblin_r <= prev_goblin):
			push_error("hurt shapes should grow with rank")
			failed += 1
		if rank > 0 and rank < 3 and (slime_r > prev_slime * 1.35 or goblin_r > prev_goblin * 1.35):
			push_error("hurt shapes grew more than a modest step")
			failed += 1
		if rank == 4 and (absf(slime_r - prev_slime) > 0.75 or absf(goblin_r - prev_goblin) > 0.75):
			push_error("rank 5 should keep the rank 4 body silhouette")
			failed += 1
		if small_r >= slime_r:
			push_error("the split slime hurt shape should be smaller")
			failed += 1
		failed += _check_body_cover(slime_file)
		failed += _check_body_cover(small_file)
		failed += _check_body_cover(goblin_file)
		prev_slime = slime_r
		prev_goblin = goblin_r
	for id in [FormCatalog.Id.VENDING, FormCatalog.Id.CAT, FormCatalog.Id.DEMON]:
		for rank in 5:
			failed += _check_body_cover(str(FormCatalog.rank_spec(id, rank)["sprite"]))
	if not HitLibrary.has_role("cat_swipe.png", "body"):
		push_error("the cat swipe needs a body shape so it can meet bullets")
		failed += 1
	var demon_pad := FormCatalog.hit_radius_for(FormCatalog.Id.DEMON, 0, false)
	var slime_pad := FormCatalog.hit_radius_for(FormCatalog.Id.SLIME, 0, false)
	if demon_pad <= slime_pad:
		push_error("demon lord's full-body pad should be larger than the slime")
		failed += 1
	if absf(FormCatalog.play_scale(FormCatalog.Id.DEMON) - 0.75) > 0.001 or absf(FormCatalog.play_scale(FormCatalog.Id.CAT) - 1.0) > 0.001:
		push_error("demon lord stays at 0.75 and the cat stays full size")
		failed += 1
	if absf(FormCatalog.play_scale(FormCatalog.Id.VENDING) - 0.7) > 0.001:
		push_error("vending should be drawn at 0.7")
		failed += 1
	var vend_file := str(FormCatalog.rank_spec(FormCatalog.Id.VENDING, 0)["sprite"])
	var vend_src := HitLibrary.bounds_radius(vend_file, "hurt")
	if absf(FormCatalog.hit_radius_for(FormCatalog.Id.VENDING, 0, false) - vend_src * 0.7) > 0.05:
		push_error("vending hurtbox should shrink with the 0.7 draw scale")
		failed += 1
	var demon_src := HitLibrary.bounds_radius("demon_lord_r3.png", "hurt")
	var demon_play := FormCatalog.hit_radius_for(FormCatalog.Id.DEMON, 2, false)
	if absf(demon_play - demon_src * FormCatalog.DEMON_PLAY_SCALE) > 0.05:
		push_error("the demon play pad should be the fitted hurtbox at the drawn size")
		failed += 1
	return failed

## Opaque body pixels, skipping the ink outline. Local points are pixel centers.
func _body_pixels(file_name: String) -> Array[Vector2]:
	var image := ArtLibrary.texture(file_name).get_image()
	var anchor := ArtLibrary.anchor(file_name)
	var pts: Array[Vector2] = []
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			if color.r8 == 20 and color.g8 == 18 and color.b8 == 31:
				continue
			pts.append(Vector2(x, y) - anchor + Vector2(0.5, 0.5))
	return pts

func _check_body_cover(file_name: String) -> int:
	var pts := _body_pixels(file_name)
	if pts.is_empty():
		push_error("%s has no opaque body" % file_name)
		return 1
	var head := pts[0]
	var foot := pts[0]
	var outside := 0
	for point in pts:
		if point.y < head.y or (is_equal_approx(point.y, head.y) and absf(point.x) < absf(head.x)):
			head = point
		if point.y > foot.y or (is_equal_approx(point.y, foot.y) and absf(point.x) < absf(foot.x)):
			foot = point
		var gap := HitLibrary.local_gap(file_name, "hurt", point)
		if gap > 1.02:
			outside += 1
	if outside > 0:
		push_error("%s leaves %d body pixels more than 1px outside the hurt shape" % [file_name, outside])
		return 1
	for point in pts:
		if not is_equal_approx(point.y, head.y) and not is_equal_approx(point.y, foot.y):
			continue
		if HitLibrary.local_gap(file_name, "hurt", point) > 0.0:
			push_error("%s head/foot pixel %s should be inside the hurt shape" % [file_name, point])
			return 1
	var sky := HitLibrary.local_gap(file_name, "hurt", head + Vector2(0, -4))
	if sky <= 0.0:
		push_error("%s hurt shape should not cover empty space above the head" % file_name)
		return 1
	# The movement pad is one circle. Collision is the parts, so some point
	# inside that circle must miss.
	var pad := HitLibrary.bounds_radius(file_name, "hurt")
	var missed := false
	for i in 32:
		var probe := Vector2.from_angle(float(i) / 32.0 * TAU) * pad * 0.9
		if not HitLibrary.contains_local(file_name, "hurt", probe):
			missed = true
			break
	if not missed:
		push_error("%s hurt shape collapsed to its bounds radius" % file_name)
		return 1
	var player := Vector2(90, 120)
	if not HitLibrary.overlaps(player, file_name, "hurt", player + head, "floating_eye_bolt.png", "threat"):
		push_error("a bolt on the %s head pixel should overlap" % file_name)
		return 1
	if not HitLibrary.overlaps(player, file_name, "hurt", player + foot, "floating_eye_bolt.png", "threat"):
		push_error("a bolt on the %s foot pixel should overlap" % file_name)
		return 1
	return 0

func _check_hurt_kills() -> int:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var failed := 0
	failed += _expect_bolt_kill(game, FormCatalog.Id.GOBLIN, false, true)
	failed += _expect_bolt_kill(game, FormCatalog.Id.GOBLIN, false, false)
	# A full slime spends its split on the head, then the small body's foot kills.
	game.phase = game.PHASE_PLAY
	game.form_id = FormCatalog.Id.SLIME
	game._player.form_id = FormCatalog.Id.SLIME
	game._player.small = false
	game._player.rank_index = 0
	game._player.alive = true
	game._player.position = Vector2(100, 130)
	game._player.aim = game._player.position
	game._player._apply_radius()
	game.invuln = 0.0
	game._player.invulnerable = false
	var head := _extremity(_body_pixels("slime_r1.png"), true)
	_fire_bolt(game, head)
	if game._player.small != true or int(game.phase) != game.PHASE_PLAY:
		push_error("a bolt on the full slime's head should connect and split")
		failed += 1
	# The split's iframes are the trait, not the hurt shape. The next bolt is the kill.
	game.invuln = 0.0
	game._player.invulnerable = false
	var foot := _extremity(_body_pixels(game._player.sprite_name()), false)
	_fire_bolt(game, foot)
	if int(game.phase) != game.PHASE_DEAD:
		push_error("a bolt on the small slime's foot should kill")
		failed += 1
	root.remove_child(game)
	game.free()
	return failed

func _expect_bolt_kill(game, form: int, small: bool, head: bool) -> int:
	game.phase = game.PHASE_PLAY
	game.form_id = form
	game._player.form_id = form
	game._player.small = small
	game._player.rank_index = 0
	game._player.alive = true
	game._player.position = Vector2(100, 130)
	game._player.aim = game._player.position
	game._player._apply_radius()
	game.invuln = 0.0
	game._player.invulnerable = false
	game.killer_name = ""
	var file := str(game._player.sprite_name())
	var pad := float(game._player.radius)
	var ghost := Vector2(pad * 0.92, 0.0)
	var found_miss := false
	for i in 48:
		var probe := Vector2.from_angle(float(i) / 48.0 * TAU) * pad * 0.92
		var separation := HitLibrary.gap(game._player.position, file, "hurt", game._player.position + probe, "floating_eye_bolt.png", "threat")
		if separation > 0.4:
			ghost = probe
			found_miss = true
			break
	if not found_miss:
		push_error("%s has no miss inside the movement radius" % file)
		return 1
	_fire_bolt(game, ghost)
	if int(game.phase) != game.PHASE_PLAY:
		push_error("a bolt inside the movement radius but off the body should miss %s" % file)
		return 1
	var point := _extremity(_body_pixels(file), head)
	_fire_bolt(game, point)
	if int(game.phase) != game.PHASE_DEAD:
		push_error("a bolt on %s %s should kill" % [file, "head" if head else "foot"])
		return 1
	return 0

func _extremity(pts: Array[Vector2], head: bool) -> Vector2:
	var best := pts[0]
	for point in pts:
		if head:
			if point.y < best.y or (is_equal_approx(point.y, best.y) and absf(point.x) < absf(best.x)):
				best = point
		elif point.y > best.y or (is_equal_approx(point.y, best.y) and absf(point.x) < absf(best.x)):
			best = point
	return best

func _fire_bolt(game, local: Vector2) -> void:
	for shot in game._shots:
		if is_instance_valid(shot):
			shot.queue_free()
	game._shots.clear()
	game._spawn_shot({
		"position": game._player.position + local,
		"velocity": Vector2(-30, 0),
		"damage": 1,
		"radius": 2.0,
		"sprite": "floating_eye_bolt.png",
		"killer_name": "Floating Eye",
		"style": "blob",
		"color": Color.WHITE,
	}, false)
	game._collide()

func _check_score() -> int:
	var failed := 0
	var first: Dictionary = ScoreRules.on_kill(100, 0, 0.0)
	var second: Dictionary = ScoreRules.on_kill(100, int(first["combo"]), float(first["combo_left"]))
	if int(first["points"]) != 100 or int(second["points"]) != 200:
		push_error("combo should scale kill score and start at x1")
		failed += 1
	if ScoreRules.format_score(4210) != "4,210":
		push_error("score formatting broke")
		failed += 1
	var line := ScoreRules.share_line("SLIME", "Ooze Titan", 102.0, "Dire Wolf", 4210)
	if line != "Reborn as SLIME, reached OOZE TITAN. Lasted 1:42. Died to a Dire Wolf. Score 4,210.":
		push_error("share line was '%s'" % line)
		failed += 1
	return failed

func _check_traits() -> int:
	var failed := 0
	var bounds := Rect2(0, 0, 780, 360)
	var slime := PlayerShip.new()
	slime.setup(FormCatalog.Id.SLIME, Vector2(200, 160))
	if slime.small or not slime.absorb_lethal_hit():
		push_error("a full slime should split instead of dying")
		failed += 1
	var full_radius := FormCatalog.hit_radius(FormCatalog.Id.SLIME)
	if not slime.small or slime.radius >= full_radius:
		push_error("the split slime should be smaller")
		failed += 1
	if slime.absorb_lethal_hit():
		push_error("a small slime should not split again")
		failed += 1
	for _i in 960:
		slime.tick(1.0 / 60.0, bounds)
	if slime.small:
		push_error("the slime should regrow after 15 seconds")
		failed += 1
	if absf(slime.radius - full_radius) > 0.1:
		push_error("the regrown slime should have a full hitbox")
		failed += 1
	slime.free()
	var goblin := PlayerShip.new()
	goblin.setup(FormCatalog.Id.GOBLIN, Vector2(200, 160))
	if goblin.absorb_lethal_hit():
		push_error("the goblin has no split shield")
		failed += 1
	goblin.free()
	if FormCatalog.player_shots(FormCatalog.Id.GOBLIN, Vector2.ZERO, 0).size() != 3:
		push_error("base slingshot should fire 3 stones")
		failed += 1
	if FormCatalog.player_shots(FormCatalog.Id.GOBLIN, Vector2.ZERO, 1).size() != 4:
		push_error("goblin chief should add a stone")
		failed += 1
	if FormCatalog.player_shots(FormCatalog.Id.GOBLIN, Vector2.ZERO, 2).size() != 5:
		push_error("goblin king should fire 5 stones")
		failed += 1
	if FormCatalog.player_shots(FormCatalog.Id.SLIME, Vector2.ZERO, 2).size() != 3:
		push_error("ooze titan should fire three streams")
		failed += 1
	var base_interval := float(FormCatalog.rank_spec(FormCatalog.Id.GOBLIN, 0)["fire_interval"])
	var king_interval := float(FormCatalog.rank_spec(FormCatalog.Id.GOBLIN, 2)["fire_interval"])
	if king_interval >= base_interval:
		push_error("higher ranks should fire faster")
		failed += 1
	var gates := FormCatalog.rank_gates()
	if FormCatalog.rank_for_points(0) != 0 or FormCatalog.rank_for_points(gates[0] - 1) != 0:
		push_error("evolution should stay at rank 0 under the first gate")
		failed += 1
	if FormCatalog.rank_for_points(gates[0]) != 1:
		push_error("the first gate should reach rank 1")
		failed += 1
	if FormCatalog.rank_for_points(gates[1]) != 2:
		push_error("the second gate should reach rank 2")
		failed += 1
	var ranked := PlayerShip.new()
	ranked.setup(FormCatalog.Id.SLIME, Vector2(200, 160))
	ranked.set_rank(2)
	if ranked.rank_index != 2 or ranked.small:
		push_error("set_rank should keep a full-size slime")
		failed += 1
	var titan_radius := ranked.radius
	if not ranked.absorb_lethal_hit() or not ranked.small:
		push_error("a ranked slime should still split")
		failed += 1
	if ranked.radius >= titan_radius:
		push_error("the split should shrink the current rank")
		failed += 1
	for _j in 960:
		ranked.tick(1.0 / 60.0, bounds)
	if ranked.small or ranked.rank_index != 2:
		push_error("regrowth should restore the current rank, not rank 0")
		failed += 1
	if ranked.radius + 0.1 < titan_radius:
		push_error("regrowth should restore the ranked hitbox")
		failed += 1
	ranked.free()
	var fresh: Dictionary = {}
	var after_slime: Dictionary = BestScores.apply(fresh, "SLIME", 100)
	var after_low: Dictionary = BestScores.apply(after_slime, "SLIME", 40)
	var after_goblin: Dictionary = BestScores.apply(after_low, "GOBLIN", 250)
	if int(after_low.get("SLIME", 0)) != 100 or int(after_goblin.get("GOBLIN", 0)) != 250:
		push_error("per-form best should keep the higher score")
		failed += 1
	if int(after_goblin.get("overall", 0)) != 250 or int(after_low.get("overall", 0)) != 100:
		push_error("overall best should be the best run of any form")
		failed += 1
	var stamped: Dictionary = BestScores.apply({"epoch": 1, "overall": 5, "SLIME": 5}, "epoch", 40)
	if stamped.has("epoch") or int(stamped.get("overall", 0)) != 40:
		push_error("epoch must not be stored as a form best")
		failed += 1
	return failed

## Old saves lose their scores once. The current epoch stays. Name and device id stay.
func _check_score_epoch() -> int:
	var failed := 0
	var best_path := BestScores.SAVE_PATH
	var daily_path := DailyRun.SAVE_PATH
	var profile_path := Leaderboard.PROFILE_PATH
	var audio_path := AudioCues.SETTINGS_PATH
	var seen_path := Replay.SEEN_PATH
	var best_backup := FileAccess.get_file_as_string(best_path) if FileAccess.file_exists(best_path) else ""
	var daily_backup := FileAccess.get_file_as_string(daily_path) if FileAccess.file_exists(daily_path) else ""
	var profile_backup := FileAccess.get_file_as_string(profile_path) if FileAccess.file_exists(profile_path) else ""
	var audio_backup := FileAccess.get_file_as_string(audio_path) if FileAccess.file_exists(audio_path) else ""
	var seen_backup := FileAccess.get_file_as_string(seen_path) if FileAccess.file_exists(seen_path) else ""
	var audio_body := "[audio]\nenabled=false\n"
	var seen_body := "{\"seen\":true}"
	_restore_user_file(audio_path, audio_body)
	_restore_user_file(seen_path, seen_body)
	_remove_user_file(best_path)
	var missing := BestScores.read()
	if int(missing.get("overall", -1)) != 0 or missing.has("epoch") or FileAccess.file_exists(best_path):
		push_error("a missing best file should read as an empty score and stay missing")
		failed += 1
	_restore_user_file(best_path, JSON.stringify({"overall": 500, "SLIME": 500, "GOBLIN": 20}))
	var wiped := BestScores.read()
	if int(wiped.get("overall", -1)) != 0 or wiped.has("SLIME") or wiped.has("GOBLIN") or wiped.has("epoch"):
		push_error("a best file with no epoch should be wiped, got %s" % wiped)
		failed += 1
	var wiped_file := _user_json(best_path)
	if int(wiped_file.get("overall", -1)) != 0 or wiped_file.has("SLIME") or int(wiped_file.get("epoch", 0)) != BestScores.SCORE_EPOCH:
		push_error("the wiped best file should only keep an empty overall at this epoch, got %s" % wiped_file)
		failed += 1
	if int(BestScores.read().get("overall", -1)) != 0:
		push_error("reading twice should not bring the old best back")
		failed += 1
	var revived := BestScores.record("SLIME", 10)
	if int(revived.get("overall", 0)) != 10 or int(revived.get("form", 0)) != 10 or revived.has("epoch"):
		push_error("a new score must not revive the wiped best or return the epoch, got %s" % revived)
		failed += 1
	var revived_file := _user_json(best_path)
	if int(revived_file.get("SLIME", 0)) != 10 or int(revived_file.get("overall", 0)) != 10 or revived_file.has("GOBLIN") or int(revived_file.get("epoch", 0)) != BestScores.SCORE_EPOCH:
		push_error("record() should write this epoch and only the new score, got %s" % revived_file)
		failed += 1
	_restore_user_file(best_path, JSON.stringify({"epoch": 0, "overall": 400, "GOBLIN": 400}))
	var old_epoch := BestScores.read()
	if int(old_epoch.get("overall", -1)) != 0 or old_epoch.has("GOBLIN") or old_epoch.has("epoch"):
		push_error("an older epoch should be wiped, got %s" % old_epoch)
		failed += 1
	var current_body := JSON.stringify({"epoch": BestScores.SCORE_EPOCH, "overall": 80, "SLIME": 80, "GOBLIN": 20})
	_restore_user_file(best_path, current_body)
	var before_keep := FileAccess.get_file_as_string(best_path)
	var kept := BestScores.read()
	var after_keep := FileAccess.get_file_as_string(best_path)
	if before_keep != after_keep:
		push_error("a current-epoch best file should be left as it is")
		failed += 1
	if int(kept.get("overall", 0)) != 80 or int(kept.get("SLIME", 0)) != 80 or int(kept.get("GOBLIN", 0)) != 20 or kept.has("epoch"):
		push_error("a current epoch should keep form scores and hide epoch, got %s" % kept)
		failed += 1
	var best_line := "%s BEST %s\nDAILY BEST %s" % [
		"SLIME",
		ScoreRules.format_score(int(kept.get("SLIME", 0))),
		ScoreRules.format_score(int(kept.get("overall", 0))),
	]
	if best_line != "SLIME BEST 80\nDAILY BEST 80":
		push_error("the death card should show the form best, got %s" % best_line)
		failed += 1
	var lowered := BestScores.record("SLIME", 10)
	if int(lowered.get("form", 0)) != 80 or int(lowered.get("overall", 0)) != 80 or lowered.has("epoch"):
		push_error("a lower score should not replace the current best, got %s" % lowered)
		failed += 1
	var kept_file := _user_json(best_path)
	if int(kept_file.get("SLIME", 0)) != 80 or int(kept_file.get("GOBLIN", 0)) != 20 or int(kept_file.get("epoch", 0)) != BestScores.SCORE_EPOCH:
		push_error("record() should keep the current best and write the epoch, got %s" % kept_file)
		failed += 1
	var today := str(DailyRun.date_seed())
	var plain := '{"date":"%s","next_run":2}' % today
	_restore_user_file(daily_path, plain)
	var daily_before := FileAccess.get_file_as_string(daily_path)
	if DailyRun.peek_run_index() != 2 or FileAccess.get_file_as_string(daily_path) != daily_before:
		push_error("the daily index should stay put when the file has no score")
		failed += 1
	var dirty := '{"date":"%s","next_run":4,"epoch":0,"best":99999,"overall":88888}' % today
	_restore_user_file(daily_path, dirty)
	if DailyRun.peek_run_index() != 4:
		push_error("wiping a cached daily score should keep the run index")
		failed += 1
	var daily_file := _user_json(daily_path)
	if int(daily_file.get("next_run", -1)) != 4 or daily_file.has("best") or daily_file.has("overall") or int(daily_file.get("epoch", 0)) != BestScores.SCORE_EPOCH:
		push_error("the daily file should drop cached scores and keep the index, got %s" % daily_file)
		failed += 1
	_restore_user_file(profile_path, JSON.stringify({
		"device_id": "device-keep",
		"name": "Gel Knight",
		"posted": true,
		"epoch": 0,
		"bests": {"slime": 99999},
		"ranks": {"all": 3, "daily": 1},
		"score": 99999,
	}))
	var client := Leaderboard.new()
	var got_name := client.player_name()
	var got_id := client.device_id()
	var posted := client.has_posted()
	client.free()
	if got_name != "Gel Knight" or got_id != "device-keep" or not posted:
		push_error("name and device id should survive the score wipe, got %s / %s posted %s" % [got_name, got_id, posted])
		failed += 1
	var profile_raw := FileAccess.get_file_as_string(profile_path)
	var profile_file := _user_json(profile_path)
	if str(profile_file.get("name", "")) != "Gel Knight" or str(profile_file.get("device_id", "")) != "device-keep":
		push_error("the profile file lost the name or device id, got %s" % profile_file)
		failed += 1
	if profile_file.has("bests") or profile_file.has("ranks") or profile_file.has("score") or profile_raw.find("99999") >= 0:
		push_error("cached bests and ranks should be gone so they cannot be posted, got %s" % profile_raw)
		failed += 1
	if int(profile_file.get("epoch", 0)) != BestScores.SCORE_EPOCH:
		push_error("the profile should stamp the current score epoch, got %s" % profile_file)
		failed += 1
	var card := ShareCard.resolve({
		"form": "slime",
		"rank_reached": 1,
		"score": 12,
		"epoch": 99,
		"time": "0:01",
		"killer": "dire_wolf",
	})
	if str(card.get("score", "")) == "99" or str(card.get("form_name", "")) == "epoch":
		push_error("the share card should not treat epoch as a score, got %s" % card)
		failed += 1
	if FileAccess.get_file_as_string(audio_path) != audio_body or FileAccess.get_file_as_string(seen_path) != seen_body:
		push_error("the score wipe should leave audio settings and the tutorial flag alone")
		failed += 1
	_restore_user_file(best_path, best_backup)
	_restore_user_file(daily_path, daily_backup)
	_restore_user_file(profile_path, profile_backup)
	_restore_user_file(audio_path, audio_backup)
	_restore_user_file(seen_path, seen_backup)
	return failed

func _check_drag() -> int:
	var bounds := Rect2(0, 0, 360, 780)
	var drag := Vector2(150, -80)
	var slime_fast := _sample(FormCatalog.Id.SLIME, drag, bounds, 3)
	var goblin_fast := _sample(FormCatalog.Id.GOBLIN, drag, bounds, 3)
	var slime_end := _sample(FormCatalog.Id.SLIME, drag, bounds, 20)
	var goblin_end := _sample(FormCatalog.Id.GOBLIN, drag, bounds, 20)
	var failed := 0
	var start := Vector2(120, 500)
	var aim := start + drag
	if slime_fast.distance_to(aim) > 2.0 or goblin_fast.distance_to(aim) > 2.0:
		push_error("both forms should reach the aim within 3 frames (slime %s goblin %s aim %s)" % [slime_fast, goblin_fast, aim])
		failed += 1
	if slime_end.distance_to(aim) > 0.5 or goblin_end.distance_to(aim) > 0.5:
		push_error("the body should stay on the aim with no slide (slime %s goblin %s)" % [slime_end, goblin_end])
		failed += 1
	var vending_fast := _sample(FormCatalog.Id.VENDING, drag, bounds, 3)
	var vending_end := _sample(FormCatalog.Id.VENDING, drag, bounds, 12)
	if vending_fast.distance_to(aim) < 4.0:
		push_error("vending should still be trailing at 3 frames, got %s aim %s" % [vending_fast, aim])
		failed += 1
	if vending_end.distance_to(aim) > 2.0:
		push_error("vending should finish a flick within 12 frames, got %s" % vending_end)
		failed += 1
	var vending_nudge := PlayerShip.new()
	vending_nudge.setup(FormCatalog.Id.VENDING, start)
	vending_nudge.nudge(Vector2(0, -36), bounds)
	if vending_nudge.position.distance_to(start) < 10.0:
		push_error("vending should answer a flick on the first frame, moved %s" % vending_nudge.position)
		failed += 1
	vending_nudge.free()
	# A drag of +150 must not be treated as a finger coordinate of (150, -80).
	if slime_end.x < start.x + 100.0:
		push_error("relative drag did not carry the ship by the drag delta")
		failed += 1
	var wall := PlayerShip.new()
	wall.setup(FormCatalog.Id.GOBLIN, Vector2(40, 40))
	var box := Rect2(0, 0, 220, 180)
	wall.nudge(Vector2(-800, -800), box)
	wall.tick(1.0 / 60.0, box)
	if wall.position.x < wall.radius - 0.2 or wall.position.y < wall.radius - 0.2:
		push_error("the body should stay inside the padded field (%s pad %s)" % [wall.position, wall.radius])
		failed += 1
	if wall.aim.x < wall.radius - 0.2 or wall.aim.y < wall.radius - 0.2:
		push_error("the aim point should stay inside the padded field")
		failed += 1
	wall.free()
	return failed

func _check_play() -> int:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	if game._player == null or game._title_card == null or game._hud_view == null:
		push_error("game did not finish setting up")
		game.free()
		return 1
	var failed := 0
	if game._hud_view.show_coins != (int(game.form_id) == FormCatalog.Id.GOBLIN):
		push_error("only the goblin run should show the coin counter")
		failed += 1
	if not game.wants_rotate(Vector2(390, 844)) or game.wants_rotate(Vector2(844, 390)):
		push_error("portrait should ask for a rotate, landscape should play")
		game.free()
		return 1
	var step := 1.0 / 60.0
	var card_file := FormCatalog.title_card(int(game.form_id))
	if game._title_card.texture != ArtLibrary.texture(card_file):
		push_error("title card should match the rolled form")
		failed += 1
	if game._title_card.scale.x > 0.9:
		push_error("title card should start smaller than the screen")
		failed += 1
	for _i in 80:
		game._process(step)
	if int(game.phase) != 0:
		push_error("title card should last about 1.5s when it is not skipped")
		failed += 1
	if game._title_card.scale.x < 0.99:
		push_error("title card pop-in should finish")
		failed += 1
	for _i in 16:
		game._process(step)
	if int(game.phase) != 1:
		push_error("title card should hand off to play")
		failed += 1
	for _i in 64:
		game._process(step)
	if int(game.phase) != 1:
		push_error("reveal did not hand off to play (phase %s)" % str(game.phase))
		failed += 1
	var before: Vector2 = game._player.position
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = before + Vector2(40, 80)
	game._unhandled_input(touch)
	var snap := InputEventScreenDrag.new()
	snap.index = 0
	snap.relative = Vector2(24, -10)
	snap.position = touch.position + snap.relative
	var at_input: Vector2 = game._player.position
	game._input(snap)
	if game._player.position.distance_to(at_input) < 10.0:
		push_error("a drag in _input should move the body before _process (moved %s)" % game._player.position.distance_to(at_input))
		failed += 1
	for i in 50:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.relative = Vector2(2.4, -1.2)
		drag.position = before + Vector2(40 + float(i) * 2.4, 80 - float(i) * 1.2)
		game._input(drag)
		game._process(step)
	var after: Vector2 = game._player.position
	if after.x < before.x + 40.0 or after.y > before.y - 15.0:
		push_error("screen drag did not move the ship (before %s after %s)" % [before, after])
		failed += 1
	for _i in 700:
		if int(game.phase) == 2:
			break
		game._process(step)
	if float(game.elapsed) < 1.2 or (float(game.score) <= 0.0 and int(game.phase) == 1):
		push_error("play slice produced no score (score %s elapsed %s phase %s)" % [str(game.score), str(game.elapsed), str(game.phase)])
		failed += 1
	print("PLAY_SLICE phase=%s score=%s elapsed=%.2f form=%s" % [
		str(game.phase), str(game.score), float(game.elapsed), FormCatalog.display_name(int(game.form_id))
	])
	root.remove_child(game)
	game.free()
	var skipped := packed.instantiate()
	skipped.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(skipped)
	for _i in 24:
		skipped._process(step)
	var skip_touch := InputEventScreenTouch.new()
	skip_touch.index = 0
	skip_touch.pressed = true
	skip_touch.position = Vector2(240, 135)
	skipped._unhandled_input(skip_touch)
	if int(skipped.phase) != 1 or absf(float(skipped.invuln) - 1.5) > 0.05:
		push_error("a tap should skip the title card into 1.5s of invulnerability")
		failed += 1
	root.remove_child(skipped)
	skipped.free()
	return failed

func _check_death_card() -> int:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var failed := 0
	if game._restart_button == null:
		push_error("death card has no Reincarnate button")
		game.free()
		return 1
	var lines := [
		ScoreRules.share_line("VENDING MACHINE", "Vending Fortress", 5999.0, "Skeleton Archer", 999999),
		ScoreRules.share_line("DEMON LORD", "True Demon King", 5999.0, "falling piano", 999999),
		ScoreRules.share_line("SLIME", "Slime", 12.0, "Floating Eye", 100),
	]
	var bests := [
		"Best as VENDING MACHINE: 999,999 / Best overall: 999,999",
		"Best as DEMON LORD: 999,999 / Best overall: 999,999",
		"Best as SLIME: 100 / Best overall: 100",
	]
	for i in lines.size():
		game._share_label.text = lines[i]
		game._best_label.text = bests[i]
		game._seed_label.text = "UTC seed 20261101 - run 99"
		game._layout_death_card()
		var field: Vector2 = game._viewport_size()
		var button: Button = game._restart_button
		var rect := Rect2(button.position, button.size)
		if button.mouse_filter != Control.MOUSE_FILTER_STOP:
			push_error("Reincarnate should receive taps")
			failed += 1
		if rect.size.y < 48.0 or rect.size.x < 200.0:
			push_error("Reincarnate is too small to tap (%s)" % rect)
			failed += 1
		if rect.position.x < -0.5 or rect.position.y < -0.5 or rect.end.x > field.x + 0.5 or rect.end.y > field.y + 0.5:
			push_error("Reincarnate left the field for '%s' rect %s field %s" % [lines[i], rect, field])
			failed += 1
		if field.x >= 480.0 and field.y >= 270.0:
			if rect.end.x > 480.5 or rect.end.y > 270.5:
				push_error("Reincarnate left the 480x270 field (%s)" % rect)
				failed += 1
		for child in game._game_over.get_children():
			if child is Button and str((child as Button).text) == "Text":
				push_error("the death card should not have a Text button")
				failed += 1
		if game._beat_button == null or not game._beat_button.visible:
			push_error("the death card should offer CHALLENGE A FRIEND")
			failed += 1
		else:
			var challenge: Button = game._beat_button
			var crect := Rect2(challenge.position, challenge.size)
			if challenge.text != "CHALLENGE A FRIEND":
				push_error("challenge button should say CHALLENGE A FRIEND, got %s" % challenge.text)
				failed += 1
			if crect.size.y < 44.0 or crect.size.y + 0.5 >= rect.size.y:
				push_error("challenge button should be tappable and shorter than Reincarnate (%s vs %s)" % [crect.size, rect.size])
				failed += 1
			if crect.size.x + 0.5 >= rect.size.x:
				push_error("challenge button should stay narrower than Reincarnate (%s vs %s)" % [crect.size, rect.size])
				failed += 1
			if crect.intersects(rect):
				push_error("challenge button overlaps Reincarnate")
				failed += 1
			if int(challenge.get_theme_font_size("font_size")) < 18:
				push_error("challenge label should be readable, font %s" % challenge.get_theme_font_size("font_size"))
				failed += 1
		if game._board_button == null or not game._board_button.visible or game._board_button.text != "LEADERBOARD":
			push_error("the death card should offer LEADERBOARD")
			failed += 1
		else:
			var board: Button = game._board_button
			var brect := Rect2(board.position, board.size)
			if brect.size.y < 44.0:
				push_error("leaderboard button should be tappable (%s)" % brect)
				failed += 1
			if brect.size.x + 0.5 >= rect.size.x:
				push_error("leaderboard button should be narrower than Reincarnate")
				failed += 1
			var challenge_rect := Rect2(game._beat_button.position, game._beat_button.size)
			if brect.intersects(rect) or (game._beat_button.visible and brect.intersects(challenge_rect)):
				push_error("leaderboard button overlaps retry or challenge")
				failed += 1
			if brect.position.x < -0.5 or brect.end.x > field.x + 0.5 or brect.end.y > field.y + 0.5:
				push_error("leaderboard button left the field (%s)" % brect)
				failed += 1
		if game._rank_label != null:
			game._rank_label.visible = true
			game._rank_label.text = "#12 today - #40 all-time"
			game._layout_death_card()
		for label in [game._share_label, game._best_label, game._seed_label, game._death_kicker, game._rank_label]:
			var label_rect := Rect2(label.position, label.size)
			if label_rect.end.y > rect.position.y + 0.5:
				push_error("death copy overlaps Reincarnate for '%s'" % lines[i])
				failed += 1
				break
			if game._beat_button != null and game._beat_button.visible:
				var challenge_rect := Rect2(game._beat_button.position, game._beat_button.size)
				if label_rect.intersects(challenge_rect):
					push_error("death copy overlaps the challenge button for '%s'" % lines[i])
					failed += 1
					break
			if game._board_button != null and game._board_button.visible:
				var board_rect := Rect2(game._board_button.position, game._board_button.size)
				if label_rect.intersects(board_rect):
					push_error("death copy overlaps the leaderboard button for '%s'" % lines[i])
					failed += 1
					break
			if label_rect.position.y < -0.5 or label_rect.end.y > field.y + 0.5:
				push_error("death copy left the field for '%s'" % lines[i])
				failed += 1
				break
	root.remove_child(game)
	game.free()
	return failed

func _check_lb_parse() -> int:
	var failed := 0
	var bad := '{"ok":false,"error":"bad_score"}'.to_utf8_buffer()
	var kept := Leaderboard.parse_response(HTTPRequest.RESULT_SUCCESS, 200, bad)
	if str(kept.get("error", "")) != "bad_score" or Leaderboard.is_network_error(kept):
		push_error("a 200 bad_score must stay bad_score, got %s" % kept)
		failed += 1
	var form_err := Leaderboard.parse_response(HTTPRequest.RESULT_SUCCESS, 200, '{"ok":false,"error":"bad_form"}'.to_utf8_buffer())
	if str(form_err.get("error", "")) != "bad_form":
		push_error("bad_form was collapsed, got %s" % form_err)
		failed += 1
	var http_bad := Leaderboard.parse_response(HTTPRequest.RESULT_SUCCESS, 400, bad)
	if str(http_bad.get("error", "")) != "bad_score" or Leaderboard.is_network_error(http_bad):
		push_error("a 400 bad_score is not a network error, got %s" % http_bad)
		failed += 1
	var server := Leaderboard.parse_response(HTTPRequest.RESULT_SUCCESS, 503, bad)
	if not Leaderboard.is_network_error(server):
		push_error("a 5xx response should retry as a network error")
		failed += 1
	var limited := Leaderboard.parse_response(HTTPRequest.RESULT_SUCCESS, 429, PackedByteArray())
	if not Leaderboard.is_network_error(limited):
		push_error("429 should count as a network error")
		failed += 1
	var timeout := Leaderboard.parse_response(HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray())
	if not Leaderboard.is_network_error(timeout):
		push_error("a timeout should count as a network error")
		failed += 1
	var weird := Leaderboard.parse_response(HTTPRequest.RESULT_SUCCESS, 200, '{"nope":1}'.to_utf8_buffer())
	if str(weird.get("error", "")) != "bad_response" or Leaderboard.is_network_error(weird):
		push_error("unexpected JSON is not offline, got %s" % weird)
		failed += 1
	var rows := Leaderboard.parse_response(HTTPRequest.RESULT_SUCCESS, 200, '[{"rank":3}]'.to_utf8_buffer())
	if not bool(rows.get("ok", false)) or (rows.get("rows", []) as Array).size() != 1:
		push_error("a rank row should parse, got %s" % rows)
		failed += 1
	if absf(Leaderboard.next_retry_delay(0) - 0.8) > 0.001 or absf(Leaderboard.next_retry_delay(1) - 2.0) > 0.001 or Leaderboard.next_retry_delay(2) >= 0.0:
		push_error("network backoff should be 0.8s then 2s, then stop")
		failed += 1
	if Leaderboard.REQUEST_TIMEOUT < 15.0:
		push_error("request timeout should be at least 15s on cellular")
		failed += 1
	if Leaderboard.loading_limit() < Leaderboard.REQUEST_TIMEOUT or Leaderboard.loading_limit() > Leaderboard.REQUEST_TIMEOUT + 2.0:
		push_error("the loading line should give up about a second after the request timeout")
		failed += 1
	var shell_lb := FileAccess.get_file_as_string("res://web/shell.html")
	if shell_lb.find("window.lbPost") < 0 or shell_lb.find("res.text()") < 0:
		push_error("the web shell should read fetch().text() so Safari cannot leave the board on ...")
		failed += 1
	var http := HTTPRequest.new()
	http.use_threads = false
	http.accept_gzip = false
	http.timeout = Leaderboard.REQUEST_TIMEOUT
	if http.use_threads or http.accept_gzip or absf(http.timeout - Leaderboard.REQUEST_TIMEOUT) > 0.01:
		push_error("web requests should poll on the main thread with the longer timeout")
		failed += 1
	http.free()
	var cap_180 := ScoreRules.server_score_cap(180000)
	var clear_180 := ScoreRules.vending_clear_score(180.0)
	var cap_300 := ScoreRules.server_score_cap(300000)
	var clear_300 := ScoreRules.vending_clear_score(300.0)
	print("SCORE_CAP 180s bound=%d clear=%d 300s bound=%d clear=%d" % [cap_180, clear_180, cap_300, clear_300])
	if clear_180 > cap_180:
		push_error("a 3:00 vending clear should still fit the server cap (%d vs %d)" % [clear_180, cap_180])
		failed += 1
	if clear_300 > cap_300:
		push_error("a 5:00 full vending clear should fit the server cap without the WINNER bonus (%d vs %d)" % [clear_300, cap_300])
		failed += 1
	return failed

func _check_leaderboard() -> int:
	var failed := 0
	if Leaderboard.local_name_error("Fuuuck") != "":
		push_error("the client must not run its own profanity filter")
		failed += 1
	if Leaderboard.local_name_error("damn") != "":
		push_error("a mild name is a format check only")
		failed += 1
	if Leaderboard.local_name_error("!!!") == "":
		push_error("symbols should fail the name format check")
		failed += 1
	if Leaderboard.local_name_error("   ") == "":
		push_error("a blank name should fail the format check")
		failed += 1
	if Leaderboard.clean_name("  A  B  ") != "A B":
		push_error("names should trim and collapse spaces, got %s" % Leaderboard.clean_name("  A  B  "))
		failed += 1
	# Web name entry: window.prompt, then the same clean / format rules.
	# Cancel and a blank box leave the saved name alone. Headless Chrome
	# stubs window.prompt itself; this checks the contract Godot applies.
	if str(NamePrompt.interpret_prompt(null).get("action", "")) != "cancel":
		push_error("a dismissed prompt should leave the name unchanged")
		failed += 1
	if str(NamePrompt.interpret_prompt("").get("action", "")) != "cancel":
		push_error("an empty prompt should leave the name unchanged")
		failed += 1
	if str(NamePrompt.interpret_prompt("   ").get("action", "")) != "cancel":
		push_error("a blank prompt should leave the name unchanged")
		failed += 1
	var prompted: Dictionary = NamePrompt.interpret_prompt("  Ace  2  ")
	if str(prompted.get("action", "")) != "submit" or str(prompted.get("name", "")) != "Ace 2":
		push_error("prompt text should trim and collapse spaces, got %s" % prompted)
		failed += 1
	var prompt_call := NamePrompt.prompt_js("A\"B")
	if not prompt_call.begins_with("window.prompt(") or prompt_call.find(NamePrompt.PROMPT_MESSAGE) < 0:
		push_error("web name entry should call window.prompt, got %s" % prompt_call)
		failed += 1
	if prompt_call.find("A\\\"B") < 0:
		push_error("prompt text should escape quotes, got %s" % prompt_call)
		failed += 1
	var name_src := FileAccess.get_file_as_string("res://scripts/name_prompt.gd")
	if name_src.find("JavaScriptBridge.eval(prompt_js(") < 0 or name_src.find("lbShowNameField") >= 0:
		push_error("the web prompt should replace the overlay text field")
		failed += 1
	var decided_src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var decided_at := decided_src.find("func _on_name_decided")
	var decided_end := decided_src.find("func _on_name_cancelled")
	var decided_body := decided_src.substr(decided_at, decided_end - decided_at)
	var label_at := decided_body.find("set_player_name")
	var send_at := decided_body.find("_send_rename")
	if label_at < 0 or send_at < 0 or label_at > send_at or decided_src.find("set_remote_name") < 0:
		push_error("the board name should update before set_name")
		failed += 1
	if Leaderboard.REJECTED_NAME != "That name isn't allowed, try another":
		push_error("rejection copy changed")
		failed += 1
	var encoded := Leaderboard.encode_rpc({"p_period": "all", "p_form": null, "p_limit": 50})
	if encoded.find("\"p_form\":null") < 0 and encoded.find("\"p_form\": null") < 0:
		push_error("overall board must send a JSON null form, got %s" % encoded)
		failed += 1
	if Leaderboard.short_form("vending_machine") != "VEND" or Leaderboard.short_form("demon_lord") != "DEMON":
		push_error("form labels drifted")
		failed += 1
	var path := Leaderboard.PROFILE_PATH
	var had := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_string(path) if had else ""
	if had:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var client := Leaderboard.new()
	root.add_child(client)
	var first := client.device_id()
	var second := client.device_id()
	if first == "" or first != second or first.find("-") < 0:
		push_error("device id should be created once, got %s / %s" % [first, second])
		failed += 1
	if client.set_local_name("TEST") != "TEST" or client.player_name() != "TEST":
		push_error("local name did not stick")
		failed += 1
	client.free()
	var again := Leaderboard.new()
	root.add_child(again)
	if again.device_id() != first or again.player_name() != "TEST":
		push_error("device id and name should persist")
		failed += 1
	again.free()
	if had:
		var restore := FileAccess.open(path, FileAccess.WRITE)
		if restore != null:
			restore.store_string(backup)
			restore.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	CaptureMode.reset_for_test(PackedStringArray(["--form=cat", "--seed=3"]))
	if not Leaderboard.should_submit():
		push_error("a challenge run should post")
		failed += 1
	CaptureMode.reset_for_test(PackedStringArray())
	if not Leaderboard.should_submit():
		push_error("a normal run should post")
		failed += 1
	if CaptureMode.is_active():
		push_error("leaderboard checks left a mode flag on")
		failed += 1
	return failed

## The in-game dialog stays for desktop. A filtered name uses the existing
## rejection line and does not stick. An accepted name updates the footer
## before any server round trip.
func _check_name_entry() -> int:
	var failed := 0
	var path := Leaderboard.PROFILE_PATH
	var had := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_string(path) if had else ""
	var profile := FileAccess.open(path, FileAccess.WRITE)
	if profile == null:
		push_error("could not write a name-entry profile")
		return 1
	profile.store_string(JSON.stringify({"device_id": "name-entry-test", "name": "TEST", "posted": false}))
	profile.close()
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	if game._leaderboard == null or game._leaderboard.player_name() != "TEST":
		push_error("name prompt check lost the saved name")
		failed += 1
	else:
		game._on_name_decided("!!!", "board")
		if game._leaderboard.player_name() != "TEST" or not game._name_prompt.visible or game._name_prompt._error.text != Leaderboard.FORMAT_HINT:
			push_error("a bad prompt should keep the name and show the format hint")
			failed += 1
		game._board.set_player_name("TEMP")
		game._on_renamed({"ok": false, "error": "name_not_allowed"}, "Nope", game._rename_gen)
		if game._board._name_label.text != "TEST" or game._name_prompt._error.text != Leaderboard.REJECTED_NAME:
			push_error("a filtered name should revert the label and show the in-game rejection")
			failed += 1
		game._on_name_decided("ACE", "board")
		if game._board._name_label.text != "ACE" or game._leaderboard.player_name() != "ACE":
			push_error("an accepted name should update the board immediately, got %s / %s" % [game._board._name_label.text, game._leaderboard.player_name()])
			failed += 1
		game._name_prompt.open("Zed", "death")
		if not game._name_prompt.visible or game._name_prompt.current_text() != "Zed":
			push_error("desktop name entry should keep the in-game field")
			failed += 1
		game._name_prompt.close()
	root.remove_child(game)
	game.free()
	if had:
		var restore := FileAccess.open(path, FileAccess.WRITE)
		if restore != null:
			restore.store_string(backup)
			restore.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return failed

## Rows are hard Kaito pixels in columns, not one tinted outlined string.
## A 12-character name and a 7-digit score have to fit the 480-wide board.
func _check_rank_fallback() -> int:
	var failed := 0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game._lb_gen = 4
	game._rank_serial = 7
	game._rank_form = "slime"
	game._daily_rank = -1
	game._all_rank = -1
	game._rank_parts = 0
	game._rank_network = 0
	game._on_rank_part({"ok": true, "rows": [{"rank": 4}]}, "daily", 4, 7)
	game._on_rank_part({"ok": false, "error": "offline", "rows": []}, "all", 4, 7)
	if game._rank_label.text != "#4 today":
		push_error("one good rank should show even if the other fetch fails, got %s" % game._rank_label.text)
		failed += 1
	game._lb_gen = 5
	game._rank_serial = 8
	game._daily_rank = -1
	game._all_rank = -1
	game._rank_parts = 0
	game._rank_network = 0
	game._on_rank_part({"ok": false, "error": "offline", "rows": []}, "daily", 5, 8)
	game._on_rank_part({"ok": false, "error": "offline", "rows": []}, "all", 5, 8)
	if game._rank_label.text != Leaderboard.UNREACHABLE or game._rank_retry != "ranks":
		push_error("two failed rank fetches should offer a tap retry, got %s" % game._rank_label.text)
		failed += 1
	game._lb_gen = 6
	game._on_submit_parsed({"ok": false, "error": "bad_score", "rows": []}, 6)
	if game._rank_label.text != Leaderboard.SCORE_NOT_POSTED:
		push_error("a rejected score should not say the leaderboard is offline, got %s" % game._rank_label.text)
		failed += 1
	root.remove_child(game)
	game.free()
	return failed

func _check_board_rows() -> int:
	var failed := 0
	var width := 468.0
	var boxes := LeaderboardScreen.column_boxes(width, true)
	if int(boxes["scale"]) != 2:
		push_error("480-wide rows should use the double pixel size, got %s" % boxes["scale"])
		failed += 1
	var name_need := PixelFont.plain_advance("MMMMMMMMMMMM") * 2
	var score_need := PixelFont.plain_advance("9,999,999") * 2
	if float(boxes["name_w"]) + 0.1 < name_need:
		push_error("a 12-character name does not fit (%s < %s)" % [boxes["name_w"], name_need])
		failed += 1
	if float(boxes["score_w"]) + 0.1 < score_need:
		push_error("a 7-digit score does not fit")
		failed += 1
	if float(boxes["name_x"]) + float(boxes["name_w"]) > float(boxes["score_x"]) + 0.1:
		push_error("the name column overlaps the score")
		failed += 1
	if float(boxes["score_x"]) + float(boxes["score_w"]) > float(boxes["form_x"]) + 0.1:
		push_error("the score column overlaps the form")
		failed += 1
	if float(boxes["form_x"]) + float(boxes["form_w"]) > float(boxes["you_x"]) + 0.1:
		push_error("the form column overlaps the you tag")
		failed += 1
	var screen := LeaderboardScreen.new()
	var client := Leaderboard.new()
	screen.setup(client, load("res://ui/font_kaito5x7_outlined.fnt"))
	root.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.position = Vector2.ZERO
	screen.size = Vector2(480, 270)
	screen.preview([
		{"rank": 1, "name": "Spyral", "score": 68566, "form": "demon_lord", "is_me": true},
		{"rank": 2, "name": "MMMMMMMMMMMM", "score": 9999999, "form": "goblin", "is_me": false},
		{"rank": 3, "name": "Gel Knight", "score": 42100, "form": "slime", "is_me": false},
	], "Spyral")
	var mine := screen._list.get_node_or_null("me") as Control
	if mine == null:
		push_error("the highlighted row is missing")
		failed += 1
	else:
		failed += _check_row_pixels(mine.get_node_or_null("Rank"), true)
		failed += _check_row_gap(mine)
	if screen._list.get_child_count() < 2:
		push_error("sample rows were not drawn")
		failed += 1
	else:
		var wide := screen._list.get_child(1) as Control
		failed += _check_row_gap(wide)
		failed += _check_row_pixels(wide.get_node_or_null("Rank"), false)
		var name_box := wide.get_node_or_null("Name") as Control
		var name_text := wide.get_node_or_null("Name/NameText") as Control
		var score := wide.get_node_or_null("Score") as Control
		if name_box == null or name_text == null or score == null:
			push_error("the wide row is missing a column")
			failed += 1
		else:
			var name_right := name_box.position.x + name_text.position.x + name_text.size.x
			if name_right > score.position.x + 0.1:
				push_error("a 12-character name overlaps its score (%s vs %s)" % [name_right, score.position.x])
				failed += 1
	screen.visible = true
	screen._status.text = "..."
	screen._on_load_watch()
	if screen._status.text != Leaderboard.UNREACHABLE or not screen._can_retry:
		push_error("a hung load should leave the tap-to-retry line, got %s" % screen._status.text)
		failed += 1
	root.remove_child(screen)
	screen.free()
	client.free()
	return failed

func _check_row_pixels(rank: Node, mine: bool) -> int:
	var rect := rank as TextureRect
	if rect == null or rect.texture == null:
		push_error("row has no rank glyphs")
		return 1
	if rect.texture.get_height() < 16:
		push_error("row glyphs should be the larger pixel size, height %s" % rect.texture.get_height())
		return 1
	var image := rect.texture.get_image()
	if image == null:
		push_error("row texture has no image")
		return 1
	var soft := 0
	var saw := false
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.02:
				continue
			if pixel.a < 0.98:
				soft += 1
				continue
			saw = true
			if mine:
				var ink := LeaderboardScreen.ROW_MINE_INK
				if absf(pixel.r - ink.r) > 0.04 or absf(pixel.g - ink.g) > 0.04 or absf(pixel.b - ink.b) > 0.04:
					push_error("highlighted row should be flat dark pixels, got %s" % pixel)
					return 1
	if not saw or soft > 0:
		push_error("row glyphs should be hard pixels, soft %d" % soft)
		return 1
	return 0

func _check_row_gap(panel: Control) -> int:
	var rank := panel.get_node_or_null("Rank") as Control
	var name_box := panel.get_node_or_null("Name") as Control
	var score := panel.get_node_or_null("Score") as Control
	var form := panel.get_node_or_null("Form") as Control
	if rank == null or name_box == null or score == null or form == null:
		push_error("a row is missing a column")
		return 1
	var rank_right := rank.position.x + rank.size.x
	var name_left := name_box.position.x
	var name_right := name_box.position.x + name_box.size.x
	var score_left := score.position.x
	var score_right := score.position.x + score.size.x
	var form_left := form.position.x
	if rank_right > name_left + 0.1 or name_right > score_left + 0.1 or score_right > form_left + 0.1:
		push_error("row columns overlap (rank %s name %s-%s score %s-%s form %s)" % [rank_right, name_left, name_right, score_left, score_right, form_left])
		return 1
	return 0

func _check_pause() -> int:
	var failed := 0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var step := 1.0 / 60.0
	for _i in 100:
		game._process(step)
	if int(game.phase) != 1 or game._pause_button == null or game._pause_icon == null:
		push_error("pause check did not reach play with a pause control")
		root.remove_child(game)
		game.free()
		return 1
	var viewport := Vector2(480, 270)
	# iPhone 14 landscape, CSS points times a 3x screen. Godot's web export
	# reports the canvas in device pixels and the scale as devicePixelRatio.
	var iphone := Vector2(2532, 1170)
	var hit: float = game.pause_hit_px(viewport, iphone, 3.0)
	var pixel_scale: float = game.visible_pixel_scale(viewport, iphone)
	var points := hit * pixel_scale / 3.0
	if hit + 0.01 < 44.0 or points + 0.01 < 44.0:
		push_error("iPhone pause target should be at least 44pt (hit %s points %s scale %s)" % [hit, points, pixel_scale])
		failed += 1
	var se_hit: float = game.pause_hit_px(viewport, Vector2(1334, 750), 2.0)
	var se_scale: float = game.visible_pixel_scale(viewport, Vector2(1334, 750))
	if se_hit * se_scale / 2.0 + 0.01 < 44.0:
		push_error("iPhone SE pause target shrank under 44pt")
		failed += 1
	game.apply_pause_layout(viewport, iphone, 3.0)
	var button: Button = game._pause_button
	if button.size.x + 0.01 < 44.0 or button.size.y + 0.01 < 44.0:
		push_error("pause control is smaller than 44px (%s)" % button.size)
		failed += 1
	if button.mouse_filter != Control.MOUSE_FILTER_STOP:
		push_error("pause control should take the touch")
		failed += 1
	var icon: TextureRect = game._pause_icon
	if icon.texture == null or icon.texture.get_width() != 18 or icon.texture.get_height() != 18:
		push_error("pause art should stay 18 px")
		failed += 1
	if absf(icon.size.x - 18.0) > 0.01 or absf(icon.size.y - 18.0) > 0.01 or absf(icon.scale.x - 1.0) > 0.01 or absf(icon.scale.y - 1.0) > 0.01:
		push_error("pause art should not be scaled (size %s scale %s)" % [icon.size, icon.scale])
		failed += 1
	var icon_rect := Rect2(button.position + icon.position, icon.size)
	var pad := button.position + Vector2(2, 2)
	if not Rect2(button.position, button.size).has_point(pad):
		push_error("pause padding should be inside the control")
		failed += 1
	if icon_rect.has_point(pad):
		push_error("the 44px target should extend past the 18px art")
		failed += 1
	if not game._hits_pause(pad):
		push_error("a touch on the padding should hit pause")
		failed += 1
	var elapsed_before := float(game.elapsed)
	game._toggle_pause()
	for _i in 30:
		game._process(step)
	if not game._paused or float(game.elapsed) > elapsed_before + 0.001:
		push_error("pause should freeze the run")
		failed += 1
	failed += _check_pause_card(game)
	game._toggle_pause()
	game._process(step)
	if game._paused or float(game.elapsed) <= elapsed_before:
		push_error("resume should advance the run")
		failed += 1
	var ship_before: Vector2 = game._player.position
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = game._pause_button.position + Vector2(2, 2)
	game._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(40, -24)
	drag.position = touch.position + drag.relative
	game._input(drag)
	game._process(step)
	if game._player.position.distance_to(ship_before) > 8.0:
		push_error("a pause touch should not drag the ship (%s -> %s)" % [ship_before, game._player.position])
		failed += 1
	HitLibrary.show = false
	var toggle := InputEventKey.new()
	toggle.pressed = true
	toggle.keycode = KEY_H
	game._unhandled_input(toggle)
	if not HitLibrary.show:
		push_error("H should draw the hit shapes")
		failed += 1
	game._unhandled_input(toggle)
	if HitLibrary.show:
		push_error("H should hide the hit shapes again")
		failed += 1
	var debug_key := InputEventKey.new()
	debug_key.pressed = true
	debug_key.keycode = KEY_D
	game._unhandled_input(debug_key)
	if not game._debug_on or game._debug_label == null or not game._debug_label.visible:
		push_error("D should show the pacing overlay")
		failed += 1
	elif game._debug_label.text.find("spawn") < 0 or game._debug_label.text.find("spd") < 0:
		push_error("the pacing overlay should show the spawn interval and the speed multiplier")
		failed += 1
	game._unhandled_input(debug_key)
	if game._debug_on:
		push_error("D should hide the pacing overlay")
		failed += 1
	root.remove_child(game)
	game.free()
	return failed

func _check_pause_card(game) -> int:
	var failed := 0
	var card = game._pause_card
	if card == null or not game._pause_overlay.visible or not card.visible:
		push_error("pause should show the form card")
		return 1
	if card.heading_text() != FormCatalog.card_heading(int(game.form_id), int(game.rank_index)):
		push_error("pause card heading mismatch: %s" % card.heading_text())
		failed += 1
	var interval := "%.2fs" % float(FormCatalog.rank_spec(int(game.form_id), int(game.rank_index))["fire_interval"])
	if card.weapon_text().find(interval) < 0 or card.weapon_text().find("WEAPON") < 0:
		push_error("pause weapon line should come from the rank data, got %s" % card.weapon_text())
		failed += 1
	if card.trait_text().find("TRAIT") < 0:
		push_error("pause card should label the trait")
		failed += 1
	if int(game.form_id) == FormCatalog.Id.SLIME:
		if card.trait_text().find("Split ready.") < 0:
			push_error("a full slime should show the split as ready")
			failed += 1
		game._player.small = true
		game._refresh_pause_card()
		if card.trait_text().find("Split used.") < 0:
			push_error("a small slime should show the split as used")
			failed += 1
		game._player.small = false
		game._player._apply_radius()
		game._refresh_pause_card()
	elif int(game.form_id) == FormCatalog.Id.GOBLIN:
		if card.trait_text().find("Gems nearby get pulled in.") < 0:
			push_error("goblin pause card should describe the gem magnet")
			failed += 1
	elif int(game.form_id) == FormCatalog.Id.VENDING:
		if card.trait_text().find("WINNER!") < 0 or card.weapon_text().find("cans") < 0:
			push_error("vending pause card should describe the cans and the WINNER meter")
			failed += 1
	elif int(game.form_id) == FormCatalog.Id.CAT:
		if card.trait_text().find("Swipes pierce 2 and knock bullets away.") < 0 or card.weapon_text().find("Reflects") < 0:
			push_error("cat pause card should describe the piercing swipe and the reflect")
			failed += 1
	elif int(game.form_id) == FormCatalog.Id.DEMON:
		if card.trait_text().find("enemies") < 0 or card.weapon_text().find("Homing") < 0:
			push_error("demon pause card should describe homing orbs and the crowd")
			failed += 1
	if card.next_text().find("FINAL FORM") >= 0:
		push_error("rank 1 should show the next-rank bar, not FINAL FORM")
		failed += 1
	var card_rect := Rect2(card.position, card.size)
	var pause_rect := Rect2(game._pause_button.position, game._pause_button.size)
	var sound_rect := Rect2(game._sound_button.position, game._sound_button.size)
	if card.size.y < 40.0 or card_rect.intersects(pause_rect) or card_rect.intersects(sound_rect):
		push_error("pause card should stay clear of resume and sound (card %s pause %s sound %s)" % [card_rect, pause_rect, sound_rect])
		failed += 1
	if card.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		push_error("the pause card should not eat the resume or sound touch")
		failed += 1
	return failed

func _check_loot() -> int:
	var failed := 0
	var gem := ArtLibrary.texture("gem.png").get_image()
	var coin := ArtLibrary.texture("coin.png").get_image()
	if gem == null or gem.get_width() != 8 or gem.get_height() != 8:
		push_error("gem should stay 8x8")
		failed += 1
	elif gem.get_pixel(3, 2) != Color("f2fbff"):
		push_error("gem glint should sit at (3, 2)")
		failed += 1
	else:
		var green := false
		var pink := false
		for y in gem.get_height():
			for x in gem.get_width():
				var pixel := gem.get_pixel(x, y)
				if pixel.a < 0.5:
					continue
				if pixel.g > pixel.r and pixel.g > pixel.b and pixel.g > 0.6:
					green = true
				if pixel.r > 0.7 and pixel.b > 0.7 and pixel.g < 0.5:
					pink = true
		if not green or pink:
			push_error("gem should be the emerald step-cut, not the old pink diamond")
			failed += 1
	if coin == null or coin.get_width() != 8 or coin.get_height() != 8:
		push_error("coin should stay 8x8")
		failed += 1
	elif coin.get_pixel(2, 2) != Color("f2fbff"):
		push_error("coin glint should sit at (2, 2)")
		failed += 1
	else:
		var rim := coin.get_pixel(4, 7)
		if rim.r < 0.35 or rim.g > rim.r or rim.b > 0.2:
			push_error("coin rim should be the brown #6b3e26, got %s" % rim)
			failed += 1
	var hud_coin := load("res://art/ui/hud_coin_icon.png") as Texture2D
	if hud_coin == null or hud_coin.get_width() != 10 or hud_coin.get_height() != 10:
		push_error("HUD coin icon should be the 10x10 loot-fix coin")
		failed += 1
	var pickup := LootGem.new()
	pickup.setup("coin.png")
	if absf(pickup.bob_offset()) > 0.001:
		push_error("loot bob should start at 0")
		failed += 1
	pickup.age = PI * 0.5 / 4.0
	if absf(pickup.bob_offset() - 1.0) > 0.001:
		push_error("loot bob should be sin(t*4), got %s" % pickup.bob_offset())
		failed += 1
	pickup.age = 0.0
	var start := pickup.position
	pickup.tick(0.25)
	if pickup.position.x >= start.x - 1.0:
		push_error("loot should keep drifting left under the bob")
		failed += 1
	# The bob is a draw offset. It must not be baked into the drifted position.
	var drifted := pickup.position.y
	pickup.age = PI * 0.5 / 4.0
	if absf(pickup.position.y - drifted) > 0.001 or absf(pickup.bob_offset() - 1.0) > 0.001:
		push_error("the 1px bob should sit on top of the drift")
		failed += 1
	pickup.free()
	return failed

## Goblin magnet glides. A gem inside the radius is not collected until it touches.
func _check_goblin_magnet() -> int:
	var failed := 0
	if absf(Difficulty.GOBLIN_MAGNET - 96.0) > 0.001 or absf(Difficulty.GOBLIN_MAGNET_SPEED - 180.0) > 0.001:
		push_error("goblin magnet should be 96 at 180 px/s, got %s / %s" % [Difficulty.GOBLIN_MAGNET, Difficulty.GOBLIN_MAGNET_SPEED])
		failed += 1
	if absf(Difficulty.MAGNET_RADIUS - 168.0) > 0.001 or absf(Difficulty.MAGNET_SPEED - 240.0) > 0.001:
		push_error("magnet power-up should stay 168 / 240")
		failed += 1
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	if game._player == null:
		push_error("goblin magnet check had no player")
		game.free()
		return failed + 1
	game._player.position = Vector2(180, 135)
	game._player.aim = game._player.position
	game._player.alive = true
	var trailing := _magnet_edge_frames(game, -1.0)
	var leading := _magnet_edge_frames(game, 1.0)
	if trailing < 2 or trailing > 90 or leading < 2 or leading > trailing:
		failed += 1
		if trailing >= 2 and trailing <= 90 and leading >= 2:
			push_error("a gem at the leading edge should arrive before the trailing edge (leading %d trailing %d)" % [leading, trailing])
	else:
		var gem_r := ArtLibrary.radius_for("gem.png", 0.65)
		print("GOBLIN_EDGE_FRAMES trailing=%d leading=%d player_r=%.2f gem_r=%.2f" % [trailing, leading, game._player.radius, gem_r])
	failed += _expect_magnet_glide(game, FormCatalog.Id.SLIME, Difficulty.POWER_DURATION, Difficulty.MAGNET_RADIUS * 0.75)
	root.remove_child(game)
	game.free()
	return failed

## Frames until a gem that starts on the goblin radius touches the player. Negative x is the trailing edge, where leftward drift opposes the pull.
func _magnet_edge_frames(game, direction: float) -> int:
	game.form_id = FormCatalog.Id.GOBLIN
	game._player.form_id = FormCatalog.Id.GOBLIN
	game._player.small = false
	game._player.fit_scale = 1.0
	game.rank_index = 0
	game.evo_points = 0
	game._player.set_rank(0)
	game._player.alive = true
	game.magnet_left = 0.0
	game.loot_count = 0
	for existing in game._loot.duplicate():
		game._release_gem(existing)
	game._loot.clear()
	var gem: LootGem = game._take_gem()
	gem.setup("gem.png")
	gem.life = Difficulty.GEM_LIFE
	gem.drift = Difficulty.GEM_DRIFT
	gem.age = 0.0
	gem.position = game._player.position + Vector2(direction * Difficulty.GOBLIN_MAGNET, 0.0)
	var before: float = gem.position.distance_to(game._player.position)
	var touch: float = float(game._player.radius) + gem.radius
	if before <= touch + 1.0:
		push_error("goblin magnet edge should start clear of the body (dist %.1f touch %.1f)" % [before, touch])
		return -1
	game._loot.append(gem)
	game._tick_loot(1.0 / 60.0)
	if int(game.loot_count) != 0:
		push_error("gem on the goblin radius was collected on the first tick")
		return 1
	if not is_instance_valid(gem) or not gem.visible:
		push_error("gem on the goblin radius was dropped on the first tick")
		return -1
	var after: float = gem.position.distance_to(game._player.position)
	if after >= before - 0.05:
		push_error("goblin magnet should move an in-range gem closer (before %.2f after %.2f dir %.0f)" % [before, after, direction])
		return -1
	var frames := 1
	while int(game.loot_count) == 0 and frames < 180:
		game._tick_loot(1.0 / 60.0)
		frames += 1
	if int(game.loot_count) != 1:
		push_error("gem at the goblin magnet edge did not reach the player (dir %.0f dist %.1f)" % [direction, gem.position.distance_to(game._player.position)])
		return 999
	return frames

## Magnet power-up: a gem inside the power radius, not touching, glides and is not grabbed on the first tick.
func _expect_magnet_glide(game, form: int, magnet_time: float, separation: float) -> int:
	game.form_id = form
	game._player.form_id = form
	game._player.small = false
	game._player.fit_scale = 1.0
	game.rank_index = 0
	game._player.set_rank(0)
	game._player.alive = true
	game._player.position = Vector2(180, 135)
	game._player.aim = game._player.position
	game.magnet_left = magnet_time
	game.loot_count = 0
	for existing in game._loot.duplicate():
		game._release_gem(existing)
	game._loot.clear()
	var gem: LootGem = game._take_gem()
	gem.setup("gem.png")
	gem.life = Difficulty.GEM_LIFE
	gem.drift = Difficulty.GEM_DRIFT
	gem.age = 0.0
	gem.position = game._player.position + Vector2(-separation, 0.0)
	var before: float = gem.position.distance_to(game._player.position)
	var touch: float = float(game._player.radius) + gem.radius
	if before <= touch + 1.0 or before > Difficulty.MAGNET_RADIUS:
		push_error("power magnet probe should sit inside the power radius and off the body (dist %.1f touch %.1f)" % [before, touch])
		return 1
	game._loot.append(gem)
	game._tick_loot(1.0 / 60.0)
	if int(game.loot_count) != 0 or not gem.visible:
		push_error("magnet power-up should not grab a gem that is inside the radius but not touching")
		return 1
	if gem.position.distance_to(game._player.position) >= before - 0.05:
		push_error("magnet power-up should pull an in-range gem closer (before %.2f after %.2f)" % [before, gem.position.distance_to(game._player.position)])
		return 1
	return 0

func _check_hud() -> int:
	var failed := 0
	var gate_rank2 := Difficulty.GATE_RANK2
	var gate_rank3 := Difficulty.GATE_RANK3
	var half_rank2 := int(gate_rank2 / 2)
	var half_rank3 := gate_rank2 + int((gate_rank3 - gate_rank2) / 2)
	if HudLayout.fill_px(0, 0) != 0 or HudLayout.fill_px(half_rank2, 0) != 32:
		push_error("rank 1 meter should be empty at 0 and half full at the midpoint, got %d %d" % [HudLayout.fill_px(0, 0), HudLayout.fill_px(half_rank2, 0)])
		failed += 1
	if HudLayout.fill_px(gate_rank2, 1) != 0 or HudLayout.fill_px(half_rank3, 1) != 32:
		push_error("rank 2 meter should reset at the gate and reach half between the gates, got %d %d" % [HudLayout.fill_px(gate_rank2, 1), HudLayout.fill_px(half_rank3, 1)])
		failed += 1
	if HudLayout.fill_px(gate_rank3, 2) != 0:
		push_error("rank 3 meter should restart at its gate, got %d" % HudLayout.fill_px(gate_rank3, 2))
		failed += 1
	if HudLayout.fill_px(Difficulty.GATE_RANK5, 4) != 0:
		push_error("rank 5 meter should restart toward Power, got %d" % HudLayout.fill_px(Difficulty.GATE_RANK5, 4))
		failed += 1
	var power_half := Difficulty.GATE_RANK5 + int(Difficulty.power_step_points(1) / 2)
	if HudLayout.fill_px(power_half, 4) != 32:
		push_error("Power meter should be half full halfway to +1, got %d" % HudLayout.fill_px(power_half, 4))
		failed += 1
	if Difficulty.power_level(Difficulty.GATE_RANK5) != 0 or Difficulty.power_level(Difficulty.GATE_RANK5 + Difficulty.power_step_points(1)) != 1:
		push_error("the first Power level should cost more than one gem and start at the final form")
		failed += 1
	if Difficulty.power_step_gems(2) <= Difficulty.power_step_gems(1):
		push_error("each Power level should cost more gems than the last")
		failed += 1
	if Difficulty.overdrive_drop_chance(180.0) <= Difficulty.overdrive_drop_chance(10.0):
		push_error("OVERDRIVE should be a little more common as the run approaches 3:00")
		failed += 1
	if Difficulty.OVERDRIVE_DROP_COOLDOWN < 8.0 or Difficulty.OVERDRIVE_SCORE <= Difficulty.BOMB_SCORE:
		push_error("OVERDRIVE should be rarer than a back-to-back drop and worth more than Bomb")
		failed += 1
	if HudLayout.meter_file(4) != "ui/hud_evo_meter_rank5_empty.png":
		push_error("rank 5 should use the five-pip meter")
		failed += 1
	if HudLayout.meter_file(0) != "ui/hud_evo_meter_rank1_empty.png" or HudLayout.meter_file(2) != "ui/hud_evo_meter_rank3_empty.png":
		push_error("meter frame should follow the rank")
		failed += 1
	var score := PixelFont.score_image("4,210")
	if score == null or score.get_width() != 64 or score.get_height() != 30 or PixelFont.checksum(score) != 1233492:
		push_error("score digits should be the 2x gold Kaito render (got %s checksum %s)" % [score.get_size() if score != null else "null", PixelFont.checksum(score) if score != null else -1])
		failed += 1
	if PixelFont.is_solid_block(score) or PixelFont.interior_holes(score) < 8:
		push_error("score glyphs rendered as one solid rectangle (holes %d)" % PixelFont.interior_holes(score))
		failed += 1
	# The clock, the rank line, and the +points pop are the HUD labels that
	# showed up as filled bars on the web build.
	var clock := PixelFont.outlined_image("0:12", Color("f2fbff"))
	var points := PixelFont.outlined_image("+100", Color("241428"))
	if PixelFont.is_solid_block(clock) or PixelFont.is_solid_block(points):
		push_error("HUD label rendered as one solid rectangle (clock holes %d points holes %d)" % [PixelFont.interior_holes(clock), PixelFont.interior_holes(points)])
		failed += 1
	var empty := Image.new()
	if PixelFont.sample_alpha(empty, 0, 0) > 0.5 or PixelFont.sample_alpha(empty, 7, 1) > 0.5:
		push_error("a missing atlas page must not count as ink")
		failed += 1
	if PixelFont.is_solid_block(PixelFont.plain_atlas()):
		push_error("Kaito atlas page is a solid rectangle")
		failed += 1
	var rank := PixelFont.outlined_image("GEL KNIGHT", Color("ffbcea"))
	var used := rank.get_used_rect()
	if int(used.size.x) != 59 or int(used.size.y) != 9:
		push_error("rank name should be 1x outlined Kaito, got %s" % used)
		failed += 1
	if PixelFont.is_solid_block(rank):
		push_error("rank name rendered as one solid rectangle")
		failed += 1
	var outlined := load("res://ui/font_kaito5x7_outlined.fnt") as Font
	var plain := load("res://ui/font_kaito5x7.fnt") as Font
	if outlined == null or plain == null:
		push_error("Kaito BMFont should import as a FontFile")
		failed += 1
	elif outlined.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= 0.0:
		push_error("outlined Kaito did not measure a glyph")
		failed += 1
	var coins_off := HudView.new()
	coins_off.set_run("0", "0:00", 4, "SLIME", 0, 0, false)
	var coins_on := HudView.new()
	coins_on.set_run("0", "0:00", 4, "GOBLIN", 0, 0, true)
	if coins_off.show_coins or coins_off._coin != null or not coins_on.show_coins or coins_on._coin == null:
		push_error("the coin counter should draw only for the goblin")
		failed += 1
	coins_off.free()
	coins_on.free()
	for file_name in ["ui/hud_clock_icon.png", "ui/hud_pause_button.png", "ui/hud_evo_meter_fill_64x6.png", "ui/hud_coin_icon.png"]:
		if not ArtLibrary.has_file(file_name):
			push_error("HUD piece missing from the manifest: %s" % file_name)
			failed += 1
	return failed

func _check_death_sequence() -> int:
	var failed := 0
	var samples := [
		[0.0, "hit"],
		[1.0 / 12.0, "hit"],
		[2.0 / 12.0, "pop"],
		[4.0 / 12.0, "pop"],
		[5.0 / 12.0, "puff"],
		[8.0 / 12.0, "puff"],
		[9.0 / 12.0, "hold"],
		[10.0 / 12.0, "hold"],
		[11.0 / 12.0, "tease"],
		[11.0 / 12.0 + 0.5, "tease"],
		[11.0 / 12.0 + 1.0, "card"],
	]
	for sample in samples:
		var stage := FxTimeline.death_stage(float(sample[0]))
		if stage != str(sample[1]):
			push_error("death t=%.3f should be %s, got %s" % [float(sample[0]), sample[1], stage])
			failed += 1
	if FxTimeline.pop_file(Vector2(24, 24)) != "fx/fx_death_pop_s.png" or FxTimeline.pop_file(Vector2(34, 34)) != "fx/fx_death_pop_s.png":
		push_error("forms up to 34 px should pop small")
		failed += 1
	if FxTimeline.pop_file(Vector2(35, 34)) != "fx/fx_death_pop_s.png" or FxTimeline.pop_file(Vector2(37, 34)) != "fx/fx_death_pop_l.png" or FxTimeline.pop_file(Vector2(40, 48)) != "fx/fx_death_pop_l.png":
		push_error("big forms should pop large")
		failed += 1
	if FxTimeline.pop_file(ArtLibrary.art_bbox("slime_r3.png")) != "fx/fx_death_pop_s.png":
		push_error("ringed slime r3 should keep the small death pop")
		failed += 1
	if FxTimeline.pop_file(ArtLibrary.art_bbox("cat_r3.png")) != "fx/fx_death_pop_s.png":
		push_error("cat r3 should keep the small death pop")
		failed += 1
	var cat_size: Array = ArtLibrary.entry("cat_r3.png")["size"]
	if FxTimeline.pop_file(Vector2(float(cat_size[0]), float(cat_size[1]))) != "fx/fx_death_pop_s.png":
		push_error("cat r3 frame size should still pop small")
		failed += 1
	for crowned in ["goblin_r1.png", "goblin_r2.png", "goblin_r3.png", "goblin_r5_body.png", "cat_r3.png", "cat_r5_body.png", "demon_lord_r3.png", "demon_lord_r5_body.png", "slime_r3.png", "slime_r4_body.png", "slime_small_r3.png", "slime_small_r5.png"]:
		if not FxTimeline.wears_crown(crowned):
			push_error("%s should fly a crown" % crowned)
			failed += 1
	for plain in ["slime_r1.png", "slime_r2.png", "cat_r1.png", "cat_r2.png", "demon_lord_r1.png", "demon_lord_r2.png", "vending_machine_r2.png"]:
		if FxTimeline.wears_crown(plain):
			push_error("%s should not fly a crown" % plain)
			failed += 1
	for sprite_name in ["slime_r1.png", "slime_small_r2.png", "goblin_r3.png", "cat_r3.png", "demon_lord_r3.png", "vending_machine_r1.png"]:
		var base := ArtLibrary.anchor(sprite_name)
		var flash := ArtLibrary.anchor(FxTimeline.flash_file(sprite_name))
		var rim := ArtLibrary.anchor(FxTimeline.rim_file(sprite_name))
		if flash != base + Vector2(1, 1) or rim != base + Vector2(1, 1):
			push_error("%s flash/rim anchor should be the sprite anchor + (1, 1)" % sprite_name)
			failed += 1
	var hit := ArtLibrary.entry("fx/fx_death_hit.png")
	if int(hit.get("frames", 0)) != 2 or absf(float(hit.get("fps", 0)) - 12.0) > 0.01 or bool(hit.get("loop", true)):
		push_error("death hit should be 2 frames at 12 fps, not looping")
		failed += 1
	var held := ArtLibrary.frame_source("fx/fx_death_pop_s.png", 10.0)
	var third := ArtLibrary.frame_source("fx/fx_death_pop_s.png", 2.0 / 12.0)
	if held.position != third.position:
		push_error("a finished pop should hold its last frame")
		failed += 1
	var evolve_samples := [
		[0.0, "glow", true],
		[1.0 / 12.0, "glow", false],
		[2.0 / 12.0, "glow", true],
		[3.0 / 12.0, "flash", false],
		[4.0 / 12.0, "flash", false],
		[5.0 / 12.0, "pop", false],
		[7.0 / 12.0, "pop", false],
		[8.0 / 12.0 + 0.5, "pop", false],
		[8.0 / 12.0 + 1.0, "done", false],
	]
	for sample in evolve_samples:
		var stage := FxTimeline.evolve_stage(float(sample[0]))
		if stage != str(sample[1]) or FxTimeline.evolve_shows_rim(float(sample[0])) != bool(sample[2]):
			push_error("evolve t=%.3f should be %s rim %s, got %s rim %s" % [float(sample[0]), sample[1], sample[2], stage, FxTimeline.evolve_shows_rim(float(sample[0]))])
			failed += 1
	return failed

func _check_death_play() -> int:
	var failed := 0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game._begin_play()
	game._player.form_id = FormCatalog.Id.GOBLIN
	game._player.set_rank(2)
	game._kill_player("Dire Wolf")
	if game.game_over_visible or FxTimeline.death_stage(game.death_elapsed) != "hit":
		push_error("death should open on the hit, not the card")
		failed += 1
	if game._death_fx == null or game._death_fx.pop_name != "fx/fx_death_pop_l.png" or not game._death_fx.crowned:
		push_error("goblin rank 3 should pop large and fly the crown")
		failed += 1
	var order: Array[String] = []
	var last := ""
	for _i in 400:
		var stage := FxTimeline.death_stage(float(game.death_elapsed))
		if stage != last:
			order.append(stage)
			last = stage
		if stage == "card":
			break
		game._process(1.0 / 60.0)
	if order != ["hit", "pop", "puff", "hold", "tease", "card"]:
		push_error("death order was %s" % str(order))
		failed += 1
	if not game.game_over_visible or (game._tease != null and game._tease.visible):
		push_error("the tease should give way to the death card")
		failed += 1
	root.remove_child(game)
	game.free()
	return failed

func _check_share_card() -> int:
	var failed := 0
	if ShareCard.killer_id("falling piano") != "piano" or ShareCard.killer_id("Dire Wolf") != "dire_wolf":
		push_error("killer names should map onto the share-card ids")
		failed += 1
	for pair in [["slime", FormCatalog.Id.SLIME], ["goblin", FormCatalog.Id.GOBLIN], ["vending_machine", FormCatalog.Id.VENDING], ["cat", FormCatalog.Id.CAT], ["demon_lord", FormCatalog.Id.DEMON]]:
		if ShareCard.form_key(int(pair[1])) != str(pair[0]) or Replay.form_key(int(pair[1])) != str(pair[0]):
			push_error("form key for %s drifted" % str(pair[0]))
			failed += 1
		var link := Replay.beat_url(20261101, str(pair[0]))
		if link.find("form=%s" % str(pair[0])) < 0:
			push_error("challenge link should keep %s, got %s" % [str(pair[0]), link])
			failed += 1
	var fields := ShareCard.resolve({
		"form": "slime",
		"rank_reached": 2,
		"time": "0:12",
		"score": 100,
		"killer": "piano",
	})
	if str(fields["form_name"]) != "SLIME" or str(fields["rank_name"]) != "GEL KNIGHT":
		push_error("share card should name the form and the rank reached")
		failed += 1
	if str(fields["time"]) != "0:12" or str(fields["score"]) != "100" or str(fields["killer_label"]) != "PIANO":
		push_error("share card should keep time, score, and the killer label")
		failed += 1
	if str(fields["sprite"]) != "slime_r2.png" or str(fields["gag"]) != "Struck a final chord.":
		push_error("share card should use the reached sprite and the killer's gag")
		failed += 1
	var king := ShareCard.resolve({
		"form": "goblin",
		"rank_reached": 3,
		"time": "1:42",
		"score": 4210,
		"killer": "skeleton_archer",
	})
	if str(king["rank_name"]) != "GOBLIN KING" or str(king["killer_label"]) != "ARCHER" or str(king["gag"]) != "The crown fell off.":
		push_error("goblin rank 3 should read GOBLIN KING, died to ARCHER")
		failed += 1
	var low := ShareCard.render_base({
		"form": "slime",
		"rank_reached": 1,
		"time": "0:05",
		"score": 100,
		"killer": "floating_eye",
	})
	var high := ShareCard.render_base({
		"form": "slime",
		"rank_reached": 1,
		"time": "0:05",
		"score": 9999,
		"killer": "floating_eye",
	})
	if low.get_width() != 270 or PixelFont.checksum(low) == PixelFont.checksum(high):
		push_error("the score field should change the card")
		failed += 1
	var exported := ShareCard.render({
		"form": "goblin",
		"rank_reached": 3,
		"time": "1:42",
		"score": 4210,
		"killer": "skeleton_archer",
	})
	if exported.get_width() != 1080 or exported.get_height() != 1080:
		push_error("share card should export at 1080")
		failed += 1
	return failed

func _check_icons() -> int:
	var failed := 0
	var project := FileAccess.get_file_as_string("res://project.godot")
	if project.find("res://app_icon/app_icon_1024.png") < 0:
		push_error("the project icon should be the 1024 app icon")
		failed += 1
	var icon := load("res://app_icon/app_icon_1024.png") as Texture2D
	var touch := load("res://app_icon/app_icon_180.png") as Texture2D
	var favicon := load("res://app_icon/app_icon_64.png") as Texture2D
	var pwa := load("res://app_icon/app_icon_512.png") as Texture2D
	var pwa_small := load("res://app_icon/app_icon_144.png") as Texture2D
	if icon == null or icon.get_width() != 1024 or touch == null or touch.get_width() != 180:
		push_error("app icon or apple-touch icon is the wrong size")
		failed += 1
	if favicon == null or favicon.get_width() != 64 or pwa == null or pwa.get_width() != 512 or pwa_small == null or pwa_small.get_width() != 144:
		push_error("favicon or PWA icon is the wrong size")
		failed += 1
	var shell := FileAccess.get_file_as_string("res://web/shell.html")
	if shell.find("apple-touch-icon.png") < 0 or shell.find("shareRunCard") < 0:
		push_error("the web shell should link the apple touch icon and the share helper")
		failed += 1
	return failed

func _check_evolve_play() -> int:
	var failed := 0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game._begin_play()
	var before := float(game.elapsed)
	game.evo_points = int(FormCatalog.rank_gates()[0]) - 1
	game._gain_skill(1)
	if int(game.rank_index) != 1 or game._player.fx_mode != "glow" or not game._player.fx_show_rim:
		push_error("ranking up should open on the gold rim glow")
		failed += 1
	if game._player.evolve_old == game._player.evolve_new:
		push_error("the glow should still show the previous sprite")
		failed += 1
	var saw_flash := false
	var saw_pop := false
	for _i in 200:
		game._process(1.0 / 60.0)
		if game._player.fx_mode == "flash":
			saw_flash = true
		if game._player._evolve_fx != null and game._player._evolve_fx.sheet == "fx/fx_evolved_pop.png" and game._player._evolve_fx.playing:
			saw_pop = true
		if game._player.evolve_t < 0.0 and saw_pop:
			break
	if not saw_flash or not saw_pop:
		push_error("evolve should flash the new silhouette and then hold EVOLVED!")
		failed += 1
	if int(game.phase) != 1 or float(game.elapsed) <= before:
		push_error("an evolve should leave the run running")
		failed += 1
	for item in game._combat.items:
		if str(item["text"]).find("EVOLVED") >= 0:
			push_error("the old EVOLVED! text should be gone")
			failed += 1
			break
	root.remove_child(game)
	game.free()
	var final_run := packed.instantiate()
	final_run.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(final_run)
	final_run._begin_play()
	final_run._player.set_rank(3)
	final_run.rank_index = 3
	final_run.evo_points = int(FormCatalog.rank_gates()[3]) - 1
	final_run._gain_skill(1)
	if int(final_run.rank_index) != 4 or not final_run._player.evolve_final:
		push_error("the last gate should open the final evolve")
		failed += 1
	if Difficulty.FINAL_SLOWMO_SECONDS < 0.5 or Difficulty.FINAL_SLOWMO_SECONDS > 0.8:
		push_error("final form slow-mo should last about 0.5 to 0.8 s")
		failed += 1
	if absf(final_run._slow_left - Difficulty.FINAL_SLOWMO_SECONDS) > 0.001 or absf(Difficulty.FINAL_SLOWMO_SCALE - 0.4) > 0.001:
		push_error("rank 5 should slow to 0.4x")
		failed += 1
	if final_run._final_flash <= 0.0:
		push_error("rank 5 should flash the screen")
		failed += 1
	if final_run._shake_left <= 0.0 or absf(final_run._sound.last_gain_db - Difficulty.FINAL_STING_DB) > 0.01:
		push_error("rank 5 should shake and play the evolve sting louder")
		failed += 1
	if absf(final_run._player.evolve_hold - Difficulty.FINAL_HOLD) > 0.001 or Difficulty.FINAL_HOLD <= FxTimeline.EVOLVE_HOLD:
		push_error("rank 5 should hold FINAL FORM! longer than a normal evolve")
		failed += 1
	root.remove_child(final_run)
	final_run.free()
	return failed

func _check_motion() -> int:
	var failed := 0
	var ship := PlayerShip.new()
	ship.setup(FormCatalog.Id.SLIME, Vector2(80, 80))
	for id in FormCatalog.IDS:
		ship.form_id = id
		ship.rank_index = 4
		ship._recoil = 0.0
		ship._recoil_lock = 0.0
		ship._clunk = 0.0
		ship._dash_flick = 0.0
		ship._pose = 0.0
		ship._wobble = 0.2
		var early: Dictionary = ship.cosmetic_pose()
		ship._wobble = 1.1
		var later: Dictionary = ship.cosmetic_pose()
		var early_offset: Vector2 = early["offset"]
		var later_offset: Vector2 = later["offset"]
		var early_scale: Vector2 = early["scale"]
		var later_scale: Vector2 = later["scale"]
		var shifted := early_offset.distance_to(later_offset) > 0.2 or absf(float(early["rotation"]) - float(later["rotation"])) > 0.01 or absf(early_scale.x - later_scale.x) > 0.01
		if not shifted:
			push_error("%s rank 5 should keep moving while it stands still" % FormCatalog.display_name(id))
			failed += 1
		if later_offset.length() > 3.2:
			push_error("%s motion should stay within a couple of pixels, got %s" % [FormCatalog.display_name(id), later_offset])
			failed += 1
		var hurt: Dictionary = ship.hurt_draw_pose()
		var hurt_offset: Vector2 = hurt["offset"]
		var hurt_scale: Vector2 = hurt["scale"]
		var fitted := FormCatalog.play_scale(id)
		if hurt_offset.length() > 0.001 or absf(float(hurt["rotation"])) > 0.001 or hurt_scale.distance_to(Vector2(fitted, fitted)) > 0.001:
			push_error("%s hurt overlay should stay on the collision" % FormCatalog.display_name(id))
			failed += 1
	ship.form_id = FormCatalog.Id.SLIME
	ship._pose = 0.0
	ship._wobble = 0.0
	ship._recoil = 0.0
	ship._recoil_lock = 0.0
	var rested: Vector2 = ship.cosmetic_pose()["offset"]
	var held := ship.position
	var held_radius := ship.radius
	ship.note_shot()
	var kicked: Vector2 = ship.cosmetic_pose()["offset"]
	if kicked.x > rested.x - 0.8 or ship.position.distance_to(held) > 0.001 or absf(ship.radius - held_radius) > 0.001:
		push_error("a shot should kick the sprite back without moving the hurt circle")
		failed += 1
	ship._recoil = 0.25
	ship.note_shot()
	if absf(ship._recoil - 0.25) > 0.001:
		push_error("rapid fire should not restart the recoil kick")
		failed += 1
	ship._recoil_lock = 0.0
	ship.note_shot()
	if absf(ship._recoil - 1.0) > 0.001:
		push_error("a shot after the lockout should kick again")
		failed += 1
	ship.form_id = FormCatalog.Id.GOBLIN
	ship._recoil = 0.0
	ship.sprinting = true
	ship._pose = 1.0
	ship._wobble = PI / (2.0 * PlayerShip.GOBLIN_HOP_RATE)
	var hop: Vector2 = ship.cosmetic_pose()["offset"]
	ship.sprinting = false
	var plant: Vector2 = ship.cosmetic_pose()["offset"]
	ship._pose = 0.0
	ship._wobble = PI / (2.0 * PlayerShip.GOBLIN_IDLE_RATE)
	var goblin_idle: Vector2 = ship.cosmetic_pose()["offset"]
	if absf(hop.y + PlayerShip.GOBLIN_HOP_PX) > 0.05 or absf(plant.y + PlayerShip.GOBLIN_PLANT_PX) > 0.05 or absf(absf(goblin_idle.y) - PlayerShip.GOBLIN_IDLE_PX) > 0.05:
		push_error("goblin should hop while moving and bob while idle, got %s %s %s" % [hop, plant, goblin_idle])
		failed += 1
	ship.form_id = FormCatalog.Id.VENDING
	ship._pose = 0.0
	ship._wobble = 0.0
	ship._recoil = 0.0
	ship._clunk = 1.0
	var clunk: Dictionary = ship.cosmetic_pose()
	var clunk_offset: Vector2 = clunk["offset"]
	if clunk_offset.y < PlayerShip.VENDING_CLUNK_PX - 0.05 or absf(float(clunk["rotation"]) - PlayerShip.VENDING_CLUNK_TILT) > 0.01:
		push_error("vending machine should clunk when it settles")
		failed += 1
	ship.form_id = FormCatalog.Id.CAT
	ship.position = Vector2(100, 100)
	ship.aim = Vector2(150, 60)
	ship._blink_cd = 0.0
	ship._dash_flick = 0.0
	ship._recoil = 0.0
	ship._pose = 0.0
	ship._wobble = 0.0
	ship._clunk = 0.0
	var cat_radius := ship.radius
	ship._try_blink(0.016)
	var cat_pose: Dictionary = ship.cosmetic_pose()
	var cat_offset: Vector2 = cat_pose["offset"]
	if ship._dash_flick < 0.99 or absf(float(cat_pose["rotation"])) < 0.05 or cat_offset.length() > 2.2 or absf(ship.radius - cat_radius) > 0.01:
		push_error("cat should flick into a dash without resizing the hurt circle")
		failed += 1
	ship.form_id = FormCatalog.Id.DEMON
	ship._dash_flick = 0.0
	ship._recoil = 0.0
	ship._wobble = PI / (2.0 * PlayerShip.DEMON_FLOAT_RATE)
	ship._pose = 0.0
	var demon_idle: Vector2 = ship.cosmetic_pose()["offset"]
	ship._pose = 1.0
	var demon_move: Vector2 = ship.cosmetic_pose()["offset"]
	var demon_scale: Vector2 = ship.cosmetic_pose()["scale"]
	if absf(demon_idle.y - PlayerShip.DEMON_IDLE_PX) > 0.05 or absf(demon_move.y - PlayerShip.DEMON_MOVE_PX) > 0.05 or demon_move.y <= demon_idle.y:
		push_error("demon lord should hover, and float a little more while moving")
		failed += 1
	if absf(demon_scale.x - FormCatalog.DEMON_PLAY_SCALE) > 0.001 or absf(demon_scale.y - FormCatalog.DEMON_PLAY_SCALE) > 0.001:
		push_error("demon lord should stay at 0.75 play scale")
		failed += 1
	var previous_hurt := 0.0
	for rank in 5:
		var sprite := str(FormCatalog.rank_spec(FormCatalog.Id.VENDING, rank)["sprite"])
		var hurt_radius := HitLibrary.bounds_radius(sprite, "hurt")
		if rank > 0 and hurt_radius + 0.05 < previous_hurt:
			push_error("vending rank %d hurtbox shrank (%.2f -> %.2f)" % [rank + 1, previous_hurt, hurt_radius])
			failed += 1
		previous_hurt = hurt_radius
	ship.free()
	return failed

func _check_audio() -> int:
	var failed := 0
	var text := FileAccess.get_file_as_string("res://audio/manifest.json")
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("audio manifest did not parse")
		return 1
	var by_file := {}
	for item in parsed:
		var entry: Dictionary = item
		by_file[str(entry["file"])] = entry
		if not FileAccess.file_exists("res://audio/" + str(entry["file"])):
			# The reborn tease ships as ogg only. The wav is the same sting, much larger.
			if str(entry["file"]) == "sting_reborn_tease.wav":
				continue
			push_error("missing audio file %s" % str(entry["file"]))
			failed += 1
	if FileAccess.file_exists("res://audio/sting_reborn_tease.wav"):
		push_error("reborn tease should be the ogg, not the wav")
		failed += 1
	var tease := FileAccess.open("res://audio/sting_reborn_tease.ogg", FileAccess.READ)
	if tease == null or tease.get_length() > 40000:
		push_error("reborn tease ogg should stay the small web file")
		failed += 1
	if tease != null:
		tease.close()
	for event in AudioCues.all_events():
		var data := AudioCues.spec(event)
		var file_name := str(data["file"]).get_file()
		if not by_file.has(file_name):
			push_error("cue %s is not in the audio manifest" % event)
			failed += 1
			continue
		var entry: Dictionary = by_file[file_name]
		if absf(float(entry["lufs"]) - float(data["lufs"])) > 0.05:
			push_error("cue %s lufs drifted from the manifest" % event)
			failed += 1
		if str(data["bus"]) != AudioCues.MUSIC_BUS and str(data["bus"]) != AudioCues.SFX_BUS:
			push_error("cue %s is not on Music or SFX" % event)
			failed += 1
	var shot: Dictionary = by_file["sfx_shot_slime.wav"]
	var pop: Dictionary = by_file["sfx_enemy_pop.wav"]
	if absf((float(pop["lufs"]) - float(shot["lufs"])) - 3.0) > 0.05:
		push_error("slime shot should sit 3 LU under the pop")
		failed += 1
	if absf(float(shot["duration"]) - AudioCues.SHOT_DURATION) > 0.001:
		push_error("shot duration should match the manifest")
		failed += 1
	if not bool(by_file["music_gameplay_loop.ogg"]["loop"]):
		push_error("gameplay music should loop")
		failed += 1
	var music_notes := str(by_file["music_gameplay_loop.ogg"]["notes"])
	if music_notes.find("loop_offset=0") < 0 and music_notes.find("loop_offset = 0") < 0:
		push_error("music notes should keep loop_offset at 0")
		failed += 1
	if str(by_file["sfx_evolve.wav"]["notes"]).find("0.42") < 0:
		push_error("evolve notes should keep the 0.42 s hit")
		failed += 1
	# The frame-11 note lives on the wav entry. The ogg is the same sting.
	if str(by_file["sting_reborn_tease.wav"]["notes"]).find("f11") < 0:
		push_error("tease notes should keep the frame 11 start")
		failed += 1
	if AudioCues.shot_event_for_form(FormCatalog.Id.SLIME) != "slime_shot":
		push_error("slime auto-fire should use the slime shot")
		failed += 1
	var shot_for_form := {
		FormCatalog.Id.GOBLIN: "goblin_shot",
		FormCatalog.Id.VENDING: "vending_machine_shot",
		FormCatalog.Id.CAT: "cat_shot",
		FormCatalog.Id.DEMON: "demon_lord_shot",
	}
	for form_id in shot_for_form:
		var shot_name := str(shot_for_form[form_id])
		if AudioCues.shot_event_for_form(form_id) != shot_name:
			push_error("%s should use %s" % [FormCatalog.display_name(form_id), shot_name])
			failed += 1
		var shot_spec := AudioCues.spec(shot_name)
		var slime_spec := AudioCues.spec("slime_shot")
		for key in ["polyphony", "volume_db", "min_interval", "pitch_ratio"]:
			if absf(float(shot_spec[key]) - float(slime_spec[key])) > 0.001:
				push_error("%s should keep the slime shot %s" % [shot_name, key])
				failed += 1
		if not bool(shot_spec.get("optional", false)):
			push_error("%s should skip a missing file" % shot_name)
			failed += 1
		if not FileAccess.file_exists(str(shot_spec["file"])):
			push_error("%s wav should be in the project" % shot_name)
			failed += 1
	for id in FormCatalog.IDS:
		var reveal := AudioCues.reveal_event_for_card(FormCatalog.title_card(id))
		if id == FormCatalog.Id.VENDING:
			if reveal != "reveal_vending_machine":
				push_error("the vending machine card should play its sting")
				failed += 1
		elif reveal != "":
			push_error("only the vending machine card plays a reveal sting")
			failed += 1
	if AudioCues.reveal_event_for_card(AudioCues.VENDING_TITLE) != "reveal_vending_machine":
		push_error("vending machine title card should map to its sting")
		failed += 1
	var tease_at := AudioCues.death_event_seconds("reborn_tease")
	var death_at := AudioCues.death_event_seconds("player_death")
	if absf(death_at) > 0.0001 or FxTimeline.death_stage(death_at) != "hit":
		push_error("death sting should start at frame 0")
		failed += 1
	if absf(tease_at - float(FxTimeline.DEATH_FRAMES) / FxTimeline.FPS) > 0.0001 or FxTimeline.death_stage(tease_at) != "tease":
		push_error("tease sting should start at death frame 11")
		failed += 1
	if absf(tease_at - float(by_file["sfx_death.wav"]["duration"])) > 0.01:
		push_error("tease should start as the 0.92 s death sting ends")
		failed += 1
	if FxTimeline.evolve_stage(0.0) != "glow":
		push_error("evolve sting should start on frame 0")
		failed += 1
	var hit_frame := int(floor(AudioCues.EVOLVE_HIT_SECONDS * FxTimeline.FPS + 0.0001))
	if hit_frame != 5 or FxTimeline.evolve_stage(AudioCues.EVOLVE_HIT_SECONDS) != "pop":
		push_error("evolve hit at 0.42 s should land on the EVOLVED! pop")
		failed += 1
	var heard: Array[String] = []
	var prev := ""
	var death_t := -1.0
	var heard_tease := -1.0
	var t := 0.0
	while t < 3.0:
		var stage := FxTimeline.death_stage(t)
		for cue in AudioCues.cues_for_death_transition(prev, stage):
			heard.append(str(cue))
			if str(cue) == "player_death":
				death_t = t
			if str(cue) == "reborn_tease":
				heard_tease = t
		prev = stage
		t += 1.0 / 60.0
	if heard.size() != 2 or heard[0] != "player_death" or heard[1] != "reborn_tease":
		push_error("death timeline cues were %s" % str(heard))
		failed += 1
	if absf(death_t) > 0.0001 or absf(heard_tease - tease_at) > 0.0001:
		push_error("death cues fired at %s and %s" % [death_t, heard_tease])
		failed += 1
	var stress := AudioCues.simulate_burst(AudioCues.SHOT_STRESS_RATE, AudioCues.SHOT_DURATION, AudioCues.SHOT_POLYPHONY, 1.0)
	if int(stress["stolen"]) != 0 or int(stress["max_active"]) > AudioCues.SHOT_POLYPHONY:
		push_error("an 8/s shot burst should fit in the polyphony cap")
		failed += 1
	var rank3_rate := 1.0 / float(FormCatalog.rank_spec(FormCatalog.Id.SLIME, 2)["fire_interval"])
	var rank3 := AudioCues.simulate_burst(rank3_rate, AudioCues.SHOT_DURATION, AudioCues.SHOT_POLYPHONY, 1.0)
	if int(rank3["stolen"]) != 0:
		push_error("slime rank 3 should not chop the shot sound")
		failed += 1
	if AudioCues.SHOT_POLYPHONY > 4 or AudioCues.overlap_voices(AudioCues.SHOT_STRESS_RATE, AudioCues.SHOT_DURATION) > AudioCues.SHOT_POLYPHONY:
		push_error("shot polyphony should stay a small cap over the 8/s burst")
		failed += 1
	if absf(AudioCues.semitone_to_pitch(0.0) - 1.0) > 0.0001 or absf(AudioCues.semitone_to_pitch(12.0) - 2.0) > 0.001:
		push_error("semitone pitch should be 2^(n/12)")
		failed += 1
	if absf(AudioCues.shot_pitch_scale(0.0) - 0.92) > 0.0001 or absf(AudioCues.shot_pitch_scale(1.0) - 1.08) > 0.0001 or absf(AudioCues.shot_pitch_scale(0.5) - 1.0) > 0.0001:
		push_error("shot pitch should be +/- 8 percent")
		failed += 1
	if AudioCues.music_playback_type(false) != AudioServer.PLAYBACK_TYPE_STREAM or AudioCues.music_playback_type(true) != AudioServer.PLAYBACK_TYPE_SAMPLE:
		push_error("web music should play as a sample and desktop should stream it")
		failed += 1
	if absf(float(AudioCues.spec("slime_shot")["volume_db"]) - AudioCues.SHOT_VOLUME_DB) > 0.01 or absf(AudioCues.SHOT_VOLUME_DB + 10.0) > 0.01:
		push_error("slime shot should be -10 dB on its player")
		failed += 1
	var gem_spec := AudioCues.spec("gem_pickup")
	var power_spec := AudioCues.spec("power_pickup")
	if int(gem_spec["polyphony"]) != AudioCues.GEM_POLYPHONY or absf(float(gem_spec["min_interval"]) - AudioCues.GEM_MIN_INTERVAL) > 0.001 or not bool(gem_spec.get("pitch_chain", false)):
		push_error("gem pickup should be a short rising chain")
		failed += 1
	if int(power_spec["polyphony"]) != AudioCues.POWER_POLYPHONY or not bool(power_spec.get("optional", false)):
		push_error("power pickup should be one voice and optional")
		failed += 1
	var level_spec := AudioCues.spec("power_level_up")
	if str(level_spec.get("file", "")) != "res://audio/sfx_power_level_up.wav" or bool(level_spec.get("loop", true)) or int(level_spec.get("polyphony", 0)) != 1:
		push_error("power level-up should be one non-looping voice")
		failed += 1
	if absf(float(level_spec.get("volume_db", 0.0))) > 0.01 or absf(float(level_spec.get("lufs", 0.0)) + 19.8) > 0.05:
		push_error("power level-up should keep the mastered file gain")
		failed += 1
	if absf(AudioCues.power_level_pitch(1) - 1.0) > 0.0001 or absf(AudioCues.power_level_pitch(2) - AudioCues.semitone_to_pitch(1.0)) > 0.0001:
		push_error("power pitch should rise one semitone per level above 1")
		failed += 1
	if absf(AudioCues.power_level_pitch(13) - 2.0) > 0.001 or absf(AudioCues.power_level_pitch(40) - AudioCues.power_level_pitch(13)) > 0.0001:
		push_error("power pitch should cap at +12 semitones")
		failed += 1
	var level_entry: Dictionary = by_file.get("sfx_power_level_up.wav", {})
	if bool(level_entry.get("loop", true)):
		push_error("power level-up should not loop")
		failed += 1
	var level_wav := load("res://audio/sfx_power_level_up.wav") as AudioStreamWAV
	if level_wav == null or level_wav.stereo or absf(level_wav.get_length() - float(level_entry.get("duration", -1.0))) > 0.02:
		push_error("power level-up should be the 0.68 s mono file")
		failed += 1
	if absf(AudioCues.gem_chain_semitones(0)) > 0.001 or absf(AudioCues.gem_chain_semitones(7) - 7.0) > 0.001 or absf(AudioCues.gem_chain_semitones(9) - 7.0) > 0.001:
		push_error("gem pitch should rise one semitone and cap at +7")
		failed += 1
	var missing := {"file": "res://audio/sfx_shot_does_not_exist.wav", "optional": true}
	var required := {"file": "res://audio/sfx_shot_does_not_exist.wav", "optional": false}
	if AudioCues.should_report_missing(missing) or not AudioCues.should_report_missing(required):
		push_error("a missing optional cue should be skipped and a required one reported")
		failed += 1
	if absf(AudioCues.SHOT_MIN_INTERVAL - 0.25) > 0.001:
		push_error("shot sfx should be capped at about 4 per second")
		failed += 1
	var down := AudioCues.pop_semitones(0.0, 0.0)
	var up := AudioCues.pop_semitones(1.0, 1.0)
	if down < -2.0 or down > -1.0 or up < 1.0 or up > 2.0:
		push_error("pop pitch should be 1 to 2 semitones either way")
		failed += 1
	var settings := "user://audio_smoke_unit.cfg"
	AudioCues.write_enabled(false, settings)
	if AudioCues.read_enabled(settings):
		push_error("sound off should persist")
		failed += 1
	AudioCues.write_enabled(true, settings)
	if not AudioCues.read_enabled(settings) or not AudioCues.read_enabled("user://audio_missing_nope.cfg"):
		push_error("sound should default on and remember on")
		failed += 1
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings))
	AudioCues.apply_bus_levels()
	var music_idx := AudioServer.get_bus_index(AudioCues.MUSIC_BUS)
	var sfx_idx := AudioServer.get_bus_index(AudioCues.SFX_BUS)
	if music_idx < 0 or sfx_idx < 0 or music_idx == sfx_idx:
		push_error("Music and SFX should be separate buses")
		failed += 1
	elif absf(AudioServer.get_bus_volume_db(music_idx) - AudioCues.MUSIC_BUS_DB) > 0.01 or absf(AudioServer.get_bus_volume_db(sfx_idx) - AudioCues.SFX_BUS_DB) > 0.01:
		push_error("Music should sit at -6 dB and SFX at -12 dB so the loop is above the stings")
		failed += 1
	elif AudioServer.get_bus_volume_db(music_idx) <= AudioServer.get_bus_volume_db(sfx_idx):
		push_error("the music bus should be louder than the SFX bus")
		failed += 1
	elif str(AudioServer.get_bus_send(music_idx)) != "Master" or str(AudioServer.get_bus_send(sfx_idx)) != "Master":
		push_error("Music and SFX should send to Master")
		failed += 1
	var music := load("res://audio/music_gameplay_loop.ogg") as AudioStreamOggVorbis
	AudioCues.prepare_stream(music, "gameplay_music")
	if music == null or not music.loop or absf(music.loop_offset) > 0.001:
		push_error("gameplay music should loop from offset 0")
		failed += 1
	elif absf(music.get_length() - float(by_file["music_gameplay_loop.ogg"]["duration"])) > 0.05:
		push_error("music length should match the manifest, got %s" % music.get_length())
		failed += 1
	var death := load("res://audio/sfx_death.wav") as AudioStream
	if death == null or absf(death.get_length() - float(by_file["sfx_death.wav"]["duration"])) > 0.02:
		push_error("death sting should be the 0.92 s file")
		failed += 1
	var shell := FileAccess.get_file_as_string("res://web/shell.html")
	if shell.find("unlockGodotAudio") < 0 or shell.find("GodotAudio.ctx") < 0 or shell.find("__godotAudioGesture") < 0:
		push_error("the web shell should resume audio on the first tap")
		failed += 1
	if shell.find("__godotAudioCtx") < 0 or shell.find("__godotAudioState") < 0 or shell.find("visibilitychange") < 0 or shell.find("__godotMusicSources") < 0:
		push_error("the web shell should publish the audio context, because GodotAudio is not a page global")
		failed += 1
	var readme := FileAccess.get_file_as_string("res://audio/README.md")
	if readme.find("TEST") < 0:
		push_error("audio README should mark the files as test assets")
		failed += 1
	return failed

func _check_audio_play() -> int:
	var failed := 0
	AudioCues.write_enabled(true)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	if game._sound == null or game._sound_button == null or game._sound_label == null:
		push_error("the run should build the sound rig and the toggle")
		root.remove_child(game)
		game.free()
		AudioCues.write_enabled(true)
		return 1
	var step := 1.0 / 60.0
	if DisplayServer.get_name() != "headless" and not game._sound.music_is_playing():
		push_error("gameplay music should start with the run")
		failed += 1
	var ogg := game._sound.music_stream() as AudioStreamOggVorbis
	if ogg == null or not ogg.loop or absf(ogg.loop_offset) > 0.001:
		push_error("the playing music should loop from the start")
		failed += 1
	var music_player: AudioStreamPlayer = game._sound.player_for("gameplay_music")
	var shot_player: AudioStreamPlayer = game._sound.player_for("slime_shot")
	if music_player == null or shot_player == null:
		push_error("music and slime shot players should exist")
		failed += 1
	elif str(music_player.bus) != AudioCues.MUSIC_BUS or str(shot_player.bus) != AudioCues.SFX_BUS:
		push_error("music and shots should use their own buses")
		failed += 1
	elif absf(music_player.volume_db) > 0.01 or absf(shot_player.volume_db - AudioCues.SHOT_VOLUME_DB) > 0.01:
		push_error("the shot player should be -10 dB and music should stay on the bus")
		failed += 1
	elif shot_player.max_polyphony != AudioCues.SHOT_POLYPHONY:
		push_error("slime shot polyphony should be capped at %d" % AudioCues.SHOT_POLYPHONY)
		failed += 1
	elif music_player.playback_type != AudioCues.music_playback_type(OS.has_feature("web")):
		push_error("music playback should stream on desktop and sample on the web")
		failed += 1
	for _i in 100:
		game._process(step)
	game.invuln = 30.0
	game._player.invulnerable = true
	if game._sound_button == null or not game._sound_button.visible:
		push_error("the sound toggle should sit on screen during play")
		failed += 1
	else:
		var pause_rect := Rect2(game._pause_button.position, game._pause_button.size)
		var sound_rect := Rect2(game._sound_button.position, game._sound_button.size)
		if pause_rect.intersects(sound_rect):
			push_error("the sound toggle should not cover the pause target")
			failed += 1
		if sound_rect.size.x + 0.01 < 44.0 or absf(sound_rect.position.x - pause_rect.position.x) > 0.01:
			push_error("the sound toggle should match the pause target and line up under it")
			failed += 1
		if sound_rect.position.y < pause_rect.end.y or sound_rect.position.y - pause_rect.end.y > 8.0:
			push_error("the sound toggle should sit just under pause")
			failed += 1
		if game._sound_label.text != "SND":
			push_error("sound on should read SND")
			failed += 1
		if game._audio_blocked_button == null or game._audio_blocked_icon == null:
			push_error("the speaker-off mark should be built")
			failed += 1
		elif game._audio_blocked_button.visible or game._sound.output_blocked:
			push_error("the speaker-off mark stays hidden when web audio is not locked")
			failed += 1
		else:
			var blocked_rect := Rect2(game._audio_blocked_button.position, game._audio_blocked_button.size)
			if blocked_rect.intersects(pause_rect) or blocked_rect.intersects(sound_rect):
				push_error("the speaker-off mark should not cover pause or SND")
				failed += 1
			if blocked_rect.position.y + 0.01 < sound_rect.end.y or blocked_rect.position.y - sound_rect.end.y > 8.0:
				push_error("the speaker-off mark should sit just under SND")
				failed += 1
			if absf(blocked_rect.position.x - pause_rect.position.x) > 0.01 or blocked_rect.size.x + 0.01 < 44.0:
				push_error("the speaker-off mark should match the pause target")
				failed += 1
	var music_nodes := 0
	for child in game._sound.get_children():
		if str(child.name) == "gameplay_music":
			music_nodes += 1
	game._sound.start_gameplay_music()
	if music_nodes != 1:
		push_error("a run should keep a single music player")
		failed += 1
	# Headless never calls play(), so stream_paused does not latch. The web
	# probe checks that pause actually stops the buffer source.
	var elapsed_before := float(game.elapsed)
	game._toggle_sound()
	if game._paused or game._sound.enabled or game._sound_label.text != "OFF":
		push_error("SND should mute without pausing")
		failed += 1
	if not AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioCues.SFX_BUS)) or not AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioCues.MUSIC_BUS)):
		push_error("sound off should mute Music and SFX")
		failed += 1
	game._process(step)
	if absf(float(game.elapsed) - elapsed_before) < 0.001:
		push_error("muting should not freeze the run")
		failed += 1
	var ship_before: Vector2 = game._player.position
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = game._sound_button.position + Vector2(2, 2)
	game._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(30, -20)
	drag.position = touch.position + drag.relative
	game._input(drag)
	game._process(step)
	if game._player.position.distance_to(ship_before) > 8.0:
		push_error("a sound-toggle touch should not drag the ship")
		failed += 1
	game._toggle_sound()
	if not game._sound.enabled or AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioCues.SFX_BUS)):
		push_error("sound on should unmute")
		failed += 1
	var remembered := packed.instantiate()
	remembered.process_mode = Node.PROCESS_MODE_DISABLED
	AudioCues.write_enabled(false)
	root.add_child(remembered)
	if remembered._sound.enabled:
		push_error("a new run should remember sound off")
		failed += 1
	remembered._sound.set_enabled(true)
	root.remove_child(remembered)
	remembered.free()
	game.form_id = FormCatalog.Id.GOBLIN
	game._player.form_id = FormCatalog.Id.GOBLIN
	game._sound.played.clear()
	game._sound._shot_lockout = 0.0
	game._player._cooldown = 0.0
	game._process(step)
	if game._sound.play_count("slime_shot") != 0 or game._sound.play_count("goblin_shot") != 1:
		push_error("goblin fire should play the goblin shot, not the slime bloop")
		failed += 1
	for form_id in [FormCatalog.Id.VENDING, FormCatalog.Id.CAT, FormCatalog.Id.DEMON]:
		var event_name := AudioCues.shot_event_for_form(form_id)
		game.form_id = form_id
		game._player.form_id = form_id
		game._sound.played.clear()
		game._sound._shot_lockout = 0.0
		game._player._cooldown = 0.0
		game._process(step)
		if game._sound.play_count(event_name) != 1 or game._sound.play_count("slime_shot") != 0:
			push_error("%s fire should play %s once" % [FormCatalog.display_name(form_id), event_name])
			failed += 1
		var form_shot: AudioStreamPlayer = game._sound.player_for(event_name)
		if form_shot == null or absf(form_shot.volume_db - AudioCues.SHOT_VOLUME_DB) > 0.01 or form_shot.max_polyphony != AudioCues.SHOT_POLYPHONY:
			push_error("%s should be armed at -10 dB with polyphony %d" % [event_name, AudioCues.SHOT_POLYPHONY])
			failed += 1
	game.form_id = FormCatalog.Id.SLIME
	game._player.form_id = FormCatalog.Id.SLIME
	game._player._cooldown = 0.0
	game._sound._shot_lockout = 0.0
	game._sound.played.clear()
	game._process(step)
	if game._sound.play_count("slime_shot") != 1:
		push_error("slime auto-fire should play one bloop per volley")
		failed += 1
	game._player.set_rank(2)
	game.rank_index = 2
	game._player._cooldown = 0.0
	game._sound._shot_lockout = 0.0
	game._sound.played.clear()
	game._process(step)
	if FormCatalog.player_shots(FormCatalog.Id.SLIME, Vector2.ZERO, 2).size() != 3 or game._sound.play_count("slime_shot") != 1:
		push_error("a rank 3 triple should play one bloop for the volley, not one per bullet")
		failed += 1
	game._sound.play_event("slime_shot")
	if game._sound.play_count("slime_shot") != 1:
		push_error("a second shot inside the rate limit should stay silent")
		failed += 1
	game._sound._process(AudioCues.SHOT_MIN_INTERVAL)
	game._sound.play_event("slime_shot")
	if game._sound.play_count("slime_shot") != 2:
		push_error("a shot after 0.25 s should be allowed (about 4 per second)")
		failed += 1
	for _i in 8:
		game._sound.play_event("slime_shot")
	if game._sound.player_for("slime_shot").max_polyphony != AudioCues.SHOT_POLYPHONY:
		push_error("the 8/s burst should stay on the capped player")
		failed += 1
	var enemy := EnemyActor.new()
	enemy.position = Vector2(120, 80)
	enemy.score_value = 50
	game._sound.played.clear()
	game._award_kill(enemy)
	enemy.free()
	if game._sound.play_count("enemy_killed") != 1:
		push_error("a kill should play the pop")
		failed += 1
	game._sound.played.clear()
	game._player.set_rank(0)
	game.rank_index = 0
	game.evo_points = int(FormCatalog.rank_gates()[0]) - 1
	game._gain_skill(1)
	if game._sound.play_count("evolve") != 1 or game._player.evolve_t > 0.02:
		push_error("evolve sting should start once, on frame 0")
		failed += 1
	var hit := AudioCues.EVOLVE_HIT_SECONDS
	var evolve_guard := 0
	while game._player.evolve_t >= 0.0 and game._player.evolve_t < hit and evolve_guard < 90:
		game._process(step)
		evolve_guard += 1
	if game._player._evolve_fx == null or game._player._evolve_fx.sheet != "fx/fx_evolved_pop.png" or not game._player._evolve_fx.playing:
		push_error("the evolve hit should land on the EVOLVED! pop")
		failed += 1
	if game._sound.play_count("evolve") != 1:
		push_error("the evolve sting should not retrigger on the pop")
		failed += 1
	game._sound.played.clear()
	game._kill_player("Anvil")
	if game._sound.play_count("player_death") != 1 or game._sound.play_count("reborn_tease") != 0:
		push_error("death should start the death sting and wait for the tease")
		failed += 1
	var tease_heard := -1.0
	for _i in 400:
		if game._sound.play_count("reborn_tease") > 0:
			tease_heard = float(game.death_elapsed)
			break
		game._process(step)
	if tease_heard < 0.0 or absf(tease_heard - AudioCues.death_event_seconds("reborn_tease")) > step + 0.0001:
		push_error("reborn tease should start at frame 11, heard at %s" % tease_heard)
		failed += 1
	game._sound.played.clear()
	game._sound.play_title_card(FormCatalog.title_card(FormCatalog.Id.SLIME))
	game._sound.play_title_card(FormCatalog.title_card(FormCatalog.Id.GOBLIN))
	if game._sound.play_count("reveal_vending_machine") != 0:
		push_error("slime and goblin cards should not play the vending sting")
		failed += 1
	game._sound.played.clear()
	game._sound._gem_step = 0
	game._sound._gem_quiet = AudioCues.GEM_CHAIN_RESET
	game._sound._gaps.clear()
	var gem := LootGem.new()
	gem.setup("gem.png")
	game.add_child(gem)
	var loot_before := int(game.loot_count)
	game._collect_gem(gem)
	if game._sound.play_count("gem_pickup") != 1 or int(game.loot_count) != loot_before + 1:
		push_error("picking up a gem should play the gem cue")
		failed += 1
	if absf(game._sound.last_pitch_scale - 1.0) > 0.001:
		push_error("the first gem in a chain should stay at the recorded pitch")
		failed += 1
	for step_i in 7:
		game._sound._process(0.06)
		game._sound.play_event("gem_pickup")
		var expect := AudioCues.semitone_to_pitch(float(step_i + 1))
		if absf(game._sound.last_pitch_scale - expect) > 0.001:
			push_error("gem %d should be +%d semitones" % [step_i + 2, step_i + 1])
			failed += 1
			break
	game._sound._process(0.06)
	game._sound.play_event("gem_pickup")
	if absf(game._sound.last_pitch_scale - AudioCues.semitone_to_pitch(7.0)) > 0.001:
		push_error("a long gem chain should cap at +7 semitones")
		failed += 1
	var chained := int(game._sound.play_count("gem_pickup"))
	game._sound.play_event("gem_pickup")
	if game._sound.play_count("gem_pickup") != chained:
		push_error("gems closer than 0.05 s should not retrigger")
		failed += 1
	game._sound._process(AudioCues.GEM_CHAIN_RESET)
	game._sound.play_event("gem_pickup")
	if absf(game._sound.last_pitch_scale - 1.0) > 0.001:
		push_error("the gem chain should reset after 0.6 s of quiet")
		failed += 1
	if game._sound.voice_count("gem_pickup") != AudioCues.GEM_POLYPHONY:
		push_error("gem pickup should have %d voices, found %d" % [AudioCues.GEM_POLYPHONY, game._sound.voice_count("gem_pickup")])
		failed += 1
	game._sound.played.clear()
	var drop := PowerDrop.new()
	drop.setup("overdrive")
	game.add_child(drop)
	game._collect_power(drop)
	if game._sound.play_count("power_pickup") != 1:
		push_error("OVERDRIVE should play the power pickup")
		failed += 1
	var shield := PowerDrop.new()
	shield.setup("shield")
	game.add_child(shield)
	game._collect_power(shield)
	if game._sound.play_count("power_pickup") != 2:
		push_error("a shield drop should play the power pickup too")
		failed += 1
	if game._sound.voice_count("power_pickup") != 1 or game._sound.player_for("power_pickup").max_polyphony != AudioCues.POWER_POLYPHONY:
		push_error("power pickup should be a single voice")
		failed += 1
	game._sound.debug_play_vending_reveal()
	game._sound.play_title_card(AudioCues.VENDING_TITLE)
	if game._sound.play_count("reveal_vending_machine") != 2:
		push_error("the vending sting should play from the debug path and the title card")
		failed += 1
	var vending: AudioStreamPlayer = game._sound.player_for("reveal_vending_machine")
	if vending == null or vending.stream == null or str(vending.bus) != AudioCues.SFX_BUS:
		push_error("the vending sting should be armed on the SFX bus")
		failed += 1
	failed += _check_power_level_cue(game)
	root.remove_child(game)
	game.free()
	AudioCues.write_enabled(true)
	AudioCues.apply_bus_levels()
	return failed

func _check_power_level_cue(game) -> int:
	var failed := 0
	var cue: AudioStreamPlayer = game._sound.player_for("power_level_up")
	if cue == null or cue.stream == null or str(cue.bus) != AudioCues.SFX_BUS or absf(cue.volume_db) > 0.01:
		push_error("power level-up should be armed on the SFX bus at the mastered gain")
		return failed + 1
	game.form_id = FormCatalog.Id.SLIME
	game._player.form_id = FormCatalog.Id.SLIME
	game.rank_index = 4
	game._player.rank_index = 4
	game._player.alive = true
	game.phase = game.PHASE_REVEAL
	game.evo_points = Difficulty.GATE_RANK5
	game._player.power_level = 0
	game._sound.played.clear()
	game._add_evo(Difficulty.power_step_points(1))
	if game._sound.play_count("power_level_up") != 0 or int(game._player.power_level) != 1:
		push_error("power level-up should latch during the reveal and stay silent")
		failed += 1
	game.phase = game.PHASE_PLAY
	game._sync_power()
	if game._sound.play_count("power_level_up") != 0:
		push_error("reaching play at the latched level should not replay the cue")
		failed += 1
	var restored := Difficulty.GATE_RANK5
	for step in 3:
		restored += Difficulty.power_step_points(step + 1)
	game.evo_points = restored
	game._player.power_level = 3
	game._sync_power()
	if game._sound.play_count("power_level_up") != 0 or int(game._player.power_level) != 3:
		push_error("a restore that keeps the same power level should stay silent")
		failed += 1
	game.evo_points = Difficulty.GATE_RANK5
	game._player.power_level = 0
	game._sound.played.clear()
	for n in 3:
		game._add_evo(Difficulty.power_step_points(n + 1))
		var expect := AudioCues.power_level_pitch(n + 1)
		if game._sound.play_count("power_level_up") != n + 1 or int(game._player.power_level) != n + 1:
			push_error("power level %d should play the cue once" % (n + 1))
			failed += 1
			break
		if absf(game._sound.last_pitch_scale - expect) > 0.001:
			push_error("power level %d pitch should be %.4f, got %.4f" % [n + 1, expect, game._sound.last_pitch_scale])
			failed += 1
			break
	var bulk := 0
	for n in range(4, 7):
		bulk += Difficulty.power_step_points(n)
	var before_plays := int(game._sound.play_count("power_level_up"))
	game._add_evo(bulk)
	if game._sound.play_count("power_level_up") != before_plays + 1 or int(game._player.power_level) != 6:
		push_error("a jump of several power levels should play the cue once")
		failed += 1
	elif absf(game._sound.last_pitch_scale - AudioCues.power_level_pitch(6)) > 0.001:
		push_error("a jumped power level should use the pitch of the level it landed on")
		failed += 1
	var cap_bulk := 0
	for n in range(7, 17):
		cap_bulk += Difficulty.power_step_points(n)
	before_plays = int(game._sound.play_count("power_level_up"))
	game._add_evo(cap_bulk)
	if game._sound.play_count("power_level_up") != before_plays + 1 or int(game._player.power_level) != 16:
		push_error("climbing to power 16 should still be one cue")
		failed += 1
	elif absf(game._sound.last_pitch_scale - 2.0) > 0.001:
		push_error("power pitch should stop at +12 semitones (octave)")
		failed += 1
	game.form_id = FormCatalog.Id.DRAGON
	var dragon_before := int(game._player.power_level)
	before_plays = int(game._sound.play_count("power_level_up"))
	game._add_evo(Difficulty.power_step_points(dragon_before + 1))
	if int(game._player.power_level) != dragon_before + 1:
		push_error("dragon form should keep raising Power")
		failed += 1
	elif game._sound.play_count("power_level_up") != before_plays + 1:
		push_error("dragon form still uses Power, so the level-up cue should play")
		failed += 1
	game.form_id = FormCatalog.Id.SLIME
	AudioCues.apply_bus_levels()
	var music_idx := AudioServer.get_bus_index(AudioCues.MUSIC_BUS)
	var sfx_idx := AudioServer.get_bus_index(AudioCues.SFX_BUS)
	var gem: AudioStreamPlayer = game._sound.player_for("gem_pickup")
	if gem == null:
		push_error("gem pickup should still be armed for the duck check")
		return failed + 1
	gem.volume_db = 0.0
	game._sound._gem_duck = 0.0
	game._sound._cue_headroom = 0.0
	game._sound._sync_sfx_guard()
	game._sound.play_event("power_level_up", 0.0, AudioCues.power_level_pitch(4))
	if absf(gem.volume_db - SoundRig.GEM_DUCK_DB) > 0.01 or absf(SoundRig.GEM_DUCK_DB + 5.0) > 0.01 or absf(SoundRig.GEM_DUCK_SECONDS - 0.25) > 0.001:
		push_error("power level-up should duck gems by 5 dB for 0.25 s")
		failed += 1
	game._sound._gaps.erase("gem_pickup")
	var gem_plays := int(game._sound.play_count("gem_pickup"))
	game._sound.play_event("gem_pickup")
	if game._sound.play_count("gem_pickup") != gem_plays + 1 or absf(gem.volume_db - SoundRig.GEM_DUCK_DB) > 0.01:
		push_error("a gem that starts during the duck should play at -5 dB")
		failed += 1
	if absf(AudioServer.get_bus_volume_db(music_idx) - AudioCues.MUSIC_BUS_DB) > 0.01:
		push_error("the power cue should not change the music bus")
		failed += 1
	if absf(AudioServer.get_bus_volume_db(sfx_idx) - (AudioCues.SFX_BUS_DB - SoundRig.RAIN_HEADROOM_DB)) > 0.01:
		push_error("power level-up should borrow the meteor-rain SFX headroom")
		failed += 1
	var limited := false
	for i in AudioServer.get_bus_effect_count(sfx_idx):
		if AudioServer.get_bus_effect(sfx_idx, i) is AudioEffectLimiter:
			limited = true
	if not limited:
		push_error("power level-up should arm the SFX limiter")
		failed += 1
	game._sound._process(SoundRig.GEM_DUCK_SECONDS)
	if absf(gem.volume_db) > 0.01:
		push_error("the gem duck should end after 0.25 s")
		failed += 1
	if absf(AudioServer.get_bus_volume_db(sfx_idx) - AudioCues.SFX_BUS_DB) < 0.5:
		push_error("SFX headroom should outlast the short gem duck")
		failed += 1
	game._sound._process(float(AudioCues.spec("power_level_up").get("duration", 0.68)))
	if absf(AudioServer.get_bus_volume_db(sfx_idx) - AudioCues.SFX_BUS_DB) > 0.01:
		push_error("SFX headroom should end with the power cue")
		failed += 1
	if AudioServer.get_bus_effect_count(sfx_idx) != 0:
		push_error("the SFX limiter should leave with the power cue")
		failed += 1
	if absf(AudioServer.get_bus_volume_db(music_idx) - AudioCues.MUSIC_BUS_DB) > 0.01:
		push_error("music should still sit at -6 dB after the power cue")
		failed += 1
	game._sound.set_meteor_mix(true)
	if absf(AudioServer.get_bus_volume_db(sfx_idx) - (AudioCues.SFX_BUS_DB - SoundRig.RAIN_HEADROOM_DB)) > 0.01:
		push_error("meteor rain should still take the 1.5 dB SFX headroom")
		failed += 1
	game._sound.set_meteor_mix(false)
	if absf(AudioServer.get_bus_volume_db(sfx_idx) - AudioCues.SFX_BUS_DB) > 0.01 or AudioServer.get_bus_effect_count(sfx_idx) != 0:
		push_error("meteor rain should still release the SFX guard")
		failed += 1
	return failed

func _check_cat_swipe() -> int:
	var failed := 0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game.phase = game.PHASE_PLAY
	game.form_id = FormCatalog.Id.CAT
	game._player.form_id = FormCatalog.Id.CAT
	game._player.position = Vector2(40, 140)
	game._player.aim = game._player.position
	game._clear_field()
	var short: Dictionary = FormCatalog.player_shots(FormCatalog.Id.CAT, Vector2(40, 140), 0)[0]
	var short_shot = game._spawn_shot(short, true)
	short_shot.life = 0.0
	short_shot.position = Vector2(40, 140)
	game._sweep(Vector2(480, 270))
	if game._shots.has(short_shot):
		push_error("a rank 1 swipe should still expire when its life runs out")
		failed += 1
	var final_spec: Dictionary = FormCatalog.player_shots(FormCatalog.Id.CAT, Vector2(20, 140), 4)[0]
	var final_shot = game._spawn_shot(final_spec, true)
	if absf(float(final_shot.hit_scale) - 1.25) > 0.001 or not final_shot.exit_right or final_shot.expires or int(final_shot.pierce) != 2 or int(final_shot.damage) != 5:
		push_error("rank 5 swipe should cross the screen at 1.25 scale, pierce 2, and deal 5, scale %s exit %s expires %s pierce %s damage %s" % [final_shot.hit_scale, final_shot.exit_right, final_shot.expires, final_shot.pierce, final_shot.damage])
		failed += 1
	final_shot.position = Vector2(20, 140)
	final_shot.life = -5.0
	game._sweep(Vector2(480, 270))
	if not game._shots.has(final_shot):
		push_error("a rank 5 swipe on the left should not expire by life")
		failed += 1
	else:
		var scale := float(final_shot.hit_scale)
		var art_left := -ArtLibrary.anchor("cat_swipe.png").x * scale
		var hit_left := HitLibrary.horizontal_span("cat_swipe.png", "body").x * scale
		var extent := minf(art_left, hit_left)
		final_shot.position.x = 480.0 - extent - 1.0
		game._sweep(Vector2(480, 270))
		if not game._shots.has(final_shot):
			push_error("a rank 5 swipe still touching the right edge should stay")
			failed += 1
		final_shot.position.x = 480.0 - extent
		game._sweep(Vector2(480, 270))
		if game._shots.has(final_shot):
			push_error("a rank 5 swipe should despawn once it is fully past the right edge")
			failed += 1
	game._clear_field()
	var early: Dictionary = FormCatalog.player_shots(FormCatalog.Id.CAT, Vector2(120, 140), 0)[0]
	var early_shot = game._spawn_shot(early, true)
	var early_hits := 0
	for i in 4:
		var foe := EnemyActor.new()
		foe.id = 10 + i
		foe.kind = SpawnDirector.EYE
		foe.hp = 5
		foe.max_hp = 5
		foe.alive = true
		foe.position = early_shot.position
		foe.score_value = 100
		game.add_child(foe)
		game._enemies.append(foe)
	game._collide()
	for foe in game._enemies:
		if foe.hp < 5:
			early_hits += 1
	if early_hits != 3 or game._shots.has(early_shot):
		push_error("ranks 1-4 should pierce 2 (three hits) and then stop, hits %d shot %s" % [early_hits, game._shots.has(early_shot)])
		failed += 1
	game._clear_field()
	var late: Dictionary = FormCatalog.player_shots(FormCatalog.Id.CAT, Vector2(120, 140), 4)[0]
	var late_shot = game._spawn_shot(late, true)
	var row: Array[EnemyActor] = []
	for i in 4:
		var foe := EnemyActor.new()
		foe.id = 20 + i
		foe.kind = SpawnDirector.EYE
		foe.hp = 8
		foe.max_hp = 8
		foe.alive = true
		foe.position = late_shot.position
		foe.score_value = 100
		game.add_child(foe)
		game._enemies.append(foe)
		row.append(foe)
	game._collide()
	var late_hits := 0
	for foe in row:
		if foe.hp == 8 - int(late["damage"]):
			late_hits += 1
	if late_hits != 3 or game._shots.has(late_shot):
		push_error("rank 5 should pierce 2 (three hits) and then stop, hits %d shot %s" % [late_hits, game._shots.has(late_shot)])
		failed += 1
	game._clear_field()
	var once: Dictionary = FormCatalog.player_shots(FormCatalog.Id.CAT, Vector2(120, 140), 4)[0]
	var once_shot = game._spawn_shot(once, true)
	var target := EnemyActor.new()
	target.id = 30
	target.kind = SpawnDirector.EYE
	target.hp = 8
	target.max_hp = 8
	target.alive = true
	target.position = once_shot.position
	target.score_value = 100
	game.add_child(target)
	game._enemies.append(target)
	game._collide()
	game._collide()
	if target.hp != 8 - int(once["damage"]) or not game._shots.has(once_shot):
		push_error("a rank 5 swipe should hit one target once and keep the rest of its pierce, hp %s shot %s" % [target.hp, game._shots.has(once_shot)])
		failed += 1
	root.remove_child(game)
	game.free()
	return failed

func _check_vending_gem_meter() -> int:
	var failed := 0
	var vending_trait := FormCatalog.trait_line(FormCatalog.Id.VENDING, true)
	if vending_trait.find("Kills and gems fill") < 0 or vending_trait.find("WINNER!") < 0:
		push_error("vending trait should say kills and gems fill the WINNER meter, got %s" % vending_trait)
		failed += 1
	if FormCatalog.weapon_line(FormCatalog.Id.VENDING, 0).find("kills or gems") < 0:
		push_error("vending weapon line should count kills or gems toward WINNER")
		failed += 1
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game.form_id = FormCatalog.Id.VENDING
	game._player.form_id = FormCatalog.Id.VENDING
	game.rank_index = 0
	game.winner = 1
	game.winner_pops = 0
	var victim := EnemyActor.new()
	victim.position = Vector2(300, 120)
	victim.score_value = 40
	victim.hp = 1
	victim.max_hp = 1
	victim.alive = true
	game._award_kill(victim, true)
	victim.free()
	var kill_step := int(game.winner) - 1
	if kill_step != 1:
		push_error("a vending kill should still add one WINNER step, got %s" % game.winner)
		failed += 1
	var gem := LootGem.new()
	gem.setup("gem.png")
	game.add_child(gem)
	game._collect_gem(gem)
	if int(game.winner) != 1 + kill_step * 2:
		push_error("a vending gem should match one kill on the WINNER meter, got %s" % game.winner)
		failed += 1
	var elder := LootGem.new()
	elder.setup(DragonPhase.ELDER_GEM)
	elder.bonus_score = DragonPhase.ELDER_GEM_BONUS
	game.add_child(elder)
	var before_elder := int(game.winner)
	game._collect_gem(elder)
	if int(game.winner) != before_elder + kill_step:
		push_error("an Elder Drake gem should match one kill on the WINNER meter, got %s" % game.winner)
		failed += 1
	var coin := LootGem.new()
	coin.setup("coin.png")
	game.add_child(coin)
	var before_coin := int(game.winner)
	game._collect_gem(coin)
	if int(game.winner) != before_coin:
		push_error("a coin should not fill the WINNER meter, got %s" % game.winner)
		failed += 1
	var shield := PowerDrop.new()
	shield.setup("shield")
	game.add_child(shield)
	var before_power := int(game.winner)
	game._collect_power(shield)
	if int(game.winner) != before_power:
		push_error("a powerup should not fill the WINNER meter, got %s" % game.winner)
		failed += 1
	for id in [FormCatalog.Id.SLIME, FormCatalog.Id.GOBLIN, FormCatalog.Id.CAT, FormCatalog.Id.DEMON, FormCatalog.Id.DRAGON]:
		game.form_id = id
		game._player.form_id = id
		game.winner = 4
		var meteor_before := int(game._meteor_kills)
		var other := LootGem.new()
		other.setup("gem.png")
		game.add_child(other)
		game._collect_gem(other)
		if int(game.winner) != 4 or int(game._meteor_kills) != meteor_before:
			push_error("%s gem should leave the WINNER meter alone, winner %s meteor %s" % [FormCatalog.display_name(id), game.winner, game._meteor_kills])
			failed += 1
	game.form_id = FormCatalog.Id.VENDING
	game._player.form_id = FormCatalog.Id.VENDING
	game.evo_points = 0
	game.rank_index = 0
	game.winner = FormCatalog.vending_winner_kills(0) - 1
	game.winner_pops = 0
	var finisher := LootGem.new()
	finisher.setup("gem.png")
	game.add_child(finisher)
	game._collect_gem(finisher)
	if int(game.winner_pops) != 1 or int(game.winner) != 0:
		push_error("a gem should finish a one-short WINNER meter without refilling it, winner %s pops %s" % [game.winner, game.winner_pops])
		failed += 1
	root.remove_child(game)
	game.free()
	return failed

func _check_roster_play() -> int:
	CaptureMode.reset_for_test(PackedStringArray())
	var failed := 0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game.day_seed = 20261101
	var previous := int(game.form_id)
	for _i in 6:
		game._reincarnate()
		if int(game.form_id) == previous:
			push_error("a retry repeated %s" % FormCatalog.display_name(previous))
			failed += 1
			break
		previous = int(game.form_id)
	game.form_id = FormCatalog.Id.SLIME
	game._player.form_id = FormCatalog.Id.SLIME
	game.winner_pops = 0
	game._overdrive_blast()
	if game.winner_pops != 0:
		push_error("overdrive must not be the WINNER clear")
		failed += 1
	for fx in game._effects:
		if str(fx.sprite_name) == "winner_burst.png":
			push_error("overdrive should not spawn the WINNER burst")
			failed += 1
	game.form_id = FormCatalog.Id.VENDING
	game._player.form_id = FormCatalog.Id.VENDING
	game.phase = game.PHASE_PLAY
	game.winner = FormCatalog.vending_winner_kills() - 1
	var victim := EnemyActor.new()
	victim.position = Vector2(300, 120)
	victim.score_value = 40
	victim.hp = 1
	victim.max_hp = 1
	victim.alive = true
	game._award_kill(victim, true)
	victim.free()
	if game.winner_pops != 1:
		push_error("a full WINNER meter should clear once, pops %s" % game.winner_pops)
		failed += 1
	var saw_burst := false
	for fx in game._effects:
		if str(fx.sprite_name) == "winner_burst.png":
			saw_burst = true
	if not saw_burst:
		push_error("the vending clear should use winner_burst.png")
		failed += 1
	var field := Vector2(480, 270)
	var eye_ok: bool = game._spawn_enemy({
		"t": 0.0, "kind": SpawnDirector.EYE, "x_ratio": 0.8, "phase": 0.2,
		"stop_ratio": 0.3, "y_bias": 0.0, "wave_amp": 4.0, "hold_fire": true,
	}, field)
	var wyvern_ok: bool = game._spawn_enemy({
		"t": 0.0, "kind": SpawnDirector.WYVERN, "x_ratio": 0.7, "phase": 0.4,
		"stop_ratio": 0.3, "y_bias": 20.0, "wave_amp": 8.0, "hold_fire": true,
	}, field)
	var piano_ok: bool = game._spawn_enemy({
		"t": 0.0, "kind": SpawnDirector.PIANO, "x_ratio": 0.6, "phase": 0.1,
		"stop_ratio": 0.3, "y_bias": 0.0, "wave_amp": 0.0, "hold_fire": true,
	}, field)
	if not eye_ok or not wyvern_ok or not piano_ok:
		push_error("winner blast fixtures should spawn")
		failed += 1
	else:
		var eye: EnemyActor
		var wyvern: EnemyActor
		var piano: EnemyActor
		for enemy in game._enemies:
			if int(enemy.kind) == SpawnDirector.EYE:
				eye = enemy
			elif int(enemy.kind) == SpawnDirector.WYVERN:
				wyvern = enemy
			elif int(enemy.kind) == SpawnDirector.PIANO:
				piano = enemy
		game.combo = 4
		game.combo_left = 0.8
		game.winner = 3
		var loot_before: int = game._loot.size()
		var powers_before: int = game._powers.size()
		var score_before: int = game.score
		var hostile = game._spawn_shot({
			"position": Vector2(400, 40),
			"velocity": Vector2(-90, 0),
			"sprite": "arrow.png",
			"radius": 4.0,
			"damage": 1,
			"killer_name": "Skeleton Archer",
		}, false)
		var friendly = game._spawn_shot({
			"position": Vector2(80, 200),
			"velocity": Vector2(200, 0),
			"sprite": "vending_can.png",
			"radius": 4.0,
			"damage": 1,
		}, true)
		game.pattern_shots.append({
			"pos": Vector2(420, 80),
			"vel": Vector2(-120, 0),
			"left": 0.4,
			"sprite": "floating_eye_bolt.png",
			"killer": "Floating Eye",
		})
		game.rank_index = 0
		game._drop_seeded = false
		game.day_seed = 20261101
		var drop_probe := RandomNumberGenerator.new()
		drop_probe.seed = int(game.day_seed) * 17 + 3
		var expect_gem := drop_probe.randf() < Difficulty.GEM_CHANCE
		var over_blocked := float(game.elapsed) < float(game._overdrive_lock) or bool(game._overdrive_live())
		var expect_over := false
		if not over_blocked:
			expect_over = drop_probe.randf() < Difficulty.overdrive_drop_chance(game.elapsed)
		var expect_power := false
		if not expect_over:
			expect_power = drop_probe.randf() < Difficulty.POWER_CHANCE
		var kill_pay: Dictionary = ScoreRules.on_kill(eye.score_value, game.combo, game.combo_left, game.rank_index)
		var blast := FormCatalog.vending_winner_damage(0)
		game._winner_clear()
		if eye.alive or not wyvern.alive or wyvern.hp != wyvern.max_hp - blast:
			push_error("winner blast should kill an eye and leave a wyvern at %d, hp %d alive %s" % [wyvern.max_hp - blast, wyvern.hp, wyvern.alive])
			failed += 1
		if not piano.alive or piano.hp != piano.max_hp - blast or piano.hp <= 0:
			push_error("winner blast should chip a piano, not delete it, hp %d" % piano.hp)
			failed += 1
		if game.combo != int(kill_pay["combo"]) or absf(game.combo_left - float(kill_pay["combo_left"])) > 0.001:
			push_error("winner kill should step the combo like a normal kill, got %s / %s" % [game.combo, game.combo_left])
			failed += 1
		if game.winner != 3:
			push_error("winner kills should not refill the meter, got %s" % game.winner)
			failed += 1
		if game.score != score_before + int(kill_pay["points"]):
			push_error("winner kill should pay a normal kill and no bonus, got %s want %s" % [game.score, score_before + int(kill_pay["points"])])
			failed += 1
		var gems_gained := int(game._loot.size()) - loot_before
		var powers_gained := int(game._powers.size()) - powers_before
		if gems_gained != (1 if expect_gem else 0) or powers_gained != (1 if expect_over or expect_power else 0):
			push_error("winner kill should drop loot like a normal kill, gems %d powers %d" % [gems_gained, powers_gained])
			failed += 1
		game.rank_index = 4
		var held_winner := int(game.winner)
		game._winner_clear()
		if wyvern.alive or piano.alive or game.winner != held_winner:
			push_error("rank 5 blast should finish the survivors without refilling the meter, wyvern %s piano %s winner %s" % [wyvern.alive, piano.alive, game.winner])
			failed += 1
		var hostile_left := false
		var friendly_kept := false
		for shot in game._shots:
			if shot == hostile:
				hostile_left = true
			if shot == friendly:
				friendly_kept = true
		if hostile_left or not friendly_kept or not game.pattern_shots.is_empty():
			push_error("winner blast should clear enemy shots and pattern shots, and keep the player's")
			failed += 1
	game._player.form_id = FormCatalog.Id.CAT
	game._player.position = Vector2(140, 130)
	var swipe_spec: Dictionary = FormCatalog.player_shots(FormCatalog.Id.CAT, game._player.position, 0)[0]
	var swipe = game._spawn_shot(swipe_spec, true)
	var bullet = game._spawn_shot({
		"position": swipe.position + Vector2(6, 0),
		"velocity": Vector2(-160, 12),
		"sprite": "floating_eye_bolt.png",
		"radius": 4.0,
		"damage": 1,
		"killer_name": "Floating Eye",
	}, false)
	var bystander = game._spawn_shot({
		"position": Vector2(400, 40),
		"velocity": Vector2(-90, 0),
		"sprite": "arrow.png",
		"radius": 4.0,
		"damage": 1,
		"killer_name": "Skeleton Archer",
	}, false)
	game._collide()
	if not bullet.from_player or str(bullet.sprite_name) != "reflected_bullet.png" or bullet.velocity.x <= 0.0:
		push_error("a swipe should reflect the bolt, from_player %s sprite %s vel %s" % [bullet.from_player, bullet.sprite_name, bullet.velocity])
		failed += 1
	if bystander.from_player or bystander.z_index < Replay.bullet_z():
		push_error("an untouched enemy bullet should stay an enemy bullet above FX")
		failed += 1
	root.remove_child(game)
	game.free()
	CaptureMode.reset_for_test(PackedStringArray(["--form=cat", "--seed=20261101"]))
	var challenged := packed.instantiate()
	challenged.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(challenged)
	if int(challenged.form_id) != FormCatalog.Id.CAT:
		push_error("a challenge link should open as the named form")
		failed += 1
	CaptureMode.note_player_retry(FormCatalog.Id.CAT)
	root.remove_child(challenged)
	challenged.free()
	var retry := packed.instantiate()
	retry.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(retry)
	if int(retry.form_id) == FormCatalog.Id.CAT:
		push_error("the retry after a challenged cat should roll a different form")
		failed += 1
	var retry_form := int(retry.form_id)
	CaptureMode.note_player_retry(retry_form)
	root.remove_child(retry)
	retry.free()
	var third := packed.instantiate()
	third.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(third)
	if int(third.form_id) == retry_form:
		push_error("consecutive retries should not repeat %s" % FormCatalog.display_name(retry_form))
		failed += 1
	root.remove_child(third)
	third.free()
	CaptureMode.reset_for_test(PackedStringArray())
	return failed

func _check_replay_rules() -> int:
	var failed := 0
	if Replay.FLASH_REVEAL > 0.5 or Replay.FLASH_REVEAL < 0.4:
		push_error("retry flash should stay within 0.5s, got %s" % Replay.FLASH_REVEAL)
		failed += 1
	if absf(Replay.CARD_GUARD - 0.25) > 0.02:
		push_error("death-card guard should be about 0.25s")
		failed += 1
	if Replay.bullet_z() <= 8:
		push_error("enemy bullets should sit above FX")
		failed += 1
	if absf(Replay.shake_cap() - Replay.JUICE_SHAKE_PX) > 0.001:
		push_error("shake cap should stay at 2px")
		failed += 1
	Replay.force_reduced_motion_for_test(1)
	if absf(Replay.shake_cap() - 1.0) > 0.001:
		push_error("reduced motion should cap shake at 1px")
		failed += 1
	Replay.force_reduced_motion_for_test(-1)
	var slime := Replay.daily_text(20261101, FormCatalog.Id.SLIME, 1240, "Gel Knight")
	if slime.find("GOBLIN") >= 0 or slime.find("goblin") >= 0 or slime.find("next") >= 0:
		push_error("daily share text leaked another form: %s" % slime)
		failed += 1
	if slime.find("Reincarnated as WHAT?!") < 0 or slime.find("2026-11-01") < 0 or slime.find("(S)") < 0 or slime.find("1,240") < 0 or slime.find("GEL KNIGHT") < 0:
		push_error("daily share text missing a wordle field: %s" % slime)
		failed += 1
	var goblin := Replay.daily_text(20261101, FormCatalog.Id.GOBLIN, 80, "Goblin")
	if goblin.find("SLIME") >= 0 or goblin.find("(S)") >= 0:
		push_error("goblin share text should not name the slime")
		failed += 1
	var url := Replay.beat_url(20261101, "goblin")
	if url.find("seed=20261101") < 0 or url.find("form=goblin") < 0:
		push_error("beat link should carry the seed and the goblin, got %s" % url)
		failed += 1
	var fallen := Replay.beat_url(20261101, "nope")
	if fallen.find("form=") >= 0 or fallen.find("seed=20261101") < 0:
		push_error("an unknown form should fall back to the daily seed, got %s" % fallen)
		failed += 1
	var shell := FileAccess.get_file_as_string("res://web/shell.html")
	if shell.find("shareRunText") < 0 or shell.find("navigator.share") < 0 or shell.find("clipboard") < 0:
		push_error("the web shell should share text and fall back to the clipboard")
		failed += 1
	if shell.find("lbReleaseInput") < 0 or shell.find("lbSetCover") < 0 or shell.find("lbPost") < 0 or shell.find(".ime") < 0 or shell.find("tabindex=\"0\"") < 0:
		push_error("the web shell should release a stuck IME and keep the canvas focusable")
		failed += 1
	if shell.find("lb-name-input") >= 0 or shell.find("lbShowNameField") >= 0:
		push_error("the overlay name field eats taps after the iOS keyboard closes")
		failed += 1
	return failed

func _check_replay() -> int:
	var failed := 0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var daily_path := "user://daily_run.json"
	var best_path := "user://best_scores.json"
	var daily_backup := FileAccess.get_file_as_string(daily_path) if FileAccess.file_exists(daily_path) else ""
	var best_backup := FileAccess.get_file_as_string(best_path) if FileAccess.file_exists(best_path) else ""
	Replay.mark_seen()
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game._begin_play()
	var shot = game._spawn_shot({
		"position": Vector2(200, 120),
		"velocity": Vector2(-40, 0),
		"sprite": "floating_eye_bolt.png",
		"radius": 4.0,
		"damage": 1,
		"killer_name": "Floating Eye",
	}, false)
	game._spawn_fx("hit_flash.png", Vector2(200, 120), 0.4, 1.0, 1.2)
	var fx = game._effects[game._effects.size() - 1]
	if shot.z_index <= game._combat.z_index or shot.z_index <= fx.z_index or shot.z_index <= game._death_fx.z_index:
		push_error("enemy bullet z %s should clear combat %s fx %s death %s" % [shot.z_index, game._combat.z_index, fx.z_index, game._death_fx.z_index])
		failed += 1
	if game._pattern_layer.z_index >= shot.z_index:
		push_error("the overdrive flash layer should stay under enemy bullets")
		failed += 1
	var evolve_z := int(game._player.z_index) + int(game._player._evolve_fx.z_index)
	if evolve_z >= shot.z_index:
		push_error("evolve art should stay under enemy bullets")
		failed += 1
	var prior_best := int(BestScores.read().get("overall", 0))
	var shown_score := prior_best + 250
	game.score = shown_score
	game.rank_index = 1
	game.killer_name = "Dire Wolf"
	game._kill_player("Dire Wolf")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.index = 0
	tap.position = Vector2(180, 90)
	game._unhandled_input(tap)
	if not game.game_over_visible or int(game.phase) != game.PHASE_DEAD:
		push_error("a tap should skip the death sting onto the card")
		failed += 1
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(30, 30)
	game._on_death_pointer(click)
	if int(game.phase) != game.PHASE_DEAD:
		push_error("a tap inside the guard should not start the next run")
		failed += 1
	var step := 1.0 / 60.0
	var sim := 0.0
	while game._card_age < Replay.CARD_GUARD and sim < 1.0:
		game._process(step)
		sim += step
	game._on_death_pointer(click)
	if int(game.phase) != game.PHASE_REVEAL or not game._short_reveal:
		push_error("the card tap should open the short reveal")
		failed += 1
	elif game._form_flash == null or not game._form_flash.visible or game._form_flash.text.is_empty():
		push_error("the short reveal should name the form")
		failed += 1
	var guard_at := sim
	while int(game.phase) == game.PHASE_REVEAL and sim < 1.2:
		game._process(step)
		sim += step
	if int(game.phase) != game.PHASE_PLAY or sim >= 1.0:
		push_error("death to control took %.3fs (guard %.3f)" % [sim, guard_at])
		failed += 1
	else:
		var before: Vector2 = game._player.position
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.index = 3
		touch.position = before
		game._unhandled_input(touch)
		var drag := InputEventScreenDrag.new()
		drag.index = 3
		drag.relative = Vector2(0, -36)
		drag.position = before + drag.relative
		game._input(drag)
		if game._player.position.distance_to(before) < 10.0:
			push_error("the next run should be draggable as soon as the flash ends")
			failed += 1
	var shown_text := ScoreRules.format_score(shown_score)
	if game._score_label == null or game._score_label.text != shown_text:
		push_error("the death card should show the score large, got %s" % (game._score_label.text if game._score_label != null else "missing"))
		failed += 1
	if game._new_best_label == null or game._new_best_label.text != "NEW BEST!":
		push_error("beating the stored best should pop NEW BEST!")
		failed += 1
	if game._seed_label == null or game._seed_label.text.find("·") >= 0 or game._seed_label.text.find(" - ") < 0:
		push_error("seed line should use a hyphen the pixel font can draw, got %s" % (game._seed_label.text if game._seed_label != null else "missing"))
		failed += 1
	else:
		var glyphs: Dictionary = PixelFont.plain_glyphs()
		var seed_text := str(game._seed_label.text)
		for i in seed_text.length():
			var ch := seed_text.substr(i, 1)
			if ch != "\n" and not glyphs.has(ch):
				push_error("seed line uses a glyph the pixel font lacks: %s" % ch)
				failed += 1
				break
	if game._beat_button == null or game._beat_button.text != "CHALLENGE A FRIEND":
		push_error("death card should challenge a friend, got %s" % (game._beat_button.text if game._beat_button != null else "missing"))
		failed += 1
	game._on_beat_link()
	if game._beat_button.text != "LINK COPIED!":
		push_error("the challenge button should confirm the link, got %s" % game._beat_button.text)
		failed += 1
	print("DEATH_TO_CONTROL %.3f guard %.3f flash %.3f" % [sim, guard_at, Replay.FLASH_REVEAL])
	root.remove_child(game)
	game.free()
	Replay.reset_seen_for_test()
	var lesson := packed.instantiate()
	lesson.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(lesson)
	var saw_eye := false
	var saw_gem := false
	var saw_shot := false
	var lesson_step := 1.0 / 60.0
	for _i in 520:
		lesson._process(lesson_step)
		if int(lesson.phase) != lesson.PHASE_PLAY:
			continue
		for enemy in lesson._enemies:
			if enemy.hold_fire:
				saw_eye = true
		if lesson._loot.size() > 0:
			saw_gem = true
		if lesson.pattern_shots.size() > 0:
			saw_shot = true
		for bullet in lesson._shots:
			if not bullet.from_player and str(bullet.killer_name) == "Floating Eye":
				saw_shot = true
		if saw_eye and saw_gem and saw_shot:
			break
	if not saw_eye or not saw_gem or not saw_shot:
		push_error("the first run should teach an eye, a gem, and one shot (eye %s gem %s shot %s t %.2f)" % [saw_eye, saw_gem, saw_shot, float(lesson.elapsed)])
		failed += 1
	if lesson._hint_label.visible:
		push_error("the lesson should not use a text screen")
		failed += 1
	root.remove_child(lesson)
	lesson.free()
	if not Replay.seen():
		push_error("the lesson should remember that it played")
		failed += 1
	var later := packed.instantiate()
	later.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(later)
	later._begin_play()
	for _i in 80:
		later._process(lesson_step)
	var gentle := 0
	for enemy in later._enemies:
		if enemy.hold_fire:
			gentle += 1
	if later._tutorial_active or gentle > 0:
		push_error("a later run should use the normal spawns")
		failed += 1
	root.remove_child(later)
	later.free()
	_restore_user_file(daily_path, daily_backup)
	_restore_user_file(best_path, best_backup)
	return failed

func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _user_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _restore_user_file(path: String, body: String) -> void:
	if body.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(body)
		file.close()

func _check_ad_policy() -> int:
	var failed := 0
	if not StoreConfig.USE_TEST_ADS:
		push_error("test ads should stay on until a store build flips the flag")
		failed += 1
	if StoreConfig.ios_app_id() != "ca-app-pub-1397621797560860~9031599553":
		push_error("iOS AdMob app id should be the real one even while test units are on")
		failed += 1
	if StoreConfig.android_app_id() != "ca-app-pub-1397621797560860~1097269219":
		push_error("Android AdMob app id should be the real one even while test units are on")
		failed += 1
	if StoreConfig.REAL_IOS_INTERSTITIAL_UNIT_ID != "ca-app-pub-1397621797560860/3293196875":
		push_error("iOS interstitial unit id is not the store unit")
		failed += 1
	if StoreConfig.REAL_ANDROID_INTERSTITIAL_UNIT_ID != "ca-app-pub-1397621797560860/3747483284":
		push_error("Android interstitial unit id is not the store unit")
		failed += 1
	if not StoreConfig.REAL_IOS_BANNER_UNIT_ID.is_empty() or not StoreConfig.REAL_ANDROID_BANNER_UNIT_ID.is_empty():
		push_error("banner real units are not created yet")
		failed += 1
	if not StoreConfig.REAL_IOS_REWARDED_UNIT_ID.is_empty() or not StoreConfig.REAL_ANDROID_REWARDED_UNIT_ID.is_empty():
		push_error("rewarded real units are not created yet")
		failed += 1
	if StoreConfig.REMOVE_ADS_PRODUCT_ID != "remove_ads":
		push_error("remove ads product id changed")
		failed += 1
	if StoreConfig.TEST_ANDROID_BANNER_UNIT_ID != "ca-app-pub-3940256099942544/6300978111":
		push_error("android test banner is not Google's sample unit")
		failed += 1
	if StoreConfig.TEST_IOS_BANNER_UNIT_ID != "ca-app-pub-3940256099942544/2934735716":
		push_error("ios test banner is not Google's sample unit")
		failed += 1
	if StoreConfig.TEST_ANDROID_INTERSTITIAL_UNIT_ID != "ca-app-pub-3940256099942544/1033173712":
		push_error("android test interstitial is not Google's sample unit")
		failed += 1
	if StoreConfig.TEST_IOS_INTERSTITIAL_UNIT_ID != "ca-app-pub-3940256099942544/4411468910":
		push_error("ios test interstitial is not Google's sample unit")
		failed += 1
	if StoreConfig.TEST_ANDROID_REWARDED_UNIT_ID != "ca-app-pub-3940256099942544/5224354917":
		push_error("android test rewarded unit is not Google's sample")
		failed += 1
	if StoreConfig.RUNS_BEFORE_ADS != 5 or StoreConfig.RUNS_BETWEEN_ADS != 5:
		push_error("interstitials should be every 5 runs, after the first 5")
		failed += 1
	if StoreConfig.ATT_USAGE_DESCRIPTION.is_empty() or StoreConfig.att_plist().find("NSUserTrackingUsageDescription") < 0:
		push_error("the tracking prompt text should land in the iOS plist")
		failed += 1
	if StoreConfig.stores_available():
		push_error("ads and purchases should be inert in the editor, on the web, and in this check")
		failed += 1
	for completed in [0, 1, 2, 3, 4, 6, 7, 8, 9]:
		if AdPolicy.interstitial_due(completed, false, false, false):
			push_error("run %d should not be an interstitial slot" % completed)
			failed += 1
	for completed in [5, 10, 15]:
		if not AdPolicy.interstitial_due(completed, false, false, false):
			push_error("run %d should be an interstitial slot" % completed)
			failed += 1
		if AdPolicy.interstitial_due(completed, true, false, false):
			push_error("remove ads should block the interstitial")
			failed += 1
		if AdPolicy.interstitial_due(completed, false, true, false):
			push_error("an interstitial must not show mid-run")
			failed += 1
		if AdPolicy.interstitial_due(completed, false, false, true):
			push_error("an interstitial must not show during a boss fight")
			failed += 1
	if not AdPolicy.banner_visible(true, false, false):
		push_error("the banner belongs on the death screen")
		failed += 1
	if AdPolicy.banner_visible(false, false, false) or AdPolicy.banner_visible(true, true, false) or AdPolicy.banner_visible(true, false, true):
		push_error("the banner must stay off during play, off the death card, and after remove ads")
		failed += 1
	if not AdPolicy.rewarded_opens_picker(true) or AdPolicy.rewarded_opens_picker(false):
		push_error("the form picker opens only from the rewarded callback")
		failed += 1
	if AdPolicy.form_is_pickable(FormCatalog.Id.DRAGON):
		push_error("Dragon is not a pickable form")
		failed += 1
	for id in FormCatalog.IDS:
		if not AdPolicy.form_is_pickable(id):
			push_error("regular form %s should be pickable" % FormCatalog.display_name(id))
			failed += 1
	var script = load("res://scripts/game.gd")
	var safe := Rect2(80, 0, 1760, 1080)
	var band: Rect2 = script.death_banner_rect(safe, 90.0)
	if band.position.y + band.size.y != safe.position.y + safe.size.y or band.position.x != safe.position.x or band.size.x != safe.size.x:
		push_error("banner should sit on the bottom of the safe area, got %s" % band)
		failed += 1
	if not safe.encloses(band):
		push_error("banner left the safe area %s" % band)
		failed += 1
	return failed


func _check_safe_insets() -> int:
	var failed := 0
	var script = load("res://scripts/game.gd")
	var full: Vector4 = script.safe_insets_for(Vector2(480, 270), Vector2(1920, 1080), Rect2(0, 0, 1920, 1080))
	if full != Vector4.ZERO:
		push_error("a full-window safe rect should not move the HUD, got %s" % full)
		failed += 1
	# 4x integer scale, 80 device pixels of notch on each side.
	var notch: Vector4 = script.safe_insets_for(Vector2(480, 270), Vector2(1920, 1080), Rect2(80, 0, 1760, 1080))
	if absf(notch.x - 20.0) > 0.01 or absf(notch.z - 20.0) > 0.01 or notch.y > 0.01 or notch.w > 0.01:
		push_error("notch insets should be 20 viewport pixels on each side, got %s" % notch)
		failed += 1
	return failed


func _check_bosses() -> int:
	var failed := 0
	if SpawnDirector.max_hp(SpawnDirector.ARCHER) != 4 or SpawnDirector.max_hp(SpawnDirector.WYVERN) != 6 or SpawnDirector.max_hp(SpawnDirector.WOLF) != 4:
		push_error("archer, wyvern, and wolf hp should be 4, 6, and 4")
		failed += 1
	if SpawnDirector.max_hp(SpawnDirector.EYE) != 2 or SpawnDirector.max_hp(SpawnDirector.ANVIL) != 4 or SpawnDirector.max_hp(SpawnDirector.PIANO) != 6:
		push_error("eye, anvil, and piano hp should stay 2, 4, and 6")
		failed += 1
	for i in 8:
		var slug := BossDirector.regular_slug(i)
		var expect := "lich_king" if i % 2 == 0 else "death_knight"
		if slug != expect:
			push_error("regular boss %d should be %s, got %s" % [i, expect, slug])
			failed += 1
	var dragon_at := BossDirector.first_dragon_time(20261101)
	if dragon_at < 148.5 or dragon_at > 151.5:
		push_error("the first dragon should arrive about 2:30, got %s" % dragon_at)
		failed += 1
	var opening := BossDirector.regular_time(20261101, 0)
	if opening < 43.4 or opening > 46.6:
		push_error("the first boss should arrive about 45 s, got %s" % opening)
		failed += 1
	if absf(BossDirector.regular_time(20261101, 0) - BossDirector.regular_time(20261102, 0)) < 0.001 and absf(BossDirector.first_dragon_time(20261101) - BossDirector.first_dragon_time(20261102)) < 0.001:
		push_error("a different day should move the boss clock")
		failed += 1
	var fine := _boss_pull(20261101, 1.0 / 60.0, dragon_at + 3.0)
	var coarse := _boss_pull(20261101, 0.5, dragon_at + 3.0)
	if fine.size() < 3 or fine.size() != coarse.size():
		push_error("boss timeline changed with the timestep (%d vs %d)" % [fine.size(), coarse.size()])
		failed += 1
	else:
		for i in fine.size():
			if str(fine[i]["slug"]) != str(coarse[i]["slug"]) or absf(float(fine[i]["t"]) - float(coarse[i]["t"])) > 0.001:
				push_error("boss event %d drifted with the timestep" % i)
				failed += 1
				break
		if str(fine[0]["slug"]) != "lich_king" or str(fine[1]["slug"]) != "death_knight":
			push_error("the cycle should open Lich King then Death Knight, got %s / %s" % [fine[0]["slug"], fine[1]["slug"]])
			failed += 1
		var dragons := 0
		var last_regular := -1.0
		for event in fine:
			var at := float(event["t"])
			if str(event["slug"]) == "great_dragon":
				dragons += 1
				if absf(at - dragon_at) > 0.001:
					push_error("dragon spawn drifted from the seed clock")
					failed += 1
			else:
				if at + BossDirector.LIFE > dragon_at - 0.2:
					push_error("a regular boss overlaps the dragon at %s" % at)
					failed += 1
				if last_regular >= 0.0 and at < last_regular + BossDirector.LIFE:
					push_error("two regular bosses would share the screen")
					failed += 1
				last_regular = at
		if dragons != 1:
			push_error("the first dragon window should spawn one dragon, got %d" % dragons)
			failed += 1
	var booked := BossDirector.new(20261101)
	var seen_dragon := false
	var kill_at := 0.0
	var t := 0.0
	while t < 200.0 and not seen_dragon:
		t += 0.25
		booked.set_boss_alive(false)
		var due := booked.pop_due(t)
		if due.is_empty():
			continue
		if str(due[0]["slug"]) == "great_dragon":
			seen_dragon = true
			kill_at = float(due[0]["t"]) + 8.0
			booked.on_dragon_killed(kill_at)
	if not seen_dragon or booked.dragon_gen != 1:
		push_error("killing the dragon should schedule its return")
		failed += 1
	elif absf(booked.dragon_at - (kill_at + BossDirector.DRAGON_RETURN)) > 0.001:
		push_error("the dragon should return 60 s after the kill, at %s" % booked.dragon_at)
		failed += 1
	if BossCatalog.max_hp("lich_king") != 500 or BossCatalog.max_hp("death_knight") != 2500 or BossCatalog.max_hp("lich_king", 3) != 500 or BossCatalog.max_hp("death_knight", 2) != 2500:
		push_error("lich and death knight hp should be 500 and 2500")
		failed += 1
	if BossCatalog.max_hp("great_dragon", 0) != 10000 or BossCatalog.max_hp("great_dragon", 1) != 20000 or BossCatalog.max_hp("great_dragon", 2) != 30000 or BossCatalog.score_value("great_dragon") != 100000:
		push_error("dragon reward and return hp drifted")
		failed += 1
	for slug in ["lich_king", "death_knight", "great_dragon"]:
		var pool := BossCatalog.max_hp(slug, 0)
		if absf(float(pool / 2) / float(pool) - 0.5) > 0.0001:
			push_error("%s half-health bar should sit at half" % slug)
			failed += 1
	if BossCatalog.winner_damage(500) != 50 or BossCatalog.winner_damage(2500) != 250 or BossCatalog.winner_damage(10000) != 1000 or BossCatalog.winner_damage(20000) != 2000 or BossCatalog.winner_damage(30000) != 3000:
		push_error("WINNER should stay 10 percent of the new boss pools")
		failed += 1
	if BossCatalog.winner_damage(2500) >= 2500 or BossCatalog.winner_damage(10000) >= 10000:
		push_error("one WINNER must not finish a full boss")
		failed += 1
	if BossCatalog.meteor_rain_damage(500) != 75 or BossCatalog.meteor_rain_damage(2500) != 375 or BossCatalog.meteor_rain_damage(10000) != 1500 or BossCatalog.meteor_rain_damage(20000) != 3000 or BossCatalog.meteor_rain_damage(30000) != 4500:
		push_error("Meteor Rain should stay 15 percent of the boss pools")
		failed += 1
	if BossCatalog.meteor_rain_damage(2500) >= 2500 or BossCatalog.meteor_rain_damage(10000) >= 10000:
		push_error("one Meteor Rain must not finish a full boss")
		failed += 1
	if BossCatalog.attack_rate(180.0, 1, 2) <= BossCatalog.attack_rate(180.0, 0, 2):
		push_error("a returning dragon should attack faster")
		failed += 1
	if BossCatalog.windup("charge", 1, 3) < 0.79:
		push_error("the death knight warning should stay about 0.8 s")
		failed += 1
	failed += _check_bone_rain()
	failed += _check_lich_patterns()
	failed += _check_boss_rework()
	failed += _check_boss_gaps()
	failed += _check_boss_flee()
	failed += _check_dragon_not_blocked()
	failed += _check_dragon_form()
	failed += _check_meteor_clock()
	var boss_px := {"lich_king": Vector2(92, 84), "death_knight": Vector2(96, 84), "great_dragon": Vector2(128, 88)}
	for slug in BossCatalog.SLUGS:
		var tex := ArtLibrary.texture(BossCatalog.sprite_for(slug))
		var expect: Vector2 = boss_px[slug]
		if tex == null or tex.get_width() != int(expect.x) or tex.get_height() != int(expect.y):
			push_error("%s art size drifted" % slug)
			failed += 1
		if absf(BossCatalog.rest_x(slug) - float({"lich_king": 428, "death_knight": 426, "great_dragon": 410}[slug])) > 0.1:
			push_error("%s should rest at the measured right-edge x" % slug)
			failed += 1
		if not HitLibrary.has_role(BossCatalog.sprite_for(slug), "body") or not HitLibrary.has_role(BossCatalog.sprite_for(slug), "threat"):
			push_error("%s needs a body and a threat shape" % slug)
			failed += 1
		for moment in ["enter", "death"]:
			var event := BossCatalog.cue(slug, moment)
			var data := AudioCues.spec(event)
			if data.is_empty() or float(data.get("pitch_semitones", 1.0)) != 0.0 or float(data.get("pitch_ratio", 0.0)) != 0.0 or float(data.get("volume_db", 0.0)) != 0.0:
				push_error("%s should be a flat sting" % event)
				failed += 1
				continue
			if not ResourceLoader.exists(str(data["file"])):
				push_error("boss cue was not imported: %s" % data["file"])
				failed += 1
	if not HitLibrary.contains_local("lich_king.png", "body", Vector2(-14, -20)):
		push_error("the lich crown should be part of the body")
		failed += 1
	if HitLibrary.contains_local("lich_king.png", "body", Vector2(44, -40)):
		push_error("empty space beside the lich should not be a hit")
		failed += 1
	if not HitLibrary.contains_local("death_knight.png", "body", Vector2(-36, -30)):
		push_error("the knight's raised blade should take a shot")
		failed += 1
	if HitLibrary.contains_local("death_knight.png", "threat", Vector2(-36, -30)):
		push_error("the raised blade should not kill on a brush")
		failed += 1
	if not HitLibrary.contains_local("great_dragon.png", "body", Vector2(30, -28)) or not HitLibrary.contains_local("great_dragon.png", "body", Vector2(-48, -4)):
		push_error("the dragon wing and head should be part of the body")
		failed += 1
	if HitLibrary.contains_local("great_dragon.png", "threat", Vector2(30, -28)):
		push_error("a dragon wing tip should not kill")
		failed += 1
	if not HitLibrary.contains_local("dragon_fireball.png", "threat", Vector2(-1, 0)):
		push_error("the dragon fireball head should be a threat")
		failed += 1
	if HitLibrary.contains_local("dragon_fireball.png", "threat", Vector2(4, 0)):
		push_error("the fireball smoke tail should not kill")
		failed += 1
	if HitLibrary.entry("lich_king_fx.png").has("body") or HitLibrary.entry("death_knight_fx.png").has("threat"):
		push_error("boss FX layers should not have a hit shape")
		failed += 1
	if not HitLibrary.contains_local("lich_skull.png", "threat", Vector2.ZERO):
		push_error("the skull bolt needs a threat shape")
		failed += 1
	if ShareCard.killer_id("Great Dragon") != "great_dragon":
		push_error("a dragon kill should stay a dragon on the share card")
		failed += 1
	return failed

func _check_boss_rework() -> int:
	var failed := 0
	if BossCatalog.WINNER_BOSS_DMG_PCT != 0.10:
		push_error("WINNER boss damage should be 10 percent")
		failed += 1
	if BossCatalog.winner_damage(200) != 20 or BossCatalog.winner_damage(350) != 35 or BossCatalog.winner_damage(500) != 50:
		push_error("WINNER chips should be 20, 35, and 50, got %d %d %d" % [BossCatalog.winner_damage(200), BossCatalog.winner_damage(350), BossCatalog.winner_damage(500)])
		failed += 1
	if BossCatalog.winner_damage(500) >= 500:
		push_error("one WINNER must not be an instant kill")
		failed += 1
	if BossCatalog.METEOR_RAIN_BOSS_DMG_PCT != 0.15:
		push_error("Meteor Rain boss damage should stay 15 percent")
		failed += 1
	if BossCatalog.meteor_rain_damage(200) != 30 or BossCatalog.meteor_rain_damage(350) != 53 or BossCatalog.meteor_rain_damage(500) != 75:
		push_error("Meteor Rain chips should stay 30, 53, and 75, got %d %d %d" % [BossCatalog.meteor_rain_damage(200), BossCatalog.meteor_rain_damage(350), BossCatalog.meteor_rain_damage(500)])
		failed += 1
	if BossCatalog.meteor_rain_damage(500) >= 500:
		push_error("one Meteor Rain must not be an instant kill")
		failed += 1
	var furious := BossCatalog.attack_cycle("lich_king", 2)
	if furious.find("beam_rain") < 0 or furious.find("spiral_hands") < 0:
		push_error("the lich should combine attacks below half health, got %s" % str(furious))
		failed += 1
	var knight_fury := BossCatalog.attack_cycle("death_knight", 2)
	if knight_fury.size() < 2 or knight_fury[0] != "charge" or knight_fury[1] != "charge":
		push_error("the enraged knight should charge twice, got %s" % str(knight_fury))
		failed += 1
	if BossCatalog.attack_cycle("great_dragon", 1) != ["sky_breath", "ember_fan"] or BossCatalog.attack_cycle("great_dragon", 2) != ["sky_breath", "dive", "wing_gust", "boss_meteor"] or BossCatalog.attack_cycle("great_dragon", 3) != ["hell_breath", "dive", "boss_meteor"]:
		push_error("the dragon's phase attacks changed, got %s / %s / %s" % [str(BossCatalog.attack_cycle("great_dragon", 1)), str(BossCatalog.attack_cycle("great_dragon", 2)), str(BossCatalog.attack_cycle("great_dragon", 3))])
		failed += 1
	var wide := 0.0
	var tall := 0.0
	for id in FormCatalog.IDS:
		for rank in 5:
			var file := str(FormCatalog.rank_spec(id, rank)["sprite"])
			wide = maxf(wide, HitLibrary.horizontal_extent(file, "hurt"))
			tall = maxf(tall, HitLibrary.vertical_extent(file, "hurt"))
	if absf(BossCatalog.BEAM_LOCK - 0.35) > 0.001 or BossCatalog.BEAM_FIRE < 0.9:
		push_error("the soul beam should lock for 0.35 s and hold about a second")
		failed += 1
	var enrage_cycle := BossCatalog.attack_cycle("lich_king", 2)
	if enrage_cycle.find("double_beam") < 0 or enrage_cycle.find("beam_rain") < 0:
		push_error("an enraged lich should chain two beams and still mix in bone rain, got %s" % str(enrage_cycle))
		failed += 1
	var beam_hit := HitLibrary.horizontal_extent(BossCatalog.SOUL_BEAM, "threat")
	if beam_hit < 16.0 or beam_hit > BossCatalog.BEAM_THICK - 2.0:
		push_error("the soul beam hit should sit inside the glow, hit %.1f thick %.1f" % [beam_hit, BossCatalog.BEAM_THICK])
		failed += 1
	var row := BossActor.new()
	row.setup(9, {"slug": "lich_king", "hold_x": 428.0, "origin_y": 140.0, "phase": 0.2, "wave_amp": 0.0, "generation": 0}, Vector2(480, 270), null)
	row.intro_left = 0.0
	row.state = BossActor.HOLD
	row.fight_left = 40.0
	row.position = Vector2(428, 140)
	row._attack_cd = 0.0
	row._attack_i = 0
	row._summon_cd = 50.0
	var tracked := false
	var locked := false
	var locked_y := -1.0
	var fired_row: Array[Dictionary] = []
	var beam_t := 0.0
	while beam_t < 2.4 and fired_row.is_empty():
		var aim_y := 100.0 if beam_t < 0.3 else 160.0
		if row._beam_mode >= 2:
			aim_y = 40.0
		row.fire_room = -1
		var shot := row.tick(0.05, Vector2(120, aim_y), 30.0, 1.0)
		beam_t += 0.05
		if row._beam_mode == 1 and beam_t > 0.3 and absf(row._beam_y - 160.0) < 2.0:
			tracked = true
		if row._beam_mode == 2 and not locked:
			locked = true
			locked_y = row._beam_y
		if row._beam_mode == 2 and locked and absf(row._beam_y - locked_y) > 1.0:
			push_error("the soul beam moved after it locked")
			failed += 1
			break
		for spec in shot:
			if str(spec.get("sprite", "")) == BossCatalog.SOUL_BEAM:
				fired_row.append(spec)
	if not tracked or not locked:
		push_error("the soul beam should track, then lock, track %s lock %s" % [tracked, locked])
		failed += 1
	elif absf(locked_y - 160.0) > 2.0:
		push_error("the locked row should be the player's y, got %s" % locked_y)
		failed += 1
	if fired_row.size() < 8:
		push_error("the soul beam should be a solid row, shots %d" % fired_row.size())
		failed += 1
	else:
		var xs: Array[float] = []
		for spec in fired_row:
			var at: Vector2 = spec["position"]
			if absf(at.y - locked_y) > 1.5:
				push_error("a beam hit left the locked row, y %s" % at.y)
				failed += 1
				break
			xs.append(at.x)
		xs.sort()
		if xs[0] > 24.0 or xs[xs.size() - 1] < 450.0:
			push_error("the beam should cross the field, x %s..%s" % [xs[0], xs[xs.size() - 1]])
			failed += 1
		for i in range(1, xs.size()):
			if xs[i] - xs[i - 1] > beam_hit:
				push_error("the beam has a hole at x %s" % xs[i])
				failed += 1
				break
	row.free()
	var hand_w := HitLibrary.horizontal_extent(BossCatalog.GRAVE_HAND, "threat")
	if BossCatalog.HAND_GAP - hand_w <= wide:
		push_error("grave hands leave no lane (gap %.1f hand %.1f body %.1f)" % [BossCatalog.HAND_GAP, hand_w, wide])
		failed += 1
	for player_x in [40.0, 120.0, 210.0, 340.0]:
		var hands := BossCatalog.hand_columns(player_x)
		var aimed := false
		var spot := clampf(player_x, 48.0, 340.0)
		for column in hands:
			if absf(column - spot) <= 0.1:
				aimed = true
		if hands.size() < 2 or not aimed:
			push_error("a grave hand should rise on the player, got %s for x %.0f" % [str(hands), player_x])
			failed += 1
	var wave_h := HitLibrary.vertical_extent(BossCatalog.SWORD_WAVE, "threat")
	if BossCatalog.SWORD_GAP - wave_h <= tall:
		push_error("sword waves leave no gap (gap %.1f wave %.1f body %.1f)" % [BossCatalog.SWORD_GAP, wave_h, tall])
		failed += 1
	var lich := BossActor.new()
	lich.setup(3, {"slug": "lich_king", "hold_x": 428.0, "origin_y": 140.0, "phase": 0.4, "wave_amp": 8.0, "generation": 0}, Vector2(480, 270), null)
	if lich.intro_left <= 0.0 or lich.position.x < 400.0:
		push_error("the lich should rise on the right, intro %s x %s" % [lich.intro_left, lich.position.x])
		failed += 1
	var full := lich.hp
	lich.hurt(40)
	if lich.hp != full:
		push_error("damage during the entrance should do nothing")
		failed += 1
	lich.intro_left = 0.0
	lich.state = BossActor.HOLD
	lich.fight_left = 40.0
	lich.hurt(lich.max_hp / 2 - 1)
	if lich.enraged or lich.hp * 2 <= lich.max_hp:
		push_error("the lich should stay calm above half health, hp %s / %s" % [lich.hp, lich.max_hp])
		failed += 1
	lich.hurt(1)
	if not lich.enraged or lich.hp * 2 > lich.max_hp:
		push_error("half health should enrage the lich, hp %s / %s" % [lich.hp, lich.max_hp])
		failed += 1
	var shots := 0
	var t := 0.0
	while t < 8.0:
		lich.fire_room = -1
		shots += lich.tick(0.05, Vector2(140, 130), 50.0, 1.0).size()
		t += 0.05
	if not lich.alive or shots < 4:
		push_error("the lich kit should keep firing, shots %d alive %s" % [shots, lich.alive])
		failed += 1
	lich.free()
	var knight := BossActor.new()
	knight.setup(4, {"slug": "death_knight", "hold_x": 426.0, "origin_y": 140.0, "phase": 0.3, "wave_amp": 6.0, "generation": 0}, Vector2(480, 270), null)
	knight.state = BossActor.HOLD
	knight.fight_left = 40.0
	knight.position = Vector2(426, 140)
	knight._attack_cd = 0.0
	knight._attack_i = BossCatalog.attack_cycle("death_knight", 1).find("fake_charge")
	var feinted := false
	var charged_y := -1.0
	var player_y := 140.0
	t = 0.0
	while t < 2.0 and knight.state != BossActor.CHARGE:
		knight.fire_room = -1
		knight.tick(0.05, Vector2(120, player_y), 20.0, 1.0)
		t += 0.05
		if knight._fake_stage == 2 and knight.state != BossActor.CHARGE:
			feinted = true
			charged_y = knight._charge_y
	if not feinted or absf(charged_y - player_y) < 40.0:
		push_error("the fake charge should switch rows before it runs, y %s" % charged_y)
		failed += 1
	if knight.state != BossActor.CHARGE or absf(knight.position.y - player_y) < 40.0:
		push_error("the knight should charge the second row, state %s y %s" % [knight.state, knight.position.y])
		failed += 1
	var dragon := BossActor.new()
	dragon.setup(5, {"slug": "great_dragon", "hold_x": 410.0, "origin_y": 130.0, "phase": 0.2, "wave_amp": 10.0, "generation": 0}, Vector2(480, 270), null)
	if dragon.intro_left <= BossCatalog.LICH_INTRO:
		push_error("the dragon entrance should outlast the lich intro")
		failed += 1
	dragon.intro_left = 0.0
	if dragon.enraged or dragon.dragon_phase() != 1:
		push_error("a full-health dragon should be phase 1")
		failed += 1
	dragon.hp = int(float(dragon.max_hp) * 0.5)
	if dragon.enraged or dragon.dragon_phase() != 2:
		push_error("half health should be dragon phase 2, not the knight enrage")
		failed += 1
	dragon.hp = int(float(dragon.max_hp) * 0.2)
	if dragon.enraged or dragon.dragon_phase() != 3:
		push_error("a fifth of health should be dragon phase 3")
		failed += 1
	knight.free()
	dragon.free()
	return failed

func _check_bone_rain() -> int:
	var failed := 0
	var cycle := BossCatalog.attack_cycle("lich_king", 1)
	if cycle.find("bone_rain") < 0 or cycle.find("soul_beam") < 0 or cycle.find("grave_hands") < 0:
		push_error("lich attacks should keep bone rain with the new kit, got %s" % str(cycle))
		failed += 1
	var wind := BossCatalog.windup("bone_rain", 1, 0)
	if wind < 0.8 or wind > 1.0:
		push_error("bone rain telegraph should stay between 0.8 and 1.0 s, got %s" % wind)
		failed += 1
	var bone_w := HitLibrary.horizontal_extent(BossCatalog.BONE_SHOT, "threat")
	if bone_w < 2.0:
		push_error("the falling bone needs a threat shape")
		failed += 1
	var worst := 0.0
	for id in FormCatalog.IDS:
		for rank in 5:
			var file := str(FormCatalog.rank_spec(id, rank)["sprite"])
			worst = maxf(worst, HitLibrary.horizontal_extent(file, "hurt"))
	if BossCatalog.BONE_GAP - bone_w <= worst:
		push_error("bone columns are closer than the widest body (gap %.1f bone %.1f body %.1f)" % [BossCatalog.BONE_GAP, bone_w, worst])
		failed += 1
	for player_x in [40.0, 120.0, 210.0, 340.0]:
		for elapsed in [8.0, 90.0, 200.0]:
			var cols := BossCatalog.bone_columns(player_x, elapsed, 480.0)
			if cols.size() < 3 or cols.size() > 5:
				push_error("bone rain should mark 3 to 5 columns, got %s at x %.0f" % [str(cols), player_x])
				failed += 1
				continue
			var near := false
			for column in cols:
				if absf(column - player_x) <= 12.0 or absf(column - clampf(player_x, BossCatalog.BONE_LEFT, BossCatalog.BONE_RIGHT)) <= 0.1:
					near = true
			if not near:
				push_error("a bone column should sit on the player, got %s for x %.0f" % [str(cols), player_x])
				failed += 1
			for i in range(1, cols.size()):
				if cols[i] - cols[i - 1] + 0.01 < BossCatalog.BONE_GAP:
					push_error("bone columns lost their safe lane: %s" % str(cols))
					failed += 1
	var boss := BossActor.new()
	boss.setup(7, {"slug": "lich_king", "hold_x": 428.0, "origin_y": 140.0, "phase": 0.2, "wave_amp": 8.0, "generation": 0}, Vector2(480, 270), null)
	boss.state = BossActor.HOLD
	boss.intro_left = 0.0
	boss.fight_left = 30.0
	boss.position = Vector2(428, 140)
	boss.fire_room = 16
	boss._attack_cd = 0.0
	boss._attack_i = cycle.find("bone_rain")
	boss._summon_cd = 50.0
	var marked: Array[float] = []
	var warned := false
	var bones: Array[Dictionary] = []
	var warn_at := -1.0
	var fall_at := -1.0
	var t := 0.0
	while t < 2.2 and bones.size() < 3:
		var fired := boss.tick(0.05, Vector2(120, 130), 40.0, 1.0)
		t += 0.05
		if boss._rain_left > 0.4 and marked.is_empty():
			warned = true
			warn_at = t
			marked.append_array(boss._rain_columns)
		for spec in fired:
			if str(spec.get("sprite", "")) != BossCatalog.BONE_SHOT:
				continue
			bones.append(spec)
			if fall_at < 0.0:
				fall_at = t
	if not warned or marked.size() < 3:
		push_error("bone rain should telegraph columns before the bones fall")
		failed += 1
	elif fall_at < 0.0 or fall_at - warn_at < 0.75:
		push_error("bones fell too soon after the marks (warn %.2f fall %.2f)" % [warn_at, fall_at])
		failed += 1
	else:
		for spec in bones:
			var vel: Vector2 = spec["velocity"]
			var at: Vector2 = spec["position"]
			if absf(vel.x) > 0.1 or vel.y < 100.0:
				push_error("bones should fall straight down, got %s" % vel)
				failed += 1
				break
			var matched := false
			for column in marked:
				if absf(at.x - column) <= 1.0:
					matched = true
			if not matched:
				push_error("a bone spawned off its marked column at %s, marks %s" % [at, marked])
				failed += 1
				break
	boss.free()
	return failed

## Skull spiral, grave hands, bone rain, and the two enraged mixes.
## The across-map beam is only checked to still chain and keep its row.
func _check_lich_patterns() -> int:
	var failed := 0
	for sprite in [BossCatalog.SPIRAL_SKULL, BossCatalog.GRAVE_HAND, BossCatalog.BONE_SHOT]:
		if not _shot_hit_fits_sprite(sprite):
			var draw_s := BossCatalog.shot_draw_scale(sprite)
			var hit_s := BossCatalog.shot_hit_scale(sprite)
			push_error("%s hitbox is outside the drawn sprite (draw %.1f hit %.1f)" % [sprite, draw_s, hit_s])
			failed += 1
	if absf(BossCatalog.shot_hit_scale(BossCatalog.SPIRAL_SKULL) - 1.0) > 0.001:
		push_error("the spiral skull threat is authored for the doubled picture and should not scale again")
		failed += 1
	if absf(BossCatalog.shot_draw_scale(BossCatalog.SOUL_BEAM) - 1.0) > 0.001 or absf(BossCatalog.shot_hit_scale(BossCatalog.SOUL_BEAM) - 1.0) > 0.001:
		push_error("the soul beam art scale drifted")
		failed += 1
	var tall := 0.0
	for id in FormCatalog.IDS:
		for rank in 5:
			var file := str(FormCatalog.rank_spec(id, rank)["sprite"])
			tall = maxf(tall, HitLibrary.vertical_extent(file, "hurt"))
	var skull_h := HitLibrary.vertical_extent(BossCatalog.SPIRAL_SKULL, "threat") * BossCatalog.shot_hit_scale(BossCatalog.SPIRAL_SKULL)
	var lane_gap := BossCatalog.SPIRAL_LANE * 2.0 - BossCatalog.SPIRAL_WAVE * 2.0 - skull_h
	if lane_gap <= tall:
		push_error("spiral bands leave no lane (gap %.1f body %.1f)" % [lane_gap, tall])
		failed += 1
	var spiral := _fresh_lich()
	spiral.fire_room = 0
	spiral._attack_cd = 0.0
	spiral._attack_i = BossCatalog.attack_cycle("lich_king", 1).find("skull_spiral")
	var spiral_shots: Array[Dictionary] = []
	var t := 0.0
	while t < 2.4:
		var fired := spiral.tick(0.05, Vector2(150, 120), 40.0, 1.0)
		t += 0.05
		for spec in fired:
			if str(spec.get("sprite", "")) != BossCatalog.SPIRAL_SKULL:
				continue
			if t < BossCatalog.SPIRAL_WIND:
				push_error("a spiral skull fired before the warning finished")
				failed += 1
			spiral_shots.append(spec)
	if spiral_shots.size() < 6:
		push_error("the skull spiral should keep firing with an empty shot cap, got %d" % spiral_shots.size())
		failed += 1
	else:
		var low := false
		var high := false
		var body_left := spiral.position.x - ArtLibrary.anchor(spiral.sprite_file()).x
		for spec in spiral_shots:
			var at: Vector2 = spec["position"]
			var vel: Vector2 = spec["velocity"]
			if vel.x > -80.0 or absf(vel.y) > 1.0:
				push_error("spiral skulls should travel straight left, got %s" % vel)
				failed += 1
				break
			if at.x >= body_left - 4.0:
				push_error("a spiral skull spawned inside the lich at %s (body left %.1f)" % [at, body_left])
				failed += 1
				break
			var rel := at.y - (spiral.position.y + BossCatalog.SPIRAL_ORIGIN.y)
			if absf(absf(rel) - BossCatalog.SPIRAL_LANE) > BossCatalog.SPIRAL_WAVE + 1.5:
				push_error("a spiral skull left its warning band, y offset %s" % rel)
				failed += 1
				break
			if rel > 0.0:
				high = true
			else:
				low = true
		if not low or not high:
			push_error("the spiral should use both bands")
			failed += 1
	spiral.free()
	var hands := _fresh_lich()
	hands.fire_room = 0
	hands._attack_cd = 0.0
	hands._attack_i = BossCatalog.attack_cycle("lich_king", 1).find("grave_hands")
	var hand_shots: Array[Dictionary] = []
	var warned_hands: Array[float] = []
	t = 0.0
	while t < 1.6 and hand_shots.is_empty():
		var fired_hands := hands.tick(0.05, Vector2(180, 140), 30.0, 1.0)
		t += 0.05
		if hands._hands_left > 0.2 and warned_hands.is_empty():
			warned_hands.append_array(hands._hand_xs)
		for spec in fired_hands:
			if str(spec.get("sprite", "")) == BossCatalog.GRAVE_HAND:
				hand_shots.append(spec)
	if warned_hands.size() < 2 or hand_shots.size() != warned_hands.size():
		push_error("grave hands should warn then rise on those columns, warn %s shots %d" % [warned_hands, hand_shots.size()])
		failed += 1
	else:
		for spec in hand_shots:
			var at: Vector2 = spec["position"]
			var matched := false
			for column in warned_hands:
				if absf(at.x - column) <= 0.5:
					matched = true
			if not matched or absf(at.y - BossCatalog.HAND_START_Y) > 0.5:
				push_error("a grave hand did not start on its marked column, at %s marks %s" % [at, warned_hands])
				failed += 1
				break
			if absf(float(spec.get("halt_y", -1.0)) - BossCatalog.HAND_HALT_Y) > 0.1:
				push_error("a grave hand has no hold height")
				failed += 1
				break
			var risen := Shot.new()
			risen.setup(spec, false)
			var guard := 0
			while risen.velocity.y < -1.0 and risen.life > 0.0 and guard < 80:
				risen.tick(0.05)
				guard += 1
			if absf(risen.position.y - BossCatalog.HAND_HALT_Y) > 1.0 or risen.velocity.length() > 0.1:
				push_error("a grave hand should rise and hold, y %s vel %s" % [risen.position.y, risen.velocity])
				failed += 1
			var held := risen.position.y
			risen.tick(0.05)
			if absf(risen.position.y - held) > 0.01:
				push_error("a grave hand drifted after it held")
				failed += 1
			risen.free()
	hands.free()
	var rain := _fresh_lich()
	rain.fire_room = 0
	rain._attack_cd = 0.0
	rain._attack_i = BossCatalog.attack_cycle("lich_king", 1).find("bone_rain")
	var marks: Array[float] = []
	var bone_specs: Array[Dictionary] = []
	t = 0.0
	while t < 2.0 and bone_specs.size() < 2:
		var fired_bones := rain.tick(0.05, Vector2(160, 120), 40.0, 1.0)
		t += 0.05
		if rain._rain_left > 0.3 and marks.is_empty():
			marks.append_array(rain._rain_columns)
		for spec in fired_bones:
			if str(spec.get("sprite", "")) == BossCatalog.BONE_SHOT:
				bone_specs.append(spec)
	if marks.size() < 3 or bone_specs.is_empty():
		push_error("bone rain should mark columns and then drop bones")
		failed += 1
	else:
		for column in marks:
			if absf(BossCatalog.bone_mark_at(column).x - column) > 0.01:
				push_error("the bone warning mark left its column")
				failed += 1
				break
		var land := BossCatalog.bone_land_y()
		for spec in bone_specs:
			var at: Vector2 = spec["position"]
			var on_mark := false
			for column in marks:
				if absf(at.x - column) <= 0.5 and absf(BossCatalog.bone_mark_at(column).y - land) <= 0.01:
					on_mark = true
			if not on_mark:
				push_error("a bone did not spawn on a marked column at %s" % at)
				failed += 1
				break
			var bone := Shot.new()
			bone.setup(spec, false)
			var speed := float((spec["velocity"] as Vector2).y)
			var steps := 0
			while bone.life > 0.0 and steps < 200:
				bone.tick(0.05)
				steps += 1
			if bone.life > 0.0 or bone.position.y > land + speed * 0.05 + 1.5:
				push_error("a bone should vanish at the ground mark, y %s land %s life %s" % [bone.position.y, land, bone.life])
				failed += 1
			bone.free()
	rain.free()
	var mix := _fresh_lich()
	mix.hp = int(mix.max_hp / 2)
	mix.enraged = true
	mix.fire_room = 0
	mix._attack_cd = 0.0
	mix._attack_i = BossCatalog.attack_cycle("lich_king", 2).find("beam_rain")
	mix.tick(0.05, Vector2(150, 110), 40.0, 1.0)
	if mix._attack_id != "beam_rain" or mix._beam_mode != 1 or mix._rain_columns.size() < 3:
		push_error("beam rain should keep both the beam and the columns, id %s mode %s cols %s" % [mix._attack_id, mix._beam_mode, mix._rain_columns])
		failed += 1
	var mix_bones := 0
	var mix_beam := 0
	t = 0.0
	while t < 2.4 and (mix_bones < 2 or mix_beam < 4):
		mix.fire_room = 0
		for spec in mix.tick(0.05, Vector2(150, 110), 40.0, 1.0):
			var picture := str(spec.get("sprite", ""))
			if picture == BossCatalog.BONE_SHOT:
				mix_bones += 1
			elif picture == BossCatalog.SOUL_BEAM:
				mix_beam += 1
		t += 0.05
	if mix_bones < 2 or mix_beam < 4:
		push_error("beam rain should fire bones and the beam, bones %d beam %d" % [mix_bones, mix_beam])
		failed += 1
	mix.free()
	var chained := _fresh_lich()
	chained.hp = int(chained.max_hp / 2)
	chained.enraged = true
	chained._attack_cd = 0.0
	chained._attack_i = BossCatalog.attack_cycle("lich_king", 2).find("double_beam")
	chained._summon_cd = 80.0
	chained.tick(0.05, Vector2(120, 100), 40.0, 1.0)
	if chained._attack_id != "double_beam" or chained._beam_chain != 1 or chained._beam_mode != 1:
		push_error("double beam should still arm a second pass, id %s chain %s mode %s" % [chained._attack_id, chained._beam_chain, chained._beam_mode])
		failed += 1
	var second := false
	t = 0.05
	while t < 3.4:
		chained.fire_room = -1
		chained.tick(0.05, Vector2(120, 160), 40.0, 1.0)
		t += 0.05
		if chained._beam_chain == 0 and chained._beam_mode == 1 and t > 1.2:
			second = true
			break
	if not second:
		push_error("double beam should start a second track after the first row")
		failed += 1
	chained.free()
	var both := _fresh_lich()
	both.hp = int(both.max_hp / 2)
	both.enraged = true
	both.fire_room = 0
	both._attack_cd = 0.0
	both._attack_i = BossCatalog.attack_cycle("lich_king", 2).find("spiral_hands")
	both.tick(0.05, Vector2(170, 140), 40.0, 1.0)
	if both._attack_id != "spiral_hands" or both._spiral_wind <= 0.0 or both._hand_xs.size() < 2:
		push_error("spiral hands should warn with both patterns, id %s wind %s cols %s" % [both._attack_id, both._spiral_wind, both._hand_xs])
		failed += 1
	both.free()
	return failed

func _fresh_lich() -> BossActor:
	var boss := BossActor.new()
	boss.setup(11, {"slug": "lich_king", "hold_x": 428.0, "origin_y": 128.0, "phase": 0.2, "wave_amp": 0.0, "generation": 0}, Vector2(480, 270), null)
	boss.state = BossActor.HOLD
	boss.intro_left = 0.0
	boss.fight_left = 40.0
	boss.position = Vector2(428, 128)
	boss._summon_cd = 80.0
	return boss

func _shot_hit_fits_sprite(sprite: String) -> bool:
	if not HitLibrary.contains_local(sprite, "threat", Vector2.ZERO):
		return false
	var draw_s := BossCatalog.shot_draw_scale(sprite)
	var hit_s := BossCatalog.shot_hit_scale(sprite)
	var anchor := ArtLibrary.anchor(sprite) * draw_s
	var size := ArtLibrary.art_bbox(sprite) * draw_s
	var across := HitLibrary.horizontal_span(sprite, "threat") * hit_s
	var down := HitLibrary.vertical_span(sprite, "threat") * hit_s
	var slop := 2.0
	if across.x < -anchor.x - slop or across.y > size.x - anchor.x + slop:
		return false
	if down.x < -anchor.y - slop or down.y > size.y - anchor.y + slop:
		return false
	if absf((across.x + across.y) * 0.5) > 3.0 or absf((down.x + down.y) * 0.5) > 3.0:
		return false
	return true

func _check_boss_gaps() -> int:
	var failed := 0
	var top := 28.0
	var bottom := 214.0
	var bullet := HitLibrary.vertical_span(BossCatalog.DRAGON_SHOT, "threat")
	var worst := 0.0
	for id in FormCatalog.IDS:
		for rank in 5:
			var file := str(FormCatalog.rank_spec(id, rank)["sprite"])
			worst = maxf(worst, HitLibrary.vertical_extent(file, "hurt"))
	var reach := 220.0
	var wide := 0.0
	for id in FormCatalog.IDS:
		for rank in 5:
			var file := str(FormCatalog.rank_spec(id, rank)["sprite"])
			wide = maxf(wide, HitLibrary.horizontal_extent(file, "hurt"))
	for phase in [1, 2, 3]:
		for generation in [0, 2, 4]:
			for pattern in BossCatalog.attack_cycle("great_dragon", phase):
				var wind := BossCatalog.windup(pattern, phase, generation)
				if wind < 0.36:
					push_error("%s telegraph is too short (%.2f)" % [pattern, wind])
					failed += 1
				if pattern == "wing_gust":
					continue
				if pattern == "boss_meteor":
					var meteor_w := HitLibrary.horizontal_extent(BossCatalog.BOSS_METEOR, "threat")
					var opening := BossCatalog.METEOR_SPACING - meteor_w
					if opening <= wide:
						push_error("boss meteors leave no sideways gap")
						failed += 1
					if wide * 0.5 + meteor_w * 0.5 > wind * reach:
						push_error("boss meteor warning does not leave time to step aside")
						failed += 1
					continue
				if pattern == "dive":
					var span := HitLibrary.vertical_span("great_dragon.png", "threat")
					var band := span.y - span.x
					if bottom - top - band <= worst:
						push_error("the dragon dive covers the field")
						failed += 1
					if band * 0.5 + worst * 0.5 > wind * reach:
						push_error("the dive warning does not leave time to leave the row")
						failed += 1
					continue
				for boss_y in [80.0, 120.0, 160.0]:
					for aim_y in [70.0, 120.0, 170.0]:
						for column in [110.0, 190.0, 270.0]:
							var origin := Vector2(BossCatalog.rest_x("great_dragon"), boss_y)
							var aim := Vector2(column, aim_y)
							var speed := BossCatalog.bullet_speed(phase, generation)
							var blocks: Array[Vector2] = []
							for spec in BossCatalog.shot_plan(pattern, phase, generation, origin, aim, speed):
								var crossed: Variant = BossCatalog.cross_y(origin, spec["offset"], spec["velocity"], column)
								if crossed == null:
									continue
								var y := float(crossed)
								blocks.append(Vector2(y + bullet.x, y + bullet.y))
							var gap := BossCatalog.widest_gap(blocks, top, bottom)
							if gap <= worst:
								push_error("%s phase %d leaves no gap (%.1f vs %.1f)" % [pattern, phase, gap, worst])
								return failed + 1
							var need := _nearest_boss_gap(aim_y, blocks, worst, top, bottom)
							if need > wind * reach + 0.5:
								push_error("%s phase %d needs %.1f px inside a %.2f s warning" % [pattern, phase, need, wind])
								return failed + 1
	return failed

func _nearest_boss_gap(aim_y: float, blocks: Array[Vector2], height: float, top: float, bottom: float) -> float:
	var half := height * 0.5
	var lo := top + half
	var hi := bottom - half
	if hi < lo:
		return 9999.0
	var best := 9999.0
	var y := lo
	while y <= hi:
		var body := Vector2(y - half, y + half)
		var clear := true
		for block in blocks:
			if body.y > block.x and body.x < block.y:
				clear = false
				break
		if clear:
			best = minf(best, absf(y - aim_y))
		y += 2.0
	return best

func _check_boss_flee() -> int:
	var failed := 0
	var field := Vector2(480, 270)
	for slug in ["lich_king", "death_knight"]:
		var boss := BossActor.new()
		boss.setup(1, {"slug": slug, "hold_x": 400.0, "origin_y": 120.0, "phase": 0.2, "wave_amp": 14.0, "generation": 0}, field, null)
		var t := 0.0
		while t < 40.0 and boss.alive:
			boss.tick(0.1, Vector2(80, 120), t, 1.0)
			t += 0.1
		if not boss.alive or boss.state == BossActor.FLEE or boss.hp != boss.max_hp or boss.position.x > field.x:
			push_error("%s should stay until killed, alive %s state %s hp %s x %.1f" % [slug, boss.alive, boss.state, boss.hp, boss.position.x])
			failed += 1
		boss.intro_left = 0.0
		boss.hurt(boss.max_hp / 2 - 1)
		if boss.enraged or boss.hp * 2 <= boss.max_hp:
			push_error("%s should stay calm above half health, hp %s / %s" % [slug, boss.hp, boss.max_hp])
			failed += 1
		boss.hurt(1)
		if not boss.enraged or boss.hp * 2 > boss.max_hp:
			push_error("half health should enrage %s, hp %s / %s" % [slug, boss.hp, boss.max_hp])
			failed += 1
		boss.hurt(boss.hp)
		if boss.alive:
			push_error("%s should die when its hp is gone" % slug)
			failed += 1
		boss.free()
	var dragon := BossActor.new()
	dragon.setup(2, {"slug": "great_dragon", "hold_x": 404.0, "origin_y": 130.0, "phase": 1.0, "wave_amp": 16.0, "generation": 0}, field, null)
	var elapsed := 0.0
	while elapsed < 36.0:
		dragon.tick(0.1, Vector2(90, 100), 170.0, 2.2)
		elapsed += 0.1
	if not dragon.alive or dragon.max_hp != 10000 or dragon.hp != 10000:
		push_error("the dragon should stay at 10000 hp until it dies, hp %s / %s alive %s" % [dragon.hp, dragon.max_hp, dragon.alive])
		failed += 1
	dragon.hp = dragon.max_hp / 2
	if dragon.enraged or dragon.dragon_phase() != 2:
		push_error("half health should be dragon phase 2")
		failed += 1
	dragon.free()
	return failed

## A regular boss that never leaves must not hold the dragon's clock, and
## after that first dragon only the dragon comes back.
func _check_dragon_not_blocked() -> int:
	var failed := 0
	var director := BossDirector.new(20261101)
	var at := director.dragon_at
	director.set_boss_alive(true)
	var early := director.pop_due(at - 1.0)
	if not early.is_empty():
		push_error("a living regular should hold spawns until the dragon is due, got %s" % str(early))
		failed += 1
	var opened := director.pop_due(at)
	if opened.size() != 1 or str(opened[0]["slug"]) != "great_dragon" or int(opened[0]["generation"]) != 0:
		push_error("the dragon should arrive on time over a living regular, got %s" % str(opened))
		failed += 1
	elif BossCatalog.max_hp("great_dragon", int(opened[0]["generation"])) != 10000:
		push_error("the first dragon should be 10000 hp")
		failed += 1
	director.set_boss_alive(false)
	var gap := director.pop_due(at + 30.0)
	if not gap.is_empty():
		push_error("regular bosses should not spawn after the first dragon, got %s" % str(gap[0]))
		failed += 1
	director.on_dragon_killed(at + 12.0)
	var wait := director.pop_due(at + 12.0 + BossDirector.DRAGON_RETURN - 1.0)
	if not wait.is_empty():
		push_error("the dragon should wait out the 60 s return, got %s" % str(wait))
		failed += 1
	var back := director.pop_due(at + 12.0 + BossDirector.DRAGON_RETURN)
	if back.size() != 1 or str(back[0]["slug"]) != "great_dragon" or int(back[0]["generation"]) != 1:
		push_error("only the dragon should return, got %s" % str(back))
		failed += 1
	elif BossCatalog.max_hp("great_dragon", int(back[0]["generation"])) != 20000:
		push_error("the returned dragon should be 20000 hp")
		failed += 1
	return failed

## The live clock clears a Lich or Knight with no kill reward when the dragon is due.
func _check_dragon_displaces_regular() -> int:
	var failed := 0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game.phase = game.PHASE_PLAY
	game.form_id = FormCatalog.Id.SLIME
	game._player.form_id = FormCatalog.Id.SLIME
	game.invuln = 30.0
	game._player.invulnerable = true
	game._tutorial_active = false
	game._director._next_time = 100000.0
	if not game._spawn_boss({"slug": "lich_king", "generation": 0, "hold_x": 428.0, "origin_y": 140.0, "phase": 0.2, "wave_amp": 8.0}, Vector2(480, 270)):
		push_error("the lich that should yield to the dragon did not spawn")
		root.remove_child(game)
		game.free()
		return 1
	var lich: BossActor = game._living_boss()
	lich.intro_left = 0.0
	lich.state = BossActor.HOLD
	lich.position = Vector2(428, 140)
	var before: int = game.score
	var deaths_before: int = game._sound.play_count(BossCatalog.cue("lich_king", "death"))
	var gems_before: int = game._loot.size()
	game.elapsed = game._boss_director.dragon_at
	game._process(1.0 / 60.0)
	var boss: EnemyActor = game._living_boss()
	if boss == null or boss.boss_slug != "great_dragon" or boss.max_hp != 10000 or boss.hp != 10000:
		push_error("the dragon should replace a living lich at 10000 hp, got %s" % (boss.kind_name if boss != null else "nobody"))
		failed += 1
	if is_instance_valid(lich) and lich.alive:
		push_error("the lich should be gone when the dragon arrives")
		failed += 1
	if game._sound.play_count(BossCatalog.cue("lich_king", "death")) != deaths_before:
		push_error("clearing the lich for the dragon should stay silent")
		failed += 1
	if game.score != before:
		push_error("clearing the lich for the dragon should not pay score, got %s" % game.score)
		failed += 1
	if game._loot.size() != gems_before:
		push_error("clearing the lich for the dragon should not drop gems")
		failed += 1
	var regulars := 0
	game._boss_director.set_boss_alive(false)
	var kill_at: float = game.elapsed
	game._boss_director.on_dragon_killed(kill_at)
	var t: float = kill_at
	while t < kill_at + BossDirector.DRAGON_RETURN + 1.0:
		t += 0.5
		game._boss_director.set_boss_alive(false)
		for event in game._boss_director.pop_due(t):
			if str(event["slug"]) != "great_dragon":
				regulars += 1
	if regulars != 0:
		push_error("lich and knight should not return after the first dragon")
		failed += 1
	root.remove_child(game)
	game.free()
	return failed

func _check_dragon_form() -> int:
	var failed := 0
	if FormCatalog.IDS.find(FormCatalog.Id.DRAGON) >= 0:
		push_error("the dragon form must stay out of the random roll")
		failed += 1
	for run in 12:
		for seed_value in [20261101, 20261104, 7]:
			if FormCatalog.id_for_run(seed_value, run) == FormCatalog.Id.DRAGON:
				push_error("a daily roll produced the dragon form")
				failed += 1
	var best := 0.0
	var fastest := 99.0
	var shot_speed := 0.0
	var move := 0.0
	for id in FormCatalog.IDS:
		var shots := FormCatalog.player_shots(id, Vector2.ZERO, 4)
		var total := 0
		for spec in shots:
			total += int(spec["damage"])
			shot_speed = maxf(shot_speed, float(spec["velocity"].length()))
		if id == FormCatalog.Id.DEMON:
			total = FormCatalog.demon_damage(4, int(FormCatalog.DEMON["enemy_cap"])) * shots.size()
			shot_speed = maxf(shot_speed, FormCatalog.demon_speed(4, int(FormCatalog.DEMON["enemy_cap"])))
		var interval := float(FormCatalog.rank_spec(id, 4)["fire_interval"])
		fastest = minf(fastest, interval)
		best = maxf(best, float(total) / interval)
		move = maxf(move, FormCatalog.max_speed(id))
	var dragon_shots := FormCatalog.player_shots(FormCatalog.Id.DRAGON, Vector2.ZERO, 0)
	if dragon_shots.size() != 1:
		push_error("the dragon attack should fire 1 fireball")
		failed += 1
	var dragon_dmg := 0
	var base_radius := HitLibrary.bounds_radius(FormCatalog.DRAGON_SHOT, "body")
	for spec in dragon_shots:
		dragon_dmg += int(spec["damage"])
		var vel: Vector2 = spec["velocity"]
		if absf(vel.length() - FormCatalog.DRAGON_SHOT_SPEED) > 0.6:
			push_error("dragon fireballs should keep speed %.1f, got %.1f" % [FormCatalog.DRAGON_SHOT_SPEED, vel.length()])
			failed += 1
		if absf(vel.y) > 0.01 or vel.x <= 0.0:
			push_error("the dragon fireball should fly straight ahead, vel %s" % vel)
			failed += 1
		if int(spec["damage"]) != 10:
			push_error("the dragon fireball should deal 10, got %s" % spec["damage"])
			failed += 1
		if absf(float(spec.get("scale", 1.0)) - FormCatalog.DRAGON_SHOT_SCALE) > 0.001:
			push_error("the dragon fireball should draw at 3x, scale %s" % spec.get("scale", 1.0))
			failed += 1
		if absf(float(spec["radius"]) - base_radius * FormCatalog.DRAGON_SHOT_SCALE) > 0.01:
			push_error("the dragon fireball hit radius should be 3x, got %s base %s" % [spec["radius"], base_radius])
			failed += 1
	var weapon := FormCatalog.weapon_line(FormCatalog.Id.DRAGON, 0)
	if weapon.find("1 fireball") < 0 or weapon.find("Fan") >= 0 or weapon.find("Meteor Rain in 50") < 0 or weapon.find("Dmg 10") < 0 or weapon.find("splash 8") < 0:
		push_error("dragon card should describe one fireball, dmg 10, splash 8, and 50 kills, got %s" % weapon)
		failed += 1
	if FormCatalog.DRAGON_METEOR_KILLS != 50:
		push_error("meteor rain should charge in 50 kills, got %s" % FormCatalog.DRAGON_METEOR_KILLS)
		failed += 1
	var dragon_trait := FormCatalog.trait_line(FormCatalog.Id.DRAGON, true)
	if dragon_trait.find("Meteor Rain in 50 kills") < 0 or dragon_trait.find("15%") < 0:
		push_error("dragon trait should name Meteor Rain at 50 kills, got %s" % dragon_trait)
		failed += 1
	if FormCatalog.DRAGON_SPLASH != 8 or absf(FormCatalog.DRAGON_SPLASH_RADIUS - 126.0) > 0.01:
		push_error("splash damage stays 8 and the radius is 3x (126), got %s / %s" % [FormCatalog.DRAGON_SPLASH, FormCatalog.DRAGON_SPLASH_RADIUS])
		failed += 1
	var dragon_dps := float(dragon_dmg) / FormCatalog.DRAGON_FIRE_INTERVAL
	if dragon_dps + 0.01 < best:
		push_error("dragon dps %.1f is under the best rank-5 form %.1f" % [dragon_dps, best])
		failed += 1
	if FormCatalog.DRAGON_FIRE_INTERVAL > fastest + 0.0001:
		push_error("dragon fire rate should be at least as fast as rank 5")
		failed += 1
	if FormCatalog.DRAGON_SHOT_SPEED + 0.1 < shot_speed:
		push_error("dragon shots should be at least as fast as rank 5")
		failed += 1
	if FormCatalog.DRAGON_MAX_SPEED + 0.1 < move:
		push_error("dragon move speed should be at least the fastest rank-5 form")
		failed += 1
	if dragon_shots.is_empty() or int(dragon_shots[0]["splash"]) != FormCatalog.DRAGON_SPLASH or absf(float(dragon_shots[0]["splash_radius"]) - FormCatalog.DRAGON_SPLASH_RADIUS) > 0.01:
		push_error("dragon fireballs should splash for 8 inside a 126px radius")
		failed += 1
	var body_img := ArtLibrary.texture("dragon_form/dragon_fly_body.png").get_image()
	var fx_img := ArtLibrary.texture("dragon_form/dragon_fly_fx.png").get_image()
	var anchor := ArtLibrary.anchor("dragon_form/dragon_fly_body.png")
	var frame_w := int(ArtLibrary.entry("dragon_form/dragon_fly.png")["frame_size"][0])
	var frame_h := int(ArtLibrary.entry("dragon_form/dragon_fly.png")["frame_size"][1])
	var frames := int(ArtLibrary.entry("dragon_form/dragon_fly.png")["frames"])
	if absf(float(ArtLibrary.entry("dragon_form/dragon_fly.png")["fps"]) - 10.0) > 0.01:
		push_error("dragon fly loop should play at 10 fps")
		failed += 1
	if absf(float(ArtLibrary.entry("dragon_form/dragon_meter_ready.png")["fps"]) - 6.0) > 0.01:
		push_error("meteor meter ready loop should play at 6 fps")
		failed += 1
	for fi in frames:
		var ox := fi * frame_w
		var body_miss := 0
		var fx_hit := 0
		for y in frame_h:
			for x in frame_w:
				var local := Vector2(x + 0.5, y + 0.5) - anchor
				var body_on := body_img.get_pixel(ox + x, y).a >= 0.5
				var fx_on := fx_img.get_pixel(ox + x, y).a >= 0.5
				var inside := HitLibrary.contains_local("dragon_form/dragon_fly.png", "hurt", local, fi)
				if body_on and not inside:
					body_miss += 1
				if fx_on and not body_on and inside:
					fx_hit += 1
		if body_miss > 0 or fx_hit > 0:
			push_error("dragon frame %d hurt missed %d body pixels and included %d wing or tail pixels" % [fi, body_miss, fx_hit])
			failed += 1
			break
	var fit := FormCatalog.dragon_fit_scale("slime_r5_body.png", 1.0)
	if absf(fit - 1.0) > 0.001:
		push_error("the dragon sheet is native size and should draw at 1x")
		failed += 1
	var dragon_w := HitLibrary.horizontal_extent("dragon_form/dragon_fly.png", "hurt") * fit
	var dragon_h := HitLibrary.vertical_extent("dragon_form/dragon_fly.png", "hurt") * fit
	var demon_w := HitLibrary.horizontal_extent("demon_lord_r5_body.png", "hurt") * FormCatalog.DEMON_PLAY_SCALE
	var demon_h := HitLibrary.vertical_extent("demon_lord_r5_body.png", "hurt") * FormCatalog.DEMON_PLAY_SCALE
	var vend_w := HitLibrary.horizontal_extent("vending_machine_r5_body.png", "hurt") * FormCatalog.VENDING_PLAY_SCALE
	var vend_h := HitLibrary.vertical_extent("vending_machine_r5_body.png", "hurt") * FormCatalog.VENDING_PLAY_SCALE
	if dragon_w + 0.5 < maxf(demon_w, vend_w) or dragon_h + 0.5 < maxf(demon_h, vend_h):
		push_error("dragon body %.1fx%.1f is smaller than the larger r5 body" % [dragon_w, dragon_h])
		failed += 1
	if dragon_w > 56.0 or dragon_h > 56.0:
		push_error("dragon hurt should stay on the body, got %.1fx%.1f" % [dragon_w, dragon_h])
		failed += 1
	var goblin_w := HitLibrary.horizontal_extent("goblin_r5_body.png", "hurt")
	var goblin_ratio := FormCatalog.max_speed(FormCatalog.Id.GOBLIN) / goblin_w
	if FormCatalog.DRAGON_MAX_SPEED / dragon_w + 0.01 < goblin_ratio:
		push_error("dragon speed does not make up for the wider body (%.1f / %.2f vs goblin %.2f)" % [FormCatalog.DRAGON_MAX_SPEED, dragon_w, goblin_ratio])
		failed += 1
	var body := Leaderboard.submit_body("dev", "Ada", "slime", 10, 1000, false)
	if body.has("p_dragon_slayer"):
		push_error("a normal run should omit the dragon-slayer flag")
		failed += 1
	var slayer := Leaderboard.submit_body("dev", "Ada", "slime", 10, 1000, true)
	if slayer.get("p_dragon_slayer", false) != true:
		push_error("a dragon-slayer run should send the flag")
		failed += 1
	if not Leaderboard.rejects_dragon_flag({"ok": false, "error": "Could not find the function public.submit_score", "data": {"code": "PGRST202"}}):
		push_error("an old leaderboard should be detected from PGRST202")
		failed += 1
	if Leaderboard.rejects_dragon_flag({"ok": false, "error": "bad_score", "data": {}}):
		push_error("a rejected score is not an old schema")
		failed += 1
	var screen := LeaderboardScreen.new()
	screen.setup(Leaderboard.new(), load("res://ui/font_kaito5x7_outlined.fnt"))
	root.add_child(screen)
	screen.size = Vector2(480, 270)
	screen.preview([{"rank": 1, "name": "Ada", "score": 100, "form": "slime", "is_me": false, "dragon_slayer": true}], "")
	var tagged := screen._list.get_child(0).get_node_or_null("Name/Dragonslayer")
	if tagged == null:
		push_error("a dragon-slayer row should show the title")
		failed += 1
	root.remove_child(screen)
	screen.free()
	return failed

func _boot_play_game() -> Node:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game.phase = game.PHASE_PLAY
	game._reveal.visible = false
	if game._hint_label != null:
		game._hint_label.visible = false
	if game._world_flash != null:
		game._world_flash.visible = false
	game._world_flash_left = 0.0
	game.invuln = 0.0
	game._player.invulnerable = false
	game._player.alive = true
	game._clear_field()
	return game

func _finish_show(show: DragonShow) -> void:
	var guard := 0
	while show.phase != DragonShow.IDLE and guard < 400:
		show.tick(DragonShow.FRAME)
		guard += 1
	for _extra in 45:
		show.tick(DragonShow.FRAME)

func _check_meteor_shake() -> int:
	var failed := 0
	if absf(DragonShow.SLAM_SHAKE_PX - 2.0) > 0.001 or absf(DragonShow.SLAM_SHAKE_SECONDS - 0.2) > 0.001:
		push_error("the giant slam bump should be 2px for 0.2s")
		failed += 1
	var game = _boot_play_game()
	game.form_id = FormCatalog.Id.DRAGON
	game._player.adopt_dragon(1.0)
	game._dragon_show.rng_seed = 11
	game.position = Vector2.ZERO
	# Shakes that are not the slam must stay quiet for the whole show.
	game._juice_shake = Replay.JUICE_SHAKE_SECONDS
	game._shake_left = Difficulty.FINAL_SHAKE_SECONDS
	game._dragon_shake(4.0, 0.45)
	game._dragon_show.start_rain()
	var dt := 1.0 / 60.0
	var charge_rain_moved := false
	var fall_moved := false
	var poked := false
	var saw_slam := false
	var after_show := false
	var bump: Array[Vector2] = []
	var guard := 0
	while guard < 800:
		guard += 1
		game._dragon_show.tick(DragonShow.FRAME)
		var phase := int(game._dragon_show.phase)
		if phase == DragonShow.RAIN and not poked:
			poked = true
			game._bump_shake()
			game._dragon_shake(4.0, 0.45)
		if phase == DragonShow.SLAM:
			saw_slam = true
		for _render in 4:
			game._apply_shake(dt)
			var off: Vector2 = game.position
			if phase == DragonShow.CHARGE or phase == DragonShow.RAIN:
				if off != Vector2.ZERO:
					charge_rain_moved = true
			elif phase == DragonShow.FALL:
				if off != Vector2.ZERO:
					fall_moved = true
			elif saw_slam:
				bump.append(off)
		if phase == DragonShow.IDLE and saw_slam:
			after_show = true
			if game.position != Vector2.ZERO:
				push_error("shake should be back to zero after meteor rain, offset %s" % game.position)
				failed += 1
			var stayed := true
			for _extra in 8:
				game._apply_shake(dt)
				if game.position != Vector2.ZERO:
					stayed = false
			if not stayed:
				push_error("shake should stay zero after the finale, offset %s" % game.position)
				failed += 1
			break
	if not poked:
		push_error("meteor shake check never reached the rain")
		failed += 1
	if charge_rain_moved:
		push_error("shake offset should be zero throughout the meteor charge and rain")
		failed += 1
	if fall_moved:
		push_error("the giant meteor's fall should not shake the screen")
		failed += 1
	if not saw_slam or not after_show:
		push_error("meteor shake check did not finish the slam")
		failed += 1
	var runs: Array[Vector2] = []
	var run_len: Array[int] = []
	var spans := 0
	var in_bump := false
	for sample in bump:
		if sample != Vector2.ZERO:
			if not in_bump:
				spans += 1
				in_bump = true
			if runs.is_empty() or sample != runs[runs.size() - 1]:
				runs.append(sample)
				run_len.append(1)
			else:
				run_len[run_len.size() - 1] += 1
		else:
			in_bump = false
	if spans != 1 or runs.size() != 2 or runs[0] != Vector2(2, 0) or runs[1] != Vector2(1, 0):
		push_error("the finale should be one bump, 2px then 1px, got %s" % str(runs))
		failed += 1
	elif run_len[0] < 4 or run_len[1] < 4:
		push_error("slam bump should hold each offset for a show frame, held %s" % str(run_len))
		failed += 1
	# A shake that is not part of the show still moves the screen afterward.
	game._bump_shake()
	var juice := false
	for _i in 8:
		game._apply_shake(dt)
		if game.position != Vector2.ZERO and game.position.length() <= Replay.JUICE_SHAKE_PX + 0.01:
			juice = true
	if not juice:
		push_error("a hit shake after meteor rain should still move the screen")
		failed += 1
	root.remove_child(game)
	game.free()
	return failed

func _check_meteor_rain() -> int:
	var failed := 0
	var show := DragonShow.new()
	show.rng_seed = 3
	show.start_rain()
	var saw_flying := false
	var saw_impact := false
	for _i in DragonShow.CHARGE_FRAMES + DragonShow.RAIN_FRAMES:
		show.tick(DragonShow.FRAME)
		if not saw_flying:
			for item in show._meteors:
				if item.get("on", false) and int(item.get("boom", -1)) < 0:
					var at: Vector2 = item["pos"]
					saw_flying = true
					if not show.blocks_bullet(at, 4.0) or not show.blocks_bullet(at, 0.0):
						push_error("a bullet overlapping a falling meteor should be blocked")
						failed += 1
					if show.blocks_bullet(at + Vector2(DragonShow.METEOR_HIT_RADIUS + 2.0, 0), 0.0):
						push_error("meteor block radius should match the 78px body")
						failed += 1
					if show.blocks_bullet(Vector2(-800, -800), 4.0):
						push_error("a bullet far from every meteor should survive")
						failed += 1
					break
		if not saw_impact and not show._impacts.is_empty():
			var blast: Vector2 = show._impacts[0]["pos"]
			saw_impact = true
			if not show.blocks_bullet(blast, 4.0):
				push_error("a bullet inside an impact should be blocked")
				failed += 1
		if saw_flying and saw_impact:
			break
	if not saw_flying or not saw_impact:
		push_error("the rain should have a falling meteor and an impact to test bullets")
		failed += 1
	_finish_show(show)
	show.free()
	var game = _boot_play_game()
	game.form_id = FormCatalog.Id.DRAGON
	game._player.adopt_dragon(1.0)
	game._player.position = Vector2(80, 140)
	game._begin_lair_transition()
	if game._lair == null or not game._lair.running:
		push_error("the lair transition should be running when the rain starts")
		failed += 1
	game._dragon_show.rng_seed = 9
	game._dragon_show.start_rain()
	var near: Shot = game._spawn_shot({
		"position": Vector2.ZERO,
		"velocity": Vector2(-10, 0),
		"sprite": "floating_eye_bolt.png",
		"radius": 4.0,
		"damage": 1,
		"killer_name": "bolt",
	}, false)
	var inside: Shot = game._spawn_shot({
		"position": Vector2(1, 1),
		"velocity": Vector2(-10, 0),
		"sprite": "floating_eye_bolt.png",
		"radius": 4.0,
		"damage": 1,
		"killer_name": "boss",
	}, false)
	var far: Shot = game._spawn_shot({
		"position": Vector2(8, 8),
		"velocity": Vector2(-10, 0),
		"sprite": "floating_eye_bolt.png",
		"radius": 4.0,
		"damage": 1,
		"killer_name": "bolt",
	}, false)
	var placed_near := false
	var placed_impact := false
	for _i in DragonShow.CHARGE_FRAMES + DragonShow.RAIN_FRAMES:
		game._dragon_show.tick(DragonShow.FRAME)
		if not placed_near:
			for item in game._dragon_show._meteors:
				if item.get("on", false) and int(item.get("boom", -1)) < 0:
					near.position = item["pos"]
					placed_near = true
					break
		if not placed_impact and not game._dragon_show._impacts.is_empty():
			inside.position = game._dragon_show._impacts[0]["pos"]
			placed_impact = true
		if placed_near and placed_impact:
			for item in game._dragon_show._meteors:
				if item.get("on", false) and int(item.get("boom", -1)) < 0:
					near.position = item["pos"]
					break
			inside.position = game._dragon_show._impacts[0]["pos"]
			break
	far.position = Vector2(24, 250)
	if game._dragon_show.blocks_bullet(far.position, far.radius):
		push_error("the control bullet should sit clear of every meteor")
		failed += 1
	if not placed_near or not placed_impact:
		push_error("could not place bullets on a meteor and an impact")
		failed += 1
	else:
		game._block_meteor_bullets()
		if game._shots.has(near) or game._shots.has(inside) or not game._shots.has(far):
			push_error("meteor overlap and impact bullets should be removed, and a far bullet should stay")
			failed += 1
	if absf(game._meteor_guard - game.METEOR_INVULN_SECONDS) > 0.02 or not game._player.invulnerable:
		push_error("meteor rain should open with %.2fs of invuln, guard %s" % [game.METEOR_INVULN_SECONDS, game._meteor_guard])
		failed += 1
	var open_marker: Label = game._hud.get_node_or_null("InvincibleMarker")
	if open_marker == null or not open_marker.visible or str(open_marker.text) != "INVINCIBLE":
		push_error("meteor rain should show INVINCIBLE during the opening invuln")
		failed += 1
	game._spawn_shot({
		"position": game._player.position,
		"velocity": Vector2.ZERO,
		"sprite": "floating_eye_bolt.png",
		"radius": 8.0,
		"damage": 1,
		"killer_name": "bolt",
	}, false)
	game._collide()
	if not game._player.alive or game.phase != game.PHASE_PLAY:
		push_error("the player should be safe for the opening 0.5s of meteor rain")
		failed += 1
	game._clear_enemy_shots()
	# The show was stepped on its own clock, so spend the guard the way play does.
	game._director._next_time = 100000.0
	game._boss_director.dragon_at = 100000.0
	game._tutorial_active = false
	var step := 1.0 / 60.0
	for _i in 34:
		game._process(step)
	if game._dragon_show.phase == DragonShow.IDLE or game._meteor_guard > 0.0 or game._player.invulnerable or game.invuln > 0.0:
		push_error("after 0.5s the rain should still be going with no invuln, phase %s guard %s invuln %s" % [game._dragon_show.phase, game._meteor_guard, game.invuln])
		failed += 1
	var late_marker: Label = game._hud.get_node_or_null("InvincibleMarker")
	if late_marker != null and late_marker.visible:
		push_error("INVINCIBLE should hide once the meteor opening ends")
		failed += 1
	var saw_rain: bool = game._dragon_show.phase == DragonShow.RAIN
	var saw_slam: bool = game._dragon_show.phase == DragonShow.SLAM
	var guard_frames := 0
	while game._dragon_show.phase != DragonShow.IDLE and game._player.alive and guard_frames < 700:
		if game._dragon_show.phase == DragonShow.RAIN:
			saw_rain = true
		elif game._dragon_show.phase == DragonShow.SLAM:
			saw_slam = true
		if game._player.invulnerable or game._meteor_guard > 0.0:
			push_error("the rest of meteor rain should not grant invuln, phase %s" % game._dragon_show.phase)
			failed += 1
			break
		game._process(step)
		guard_frames += 1
	if not saw_rain or not saw_slam:
		push_error("the show should still reach the rain and the slam, rain %s slam %s phase %s" % [saw_rain, saw_slam, game._dragon_show.phase])
		failed += 1
	if game.phase != game.PHASE_PLAY or not game._player.alive:
		push_error("a clear field should not kill the player during the unguarded rain")
		failed += 1
	game._spawn_shot({
		"position": game._player.position,
		"velocity": Vector2.ZERO,
		"sprite": "floating_eye_bolt.png",
		"radius": 8.0,
		"damage": 1,
		"killer_name": "bolt",
	}, false)
	game._collide()
	if game._player.alive or game.phase != game.PHASE_DEAD:
		push_error("the player should be hittable for the rest of meteor rain")
		failed += 1
	if game._meteor_guard > 0.0:
		push_error("dying should clear the meteor guard")
		failed += 1
	var dead_marker: Label = game._hud.get_node_or_null("InvincibleMarker")
	if dead_marker != null and dead_marker.visible:
		push_error("dying should hide the INVINCIBLE marker")
		failed += 1
	_finish_show(game._dragon_show)
	if game._dragon_show.phase != DragonShow.IDLE or game._dragon_show.active_meteors() != 0 or game._dragon_show._giant.get("on", false) or game._dragon_show._impacts.size() != 0 or game._dragon_show.visible_meteor_fx() != 0 or game._dragon_show.lingering_meteor_fx() != 0:
		push_error("a rain started as the lair opens should clear every meteor after it ends")
		failed += 1
	game.invuln = 0.0
	game._player.invulnerable = false
	game._player.position = Vector2(80, 140)
	game._spawn_shot({
		"position": game._player.position,
		"velocity": Vector2.ZERO,
		"sprite": "floating_eye_bolt.png",
		"radius": 8.0,
		"damage": 1,
		"killer_name": "after",
	}, false)
	game._collide()
	if game._player.alive or game.phase != game.PHASE_DEAD:
		push_error("the player should be hittable again after meteor rain")
		failed += 1
	root.remove_child(game)
	game.free()
	return failed

func _check_dragon_death() -> int:
	var failed := 0
	CaptureMode.reset_for_test(PackedStringArray())
	var game = _boot_play_game()
	game.form_id = FormCatalog.Id.GOBLIN
	game._player.form_id = FormCatalog.Id.GOBLIN
	game._roster_form = FormCatalog.Id.GOBLIN
	game.rank_index = 2
	game._player.rank_index = 2
	game._player.small = false
	game.evo_points = 40
	game._player.power_level = 0
	game.score = 4321
	game.elapsed = 66.0
	game.combo = 3
	game.dragon_kills = 1
	game.day_seed = 20261101
	game._background.apply_world(WorldCatalog.DRAGON_LAIR, false)
	game._adopt_dragon_form()
	if game.form_id != FormCatalog.Id.DRAGON or game._player.form_id != FormCatalog.Id.DRAGON or game._roster_form != FormCatalog.Id.GOBLIN:
		push_error("adopting the dragon should keep the goblin as the run's roster form")
		failed += 1
	if game.rank_index != 2 or game.evo_points != 40:
		push_error("adopting the dragon should keep the rank and evolution points already earned")
		failed += 1
	if not game._dragon_phase_on or game._background.world_id != WorldCatalog.DRAGON_LAIR:
		push_error("the dragon phase and the lair should be up before the hit")
		failed += 1
	game._dragon_show.rng_seed = 4
	game._dragon_show.start_rain()
	game._meteor_kills = 7
	# The opening guard is a separate 0.5s. This hit is after that window.
	game._meteor_guard = 0.0
	game.invuln = 0.0
	game._player.invulnerable = false
	game._player.position = Vector2(140, 120)
	game._kill_player("Ember Bat")
	if game.phase != game.PHASE_DEAD or game._player.alive or game.form_id != FormCatalog.Id.DRAGON or game._player.form_id != FormCatalog.Id.DRAGON:
		push_error("dying as the dragon should end the run as the dragon, phase %s form %s alive %s" % [game.phase, game.form_id, game._player.alive])
		failed += 1
	if game.killer_name != "Ember Bat":
		push_error("the death card should keep the killer, got %s" % game.killer_name)
		failed += 1
	if game.invuln > 0.0 or game._player.invulnerable or game._meteor_guard > 0.0:
		push_error("a dragon death should not grant i-frames, invuln %s guard %s" % [game.invuln, game._meteor_guard])
		failed += 1
	if game._dragon_show.phase != DragonShow.IDLE:
		push_error("dying should cancel meteor rain, phase %s" % game._dragon_show.phase)
		failed += 1
	if game.score != 4321 or absf(game.elapsed - 66.0) > 0.001 or game.combo != 3:
		push_error("the ended run should keep its score, time, and combo")
		failed += 1
	if game._combat != null:
		for item in game._combat.items:
			if str(item.get("text", "")) == "REVERTED!":
				push_error("a dragon death should not show REVERTED!")
				failed += 1
				break
	var life_marker: Label = game._hud.get_node_or_null("InvincibleMarker")
	if life_marker != null and life_marker.visible:
		push_error("dying should hide the INVINCIBLE marker")
		failed += 1
	game._skip_death_to_card()
	if not game.game_over_visible or game.phase != game.PHASE_DEAD:
		push_error("a dragon death should open the death card, visible %s phase %s" % [game.game_over_visible, game.phase])
		failed += 1
	if game._share_label == null or game._share_label.text != "Reached DRAGON":
		push_error("the death card should name the dragon, got %s" % (game._share_label.text if game._share_label != null else "missing"))
		failed += 1
	if game._best_label == null or not str(game._best_label.text).begins_with("DRAGON BEST"):
		push_error("the death card should score the dragon form, got %s" % (game._best_label.text if game._best_label != null else "missing"))
		failed += 1
	if game._score_label == null or game._score_label.text != ScoreRules.format_score(4321):
		push_error("the death card should show the run score, got %s" % (game._score_label.text if game._score_label != null else "missing"))
		failed += 1
	var run: Dictionary = game.share_run()
	if str(run.get("form", "")) != "goblin" or int(run.get("rank_reached", 0)) != 3 or int(run.get("score", 0)) != 4321:
		push_error("run stats should keep the roster form and the score, got %s" % run)
		failed += 1
	var resolved := ShareCard.resolve(run)
	if str(resolved.get("form", "")) != "goblin":
		push_error("the share card should resolve the roster form, got %s" % resolved.get("form", ""))
		failed += 1
	# A lair killer is not on the share table. Resolving it must not crash.
	var lair_run: Dictionary = run.duplicate()
	lair_run["killer"] = ShareCard.killer_id("Ember Bat")
	var lair_card := ShareCard.resolve(lair_run)
	if str(lair_card.get("form", "")) != "goblin" or str(lair_card.get("killer", "")) == "":
		push_error("a dragon-lair killer should still resolve a share card, got %s" % lair_card)
		failed += 1
	if game._public_form() != FormCatalog.Id.GOBLIN:
		push_error("a dragon death should count as the roster form for the next roll")
		failed += 1
	var repeat_at := -1
	for step in 12:
		if FormCatalog.id_for_run(game.day_seed, step) == FormCatalog.Id.GOBLIN:
			repeat_at = step
			break
	if repeat_at < 0:
		push_error("expected a goblin roll to prove the no-repeat rule")
		failed += 1
	else:
		var avoided := FormCatalog.id_for_run_avoiding(game.day_seed, repeat_at, FormCatalog.Id.GOBLIN)
		if avoided == FormCatalog.Id.GOBLIN or avoided == FormCatalog.Id.DRAGON:
			push_error("avoiding the roster form should not roll goblin or dragon, got %s" % FormCatalog.display_name(avoided))
			failed += 1
		var daily_path := DailyRun.SAVE_PATH
		var daily_body := FileAccess.get_file_as_string(daily_path) if FileAccess.file_exists(daily_path) else ""
		_restore_user_file(daily_path, JSON.stringify({
			"date": str(DailyRun.date_seed()),
			"next_run": repeat_at,
			"epoch": BestScores.SCORE_EPOCH,
		}))
		game._card_age = Replay.CARD_GUARD
		game._reincarnate()
		_restore_user_file(daily_path, daily_body)
	if game.form_id == FormCatalog.Id.DRAGON or FormCatalog.IDS.find(game.form_id) < 0:
		push_error("reincarnation must not roll the dragon, got %s" % FormCatalog.display_name(game.form_id))
		failed += 1
	if game.form_id == FormCatalog.Id.GOBLIN:
		push_error("reincarnation after a dragon death should not repeat the roster form")
		failed += 1
	if game.phase != game.PHASE_REVEAL or not game._player.alive or not game._short_reveal:
		push_error("reincarnation should open the next run's reveal, phase %s" % game.phase)
		failed += 1
	root.remove_child(game)
	game.free()
	return failed

func _check_meteor_clock() -> int:
	var failed := 0
	if DragonShow.METEOR_COUNT != 15 or DragonShow.RAIN_FRAMES != 45 or DragonShow.SPAWN_EVERY != 3 or DragonShow.CHARGE_FRAMES != 15:
		push_error("meteor rain should be 1.0s of charge and 3.0s with exactly 15 meteors every 3 frames")
		failed += 1
	if absf(DragonShow.METEOR_HIT_RADIUS - 39.0) > 0.01 or absf(DragonShow.IMPACT_HIT_RADIUS - 87.0) > 0.01 or absf(DragonShow.GIANT_HIT_RADIUS - 84.0) > 0.01 or absf(DragonShow.GIANT_IMPACT_HIT_RADIUS - 135.0) > 0.01:
		push_error("meteor hit radii should be half the drawn cells (39, 87, 84, 135)")
		failed += 1
	if absf(DragonShow.DRAW_SCALE - 1.0) > 0.001 or absf(DragonShow.METEOR_CELL * DragonShow.DRAW_SCALE - 78.0) > 0.1 or absf(DragonShow.IMPACT_CELL * DragonShow.DRAW_SCALE - 174.0) > 0.1:
		push_error("barrage meteors should draw at 1x, 78 and 174")
		failed += 1
	if ArtLibrary.anchor("dragon_form/dragon_meteor.png") != Vector2(39, 39) or ArtLibrary.anchor("dragon_form/dragon_meteor_impact.png") != Vector2(87, 87):
		push_error("meteor anchors should be the centres (39, 39) and (87, 87)")
		failed += 1
	if absf(ArtLibrary.art_bbox("dragon_form/dragon_meteor.png").x - DragonShow.METEOR_CELL) > 0.1 or absf(ArtLibrary.art_bbox("dragon_form/dragon_meteor_impact.png").x - DragonShow.IMPACT_CELL) > 0.1:
		push_error("meteor sheets should be native 78 and 174 cells")
		failed += 1
	if absf(ArtLibrary.art_bbox("dragon_form/dragon_meteor_giant.png").x - DragonShow.GIANT_METEOR) > 0.1 or absf(ArtLibrary.art_bbox("dragon_form/dragon_meteor_giant_impact.png").x - DragonShow.GIANT_IMPACT) > 0.1:
		push_error("the giant meteor and impact should be native 168 and 270")
		failed += 1
	if DragonShow.GIANT_IMPACT_FRAMES != 13 or DragonShow.IMPACT_HOLD != 2:
		push_error("the giant impact should hold each of its 13 frames for 2 ticks")
		failed += 1
	if absf(DragonShow.GIANT_METEOR - 168.0) > 0.1 or absf(DragonShow.GIANT_IMPACT - 270.0) > 0.1:
		push_error("the final meteor should be 168px with a 270px impact")
		failed += 1
	if DragonShow.POOL < 11 or DragonShow.EMBER_CAP < 32 or DragonShow.DEBRIS_CAP < 24:
		push_error("meteor pools should cover the on-screen cap")
		failed += 1
	var show := DragonShow.new()
	show.rng_seed = 5
	show.start_rain()
	var peak := 0
	var steps := DragonShow.CHARGE_FRAMES + DragonShow.RAIN_FRAMES + DragonShow.FALL_FRAMES
	for _i in steps:
		show.tick(DragonShow.FRAME)
		peak = maxi(peak, show.active_meteors())
	if show._spawned != 15:
		push_error("the rain should spawn exactly 15 barrage meteors, got %d" % show._spawned)
		failed += 1
	if peak > DragonShow.POOL:
		push_error("too many meteors on screen at once (%d, cap %d)" % [peak, DragonShow.POOL])
		failed += 1
	if show.phase != DragonShow.FALL and show.phase != DragonShow.SLAM:
		push_error("the giant meteor should start when the rain ends, phase %s" % show.phase)
		failed += 1
	var guard := 0
	while show.phase != DragonShow.IDLE and guard < 400:
		show.tick(DragonShow.FRAME)
		guard += 1
	for _extra in 45:
		show.tick(DragonShow.FRAME)
	if show.phase != DragonShow.IDLE or show.active_meteors() != 0 or show._giant.get("on", false) or show._impacts.size() != 0 or show.visible_meteor_fx() != 0 or show.lingering_meteor_fx() != 0 or show.flash_frames != 0:
		push_error("a finished rain should leave no meteor, giant, or impact, phase %s flying %s giant %s impacts %s visible %s" % [show.phase, show.active_meteors(), show._giant.get("on", false), show._impacts.size(), show.visible_meteor_fx()])
		failed += 1
	show.free()
	failed += _check_meteor_sheets()
	return failed

func _png_size(path: String) -> Vector2i:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 24 or bytes[0] != 137:
		return Vector2i(-1, -1)
	var w := (int(bytes[16]) << 24) | (int(bytes[17]) << 16) | (int(bytes[18]) << 8) | int(bytes[19])
	var h := (int(bytes[20]) << 24) | (int(bytes[21]) << 16) | (int(bytes[22]) << 8) | int(bytes[23])
	return Vector2i(w, h)

## v2 sheets, the 13-frame giant slam, ground scorch, and no landing marker.
func _check_meteor_sheets() -> int:
	var failed := 0
	var sheets: Array[Dictionary] = [
		{"file": "dragon_form/dragon_meteor.png", "w": 312, "h": 78, "fw": 78, "fh": 78, "frames": 4, "fps": 15, "ax": 39, "ay": 39, "loop": true},
		{"file": "dragon_form/dragon_meteor_impact.png", "w": 1392, "h": 174, "fw": 174, "fh": 174, "frames": 8, "fps": 15, "ax": 87, "ay": 87, "loop": false},
		{"file": "dragon_form/dragon_meteor_giant.png", "w": 672, "h": 168, "fw": 168, "fh": 168, "frames": 4, "fps": 15, "ax": 84, "ay": 84, "loop": true},
		{"file": "dragon_form/dragon_meteor_giant_impact.png", "w": 3510, "h": 270, "fw": 270, "fh": 270, "frames": 13, "fps": 15, "ax": 135, "ay": 135, "loop": false},
		{"file": "dragon_form/dragon_meteor_warning.png", "w": 288, "h": 72, "fw": 72, "fh": 72, "frames": 4, "fps": 8, "ax": 36, "ay": 36, "loop": true},
		{"file": "dragon_form/dragon_meteor_scorch.png", "w": 104, "h": 32, "fw": 104, "fh": 32, "frames": 1, "fps": 0, "ax": 52, "ay": 16, "loop": false},
	]
	for spec in sheets:
		var file_name := str(spec["file"])
		var data := ArtLibrary.entry(file_name)
		var png := _png_size("res://art/" + file_name)
		var tex := ArtLibrary.texture(file_name)
		var box := ArtLibrary.art_bbox(file_name)
		var anchor := ArtLibrary.anchor(file_name)
		if data.is_empty() or png.x != int(spec["w"]) or png.y != int(spec["h"]):
			push_error("%s sheet size should be %sx%s, png %s" % [file_name, spec["w"], spec["h"], png])
			failed += 1
		if tex == null or tex.get_width() != int(spec["w"]) or tex.get_height() != int(spec["h"]):
			push_error("%s did not load at its sheet size" % file_name)
			failed += 1
		if int(data.get("frames", 0)) != int(spec["frames"]) or absf(float(data.get("fps", -1)) - float(spec["fps"])) > 0.01 or bool(data.get("loop", true)) != bool(spec["loop"]):
			push_error("%s frames/fps/loop drifted from the v2 sheet" % file_name)
			failed += 1
		if absf(box.x - float(spec["fw"])) > 0.1 or absf(box.y - float(spec["fh"])) > 0.1 or anchor != Vector2(float(spec["ax"]), float(spec["ay"])):
			push_error("%s cell or anchor drifted, box %s anchor %s" % [file_name, box, anchor])
			failed += 1
	var giant_impact := "dragon_form/dragon_meteor_giant_impact.png"
	if ArtLibrary.frame_index(giant_impact, 0.0) != 0 or ArtLibrary.frame_index(giant_impact, 12.0 / 15.0) != 12 or ArtLibrary.frame_index(giant_impact, 20.0 / 15.0) != 12:
		push_error("the giant impact should play 13 frames once and hold the last")
		failed += 1
	if ArtLibrary.frame_index("dragon_form/dragon_meteor.png", 4.0 / 15.0) != 0:
		push_error("the barrage meteor should loop after 4 frames")
		failed += 1
	var src := FileAccess.get_file_as_string("res://scripts/dragon_show.gd")
	if src.contains("dragon_meteor_warning") or src.contains("_draw_reticle") or src.contains("_show_reticle") or src.contains("WARN_LEAD") or src.contains("_paint_mark") or src.contains("draw_circle"):
		push_error("meteor rain must not draw a landing warning, reticle, or painted mark")
		failed += 1
	if src.count("draw_arc(") != 1:
		push_error("the slam shock ring should be the only code-drawn arc")
		failed += 1
	var show := DragonShow.new()
	if show.phase != DragonShow.IDLE or not show._sprite_commands().is_empty() or show.visible_meteor_fx() != 0:
		push_error("nothing should be drawn while meteor rain is idle")
		failed += 1
	show.rng_seed = 5
	show.start_rain()
	var saw_scorch := false
	var scorch_bad := 0
	var warning_hits := 0
	var preview_shock := false
	var giant_frames := {}
	var saw_barrage := false
	var saw_impact := false
	var saw_giant := false
	var guard := 0
	while show.phase != DragonShow.IDLE and guard < 400:
		for cmd in show._sprite_commands():
			var file_name := str(cmd["file"])
			if file_name.contains("warning"):
				warning_hits += 1
			if file_name == DragonShow.METEOR:
				saw_barrage = true
			elif file_name == DragonShow.IMPACT:
				saw_impact = true
			elif file_name == DragonShow.GIANT_METEOR_ART:
				saw_giant = true
			elif file_name == DragonShow.GIANT_IMPACT_ART:
				giant_frames[ArtLibrary.frame_index(file_name, float(cmd["time"]))] = true
			elif file_name == DragonShow.SCORCH:
				saw_scorch = true
				var at: Vector2 = cmd["at"]
				var tint: Color = cmd["tint"]
				if absf(at.y - 230.0) > 0.01 or tint.a < 0.149 or tint.a > 0.701:
					scorch_bad += 1
		for item in show._decals:
			if item.has("boom"):
				continue
			if absf(float(item["pos"].y) - 226.0) > 0.01:
				scorch_bad += 1
		if show.phase == DragonShow.CHARGE or show.phase == DragonShow.RAIN or show.phase == DragonShow.FALL:
			if show.shock > 0.02:
				preview_shock = true
		show.tick(DragonShow.FRAME)
		guard += 1
	if not saw_scorch or scorch_bad > 0:
		push_error("ground landings should draw the scorch at impact + (0, 4) with the existing fade")
		failed += 1
	if warning_hits > 0 or preview_shock:
		push_error("no warning or reticle should be drawn for the giant or the barrage")
		failed += 1
	if not saw_barrage or not saw_impact or not saw_giant:
		push_error("barrage meteors, impacts, and the falling giant should still draw")
		failed += 1
	if giant_frames.size() != 13:
		push_error("the giant impact should play all 13 frames, saw %d" % giant_frames.size())
		failed += 1
	for index in 13:
		if not giant_frames.has(index):
			push_error("the giant impact skipped frame %d" % index)
			failed += 1
			break
	if show.phase != DragonShow.IDLE or not show._sprite_commands().is_empty() or show._decals.size() != 0 or show.visible_meteor_fx() != 0 or show.lingering_meteor_fx() != 0:
		push_error("scorch and every other meteor sprite should clear when the show ends")
		failed += 1
	show.free()
	return failed

func _boss_pull(seed_value: int, step: float, until: float) -> Array[Dictionary]:
	var director := BossDirector.new(seed_value)
	var events: Array[Dictionary] = []
	var alive_until := -1.0
	var t := 0.0
	while t < until - 0.0001:
		t += step
		director.set_boss_alive(alive_until > t)
		var due := director.pop_due(t)
		if due.is_empty():
			continue
		var event: Dictionary = due[0]
		events.append(event)
		if str(event["slug"]) == "great_dragon":
			alive_until = 100000.0
		else:
			alive_until = float(event["t"]) + BossDirector.LIFE
		director.set_boss_alive(true)
	return events

func _check_boss_play() -> int:
	var failed := 0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game.phase = game.PHASE_PLAY
	game.form_id = FormCatalog.Id.SLIME
	game._player.form_id = FormCatalog.Id.SLIME
	game.invuln = 30.0
	game._player.invulnerable = true
	var field := Vector2(480, 270)
	var before: int = game.score
	for slug in BossCatalog.SLUGS:
		var data := {
			"slug": slug,
			"generation": 0,
			"hold_x": 400.0,
			"origin_y": 120.0,
			"phase": 0.4,
			"wave_amp": 12.0,
		}
		if not game._spawn_boss(data, field):
			push_error("%s did not spawn" % slug)
			failed += 1
			continue
		var boss: BossActor = null
		for enemy in game._enemies:
			if enemy.is_boss() and enemy.alive and enemy.boss_slug == slug:
				boss = enemy
		if boss == null:
			push_error("%s was not on the field" % slug)
			failed += 1
			continue
		if boss.intro_left > 0.0:
			var guarded := boss.hp
			boss.hurt(30)
			if boss.hp != guarded:
				push_error("the lich entrance should ignore damage")
				failed += 1
			boss.intro_left = 0.0
			boss.state = BossActor.HOLD
		var hp := boss.hp
		var point := Vector2(-14, -20)
		if slug == "death_knight":
			point = Vector2(4, 10)
		elif slug == "great_dragon":
			point = Vector2(8, 10)
		game._spawn_shot({
			"position": boss.position + point,
			"velocity": Vector2(-20, 0),
			"sprite": "slime_shot.png",
			"damage": 1,
		}, true)
		game._collide()
		if boss.hp != hp - 1:
			push_error("a shot on %s should hit the body, hp %s" % [slug, boss.hp])
			failed += 1
		while boss.alive:
			boss.hurt(8)
		game._award_kill(boss, true)
	if game.score < before + BossCatalog.DRAGON_SCORE:
		push_error("killing the dragon should pay at least 100,000, score %s" % game.score)
		failed += 1
	var saw_overdrive := false
	for drop in game._powers:
		if is_instance_valid(drop) and drop.kind == "overdrive":
			saw_overdrive = true
	if not saw_overdrive:
		push_error("a dragon kill should guarantee an OVERDRIVE")
		failed += 1
	if game._loot.size() < BossCatalog.DRAGON_GEM_BURST:
		push_error("a dragon kill should burst gems, got %d" % game._loot.size())
		failed += 1
	if game._boss_director.dragon_gen != 1:
		push_error("the dragon kill should arm the 60 s return")
		failed += 1
	game.invuln = 0.0
	game._player.invulnerable = false
	game.form_id = FormCatalog.Id.DRAGON
	game._player.adopt_dragon(1.0)
	game.form_id = FormCatalog.Id.DRAGON
	game._meteor_kills = 25
	game._refresh_hud()
	if game._hud_view == null or game._hud_view.meteor_px != 9:
		push_error("25 of 50 kills should fill half the meteor meter, got %s" % (game._hud_view.meteor_px if game._hud_view != null else -1))
		failed += 1
	game._meteor_kills = 49
	game._refresh_hud()
	if game._hud_view.meteor_ready:
		push_error("49 kills should not mark meteor rain ready")
		failed += 1
	game._charge_meteor()
	if game._dragon_show.phase != DragonShow.CHARGE or game._meteor_kills != 0:
		push_error("the 50th kill should start meteor rain, phase %s kills %s" % [game._dragon_show.phase, game._meteor_kills])
		failed += 1
	if not game._player.invulnerable or absf(game._meteor_guard - game.METEOR_INVULN_SECONDS) > 0.02:
		push_error("meteor rain should make the player invulnerable for 0.5s from the charge")
		failed += 1
	var marker: Label = game._hud.get_node_or_null("InvincibleMarker")
	if marker == null or not marker.visible or str(marker.text) != "INVINCIBLE":
		push_error("meteor rain should show the INVINCIBLE marker at the start of the charge")
		failed += 1
	game._director._next_time = 100000.0
	game._boss_director.dragon_at = 100000.0
	game._tutorial_active = false
	game._clear_field()
	for _i in 34:
		game._process(1.0 / 60.0)
	if game._dragon_show.phase != DragonShow.CHARGE or game._player.invulnerable or game._meteor_guard > 0.0:
		push_error("the rest of the charge should be vulnerable, phase %s guard %s" % [game._dragon_show.phase, game._meteor_guard])
		failed += 1
	marker = game._hud.get_node_or_null("InvincibleMarker")
	if marker != null and marker.visible:
		push_error("the INVINCIBLE marker should leave before the charge ends")
		failed += 1
	var daily_path := "user://daily_run.json"
	var daily_body := FileAccess.get_file_as_string(daily_path) if FileAccess.file_exists(daily_path) else ""
	game._dragon_show.cancel()
	game.phase = game.PHASE_PLAY
	game._player.alive = true
	game._meteor_guard = 0.4
	game.invuln = 0.4
	game._reincarnate()
	_restore_user_file(daily_path, daily_body)
	if game._meteor_guard > 0.0 or game.invuln > 0.0:
		push_error("a new run should clear the meteor guard, guard %s invuln %s" % [game._meteor_guard, game.invuln])
		failed += 1
	marker = game._hud.get_node_or_null("InvincibleMarker")
	if marker != null and marker.visible:
		push_error("a new run should hide the INVINCIBLE marker")
		failed += 1
	if game._dragon_show.z_index >= game._player.z_index or game._dragon_show.z_index >= Replay.bullet_z():
		push_error("meteor FX should draw under the ship and under enemy bullets")
		failed += 1
	game._clear_field()
	game.form_id = FormCatalog.Id.VENDING
	game._player.form_id = FormCatalog.Id.VENDING
	if not game._spawn_boss({"slug": "great_dragon", "generation": 1, "hold_x": 410.0, "origin_y": 130.0, "phase": 0.2, "wave_amp": 10.0}, field):
		push_error("the return dragon did not spawn")
		failed += 1
	else:
		var boss: EnemyActor = game._living_boss()
		boss.intro_left = 0.0
		var hp := int(boss.hp)
		if hp != 20000:
			push_error("the returned dragon should have 20000 hp, got %s" % hp)
			failed += 1
		game._spawn_enemy({
			"t": 0.0, "kind": SpawnDirector.EYE, "x_ratio": 0.4, "phase": 0.2,
			"stop_ratio": 0.3, "y_bias": 0.0, "wave_amp": 4.0, "hold_fire": true,
		}, field)
		var chip := BossCatalog.winner_damage(boss.max_hp)
		game._winner_clear()
		if not boss.alive or boss.hp != hp - chip:
			push_error("WINNER should chip a full boss by %d, hp %s alive %s" % [chip, boss.hp, boss.alive])
			failed += 1
		var rain := int(game._dragon_open_budget())
		var rain_chip := BossCatalog.meteor_rain_damage(boss.max_hp)
		if rain != rain_chip or rain != 3000 or rain <= chip or boss.hp != hp - chip:
			push_error("Meteor Rain budget should stay 15 percent (%d) without hitting, got %d hp %s" % [rain_chip, rain, boss.hp])
			failed += 1
		var eye_alive := false
		for enemy in game._enemies:
			if not enemy.is_boss() and enemy.kind == SpawnDirector.EYE and enemy.alive:
				eye_alive = true
		if eye_alive:
			push_error("WINNER should still clear a normal enemy")
			failed += 1
	game._clear_field()
	if game._spawn_boss({"slug": "death_knight", "generation": 0, "hold_x": 426.0, "origin_y": 130.0, "phase": 0.2, "wave_amp": 8.0}, field):
		var knight: BossActor = game._living_boss()
		knight.intro_left = 0.0
		knight.state = BossActor.HOLD
		knight.position = Vector2(426, 130)
		knight.shield_left = BossCatalog.SHIELD_TIME
		var probe := Shot.new()
		probe.position = knight.position + Vector2(-22, -8)
		if not knight.blocks_player_shot(probe):
			push_error("the knight shield should stop a shot in front")
			failed += 1
		probe.position = knight.position + Vector2(36, 0)
		if knight.blocks_player_shot(probe):
			push_error("the knight shield should not block a shot behind him")
			failed += 1
		probe.free()
		var shielded := knight.hp
		game._spawn_shot({
			"position": knight.position + Vector2(-22, -8),
			"velocity": Vector2(40, 0),
			"sprite": "slime_shot.png",
			"damage": 1,
		}, true)
		game._collide()
		if knight.hp != shielded:
			push_error("a blocked shot should leave the knight's hp alone, hp %s" % knight.hp)
			failed += 1
		game._winner_clear()
		var knight_chip := BossCatalog.winner_damage(knight.max_hp)
		if not knight.alive or knight.hp != shielded - knight_chip:
			push_error("WINNER should bypass the shield and chip %d, hp %s" % [knight_chip, knight.hp])
			failed += 1
	for slug in BossCatalog.SLUGS:
		var enter_cue := "great_dragon_entrance" if slug == "great_dragon" else BossCatalog.cue(slug, "enter")
		if game._sound.play_count(enter_cue) < 1 or game._sound.play_count(BossCatalog.cue(slug, "death")) < 1:
			push_error("missing boss cue playback for %s" % slug)
			failed += 1
	root.remove_child(game)
	game.free()
	return failed

## The real scene, past 45 s. A boss that is spawned and then swept on the
## same frame never reaches this check.
func _check_boss_arrives() -> int:
	var failed := 0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var step := 1.0 / 60.0
	for _i in 200:
		game._process(step)
		if int(game.phase) == game.PHASE_PLAY:
			break
	if int(game.phase) != game.PHASE_PLAY:
		push_error("the run should leave the title card before the boss clock")
		root.remove_child(game)
		game.free()
		return 1
	var held := 0
	var saw_name := ""
	while game.elapsed < 55.0 and held < 8:
		game.invuln = 30.0
		game._process(step)
		if int(game.phase) != game.PHASE_PLAY:
			push_error("the run died before a boss, killer %s at %.1f" % [game.killer_name, game.elapsed])
			failed += 1
			break
		var boss: EnemyActor = game._living_boss()
		if boss == null or not boss.visible:
			held = 0
			continue
		var on_screen := boss.position.x > 16.0 and boss.position.x < 470.0 and boss.position.y > 8.0 and boss.position.y < 262.0
		if on_screen:
			held += 1
			saw_name = boss.kind_name
		else:
			held = 0
	if held < 8:
		push_error("no boss stayed on screen after 45 s (elapsed %.1f)" % game.elapsed)
		failed += 1
	elif saw_name != "Lich King":
		push_error("the first boss on the real clock should be the Lich King, got %s" % saw_name)
		failed += 1
	root.remove_child(game)
	game.free()
	return failed

func _sample(id: int, drag: Vector2, bounds: Rect2, frames: int) -> Vector2:
	var ship := PlayerShip.new()
	ship.setup(id, Vector2(120, 500))
	ship.add_drag(drag, bounds)
	for _i in frames:
		ship.tick(1.0 / 60.0, bounds)
	var where := ship.position
	ship.free()
	return where
