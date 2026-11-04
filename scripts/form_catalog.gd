extends RefCounted
class_name FormCatalog

## Launch roster. One life per run still holds. The Slime split is that form's
## trait, not an extra life.
## Vending Machine, Cat, and Demon Lord play with the art already in res://art/.
## The vending machine title card plays its reveal sting. Each form has its
## own shot cue. WINNER! is only the vending meter clear.
## Slime pays for a reliable forward stream with a big body.
## Goblin pays for stones that lob forward and only fully connect up close.
## Vending Machine trails the finger (heavier, still a flick, not a slog).
## Cat blinks a short dash on a hard flick. Demon Lord is the large body.
## Slime, Goblin, Cat, and Demon Lord snap to the aim. Squash, bob, and lean
## are cosmetic.
## Goblin's rocks hit harder than the slime stream because most of the arc misses.
## Every Goblin balance number lives in GOBLIN. The three new forms live in
## VENDING, CAT, and DEMON.

enum Id { SLIME, GOBLIN, VENDING, CAT, DEMON, DRAGON }

## The random reincarnation roll. Dragon is earned by killing the Great Dragon
## and is never part of this list.
const IDS: Array[int] = [Id.SLIME, Id.GOBLIN, Id.VENDING, Id.CAT, Id.DEMON]

const SLIME_FIRE_INTERVAL := 0.16
const SLIME_SHOT_SPEED := 700.0
## Keyboard aim rate. The body does not lag behind this aim, except Vending.
const SLIME_MAX_SPEED := 430.0
## Shared by the snap forms. At 60 fps, about 84% of the remaining gap closes
## each frame, so a flick lands inside 1-3 frames. The cap stays above a
## full-screen drag so it does not add a slide.
const SNAP_ARRIVE := 110.0
const SNAP_MAX_SPEED := 22000.0
## Vending closes about 45% of the gap per frame. A flick still lands inside
## 8 frames, and the first frame of a drag already moves. No overshoot.
const VENDING_ARRIVE := 62.0
const VENDING_MAX_SPEED := 400.0
## Kills, not coins. A full meter is the only WINNER! in the game.
## Rank-1 length. Play reads the per-rank list. This is the empty-list fallback.
const VENDING_WINNER_KILLS := 10
## Heavy hit for a WINNER! clear, read off SpawnDirector.max_hp.
## An eye is 2. Wolf, anvil, and archer are 4. Wyvern and piano are 6.
## 2 kills an eye and chips every tougher body. Bosses take 15% of max HP instead.
const VENDING_WINNER_DAMAGE := 2

## Short dash when the aim jumps. Fine corrections still use the snap.
const CAT_BLINK_DIST := 34.0
const CAT_BLINK_MIN := 26.0
const CAT_BLINK_CD := 0.14
## A few frames where the dash body cannot be hit.
const CAT_BLINK_GUARD := 0.10
const CAT_GRAZE_NEED := 3
const CAT_GRAZE_WINDOW := 1.6
const CAT_CHARM_TIME := 1.55
const CAT_CHARM_RADIUS := 92.0
const CAT_CHARM_MAX := 2

## Every Goblin balance number. Rank arrays are rank 1 through rank 5.
## Movement, stones, and loot all read this table.
## Before this pass: fire_interval [0.48, 0.36, 0.28], shot_speed 780, gravity 170,
## spread [±110], [±150, ±50], [±180, ±90, 0], damage 1, pierce 0,
## loot_points 40, loot_magnet 0, loot_magnet_speed 0.
## Movement used to sprint and then plant. Snap forms now use SNAP_ARRIVE.
## Stride still clocks the goblin's drawn hop. Loot points stay 40. A magnet was
## measured and left at 0: it inflated score past the bot band without being
## what closed the survival gap.
const GOBLIN := {
	"fire_interval": [0.30, 0.24, 0.20, 0.16, 0.13],
	"shot_speed": 780.0,
	"gravity": 170.0,
	"spread": [
		[-110.0, 0.0, 110.0],
		[-170.0, -56.0, 56.0, 170.0],
		[-200.0, -100.0, 0.0, 100.0, 200.0],
		[-220.0, -110.0, 0.0, 110.0, 220.0],
		[-230.0, -138.0, -46.0, 46.0, 138.0, 230.0],
	],
	"damage": 2,
	"damage_by_rank": [2, 2, 2, 3, 3],
	"pierce": 1,
	"pierce_by_rank": [1, 1, 1, 2, 2],
	"max_speed": 560.0,
	"stride": 0.32,
	"sprint_fraction": 0.70,
	"loot_points": 40,
	"loot_magnet": 0.0,
	"loot_magnet_speed": 0.0,
}

