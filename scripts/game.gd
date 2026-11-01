extends Node2D

const REVEAL_SECONDS := 1.5
const INVULN_SECONDS := 1.5
const GRAZE_PAD := 22.0
const SPLIT_IFRAMES := 1.15
const REGROW_IFRAMES := 0.45
## The pause glyph stays 18 viewport pixels. The control around it is the touch target.
const PAUSE_ART_PX := 18.0
const PAUSE_MIN_PT := 44.0

const PHASE_REVEAL := 0
const PHASE_PLAY := 1
const PHASE_DEAD := 2

var day_seed := 0
var run_index := 0
var form_id := FormCatalog.Id.SLIME
var phase := PHASE_REVEAL
var elapsed := 0.0
var score := 0
var combo := 0
var combo_left := 0.0
var survival_bank := 0.0
var invuln := 0.0
var reveal_elapsed := 0.0
var death_elapsed := 0.0
var game_over_visible := false
var killer_name := "something"
var next_enemy_id := 1
var loot_count := 0
var evo_points := 0
var rank_index := 0

var _player: PlayerShip
var _background: FieldBackground
var _combat: CombatText
var _director: SpawnDirector
var _enemies: Array[EnemyActor] = []
var _shots: Array[Shot] = []
var _loot: Array[LootGem] = []
var _effects: Array[PixelEffect] = []
var _death_fx: DeathFx
var _tease: Control
var _loot_spawned := 0
var _drag_accum := Vector2.ZERO
var _primary_touch := -1
var _mouse_down := false

var _hud: Control
var _hud_view: HudView
var _font_outlined: Font
var _hint_label: Label
var _reveal: Control
var _title_card: TextureRect
var _skip_label: Label
var _game_over: Control
var _share_label: Label
var _best_label: Label
var _seed_label: Label
var _death_kicker: Label
var _restart_button: Button
var _rotate: Control
var _paused := false
var _pause_button: Button
var _pause_icon: TextureRect
var _pause_overlay: Control

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	day_seed = DailyRun.date_seed()
	run_index = DailyRun.consume_run_index()
	form_id = FormCatalog.id_for_run(day_seed, run_index)
	_director = SpawnDirector.new(day_seed)
	_build_world()
	_build_hud()
	print("Reincarnated as %s (seed %d, run %d)" % [FormCatalog.display_name(form_id), day_seed, run_index])

