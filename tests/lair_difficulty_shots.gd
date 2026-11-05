extends SceneTree

## Stills of the Elder breath and a Great Dragon fight with lair monsters.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/lair_difficulty_shots.gd

var _phase := 0
var _frames := 0
var _game: Node
var _field := Vector2(480, 270)

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
		_stage_breath()
		_frames = 0
		_phase = 2
		return false
	if _phase == 2:
		if _frames < 2:
			return false
		if not _save("elder_breath_after.png"):
			return true
		_stage_boss()
		_frames = 0
		_phase = 3
		return false
	if _frames < 2:
		return false
	if not _save("lair_boss_minions.png"):
		return true
	print("LAIR_DIFFICULTY_SHOTS_OK")
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
	game.elapsed = 40.0
	game.invuln = 0.0
	game._player.alive = true
	game._player.invulnerable = false
	game._player.visible = true
	game._player.position = Vector2(90, 140)
	game.form_id = FormCatalog.Id.DRAGON
	game._player.form_id = FormCatalog.Id.DRAGON
	game._player.adopt_dragon(1.0)
	game._clear_field()
	if game._background != null:
		game._background.apply_world(WorldCatalog.DRAGON_LAIR, false)
	if game._title_board_button != null:
		game._title_board_button.visible = false
	game.set_process(false)

func _stage_breath() -> void:
	_wipe()
	_game._player.position = Vector2(100, 148)
	_game._spawn_enemy({
		"dragon": true,
		"dragon_id": DragonPhase.ELDER,
		"kind": DragonPhase.ELDER,
		"hp_mul": 2.0,
		"x_ratio": 0.7,
		"phase": 0.3,
		"stop_ratio": 0.3,
		"wave_amp": 12.0,
		"y_bias": 0.0,
		"spawn_at": Vector2(400, 168),
	}, _field)
	var elder := _game._enemies[_game._enemies.size() - 1] as DragonEnemy
	elder.fire_room = -1
	elder.bullet_density = 1.0
	elder._attack_wait = 0.0
	var player: Vector2 = _game._player.position
	var waves := 0
	var guard := 0
	while guard < 500 and waves < DragonPhase.ELDER_WAVES:
		guard += 1
		var born := 0
		for spec in elder.tick(0.05, player, 1.0, 1.0):
			_game._spawn_shot(spec, false)
			if str(spec.get("sprite", "")) == DragonPhase.BREATH_PUFF:
				born += 1
		if born > 0:
			waves += 1
		for shot in _game._shots:
			if is_instance_valid(shot) and not shot.from_player:
				shot.tick(0.05)
	for shot in _game._shots:
		if is_instance_valid(shot) and not shot.from_player:
			shot.tick(0.95)
	elder.queue_redraw()
	_game._player.queue_redraw()

func _stage_boss() -> void:
	_wipe()
	_game._player.position = Vector2(78, 132)
	_game._spawn_boss({
		"slug": "great_dragon",
		"generation": 1,
		"hold_x": 404.0,
		"origin_y": 118.0,
		"phase": 0.4,
		"wave_amp": 10.0,
	}, _field)
	var boss := _game._living_boss() as BossActor
	boss.intro_left = 0.0
	boss.state = BossActor.HOLD
	boss.position = Vector2(404, 118)
	boss._attack_cd = 2.0
	boss._summon_cd = 80.0
	for _i in 4:
		boss.tick(0.05, _game._player.position, 80.0, 1.0)
	_place(DragonPhase.BAT, Vector2(250, 58))
	_place(DragonPhase.WHELP, Vector2(300, 108))
	_place(DragonPhase.KOBOLD, Vector2(210, 200))
	_place(DragonPhase.SLIME, Vector2(330, 206))
	_place(DragonPhase.RIDER, Vector2(168, 78))
	boss.queue_redraw()
	if _game._boss_banner != null:
		_game._boss_banner.queue_redraw()

func _place(id: int, at: Vector2) -> void:
	_game._spawn_enemy({
		"dragon": true,
		"dragon_id": id,
		"kind": id,
		"hp_mul": 2.0,
		"x_ratio": 0.6,
		"phase": 0.4,
		"stop_ratio": 0.3,
		"wave_amp": 8.0,
		"y_bias": 0.0,
		"spawn_at": at,
	}, _field)
	var enemy := _game._enemies[_game._enemies.size() - 1] as DragonEnemy
	enemy.fire_room = 0
	enemy.tick(0.05, _game._player.position, 1.0, 1.0)
	enemy.queue_redraw()

func _wipe() -> void:
	_game._clear_field()
	_game._player.position = Vector2(100, 148)
	_game._player.queue_redraw()
	if _game._background != null:
		_game._background.queue_redraw()

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