## Three forward cans. Spread is degrees off the forward axis, +y down.
## Rank 1 is slow enough that the heavy body is the tax. Later ranks hit
## harder. WINNER! takes more kills as the rank climbs and no longer wipes
## the screen. The body is the original large art again. Drift, damage, and
## the WINNER! meter are unchanged.
const VENDING := {
	"fire_interval": [0.24, 0.20, 0.16, 0.135, 0.115],
	"shot_speed": [520.0, 580.0, 640.0, 700.0, 760.0],
	"damage": [1, 1, 2, 2, 3],
	"spread_deg": [16.0, 18.0, 20.0, 22.0, 24.0],
	"winner_kills": [10, 12, 14, 16, 18],
	"winner_bonus": [200, 300, 400, 500, 600],
}

## The swipe is short. Reflecting bullets is the defense, not a long stream.
## Later ranks dash farther, graze into a charm sooner, and swipe harder.
const CAT := {
	"fire_interval": [0.24, 0.20, 0.17, 0.145, 0.12],
	"shot_speed": 420.0,
	"life": [0.58, 0.60, 0.64, 0.70, 0.78],
	"damage": [1, 1, 2, 2, 3],
	"pierce": 2,
	"blink_dist": [34.0, 38.0, 44.0, 52.0, 62.0],
	"blink_guard": [0.10, 0.10, 0.11, 0.13, 0.15],
	"graze_need": [3, 3, 3, 2, 2],
	"charm_max": [2, 2, 2, 3, 4],
	"charm_radius": [92.0, 100.0, 110.0, 124.0, 140.0],
}

## Drawn and hurt at this fraction of the source art. The hurt circles are the
## same fit, scaled with the sprite, so a shot that touches the picture hits.
const DEMON_PLAY_SCALE := 0.75
## 30% smaller than the source art. The hurt shape uses the same scale.
const VENDING_PLAY_SCALE := 0.7
## Rank-5 combat from the first frame. There are no stages.
## Three fireballs. Each is 5, so a volley that all hits is 15.
## That is 214 DPS at 0.07s, above a rank-5 Goblin's 138.
## The +1 per fireball is +3 on the volley, the same slope as the Goblin.
const DRAGON_FIRE_INTERVAL := 0.07
const DRAGON_SHOT_SPEED := 820.0
const DRAGON_DAMAGE := 5
const DRAGON_SPLASH := 8
const DRAGON_SPLASH_RADIUS := 42.0
## Hurt body is about 45px wide. 760 / 45 beats Goblin 560 / 34.
const DRAGON_MAX_SPEED := 760.0
const DRAGON_POWER_PER_LEVEL := 1
const DRAGON_METEOR_KILLS := 8
const DRAGON_SPRITE := "dragon_form/dragon_fly.png"
const DRAGON_SHOT := "dragon_form/dragon_fireball.png"
const DRAGON_SPREAD: Array[float] = [-58.0, 0.0, 58.0]

static func play_scale(id: int) -> float:
	if id == Id.DEMON:
		return DEMON_PLAY_SCALE
	if id == Id.VENDING:
		return VENDING_PLAY_SCALE
	return 1.0

static func dragon_power_bonus(level: int) -> int:
	return maxi(level, 0) * DRAGON_POWER_PER_LEVEL

## The fly sheet is already the on-screen size. Do not shrink it.
static func dragon_fit_scale(_file_name: String, _old_scale: float) -> float:
	return 1.0

## Slow homing orbs. Damage, speed, and turn rate climb with the crowd.
## Rank 4 fires a pair. Rank 5 fires three. The art stays the rank-3 orb.
const DEMON := {
	"fire_interval": [0.34, 0.28, 0.22, 0.20, 0.18],
	"shot_speed": [180.0, 210.0, 240.0, 250.0, 265.0],
	"damage": [2, 2, 3, 3, 3],
	"homing": [180.0, 220.0, 260.0, 280.0, 300.0],
	"orbs": [1, 1, 1, 2, 3],
	"per_enemy": 0.5,
	"enemy_cap": 6,
}

