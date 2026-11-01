extends RefCounted
class_name HopBalance

## Tuning for the experimental hop mode only.
## The side-scroller keeps Difficulty.gates(). Rank 3 is a long shot inside a
## life that the hop bot measures in the 15–30 s band.

const TILE := 30.0
const COLS := 16
const ROWS := 9
const FIELD_W := 480.0
const FIELD_H := 270.0

const START_COL := 2
const START_ROW := 4

const HOP_SLIME := 0.10
const HOP_GOBLIN := 0.08
## Goblin is off the ground for this slice of the hop and clears bodies.
const GOBLIN_AIR_START := 0.15
const GOBLIN_AIR_END := 0.85

const OPEN_INVULN := 0.40
const SPLIT_IFRAMES := 0.85
const REGROW_SECONDS := 15.0

const GRACE := 1.15
const PRESSURE_MIN := 16.0
const PRESSURE_MAX := 38.0
const PRESSURE_RAMP := 32.0
const KILL_INSET := 12.0
## When the player sprints, the camera catches up so the next lanes stay on screen.
const CAM_MAX_LEAD := 336.0

const LANE_POINTS := 10

## Short grid ranges. Slime is a tight stream. Goblin reaches a lane farther.
const SLIME_SPEED := 220.0
const GOBLIN_SPEED := 200.0
const GOBLIN_GRAVITY := 80.0
const SLIME_RANGE := [70.0, 82.0, 96.0]
const GOBLIN_RANGE := [100.0, 118.0, 136.0]
const SLIME_FIRE := [0.30, 0.24, 0.19]
const GOBLIN_FIRE := [0.42, 0.34, 0.28]

## Skill gates for this mode. Not Difficulty.gates() (800 / 12000 on the road).
## Full-body shapes make rank 2 a bigger target, so the gate sits later than
## the side-scroller's 800. Rank 3 stays rare inside a 15–30 s life.
const GATE_RANK2 := 900
const GATE_RANK3 := 3400

const TITLE_SECONDS := 0.85
const DEATH_SECONDS := 0.34
const TEASE_SECONDS := 0.28
const CARD_SECONDS := 0.55

const CAP_SECONDS := 90.0

static func gates() -> Array[int]:
	return [GATE_RANK2, GATE_RANK3]

static func hop_seconds(form_id: int) -> float:
	if form_id == FormCatalog.Id.GOBLIN:
		return HOP_GOBLIN
	return HOP_SLIME

static func shot_speed(form_id: int) -> float:
	if form_id == FormCatalog.Id.GOBLIN:
		return GOBLIN_SPEED
	return SLIME_SPEED

static func shot_range(form_id: int, rank_index: int) -> float:
	var table: Array = GOBLIN_RANGE if form_id == FormCatalog.Id.GOBLIN else SLIME_RANGE
	return float(table[clampi(rank_index, 0, table.size() - 1)])

static func fire_interval(form_id: int, rank_index: int) -> float:
	var table: Array = GOBLIN_FIRE if form_id == FormCatalog.Id.GOBLIN else SLIME_FIRE
	return float(table[clampi(rank_index, 0, table.size() - 1)])

static func pressure_speed(elapsed: float) -> float:
	if elapsed < GRACE:
		return 0.0
	var along := clampf((elapsed - GRACE) / PRESSURE_RAMP, 0.0, 1.0)
	return lerpf(PRESSURE_MIN, PRESSURE_MAX, along)
