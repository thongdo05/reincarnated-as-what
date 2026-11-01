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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var lane := float(data["x_ratio"])
	origin_y = clampf(lane * field.y, 36.0, field.y - 96.0)
	var park := clampf(0.62 + float(data["stop_ratio"]) * 0.55, 0.62, 0.88)
	stop_x = field.x * park
	if kind == SpawnDirector.ANVIL or kind == SpawnDirector.PIANO:
		var span := maxf(field.x - 80.0, 40.0)
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

func hurt(amount: int) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0:
		alive = false

func tick(delta: float, _player_pos: Vector2) -> Array[Dictionary]:
	age += delta
	var fired: Array[Dictionary] = []
	match kind:
		SpawnDirector.EYE:
			position.x -= speed * delta
			position.y = origin_y + sin(age * 1.5 + phase) * 8.0
			_try_fire(fired, delta, 2.6, Vector2(-88, 0), "floating_eye_bolt.png", Vector2(-12, 0))
		SpawnDirector.WOLF:
			position.x -= speed * delta
			position.y = origin_y + sin(age * 1.1 + phase) * 3.0
		SpawnDirector.ARCHER:
			_tick_archer(delta, fired)
		SpawnDirector.WYVERN:
			position.x -= speed * delta
			position.y = origin_y + sin(age * 2.1 + phase) * 12.0
			_try_fire(fired, delta, 2.2, Vector2(-104, 8), "wyvern_shot.png", Vector2(-20, 4))
		SpawnDirector.ANVIL:
			position.x -= 16.0 * delta
			position.y += 96.0 * delta
		SpawnDirector.PIANO:
			position.x -= 12.0 * delta
			position.y += 62.0 * delta
	if kind == SpawnDirector.EYE or kind == SpawnDirector.WOLF or kind == SpawnDirector.WYVERN:
		position.y = clampf(position.y, 28.0, field_size.y - 78.0)
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
	shot_cooldown = 1.8

func _tick_archer(delta: float, fired: Array[Dictionary]) -> void:
	if on_island and background != null:
		position.x = ride_tex_x - background.scroll_far
		position.y = background.island_feet(ride_island)
		if position.x < -40.0:
			alive = false
			return
		_try_fire(fired, delta, 1.7, Vector2(-116, 0), "arrow.png", Vector2(-16, -26))
		return
	if not stopped:
		position.x -= speed * delta
		position.y = FieldBackground.GROUND_FEET
		if position.x <= stop_x:
			position.x = stop_x
			stopped = true
			planted_scroll = background.scroll_near if background != null else 0.0
			shot_cooldown = 1.4
	else:
		if background != null:
			position.x = stop_x - (background.scroll_near - planted_scroll)
		position.y = FieldBackground.GROUND_FEET
		if position.x < -40.0:
			alive = false
			return
		_try_fire(fired, delta, 1.7, Vector2(-116, 0), "arrow.png", Vector2(-16, -26))

func _try_fire(fired: Array[Dictionary], delta: float, interval: float, bolt_velocity: Vector2, sprite: String, offset: Vector2) -> void:
	# shot_cooldown starts above zero, so a spawn on the right edge cannot snipe.
	shot_cooldown -= delta
	if shot_cooldown > 0.0:
		return
	shot_cooldown = interval
	fired.append(_bolt(bolt_velocity, offset, sprite))

func _bolt(bolt_velocity: Vector2, offset: Vector2, sprite: String) -> Dictionary:
	return {
		"position": position + offset,
		"velocity": bolt_velocity,
		"gravity": 0.0,
		"damage": 1,
		"radius": ArtLibrary.radius_for(sprite, 0.62),
		"splits": 0,
		"color": Color("f0d78c"),
		"style": "arrow" if sprite == "arrow.png" else "blob",
		"sprite": sprite,
		"killer_name": kind_name,
	}

func _draw() -> void:
	var file := SpawnDirector.sprite_for(kind)
	# Enemies and hazards are drawn facing the way the files face. Do not flip.
	ArtLibrary.draw_loop(self, file, age)
	if hp < max_hp and alive:
		var box := ArtLibrary.art_bbox(file)
		var width := maxf(box.x * 0.55, 8.0)
		var left := -width * 0.5
		var y := -ArtLibrary.anchor(file).y - 3.0
		draw_rect(Rect2(left, y, width, 2), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(left, y, width * float(hp) / float(max_hp), 2), Color("f4efe4"))
