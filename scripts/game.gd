extends Node2D

const REVEAL_SECONDS := 1.5
const INVULN_SECONDS := 1.5
const GRAZE_PAD := 22.0
const SPLIT_IFRAMES := 1.15
const REGROW_IFRAMES := 0.45
## The pause glyph stays 18 viewport pixels. The control around it is the touch target.
const PAUSE_ART_PX := 18.0
const PAUSE_MIN_PT := 44.0
const CHALLENGE_LABEL := "CHALLENGE A FRIEND"
const CHALLENGE_COPIED := "LINK COPIED!"
const COPY_FEEDBACK := 1.4
## The world name stays up with the form card, then for this long once play starts.
const WORLD_NAME_HOLD := 0.9
## Muted warning ink for the capture invuln note. Alpha lives on the label.
const INVULN_BANNER_COLOR := Color(0.86, 0.48, 0.22, 1)

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
var _boss_director: BossDirector
var _boss_throttle := 0
var _boss_banner: Node2D
var _enemies: Array[EnemyActor] = []
var _shots: Array[Shot] = []
var _loot: Array[LootGem] = []
var _powers: Array[PowerDrop] = []
var _effects: Array[PixelEffect] = []
var pattern_shots: Array[Dictionary] = []
var power_spawned := 0
var overdrive := 0
var overdrive_spawned := 0
var _overdrive_lock := 0.0
var winner := 0
var winner_pops := 0
var _winner_busy := false
var rapid_left := 0.0
var magnet_left := 0.0
var _next_rake := Difficulty.RAKE_FIRST
var _overdrive_flash := 0.0
var _final_flash := 0.0
var _drop_rng := RandomNumberGenerator.new()
var _drop_seeded := false
var _shot_pool: Array[Shot] = []
var _fx_pool: Array[PixelEffect] = []
var _gem_pool: Array[LootGem] = []
var _power_pool: Array[PowerDrop] = []
var _pattern_layer: Node2D
var _death_fx: DeathFx
var _tease: Control
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
var _share_button: Button
var _rotate: Control
var _paused := false
var _debug_on := false
var _debug_label: Label
var _invuln_banner: Label
var _final_evolve := false
var _slow_left := 0.0
var _shake_left := 0.0
var _shake_rng := RandomNumberGenerator.new()
var _pause_button: Button
var _pause_icon: TextureRect
var _pause_overlay: Control
var _pause_card: PauseCard
var _sound: SoundRig
var _sound_button: Button
var _sound_label: Label
var _audio_blocked_button: Button
var _audio_blocked_icon: Control
var _death_audio_stage := ""
var _short_reveal := false
var _card_age := 0.0
var _score_label: Label
var _new_best_label: Label
var _beat_button: Button
var _form_flash: Label
var _world_flash: Label
var _world_flash_left := 0.0
var _death_shade: ColorRect
var _hit_stop_frames := 0
var _hit_stop_cooldown := 0.0
var _juice_shake := 0.0
var _dragon_show: DragonShow
var _lair: LairTransition
var _dragon_phase_on := false
var _dragon_phase_at := 0.0
var _dragon_spawns: DragonSpawnDirector
var _dragon_tier := 0
var _sheets: Array[SheetFx] = []
var _roster_form := 0
var dragon_kills := 0
var _meteor_kills := 0
var _rain_budget := 0
var _meteor_shake_left := 0.0
var _meteor_shake_mag := 0.0
var _tutorial_active := false
var _tut_eye := false
var _tut_gem := false
var _tut_shot := false
var _finger: Replay.Finger
var _chains: Array[Dictionary] = []
var _new_best := false
var _copy_left := 0.0
var _leaderboard: Leaderboard
var _board: LeaderboardScreen
var _name_prompt: NamePrompt
var _rank_label: Label
var _board_button: Button
var _title_board_button: Button
var _pending_score: Dictionary = {}
var _lb_gen := 0
var _rename_gen := 0
var _died_in_play := false
var _board_scaled := false
var _saved_scale_mode := 0
var _saved_scale_aspect := 0
var _saved_window_size := Vector2i.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Touch drags stay raw. Accumulated motion would smooth the finger and
	# add a frame before the body can follow.
	Input.use_accumulated_input = false
	CaptureMode.boot(self)
	_director = SpawnDirector.new(day_seed)
	_boss_director = BossDirector.new(day_seed)
	_sound = SoundRig.new()
	_sound.name = "SoundRig"
	# Keep playing when a headless check disables the game node. The pause
	# button still stops the music through stream_paused.
	_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sound)
	_build_world()
	_sound.play_world_music(_background.world_id)
	_build_hud()
	CaptureMode.finish_boot(self)
	_sound.play_title_card(CaptureMode.title_card(form_id))
	print("Reincarnated as %s in %s (seed %d, run %d)" % [CaptureMode.announce_name(form_id), WorldCatalog.flash_name(_background.world_id), day_seed, run_index])
	if CaptureMode.is_active():
		print(CaptureMode.summary())
	if CaptureMode.wants_hitbox():
		HitLibrary.show = true
		_redraw_hitboxes()
	_prewarm()

func _build_world() -> void:
	var size := _viewport_size()
	_background = FieldBackground.new()
	_background.setup(day_seed, size)
	_background.apply_world(_roll_world())
	add_child(_background)

	_player = PlayerShip.new()
	_player.z_index = 5
	_player.setup(form_id, Vector2(size.x * 0.28, size.y * 0.5))
	add_child(_player)
	_roster_form = form_id
	_dragon_show = DragonShow.new()
	_dragon_show.host = self
	_dragon_show.rng_seed = day_seed
	add_child(_dragon_show)
	_lair = LairTransition.new()
	_lair.name = "LairTransition"
	add_child(_lair)

	_combat = CombatText.new()
	_combat.z_index = 8
	add_child(_combat)
	_pattern_layer = PatternLayer.new()
	_pattern_layer.z_index = 6
	(_pattern_layer as PatternLayer).host = self
	add_child(_pattern_layer)
	_boss_banner = BossBanner.new()
	_boss_banner.z_index = 21
	(_boss_banner as BossBanner).host = self
	add_child(_boss_banner)

	_death_fx = DeathFx.new()
	_death_fx.z_index = 9
	_death_fx.visible = false
	add_child(_death_fx)
	_finger = Replay.Finger.new()
	_finger.z_index = 4
	_finger.visible = false
	add_child(_finger)

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
	_title_card.texture = ArtLibrary.texture(CaptureMode.title_card(form_id))
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
	_form_flash = _make_label(18, Color("ffe56a"))
	_form_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_form_flash.anchor_left = 0.5
	_form_flash.anchor_right = 0.5
	_form_flash.anchor_top = 1.0
	_form_flash.anchor_bottom = 1.0
	_form_flash.offset_left = -120.0
	_form_flash.offset_right = 120.0
	_form_flash.offset_top = -44.0
	_form_flash.offset_bottom = -22.0
	_form_flash.visible = false
	_reveal.add_child(_form_flash)
	_world_flash = _make_label(18, Color("ffe56a"))
	_world_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_flash.anchor_left = 0.5
	_world_flash.anchor_right = 0.5
	_world_flash.anchor_top = 1.0
	_world_flash.anchor_bottom = 1.0
	_world_flash.offset_left = -140.0
	_world_flash.offset_right = 140.0
	_world_flash.offset_top = -70.0
	_world_flash.offset_bottom = -48.0
	_world_flash.visible = false
	_world_flash.z_index = 2
	_hud.add_child(_world_flash)
	_sync_world_flash()

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
	_death_shade = ColorRect.new()
	_death_shade.color = Color(0.04, 0.03, 0.07, 0.86)
	_death_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_shade.gui_input.connect(_on_death_pointer)
	_game_over.add_child(_death_shade)
	_death_kicker = _make_label(9, Color("f2fbff"))
	_death_kicker.text = "RUN OVER"
	_death_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over.add_child(_death_kicker)
	_score_label = _make_label(27, Color("f2fbff"))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.visible = false
	_game_over.add_child(_score_label)
	_new_best_label = _make_label(18, Color("ffe56a"))
	_new_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_new_best_label.visible = false
	_game_over.add_child(_new_best_label)
	_share_label = _make_label(18, Color("f2fbff"))
	_share_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_share_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over.add_child(_share_label)
	_best_label = _make_label(18, Color("ffd84a"))
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over.add_child(_best_label)
	_seed_label = _make_label(9, Color("a49fcf"))
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over.add_child(_seed_label)
	_rank_label = _make_label(9, Color("8ecbff"))
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_label.visible = false
	_rank_label.gui_input.connect(_on_rank_retry_input)
	_game_over.add_child(_rank_label)
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
	_share_button = Button.new()
	_share_button.text = "Share"
	_share_button.focus_mode = Control.FOCUS_NONE
	_share_button.mouse_filter = Control.MOUSE_FILTER_STOP
	var share_style := StyleBoxFlat.new()
	share_style.bg_color = Color("241428")
	share_style.set_border_width_all(2)
	share_style.border_color = Color("f2fbff")
	share_style.set_corner_radius_all(4)
	_share_button.add_theme_stylebox_override("normal", share_style)
	_share_button.add_theme_stylebox_override("hover", share_style)
	_share_button.add_theme_stylebox_override("pressed", share_style)
	_share_button.add_theme_stylebox_override("focus", share_style)
	_share_button.add_theme_font_override("font", _font_outlined)
	_share_button.add_theme_color_override("font_color", Color("f2fbff"))
	_share_button.add_theme_color_override("font_hover_color", Color("f2fbff"))
	_share_button.add_theme_color_override("font_pressed_color", Color("f2fbff"))
	_share_button.add_theme_font_size_override("font_size", 18)
	_share_button.pressed.connect(_on_share)
	_game_over.add_child(_share_button)
	_beat_button = _make_death_button(CHALLENGE_LABEL, Color("14324f"))
	_beat_button.add_theme_font_size_override("font_size", 18)
	_beat_button.pressed.connect(_on_beat_link)
	_game_over.add_child(_beat_button)
	_board_button = _make_death_button("LEADERBOARD", Color("2a2140"))
	_board_button.pressed.connect(_open_board)
	_game_over.add_child(_board_button)
	_style_challenge(false)
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
	_pause_card = PauseCard.new()
	_pause_card.setup(_font_outlined)
	_pause_overlay.add_child(_pause_card)
	_refresh_pause_card()

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
	_sound_button = Button.new()
	_sound_button.focus_mode = Control.FOCUS_NONE
	_sound_button.flat = true
	_sound_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_sound_button.z_index = 3
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_sound_button.add_theme_stylebox_override(state, empty)
	_sound_button.add_theme_font_override("font", _font_outlined)
	_sound_button.add_theme_font_size_override("font_size", 9)
	_sound_button.pressed.connect(_toggle_sound)
	_hud.add_child(_sound_button)
	_audio_blocked_button = Button.new()
	_audio_blocked_button.focus_mode = Control.FOCUS_NONE
	_audio_blocked_button.flat = true
	_audio_blocked_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_audio_blocked_button.z_index = 4
	_audio_blocked_button.visible = false
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_audio_blocked_button.add_theme_stylebox_override(state, empty)
	_audio_blocked_button.pressed.connect(_retry_web_audio)
	_hud.add_child(_audio_blocked_button)
	_audio_blocked_icon = SpeakerOffMark.new()
	_audio_blocked_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio_blocked_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_audio_blocked_icon.size = Vector2(PAUSE_ART_PX, PAUSE_ART_PX)
	_audio_blocked_icon.custom_minimum_size = Vector2(PAUSE_ART_PX, PAUSE_ART_PX)
	_audio_blocked_button.add_child(_audio_blocked_icon)
	_sound_label = _make_label(9, Color("f2fbff"))
	_sound_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sound_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_sound_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sound_label.offset_left = 0.0
	_sound_label.offset_top = 1.0
	_sound_label.offset_right = -2.0
	_sound_label.offset_bottom = 0.0
	_sound_button.add_child(_sound_label)
	_refresh_sound_button()
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
	_debug_label = _make_label(9, Color("ffe56a"))
	_debug_label.position = Vector2(8, 78)
	_debug_label.visible = false
	_debug_label.z_index = 4
	_hud.add_child(_debug_label)
	_build_invuln_banner()
	_title_board_button = _make_death_button("LEADERBOARD", Color("2a2140"))
	_title_board_button.z_index = 3
	_title_board_button.visible = false
	_title_board_button.pressed.connect(_open_board)
	_hud.add_child(_title_board_button)
	_layout_title_button(_viewport_size())
	_leaderboard = Leaderboard.new()
	_leaderboard.name = "Leaderboard"
	_leaderboard.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_leaderboard)
	_board = LeaderboardScreen.new()
	_board.setup(_leaderboard, _font_outlined)
	_board.closed.connect(_on_board_closed)
	_board.rename_requested.connect(_on_board_rename)
	_hud.add_child(_board)
	_name_prompt = NamePrompt.new()
	_name_prompt.setup(_font_outlined)
	_name_prompt.decided.connect(_on_name_decided)
	_name_prompt.cancelled.connect(_on_name_cancelled)
	_hud.add_child(_name_prompt)
	_refresh_hud()
	_sync_invuln_banner()

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

func _make_death_button(caption: String, bg: Color) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(2)
	style.border_color = Color("f2fbff")
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_font_override("font", _font_outlined)
	button.add_theme_color_override("font_color", Color("f2fbff"))
	button.add_theme_color_override("font_hover_color", Color("f2fbff"))
	button.add_theme_color_override("font_pressed_color", Color("f2fbff"))
	button.add_theme_font_size_override("font_size", 9)
	return button

func wants_rotate(size: Vector2) -> bool:
	# The stretch mode can keep a landscape viewport inside a tall window.
	# A portrait phone should see the prompt, not a letterboxed strip.
	if size.y > size.x:
		return true
	var window_size := DisplayServer.window_get_size()
	return window_size.y > window_size.x

