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
	_unit_failed += _check_parallax()
	_unit_failed += _check_titles()
	_unit_failed += _check_facing()
	_unit_failed += _check_polish()
	_unit_failed += _check_shapes()
	_unit_failed += _check_loot()
	_unit_failed += _check_hud()
	_unit_failed += _check_death_sequence()
	_unit_failed += _check_share_card()
	_unit_failed += _check_icons()
	_unit_failed += _check_audio()
	if _unit_failed > 0:
		push_error("%d smoke checks failed" % _unit_failed)
		quit(1)

func _process(_delta: float) -> bool:
	if _done or _unit_failed > 0:
		return false
	_done = true
	var failed := _unit_failed + _check_play() + _check_death_card() + _check_pause() + _check_death_play() + _check_evolve_play() + _check_audio_play()
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
	if FormCatalog.core_radius(FormCatalog.Id.SLIME, 0, false) <= FormCatalog.core_radius(FormCatalog.Id.GOBLIN, 0, false):
		push_error("slime's core should be a bigger target than the goblin's")
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
	if ArtLibrary.file_count() != 128:
		push_error("art manifest should have 128 entries, found %d" % ArtLibrary.file_count())
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
		push_error("the slime core should be the hurtbox")
		failed += 1
	if HitLibrary.contains_local("slime_r1.png", "hurt", Vector2(10, 10)):
		push_error("the slime hurtbox should stay inside the sprite")
		failed += 1
	if HitLibrary.contains_local("goblin_r1.png", "hurt", Vector2(0, -14)):
		push_error("the goblin crown should not be part of the hurtbox")
		failed += 1
	var wolf := Vector2(120, 80)
	if not HitLibrary.overlaps(wolf + Vector2(-20, 0), "slime_shot.png", "body", wolf, "dire_wolf.png", "body"):
		push_error("a slime shot on the wolf's nose should connect")
		failed += 1
	if HitLibrary.overlaps(wolf + Vector2(0, -40), "slime_shot.png", "body", wolf, "dire_wolf.png", "body"):
		push_error("a slime shot over the wolf should miss")
		failed += 1
	var eye := Vector2(40, 40)
	var brush := HitLibrary.gap(eye + Vector2(14, 0), "slime_r1.png", "hurt", eye, "floating_eye.png", "threat")
	if brush <= 0.0:
		push_error("overlapping the eye's rim with the sprite should not kill when the core is clear (gap %s)" % brush)
		failed += 1
	var fatal := HitLibrary.gap(eye + Vector2(10, 0), "slime_r1.png", "hurt", eye, "floating_eye.png", "threat")
	if fatal > 0.0:
		push_error("a core inside the eye should be fatal (gap %s)" % fatal)
		failed += 1
	var prev_slime := 0.0
	var prev_goblin := 0.0
	for rank in 3:
		var slime_r := HitLibrary.max_part_radius(str(FormCatalog.rank_spec(FormCatalog.Id.SLIME, rank)["sprite"]), "hurt")
		var goblin_r := HitLibrary.max_part_radius(str(FormCatalog.rank_spec(FormCatalog.Id.GOBLIN, rank)["sprite"]), "hurt")
		if slime_r <= goblin_r:
			push_error("the slime core should stay a bigger target than the goblin")
			failed += 1
		if rank > 0 and (slime_r <= prev_slime or goblin_r <= prev_goblin):
			push_error("cores should grow with rank")
			failed += 1
		if rank > 0 and (slime_r > prev_slime * 1.35 or goblin_r > prev_goblin * 1.35):
			push_error("cores grew more than a modest step")
			failed += 1
		var small_r := HitLibrary.max_part_radius(str(FormCatalog.rank_spec(FormCatalog.Id.SLIME, rank)["sprite_small"]), "hurt")
		if small_r >= slime_r:
			push_error("the split slime core should be smaller")
			failed += 1
		prev_slime = slime_r
		prev_goblin = goblin_r
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
		game._seed_label.text = "UTC seed 20261101 · run 99"
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
		for label in [game._share_label, game._best_label, game._seed_label, game._death_kicker]:
			var label_rect := Rect2(label.position, label.size)
			if label_rect.end.y > rect.position.y + 0.5:
				push_error("death copy overlaps Reincarnate for '%s'" % lines[i])
				failed += 1
				break
			if label_rect.position.y < -0.5 or label_rect.end.y > field.y + 0.5:
				push_error("death copy left the field for '%s'" % lines[i])
				failed += 1
				break
	root.remove_child(game)
	game.free()
	return failed

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
	game._unhandled_input(drag)
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
	root.remove_child(game)
	game.free()
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

