extends SceneTree

## Saves the death card: a normal run, a NEW BEST run, the copied challenge,
## and the iOS card with the ad line. Not part of CI.
## xvfb-run godot --path . -s res://tests/death_card_shot.gd

var _phase := 0
var _frames := 0
var _game: Node
var _which := 0

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(480, 270))
	_clear_bests()

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
		_show_normal()
		_frames = 0
		_phase = 2
		return false
	_frames += 1
	if _frames < 6:
		return false
	if _which == 0:
		_write("death_card_normal.png")
		_clear_bests()
		_show_new_best()
		_which = 1
		_frames = 0
		return false
	if _which == 1:
		_write("death_card_new_best.png")
		_game._on_beat_link()
		_game._layout_death_card()
		_which = 2
		_frames = 0
		return false
	if _which == 2:
		_write("death_card_link_copied.png")
		_show_ios()
		_which = 3
		_frames = 0
		return false
	_write("death_card_ios.png")
	print("SHOTS_OK")
	quit(0)
	return true

func _quiet_hud() -> void:
	var game = _game
	game.phase = game.PHASE_DEAD
	game.death_elapsed = 2.0
	if game._reveal != null:
		game._reveal.visible = false
	if game._world_flash != null:
		game._world_flash.visible = false
		game._world_flash_left = 0.0
	if game._title_board_button != null:
		game._title_board_button.visible = false
	if game._pause_button != null:
		game._pause_button.visible = false
	if game._sound_button != null:
		game._sound_button.visible = false
	if game._hint_label != null:
		game._hint_label.visible = false
	if game._title_card != null:
		game._title_card.visible = false

func _show_normal() -> void:
	BestScores.record("GOBLIN", 51397)
	var game = _game
	_hide_ad()
	_quiet_hud()
	game.form_id = FormCatalog.Id.GOBLIN
	game.rank_index = 0
	game.score = 275
	game.elapsed = 18.0
	game.killer_name = "Dire Wolf"
	game.day_seed = 20261101
	game.run_index = 0
	game.game_over_visible = false
	game._show_game_over()
	game._card_age = 1.0
	if game._new_best_label != null and game._new_best_label.visible:
		push_error("a score under the stored best should not say NEW BEST")
		quit(1)
	var line := str(game._share_label.text)
	if line.find("Reached GOBLIN") < 0 or line.find("51,397") < 0 or line.find("DAILY") < 0:
		push_error("normal card should name the form and both bests, got %s" % line)
		quit(1)

func _show_new_best() -> void:
	var game = _game
	_hide_ad()
	_quiet_hud()
	game.form_id = FormCatalog.Id.SLIME
	game.rank_index = 1
	game.score = 12400
	game.elapsed = 47.0
	game.killer_name = "Dire Wolf"
	game.day_seed = 20261101
	game.run_index = 0
	game.game_over_visible = false
	game._show_game_over()
	game._card_age = 1.0
	game._tick_new_best_pop()
	if game._new_best_label == null or game._new_best_label.text != "NEW BEST!":
		push_error("expected NEW BEST on the death card")
		quit(1)
	if game._beat_button == null or game._beat_button.text != "CHALLENGE A FRIEND":
		push_error("expected the challenge button")
		quit(1)
	if game._footer_label == null or game._footer_label.text != "BEAT MY RUN":
		push_error("the death card should end with BEAT MY RUN")
		quit(1)
	if str(game._footer_label.text).find("·") >= 0:
		push_error("footer line still has a missing glyph")
		quit(1)
	var fonts := [
		int(game._restart_button.get_theme_font_size("font_size")),
		int(game._share_button.get_theme_font_size("font_size")),
		int(game._beat_button.get_theme_font_size("font_size")),
		int(game._board_button.get_theme_font_size("font_size")),
	]
	if fonts[0] != fonts[1] or fonts[0] != fonts[2] or fonts[0] != fonts[3]:
		push_error("death buttons should share one font size, got %s" % fonts)
		quit(1)

func _show_ios() -> void:
	BestScores.record("GOBLIN", 51397)
	var game = _game
	game._copy_left = 0.0
	if game._copy_toast != null:
		game._copy_toast.visible = false
	if game._beat_button != null:
		game._beat_button.text = "CHALLENGE A FRIEND"
		game._style_challenge(false)
	_ensure_ad()
	_quiet_hud()
	game.form_id = FormCatalog.Id.GOBLIN
	game.rank_index = 0
	game.score = 275
	game.elapsed = 18.0
	game.killer_name = "Dire Wolf"
	game.day_seed = 20261101
	game.run_index = 1
	game.game_over_visible = false
	game._show_game_over()
	_ensure_ad()
	game._layout_death_card()
	game._card_age = 1.0
	if game._form_pick_button == null or not game._form_pick_button.visible:
		push_error("the iOS card should show the ad line")
		quit(1)
	if game._form_pick_button.text != "Watch ad: choose your form":
		push_error("ad line should keep its label, got %s" % game._form_pick_button.text)
		quit(1)
	if game._form_pick_button.size.y + 0.01 < 22.0 or game._form_pick_button.size.y > 28.0:
		push_error("ad line should stay slim, got %s" % game._form_pick_button.size)
		quit(1)

func _ensure_ad() -> void:
	var game = _game
	if game._form_pick_button == null:
		game._form_pick_button = game._make_store_button()
		game._game_over.add_child(game._form_pick_button)
	game._form_pick_button.text = "Watch ad: choose your form"
	game._form_pick_button.visible = true

func _hide_ad() -> void:
	if _game._form_pick_button != null:
		_game._form_pick_button.visible = false

func _clear_bests() -> void:
	var best := "user://best_scores.json"
	if FileAccess.file_exists(best):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(best))

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