## Kept so older shot-size checks can still name the previous circle fraction.
## Live shots use the shapes in res://art/hitboxes.json.
const SHOT_PCT := 0.62

## Pause-card sentences. A new form adds one entry. Weapon text is not copied
## here; weapon_line() builds it from the rank's real shot data.
const FORM_CARD := {
	Id.SLIME: {
		"trait": "Once per run, splits into a small slime instead of dying; regrows in 15s. Later ranks add lanes and a wider split.",
		"ready": "Split ready.",
		"used": "Split used.",
	},
	Id.GOBLIN: {
		"trait": "Kills can drop gems. Picking one up adds score and evolution points. Later ranks throw more rocks that hit harder.",
		"ready": "",
		"used": "",
	},
	Id.VENDING: {
		"trait": "Heavy drift. Kills fill a WINNER! meter. A full meter blasts the field and clears shots. Later ranks pay a bigger WINNER!.",
		"ready": "",
		"used": "",
	},
	Id.CAT: {
		"trait": "A hard flick blinks a short dash. A graze streak makes nearby enemies fight for you. Later ranks dash farther and charm more.",
		"ready": "",
		"used": "",
	},
	Id.DEMON: {
		"trait": "Big slow orbs home in. They hit harder the more enemies are on screen. Later ranks loose more orbs.",
		"ready": "",
		"used": "",
	},
	Id.DRAGON: {
		"trait": "Earned by slaying the Great Dragon. Fireballs explode. Kills fill Meteor Rain, which chips a boss for 15% of its max HP.",
		"ready": "",
		"used": "",
	},
}

## Cumulative skill points to reach rank 2, then 3, 4, and 5. Rank 1 is the start.
## The numbers live in Difficulty so the bot and the meter share one list.
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

static func goblin_damage(rank_index: int) -> int:
	var values: Array = GOBLIN["damage_by_rank"]
	return int(values[clampi(rank_index, 0, values.size() - 1)])

static func goblin_pierce(rank_index: int) -> int:
	var values: Array = GOBLIN["pierce_by_rank"]
	return int(values[clampi(rank_index, 0, values.size() - 1)])

static func vending_rank_f(key: String, rank_index: int) -> float:
	var values: Array = VENDING[key]
	return float(values[clampi(rank_index, 0, values.size() - 1)])

static func cat_rank_f(key: String, rank_index: int) -> float:
	var values: Array = CAT[key]
	return float(values[clampi(rank_index, 0, values.size() - 1)])

static func cat_f(key: String) -> float:
	return float(CAT[key])

static func cat_blink_dist(rank_index: int, power_level: int = 0) -> float:
	var values: Array = CAT["blink_dist"]
	return float(values[clampi(rank_index, 0, values.size() - 1)]) + float(maxi(power_level, 0)) * 2.0

static func cat_blink_guard(rank_index: int, power_level: int = 0) -> float:
	var values: Array = CAT["blink_guard"]
	var guard := float(values[clampi(rank_index, 0, values.size() - 1)]) + float(maxi(power_level, 0)) * 0.008
	return minf(guard, 0.2)

static func cat_graze_need(rank_index: int) -> int:
	var values: Array = CAT["graze_need"]
	return int(values[clampi(rank_index, 0, values.size() - 1)])

static func cat_charm_max(rank_index: int) -> int:
	var values: Array = CAT["charm_max"]
	return int(values[clampi(rank_index, 0, values.size() - 1)])

static func cat_charm_radius(rank_index: int) -> float:
	var values: Array = CAT["charm_radius"]
	return float(values[clampi(rank_index, 0, values.size() - 1)])

static func cat_life(rank_index: int) -> float:
	var values: Array = CAT["life"]
	return float(values[clampi(rank_index, 0, values.size() - 1)])

static func demon_rank_f(key: String, rank_index: int) -> float:
	var values: Array = DEMON[key]
	return float(values[clampi(rank_index, 0, values.size() - 1)])

static func demon_damage(rank_index: int, enemies: int) -> int:
	var base := int(demon_rank_f("damage", rank_index))
	var capped := clampi(enemies, 0, int(DEMON["enemy_cap"]))
	return base + int(floor(float(capped) * float(DEMON["per_enemy"])))

