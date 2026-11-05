extends RefCounted
class_name DragonPhase

## Every dragon-phase tuning number lives in this file.
##
## Time t is seconds survived since the Dragon form transform, not the run clock.
## run_t is the run clock at that same moment.
##
## Spawn rate
##   smooth(u) = u^2 * (3 - 2u), u clamped to 0..1
##   rate(t) = lerp(SPAWN_RATE_START, SPAWN_RATE_CAP, smooth(t / SPAWN_RAMP_SECONDS))
##   interval(run_t, t) = max(SPAWN_INTERVAL_FLOOR, Difficulty.spawn_interval(run_t) / rate(t))
## SPAWN_RATE_START is 1.5, so the phase opens at 1.5x the spawn rate the run already had.
##
## Hit points
##   hp(t) = max(1, round(base_hp * lerp(HP_MULT_START, HP_MULT_CAP, smooth(t / HP_RAMP_SECONDS))))
## HP_MULT_START is 2, so each enemy opens at twice the base in STATS.
##
## Bullet density
##   density(t) = lerp(BULLET_DENSITY_START, BULLET_DENSITY_CAP, smooth(t / BULLET_RAMP_SECONDS))
## Attack gaps use base_interval / density, and never drop below MIN_ATTACK_GAP.
## Telegraphs are not scaled. Spreads are not tightened.
##   shot_cap(t) = round(lerp(SHOT_CAP_START, SHOT_CAP_END, smooth(t / BULLET_RAMP_SECONDS)))
##
## Great Dragon returns (generation 0 is the first fight). Each later return
## keeps every earlier upgrade. Windups are not part of this list.

const BAT := 0
const KOBOLD := 1
const EGG := 2
const WHELP := 3
const WYVERN := 4
const SLIME := 5
const RIDER := 6
const CULTIST := 7
const WRAITH := 8
const ELDER := 9

const TIER2_AT := 60.0
const TIER3_AT := 120.0
const TIER4_AT := 180.0

const FIRST_SPAWN := 0.45
const SPAWN_JITTER_MIN := 0.92
const SPAWN_JITTER_MAX := 1.08
const SPAWN_RATE_START := 1.5
const SPAWN_RATE_CAP := 2.35
const SPAWN_RAMP_SECONDS := 210.0
const SPAWN_INTERVAL_FLOOR := 0.16
const BURST_CHANCE_START := 0.12
const BURST_CHANCE_CAP := 0.40
const BURST_RAMP_SECONDS := 210.0

const HP_MULT_START := 2.0
const HP_MULT_CAP := 3.2
const HP_RAMP_SECONDS := 210.0

const BULLET_DENSITY_START := 1.0
const BULLET_DENSITY_CAP := 1.65
const BULLET_RAMP_SECONDS := 210.0
const MIN_ATTACK_GAP := 0.55
const SHOT_CAP_START := 8.0
const SHOT_CAP_END := 11.0

const SPEED_MULT_START := 1.0
const SPEED_MULT_CAP := 1.22
const SPEED_RAMP_SECONDS := 210.0

const MAX_ENEMIES := 7
const EGG_CAP := 2
const ELDER_CAP := 1
const WYVERN_CAP := 2
const BOSS_EXIT_SPEED := 1.9

const EGG_HATCH := 4.0
const EGG_CRACK_STEP := 1.0

const KOBOLD_INTERVAL := 1.55
const KOBOLD_THROW_AT := 0.16
const KOBOLD_BOMB_VX := -78.0
const KOBOLD_BOMB_VY := -168.0
const KOBOLD_BOMB_GRAVITY := 340.0
const KOBOLD_BOMB_LIFE := 2.3

const WHELP_INTERVAL := 1.7
const WHELP_SHOT_SPEED := 148.0
const WHELP_WINDUP := 0.34
const WHELP_CHASE := 0.72

const WYVERN_WARN := 0.72
const WYVERN_DIVE_VX := -230.0
const WYVERN_DIVE_VY := 36.0

const PUDDLE_LIFE := 2.6
const PUDDLE_SPREAD := 16.0
const PUDDLE_DRIFT := -18.0

const RIDER_INTERVAL := 1.28
const RIDER_SHOTS := 3
const RIDER_GAP := 72.0
const RIDER_BOLT_SPEED := 168.0
const RIDER_STRAFE := 22.0
const RIDER_WINDUP := 0.28

