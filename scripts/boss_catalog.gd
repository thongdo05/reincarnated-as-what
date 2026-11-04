extends RefCounted
class_name BossCatalog

## Boss roster. Swap art by replacing the PNG at the same filename and refitting
## art/hitboxes.json. Anchors stay at the center of the 96x84 frame.
##
## The Great Dragon is not in the Lich King / Death Knight cycle. It arrives
## on its own clock, stays until it dies, and comes back with another 10000 HP.
## Once it has appeared, the Lich King and the Death Knight do not spawn again.

const MOUTH := Vector2(-60, -4)
const SKULL_MUZZLE := Vector2(-36, -20)
const SWEEP_HOLE_LO := -0.62
const SWEEP_HOLE_HI := 0.98
const STREAM_GAP := 128.0
const DRAGON_SHOT := "dragon_fireball.png"
const BONE_SHOT := "lich_bone.png"
const BONE_MARK := "lich_bone_mark.png"
## Center spacing. Wider than the largest hurtbox plus the bone, so a lane stays open.
const BONE_GAP := 96.0
const BONE_LEFT := 28.0
const BONE_RIGHT := 376.0
const BONE_TOP := 12.0
const BONE_SPAWN_Y := -8.0
const WINNER_BOSS_DMG_PCT := 0.15
const LICH_INTRO := 1.7
## Longer than the lich entrance: shadow, roar, crash, title.
const DRAGON_INTRO := 2.6
## Safe lane in the full-screen breath. Wider than every rank-5 body.
const HELL_GAP := 96.0
## Sky-breath band, measured across the shot centers.
const SKY_BAND := 40.0
## Horizontal spacing of the dragon's own meteors.
const METEOR_SPACING := 96.0
const BOSS_METEOR := "dragon_form/boss_meteor.png"
const BOSS_EMBER := "dragon_form/boss_ember.png"
const BOSS_BREATH := "dragon_form/boss_breath.png"
const BOSS_GUST := "dragon_form/boss_gust.png"
## The thin line follows the player, then freezes. The lock is not shortened
## when the lich is enraged, so there is always time to leave the row.
const BEAM_TRACK := 0.55
const BEAM_LOCK := 0.35
## Solid beam, no gap. It holds, then the sprite fades.
const BEAM_FIRE := 1.0
const BEAM_FADE := 0.22
## Outer glow, in pixels at 480x270. The core sits inside this.
const BEAM_THICK := 22.0
## Threat radius. Diameter stays a few pixels inside the glow.
const BEAM_HIT_R := 8.5
const HAND_GAP := 140.0
const SWORD_GAP := 132.0
const SHIELD_TIME := 2.0
const SOUL_BEAM := "lich_soul_beam.png"
const SPIRAL_SKULL := "lich_spiral_skull.png"
const GRAVE_HAND := "lich_grave_hand.png"
const SWORD_WAVE := "knight_sword_wave.png"
const KNIGHT_SHIELD := "knight_shield.png"
const OVERDRIVE_MULT := 3.0
const GEM_BURST := 8
const DRAGON_GEM_BURST := 18
const DRAGON_SCORE := 100000

const SLUGS: Array[String] = ["lich_king", "death_knight", "great_dragon"]

static func sprite_for(slug: String) -> String:
	return "%s.png" % slug

## Right-edge rest, measured so the sprite sits about 6 px inside the screen.
static func rest_x(slug: String) -> float:
	match slug:
		"lich_king":
			return 428.0
		"death_knight":
			return 426.0
		"great_dragon":
			return 410.0
		_:
			return 410.0

static func display_name(slug: String) -> String:
	match slug:
		"lich_king":
			return "Lich King"
		"death_knight":
			return "Death Knight"
		"great_dragon":
			return "Great Dragon"
		_:
			return "Boss"

static func banner_color(slug: String) -> Color:
	match slug:
		"lich_king":
			return Color("d7c4ff")
		"death_knight":
			return Color("ffb0b8")
		_:
			return Color("ffb15a")

static func max_hp(slug: String, generation: int = 0) -> int:
	match slug:
		"lich_king":
			return 500
		"death_knight":
			return 2500
		"great_dragon":
			# 10000, then 20000, 30000, ... Each return adds another 10000.
			return 10000 * (maxi(generation, 0) + 1)
		_:
			return 20

