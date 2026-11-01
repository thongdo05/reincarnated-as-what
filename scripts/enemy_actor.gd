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
var flash := 0.0
var grazed := false
var phase := 0.0
var stop_x := 500.0
var origin_y := 0.0
var stopped := false
var shot_cooldown := 0.7
var speed := 80.0
var on_ceiling := false
var field_size := Vector2(780, 360)

func setup(spawn_id: int, data: Dictionary, field: Vector2) -> void:
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
	var lane := float(data["x_ratio"])
	origin_y = clampf(lane * field.y, 40.0, field.y - 40.0)
	on_ceiling = lane < 0.5
	var park := clampf(0.62 + float(data["stop_ratio"]) * 0.55, 0.62, 0.9)
	stop_x = field.x * park
	if kind == SpawnDirector.ARCHER:
		var edge_y := 18.0 if on_ceiling else field.y - 18.0
		position = Vector2(field.x + radius + 16.0, edge_y)
	else:
		position = Vector2(field.x + radius + 16.0, origin_y)

func hurt(amount: int) -> void:
	if not alive:
		return
	hp -= amount
	flash = 0.08
	if hp <= 0:
		alive = false

func tick(delta: float, _player_pos: Vector2) -> Array[Dictionary]:
	age += delta
	if flash > 0.0:
		flash = maxf(flash - delta, 0.0)
	var fired: Array[Dictionary] = []
	match kind:
		SpawnDirector.EYE:
			position.x -= speed * delta
			position.y = origin_y + sin(age * 1.6 + phase) * 20.0
		SpawnDirector.WOLF:
			position.x -= speed * delta
			position.y = origin_y + sin(age * 1.1 + phase) * 6.0
		SpawnDirector.ARCHER:
			if not stopped:
				position.x -= speed * delta
				if position.x <= stop_x:
					position.x = stop_x
					stopped = true
					shot_cooldown = 0.55
			else:
				shot_cooldown -= delta
				if shot_cooldown <= 0.0:
					shot_cooldown = 1.2
					fired.append(_bolt(Vector2(-240, 0), Vector2(-radius - 6.0, -2.0)))
		SpawnDirector.WYVERN:
			position.x -= speed * delta
			position.y = origin_y + sin(age * 2.3 + phase) * 36.0
	if kind == SpawnDirector.EYE or kind == SpawnDirector.WOLF or kind == SpawnDirector.WYVERN:
		position.y = clampf(position.y, 30.0, field_size.y - 30.0)
	if is_inside_tree():
		queue_redraw()
	return fired

func _bolt(bolt_velocity: Vector2, offset: Vector2) -> Dictionary:
	return {
		"position": position + offset,
		"velocity": bolt_velocity,
		"gravity": 0.0,
		"damage": 1,
		"radius": 5.0,
		"splits": 0,
		"color": Color("f0d78c"),
		"style": "arrow",
		"killer_name": kind_name,
	}

func _draw() -> void:
	match kind:
		SpawnDirector.EYE:
			draw_circle(Vector2.ZERO, radius + 2.0, Color("ff8ad4"))
			draw_circle(Vector2.ZERO, radius, Color("fff8ee"))
			draw_circle(Vector2(-1, 0), radius * 0.55, Color("e0239a"))
			draw_circle(Vector2(-1, 0), radius * 0.24, Color("1a1020"))
			draw_rect(Rect2(-radius * 0.35, -radius * 0.45, 3, 3), Color("ffffff"))
		SpawnDirector.WOLF:
			draw_rect(Rect2(-12, -4, 26, 12), Color("2a1c18"))
			draw_rect(Rect2(-22, -8, 14, 11), Color("4a3028"))
			draw_rect(Rect2(-28, -3, 8, 5), Color("6a4638"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-16, -8), Vector2(-12, -15), Vector2(-8, -8),
			]), Color("3a241e"))
			draw_rect(Rect2(-18, -6, 3, 3), Color("ffb020"))
			draw_rect(Rect2(-8, 6, 4, 5), Color("2a1c18"))
			draw_rect(Rect2(4, 6, 4, 5), Color("2a1c18"))
			draw_rect(Rect2(-26, -1, 3, 2), Color("f4efe4"))
		SpawnDirector.ARCHER:
			draw_rect(Rect2(-6, -16, 12, 10), Color("f6f0e4"))
			draw_rect(Rect2(-4, -13, 3, 3), Color("1a1020"))
			draw_rect(Rect2(1, -13, 3, 3), Color("1a1020"))
			draw_rect(Rect2(-4, -6, 8, 12), Color("f0e6d2"))
			draw_rect(Rect2(-5, -2, 10, 2), Color("d9cbb4"))
			draw_rect(Rect2(-5, 2, 10, 2), Color("d9cbb4"))
			draw_line(Vector2(-14, -12), Vector2(-14, 8), Color("6a3a22"), 2.0)
			draw_line(Vector2(-14, -12), Vector2(-6, -2), Color("c9854a"), 1.5)
			draw_line(Vector2(-14, 8), Vector2(-6, -2), Color("c9854a"), 1.5)
			var foot := -radius - 4.0 if on_ceiling else radius - 2.0
			draw_rect(Rect2(-8, foot, 16, 4), Color("6a4630"))
		SpawnDirector.WYVERN:
			var flap := sin(age * 8.0) * 4.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(-2, -2), Vector2(8, -4), Vector2(-4, -16 - flap),
			]), Color("ff5a2a"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-2, 2), Vector2(8, 4), Vector2(-4, 16 + flap),
			]), Color("e23b22"))
			draw_rect(Rect2(-8, -4, 22, 8), Color("c4382a"))
			draw_rect(Rect2(-16, -5, 10, 7), Color("ff6a3a"))
			draw_rect(Rect2(-14, -3, 2, 2), Color("1a1020"))
			draw_rect(Rect2(12, -2, 8, 3), Color("8a241c"))
	if flash > 0.0:
		draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), Color(1, 1, 1, 0.45))
	if hp < max_hp and alive:
		var width := radius * 2.0
		var left := -radius
		var y := -radius - 6.0
		draw_rect(Rect2(left, y, width, 3), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(left, y, width * float(hp) / float(max_hp), 3), Color("f4efe4"))
