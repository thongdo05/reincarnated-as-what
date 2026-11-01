extends Node2D
class_name PlayerShip

## Relative drag: the finger moves an aim point, and the body chases it.
## The ship never jumps to the finger, so the thumb can stay out of the way.
## Slime accelerates slowly and keeps sliding. Goblin sprints, then plants.

var form_id := FormCatalog.Id.SLIME
var aim := Vector2.ZERO
var velocity := Vector2.ZERO
var radius := FormCatalog.SLIME_HIT_RADIUS
var alive := true
var invulnerable := true
var stride := 0.0
var sprinting := true
var _cooldown := 0.0
var _wobble := 0.0
var _trail_timer := 0.0
var _trail: Array[Vector2] = []

func setup(id: int, start: Vector2) -> void:
	form_id = id
	position = start
	aim = start
	radius = FormCatalog.hit_radius(id)
	_cooldown = 0.12

func add_drag(relative: Vector2, bounds: Rect2) -> void:
	aim += relative
	var pad := radius
	aim.x = clampf(aim.x, bounds.position.x + pad, bounds.end.x - pad)
	aim.y = clampf(aim.y, bounds.position.y + pad, bounds.end.y - pad)

func ready_to_fire() -> bool:
	return alive and _cooldown <= 0.0

func did_fire(interval: float) -> void:
	_cooldown = interval

func tick(delta: float, bounds: Rect2) -> void:
	_wobble += delta
	if _cooldown > 0.0:
		_cooldown -= delta
	if form_id == FormCatalog.Id.SLIME:
		_move_slime(delta)
		_record_trail(delta)
	else:
		_move_goblin(delta)
	_clamp(bounds)
	if invulnerable:
		modulate.a = 0.35 if fmod(_wobble, 0.16) < 0.08 else 1.0
	else:
		modulate.a = 1.0
	if is_inside_tree():
		queue_redraw()

func _move_slime(delta: float) -> void:
	var to_aim := aim - position
	var dist := to_aim.length()
	var desired := Vector2.ZERO
	if dist > 0.6:
		var speed := minf(FormCatalog.SLIME_MAX_SPEED, dist * FormCatalog.SLIME_ARRIVE)
		desired = to_aim / dist * speed
	velocity = velocity.move_toward(desired, FormCatalog.SLIME_ACCEL * delta)
	position += velocity * delta

func _move_goblin(delta: float) -> void:
	stride = fmod(stride + delta, FormCatalog.GOBLIN_STRIDE)
	sprinting = stride < FormCatalog.GOBLIN_STRIDE * FormCatalog.GOBLIN_SPRINT_FRACTION
	var to_aim := aim - position
	var dist := to_aim.length()
	var desired := Vector2.ZERO
	var accel := FormCatalog.GOBLIN_ACCEL
	if dist > 0.6:
		var cap := FormCatalog.GOBLIN_MAX_SPEED
		if not sprinting:
			cap *= FormCatalog.GOBLIN_PLANT_SPEED_SCALE
			accel *= 0.35
		var speed := minf(cap, dist * FormCatalog.GOBLIN_ARRIVE)
		desired = to_aim / dist * speed
	velocity = velocity.move_toward(desired, accel * delta)
	position += velocity * delta

func _clamp(bounds: Rect2) -> void:
	var min_x := bounds.position.x + radius
	var max_x := bounds.end.x - radius
	var min_y := bounds.position.y + radius
	var max_y := bounds.end.y - radius
	if position.x < min_x or position.x > max_x:
		velocity.x = 0.0
	if position.y < min_y or position.y > max_y:
		velocity.y = 0.0
	position.x = clampf(position.x, min_x, max_x)
	position.y = clampf(position.y, min_y, max_y)

func _record_trail(delta: float) -> void:
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = 0.045
	_trail.push_front(position)
	while _trail.size() > 5:
		_trail.pop_back()

func _draw() -> void:
	if form_id == FormCatalog.Id.SLIME:
		_draw_slime()
	else:
		_draw_goblin()

func _draw_slime() -> void:
	var i := _trail.size()
	for point in _trail:
		i -= 1
		var blob := Color("176b2c")
		blob.a = 0.18 + 0.1 * float(i)
		var size := 8.0 + float(i) * 2.0
		var local := point - position
		draw_rect(Rect2(local - Vector2(size, size) * 0.5, Vector2(size, size)), blob)
	var squash := 1.0 + sin(_wobble * 7.0) * 0.07
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 / squash, squash))
	draw_rect(Rect2(-16, -13, 32, 26), Color("176b2c"))
	draw_rect(Rect2(-14, -16, 26, 10), Color("2f9e45"))
	draw_rect(Rect2(-18, -4, 8, 12), Color("248a38"))
	draw_rect(Rect2(10, -2, 8, 14), Color("34a844"))
	draw_rect(Rect2(-6, -18, 14, 8), Color("b6ffbf"))
	draw_rect(Rect2(-9, -3, 6, 6), Color("f4fff4"))
	draw_rect(Rect2(3, -2, 6, 6), Color("f4fff4"))
	draw_rect(Rect2(-7, -1, 3, 3), Color("14200f"))
	draw_rect(Rect2(5, 0, 3, 3), Color("14200f"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_goblin() -> void:
	if sprinting and velocity.length() > 30.0:
		var back := -velocity.normalized() * 12.0
		draw_rect(Rect2(back + Vector2(-5, 2), Vector2(4, 3)), Color("6a5640"))
		draw_rect(Rect2(back + Vector2(2, 5), Vector2(3, 3)), Color("8a7058"))
	# Tiny crown, a size too proud for the head under it.
	draw_rect(Rect2(-7, -20, 14, 3), Color("ffd15c"))
	draw_rect(Rect2(-7, -24, 3, 6), Color("ffd15c"))
	draw_rect(Rect2(-1, -27, 3, 9), Color("ffe08a"))
	draw_rect(Rect2(4, -24, 3, 6), Color("ffd15c"))
	draw_rect(Rect2(-6, -16, 12, 9), Color("7ea14a"))
	draw_rect(Rect2(-8, -13, 3, 4), Color("6d8c3e"))
	draw_rect(Rect2(5, -13, 3, 4), Color("6d8c3e"))
	draw_rect(Rect2(-5, -6, 10, 10), Color("8a4b2f"))
	draw_rect(Rect2(-4, -13, 2, 2), Color("14200f"))
	draw_rect(Rect2(2, -13, 2, 2), Color("14200f"))
	var step := 2.0 if sprinting else 0.0
	draw_rect(Rect2(-5, 4, 3, 4 + step), Color("5c3a24"))
	draw_rect(Rect2(2, 4, 3, 4 + step), Color("5c3a24"))
