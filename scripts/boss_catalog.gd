extends RefCounted
class_name BossCatalog

## Boss roster. Swap art by replacing the PNG at the same filename and refitting
## art/hitboxes.json. Anchors stay at the center of the 96x84 frame.
##
## The Great Dragon is not in the Lich King / Death Knight cycle. It arrives
## on its own clock, stays until it dies, and comes back harder.

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
			return 200
		"death_knight":
			return 350
		"great_dragon":
			return 500 + maxi(generation, 0) * 10
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
	var phase_mul := 1.0 if phase <= 1 else 1.22
	return gentle * gen * phase_mul

static func attack_cycle(slug: String, phase: int) -> Array[String]:
	if slug == "great_dragon":
		if phase <= 1:
			return ["sweep", "volley"]
		return ["sweep", "fan", "dive"]
	if slug == "death_knight":
		return ["charge"]
	return ["skull", "skull", "bone_rain"]

static func windup(pattern: String, phase: int, generation: int) -> float:
	if pattern == "charge":
		return 0.8
	if pattern == "bone_rain":
		return 0.9
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
	var shaved := base - float(mini(maxi(generation, 0), 4)) * 0.015
	if pattern == "dive":
		return maxf(shaved, 0.6)
	return maxf(shaved, 0.36)

static func cooldown(pattern: String, phase: int, elapsed: float, generation: int) -> float:
	var base := 2.2
	match pattern:
		"skull":
			base = 2.35
		"bone_rain":
			base = 2.55
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
			base = 1.45
	return maxf(base / attack_rate(elapsed, generation, phase), 0.58)

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

static func bullet_speed(phase: int, generation: int) -> float:
	var base := 150.0 if phase <= 1 else 176.0
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
