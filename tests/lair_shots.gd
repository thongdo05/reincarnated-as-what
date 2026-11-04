extends SceneTree

## Stills: crack transition, the lair during the dragon phase, wraith and egg on it.
## xvfb-run godot --path . -s res://tests/lair_shots.gd

var _phase := 0
var _frames := 0
var _game: Node
var _field := Vector2(480, 270)

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")

func _process(_delta: float) -> bool:
	if _phase == 0:
		var packed: PackedScene = load("res://scenes/main.tscn")
		_game = packed.instantiate()
		_game.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(_game)
		_game.phase = _game.PHASE_PLAY
		_game.elapsed = 12.0
		_game.invuln = 30.0
		_game._player.invulnerable = true
		_game._player.alive = true
		_game._tutorial_active = false
		_game._boss_director.dragon_at = 100000.0
		_game._background.apply_world("neon_tokyo")
		if _game._reveal != null:
			_game._reveal.visible = false
		if _game._world_flash != null:
			_game._world_flash.visible = false
			_game._world_flash_left = 0.0
		if _game._hint_label != null:
			_game._hint_label.visible = false
		_frames = 0
		_phase = 1
		return false
	_frames += 1
	if _phase == 1:
		if _frames < 2:
			return false
		_game._begin_lair_transition()
		_step_until(0.78)
		_frames = 0
		_phase = 2
		return false
	if _phase == 2:
		if _frames < 3:
			_game._process(1.0 / 60.0)
			return false
		if not _save("lair_mid_transition.png"):
			return true
		_step_until(LairTransition.SWAP_AT + 0.15)
		_game.form_id = FormCatalog.Id.DRAGON
		_game._player.adopt_dragon(1.0)
		_game._player.position = Vector2(110, 150)
		_game._begin_dragon_phase()
		if _game._dragon_spawns != null:
			_game._dragon_spawns.arm_at(10000.0)
		_spawn(DragonPhase.BAT, Vector2(300, 120), 8)
		_game._player.queue_redraw()
		_frames = 0
		_phase = 3
		return false
	if _phase == 3:
		if _frames < 3:
			_game._process(1.0 / 60.0)
			return false
		if not _save("lair_dragon_phase.png"):
			return true
		_clear_enemies()
		var egg := _spawn(DragonPhase.EGG, Vector2(250, 200), 70)
		var wraith := _spawn(DragonPhase.WRAITH, Vector2(360, 110), 50)
		egg.queue_redraw()
		wraith.queue_redraw()
		_frames = 0
		_phase = 4
		return false
	if _phase == 4:
		if _frames < 3:
			_game._process(1.0 / 60.0)
			return false
		if not _save("lair_wraith_and_egg.png"):
			return true
		print("LAIR_SHOTS_OK")
		quit(0)
		return true
	return false

func _step_until(target: float) -> void:
	var guard := 0
	while _game._lair.elapsed < target and guard < 400:
		_game._process(1.0 / 60.0)
		guard += 1

func _spawn(id: int, at: Vector2, steps: int) -> DragonEnemy:
	_game._spawn_enemy({
		"dragon": true,
		"dragon_id": id,
		"kind": id,
		"hp_mul": 2.0,
		"x_ratio": 0.7,
		"phase": 0.2,
		"stop_ratio": 0.3,
		"wave_amp": 8.0,
		"y_bias": 0.0,
		"spawn_at": at,
	}, _field)
	var enemy := _game._enemies[_game._enemies.size() - 1] as DragonEnemy
	enemy.fire_room = 0
	for _i in steps:
		enemy.tick(0.05, _game._player.position, 1.0, 1.0)
	enemy.position = at
	enemy.queue_redraw()
	return enemy

func _clear_enemies() -> void:
	for enemy in _game._enemies:
		if is_instance_valid(enemy):
			enemy.alive = false
			enemy.visible = false

func _save(file_name: String) -> bool:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image for %s" % file_name)
		quit(1)
		return false
	var path := "/opt/cursor/artifacts/%s" % file_name
	if image.save_png(path) != OK:
		push_error("save failed %s" % path)
		quit(1)
		return false
	print("WROTE %s %dx%d world=%s phase=%s" % [
		path,
		image.get_width(),
		image.get_height(),
		_game._background.world_id,
		_game._lair.phase_name(),
	])
	return true