const SHIELD_HITS := 4
const SHIELD_RANGE := 168.0
const SHIELD_PIERCE := 50

const WRAITH_FLOAT := 2.15
const WRAITH_OUT := 1.15
const WRAITH_WARN := 0.74
const RING_BULLETS := 8
const RING_SPEED := 86.0

const ELDER_INTERVAL := 2.45
const ELDER_WARN := 0.8
const ELDER_OPEN := 0.45
const ELDER_PUFF_SPEED := 148.0
const ELDER_PUFF_LIFE := 0.46
const ELDER_CONE := 5
const ELDER_CONE_SPAN := 0.84
const ELDER_PARK_X := 0.70
const ELDER_GEM_BONUS := 560
const ELDER_GEM_LIFE := 5.4

## generation >= 1, 2, 3, 4, 5. Cumulative.
const RETURN_BREATH_SPEED := 1.22
const RETURN_METEOR_COUNT := 4
const RETURN_GAP_SCALE := 0.78
const RETURN_GAP_FLOOR := 0.48
const RETURN_HELL_GAP_SPEED := 82.0
const RETURN_EXTRA_STAGGER := 5
const RETURN_ORDER: Array[String] = [
	"Faster breath sweeps",
	"More dark meteors",
	"Shorter gaps between attacks",
	"Faster-moving safe gap in the enrage breath",
	"Extra fireball spread",
]

const HOOK_BAT_ATTACK := "sfx_dragon_enemy_ember_bat_attack"
const HOOK_BAT_DEATH := "sfx_dragon_enemy_ember_bat_death"
const HOOK_KOBOLD_ATTACK := "sfx_dragon_enemy_kobold_torchbearer_attack"
const HOOK_KOBOLD_DEATH := "sfx_dragon_enemy_kobold_torchbearer_death"
const HOOK_EGG_HATCH := "sfx_dragon_enemy_dragon_egg_hatch"
const HOOK_EGG_DEATH := "sfx_dragon_enemy_dragon_egg_death"
const HOOK_WHELP_ATTACK := "sfx_dragon_enemy_whelp_attack"
const HOOK_WHELP_DEATH := "sfx_dragon_enemy_whelp_death"
const HOOK_WYVERN_ATTACK := "sfx_dragon_enemy_ember_wyvern_attack"
const HOOK_WYVERN_DEATH := "sfx_dragon_enemy_ember_wyvern_death"
const HOOK_SLIME_ATTACK := "sfx_dragon_enemy_magma_slime_attack"
const HOOK_SLIME_DEATH := "sfx_dragon_enemy_magma_slime_death"
const HOOK_RIDER_ATTACK := "sfx_dragon_enemy_drake_rider_attack"
const HOOK_RIDER_DEATH := "sfx_dragon_enemy_drake_rider_death"
const HOOK_CULTIST_ATTACK := "sfx_dragon_enemy_dragon_cultist_attack"
const HOOK_CULTIST_DEATH := "sfx_dragon_enemy_dragon_cultist_death"
const HOOK_WRAITH_ATTACK := "sfx_dragon_enemy_ash_wraith_attack"
const HOOK_WRAITH_DEATH := "sfx_dragon_enemy_ash_wraith_death"
const HOOK_ELDER_ATTACK := "sfx_dragon_enemy_elder_drake_attack"
const HOOK_ELDER_DEATH := "sfx_dragon_enemy_elder_drake_death"
const HOOK_TIER := "sfx_dragon_tier_up"
const HOOK_SKY_BREATH := "sfx_dragon_ability_sky_breath"
const HOOK_EMBER_FAN := "sfx_dragon_ability_ember_fan"
const HOOK_DIVE := "sfx_dragon_ability_dive"
const HOOK_WING_GUST := "sfx_dragon_ability_wing_gust"
const HOOK_METEOR := "sfx_dragon_ability_boss_meteor"
const HOOK_HELL_BREATH := "sfx_dragon_ability_hell_breath"
const HOOK_RETURN_BREATH := "sfx_dragon_return_faster_breath"
const HOOK_RETURN_METEORS := "sfx_dragon_return_more_meteors"
const HOOK_RETURN_GAPS := "sfx_dragon_return_shorter_gaps"
const HOOK_RETURN_HELL := "sfx_dragon_return_moving_hell_gap"
const HOOK_RETURN_FAN := "sfx_dragon_return_extra_fireball"

