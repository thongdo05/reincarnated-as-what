extends SceneTree

## Headless checks for the daily order, the shared spawn timeline, score rules,
## and relative-drag movement. Run with: godot --headless -s res://tests/smoke.gd

var _unit_failed := 0
var _done := false

func _initialize() -> void:
	_unit_failed += _check_forms()
	_unit_failed += _check_spawns()
	_unit_failed += _check_score()
	_unit_failed += _check_drag()
	_unit_failed += _check_traits()
	_unit_failed += _check_art()
	_unit_failed += _check_idle()
	if _unit_failed > 0:
		push_error("%d smoke checks failed" % _unit_failed)
		quit(1)

func _process(_delta: float) -> bool:
	if _done or _unit_failed > 0:
		return false
	_done = true
	var failed := _unit_failed + _check_play()
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
	if FormCatalog.id_for_run(20261101, 1) == first:
		push_error("the two forms did not both appear in the daily order")
		failed += 1
	if FormCatalog.id_for_run(20261101, 2) != first:
		push_error("form order did not cycle")
		failed += 1
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
	var slime_dps := 1.0 / FormCatalog.SLIME_FIRE_INTERVAL
	var goblin_close := 3.0 / FormCatalog.GOBLIN_FIRE_INTERVAL
	var goblin_far := 1.0 / FormCatalog.GOBLIN_FIRE_INTERVAL
	if absf(slime_dps - goblin_close) / slime_dps > 0.2:
		push_error("close-range fire rate is out of balance: slime %.2f goblin %.2f" % [slime_dps, goblin_close])
		failed += 1
	if goblin_far >= slime_dps:
		push_error("goblin's single center stone should not out-damage slime's stream")
		failed += 1
	if FormCatalog.hit_radius(FormCatalog.Id.SLIME) <= FormCatalog.hit_radius(FormCatalog.Id.GOBLIN):
		push_error("slime's cube should be a bigger target than the goblin")
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
	return 0

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
	if ArtLibrary.file_count() != 75:
		push_error("art manifest should have 75 entries, found %d" % ArtLibrary.file_count())
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
	for parked in ["vending_machine_r1.png", "vending_machine_r3.png", "cat_r2.png", "demon_lord_r1.png", "demon_lord_r3.png"]:
		if not ArtLibrary.has_file(parked):
			push_error("parked form art missing: %s" % parked)
			failed += 1
	if FormCatalog.IDS.size() != 2:
		push_error("vending, cat, and demon lord should stay out of the roster")
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
			var spec := FormCatalog.rank_spec(id, rank)
			var pct := float(spec["hit_pct"])
			if pct < 0.50 or pct > 0.65:
				push_error("hit pct out of band for %s rank %d" % [FormCatalog.display_name(id), rank])
				failed += 1
			var radius := FormCatalog.hit_radius_for(id, rank, false)
			var box := ArtLibrary.art_bbox(str(spec["sprite"]))
			var expect := pct * (box.x + box.y) * 0.25
			if absf(radius - expect) > 0.05:
				push_error("hit radius drifted from the art box")
				failed += 1
			if rank > 0 and radius <= prev:
				push_error("hitbox should grow with rank")
				failed += 1
			if rank > 0 and radius > prev * 1.35:
				push_error("hitbox grew more than a modest step")
				failed += 1
			prev = radius
			if id == FormCatalog.Id.SLIME:
				var small := FormCatalog.hit_radius_for(id, rank, true)
				if small >= radius:
					push_error("split slime hitbox should be smaller than the current rank")
					failed += 1
	if FormCatalog.hit_radius(FormCatalog.Id.SLIME) <= FormCatalog.hit_radius(FormCatalog.Id.GOBLIN):
		push_error("slime's hitbox should stay larger than the goblin's")
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
			if frames != 4 or absf(fps - 6.0) > 0.01 or not bool(entry["loop"]):
				push_error("idle sheet %s should be a 4-frame loop at 6 fps" % file_name)
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
		var wants_idle := category == "player_form" or category == "player_form_split" or category == "enemy"
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
		var expect := SpawnDirector.BODY_PCT * (box.x + box.y) * 0.25
		if absf(body - expect) > 0.05:
			push_error("enemy hitbox should stay on the static art box")
			failed += 1
	return failed

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
	if FormCatalog.rank_for_points(0) != 0 or FormCatalog.rank_for_points(FormCatalog.RANK_GATES[0] - 1) != 0:
		push_error("evolution should stay at rank 0 under the first gate")
		failed += 1
	if FormCatalog.rank_for_points(FormCatalog.RANK_GATES[0]) != 1:
		push_error("the first gate should reach rank 1")
		failed += 1
	if FormCatalog.rank_for_points(FormCatalog.RANK_GATES[1]) != 2:
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
	return failed

