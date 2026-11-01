extends Node2D
class_name EnemyActor

var id := 0
var kind := SpawnDirector.WISP
var hp := 1
var max_hp := 1
var radius := 12.0
var score_value := 100
var kind_name := "Wisp"
var alive := true
var age := 0.0
var flash := 0.0
var grazed := false
var phase := 0.0
var stop_y := 200.0
var origin_x := 0.0
var diving := false
var dive_velocity := Vector2.ZERO
var stopped := false
var shot_cooldown := 0.7
var fall_speed := 80.0

func setup(spawn_id: int, data: Dictionary, field: Vector2) -> void:
	id = spawn_id
	kind = int(data["kind"])
	kind_name = SpawnDirector.kind_name(kind)
	max_hp = SpawnDirector.max_hp(kind)
	hp = max_hp
	radius = SpawnDirector.body_radius(kind)
	score_value = SpawnDirector.score_value(kind)
	fall_speed = SpawnDirector.fall_speed(kind)
	phase = float(data["phase"])
	origin_x = clampf(float(data["x_ratio"]) * field.x, 28.0, field.x - 28.0)
	stop_y = clampf(float(data["stop_ratio"]) * field.y, 120.0, field.y * 0.46)
	position = Vector2(origin_x, -radius - 8.0)

func hurt(amount: int) -> void:
	if not alive:
		return
	hp -= amount
	flash = 0.08
	if hp <= 0:
		alive = false

func tick(delta: float, player_pos: Vector2) -> Array[Dictionary]:
	age += delta
	if flash > 0.0:
		flash = maxf(flash - delta, 0.0)
	var fired: Array[Dictionary] = []
	match kind:
		SpawnDirector.WISP:
			position.y += fall_speed * delta
			position.x = origin_x + sin(age * 1.35 + phase) * 32.0
		SpawnDirector.DART:
			position.y += fall_speed * delta
			position.x = origin_x + sin(age * 3.5 + phase) * 58.0
		SpawnDirector.TURRET:
			if not stopped:
				position.y += fall_speed * delta
				if position.y >= stop_y:
					position.y = stop_y
					stopped = true
					shot_cooldown = 0.55
			else:
				shot_cooldown -= delta
				if shot_cooldown <= 0.0:
					shot_cooldown = 1.2
					fired.append(_bolt(Vector2(0, 210)))
		SpawnDirector.FANG:
			if age < 0.55:
				position.y += fall_speed * delta
			elif not diving:
				diving = true
				var aim := player_pos - position
				if aim.length() < 1.0:
					aim = Vector2(0, 1)
				dive_velocity = aim.normalized() * 350.0
			else:
				position += dive_velocity * delta
	if is_inside_tree():
		queue_redraw()
	return fired

func _bolt(bolt_velocity: Vector2) -> Dictionary:
	return {
		"position": position + Vector2(0, radius + 2.0),
		"velocity": bolt_velocity,
		"gravity": 0.0,
		"damage": 1,
		"radius": 5.0,
		"splits": 0,
		"color": Color("ffb4b4"),
		"style": "bolt",
		"killer_name": kind_name,
	}

func _draw() -> void:
	var body := _body_color()
	if flash > 0.0:
		body = body.lerp(Color.WHITE, 0.75)
	match kind:
		SpawnDirector.WISP:
			var points := PackedVector2Array([
				Vector2(0, -radius),
				Vector2(radius, 0),
				Vector2(0, radius),
				Vector2(-radius, 0),
			])
			draw_colored_polygon(points, body)
			draw_rect(Rect2(-3, -3, 6, 6), Color("f4e8ff"))
		SpawnDirector.DART:
			var points := PackedVector2Array([
				Vector2(0, radius + 2),
				Vector2(-radius, -radius + 2),
				Vector2(radius, -radius + 2),
			])
			draw_colored_polygon(points, body)
		SpawnDirector.TURRET:
			draw_rect(Rect2(-radius, -radius + 2, radius * 2.0, radius * 2.0 - 4.0), body)
			draw_rect(Rect2(-4, radius - 4, 8, 10), Color("d7ecff"))
			draw_rect(Rect2(-2, -2, 4, 4), Color("071018"))
		SpawnDirector.FANG:
			var pulse := 1.0
			if not diving and age < 0.55 and fmod(age, 0.12) < 0.06:
				pulse = 0.35
				body = Color("ffd0d0")
			var points := PackedVector2Array([
				Vector2(0, radius + 4),
				Vector2(-radius, -radius),
				Vector2(radius, -radius),
			])
			draw_colored_polygon(points, body)
			draw_rect(Rect2(-2, -2, 3, 3), Color(1, 1, 1, pulse))
	if hp < max_hp and alive:
		var width := radius * 2.0
		var left := -radius
		var y := -radius - 6.0
		draw_rect(Rect2(left, y, width, 3), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(left, y, width * float(hp) / float(max_hp), 3), Color("f4efe4"))

func _body_color() -> Color:
	match kind:
		SpawnDirector.WISP:
			return Color("b388ff")
		SpawnDirector.DART:
			return Color("ffb020")
		SpawnDirector.TURRET:
			return Color("4aa3ff")
		SpawnDirector.FANG:
			return Color("ff4d4d")
		_:
			return Color.WHITE