func _build_world() -> void:
	var size := _viewport_size()
	_background = FieldBackground.new()
	_background.setup(day_seed, size)
	add_child(_background)

	_player = PlayerShip.new()
	_player.z_index = 5
	_player.setup(form_id, Vector2(size.x * 0.28, size.y * 0.5))
	add_child(_player)

	_combat = CombatText.new()
	_combat.z_index = 8
	add_child(_combat)

	_death_fx = DeathFx.new()
	_death_fx.z_index = 9
	_death_fx.visible = false
	add_child(_death_fx)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_load_fonts()
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(_hud)

	_hud_view = HudView.new()
	_hud_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hud.add_child(_hud_view)

	_hint_label = _make_label(9, Color("f2fbff"))
	_hint_label.anchor_left = 0.5
	_hint_label.anchor_right = 0.5
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_left = -140.0
	_hint_label.offset_right = 140.0
	_hint_label.offset_top = -48.0
	_hint_label.offset_bottom = -26.0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.text = "Drag anywhere to move"
	_hint_label.visible = false
	_hud.add_child(_hint_label)

	_reveal = Control.new()
	_reveal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_reveal)
	var dim := ColorRect.new()
	dim.color = Color("100c14")
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.add_child(dim)
	_title_card = TextureRect.new()
	_title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.texture = ArtLibrary.texture(FormCatalog.title_card(form_id))
	_title_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_card.stretch_mode = TextureRect.STRETCH_SCALE
	_title_card.pivot_offset = _viewport_size() * 0.5
	_title_card.scale = Vector2(0.84, 0.84)
	_reveal.add_child(_title_card)
	_skip_label = _make_label(9, Color("f2fbff"))
	_skip_label.text = ""
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.anchor_left = 0.5
	_skip_label.anchor_right = 0.5
	_skip_label.anchor_top = 1.0
	_skip_label.anchor_bottom = 1.0
	_skip_label.offset_left = -90.0
	_skip_label.offset_right = 90.0
	_skip_label.offset_top = -22.0
	_skip_label.offset_bottom = -6.0
	_reveal.add_child(_skip_label)

	_tease = Control.new()
	_tease.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tease.visible = false
	_tease.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_tease)
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

	_game_over = Control.new()
	_game_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over.visible = false
	_game_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_game_over)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.07, 0.86)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_over.add_child(shade)
	_death_kicker = _make_label(9, Color("f2fbff"))
	_death_kicker.text = "RUN OVER"
	_death_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over.add_child(_death_kicker)
	_share_label = _make_label(18, Color("f2fbff"))
	_share_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_share_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over.add_child(_share_label)
	_best_label = _make_label(9, Color("ffd84a"))
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over.add_child(_best_label)
	_seed_label = _make_label(9, Color("a49fcf"))
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over.add_child(_seed_label)
	_restart_button = Button.new()
	_restart_button.text = "Reincarnate"
	_restart_button.focus_mode = Control.FOCUS_NONE
	_restart_button.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f0d78c")
	style.set_corner_radius_all(4)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_restart_button.add_theme_stylebox_override("normal", style)
	_restart_button.add_theme_stylebox_override("hover", style)
	_restart_button.add_theme_stylebox_override("pressed", style)
	_restart_button.add_theme_stylebox_override("focus", style)
	_restart_button.add_theme_font_override("font", _font_outlined)
	_restart_button.add_theme_color_override("font_color", Color("f2fbff"))
	_restart_button.add_theme_color_override("font_hover_color", Color("f2fbff"))
	_restart_button.add_theme_color_override("font_pressed_color", Color("f2fbff"))
	_restart_button.add_theme_font_size_override("font_size", 18)
	_restart_button.pressed.connect(_on_restart)
	_game_over.add_child(_restart_button)
	_layout_death_card()

	_rotate = Control.new()
	_rotate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate.visible = false
	_rotate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_rotate)
	var rotate_dim := ColorRect.new()
	rotate_dim.color = Color("100c14")
	rotate_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotate_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate.add_child(rotate_dim)
	var rotate_center := CenterContainer.new()
	rotate_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotate_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotate.add_child(rotate_center)
	var rotate_column := VBoxContainer.new()
	rotate_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotate_column.add_theme_constant_override("separation", 8)
	rotate_center.add_child(rotate_column)
	var rotate_title := _make_label(18, Color("f2fbff"))
	rotate_title.text = "Rotate your phone"
	rotate_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_column.add_child(rotate_title)
	var rotate_body := _make_label(9, Color("f2fbff"))
	rotate_body.text = "This run flies sideways."
	rotate_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_column.add_child(rotate_body)

	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_pause_overlay)
	var pause_dim := ColorRect.new()
	pause_dim.color = Color(0.04, 0.03, 0.07, 0.45)
	pause_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(pause_dim)
	var pause_label := _make_label(18, Color("f2fbff"))
	pause_label.text = "PAUSED"
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(pause_label)

	_pause_button = Button.new()
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.flat = true
	_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_button.z_index = 2
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_pause_button.add_theme_stylebox_override(state, empty)
	_pause_button.pressed.connect(_toggle_pause)
	_hud.add_child(_pause_button)
	_pause_icon = TextureRect.new()
	_pause_icon.texture = load("res://art/ui/hud_pause_button.png")
	_pause_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pause_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_icon.stretch_mode = TextureRect.STRETCH_KEEP
	_pause_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pause_icon.size = Vector2(PAUSE_ART_PX, PAUSE_ART_PX)
	_pause_icon.custom_minimum_size = Vector2(PAUSE_ART_PX, PAUSE_ART_PX)
	_pause_button.add_child(_pause_icon)
	_layout_pause(_viewport_size())
	_refresh_hud()

func _load_fonts() -> void:
	_font_outlined = load("res://ui/font_kaito5x7_outlined.fnt")
	var plain := load("res://ui/font_kaito5x7.fnt") as FontFile
	if _font_outlined is FontFile:
		var outlined := _font_outlined as FontFile
		outlined.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		outlined.hinting = TextServer.HINTING_NONE
	if plain != null:
		plain.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		plain.hinting = TextServer.HINTING_NONE

