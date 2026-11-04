extends RefCounted
class_name BestScores

## Local bests only. One number per form, plus the best run of any form.
## Stored in user:// so the web build keeps them in the browser.
##
## Bump SCORE_EPOCH to wipe every local best once, on the next load.
## That bump is the whole reset. Epoch 2 is this build: the dragon lair
## and its audio. The saved name lives in the leaderboard profile, not here.

const SAVE_PATH := "user://best_scores.json"
const SCORE_EPOCH := 2

static func apply(data: Dictionary, form_name: String, score: int) -> Dictionary:
	var next := data.duplicate()
	# The epoch is the wipe generation, never a form's best.
	next.erase("epoch")
	if form_name != "epoch":
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
	var data: Dictionary = parsed
	if int(data.get("epoch", 0)) < SCORE_EPOCH:
		_write({"overall": 0, "epoch": SCORE_EPOCH})
		return {"overall": 0}
	return _without_epoch(data)

static func record(form_name: String, score: int) -> Dictionary:
	var saved := apply(read(), form_name, score)
	var stored := saved.duplicate()
	stored["epoch"] = SCORE_EPOCH
	_write(stored)
	return {
		"form": int(saved.get(form_name, 0)),
		"overall": int(saved.get("overall", 0)),
	}

## Form bests and "overall" only. Callers that list keys must not see "epoch".
static func _without_epoch(data: Dictionary) -> Dictionary:
	var scores := {}
	for key in data.keys():
		if str(key) == "epoch":
			continue
		scores[key] = data[key]
	if not scores.has("overall"):
		scores["overall"] = 0
	return scores

static func _write(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
