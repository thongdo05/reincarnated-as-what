extends Node2D
class_name PlayerShip

## Relative drag: the finger moves an aim point, and the body follows it.
## The ship never jumps to the finger, so the thumb can stay out of the way.
## Snap forms arrive in about 1-3 frames, with no slide. Vending trails the
## aim for a few frames and still finishes a flick quickly. Cat blinks a short
## dash when the aim jumps, then snaps the rest. Squash, bob, rock, and recoil
## are drawn only. They do not move the hurt circle.

var form_id := FormCatalog.Id.SLIME
## Extra fit on top of FormCatalog.play_scale. 1 for every form except a
## dragon that had to shrink to the body it replaced.
var fit_scale := 1.0
var rear := 0.0
var aim := Vector2.ZERO
var velocity := Vector2.ZERO
var radius := 8.0
var alive := true
var invulnerable := true
var stride := 0.0
var sprinting := true
var _cooldown := 0.0
var _blink_cd := 0.0
## Seconds left where a Cat dash cannot be hit.
var blink_guard := 0.0
var _wobble := 0.0
var _trail_timer := 0.0
var _trail: Array[Vector2] = []
var _pose := 0.0
var _recoil := 0.0
var _recoil_lock := 0.0
var _clunk := 0.0
var _was_stepping := false
var _dash_flick := 0.0
var _dash_lean := 0.0
var _dash_offset := Vector2.ZERO
var small := false
var regrow_left := 0.0
var regrew := false
var rank_index := 0
var power_level := 0
var evolve_flash := 0.0
var evolve_t := -1.0
var evolve_hold := 1.0
var evolve_final := false
var evolve_old := ""
var evolve_new := ""
var fx_mode := ""
var fx_sprite := ""
var fx_show_rim := false
var shield_hits := 0
var _evolve_fx: EvolveFx
var _banner: Texture2D
var _aura_layer: Node2D

const REGROW_SECONDS := 15.0

## Afterimages behind a moving slime. The split body is small on the pastel
## sky, so it keeps fewer, fainter copies than the full form.
const TRAIL_COPIES := 5
const TRAIL_ALPHA_FAR := 0.10
const TRAIL_ALPHA_NEAR := 0.38
const SPLIT_TRAIL_COPIES := 3
const SPLIT_TRAIL_ALPHA_FAR := 0.08
const SPLIT_TRAIL_ALPHA_NEAR := 0.25

## Draw-only motion, about 1–2 px. The hurt overlay is drawn after this pose
## is cleared, so the HitLibrary circle stays on the collision.
const RECOIL_PX := 1.0
const RECOIL_RETURN := 16.0
const RECOIL_LOCK := 0.12
const GOBLIN_HOP_PX := 2.0
const GOBLIN_PLANT_PX := 1.0
const GOBLIN_IDLE_PX := 1.0
const GOBLIN_HOP_RATE := 11.0
const GOBLIN_IDLE_RATE := 2.8
const VENDING_ROCK_IDLE := 0.04
const VENDING_ROCK_MOVE := 0.07
const VENDING_SWAY_IDLE := 1.0
const VENDING_SWAY_MOVE := 2.0
const VENDING_RATE_IDLE := 1.35
const VENDING_RATE_MOVE := 2.05
const VENDING_CLUNK_PX := 2.0
const VENDING_CLUNK_TILT := 0.07
const VENDING_CLUNK_DECAY := 6.0
const CAT_IDLE_PX := 1.0
const CAT_IDLE_RATE := 2.1
const CAT_IDLE_TILT := 0.07
const CAT_IDLE_TILT_RATE := 1.7
const CAT_DASH_PX := 1.0
const CAT_DASH_TILT := 0.14
const CAT_FLICK_RETURN := 10.0
const DEMON_IDLE_PX := 1.0
const DEMON_MOVE_PX := 2.0
const DEMON_FLOAT_RATE := 1.7
const SLIME_IDLE_BOB := 1.0
const SLIME_IDLE_RATE := 2.6
const SLIME_SQUASH := 0.06
const SLIME_BREATHE := 0.04
const SLIME_BREATHE_RATE := 3.2
## Jackpot rays are the widest aura. They sit under enemies and enemy shots,
## and they are dimmed so a bullet in front of a ray still reads.
const VENDING_RAY_ALPHA := 0.6
const VENDING_RAY_Z := 1