func _check_hud() -> int:
	var failed := 0
	if HudLayout.fill_px(0, 0) != 0 or HudLayout.fill_px(250, 0) != 32:
		push_error("rank 1 meter should be empty at 0 and half full at 250, got %d %d" % [HudLayout.fill_px(0, 0), HudLayout.fill_px(250, 0)])
		failed += 1
	if HudLayout.fill_px(500, 1) != 0 or HudLayout.fill_px(1000, 1) != 32:
		push_error("rank 2 meter should reset at the gate and reach half at 1000, got %d %d" % [HudLayout.fill_px(500, 1), HudLayout.fill_px(1000, 1)])
		failed += 1
	if HudLayout.fill_px(1500, 2) != 64 or HudLayout.fill_px(9000, 2) != 64:
		push_error("rank 3 meter should stay full")
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
	if FxTimeline.pop_file(Vector2(24, 24)) != "fx/fx_death_pop_s.png" or FxTimeline.pop_file(Vector2(32, 32)) != "fx/fx_death_pop_s.png":
		push_error("forms up to 32 px should pop small")
		failed += 1
	if FxTimeline.pop_file(Vector2(32, 36)) != "fx/fx_death_pop_l.png" or FxTimeline.pop_file(Vector2(40, 48)) != "fx/fx_death_pop_l.png":
		push_error("big forms should pop large")
		failed += 1
	for crowned in ["goblin_r1.png", "goblin_r2.png", "goblin_r3.png", "cat_r3.png", "demon_lord_r3.png", "slime_r3.png", "slime_small_r3.png"]:
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
	if ShareCard.form_key(FormCatalog.Id.SLIME) != "slime" or ShareCard.form_key(FormCatalog.Id.GOBLIN) != "goblin":
		push_error("playable forms should map onto the share-card config")
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
	game.evo_points = int(FormCatalog.RANK_GATES[0]) - 1
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
	if AudioCues.shot_event_for_form(FormCatalog.Id.GOBLIN) != "":
		push_error("goblin shots should stay silent")
		failed += 1
	for id in FormCatalog.IDS:
		if AudioCues.reveal_event_for_card(FormCatalog.title_card(id)) != "":
			push_error("a live form should not play a reveal sting")
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
		push_error("web music should be a sample so iOS Safari plays the loop")
		failed += 1
	if absf(float(AudioCues.spec("slime_shot")["volume_db"]) - AudioCues.SHOT_VOLUME_DB) > 0.01 or absf(AudioCues.SHOT_VOLUME_DB + 10.0) > 0.01:
		push_error("slime shot should be -10 dB on its player")
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
	game._unhandled_input(drag)
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
	for _i in 20:
		game._player._cooldown = 0.0
		game._process(step)
	if game._sound.play_count("slime_shot") != 0:
		push_error("goblin fire should not play the slime shot")
		failed += 1
	game.form_id = FormCatalog.Id.SLIME
	game._player.form_id = FormCatalog.Id.SLIME
	game._player._cooldown = 0.0
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
	game.evo_points = int(FormCatalog.RANK_GATES[0]) - 1
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
	game._sound.debug_play_vending_reveal()
	game._sound.play_title_card(AudioCues.VENDING_TITLE)
	if game._sound.play_count("reveal_vending_machine") != 2:
		push_error("the vending sting should play from the debug path and the title card")
		failed += 1
	var vending: AudioStreamPlayer = game._sound.player_for("reveal_vending_machine")
	if vending == null or vending.stream == null or str(vending.bus) != AudioCues.SFX_BUS:
		push_error("the vending sting should be armed on the SFX bus")
		failed += 1
	root.remove_child(game)
	game.free()
	AudioCues.write_enabled(true)
	AudioCues.apply_bus_levels()
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
