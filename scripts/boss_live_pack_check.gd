extends SceneTree

## Real main scene from a release pack, past the first boss.
## godot --headless --main-pack build/web/index.pck -s res://scripts/boss_live_pack_check.gd

var _game: Node
var _ready_frames := 0
var _started := false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("main scene missing from the pack")
		quit(1)
		return
	_game = packed.instantiate()
	root.add_child(_game)

func _process(_delta: float) -> bool:
	if not _started:
		_ready_frames += 1
		if _ready_frames < 2:
			return false
		_started = true
	var step := 1.0 / 60.0
	_game.invuln = 60.0
	if _game._player != null:
		_game._player.invulnerable = true
	_game._process(step)
	if int(_game.phase) != _game.PHASE_PLAY and _game.elapsed > 2.0:
		push_error("packed run left play at %.1f" % _game.elapsed)
		quit(1)
		return true
	var boss: EnemyActor = _game._living_boss()
	if boss != null and boss.visible and boss.position.x > 16.0 and boss.position.x < 470.0 and _game.elapsed > 45.0:
		print("PACK_BOSS %s pos=%s elapsed=%.2f" % [boss.boss_slug, boss.position, _game.elapsed])
		print("PACK_BOSS_OK")
		quit(0)
		return true
	if _game.elapsed > 55.0:
		push_error("packed run reached %.1f with no boss on screen" % _game.elapsed)
		quit(1)
		return true
	return false