func setup(id: int, start: Vector2) -> void:
	form_id = id
	position = start
	aim = start
	_cooldown = 0.12
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_evolve_fx = EvolveFx.new()
	_evolve_fx.z_index = 2
	add_child(_evolve_fx)
	_aura_layer = Node2D.new()
	_aura_layer.name = "BackAura"
	_aura_layer.z_as_relative = false
	_aura_layer.z_index = VENDING_RAY_Z
	_aura_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_aura_layer.draw.connect(_draw_back_aura)
	add_child(_aura_layer)
	_banner = PixelFont.outlined_texture("FINAL FORM!", Color("ffe56a"))
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

## One kick per volley, and not on every bullet of a fast stream.
func note_shot() -> void:
	if _recoil_lock > 0.0:
		return
	_recoil = 1.0
	_recoil_lock = RECOIL_LOCK

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
	if blink_guard > 0.0:
		blink_guard = maxf(blink_guard - delta, 0.0)
	if form_id == FormCatalog.Id.GOBLIN:
		stride = fmod(stride + delta, FormCatalog.goblin_f("stride"))
		sprinting = stride < FormCatalog.goblin_f("stride") * FormCatalog.goblin_f("sprint_fraction")
	var before := position
	_pursue(delta)
	var stepped := position.distance_to(before) > 0.2
	if stepped:
		_pose = 1.0
	else:
		_pose = maxf(_pose - delta * 7.0, 0.0)
	if form_id == FormCatalog.Id.VENDING and _was_stepping and not stepped:
		_clunk = 1.0
	_was_stepping = stepped
	if _clunk > 0.0:
		_clunk = maxf(_clunk - delta * VENDING_CLUNK_DECAY, 0.0)
	if _recoil_lock > 0.0:
		_recoil_lock = maxf(_recoil_lock - delta, 0.0)
	if _recoil > 0.0:
		_recoil = maxf(_recoil - delta * RECOIL_RETURN, 0.0)
	if _dash_flick > 0.0:
		_dash_flick = maxf(_dash_flick - delta * CAT_FLICK_RETURN, 0.0)
	if form_id == FormCatalog.Id.SLIME:
		_record_trail(delta)
	elif form_id == FormCatalog.Id.CAT:
		_fade_blink_trail(delta)
	_clamp(bounds)
	if invulnerable:
		modulate.a = 0.35 if fmod(_wobble, 0.16) < 0.08 else 1.0
	else:
		modulate.a = 1.0
	if is_inside_tree():
		queue_redraw()
		if _aura_layer != null:
			_aura_layer.queue_redraw()

func _pursue(delta: float) -> void:
	if form_id == FormCatalog.Id.CAT:
		_try_blink(delta)
	var to_aim := aim - position
	var dist := to_aim.length()
	if dist <= 0.35:
		position = aim
		velocity = Vector2.ZERO
		return
	var gain := 1.0 - exp(-FormCatalog.arrive_rate(form_id) * delta)
	var step := to_aim * gain
	var cap := FormCatalog.SNAP_MAX_SPEED * delta
	if step.length() > cap:
		step = to_aim / dist * cap
	if step.length() >= dist - 0.35:
		position = aim
	else:
		position += step
	velocity = Vector2.ZERO

## One short dash toward a hard flick. Small aim corrections stay on the snap.
func _try_blink(delta: float) -> void:
	if _blink_cd > 0.0:
		_blink_cd = maxf(_blink_cd - delta, 0.0)
		return
	var to_aim := aim - position
	var dist := to_aim.length()
	if dist < FormCatalog.CAT_BLINK_MIN:
		return
	var hop := to_aim / dist * minf(dist, FormCatalog.cat_blink_dist(rank_index, power_level))
	var dash_dir := hop / hop.length()
	_dash_lean = clampf(dash_dir.y, -1.0, 1.0) * CAT_DASH_TILT
	_dash_offset = dash_dir * CAT_DASH_PX
	_dash_flick = 1.0
	_trail.push_front(position)
	_trim_trail()
	position += hop
	_blink_cd = FormCatalog.CAT_BLINK_CD
	blink_guard = FormCatalog.cat_blink_guard(rank_index, power_level)
	_trail_timer = 0.04

func _fade_blink_trail(delta: float) -> void:
	if _trail.is_empty():
		return
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail.pop_back()
	_trail_timer = 0.04

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

