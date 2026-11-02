extends RefCounted
class_name Difficulty

## Pacing for the drag shooter.
##
## The first ten seconds are the old short curve, the one that kills an
## average dodge in 5–10 s. After that the field climbs smoothly and is
## extremely hard at 3:00. Past 3:00 it holds, with at most a tiny creep.
## Rake and fan gaps stay wider than every hurtbox, aimed shots stay
## telegraphed, and enemy and bullet counts stay capped.

const FIRST_SPAWN := 0.34

const SPAWN_INTERVAL_START := 0.78
const SPAWN_INTERVAL_AT_20 := 0.40
const SPAWN_INTERVAL_AT_50 := 0.34
const SPAWN_INTERVAL_PEAK := 0.32
const SPAWN_INTERVAL_FLOOR := 0.30
const SPAWN_EASE_SECONDS := 20.0
const SPAWN_PEAK_SECONDS := 60.0
const SPAWN_CREEP_SECONDS := 240.0
const SPAWN_JITTER_MIN := 0.94
const SPAWN_JITTER_MAX := 1.06
## Opening is frozen at 10 s. The extreme is the 3:00 mark. After that, creep.
const OPENING_SECONDS := 10.0
const EXTREME_SECONDS := 180.0
const CREEP_SECONDS := 180.0
const SPAWN_EXTREME := 0.24
const SPAWN_CREEP_END := 0.228

const BURST_PAIR_AFTER := 6.0
const BURST_TRIPLE_AFTER := 26.0
const BURST_PAIR_CHANCE := 0.55
const BURST_TRIPLE_CHANCE := 0.22

const SPEED_AT_20 := 1.55
const SPEED_AT_50 := 1.85
const SPEED_PEAK := 1.95
const SPEED_CAP := 2.08
const SPEED_EASE_SECONDS := 20.0
const SPEED_PEAK_SECONDS := 60.0
const SPEED_CREEP_SECONDS := 240.0
const SPEED_EXTREME := 2.42
const SPEED_CREEP_END := 2.48

## Live caps so a bad seed cannot tile the field. The rake is not part of the
## bullet cap; it is a designed lane, not leftover fire.
const MAX_ENEMIES := 8
const MAX_ENEMIES_LATE := 6
const MAX_ENEMY_SHOTS := 9
## After the opening, fewer aimed shots may be in flight at once. The count
## stays fixed, so a long run does not drown in bullets.
const MAX_ENEMY_SHOTS_LATE := 6
const MAX_ENEMY_SHOTS_PEAK := 8
const SHOT_CAP_PEAK_SECONDS := 50.0
const SHOT_CAP_LATE_SECONDS := 14.0

const SCROLL_AT_45 := 1.18
const SCROLL_CAP := 1.30
const SCROLL_RAMP_SECONDS := 45.0
const SCROLL_CAP_SECONDS := 75.0
const SCROLL_EXTREME := 1.58
const SCROLL_CREEP_END := 1.64

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

## Gem points, not kill score. Each rank costs more gems than the last.
## Two gems reach rank 2. Rank 3, 4, and 5 step up from there.
const GATE_RANK2 := 1440
const GATE_RANK3 := 6480
const GATE_RANK4 := 14400
const GATE_RANK5 := 25920
const GEM_EVO := 720
const GEM_SCORE := 40
const GEM_CHANCE := 0.8
const GEM_LIFE := 3.05
const GEM_DRIFT := 36.0

## Goblin loot trait.
const GOBLIN_MAGNET := 40.0
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