const HOOKS: PackedStringArray = [
	HOOK_BAT_ATTACK, HOOK_BAT_DEATH,
	HOOK_KOBOLD_ATTACK, HOOK_KOBOLD_DEATH,
	HOOK_EGG_HATCH, HOOK_EGG_DEATH,
	HOOK_WHELP_ATTACK, HOOK_WHELP_DEATH,
	HOOK_WYVERN_ATTACK, HOOK_WYVERN_DEATH,
	HOOK_SLIME_ATTACK, HOOK_SLIME_DEATH,
	HOOK_RIDER_ATTACK, HOOK_RIDER_DEATH,
	HOOK_CULTIST_ATTACK, HOOK_CULTIST_DEATH,
	HOOK_WRAITH_ATTACK, HOOK_WRAITH_DEATH,
	HOOK_ELDER_ATTACK, HOOK_ELDER_DEATH,
	HOOK_TIER,
	HOOK_SKY_BREATH, HOOK_EMBER_FAN, HOOK_DIVE, HOOK_WING_GUST, HOOK_METEOR, HOOK_HELL_BREATH,
	HOOK_RETURN_BREATH, HOOK_RETURN_METEORS, HOOK_RETURN_GAPS, HOOK_RETURN_HELL, HOOK_RETURN_FAN,
]

## base hp is the pre-multiplier pool. The phase opens at HP_MULT_START times this.
## damage is the shot and the touch. One touch still ends the run.
const STATS: Array[Dictionary] = [
	{"name": "Ember Bat", "hp": 2, "speed": 124.0, "damage": 1, "score": 110, "tier": 1, "weight": 1.15},
	{"name": "Kobold Torchbearer", "hp": 4, "speed": 48.0, "damage": 1, "score": 180, "tier": 1, "weight": 0.85},
	{"name": "Dragon Egg", "hp": 6, "speed": 0.0, "damage": 1, "score": 160, "tier": 1, "weight": 0.55},
	{"name": "Whelp", "hp": 3, "speed": 90.0, "damage": 1, "score": 140, "tier": 1, "weight": 0.9},
	{"name": "Ember Wyvern", "hp": 8, "speed": 230.0, "damage": 1, "score": 260, "tier": 2, "weight": 0.7},
	{"name": "Magma Slime", "hp": 7, "speed": 40.0, "damage": 1, "score": 220, "tier": 2, "weight": 0.72},
	{"name": "Drake Rider", "hp": 9, "speed": 52.0, "damage": 1, "score": 300, "tier": 2, "weight": 0.74},
	{"name": "Dragon Cultist", "hp": 8, "speed": 34.0, "damage": 1, "score": 280, "tier": 3, "weight": 0.58},
	{"name": "Ash Wraith", "hp": 8, "speed": 44.0, "damage": 1, "score": 340, "tier": 3, "weight": 0.58},
	{"name": "Elder Drake", "hp": 160, "speed": 30.0, "damage": 1, "score": 800, "tier": 4, "weight": 0.36},
]

