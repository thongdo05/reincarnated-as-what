extends SceneTree

## Headless survival and rank timing. Not part of the CI smoke run.
## godot --headless -s res://tests/dodge_bot.gd

const STEP := 1.0 / 60.0
const CAP := 120.0

var _done := false
var _held_y := {}

func _initialize() -> void:
	# The first-run lesson is not part of the difficulty sample.
	Replay.mark_seen()

func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var args := OS.get_cmdline_user_args()
	if args.has("--report"):
		_report()
	elif args.has("--balance"):
		_measure_balance()
	else:
		_measure()
	return true

func _measure() -> void:
	var seeds := [20261101, 20261102, 20261103, 20261104, 20261108, 20261115]
	var rows: Array[String] = []
	for style in ["naive", "dodge", "strong"]:
		for form in FormCatalog.IDS:
			var deaths: Array[float] = []
			var r2: Array[float] = []
			var r3: Array[float] = []
			var reached2 := 0
			var reached3 := 0
			for seed_value in seeds:
				print("RUN %s %s %d" % [style, FormCatalog.display_name(form), int(seed_value)])
				var result := _run(int(seed_value), form, style)
				deaths.append(float(result["death"]))
				if float(result["rank2"]) >= 0.0:
					reached2 += 1
					r2.append(float(result["rank2"]))
				if float(result["rank3"]) >= 0.0:
					reached3 += 1
					r3.append(float(result["rank3"]))
				rows.append("%s %s seed %d death %.2f rank2 %s rank3 %s points %d killer %s" % [
					style,
					FormCatalog.display_name(form),
					int(seed_value),
					float(result["death"]),
					"%.2f" % float(result["rank2"]) if float(result["rank2"]) >= 0.0 else "never",
					"%.2f" % float(result["rank3"]) if float(result["rank3"]) >= 0.0 else "never",
					int(result["points"]),
					str(result["killer"]),
				])
			rows.append("SUMMARY %s %s n %d death_med %.2f death_min %.2f death_max %.2f rank2 %d/%d med %s rank3 %d/%d med %s" % [
				style,
				FormCatalog.display_name(form),
				seeds.size(),
				_median(deaths),
				_min(deaths),
				_max(deaths),
				reached2,
				seeds.size(),
				_median(r2) if not r2.is_empty() else -1.0,
				reached3,
				seeds.size(),
				_median(r3) if not r3.is_empty() else -1.0,
			])
	for row in rows:
		print(row)
	print("BOT_OK")
	quit(0)

func _run(seed_value: int, form: int, style: String) -> Dictionary:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game.day_seed = seed_value
	game.form_id = form
	game._director = SpawnDirector.new(seed_value)
	game._player.form_id = form
	game._player.setup(form, Vector2(134, 135))
	game._begin_play()
	var start: Vector2 = game._player.position
	var rank2 := -1.0
	var rank3 := -1.0
	var frames := 0
	while int(game.phase) == 1 and float(game.elapsed) < CAP and frames < 9000:
		_steer(game, style, start)
		game._process(STEP)
		frames += 1
		if rank2 < 0.0 and int(game.rank_index) >= 1:
			rank2 = float(game.elapsed)
		if rank3 < 0.0 and int(game.rank_index) >= 2:
			rank3 = float(game.elapsed)
	var death := float(game.elapsed)
	if int(game.phase) != 2:
		death = CAP
	var result := {
		"death": death,
		"rank2": rank2,
		"rank3": rank3,
		"points": int(game.evo_points),
		"score": int(game.score),
		"killer": str(game.killer_name),
		"powers": int(game.power_spawned),
		"loot": int(game.loot_count),
	}
	root.remove_child(game)
	game.free()
	return result

func _steer(game, style: String, start: Vector2) -> void:
	var ship: PlayerShip = game._player
	if style == "strong":
		_strong_steer(game, ship)
		return
	if style == "naive":
		var y := start.y + sin(float(game.elapsed) * 0.65) * 18.0
		ship.aim = Vector2(start.x, clampf(y, 36.0, 200.0))
		return
	var y := _jukes(game, ship.position)
	var id: int = game.get_instance_id()
	var held := float(_held_y.get(id, y))
	# Goblin's dodge aim stays the slower step this harness was tuned with.
	# Vending's aim is the finger; the body lag is the ship's, not the bot's.
	var follow := 0.22
	if int(game.form_id) == FormCatalog.Id.GOBLIN:
		follow = 0.08
	elif int(game.form_id) == FormCatalog.Id.VENDING:
		follow = 0.55
	elif int(game.form_id) == FormCatalog.Id.CAT:
		follow = 0.34
	if absf(y - held) > 48.0:
		follow = 0.45
	held = lerpf(held, y, follow)
	_held_y[id] = held
	var x := start.x
	for enemy in game._enemies:
		if not enemy.alive:
			continue
		if int(enemy.kind) == SpawnDirector.ANVIL or int(enemy.kind) == SpawnDirector.PIANO:
			if absf(enemy.position.x - ship.position.x) < 36.0:
				x = start.x - 28.0 if enemy.position.x > start.x else start.x + 36.0
	ship.aim = Vector2(clampf(x, 40.0, 200.0), held)

