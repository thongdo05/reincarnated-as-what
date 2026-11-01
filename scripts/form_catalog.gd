extends RefCounted
class_name FormCatalog

## Launch roster entries that exist in this prototype.
## The Slime split is that form's trait. It is not an extra life. One life per run still holds.
## Vending Machine, Cat, and Demon Lord art is in res://art/ and is not played yet.
## Vending Machine's weapon has no random WINNER! burst. WINNER! is only the meter clear.
## Slime and Goblin are tuned to the same close-range hit rate.
## Slime pays for a reliable forward stream with a big body and a long slide.
## Goblin pays for a small body with stones that lob forward and only fully connect up close,
## plus a stride that plants his feet for a moment each step.

enum Id { SLIME, GOBLIN }

const IDS: Array[int] = [Id.SLIME, Id.GOBLIN]

const SLIME_FIRE_INTERVAL := 0.16
const SLIME_SHOT_SPEED := 700.0
const SLIME_ACCEL := 1550.0
const SLIME_MAX_SPEED := 430.0
const SLIME_ARRIVE := 4.8

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

## Cumulative skill points to reach rank 1, then rank 2. Rank 0 is the start.
## Placeholder. Tune these two numbers.
const RANK_GATES: Array[int] = [500, 1500]

## A Goblin pickup. Added to the score and to the evolution meter. Not a weapon upgrade.
const LOOT_POINTS := 40

## Kept so older shot-size checks can still name the previous circle fraction.
## Live shots use the shapes in res://art/hitboxes.json.
const SHOT_PCT := 0.62

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

## Full-screen 480x270 card shown before the run. Files live in res://art/title_cards/.
static func title_card(id: int) -> String:
	match id:
		Id.SLIME:
			return "title_cards/title_slime.png"
		Id.GOBLIN:
			return "title_cards/title_goblin.png"
		_:
			return "title_cards/title_slime.png"

static func title_color(id: int) -> Color:
	if id == Id.SLIME:
		return Color("8ecbff")
	return Color("ffd56a")

static func hit_radius(id: int) -> float:
	return hit_radius_for(id, 0, false)

static func _sprite_file(id: int, rank_index: int, small: bool) -> String:
	var spec := rank_spec(id, rank_index)
	if small and id == Id.SLIME:
		return str(spec["sprite_small"])
	return str(spec["sprite"])

## Movement pad: far enough that the core, which can sit off the anchor, stays in frame.
static func hit_radius_for(id: int, rank_index: int, small: bool) -> float:
	return HitLibrary.bounds_radius(_sprite_file(id, rank_index, small), "hurt")

## Radius of the core itself. This is the hurt target, not the distance from the anchor.
static func core_radius(id: int, rank_index: int, small: bool) -> float:
	return HitLibrary.max_part_radius(_sprite_file(id, rank_index, small), "hurt")

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

## Three ranks per form. Hurt, body, and threat shapes live in res://art/hitboxes.json.
static func rank_table(id: int) -> Array[Dictionary]:
	if id == Id.SLIME:
		return [
			{
				"name": "Slime",
				"sprite": "slime_r1.png",
				"sprite_small": "slime_small_r1.png",
				"fire_interval": SLIME_FIRE_INTERVAL,
				"shot_sprite": "slime_shot.png",
				"shot_color": Color("7ec8ff"),
				"lanes": [0.0],
				"spread": [],
			},
			{
				"name": "Gel Knight",
				"sprite": "slime_r2.png",
				"sprite_small": "slime_small_r2.png",
				"fire_interval": 0.13,
				"shot_sprite": "slime_shot.png",
				"shot_color": Color("b7e4ff"),
				"lanes": [-12.0, 12.0],
				"spread": [],
			},
			{
				"name": "Ooze Titan",
				"sprite": "slime_r3.png",
				"sprite_small": "slime_small_r3.png",
				"fire_interval": 0.10,
				"shot_sprite": "slime_shot.png",
				"shot_color": Color("eaf7ff"),
				"lanes": [-16.0, 0.0, 16.0],
				"spread": [],
			},
		]
	return [
		{
			"name": "Goblin",
			"sprite": "goblin_r1.png",
			"fire_interval": GOBLIN_FIRE_INTERVAL,
			"shot_sprite": "slingshot_stone.png",
			"shot_color": Color("f0c36a"),
			"lanes": [],
			"spread": [-GOBLIN_SPREAD, 0.0, GOBLIN_SPREAD],
		},
		{
			"name": "Goblin Chief",
			"sprite": "goblin_r2.png",
			"fire_interval": 0.36,
			"shot_sprite": "slingshot_stone_l2.png",
			"shot_color": Color("ffe08a"),
			"lanes": [],
			"spread": [-150.0, -50.0, 50.0, 150.0],
		},
		{
			"name": "Goblin King",
			"sprite": "goblin_r3.png",
			"fire_interval": 0.28,
			"shot_sprite": "slingshot_stone_l3.png",
			"shot_color": Color("fff3c4"),
			"lanes": [],
			"spread": [-180.0, -90.0, 0.0, 90.0, 180.0],
		},
	]

static func rank_spec(id: int, rank_index: int) -> Dictionary:
	var table := rank_table(id)
	return table[clampi(rank_index, 0, table.size() - 1)]

static func rank_name(id: int, rank_index: int) -> String:
	return str(rank_spec(id, rank_index)["name"])

static func rank_for_points(points: int) -> int:
	var rank := 0
	for gate in RANK_GATES:
		if points >= gate:
			rank += 1
	return mini(rank, RANK_GATES.size())

static func gate_for_next_rank(rank_index: int) -> int:
	if rank_index < 0 or rank_index >= RANK_GATES.size():
		return -1
	return RANK_GATES[rank_index]

static func player_shots(id: int, origin: Vector2, rank_index: int = 0) -> Array[Dictionary]:
	var spec := rank_spec(id, rank_index)
	var shots: Array[Dictionary] = []
	var shot_sprite := str(spec["shot_sprite"])
	var shot_color: Color = spec["shot_color"]
	var muzzle := ArtLibrary.anchor(str(spec["sprite"])).x + 2.0
	if id == Id.SLIME:
		var lanes: Array = spec["lanes"]
		for lane in lanes:
			shots.append(_blob(origin + Vector2(muzzle, float(lane)), Vector2(SLIME_SHOT_SPEED, 0), 1, shot_color, shot_sprite))
	else:
		var spread: Array = spec["spread"]
		for vy in spread:
			var stone := _blob(origin + Vector2(muzzle, -2), Vector2(GOBLIN_SHOT_SPEED, float(vy)), 0, shot_color, shot_sprite)
			stone["gravity"] = GOBLIN_GRAVITY
			stone["style"] = "stone"
			shots.append(stone)
	return shots

static func split_shots(velocity: Vector2, origin: Vector2) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	var base := velocity
	if base.length() < 1.0:
		base = Vector2(SLIME_SHOT_SPEED, 0)
	for angle in [-0.62, 0.62]:
		var spec := _blob(origin + base.normalized() * 10.0, base.rotated(angle) * 0.92, 0, Color("d7f1ff"), "slime_shot.png")
		shots.append(spec)
	return shots

static func _blob(pos: Vector2, velocity: Vector2, splits: int, color: Color, sprite: String) -> Dictionary:
	return {
		"position": pos,
		"velocity": velocity,
		"gravity": 0.0,
		"damage": 1,
		"radius": HitLibrary.bounds_radius(sprite, "body"),
		"splits": splits,
		"color": color,
		"style": "blob",
		"sprite": sprite,
		"killer_name": "",
	}
