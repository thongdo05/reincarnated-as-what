extends RefCounted
class_name ScoreRules

## Skill-only score. No form multiplier.
const GRAZE := 25
const SURVIVAL_PER_SECOND := 10
const COMBO_WINDOW := 1.55
const COMBO_CAP := 8

## rank_index 0 is the opening form. Rank 2 (index 1) and rank 3 weigh combo
## steps above x1 by Difficulty.RANK2_COMBO_WEIGHT. A lone kill stays x1.
static func on_kill(base: int, combo: int, combo_left: float, rank_index: int = 0) -> Dictionary:
	var next_combo := 1
	if combo_left > 0.0:
		next_combo = mini(combo + 1, COMBO_CAP)
	var multiplier := Difficulty.kill_multiplier(next_combo, rank_index)
	return {
		"points": int(round(float(base) * multiplier)),
		"combo": next_combo,
		"combo_left": COMBO_WINDOW,
	}

static func graze_points(rank_index: int) -> int:
	return Difficulty.graze_points(rank_index)

static func format_time(seconds: float) -> String:
	var total := maxi(int(floor(seconds)), 0)
	return "%d:%02d" % [int(total / 60.0), total % 60]

## Live SQL rejects a submit when score > 50000 + survival_ms * 10.
static func server_score_cap(survival_ms: int) -> int:
	return 50000 + survival_ms * 10

## Points in `seconds` if a rank-5 vending run kills every spawned enemy.
## Combo is capped, bodies are priced as archers (the best non-heavy), and
## each kill also pays the rank-5 WINNER share, a gem, and a graze.
## Power and the final form add no score of their own.
static func vending_clear_score(seconds: float) -> int:
	var elapsed := maxf(seconds, 0.0)
	var mult := Difficulty.kill_multiplier(COMBO_CAP, 1)
	var per_kill := 220.0 * mult + 2000.0 / 3.0 + Difficulty.GEM_CHANCE * float(Difficulty.GEM_SCORE) + float(Difficulty.GRAZE_RANK2)
	var total := 0.0
	var whole := int(ceil(elapsed))
	for second in whole:
		var at := float(second)
		var dt := 1.0
		if at + 1.0 > elapsed:
			dt = elapsed - at
		if dt <= 0.0:
			continue
		var gap := Difficulty.spawn_interval(at)
		if gap <= 0.0:
			continue
		var kills := _expected_burst(at) / gap * dt
		total += kills * per_kill + dt * float(SURVIVAL_PER_SECOND)
	if elapsed > 0.0:
		var overdrives: float = 1.0 + floor(elapsed / Difficulty.OVERDRIVE_DROP_COOLDOWN)
		total += overdrives * float(Difficulty.OVERDRIVE_SCORE)
	return int(floor(total))

static func _expected_burst(elapsed: float) -> float:
	var total := 0.0
	var steps := 200
	for i in steps:
		total += float(Difficulty.burst_count(elapsed, (float(i) + 0.5) / float(steps)))
	return total / float(steps)

static func format_score(value: int) -> String:
	var sign := ""
	var number := value
	if number < 0:
		sign = "-"
		number = -number
	var digits := str(number)
	var parts: PackedStringArray = []
	while digits.length() > 3:
		parts.insert(0, digits.substr(digits.length() - 3, 3))
		digits = digits.substr(0, digits.length() - 3)
	parts.insert(0, digits)
	return sign + ",".join(parts)

static func share_line(form_name: String, rank_name: String, seconds: float, killer: String, score: int) -> String:
	return "Reborn as %s, reached %s. Lasted %s. Died to a %s. Score %s." % [
		form_name,
		rank_name.to_upper(),
		format_time(seconds),
		killer,
		format_score(score),
	]