func _jukes(game, where: Vector2) -> float:
	var threat_y := -1.0
	var soonest := 99.0
	for shot in game._shots:
		if shot.from_player or not is_instance_valid(shot):
			continue
		var dx: float = shot.position.x - where.x
		if dx < -8.0 or dx > 260.0 or shot.velocity.x > -8.0:
			continue
		var arrive: float = dx / -shot.velocity.x
		var at_y: float = shot.position.y + shot.velocity.y * arrive
		if absf(at_y - where.y) < 34.0 and arrive < soonest:
			soonest = arrive
			threat_y = at_y
	for enemy in game._enemies:
		if not enemy.alive:
			continue
		if int(enemy.kind) != SpawnDirector.WOLF and int(enemy.kind) != SpawnDirector.EYE:
			continue
		var dx: float = enemy.position.x - where.x
		if dx < 0.0 or dx > 180.0:
			continue
		if absf(enemy.position.y - where.y) < enemy.radius + 20.0 and dx / maxf(enemy.speed, 1.0) < soonest:
			soonest = dx / maxf(enemy.speed, 1.0)
			threat_y = enemy.position.y
	if threat_y < 0.0:
		return _safest_y(game, where)
	if threat_y >= where.y:
		return clampf(where.y - 52.0, 36.0, 200.0)
	return clampf(where.y + 52.0, 36.0, 200.0)

func _safest_y(game, where: Vector2) -> float:
	var threats: Array[Dictionary] = []
	for enemy in game._enemies:
		if not enemy.alive:
			continue
		var velocity := Vector2(-enemy.speed, 0.0)
		if int(enemy.kind) == SpawnDirector.ANVIL or int(enemy.kind) == SpawnDirector.PIANO:
			velocity = Vector2(0.0, Difficulty.fall_speed(int(enemy.kind)) * enemy.speed_scale)
		threats.append({
			"position": enemy.position,
			"velocity": velocity,
			"pad": enemy.radius + 16.0,
		})
	for shot in game._shots:
		if shot.from_player or not is_instance_valid(shot):
			continue
		threats.append({
			"position": shot.position,
			"velocity": shot.velocity,
			"pad": shot.radius + 12.0,
		})
	var best_y := where.y
	var best := -100000.0
	for i in 17:
		var y := lerpf(36.0, 206.0, float(i) / 16.0)
		var safety := 0.0
		for threat in threats:
			var pos: Vector2 = threat["position"]
			var vel: Vector2 = threat["velocity"]
			var closing := where.x - pos.x
			var approach := 1.4
			if vel.x < -8.0 and closing > 0.0:
				approach = clampf(closing / -vel.x, 0.05, 1.6)
			elif vel.y > 8.0:
				approach = clampf((y - pos.y) / vel.y, 0.05, 1.6)
			var future_y := pos.y + vel.y * approach
			var gap := absf(future_y - y) - float(threat["pad"])
			var soon := clampf(1.3 - approach, 0.0, 1.3)
			safety += minf(gap, 80.0) * (0.25 + soon)
		safety -= absf(y - where.y) * 0.35
		if safety > best:
			best = safety
			best_y = y
	return best_y

## Expert thumb on the 480x270 field. A full-height correction takes about a quarter second.
const TOUCH_SPEED := 960.0
const LOOKAHEAD := 0.95

func _strong_steer(game, ship: PlayerShip) -> void:
	var origin: Vector2 = ship.position
	var radius := ship.radius
	var bounds: Rect2 = game._play_bounds(game._viewport_size())
	var threats := _strong_threats(game)
	var best_target := origin
	var best_score := -1000000.0
	var candidates: Array[Vector2] = [origin]
	var y := bounds.position.y + radius
	while y <= bounds.end.y - radius:
		candidates.append(Vector2(origin.x, y))
		candidates.append(Vector2(origin.x + 48.0, y))
		candidates.append(Vector2(origin.x - 36.0, y))
		y += 14.0
	for gem in game._loot:
		if is_instance_valid(gem) and gem.visible:
			candidates.append(gem.position)
	for drop in game._powers:
		if is_instance_valid(drop) and drop.visible:
			candidates.append(drop.position)
	for target in candidates:
		var clamped := _clamp_point(target, bounds, radius)
		var safety := _path_clearance(origin, clamped, radius, threats)
		# Any spot that stays clear beats a hit. Among clear spots, step toward gems.
		# A clearly safer lane beats a gem. Gems only matter when the lanes are close.
		var score := safety * 4.0
		if safety > 18.0:
			score += _pickup_pull(origin, clamped, game) 
		if score > best_score:
			best_score = score
			best_target = clamped
	var step := TOUCH_SPEED * STEP
	var delta := best_target - origin
	if delta.length() > step:
		delta = delta.normalized() * step
	ship.aim = origin + delta

