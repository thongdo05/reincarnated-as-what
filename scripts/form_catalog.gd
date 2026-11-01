extends RefCounted
class_name FormCatalog

## Launch roster entries that exist in this prototype.
## The Slime split is that form's trait. It is not an extra life. One life per run still holds.
## Vending Machine, Cat, and Demon Lord art is in res://art/ and is not played yet.
## The vending machine title card is already mapped to its reveal sting. It stays
## silent until that form is added to IDS. Goblin shots stay silent too.
## Vending Machine's weapon has no random WINNER! burst. WINNER! is only the meter clear.
## Slime pays for a reliable forward stream with a big body and a long slide.
## Goblin pays for a small body with stones that lob forward and only fully connect up close,
## plus a stride that plants his feet for a moment each step.
## Goblin's rocks hit harder than that stream because most of the arc misses.
## Every Goblin balance number lives in GOBLIN. Slime's numbers are unchanged.

enum Id { SLIME, GOBLIN }

const IDS: Array[int] = [Id.SLIME, Id.GOBLIN]

const SLIME_FIRE_INTERVAL := 0.16
const SLIME_SHOT_SPEED := 700.0
const SLIME_ACCEL := 1550.0
const SLIME_MAX_SPEED := 430.0
const SLIME_ARRIVE := 4.8

## Every Goblin balance number. Rank arrays are rank 1, rank 2, rank 3.
## Movement, stones, and loot all read this table.
## Before this pass: fire_interval [0.48, 0.36, 0.28], shot_speed 780, gravity 170,
## spread [±110], [±150, ±50], [±180, ±90, 0], damage 1, pierce 0,
## loot_points 40, loot_magnet 0, loot_magnet_speed 0.
## Movement (accel, max_speed, arrive, stride, sprint, plant) is unchanged.
## Loot points stay 40. A magnet was measured and left at 0: it inflated score
## past the bot band without being what closed the survival gap.
const GOBLIN := {
	"fire_interval": [0.30, 0.24, 0.20],
	"shot_speed": 780.0,
	"gravity": 170.0,
	"spread": [
		[-110.0, 0.0, 110.0],
		[-170.0, -56.0, 56.0, 170.0],
		[-200.0, -100.0, 0.0, 100.0, 200.0],
	],
	"damage": 2,
	"pierce": 1,
	"accel": 3800.0,
	"max_speed": 560.0,
	"arrive": 11.0,
	"stride": 0.32,
	"sprint_fraction": 0.70,
	"plant_speed_scale": 0.16,
	"loot_points": 40,
	"loot_magnet": 0.0,
	"loot_magnet_speed": 0.0,
}

## Kept so older shot-size checks can still name the previous circle fraction.
## Live shots use the shapes in res://art/hitboxes.json.
const SHOT_PCT := 0.62

## Pause-card sentences. A new form adds one entry. Weapon text is not copied
## here; weapon_line() builds it from the rank's real shot data.
const FORM_CARD := {
	Id.SLIME: {
		"trait": "Once per run, splits into a small slime instead of dying; regrows in 15s.",
		"ready": "Split ready.",
		"used": "Split used.",
	},
	Id.GOBLIN: {
		"trait": "Kills drop loot. Picking it up adds score and evolution points.",
		"ready": "",
		"used": "",
	},
}

## Cumulative skill points to reach rank 2, then rank 3. Rank 1 is the start.
## The numbers live in Difficulty so the bot and the meter share one pair.
static func rank_gates() -> Array[int]:
	return Difficulty.gates()

static func goblin_f(key: String) -> float:
	return float(GOBLIN[key])

static func goblin_rank_f(key: String, rank_index: int) -> float:
	var values: Array = GOBLIN[key]
	return float(values[clampi(rank_index, 0, values.size() - 1)])

static func goblin_spread(rank_index: int) -> Array:
	var rows: Array = GOBLIN["spread"]
	return (rows[clampi(rank_index, 0, rows.size() - 1)] as Array).duplicate()

## A Goblin pickup. Added to the score and to the evolution meter. Not a weapon upgrade.
static func loot_points() -> int:
	return int(GOBLIN["loot_points"])

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
	return goblin_f("max_speed")