## Full-height rake. The hole starts wide and closes on the old early slope,
## then stops at a lane the largest body can sit in. It does not keep closing.
const RAKE_FIRST := 3.4
const RAKE_GAP_START := 120.0
const RAKE_GAP_END := 28.0
const RAKE_GAP_FLOOR := 100.0
const RAKE_GAP_SECONDS := 22.0
const RAKE_SPEED_START := 142.0
const RAKE_SPEED_END := 220.0
const RAKE_SPEED_CAP := 236.0
const RAKE_EVERY_START := 3.5
const RAKE_EVERY_END := 2.15
const RAKE_EVERY_FLOOR := 2.0
const RAKE_SHIFT := 78.0
const RAKE_TOP := 40.0
const RAKE_BOTTOM := 214.0
const RAKE_STEP := 26.0
## Extra empty pixels beyond the hurtbox, so the lane is wider than the body.
const PATTERN_GAP_SLACK := 12.0
const RAKE_BOLT := "floating_eye_bolt.png"

const FINAL_HOLD := 1.7
const FINAL_SLOWMO_SECONDS := 0.65
const FINAL_SLOWMO_SCALE := 0.4
const FINAL_FLASH := 0.48
const FINAL_SHAKE_SECONDS := 0.38
const FINAL_SHAKE_PX := 3.0
const FINAL_STING_DB := 6.0

const POPUP_MIN := 200
const POPUP_LIFE := 0.32
const MAX_FX := 18

static func first_spawn() -> float:
	return FIRST_SPAWN

