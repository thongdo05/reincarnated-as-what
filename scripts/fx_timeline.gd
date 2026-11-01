extends RefCounted
class_name FxTimeline

## 12 fps, no loop. Death is 11 frames (0.92 s) then a 1 s tease.
## Evolve is 8 frames (0.67 s) then the last pop frame holds for 1 s.

const FPS := 12.0
const DEATH_FRAMES := 11
const TEASE_SECONDS := 1.0
const EVOLVE_FRAMES := 8
const EVOLVE_HOLD := 1.0

static func _frame(t: float) -> int:
	return int(floor(t * FPS + 0.0001))

static func death_stage(t: float) -> String:
	if t < 0.0:
		return "none"
	var frame := _frame(t)
	if frame <= 1:
		return "hit"
	if frame <= 4:
		return "pop"
	if frame <= 8:
		return "puff"
	if frame <= 10:
		return "hold"
	if t < float(DEATH_FRAMES) / FPS + TEASE_SECONDS - 0.0001:
		return "tease"
	return "card"

static func pop_file(box: Vector2) -> String:
	if maxf(box.x, box.y) > 32.0:
		return "fx/fx_death_pop_l.png"
	return "fx/fx_death_pop_s.png"

## Goblins are crowned at every rank. Every rank-3 form is crowned,
## including Cat r3 and Demon Lord r3.
static func wears_crown(sprite_name: String) -> bool:
	var stem := sprite_name.get_file().trim_suffix(".png")
	if stem.begins_with("goblin"):
		return true
	return stem.ends_with("_r3")

static func flash_file(sprite_name: String) -> String:
	return "fx/forms/%s_flash.png" % sprite_name.get_file().trim_suffix(".png")

static func rim_file(sprite_name: String) -> String:
	return "fx/forms/%s_rim.png" % sprite_name.get_file().trim_suffix(".png")

static func evolve_stage(t: float) -> String:
	if t < 0.0:
		return "none"
	var frame := _frame(t)
	if frame <= 2:
		return "glow"
	if frame <= 4:
		return "flash"
	if t < float(EVOLVE_FRAMES) / FPS + EVOLVE_HOLD - 0.0001:
		return "pop"
	return "done"

static func evolve_shows_rim(t: float) -> bool:
	var frame := _frame(t)
	return frame == 0 or frame == 2
