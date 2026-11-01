extends RefCounted
class_name BestScores

## Local bests only. One number per form, plus the best run of any form.
## Stored in user:// so the web build keeps them in the browser.

const SAVE_PATH := "user://best_scores.json"

static func apply(data: Dictionary, form_name: String, score: int) -> Dictionary:
	var next := data.duplicate()
	next[form_name] = maxi(int(next.get(form_name, 0)), score)
	next["overall"] = maxi(int(next.get("overall", 0)), score)
	return next

static func read() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"overall": 0}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {"overall": 0}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"overall": 0}
	return parsed

static func record(form_name: String, score: int) -> Dictionary:
	var saved := apply(read(), form_name, score)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(saved))
		file.close()
	return {
		"form": int(saved.get(form_name, 0)),
		"overall": int(saved.get("overall", 0)),
	}
