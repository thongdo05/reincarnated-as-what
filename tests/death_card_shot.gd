extends SceneTree

## Saves the default-mode death card. Not part of CI.
## xvfb-run godot --path . -s res://tests/death_card_shot.gd

var _phase := 0
var _frames := 0
var _game: Node
var _which := 0

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(480, 270))
	var best := "user://best_scores.json"
	if FileAccess.file_exists(best):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(best))

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
		_show_card()
		_frames = 0
		_phase = 2
		return false
	_frames += 1
	if _frames < 6:
		return false
	if _which == 0:
		_write("death_card_new_best.png")
		_game._on_beat_link()
		_game._layout_death_card()
		_which = 1
		_frames = 0
		return false
	_write("death_card_link_copied.png")
	print("SHOTS_OK")
	quit(0)
	return true

func _show_card() -> void:
	var game = _game
	if game._reveal != null:
		game._reveal.visible = false
	game.form_id = FormCatalog.Id.SLIME
	game.rank_index = 1
	game.score = 12400
	game.elapsed = 47.0
	game.killer_name = "Dire Wolf"
	game.day_seed = 20261101
	game.run_index = 0
	game._show_game_over()
	game._card_age = 1.0
	game._tick_new_best_pop()
	if game._new_best_label == null or game._new_best_label.text != "NEW BEST!":
		push_error("expected NEW BEST on the death card")
		quit(1)
	if game._beat_button == null or game._beat_button.text != "CHALLENGE A FRIEND":
		push_error("expected the challenge button")
		quit(1)
	if str(game._seed_label.text).find("·") >= 0:
		push_error("seed line still has a missing glyph")
		quit(1)

func _write(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.get_width() != 480 or image.get_height() != 270:
		var size := image.get_size() if image != null else Vector2i.ZERO
		push_error("expected 480x270, got %s" % size)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/death-card")
	var path := "/opt/cursor/artifacts/death-card/%s" % file_name
	var err := image.save_png(path)
	if err != OK:
		push_error("save failed %s" % path)
		quit(1)
		return
	print("WROTE %s" % path)