static func score_value(slug: String) -> int:
	match slug:
		"lich_king":
			return 1500
		"death_knight":
			return 2000
		"great_dragon":
			return DRAGON_SCORE
		_:
			return 100

static func cue(slug: String, moment: String) -> String:
	return "boss_%s_%s" % [slug, moment]

static func attack_unit(elapsed: float) -> float:
	var span := Difficulty.SPEED_EXTREME - 1.0
	if span <= 0.001:
		return 0.0
	return clampf((Difficulty.speed_scale(elapsed) - 1.0) / span, 0.0, 1.0)

## Gentle climb with the difficulty curve, a bit quicker in dragon phase 2,
## and quicker again each time the dragon returns.
static func attack_rate(elapsed: float, generation: int, phase: int) -> float:
	var gentle := lerpf(1.0, 1.28, attack_unit(elapsed))
	var gen := 1.0 + float(mini(maxi(generation, 0), 6)) * 0.16
	var phase_mul := 1.0
	if phase == 2:
		phase_mul = 1.22
	elif phase >= 3:
		phase_mul = 1.45
	return gentle * gen * phase_mul

static func attack_cycle(slug: String, phase: int) -> Array[String]:
	if slug == "great_dragon":
		if phase <= 1:
			return ["sky_breath", "ember_fan"]
		if phase == 2:
			return ["sky_breath", "dive", "wing_gust", "boss_meteor"]
		return ["hell_breath", "dive", "boss_meteor"]
	if slug == "death_knight":
		if phase >= 2:
			return ["charge", "charge", "fake_charge", "sword_waves", "shield"]
		return ["charge", "fake_charge", "sword_waves", "shield"]
	if phase >= 2:
		return ["double_beam", "beam_rain", "spiral_hands"]
	return ["soul_beam", "skull_spiral", "grave_hands", "bone_rain"]

static func windup(pattern: String, phase: int, generation: int) -> float:
	if pattern == "charge":
		return 0.8
	if pattern == "bone_rain":
		return 0.9
	if pattern == "soul_beam" or pattern == "beam_rain" or pattern == "double_beam":
		return BEAM_TRACK + BEAM_LOCK
	if pattern == "grave_hands" or pattern == "spiral_hands":
		return 0.8
	if pattern == "fake_charge":
		return 0.55
	if pattern == "sword_waves":
		return 0.48
	var base := 0.42
	match pattern:
		"skull":
			base = 0.36
		"sweep":
			base = 0.56 if phase <= 1 else 0.46
		"volley":
			base = 0.46
		"fan":
			base = 0.44
		"dive":
			base = 0.7
		"sky_breath":
			base = 0.7
		"ember_fan":
			base = 0.52
		"wing_gust":
			base = 0.62
		"boss_meteor":
			base = 0.78
		"hell_breath":
			base = 0.88
	var shaved := base - float(mini(maxi(generation, 0), 4)) * 0.015
	if pattern == "dive":
		return maxf(shaved, 0.6)
	return maxf(shaved, 0.36)

static func cooldown(pattern: String, phase: int, elapsed: float, generation: int) -> float:
	var base := 2.2
	match pattern:
		"skull":
			base = 2.35
		"bone_rain", "beam_rain":
			base = 2.55
		"soul_beam", "double_beam":
			base = 2.4
		"skull_spiral", "spiral_hands":
			base = 2.3
		"grave_hands":
			base = 2.45
		"sword_waves":
			base = 2.2
		"fake_charge":
			base = 3.2
		"shield":
			base = 2.6
		"summon":
			base = 7.4
		"charge":
			base = 3.5
		"sweep":
			base = 2.45 if phase <= 1 else 1.28
		"volley":
			base = 2.05
		"fan":
			base = 1.12
		"dive":
			base = 1.45 if phase < 3 else 1.05
		"sky_breath":
			base = 1.7
		"ember_fan":
			base = 1.55
		"wing_gust":
			base = 1.85
		"boss_meteor":
			base = 1.7 if phase < 3 else 1.15
		"hell_breath":
			base = 1.2
	var cooled := maxf(base / attack_rate(elapsed, generation, phase), 0.58)
	# Return 3 and later. The floor stays long enough to read the next warning.
	# Windups are not touched here.
	if generation >= 3:
		cooled = maxf(cooled * DragonPhase.RETURN_GAP_SCALE, DragonPhase.RETURN_GAP_FLOOR)
	return cooled

