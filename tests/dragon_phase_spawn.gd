extends SceneTree

## godot --headless --path . -s res://tests/dragon_phase_spawn.gd

var _checker = null
var _started := false

func _initialize() -> void:
	_checker = load("res://tests/dragon_phase_checks.gd").new()
	var failed: int = _checker.run()
	if failed > 0:
		push_error("%d dragon phase checks failed" % failed)
		quit(1)

func _process(_delta: float) -> bool:
	if _started:
		return true
	_started = true
	var failed: int = _checker.run_live(self)
	if failed > 0:
		push_error("%d dragon phase checks failed" % failed)
		quit(1)
		return true
	print("DRAGON_PHASE_SPAWN_OK")
	quit(0)
	return true
