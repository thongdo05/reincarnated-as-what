extends SceneTree

## Headless late-run frame times. Same density the before-pass used:
## 18 enemies, 140 player shots, 70 enemy shots, popups, and hit flashes.
## godot --headless -s res://tests/stress_frame.gd

func _initialize() -> void:
	pass

func _process(_delta: float) -> bool:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game._begin_play()
	game.invuln = 999.0
	game._player.invulnerable = true
	game.elapsed = 90.0
	var size := Vector2(480, 270)
	for i in 18:
		game._spawn_enemy({
			"t": 0.0,
			"kind": SpawnDirector.EYE if i % 3 != 2 else SpawnDirector.WOLF,
			"x_ratio": 0.4,
			"phase": float(i),
			"stop_ratio": 0.3,
			"y_bias": 0.0,
			"wave_amp": 8.0,
		}, size)
	for i in 140:
		game._spawn_shot({
			"position": Vector2(40.0 + float(i % 20) * 18.0, 40.0 + float(i % 7) * 22.0),
			"velocity": Vector2(220.0, 0.0),
			"sprite": "slime_shot.png",
			"radius": 4.0,
			"damage": 1,
		}, true)
	for i in 70:
		game._spawn_shot({
			"position": Vector2(460.0 - float(i % 10) * 12.0, 30.0 + float(i % 9) * 24.0),
			"velocity": Vector2(-180.0, 12.0),
			"sprite": "arrow.png" if i % 2 == 0 else "floating_eye_bolt.png",
			"radius": 5.0,
			"damage": 1,
			"killer_name": "Floating Eye",
		}, false)
	for i in 24:
		game._combat.push("+%d" % (120 + i * 17), Vector2(80, 40), Color("241428"))
	for i in 20:
		game._spawn_fx("hit_flash.png", Vector2(100 + i * 8, 120), 0.8, 0.5, 1.4)
	for _i in 20:
		game._process(1.0 / 60.0)
	var times: Array[float] = []
	for _i in 180:
		var t0 := Time.get_ticks_usec()
		game._process(1.0 / 60.0)
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	var sum := 0.0
	for value in times:
		sum += value
	var med: float = times[times.size() / 2]
	var p95: float = times[int(float(times.size()) * 0.95)]
	var hitch0 := Time.get_ticks_usec()
	game.evo_points = int(FormCatalog.rank_gates()[1]) - 1
	game.rank_index = 1
	game._player.set_rank(1)
	game._gain_skill(1)
	var hitch := float(Time.get_ticks_usec() - hitch0) / 1000.0
	print("STRESS n %d mean_ms %.3f med_ms %.3f p95_ms %.3f max_ms %.3f shots %d enemies %d fx %d texts %d evolve_hitch_ms %.3f" % [
		times.size(), sum / float(times.size()), med, p95, times[times.size() - 1],
		game._shots.size(), game._enemies.size(), game._effects.size(), game._combat.items.size(), hitch,
	])
	quit(0)
	return true
