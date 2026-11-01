extends Node2D

const REVEAL_SECONDS := 2.3
const INVULN_SECONDS := 1.5
const GRAZE_PAD := 22.0

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

var _player: PlayerShip
var _background: FieldBackground
var _combat: CombatText
var _director: SpawnDirector
var _enemies: Array[EnemyActor] = []
var _shots: Array[Shot] = []
var _drag_accum := Vector2.ZERO
var _primary_touch := -1
var _mouse_down := false

var _hud: Control
var _score_label: Label
var _time_label: Label
var _combo_label: Label
var _form_label: Label
var _hint_label: Label
var _reveal: Control
var _skip_label: Label
var _game_over: Control
var _share_label: Label
var _seed_label: Label

func _ready() -> void:
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
	_player.setup(form_id, Vector2(size.x * 0.5, size.y * 0.78))
	add_child(_player)

	_combat = CombatText.new()
	_combat.z_index = 8
	add_child(_combat)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)

	_score_label = _make_label(22, Color("f4efe4"))
	_score_label.position = Vector2(16, 54)
	_hud.add_child(_score_label)

	_form_label = _make_label(13, FormCatalog.title_color(form_id))
	_form_label.position = Vector2(16, 80)
	_form_label.text = FormCatalog.display_name(form_id)
	_hud.add_child(_form_label)

	_time_label = _make_label(22, Color("f4efe4"))
	_time_label.anchor_left = 1.0
	_time_label.anchor_right = 1.0
	_time_label.offset_left = -150.0
	_time_label.offset_right = -16.0
	_time_label.offset_top = 54.0
	_time_label.offset_bottom = 84.0
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_time_label)

	_combo_label = _make_label(18, Color("ffd56a"))
	_combo_label.anchor_left = 0.5
	_combo_label.anchor_right = 0.5
	_combo_label.offset_left = -80.0
	_combo_label.offset_right = 80.0
	_combo_label.offset_top = 54.0
	_combo_label.offset_bottom = 84.0
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_combo_label)

	_hint_label = _make_label(16, Color("f4efe4"))
	_hint_label.anchor_left = 0.5
	_hint_label.anchor_right = 0.5
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_left = -140.0
	_hint_label.offset_right = 140.0
	_hint_label.offset_top = -78.0
	_hint_label.offset_bottom = -48.0
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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.add_child(center)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(300, 0)
	center.add_child(column)
	var kicker := _make_label(18, Color("c8bdd4"))
	kicker.text = "YOU ARE NOW"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kicker)
	var title := _make_label(52, FormCatalog.title_color(form_id))
	title.text = "%s." % FormCatalog.display_name(form_id)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var gag := _make_label(18, Color("f4efe4"))
	gag.text = FormCatalog.gag(form_id)
	gag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gag.custom_minimum_size = Vector2(280, 60)
	column.add_child(gag)
	_skip_label = _make_label(13, Color("8d8298"))
	_skip_label.text = ""
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_skip_label)

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
	var over_center := CenterContainer.new()
	over_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over.add_child(over_center)
	var over_column := VBoxContainer.new()
	over_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_column.add_theme_constant_override("separation", 16)
	over_column.custom_minimum_size = Vector2(300, 0)
	over_center.add_child(over_column)
	var over_kicker := _make_label(14, Color("c8bdd4"))
	over_kicker.text = "RUN OVER"
	over_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_column.add_child(over_kicker)
	_share_label = _make_label(22, Color("f4efe4"))
	_share_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_share_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_share_label.custom_minimum_size = Vector2(280, 110)
	over_column.add_child(_share_label)
	_seed_label = _make_label(12, Color("8d8298"))
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_column.add_child(_seed_label)
	var button := Button.new()
	button.text = "Reincarnate"
	button.custom_minimum_size = Vector2(260, 72)
	button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f0d78c")
	style.set_corner_radius_all(4)
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_color_override("font_color", Color("24180a"))
	button.add_theme_color_override("font_hover_color", Color("24180a"))
	button.add_theme_color_override("font_pressed_color", Color("24180a"))
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(_on_restart)
	over_column.add_child(button)
	_refresh_hud()

func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_screen_touch(event)
	elif event is InputEventScreenDrag:
		_on_screen_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)

func _on_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
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
	if _primary_touch != -1:
		return
	_mouse_down = event.pressed
	if event.pressed:
		_try_skip_reveal()

func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if phase != PHASE_PLAY or _primary_touch != -1 or not _mouse_down:
		return
	_drag_accum += event.relative

func _try_skip_reveal() -> void:
	if phase == PHASE_REVEAL and reveal_elapsed > 0.35:
		_begin_play()

