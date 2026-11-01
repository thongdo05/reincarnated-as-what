extends SceneTree

## Headless survival and rank timing. Not part of the CI smoke run.
## godot --headless -s res://tests/dodge_bot.gd

const STEP := 1.0 / 60.0
const CAP := 120.0

var _done := false
var _held_y := {}

func _initialize() -> void:
	pass

func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	_measure()
	return true

func _measure() -> void:
	var seeds := [20261101, 20261102, 20261103, 20261104, 20261108, 20261115]
	var rows: Array[String] = []
	for style in ["naive", "dodge"]:
		for form in [FormCatalog.Id.SLIME, FormCatalog.Id.GOBLIN]:
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
		"killer": str(game.killer_name),
	}
	root.remove_child(game)
	game.free()
	return result

func _steer(game, style: String, start: Vector2) -> void:
	var ship: PlayerShip = game._player
	if style == "naive":
		var y := start.y + sin(float(game.elapsed) * 0.65) * 18.0
		ship.aim = Vector2(start.x, clampf(y, 36.0, 200.0))
		return
	var y := _jukes(game, ship.position)
	var id: int = game.get_instance_id()
	var held := float(_held_y.get(id, y))
	# Goblin plants his feet, so retarget in steps. Slime can slide.
	var follow := 0.22 if int(game.form_id) == FormCatalog.Id.SLIME else 0.08
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