func _input(event: InputEvent) -> void:
	if _paused or wants_rotate(_viewport_size()):
		return
	var consumed := false
	if event is InputEventScreenDrag:
		consumed = _on_screen_drag(event)
	elif event is InputEventMouseMotion:
		consumed = _on_mouse_motion(event)
	if consumed and is_inside_tree():
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _is_gesture(event) and _sound != null:
		_sound.unlock_from_gesture()
	if _board != null and _board.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_board._on_back()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if CaptureMode.eat_key(self, event.keycode):
			return
		if event.keycode == KEY_H:
			HitLibrary.show = not HitLibrary.show
			_redraw_hitboxes()
			return
		if event.keycode == KEY_D:
			_debug_on = not _debug_on
			_refresh_debug()
			return
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			_toggle_pause()
			return
	if _paused or wants_rotate(_viewport_size()):
		return
	if event is InputEventScreenTouch:
		_on_screen_touch(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_mouse_button(event)

func _is_gesture(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	return false

func _on_screen_touch(event: InputEventScreenTouch) -> void:
	if _hits_pause(event.position) or _hits_sound(event.position) or _hits_audio_blocked(event.position):
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

func _on_screen_drag(event: InputEventScreenDrag) -> bool:
	if phase != PHASE_PLAY or event.index != _primary_touch or _player == null:
		return false
	_player.nudge(event.relative, _play_bounds(_viewport_size()))
	return true

func _on_mouse_button(event: InputEventMouseButton) -> void:
	if _hits_pause(event.position) or _hits_sound(event.position) or _hits_audio_blocked(event.position):
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

func _on_mouse_motion(event: InputEventMouseMotion) -> bool:
	if phase != PHASE_PLAY or _primary_touch != -1 or not _mouse_down or _player == null:
		return false
	_player.nudge(event.relative, _play_bounds(_viewport_size()))
	return true

func _try_skip_reveal() -> void:
	if phase != PHASE_REVEAL:
		return
	if _short_reveal or reveal_elapsed > 0.35:
		_begin_play()

func _try_skip_tease() -> bool:
	if phase != PHASE_DEAD or game_over_visible:
		return false
	_skip_death_to_card()
	return true

func _skip_death_to_card() -> void:
	if phase != PHASE_DEAD or game_over_visible:
		return
	var card_at := float(FxTimeline.DEATH_FRAMES) / FxTimeline.FPS + FxTimeline.TEASE_SECONDS
	if death_elapsed < card_at:
		death_elapsed = card_at
	_silence_death()
	_present_death()

func _on_death_pointer(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		pressed = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		_on_restart()

func _process(delta: float) -> void:
	if _background == null or _player == null or _combat == null:
		return
	var size := _viewport_size()
	if _name_prompt != null and _name_prompt.visible:
		_name_prompt.place_for(size)
	if _board != null and _board.visible:
		if _rotate != null:
			_rotate.visible = false
		if _title_board_button != null:
			_title_board_button.visible = false
		return
	if _rotate != null and wants_rotate(size):
		_rotate.visible = true
		if _pause_button != null:
			_pause_button.visible = false
		if _sound_button != null:
			_sound_button.visible = false
		if _audio_blocked_button != null:
			_audio_blocked_button.visible = false
		if _title_board_button != null:
			_title_board_button.visible = false
		return
	if _rotate != null:
		_rotate.visible = false
	_layout_pause(size)
	_layout_title_button(size)
	if _title_board_button != null:
		_title_board_button.visible = phase == PHASE_REVEAL
	_apply_shake(delta)
	if _paused:
		return
	delta = clampf(delta, 0.0, 0.033)
	# A few frozen frames. Elapsed does not move, so the spawn clock stays put.
	if phase == PHASE_PLAY and _hit_stop_frames > 0:
		_hit_stop_frames -= 1
		return
	if phase == PHASE_PLAY and _dragon_show != null:
		_dragon_show.tick(delta)
	var world_delta := delta
	if phase == PHASE_PLAY and _slow_left > 0.0:
		_slow_left = maxf(_slow_left - delta, 0.0)
		world_delta = delta * Difficulty.FINAL_SLOWMO_SCALE
	var scroll_delta := world_delta if phase == PHASE_PLAY else delta
	var scroll_scale := Difficulty.scroll_scale(elapsed)
	_background.tick(scroll_delta, size, scroll_scale)
	if _lair != null and _lair.running:
		_lair.scroll(scroll_delta, size, scroll_scale)
		if _lair.advance(delta):
			_finish_lair_swap()
	_combat.tick(delta)
	_tick_effects(delta)
	_tick_sheets(delta)
	if phase == PHASE_REVEAL:
		if CaptureMode.holding():
			return
		reveal_elapsed += delta
		_animate_title_card()
		_present_reveal()
		var reveal_limit := Replay.FLASH_REVEAL if _short_reveal else REVEAL_SECONDS
		if reveal_elapsed >= reveal_limit:
			_begin_play()
		return
	if phase == PHASE_DEAD:
		if _world_flash != null and _world_flash.visible:
			_world_flash.visible = false
			_world_flash_left = 0.0
		death_elapsed += delta
		if game_over_visible:
			_card_age += delta
			_tick_copy_flash(delta)
			_tick_new_best_pop()
		_present_death()
		return
	if _world_flash_left > 0.0:
		_world_flash_left = maxf(_world_flash_left - delta, 0.0)
		if _world_flash_left <= 0.0 and _world_flash != null:
			_world_flash.visible = false
	_play_frame(world_delta, size)

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
	if CaptureMode.block_play(self):
		return
	phase = PHASE_PLAY
	invuln = INVULN_SECONDS
	_player.invulnerable = true
	_reveal.visible = false
	if _form_flash != null:
		_form_flash.visible = false
	_world_flash_left = WORLD_NAME_HOLD
	_sync_world_flash()
	_hint_label.visible = true
	if _wants_tutorial():
		_tutorial_active = true
		_tut_eye = false
		_tut_gem = false
		_tut_shot = false
		Replay.mark_seen()
		_hint_label.visible = false

func _play_frame(delta: float, size: Vector2) -> void:
	var bounds := _play_bounds(size)
	# Pointer drag is applied in _input. Keys stay on this tick.
	var key := _key_vector()
	if key != Vector2.ZERO:
		_player.add_drag(key * FormCatalog.max_speed(form_id) * delta, bounds)
	invuln = maxf(invuln - delta, 0.0)
	_player.invulnerable = invuln > 0.0
	_player.tick(delta, bounds)
	if _player.regrew:
		invuln = maxf(invuln, REGROW_IFRAMES)
		_player.invulnerable = true
	if _player.ready_to_fire():
		var interval := float(FormCatalog.rank_spec(form_id, rank_index)["fire_interval"])
		var level := _power_level()
		if form_id == FormCatalog.Id.DEMON:
			# Orbs already clear crowds. Power only nudges them, so a long run
			# cannot turn the final form into a screen wipe.
			interval *= pow(0.995, float(level))
		else:
			interval = FormCatalog.power_fire_interval(interval, level)
		if rapid_left > 0.0:
			interval *= Difficulty.RAPID_FIRE_SCALE
		_player.note_shot()
		var shot_event := AudioCues.shot_event_for_form(form_id)
		if _sound != null and shot_event != "":
			_sound.play_event(shot_event)
		var crowd := _crowd_size()
		for spec in FormCatalog.player_shots(form_id, _player.position, rank_index):
			if form_id == FormCatalog.Id.DEMON:
				var speed := FormCatalog.demon_speed(rank_index, crowd)
				var aim: Vector2 = spec["velocity"]
				spec["velocity"] = Vector2(speed, aim.y)
				spec["homing"] = FormCatalog.demon_homing(rank_index, crowd) + float(level) * 0.5
				spec["damage"] = FormCatalog.demon_damage(rank_index, crowd) + level / 8
			elif form_id == FormCatalog.Id.DRAGON:
				spec["damage"] = int(spec["damage"]) + FormCatalog.dragon_power_bonus(level)
				_spawn_fx("dragon_form/dragon_muzzle.png", spec["position"], 3.0 / 15.0, 0.8, 1.3)
			elif level > 0:
				spec["damage"] = int(spec["damage"]) + FormCatalog.power_damage_bonus(form_id, level)
			_spawn_shot(spec, true)
		_player.did_fire(interval)
	CaptureMode.tick_play(self, delta)
	if _tutorial_active and elapsed < Replay.TUTORIAL_SECONDS:
		_tick_tutorial(delta, size)
		_director.pop_due(elapsed)
	else:
		if _tutorial_active:
			_finish_tutorial()
		var living := _living_boss()
		if _boss_director != null:
			_boss_director.set_boss_alive(living != null)
			for event in _boss_director.pop_due(elapsed):
				# A regular boss no longer walks off, so it would hold the
				# dragon's clock. Clear it with no reward, then the dragon enters.
				if str(event.get("slug", "")) == "great_dragon" and living != null and living.boss_slug != "great_dragon":
					if living is BossActor:
						(living as BossActor).dismiss()
					else:
						living.alive = false
						living.visible = false
					living = null
				if _spawn_boss(event, size):
					living = _living_boss()
		if dragon_phase_elapsed() >= 0.0:
			_spawn_dragon_minions(living, size)
		else:
			var enemy_room := Difficulty.enemy_cap(elapsed) - _alive_enemy_count()
			for event in _director.pop_due(elapsed):
				if living != null and _throttle_spawn(living):
					continue
				if enemy_room <= 0:
					continue
				if _spawn_enemy(event, size):
					enemy_room -= 1
	var player_pos := _player.position
	var shot_cap := Difficulty.enemy_shot_cap(elapsed)
	if dragon_phase_elapsed() >= 0.0:
		shot_cap = DragonPhase.shot_cap(dragon_phase_elapsed())
	var shot_room := maxi(shot_cap - _reserved_enemy_shots(), 0)
	var dragon_boss := _great_dragon_on_screen()
	for enemy in _enemies:
		if not enemy.alive:
			continue
		if enemy is DragonEnemy:
			var dragon := enemy as DragonEnemy
			var phase_t := dragon_phase_elapsed()
			if phase_t < 0.0:
				phase_t = 0.0
			dragon.bullet_density = DragonPhase.bullet_density(phase_t)
			dragon.move_scale = DragonPhase.speed_mul(phase_t)
			dragon.suppress_fire = dragon_boss
			dragon.bind_allies(_enemies)
		enemy.fire_room = shot_room
		for spec in enemy.tick(delta, player_pos, elapsed, Difficulty.speed_scale(elapsed)):
			_note_enemy_shot(spec)
			_spawn_shot(spec, false)
		if enemy.gust_push != 0.0 and _player.alive:
			_player.position.x = clampf(_player.position.x + enemy.gust_push * delta, 18.0, size.x - 18.0)
		for extra in enemy.take_spawns():
			_spawn_enemy(extra, size)
		var bye := enemy.take_farewell()
		if not bye.is_empty():
			var offset: Vector2 = bye.get("offset", Vector2.ZERO)
			_play_sheet(str(bye.get("file", "")), enemy.position + offset)
			play_sfx_hook(str(bye.get("cue", "")))
		if shot_room >= 0:
			shot_room = enemy.fire_room
	_guide_orbs(delta)
	for shot in _shots:
		shot.tick(delta)
	_sync_puddle_loop()
	_tick_patterns(delta, size)
	_collide()
	_tick_loot(delta)
	_tick_powers(delta)
	if rapid_left > 0.0:
		rapid_left = maxf(rapid_left - delta, 0.0)
	if magnet_left > 0.0:
		magnet_left = maxf(magnet_left - delta, 0.0)
	if _overdrive_flash > 0.0:
		_overdrive_flash = maxf(_overdrive_flash - delta, 0.0)
	if _final_flash > 0.0:
		_final_flash = maxf(_final_flash - delta, 0.0)
	_sweep(size)
	_bank_survival(delta)
	if combo_left > 0.0:
		combo_left = maxf(combo_left - delta, 0.0)
	elapsed += delta
	if _hit_stop_cooldown > 0.0:
		_hit_stop_cooldown = maxf(_hit_stop_cooldown - delta, 0.0)
	_tick_chains(delta)
	if elapsed > 3.2 and not _tutorial_active:
		_hint_label.visible = false
	_refresh_hud()
	_refresh_debug()
	_sync_invuln_banner()
	if _boss_banner != null:
		_boss_banner.queue_redraw()

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

func _spawn_boss(data: Dictionary, size: Vector2) -> bool:
	var enemy := BossActor.new()
	enemy.z_index = 4
	enemy.setup(next_enemy_id, data, size, _background)
	next_enemy_id += 1
	if _spawn_overlaps_player(enemy):
		enemy.free()
		return false
	add_child(enemy)
	_enemies.append(enemy)
	if _sound != null:
		var enter := BossCatalog.cue(str(data.get("slug", "")), "enter")
		if str(data.get("slug", "")) == "great_dragon":
			enter = "great_dragon_entrance"
		_sound.play_event(enter)
	return true

func _living_boss() -> EnemyActor:
	for enemy in _enemies:
		if is_instance_valid(enemy) and enemy.alive and enemy.is_boss():
			return enemy
	return null

## Regular bosses cut the spawn stream in half. The dragon leaves more of it,
## so the field stays busy under the final fight.
func _throttle_spawn(boss: EnemyActor) -> bool:
	_boss_throttle += 1
	if boss.boss_slug == "great_dragon":
		return _boss_throttle % 3 == 0
	return _boss_throttle % 2 == 0

func _spawn_enemy(data: Dictionary, size: Vector2) -> bool:
	var enemy: EnemyActor = DragonEnemy.new() if bool(data.get("dragon", false)) else EnemyActor.new()
	enemy.z_index = 3
	enemy.setup(next_enemy_id, data, size, _background)
	next_enemy_id += 1
	if _spawn_overlaps_player(enemy):
		enemy.free()
		return false
	add_child(enemy)
	_enemies.append(enemy)
	return true

func _alive_enemy_count() -> int:
	var count := 0
	for enemy in _enemies:
		if enemy.alive:
			count += 1
	return count

func _reserved_enemy_shots() -> int:
	var count := 0
	for shot in _shots:
		if is_instance_valid(shot) and not shot.from_player:
			count += 1
	for enemy in _enemies:
		if enemy.alive:
			count += enemy.telegraphs.size()
	return count

## A spawn that is already touching the player is not a dodge. Pushing it
## would desync an archer from its island, so the beat is skipped instead.
func _spawn_overlaps_player(enemy: EnemyActor) -> bool:
	if CaptureMode.is_active() or _player == null:
		return false
	if enemy.position.distance_to(_player.position) > enemy.radius + _player.radius + 6.0:
		return false
	var enemy_file := enemy.sprite_file()
	return HitLibrary.overlaps(_player.position, _player.sprite_name(), "hurt", enemy.position, enemy_file, "threat", _player_scale(), 1.0, _player.anim_frame())

func _spawn_shot(data: Dictionary, from_player: bool) -> Shot:
	var shot: Shot
	if _shot_pool.is_empty():
		shot = Shot.new()
		add_child(shot)
	else:
		shot = _shot_pool.pop_back() as Shot
	# Enemy bullets sit above FX, popups, evolve art, and the overdrive flash.
	shot.z_index = 3 if from_player else Replay.bullet_z()
	shot.setup(data, from_player)
	_shots.append(shot)
	return shot

func _collide() -> void:
	_reflect_swipes()
	var spent: Array[Shot] = []
	var splits: Array[Dictionary] = []
	for shot in _shots:
		if not shot.from_player or not is_instance_valid(shot):
			continue
		# A zero-damage swipe only reflects. Touching a body must not erase it.
		if int(shot.damage) <= 0:
			continue
		for enemy in _enemies:
			if not enemy.alive:
				continue
			if shot.hit_ids.has(enemy.id):
				continue
			if shot.ignore_id == enemy.id and shot.age < 0.1:
				continue
			var enemy_file := enemy.sprite_file()
			var reach_scale := shot.hit_scale
			var reach_x := (128.0 if enemy.is_boss() else 96.0) * reach_scale
			var reach_y := (96.0 if enemy.is_boss() else 72.0) * reach_scale
			if absf(shot.position.x - enemy.position.x) > reach_x or absf(shot.position.y - enemy.position.y) > reach_y:
				continue
			if not enemy.can_be_hit():
				continue
			if enemy.blocks_player_shot(shot):
				_spawn_fx("hit_flash.png", shot.position, 0.14, 0.8, 1.3)
				if _combat != null:
					_combat.push("BLOCK", shot.position + Vector2(-10, -12), Color("d4dcf5"), 0.28)
				if shot.pierce < 0:
					shot.hit_ids.append(enemy.id)
					continue
				spent.append(shot)
				break
			if not HitLibrary.overlaps(shot.position, shot.sprite_name, "body", enemy.position, enemy_file, "body", shot.hit_scale):
				continue
			enemy.hurt(shot.damage)
			if enemy is DragonEnemy and (enemy as DragonEnemy).consume_block():
				_spawn_fx("hit_flash.png", shot.position, 0.14, 0.8, 1.3)
				if _combat != null:
					_combat.push("BLOCK", shot.position + Vector2(-10, -12), Color("d7c4ff"), 0.28)
				if shot.pierce < 0:
					shot.hit_ids.append(enemy.id)
					continue
				spent.append(shot)
				break
			shot.hit_ids.append(enemy.id)
			if shot.splits > 0:
				for spec in FormCatalog.split_shots(shot.velocity, shot.position, shot.splits):
					spec["ignore_id"] = enemy.id
					splits.append(spec)
			if shot.splash > 0:
				_splash_shot(shot, enemy)
			if not enemy.alive:
				_award_kill(enemy, true)
				if not enemy is DragonEnemy:
					_spawn_fx("death_puff.png", enemy.position, 0.42, 0.45, 1.55)
			else:
				_spawn_fx("hit_flash.png", shot.position, 0.16, 0.75, 1.35)
			# Pierce below 0 is unlimited. hit_ids already keeps one hit per target.
			if shot.pierce < 0 or shot.pierce > 0:
				if shot.pierce > 0:
					shot.pierce -= 1
				continue
			spent.append(shot)
			break
	for shot in spent:
		_drop_shot(shot)
	for spec in splits:
		var child := _spawn_shot(spec, true)
		child.ignore_id = int(spec["ignore_id"])
	if not _player.alive or _player.invulnerable or _player.blink_guard > 0.0:
		return
	var player_file := _player.sprite_name()
	var player_scale := _player_scale()
	for enemy in _enemies:
		if not enemy.alive or not enemy.threatens_player():
			continue
		var enemy_file := enemy.sprite_file()
		# Every hurt part, not the movement bounds radius.
		if enemy.is_boss() and enemy.intro_left > 0.0:
			continue
		var enemy_gap := HitLibrary.gap(_player.position, player_file, "hurt", enemy.position, enemy_file, "threat", player_scale, 1.0, _player.anim_frame())
		if enemy_gap <= 0.0:
			_hurt_player(enemy.kind_name)
			return
		_graze_gap(enemy, enemy_gap)
	for shot in _shots:
		if shot.from_player or not is_instance_valid(shot):
			continue
		var shot_gap := HitLibrary.gap(_player.position, player_file, "hurt", shot.position, shot.sprite_name, "threat", player_scale, 1.0, _player.anim_frame())
		if shot_gap <= 0.0:
			_hurt_player(shot.killer_name if shot.killer_name != "" else "shot")
			return
		_graze_gap(shot, shot_gap)

func _award_kill(enemy: EnemyActor, drop_loot: bool = true) -> void:
	var result := ScoreRules.on_kill(enemy.score_value, combo, combo_left, rank_index)
	combo = int(result["combo"])
	combo_left = float(result["combo_left"])
	var points := int(result["points"])
	score += points
	if points >= Difficulty.POPUP_MIN:
		_combat.push("+%s" % ScoreRules.format_score(points), enemy.position + Vector2(-6, -12), Color("241428"), Difficulty.POPUP_LIFE)
	if enemy is BossActor:
		var boss := enemy as BossActor
		if boss.boss_slug == "great_dragon" and not boss.return_booked and _boss_director != null:
			boss.return_booked = true
			_boss_director.on_dragon_killed(elapsed)
			_begin_dragon_slay(points, boss.position)
	if drop_loot:
		if enemy.is_boss():
			_reward_boss(enemy)
		else:
			_roll_drops(enemy.position)
	if _sound != null:
		_sound.play_event("enemy_killed")
		if enemy.is_boss():
			_sound.play_event(BossCatalog.cue(enemy.boss_slug, "death"))
	if drop_loot and not _winner_busy and form_id == FormCatalog.Id.VENDING:
		_charge_winner()
	if drop_loot and form_id == FormCatalog.Id.DRAGON:
		_charge_meteor()
	if enemy is DragonEnemy:
		_present_dragon_death(enemy as DragonEnemy)
	if enemy.max_hp >= 3:
		_request_hit_stop(3)
		_bump_shake()

func _graze_gap(hazard: Object, separation: float) -> void:
	if hazard.grazed:
		return
	if separation <= 0.0 or separation > GRAZE_PAD:
		return
	hazard.grazed = true
	var grazed := ScoreRules.graze_points(rank_index)
	score += grazed

func _hurt_player(killer: String) -> void:
	if CaptureMode.ignore_hit(self, killer):
		return
	if phase != PHASE_PLAY or not _player.alive:
		return
	if _player.shield_hits > 0:
		_player.shield_hits = 0
		invuln = maxf(invuln, Difficulty.SHIELD_IFRAMES)
		_player.invulnerable = true
		_spawn_fx("hit_flash.png", _player.position, 0.18, 0.5, 1.2)
		return
	# Slime trait only. A small Slime falls through to the one death of the run.
	# A capture piano is the death the clip is there to record, so it is not spent on the split.
	if not CaptureMode.bypass_split(killer) and _player.absorb_lethal_hit():
		invuln = maxf(invuln, SPLIT_IFRAMES)
		_player.invulnerable = true
		_combat.push("SPLIT!", _player.position + Vector2(-28, -24), Color("1a4f9c"))
		_spawn_fx("hit_flash.png", _player.position, 0.22, 0.6, 1.4)
		return
	_kill_player(killer)

func _spawn_evo_gem(at: Vector2) -> void:
	var gem := _take_gem()
	gem.setup("gem.png")
	gem.life = Difficulty.GEM_LIFE
	gem.drift = Difficulty.GEM_DRIFT
	gem.age = 0.0
	gem.position = at
	gem.modulate = Color.WHITE
	gem.z_index = 7
	_loot.append(gem)

func _take_gem() -> LootGem:
	if _gem_pool.is_empty():
		var gem := LootGem.new()
		add_child(gem)
		return gem
	var gem: LootGem = _gem_pool.pop_back() as LootGem
	gem.visible = true
	return gem

func _release_gem(gem: LootGem) -> void:
	if not is_instance_valid(gem):
		return
	gem.visible = false
	_gem_pool.append(gem)

func _tick_loot(delta: float) -> void:
	var magnet := 0.0
	var magnet_speed := 0.0
	if form_id == FormCatalog.Id.GOBLIN:
		magnet = Difficulty.GOBLIN_MAGNET
		magnet_speed = Difficulty.GOBLIN_MAGNET_SPEED
	if magnet_left > 0.0:
		magnet = maxf(magnet, Difficulty.MAGNET_RADIUS)
		magnet_speed = maxf(magnet_speed, Difficulty.MAGNET_SPEED)
	var write := 0
	for gem in _loot:
		if not is_instance_valid(gem):
			continue
		var started := gem.position
		if not gem.tick(delta):
			_release_gem(gem)
			continue
		if _player.alive and magnet > 0.0:
			var offset := _player.position - gem.position
			var dist := offset.length()
			# tick() already drifted the gem left. A gem that began this frame
			# inside the radius stays in the pull, or the trailing rim would
			# scroll out before the speed could matter.
			var in_range := dist <= magnet or started.distance_to(_player.position) <= magnet
			if in_range and dist > 0.5:
				gem.position += offset / dist * magnet_speed * delta
		if _player.alive and _loot_reached(gem):
			_collect_gem(gem)
			continue
		if gem.position.x < -40.0:
			_release_gem(gem)
			continue
		_loot[write] = gem
		write += 1
	_loot.resize(write)

func _collect_gem(gem: LootGem) -> void:
	var at := gem.position
	var winner_gem := _pickup_is_gem(gem)
	_release_gem(gem)
	loot_count += 1
	score += Difficulty.GEM_SCORE + gem.bonus_score
	if gem.bonus_score > 0 and _combat != null:
		_combat.push("+%d" % (Difficulty.GEM_SCORE + gem.bonus_score), at + Vector2(-10, -14), Color("ffe56a"), 0.45)
	if _sound != null:
		_sound.play_event("gem_pickup")
		if gem.sprite_name == DragonPhase.ELDER_GEM:
			_sound.play_event("dragon_enemy_elder_drake_gem_pickup")
	_spawn_fx("graze_sparkle.png", at, 0.22, 0.6, 1.2)
	_add_evo(Difficulty.GEM_EVO)
	# Same step as one kill. Coins share this pickup and do not count. Powerups do not come through here.
	if winner_gem and form_id == FormCatalog.Id.VENDING and not _winner_busy:
		_charge_winner()

## Evolution gems and Elder Drake gems. A coin uses the same node and does not count.
func _pickup_is_gem(gem: LootGem) -> bool:
	return gem.sprite_name.find("gem") >= 0

## Touch only. The magnet radius pulls; it does not collect.
func _loot_reached(gem: LootGem) -> bool:
	return _overlaps(_player.position, _player.radius, gem.position, gem.radius)

func _roll_drops(at: Vector2) -> void:
	if _drop_unit() < Difficulty.GEM_CHANCE:
		_spawn_evo_gem(at)
	if _try_overdrive_drop(at):
		return
	if _drop_unit() < Difficulty.POWER_CHANCE:
		var kinds: Array[String] = ["bomb", "shield", "rapid", "magnet"]
		var index := _drop_rng.randi() % kinds.size()
		_spawn_power(at + Vector2(8, -6), kinds[index])

func _reward_boss(enemy: EnemyActor) -> void:
	var count := BossCatalog.GEM_BURST
	if enemy.boss_slug == "great_dragon":
		count = BossCatalog.DRAGON_GEM_BURST
		_spawn_gem_burst(enemy.position, count)
		# Guaranteed. The normal roll can miss, and a live drop would block it.
		_spawn_power(enemy.position + Vector2(8, -12), "overdrive")
		return
	_spawn_gem_burst(enemy.position, count)
	_try_overdrive_drop(enemy.position, BossCatalog.OVERDRIVE_MULT)

func _spawn_gem_burst(at: Vector2, count: int) -> void:
	for i in count:
		var gem := _take_gem()
		gem.setup("gem.png")
		gem.life = Difficulty.GEM_LIFE + 0.35
		gem.drift = Difficulty.GEM_DRIFT
		gem.age = 0.0
		var ang := TAU * float(i) / float(maxi(count, 1))
		var ring := 12.0 + float(i % 3) * 7.0
		gem.position = at + Vector2(cos(ang), sin(ang)) * ring
		gem.modulate = Color.WHITE
		gem.z_index = 7
		_loot.append(gem)

func _try_overdrive_drop(at: Vector2, multiplier: float = 1.0) -> bool:
	if elapsed < _overdrive_lock or _overdrive_live():
		return false
	var chance := Difficulty.overdrive_drop_chance(elapsed) * maxf(multiplier, 0.0)
	if _drop_unit() >= chance:
		return false
	_spawn_power(at + Vector2(10, -8), "overdrive")
	_overdrive_lock = elapsed + Difficulty.OVERDRIVE_DROP_COOLDOWN
	return true

func _overdrive_live() -> bool:
	for drop in _powers:
		if is_instance_valid(drop) and drop.visible and drop.kind == "overdrive":
			return true
	return false

func _drop_unit() -> float:
	if not _drop_seeded:
		_drop_seeded = true
		_drop_rng.seed = int(day_seed) * 17 + 3
	return _drop_rng.randf()

func _spawn_power(at: Vector2, kind: String) -> void:
	var drop: PowerDrop
	if _power_pool.is_empty():
		drop = PowerDrop.new()
		add_child(drop)
	else:
		drop = _power_pool.pop_back() as PowerDrop
	drop.setup(kind)
	drop.position = at
	drop.drift = Difficulty.POWER_DRIFT
	drop.life = Difficulty.POWER_LIFE
	drop.z_index = 7
	drop.visible = true
	_powers.append(drop)
	power_spawned += 1
	if kind == "overdrive":
		overdrive_spawned += 1

func _tick_powers(delta: float) -> void:
	if _powers.is_empty():
		return
	var magnet := Difficulty.MAGNET_RADIUS if magnet_left > 0.0 else 0.0
	var write := 0
	for drop in _powers:
		if not is_instance_valid(drop):
			continue
		if not drop.tick(delta):
			_release_power(drop)
			continue
		if _player.alive and magnet > 0.0:
			var offset := _player.position - drop.position
			var dist := offset.length()
			if dist <= magnet and dist > 0.5:
				drop.position += offset / dist * Difficulty.MAGNET_SPEED * delta
		if _player.alive and _overlaps(_player.position, _player.radius, drop.position, drop.radius):
			_collect_power(drop)
			continue
		if drop.position.x < -40.0:
			_release_power(drop)
			continue
		_powers[write] = drop
		write += 1
	_powers.resize(write)

func _collect_power(drop: PowerDrop) -> void:
	var kind := drop.kind
	var at := drop.position
	_release_power(drop)
	if _sound != null:
		_sound.play_event("power_pickup")
	_spawn_fx("graze_sparkle.png", at, 0.2, 0.5, 1.3)
	match kind:
		"bomb":
			_detonate()
		"shield":
			_player.shield_hits = 1
		"rapid":
			rapid_left = Difficulty.POWER_DURATION
		"magnet":
			magnet_left = Difficulty.POWER_DURATION
		"overdrive":
			_overdrive_blast()

func _release_power(drop: PowerDrop) -> void:
	if not is_instance_valid(drop):
		return
	drop.visible = false
	_power_pool.append(drop)

func _detonate() -> void:
	_clear_enemy_shots()
	score += Difficulty.BOMB_SCORE
	_combat.push_callout("BOMB", _player.position + Vector2(-16, -20), Color("ffe56a"), 0.4)
	for enemy in _enemies:
		if not enemy.alive:
			continue
		enemy.hurt(Difficulty.BOMB_DAMAGE)
		if not enemy.alive:
			_award_kill(enemy, false)
			if not enemy is DragonEnemy:
				_spawn_fx("death_puff.png", enemy.position, 0.28, 0.4, 1.2)

func _overdrive_blast() -> void:
	_clear_enemy_shots()
	score += Difficulty.OVERDRIVE_SCORE
	_overdrive_flash = 0.32
	_clear_banner_fx()
	_combat.push_callout("OVERDRIVE", _player.position + Vector2(-32, -24), Color("ffe56a"), 0.45)
	_spawn_fx("evolved_burst.png", _player.position + Vector2(40, -8), 0.45, 0.6, 1.4)
	_request_hit_stop(4)
	_bump_shake()
	for enemy in _enemies:
		if not enemy.alive:
			continue
		enemy.hurt(99)
		if not enemy.alive:
			_award_kill(enemy, false)

func _charge_winner() -> void:
	winner += 1
	if winner < FormCatalog.vending_winner_kills(rank_index):
		return
	winner = 0
	_winner_clear()

## The only WINNER! in the game. Kills and gems fill it. Coins and powerups do not.
## Flying enemy shots and pending pattern shots (the rake windup included)
## are cleared. A survivor can still loose a telegraph it already started.
## Kills score and drop loot like any other kill. _winner_busy keeps them
## from refilling this meter. There is no bonus score.
func _winner_clear() -> void:
	if _winner_busy:
		return
	_winner_busy = true
	winner_pops += 1
	_clear_enemy_shots()
	_overdrive_flash = 0.28
	_clear_banner_fx()
	_combat.push_callout("WINNER!", _player.position + Vector2(-28, -28), Color("ffe56a"), 0.5)
	var field := _viewport_size()
	_spawn_fx("winner_burst.png", field * 0.5, 0.55, 1.2, 2.4)
	_request_hit_stop(4)
	_bump_shake()
	var blast := FormCatalog.vending_winner_damage(rank_index)
	for enemy in _enemies:
		if not enemy.alive:
			continue
		if enemy.is_boss():
			# The entrance is the only invulnerable window. The knight's shield does not stop this.
			if enemy.intro_left > 0.0:
				continue
			var before := enemy.hp
			enemy.hurt(BossCatalog.winner_damage(enemy.max_hp))
			var dealt := before - enemy.hp
			if dealt > 0:
				_spawn_fx("hit_flash.png", enemy.position, 0.32, 1.5, 2.6)
				if _combat != null:
					_combat.push_callout("-%d" % dealt, enemy.position + Vector2(-18, -40), Color("ffe56a"), 0.7, 2)
			if not enemy.alive:
				_award_kill(enemy, true)
				if not enemy is DragonEnemy:
					_spawn_fx("death_puff.png", enemy.position, 0.22, 0.35, 1.1)
			continue
		enemy.hurt(blast)
		if not enemy.alive:
			_award_kill(enemy, true)
			if not enemy is DragonEnemy:
				_spawn_fx("death_puff.png", enemy.position, 0.22, 0.35, 1.1)
	_winner_busy = false

func _guide_orbs(delta: float) -> void:
	var foes: Array[EnemyActor] = []
	for enemy in _enemies:
		if enemy.alive:
			foes.append(enemy)
	if foes.is_empty():
		return
	for shot in _shots:
		if not is_instance_valid(shot) or shot.homing <= 0.0 or not shot.from_player:
			continue
		var best: EnemyActor = null
		var best_d := 99999999.0
		for enemy in foes:
			var dist := shot.position.distance_squared_to(enemy.position)
			if dist < best_d:
				best_d = dist
				best = enemy
		if best == null:
			continue
		var cruise := shot.cruise if shot.cruise > 1.0 else shot.velocity.length()
		var desired := best.position - shot.position
		if desired.length() < 1.0:
			continue
		shot.velocity = shot.velocity.move_toward(desired.normalized() * cruise, shot.homing * delta)

func _reflect_swipes() -> void:
	for swipe in _shots:
		if not is_instance_valid(swipe) or not swipe.from_player or str(swipe.style) != "swipe":
			continue
		for bullet in _shots:
			if bullet == swipe or not is_instance_valid(bullet) or bullet.from_player:
				continue
			var reach := FormCatalog.cat_reflect_reach(swipe.hit_scale)
			if swipe.position.distance_squared_to(bullet.position) > reach * reach:
				continue
			if not HitLibrary.overlaps(swipe.position, swipe.sprite_name, "body", bullet.position, bullet.sprite_name, "threat", swipe.hit_scale):
				continue
			_reflect_bullet(bullet)

func _reflect_bullet(bullet: Shot) -> void:
	var speed := maxf(bullet.velocity.length(), 220.0)
	var dir := Vector2(1, 0)
	if bullet.velocity.length() > 1.0:
		dir = Vector2(-bullet.velocity.x, -bullet.velocity.y * 0.35)
		if dir.length() < 0.01:
			dir = Vector2(1, 0)
		else:
			dir = dir.normalized()
		if dir.x < 0.35:
			dir.x = 0.35
			dir = dir.normalized()
	bullet.velocity = dir * speed
	bullet.from_player = true
	bullet.sprite_name = "reflected_bullet.png"
	bullet.damage = 2
	bullet.pierce = 0
	bullet.radius = HitLibrary.bounds_radius("reflected_bullet.png", "body")
	bullet.style = "blob"
	bullet.killer_name = ""
	bullet.homing = 0.0
	bullet.expires = false
	bullet.z_index = 3
	bullet.grazed = true
	bullet.hit_ids.clear()

func _crowd_size() -> int:
	var count := 0
	for enemy in _enemies:
		if enemy.alive:
			count += 1
	return count

func _clear_enemy_shots() -> void:
	var write := 0
	for shot in _shots:
		if not is_instance_valid(shot) or not shot.from_player:
			_release_shot(shot)
			continue
		_shots[write] = shot
		write += 1
	_shots.resize(write)
	pattern_shots.clear()

func _tick_patterns(delta: float, size: Vector2) -> void:
	if _player == null:
		return
	if phase == PHASE_PLAY and elapsed + 0.00001 >= _next_rake:
		# The lesson keeps the rake clock moving so the wall does not land in a pile at 10s.
		if not _tutorial_active:
			_spawn_rake(size)
		_next_rake = elapsed + Difficulty.rake_every(elapsed)
	var write := 0
	for item in pattern_shots:
		var left := float(item["left"]) - delta
		if left <= 0.0:
			var pos: Vector2 = item["pos"]
			var vel: Vector2 = item["vel"]
			_spawn_shot({
				"position": pos,
				"velocity": vel,
				"sprite": str(item["sprite"]),
				"radius": 5.0,
				"damage": 1,
				"killer_name": str(item.get("killer", "rake")),
				"color": Color("f0d78c"),
			}, false)
			continue
		item["left"] = left
		pattern_shots[write] = item
		write += 1
	pattern_shots.resize(write)
	if _pattern_layer != null:
		_pattern_layer.queue_redraw()

func _spawn_rake(size: Vector2) -> void:
	var hurt_h := HitLibrary.vertical_extent(_player.sprite_name(), "hurt")
	var plan := Difficulty.build_rake(elapsed, _player.position.y, hurt_h)
	var speed := float(plan["speed"])
	var windup := Difficulty.telegraph_for(speed)
	for y in plan["ys"]:
		pattern_shots.append({
			"pos": Vector2(size.x + 18.0, float(y)),
			"vel": Vector2(-speed, 0.0),
			"left": windup,
			"sprite": Difficulty.RAKE_BOLT,
		})

func _gain_skill(points: int) -> void:
	if points <= 0:
		return
	score += points
	_add_evo(points)

func _add_evo(points: int) -> void:
	if points <= 0:
		return
	evo_points += points
	_try_rank()
	_sync_power()

func _power_level() -> int:
	return Difficulty.power_level(evo_points)

func _sync_power() -> void:
	if _player == null:
		return
	var level := _power_level()
	var before := int(_player.power_level)
	_player.power_level = level
	# A latch at boot or a restore keeps the same level, so it stays silent.
	# One call that jumps several levels still plays once, at the level it landed on.
	if level > before and phase == PHASE_PLAY and _combat != null:
		_combat.push_callout("POWER +%d" % level, _player.position + Vector2(-28, -22), Color("ffe56a"), 0.36)
		if _sound != null:
			_sound.play_event("power_level_up", 0.0, AudioCues.power_level_pitch(level))

func _try_rank() -> void:
	if form_id == FormCatalog.Id.DRAGON:
		_refresh_hud()
		_refresh_debug()
		return
	var reached := FormCatalog.rank_for_points(evo_points)
	if reached > rank_index:
		var gate_count := FormCatalog.rank_gates().size()
		var final := reached >= gate_count
		var old_sprite := _player.sprite_name()
		rank_index = reached
		_player.set_rank(rank_index)
		_player.begin_evolve(old_sprite, _player.sprite_name(), final)
		_final_evolve = final
		if final:
			_slow_left = Difficulty.FINAL_SLOWMO_SECONDS
			_shake_left = Difficulty.FINAL_SHAKE_SECONDS
			_final_flash = Difficulty.FINAL_FLASH
		_request_hit_stop(4 if final else 3)
		_bump_shake()
		# Rank 5 is the FINAL FORM banner, not another EVOLVED! on the pile.
		# Rank 4 keeps a smaller pop. Earlier ranks keep the normal one.
		if not final:
			var pop_at := 5.0 / FxTimeline.FPS
			var pop_scale := 0.62 if reached == 3 else 1.0
			_clear_banner_fx()
			_queue_chain(pop_at, "evolved_burst.png", Vector2(0, -28), "", pop_scale)
		if _sound != null:
			_sound.play_event("evolve", Difficulty.FINAL_STING_DB if final else 0.0)
	_refresh_hud()
	_refresh_debug()

func _kill_player(name: String) -> void:
	if phase != PHASE_PLAY:
		return
	killer_name = name
	phase = PHASE_DEAD
	_paused = false
	_death_audio_stage = ""
	if _world_flash != null:
		_world_flash.visible = false
		_world_flash_left = 0.0
	if _sound != null:
		_sound.set_music_paused(false)
		_sound.end_dragon_bed()
	if _pause_overlay != null:
		_pause_overlay.visible = false
	if _pause_button != null:
		_pause_button.visible = false
	if _sound_button != null:
		_sound_button.visible = false
	if _audio_blocked_button != null:
		_audio_blocked_button.visible = false
	_player.alive = false
	_player.visible = false
	_hint_label.visible = false
	_died_in_play = true
	if _death_fx != null:
		_death_fx.start(_player.position, _player.sprite_name())
	_present_death()
	_refresh_hud()

func _present_death() -> void:
	var stage := FxTimeline.death_stage(death_elapsed)
	if _sound != null:
		for cue in AudioCues.cues_for_death_transition(_death_audio_stage, stage):
			_sound.play_event(cue)
	_death_audio_stage = stage
	if _death_fx != null:
		_death_fx.elapsed = death_elapsed
		_death_fx.visible = stage == "hit" or stage == "pop" or stage == "puff" or stage == "hold"
		_death_fx.queue_redraw()
	if _tease != null:
		_tease.visible = stage == "tease" and not game_over_visible
	if stage == "card" and not game_over_visible:
		if CaptureMode.continue_after_death(self):
			return
		_show_game_over()

func _show_game_over() -> void:
	if game_over_visible:
		return
	game_over_visible = true
	_card_age = 0.0
	if _sound != null:
		_sound.stop_event("reborn_tease")
	if _tease != null:
		_tease.visible = false
	if _death_fx != null:
		_death_fx.visible = false
	var form_name := FormCatalog.display_name(form_id)
	var reached_rank := FormCatalog.rank_name(form_id, rank_index)
	_set_default_death(form_name, reached_rank)
	_layout_death_card()
	_game_over.visible = true
	_present_online_score()

func _set_default_death(form_name: String, reached_rank: String) -> void:
	var prior := BestScores.read()
	var old_form := int(prior.get(form_name, 0))
	var old_all := int(prior.get("overall", 0))
	var saved := CaptureMode.record_score(form_name, score)
	var beaten := score > 0 and (score > old_form or score > old_all)
	_new_best = beaten
	if _score_label != null:
		_score_label.text = ScoreRules.format_score(score)
		_score_label.visible = true
	if _new_best_label != null:
		_new_best_label.text = "NEW BEST!" if beaten else ""
		_new_best_label.visible = beaten
		_new_best_label.scale = Vector2(0.72, 0.72) if beaten else Vector2.ONE
	_best_label.text = "%s BEST %s\nDAILY BEST %s" % [
		form_name,
		ScoreRules.format_score(int(saved["form"])),
		ScoreRules.format_score(int(saved["overall"])),
	]
	_share_label.text = "Reached %s" % reached_rank.to_upper()
	_seed_label.text = _seed_line()
	if _beat_button != null:
		_beat_button.visible = true
		_beat_button.text = CHALLENGE_LABEL
		_style_challenge(false)
	if beaten and _sound != null:
		_sound.play_event("enemy_killed")

## Pin Reincarnate inside the field. Long rank names wrap, then shrink, so the
## button is never pushed past the bottom of the 480x270 viewport.
func _layout_death_card() -> void:
	if _restart_button == null or _share_label == null:
		return
	var field := _viewport_size()
	var margin := 10.0
	var share_w := 112.0
	var gap := 8.0
	var reinc_w := minf(252.0, field.x - 16.0 - share_w - gap)
	reinc_w = maxf(reinc_w, minf(220.0, field.x - 16.0))
	var button_h := 56.0
	var row_w := share_w + gap + reinc_w
	if row_w > field.x - 8.0:
		share_w = 96.0
		reinc_w = minf(220.0, field.x - 16.0 - share_w - gap)
		row_w = share_w + gap + reinc_w
	var row_x := (field.x - row_w) * 0.5
	var button_pos := Vector2(row_x + share_w + gap, field.y - margin - button_h)
	_place_death_control(_restart_button, button_pos, Vector2(reinc_w, button_h))
	if _share_button != null:
		_place_death_control(_share_button, Vector2(row_x, button_pos.y), Vector2(share_w, button_h))
	# Challenge sits above the retry row. Shorter and narrower than Reincarnate,
	# and a different color, so the gold button stays the retry target.
	# Leaderboard shares that row, on the left, in a smaller face.
	var challenge := _beat_button != null and _beat_button.visible
	var challenge_h := 44.0 if challenge else 0.0
	var challenge_gap := 6.0 if challenge else 0.0
	if challenge:
		var challenge_w := minf(240.0, reinc_w - 8.0)
		if challenge_w < 160.0:
			challenge_w = minf(240.0, field.x - 16.0)
		var show_board := _board_button != null and _board_button.visible
		var board_w := 120.0 if show_board else 0.0
		var pair_gap := 8.0 if show_board else 0.0
		var pair := board_w + pair_gap + challenge_w
		if show_board and pair > field.x - 12.0:
			board_w = maxf(96.0, field.x - 12.0 - pair_gap - challenge_w)
			pair = board_w + pair_gap + challenge_w
		var pair_x := (field.x - pair) * 0.5
		var challenge_y := button_pos.y - challenge_gap - challenge_h
		if show_board:
			_place_death_control(_board_button, Vector2(pair_x, challenge_y), Vector2(board_w, challenge_h))
			_place_death_control(_beat_button, Vector2(pair_x + board_w + pair_gap, challenge_y), Vector2(challenge_w, challenge_h))
		else:
			_place_death_control(_beat_button, Vector2(pair_x, challenge_y), Vector2(challenge_w, challenge_h))
		var label_px := 18 if challenge_w >= 224.0 else 9
		_beat_button.add_theme_font_size_override("font_size", label_px)
	elif _board_button != null and _board_button.visible:
		var lone_w := minf(200.0, field.x - 16.0)
		var lone_y := button_pos.y - 6.0 - 44.0
		_place_death_control(_board_button, Vector2((field.x - lone_w) * 0.5, lone_y), Vector2(lone_w, 44.0))
		challenge_h = 44.0
		challenge_gap = 6.0
	var text_width := minf(448.0, field.x - 16.0)
	var text_left := (field.x - text_width) * 0.5
	var text_top := 6.0
	var text_bottom := button_pos.y - challenge_gap - challenge_h - 6.0
	var text_height := maxf(text_bottom - text_top, 48.0)
	var kicker_h := 14.0
	var seed_h := 14.0
	var text_gap := 3.0
	var score_h := 0.0
	if _score_label != null and _score_label.visible and not _score_label.text.is_empty():
		_fit_wrapped_label(_score_label, text_width, 34.0, 27, 18)
		score_h = _wrapped_height(_score_label.text, text_width, _death_font_size(_score_label))
	var new_h := 0.0
	if _new_best_label != null and _new_best_label.visible and not _new_best_label.text.is_empty():
		_fit_wrapped_label(_new_best_label, text_width, 22.0, 18, 9)
		new_h = _wrapped_height(_new_best_label.text, text_width, _death_font_size(_new_best_label))
	var rank_h := 0.0
	if _rank_label != null and _rank_label.visible and not _rank_label.text.is_empty():
		_fit_wrapped_label(_rank_label, text_width, 28.0, 9, 9)
		rank_h = _wrapped_height(_rank_label.text, text_width, _death_font_size(_rank_label))
	var chrome := kicker_h + seed_h + score_h + new_h + rank_h
	var gap_count := 3.0
	if score_h > 0.0:
		gap_count += 1.0
	if new_h > 0.0:
		gap_count += 1.0
	if rank_h > 0.0:
		gap_count += 1.0
	var room := maxf(text_height - chrome - text_gap * gap_count, 24.0)
	# A rank line takes a row. The score stays the largest line, a step smaller.
	var score_cap := 22.0 if rank_h > 0.0 else 34.0
	var score_start := 18 if rank_h > 0.0 else 27
	if _score_label != null and score_h > 0.0:
		_fit_wrapped_label(_score_label, text_width, score_cap, score_start, 9)
		score_h = _wrapped_height(_score_label.text, text_width, _death_font_size(_score_label))
		chrome = kicker_h + seed_h + score_h + new_h + rank_h
		room = maxf(text_height - chrome - text_gap * gap_count, 24.0)
	_fit_wrapped_label(_share_label, text_width, room * 0.4, 18, 9)
	_fit_wrapped_label(_best_label, text_width, room * 0.6, 18, 9)
	var share_h := _wrapped_height(_share_label.text, text_width, _death_font_size(_share_label))
	var best_h := _wrapped_height(_best_label.text, text_width, _death_font_size(_best_label))
	var used := chrome + share_h + best_h + text_gap * gap_count
	var y := text_top + maxf(text_height - used, 0.0) * 0.35
	_place_death_control(_death_kicker, Vector2(text_left, y), Vector2(text_width, kicker_h))
	y += kicker_h + text_gap
	if score_h > 0.0:
		_place_death_control(_score_label, Vector2(text_left, y), Vector2(text_width, score_h))
		y += score_h + text_gap
	if new_h > 0.0:
		_place_death_control(_new_best_label, Vector2(text_left, y), Vector2(text_width, new_h))
		_new_best_label.pivot_offset = Vector2(text_width * 0.5, new_h * 0.5)
		y += new_h + text_gap
	_place_death_control(_share_label, Vector2(text_left, y), Vector2(text_width, share_h))
	y += share_h + text_gap
	_place_death_control(_best_label, Vector2(text_left, y), Vector2(text_width, best_h))
	y += best_h + text_gap
	if rank_h > 0.0:
		_place_death_control(_rank_label, Vector2(text_left, y), Vector2(text_width, rank_h))
		y += rank_h + text_gap
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
	var enemy_write := 0
	for enemy in _enemies:
		var gone := not is_instance_valid(enemy) or not enemy.alive or not field.has_point(enemy.position)
		if gone:
			if is_instance_valid(enemy):
				if enemy is DragonEnemy:
					(enemy as DragonEnemy).detach()
				enemy.queue_free()
			continue
		_enemies[enemy_write] = enemy
		enemy_write += 1
	_enemies.resize(enemy_write)
	var shot_write := 0
	var wide := field.grow(20)
	for shot in _shots:
		if not is_instance_valid(shot) or _shot_left_play(shot, size, wide):
			_release_shot(shot)
			continue
		_shots[shot_write] = shot
		shot_write += 1
	_shots.resize(shot_write)

func _shot_left_play(shot: Shot, size: Vector2, wide: Rect2) -> bool:
	if shot.exit_right and _swipe_clear_of_right(shot, size.x):
		return true
	if not wide.has_point(shot.position):
		return true
	return shot.expires and shot.life <= 0.0

## True when the drawn sprite and the hit shape are both past the right edge.
func _swipe_clear_of_right(shot: Shot, width: float) -> bool:
	var scale := shot.hit_scale
	var art_left := -ArtLibrary.anchor(shot.sprite_name).x * scale
	var hit_left := HitLibrary.horizontal_span(shot.sprite_name, "body").x * scale
	return shot.position.x + minf(art_left, hit_left) >= width

func _drop_shot(shot: Shot) -> void:
	_shots.erase(shot)
	_release_shot(shot)

func _release_shot(shot: Shot) -> void:
	if not is_instance_valid(shot):
		return
	shot.visible = false
	shot.hit_ids.clear()
	_shot_pool.append(shot)

func _bank_survival(delta: float) -> void:
	survival_bank += delta
	while survival_bank >= 1.0:
		survival_bank -= 1.0
		score += ScoreRules.SURVIVAL_PER_SECOND

func _build_invuln_banner() -> void:
	if CaptureMode.invuln_notice_text() == "":
		return
	_invuln_banner = _make_label(9, INVULN_BANNER_COLOR)
	_invuln_banner.name = "InvulnBanner"
	_invuln_banner.modulate = Color(1, 1, 1, 0.82)
	_invuln_banner.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_invuln_banner.autowrap_mode = TextServer.AUTOWRAP_OFF
	_invuln_banner.clip_text = false
	_invuln_banner.size = Vector2(220, 14)
	_invuln_banner.custom_minimum_size = Vector2(220, 14)
	_hud.add_child(_invuln_banner)
	_sync_invuln_banner()

func _sync_invuln_banner() -> void:
	if _invuln_banner == null:
		return
	_invuln_banner.text = CaptureMode.invuln_notice_text()
	_invuln_banner.visible = CaptureMode.invuln_notice_visible()
	_invuln_banner.position = _invuln_banner_origin()

## Top-left, just under the rank line, and lower when a power row is showing.
func _invuln_banner_origin() -> Vector2:
	var y := 68.0
	if _hud_view == null:
		return Vector2(6, y)
	if _hud_view.shield_on or _hud_view.rapid_s > 0 or _hud_view.magnet_s > 0 or _hud_view.overdrive_px >= 0:
		y = 84.0
	if _hud_view.winner_px >= 0:
		y = 94.0
	if _hud_view.meteor_px >= 0:
		y = 114.0
	return Vector2(6, y)

func _refresh_debug() -> void:
	if _debug_label == null:
		return
	if CaptureMode.hides_overlay():
		_debug_on = false
		HitLibrary.show = false
	_debug_label.visible = _debug_on
	if not _debug_on:
		return
	_debug_label.text = "t %.1fs\nspawn %.2fs\nspd x%.2f" % [
		elapsed,
		Difficulty.spawn_interval(elapsed),
		Difficulty.speed_scale(elapsed),
	]

func _apply_shake(delta: float) -> void:
	var mag := 0.0
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		mag = maxf(mag, Difficulty.FINAL_SHAKE_PX * clampf(_shake_left / Difficulty.FINAL_SHAKE_SECONDS, 0.0, 1.0))
	if _juice_shake > 0.0:
		_juice_shake = maxf(_juice_shake - delta, 0.0)
		mag = maxf(mag, Replay.JUICE_SHAKE_PX * clampf(_juice_shake / Replay.JUICE_SHAKE_SECONDS, 0.0, 1.0))
	var cap := Replay.shake_cap()
	if _meteor_shake_left > 0.0:
		_meteor_shake_left = maxf(_meteor_shake_left - delta, 0.0)
		mag = maxf(mag, _meteor_shake_mag)
		cap = maxf(cap, _meteor_shake_mag)
	# The everyday cap stays at 2px so a bullet cannot leave the eye.
	# Meteor Rain may shake a little harder, and only while it is running.
	mag = minf(mag, cap)
	if mag <= 0.05:
		if position != Vector2.ZERO:
			position = Vector2.ZERO
		return
	position = Vector2(
		round(_shake_rng.randf_range(-mag, mag)),
		round(_shake_rng.randf_range(-mag, mag))
	)

func _refresh_hud() -> void:
	if _hud_view == null:
		return
	var fill := HudLayout.fill_px(evo_points, rank_index)
	var winner_px := -1
	if form_id == FormCatalog.Id.VENDING:
		var need := float(FormCatalog.vending_winner_kills(rank_index))
		winner_px = int(round(float(HudLayout.FILL_FULL) * clampf(float(winner) / need, 0.0, 1.0)))
	var meteor_px := -1
	var meteor_ready := false
	if form_id == FormCatalog.Id.DRAGON:
		var need_m := float(FormCatalog.DRAGON_METEOR_KILLS)
		meteor_px = int(round(18.0 * clampf(float(_meteor_kills) / need_m, 0.0, 1.0)))
		meteor_ready = _meteor_kills >= FormCatalog.DRAGON_METEOR_KILLS or (_dragon_show != null and _dragon_show.phase == DragonShow.CHARGE)
	var rank_label := FormCatalog.rank_name(form_id, rank_index).to_upper()
	var level := _power_level()
	if level > 0:
		rank_label += " +%d" % level
	_hud_view.set_run(
		ScoreRules.format_score(score),
		ScoreRules.format_time(elapsed),
		loot_count,
		rank_label,
		rank_index,
		fill,
		form_id == FormCatalog.Id.GOBLIN,
		_player != null and _player.shield_hits > 0,
		int(ceil(rapid_left)) if rapid_left > 0.0 else 0,
		int(ceil(magnet_left)) if magnet_left > 0.0 else 0,
		-1,
		winner_px,
		meteor_px,
		meteor_ready
	)

func share_run() -> Dictionary:
	return {
		"form": ShareCard.form_key(_public_form()),
		"rank_reached": rank_index + 1,
		"time": ScoreRules.format_time(elapsed),
		"score": score,
		"killer": ShareCard.killer_id(killer_name),
	}

func _on_share() -> void:
	var run := share_run()
	var image := ShareCard.render(run)
	var text := ScoreRules.share_line(
		str(ShareCard.resolve(run)["form_name"]),
		str(ShareCard.resolve(run)["rank_name"]),
		elapsed,
		killer_name,
		score
	)
	if OS.has_feature("web"):
		var encoded := Marshalls.raw_to_base64(image.save_png_to_buffer())
		var call := "shareRunCard(%s,%s,%s)" % [
			JSON.stringify(encoded),
			JSON.stringify("reincarnated.png"),
			JSON.stringify(text),
		]
		JavaScriptBridge.eval(call, true)
		return
	var path := "user://reincarnated.png"
	image.save_png(path)
	print("Saved share card to %s" % ProjectSettings.globalize_path(path))

func _on_restart() -> void:
	_force_close_board()
	_dismiss_name_prompt()
	if CaptureMode.is_active():
		# A challenged form sticks for that one run; the retry rolls, and
		# does not repeat the form you died as.
		CaptureMode.note_player_retry(form_id)
		get_tree().reload_current_scene()
		return
	if phase != PHASE_DEAD or not game_over_visible:
		return
	if _card_age < Replay.CARD_GUARD:
		return
	_reincarnate()

## Kaito has no middle dot, so the seed line uses a hyphen.
func _seed_line() -> String:
	return "UTC seed %d - run %d" % [day_seed, run_index + 1]

func _on_beat_link() -> void:
	_copy_text(Replay.beat_url_for(day_seed, _public_form()))
	_flash_copy()

func _copy_text(text: String) -> void:
	print(text)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.shareRunText) shareRunText(%s);" % JSON.stringify(text), true)
		return
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.clipboard_set(text)

func _style_challenge(copied: bool) -> void:
	if _beat_button == null:
		return
	var bg := Color("145c32") if copied else Color("14324f")
	var edge := Color("b6ffb0") if copied else Color("8ecbff")
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := _beat_button.get_theme_stylebox(state) as StyleBoxFlat
		if style == null:
			continue
		style.bg_color = bg
		style.border_color = edge

func _flash_copy() -> void:
	_copy_left = COPY_FEEDBACK
	if _beat_button == null:
		return
	_beat_button.text = CHALLENGE_COPIED
	_style_challenge(true)

func _tick_copy_flash(delta: float) -> void:
	if _copy_left <= 0.0:
		return
	_copy_left = maxf(_copy_left - delta, 0.0)
	if _copy_left > 0.0:
		return
	if _beat_button != null and _beat_button.text == CHALLENGE_COPIED:
		_beat_button.text = CHALLENGE_LABEL
		_style_challenge(false)

func _tick_new_best_pop() -> void:
	if _new_best_label == null or not _new_best_label.visible:
		return
	var u := clampf(_card_age / 0.22, 0.0, 1.0)
	var pop := lerpf(0.72, 1.0, 1.0 - pow(1.0 - u, 3.0))
	_new_best_label.scale = Vector2(pop, pop)

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
	_layout_pause_card(viewport)
	var show := phase == PHASE_PLAY or _paused
	_pause_button.visible = show
	if _pause_overlay != null:
		_pause_overlay.visible = _paused
	if _sound_button != null:
		var gap := 2.0
		var sound_pos := Vector2(button_pos.x, button_pos.y + hit + gap)
		if sound_pos.y + hit > viewport.y:
			sound_pos.y = maxf(viewport.y - hit, 0.0)
		_sound_button.position = sound_pos
		_sound_button.size = control_size
		_sound_button.custom_minimum_size = control_size
		_sound_button.visible = phase == PHASE_REVEAL or phase == PHASE_PLAY or _paused
		if _audio_blocked_button != null:
			var blocked_pos := Vector2(sound_pos.x, sound_pos.y + hit + gap)
			if blocked_pos.y + hit > viewport.y:
				blocked_pos.y = maxf(viewport.y - hit, 0.0)
			_audio_blocked_button.position = blocked_pos
			_audio_blocked_button.size = control_size
			_audio_blocked_button.custom_minimum_size = control_size
			if _audio_blocked_icon != null:
				_audio_blocked_icon.position = icon_pos
				_audio_blocked_icon.size = art
				_audio_blocked_icon.custom_minimum_size = art
			var show_blocked := _sound != null and _sound.output_blocked
			show_blocked = show_blocked and (phase == PHASE_REVEAL or phase == PHASE_PLAY or _paused)
			_audio_blocked_button.visible = show_blocked

func _layout_pause_card(viewport: Vector2) -> void:
	if _pause_card == null:
		return
	# The pause glyph and the SND control share a column on the right.
	var reserved := 56.0
	if _pause_button != null:
		reserved = maxf(viewport.x - _pause_button.position.x + 8.0, 56.0)
	var margin := 8.0
	var width := clampf(viewport.x - margin - reserved, 160.0, 400.0)
	_pause_card.set_card_width(width)
	_refresh_pause_card()
	var height := _pause_card.get_combined_minimum_size().y
	var y := clampf((viewport.y - height) * 0.5, 66.0, maxf(viewport.y - height - 4.0, 66.0))
	_pause_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pause_card.position = Vector2(margin, y)
	_pause_card.size = Vector2(width, height)

func _refresh_pause_card() -> void:
	if _pause_card == null or _player == null:
		return
	var split_ready := form_id != FormCatalog.Id.SLIME or not _player.small
	_pause_card.show_form(form_id, rank_index, evo_points, split_ready)

func _layout_pause(viewport: Vector2) -> void:
	var window := DisplayServer.window_get_size()
	apply_pause_layout(viewport, Vector2(window), DisplayServer.screen_get_scale())

func _hits_pause(point: Vector2) -> bool:
	if _pause_button == null or not _pause_button.visible:
		return false
	return Rect2(_pause_button.position, _pause_button.size).has_point(point)

func _hits_sound(point: Vector2) -> bool:
	if _sound_button == null or not _sound_button.visible:
		return false
	return Rect2(_sound_button.position, _sound_button.size).has_point(point)

func _hits_audio_blocked(point: Vector2) -> bool:
	if _audio_blocked_button == null or not _audio_blocked_button.visible:
		return false
	return Rect2(_audio_blocked_button.position, _audio_blocked_button.size).has_point(point)

func _retry_web_audio() -> void:
	if _sound == null:
		return
	_sound.unlock_from_gesture()

func _toggle_pause() -> void:
	if phase != PHASE_PLAY and not _paused:
		return
	if _sound != null:
		_sound.unlock_from_gesture()
	_paused = not _paused
	_mouse_down = false
	_primary_touch = -1
	if _sound != null:
		_sound.set_music_paused(_paused)
	_layout_pause(_viewport_size())

func _toggle_sound() -> void:
	if _sound == null:
		return
	_sound.unlock_from_gesture()
	_sound.set_enabled(not _sound.enabled)
	_refresh_sound_button()

func _refresh_sound_button() -> void:
	if _sound_label == null or _sound == null:
		return
	var on := _sound.enabled
	_sound_label.text = "SND" if on else "OFF"
	var color := Color("f2fbff") if on else Color("8d88a8")
	_sound_label.add_theme_color_override("font_color", color)

func _overlaps(a: Vector2, a_radius: float, b: Vector2, b_radius: float) -> bool:
	var reach := a_radius + b_radius
	return a.distance_squared_to(b) <= reach * reach

func _player_scale() -> float:
	if _player != null:
		return _player.drawn_scale()
	return FormCatalog.play_scale(form_id)

func _public_form() -> int:
	if form_id == FormCatalog.Id.DRAGON:
		return _roster_form
	return form_id

func _begin_dragon_slay(points: int, at: Vector2) -> void:
	dragon_kills += 1
	if _dragon_show != null:
		_dragon_show.begin_slay(points, at)
	_begin_lair_transition()

func _charge_meteor() -> void:
	if _dragon_show != null and _dragon_show.phase != DragonShow.IDLE:
		return
	_meteor_kills += 1
	if _meteor_kills < FormCatalog.DRAGON_METEOR_KILLS:
		return
	_meteor_kills = 0
	# The player stays hittable. Meteor pictures sit under the ship and under bullets.
	if _dragon_show != null:
		_dragon_show.rng_seed = day_seed + dragon_kills * 17 + int(elapsed * 10.0)
		_dragon_show.start_rain()

func _dragon_slow(seconds: float) -> void:
	_slow_left = maxf(_slow_left, seconds)

func _dragon_shake(amount: float, seconds: float) -> void:
	_meteor_shake_mag = amount
	_meteor_shake_left = maxf(_meteor_shake_left, seconds)

func _dragon_clear_shots() -> void:
	_clear_enemy_shots()

func _dragon_clear_regulars() -> void:
	for enemy in _enemies:
		if enemy.alive and not enemy.is_boss():
			enemy.alive = false
	_clear_enemy_shots()

func _dragon_open_budget() -> int:
	var boss := _living_boss()
	if boss == null:
		_rain_budget = 0
		return 0
	_rain_budget = BossCatalog.winner_damage(boss.max_hp)
	return _rain_budget

func _dragon_chip(amount: int) -> void:
	if amount <= 0 or _rain_budget <= 0:
		return
	var pay := mini(amount, _rain_budget)
	var boss := _living_boss()
	if boss != null and boss.alive and boss.intro_left <= 0.0:
		var before := boss.hp
		boss.hurt(pay)
		var dealt := before - boss.hp
		_rain_budget = maxi(_rain_budget - maxi(dealt, pay), 0)
		if not boss.alive:
			_award_kill(boss, true)
	else:
		_rain_budget = maxi(_rain_budget - pay, 0)

func _dragon_splash(at: Vector2, radius: float) -> void:
	var reach := radius * radius
	for enemy in _enemies:
		if not enemy.alive or enemy.is_boss() or not enemy.can_be_hit():
			continue
		if enemy.position.distance_squared_to(at) <= reach:
			enemy.alive = false

func _dragon_jingle() -> void:
	if _sound != null:
		_sound.play_event("dragon_slain")

func _dragon_roar() -> void:
	if _sound != null:
		_sound.play_event("great_dragon_phase_roar")

func _dragon_cue(event: String) -> void:
	if _sound != null and event != "":
		_sound.play_event(event)

func _dragon_rain(on: bool) -> void:
	if _sound != null:
		_sound.set_meteor_mix(on)

func _adopt_dragon_form() -> void:
	if _player == null or form_id == FormCatalog.Id.DRAGON:
		return
	var old_file := _player.sprite_name()
	var old_scale := _player.drawn_scale()
	var fit := FormCatalog.dragon_fit_scale(old_file, old_scale)
	form_id = FormCatalog.Id.DRAGON
	_player.adopt_dragon(fit)
	_begin_dragon_phase()
	if _sound != null:
		_sound.play_event("dragon_transform")
		_sound.play_dragon_music()
	_spawn_fx("dragon_form/dragon_transform.png", _player.position, 9.0 / 15.0, 0.6, 1.5)

func dragon_phase_elapsed() -> float:
	if not _dragon_phase_on:
		return -1.0
	return maxf(elapsed - _dragon_phase_at, 0.0)

func _begin_dragon_phase() -> void:
	if _dragon_phase_on:
		return
	_dragon_phase_on = true
	_dragon_phase_at = elapsed
	_dragon_tier = 1
	_dragon_spawns = DragonSpawnDirector.new(day_seed)
	_dragon_spawns.begin(elapsed)

func _great_dragon_on_screen() -> bool:
	var living := _living_boss()
	return living != null and living.boss_slug == "great_dragon"

func _spawn_dragon_minions(living: EnemyActor, size: Vector2) -> void:
	_note_dragon_tier()
	if _dragon_spawns == null:
		return
	var paused := (living != null and living.boss_slug == "great_dragon") or _lair_blocks_spawns()
	var room := DragonPhase.MAX_ENEMIES - _alive_minion_count()
	for event in _dragon_spawns.pop_due(elapsed, paused):
		if room <= 0:
			continue
		if _spawn_enemy(event, size):
			room -= 1

func _note_dragon_tier() -> void:
	var tier := DragonPhase.tier_for(maxf(dragon_phase_elapsed(), 0.0))
	if tier <= _dragon_tier:
		return
	_dragon_tier = tier
	play_sfx_hook(DragonPhase.HOOK_TIER)
	if _combat != null:
		var field := _viewport_size()
		_combat.push_callout("TIER %d" % tier, Vector2(field.x * 0.5, 36.0), Color("ffb15a"), 0.9, 2)

func _lair_blocks_spawns() -> bool:
	return _lair != null and _lair.blocks_spawns()

func _begin_lair_transition() -> void:
	if _lair == null or _background == null:
		return
	if _background.world_id == WorldCatalog.DRAGON_LAIR and not _lair.running:
		return
	_lair.begin()
	if _sound != null:
		_sound.play_event("dragon_lair_transition")

func _finish_lair_swap() -> void:
	if _background == null or _lair == null:
		return
	var preview := _lair.preview_background()
	_background.apply_world(WorldCatalog.DRAGON_LAIR, false)
	_background.copy_scroll_from(preview)
	if _world_flash != null:
		_world_flash.visible = false
		_world_flash_left = 0.0

func _note_enemy_shot(spec: Dictionary) -> void:
	if _sound == null:
		return
	var sprite := str(spec.get("sprite", ""))
	if sprite == BossCatalog.BOSS_EMBER:
		_sound.play_event("great_dragon_ember_burst")
		return
	if sprite != BossCatalog.BOSS_METEOR:
		return
	var velocity: Vector2 = spec.get("velocity", Vector2.ZERO)
	var at: Vector2 = spec.get("position", Vector2.ZERO)
	var fall := FieldBackground.GROUND_FEET - at.y
	var delay := fall / maxf(velocity.y, 1.0)
	_sound.play_later("great_dragon_meteor_impact", clampf(delay, 0.05, 3.0))

func _sync_puddle_loop() -> void:
	if _sound == null:
		return
	var live := false
	for shot in _shots:
		if is_instance_valid(shot) and shot.sprite_name == DragonPhase.PUDDLE:
			live = true
			break
	if live:
		_sound.play_event("dragon_enemy_magma_puddle_sizzle_loop")
	else:
		_sound.stop_event("dragon_enemy_magma_puddle_sizzle_loop")

func _alive_minion_count() -> int:
	var count := 0
	for enemy in _enemies:
		if enemy.alive and not enemy.is_boss():
			count += 1
	return count

func play_sfx_hook(cue: String, delay: float = 0.0) -> void:
	if cue == "" or _sound == null:
		return
	if delay > 0.0:
		_sound.play_later(cue, delay)
		return
	_sound.play_event(cue)

func _present_dragon_death(dragon: DragonEnemy) -> void:
	dragon.detach()
	var visual := dragon.death_visual()
	var file := str(visual.get("file", ""))
	if file != "":
		var offset: Vector2 = visual.get("offset", Vector2.ZERO)
		_play_sheet(file, dragon.position + offset)
	play_sfx_hook(str(visual.get("cue", "")))
	for spec in dragon.death_shots():
		_spawn_shot(spec, false)
	var gem: Dictionary = dragon.death_gem()
	if gem.is_empty():
		return
	_spawn_bonus_gem(gem["at"], str(gem["sprite"]), int(gem["bonus"]), float(gem["life"]))

func _spawn_bonus_gem(at: Vector2, sprite: String, bonus: int, life: float) -> void:
	var gem := _take_gem()
	gem.setup(sprite)
	gem.bonus_score = bonus
	gem.life = life
	gem.drift = Difficulty.GEM_DRIFT
	gem.age = 0.0
	gem.position = at
	gem.modulate = Color.WHITE
	gem.z_index = 7
	_loot.append(gem)

func _play_sheet(file_name: String, at: Vector2) -> void:
	if file_name == "" or not ArtLibrary.has_file(file_name):
		return
	var fx := SheetFx.new()
	fx.z_index = 8
	fx.setup(file_name, at)
	add_child(fx)
	_sheets.append(fx)

func _tick_sheets(delta: float) -> void:
	if _sheets.is_empty():
		return
	var write := 0
	for fx in _sheets:
		if is_instance_valid(fx) and fx.tick(delta):
			_sheets[write] = fx
			write += 1
			continue
		if is_instance_valid(fx):
			fx.queue_free()
	_sheets.resize(write)

func _splash_shot(shot: Shot, direct: EnemyActor) -> void:
	if shot.splash <= 0 or shot.splash_radius <= 0.0:
		return
	if _sound != null:
		_sound.play_event("dragon_form_fireball_explode")
	_spawn_fx("dragon_form/dragon_explosion.png", shot.position, 7.0 / 15.0, 0.5, 1.2)
	var reach := shot.splash_radius * shot.splash_radius
	for enemy in _enemies:
		if enemy == direct or not enemy.alive or enemy.is_boss() or not enemy.can_be_hit():
			continue
		if enemy.position.distance_squared_to(shot.position) > reach:
			continue
		enemy.hurt(shot.splash)
		if enemy is DragonEnemy and (enemy as DragonEnemy).consume_block():
			continue
		if not enemy.alive:
			_award_kill(enemy, true)

func _spawn_fx(file_name: String, at: Vector2, duration: float, from_scale: float, to_scale: float) -> void:
	if _effects.size() >= Difficulty.MAX_FX:
		return
	var fx: PixelEffect
	if _fx_pool.is_empty():
		fx = PixelEffect.new()
		fx.z_index = 7
		add_child(fx)
	else:
		fx = _fx_pool.pop_back() as PixelEffect
	fx.setup(file_name, at, duration, from_scale, to_scale)
	fx.visible = true
	_effects.append(fx)

func _tick_effects(delta: float) -> void:
	var write := 0
	for fx in _effects:
		if is_instance_valid(fx) and fx.tick(delta):
			_effects[write] = fx
			write += 1
			continue
		if is_instance_valid(fx):
			fx.visible = false
			_fx_pool.append(fx)
	_effects.resize(write)

func _prewarm() -> void:
	PixelFont.outlined_texture("FINAL FORM!", Color("ffe56a"))
	PixelFont.outlined_texture("OVERDRIVE", Color("ffe56a"))
	PixelFont.outlined_texture("POWER +1", Color("ffe56a"))
	PixelFont.outlined_texture("WINNER!", Color("ffe56a"))
	PixelFont.outlined_texture("NEW BEST!", Color("ffe56a"))
	PixelFont.outlined_texture("BOMB", Color("ffe56a"))
	PixelFont.outlined_texture("OD", Color("ffe56a"))
	for file_name in ["fx/fx_evolve_glow.png", "fx/fx_evolve_flash.png", "fx/fx_evolved_pop.png", "evolved_burst.png", "winner_burst.png", "graze_sparkle.png", "hit_flash.png", "anvil.png", "slime_shot.png", "ui/hud_coin_icon.png", "gem.png", "floating_eye_bolt.png", "arrow.png", "wyvern_shot.png", "vending_can.png", "cat_swipe.png", "reflected_bullet.png", "demon_orb_r1.png", "demon_orb_r2.png", "demon_orb_r3.png"]:
		ArtLibrary.texture(file_name)
	for rank in 3:
		for id in FormCatalog.IDS:
			var spec := FormCatalog.rank_spec(id, rank)
			ArtLibrary.texture("fx/forms/%s_flash.png" % str(spec["sprite"]).trim_suffix(".png"))
			ArtLibrary.texture("fx/forms/%s_rim.png" % str(spec["sprite"]).trim_suffix(".png"))

func _roll_world() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return WorldCatalog.roll(rng)

func _sync_world_flash() -> void:
	if _world_flash == null or _background == null:
		return
	_world_flash.text = WorldCatalog.flash_name(_background.world_id)
	_world_flash.visible = phase != PHASE_DEAD

func _present_reveal() -> void:
	if _form_flash == null or _skip_label == null:
		return
	_form_flash.visible = _short_reveal
	if _short_reveal:
		_form_flash.text = FormCatalog.display_name(form_id)
		_skip_label.text = "Tap"
	else:
		_skip_label.text = "Tap to skip" if reveal_elapsed > 0.35 else ""
	_sync_world_flash()

func _wants_tutorial() -> bool:
	if _short_reveal or CaptureMode.is_active():
		return false
	return not Replay.seen()

func _tick_tutorial(delta: float, size: Vector2) -> void:
	if _finger != null and _player != null:
		var show := elapsed >= 0.35 and elapsed < 3.1
		_finger.visible = show
		if show:
			_finger.position = _player.position + Vector2(18, 6)
			_finger.advance(delta)
	if not _tut_eye and elapsed >= 0.7:
		_tut_eye = true
		_spawn_enemy({
			"t": elapsed,
			"kind": SpawnDirector.EYE,
			"x_ratio": 0.08,
			"phase": 0.4,
			"stop_ratio": 0.2,
			"y_bias": 0.0,
			"wave_amp": 4.0,
			"hold_fire": true,
		}, size)
	if not _tut_gem and elapsed >= 3.6 and _player != null:
		_tut_gem = true
		var bounds := _play_bounds(size)
		var at := _player.position + Vector2(48, -28)
		at.x = clampf(at.x, bounds.position.x + 16.0, bounds.end.x - 16.0)
		at.y = clampf(at.y, bounds.position.y + 16.0, bounds.end.y - 16.0)
		_spawn_evo_gem(at)
	if not _tut_shot and elapsed >= 6.0 and _player != null:
		_tut_shot = true
		var from := Vector2(minf(_player.position.x + 168.0, size.x - 8.0), _player.position.y)
		pattern_shots.append({
			"pos": from,
			"vel": Vector2(-78.0, 0.0),
			"left": 0.42,
			"sprite": "floating_eye_bolt.png",
			"killer": "Floating Eye",
		})

func _finish_tutorial() -> void:
	_tutorial_active = false
	if _finger != null:
		_finger.visible = false

func _reincarnate() -> void:
	_silence_death()
	_lb_gen += 1
	_died_in_play = false
	_pending_score = {}
	_force_close_board()
	_dismiss_name_prompt()
	_clear_field()
	var died_as := _public_form()
	dragon_kills = 0
	_meteor_kills = 0
	_dragon_phase_on = false
	_dragon_phase_at = 0.0
	_dragon_spawns = null
	_dragon_tier = 0
	if _lair != null:
		_lair.cancel()
	if _sound != null:
		_sound.end_dragon_bed()
	_rain_budget = 0
	_meteor_shake_left = 0.0
	if _player != null:
		_player.fit_scale = 1.0
		_player.rear = 0.0
	run_index = DailyRun.consume_run_index()
	form_id = FormCatalog.id_for_run(day_seed, run_index)
	if form_id == died_as:
		form_id = FormCatalog.id_for_run_avoiding(day_seed, run_index, died_as)
	_roster_form = form_id
	score = 0
	combo = 0
	combo_left = 0.0
	survival_bank = 0.0
	elapsed = 0.0
	invuln = 0.0
	loot_count = 0
	evo_points = 0
	rank_index = 0
	overdrive = 0
	overdrive_spawned = 0
	_overdrive_lock = 0.0
	winner = 0
	_winner_busy = false
	rapid_left = 0.0
	magnet_left = 0.0
	power_spawned = 0
	_drop_seeded = false
	_final_evolve = false
	_slow_left = 0.0
	_shake_left = 0.0
	_juice_shake = 0.0
	_overdrive_flash = 0.0
	_final_flash = 0.0
	_hit_stop_frames = 0
	_hit_stop_cooldown = 0.0
	_next_rake = Difficulty.RAKE_FIRST
	_tutorial_active = false
	_tut_eye = false
	_tut_gem = false
	_tut_shot = false
	_new_best = false
	_copy_left = 0.0
	killer_name = "something"
	death_elapsed = 0.0
	_card_age = 0.0
	_death_audio_stage = ""
	game_over_visible = false
	_paused = false
	_primary_touch = -1
	_mouse_down = false
	position = Vector2.ZERO
	if _game_over != null:
		_game_over.visible = false
	if _tease != null:
		_tease.visible = false
	if _death_fx != null:
		_death_fx.visible = false
	if _pause_overlay != null:
		_pause_overlay.visible = false
	if _finger != null:
		_finger.visible = false
	var size := _viewport_size()
	_director = SpawnDirector.new(day_seed)
	_boss_director = BossDirector.new(day_seed)
	_boss_throttle = 0
	if _player != null:
		_player.respawn(form_id, Vector2(size.x * 0.28, size.y * 0.5))
	if _background != null:
		_background.apply_world(_roll_world())
	if _sound != null and _background != null:
		_sound.play_world_music(_background.world_id)
	if _title_card != null:
		_title_card.texture = ArtLibrary.texture(FormCatalog.title_card(form_id))
		_title_card.scale = Vector2(0.84, 0.84)
	_short_reveal = true
	reveal_elapsed = 0.0
	phase = PHASE_REVEAL
	if _reveal != null:
		_reveal.visible = true
	if _hint_label != null:
		_hint_label.visible = false
	_present_reveal()
	if _sound != null:
		_sound.play_title_card(FormCatalog.title_card(form_id))
	print("Reincarnated as %s in %s (seed %d, run %d)" % [FormCatalog.display_name(form_id), WorldCatalog.flash_name(_background.world_id), day_seed, run_index])
	if _pattern_layer != null:
		_pattern_layer.queue_redraw()
	_refresh_hud()
	_refresh_pause_card()

func _clear_field() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.visible = false
			enemy.alive = false
			enemy.queue_free()
	_enemies.clear()
	for fx in _sheets:
		if is_instance_valid(fx):
			fx.queue_free()
	_sheets.clear()
	for shot in _shots:
		_release_shot(shot)
	_shots.clear()
	for gem in _loot:
		_release_gem(gem)
	_loot.clear()
	for drop in _powers:
		_release_power(drop)
	_powers.clear()
	for fx in _effects:
		if is_instance_valid(fx):
			fx.visible = false
			_fx_pool.append(fx)
	_effects.clear()
	pattern_shots.clear()
	_chains.clear()
	next_enemy_id = 1

func _silence_death() -> void:
	if _sound == null:
		return
	_sound.stop_event("player_death")
	_sound.stop_event("reborn_tease")

func _request_hit_stop(frames: int) -> void:
	if _hit_stop_cooldown > 0.0:
		return
	_hit_stop_frames = clampi(frames, 2, 4)
	_hit_stop_cooldown = 0.2

func _bump_shake() -> void:
	_juice_shake = Replay.JUICE_SHAKE_SECONDS

func _note_boss_enrage(boss: EnemyActor) -> void:
	_bump_shake()
	_spawn_fx("hit_flash.png", boss.position, 0.28, 1.3, 2.2)
	if _combat != null:
		_combat.push_callout("ENRAGED", boss.position + Vector2(-28, -36), Color("ff6b6b"), 0.5)

func _queue_chain(delay: float, fx_file: String, offset: Vector2, text: String, scale: float = 1.0) -> void:
	_chains.append({
		"t": delay,
		"fx": fx_file,
		"off": offset,
		"text": text,
		"scale": scale,
	})

func _clear_banner_fx() -> void:
	var keep: Array[PixelEffect] = []
	for fx in _effects:
		if not is_instance_valid(fx):
			continue
		var name := str(fx.sprite_name)
		if name == "evolved_burst.png" or name == "winner_burst.png":
			fx.visible = false
			_fx_pool.append(fx)
			continue
		keep.append(fx)
	_effects = keep

func _tick_chains(delta: float) -> void:
	if _chains.is_empty() or _player == null:
		return
	var keep: Array[Dictionary] = []
	for item in _chains:
		var left := float(item["t"]) - delta
		if left > 0.0:
			item["t"] = left
			keep.append(item)
			continue
		var at: Vector2 = _player.position + item["off"]
		var fx_file := str(item["fx"])
		if not fx_file.is_empty():
			var scale := float(item.get("scale", 1.0))
			_spawn_fx(fx_file, at, 0.28, 0.75 * scale, 1.15 * scale)
		var text := str(item["text"])
		if not text.is_empty():
			_combat.push(text, at, Color("ffe56a"), 0.36)
	_chains = keep

func draw_boss_banner(canvas: CanvasItem) -> void:
	var boss := _living_boss()
	if boss == null:
		return
	var field := _viewport_size()
	var label := boss.kind_name.to_upper()
	if boss.boss_slug == "great_dragon" and boss.dragon_phase() == 2:
		label += " II"
	elif boss.boss_slug == "great_dragon" and boss.dragon_phase() >= 3:
		label += " III"
	if boss.boss_slug == "great_dragon" and boss is BossActor and (boss as BossActor).generation > 0:
		label += " R%d" % ((boss as BossActor).generation + 1)
	var fill := BossCatalog.banner_color(boss.boss_slug)
	var tex := PixelFont.outlined_texture(label, fill)
	var pen := Vector2((field.x - tex.get_width()) * 0.5, 1.0)
	canvas.draw_texture(tex, pen)
	var bar_w := 156.0
	var bar_h := 5.0
	var bar := Vector2((field.x - bar_w) * 0.5, 16.0)
	canvas.draw_rect(Rect2(bar + Vector2(-1, -1), Vector2(bar_w + 2.0, bar_h + 2.0)), Color(0, 0, 0, 0.88))
	canvas.draw_rect(Rect2(bar, Vector2(bar_w, bar_h)), Color(0.1, 0.07, 0.12, 0.95))
	var ratio := clampf(float(boss.hp) / float(maxi(boss.max_hp, 1)), 0.0, 1.0)
	if ratio > 0.0:
		canvas.draw_rect(Rect2(bar, Vector2(bar_w * ratio, bar_h)), fill)

class BossBanner extends Node2D:
	var host

	func _draw() -> void:
		if host == null:
			return
		host.draw_boss_banner(self)

class PatternLayer extends Node2D:
	var host

	func _draw() -> void:
		if host == null:
			return
		var rows: Array = host.pattern_shots
		var ink := Color(1.0, 0.84, 0.38, 0.9)
		for item in rows:
			var pos: Vector2 = item["pos"]
			var vel: Vector2 = item["vel"]
			if vel.length_squared() < 1.0:
				continue
			var dir := vel.normalized()
			draw_line(pos, pos + dir * 14.0, ink, 1.0)
			draw_arc(pos, 2.5, 0.0, TAU, 8, ink, 1.0, true)
		var field: Vector2 = host._viewport_size()
		var final_flash := float(host._final_flash)
		if final_flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, field), Color(1.0, 0.97, 0.86, clampf(final_flash * 1.35, 0.0, 0.72)))
		var flash := float(host._overdrive_flash)
		if flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, field), Color(1.0, 0.93, 0.62, clampf(flash * 1.4, 0.0, 0.55)))
		_draw_final_banner(field)

	func _draw_final_banner(field: Vector2) -> void:
		var player = host._player
		if player == null or not player.evolve_final or player.evolve_t < 0.0:
			return
		if FxTimeline.evolve_stage(player.evolve_t, player.evolve_hold) != "pop":
			return
		var tex := PixelFont.outlined_texture("FINAL FORM!", Color("ffe56a"))
		var size := tex.get_size() * 4.0
		var at := Vector2((field.x - size.x) * 0.5, 18.0)
		draw_texture_rect(tex, Rect2(at, size), false)

