extends SceneTree

## One still of the Demon Lord at each rank, drawn at the in-play size.
## xvfb-run godot --path . -s res://tests/demon_rank_shots.gd

var _phase := 0
var _frames := 0
var _index := 0
var _game: Node
var _ranks := [0, 1, 2]

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(480, 270))

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
		_pose(_ranks[_index])
		_frames = 0
		_phase = 2
		return false
	_frames += 1
	if _frames < 8:
		_game._process(1.0 / 60.0)
		return false
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image")
		quit(1)
		return true
	var path := "/opt/cursor/artifacts/demon_ranks/demon_r%d.png" % (_ranks[_index] + 1)
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/demon_ranks")
	if image.save_png(path) != OK:
		push_error("save failed %s" % path)
		quit(1)
		return true
	print("WROTE %s" % path)
	_index += 1
	if _index >= _ranks.size():
		print("DEMON_SHOTS_OK")
		quit(0)
		return true
	_game.queue_free()
	_game = null
	_phase = 0
	return false

func _pose(rank: int) -> void:
	var game = _game
	game.form_id = FormCatalog.Id.DEMON
	game.phase = game.PHASE_PLAY
	game._reveal.visible = false
	if game._hint_label != null:
		game._hint_label.visible = false
	if game._pause_button != null:
		game._pause_button.visible = false
	if game._sound_button != null:
		game._sound_button.visible = false
	game._paused = false
	game.rank_index = rank
	game.invuln = 9.0
	game._player.form_id = FormCatalog.Id.DEMON
	game._player.rank_index = rank
	game._player.small = false
	game._player.alive = true
	game._player.invulnerable = true
	game._player._apply_radius()
	game._player.position = Vector2(168, 132)
	game._player.aim = game._player.position
	game._player.queue_redraw()
	game._clear_field()
	game._refresh_hud()
