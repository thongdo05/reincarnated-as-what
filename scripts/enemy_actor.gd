extends Node2D
class_name EnemyActor

var id := 0
var kind := SpawnDirector.EYE
var hp := 1
var max_hp := 1
var radius := 12.0
var score_value := 100
var kind_name := "Floating Eye"
var alive := true
var age := 0.0
var grazed := false
var phase := 0.0
var stop_x := 360.0
var origin_y := 0.0
var stopped := false
var shot_cooldown := 1.6
var speed := 40.0
var on_island := false
var ride_island := 0
var ride_tex_x := 0.0
var planted_scroll := 0.0
var field_size := Vector2(480, 270)
var background: FieldBackground
var warn_left := 0.0
var wave_amp := 8.0
var y_bias := 0.0
var speed_scale := 1.0
var move_velocity := Vector2.ZERO
var hold_fire := false
## Shots promised by a telegraph. Each entry is left, velocity, offset, sprite.
var telegraphs: Array[Dictionary] = []
var _last_player := Vector2.ZERO
var _have_player := false

func setup(spawn_id: int, data: Dictionary, field: Vector2, field_background: FieldBackground) -> void:
	id = spawn_id
	kind = int(data["kind"])
	kind_name = SpawnDirector.kind_name(kind)
	max_hp = SpawnDirector.max_hp(kind)
	hp = max_hp
	radius = SpawnDirector.body_radius(kind)
	score_value = SpawnDirector.score_value(kind)
	speed = SpawnDirector.cruise_speed(kind)
	phase = float(data["phase"])
	field_size = field
	background = field_background
	wave_amp = float(data.get("wave_amp", 8.0))
	y_bias = float(data.get("y_bias", 0.0))
	hold_fire = bool(data.get("hold_fire", false))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var lane := float(data["x_ratio"])
	origin_y = clampf(lane * field.y + y_bias, 36.0, field.y - 96.0)
	var park := clampf(0.62 + float(data["stop_ratio"]) * 0.55, 0.62, 0.88)
	stop_x = field.x * park
	if kind == SpawnDirector.ANVIL or kind == SpawnDirector.PIANO:
		var span := maxf(field.x - 80.0, 40.0)
		# Straight down onto this column. The shadow is the telegraph.
		warn_left = Difficulty.hazard_warn()
		position = Vector2(40.0 + lane * span, -radius - 8.0)
	elif kind == SpawnDirector.ARCHER:
		on_island = lane < 0.45
		if on_island and background != null:
			ride_island = 0 if float(data["stop_ratio"]) < 0.28 else 1
			_mount_island()
		else:
			position = Vector2(field.x + radius + 20.0, FieldBackground.GROUND_FEET)
	else:
		position = Vector2(field.x + radius + 20.0, origin_y)
	if not FlappyMode.is_active() and kind != SpawnDirector.ANVIL and kind != SpawnDirector.PIANO:
		shot_cooldown = 0.5

func hurt(amount: int) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0:
		alive = false

func tick(delta: float, player_pos: Vector2, run_time: float = 0.0, scale: float = 1.0) -> Array[Dictionary]:
	age += delta
	speed_scale = maxf(scale, 0.05)
	speed = SpawnDirector.cruise_speed(kind) * speed_scale
	var player_vel := Vector2.ZERO
	if _have_player and delta > 0.0:
		player_vel = (player_pos - _last_player) / delta
	_last_player = player_pos
	_have_player = true
	var before := position
	var fired: Array[Dictionary] = []
	if warn_left > 0.0:
		warn_left -= delta
		if warn_left > 0.0:
			if is_inside_tree():
				queue_redraw()
			return fired
		delta = -warn_left
		warn_left = 0.0
	match kind:
		SpawnDirector.EYE:
			position.x -= speed * delta
			position.y = origin_y + sin(age * 1.5 + phase) * wave_amp
			if FlappyMode.is_active():
				_try_fire(fired, delta, 2.8, _lead(position + Vector2(-12, 0), player_pos, player_vel, 88.0 * speed_scale, run_time), "floating_eye_bolt.png", Vector2(-12, 0))
			else:
				_pattern_fire(fired, delta, player_pos, player_vel, run_time, 1.15, Vector2(-12, 0), "floating_eye_bolt.png")
		SpawnDirector.WOLF:
			position.x -= speed * delta
			var chase := Difficulty.wolf_chase(run_time) * speed
			position.y = move_toward(position.y, player_pos.y, chase * delta)
		SpawnDirector.ARCHER:
			_tick_archer(delta, fired, player_pos, player_vel, run_time)
		SpawnDirector.WYVERN:
			position.x -= speed * delta
			position.y = origin_y + sin(age * 2.1 + phase) * wave_amp
			if FlappyMode.is_active():
				_try_fire(fired, delta, 2.3, _lead(position + Vector2(-20, 4), player_pos, player_vel, 104.0 * speed_scale, run_time), "wyvern_shot.png", Vector2(-20, 4))
			else:
				_pattern_fire(fired, delta, player_pos, player_vel, run_time, 1.45, Vector2(-20, 4), "wyvern_shot.png")
		SpawnDirector.ANVIL, SpawnDirector.PIANO:
			position.y += Difficulty.fall_speed(kind) * speed_scale * delta
	if kind == SpawnDirector.EYE or kind == SpawnDirector.WOLF or kind == SpawnDirector.WYVERN:
		position.y = clampf(position.y, 28.0, field_size.y - 78.0)
	if delta > 0.0:
		move_velocity = (position - before) / delta
	_release_telegraphs(fired, delta)
	if is_inside_tree():
		queue_redraw()
	return fired

