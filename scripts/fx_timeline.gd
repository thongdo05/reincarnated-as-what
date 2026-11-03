extends RefCounted
class_name FxTimeline

## 12 fps, no loop. Death is 11 frames (0.92 s) then a 1 s tease.
## Evolve is 8 frames (0.67 s) then the last pop frame holds for 1 s.

const FPS := 12.0
const DEATH_FRAMES := 11
const TEASE_SECONDS := 1.0
const EVOLVE_FRAMES := 8
const EVOLVE_HOLD := 1.0
const EVOLVE_HOLD_FINAL := 1.85

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

## The readability ring adds 2 px. 36 keeps slime r3 (art box 34), the batch-6
## slime r4 box (35), cat r3, and the new small vending r1 on the small pop.
## Goblin r2 (37) and the big bodies stay on the large pop.
const POP_LARGE_ABOVE := 36.0

static func pop_file(box: Vector2) -> String:
	if maxf(box.x, box.y) > POP_LARGE_ABOVE:
		return "fx/fx_death_pop_l.png"
	return "fx/fx_death_pop_s.png"

## Goblins are crowned at every rank. Rank 3 and above wear a crown,
## including the batch-6 body files (`slime_r4_body`, `demon_lord_r5_body`).
static func wears_crown(sprite_name: String) -> bool:
	var stem := sprite_name.get_file().trim_suffix(".png")
	if stem.begins_with("goblin"):
		return true
	return rank_number(stem) >= 3

static func rank_number(stem: String) -> int:
	var at := stem.rfind("_r")
	if at < 0:
		return 0
	var digits := ""
	var rest := stem.substr(at + 2)
	for i in rest.length():
		var ch := rest.substr(i, 1)
		if ch < "0" or ch > "9":
			break
		digits += ch
	if digits.is_empty():
		return 0
	return int(digits)

static func flash_file(sprite_name: String) -> String:
	return "fx/forms/%s_flash.png" % sprite_name.get_file().trim_suffix(".png")

static func rim_file(sprite_name: String) -> String:
	return "fx/forms/%s_rim.png" % sprite_name.get_file().trim_suffix(".png")

static func evolve_stage(t: float, hold: float = EVOLVE_HOLD) -> String:
	if t < 0.0:
		return "none"
	var frame := _frame(t)
	if frame <= 2:
		return "glow"
	if frame <= 4:
		return "flash"
	if t < float(EVOLVE_FRAMES) / FPS + hold - 0.0001:
		return "pop"
	return "done"

static func evolve_shows_rim(t: float) -> bool:
	var frame := _frame(t)
	return frame == 0 or frame == 2
