extends EnemyActor
class_name BossActor

## One boss body. Art is the PNG named by the slug, so a later file drop at
## art/<slug>.png replaces the placeholder without a code change. Hit shapes
## stay in art/hitboxes.json.

const ENTER := 0
const HOLD := 1
const CHARGE := 2
const RETURN := 3
const FLEE := 4

var generation := 0
var hold_x := 410.0
var state := ENTER
var fight_left := 0.0
var return_booked := false
var _attack_i := 0
var _attack_cd := 0.6
var _summon_cd := 3.2
var _attack_id := ""
var _charge_y := 120.0
var _charge_speed := 320.0
var _row_left := 0.0

func is_boss() -> bool:
	return true

func sprite_file() -> String:
	return BossCatalog.sprite_for(boss_slug)

func dragon_phase() -> int:
	if boss_slug != "great_dragon":
		return 1
	if hp * 2 <= max_hp:
		return 2
	return 1

func setup(spawn_id: int, data: Dictionary, field: Vector2, field_background: FieldBackground) -> void:
	id = spawn_id
	kind = -1
	boss_slug = str(data.get("slug", "lich_king"))
	generation = int(data.get("generation", 0))
	kind_name = BossCatalog.display_name(boss_slug)
	max_hp = BossCatalog.max_hp(boss_slug, generation)
	hp = max_hp
	score_value = BossCatalog.score_value(boss_slug)
	radius = HitLibrary.bounds_radius(sprite_file(), "body")
	field_size = field
	background = field_background
	hold_x = clampf(float(data.get("hold_x", BossCatalog.rest_x(boss_slug))), 380.0, 440.0)
	var limits := _y_limits(field.y)
	origin_y = clampf(float(data.get("origin_y", field.y * 0.45)), limits.x, limits.y)
	phase = float(data.get("phase", 0.0))
	wave_amp = float(data.get("wave_amp", 18.0))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2(field.x + radius + 28.0, origin_y)
	state = ENTER
	fight_left = 0.0
	_attack_cd = 0.55
	_summon_cd = 3.4
	_charge_speed = 340.0 if boss_slug == "great_dragon" else 300.0

func take_spawns() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	pending.append_array(_pending_spawns)
	_pending_spawns.clear()
	return pending

## Puts the named attack's telegraph on screen without waiting out the cooldown.
func present(attack: String, aim: Vector2) -> void:
	state = HOLD
	position.x = hold_x
	fight_left = BossDirector.LIFE
	_attack_id = attack
	_attack_cd = 10.0
	telegraphs.clear()
	if attack == "charge" or attack == "dive":
		_charge_y = _clamp_row(aim.y)
		_attack_id = attack
		# Reuse the shot telegraph timer by parking a zero-velocity mark the
		# drawer ignores, and keep the warning on _attack_cd's sibling.
		_arm_row(BossCatalog.windup(attack, dragon_phase(), generation))
		return
	_arm_shots(attack, aim, BossCatalog.windup(attack, dragon_phase(), generation))

func tick(delta: float, player_pos: Vector2, run_time: float = 0.0, scale: float = 1.0) -> Array[Dictionary]:
	age += delta
	speed_scale = maxf(scale, 0.05)
	var player_vel := Vector2.ZERO
	if _have_player and delta > 0.0:
		player_vel = (player_pos - _last_player) / delta
	_last_player = player_pos
	_have_player = true
	var fired: Array[Dictionary] = []
	match state:
		ENTER:
			position.x = move_toward(position.x, hold_x, 120.0 * delta)
			position.y = origin_y
			if absf(position.x - hold_x) <= 1.0:
				position.x = hold_x
				state = HOLD
				fight_left = BossDirector.LIFE
				_attack_cd = 0.45
		FLEE:
			position.x += 170.0 * delta
			if position.x > field_size.x + radius + 36.0:
				alive = false
		CHARGE:
			position.y = _charge_y
			position.x -= _charge_speed * delta
			if position.x < 26.0:
				state = RETURN
		RETURN:
			position.x = move_toward(position.x, hold_x, 250.0 * delta)
			position.y = move_toward(position.y, origin_y, 120.0 * delta)
			if absf(position.x - hold_x) <= 2.0:
				position.x = hold_x
				state = HOLD
				_attack_cd = BossCatalog.cooldown(_attack_id, dragon_phase(), run_time, generation)
		_:
			_drift(delta)
			_fight(delta, player_pos, player_vel, run_time, fired)
	if _flees() and state != ENTER and state != FLEE:
		fight_left -= delta
		if fight_left <= 0.0:
			_begin_flee()
	_release_telegraphs(fired, delta)
	if is_inside_tree():
		queue_redraw()
	return fired

func _flees() -> bool:
	return boss_slug != "great_dragon"

func _begin_flee() -> void:
	state = FLEE
	telegraphs.clear()
	_attack_id = ""
	_pending_spawns.clear()

func _y_limits(height: float) -> Vector2:
	var file := sprite_file()
	var point := ArtLibrary.anchor(file)
	var box := ArtLibrary.art_bbox(file)
	var top := point.y + 4.0
	var bottom := height - (box.y - point.y) - 6.0
	if bottom < top:
		bottom = top
	return Vector2(top, bottom)

func _drift(delta: float) -> void:
	var bob := sin(age * 1.15 + phase) * wave_amp
	var limits := _y_limits(field_size.y)
	position.y = clampf(origin_y + bob, limits.x, limits.y)
	if absf(position.x - hold_x) > 0.5:
		position.x = move_toward(position.x, hold_x, 80.0 * delta)