class SpeakerOffMark extends Control:
	func _draw() -> void:
		var ink := Color("f2fbff")
		var slash := Color("ff6b8a")
		draw_rect(Rect2(1, 6, 3, 6), ink)
		draw_rect(Rect2(4, 5, 2, 8), ink)
		draw_rect(Rect2(6, 4, 2, 10), ink)
		draw_rect(Rect2(8, 3, 2, 12), ink)
		for i in 12:
			draw_rect(Rect2(3 + i, 15 - i, 2, 2), slash)

func _exit_tree() -> void:
	_restore_board_viewport()
	if _name_prompt != null:
		_name_prompt.close()

func _layout_title_button(viewport: Vector2) -> void:
	if _title_board_button == null:
		return
	var width := 136.0
	var height := 44.0
	_title_board_button.position = Vector2(8, viewport.y - 6.0 - height)
	_title_board_button.size = Vector2(width, height)
	_title_board_button.custom_minimum_size = Vector2(width, height)

func _present_online_score() -> void:
	var post := Leaderboard.should_submit()
	if _board_button != null:
		_board_button.visible = post
	if _rank_label != null:
		_rank_label.visible = post
		if not post:
			_rank_label.text = ""
	_layout_death_card()
	if not post or _leaderboard == null:
		return
	if DisplayServer.get_name() == "headless" or not _died_in_play:
		return
	# This run only. A local best from before SCORE_EPOCH is already gone and is not posted.
	_pending_score = {
		"form": FormCatalog.key_for(_public_form()),
		"score": maxi(score, 0),
		"survival_ms": maxi(int(round(elapsed * 1000.0)), 0),
		"dragon_slayer": dragon_kills > 0,
	}
	_lb_gen += 1
	if _leaderboard.player_name() == "":
		_set_rank_text("Name this run to post it", Color("a49fcf"))
		_open_name_prompt("death")
		return
	_submit_pending()

