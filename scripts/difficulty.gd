extends RefCounted
class_name Difficulty

## Pacing for the default drag shooter. Flappy mode keeps the previous curve
## (see the legacy_* helpers) so ?mode=flappy stays on its own tuning.
##
## Previous default (f4d1e34 / 06a00b9), before this pass:
## - FIRST_SPAWN 0.72
## - spawn gap 1.85 → 1.45 at 20 s → 0.52 at 50 s → floor 0.36
## - speed scale 1.0 → 1.20 at 20 s → 1.95 at 50 s → cap 2.40
## - aim 0.18 until 8 s, full at 44 s
## - wolf chase off until 16 s, then 0.35 → 0.85 over 20 s
## - bursts only after 15 s (pair chance 0.62, triple after 32 s)
## - hazards from 8 s, warn 0.4 s, anvil fall 96, piano fall 62
## - gates 800 / 12000 skill points, kills and grazes filled the meter
## - graze 25, then 55 at rank 2
## - no power drops, no overdrive, goblin magnet 0

const FIRST_SPAWN := 0.34

const SPAWN_INTERVAL_START := 0.78
const SPAWN_INTERVAL_AT_20 := 0.40
const SPAWN_INTERVAL_AT_50 := 0.30
const SPAWN_INTERVAL_FLOOR := 0.24
const SPAWN_EASE_SECONDS := 20.0
const SPAWN_STEEP_SECONDS := 30.0
const SPAWN_FLOOR_SECONDS := 40.0
const SPAWN_RAMP_SECONDS := 60.0
const SPAWN_JITTER_MIN := 0.94
const SPAWN_JITTER_MAX := 1.06

const BURST_PAIR_AFTER := 6.0
const BURST_TRIPLE_AFTER := 14.0
const BURST_PAIR_CHANCE := 0.55
const BURST_TRIPLE_CHANCE := 0.34

const SPEED_AT_20 := 1.55
const SPEED_AT_50 := 2.20
const SPEED_CAP := 2.65
const SPEED_EASE_SECONDS := 20.0
const SPEED_STEEP_SECONDS := 30.0
const SPEED_CAP_SECONDS := 40.0

const SCROLL_AT_45 := 1.18
const SCROLL_CAP := 1.30
const SCROLL_RAMP_SECONDS := 45.0
const SCROLL_CAP_SECONDS := 75.0

## Aimed from the opening. 1 is a full lead.
const AIM_START := 0.82
const AIM_ARM_SECONDS := 0.0
const AIM_FULL_SECONDS := 12.0

const WOLF_CHASE_START := 0.42
const WOLF_CHASE_FULL := 0.92
const WOLF_CHASE_RAMP_SECONDS := 14.0

const HAZARD_WARN := 0.4
const ANVIL_FALL := 110.0
const PIANO_FALL := 74.0
const HAZARD_START_SECONDS := 5.0
const HAZARD_RAMP_SECONDS := 28.0

## Anything at least this fast draws a telegraph before the projectile exists.
const FAST_SHOT := 165.0
const FAST_TELEGRAPH := 0.30
const SHOT_TELEGRAPH := 0.20

const GRAZE_BASE := 25
const GRAZE_RANK2 := 55
const RANK2_KILL_KEEP := 0.40
const RANK2_CHAIN_WEIGHT := 0.45

## Gem points, not kill score. Two gems reach rank 2. Seven reach rank 3.
## Both stay above the flappy rank-2 gate (640).
const GATE_RANK2 := 900
const GATE_RANK3 := 9000
const GEM_EVO := 450
const GEM_SCORE := 40
const GEM_CHANCE := 0.8
const GEM_LIFE := 3.05
const GEM_DRIFT := 36.0

## Goblin loot trait. Applied only in the default game.
const GOBLIN_MAGNET := 26.0
const GOBLIN_MAGNET_SPEED := 90.0

const POWER_CHANCE := 0.065
const POWER_LIFE := 3.1
const POWER_DRIFT := 26.0
const POWER_DURATION := 5.0
const RAPID_FIRE_SCALE := 0.48
const MAGNET_RADIUS := 168.0
const MAGNET_SPEED := 240.0
const BOMB_DAMAGE := 8
const BOMB_SCORE := 400
const SHIELD_IFRAMES := 0.22