static func skull_speed(elapsed: float) -> float:
	return lerpf(68.0, 90.0, attack_unit(elapsed))

static func bone_fall_speed(elapsed: float) -> float:
	return lerpf(150.0, 210.0, attack_unit(elapsed))

static func bone_column_count(elapsed: float) -> int:
	var u := attack_unit(elapsed)
	if u < 0.34:
		return 3
	if u < 0.7:
		return 4
	return 5

## One column sits on the player's x. The rest step away by BONE_GAP, so a body
## always fits between the bones. Count climbs gently with the difficulty curve.
static func bone_columns(player_x: float, elapsed: float, field_w: float) -> Array[float]:
	var right := minf(BONE_RIGHT, field_w - 96.0)
	var left := BONE_LEFT
	if right < left + BONE_GAP:
		right = left + BONE_GAP
	var anchor := clampf(player_x, left, right)
	var cols: Array[float] = [anchor]
	var want := bone_column_count(elapsed)
	var step := 1
	var signs: Array[float] = [-1.0, 1.0]
	while cols.size() < want and step < 6:
		for sign in signs:
			if cols.size() >= want:
				break
			var x := anchor + sign * BONE_GAP * float(step)
			if x < left - 0.1 or x > right + 0.1:
				continue
			cols.append(x)
		step += 1
	cols.sort()
	return cols

## 15% of max HP, rounded. A full boss always survives one WINNER.
static func winner_damage(max_hp: int) -> int:
	var pct := int(round(WINNER_BOSS_DMG_PCT * 100.0))
	var chip := int((maxi(max_hp, 1) * pct + 50) / 100)
	if chip >= max_hp:
		chip = maxi(max_hp - 1, 1)
	return chip

static func hand_columns(player_x: float) -> Array[float]:
	var anchor := clampf(player_x, 48.0, 340.0)
	var cols: Array[float] = [anchor]
	if anchor - HAND_GAP >= 32.0:
		cols.append(anchor - HAND_GAP)
	if anchor + HAND_GAP <= 360.0:
		cols.append(anchor + HAND_GAP)
	cols.sort()
	return cols

static func sword_offsets() -> Array[float]:
	return [-SWORD_GAP, 0.0, SWORD_GAP]

## Phase 2 lich and knight attacks come out quicker. Telegraphs stay readable.
static func fury_time(seconds: float, phase: int) -> float:
	if phase >= 2:
		return maxf(seconds * 0.74, 0.42)
	return seconds

static func bullet_speed(phase: int, generation: int) -> float:
	var base := 150.0
	if phase == 2:
		base = 176.0
	elif phase >= 3:
		base = 196.0
	return base + float(mini(maxi(generation, 0), 6)) * 6.0

static func sweep_angles(phase: int, generation: int) -> Array[float]:
	var step := 0.22 if phase <= 1 else 0.17
	var rings := 3 if phase <= 1 else 4
	if phase <= 1:
		rings += mini(maxi(generation, 0), 1)
	else:
		rings += mini(maxi(generation, 0), 3)
	var angles: Array[float] = []
	for i in rings:
		angles.append(SWEEP_HOLE_LO - step * float(i + 1))
		angles.append(SWEEP_HOLE_HI + step * float(i))
	return angles

static func stream_offsets(pattern: String) -> Array[float]:
	if pattern == "fan":
		return [-STREAM_GAP * 2.0, -STREAM_GAP, 0.0, STREAM_GAP, STREAM_GAP * 2.0]
	return [-STREAM_GAP, 0.0, STREAM_GAP]