func _fight(delta: float, player_pos: Vector2, player_vel: Vector2, run_time: float, fired: Array[Dictionary]) -> void:
	if charmed > 0.0:
		return
	if not telegraphs.is_empty():
		return
	if _row_left > 0.0:
		_row_left -= delta
		if _row_left <= 0.0:
			state = CHARGE
			position.y = _charge_y
		return
	if boss_slug == "lich_king":
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_eyes()
			_summon_cd = BossCatalog.cooldown("summon", 1, run_time, generation)
	_attack_cd -= delta
	if _attack_cd > 0.0:
		return
	var cycle := BossCatalog.attack_cycle(boss_slug, dragon_phase())
	var attack := cycle[_attack_i % cycle.size()]
	_attack_i += 1
	_attack_id = attack
	if attack == "charge" or attack == "dive":
		_charge_y = _clamp_row(player_pos.y)
		_arm_row(BossCatalog.windup(attack, dragon_phase(), generation))
		return
	if attack == "skull":
		var speed := BossCatalog.skull_speed(run_time)
		var aim := _lead(position + BossCatalog.MOUTH, player_pos, player_vel, speed, run_time)
		_commit_shot(fired, aim, BossCatalog.SKULL_MUZZLE, "lich_skull.png", BossCatalog.windup("skull", 1, generation))
		_attack_cd = BossCatalog.cooldown("skull", 1, run_time, generation)
		return
	_arm_shots(attack, player_pos, BossCatalog.windup(attack, dragon_phase(), generation))
	_attack_cd = BossCatalog.cooldown(attack, dragon_phase(), run_time, generation)

func _arm_shots(attack: String, aim: Vector2, windup: float) -> void:
	var phase_now := dragon_phase()
	var speed := BossCatalog.bullet_speed(phase_now, generation)
	for spec in BossCatalog.shot_plan(attack, phase_now, generation, position, aim, speed):
		var extra := 0.03 * float(spec["stagger"])
		telegraphs.append({
			"left": windup + extra,
			"velocity": spec["velocity"],
			"pos": position + spec["offset"],
			"sprite": BossCatalog.DRAGON_SHOT,
		})

func _arm_row(seconds: float) -> void:
	_row_left = seconds

func _clamp_row(y: float) -> float:
	return clampf(y, 64.0, field_size.y - 76.0)

func _summon_eyes() -> void:
	var spots: Array[Vector2] = [Vector2(-36, -16), Vector2(-28, 18)]
	for spot in spots:
		var at := position + spot
		_pending_spawns.append({
			"kind": SpawnDirector.EYE,
			"x_ratio": clampf(at.y / field_size.y, 0.15, 0.85),
			"phase": phase + at.y * 0.01,
			"stop_ratio": 0.3,
			"wave_amp": 8.0,
			"y_bias": 0.0,
			"hold_fire": false,
			"spawn_at": at,
		})

func _draw() -> void:
	if charmed > 0.0:
		modulate = Color(0.62, 1.0, 0.72)
	else:
		modulate = Color.WHITE
	# Body, then the no-hit FX. Both sit on this node, under enemy bullets.
	var entry := ArtLibrary.entry(sprite_file())
	var body := str(entry.get("body_file", ""))
	var fx := str(entry.get("fx_file", ""))
	ArtLibrary.draw_loop(self, body if body != "" else sprite_file(), age)
	if fx != "":
		ArtLibrary.draw_loop(self, fx, age)
	_draw_attack_flash()
	_draw_telegraphs()
	if HitLibrary.show:
		HitLibrary.draw(self, sprite_file(), "body", Color(1.0, 0.86, 0.2, 0.95))
		HitLibrary.draw(self, sprite_file(), "threat", Color(1.0, 0.28, 0.32, 0.95))

func _draw_attack_flash() -> void:
	var pulse := 0.4 + 0.55 * absf(sin(age * 26.0))
	if _attack_id == "skull" and not telegraphs.is_empty():
		var item: Dictionary = telegraphs[0]
		var origin: Vector2 = item["pos"] - position
		var vel: Vector2 = item["velocity"]
		if vel.length_squared() > 1.0:
			var dir := vel.normalized()
			var ink := Color(0.55, 1.0, 0.72, pulse)
			draw_line(origin, origin + dir * 64.0, ink, 2.0)
			draw_circle(origin, 4.0, ink)
		return
	if _attack_id == "sweep" and not telegraphs.is_empty():
		var origin := BossCatalog.MOUTH
		var ink := Color(1.0, 0.42, 0.12, pulse)
		for angle in BossCatalog.sweep_angles(dragon_phase(), generation):
			var dir := Vector2(-cos(angle), sin(angle))
			draw_line(origin, origin + dir * 70.0, ink, 2.0)
		var safe := Color(0.75, 1.0, 0.86, pulse)
		for edge in [BossCatalog.SWEEP_HOLE_LO, BossCatalog.SWEEP_HOLE_HI]:
			var dir := Vector2(-cos(edge), sin(edge))
			draw_line(origin, origin + dir * 78.0, safe, 1.0)
		draw_circle(origin, 5.0, Color(1.0, 0.82, 0.4, pulse))
		return
	if _row_left <= 0.0:
		return
	if _attack_id != "charge" and _attack_id != "dive":
		return
	var y := _charge_y - position.y
	var x0 := 16.0 - position.x
	var x1 := -6.0
	var span := HitLibrary.vertical_span(sprite_file(), "threat")
	var half := maxf((span.y - span.x) * 0.5, 6.0)
	draw_rect(Rect2(Vector2(x0, y - half), Vector2(x1 - x0, half * 2.0)), Color(1.0, 0.28, 0.22, 0.28 * pulse))
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(1.0, 0.35, 0.28, pulse), 2.0)
	draw_line(Vector2(x0, y - 5.0), Vector2(x0, y + 5.0), Color(1.0, 0.86, 0.45, pulse), 1.0)
