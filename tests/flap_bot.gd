extends SceneTree

## Headless flap bot for the mode=flappy experiment. Not part of CI.
## godot --headless --path . -s res://tests/flap_bot.gd
## Optional: -- --n=8 for a shorter pass. The published table is n=24.
##
## Rows are bot data, not a human playtest. Survival is the in-game clock
## (play starts when the title card ends; this bot skips the card).

const STEP := 1.0 / 60.0
const CAP := 36.0

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var n := _run_count()
	FlappyMode.reset_for_test(PackedStringArray(["--mode=flappy"]))
	var lines: Array[String] = []
	for form in [FormCatalog.Id.SLIME, FormCatalog.Id.GOBLIN]:
		var deaths: Array[float] = []
		var scores: Array[float] = []
		var evos: Array[float] = []
		var rank2 := 0
		var rank3 := 0
		var killers := {}
		var name := FormCatalog.display_name(form)
		for i in n:
			var seed_value := 20261101 + i
			print("RUN %s seed %d" % [name, seed_value])
			var result := _run(seed_value, form)
			deaths.append(float(result["death"]))
			scores.append(float(result["score"]))
			evos.append(float(result["evo"]))
			if bool(result["rank2"]):
				rank2 += 1
			if bool(result["rank3"]):
				rank3 += 1
			var killer := str(result["killer"])
			killers[killer] = int(killers.get(killer, 0)) + 1
			lines.append("BOT_RUN %s seed %d death %.2f score %d evo %d rank %d killer %s" % [
				name, seed_value, float(result["death"]), int(result["score"]), int(result["evo"]), int(result["rank"]), killer,
			])
		var med_s := _median(deaths)
		var med_score := _median(scores)
		lines.append("BOT_DATA %s n=%d median_s=%.2f median_score=%.1f rank2_pct=%.1f rank3_pct=%.1f median_evo=%.1f killers %s" % [
			name,
			n,
			med_s,
			med_score,
			_pct(rank2, n),
			_pct(rank3, n),
			_median(evos),
			str(killers),
		])
		var band := med_s >= 10.0 and med_s <= 25.0
		lines.append("BOT_BAND %s %s" % [name, "inside 10-25s" if band else "OUTSIDE 10-25s"])
	var table: Array[String] = []
	table.append("BOT DATA (headless flap bot, not a human playtest)")
	table.append("| Form | n | median survival s | median score | rank 2 % | rank 3 % |")
	table.append("| --- | --- | --- | --- | --- | --- |")
	for line in lines:
		if not line.begins_with("BOT_DATA "):
			continue
		var bits := line.split(" ")
		# BOT_DATA NAME n=24 median_s=.. median_score=.. rank2_pct=.. rank3_pct=..
		var form_name := bits[1] if bits.size() > 1 else "?"
		var cells := {"n": "", "s": "", "score": "", "r2": "", "r3": ""}
		for bit in bits:
			if bit.begins_with("n="):
				cells["n"] = bit.substr(2)
			elif bit.begins_with("median_s="):
				cells["s"] = bit.substr(9)
			elif bit.begins_with("median_score="):
				cells["score"] = bit.substr(13)
			elif bit.begins_with("rank2_pct="):
				cells["r2"] = bit.substr(10)
			elif bit.begins_with("rank3_pct="):
				cells["r3"] = bit.substr(10)
		table.append("| %s | %s | %s | %s | %s | %s |" % [form_name, cells["n"], cells["s"], cells["score"], cells["r2"], cells["r3"]])
	for row in table:
		lines.append(row)
	for line in lines:
		print(line)
	print("BOT_OK")
	quit(0)
	return true

func _run_count() -> int:
	var n := 24
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--n=") and arg.substr(4).is_valid_int():
			n = maxi(int(arg.substr(4)), 1)
	return n

func _run(seed_value: int, form: int) -> Dictionary:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game.day_seed = seed_value
	game.form_id = form
	game._director = SpawnDirector.new(seed_value)
	var start: Vector2 = game._player.position
	game._player.setup(form, start)
	FlappyMode.relock(game)
	game._begin_play()
	var rank2 := false
	var rank3 := false
	var frames := 0
	while int(game.phase) == int(game.PHASE_PLAY) and float(game.elapsed) < CAP and frames < 3600:
		_steer(game)
		game._process(STEP)
		frames += 1
		if int(game.rank_index) >= 1:
			rank2 = true
		if int(game.rank_index) >= 2:
			rank3 = true
	var death := float(game.elapsed)
	if int(game.phase) != int(game.PHASE_DEAD):
		death = CAP
	var result := {
		"death": death,
		"score": int(game.score),
		"evo": int(game.evo_points),
		"rank": int(game.rank_index) + 1,
		"rank2": rank2,
		"rank3": rank3,
		"killer": str(game.killer_name),
	}
	root.remove_child(game)
	game.free()
	return result

