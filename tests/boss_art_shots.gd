extends SceneTree

## Final attack art, on a bright world and a dark one.
## xvfb-run godot --path . -s res://tests/boss_art_shots.gd

var _phase := 0
var _frames := 0
var _index := 0
var _game: Node
var _names: Array[String] = [
	"lich_soul_beam_bright.png",
	"lich_soul_beam_dark.png",
	"lich_skull_spiral.png",
	"lich_grave_hands.png",
	"lich_bone_rain.png",
	"knight_sword_waves.png",
	"knight_shield.png",
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
	if _frames < _hold(_names[_index]):
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
		print("BOSS_ART_SHOTS_OK")
		quit(0)
		return true
	_game.queue_free()
	_game = null
	_phase = 0
	return false

func _hold(file_name: String) -> int:
	if file_name == "lich_skull_spiral.png":
		return 70
	if file_name == "lich_grave_hands.png":
		return 16
	if file_name == "knight_sword_waves.png":
		return 28
	if file_name == "lich_bone_rain.png":
		return 4
	return 6

func _pin() -> void:
	if _game._player == null:
		return
	var at := Vector2(150, 150)
	if _index < _names.size() and _names[_index] == "lich_grave_hands.png":
		at = Vector2(210, 180)
	_game._player.position = at
	_game._player.aim = at
	_game._player.invulnerable = true
	_game.invuln = 30.0

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
	var world := WorldCatalog.SKY_CASTLE
	if file_name == "lich_soul_beam_dark.png":
		world = "underworld"
	if game._background != null:
		game._background.apply_world(world)
	game._clear_field()
	var knight := file_name.begins_with("knight")
	var slug := "death_knight" if knight else "lich_king"
	game._spawn_boss({
		"slug": slug,
		"generation": 0,
		"hold_x": BossCatalog.rest_x(slug),
		"origin_y": 128.0,
		"phase": 0.4,
		"wave_amp": 4.0,
	}, Vector2(480, 270))
	var boss: BossActor = game._living_boss()
	boss.hp = boss.max_hp
	boss.position = Vector2(boss.hold_x, boss.origin_y)
	if file_name.begins_with("lich_soul_beam"):
		boss.present("soul_beam", game._player.position)
		boss._beam_mode = 3
		boss._beam_y = game._player.position.y
		boss._beam_time = 0.1
	elif file_name == "lich_skull_spiral.png":
		boss.present("skull_spiral", game._player.position)
	elif file_name == "lich_grave_hands.png":
		boss.present("grave_hands", game._player.position)
		boss._hands_left = 0.04
	elif file_name == "lich_bone_rain.png":
		boss.present("bone_rain", Vector2(180, 140))
		boss.age = 0.04
	elif file_name == "knight_sword_waves.png":
		boss.present("sword_waves", game._player.position)
		for item in boss.telegraphs:
			item["left"] = 0.04
	elif file_name == "knight_shield.png":
		boss.present("shield", game._player.position)
		game._spawn_shot({
			"position": boss.position + Vector2(-22, -8),
			"velocity": Vector2(20, 0),
			"sprite": "slime_shot.png",
			"damage": 1,
		}, true)
		game._collide()
	if game._boss_banner != null:
		game._boss_banner.queue_redraw()
	game._refresh_hud()
