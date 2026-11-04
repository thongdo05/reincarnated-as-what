extends SceneTree

## Windowed shots of the death rank, name entry, and live boards.
## xvfb-run godot --path . -s res://tests/leaderboard_shots.gd

var _phase := 0
var _frames := 0
var _game: Node
var _wait := 0.0

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))

func _process(delta: float) -> bool:
	if _wait > 0.0:
		_wait -= delta
		return false
	match _phase:
		0:
			var packed: PackedScene = load("res://scenes/main.tscn")
			_game = packed.instantiate()
			root.add_child(_game)
			_game.process_mode = Node.PROCESS_MODE_DISABLED
			_seed_best()
			_phase = 1
			_frames = 0
		1:
			_show_death()
			_phase = 2
			_frames = 0
		2:
			_frames += 1
			if _frames > 400:
				push_error("rank did not arrive: %s" % _game._rank_label.text)
				quit(1)
				return true
			if str(_game._rank_label.text).find("#") >= 0:
				_frames = 0
				_phase = 3
		3:
			_frames += 1
			if _frames < 6:
				return false
			_shot("death_rank.png")
			_game._name_prompt.place_for(_game._viewport_size())
			_game._name_prompt.open("", "death")
			_frames = 0
			_phase = 4
		4:
			_frames += 1
			if _frames < 4:
				return false
			_shot("name_entry.png")
			_game._name_prompt.show_error(Leaderboard.REJECTED_NAME)
			_frames = 0
			_phase = 5
		5:
			_frames += 1
			if _frames < 3:
				return false
			_shot("name_rejected.png")
			_game._name_prompt.close()
			_game._open_board()
			_frames = 0
			_phase = 6
		6:
			if not _board_ready():
				_frames += 1
				if _frames > 400:
					push_error("board did not load: %s" % _game._board._status.text)
					quit(1)
					return true
				return false
			_frames = 0
			_phase = 7
		7:
			_frames += 1
			if _frames < 8:
				return false
			_shot("board_alltime.png")
			_game._board.show_period("daily")
			_frames = 0
			_phase = 8
		8:
			if not _board_ready():
				_frames += 1
				if _frames > 400:
					push_error("daily board did not load")
					quit(1)
					return true
				return false
			_frames = 0
			_phase = 9
		9:
			_frames += 1
			if _frames < 8:
				return false
			_shot("board_daily.png")
			_game._board.show_form("slime")
			_game._board.show_period("all")
			_frames = 0
			_phase = 10
		10:
			if not _board_ready():
				_frames += 1
				if _frames > 400:
					push_error("slime board did not load")
					quit(1)
					return true
				return false
			_frames = 0
			_phase = 11
		11:
			_frames += 1
			if _frames < 8:
				return false
			_shot("board_slime.png")
			_game._force_close_board()
			DisplayServer.window_set_min_size(Vector2i(0, 0))
			DisplayServer.window_set_size(Vector2i(390, 780))
			_frames = 0
			_phase = 12
		12:
			_frames += 1
			if _frames < 4:
				return false
			_game._open_board()
			_frames = 0
			_phase = 13
		13:
			if not _board_ready():
				_frames += 1
				if _frames > 400:
					push_error("portrait board did not load")
					quit(1)
					return true
				return false
			_frames = 0
			_phase = 14
		14:
			_frames += 1
			if _frames < 8:
				return false
			_shot("board_portrait.png")
			var restored: Vector2 = _game._viewport_size()
			_game._force_close_board()
			print("RESTORED %s" % _game._viewport_size())
			if restored.y <= restored.x:
				push_error("portrait board was not taller than it is wide (%s)" % restored)
				quit(1)
				return true
			print("SHOTS_OK")
			quit(0)
			return true
	return false

func _seed_best() -> void:
	var file := FileAccess.open("user://best_scores.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"epoch": BestScores.SCORE_EPOCH, "overall": 4242, "SLIME": 4242}))
	file.close()

func _show_death() -> void:
	_game.form_id = FormCatalog.Id.SLIME
	_game.rank_index = 1
	_game.score = 4242
	_game.elapsed = 30.0
	_game.killer_name = "Dire Wolf"
	_game.day_seed = 20261102
	_game.run_index = 0
	if _game._reveal != null:
		_game._reveal.visible = false
	_game._died_in_play = false
	_game.phase = _game.PHASE_DEAD
	_game._refresh_hud()
	_game._show_game_over()
	if _game._player != null:
		_game._player.visible = false
	_game._layout_pause(_game._viewport_size())
	_game._lb_gen += 1
	_game._fetch_ranks("slime", _game._lb_gen)

func _board_ready() -> bool:
	var status := str(_game._board._status.text)
	if status == "..." or status == "":
		if status == "..." :
			return false
		return _game._board._list.get_child_count() > 0
	if status == Leaderboard.UNREACHABLE or status == "leaderboard offline" or status == "No scores yet.":
		push_error("board status %s" % status)
		quit(1)
	return false

func _shot(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image for %s" % file_name)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/leaderboard")
	var path := "/opt/cursor/artifacts/leaderboard/%s" % file_name
	var err := image.save_png(path)
	if err != OK:
		push_error("save failed %s" % path)
		quit(1)
		return
	print("WROTE %s %s" % [path, image.get_size()])