## Next run in the same visit. Does not add another evolve node.
func drawn_scale() -> float:
	return FormCatalog.play_scale(form_id) * fit_scale

func adopt_dragon(fit: float) -> void:
	form_id = FormCatalog.Id.DRAGON
	small = false
	fit_scale = fit
	rear = 0.0
	_apply_radius()

func respawn(id: int, start: Vector2) -> void:
	form_id = id
	fit_scale = 1.0
	rear = 0.0
	position = start
	aim = start
	velocity = Vector2.ZERO
	alive = true
	visible = true
	invulnerable = true
	small = false
	regrow_left = 0.0
	regrew = false
	rank_index = 0
	power_level = 0
	evolve_flash = 0.0
	evolve_t = -1.0
	evolve_final = false
	evolve_old = ""
	evolve_new = ""
	fx_mode = ""
	fx_sprite = ""
	fx_show_rim = false
	shield_hits = 0
	_cooldown = 0.12
	_blink_cd = 0.0
	blink_guard = 0.0
	_wobble = 0.0
	_pose = 0.0
	_recoil = 0.0
	_recoil_lock = 0.0
	_clunk = 0.0
	_was_stepping = false
	_dash_flick = 0.0
	_dash_lean = 0.0
	_dash_offset = Vector2.ZERO
	_trail.clear()
	_trail_timer = 0.0
	modulate = Color.WHITE
	_apply_radius()
	if _evolve_fx != null:
		_evolve_fx.play(99.0)
	queue_redraw()

func set_rank(index: int) -> void:
	rank_index = index
	evolve_flash = 0.4
	_apply_radius()

func begin_evolve(old_sprite: String, new_sprite: String, final: bool = false) -> void:
	evolve_old = old_sprite
	evolve_new = new_sprite
	evolve_final = final
	evolve_hold = Difficulty.FINAL_HOLD if final else (FxTimeline.EVOLVE_HOLD * 0.72 if rank_index == 3 else FxTimeline.EVOLVE_HOLD)
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
		_evolve_fx.pop_scale = 0.62 if rank_index == 3 and not evolve_final else 1.0
		_evolve_fx.play(99.0 if evolve_t < 0.0 else evolve_t, evolve_hold)

func _draw() -> void:
	var pose := cosmetic_pose()
	draw_set_transform(pose["offset"], float(pose["rotation"]), pose["scale"])
	if fx_mode == "flash":
		if ArtLibrary.has_file(fx_sprite):
			ArtLibrary.draw_anchored(self, fx_sprite)
		else:
			_draw_body(evolve_new if evolve_new != "" else sprite_name())
	elif fx_mode == "glow":
		_draw_body(fx_sprite)
		var rim := FxTimeline.rim_file(fx_sprite)
		if fx_show_rim and ArtLibrary.has_file(rim):
			ArtLibrary.draw_anchored(self, rim)
	else:
		var aura := FormCatalog.aura_file(form_id, rank_index)
		if aura != "" and not _aura_draws_behind():
			ArtLibrary.draw_loop(self, aura, 0.0)
		_draw_body(sprite_name())
	var hurt := hurt_draw_pose()
	draw_set_transform(hurt["offset"], float(hurt["rotation"]), hurt["scale"])
	if shield_hits > 0:
		var fitted := drawn_scale()
		draw_arc(Vector2.ZERO, radius / maxf(fitted, 0.01) + 5.0, 0.0, TAU, 22, Color("f2fbff"), 1.5, true)
	if HitLibrary.show:
		HitLibrary.draw(self, sprite_name(), "hurt", Color(0.35, 1.0, 0.55, 0.95), anim_frame())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Rank 5 jackpot rays are a separate canvas item so they render under
## enemies (z 3) and enemy shots (z 20). The body stays on the ship.
func _aura_draws_behind() -> bool:
	return form_id == FormCatalog.Id.VENDING and rank_index == 4

func _draw_back_aura() -> void:
	if _aura_layer == null or not _aura_draws_behind() or fx_mode != "":
		return
	var aura := FormCatalog.aura_file(form_id, rank_index)
	if aura == "":
		return
	var pose := cosmetic_pose()
	_aura_layer.draw_set_transform(pose["offset"], float(pose["rotation"]), pose["scale"])
	ArtLibrary.draw_loop(_aura_layer, aura, 0.0, Vector2.ZERO, Color(1, 1, 1, VENDING_RAY_ALPHA))
	_aura_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Cosmetic transform for the body only. Rank 4 and 5 have no idle sheet, so
