extends Node2D
class_name DragonShow

## Meteor Rain, timed at 15 fps on the 480x270 field.
## Charge-up is 1.0 s (15 frames). The rain itself is 3.0 s (45 frames).
## One meteor is scheduled every 2 frames, which is 23 meteors. They are the
## 26px cell drawn at 3x (78px) and step +9,+9 px each mock frame. Impacts are
## the 58px cell at 3x (174px). At most POOL meteors fly at once. FX on this
## node stay under the player and under enemy bullets.

const FRAME := 1.0 / 15.0
const CHARGE_FRAMES := 15
const RAIN_FRAMES := 45
const SPAWN_EVERY := 2
const METEOR_COUNT := 23
const WARN_LEAD := 10
const FALL_FRAMES := 16
const IMPACT_ART_FRAMES := 8
const IMPACT_HOLD := 2
const FLASH_FRAMES := 6
const AFTERMATH_FRAMES := 14
const DRAW_SCALE := 3.0
const METEOR_CELL := 26.0
const IMPACT_CELL := 58.0
const GIANT_METEOR := 168.0
const GIANT_IMPACT := 270.0
const STEP := 9.0
const SPAWN_LEAD_EXTRA := 60.0
const RETICLE := Vector2(300, 150)
const POOL := 16
const IMPACT_POOL := 8
const EMBER_CAP := 48
const DEBRIS_CAP := 64
const DECAL_CAP := 16
const SKY_ALPHA := 0.33
const BARRAGE_CHIP := 0.7
const FLY := "dragon_form/dragon_fly.png"
const METEOR := "dragon_form/dragon_meteor.png"
const IMPACT := "dragon_form/dragon_meteor_impact.png"
const EMBER := "dragon_form/dragon_ember.png"
const TARGET_YS: Array[int] = [150, 190, 226, 226]

const IDLE := 0
const CHARGE := 1
const RAIN := 2
const FALL := 3
const SLAM := 4
const AFTERMATH := 5

var host = null
var rng_seed := 0
var slain_left := 0.0
var slain_points := 0
var slain_at := Vector2.ZERO
var flash_frames := 0
var sky := 0.0
var shock := 0.0
var phase := IDLE
var _frame := 0
var _acc := 0.0
var _spawned := 0
var _spawn_wait := false
var _budget := 0
var _barrage_paid := 0
var _chip_f := 0.0
var _rng := RandomNumberGenerator.new()
var _meteors: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _decals: Array[Dictionary] = []
var _giant := {}
var _banner: Node2D

func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_pools()

func _ensure_pools() -> void:
	if not _meteors.is_empty():
		return
	for _i in POOL:
		_meteors.append({"on": false})
	for _i in EMBER_CAP:
		_embers.append({"on": false})
	for _i in DEBRIS_CAP:
		_debris.append({"on": false})
	_banner = Banner.new()
	_banner.rain = self
	_banner.z_as_relative = false
	_banner.z_index = 22
	add_child(_banner)

func meteor_px() -> int:
	return 78

func impact_px() -> int:
	return 174

func busy() -> bool:
	return phase != IDLE or slain_left > 0.0

func meter_fill(kills: int, need: int) -> float:
	if need <= 0:
		return 0.0
	return clampf(float(kills) / float(need), 0.0, 1.0)

func begin_slay(points: int, at: Vector2) -> void:
	slain_points = points
	slain_at = at
	slain_left = 1.15
	_boom(at, 1.4, 0.45)
	_boom(at + Vector2(-18, -8), 1.0, 0.55)
	_boom(at + Vector2(14, 6), 1.1, 0.62)
	_boom(at + Vector2(-6, 12), 0.9, 0.7)
	if host != null and host.has_method("_dragon_slow"):
		host._dragon_slow(0.7)
	if host != null and host.has_method("_dragon_clear_regulars"):
		host._dragon_clear_regulars()
	if host != null and host.has_method("_dragon_jingle"):
		host._dragon_jingle()
	queue_redraw()
	_banner.queue_redraw()