static func demon_speed(rank_index: int, enemies: int) -> float:
	var extra := float(clampi(enemies, 0, int(DEMON["enemy_cap"]))) * 8.0
	return demon_rank_f("shot_speed", rank_index) + extra

static func demon_homing(rank_index: int, enemies: int) -> float:
	var extra := float(clampi(enemies, 0, int(DEMON["enemy_cap"]))) * 12.0
	return demon_rank_f("homing", rank_index) + extra

static func vending_winner_kills(rank_index: int = 0) -> int:
	var values: Array = VENDING["winner_kills"]
	if values.is_empty():
		return VENDING_WINNER_KILLS
	return int(values[clampi(rank_index, 0, values.size() - 1)])

static func vending_winner_bonus(rank_index: int) -> int:
	var values: Array = VENDING["winner_bonus"]
	return int(values[clampi(rank_index, 0, values.size() - 1)])

## Modest, and slower for the slime stream, whose shots start at 1 damage.
static func power_damage_bonus(id: int, power_level: int) -> int:
	if power_level <= 0:
		return 0
	if id == Id.SLIME:
		return power_level / 3
	if id == Id.DEMON:
		return power_level / 4
	return power_level / 2

static func power_fire_interval(base: float, power_level: int) -> float:
	if power_level <= 0:
		return base
	return base * pow(0.985, float(power_level))

static func demon_orbs(rank_index: int) -> int:
	var values: Array = DEMON["orbs"]
	return int(values[clampi(rank_index, 0, values.size() - 1)])

## A Goblin pickup. Added to the score and to the evolution meter. Not a weapon upgrade.
static func loot_points() -> int:
	return int(GOBLIN["loot_points"])

static func id_from_key(key: String) -> int:
	match key:
		"slime":
			return Id.SLIME
		"goblin":
			return Id.GOBLIN
		"vending_machine":
			return Id.VENDING
		"cat":
			return Id.CAT
		"demon_lord":
			return Id.DEMON
		_:
			return -1

static func key_for(id: int) -> String:
	match id:
		Id.GOBLIN:
			return "goblin"
		Id.VENDING:
			return "vending_machine"
		Id.CAT:
			return "cat"
		Id.DEMON:
			return "demon_lord"
		Id.DRAGON:
			return "dragon"
		_:
			return "slime"

static func display_name(id: int) -> String:
	match id:
		Id.SLIME:
			return "SLIME"
		Id.GOBLIN:
			return "GOBLIN"
		Id.VENDING:
			return "VENDING MACHINE"
		Id.CAT:
			return "CAT"
		Id.DEMON:
			return "DEMON LORD"
		Id.DRAGON:
			return "DRAGON"
		_:
			return "UNKNOWN"

static func gag(id: int) -> String:
	match id:
		Id.SLIME:
			return "You leave a trail. Mostly of yourself."
		Id.GOBLIN:
			return "The crown is heavy. The plan is not."
		Id.VENDING:
			return "Sold out at the worst time."
		Id.CAT:
			return "The board voted to pounce."
		Id.DEMON:
			return "The crown was already on fire."
		Id.DRAGON:
			return "The sky learned your name."
		_:
			return ""

## Full-screen 480x270 card shown before the run. Files live in res://art/title_cards/.
static func title_card(id: int) -> String:
	match id:
		Id.SLIME:
			return "title_cards/title_slime.png"
		Id.GOBLIN:
			return "title_cards/title_goblin.png"
		Id.VENDING:
			return "title_cards/title_vending_machine.png"
		Id.CAT:
			return "title_cards/title_cat.png"
		Id.DEMON:
			return "title_cards/title_demon_lord.png"
		_:
			return "title_cards/title_slime.png"

static func title_color(id: int) -> Color:
	match id:
		Id.SLIME:
			return Color("8ecbff")
		Id.GOBLIN:
			return Color("ffd56a")
		Id.VENDING:
			return Color("ffb84a")
		Id.CAT:
			return Color("ff9ad8")
		Id.DEMON:
			return Color("ff6b8a")
		Id.DRAGON:
			return Color("ffb15a")
		_:
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
	return HitLibrary.bounds_radius(_sprite_file(id, rank_index, small), "hurt") * play_scale(id)

