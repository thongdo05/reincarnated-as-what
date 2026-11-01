extends RefCounted
class_name SpawnDirector

## Enemy timeline for one day. Depends only on the seed and elapsed play time,
## never on how well the player is doing, so every run that day meets the same
## spawns. Querying more or less often does not change the timeline.
##
## Dire wolves and wyverns share a cap of 2 on screen. The cap uses travel time,
## not live kills, so a player who clears them early does not get a different timeline.

const EYE := 0
const WOLF := 1
const ARCHER := 2
const WYVERN := 3
const ANVIL := 4
const PIANO := 5

const HEAVY_CAP := 2
const BODY_PCT := 0.55
const HAZARD_PCT := 0.60

var _rng := RandomNumberGenerator.new()
var _next_time := 1.45
var _heavy_until: Array[float] = []
var max_heavies := 0

func _init(seed_value: int) -> void:
	_rng.seed = seed_value

func pop_due(elapsed: float) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	while _next_time <= elapsed:
		var at := _next_time
		due.append(_make(at))
		var diff := clampf(at / 80.0, 0.0, 1.0)
		if diff > 0.55 and _rng.randf() < lerpf(0.0, 0.28, diff):
			due.append(_make(at + 0.18))
		# Wider gaps than the old 780-wide field. The sprites are bigger and slower.
		var gap := lerpf(1.85, 1.05, diff) * _rng.randf_range(0.90, 1.14)
		_next_time = at + gap
	return due

func _make(at: float) -> Dictionary:
	_cull_heavies(at)
	var diff := clampf(at / 80.0, 0.0, 1.0)
	var kind := _pick(diff)
	if _is_heavy(kind) and _heavy_until.size() >= HEAVY_CAP:
		kind = EYE if kind == WOLF else ARCHER
	if _is_heavy(kind):
		_heavy_until.append(at + _heavy_life(kind))
		max_heavies = maxi(max_heavies, _heavy_until.size())
	return {
		"t": at,
		"kind": kind,
		"x_ratio": _rng.randf_range(0.16, 0.84),
		"phase": _rng.randf() * TAU,
		"stop_ratio": _rng.randf_range(0.20, 0.36),
	}

func _pick(diff: float) -> int:
	# Hazards stay out of the opening so the first seconds are the four creatures.
	var late := clampf((diff - 0.12) / 0.88, 0.0, 1.0)
	var wyvern_in := clampf((diff - 0.08) / 0.25, 0.0, 1.0)
	var weights: Array[float] = [
		lerpf(0.64, 0.20, diff),
		lerpf(0.24, 0.20, diff),
		lerpf(0.12, 0.22, diff),
		lerpf(0.00, 0.18, diff) * wyvern_in,
		lerpf(0.00, 0.12, late),
		lerpf(0.00, 0.08, late),
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
	return EYE

func _cull_heavies(now: float) -> void:
	var still: Array[float] = []
	for until in _heavy_until:
		if until > now:
			still.append(until)
	_heavy_until = still

func _is_heavy(kind: int) -> bool:
	return kind == WOLF or kind == WYVERN

func _heavy_life(kind: int) -> float:
	# Spawn pad + field + the margin where the sweeper drops them.
	var travel := 480.0 + body_radius(kind) + 20.0 + 80.0
	return travel / cruise_speed(kind)

static func sprite_for(kind: int) -> String:
	match kind:
		EYE:
			return "floating_eye.png"
		WOLF:
			return "dire_wolf.png"
		ARCHER:
			return "skeleton_archer.png"
		WYVERN:
			return "wyvern.png"
		ANVIL:
			return "anvil.png"
		PIANO:
			return "piano.png"
		_:
			return "floating_eye.png"

static func kind_name(kind: int) -> String:
	match kind:
		EYE:
			return "Floating Eye"
		WOLF:
			return "Dire Wolf"
		ARCHER:
			return "Skeleton Archer"
		WYVERN:
			return "Wyvern"
		ANVIL:
			return "falling anvil"
		PIANO:
			return "falling piano"
		_:
			return "Thing"

static func max_hp(kind: int) -> int:
	match kind:
		ARCHER:
			return 6
		WYVERN:
			return 3
		ANVIL:
			return 4
		PIANO:
			return 6
		_:
			return 2

static func score_value(kind: int) -> int:
	match kind:
		EYE:
			return 100
		WOLF:
			return 150
		ARCHER:
			return 220
		WYVERN:
			return 260
		ANVIL:
			return 80
		PIANO:
			return 160
		_:
			return 50

static func body_radius(kind: int) -> float:
	var pct := HAZARD_PCT if kind == ANVIL or kind == PIANO else BODY_PCT
	return ArtLibrary.radius_for(sprite_for(kind), pct)

static func cruise_speed(kind: int) -> float:
	# Tuned for a 480-wide field and sprites up to 64px. The wolf is still the charger.
	match kind:
		EYE:
			return 34.0
		WOLF:
			return 72.0
		ARCHER:
			return 48.0
		WYVERN:
			return 54.0
		_:
			return 40.0
