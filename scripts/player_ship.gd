extends Node2D
class_name PlayerShip

## Relative drag: the finger moves an aim point, and the body chases it.
## The ship never jumps to the finger, so the thumb can stay out of the way.
## Slime accelerates slowly and keeps sliding. Goblin sprints, then plants.

var form_id := FormCatalog.Id.SLIME
var aim := Vector2.ZERO
var velocity := Vector2.ZERO
var radius := 8.0
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

func setup(id: int, start: Vector2) -> void:
	form_id = id
	position = start
	aim = start
	_cooldown = 0.12
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

func sprite_name() -> String:
	var spec := FormCatalog.rank_spec(form_id, rank_index)
	if small and spec.has("sprite_small"):
		return str(spec["sprite_small"])
	return str(spec["sprite"])

func _apply_radius() -> void:
	radius = FormCatalog.hit_radius_for(form_id, rank_index, small)

func _draw() -> void:
	var file := sprite_name()
	if form_id == FormCatalog.Id.SLIME:
		var i := _trail.size()
		for point in _trail:
			i -= 1
			var tint := Color(1, 1, 1, 0.10 + 0.07 * float(i))
			ArtLibrary.draw_loop(self, file, _wobble, point - position, tint)
	ArtLibrary.draw_loop(self, file, _wobble)
	if HitLibrary.show:
		HitLibrary.draw(self, file, "hurt", Color(0.35, 1.0, 0.55, 0.95))
