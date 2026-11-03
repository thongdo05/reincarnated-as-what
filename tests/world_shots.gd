extends SceneTree

## Gameplay frames for the random worlds.
## xvfb-run godot --path . -s res://tests/world_shots.gd

var _worlds: PackedStringArray = ["neon_tokyo", "underworld", "sunken_ruins", "sky_castle"]
var _index := 0
var _phase := 0
var _frames := 0
var _game: Node
var _wolf: EnemyActor
var _bolted := false

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/worlds")
	Replay.mark_seen()

func _process(_delta: float) -> bool:
	if _phase == 0:
		var packed: PackedScene = load("res://scenes/main.tscn")
		_game = packed.instantiate()
		_game.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(_game)
		var world_id := _worlds[_index]
		_game._background.apply_world(world_id)
		_game._sync_world_flash()
		_frames = 0
		_wolf = null
		_bolted = false
		_phase = 1
		return false
	var step := 1.0 / 60.0
	_game._process(step)
	_frames += 1
	if int(_game.phase) == _game.PHASE_PLAY and not _bolted:
		_bolted = true
		_game._spawn_shot({
			"position": Vector2(300, 108),
			"velocity": Vector2(-110, 18),
			"sprite": "floating_eye_bolt.png",
			"damage": 1,
			"radius": 4.0,
			"killer_name": "Floating Eye",
		}, false)
	var traveled := false
	if _game._player != null:
		for shot in _game._shots:
			if shot.from_player and shot.position.x > _game._player.position.x + 36.0:
				traveled = true
	if int(_game.phase) != _game.PHASE_PLAY or not traveled or _game._world_flash == null or not _game._world_flash.visible:
		if _frames > 220:
			push_error("timed out waiting for %s (phase %s shots %d flash %s)" % [
				_worlds[_index],
				_game.phase,
				_game._shots.size(),
				_game._world_flash.visible if _game._world_flash != null else false,
			])
			quit(1)
			return true
		return false
	if _worlds[_index] == "underworld" and _wolf == null:
		var spawned: bool = _game._spawn_enemy({
			"t": 0.0,
			"kind": SpawnDirector.WOLF,
			"x_ratio": 0.62,
			"phase": 0.4,
			"stop_ratio": 0.3,
			"y_bias": 0.0,
			"wave_amp": 0.0,
			"hold_fire": true,
		}, Vector2(480, 270))
		if spawned and not _game._enemies.is_empty():
			_wolf = _game._enemies[_game._enemies.size() - 1]
			var anchor := ArtLibrary.anchor("dire_wolf.png")
			var size: Array = ArtLibrary.entry("dire_wolf.png")["size"]
			var feet := _wolf.position.y + float(size[1]) - 1.0 - anchor.y
			_wolf.position.x = 390.0
			print("WOLF_CHECK pos=%s anchor=%s feet_y=%.1f ground=%.1f max_body_y=%.1f" % [
				_wolf.position,
				anchor,
				feet,
				FieldBackground.GROUND_FEET,
				270.0 - 78.0,
			])
			_wolf.queue_redraw()
			_game._process(step)
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image")
		quit(1)
		return true
	var path := "/opt/cursor/artifacts/worlds/%s.png" % _worlds[_index]
	if image.save_png(path) != OK:
		push_error("save failed %s" % path)
		quit(1)
		return true
	print("WROTE %s phase=%s shots=%d flash=%s world=%s" % [
		path,
		_game.phase,
		_game._shots.size(),
		_game._world_flash.text,
		_game._background.world_id,
	])
	_index += 1
	if _index >= _worlds.size():
		print("WORLD_SHOTS_OK")
		quit(0)
		return true
	_game.queue_free()
	_game = null
	_phase = 0
	return false
