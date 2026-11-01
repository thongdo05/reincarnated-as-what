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
	if _unit_failed > 0:
		push_error("%d smoke checks failed" % _unit_failed)
		quit(1)

func _process(_delta: float) -> bool:
	if _done or _unit_failed > 0:
		return false
	_done = true
	var failed := _unit_failed + _check_play() + _check_death_card() + _check_pause()
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
	if game._player == null or game._title_card == null:
		push_error("game did not finish setting up")
		game.free()
		return 1
	if not game.wants_rotate(Vector2(390, 844)) or game.wants_rotate(Vector2(844, 390)):
		push_error("portrait should ask for a rotate, landscape should play")
		game.free()
		return 1
	var step := 1.0 / 60.0
	var failed := 0
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

func _sample(id: int, drag: Vector2, bounds: Rect2, frames: int) -> Vector2:
	var ship := PlayerShip.new()
	ship.setup(id, Vector2(120, 500))
	ship.add_drag(drag, bounds)
	for _i in frames:
		ship.tick(1.0 / 60.0, bounds)
	var where := ship.position
	ship.free()
	return where
