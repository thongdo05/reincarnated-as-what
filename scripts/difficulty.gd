extends RefCounted
class_name Difficulty

## Pacing for the default drag shooter. Flappy mode keeps the previous curve
## (see the legacy_* helpers) so ?mode=flappy stays on its own tuning.
##
## The opening stays brutal: the first ten seconds still match the short
## curve that kills an average dodge in 5–10 s. Danger then climbs to a hard
## ceiling around a minute. After that, spawn rate and speed only creep, and
## the sweeping rake never closes past a lane a body can sit in.

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
## Slime's hit-split is an opening clear. After this, a shot stays one bullet
## so a long run does not vacuum the field. Flappy keeps the split.
const SLIME_SPLIT_UNTIL := 14.0
## After the opening, the slime stream slows so it no longer erases the field.
## 1 until SLIME_SPLIT_UNTIL, then up to this multiple.
const SLIME_LATE_FIRE_SCALE := 9.0
const SLIME_LATE_FIRE_SECONDS := 24.0

const SCROLL_AT_45 := 1.18
const SCROLL_CAP := 1.30
const SCROLL_RAMP_SECONDS := 45.0
const SCROLL_CAP_SECONDS := 75.0

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

## Gem points, not kill score. One gem reaches rank 2. Nine reach rank 3.
## Both stay above the flappy rank-2 gate (640).
const GATE_RANK2 := 720
const GATE_RANK3 := 6480
const GEM_EVO := 720
const GEM_SCORE := 40
const GEM_CHANCE := 0.8
const GEM_LIFE := 3.05
const GEM_DRIFT := 36.0

## Goblin loot trait. Applied only in the default game.
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

const FINAL_HOLD := 1.85
const FINAL_SLOWMO_SECONDS := 0.3
const FINAL_SLOWMO_SCALE := 0.4
const FINAL_SHAKE_SECONDS := 0.38
const FINAL_SHAKE_PX := 3.0
const FINAL_STING_DB := 6.0

const POPUP_MIN := 200
const POPUP_LIFE := 0.32
const MAX_FX := 18

const LEGACY_FIRST_SPAWN := 0.72
const LEGACY_SPAWN_START := 1.85
const LEGACY_SPAWN_AT_20 := 1.45
const LEGACY_SPAWN_AT_50 := 0.52
const LEGACY_SPAWN_FLOOR := 0.36
const LEGACY_SPEED_AT_20 := 1.20
const LEGACY_SPEED_AT_50 := 1.95
const LEGACY_SPEED_CAP := 2.40
const LEGACY_AIM_START := 0.18
const LEGACY_AIM_ARM := 8.0
const LEGACY_AIM_FULL := 36.0
const LEGACY_WOLF_ARM := 16.0
const LEGACY_WOLF_START := 0.35
const LEGACY_WOLF_FULL := 0.85
const LEGACY_WOLF_RAMP := 20.0
const LEGACY_BURST_PAIR_AFTER := 15.0
const LEGACY_BURST_TRIPLE_AFTER := 32.0
const LEGACY_BURST_PAIR := 0.62
const LEGACY_BURST_TRIPLE := 0.38
const LEGACY_HAZARD_START := 8.0
const LEGACY_HAZARD_RAMP := 42.0
const LEGACY_HAZARD_WARN := 0.4
const LEGACY_ANVIL_FALL := 96.0
const LEGACY_PIANO_FALL := 62.0

static func _flappy() -> bool:
	return FlappyMode.is_active()

static func first_spawn() -> float:
	if _flappy():
		return LEGACY_FIRST_SPAWN
	return FIRST_SPAWN

