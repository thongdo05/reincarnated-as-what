extends RefCounted
class_name FormCatalog

## Launch roster entries that exist in this prototype.
## Slime and Goblin are tuned to the same close-range hit rate.
## Slime pays for reliable column fire with a big body and a long slide.
## Goblin pays for a small body with arcing stones that only fully connect up close,
## plus a stride that plants his feet for a moment each step.

enum Id { SLIME, GOBLIN }

const IDS: Array[int] = [Id.SLIME, Id.GOBLIN]

const SLIME_FIRE_INTERVAL := 0.16
const SLIME_SHOT_SPEED := 700.0
const SLIME_ACCEL := 1550.0
const SLIME_MAX_SPEED := 430.0
const SLIME_ARRIVE := 4.8
const SLIME_HIT_RADIUS := 17.0

const GOBLIN_FIRE_INTERVAL := 0.48
const GOBLIN_SHOT_SPEED := 780.0
const GOBLIN_GRAVITY := 170.0
const GOBLIN_SPREAD := 110.0
const GOBLIN_ACCEL := 3800.0
const GOBLIN_MAX_SPEED := 560.0
const GOBLIN_ARRIVE := 11.0
const GOBLIN_STRIDE := 0.32
const GOBLIN_SPRINT_FRACTION := 0.70
const GOBLIN_PLANT_SPEED_SCALE := 0.16
const GOBLIN_HIT_RADIUS := 11.0

static func display_name(id: int) -> String:
	match id:
		Id.SLIME:
			return "SLIME"
		Id.GOBLIN:
			return "GOBLIN"
		_:
			return "UNKNOWN"

static func gag(id: int) -> String:
	match id:
		Id.SLIME:
			return "You leave a trail. Mostly of yourself."
		Id.GOBLIN:
			return "The crown is heavy. The plan is not."
		_:
			return ""

static func title_color(id: int) -> Color:
	if id == Id.SLIME:
		return Color("9dff7a")
	return Color("ffd56a")

static func hit_radius(id: int) -> float:
	if id == Id.SLIME:
		return SLIME_HIT_RADIUS
	return GOBLIN_HIT_RADIUS

static func max_speed(id: int) -> float:
	if id == Id.SLIME:
		return SLIME_MAX_SPEED
	return GOBLIN_MAX_SPEED

static func fire_interval(id: int) -> float:
	if id == Id.SLIME:
		return SLIME_FIRE_INTERVAL
	return GOBLIN_FIRE_INTERVAL

## Daily order: shuffle the roster once with the UTC date seed, then cycle.
## Run 0 and run 1 are the two forms in that day's order. Run 2 repeats run 0.
static func id_for_run(day_seed: int, run_index: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed
	var forms: Array[int] = []
	forms.assign(IDS)
	for i in range(forms.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := forms[i]
		forms[i] = forms[j]
		forms[j] = swap
	var index := run_index % forms.size()
	if index < 0:
		index += forms.size()
	return forms[index]

static func player_shots(id: int, origin: Vector2) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	if id == Id.SLIME:
		shots.append(_blob(origin + Vector2(0, -18), Vector2(0, -SLIME_SHOT_SPEED), 5.0, 1, Color("d6ff6a")))
	else:
		for vx in [-GOBLIN_SPREAD, 0.0, GOBLIN_SPREAD]:
			var stone := _blob(origin + Vector2(0, -14), Vector2(vx, -GOBLIN_SHOT_SPEED), 4.5, 0, Color("f0c36a"))
			stone["gravity"] = GOBLIN_GRAVITY
			stone["style"] = "stone"
			shots.append(stone)
	return shots

static func split_shots(velocity: Vector2, origin: Vector2) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	var base := velocity
	if base.length() < 1.0:
		base = Vector2(0, -SLIME_SHOT_SPEED)
	for angle in [-0.62, 0.62]:
		var spec := _blob(origin + base.normalized() * 10.0, base.rotated(angle) * 0.92, 4.0, 0, Color("efffb0"))
		shots.append(spec)
	return shots

static func _blob(pos: Vector2, velocity: Vector2, radius: float, splits: int, color: Color) -> Dictionary:
	return {
		"position": pos,
		"velocity": velocity,
		"gravity": 0.0,
		"damage": 1,
		"radius": radius,
		"splits": splits,
		"color": color,
		"style": "blob",
		"killer_name": "",
	}
