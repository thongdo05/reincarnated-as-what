extends SceneTree

## Frames of the Dragon form, the fireball fan, Meteor Rain, and the giant impact.
## xvfb-run godot --path . -s res://tests/dragon_shots.gd

var _phase := 0
var _frames := 0
var _game: Node

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))

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
		if _frames < 3:
			return false
		_ready_play()
		_game.set_process(false)
		_game.form_id = FormCatalog.Id.DRAGON
		_game._player.adopt_dragon(1.0)
		_game._player.position = Vector2(120, 140)
		_game._player.aim = _game._player.position
		_game._player._wobble = 0.35
		_game._refresh_hud()
		_game._player.queue_redraw()
		_frames = 0
		_phase = 2
		return false
	if _phase == 2:
		if _frames < 2:
			return false
		if not _save("dragon_flying.png"):
			return true
		for spec in FormCatalog.player_shots(FormCatalog.Id.DRAGON, _game._player.position, 0):
			_game._spawn_shot(spec, true)
		for shot in _game._shots:
			shot.tick(0.32)
			shot.queue_redraw()
		_frames = 0
		_phase = 3
		return false
	if _phase == 3:
		if _frames < 2:
			return false
		if not _save("fireball_fan.png"):
			return true
		for shot in _game._shots:
			shot.visible = false
			shot.queue_free()
		_game._shots.clear()
		_game._dragon_show.start_rain()
		for _i in DragonShow.CHARGE_FRAMES + 22:
			_game._dragon_show.tick(DragonShow.FRAME)
		_game._dragon_show.queue_redraw()
		_frames = 0
		_phase = 4
		return false
	if _phase == 4:
		if _frames < 2:
			return false
		if not _save("meteor_rain.png"):
			return true
		var rest := DragonShow.RAIN_FRAMES - 22 + DragonShow.FALL_FRAMES + 8
		for _i in rest:
			_game._dragon_show.tick(DragonShow.FRAME)
		_game._dragon_show.queue_redraw()
		_frames = 0
		_phase = 5
		return false
	if _frames < 2:
		return false
	if not _save("giant_meteor_impact.png"):
		return true
	print("DRAGON_SHOTS_OK phase %s frame %s" % [_game._dragon_show.phase, _game._dragon_show._frame])
	quit(0)
	return true

func _ready_play() -> void:
	var game = _game
	game.phase = game.PHASE_PLAY
	game._reveal.visible = false
	if game._hint_label != null:
		game._hint_label.visible = false
	if game._world_flash != null:
		game._world_flash.visible = false
	game._world_flash_left = 0.0
	game._paused = false
	game.elapsed = 2.0
	game.invuln = 0.0
	game._player.alive = true
	game._player.invulnerable = false
	game._player.visible = true
	game._clear_field()
	if game._title_board_button != null:
		game._title_board_button.visible = false

func _save(file_name: String) -> bool:
	if _game != null and _game.has_method("_refresh_hud"):
		_game._refresh_hud()
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image for %s" % file_name)
		quit(1)
		return false
	if image.get_width() < 900:
		image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var path := "/opt/cursor/artifacts/%s" % file_name
	if image.save_png(path) != OK:
		push_error("save failed %s" % path)
		quit(1)
		return false
	print("WROTE %s %sx%s" % [path, image.get_width(), image.get_height()])
	return true