func _process(delta: float) -> void:
	if _background == null or _player == null or _combat == null:
		return
	delta = clampf(delta, 0.0, 0.033)
	var size := _viewport_size()
	_background.tick(delta, size)
	_combat.tick(delta)
	if phase == PHASE_REVEAL:
		reveal_elapsed += delta
		_skip_label.text = "Tap to start" if reveal_elapsed > 0.35 else ""
		if reveal_elapsed >= REVEAL_SECONDS:
			_begin_play()
		return
	if phase == PHASE_DEAD:
		death_elapsed += delta
		if death_elapsed >= 0.4 and not game_over_visible:
			_show_game_over()
		return
	_play_frame(delta, size)

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
	if _player.ready_to_fire():
		for spec in FormCatalog.player_shots(form_id, _player.position):
			_spawn_shot(spec, true)
		_player.did_fire(FormCatalog.fire_interval(form_id))
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
	_sweep(size)
	_bank_survival(delta)
	if combo_left > 0.0:
		combo_left = maxf(combo_left - delta, 0.0)
	elapsed += delta
	if elapsed > 3.2:
		_hint_label.visible = false
	_refresh_hud()

func _play_bounds(size: Vector2) -> Rect2:
	return Rect2(16, 18, maxf(size.x - 32.0, 40.0), maxf(size.y - 46.0, 40.0))

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
	enemy.setup(next_enemy_id, data, size)
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
			if not _overlaps(shot.position, shot.radius, enemy.position, enemy.radius):
				continue
			enemy.hurt(shot.damage)
			if shot.splits > 0:
				for spec in FormCatalog.split_shots(shot.velocity, shot.position):
					spec["ignore_id"] = enemy.id
					splits.append(spec)
			if not enemy.alive:
				_award_kill(enemy)
			spent.append(shot)
			break
	for shot in spent:
		_drop_shot(shot)
	for spec in splits:
		var child := _spawn_shot(spec, true)
		child.ignore_id = int(spec["ignore_id"])
	if not _player.alive or _player.invulnerable:
		return
	for enemy in _enemies:
		if not enemy.alive:
			continue
		if _overlaps(_player.position, _player.radius, enemy.position, enemy.radius):
			_kill_player(enemy.kind_name)
			return
		_graze(enemy, enemy.position, enemy.radius)
	for shot in _shots:
		if shot.from_player or not is_instance_valid(shot):
			continue
		if _overlaps(_player.position, _player.radius, shot.position, shot.radius):
			_kill_player(shot.killer_name if shot.killer_name != "" else "shot")
			return
		_graze(shot, shot.position, shot.radius)

func _award_kill(enemy: EnemyActor) -> void:
	var result := ScoreRules.on_kill(enemy.score_value, combo, combo_left)
	combo = int(result["combo"])
	combo_left = float(result["combo_left"])
	var points := int(result["points"])
	score += points
	_combat.push("+%s" % ScoreRules.format_score(points), enemy.position + Vector2(-8, -18), Color("f4efe4"))

func _graze(hazard: Object, at: Vector2, hazard_radius: float) -> void:
	if hazard.grazed:
		return
	var dist := _player.position.distance_to(at)
	var hit := _player.radius + hazard_radius
	if dist < hit or dist > hit + GRAZE_PAD:
		return
	hazard.grazed = true
	score += ScoreRules.GRAZE
	_combat.push("+%d" % ScoreRules.GRAZE, at + Vector2(6, -8), Color("ffe08a"))

func _kill_player(name: String) -> void:
	if phase != PHASE_PLAY:
		return
	killer_name = name
	phase = PHASE_DEAD
	_player.alive = false
	_player.visible = false
	_hint_label.visible = false
	_combat.burst(_player.position, FormCatalog.title_color(form_id))
	_refresh_hud()

func _show_game_over() -> void:
	game_over_visible = true
	_share_label.text = ScoreRules.share_line(FormCatalog.display_name(form_id), elapsed, killer_name, score)
	_seed_label.text = "UTC seed %d · run %d" % [day_seed, run_index + 1]
	_game_over.visible = true

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
	_score_label.text = ScoreRules.format_score(score)
	_time_label.text = ScoreRules.format_time(elapsed)
	if combo_left > 0.0 and combo >= 2:
		_combo_label.text = "x%d" % combo
	else:
		_combo_label.text = ""

func _on_restart() -> void:
	get_tree().reload_current_scene()

func _overlaps(a: Vector2, a_radius: float, b: Vector2, b_radius: float) -> bool:
	var reach := a_radius + b_radius
	return a.distance_squared_to(b) <= reach * reach

func _viewport_size() -> Vector2:
	if not is_inside_tree():
		return Vector2(360, 780)
	var size := get_viewport_rect().size
	if size.x < 32.0 or size.y < 32.0:
		return Vector2(360, 780)
	return size