func _strong_threats(game) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for shot in game._shots:
		if not is_instance_valid(shot) or shot.from_player or not shot.visible:
			continue
		rows.append({
			"pos": shot.position,
			"vel": shot.velocity,
			"delay": 0.0,
			"pad": shot.radius,
		})
	for enemy in game._enemies:
		if not enemy.alive:
			continue
		rows.append({
			"pos": enemy.position,
			"vel": enemy.move_velocity,
			"delay": 0.0,
			"pad": enemy.radius,
		})
		for item in enemy.telegraphs:
			rows.append({
				"pos": item["pos"],
				"vel": item["velocity"],
				"delay": float(item["left"]),
				"pad": 4.0,
			})
	for item in game.pattern_shots:
		rows.append({
			"pos": item["pos"],
			"vel": item["vel"],
			"delay": float(item["left"]),
			"pad": 4.0,
		})
	return rows

func _path_clearance(origin: Vector2, target: Vector2, radius: float, threats: Array[Dictionary]) -> float:
	var worst := 240.0
	for step in 10:
		var t := LOOKAHEAD * float(step) / 9.0
		var pos := origin.move_toward(target, TOUCH_SPEED * t)
		for threat in threats:
			var delay := float(threat["delay"])
			var flight := t - delay
			if flight < 0.0:
				continue
			var at: Vector2 = threat["pos"] + threat["vel"] * flight
			var gap := pos.distance_to(at) - radius - float(threat["pad"])
			if gap < worst:
				worst = gap
	return worst

func _pickup_pull(origin: Vector2, target: Vector2, game) -> float:
	var best := 0.0
	for gem in game._loot:
		if not is_instance_valid(gem) or not gem.visible:
			continue
		var closer := origin.distance_to(gem.position) - target.distance_to(gem.position)
		best = maxf(best, clampf(closer, 0.0, 40.0) * 0.35)
	return best

func _clamp_point(point: Vector2, bounds: Rect2, radius: float) -> Vector2:
	return Vector2(
		clampf(point.x, bounds.position.x + radius, bounds.end.x - radius),
		clampf(point.y, bounds.position.y + radius, bounds.end.y - radius)
	)

## Same seeds and the same steer policies as _measure. 24 runs per form.
## Prints median and p75 survival, median and best score, and rank rates.
## godot --headless -s res://tests/dodge_bot.gd -- --balance
func _measure_balance() -> void:
	var seeds: Array[int] = [
		20261101, 20261102, 20261103, 20261104, 20261108, 20261115,
		20261116, 20261122, 20261129, 20261206, 20261213, 20261220,
		20261227, 20270103, 20270110, 20270117, 20270124, 20270131,
		20270207, 20270214, 20270221, 20270228, 20270307, 20270314,
	]
	var styles: Array[String] = ["dodge", "strong", "naive"]
	var args := OS.get_cmdline_user_args()
	var style_at := args.find("--style")
	if style_at >= 0 and style_at + 1 < args.size():
		styles = [str(args[style_at + 1])]
	var limit_at := args.find("--limit")
	if limit_at >= 0 and limit_at + 1 < args.size():
		seeds = seeds.slice(0, int(args[limit_at + 1]))
	for style in styles:
		for form in FormCatalog.IDS:
			var deaths: Array[float] = []
			var scores: Array[float] = []
			var reached2 := 0
			var reached3 := 0
			for seed_value in seeds:
				print("RUN %s %s %d" % [style, FormCatalog.display_name(form), seed_value])
				var result := _run(seed_value, form, style)
				deaths.append(float(result["death"]))
				scores.append(float(result["score"]))
				if float(result["rank2"]) >= 0.0:
					reached2 += 1
				if float(result["rank3"]) >= 0.0:
					reached3 += 1
				print("ROW %s %s seed %d death %.2f score %d rank2 %s rank3 %s" % [
					style,
					FormCatalog.display_name(form),
					seed_value,
					float(result["death"]),
					int(result["score"]),
					"yes" if float(result["rank2"]) >= 0.0 else "no",
					"yes" if float(result["rank3"]) >= 0.0 else "no",
				])
			var n := seeds.size()
			print("BALANCE %s %s n %d death_med %.2f death_p75 %.2f score_med %.0f score_best %.0f rank2_pct %.1f rank3_pct %.1f" % [
				style,
				FormCatalog.display_name(form),
				n,
				_median(deaths),
				_percentile(deaths, 0.75),
				_median(scores),
				_max(scores),
				100.0 * float(reached2) / float(n),
				100.0 * float(reached3) / float(n),
			])
	print("BOT_OK")
	quit(0)

