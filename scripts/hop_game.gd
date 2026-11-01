extends Node2D
class_name HopGame

## Experimental Crossy-style hop. Enter from the main scene only when HopMode
## was requested (?mode=hop or --mode=hop). This scene does not boot the
## side-scroller and does not write its best-score file.

const REVEAL := 0
const PLAY := 1
const DYING := 2
const TEASE := 3

var world: HopWorld
var phase := REVEAL

var _base_seed := 0
var _run_index := 0
var _rng := RandomNumberGenerator.new()
var _reveal_t := 0.0
var _reveal_limit := HopBalance.TITLE_SECONDS
var _death_t := 0.0
var _tease_t := 0.0
var _first_run := true
var _closing := false
var _queued := Vector2i.ZERO
var _pressing := false
var _press_at := Vector2.ZERO
var _evolve_left := 0.0
var _hint_left := 3.8
var death_score := 0
var best_form := 0
var best_overall := 0

var _sound: SoundRig
var _death: DeathFx
var _combat: CombatText
var _effects: Array[PixelEffect] = []
var _hud: Node2D
var _reveal: Control
var _title: TextureRect
var _tease: Control

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_seed = HopMode.seed_value() if HopMode.has_seed() else DailyRun.date_seed()
	_rng.seed = _base_seed
	_sound = SoundRig.new()
	_sound.name = "SoundRig"
	_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sound)
	_sound.start_gameplay_music()
	_combat = CombatText.new()
	_combat.z_index = 8
	add_child(_combat)
	_death = DeathFx.new()
	_death.z_index = 9
	_death.visible = false
	add_child(_death)
	_build_overlay()
	var form := HopMode.forced_form()
	if form < 0:
		form = HopWorld.roll_form(_rng)
	_start_world(form)

func _start_world(form: int) -> void:
	var run_seed := _base_seed + _run_index * 101
	world = HopWorld.new()
	world.setup(run_seed, form)
	phase = REVEAL
	_reveal_t = 0.0
	_reveal_limit = HopBalance.TITLE_SECONDS if _first_run else HopBalance.CARD_SECONDS
	_first_run = false
	_closing = false
	_queued = Vector2i.ZERO
	_evolve_left = 0.0
	_hint_left = 3.8
	_death.visible = false
	_show_title(FormCatalog.title_card(form))
	_tease.visible = false
	if _sound != null:
		_sound.play_title_card(FormCatalog.title_card(form))
	print("HOP TEST as %s (seed %d, run %d)" % [FormCatalog.display_name(form), run_seed, _run_index])

func _process(delta: float) -> void:
	if _evolve_left > 0.0:
		_evolve_left = maxf(_evolve_left - delta, 0.0)
	_tick_fx(delta)
	match phase:
		REVEAL:
			_reveal_t += delta
			_pulse_title(_reveal_t)
			if _reveal_t >= _reveal_limit:
				_begin_play()
		PLAY:
			_play(delta)
		DYING:
			_death_t += delta
			if _death != null:
				_death.elapsed = _death_t
				_death.queue_redraw()
			if _death_t >= HopBalance.DEATH_SECONDS:
				_begin_tease()
		TEASE:
			_tease_t += delta
			if _tease_t >= HopBalance.TEASE_SECONDS:
				_advance_after_death()
	if _hud != null:
		_hud.queue_redraw()
	queue_redraw()
	_maybe_capture()

var _shot_title := false
var _shot_index := 0
var _shot_next := 0.2

func _maybe_capture() -> void:
	if OS.get_environment("HOP_SHOT") != "1":
		return
	var dir := OS.get_environment("HOP_SHOT_DIR")
	if dir == "":
		dir = "/tmp/hopframes"
	if phase == REVEAL and not _shot_title and _reveal_t >= 0.2:
		_save_shot(dir, "title")
		_shot_title = true
		_begin_play()
		return
	if phase != PLAY or world == null:
		return
	if world.elapsed + 0.001 < _shot_next:
		return
	_save_shot(dir, "play_%02d" % _shot_index)
	_shot_index += 1
	_shot_next += 0.12
	if world.elapsed >= 4.0:
		get_tree().call_deferred("quit")