## Radius of the core itself. This is the hurt target, not the distance from the anchor.
static func core_radius(id: int, rank_index: int, small: bool) -> float:
	return HitLibrary.max_part_radius(_sprite_file(id, rank_index, small), "hurt")

static func max_speed(id: int) -> float:
	if id == Id.DRAGON:
		return DRAGON_MAX_SPEED
	if id == Id.SLIME or id == Id.CAT or id == Id.DEMON:
		return SLIME_MAX_SPEED
	if id == Id.VENDING:
		return VENDING_MAX_SPEED
	return goblin_f("max_speed")

static func arrive_rate(id: int) -> float:
	if id == Id.VENDING:
		return VENDING_ARRIVE
	return SNAP_ARRIVE

static func fire_interval(id: int) -> float:
	if id == Id.SLIME:
		return SLIME_FIRE_INTERVAL
	return float(rank_spec(id, 0)["fire_interval"])

## Daily order for the default game. Run 0 is uniform over the roster.
## Each later run is uniform over the other forms, so it never repeats the
## form the chain just rolled. Seeded only by the UTC day.
static func id_for_run(day_seed: int, run_index: int) -> int:
	return _pick(day_seed, run_index, -1, IDS)

## Same chain, but the last step refuses `avoid` when the natural roll landed on it.
## Used when a challenged run was a fixed form the chain did not play.
static func id_for_run_avoiding(day_seed: int, run_index: int, avoid: int) -> int:
	var natural := _pick(day_seed, run_index, -1, IDS)
	if natural != avoid:
		return natural
	return _pick(day_seed, run_index, avoid, IDS)

static func _pick(day_seed: int, run_index: int, force_avoid: int, roster: Array[int]) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed
	var previous := -1
	var chosen := roster[0]
	var steps := maxi(run_index, 0) + 1
	for step in steps:
		var skip := previous
		if force_avoid >= 0 and step == steps - 1:
			skip = force_avoid
		var pool: Array[int] = []
		for id in roster:
			if id != skip:
				pool.append(id)
		if pool.is_empty():
			pool.assign(roster)
		chosen = pool[rng.randi_range(0, pool.size() - 1)]
		previous = chosen
	return chosen