func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _font_outlined != null:
		label.add_theme_font_override("font", _font_outlined)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func wants_rotate(size: Vector2) -> bool:
	# The stretch mode can keep a landscape viewport inside a tall window.
	# A portrait phone should see the prompt, not a letterboxed strip.
	if size.y > size.x:
		return true
	var window_size := DisplayServer.window_get_size()
	return window_size.y > window_size.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			HitLibrary.show = not HitLibrary.show
			_redraw_hitboxes()
			return
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			_toggle_pause()
			return
	if _paused or wants_rotate(_viewport_size()):
		return
	if event is InputEventScreenTouch:
		_on_screen_touch(event)
	elif event is InputEventScreenDrag:
		_on_screen_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)

func _on_screen_touch(event: InputEventScreenTouch) -> void:
	if _hits_pause(event.position):
		if not event.pressed and event.index == _primary_touch:
			_primary_touch = -1
		return
	if event.pressed:
		if _try_skip_tease():
			return
		if _primary_touch == -1:
			_primary_touch = event.index
			_try_skip_reveal()
	elif event.index == _primary_touch:
		_primary_touch = -1

func _on_screen_drag(event: InputEventScreenDrag) -> void:
	if phase != PHASE_PLAY or event.index != _primary_touch:
		return
	_drag_accum += event.relative

func _on_mouse_button(event: InputEventMouseButton) -> void:
	if _hits_pause(event.position):
		if not event.pressed:
			_mouse_down = false
		return
	if _primary_touch != -1:
		return
	_mouse_down = event.pressed
	if event.pressed:
		if _try_skip_tease():
			_mouse_down = false
			return
		_try_skip_reveal()

func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if phase != PHASE_PLAY or _primary_touch != -1 or not _mouse_down:
		return
	_drag_accum += event.relative

func _try_skip_reveal() -> void:
	if phase == PHASE_REVEAL and reveal_elapsed > 0.35:
		_begin_play()

func _try_skip_tease() -> bool:
	if phase != PHASE_DEAD or game_over_visible:
		return false
	if FxTimeline.death_stage(death_elapsed) != "tease":
		return false
	_show_game_over()
	return true

func _process(delta: float) -> void:
	if _background == null or _player == null or _combat == null:
		return
	var size := _viewport_size()
	if _rotate != null and wants_rotate(size):
		_rotate.visible = true
		if _pause_button != null:
			_pause_button.visible = false
		return
	if _rotate != null:
		_rotate.visible = false
	_layout_pause(size)
	if _paused:
		return
	delta = clampf(delta, 0.0, 0.033)
	_background.tick(delta, size)
	_combat.tick(delta)
	_tick_effects(delta)
	if phase == PHASE_REVEAL:
		reveal_elapsed += delta
		_animate_title_card()
		_skip_label.text = "Tap to skip" if reveal_elapsed > 0.35 else ""
		if reveal_elapsed >= REVEAL_SECONDS:
			_begin_play()
		return
	if phase == PHASE_DEAD:
		death_elapsed += delta
		_present_death()
		return
	_play_frame(delta, size)

