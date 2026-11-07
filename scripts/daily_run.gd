extends RefCounted
class_name DailyRun

## Shared daily seed. UTC, so every player is on the same date at the same moment.
## The run index lives in user:// (IndexedDB on the web export). Clearing site data
## restarts that browser at run 0. The order itself does not change.

const SAVE_PATH := "user://daily_run.json"
## date and next_run are the place in today's order, not a score.
## A bump of BestScores.SCORE_EPOCH drops any other field in this file.
const _RUN_KEYS: Array[String] = ["date", "next_run", "epoch"]

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
	if CrazyGamesHost.cloud_handles():
		return _saved_run(CrazyGamesHost.cloud_get(CrazyGamesHost.CLOUD_DAILY), today)
	if not FileAccess.file_exists(SAVE_PATH):
		return {"date": today, "next_run": 0}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {"date": today, "next_run": 0}
	var parsed_text := file.get_as_text()
	file.close()
	return _saved_run(parsed_text, today)


static func _saved_run(text: String, today: String) -> Dictionary:
	if text.strip_edges() == "":
		return {"date": today, "next_run": 0}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"date": today, "next_run": 0}
	var data: Dictionary = parsed
	if str(data.get("date", "")) != today:
		return {"date": today, "next_run": 0}
	var index := int(data.get("next_run", 0))
	if int(data.get("epoch", 0)) < BestScores.SCORE_EPOCH and _has_score_fields(data):
		_write(index)
	return {"date": today, "next_run": index}

static func _has_score_fields(data: Dictionary) -> bool:
	for key in data.keys():
		if not _RUN_KEYS.has(str(key)):
			return true
	return false

static func _write(next_run: int) -> void:
	var body := JSON.stringify({
		"date": str(date_seed()),
		"next_run": next_run,
		"epoch": BestScores.SCORE_EPOCH,
	})
	if CrazyGamesHost.cloud_handles():
		CrazyGamesHost.cloud_set(CrazyGamesHost.CLOUD_DAILY, body)
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the daily run index.")
		return
	file.store_string(body)
	file.close()
