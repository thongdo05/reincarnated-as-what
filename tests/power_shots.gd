extends SceneTree

## HUD with a Power level, and the OVERDRIVE pickup beside a bomb.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/power_shots.gd

var _phase := 0
var _frames := 0
var _index := 0
var _game: Node
var _out := "/opt/cursor/artifacts/screenshots"

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(480, 270))
	DirAccess.make_dir_recursive_absolute(_out)

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
		if _frames < 3:
			return false
		_show_power()
		_frames = 0
		_phase = 2
		return false
	_frames += 1
	if _frames < 6:
		return false
	if _index == 0:
		_save("power_level_hud.png")
		_show_drop()
		_frames = 0
		_index = 1
		return false
	_save("overdrive_drop.png")
	print("POWER_SHOTS_OK")
	quit(0)
	return true

func _show_power() -> void:
	var game = _game
	game.form_id = FormCatalog.Id.SLIME
	game.phase = game.PHASE_PLAY
	game._reveal.visible = false
	if game._hint_label != null:
		game._hint_label.visible = false
	game._pause_overlay.visible = false
	game.rank_index = 4
	game.evo_points = Difficulty.GATE_RANK5 + Difficulty.power_step_points(1) + Difficulty.power_step_points(2) + int(Difficulty.power_step_points(3) / 2)
	game.invuln = 30.0
	game.elapsed = 96.0
	game._player.form_id = FormCatalog.Id.SLIME
	game._player.rank_index = 4
	game._player.power_level = Difficulty.power_level(game.evo_points)
	game._player.alive = true
	game._player.visible = true
	game._player.invulnerable = true
	game._player.position = Vector2(150, 140)
	game._player.aim = game._player.position
	game._player._apply_radius()
	game._clear_field()
	game._spawn_enemy({
		"t": 0.0,
		"kind": SpawnDirector.EYE,
		"x_ratio": 0.75,
		"phase": 0.2,
		"stop_ratio": 0.2,
		"y_bias": -20.0,
		"wave_amp": 6.0,
		"hold_fire": true,
	}, Vector2(480, 270))
	game._refresh_hud()
	game._player.queue_redraw()

func _show_drop() -> void:
	var game = _game
	game.rank_index = 2
	game.evo_points = Difficulty.GATE_RANK3
	game._player.rank_index = 2
	game._player.power_level = 0
	game._player.position = Vector2(120, 130)
	game._player.aim = game._player.position
	game._clear_field()
	game._spawn_power(Vector2(210, 130), "overdrive")
	game._spawn_power(Vector2(300, 130), "bomb")
	game._spawn_shot({
		"position": Vector2(360, 150),
		"velocity": Vector2(-40, 0),
		"sprite": "floating_eye_bolt.png",
		"damage": 1,
		"killer_name": "Floating Eye",
	}, false)
	game._refresh_hud()

func _save(file_name: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := _out + "/" + file_name
	var err := image.save_png(path)
	print("SAVED %s err %s" % [path, err])
