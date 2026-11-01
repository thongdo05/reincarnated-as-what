extends SceneTree

## Gameplay and pause shots for the three new forms.
## xvfb-run godot --path . -s res://tests/form_shots.gd

var _phase := 0
var _frames := 0
var _index := 0
var _game: Node
var _specs: Array[Dictionary] = []

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(480, 270))
	_specs = [
		{"file": "vending_r1.png", "form": FormCatalog.Id.VENDING, "rank": 0, "kind": "play"},
		{"file": "vending_r3.png", "form": FormCatalog.Id.VENDING, "rank": 2, "kind": "play"},
		{"file": "vending_winner.png", "form": FormCatalog.Id.VENDING, "rank": 1, "kind": "winner"},
		{"file": "cat_r1.png", "form": FormCatalog.Id.CAT, "rank": 0, "kind": "play"},
		{"file": "cat_r3.png", "form": FormCatalog.Id.CAT, "rank": 2, "kind": "play"},
		{"file": "cat_reflect.png", "form": FormCatalog.Id.CAT, "rank": 1, "kind": "reflect"},
		{"file": "demon_r1.png", "form": FormCatalog.Id.DEMON, "rank": 0, "kind": "orbs"},
		{"file": "demon_r3.png", "form": FormCatalog.Id.DEMON, "rank": 2, "kind": "orbs"},
		{"file": "pause_vending.png", "form": FormCatalog.Id.VENDING, "rank": 0, "kind": "pause", "points": 240},
		{"file": "pause_cat.png", "form": FormCatalog.Id.CAT, "rank": 0, "kind": "pause", "points": 240},
		{"file": "pause_demon.png", "form": FormCatalog.Id.DEMON, "rank": 1, "kind": "pause", "points": Difficulty.GATE_RANK2 + 800},
	]

func _process(_delta: float) -> bool:
	if _phase == 0:
		var packed: PackedScene = load("res://scenes/main.tscn")
		_game = packed.instantiate()
		root.add_child(_game)
		_frames = 0
		_phase = 1
		return false
	if _phase == 1:
		_frames += 1
		if _frames < 2:
			return false
		_apply(_specs[_index])
		_frames = 0
		_phase = 2
		return false
	_frames += 1
	if _frames < 6:
		_game._process(1.0 / 60.0)
		return false
	var spec: Dictionary = _specs[_index]
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image for %s" % spec["file"])
		quit(1)
		return true
	var path := "/opt/cursor/artifacts/forms/%s" % spec["file"]
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/forms")
	if image.save_png(path) != OK:
		push_error("save failed %s" % path)
		quit(1)
		return true
	print("WROTE %s" % path)
	_index += 1
	if _index >= _specs.size():
		print("FORM_SHOTS_OK")
		quit(0)
		return true
	_game.queue_free()
	_game = null
	_phase = 0
	return false

func _apply(spec: Dictionary) -> void:
	var game = _game
	var form := int(spec["form"])
	var rank := int(spec["rank"])
	game.form_id = form
	game.phase = game.PHASE_PLAY
	game._reveal.visible = false
	if game._hint_label != null:
		game._hint_label.visible = false
	game._paused = false
	game.rank_index = rank
	game.evo_points = 0 if rank == 0 else int(FormCatalog.rank_gates()[rank - 1])
	game.invuln = 9.0
	game._player.form_id = form
	game._player.rank_index = rank
	game._player.small = false
	game._player.alive = true
	game._player.invulnerable = true
	game._player._apply_radius()
	game._player.position = Vector2(130, 140)
	game._player.aim = game._player.position
	game._player.queue_redraw()
	game._clear_field()
	var kind := str(spec["kind"])
	if kind == "pause":
		game.evo_points = int(spec["points"])
		game._player.position = Vector2(360, 200)
		game._player.aim = game._player.position
		game._paused = true
		game._refresh_hud()
		game._refresh_pause_card()
		game._layout_pause(Vector2(480, 270))
		game._pause_overlay.visible = true
		return
	game._pause_overlay.visible = false
	game._spawn_enemy({
		"t": 0.0,
		"kind": SpawnDirector.EYE,
		"x_ratio": 0.72,
		"phase": 0.2,
		"stop_ratio": 0.15,
		"y_bias": -20.0,
		"wave_amp": 6.0,
		"hold_fire": true,
	}, Vector2(480, 270))
	game._spawn_enemy({
		"t": 0.0,
		"kind": SpawnDirector.WOLF,
		"x_ratio": 0.55,
		"phase": 1.0,
		"stop_ratio": 0.4,
		"y_bias": 30.0,
		"wave_amp": 0.0,
		"hold_fire": true,
	}, Vector2(480, 270))
	if kind == "orbs":
		for i in 3:
			var shots := FormCatalog.player_shots(form, game._player.position + Vector2(18 + i * 36, -16 + i * 14), rank)
			for shot_spec in shots:
				shot_spec["homing"] = 0.0
				game._spawn_shot(shot_spec, true)
	elif kind == "reflect":
		var swipe_spec: Dictionary = FormCatalog.player_shots(form, game._player.position, rank)[0]
		var swipe = game._spawn_shot(swipe_spec, true)
		game._spawn_shot({
			"position": swipe.position + Vector2(8, -2),
			"velocity": Vector2(-140, 20),
			"sprite": "floating_eye_bolt.png",
			"damage": 1,
			"killer_name": "Floating Eye",
		}, false)
		game._spawn_shot({
			"position": swipe.position + Vector2(4, 8),
			"velocity": Vector2(-120, -16),
			"sprite": "arrow.png",
			"damage": 1,
			"killer_name": "Skeleton Archer",
		}, false)
		game._collide()
	elif kind == "winner":
		for i in 4:
			game._spawn_enemy({
				"t": 0.0,
				"kind": SpawnDirector.EYE,
				"x_ratio": 0.5 + float(i) * 0.08,
				"phase": float(i),
				"stop_ratio": 0.2,
				"y_bias": -40.0 + float(i) * 22.0,
				"wave_amp": 4.0,
				"hold_fire": true,
			}, Vector2(480, 270))
		for shot_spec in FormCatalog.player_shots(form, game._player.position, rank):
			game._spawn_shot(shot_spec, true)
		game._winner_clear()
	else:
		for shot_spec in FormCatalog.player_shots(form, game._player.position, rank):
			game._spawn_shot(shot_spec, true)
	game._refresh_hud()
	game._player.queue_redraw()