## One entry per bullet: offset from the boss anchor, velocity, stagger index.
## Sweep shots sit outside the fixed angular hole. Streams are parallel, so
## the gap between them stays STREAM_GAP even when the aim tilts.
static func shot_plan(pattern: String, phase: int, generation: int, origin: Vector2, aim: Vector2, speed: float) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	if pattern == "sky_breath":
		var lane := clampf(aim.y, 48.0, 200.0)
		var scaled := speed * DragonPhase.breath_speed_scale(generation)
		var index := 0
		for off in [-20.0, -10.0, 0.0, 10.0, 20.0]:
			plans.append({
				"offset": Vector2(MOUTH.x, lane - origin.y + off),
				"velocity": Vector2(-scaled, 0.0),
				"stagger": index,
				"sprite": DRAGON_SHOT,
			})
			index += 1
		return plans
	if pattern == "hell_breath":
		return hell_breath_plan(origin, hell_gap_center(aim.y), speed, generation)
	if pattern == "ember_fan":
		var to := aim - (origin + MOUTH)
		if to.length() < 1.0:
			to = Vector2.LEFT
		var dir := to.normalized()
		var perp := Vector2(-dir.y, dir.x)
		var index := 0
		for off in [-150.0, -70.0, 70.0, 150.0]:
			plans.append({
				"offset": MOUTH + perp * off,
				"velocity": dir * speed,
				"stagger": index,
				"sprite": DRAGON_SHOT,
			})
			plans.append({
				"offset": MOUTH + perp * off,
				"velocity": dir * (speed * 0.72),
				"stagger": index + 3,
				"sprite": BOSS_EMBER,
			})
			index += 1
		if DragonPhase.has_return(generation, 4):
			var extra: Array[Dictionary] = []
			for spec in plans:
				var copy: Dictionary = spec.duplicate()
				copy["stagger"] = int(copy["stagger"]) + DragonPhase.RETURN_EXTRA_STAGGER
				extra.append(copy)
			plans.append_array(extra)
		return plans
	if pattern == "boss_meteor":
		var count := DragonPhase.meteor_count(generation)
		var span := METEOR_SPACING * float(count - 1)
		var left := clampf(aim.x - span * 0.5, 64.0, 400.0 - span)
		for step in count:
			var column := left + float(step) * METEOR_SPACING
			plans.append({
				"offset": Vector2(column - origin.x, -36.0 - origin.y),
				"velocity": Vector2(-16.0, 170.0),
				"stagger": step,
				"sprite": BOSS_METEOR,
			})
		return plans
	if pattern == "wing_gust":
		return plans
	if pattern == "sweep":
		var index := 0
		for angle in sweep_angles(phase, generation):
			var dir := Vector2(-cos(angle), sin(angle))
			plans.append({
				"offset": MOUTH,
				"velocity": dir * speed,
				"stagger": index,
			})
			index += 1
		return plans
	var to := aim - (origin + MOUTH)
	if to.length() < 1.0:
		to = Vector2.LEFT
	var dir := to.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var index := 0
	for off in stream_offsets(pattern):
		plans.append({
			"offset": MOUTH + perp * float(off),
			"velocity": dir * speed,
			"stagger": index,
		})
		index += 1
	return plans

static func hell_gap_center(aim_y: float) -> float:
	var half := HELL_GAP * 0.5
	return clampf(aim_y + 72.0, 36.0 + half, 206.0 - half)

static func hell_gap_speed(generation: int) -> float:
	if DragonPhase.has_return(generation, 3):
		return DragonPhase.RETURN_HELL_GAP_SPEED
	return 0.0

static func hell_breath_plan(origin: Vector2, gap_center: float, speed: float, generation: int) -> Array[Dictionary]:
	var scaled := speed * DragonPhase.breath_speed_scale(generation)
	var half := HELL_GAP * 0.5
	var plans: Array[Dictionary] = []
	var index := 0
	var y := 40.0
	while y <= 214.0:
		if absf(y - gap_center) >= half + 10.0:
			plans.append({
				"offset": Vector2(MOUTH.x, y - origin.y),
				"velocity": Vector2(-scaled, 0.0),
				"stagger": index % 4,
				"sprite": DRAGON_SHOT,
			})
			index += 1
		y += 12.0
	return plans

## Y where this bullet crosses column_x. Empty when it never travels that way.
static func cross_y(origin: Vector2, offset: Vector2, velocity: Vector2, column_x: float) -> Variant:
	var start := origin + offset
	if velocity.x >= -1.0:
		return null
	var t := (column_x - start.x) / velocity.x
	if t < 0.0:
		return null
	return start.y + velocity.y * t

static func widest_gap(blocks: Array[Vector2], top: float, bottom: float) -> float:
	var spans: Array[Vector2] = []
	for block in blocks:
		if block.y < top or block.x > bottom:
			continue
		spans.append(Vector2(maxf(block.x, top), minf(block.y, bottom)))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor := top
	var best := 0.0
	for span in spans:
		best = maxf(best, span.x - cursor)
		cursor = maxf(cursor, span.y)
	return maxf(best, bottom - cursor)
