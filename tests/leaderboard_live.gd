extends SceneTree

## Posts one clearly marked test row, checks the board, rename, and a harsh
## name the server still rejects. Does not delete anything.
## godot --headless --path . -s res://tests/leaderboard_live.gd

var _lb: Leaderboard
var _step := 0
var _wait := 0.0
var _device := ""
var _failed := false

func _initialize() -> void:
	var path := Leaderboard.PROFILE_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_lb = Leaderboard.new()
	root.add_child(_lb)
	_lb.set_local_name("TEST")
	_device = _lb.device_id()
	print("TEST_DEVICE %s" % _device)

func _process(delta: float) -> bool:
	if _wait > 0.0:
		_wait -= delta
		return false
	match _step:
		0:
			_step = 100
			_lb.submit_score("slime", 4242, 30000, _on_submit)
		1:
			_step = 100
			_lb.set_remote_name("TESTTWO", _on_rename)
		2:
			_step = 100
			_lb.set_remote_name("Fuuuck", _on_reject)
		3:
			_step = 100
			_lb.fetch_rank("slime", "all", _on_still_testtwo)
		4:
			_step = 100
			_wait = 0.0
			_lb.set_remote_name("TEST", _on_restore)
		5:
			_step = 100
			_lb.fetch_rank("", "all", _on_overall)
		6:
			_step = 100
			_lb.fetch_rank("slime", "daily", _on_daily)
		7:
			_step = 100
			_lb.fetch_board("slime", "daily", _on_board)
		_:
			return false
	return false

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	print("LIVE_FAIL %s" % message)
	print("CLEANUP device_id=%s name=TEST form=slime score=4242 (and any rename of that same device)" % _device)
	quit(1)

func _pause(next: int) -> void:
	_step = next
	_wait = 3.3

func _on_submit(parsed: Dictionary) -> void:
	print("SUBMIT %s" % JSON.stringify(parsed.get("data", parsed)))
	if not bool(parsed.get("ok", false)):
		_fail("submit failed: %s" % JSON.stringify(parsed))
		return
	var data: Dictionary = parsed.get("data", {})
	if str(data.get("name", "")) != "TEST" or str(data.get("form", "")) != "slime":
		_fail("submit echo was %s" % JSON.stringify(data))
		return
	if int(data.get("best_all", 0)) != 4242 or int(data.get("best_daily", 0)) != 4242:
		_fail("expected best 4242, got %s" % JSON.stringify(data))
		return
	print("ROW device_id=%s name=TEST form=slime score=4242 day=%s best_all=4242 best_daily=4242" % [_device, str(data.get("day", ""))])
	_pause(1)

func _on_rename(parsed: Dictionary) -> void:
	print("RENAME %s" % JSON.stringify(parsed.get("data", parsed)))
	if not bool(parsed.get("ok", false)) or str(parsed.get("data", {}).get("name", "")) != "TESTTWO":
		_fail("rename to TESTTWO failed: %s" % JSON.stringify(parsed))
		return
	_pause(2)

func _on_reject(parsed: Dictionary) -> void:
	print("REJECT %s" % JSON.stringify(parsed.get("data", parsed)))
	if bool(parsed.get("ok", false)) or str(parsed.get("error", "")) != "name_not_allowed":
		_fail("Fuuuck should be rejected, got %s" % JSON.stringify(parsed))
		return
	_step = 3

func _on_still_testtwo(parsed: Dictionary) -> void:
	var rows: Array = parsed.get("rows", [])
	if rows.is_empty() or str(rows[0].get("name", "")) != "TESTTWO":
		_fail("rejected name should not replace TESTTWO, got %s" % JSON.stringify(parsed))
		return
	_pause(4)

func _on_restore(parsed: Dictionary) -> void:
	print("RESTORE %s" % JSON.stringify(parsed.get("data", parsed)))
	if not bool(parsed.get("ok", false)) or str(parsed.get("data", {}).get("name", "")) != "TEST":
		_fail("could not put the name back to TEST: %s" % JSON.stringify(parsed))
		return
	_step = 5

func _on_overall(parsed: Dictionary) -> void:
	print("OVERALL %s" % JSON.stringify(parsed.get("rows", [])))
	var rows: Array = parsed.get("rows", [])
	if rows.is_empty() or str(rows[0].get("name", "")) != "TEST" or int(rows[0].get("score", 0)) != 4242:
		_fail("overall rank missing TEST 4242: %s" % JSON.stringify(rows))
		return
	_step = 6

func _on_daily(parsed: Dictionary) -> void:
	print("DAILY %s" % JSON.stringify(parsed.get("rows", [])))
	var rows: Array = parsed.get("rows", [])
	if rows.is_empty() or int(rows[0].get("rank", 0)) <= 0:
		_fail("daily rank missing: %s" % JSON.stringify(rows))
		return
	_step = 7

func _on_board(parsed: Dictionary) -> void:
	var rows: Array = parsed.get("rows", [])
	var mine := false
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and bool((row as Dictionary).get("is_me", false)):
			mine = str(row.get("name", "")) == "TEST" and int(row.get("score", 0)) == 4242
			print("BOARD_ME %s" % JSON.stringify(row))
	if not mine:
		_fail("slime daily board did not mark this device: %s" % JSON.stringify(rows))
		return
	print("LIVE_OK")
	print("CLEANUP device_id=%s name=TEST form=slime score=4242 day=today best_all and best_daily" % _device)
	quit(0)
