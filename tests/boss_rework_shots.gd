extends SceneTree

## Frames for the lich and knight rework, plus a WINNER chip on a boss.
## xvfb-run godot --path . -s res://tests/boss_rework_shots.gd

var _phase := 0
var _frames := 0
var _index := 0
var _game: Node
var _names: Array[String] = [
	"lich_entrance.png",
	"lich_beam_telegraph.png",
	"lich_soul_beam.png",
	"lich_skull_spiral.png",
	"lich_grave_hands.png",
	"lich_enrage.png",
	"knight_fake_charge.png",
	"knight_sword_waves.png",
	"knight_shield.png",
	"knight_enrage.png",
	"winner_boss_hit.png",
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
	if _frames < _hold_frames(_names[_index]):
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
		print("BOSS_REWORK_SHOTS_OK")
		quit(0)
		return true
	_game.queue_free()
	_game = null
	_phase = 0
	return false

func _hold_frames(file_name: String) -> int:
	if file_name == "lich_entrance.png":
		return 18
	if file_name == "lich_skull_spiral.png":
		return 80
	if file_name == "lich_soul_beam.png":
		return 8
	if file_name == "knight_sword_waves.png":
		return 36
	if file_name == "winner_boss_hit.png":
		return 3
	return 4

func _pin() -> void:
	var game = _game
	if game._player == null:
		return
	var at := Vector2(120, 148)
	if _index < _names.size() and _names[_index] == "lich_grave_hands.png":
		at = Vector2(210, 168)
	game._player.position = at
	game._player.aim = at
	game._player.invulnerable = true
	game.invuln = 30.0

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
	game._player.invulnerable = true
	_pin()
	game._clear_field()
	var knight := file_name.begins_with("knight")
	var slug := "death_knight" if knight else "lich_king"
	game._spawn_boss({
		"slug": slug,
		"generation": 0,
		"hold_x": BossCatalog.rest_x(slug),
		"origin_y": 132.0,
		"phase": 0.4,
		"wave_amp": 6.0,
	}, Vector2(480, 270))
	var boss: BossActor = game._living_boss()
	boss.hp = boss.max_hp
	if file_name == "lich_entrance.png":
		game._refresh_hud()
		return
	boss.present("charge" if knight else "soul_beam", game._player.position)
	boss.position = Vector2(boss.hold_x, boss.origin_y)
	if file_name == "lich_beam_telegraph.png":
		boss.present("soul_beam", game._player.position)
	elif file_name == "lich_soul_beam.png":
		boss.present("soul_beam", game._player.position)
		boss._beam_mode = 2
		boss._beam_time = 0.15
	elif file_name == "lich_skull_spiral.png":
		boss.present("skull_spiral", game._player.position)
	elif file_name == "lich_grave_hands.png":
		boss.present("grave_hands", game._player.position)
	elif file_name == "lich_enrage.png":
		boss.hp = 90
		boss.enraged = true
		boss.enrage_flash = 0.35
		boss.present("beam_rain", game._player.position)
	elif file_name == "knight_fake_charge.png":
		boss.present("fake_charge", Vector2(120, 40))
	elif file_name == "knight_sword_waves.png":
		boss.present("sword_waves", game._player.position)
		for item in boss.telegraphs:
			item["left"] = 0.05
	elif file_name == "knight_shield.png":
		boss.present("shield", game._player.position)
		game._spawn_shot({
			"position": boss.position + Vector2(-22, -8),
			"velocity": Vector2(20, 0),
			"sprite": "slime_shot.png",
			"damage": 1,
		}, true)
		game._collide()
	elif file_name == "knight_enrage.png":
		boss.hp = 160
		boss.enraged = true
		boss.enrage_flash = 0.35
		boss.present("charge", game._player.position)
	elif file_name == "winner_boss_hit.png":
		boss.intro_left = 0.0
		boss.state = BossActor.HOLD
		boss.position = Vector2(boss.hold_x, boss.origin_y)
		boss.fight_left = BossDirector.LIFE
		game.form_id = FormCatalog.Id.VENDING
		game._player.form_id = FormCatalog.Id.VENDING
		game._winner_clear()
	if game._boss_banner != null:
		game._boss_banner.queue_redraw()
	game._refresh_hud()