static func _creep(elapsed: float, knee: float, span: float) -> float:
	var u := clampf((elapsed - knee) / span, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

static func spawn_interval(elapsed: float) -> float:
	if elapsed <= OPENING_SECONDS:
		return _opening_spawn(elapsed)
	var opened := _opening_spawn(OPENING_SECONDS)
	if elapsed <= EXTREME_SECONDS:
		return lerpf(opened, SPAWN_EXTREME, _climb(elapsed))
	return lerpf(SPAWN_EXTREME, SPAWN_CREEP_END, _creep(elapsed, EXTREME_SECONDS, CREEP_SECONDS))

static func speed_scale(elapsed: float) -> float:
	if elapsed <= OPENING_SECONDS:
		return _opening_speed(elapsed)
	var opened := _opening_speed(OPENING_SECONDS)
	if elapsed <= EXTREME_SECONDS:
		return lerpf(opened, SPEED_EXTREME, _climb(elapsed))
	return lerpf(SPEED_EXTREME, SPEED_CREEP_END, _creep(elapsed, EXTREME_SECONDS, CREEP_SECONDS))

static func scroll_scale(elapsed: float) -> float:
	if elapsed <= OPENING_SECONDS:
		return _opening_scroll(elapsed)
	var opened := _opening_scroll(OPENING_SECONDS)
	if elapsed <= EXTREME_SECONDS:
		return lerpf(opened, SCROLL_EXTREME, _climb(elapsed))
	return lerpf(SCROLL_EXTREME, SCROLL_CREEP_END, _creep(elapsed, EXTREME_SECONDS, CREEP_SECONDS))

static func aim_amount(elapsed: float) -> float:
	if elapsed < AIM_ARM_SECONDS:
		return AIM_START
	var u := clampf((elapsed - AIM_ARM_SECONDS) / AIM_FULL_SECONDS, 0.0, 1.0)
	return lerpf(AIM_START, 1.0, u)

static func wolf_chase(elapsed: float) -> float:
	var u := clampf(elapsed / WOLF_CHASE_RAMP_SECONDS, 0.0, 1.0)
	return lerpf(WOLF_CHASE_START, WOLF_CHASE_FULL, u)

static func burst_count(elapsed: float, roll: float) -> int:
	# The first ten seconds keep the old pair chance. After that, pairs and
	# triples become common, and stop climbing once the 3:00 extreme is reached.
	var pair := BURST_PAIR_CHANCE
	var triple_after := BURST_TRIPLE_AFTER
	var triple := BURST_TRIPLE_CHANCE
	if elapsed > OPENING_SECONDS:
		var u := _climb(minf(elapsed, EXTREME_SECONDS))
		pair = lerpf(BURST_PAIR_CHANCE, 0.86, u)
		triple_after = lerpf(BURST_TRIPLE_AFTER, 16.0, u)
		triple = lerpf(BURST_TRIPLE_CHANCE, 0.55, u)
	if elapsed < BURST_PAIR_AFTER or roll > pair:
		return 1
	if elapsed >= triple_after and roll < pair * triple:
		return 3
	return 2

static func _opening_kind_weights(elapsed: float) -> Array[float]:
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

static func kind_weights(elapsed: float) -> Array[float]:
	if elapsed <= OPENING_SECONDS:
		return _opening_kind_weights(elapsed)
	var opened := _opening_kind_weights(OPENING_SECONDS)
	var extreme: Array[float] = [0.12, 0.16, 0.18, 0.20, 0.18, 0.16]
	var u := _climb(minf(elapsed, EXTREME_SECONDS))
	var mixed: Array[float] = []
	for i in opened.size():
		mixed.append(lerpf(float(opened[i]), extreme[i], u))
	return mixed

static func fall_speed(kind: int) -> float:
	if kind == SpawnDirector.PIANO:
		return PIANO_FALL
	return ANVIL_FALL

static func hazard_warn() -> float:
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
	return [GATE_RANK2, GATE_RANK3, GATE_RANK4, GATE_RANK5]

## 0 at the end of the opening, 1 at 3:00. Smooth, so the climb has no knee.
static func _climb(elapsed: float) -> float:
	var u := clampf((elapsed - OPENING_SECONDS) / (EXTREME_SECONDS - OPENING_SECONDS), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

static func _opening_spawn(elapsed: float) -> float:
	return lerpf(SPAWN_INTERVAL_START, SPAWN_INTERVAL_AT_20, clampf(elapsed / SPAWN_EASE_SECONDS, 0.0, 1.0))

static func _opening_speed(elapsed: float) -> float:
	return lerpf(1.0, SPEED_AT_20, clampf(elapsed / SPEED_EASE_SECONDS, 0.0, 1.0))

static func _opening_scroll(elapsed: float) -> float:
	return lerpf(1.0, SCROLL_AT_45, clampf(elapsed / SCROLL_RAMP_SECONDS, 0.0, 1.0))

## Y offsets for an aimed fan. Early fire is one shot. Later fans keep a
## lane between the streams wider than the largest hurtbox.
static func fan_offsets(elapsed: float) -> Array:
	# One stream through the opening. Later fans keep a body-wide gap.
	# The third stream arrives earlier than the old one-minute ceiling, and
	# the spacing never tightens past what the gap check allows.
	if elapsed < 18.0:
		return [0.0]
	if elapsed < 48.0:
		return [0.0, -110.0]
	return [-110.0, 0.0, 110.0]

static func fan_min_spacing(elapsed: float) -> float:
	var offs := fan_offsets(elapsed)
	if offs.size() < 2:
		return 10000.0
	var best := 10000.0
	for i in offs.size():
		for j in range(i + 1, offs.size()):
			best = minf(best, absf(float(offs[i]) - float(offs[j])))
	return best

static func pattern_speed(kind: int, elapsed: float) -> float:
	var base := 90.0
	if kind == SpawnDirector.ARCHER:
		base = 142.0
	elif kind == SpawnDirector.WYVERN:
		base = 118.0
	elif kind == SpawnDirector.EYE:
		base = 102.0
	# The first 10s use the old climb, so the opening that kills an average
	# dodge stays put. After that, bullet speed eases toward a ceiling a
	# committed dodge can still leave, then creeps.
	var opening := lerpf(1.0, 1.55, clampf(minf(elapsed, 10.0) / 18.0, 0.0, 1.0)) * speed_scale(minf(elapsed, 10.0))
	if elapsed <= 10.0:
		return base * opening
	var extra := lerpf(1.0, 1.62, _climb(elapsed))
	if elapsed > EXTREME_SECONDS:
		extra = lerpf(1.62, 1.68, _creep(elapsed, EXTREME_SECONDS, CREEP_SECONDS))
	return base * opening * extra

static func enemy_cap(_elapsed: float) -> int:
	# The cap stays the opening cap. Density climbs by speed and interval,
	# not by adding a ninth body.
	return MAX_ENEMIES

static func enemy_shot_cap(_elapsed: float) -> int:
	return MAX_ENEMY_SHOTS

static func telegraph_for(speed: float) -> float:
	if speed >= FAST_SHOT:
		return FAST_TELEGRAPH
	return SHOT_TELEGRAPH

static func rake_gap(elapsed: float) -> float:
	var u := clampf(elapsed / RAKE_GAP_SECONDS, 0.0, 1.0)
	# The lane closes to the legal floor and stays there. build_rake still
	# widens it to the hurtbox plus slack, so it cannot become impossible.
	return maxf(lerpf(RAKE_GAP_START, RAKE_GAP_END, u), RAKE_GAP_FLOOR)

static func rake_speed(elapsed: float) -> float:
	if elapsed <= OPENING_SECONDS:
		var u := clampf(elapsed / RAKE_GAP_SECONDS, 0.0, 1.0)
		return lerpf(RAKE_SPEED_START, RAKE_SPEED_END, u)
	var opened := lerpf(RAKE_SPEED_START, RAKE_SPEED_END, clampf(OPENING_SECONDS / RAKE_GAP_SECONDS, 0.0, 1.0))
	if elapsed <= EXTREME_SECONDS:
		return lerpf(opened, 268.0, _climb(elapsed))
	return lerpf(268.0, 276.0, _creep(elapsed, EXTREME_SECONDS, CREEP_SECONDS))

static func rake_every(elapsed: float) -> float:
	var u := clampf(elapsed / RAKE_GAP_SECONDS, 0.0, 1.0)
	var cadence := lerpf(RAKE_EVERY_START, RAKE_EVERY_END, u)
	if elapsed > RAKE_GAP_SECONDS:
		var creep := clampf((elapsed - RAKE_GAP_SECONDS) / 180.0, 0.0, 1.0)
		cadence = lerpf(RAKE_EVERY_END, RAKE_EVERY_FLOOR, creep * creep)
	# A new wall waits until the last one has passed the player, so two
	# holes cannot cross and erase each other.
	var pass_time := 370.0 / maxf(rake_speed(elapsed), 1.0)
	return maxf(cadence, pass_time + 0.2)

static func bolt_half_height() -> float:
	var span := HitLibrary.vertical_span(RAKE_BOLT, "threat")
	return maxf(absf(span.x), absf(span.y))

## Bullet rows for the rake, plus the empty lane they leave. The lane is at
## least the closing curve, the fixed floor, and this body's height plus slack.
static func build_rake(elapsed: float, player_y: float, hurt_height: float) -> Dictionary:
	var clear := maxf(rake_gap(elapsed), hurt_height + PATTERN_GAP_SLACK)
	var span := RAKE_BOTTOM - RAKE_TOP
	if clear > span - 8.0:
		clear = span - 8.0
	var half := clear * 0.5
	var min_c := RAKE_TOP + half
	var max_c := RAKE_BOTTOM - half
	var shift := RAKE_SHIFT if player_y < (RAKE_TOP + RAKE_BOTTOM) * 0.5 else -RAKE_SHIFT
	var center := clampf(player_y + shift, min_c, max_c)
	var bolt := bolt_half_height()
	var lane_top := center - half
	var lane_bottom := center + half
	var ys: Array[float] = []
	var y := RAKE_TOP
	while y <= RAKE_BOTTOM + 0.1:
		var overlaps := (y + bolt) > lane_top and (y - bolt) < lane_bottom
		if not overlaps:
			ys.append(y)
		y += RAKE_STEP
	return {
		"center": center,
		"clear": lane_bottom - lane_top,
		"lane_top": lane_top,
		"lane_bottom": lane_bottom,
		"ys": ys,
		"speed": rake_speed(elapsed),
	}
