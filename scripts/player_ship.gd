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
var small := false
var regrow_left := 0.0
var regrew := false
var rank_index := 0
var evolve_flash := 0.0

const REGROW_SECONDS := 15.0
const SMALL_SCALE := 0.62

func setup(id: int, start: Vector2) -> void:
	form_id = id
	position = start
	aim = start
	_cooldown = 0.12
	_apply_radius()

func add_drag(relative: Vector2, bounds: Rect2) -> void:
	aim += relative
	var pad := radius
	aim.x = clampf(aim.x, bounds.position.x + pad, bounds.end.x - pad)
	aim.y = clampf(aim.y, bounds.position.y + pad, bounds.end.y - pad)

## Slime trait, not an extra life. One life per run still holds.
## A full-size Slime spends that trait and becomes small. A hit while small ends the run.
func absorb_lethal_hit() -> bool:
	if form_id != FormCatalog.Id.SLIME or small:
		return false
	small = true
	regrow_left = REGROW_SECONDS
	_apply_radius()
	return true

func ready_to_fire() -> bool:
	return alive and _cooldown <= 0.0

func did_fire(interval: float) -> void:
	_cooldown = interval

func tick(delta: float, bounds: Rect2) -> void:
	_wobble += delta
	regrew = false
	if small:
		regrow_left -= delta
		if regrow_left <= 0.0:
			small = false
			regrow_left = 0.0
			regrew = true
			_apply_radius()
	if evolve_flash > 0.0:
		evolve_flash = maxf(evolve_flash - delta, 0.0)
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

func set_rank(index: int) -> void:
	rank_index = index
	evolve_flash = 0.4
	_apply_radius()

func _apply_radius() -> void:
	var spec_scale := float(FormCatalog.rank_spec(form_id, rank_index)["body_scale"])
	var base := FormCatalog.hit_radius(form_id) * spec_scale
	radius = base * (SMALL_SCALE if small else 1.0)

func _body_scale() -> float:
	var spec_scale := float(FormCatalog.rank_spec(form_id, rank_index)["body_scale"])
	return spec_scale * (SMALL_SCALE if small else 1.0)

func _draw() -> void:
	if form_id == FormCatalog.Id.SLIME:
		_draw_slime()
	else:
		_draw_goblin()
	if evolve_flash > 0.0:
		var alpha := clampf(evolve_flash / 0.4, 0.0, 0.65)
		draw_rect(Rect2(-28, -28, 56, 56), Color(1, 1, 1, alpha))

func _draw_slime() -> void:
	var i := _trail.size()
	for point in _trail:
		i -= 1
		var blob := Color("1a4f9c")
		blob.a = 0.18 + 0.1 * float(i)
		var size := 8.0 + float(i) * 2.0
		var local := point - position
		draw_rect(Rect2(local - Vector2(size, size) * 0.5, Vector2(size, size)), blob)
	var squash := 1.0 + sin(_wobble * 7.0) * 0.07
	var body_scale := _body_scale()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(body_scale / squash, body_scale * squash))
	draw_rect(Rect2(-18, -18, 36, 34), Color("10243f"))
	draw_rect(Rect2(-16, -13, 32, 26), Color("1a4f9c"))
	draw_rect(Rect2(-10, -16, 22, 10), Color("3b82f6"))
	draw_rect(Rect2(-18, -4, 8, 12), Color("2563c7"))
	draw_rect(Rect2(10, -6, 10, 14), Color("60a5fa"))
	draw_rect(Rect2(2, -18, 12, 8), Color("d7ecff"))
	draw_rect(Rect2(-8, -3, 6, 6), Color("f4fbff"))
	draw_rect(Rect2(4, -2, 6, 6), Color("f4fbff"))
	draw_rect(Rect2(-6, -1, 3, 3), Color("0c1424"))
	draw_rect(Rect2(6, 0, 3, 3), Color("0c1424"))
	if rank_index > 0:
		var shine := Color(1, 1, 1, 0.18 * float(rank_index))
		draw_rect(Rect2(-12, -14, 22, 10), shine)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_goblin() -> void:
	if sprinting and velocity.length() > 30.0:
		draw_rect(Rect2(-18, 2, 4, 3), Color("6a5640"))
		draw_rect(Rect2(-14, 6, 3, 3), Color("8a7058"))
	# Tiny crown, a size too proud for the head under it. Face points right.
	var body_scale := _body_scale()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(body_scale, body_scale))
	draw_rect(Rect2(-9, -22, 20, 30), Color("24180a"))
	draw_rect(Rect2(-6, -20, 12, 3), Color("ffd15c"))
	draw_rect(Rect2(-6, -24, 3, 6), Color("ffd15c"))
	draw_rect(Rect2(-1, -27, 3, 9), Color("ffe08a"))
	draw_rect(Rect2(3, -24, 3, 6), Color("ffd15c"))
	draw_rect(Rect2(-6, -16, 12, 9), Color("7ea14a"))
	draw_rect(Rect2(4, -13, 6, 5), Color("6d8c3e"))
	draw_rect(Rect2(1, -14, 2, 2), Color("14200f"))
	draw_rect(Rect2(-7, -7, 12, 9), Color("8a4b2f"))
	var step := 2.0 if sprinting else 0.0
	draw_rect(Rect2(-6, 2, 3, 5 + step), Color("5c3a24"))
	draw_rect(Rect2(1, 2, 3, 5 + step), Color("5c3a24"))
	if rank_index > 0:
		draw_rect(Rect2(-4, -26, 8, 3), Color(1, 1, 1, 0.25 * float(rank_index)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