const OVERDRIVE_GEMS := 4
const OVERDRIVE_SCORE := 2500

## Full-height rake. The gap starts wide enough to reach and closes
## until a body no longer fits, so a perfect dodge still ends the run.
const RAKE_FIRST := 3.4
const RAKE_GAP_START := 120.0
const RAKE_GAP_END := 28.0
const RAKE_GAP_SECONDS := 22.0
const RAKE_SPEED_START := 142.0
const RAKE_SPEED_END := 220.0
const RAKE_EVERY_START := 3.5
const RAKE_EVERY_END := 2.15
const RAKE_SHIFT := 78.0

const FINAL_HOLD := 1.85
const FINAL_SLOWMO_SECONDS := 0.3
const FINAL_SLOWMO_SCALE := 0.4
const FINAL_SHAKE_SECONDS := 0.38
const FINAL_SHAKE_PX := 3.0
const FINAL_STING_DB := 6.0

const POPUP_MIN := 200
const POPUP_LIFE := 0.32
const MAX_FX := 18

const LEGACY_FIRST_SPAWN := 0.72
const LEGACY_SPAWN_START := 1.85
const LEGACY_SPAWN_AT_20 := 1.45
const LEGACY_SPAWN_AT_50 := 0.52
const LEGACY_SPAWN_FLOOR := 0.36
const LEGACY_SPEED_AT_20 := 1.20
const LEGACY_SPEED_AT_50 := 1.95
const LEGACY_SPEED_CAP := 2.40
const LEGACY_AIM_START := 0.18
const LEGACY_AIM_ARM := 8.0
const LEGACY_AIM_FULL := 36.0
const LEGACY_WOLF_ARM := 16.0
const LEGACY_WOLF_START := 0.35
const LEGACY_WOLF_FULL := 0.85
const LEGACY_WOLF_RAMP := 20.0
const LEGACY_BURST_PAIR_AFTER := 15.0
const LEGACY_BURST_TRIPLE_AFTER := 32.0
const LEGACY_BURST_PAIR := 0.62
const LEGACY_BURST_TRIPLE := 0.38
const LEGACY_HAZARD_START := 8.0
const LEGACY_HAZARD_RAMP := 42.0
const LEGACY_HAZARD_WARN := 0.4
const LEGACY_ANVIL_FALL := 96.0
const LEGACY_PIANO_FALL := 62.0

static func _flappy() -> bool:
	return FlappyMode.is_active()

static func first_spawn() -> float:
	if _flappy():
		return LEGACY_FIRST_SPAWN
	return FIRST_SPAWN

static func spawn_interval(elapsed: float) -> float:
	if _flappy():
		return _legacy_spawn_interval(elapsed)
	if elapsed <= SPAWN_EASE_SECONDS:
		return lerpf(SPAWN_INTERVAL_START, SPAWN_INTERVAL_AT_20, clampf(elapsed / SPAWN_EASE_SECONDS, 0.0, 1.0))
	if elapsed <= SPAWN_EASE_SECONDS + SPAWN_STEEP_SECONDS:
		var u := clampf((elapsed - SPAWN_EASE_SECONDS) / SPAWN_STEEP_SECONDS, 0.0, 1.0)
		return lerpf(SPAWN_INTERVAL_AT_20, SPAWN_INTERVAL_AT_50, u)
	var extra := clampf((elapsed - SPAWN_EASE_SECONDS - SPAWN_STEEP_SECONDS) / SPAWN_FLOOR_SECONDS, 0.0, 1.0)
	return lerpf(SPAWN_INTERVAL_AT_50, SPAWN_INTERVAL_FLOOR, extra)

static func speed_scale(elapsed: float) -> float:
	if _flappy():
		return _legacy_speed_scale(elapsed)
	if elapsed <= SPEED_EASE_SECONDS:
		return lerpf(1.0, SPEED_AT_20, clampf(elapsed / SPEED_EASE_SECONDS, 0.0, 1.0))
	if elapsed <= SPEED_EASE_SECONDS + SPEED_STEEP_SECONDS:
		var u := clampf((elapsed - SPEED_EASE_SECONDS) / SPEED_STEEP_SECONDS, 0.0, 1.0)
		return lerpf(SPEED_AT_20, SPEED_AT_50, u)
	var extra := clampf((elapsed - SPEED_EASE_SECONDS - SPEED_STEEP_SECONDS) / SPEED_CAP_SECONDS, 0.0, 1.0)
	return lerpf(SPEED_AT_50, SPEED_CAP, extra)

