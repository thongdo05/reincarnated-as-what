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