func _open_name_prompt(source: String, ask := true) -> void:
	if _name_prompt == null or _leaderboard == null:
		return
	_name_prompt.place_for(_viewport_size())
	# Cover first. On the web export the prompt can finish before open() returns.
	_leaderboard.set_page_cover(true)
	_name_prompt.open(_leaderboard.player_name(), source, ask)

func _dismiss_name_prompt() -> void:
	if _name_prompt != null and _name_prompt.visible:
		_name_prompt.close()
	if _leaderboard != null and (_board == null or not _board.visible):
		_leaderboard.set_page_cover(false)

func _on_name_decided(clean: String, source: String) -> void:
	if _leaderboard == null:
		return
	var local_err := Leaderboard.local_name_error(clean)
	if local_err != "":
		_name_prompt.show_error(local_err)
		return
	if source == "board" and _board != null:
		_board.set_player_name(clean)
	if source == "board" and _leaderboard.has_posted():
		_name_prompt.close()
		_send_rename(clean)
		return
	_leaderboard.set_local_name(clean)
	_name_prompt.close()
	if _leaderboard != null and (_board == null or not _board.visible):
		_leaderboard.set_page_cover(false)
	if source == "board":
		return
	if source == "death" and not _pending_score.is_empty():
		_submit_pending()

func _on_name_cancelled() -> void:
	if _leaderboard != null and (_board == null or not _board.visible):
		_leaderboard.set_page_cover(false)
	if _name_prompt != null and _name_prompt.source == "death":
		_set_rank_text("Name this run to post it", Color("a49fcf"))