func _mount_island() -> void:
	var feet := background.island_feet(ride_island)
	var tex_x := FieldBackground.ISLANDS[ride_island].x
	var screen := tex_x - background.scroll_far
	var min_x := field_size.x * 0.72
	while screen < min_x:
		screen += FieldBackground.TILE_W
	while screen >= min_x + FieldBackground.TILE_W:
		screen -= FieldBackground.TILE_W
	ride_tex_x = screen + background.scroll_far
	position = Vector2(screen, feet)
	shot_cooldown = 1.8 if FlappyMode.is_active() else 0.85

func _tick_archer(delta: float, fired: Array[Dictionary], player_pos: Vector2, player_vel: Vector2, run_time: float) -> void:
	var muzzle := Vector2(-16, -26)
	var arrow_speed := 116.0 * speed_scale
	if on_island and background != null:
		position.x = ride_tex_x - background.scroll_far
		position.y = background.island_feet(ride_island)
		if position.x < -40.0:
			alive = false
			return
		if FlappyMode.is_active():
			_try_fire(fired, delta, 1.9, _lead(position + muzzle, player_pos, player_vel, arrow_speed, run_time), "arrow.png", muzzle)
		else:
			_pattern_fire(fired, delta, player_pos, player_vel, run_time, 1.25, muzzle, "arrow.png")
		return
	if not stopped:
		position.x -= speed * delta
		position.y = FieldBackground.GROUND_FEET
		if position.x <= stop_x:
			position.x = stop_x
			stopped = true
			planted_scroll = background.scroll_near if background != null else 0.0
			shot_cooldown = 1.15 if FlappyMode.is_active() else 0.7
	else:
		if background != null:
			position.x = stop_x - (background.scroll_near - planted_scroll)
		position.y = FieldBackground.GROUND_FEET
		if position.x < -40.0:
			alive = false
			return
		if FlappyMode.is_active():
			_try_fire(fired, delta, 1.9, _lead(position + muzzle, player_pos, player_vel, arrow_speed, run_time), "arrow.png", muzzle)
		else:
			_pattern_fire(fired, delta, player_pos, player_vel, run_time, 1.25, muzzle, "arrow.png")

func _pattern_fire(fired: Array[Dictionary], delta: float, player_pos: Vector2, player_vel: Vector2, run_time: float, interval: float, offset: Vector2, sprite: String) -> void:
	if hold_fire:
		return
	if not telegraphs.is_empty():
		return
	shot_cooldown -= delta
	if shot_cooldown > 0.0:
		return
	var bolt_speed := Difficulty.pattern_speed(kind, run_time)
	var aim := _lead(position + offset, player_pos, player_vel, bolt_speed, run_time)
	var windup := Difficulty.telegraph_for(aim.length())
	shot_cooldown = interval
	for off_y in Difficulty.fan_offsets(run_time):
		_commit_shot(fired, aim, offset + Vector2(0.0, float(off_y)), sprite, windup)