## Five ranks per form. A `<form>_rN_body.png` is the body and the hitbox.
## `<form>_rN.png` is the fallback when no body file has been dropped in.
## `<form>_rN_aura.png` is optional FX and is not part of this table.
static func rank_table(id: int) -> Array[Dictionary]:
	if id == Id.SLIME:
		var names := ["Slime", "Gel Knight", "Ooze Titan", "Gel Paladin", "Prism Ooze"]
		var intervals: Array[float] = [SLIME_FIRE_INTERVAL, 0.13, 0.10, 0.085, 0.072]
		var lanes: Array = [
			[0.0],
			[-12.0, 12.0],
			[-16.0, 0.0, 16.0],
			[-22.0, -8.0, 8.0, 22.0],
			[-24.0, -12.0, 0.0, 12.0, 24.0],
		]
		var splits: Array[int] = [1, 1, 1, 2, 3]
		var colors: Array[Color] = [Color("7ec8ff"), Color("b7e4ff"), Color("eaf7ff"), Color("f4fbff"), Color("ffffff")]
		var rows: Array[Dictionary] = []
		for i in names.size():
			rows.append({
				"name": names[i],
				"sprite": _body_file("slime", i + 1),
				"sprite_small": _small_file(i + 1),
				"fire_interval": intervals[i],
				"shot_sprite": "slime_shot.png",
				"shot_color": colors[i],
				"lanes": lanes[i],
				"spread": [],
				"splits": splits[i],
			})
		return rows
	if id == Id.GOBLIN:
		var names := ["Goblin", "Goblin Chief", "Goblin King", "Goblin Warlord", "Goblin Emperor"]
		var stones := ["slingshot_stone.png", "slingshot_stone_l2.png", "slingshot_stone_l3.png", "slingshot_stone_l3.png", "slingshot_stone_l3.png"]
		var colors: Array[Color] = [Color("f0c36a"), Color("ffe08a"), Color("fff3c4"), Color("fff6d2"), Color("fffdf2")]
		var rows: Array[Dictionary] = []
		for i in names.size():
			rows.append({
				"name": names[i],
				"sprite": _body_file("goblin", i + 1),
				"fire_interval": goblin_rank_f("fire_interval", i),
				"shot_sprite": stones[i],
				"shot_color": colors[i],
				"lanes": [],
				"spread": goblin_spread(i),
			})
		return rows
	if id == Id.VENDING:
		var names := ["Vending Machine", "Mega Vendor", "Vending Fortress", "Vending Citadel", "Golden Jackpot"]
		var colors: Array[Color] = [Color("ffd56a"), Color("ffe08a"), Color("fff3c4"), Color("fff6d0"), Color("fffdf0")]
		var rows: Array[Dictionary] = []
		for i in names.size():
			rows.append({
				"name": names[i],
				"sprite": _body_file("vending_machine", i + 1),
				"fire_interval": vending_rank_f("fire_interval", i),
				"shot_sprite": "vending_can.png",
				"shot_color": colors[i],
				"lanes": [],
				"spread": [],
				"spread_deg": vending_rank_f("spread_deg", i),
			})
		return rows
	if id == Id.CAT:
		var names := ["Cat (ex-CEO)", "Cat Chairman", "Cat Overlord", "Cat Tycoon", "Briefcase Boss"]
		var colors: Array[Color] = [Color("ffb7ea"), Color("ffd0f2"), Color("fff0fb"), Color("fff6fd"), Color("ffffff")]
		var rows: Array[Dictionary] = []
		for i in names.size():
			rows.append({
				"name": names[i],
				"sprite": _body_file("cat", i + 1),
				"fire_interval": cat_rank_f("fire_interval", i),
				"shot_sprite": "cat_swipe.png",
				"shot_color": colors[i],
				"lanes": [],
				"spread": [],
			})
		return rows
	if id == Id.DRAGON:
		var dragon_rows: Array[Dictionary] = []
		for _i in 5:
			dragon_rows.append({
				"name": "Dragon",
				"sprite": DRAGON_SPRITE,
				"fire_interval": DRAGON_FIRE_INTERVAL,
				"shot_sprite": DRAGON_SHOT,
				"shot_color": Color("ffb15a"),
				"lanes": [],
				"spread": [],
			})
		return dragon_rows
	var names := ["Demon Lord", "Demon Emperor", "True Demon King", "Demon Overlord", "Abyss Sovereign"]
	var orbs := ["demon_orb_r1.png", "demon_orb_r2.png", "demon_orb_r3.png", "demon_orb_r3.png", "demon_orb_r3.png"]
	var colors: Array[Color] = [Color("ff4d6a"), Color("ff6b8a"), Color("ffd0dc"), Color("ffe0e8"), Color("fff4f7")]
	var rows: Array[Dictionary] = []
	for i in names.size():
		rows.append({
			"name": names[i],
			"sprite": _body_file("demon_lord", i + 1),
			"fire_interval": demon_rank_f("fire_interval", i),
			"shot_sprite": orbs[i],
			"shot_color": colors[i],
			"lanes": [],
			"spread": [],
		})
	return rows

## Body file when the artist dropped one in, otherwise the plain rank sprite.
## Idle sheets are optional: ArtLibrary.loop_file falls back when `_idle` is missing.
static func _body_file(form_key: String, rank_number: int) -> String:
	var body := "%s_r%d_body.png" % [form_key, rank_number]
	if ArtLibrary.has_file(body):
		return body
	return "%s_r%d.png" % [form_key, rank_number]

static func _small_file(rank_number: int) -> String:
	var body := "slime_small_r%d_body.png" % rank_number
	if ArtLibrary.has_file(body):
		return body
	return "slime_small_r%d.png" % rank_number