func _send_rename(clean: String) -> void:
	_rename_gen += 1
	var gen := _rename_gen
	_leaderboard.set_remote_name(clean, func(parsed: Dictionary) -> void:
		_on_renamed(parsed, clean, gen)
	)

func _on_renamed(parsed: Dictionary, attempted: String, gen: int) -> void:
	if _name_prompt == null or gen != _rename_gen:
		return
	var err := str(parsed.get("error", ""))
	if err == "rate_limited":
		if _leaderboard != null:
			_leaderboard.call_later(Leaderboard.RETRY_SECONDS, func() -> void:
				if _leaderboard != null and gen == _rename_gen and attempted != "":
					_leaderboard.set_remote_name(attempted, func(again: Dictionary) -> void:
						_on_renamed(again, attempted, gen)
					)
			)
		return
	if err == "name_not_allowed":
		_revert_board_name()
		_name_prompt.show_error(Leaderboard.REJECTED_NAME)
		return
	if err == "bad_name":
		_revert_board_name()
		_name_prompt.show_error(Leaderboard.FORMAT_HINT)
		return
	if err == "no_scores_yet":
		var kept := _leaderboard.set_local_name(attempted)
		_name_prompt.close()
		if _board != null:
			_board.set_player_name(kept)
		return
	if not bool(parsed.get("ok", false)):
		_revert_board_name()
		if Leaderboard.is_network_error(parsed):
			_name_prompt.show_error(Leaderboard.UNREACHABLE)
		else:
			var err_text := str(parsed.get("error", ""))
			_name_prompt.show_error(err_text if err_text != "" else Leaderboard.SCORE_NOT_POSTED)
		return
	var renamed := str(parsed.get("data", {}).get("name", attempted))
	_name_prompt.close()
	if _board != null:
		_board.set_player_name(renamed)
		if _board.visible:
			_board.open()

