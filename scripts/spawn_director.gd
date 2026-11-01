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

var _rng := RandomNumberGenerator.new()
var _next_time := Difficulty.FIRST_SPAWN
var _heavy_until: Array[float] = []
var max_heavies := 0

func _init(seed_value: int) -> void:
	_rng.seed = seed_value

func pop_due(elapsed: float) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	while _next_time <= elapsed:
		var at := _next_time
		var burst := Difficulty.burst_count(at, _rng.randf())
		for _i in burst:
			due.append(_make(at))
		var gap := Difficulty.spawn_interval(at) * _rng.randf_range(Difficulty.SPAWN_JITTER_MIN, Difficulty.SPAWN_JITTER_MAX)
		_next_time = at + gap
	return due

func _make(at: float) -> Dictionary:
	_cull_heavies(at)
	var kind := _pick(at)
	if _is_heavy(kind) and _heavy_until.size() >= HEAVY_CAP:
		kind = EYE if kind == WOLF else ARCHER
	if _is_heavy(kind):
		_heavy_until.append(at + _heavy_life(kind, at))
		max_heavies = maxi(max_heavies, _heavy_until.size())
	var y_bias := 0.0
	var wave_amp := 8.0
	if kind == WYVERN:
		y_bias = _rng.randf_range(-46.0, 46.0)
		wave_amp = _rng.randf_range(8.0, 32.0)
	elif kind == EYE:
		y_bias = _rng.randf_range(-16.0, 16.0)
		wave_amp = _rng.randf_range(5.0, 14.0)
	return {
		"t": at,
		"kind": kind,
		"x_ratio": _rng.randf_range(0.16, 0.84),
		"phase": _rng.randf() * TAU,
		"stop_ratio": _rng.randf_range(0.20, 0.36),
		"y_bias": y_bias,
		"wave_amp": wave_amp,
	}

func _pick(diff: float) -> int:
	var weights := Difficulty.kind_weights(diff)
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

func _heavy_life(kind: int, at: float) -> float:
	# Spawn pad + field + the margin where the sweeper drops them.
	# Faster runs clear the cap sooner, so a cleared wolf does not hold a slot.
	var travel := 480.0 + body_radius(kind) + 20.0 + 80.0
	return travel / (cruise_speed(kind) * Difficulty.speed_scale(at))

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
	return HitLibrary.bounds_radius(sprite_for(kind), "body")

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