func _commit_shot(fired: Array[Dictionary], bolt_velocity: Vector2, offset: Vector2, sprite: String, windup: float) -> void:
	if windup <= 0.02:
		fired.append(_bolt(bolt_velocity, offset, sprite))
		return
	# Lock the muzzle in world space. The body can keep moving; the shot
	# still leaves from the point the telegraph showed.
	telegraphs.append({
		"left": windup,
		"velocity": bolt_velocity,
		"pos": position + offset,
		"sprite": sprite,
	})

func _release_telegraphs(fired: Array[Dictionary], delta: float) -> void:
	if telegraphs.is_empty():
		return
	var still: Array[Dictionary] = []
	for item in telegraphs:
		var left := float(item["left"]) - delta
		if left <= 0.0:
			var world: Vector2 = item["pos"]
			fired.append(_bolt(item["velocity"], world - position, str(item["sprite"])))
		else:
			item["left"] = left
			still.append(item)
	telegraphs = still

func _try_fire(fired: Array[Dictionary], delta: float, interval: float, bolt_velocity: Vector2, sprite: String, offset: Vector2) -> void:
	if hold_fire:
		return
	# shot_cooldown starts above zero, so a spawn on the right edge cannot snipe.
	shot_cooldown -= delta
	if shot_cooldown > 0.0:
		return
	shot_cooldown = interval
	fired.append(_bolt(bolt_velocity, offset, sprite))

func _lead(from: Vector2, player_pos: Vector2, player_vel: Vector2, shot_speed: float, run_time: float) -> Vector2:
	var speed_abs := maxf(shot_speed, 1.0)
	var flat := Vector2(-speed_abs, 0.0)
	var travel := clampf(from.distance_to(player_pos) / speed_abs, 0.0, 0.55)
	var aim := player_pos + player_vel * travel
	var to := aim - from
	if to.length() < 1.0:
		return flat
	var aimed := to.normalized() * speed_abs
	var mixed := flat.lerp(aimed, Difficulty.aim_amount(run_time))
	if mixed.length() < 1.0:
		return flat
	return mixed.normalized() * speed_abs

func _bolt(bolt_velocity: Vector2, offset: Vector2, sprite: String) -> Dictionary:
	return {
		"position": position + offset,
		"velocity": bolt_velocity,
		"gravity": 0.0,
		"damage": 1,
		"radius": HitLibrary.bounds_radius(sprite, "threat"),
		"splits": 0,
		"color": Color("f0d78c"),
		"style": "arrow" if sprite == "arrow.png" else "blob",
		"sprite": sprite,
		"killer_name": kind_name,
	}

func _draw() -> void:
	if warn_left > 0.0:
		_draw_warning()
		return
	_draw_telegraphs()
	var file := SpawnDirector.sprite_for(kind)
	# Enemies and hazards are drawn facing the way the files face. Do not flip.
	ArtLibrary.draw_loop(self, file, age)
	if HitLibrary.show:
		HitLibrary.draw(self, file, "body", Color(1.0, 0.86, 0.2, 0.95))
		HitLibrary.draw(self, file, "threat", Color(1.0, 0.28, 0.32, 0.95))
	if hp < max_hp and alive:
		var box := ArtLibrary.art_bbox(file)
		var width := maxf(box.x * 0.55, 8.0)
		var left := -width * 0.5
		var y := -ArtLibrary.anchor(file).y - 3.0
		draw_rect(Rect2(left, y, width, 2), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(left, y, width * float(hp) / float(max_hp), 2), Color("f4efe4"))

func _draw_telegraphs() -> void:
	if telegraphs.is_empty():
		return
	var pulse := 0.45 + 0.45 * absf(sin(age * 28.0))
	var ink := Color(1.0, 0.82, 0.35, pulse)
	for item in telegraphs:
		var origin: Vector2 = item["pos"] - position
		var vel: Vector2 = item["velocity"]
		if vel.length_squared() < 1.0:
			continue
		var dir := vel.normalized()
		draw_line(origin, origin + dir * 16.0, ink, 1.0)
		draw_arc(origin, 3.0, 0.0, TAU, 8, ink, 1.0, true)

func _draw_warning() -> void:
	var local_y := FieldBackground.GROUND_FEET - position.y
	var pulse := 0.4 + 0.45 * absf(sin((Difficulty.HAZARD_WARN - warn_left) * 28.0))
	draw_rect(Rect2(Vector2(-16, local_y - 1), Vector2(32, 4)), Color(0.05, 0.03, 0.08, pulse))
	draw_rect(Rect2(Vector2(-7, local_y - 3), Vector2(14, 2)), Color(0.55, 0.28, 0.72, pulse))