func _steer(game) -> void:
	var ship: PlayerShip = game._player
	var size: Vector2 = game._viewport_size()
	var floor_y := minf(FieldBackground.GROUND_FEET, size.y)
	var target := size.y * 0.46
	var gap_top := 24.0
	var gap_bot := floor_y - 24.0
	var soon_dx := 100000.0
	for gate in FlappyMode.gates():
		if not is_instance_valid(gate):
			continue
		var dx: float = gate.position.x - ship.position.x
		if dx < -32.0:
			continue
		if dx < soon_dx:
			soon_dx = dx
			target = gate.gap_center
			gap_top = gate.flight_top()
			gap_bot = gate.flight_bottom()
	target = _bias(game, ship, target, gap_top, gap_bot, soon_dx, floor_y)
	var form := int(game.form_id)
	var hop := FlappyMode.hop_px(form)
	var opening := maxf(gap_bot - gap_top, 24.0)
	var depth := minf(hop * 0.42, opening * 0.25)
	var flap_at := target + depth
	var ceiling := gap_top + ship.radius + 6.0
	if ship.position.y <= ceiling and ship.velocity.y < 0.0:
		return
	var near_floor := ship.position.y >= floor_y - ship.radius - 18.0
	var near_gap_floor := soon_dx < 260.0 and ship.position.y >= gap_bot - 12.0
	if near_floor or near_gap_floor:
		if ship.velocity.y > -80.0:
			FlappyMode.queue_flap()
		return
	if ship.velocity.y > 0.0 and ship.position.y > flap_at:
		FlappyMode.queue_flap()

func _bias(game, ship: PlayerShip, target: float, gap_top: float, gap_bot: float, soon_dx: float, floor_y: float) -> float:
	var threat_y := -1.0
	var soonest := 0.48
	var ship_x := ship.position.x
	for shot in game._shots:
		if shot.from_player or not is_instance_valid(shot):
			continue
		var dx: float = shot.position.x - ship_x
		if dx < -12.0 or dx > 180.0 or shot.velocity.x >= -8.0:
			continue
		var arrive: float = dx / -shot.velocity.x
		if arrive < 0.0 or arrive > soonest:
			continue
		var at_y: float = shot.position.y + shot.velocity.y * arrive
		if absf(at_y - ship.position.y) > 32.0 and absf(at_y - target) > 32.0:
			continue
		soonest = arrive
		threat_y = at_y
	for enemy in game._enemies:
		if not enemy.alive:
			continue
		var dx: float = enemy.position.x - ship_x
		var kind := int(enemy.kind)
		if kind == SpawnDirector.ANVIL or kind == SpawnDirector.PIANO:
			if absf(dx) > 36.0:
				continue
			var fall: float = Difficulty.fall_speed(kind) * float(enemy.speed_scale)
			if fall < 8.0 or enemy.position.y > ship.position.y:
				continue
			var drop_in: float = (ship.position.y - enemy.position.y) / fall
			if drop_in > soonest:
				continue
			soonest = drop_in
			threat_y = enemy.position.y
			continue
		if dx < -8.0 or dx > 170.0:
			continue
		var speed: float = maxf(float(enemy.speed), 1.0)
		var close_in: float = dx / speed
		if close_in > soonest:
			continue
		if absf(enemy.position.y - ship.position.y) > float(enemy.radius) + 24.0:
			continue
		soonest = close_in
		threat_y = enemy.position.y
	if threat_y < 0.0:
		return target
	var nudged: float = target + 36.0
	if threat_y >= ship.position.y:
		nudged = target - 36.0
	if soon_dx < 210.0:
		return clampf(nudged, gap_top + 14.0, gap_bot - 14.0)
	return clampf(nudged, 28.0, floor_y - 28.0)

func _median(values: Array[float]) -> float:
	if values.is_empty():
		return -1.0
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n % 2 == 1:
		return float(sorted[n / 2])
	return (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) * 0.5

func _pct(hits: int, n: int) -> float:
	if n <= 0:
		return 0.0
	return 100.0 * float(hits) / float(n)
