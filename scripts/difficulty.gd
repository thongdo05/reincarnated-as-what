extends RefCounted
class_name Difficulty

## One place for the pacing numbers. Comments keep the previous main values
## (d9a9416) so a later pass can see what moved.
##
## Before:
## - first enemy at 1.45 s
## - spawn gap lerped from 1.85 s to 1.05 s across 80 s, times a 0.90–1.14 roll
## - a second spawn only after 44 s, and only sometimes
## - enemy and shot speeds stayed at their base (eye 34, wolf 72, archer 48,
##   wyvern 54, eye bolt 88, arrow 116, wyvern shot 104)
## - scroll stayed at 28 px/s on the near layer
## - anvil drift 16 px/s and fall 96, piano drift 12 and fall 62, no warning
## - hazards were a small late weight (anvil 0.12, piano 0.08 at the 80 s cap)
## - shots flew flat, the wolf held its lane, wyverns shared one wave height
## - evolve gates [500, 1500]
## - graze 25, kill score = base * combo, same at every rank

## Opening spawn. Was 1.45 s. Inside the first second, not on the first frame.
const FIRST_SPAWN := 0.72

## Gap before the small roll. Was a lerp of 1.85 → 1.05 over 80 s.
## Now the center of that gap is 35% of the start by 60 s, then eases toward
## a floor so the ramp does not go to zero.
const SPAWN_INTERVAL_START := 1.85
const SPAWN_INTERVAL_60_SCALE := 0.35
const SPAWN_INTERVAL_FLOOR_SCALE := 0.22
const SPAWN_RAMP_SECONDS := 60.0
const SPAWN_FLOOR_SECONDS := 90.0
const SPAWN_JITTER_MIN := 0.92
const SPAWN_JITTER_MAX := 1.08

## Extra bodies in the same beat. Was a 0–28% chance of one extra after 44 s.
const BURST_PAIR_AFTER := 15.0
const BURST_TRIPLE_AFTER := 32.0
const BURST_PAIR_CHANCE := 0.62
const BURST_TRIPLE_CHANCE := 0.38

## Speed of enemies and their shots. Was a flat 1.
const SPEED_AT_60 := 1.6
const SPEED_CAP := 2.05
const SPEED_RAMP_SECONDS := 60.0
const SPEED_CAP_SECONDS := 90.0

## Near-layer scroll. 1.0 is the old 28 px/s. 1.3 by 45 s, then a low cap.
const SCROLL_AT_45 := 1.3
const SCROLL_CAP := 1.42
const SCROLL_RAMP_SECONDS := 45.0
const SCROLL_CAP_SECONDS := 75.0

## How hard shots bend toward a predicted point. 1 is a full lead.
## Flat shots until the arm time, then a ramp. A player who only drifts
## gets through the opening and starts dying once the shots bend.
const AIM_START := 0.18
const AIM_ARM_SECONDS := 8.0
const AIM_FULL_SECONDS := 36.0

## Share of the wolf's speed spent matching the player's Y. Was 0 (it held a lane).
const WOLF_CHASE_ARM_SECONDS := 16.0
const WOLF_CHASE_START := 0.35
const WOLF_CHASE_FULL := 0.85
const WOLF_CHASE_RAMP_SECONDS := 20.0

## Falling hazards. Drift was 16 and 12; it is 0 so the shadow is the landing column.
const HAZARD_WARN := 0.4
const ANVIL_FALL := 96.0
const PIANO_FALL := 62.0
const HAZARD_START_SECONDS := 8.0
const HAZARD_RAMP_SECONDS := 42.0

## Skill points. Rank 1 (the opening form) keeps base * combo, graze 25.
## At rank 2 and after, a raw kill is throttled and the chain above x1 is what
## fills the meter, along with a richer near-miss. Sitting on x1 kills crawls.
## A combo still cannot run away: the chain term is a fraction of the base,
## not a second full multiplier. Survival points still do not fill the meter.
const GRAZE_BASE := 25
const GRAZE_RANK2 := 55
const RANK2_KILL_KEEP := 0.40
const RANK2_CHAIN_WEIGHT := 0.45

## Cumulative skill points. Was [500, 1500].
## Rank 2 stays near the measured 20–30 s crossings on the headless bots.
## Rank 3 sits above every measured run (best was 6442 points): a hot combo
## streak can reach it a little after a minute, a normal chain closer to 80 s.
const GATE_RANK2 := 2200
const GATE_RANK3 := 12000