static func scroll_scale(elapsed: float) -> float:
	if elapsed <= SCROLL_RAMP_SECONDS:
		return lerpf(1.0, SCROLL_AT_45, clampf(elapsed / SCROLL_RAMP_SECONDS, 0.0, 1.0))
	var extra := clampf((elapsed - SCROLL_RAMP_SECONDS) / SCROLL_CAP_SECONDS, 0.0, 1.0)
	return lerpf(SCROLL_AT_45, SCROLL_CAP, extra)

static func aim_amount(elapsed: float) -> float:
	if _flappy():
		if elapsed < LEGACY_AIM_ARM:
			return LEGACY_AIM_START
		var legacy_u := clampf((elapsed - LEGACY_AIM_ARM) / LEGACY_AIM_FULL, 0.0, 1.0)
		return lerpf(LEGACY_AIM_START, 1.0, legacy_u)
	if elapsed < AIM_ARM_SECONDS:
		return AIM_START
	var u := clampf((elapsed - AIM_ARM_SECONDS) / AIM_FULL_SECONDS, 0.0, 1.0)
	return lerpf(AIM_START, 1.0, u)

static func wolf_chase(elapsed: float) -> float:
	if _flappy():
		if elapsed < LEGACY_WOLF_ARM:
			return 0.0
		var legacy_u := clampf((elapsed - LEGACY_WOLF_ARM) / LEGACY_WOLF_RAMP, 0.0, 1.0)
		return lerpf(LEGACY_WOLF_START, LEGACY_WOLF_FULL, legacy_u)
	var u := clampf(elapsed / WOLF_CHASE_RAMP_SECONDS, 0.0, 1.0)
	return lerpf(WOLF_CHASE_START, WOLF_CHASE_FULL, u)

static func burst_count(elapsed: float, roll: float) -> int:
	if _flappy():
		if elapsed < LEGACY_BURST_PAIR_AFTER or roll > LEGACY_BURST_PAIR:
			return 1
		if elapsed >= LEGACY_BURST_TRIPLE_AFTER and roll < LEGACY_BURST_PAIR * LEGACY_BURST_TRIPLE:
			return 3
		return 2
	if elapsed < BURST_PAIR_AFTER or roll > BURST_PAIR_CHANCE:
		return 1
	if elapsed >= BURST_TRIPLE_AFTER and roll < BURST_PAIR_CHANCE * BURST_TRIPLE_CHANCE:
		return 3
	return 2

static func kind_weights(elapsed: float) -> Array[float]:
	if _flappy():
		return _legacy_kind_weights(elapsed)
	var pace := clampf(elapsed / 22.0, 0.0, 1.0)
	var hazard := clampf((elapsed - HAZARD_START_SECONDS) / HAZARD_RAMP_SECONDS, 0.0, 1.0)
	var wyvern := clampf((elapsed - 6.5) / 12.0, 0.0, 1.0)
	return [
		lerpf(0.46, 0.22, pace),
		lerpf(0.24, 0.18, pace),
		lerpf(0.30, 0.20, pace),
		lerpf(0.00, 0.16, pace) * wyvern,
		lerpf(0.00, 0.14, hazard),
		lerpf(0.00, 0.10, hazard),
	]

static func fall_speed(kind: int) -> float:
	if _flappy():
		if kind == SpawnDirector.PIANO:
			return LEGACY_PIANO_FALL
		return LEGACY_ANVIL_FALL
	if kind == SpawnDirector.PIANO:
		return PIANO_FALL
	return ANVIL_FALL

static func hazard_warn() -> float:
	if _flappy():
		return LEGACY_HAZARD_WARN
	return HAZARD_WARN

static func graze_points(rank_index: int) -> int:
	if rank_index >= 1:
		return GRAZE_RANK2
	return GRAZE_BASE

