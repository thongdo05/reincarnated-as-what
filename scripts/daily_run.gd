extends RefCounted
class_name DailyRun

## Shared daily seed. UTC, so every player is on the same date at the same moment.
## The run index lives in user:// (IndexedDB on the web export). Clearing site data
## restarts that browser at run 0. The order itself does not change.

const SAVE_PATH := "user://daily_run.json"

static func date_seed() -> int:
	var date := Time.get_date_dict_from_system(true)
	return int(date["year"]) * 10000 + int(date["month"]) * 100 + int(date["day"])

static func peek_run_index() -> int:
	return int(_read().get("next_run", 0))

static func consume_run_index() -> int:
	var state := _read()
	var index := int(state.get("next_run", 0))
	_write(index + 1)
	return index

static func _read() -> Dictionary:
	var today := str(date_seed())
	if not FileAccess.file_exists(SAVE_PATH):
		return {"date": today, "next_run": 0}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {"date": today, "next_run": 0}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"date": today, "next_run": 0}
	var data: Dictionary = parsed
	if str(data.get("date", "")) != today:
		return {"date": today, "next_run": 0}
	return {"date": today, "next_run": int(data.get("next_run", 0))}

static func _write(next_run: int) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the daily run index.")
		return
	file.store_string(JSON.stringify({"date": str(date_seed()), "next_run": next_run}))
	file.close()