static func fire_interval(id: int) -> float:
	if id == Id.SLIME:
		return SLIME_FIRE_INTERVAL
	return goblin_rank_f("fire_interval", 0)

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
	var names := ["Goblin", "Goblin Chief", "Goblin King"]
	var sprites := ["goblin_r1.png", "goblin_r2.png", "goblin_r3.png"]
	var stones := ["slingshot_stone.png", "slingshot_stone_l2.png", "slingshot_stone_l3.png"]
	var colors: Array[Color] = [Color("f0c36a"), Color("ffe08a"), Color("fff3c4")]
	var rows: Array[Dictionary] = []
	for i in names.size():
		rows.append({
			"name": names[i],
			"sprite": sprites[i],
			"fire_interval": goblin_rank_f("fire_interval", i),
			"shot_sprite": stones[i],
			"shot_color": colors[i],
			"lanes": [],
			"spread": goblin_spread(i),
		})
	return rows

static func rank_spec(id: int, rank_index: int) -> Dictionary:
	var table := rank_table(id)
	return table[clampi(rank_index, 0, table.size() - 1)]

static func rank_name(id: int, rank_index: int) -> String:
	return str(rank_spec(id, rank_index)["name"])

static func rank_for_points(points: int) -> int:
	var rank := 0
	var gates := rank_gates()
	for gate in gates:
		if points >= gate:
			rank += 1
	return mini(rank, gates.size())

static func gate_for_next_rank(rank_index: int) -> int:
	var gates := rank_gates()
	if rank_index < 0 or rank_index >= gates.size():
		return -1
	return gates[rank_index]

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
		var damage := int(goblin_f("damage"))
		var pierce := int(goblin_f("pierce"))
		for vy in spread:
			var stone := _blob(origin + Vector2(muzzle, -2), Vector2(goblin_f("shot_speed"), float(vy)), 0, shot_color, shot_sprite, damage)
			stone["gravity"] = goblin_f("gravity")
			stone["pierce"] = pierce
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

static func _blob(pos: Vector2, velocity: Vector2, splits: int, color: Color, sprite: String, damage: int = 1) -> Dictionary:
	return {
		"position": pos,
		"velocity": velocity,
		"gravity": 0.0,
		"damage": damage,
		"pierce": 0,
		"radius": HitLibrary.bounds_radius(sprite, "body"),
		"splits": splits,
		"color": color,
		"style": "blob",
		"sprite": sprite,
		"killer_name": "",
	}

static func card_heading(id: int, rank_index: int) -> String:
	var total := rank_table(id).size()
	return "%s, %s (rank %d/%d)" % [
		display_name(id),
		rank_name(id, rank_index),
		rank_index + 1,
		total,
	]

## One short line from this rank's shot count, interval, arc, split, pierce, and damage.
static func weapon_line(id: int, rank_index: int) -> String:
	var spec := rank_spec(id, rank_index)
	var shots := player_shots(id, Vector2.ZERO, rank_index)
	if shots.is_empty():
		return "No weapon."
	var first: Dictionary = shots[0]
	var every := "%.2fs" % float(spec["fire_interval"])
	var count := shots.size()
	if id == Id.SLIME:
		var head := "Straight shot every %s." % every
		if count > 1:
			head = "%d shots every %s." % [count, every]
		if int(first.get("splits", 0)) > 0:
			return "%s Splits on hit." % head
		return head
	var arc := 0.0
	for vy in spec["spread"]:
		arc = maxf(arc, absf(float(vy)))
	var line := "%d rocks every %s. Arc %d." % [count, every, int(round(arc))]
	var pierce := int(first.get("pierce", 0))
	if pierce > 0:
		line += " Pierce %d." % pierce
	var damage := int(first.get("damage", 1))
	if damage != 1:
		line += " Dmg %d." % damage
	return line

## Trait copy from FORM_CARD, plus the live split state or the magnet radius.
static func trait_line(id: int, split_ready: bool) -> String:
	var row: Dictionary = FORM_CARD.get(id, {})
	var body := str(row.get("trait", ""))
	if id == Id.SLIME:
		var state_key := "used"
		if split_ready:
			state_key = "ready"
		var flag := str(row.get(state_key, ""))
		if flag != "":
			return "%s %s" % [flag, body]
		return body
	if id == Id.GOBLIN and goblin_f("loot_magnet") > 0.0:
		return "%s Pulls in within %dpx." % [body, int(round(goblin_f("loot_magnet")))]
	return body

## Absolute points against the next gate, or FINAL FORM at the last rank.
static func next_rank_text(rank_index: int, points: int) -> String:
	var gate := gate_for_next_rank(rank_index)
	if gate < 0:
		return "FINAL FORM"
	return "%d/%d" % [maxi(points, 0), gate]