func start_rain() -> void:
	phase = CHARGE
	_frame = 0
	_acc = 0.0
	_spawned = 0
	_spawn_wait = false
	_impacts.clear()
	_barrage_paid = 0
	_chip_f = 0.0
	_budget = 0
	_giant = {}
	if host != null and host.has_method("_dragon_open_budget"):
		_budget = int(host._dragon_open_budget())
	_ensure_pools()
	_rng.seed = rng_seed
	sky = 0.0
	if host != null and host.has_method("_dragon_slow"):
		host._dragon_slow(1.0)
	if host != null and host.has_method("_dragon_shake"):
		host._dragon_shake(4.0, 1.0)
	if host != null and host.has_method("_dragon_clear_shots"):
		host._dragon_clear_shots()
	if host != null and host.has_method("_dragon_roar"):
		host._dragon_roar()
	queue_redraw()

func tick(delta: float) -> void:
	if slain_left > 0.0:
		var before := slain_left
		slain_left = maxf(slain_left - delta, 0.0)
		if before > 0.62 and slain_left <= 0.62 and host != null and host.has_method("_adopt_dragon_form"):
			host._adopt_dragon_form()
		_banner.queue_redraw()
	if phase == IDLE:
		_fade_bits(delta)
		queue_redraw()
		return
	_acc += delta
	var guard := 0
	while _acc >= FRAME and guard < 4:
		_acc -= FRAME
		_step_frame()
		guard += 1
	_fade_bits(delta)
	queue_redraw()
	if _banner != null:
		_banner.queue_redraw()

func _step_frame() -> void:
	_frame += 1
	match phase:
		CHARGE:
			sky = SKY_ALPHA * clampf(float(_frame) / float(CHARGE_FRAMES), 0.0, 1.0)
			_pose_rear(1.0)
			if _frame >= CHARGE_FRAMES:
				phase = RAIN
				_frame = 0
		RAIN:
			sky = SKY_ALPHA
			_pose_rear(0.0)
			if (_frame - 1) % SPAWN_EVERY == 0 and _spawned < METEOR_COUNT:
				_spawn_wait = true
			if _spawn_wait and _spawned < METEOR_COUNT and _spawn_barrage():
				_spawn_wait = false
			_move_meteors()
			_pay_barrage_chip()
			if host != null and host.has_method("_dragon_shake"):
				host._dragon_shake(4.0, FRAME * 2.0)
			if _frame >= RAIN_FRAMES:
				phase = FALL
				_frame = 0
				_launch_giant()
		FALL:
			_move_giant()
			if host != null and host.has_method("_dragon_shake"):
				host._dragon_shake(4.0, FRAME * 2.0)
			if _frame >= FALL_FRAMES:
				_slam_giant()
				phase = SLAM
				_frame = 0
		SLAM:
			if _frame <= FLASH_FRAMES:
				flash_frames = FLASH_FRAMES - _frame + 1
			shock = clampf(float(_frame) / float(IMPACT_ART_FRAMES * IMPACT_HOLD), 0.0, 1.0)
			if _frame >= IMPACT_ART_FRAMES * IMPACT_HOLD:
				phase = AFTERMATH
				_frame = 0
				flash_frames = 0
		AFTERMATH:
			var u := clampf(float(_frame) / float(AFTERMATH_FRAMES), 0.0, 1.0)
			sky = SKY_ALPHA * (1.0 - u)
			shock = maxf(shock - 0.08, 0.0)
			if _frame >= AFTERMATH_FRAMES:
				phase = IDLE
				_frame = 0
				sky = 0.0
				shock = 0.0
				_pose_rear(0.0)
	_age_particles()

func _spawn_barrage() -> bool:
	var slot := _free_meteor()
	if slot < 0:
		return false
	var tx := _rng.randi_range(150, 470)
	var ty := TARGET_YS[_rng.randi_range(0, TARGET_YS.size() - 1)]
	var lead := float(ty) + SPAWN_LEAD_EXTRA
	var target := Vector2(float(tx), float(ty))
	var at := target - Vector2(lead, lead)
	_meteors[slot] = {
		"on": true,
		"pos": at,
		"target": target,
		"vel": Vector2(STEP, STEP),
		"age": 0,
		"boom": -1,
		"giant": false,
		"scale": DRAW_SCALE,
	}
	_spawned += 1
	return true

