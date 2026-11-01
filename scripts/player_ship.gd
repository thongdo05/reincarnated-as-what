extends Node2D
class_name PlayerShip

## Relative drag: the finger moves an aim point, and the body snaps to it.
## The ship never jumps to the finger, so the thumb can stay out of the way.
## Both forms arrive in about 1-3 frames, with no slide. A slime squash and a
## goblin lean are drawn only. They do not lag the hurtbox.

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
var _pose := 0.0
var small := false
var regrow_left := 0.0
var regrew := false
var rank_index := 0
var evolve_flash := 0.0
var evolve_t := -1.0
var evolve_hold := 1.0
var evolve_final := false
var evolve_old := ""
var evolve_new := ""
var fx_mode := ""
var fx_sprite := ""
var fx_show_rim := false
var _evolve_fx: EvolveFx

const REGROW_SECONDS := 15.0

## Afterimages behind a moving slime. The split body is small on the pastel
## sky, so it keeps fewer, fainter copies than the full form.
const TRAIL_COPIES := 5
const TRAIL_ALPHA_FAR := 0.10
const TRAIL_ALPHA_NEAR := 0.38
const SPLIT_TRAIL_COPIES := 3
const SPLIT_TRAIL_ALPHA_FAR := 0.08
const SPLIT_TRAIL_ALPHA_NEAR := 0.25

func setup(id: int, start: Vector2) -> void:
	form_id = id
	position = start
	aim = start
	_cooldown = 0.12
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_evolve_fx = EvolveFx.new()
	_evolve_fx.z_index = 2
	add_child(_evolve_fx)
	_apply_radius()

func add_drag(relative: Vector2, bounds: Rect2) -> void:
	aim += relative
	_clamp_aim(bounds)

## One catch-up step. Pointer input calls this immediately so the body does
## not wait for the next process tick.
func nudge(relative: Vector2, bounds: Rect2, step: float = 1.0 / 60.0) -> void:
	add_drag(relative, bounds)
	_pursue(step)
	_clamp(bounds)

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
	if evolve_t >= 0.0:
		evolve_t += delta
		_apply_evolve_visual()
	if _cooldown > 0.0:
		_cooldown -= delta
	if form_id == FormCatalog.Id.GOBLIN:
		stride = fmod(stride + delta, FormCatalog.goblin_f("stride"))
		sprinting = stride < FormCatalog.goblin_f("stride") * FormCatalog.goblin_f("sprint_fraction")
	var before := position
	# Flappy replaces the snap-to-aim chase. The pose is drawn only, so the
	# hurt shape stays on the body either way.
	if FlappyMode.is_active():
		FlappyMode.integrate_ship(self, delta, bounds)
	else:
		_pursue(delta)
	if position.distance_to(before) > 0.2:
		_pose = 1.0
	else:
		_pose = maxf(_pose - delta * 7.0, 0.0)
	if form_id == FormCatalog.Id.SLIME:
		_record_trail(delta)
	if not FlappyMode.is_active():
		_clamp(bounds)
	if invulnerable:
		modulate.a = 0.35 if fmod(_wobble, 0.16) < 0.08 else 1.0
	else:
		modulate.a = 1.0
	if is_inside_tree():
		queue_redraw()

func _pursue(delta: float) -> void:
	var to_aim := aim - position
	var dist := to_aim.length()
	if dist <= 0.35:
		position = aim
		velocity = Vector2.ZERO
		return
	var gain := 1.0 - exp(-FormCatalog.SNAP_ARRIVE * delta)
	var step := to_aim * gain
	var cap := FormCatalog.SNAP_MAX_SPEED * delta
	if step.length() > cap:
		step = to_aim / dist * cap
	if step.length() >= dist - 0.35:
		position = aim
	else:
		position += step
	velocity = Vector2.ZERO

func _clamp_aim(bounds: Rect2) -> void:
	var pad := radius
	aim.x = clampf(aim.x, bounds.position.x + pad, bounds.end.x - pad)
	aim.y = clampf(aim.y, bounds.position.y + pad, bounds.end.y - pad)

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
	_trim_trail()