static func kill_multiplier(combo: int, rank_index: int) -> float:
	var step := maxi(combo, 1)
	if rank_index < 1:
		return float(step)
	return RANK2_KILL_KEEP + float(step - 1) * RANK2_CHAIN_WEIGHT

static func gates() -> Array[int]:
	return [GATE_RANK2, GATE_RANK3]

## Y offsets for an aimed fan. Early fans cover a parked lane.
## Later fans reach both edges of the 270-tall field.
static func fan_offsets(elapsed: float) -> Array:
	# One aimed shot while the run is young. The -54 fork is the average
	# bot's tie-break juke. Later fans close the open side.
	if elapsed < 16.0:
		return [0.0]
	if elapsed < 20.0:
		return [0.0, -54.0]
	return [-84.0, 0.0, 84.0]

static func pattern_speed(kind: int, elapsed: float) -> float:
	var base := 90.0
	if kind == SpawnDirector.ARCHER:
		base = 142.0
	elif kind == SpawnDirector.WYVERN:
		base = 118.0
	elif kind == SpawnDirector.EYE:
		base = 102.0
	var climb := lerpf(1.0, 1.55, clampf(elapsed / 18.0, 0.0, 1.0))
	return base * climb * speed_scale(elapsed)

static func telegraph_for(speed: float) -> float:
	if speed >= FAST_SHOT:
		return FAST_TELEGRAPH
	return SHOT_TELEGRAPH

static func rake_gap(elapsed: float) -> float:
	var u := clampf(elapsed / RAKE_GAP_SECONDS, 0.0, 1.0)
	return lerpf(RAKE_GAP_START, RAKE_GAP_END, u)

static func rake_speed(elapsed: float) -> float:
	var u := clampf(elapsed / RAKE_GAP_SECONDS, 0.0, 1.0)
	return lerpf(RAKE_SPEED_START, RAKE_SPEED_END, u)

static func rake_every(elapsed: float) -> float:
	var u := clampf(elapsed / RAKE_GAP_SECONDS, 0.0, 1.0)
	return lerpf(RAKE_EVERY_START, RAKE_EVERY_END, u)

static func _legacy_spawn_interval(elapsed: float) -> float:
	if elapsed <= 20.0:
		return lerpf(LEGACY_SPAWN_START, LEGACY_SPAWN_AT_20, clampf(elapsed / 20.0, 0.0, 1.0))
	if elapsed <= 50.0:
		var u := clampf((elapsed - 20.0) / 30.0, 0.0, 1.0)
		return lerpf(LEGACY_SPAWN_AT_20, LEGACY_SPAWN_AT_50, u)
	var extra := clampf((elapsed - 50.0) / 40.0, 0.0, 1.0)
	return lerpf(LEGACY_SPAWN_AT_50, LEGACY_SPAWN_FLOOR, extra)

static func _legacy_speed_scale(elapsed: float) -> float:
	if elapsed <= 20.0:
		return lerpf(1.0, LEGACY_SPEED_AT_20, clampf(elapsed / 20.0, 0.0, 1.0))
	if elapsed <= 50.0:
		var u := clampf((elapsed - 20.0) / 30.0, 0.0, 1.0)
		return lerpf(LEGACY_SPEED_AT_20, LEGACY_SPEED_AT_50, u)
	var extra := clampf((elapsed - 50.0) / 40.0, 0.0, 1.0)
	return lerpf(LEGACY_SPEED_AT_50, LEGACY_SPEED_CAP, extra)

static func _legacy_kind_weights(elapsed: float) -> Array[float]:
	var pace := clampf(elapsed / 60.0, 0.0, 1.0)
	var hazard := clampf((elapsed - LEGACY_HAZARD_START) / LEGACY_HAZARD_RAMP, 0.0, 1.0)
	var wyvern := clampf((elapsed - 8.0) / 18.0, 0.0, 1.0)
	return [
		lerpf(0.70, 0.16, pace),
		lerpf(0.10, 0.16, pace),
		lerpf(0.20, 0.16, pace),
		lerpf(0.00, 0.15, pace) * wyvern,
		lerpf(0.00, 0.22, hazard),
		lerpf(0.00, 0.16, hazard),
	]