func _launch_giant() -> void:
	var lead := RETICLE.y + SPAWN_LEAD_EXTRA
	var steps := float(FALL_FRAMES)
	_giant = {
		"on": true,
		"pos": RETICLE - Vector2(lead, lead),
		"target": RETICLE,
		"vel": Vector2(lead / steps, lead / steps),
		"age": 0,
		"boom": -1,
		"giant": true,
		"scale": GIANT_METEOR / METEOR_CELL,
	}

func _move_meteors() -> void:
	for i in _meteors.size():
		var item: Dictionary = _meteors[i]
		if not item.get("on", false):
			continue
		if int(item.get("boom", -1)) >= 0:
			continue
		item["pos"] = item["pos"] + item["vel"]
		item["age"] = int(item["age"]) + 1
		if int(item["age"]) % 2 == 0:
			_puff(item["pos"], 1.0)
		var target: Vector2 = item["target"]
		var pos: Vector2 = item["pos"]
		if pos.y >= target.y:
			_impact(item, false)

func _move_giant() -> void:
	if not _giant.get("on", false):
		return
	_giant["pos"] = _giant["pos"] + _giant["vel"]
	_giant["age"] = int(_giant.get("age", 0)) + 1
	if int(_giant["age"]) % 2 == 0:
		_puff(_giant["pos"], 1.8)
	var target: Vector2 = _giant["target"]
	var pos: Vector2 = _giant["pos"]
	if pos.y >= target.y or int(_giant["age"]) >= FALL_FRAMES:
		_giant["pos"] = target

func _slam_giant() -> void:
	var at: Vector2 = _giant.get("target", RETICLE)
	_giant["on"] = true
	_giant["boom"] = 0
	_giant["pos"] = at
	_throw_debris(at, 24, 2.2)
	if host != null and host.has_method("_dragon_clear_regulars"):
		host._dragon_clear_regulars()
	if host != null and host.has_method("_dragon_shake"):
		host._dragon_shake(5.0, 0.28)
	var rest := _budget - _barrage_paid
	if rest > 0 and host != null and host.has_method("_dragon_chip"):
		host._dragon_chip(rest)
		_barrage_paid = _budget
	flash_frames = FLASH_FRAMES
	shock = 0.15

func _impact(item: Dictionary, giant: bool) -> void:
	var at: Vector2 = item["target"]
	item["pos"] = at
	if not giant:
		# Free the flight slot immediately so the on-screen cap can refill.
		# The explosion itself is a separate capped list.
		item["on"] = false
		_add_impact(at, DRAW_SCALE, false)
	else:
		item["boom"] = 0
	var n := 24 if giant else 6
	_throw_debris(at, n, 1.6 if giant else 1.0)
	var ty := int(round(float(item["target"].y)))
	if ty == 226:
		_add_decal(at)
	if host != null and host.has_method("_dragon_splash"):
		host._dragon_splash(at, 42.0)

func _pay_barrage_chip() -> void:
	if _budget <= 0:
		return
	var share := int(floor(float(_budget) * BARRAGE_CHIP))
	_chip_f += float(share) / float(RAIN_FRAMES)
	var whole := int(floor(_chip_f))
	if whole <= 0:
		return
	_chip_f -= float(whole)
	var room := share - _barrage_paid
	var pay := mini(whole, room)
	if pay <= 0:
		return
	if host != null and host.has_method("_dragon_chip"):
		host._dragon_chip(pay)
	_barrage_paid += pay

func _free_meteor() -> int:
	for i in _meteors.size():
		if not _meteors[i].get("on", false):
			return i
	return -1

func _puff(at: Vector2, scale: float) -> void:
	for i in _embers.size():
		if _embers[i].get("on", false):
			continue
		_embers[i] = {
			"on": true,
			"pos": at,
			"vel": Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-10, 28)),
			"life": 8,
			"scale": scale,
		}
		return

func _throw_debris(at: Vector2, count: int, scale: float) -> void:
	var made := 0
	for i in _debris.size():
		if made >= count:
			return
		if _debris[i].get("on", false):
			continue
		var ang := _rng.randf() * TAU
		var spd := _rng.randf_range(40.0, 110.0)
		_debris[i] = {
			"on": true,
			"pos": at,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": 12,
			"scale": scale,
		}
		made += 1