static func aura_file(id: int, rank_index: int) -> String:
	var aura := "%s_r%d_aura.png" % [key_for(id), rank_index + 1]
	if ArtLibrary.has_file(aura):
		return aura
	return ""

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
	var muzzle := (ArtLibrary.anchor(str(spec["sprite"])).x + 2.0) * play_scale(id)
	if id == Id.SLIME:
		var lanes: Array = spec["lanes"]
		var splits := int(spec.get("splits", 1))
		for lane in lanes:
			shots.append(_blob(origin + Vector2(muzzle, float(lane)), Vector2(SLIME_SHOT_SPEED, 0), splits, shot_color, shot_sprite))
	elif id == Id.GOBLIN:
		var spread: Array = spec["spread"]
		var damage := goblin_damage(rank_index)
		var pierce := goblin_pierce(rank_index)
		for vy in spread:
			var stone := _blob(origin + Vector2(muzzle, -2), Vector2(goblin_f("shot_speed"), float(vy)), 0, shot_color, shot_sprite, damage)
			stone["gravity"] = goblin_f("gravity")
			stone["pierce"] = pierce
			stone["style"] = "stone"
			shots.append(stone)
	elif id == Id.VENDING:
		var deg := float(spec["spread_deg"])
		var speed := vending_rank_f("shot_speed", rank_index)
		var damage := int(vending_rank_f("damage", rank_index))
		for sign in [-1.0, 0.0, 1.0]:
			var angle := deg_to_rad(sign * deg)
			var vel := Vector2(cos(angle), sin(angle)) * speed
			var can := _blob(origin + Vector2(muzzle, 0), vel, 0, shot_color, shot_sprite, damage)
			can["style"] = "can"
			shots.append(can)
	elif id == Id.DRAGON:
		for vy in DRAGON_SPREAD:
			var fireball := _blob(origin + Vector2(muzzle, 0), Vector2(DRAGON_SHOT_SPEED, vy), 0, shot_color, shot_sprite, DRAGON_DAMAGE)
			fireball["style"] = "dragon"
			fireball["splash"] = DRAGON_SPLASH
			fireball["splash_radius"] = DRAGON_SPLASH_RADIUS
			shots.append(fireball)
	elif id == Id.CAT:
		var damage := int(cat_rank_f("damage", rank_index))
		var swipe := _blob(origin + Vector2(muzzle, -2), Vector2(cat_f("shot_speed"), 0), 0, shot_color, shot_sprite, damage)
		swipe["style"] = "swipe"
		swipe["expires"] = true
		swipe["life"] = cat_life(rank_index)
		swipe["pierce"] = int(CAT["pierce"])
		shots.append(swipe)
	else:
		var damage := int(demon_rank_f("damage", rank_index))
		var speed := demon_rank_f("shot_speed", rank_index)
		var count := demon_orbs(rank_index)
		var offsets: Array[float] = [0.0]
		if count == 2:
			offsets = [-12.0, 12.0]
		elif count >= 3:
			offsets = [-16.0, 0.0, 16.0]
		for lane in offsets:
			var orb := _blob(origin + Vector2(muzzle, lane), Vector2(speed, lane * 0.35), 0, shot_color, shot_sprite, damage)
			orb["style"] = "orb"
			orb["homing"] = demon_rank_f("homing", rank_index)
			shots.append(orb)
	return shots

static func split_shots(velocity: Vector2, origin: Vector2, count: int = 1) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	var base := velocity
	if base.length() < 1.0:
		base = Vector2(SLIME_SHOT_SPEED, 0)
	var angles: Array[float] = [-0.62, 0.62]
	if count >= 3:
		angles = [-1.05, -0.62, 0.0, 0.62, 1.05]
	elif count >= 2:
		angles = [-0.95, -0.38, 0.38, 0.95]
	for angle in angles:
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
		"splash": 0,
		"splash_radius": 0.0,
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
	if id == Id.VENDING:
		return "%d cans every %s. Spread %d. WINNER! in %d kills." % [count, every, int(round(float(spec["spread_deg"]))), vending_winner_kills(rank_index)]
	if id == Id.CAT:
		var line := "Swipe every %s. Reflects shots." % every
		var damage := int(first.get("damage", 1))
		if damage != 1:
			line += " Dmg %d." % damage
		return line
	if id == Id.DRAGON:
		return "3 fireballs every %s. Dmg %d each, splash %d. Meteor Rain in %d kills." % [every, DRAGON_DAMAGE, DRAGON_SPLASH, DRAGON_METEOR_KILLS]
	if id == Id.DEMON:
		var line := "Homing orb every %s." % every
		if count > 1:
			line = "%d homing orbs every %s." % [count, every]
		var damage := int(first.get("damage", 1))
		if damage != 1:
			line += " Dmg %d." % damage
		return line
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
