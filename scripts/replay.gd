extends RefCounted
class_name Replay

## Default-mode replay pass. Flappy and hop do not read this.
## The first run of a page load keeps the full title card. A retry in that
## same visit flashes the next form. The very first run on a device is a
## short wordless lesson; the flag lives in user:// with the other saves.

const CARD_GUARD := 0.25
const FLASH_REVEAL := 0.48
const TUTORIAL_SECONDS := 10.0
const JUICE_SHAKE_PX := 2.0
const JUICE_SHAKE_REDUCED := 1.0
const JUICE_SHAKE_SECONDS := 0.12
const BULLET_Z := 20
const BULLET_Z_FLAPPY := 6
const SEEN_PATH := "user://tutorial_seen.json"
const PAGE := "https://thongdo05.github.io/reincarnated-as-what/"

static var _motion_known := false
static var _motion := false
static var _force_motion := -1

static func bullet_z(flappy: bool) -> int:
	if flappy:
		return BULLET_Z_FLAPPY
	return BULLET_Z

static func shake_cap() -> float:
	if reduced_motion():
		return JUICE_SHAKE_REDUCED
	return JUICE_SHAKE_PX

static func reduced_motion() -> bool:
	if _force_motion >= 0:
		return _force_motion == 1
	if _motion_known:
		return _motion
	_motion_known = true
	_motion = false
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval("!!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches)", true)
		_motion = bool(value)
	return _motion

## Test hook. -1 follows the platform, 0 is full juice, 1 is the reduced cap.
static func force_reduced_motion_for_test(mode: int) -> void:
	_force_motion = mode
	_motion_known = false

static func seen() -> bool:
	if not FileAccess.file_exists(SEEN_PATH):
		return false
	var file := FileAccess.open(SEEN_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	return bool((parsed as Dictionary).get("seen", false))

static func mark_seen() -> void:
	var file := FileAccess.open(SEEN_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"seen": true}))
	file.close()

static func reset_seen_for_test() -> void:
	if FileAccess.file_exists(SEEN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SEEN_PATH))

## The pixel font has no emoji, so the share line uses a text mark.
## Phones still get the words, and a later form is never named.
static func form_mark(form_id: int) -> String:
	match form_id:
		FormCatalog.Id.GOBLIN:
			return "(G)"
		FormCatalog.Id.SLIME:
			return "(S)"
		FormCatalog.Id.VENDING:
			return "(V)"
		FormCatalog.Id.CAT:
			return "(C)"
		FormCatalog.Id.DEMON:
			return "(D)"
		_:
			return "(?)"

static func form_key(form_id: int) -> String:
	var key := FormCatalog.key_for(form_id)
	if key == "slime" and form_id != FormCatalog.Id.SLIME:
		return ""
	return key

## Wordle-style line for this run only. No later form in the daily order.
static func daily_text(seed_value: int, form_id: int, score: int, rank_name: String) -> String:
	return "Reincarnated as WHAT?!\n%s\n%s %s\nScore %s\nRank %s" % [
		format_seed_date(seed_value),
		form_mark(form_id),
		FormCatalog.display_name(form_id),
		ScoreRules.format_score(score),
		rank_name.to_upper(),
	]

## Same seed and form. Any of the five playable forms stays on the link.
## An unknown key drops the form so the friend gets that day's normal run.
static func beat_url(seed_value: int, form_key: String) -> String:
	var base := "%s?seed=%d" % [PAGE, seed_value]
	var key := form_key.strip_edges().to_lower()
	if FormCatalog.id_from_key(key) < 0:
		return base
	return "%s&form=%s" % [base, key]

static func beat_url_for(seed_value: int, form_id: int) -> String:
	return beat_url(seed_value, form_key(form_id))

static func format_seed_date(seed_value: int) -> String:
	var year := int(seed_value / 10000)
	var month := int(seed_value / 100) % 100
	var day := int(seed_value) % 100
	if year < 2000 or month < 1 or month > 12 or day < 1 or day > 31:
		return str(seed_value)
	return "%04d-%02d-%02d" % [year, month, day]


class Finger extends Node2D:
	var age := 0.0

	func advance(delta: float) -> void:
		age += delta
		queue_redraw()

	func _draw() -> void:
		var loop := 0.9
		var t := fmod(age, loop) / loop
		var pos := Vector2(round(lerpf(0.0, 10.0, t)), round(lerpf(0.0, 16.0, t)))
		var alpha := 0.55 + 0.4 * sin(t * PI)
		# Dark body, light edge, so it reads on the pastel sky. A short trail shows the drag.
		var edge := Color(0.95, 0.97, 1.0, alpha)
		var ink := Color(0.08, 0.07, 0.12, alpha)
		for i in 3:
			var back := pos - Vector2(round(lerpf(4.0, 0.0, float(i) / 2.0)), round(lerpf(6.0, 0.0, float(i) / 2.0)))
			draw_rect(Rect2(back, Vector2(2, 2)), Color(edge.r, edge.g, edge.b, alpha * 0.45))
		draw_rect(Rect2(pos + Vector2(-1, -1), Vector2(7, 9)), edge)
		draw_rect(Rect2(pos, Vector2(5, 7)), ink)
		draw_rect(Rect2(pos + Vector2(1, -3), Vector2(3, 3)), edge)
		draw_rect(Rect2(pos + Vector2(2, -2), Vector2(1, 2)), ink)