func _add_impact(at: Vector2, scale: float, giant: bool) -> void:
	if _impacts.size() >= IMPACT_POOL:
		var oldest := 0
		for i in _impacts.size():
			if int(_impacts[i]["age"]) > int(_impacts[oldest]["age"]):
				oldest = i
		_impacts.remove_at(oldest)
	_impacts.append({"pos": at, "age": 0, "scale": scale, "giant": giant})

func _add_decal(at: Vector2) -> void:
	var live := 0
	for item in _decals:
		if item.get("life", 0) > 0:
			live += 1
	if live >= DECAL_CAP:
		return
	_decals.append({"pos": at, "life": RAIN_FRAMES})

func _boom(at: Vector2, scale: float, delay: float) -> void:
	_decals.append({"pos": at, "life": 10, "boom": delay, "scale": scale})

func _age_particles() -> void:
	var still: Array[Dictionary] = []
	for impact in _impacts:
		impact["age"] = int(impact["age"]) + 1
		var limit := IMPACT_ART_FRAMES
		if impact.get("giant", false):
			limit = IMPACT_ART_FRAMES * IMPACT_HOLD
		if int(impact["age"]) < limit:
			still.append(impact)
	_impacts = still
	for i in _meteors.size():
		var item: Dictionary = _meteors[i]
		if not item.get("on", false):
			continue
		if int(item.get("boom", -1)) < 0:
			continue
		item["boom"] = int(item["boom"]) + 1
		if int(item["boom"]) >= IMPACT_ART_FRAMES:
			item["on"] = false
	if _giant.get("on", false) and int(_giant.get("boom", -1)) >= 0:
		_giant["boom"] = int(_giant["boom"]) + 1
		if int(_giant["boom"]) >= IMPACT_ART_FRAMES * IMPACT_HOLD:
			_giant["on"] = false
	for i in _embers.size():
		if not _embers[i].get("on", false):
			continue
		_embers[i]["pos"] = _embers[i]["pos"] + _embers[i]["vel"] * FRAME
		_embers[i]["life"] = int(_embers[i]["life"]) - 1
		if int(_embers[i]["life"]) <= 0:
			_embers[i]["on"] = false
	for i in _debris.size():
		if not _debris[i].get("on", false):
			continue
		_debris[i]["pos"] = _debris[i]["pos"] + _debris[i]["vel"] * FRAME
		_debris[i]["vel"] = _debris[i]["vel"] * 0.92
		_debris[i]["life"] = int(_debris[i]["life"]) - 1
		if int(_debris[i]["life"]) <= 0:
			_debris[i]["on"] = false
	var keep: Array[Dictionary] = []
	for item in _decals:
		if item.has("boom"):
			item["boom"] = float(item["boom"]) - FRAME
			if float(item["boom"]) > 0.0:
				keep.append(item)
				continue
			item.erase("boom")
			item["life"] = 8
		item["life"] = int(item.get("life", 0)) - 1
		if int(item["life"]) > 0:
			keep.append(item)
	_decals = keep

func _fade_bits(_delta: float) -> void:
	pass

func _pose_rear(amount: float) -> void:
	if host == null or host._player == null:
		return
	host._player.rear = amount

func active_meteors() -> int:
	var n := 0
	for item in _meteors:
		if item.get("on", false) and int(item.get("boom", -1)) < 0:
			n += 1
	return n