const MOVE_FILE: PackedStringArray = [
	"dragon_enemies/ember_bat_fly.png",
	"dragon_enemies/kobold_torchbearer_walk.png",
	"dragon_enemies/dragon_egg_idle_pulse.png",
	"dragon_enemies/whelp_fly.png",
	"dragon_enemies/ember_wyvern_fly.png",
	"dragon_enemies/magma_slime_move.png",
	"dragon_enemies/drake_rider_fly.png",
	"dragon_enemies/dragon_cultist_idle.png",
	"dragon_enemies/ash_wraith_float.png",
	"dragon_enemies/elder_drake_walk.png",
]
const ATTACK_FILE: PackedStringArray = [
	"",
	"dragon_enemies/kobold_torchbearer_throw.png",
	"",
	"dragon_enemies/whelp_spit.png",
	"dragon_enemies/ember_wyvern_dive.png",
	"",
	"dragon_enemies/drake_rider_fire.png",
	"dragon_enemies/dragon_cultist_cast.png",
	"dragon_enemies/ash_wraith_phase.png",
	"dragon_enemies/elder_drake_breath.png",
]
const DEATH_FILE: PackedStringArray = [
	"dragon_enemies/ember_bat_death.png",
	"dragon_enemies/kobold_torchbearer_death.png",
	"dragon_enemies/dragon_egg_break.png",
	"dragon_enemies/whelp_death.png",
	"dragon_enemies/ember_wyvern_death.png",
	"dragon_enemies/magma_slime_split_death.png",
	"dragon_enemies/drake_rider_death.png",
	"dragon_enemies/dragon_cultist_death.png",
	"dragon_enemies/ash_wraith_death.png",
	"dragon_enemies/elder_drake_death.png",
]
const ATTACK_HOOK: PackedStringArray = [
	HOOK_BAT_ATTACK, HOOK_KOBOLD_ATTACK, "", HOOK_WHELP_ATTACK, HOOK_WYVERN_ATTACK,
	HOOK_SLIME_ATTACK, HOOK_RIDER_ATTACK, HOOK_CULTIST_ATTACK, HOOK_WRAITH_ATTACK, HOOK_ELDER_ATTACK,
]
const DEATH_HOOK: PackedStringArray = [
	HOOK_BAT_DEATH, HOOK_KOBOLD_DEATH, HOOK_EGG_DEATH, HOOK_WHELP_DEATH, HOOK_WYVERN_DEATH,
	HOOK_SLIME_DEATH, HOOK_RIDER_DEATH, HOOK_CULTIST_DEATH, HOOK_WRAITH_DEATH, HOOK_ELDER_DEATH,
]

const EGG_CRACK := "dragon_enemies/dragon_egg_crack.png"
const EGG_HATCH_FILE := "dragon_enemies/dragon_egg_hatch.png"
const WYVERN_WARN_FILE := "dragon_enemies/ember_wyvern_warning.png"
const FIREBOMB := "dragon_enemies/kobold_firebomb.png"
const WHELP_PROJ := "dragon_enemies/whelp_spit_proj.png"
const RIDER_BOLT := "dragon_enemies/drake_rider_bolt.png"
const PUDDLE := "dragon_enemies/magma_puddle_burn.png"
const SHIELD_FILE := "dragon_enemies/cultist_shield_loop.png"
const RING_WARN := "dragon_enemies/ash_ring_warning.png"
const RING_BULLET := "dragon_enemies/ash_ring_bullet.png"
const BREATH_TELEGRAPH := "dragon_enemies/elder_breath_telegraph.png"
const BREATH_PUFF := "dragon_enemies/elder_breath_puff.png"
const ELDER_GEM := "dragon_enemies/elder_gem.png"


static func is_hook(event: String) -> bool:
	return HOOKS.has(event)

static func hook_for_boss(attack: String) -> String:
	match attack:
		"sky_breath":
			return HOOK_SKY_BREATH
		"ember_fan":
			return HOOK_EMBER_FAN
		"dive":
			return HOOK_DIVE
		"wing_gust":
			return HOOK_WING_GUST
		"boss_meteor":
			return HOOK_METEOR
		"hell_breath":
			return HOOK_HELL_BREATH
		_:
			return ""

static func return_label(generation: int) -> String:
	var index := generation - 1
	if index < 0 or index >= RETURN_ORDER.size():
		return ""
	return RETURN_ORDER[index]

static func has_return(generation: int, index: int) -> bool:
	return generation >= index + 1

static func breath_speed_scale(generation: int) -> float:
	if has_return(generation, 0):
		return RETURN_BREATH_SPEED
	return 1.0

static func meteor_count(generation: int) -> int:
	if has_return(generation, 1):
		return RETURN_METEOR_COUNT
	return 3