static func _creep(elapsed: float, knee: float, span: float) -> float:
	var u := clampf((elapsed - knee) / span, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

static func spawn_interval(elapsed: float) -> float:
	if _flappy():
		return _legacy_spawn_interval(elapsed)
	if elapsed <= SPAWN_EASE_SECONDS:
		return lerpf(SPAWN_INTERVAL_START, SPAWN_INTERVAL_AT_20, clampf(elapsed / SPAWN_EASE_SECONDS, 0.0, 1.0))
	if elapsed <= 50.0:
		var u := clampf((elapsed - SPAWN_EASE_SECONDS) / 30.0, 0.0, 1.0)
		return lerpf(SPAWN_INTERVAL_AT_20, SPAWN_INTERVAL_AT_50, u)
	if elapsed <= SPAWN_PEAK_SECONDS:
		var to_peak := clampf((elapsed - 50.0) / 10.0, 0.0, 1.0)
		return lerpf(SPAWN_INTERVAL_AT_50, SPAWN_INTERVAL_PEAK, to_peak)
	return lerpf(SPAWN_INTERVAL_PEAK, SPAWN_INTERVAL_FLOOR, _creep(elapsed, SPAWN_PEAK_SECONDS, SPAWN_CREEP_SECONDS))

static func speed_scale(elapsed: float) -> float:
	if _flappy():
		return _legacy_speed_scale(elapsed)
	if elapsed <= SPEED_EASE_SECONDS:
		return lerpf(1.0, SPEED_AT_20, clampf(elapsed / SPEED_EASE_SECONDS, 0.0, 1.0))
	if elapsed <= 50.0:
		var u := clampf((elapsed - SPEED_EASE_SECONDS) / 30.0, 0.0, 1.0)
		return lerpf(SPEED_AT_20, SPEED_AT_50, u)
	if elapsed <= SPEED_PEAK_SECONDS:
		var to_peak := clampf((elapsed - 50.0) / 10.0, 0.0, 1.0)
		return lerpf(SPEED_AT_50, SPEED_PEAK, to_peak)
	return lerpf(SPEED_PEAK, SPEED_CAP, _creep(elapsed, SPEED_PEAK_SECONDS, SPEED_CREEP_SECONDS))

static func scroll_scale(elapsed: float) -> float:
	if elapsed <= SCROLL_RAMP_SECONDS:
		return lerpf(1.0, SCROLL_AT_45, clampf(elapsed / SCROLL_RAMP_SECONDS, 0.0, 1.0))
	var extra := clampf((elapsed - SCROLL_RAMP_SECONDS) / SCROLL_CAP_SECONDS, 0.0, 1.0)
	return lerpf(SCROLL_AT_45, SCROLL_CAP, extra)

static func aim_amount(elapsed: float) -> float:
	if _flappy():
		if elapsed < LEGACY_AIM_ARM:
			return LEGACY_AIM_START
		var legacy_u := clampf((elapsed - LEGACY_AIM_ARM) / LEGACY_AIM_FULL, 0.0, 1.0)
		return lerpf(LEGACY_AIM_START, 1.0, legacy_u)
	if elapsed < AIM_ARM_SECONDS:
		return AIM_START
	var u := clampf((elapsed - AIM_ARM_SECONDS) / AIM_FULL_SECONDS, 0.0, 1.0)
	return lerpf(AIM_START, 1.0, u)

static func wolf_chase(elapsed: float) -> float:
	if _flappy():
		if elapsed < LEGACY_WOLF_ARM:
			return 0.0
		var legacy_u := clampf((elapsed - LEGACY_WOLF_ARM) / LEGACY_WOLF_RAMP, 0.0, 1.0)
		return lerpf(LEGACY_WOLF_START, LEGACY_WOLF_FULL, legacy_u)
	var u := clampf(elapsed / WOLF_CHASE_RAMP_SECONDS, 0.0, 1.0)
	return lerpf(WOLF_CHASE_START, WOLF_CHASE_FULL, u)

static func burst_count(elapsed: float, roll: float) -> int:
	if _flappy():
		if elapsed < LEGACY_BURST_PAIR_AFTER or roll > LEGACY_BURST_PAIR:
			return 1
		if elapsed >= LEGACY_BURST_TRIPLE_AFTER and roll < LEGACY_BURST_PAIR * LEGACY_BURST_TRIPLE:
			return 3
		return 2
	if elapsed < BURST_PAIR_AFTER or roll > BURST_PAIR_CHANCE:
		return 1
	if elapsed >= BURST_TRIPLE_AFTER and roll < BURST_PAIR_CHANCE * BURST_TRIPLE_CHANCE:
		return 3
	return 2

static func kind_weights(elapsed: float) -> Array[float]:
	if _flappy():
		return _legacy_kind_weights(elapsed)
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

static func fall_speed(kind: int) -> float:
	if _flappy():
		if kind == SpawnDirector.PIANO:
			return LEGACY_PIANO_FALL
		return LEGACY_ANVIL_FALL
	if kind == SpawnDirector.PIANO:
		return PIANO_FALL
	return ANVIL_FALL

static func hazard_warn() -> float:
	if _flappy():
		return LEGACY_HAZARD_WARN
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
	return [GATE_RANK2, GATE_RANK3]

## Y offsets for an aimed fan. Early fire is one shot. Later fans keep a
## lane between the streams wider than the largest hurtbox.
static func fan_offsets(elapsed: float) -> Array:
	# One stream through the opening. A second stream, then a third, only
	# once an average run is already over, and each gap stays body-wide.
	if elapsed < 18.0:
		return [0.0]
	if elapsed < 70.0:
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
	var extra := lerpf(1.0, 1.05, clampf((elapsed - 10.0) / 35.0, 0.0, 1.0))
	if elapsed > 42.0:
		extra = lerpf(1.05, 1.24, clampf((elapsed - 42.0) / 48.0, 0.0, 1.0))
	return base * opening * extra

static func slime_fire_scale(elapsed: float) -> float:
	if _flappy() or elapsed <= SLIME_SPLIT_UNTIL:
		return 1.0
	var u := clampf((elapsed - SLIME_SPLIT_UNTIL) / SLIME_LATE_FIRE_SECONDS, 0.0, 1.0)
	return lerpf(1.0, SLIME_LATE_FIRE_SCALE, u)

static func enemy_cap(elapsed: float) -> int:
	if _flappy() or elapsed < SHOT_CAP_LATE_SECONDS:
		return MAX_ENEMIES
	return MAX_ENEMIES_LATE

static func enemy_shot_cap(elapsed: float) -> int:
	if _flappy() or elapsed < SHOT_CAP_LATE_SECONDS:
		return MAX_ENEMY_SHOTS
	if elapsed < SHOT_CAP_PEAK_SECONDS:
		return MAX_ENEMY_SHOTS_LATE
	return MAX_ENEMY_SHOTS_PEAK

static func telegraph_for(speed: float) -> float:
	if speed >= FAST_SHOT:
		return FAST_TELEGRAPH
	return SHOT_TELEGRAPH

static func rake_gap(elapsed: float) -> float:
	var u := clampf(elapsed / RAKE_GAP_SECONDS, 0.0, 1.0)
	var floor := RAKE_GAP_FLOOR
	# The opening keeps the narrow-but-legal lane. After that the lane opens
	# a little so a large body can still sit in it while other fire is in the air.
	if elapsed > SHOT_CAP_LATE_SECONDS:
		var open := clampf((elapsed - SHOT_CAP_LATE_SECONDS) / 30.0, 0.0, 1.0)
		floor = lerpf(RAKE_GAP_FLOOR, 130.0, open)
	return maxf(lerpf(RAKE_GAP_START, RAKE_GAP_END, u), floor)

static func rake_speed(elapsed: float) -> float:
	if elapsed <= RAKE_GAP_SECONDS:
		var u := clampf(elapsed / RAKE_GAP_SECONDS, 0.0, 1.0)
		return lerpf(RAKE_SPEED_START, RAKE_SPEED_END, u)
	var creep := clampf((elapsed - RAKE_GAP_SECONDS) / 180.0, 0.0, 1.0)
	return lerpf(RAKE_SPEED_END, RAKE_SPEED_CAP, creep * creep)

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

static func _legacy_spawn_interval(elapsed: float) -> float:
	if elapsed <= 20.0:
		return lerpf(LEGACY_SPAWN_START, LEGACY_SPAWN_AT_20, clampf(elapsed / 20.0, 0.0, 1.0))
	if elapsed <= 50.0:
		var u := clampf((elapsed - 20.0) / 30.0, 0.0, 1.0)
		return lerpf(LEGACY_SPAWN_AT_20, LEGACY_SPAWN_AT_50, u)
	var extra := clampf((elapsed - 50.0) / 40.0, 0.0, 1.0)
	return lerpf(LEGACY_SPAWN_AT_50, LEGACY_SPAWN_FLOOR, extra)

static func _legacy_speed_scale(elapsed: float) -> float:
	if elapsed <= 20.0:
		return lerpf(1.0, LEGACY_SPEED_AT_20, clampf(elapsed / 20.0, 0.0, 1.0))
	if elapsed <= 50.0:
		var u := clampf((elapsed - 20.0) / 30.0, 0.0, 1.0)
		return lerpf(LEGACY_SPEED_AT_20, LEGACY_SPEED_AT_50, u)
	var extra := clampf((elapsed - 50.0) / 40.0, 0.0, 1.0)
	return lerpf(LEGACY_SPEED_AT_50, LEGACY_SPEED_CAP, extra)

static func _legacy_kind_weights(elapsed: float) -> Array[float]:
	var pace := clampf(elapsed / 60.0, 0.0, 1.0)
	var hazard := clampf((elapsed - LEGACY_HAZARD_START) / LEGACY_HAZARD_RAMP, 0.0, 1.0)
	var wyvern := clampf((elapsed - 8.0) / 18.0, 0.0, 1.0)
	return [
		lerpf(0.70, 0.16, pace),
		lerpf(0.10, 0.16, pace),
		lerpf(0.20, 0.16, pace),
		lerpf(0.00, 0.15, pace) * wyvern,
		lerpf(0.00, 0.22, hazard),
		lerpf(0.00, 0.16, hazard),
	]
