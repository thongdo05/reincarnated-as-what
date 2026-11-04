extends SceneTree

## Locked telegraph, then the solid row beam.
## xvfb-run godot --path . -s res://tests/lich_row_beam_shots.gd

var _phase := 0
var _frames := 0
var _index := 0
var _game: Node
var _names: Array[String] = [
	"lich_beam_locked.png",
	"lich_beam_firing.png",
]

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
		_pose(_names[_index])
		_frames = 0
		_phase = 2
		return false
	_frames += 1
	_pin()
	_game.invuln = 30.0
	_game._process(1.0 / 60.0)
	if _frames < 4:
		return false
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image")
		quit(1)
		return true
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/bosses")
	var path := "/opt/cursor/artifacts/bosses/%s" % _names[_index]
	if image.save_png(path) != OK:
		push_error("save failed %s" % path)
		quit(1)
		return true
	print("WROTE %s" % path)
	_index += 1
	if _index >= _names.size():
		print("LICH_ROW_BEAM_OK")
		quit(0)
		return true
	_game.queue_free()
	_game = null
	_phase = 0
	return false

func _pin() -> void:
	if _game._player == null:
		return
	var at := Vector2(140, 148)
	if _index < _names.size() and _names[_index] == "lich_beam_firing.png":
		at = Vector2(140, 78)
	_game._player.position = at
	_game._player.aim = at
	_game._player.invulnerable = true

func _pose(file_name: String) -> void:
	var game = _game
	game.phase = game.PHASE_PLAY
	game.form_id = FormCatalog.Id.SLIME
	game._reveal.visible = false
	if game._hint_label != null:
		game._hint_label.visible = false
	if game._world_flash != null:
		game._world_flash.visible = false
	game._world_flash_left = 0.0
	game._tutorial_active = false
	if game._finger != null:
		game._finger.visible = false
	game._paused = false
	game.elapsed = 2.0
	game.invuln = 30.0
	game._player.form_id = FormCatalog.Id.SLIME
	game._player.alive = true
	_pin()
	if game._background != null:
		game._background.apply_world(WorldCatalog.SKY_CASTLE)
	game._clear_field()
	game._spawn_boss({
		"slug": "lich_king",
		"generation": 0,
		"hold_x": BossCatalog.rest_x("lich_king"),
		"origin_y": 132.0,
		"phase": 0.2,
		"wave_amp": 0.0,
	}, Vector2(480, 270))
	var boss: BossActor = game._living_boss()
	boss.hp = boss.max_hp
	boss.position = Vector2(boss.hold_x, boss.origin_y)
	boss.present("soul_beam", Vector2(140, 148))
	boss._beam_y = 148.0
	boss._beam_chain = 0
	if file_name == "lich_beam_locked.png":
		boss._beam_mode = 2
		boss._beam_time = 0.04
	else:
		boss._beam_mode = 3
		boss._beam_time = 0.15
		boss._beam_emit = 0.0
	if game._boss_banner != null:
		game._boss_banner.queue_redraw()
	game._refresh_hud()