func _draw() -> void:
	var field := Vector2(480, 270)
	if host != null and host.has_method("_viewport_size"):
		field = host._viewport_size()
	if sky > 0.01:
		draw_rect(Rect2(Vector2.ZERO, field), Color(0.18, 0.04, 0.02, sky))
	for item in _decals:
		if item.has("boom"):
			continue
		var at: Vector2 = item["pos"]
		var a := clampf(float(item["life"]) / 20.0, 0.15, 0.7)
		_paint_mark(at + Vector2(0, 4), Vector2(22, 7), Color(0.9, 0.28, 0.05, a))
	for i in _embers.size():
		if not _embers[i].get("on", false):
			continue
		var life := int(_embers[i]["life"])
		var tint := Color(1, 1, 1, clampf(float(life) / 8.0, 0.2, 1.0))
		ArtLibrary.draw_loop(self, EMBER, float(8 - life) / 15.0, _embers[i]["pos"], tint, float(_embers[i]["scale"]))
	for i in _debris.size():
		if not _debris[i].get("on", false):
			continue
		ArtLibrary.draw_loop(self, EMBER, float(12 - int(_debris[i]["life"])) / 15.0, _debris[i]["pos"], Color.WHITE, float(_debris[i]["scale"]))
	for item in _meteors:
		_draw_meteor(item)
	for impact in _impacts:
		var frame := int(impact["age"])
		if impact.get("giant", false):
			frame = int(impact["age"]) / IMPACT_HOLD
		ArtLibrary.draw_loop(self, IMPACT, float(frame) / 15.0, impact["pos"], Color.WHITE, float(impact["scale"]))
	_draw_meteor(_giant)
	if _show_reticle():
		_draw_reticle(RETICLE)
	if shock > 0.02:
		var rad := lerpf(20.0, 150.0, shock)
		draw_arc(RETICLE, rad, 0.0, TAU, 40, Color(1.0, 0.9, 0.55, (1.0 - shock) * 0.85), 3.0, true)
	if flash_frames > 0:
		var a := clampf(float(flash_frames) / float(FLASH_FRAMES), 0.0, 1.0) * 0.72
		draw_rect(Rect2(Vector2.ZERO, field), Color(1.0, 0.96, 0.75, a))

func _show_reticle() -> bool:
	if phase == FALL:
		return true
	return phase == RAIN and _frame >= RAIN_FRAMES - WARN_LEAD

func _draw_reticle(at: Vector2) -> void:
	var pulse := 0.55 + 0.45 * absf(sin(float(_frame) * 0.7))
	var ink := Color(1.0, 0.35, 0.15, pulse)
	draw_arc(at, 18.0, 0.0, TAU, 24, ink, 2.0, true)
	draw_line(at + Vector2(-26, 0), at + Vector2(-8, 0), ink, 2.0)
	draw_line(at + Vector2(8, 0), at + Vector2(26, 0), ink, 2.0)
	draw_line(at + Vector2(0, -26), at + Vector2(0, -8), ink, 2.0)
	draw_line(at + Vector2(0, 8), at + Vector2(0, 26), ink, 2.0)

func _draw_meteor(item: Dictionary) -> void:
	if not item.get("on", false):
		return
	var pos: Vector2 = item["pos"]
	var scale := float(item.get("scale", DRAW_SCALE))
	var boom := int(item.get("boom", -1))
	if boom >= 0:
		var art_scale := DRAW_SCALE
		var frame := boom
		if item.get("giant", false):
			art_scale = GIANT_IMPACT / IMPACT_CELL
			frame = int(boom / IMPACT_HOLD)
		else:
			art_scale = DRAW_SCALE
		var t := float(frame) / 15.0
		ArtLibrary.draw_loop(self, IMPACT, t, pos, Color.WHITE, art_scale)
		return
	var t := float(int(item.get("age", 0))) / 15.0
	ArtLibrary.draw_loop(self, METEOR, t, pos, Color.WHITE, scale)

func paint_banner(canvas: CanvasItem) -> void:
	if slain_left <= 0.0:
		return
	var field := Vector2(480, 270)
	if host != null and host.has_method("_viewport_size"):
		field = host._viewport_size()
	var title := PixelFont.outlined_texture("DRAGON SLAIN!", Color("ffe56a"))
	var points := PixelFont.outlined_texture("+%s" % ScoreRules.format_score(slain_points), Color("fff6d2"))
	var title_size := title.get_size() * 3.0
	var point_size := points.get_size() * 2.0
	var y := field.y * 0.28
	canvas.draw_texture_rect(title, Rect2(Vector2((field.x - title_size.x) * 0.5, y), title_size), false)
	canvas.draw_texture_rect(points, Rect2(Vector2((field.x - point_size.x) * 0.5, y + title_size.y + 4.0), point_size), false)

class Banner extends Node2D:
	var rain

	func _draw() -> void:
		if rain != null:
			rain.paint_banner(self)

func _paint_mark(at: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(at, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