func _check_drag() -> int:
	var bounds := Rect2(0, 0, 360, 780)
	var drag := Vector2(150, -80)
	var slime_early := _sample(FormCatalog.Id.SLIME, drag, bounds, 8)
	var goblin_early := _sample(FormCatalog.Id.GOBLIN, drag, bounds, 8)
	var slime_end := _sample(FormCatalog.Id.SLIME, drag, bounds, 180)
	var goblin_end := _sample(FormCatalog.Id.GOBLIN, drag, bounds, 180)
	var failed := 0
	var start := Vector2(120, 500)
	var aim := start + drag
	if slime_end.distance_to(aim) > 18.0 or goblin_end.distance_to(aim) > 18.0:
		push_error("ship did not settle on the drag aim (slime %s goblin %s aim %s)" % [slime_end, goblin_end, aim])
		failed += 1
	var slime_travel := slime_early.distance_to(start)
	var goblin_travel := goblin_early.distance_to(start)
	if goblin_travel <= slime_travel:
		push_error("goblin should cover the first stride faster than slime slides (%.1f vs %.1f)" % [goblin_travel, slime_travel])
		failed += 1
	if slime_early.distance_to(aim) < 40.0:
		push_error("slime reached the aim too quickly to feel slippery")
		failed += 1
	# A drag of +150 must not be treated as a finger coordinate of (150, -80).
	if slime_end.x < start.x + 100.0:
		push_error("relative drag did not carry the ship by the drag delta")
		failed += 1
	return failed

func _check_play() -> int:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	if game._player == null:
		push_error("game did not finish setting up")
		game.free()
		return 1
	if not game.wants_rotate(Vector2(390, 844)) or game.wants_rotate(Vector2(844, 390)):
		push_error("portrait should ask for a rotate, landscape should play")
		game.free()
		return 1
	var step := 1.0 / 60.0
	for _i in 160:
		game._process(step)
	var failed := 0
	if int(game.phase) != 1:
		push_error("reveal did not hand off to play (phase %s)" % str(game.phase))
		failed += 1
	var before: Vector2 = game._player.position
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = before + Vector2(40, 80)
	game._unhandled_input(touch)
	for i in 50:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.relative = Vector2(2.4, -1.2)
		drag.position = before + Vector2(40 + float(i) * 2.4, 80 - float(i) * 1.2)
		game._unhandled_input(drag)
		game._process(step)
	var after: Vector2 = game._player.position
	if after.x < before.x + 40.0 or after.y > before.y - 15.0:
		push_error("screen drag did not move the ship (before %s after %s)" % [before, after])
		failed += 1
	for _i in 700:
		if int(game.phase) == 2:
			break
		game._process(step)
	if float(game.score) <= 0.0 or float(game.elapsed) < 5.0:
		push_error("play slice produced no score (score %s elapsed %s)" % [str(game.score), str(game.elapsed)])
		failed += 1
	print("PLAY_SLICE phase=%s score=%s elapsed=%.2f form=%s" % [
		str(game.phase), str(game.score), float(game.elapsed), FormCatalog.display_name(int(game.form_id))
	])
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