func _revert_board_name() -> void:
	if _board == null or _leaderboard == null:
		return
	_board.set_player_name(_leaderboard.player_name())

func _submit_pending() -> void:
	if _leaderboard == null or _pending_score.is_empty():
		return
	var local_err := Leaderboard.local_name_error(_leaderboard.player_name())
	if local_err != "":
		_open_name_prompt("death", false)
		_name_prompt.show_error(local_err)
		return
	if _name_prompt != null:
		_name_prompt.close()
	_set_rank_text("...", Color("a49fcf"))
	_send_submit(_lb_gen)

func _send_submit(gen: int) -> void:
	if _leaderboard == null or _pending_score.is_empty():
		return
	_leaderboard.submit_score(
		str(_pending_score.get("form", "")),
		int(_pending_score.get("score", 0)),
		int(_pending_score.get("survival_ms", 0)),
		func(parsed: Dictionary) -> void:
			_on_submit_parsed(parsed, gen),
		bool(_pending_score.get("dragon_slayer", false))
	)

func _on_submit_parsed(parsed: Dictionary, gen: int) -> void:
	if gen != _lb_gen:
		return
	var err := str(parsed.get("error", ""))
	if err == "rate_limited":
		if _leaderboard != null:
			_leaderboard.call_later(Leaderboard.RETRY_SECONDS, func() -> void:
				if gen == _lb_gen:
					_send_submit(gen)
			)
		return
	if err == "name_not_allowed":
		_open_name_prompt("death", false)
		_name_prompt.show_error(Leaderboard.REJECTED_NAME)
		_set_rank_text("", Color("8ecbff"))
		return
	if err == "bad_name":
		_open_name_prompt("death", false)
		_name_prompt.show_error(Leaderboard.FORMAT_HINT)
		_set_rank_text("", Color("8ecbff"))
		return
	if not bool(parsed.get("ok", false)):
		if Leaderboard.is_network_error(parsed):
			_rank_retry = "submit"
			_set_rank_text(Leaderboard.UNREACHABLE, Color("a49fcf"))
		else:
			_rank_retry = ""
			_set_rank_text(Leaderboard.SCORE_NOT_POSTED, Color("a49fcf"))
		return
	_fetch_ranks(str(_pending_score.get("form", "")), gen)

