extends SceneTree

## CrazyGames-only screens: first-launch privacy line, the letter picker on a
## desktop window and a phone-sized landscape window, and the death card.
## xvfb-run godot --path . -s res://tests/crazygames_shots.gd

var _phase := 0
var _frames := 0
var _game: Node
var _desktop := Vector2i(1280, 720)
var _phone := Vector2i(844, 390)

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(_desktop)
	CrazyGamesHost.use_memory_store_for_test({})
	CrazyGamesHost.set_invite_override_for_test("https://www.crazygames.com/game/reincarnated-as-what?seed=20261101&form=goblin")

func _process(_delta: float) -> bool:
	if _phase == 0:
		var packed: PackedScene = load("res://scenes/main.tscn")
		_game = packed.instantiate()
		root.add_child(_game)
		_frames = 0
		_phase = 1
		return false
	_frames += 1
	if _phase == 1:
		if _frames < 8:
			return false
		if _game._privacy == null or not _game._privacy.visible:
			push_error("privacy notice missing")
			quit(1)
			return true
		_write("crazygames_privacy_notice.png")
		CrazyGamesHost.set_suggested_name_for_test("Ace")
		_game._name_prompt.open("", "death")
		_game._name_prompt.place_for(_game._viewport_size())
		_frames = 0
		_phase = 2
		return false
	if _phase == 2:
		if _frames < 4:
			return false
		if not _game._name_prompt.visible or not _game._name_prompt._picker:
			push_error("desktop name picker missing")
			quit(1)
			return true
		_write("crazygames_name_desktop.png")
		_apply_window(_phone)
		_frames = 0
		_phase = 3
		return false
	if _phase == 3:
		if _frames < 8:
			return false
		_game._name_prompt.place_for(_game._viewport_size())
		_write("crazygames_name_phone.png")
		_apply_window(_desktop)
		_game._name_prompt.close()
		_game._dismiss_privacy()
		_show_death()
		_frames = 0
		_phase = 4
		return false
	if _frames < 6:
		return false
	if _game.challenge_link().find("github.io") >= 0 or _game.challenge_link().find("crazygames.com") < 0:
		push_error("death card challenge link is not the SDK invite, got %s" % _game.challenge_link())
		quit(1)
		return true
	if _game._beat_button == null or not _game._beat_button.visible or _game._beat_button.text != "CHALLENGE":
		push_error("death card should show Challenge when the SDK link exists")
		quit(1)
		return true
	_write("crazygames_death_card.png")
	print("SHOTS_OK")
	quit(0)
	return true

func _apply_window(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	var window := root.get_window()
	if window != null:
		window.size = size
		window.content_scale_size = Vector2i(480, 270)
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	print("WINDOW %s viewport %s" % [DisplayServer.window_get_size(), root.get_visible_rect().size])


func _show_death() -> void:
	var game = _game
	game.phase = game.PHASE_DEAD
	game.death_elapsed = 2.0
	if game._reveal != null:
		game._reveal.visible = false
	if game._title_card != null:
		game._title_card.visible = false
	if game._world_flash != null:
		game._world_flash.visible = false
	if game._title_board_button != null:
		game._title_board_button.visible = false
	if game._pause_button != null:
		game._pause_button.visible = false
	if game._sound_button != null:
		game._sound_button.visible = false
	if game._hint_label != null:
		game._hint_label.visible = false
	if game._form_pick_button != null:
		game._form_pick_button.visible = false
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

func _write(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no framebuffer for %s" % file_name)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/crazygames")
	var path := "/opt/cursor/artifacts/crazygames/%s" % file_name
	if image.save_png(path) != OK:
		push_error("save failed %s" % path)
		quit(1)
		return
	print("WROTE %s %s" % [path, image.get_size()])
