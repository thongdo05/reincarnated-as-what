extends SceneTree

## Gameplay frames for the three bosses and dragon phase 2.
## xvfb-run godot --path . -s res://tests/boss_shots.gd

var _phase := 0
var _frames := 0
var _index := 0
var _game: Node
var _specs: Array[Dictionary] = []

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(480, 270))
	_specs = [
		{"file": "boss_lich_king.png", "slug": "lich_king", "attack": "skull", "hp": 20},
		{"file": "boss_death_knight.png", "slug": "death_knight", "attack": "charge", "hp": 25},
		{"file": "boss_great_dragon.png", "slug": "great_dragon", "attack": "sweep", "hp": 30},
		{"file": "boss_great_dragon_phase2.png", "slug": "great_dragon", "attack": "dive", "hp": 12},
	]

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
		_apply(_specs[_index])
		_frames = 0
		_phase = 2
		return false
	_frames += 1
	if _frames < 4:
		_game._process(1.0 / 60.0)
		return false
	var spec: Dictionary = _specs[_index]
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image for %s" % spec["file"])
		quit(1)
		return true
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/bosses")
	var path := "/opt/cursor/artifacts/bosses/%s" % spec["file"]
	if image.save_png(path) != OK:
		push_error("save failed %s" % path)
		quit(1)
		return true
	print("WROTE %s" % path)
	_index += 1
	if _index >= _specs.size():
		print("BOSS_SHOTS_OK")
		quit(0)
		return true
	_game.queue_free()
	_game = null
	_phase = 0
	return false

func _apply(spec: Dictionary) -> void:
	var game = _game
	game.phase = game.PHASE_PLAY
	game.form_id = FormCatalog.Id.SLIME
	game._reveal.visible = false
	if game._hint_label != null:
		game._hint_label.visible = false
	if game._world_flash != null:
		game._world_flash.visible = false
	game._world_flash_left = 0.0
	game._paused = false
	game.elapsed = 2.0
	game.invuln = 9.0
	game._player.form_id = FormCatalog.Id.SLIME
	game._player.alive = true
	game._player.invulnerable = true
	game._player.position = Vector2(92, 132)
	game._player.aim = game._player.position
	game._clear_field()
	var slug := str(spec["slug"])
	game._spawn_boss({
		"slug": slug,
		"generation": 0,
		"hold_x": BossCatalog.rest_x(slug),
		"origin_y": 128.0,
		"phase": 0.6,
		"wave_amp": 12.0,
	}, Vector2(480, 270))
	var boss: BossActor = game._living_boss()
	boss.hp = int(spec["hp"])
	boss.max_hp = BossCatalog.max_hp(slug, 0)
	boss.present(str(spec["attack"]), game._player.position)
	for shot_spec in FormCatalog.player_shots(FormCatalog.Id.SLIME, game._player.position, 0):
		shot_spec["position"] = game._player.position + Vector2(28, 0)
		game._spawn_shot(shot_spec, true)
	game._refresh_hud()
	game._player.queue_redraw()
	if game._boss_banner != null:
		game._boss_banner.queue_redraw()