## this bob is what keeps them from looking frozen.
func cosmetic_pose() -> Dictionary:
	var fitted := drawn_scale()
	var offset := Vector2.ZERO
	var rotation := 0.0
	var scale := Vector2(fitted, fitted)
	var moving := clampf(_pose, 0.0, 1.0)
	match form_id:
		FormCatalog.Id.SLIME:
			var breathe := sin(_wobble * SLIME_BREATHE_RATE) * SLIME_BREATHE * (1.0 - moving)
			var squash := SLIME_SQUASH * moving + breathe
			scale = Vector2(fitted * (1.0 + squash), fitted * (1.0 - squash * 0.75))
			offset.y = sin(_wobble * SLIME_IDLE_RATE) * SLIME_IDLE_BOB * (1.0 - moving)
		FormCatalog.Id.GOBLIN:
			var hop_px := GOBLIN_HOP_PX if sprinting else GOBLIN_PLANT_PX
			var hop := -absf(sin(_wobble * GOBLIN_HOP_RATE)) * hop_px
			var idle := sin(_wobble * GOBLIN_IDLE_RATE) * GOBLIN_IDLE_PX
			offset.y = lerpf(idle, hop, moving)
		FormCatalog.Id.VENDING:
			var rate := lerpf(VENDING_RATE_IDLE, VENDING_RATE_MOVE, moving)
			rotation = sin(_wobble * rate) * lerpf(VENDING_ROCK_IDLE, VENDING_ROCK_MOVE, moving)
			offset.x = sin(_wobble * rate * 0.8) * lerpf(VENDING_SWAY_IDLE, VENDING_SWAY_MOVE, moving)
			offset.y += _clunk * VENDING_CLUNK_PX
			rotation += _clunk * VENDING_CLUNK_TILT
		FormCatalog.Id.CAT:
			offset.y = sin(_wobble * CAT_IDLE_RATE) * CAT_IDLE_PX
			rotation = sin(_wobble * CAT_IDLE_TILT_RATE) * CAT_IDLE_TILT
			rotation += _dash_lean * _dash_flick
			offset += _dash_offset * _dash_flick
		FormCatalog.Id.DEMON:
			var amp := lerpf(DEMON_IDLE_PX, DEMON_MOVE_PX, moving)
			offset.y = sin(_wobble * DEMON_FLOAT_RATE) * amp
		FormCatalog.Id.DRAGON:
			offset.y = sin(_wobble * 1.8) * lerpf(1.0, 2.0, moving)
			offset.y -= rear * 6.0
			rotation = -rear * 0.35
	offset.x -= RECOIL_PX * _recoil
	return {"offset": offset, "rotation": rotation, "scale": scale}

## Shield ring and the hurt overlay. No bob, so the drawn circle matches collision.
func hurt_draw_pose() -> Dictionary:
	var fitted := drawn_scale()
	return {"offset": Vector2.ZERO, "rotation": 0.0, "scale": Vector2(fitted, fitted)}

func _draw_final_banner() -> void:
	if not evolve_final or evolve_t < 0.0:
		return
	if FxTimeline.evolve_stage(evolve_t, evolve_hold) != "pop":
		return
	var tex := _banner if _banner != null else PixelFont.outlined_texture("FINAL FORM!", Color("ffe56a"))
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
	if form_id == FormCatalog.Id.SLIME or (form_id == FormCatalog.Id.CAT and not _trail.is_empty()):
		_trim_trail()
		var i := _trail.size()
		for point in _trail:
			i -= 1
			var tint := Color(1, 1, 1, _trail_alpha(i))
			ArtLibrary.draw_loop(self, file, _wobble, point - position, tint)
	ArtLibrary.draw_loop(self, file, _wobble)

func anim_frame() -> int:
	return ArtLibrary.frame_index(sprite_name(), _wobble)

func sprite_name() -> String:
	var spec := FormCatalog.rank_spec(form_id, rank_index)
	if small and spec.has("sprite_small"):
		return str(spec["sprite_small"])
	return str(spec["sprite"])

func _apply_radius() -> void:
	radius = FormCatalog.hit_radius_for(form_id, rank_index, small) * fit_scale

