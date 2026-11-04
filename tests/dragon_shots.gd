extends SceneTree

## Frames of the earned Dragon form, Meteor Rain, and the slain banner.
## xvfb-run godot --path . -s res://tests/dragon_shots.gd

var _phase := 0
var _frames := 0
var _game: Node

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
	_frames += 1
	if _phase == 1:
		if _frames < 3:
			return false
		_ready_play()
		_game.form_id = FormCatalog.Id.DRAGON
		_game._player.adopt_dragon(1.0)
		_game._player.position = Vector2(110, 150)
		_game._player.aim = _game._player.position
		for spec in FormCatalog.player_shots(FormCatalog.Id.DRAGON, _game._player.position, 0):
			spec["position"] = _game._player.position + Vector2(36, 0)
			_game._spawn_shot(spec, true)
		_game._player.queue_redraw()
		for shot in _game._shots:
			shot.tick(0.28)
		_frames = 0
		_phase = 2
		return false
	if _phase == 2:
		if _frames < 2:
			return false
		if not _save("dragon_form.png"):
			return true
		_game.set_process(false)
		_game._dragon_show.start_rain()
		for _i in 32:
			_game._dragon_show.tick(DragonShow.FRAME)
		_game._dragon_show.queue_redraw()
		_frames = 0
		_phase = 3
		return false
	if _phase == 3:
		if _frames < 2:
			return false
		if not _save("meteor_rain.png"):
			return true
		_game._dragon_show.begin_slay(100000, Vector2(220, 130))
		_game._dragon_show.tick(0.2)
		_game._dragon_show.queue_redraw()
		_frames = 0
		_phase = 4
		return false
	if _frames < 2:
		return false
	if not _save("dragon_slain.png"):
		return true
	print("DRAGON_SHOTS_OK")
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

func _save(file_name: String) -> bool:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image for %s" % file_name)
		quit(1)
		return false
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var path := "/opt/cursor/artifacts/%s" % file_name
	if image.save_png(path) != OK:
		push_error("save failed %s" % path)
		quit(1)
		return false
	print("WROTE %s" % path)
	return true