static func _smooth(u: float) -> float:
	var t := clampf(u, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func _ramp(elapsed: float, span: float) -> float:
	if span <= 0.0:
		return 1.0
	return _smooth(elapsed / span)

static func spawn_rate_mul(dragon_time: float) -> float:
	return lerpf(SPAWN_RATE_START, SPAWN_RATE_CAP, _ramp(dragon_time, SPAWN_RAMP_SECONDS))

static func spawn_interval(run_time: float, dragon_time: float) -> float:
	var base := Difficulty.spawn_interval(run_time)
	return maxf(base / spawn_rate_mul(dragon_time), SPAWN_INTERVAL_FLOOR)

static func hp_mul(dragon_time: float) -> float:
	return lerpf(HP_MULT_START, HP_MULT_CAP, _ramp(dragon_time, HP_RAMP_SECONDS))

static func scaled_hp(id: int, dragon_time: float) -> int:
	return maxi(1, int(round(float(stat(id)["hp"]) * hp_mul(dragon_time))))

static func bullet_density(dragon_time: float) -> float:
	return lerpf(BULLET_DENSITY_START, BULLET_DENSITY_CAP, _ramp(dragon_time, BULLET_RAMP_SECONDS))

static func shot_cap(dragon_time: float) -> int:
	var count := lerpf(SHOT_CAP_START, SHOT_CAP_END, _ramp(dragon_time, BULLET_RAMP_SECONDS))
	return maxi(1, int(round(count)))

static func speed_mul(dragon_time: float) -> float:
	return lerpf(SPEED_MULT_START, SPEED_MULT_CAP, _ramp(dragon_time, SPEED_RAMP_SECONDS))

static func burst_chance(dragon_time: float) -> float:
	return lerpf(BURST_CHANCE_START, BURST_CHANCE_CAP, _ramp(dragon_time, BURST_RAMP_SECONDS))

static func attack_gap(base: float, density: float) -> float:
	return maxf(base / maxf(density, 0.2), MIN_ATTACK_GAP)

static func tier_for(dragon_time: float) -> int:
	if dragon_time >= TIER4_AT:
		return 4
	if dragon_time >= TIER3_AT:
		return 3
	if dragon_time >= TIER2_AT:
		return 2
	return 1

static func unlock_time(tier: int) -> float:
	match tier:
		2:
			return TIER2_AT
		3:
			return TIER3_AT
		4:
			return TIER4_AT
		_:
			return 0.0

static func stat(id: int) -> Dictionary:
	return STATS[clampi(id, 0, STATS.size() - 1)]

static func unlocked(dragon_time: float) -> Array[int]:
	var tier := tier_for(dragon_time)
	var ids: Array[int] = []
	for i in STATS.size():
		if int(STATS[i]["tier"]) <= tier:
			ids.append(i)
	return ids

static func weight(id: int) -> float:
	return float(stat(id)["weight"])

static func cap_for(id: int) -> int:
	match id:
		EGG:
			return EGG_CAP
		ELDER:
			return ELDER_CAP
		WYVERN:
			return WYVERN_CAP
		_:
			return 0

static func occupancy(id: int) -> float:
	match id:
		EGG:
			return 7.0
		ELDER:
			return 16.0
		WYVERN:
			return 3.4
		_:
			return 0.0

static func move_file(id: int) -> String:
	return MOVE_FILE[clampi(id, 0, MOVE_FILE.size() - 1)]

static func attack_file(id: int) -> String:
	return ATTACK_FILE[clampi(id, 0, ATTACK_FILE.size() - 1)]

static func death_file(id: int) -> String:
	return DEATH_FILE[clampi(id, 0, DEATH_FILE.size() - 1)]

static func attack_hook(id: int) -> String:
	return ATTACK_HOOK[clampi(id, 0, ATTACK_HOOK.size() - 1)]

static func death_hook(id: int) -> String:
	return DEATH_HOOK[clampi(id, 0, DEATH_HOOK.size() - 1)]

static func sheet_time(file_name: String) -> float:
	var data := ArtLibrary.entry(file_name)
	var frames := maxi(int(data.get("frames", 1)), 1)
	var fps := float(data.get("fps", 12.0))
	if fps <= 0.0:
		fps = 12.0
	return float(frames) / fps

static func death_offset(file_name: String) -> Vector2:
	var raw: Variant = ArtLibrary.entry(file_name).get("death_anchor_offset", [0, 0])
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 2:
		return Vector2.ZERO
	var pair: Array = raw
	return Vector2(float(pair[0]), float(pair[1]))

static func feet_y(file_name: String) -> float:
	var box := ArtLibrary.art_bbox(file_name)
	var point := ArtLibrary.anchor(file_name)
	return FieldBackground.GROUND_FEET - (box.y - point.y)

static func grounded(id: int) -> bool:
	return id == KOBOLD or id == EGG or id == SLIME or id == CULTIST or id == ELDER
