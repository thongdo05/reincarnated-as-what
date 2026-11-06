extends RefCounted
class_name DragonSpawnDirector

## Spawns for the post-dragon phase. The clock is seconds since the transform.
## A paused poll drops the beats it would have emitted instead of saving them
## up. The lair wipe uses that. The Great Dragon does not pause this clock.
## Kind caps use travel time, same as the daily director, so clearing a body
## early does not change the rest of the timeline.

var _rng := RandomNumberGenerator.new()
var _origin := 0.0
var _next_time := 0.0
var _active := false
var _busy: Array[Dictionary] = []

func _init(seed_value: int) -> void:
	_rng.seed = seed_value + 880221

func begin(run_elapsed: float) -> void:
	_active = true
	_origin = run_elapsed
	_next_time = DragonPhase.FIRST_SPAWN
	_busy.clear()

func arm_at(dragon_time: float) -> void:
	_active = true
	_next_time = dragon_time
	_busy.clear()

func pop_due(run_elapsed: float, paused: bool) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	if not _active:
		return due
	var dragon_time := run_elapsed - _origin
	if paused:
		if _next_time < dragon_time:
			_next_time = dragon_time
		return due
	var guard := 0
	while _next_time <= dragon_time + 0.0001 and guard < 24:
		guard += 1
		var at := _next_time
		_cull(at)
		var burst := 1
		if _rng.randf() < DragonPhase.burst_chance(at):
			burst = 2
		for _i in burst:
			due.append(_make(at))
		var gap := DragonPhase.spawn_interval(_origin + at, at)
		gap *= _rng.randf_range(DragonPhase.SPAWN_JITTER_MIN, DragonPhase.SPAWN_JITTER_MAX)
		_next_time = at + gap
	return due

func _make(at: float) -> Dictionary:
	var kind := _pick(at)
	var hold := DragonPhase.occupancy(kind)
	if hold > 0.0:
		_busy.append({"id": kind, "until": at + hold})
	return {
		"t": at,
		"dragon": true,
		"dragon_id": kind,
		"kind": kind,
		"hp_mul": DragonPhase.hp_mul(at),
		"x_ratio": _lane(kind),
		"phase": _rng.randf() * TAU,
		"stop_ratio": _rng.randf_range(0.22, 0.4),
		"wave_amp": _rng.randf_range(8.0, 18.0),
		"y_bias": _rng.randf_range(-12.0, 12.0),
	}

func _lane(kind: int) -> float:
	if kind == DragonPhase.EGG:
		return _rng.randf_range(0.58, 0.88)
	return _rng.randf_range(0.22, 0.82)

func _pick(at: float) -> int:
	var open := DragonPhase.unlocked(at)
	var kind := _roll(open)
	if _over_cap(kind, at):
		kind = DragonPhase.BAT
	return kind

func _roll(open: Array[int]) -> int:
	var total := 0.0
	for id in open:
		total += DragonPhase.weight(id)
	var roll := _rng.randf() * total
	var acc := 0.0
	for id in open:
		acc += DragonPhase.weight(id)
		if roll <= acc:
			return id
	return DragonPhase.BAT

func _over_cap(kind: int, at: float) -> bool:
	var cap := DragonPhase.cap_for(kind)
	if cap <= 0:
		return false
	return _count(kind, at) >= cap

func _count(kind: int, at: float) -> int:
	var count := 0
	for item in _busy:
		if int(item["id"]) == kind and float(item["until"]) > at:
			count += 1
	return count

func _cull(now: float) -> void:
	var still: Array[Dictionary] = []
	for item in _busy:
		if float(item["until"]) > now:
			still.append(item)
	_busy = still