func _fetch_ranks(form: String, gen: int) -> void:
	if _leaderboard == null:
		return
	_rank_serial += 1
	var serial := _rank_serial
	_daily_rank = -1
	_all_rank = -1
	_rank_parts = 0
	_rank_network = 0
	_rank_form = form
	_leaderboard.fetch_rank(form, "daily", _on_rank_part.bind("daily", gen, serial))
	_leaderboard.fetch_rank(form, "all", _on_rank_part.bind("all", gen, serial))

var _daily_rank := -1
var _all_rank := -1
var _rank_parts := 0
var _rank_network := 0
var _rank_serial := 0
var _rank_retry := ""
var _rank_form := ""

func _on_rank_part(parsed: Dictionary, period: String, gen: int, serial: int) -> void:
	if gen != _lb_gen or serial != _rank_serial:
		return
	_rank_parts += 1
	if Leaderboard.is_network_error(parsed):
		_rank_network += 1
	else:
		var rows: Array = parsed.get("rows", [])
		if bool(parsed.get("ok", false)) and not rows.is_empty() and typeof(rows[0]) == TYPE_DICTIONARY:
			var rank := int((rows[0] as Dictionary).get("rank", 0))
			if period == "daily":
				_daily_rank = rank
			else:
				_all_rank = rank
	if _rank_parts < 2:
		return
	_rank_parts = 0
	var bits: PackedStringArray = []
	if _daily_rank > 0:
		bits.append("#%d today" % _daily_rank)
	if _all_rank > 0:
		bits.append("#%d all-time" % _all_rank)
	if not bits.is_empty():
		_rank_retry = ""
		_set_rank_text(" - ".join(bits), Color("8ecbff"))
		return
	if _rank_network > 0:
		_rank_retry = "ranks"
		_set_rank_text(Leaderboard.UNREACHABLE, Color("a49fcf"))
		return
	_rank_retry = ""
	_set_rank_text("", Color("8ecbff"))