func _animate_title_card() -> void:
	if _title_card == null:
		return
	var size := _viewport_size()
	var t := clampf(reveal_elapsed / 0.26, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var pop := lerpf(0.84, 1.0, eased)
	_title_card.pivot_offset = size * 0.5
	_title_card.scale = Vector2(pop, pop)

func _begin_play() -> void:
	if phase != PHASE_REVEAL:
		return
	phase = PHASE_PLAY
	invuln = INVULN_SECONDS
	_player.invulnerable = true
	_reveal.visible = false
	_hint_label.visible = true

func _play_frame(delta: float, size: Vector2) -> void:
	var bounds := _play_bounds(size)
	var key := _key_vector()
	if key != Vector2.ZERO:
		_player.add_drag(key * FormCatalog.max_speed(form_id) * delta, bounds)
	if _drag_accum != Vector2.ZERO:
		_player.add_drag(_drag_accum, bounds)
		_drag_accum = Vector2.ZERO
	invuln = maxf(invuln - delta, 0.0)
	_player.invulnerable = invuln > 0.0
	_player.tick(delta, bounds)
	if _player.regrew:
		invuln = maxf(invuln, REGROW_IFRAMES)
		_player.invulnerable = true
	if _player.ready_to_fire():
		var interval := float(FormCatalog.rank_spec(form_id, rank_index)["fire_interval"])
		for spec in FormCatalog.player_shots(form_id, _player.position, rank_index):
			_spawn_shot(spec, true)
		_player.did_fire(interval)
	for event in _director.pop_due(elapsed):
		_spawn_enemy(event, size)
	var player_pos := _player.position
	for enemy in _enemies:
		if not enemy.alive:
			continue
		for spec in enemy.tick(delta, player_pos):
			_spawn_shot(spec, false)
	for shot in _shots:
		shot.tick(delta)
	_collide()
	_tick_loot(delta)
	_sweep(size)
	_bank_survival(delta)
	if combo_left > 0.0:
		combo_left = maxf(combo_left - delta, 0.0)
	elapsed += delta
	if elapsed > 3.2:
		_hint_label.visible = false
	_refresh_hud()

func _play_bounds(size: Vector2) -> Rect2:
	var floor_y := minf(FieldBackground.GROUND_FEET - 2.0, size.y - 8.0)
	return Rect2(14, 10, maxf(size.x - 28.0, 40.0), maxf(floor_y - 10.0, 40.0))

func _key_vector() -> Vector2:
	var vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		vector.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		vector.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		vector.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		vector.y += 1.0
	if vector.length() > 1.0:
		vector = vector.normalized()
	return vector

func _spawn_enemy(data: Dictionary, size: Vector2) -> void:
	var enemy := EnemyActor.new()
	enemy.z_index = 3
	enemy.setup(next_enemy_id, data, size, _background)
	next_enemy_id += 1
	add_child(enemy)
	_enemies.append(enemy)

func _spawn_shot(data: Dictionary, from_player: bool) -> Shot:
	var shot := Shot.new()
	shot.z_index = 4
	shot.setup(data, from_player)
	add_child(shot)
	_shots.append(shot)
	return shot

func _collide() -> void:
	var spent: Array[Shot] = []
	var splits: Array[Dictionary] = []
	for shot in _shots:
		if not shot.from_player or not is_instance_valid(shot):
			continue
		for enemy in _enemies:
			if not enemy.alive:
				continue
			if shot.ignore_id == enemy.id and shot.age < 0.1:
				continue
			var enemy_file := SpawnDirector.sprite_for(enemy.kind)
			if not HitLibrary.overlaps(shot.position, shot.sprite_name, "body", enemy.position, enemy_file, "body"):
				continue
			enemy.hurt(shot.damage)
			if shot.splits > 0:
				for spec in FormCatalog.split_shots(shot.velocity, shot.position):
					spec["ignore_id"] = enemy.id
					splits.append(spec)
			if not enemy.alive:
				_award_kill(enemy)
				_spawn_fx("death_puff.png", enemy.position, 0.42, 0.45, 1.55)
			else:
				_spawn_fx("hit_flash.png", shot.position, 0.16, 0.75, 1.35)
			spent.append(shot)
			break
	for shot in spent:
		_drop_shot(shot)
	for spec in splits:
		var child := _spawn_shot(spec, true)
		child.ignore_id = int(spec["ignore_id"])
	if not _player.alive or _player.invulnerable:
		return
	var player_file := _player.sprite_name()
	for enemy in _enemies:
		if not enemy.alive:
			continue
		var enemy_file := SpawnDirector.sprite_for(enemy.kind)
		var enemy_gap := HitLibrary.gap(_player.position, player_file, "hurt", enemy.position, enemy_file, "threat")
		if enemy_gap <= 0.0:
			_hurt_player(enemy.kind_name)
			return
		_graze_gap(enemy, enemy_gap)
	for shot in _shots:
		if shot.from_player or not is_instance_valid(shot):
			continue
		var shot_gap := HitLibrary.gap(_player.position, player_file, "hurt", shot.position, shot.sprite_name, "threat")
		if shot_gap <= 0.0:
			_hurt_player(shot.killer_name if shot.killer_name != "" else "shot")
			return
		_graze_gap(shot, shot_gap)

func _award_kill(enemy: EnemyActor) -> void:
	var result := ScoreRules.on_kill(enemy.score_value, combo, combo_left)
	combo = int(result["combo"])
	combo_left = float(result["combo_left"])
	var points := int(result["points"])
	_gain_skill(points)
	_combat.push("+%s" % ScoreRules.format_score(points), enemy.position + Vector2(-8, -18), Color("241428"))
	if form_id == FormCatalog.Id.GOBLIN:
		_spawn_loot(enemy.position)

func _graze_gap(hazard: Object, separation: float) -> void:
	if hazard.grazed:
		return
	if separation <= 0.0 or separation > GRAZE_PAD:
		return
	hazard.grazed = true
	_gain_skill(ScoreRules.GRAZE)
	var at: Vector2 = hazard.position
	_combat.push("+%d" % ScoreRules.GRAZE, at + Vector2(6, -8), Color("ffe08a"))
	_spawn_fx("graze_sparkle.png", at, 0.34, 0.45, 1.45)

func _hurt_player(killer: String) -> void:
	if phase != PHASE_PLAY or not _player.alive:
		return
	# Slime trait only. A small Slime falls through to the one death of the run.
	if _player.absorb_lethal_hit():
		invuln = maxf(invuln, SPLIT_IFRAMES)
		_player.invulnerable = true
		_combat.push("SPLIT!", _player.position + Vector2(-28, -24), Color("1a4f9c"))
		_spawn_fx("hit_flash.png", _player.position, 0.22, 0.6, 1.4)
		return
	_kill_player(killer)

func _spawn_loot(at: Vector2) -> void:
	var gem := LootGem.new()
	var file := "coin.png" if _loot_spawned % 2 == 0 else "gem.png"
	_loot_spawned += 1
	gem.setup(file)
	gem.position = at
	gem.z_index = 4
	add_child(gem)
	_loot.append(gem)

func _tick_loot(delta: float) -> void:
	var keep: Array[LootGem] = []
	for gem in _loot:
		if not is_instance_valid(gem):
			continue
		gem.tick(delta)
		if _player.alive and _overlaps(_player.position, _player.radius, gem.position, gem.radius):
			_collect_gem(gem)
			continue
		if gem.position.x < -40.0:
			gem.queue_free()
			continue
		keep.append(gem)
	_loot = keep

func _collect_gem(gem: LootGem) -> void:
	gem.queue_free()
	loot_count += 1
	_gain_skill(FormCatalog.LOOT_POINTS)
	_combat.push("+%d" % FormCatalog.LOOT_POINTS, gem.position + Vector2(-8, -14), Color("8a4b12"))

func _gain_skill(points: int) -> void:
	if points <= 0:
		return
	score += points
	evo_points += points
	var reached := FormCatalog.rank_for_points(evo_points)
	if reached > rank_index:
		var old_sprite := _player.sprite_name()
		rank_index = reached
		_player.set_rank(rank_index)
		_player.begin_evolve(old_sprite, _player.sprite_name())
	_refresh_hud()

func _kill_player(name: String) -> void:
	if phase != PHASE_PLAY:
		return
	killer_name = name
	phase = PHASE_DEAD
	_paused = false
	if _pause_overlay != null:
		_pause_overlay.visible = false
	if _pause_button != null:
		_pause_button.visible = false
	_player.alive = false
	_player.visible = false
	_hint_label.visible = false
	if _death_fx != null:
		_death_fx.start(_player.position, _player.sprite_name())
	_present_death()
	_refresh_hud()

func _present_death() -> void:
	var stage := FxTimeline.death_stage(death_elapsed)
	if _death_fx != null:
		_death_fx.elapsed = death_elapsed
		_death_fx.visible = stage == "hit" or stage == "pop" or stage == "puff" or stage == "hold"
		_death_fx.queue_redraw()
	if _tease != null:
		_tease.visible = stage == "tease" and not game_over_visible
	if stage == "card" and not game_over_visible:
		_show_game_over()

func _show_game_over() -> void:
	game_over_visible = true
	if _tease != null:
		_tease.visible = false
	if _death_fx != null:
		_death_fx.visible = false
	var form_name := FormCatalog.display_name(form_id)
	var reached_rank := FormCatalog.rank_name(form_id, rank_index)
	_share_label.text = ScoreRules.share_line(form_name, reached_rank, elapsed, killer_name, score)
	var saved := BestScores.record(form_name, score)
	_best_label.text = "Best as %s: %s / Best overall: %s" % [
		form_name,
		ScoreRules.format_score(int(saved["form"])),
		ScoreRules.format_score(int(saved["overall"])),
	]
	_seed_label.text = "UTC seed %d · run %d" % [day_seed, run_index + 1]
	_layout_death_card()
	_game_over.visible = true

## Pin Reincarnate inside the field. Long rank names wrap, then shrink, so the
## button is never pushed past the bottom of the 480x270 viewport.
func _layout_death_card() -> void:
	if _restart_button == null or _share_label == null:
		return
	var field := _viewport_size()
	var button_size := Vector2(minf(280.0, field.x - 24.0), 56.0)
	var margin := 10.0
	var button_pos := Vector2((field.x - button_size.x) * 0.5, field.y - margin - button_size.y)
	_place_death_control(_restart_button, button_pos, button_size)
	var text_width := minf(448.0, field.x - 16.0)
	var text_left := (field.x - text_width) * 0.5
	var text_top := 8.0
	var text_bottom := button_pos.y - 8.0
	var text_height := maxf(text_bottom - text_top, 48.0)
	var kicker_h := 18.0
	var seed_h := 16.0
	var gap := 4.0
	var flexible := maxf(text_height - kicker_h - seed_h - gap * 3.0, 36.0)
	_fit_wrapped_label(_share_label, text_width, flexible * 0.68, 18, 9)
	_fit_wrapped_label(_best_label, text_width, flexible * 0.32, 9, 9)
	var share_h := _wrapped_height(_share_label.text, text_width, _death_font_size(_share_label))
	var best_h := _wrapped_height(_best_label.text, text_width, _death_font_size(_best_label))
	var used := kicker_h + share_h + best_h + seed_h + gap * 3.0
	var y := text_top + maxf(text_height - used, 0.0) * 0.5
	_place_death_control(_death_kicker, Vector2(text_left, y), Vector2(text_width, kicker_h))
	y += kicker_h + gap
	_place_death_control(_share_label, Vector2(text_left, y), Vector2(text_width, share_h))
	y += share_h + gap
	_place_death_control(_best_label, Vector2(text_left, y), Vector2(text_width, best_h))
	y += best_h + gap
	_place_death_control(_seed_label, Vector2(text_left, y), Vector2(text_width, seed_h))

func _place_death_control(control: Control, pos: Vector2, control_size: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = pos
	control.size = control_size
	control.custom_minimum_size = control_size

func _death_font_size(label: Label) -> int:
	return int(label.get_theme_font_size("font_size"))

func _fit_wrapped_label(label: Label, width: float, max_height: float, start_size: int, min_size: int) -> void:
	var size := start_size
	while size > min_size and _wrapped_height(label.text, width, size) > max_height:
		size = maxi(size - 9, min_size)
	label.add_theme_font_size_override("font_size", size)

func _wrapped_height(text: String, width: float, font_size: int) -> float:
	if text.is_empty():
		return 0.0
	var font := _font_outlined if _font_outlined != null else ThemeDB.fallback_font
	var box := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size)
	return box.y + 2.0

func _sweep(size: Vector2) -> void:
	var field := Rect2(-80, -80, size.x + 160, size.y + 160)
	var enemies_left: Array[EnemyActor] = []
	for enemy in _enemies:
		var gone := not enemy.alive or not field.has_point(enemy.position)
		if gone:
			if is_instance_valid(enemy):
				enemy.queue_free()
		else:
			enemies_left.append(enemy)
	_enemies = enemies_left
	var shots_left: Array[Shot] = []
	for shot in _shots:
		if not is_instance_valid(shot) or not field.grow(20).has_point(shot.position):
			if is_instance_valid(shot):
				shot.queue_free()
		else:
			shots_left.append(shot)
	_shots = shots_left

func _drop_shot(shot: Shot) -> void:
	_shots.erase(shot)
	if is_instance_valid(shot):
		shot.queue_free()

func _bank_survival(delta: float) -> void:
	survival_bank += delta
	while survival_bank >= 1.0:
		survival_bank -= 1.0
		score += ScoreRules.SURVIVAL_PER_SECOND

func _refresh_hud() -> void:
	if _hud_view == null:
		return
	_hud_view.set_run(
		ScoreRules.format_score(score),
		ScoreRules.format_time(elapsed),
		loot_count,
		FormCatalog.rank_name(form_id, rank_index).to_upper(),
		rank_index,
		HudLayout.fill_px(evo_points, rank_index)
	)

func _on_restart() -> void:
	get_tree().reload_current_scene()

func _redraw_hitboxes() -> void:
	if _player != null:
		_player.queue_redraw()
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_redraw()
	for shot in _shots:
		if is_instance_valid(shot):
			shot.queue_redraw()

## Integer viewport scale for stretch mode "viewport", aspect "keep".
## One returned unit is one window pixel per viewport pixel. Godot never goes below 1.
func visible_pixel_scale(viewport: Vector2, window: Vector2) -> float:
	if window.x < 1.0 or window.y < 1.0 or viewport.x < 1.0 or viewport.y < 1.0:
		return 1.0
	var viewport_aspect := viewport.x / viewport.y
	var window_aspect := window.x / window.y
	var screen := window
	if not is_equal_approx(viewport_aspect, window_aspect):
		if viewport_aspect < window_aspect:
			screen = Vector2(floorf(window.y * viewport_aspect), window.y)
		else:
			screen = Vector2(window.x, floorf(window.x / viewport_aspect))
	var scale := minf(floorf(screen.x / viewport.x), floorf(screen.y / viewport.y))
	return maxf(scale, 1.0)

## Viewport pixels that cover at least 44 points on this window.
## The floor is 44 viewport pixels: on a phone, one game pixel is at most one point,
## and an 18px glyph would otherwise be an 18pt target.
func pause_hit_px(viewport: Vector2, window: Vector2, screen_scale: float) -> float:
	var pixel_scale := visible_pixel_scale(viewport, window)
	var safe_screen := screen_scale if screen_scale >= 1.0 else 1.0
	var points_per_px := pixel_scale / safe_screen
	var from_points := PAUSE_MIN_PT / points_per_px
	return maxf(ceilf(from_points), PAUSE_MIN_PT)

func apply_pause_layout(viewport: Vector2, window: Vector2, screen_scale: float) -> void:
	if _pause_button == null or _pause_icon == null:
		return
	var hit := pause_hit_px(viewport, window, screen_scale)
	var control_size := Vector2(hit, hit)
	var art := Vector2(PAUSE_ART_PX, PAUSE_ART_PX)
	# The 18px mark stays where the HUD mock puts it. The hit target grows left and down.
	var art_pos := Vector2(viewport.x - 4.0 - PAUSE_ART_PX, 4.0)
	var button_pos := art_pos - Vector2(hit - PAUSE_ART_PX, 0.0)
	button_pos.x = clampf(button_pos.x, 0.0, maxf(viewport.x - hit, 0.0))
	button_pos.y = clampf(button_pos.y, 0.0, maxf(viewport.y - hit, 0.0))
	_pause_button.position = button_pos
	_pause_button.size = control_size
	_pause_button.custom_minimum_size = control_size
	_pause_icon.scale = Vector2.ONE
	_pause_icon.size = art
	_pause_icon.custom_minimum_size = art
	var icon_pos := art_pos - button_pos
	icon_pos.x = clampf(icon_pos.x, 0.0, maxf(hit - PAUSE_ART_PX, 0.0))
	icon_pos.y = clampf(icon_pos.y, 0.0, maxf(hit - PAUSE_ART_PX, 0.0))
	_pause_icon.position = icon_pos
	var show := phase == PHASE_PLAY or _paused
	_pause_button.visible = show
	if _pause_overlay != null:
		_pause_overlay.visible = _paused

func _layout_pause(viewport: Vector2) -> void:
	var window := DisplayServer.window_get_size()
	apply_pause_layout(viewport, Vector2(window), DisplayServer.screen_get_scale())

func _hits_pause(point: Vector2) -> bool:
	if _pause_button == null or not _pause_button.visible:
		return false
	return Rect2(_pause_button.position, _pause_button.size).has_point(point)

func _toggle_pause() -> void:
	if phase != PHASE_PLAY and not _paused:
		return
	_paused = not _paused
	_drag_accum = Vector2.ZERO
	_mouse_down = false
	_primary_touch = -1
	_layout_pause(_viewport_size())

func _overlaps(a: Vector2, a_radius: float, b: Vector2, b_radius: float) -> bool:
	var reach := a_radius + b_radius
	return a.distance_squared_to(b) <= reach * reach

func _spawn_fx(file_name: String, at: Vector2, duration: float, from_scale: float, to_scale: float) -> void:
	var fx := PixelEffect.new()
	fx.z_index = 7
	fx.setup(file_name, at, duration, from_scale, to_scale)
	add_child(fx)
	_effects.append(fx)

func _tick_effects(delta: float) -> void:
	var keep: Array[PixelEffect] = []
	for fx in _effects:
		if is_instance_valid(fx) and fx.tick(delta):
			keep.append(fx)
			continue
		if is_instance_valid(fx):
			fx.queue_free()
	_effects = keep

func _viewport_size() -> Vector2:
	if not is_inside_tree():
		return Vector2(480, 270)
	var size := get_viewport_rect().size
	if size.x < 32.0 or size.y < 32.0:
		return Vector2(480, 270)
	return size