func set_rank(index: int) -> void:
	rank_index = index
	evolve_flash = 0.4
	_apply_radius()

func begin_evolve(old_sprite: String, new_sprite: String, final: bool = false) -> void:
	evolve_old = old_sprite
	evolve_new = new_sprite
	evolve_final = final
	evolve_hold = Difficulty.FINAL_HOLD if final else FxTimeline.EVOLVE_HOLD
	evolve_t = 0.0
	_apply_evolve_visual()

func _apply_evolve_visual() -> void:
	var stage := FxTimeline.evolve_stage(evolve_t, evolve_hold)
	if stage == "glow":
		fx_mode = "glow"
		fx_sprite = evolve_old
		fx_show_rim = FxTimeline.evolve_shows_rim(evolve_t)
	elif stage == "flash":
		fx_mode = "flash"
		fx_sprite = FxTimeline.flash_file(evolve_new)
		fx_show_rim = false
	elif stage == "pop":
		fx_mode = ""
		fx_sprite = ""
		fx_show_rim = false
	else:
		fx_mode = ""
		fx_sprite = ""
		fx_show_rim = false
		evolve_t = -1.0
	if _evolve_fx != null:
		_evolve_fx.play(99.0 if evolve_t < 0.0 else evolve_t)

func _draw() -> void:
	_begin_pose()
	if fx_mode == "flash":
		ArtLibrary.draw_anchored(self, fx_sprite)
	elif fx_mode == "glow":
		_draw_body(fx_sprite)
		if fx_show_rim:
			ArtLibrary.draw_anchored(self, FxTimeline.rim_file(fx_sprite))
	else:
		_draw_body(sprite_name())
		_draw_final_banner()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if HitLibrary.show:
		HitLibrary.draw(self, sprite_name(), "hurt", Color(0.35, 1.0, 0.55, 0.95))

## Squash and lean stay under about a pixel on these sprites, and the hurt
## overlay is drawn after the pose is cleared so it matches the collision.
func _begin_pose() -> void:
	if _pose <= 0.01:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if form_id == FormCatalog.Id.SLIME:
		var squash := 0.06 * _pose
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + squash, 1.0 - squash * 0.75))
	else:
		var lean := (-0.045 if sprinting else 0.025) * _pose
		draw_set_transform(Vector2.ZERO, lean, Vector2.ONE)

func _draw_final_banner() -> void:
	if not evolve_final or evolve_t < 0.0:
		return
	if FxTimeline.evolve_stage(evolve_t, evolve_hold) != "pop":
		return
	var tex := PixelFont.outlined_texture("FINAL FORM!", Color("ffe56a"))
	var size := tex.get_size() * 2.0
	draw_texture_rect(tex, Rect2(Vector2(-size.x * 0.5, -60.0), size), false)

func _trail_copies() -> int:
	return SPLIT_TRAIL_COPIES if small else TRAIL_COPIES

func _trail_alpha(age_index: int) -> float:
	var copies := _trail_copies()
	var far := SPLIT_TRAIL_ALPHA_FAR if small else TRAIL_ALPHA_FAR
	var near := SPLIT_TRAIL_ALPHA_NEAR if small else TRAIL_ALPHA_NEAR
	if copies <= 1:
		return near
	return lerpf(far, near, float(age_index) / float(copies - 1))

func _trim_trail() -> void:
	var copies := _trail_copies()
	while _trail.size() > copies:
		_trail.pop_back()

func _draw_body(file: String) -> void:
	if form_id == FormCatalog.Id.SLIME:
		_trim_trail()
		var i := _trail.size()
		for point in _trail:
			i -= 1
			var tint := Color(1, 1, 1, _trail_alpha(i))
			ArtLibrary.draw_loop(self, file, _wobble, point - position, tint)
	ArtLibrary.draw_loop(self, file, _wobble)

func sprite_name() -> String:
	var spec := FormCatalog.rank_spec(form_id, rank_index)
	if small and spec.has("sprite_small"):
		return str(spec["sprite_small"])
	return str(spec["sprite"])

func _apply_radius() -> void:
	radius = FormCatalog.hit_radius_for(form_id, rank_index, small)