## Rank 3 moment. The rank 2 evolve is unchanged (1 s hold, no punch).
const FINAL_HOLD := 1.85
const FINAL_SLOWMO_SECONDS := 0.3
const FINAL_SLOWMO_SCALE := 0.4
const FINAL_SHAKE_SECONDS := 0.38
const FINAL_SHAKE_PX := 3.0
const FINAL_STING_DB := 6.0

static func spawn_interval(elapsed: float) -> float:
	var start := SPAWN_INTERVAL_START
	var at_60 := start * SPAWN_INTERVAL_60_SCALE
	var floor_gap := start * SPAWN_INTERVAL_FLOOR_SCALE
	if elapsed <= SPAWN_RAMP_SECONDS:
		return lerpf(start, at_60, clampf(elapsed / SPAWN_RAMP_SECONDS, 0.0, 1.0))
	var extra := clampf((elapsed - SPAWN_RAMP_SECONDS) / SPAWN_FLOOR_SECONDS, 0.0, 1.0)
	return lerpf(at_60, floor_gap, extra)

static func speed_scale(elapsed: float) -> float:
	if elapsed <= SPEED_RAMP_SECONDS:
		return lerpf(1.0, SPEED_AT_60, clampf(elapsed / SPEED_RAMP_SECONDS, 0.0, 1.0))
	var extra := clampf((elapsed - SPEED_RAMP_SECONDS) / SPEED_CAP_SECONDS, 0.0, 1.0)
	return lerpf(SPEED_AT_60, SPEED_CAP, extra)

static func scroll_scale(elapsed: float) -> float:
	if elapsed <= SCROLL_RAMP_SECONDS:
		return lerpf(1.0, SCROLL_AT_45, clampf(elapsed / SCROLL_RAMP_SECONDS, 0.0, 1.0))
	var extra := clampf((elapsed - SCROLL_RAMP_SECONDS) / SCROLL_CAP_SECONDS, 0.0, 1.0)
	return lerpf(SCROLL_AT_45, SCROLL_CAP, extra)

static func aim_amount(elapsed: float) -> float:
	if elapsed < AIM_ARM_SECONDS:
		return AIM_START
	var u := clampf((elapsed - AIM_ARM_SECONDS) / AIM_FULL_SECONDS, 0.0, 1.0)
	return lerpf(AIM_START, 1.0, u)

static func wolf_chase(elapsed: float) -> float:
	if elapsed < WOLF_CHASE_ARM_SECONDS:
		return 0.0
	var u := clampf((elapsed - WOLF_CHASE_ARM_SECONDS) / WOLF_CHASE_RAMP_SECONDS, 0.0, 1.0)
	return lerpf(WOLF_CHASE_START, WOLF_CHASE_FULL, u)

## 1, 2, or 3 spawns sharing this timestamp. roll is 0..1 from the run rng.
static func burst_count(elapsed: float, roll: float) -> int:
	if elapsed < BURST_PAIR_AFTER or roll > BURST_PAIR_CHANCE:
		return 1
	if elapsed >= BURST_TRIPLE_AFTER and roll < BURST_PAIR_CHANCE * BURST_TRIPLE_CHANCE:
		return 3
	return 2

static func kind_weights(elapsed: float) -> Array[float]:
	var pace := clampf(elapsed / SPAWN_RAMP_SECONDS, 0.0, 1.0)
	var hazard := clampf((elapsed - HAZARD_START_SECONDS) / HAZARD_RAMP_SECONDS, 0.0, 1.0)
	# Wyverns stay out of the first 1.2 s. The old "no immediate fang" check
	# still holds, and the opening pressure is the eye, the wolf, and the archer.
	var wyvern := clampf((elapsed - 8.0) / 18.0, 0.0, 1.0)
	return [
		lerpf(0.70, 0.16, pace),
		lerpf(0.10, 0.16, pace),
		lerpf(0.20, 0.16, pace),
		lerpf(0.00, 0.15, pace) * wyvern,
		lerpf(0.00, 0.22, hazard),
		lerpf(0.00, 0.16, hazard),
	]

static func fall_speed(kind: int) -> float:
	if kind == SpawnDirector.PIANO:
		return PIANO_FALL
	return ANVIL_FALL

static func graze_points(rank_index: int) -> int:
	if rank_index >= 1:
		return GRAZE_RANK2
	return GRAZE_BASE

## Opening form: base * combo. Rank 2+: a throttled kill plus credit for each
## combo step above x1. Near-misses are separate, in graze_points.
static func kill_multiplier(combo: int, rank_index: int) -> float:
	var step := maxi(combo, 1)
	if rank_index < 1:
		return float(step)
	return RANK2_KILL_KEEP + float(step - 1) * RANK2_CHAIN_WEIGHT

static func gates() -> Array[int]:
	return [GATE_RANK2, GATE_RANK3]
