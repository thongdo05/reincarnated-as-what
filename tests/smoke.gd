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
	if goblin.size() != 3:
		push_error("goblin should fire a 3-stone burst")
		failed += 1
	else:
		var spreads: Array[float] = []
		for shot in goblin:
			spreads.append(float(shot["velocity"].x))
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
		if float(event["t"]) < 8.0 and int(event["kind"]) == SpawnDirector.FANG and float(event["t"]) < 1.2:
			early_fang = true
	if early_fang:
		push_error("a fang spawned immediately")
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
	var line := ScoreRules.share_line("SLIME", 102.0, "Dart", 4210)
	if line != "Reborn as SLIME. Lasted 1:42. Died to a Dart. Score 4,210.":
		push_error("share line was '%s'" % line)
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
