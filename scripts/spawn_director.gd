extends RefCounted
class_name SpawnDirector

## Enemy timeline for one day. Depends only on the seed and elapsed play time,
## never on how well the player is doing, so every run that day meets the same
## spawns. Querying more or less often does not change the timeline.

const WISP := 0
const DART := 1
const TURRET := 2
const FANG := 3

var _rng := RandomNumberGenerator.new()
var _next_time := 1.05

func _init(seed_value: int) -> void:
	_rng.seed = seed_value

func pop_due(elapsed: float) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	while _next_time <= elapsed:
		var at := _next_time
		due.append(_make(at))
		var diff := clampf(at / 80.0, 0.0, 1.0)
		if diff > 0.4 and _rng.randf() < lerpf(0.0, 0.55, diff):
			due.append(_make(at + 0.1))
		var gap := lerpf(1.22, 0.44, diff) * _rng.randf_range(0.84, 1.12)
		_next_time = at + gap
	return due

func _make(at: float) -> Dictionary:
	var diff := clampf(at / 80.0, 0.0, 1.0)
	return {
		"t": at,
		"kind": _pick(diff),
		"x_ratio": _rng.randf_range(0.16, 0.84),
		"phase": _rng.randf() * TAU,
		"stop_ratio": _rng.randf_range(0.20, 0.36),
	}

func _pick(diff: float) -> int:
	var weights: Array[float] = [
		lerpf(0.68, 0.20, diff),
		lerpf(0.26, 0.30, diff),
		lerpf(0.06, 0.28, diff),
		lerpf(0.00, 0.22, diff),
	]
	var total := 0.0
	for weight in weights:
		total += weight
	var roll := _rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if roll <= acc:
			return i
	return WISP

static func kind_name(kind: int) -> String:
	match kind:
		WISP:
			return "Wisp"
		DART:
			return "Dart"
		TURRET:
			return "Turret"
		FANG:
			return "Fang"
		_:
			return "Thing"

static func max_hp(kind: int) -> int:
	match kind:
		TURRET:
			return 6
		FANG:
			return 3
		_:
			return 2

static func score_value(kind: int) -> int:
	match kind:
		WISP:
			return 100
		DART:
			return 150
		TURRET:
			return 220
		FANG:
			return 260
		_:
			return 50

static func body_radius(kind: int) -> float:
	match kind:
		WISP:
			return 13.0
		DART:
			return 12.0
		TURRET:
			return 16.0
		FANG:
			return 12.0
		_:
			return 12.0

static func fall_speed(kind: int) -> float:
	match kind:
		WISP:
			return 74.0
		DART:
			return 158.0
		TURRET:
			return 56.0
		FANG:
			return 30.0
		_:
			return 80.0