func _on_rank_retry_input(event: InputEvent) -> void:
	if _rank_label == null or _rank_label.text != Leaderboard.UNREACHABLE or _rank_retry == "":
		return
	if not _is_pointer_press(event) or _is_emulated_mouse(event):
		return
	_rank_label.accept_event()
	var mode := _rank_retry
	_rank_retry = ""
	_set_rank_text("...", Color("a49fcf"))
	if mode == "submit":
		_send_submit(_lb_gen)
	else:
		_fetch_ranks(_rank_form, _lb_gen)

func _is_pointer_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

func _is_emulated_mouse(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION

func _set_rank_text(text: String, color: Color) -> void:
	if _rank_label == null:
		return
	_rank_label.text = text
	_rank_label.visible = text != "" or (_board_button != null and _board_button.visible and Leaderboard.should_submit())
	_rank_label.mouse_filter = Control.MOUSE_FILTER_STOP if text == Leaderboard.UNREACHABLE else Control.MOUSE_FILTER_IGNORE
	_rank_label.add_theme_color_override("font_color", color)
	if game_over_visible:
		_layout_death_card()

func _open_board() -> void:
	if _board == null or _leaderboard == null:
		return
	_apply_board_viewport()
	_board.open()
	_leaderboard.set_page_cover(true)
	if _title_board_button != null:
		_title_board_button.visible = false
	if _rotate != null:
		_rotate.visible = false

func _on_board_closed() -> void:
	_restore_board_viewport()
	call_deferred("_layout_after_board")

func _on_board_rename() -> void:
	_open_name_prompt("board")

func _force_close_board() -> void:
	if _board != null and _board.visible:
		_board.dismiss()
	_restore_board_viewport()

func _apply_board_viewport() -> void:
	if _leaderboard != null:
		_leaderboard.set_page_cover(true)
	if _board_scaled:
		return
	var win := DisplayServer.window_get_size()
	if win.x < 2 or win.y < 2 or win.y <= win.x:
		return
	var root := get_tree().root
	_saved_scale_mode = root.content_scale_mode
	_saved_scale_aspect = root.content_scale_aspect
	_saved_window_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	# Fill the phone. The game field stays 480x270 until this closes.
	root.size = win
	_board_scaled = true

func _restore_board_viewport() -> void:
	if _leaderboard != null and (_board == null or not _board.visible) and (_name_prompt == null or not _name_prompt.visible):
		_leaderboard.set_page_cover(false)
	if not _board_scaled:
		return
	var root := get_tree().root
	root.content_scale_mode = _saved_scale_mode as Window.ContentScaleMode
	root.content_scale_aspect = _saved_scale_aspect as Window.ContentScaleAspect
	if _saved_window_size != Vector2i.ZERO:
		root.size = _saved_window_size
	_board_scaled = false
	_saved_window_size = Vector2i.ZERO

func _layout_after_board() -> void:
	_layout_death_card()
	_layout_pause(_viewport_size())
	_layout_title_button(_viewport_size())
	if _title_board_button != null and (_board == null or not _board.visible):
		var covered := wants_rotate(_viewport_size())
		_title_board_button.visible = phase == PHASE_REVEAL and not covered

func _viewport_size() -> Vector2:
	if not is_inside_tree():
		return Vector2(480, 270)
	var size := get_viewport_rect().size
	if size.x < 32.0 or size.y < 32.0:
		return Vector2(480, 270)
	return size