## n=40 by default. godot --headless -s res://tests/dodge_bot.gd -- --report
## Optional --style dodge|strong and --limit N.
func _report() -> void:
	var args := OS.get_cmdline_user_args()
	var count := 40
	var limit_at := args.find("--limit")
	if limit_at >= 0 and limit_at + 1 < args.size():
		count = int(args[limit_at + 1])
	var styles: Array[String] = ["dodge", "strong"]
	var style_at := args.find("--style")
	if style_at >= 0 and style_at + 1 < args.size():
		styles = [str(args[style_at + 1])]
	var forms: Array[int] = []
	forms.assign(FormCatalog.IDS)
	var form_at := args.find("--form")
	if form_at >= 0 and form_at + 1 < args.size():
		forms = [FormCatalog.id_from_key(str(args[form_at + 1]))]
	var seeds: Array[int] = []
	for i in count:
		seeds.append(20261101 + i * 7)
	for style in styles:
		for form in forms:
			var deaths: Array[float] = []
			var r2: Array[float] = []
			var r3: Array[float] = []
			var powers := 0
			var dead10 := 0
			var dead30 := 0
			var dead60 := 0
			var reached2 := 0
			var reached3 := 0
			for seed_value in seeds:
				print("RUN %s %s %d" % [style, FormCatalog.display_name(form), seed_value])
				var result := _run(seed_value, form, style)
				var death := float(result["death"])
				deaths.append(death)
				powers += int(result["powers"])
				if death <= 10.0:
					dead10 += 1
				if death <= 30.0:
					dead30 += 1
				if death <= 60.0:
					dead60 += 1
				if float(result["rank2"]) >= 0.0:
					reached2 += 1
					r2.append(float(result["rank2"]))
				if float(result["rank3"]) >= 0.0:
					reached3 += 1
					r3.append(float(result["rank3"]))
				var rank2_text := "never"
				var rank3_text := "never"
				if float(result["rank2"]) >= 0.0:
					rank2_text = "%.2f" % float(result["rank2"])
				if float(result["rank3"]) >= 0.0:
					rank3_text = "%.2f" % float(result["rank3"])
				print("ROW %s %s seed %d death %.2f rank2 %s rank3 %s powers %d evo %d loot %d score %d killer %s" % [
					style,
					FormCatalog.display_name(form),
					seed_value,
					death,
					rank2_text,
					rank3_text,
					int(result["powers"]),
					int(result["points"]),
					int(result["loot"]),
					int(result["score"]),
					str(result["killer"]),
				])
			var n := seeds.size()
			print("REPORT %s %s n %d med %.2f p90 %.2f dead10 %.1f dead30 %.1f dead60 %.1f rank2 %.1f rank3 %.1f rank2_med %s rank3_med %s powers %.2f" % [
				style,
				FormCatalog.display_name(form),
				n,
				_median(deaths),
				_percentile(deaths, 0.90),
				100.0 * float(dead10) / float(n),
				100.0 * float(dead30) / float(n),
				100.0 * float(dead60) / float(n),
				100.0 * float(reached2) / float(n),
				100.0 * float(reached3) / float(n),
				"%.2f" % _median(r2) if not r2.is_empty() else "never",
				"%.2f" % _median(r3) if not r3.is_empty() else "never",
				float(powers) / float(n),
			])
	print("BOT_OK")
	quit(0)

func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return -1.0
	var copy := values.duplicate()
	copy.sort()
	var index := clampi(int(ceil(fraction * float(copy.size()))) - 1, 0, copy.size() - 1)
	return float(copy[index])

func _median(values: Array[float]) -> float:
	if values.is_empty():
		return -1.0
	var copy := values.duplicate()
	copy.sort()
	return float(copy[copy.size() / 2])

func _min(values: Array[float]) -> float:
	var best := values[0]
	for value in values:
		best = minf(best, value)
	return best

func _max(values: Array[float]) -> float:
	var best := values[0]
	for value in values:
		best = maxf(best, value)
	return best