func _save_shot(dir: String, name: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var texture := get_viewport().get_texture()
	if texture == null:
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		return
	image.save_png("%s/%s.png" % [dir, name])

func _play(delta: float) -> void:
	if _hint_left > 0.0:
		_hint_left = maxf(_hint_left - delta, 0.0)
	if _queued != Vector2i.ZERO and world != null and not world.hopping():
		var move := _queued
		_queued = Vector2i.ZERO
		world.try_hop(move.x, move.y)
	if HopMode.drive_bot():
		HopBot.steer(world)
	var was_alive := world.alive
	world.tick(delta)
	_drain_events()
	if was_alive and not world.alive:
		_begin_death()

func _begin_play() -> void:
	phase = PLAY
	_reveal.visible = false
	_tease.visible = false
	if _sound != null:
		_sound.stop_event("reborn_tease")

func _begin_death() -> void:
	if _closing or world == null:
		return
	_closing = true
	phase = DYING
	_death_t = 0.0
	death_score = world.score
	var form_name := FormCatalog.display_name(world.form_id)
	var saved := HopMode.record(form_name, world.score)
	best_form = int(saved["form"])
	best_overall = int(saved["overall"])
	_reveal.visible = false
	_tease.visible = false
	if _death != null:
		_death.start(_screen(world.visual_pos()), world.player_sprite())
	if _sound != null:
		_sound.play_event("player_death")

func _begin_tease() -> void:
	if phase != DYING:
		return
	phase = TEASE
	_tease_t = 0.0
	_tease.visible = true
	_reveal.visible = false
	if _death != null:
		_death.visible = false
	if _sound != null:
		_sound.play_event("reborn_tease")

func _advance_after_death() -> void:
	if phase == PLAY:
		return
	_run_index += 1
	var form := HopMode.forced_form()
	if form < 0:
		form = HopWorld.roll_form(_rng)
	_start_world(form)

func _skip_overlay() -> void:
	if phase == REVEAL:
		_begin_play()
	elif phase == DYING or phase == TEASE:
		if _sound != null:
			_sound.stop_event("reborn_tease")
		_advance_after_death()
		_begin_play()

func _unhandled_input(event: InputEvent) -> void:
	var tapped := false
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		tapped = true
	elif event is InputEventKey and event.pressed:
		tapped = true
	if tapped and _sound != null:
		_sound.unlock_from_gesture()
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		var key := key_event.keycode
		if phase != PLAY:
			if not event.echo:
				_skip_overlay()
			return
		if key == KEY_H and not event.echo:
			HitLibrary.show = not HitLibrary.show
			return
		var move := Vector2i.ZERO
		match key:
			KEY_RIGHT, KEY_D:
				move = Vector2i(1, 0)
			KEY_LEFT, KEY_A:
				move = Vector2i(-1, 0)
			KEY_UP, KEY_W:
				move = Vector2i(0, -1)
			KEY_DOWN, KEY_S:
				move = Vector2i(0, 1)
		if move != Vector2i.ZERO:
			_request_hop(move)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_at = event.position
		elif _pressing:
			_pressing = false
			_release(event.position)

func _request_hop(move: Vector2i) -> void:
	if phase != PLAY or world == null or not world.alive:
		return
	if world.hopping():
		_queued = move
		return
	world.try_hop(move.x, move.y)

func _release(at: Vector2) -> void:
	if phase != PLAY:
		_skip_overlay()
		return
	var delta := at - _press_at
	if delta.length() < 14.0:
		_request_hop(Vector2i(1, 0))
		return
	if absf(delta.x) > absf(delta.y):
		_request_hop(Vector2i(1 if delta.x > 0.0 else -1, 0))
	else:
		_request_hop(Vector2i(0, 1 if delta.y > 0.0 else -1))

func _drain_events() -> void:
	if world == null:
		return
	for ev in world.take_events():
		var name := str(ev.get("name", ""))
		var at := _screen(ev.get("at", world.visual_pos()))
		match name:
			"shot":
				if world.form_id == FormCatalog.Id.SLIME and _sound != null:
					_sound.play_event("slime_shot")
			"kill":
				if _sound != null:
					_sound.play_event("enemy_killed")
				_combat.push("+%s" % ScoreRules.format_score(int(ev.get("points", 0))), at + Vector2(-8, -16), Color("241428"))
				_spawn_fx("death_puff.png", at, 0.36, 0.5, 1.4)
			"ping":
				_spawn_fx("hit_flash.png", at, 0.14, 0.7, 1.25)
			"loot":
				_combat.push("+%d" % int(ev.get("points", 0)), at + Vector2(-8, -12), Color("8a4b12"))
			"split":
				_combat.push("SPLIT!", at + Vector2(-22, -20), Color("1a4f9c"))
				_spawn_fx("hit_flash.png", at, 0.2, 0.6, 1.35)
			"regrow":
				_spawn_fx("fx/fx_evolve_glow.png", at, 0.28, 0.7, 1.2)
			"evolve":
				_evolve_left = 0.75
				_combat.push("EVOLVED!", at + Vector2(-28, -24), Color("fff3c4"))
				_spawn_fx("fx/fx_evolved_pop.png", at, 0.55, 0.6, 1.35)
				if _sound != null:
					var final := int(ev.get("rank", 0)) >= 2
					_sound.play_event("evolve", Difficulty.FINAL_STING_DB if final else 0.0)
			"dead":
				pass

func _draw() -> void:
	if world == null:
		return
	_paint_field()
	_paint_actors()

func _paint_field() -> void:
	var cam := world.cam_x
	_blit("bg_sky.png", cam * 0.05)
	var first := int(floor(cam / HopBalance.TILE)) - 1
	var last := first + HopBalance.COLS + 3
	var kill := world.kill_x_at(world.elapsed)
	for col in range(maxi(first, 0), last):
		var kind := world.lane_kind(col)
		for row in HopBalance.ROWS:
			var dest := Rect2(float(col) * HopBalance.TILE - cam, float(row) * HopBalance.TILE, HopBalance.TILE, HopBalance.TILE)
			var crop := _lane_crop(kind, col, row)
			var tint: Color = crop["tint"]
			if dest.position.x + dest.size.x <= kill - cam + 1.0:
				tint = Color(tint.r * 0.42, tint.g * 0.36, tint.b * 0.52, tint.a)
			var tex := ArtLibrary.texture(str(crop["file"]))
			if tex == null:
				continue
			draw_texture_rect_region(tex, dest, crop["region"], tint)
	_blit("bg_clouds.png", cam * 0.18)
	_blit_slice("bg_far.png", cam * 0.28, 132.0)

func _paint_actors() -> void:
	var cam := world.cam_x
	for hazard in world.draw_hazards:
		if bool(hazard.get("warn", false)):
			var target: Vector2 = hazard["target"]
			var mark := target - Vector2(cam, 0.0)
			var pulse := 0.55 + 0.45 * absf(sin(world.elapsed * 9.0))
			draw_set_transform(mark, 0.0, Vector2.ONE)
			ArtLibrary.draw_anchored(self, "graze_sparkle.png", Color(1, 1, 1, pulse))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var phase := str(hazard.get("phase", ""))
		if phase == "warn":
			continue
		var pos: Vector2 = hazard["pos"] - Vector2(cam, 0.0)
		draw_set_transform(pos, 0.0, Vector2.ONE)
		ArtLibrary.draw_loop(self, str(hazard["sprite"]), world.elapsed)
		if HitLibrary.show:
			HitLibrary.draw(self, str(hazard["sprite"]), "threat", Color(1, 0.35, 0.3, 0.8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for gem in world.loot:
		var gpos: Vector2 = gem["pos"]
		gpos.y += sin(world.elapsed * 5.0 + gpos.x) * 1.0
		draw_set_transform(_screen(gpos), 0.0, Vector2.ONE)
		ArtLibrary.draw_anchored(self, str(gem["sprite"]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for shot in world.draw_shots:
		var spos: Vector2 = shot["pos"]
		draw_set_transform(_screen(spos), 0.0, Vector2.ONE)
		ArtLibrary.draw_anchored(self, str(shot["sprite"]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if world.alive and phase != DYING:
		var player := _screen(world.visual_pos() + Vector2(0.0, world.hop_arc()))
		var tint := Color.WHITE
		if world.invuln > 0.0 and int(world.elapsed * 16.0) % 2 == 0:
			tint = Color(1, 1, 1, 0.4)
		draw_set_transform(player, 0.0, Vector2.ONE)
		var sprite := world.player_sprite()
		if _evolve_left > 0.0:
			ArtLibrary.draw_anchored(self, FxTimeline.rim_file(sprite), Color(1, 1, 1, clampf(_evolve_left / 0.75, 0.0, 1.0)))
		ArtLibrary.draw_loop(self, sprite, world.elapsed, Vector2.ZERO, tint)
		if HitLibrary.show:
			HitLibrary.draw(self, sprite, "hurt", Color(0.4, 1.0, 0.5, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var chaser := Vector2(world.kill_x_at(world.elapsed) - cam, clampf(world.visual_pos().y, 36.0, 234.0))
	draw_set_transform(chaser, 0.0, Vector2.ONE)
	ArtLibrary.draw_loop(self, "wyvern.png", world.elapsed)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func paint_hud(canvas: CanvasItem) -> void:
	var tag := PixelFont.outlined_texture("HOP TEST", Color("ffe56a"))
	var tag_at := Vector2(4.0, HopBalance.FIELD_H - tag.get_height() - 3.0)
	if phase == PLAY or phase == DYING:
		tag_at = Vector2(HopBalance.FIELD_W - tag.get_width() - 4.0, 4.0)
	canvas.draw_texture(tag, tag_at)
	if world == null:
		return
	if phase == PLAY or phase == DYING:
		_paint_run_hud(canvas)
	if phase == PLAY and _hint_left > 0.0:
		PixelFont.draw_outlined(canvas, "TAP HOP  SWIPE UP/DOWN", Vector2(132, 248), Color("f2fbff"))
	if phase == TEASE or phase == DYING:
		var score_line := "SCORE %s" % ScoreRules.format_score(death_score)
		PixelFont.draw_outlined(canvas, score_line, Vector2(168, 150), Color("ffe56a"))
		var form_line := "BEST %s" % ScoreRules.format_score(best_form)
		var all_line := "OVERALL %s" % ScoreRules.format_score(best_overall)
		PixelFont.draw_outlined(canvas, form_line, Vector2(168, 166), Color("f2fbff"))
		PixelFont.draw_outlined(canvas, all_line, Vector2(156, 180), Color("f2fbff"))
		if phase == TEASE:
			PixelFont.draw_outlined(canvas, "TAP RETRY", Vector2(198, 248), Color("ffe56a"))

func _paint_run_hud(canvas: CanvasItem) -> void:
	var score_tex := PixelFont.score_texture(ScoreRules.format_score(world.score))
	canvas.draw_texture(score_tex, HudLayout.SCORE_POS)
	canvas.draw_texture(ArtLibrary.texture("ui/hud_clock_icon.png"), HudLayout.CLOCK_POS)
	PixelFont.draw_outlined(canvas, ScoreRules.format_time(world.elapsed), HudLayout.TIME_PEN, HudLayout.TIME_COLOR)
	canvas.draw_texture(ArtLibrary.texture(HudLayout.meter_file(world.rank_index)), HudLayout.METER_POS)
	var fill_px := _fill_px()
	if fill_px > 0:
		var fill := ArtLibrary.texture("ui/hud_evo_meter_fill_64x6.png")
		var width := mini(fill_px, HudLayout.FILL_FULL)
		canvas.draw_texture_rect_region(fill, Rect2(HudLayout.FILL_POS, Vector2(width, 6)), Rect2(0, 0, width, 6))
	PixelFont.draw_outlined(canvas, FormCatalog.rank_name(world.form_id, world.rank_index), HudLayout.RANK_PEN, HudLayout.RANK_COLOR)
	if world.form_id == FormCatalog.Id.GOBLIN:
		canvas.draw_texture(ArtLibrary.texture("ui/hud_coin_icon.png"), Vector2(150, 50))
		PixelFont.draw_outlined(canvas, "x%d" % world.loot_count, Vector2(162, 51), HudLayout.COIN_COLOR)

func _fill_px() -> int:
	if world.rank_index >= 2:
		return HudLayout.FILL_FULL
	var gates := HopBalance.gates()
	var nxt := int(gates[world.rank_index])
	var prev := 0
	if world.rank_index > 0:
		prev = int(gates[world.rank_index - 1])
	var span := nxt - prev
	if span <= 0:
		return HudLayout.FILL_FULL
	var along := clampf(float(world.skill - prev) / float(span), 0.0, 1.0)
	return int(round(float(HudLayout.FILL_FULL) * along))

func _lane_crop(kind: int, col: int, row: int) -> Dictionary:
	var x := int(posmod(col * 53 + row * 29, 440))
	if kind == HopWorld.SHOT:
		var road_y := 214 + (row % 2) * 10
		if road_y > 240:
			road_y = 240
		return {
			"file": "bg_far.png",
			"region": Rect2(x, road_y, HopBalance.TILE, HopBalance.TILE),
			"tint": Color(0.9, 0.92, 1.05, 1),
		}
	var y := 208 + (row % 2) * 8
	var tint := Color(1, 1, 1, 1)
	if kind == HopWorld.WALK:
		y = 228
		tint = Color(0.8, 0.94, 0.74, 1)
	elif kind == HopWorld.PIANO:
		y = 214
		tint = Color(1.04, 0.9, 0.78, 1)
	if y > 240:
		y = 240
	return {
		"file": "bg_near.png",
		"region": Rect2(x, y, HopBalance.TILE, HopBalance.TILE),
		"tint": tint,
	}

func _blit(file_name: String, scroll: float) -> void:
	var tex := ArtLibrary.texture(file_name)
	if tex == null:
		return
	var offset := fposmod(scroll, HopBalance.FIELD_W)
	var x := -offset
	var guard := 0
	while x < HopBalance.FIELD_W and guard < 4:
		draw_texture(tex, Vector2(x, 0.0))
		x += HopBalance.FIELD_W
		guard += 1

func _blit_slice(file_name: String, scroll: float, height: float) -> void:
	var tex := ArtLibrary.texture(file_name)
	if tex == null:
		return
	var offset := fposmod(scroll, HopBalance.FIELD_W)
	var x := -offset
	var guard := 0
	var src := Rect2(0, 0, HopBalance.FIELD_W, height)
	while x < HopBalance.FIELD_W and guard < 4:
		draw_texture_rect_region(tex, Rect2(x, 0, HopBalance.FIELD_W, height), src)
		x += HopBalance.FIELD_W
		guard += 1

func _screen(world_pos: Vector2) -> Vector2:
	if world == null:
		return world_pos
	return world_pos - Vector2(world.cam_x, 0.0)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_reveal = Control.new()
	_reveal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_reveal)
	var dim := ColorRect.new()
	dim.color = Color("100c14")
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.add_child(dim)
	_title = TextureRect.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title.stretch_mode = TextureRect.STRETCH_SCALE
	_title.pivot_offset = Vector2(HopBalance.FIELD_W, HopBalance.FIELD_H) * 0.5
	_reveal.add_child(_title)
	_tease = Control.new()
	_tease.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tease.visible = false
	_tease.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_tease)
	var tease_dim := ColorRect.new()
	tease_dim.color = Color(0.078, 0.071, 0.122, 0.62)
	tease_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	tease_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tease.add_child(tease_dim)
	var tease_card := TextureRect.new()
	tease_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	tease_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tease_card.texture = ArtLibrary.texture("fx/fx_reborn_tease_card.png")
	tease_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tease_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tease_card.stretch_mode = TextureRect.STRETCH_SCALE
	_tease.add_child(tease_card)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 20
	add_child(hud_layer)
	var paint := HudPaint.new()
	paint.host = self
	paint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hud_layer.add_child(paint)
	_hud = paint

func _show_title(card: String) -> void:
	_title.texture = ArtLibrary.texture(card)
	_title.scale = Vector2(0.9, 0.9)
	_reveal.visible = true

func _pulse_title(t: float) -> void:
	if _title == null:
		return
	var u := clampf(t / 0.28, 0.0, 1.0)
	var scale := lerpf(0.9, 1.0, u)
	_title.scale = Vector2(scale, scale)

func _spawn_fx(file_name: String, at: Vector2, life: float, from_scale: float, to_scale: float) -> void:
	var fx := PixelEffect.new()
	fx.setup(file_name, at, life, from_scale, to_scale)
	fx.z_index = 8
	add_child(fx)
	_effects.append(fx)

func _tick_fx(delta: float) -> void:
	if _combat != null:
		_combat.tick(delta)
	var keep: Array[PixelEffect] = []
	for fx in _effects:
		if not is_instance_valid(fx):
			continue
		if fx.tick(delta):
			keep.append(fx)
		else:
			fx.queue_free()
	_effects = keep

class HudPaint extends Node2D:
	var host: Node2D

	func _draw() -> void:
		if host != null and host.has_method("paint_hud"):
			host.paint_hud(self)
