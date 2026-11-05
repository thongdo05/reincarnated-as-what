extends RefCounted
class_name DailyRun

## Shared daily seed. UTC, so every player is on the same date at the same moment.
## user:// is the in-memory file for this visit. Godot copies it to IndexedDB on
## a later frame, and that copy is async. iOS Safari often freezes the page
## (iMessage, a share sheet, a killed tab) before the copy lands, so the next
## visit reads run 0. localStorage is written in the same call. An in-memory
## counter covers a visit where both writes fail. The index handed out is the
## max of the saved value and that counter, so a file that stuck plays the
## same order. Clearing site data and reloading still starts at run 0.

const SAVE_PATH := "user://daily_run.json"
## date and next_run are the place in today's order, not a score.
## A bump of BestScores.SCORE_EPOCH drops any other field in this file.
const _RUN_KEYS: Array[String] = ["date", "next_run", "epoch"]
const _MIRROR_KEY := "reincarnated.daily_run"

static var _memory_date := ""
static var _memory_next := 0

static func date_seed() -> int:
	var date := Time.get_date_dict_from_system(true)
	return int(date["year"]) * 10000 + int(date["month"]) * 100 + int(date["day"])

static func peek_run_index() -> int:
	return int(_read().get("next_run", 0))

static func consume_run_index() -> int:
	var today := str(date_seed())
	if _memory_date != today:
		_memory_date = today
		_memory_next = 0
	var saved := int(_read().get("next_run", 0))
	var index := maxi(saved, _memory_next)
	_memory_next = index + 1
	_write(index + 1)
	return index

## Test hook. The exported game never calls this.
static func reset_session_for_test() -> void:
	_memory_date = ""
	_memory_next = 0

static func _read() -> Dictionary:
	var today := str(date_seed())
	var saved := maxi(_read_file(today), _read_mirror(today))
	return {"date": today, "next_run": saved}

static func _read_file(today: String) -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return 0
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var data: Dictionary = parsed
	if str(data.get("date", "")) != today:
		return 0
	var index := int(data.get("next_run", 0))
	if int(data.get("epoch", 0)) < BestScores.SCORE_EPOCH and _has_score_fields(data):
		_write_file(index)
	return index

static func _has_score_fields(data: Dictionary) -> bool:
	for key in data.keys():
		if not _RUN_KEYS.has(str(key)):
			return true
	return false

static func _write(next_run: int) -> void:
	_write_file(next_run)
	_write_mirror(next_run)

static func _write_file(next_run: int) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the daily run index.")
		return
	file.store_string(JSON.stringify({
		"date": str(date_seed()),
		"next_run": next_run,
		"epoch": BestScores.SCORE_EPOCH,
	}))
	file.close()

static func _read_mirror(today: String) -> int:
	if not OS.has_feature("web"):
		return 0
	var raw: Variant = JavaScriptBridge.eval(
		"(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % _MIRROR_KEY,
		true
	)
	if raw == null or str(raw).is_empty():
		return 0
	var parsed: Variant = JSON.parse_string(str(raw))
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var data: Dictionary = parsed
	if str(data.get("date", "")) != today:
		return 0
	return maxi(int(data.get("next_run", 0)), 0)

static func _write_mirror(next_run: int) -> void:
	if not OS.has_feature("web"):
		return
	var payload := JSON.stringify({
		"date": str(date_seed()),
		"next_run": next_run,
	})
	JavaScriptBridge.eval(
		"try{localStorage.setItem('%s',%s)}catch(e){}" % [_MIRROR_KEY, JSON.stringify(payload)],
		true
	)
