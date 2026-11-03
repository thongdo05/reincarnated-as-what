extends RefCounted
class_name BossDirector

## Boss clock for one day. Times come only from the seed and elapsed time,
## plus the elapsed time of a dragon kill (the return is 60 s after that).
## Querying more or less often does not change who shows up.
##
## Lich King and Death Knight alternate from about 45 s, then about every 40 s.
## A slot that would still be on screen when the dragon arrives is skipped.
## The Great Dragon is not part of that cycle. The first one is about 2:30.
## It does not leave on a timer. After it dies, the cycle resumes, and the
## dragon returns 60 s later with a higher generation.

const FIRST := 45.0
const EVERY := 40.0
const LIFE := 25.0
const DRAGON_AT := 150.0
const DRAGON_RETURN := 60.0
const JITTER := 1.35
const OVERLAP_PAD := 0.85

var seed_value := 0
var next_regular := 0
var dragon_gen := 0
var dragon_at := DRAGON_AT
var _emitted_gen := -1
var _boss_alive := false

func _init(day_seed: int) -> void:
	seed_value = day_seed
	dragon_at = first_dragon_time(day_seed)

static func regular_time(day_seed: int, index: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed + 190047
	var jitter := 0.0
	for _i in index + 1:
		jitter = rng.randf_range(-JITTER, JITTER)
	return FIRST + float(index) * EVERY + jitter

static func first_dragon_time(day_seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed + 771903
	return DRAGON_AT + rng.randf_range(-1.2, 1.2)

static func regular_slug(index: int) -> String:
	return "lich_king" if index % 2 == 0 else "death_knight"

static func placement(day_seed: int, salt: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed + 440221 + salt * 97
	return {
		"hold_x": rng.randf_range(388.0, 428.0),
		"origin_y": rng.randf_range(78.0, 168.0),
		"phase": rng.randf() * TAU,
		"wave_amp": rng.randf_range(14.0, 24.0),
	}

func set_boss_alive(alive: bool) -> void:
	_boss_alive = alive

func on_dragon_killed(elapsed: float) -> void:
	dragon_gen += 1
	dragon_at = elapsed + DRAGON_RETURN

func pop_due(elapsed: float) -> Array[Dictionary]:
	# One boss at a time. While one is up, later regular slots are skipped so
	# they do not queue and arrive together when the fight ends.
	if _boss_alive:
		while regular_time(seed_value, next_regular) <= elapsed + 0.0001:
			next_regular += 1
		return []
	# Regulars whose time is before the dragon go out first, so a coarse poll
	# still meets the Lich / Knight that a per-frame poll would have spawned.
	while regular_time(seed_value, next_regular) <= elapsed + 0.0001 and regular_time(seed_value, next_regular) < dragon_at - 0.0001:
		var index := next_regular
		var at := regular_time(seed_value, index)
		next_regular += 1
		if _overlaps_dragon(at):
			continue
		return [_regular_event(index, at)]
	if elapsed + 0.0001 >= dragon_at and _emitted_gen != dragon_gen:
		_emitted_gen = dragon_gen
		return [_dragon_event()]
	return []

func _overlaps_dragon(at: float) -> bool:
	return at < dragon_at and at + LIFE + OVERLAP_PAD > dragon_at

func _regular_event(index: int, at: float) -> Dictionary:
	var slug := regular_slug(index)
	var spot := placement(seed_value, index + 1)
	spot["slug"] = slug
	spot["t"] = at
	spot["generation"] = 0
	spot["hold_x"] = BossCatalog.rest_x(slug)
	return spot

func _dragon_event() -> Dictionary:
	var spot := placement(seed_value, 9000 + dragon_gen)
	spot["slug"] = "great_dragon"
	spot["t"] = dragon_at
	spot["generation"] = dragon_gen
	spot["hold_x"] = BossCatalog.rest_x("great_dragon")
	return spot
