extends RefCounted
class_name CaptureMode

## On-demand recording flags. With none set, boot() is a no-op and the run
## matches a normal launch, including the daily-run write.
##
## Web: window.location.search. Desktop and headless: user args after --
## (`--form=slime`). When both are present the query string wins.

const DEFAULT_HAZARD_T := 6.0
const _PLAYABLE := ["slime", "goblin"]
const _UNPLAYABLE := ["vending_machine", "cat", "demon_lord"]
const _CARDS := {
	"vending_machine": "title_cards/title_vending_machine.png",
	"cat": "title_cards/title_cat.png",
	"demon_lord": "title_cards/title_demon_lord.png",
}
const _NAMES := {
	"vending_machine": "VENDING MACHINE",
	"cat": "CAT",
	"demon_lord": "DEMON LORD",
}

static var _parsed := false
static var _active := false
static var _form_key := ""
static var _has_seed := false
static var _seed_value := 0
static var _clean := false
static var _rank := 0
static var _evo := false
static var _hazard := ""
static var _hazard_t := DEFAULT_HAZARD_T
static var _invuln := false
static var _hitbox := false
static var _run_offset := 0
static var _hazard_spent := false
static var _spawn_at := -1.0
static var _piano_spawned := false
static var _piano_connected := false
static var _holding := false
static var _use_test := false
static var _test_web := ""
static var _test_argv: PackedStringArray = PackedStringArray()

static func is_active() -> bool:
	_ensure_parsed()
	return _active

static func title_card(form_id: int) -> String:
	_ensure_parsed()
	if _CARDS.has(_form_key):
		return str(_CARDS[_form_key])
	return FormCatalog.title_card(form_id)

static func announce_name(form_id: int) -> String:
	_ensure_parsed()
	if _NAMES.has(_form_key):
		return str(_NAMES[_form_key])
	return FormCatalog.display_name(form_id)

static func summary() -> String:
	_ensure_parsed()
	if not _active:
		return ""
	var parts: PackedStringArray = []
	if _form_key != "":
		parts.append("form=%s" % _form_key)
	if _has_seed:
		parts.append("seed=%d" % _seed_value)
	if _clean:
		parts.append("clean=1")
	if _rank > 0:
		parts.append("rank=%d" % _rank)
	if _evo:
		parts.append("evo=1")
	if _hazard != "":
		parts.append("hazard=%s" % _hazard)
		parts.append("hazard_t=%s" % _format_seconds(_hazard_t))
	if _invuln:
		parts.append("invuln=1")
	if _hitbox:
		parts.append("hitbox=1")
	return "Capture mode: %s" % " ".join(parts)

## Test hook. The exported game never calls this.
static func reset_for_test(argv: PackedStringArray, web: String = "") -> void:
	_reset_run_state()
	_parsed = false
	_active = false
	_form_key = ""
	_has_seed = false
	_seed_value = 0
	_clean = false
	_rank = 0
	_evo = false
	_hazard = ""
	_hazard_t = DEFAULT_HAZARD_T
	_invuln = false
	_hitbox = false
	_run_offset = 0
	_hazard_spent = false
	_use_test = true
	_test_web = web
	_test_argv = argv

static func boot(game: Node) -> void:
	_ensure_parsed()
	_piano_spawned = false
	_piano_connected = false
	_holding = false
	_spawn_at = -1.0
	if not _active:
		game.day_seed = DailyRun.date_seed()
		game.run_index = DailyRun.consume_run_index()
		game.form_id = FormCatalog.id_for_run(game.day_seed, game.run_index)
		return
	var seed := _seed_value if _has_seed else DailyRun.date_seed()
	var run := DailyRun.peek_run_index() + _run_offset
	var form := FormCatalog.id_for_run(seed, run)
	if _form_key == "slime":
		form = FormCatalog.Id.SLIME
	elif _form_key == "goblin":
		form = FormCatalog.Id.GOBLIN
	game.day_seed = seed
	game.run_index = run
	game.form_id = form

static func finish_boot(game: Node) -> void:
	if not _active:
		return
	if _rank > 0 and not _unplayable():
		var index := clampi(_rank - 1, 0, 2)
		var gates := FormCatalog.rank_gates()
		game.rank_index = index
		game.evo_points = 0 if index <= 0 or index - 1 >= gates.size() else int(gates[index - 1])
		game._player.rank_index = index
		game._player.evolve_flash = 0.0
		game._player._apply_radius()
		game._refresh_hud()
	if _clean:
		_force_clean(game)
	if _hazard == "piano" and not _hazard_spent and not _unplayable():
		_schedule_piano(game)

static func holding() -> bool:
	return _holding

## True when this reveal must not enter play. Shows the fallback once.
static func block_play(game: Node) -> bool:
	if not _active or not _unplayable():
		return false
	if not _holding:
		_holding = true
		_show_locked(game)
	return true

static func eat_key(game: Node, keycode: int) -> bool:
	if not _active:
		return false
	if _clean and (keycode == KEY_H or keycode == KEY_D):
		_force_clean(game)
		return true
	if _evo and keycode == KEY_E:
		if int(game.phase) == int(game.PHASE_PLAY) and not _holding:
			var need := _points_to_next(game)
			if need > 0:
				game._gain_skill(need)
		return true
	return false

static func hides_overlay() -> bool:
	return _active and _clean

## Green hurt shapes. `?hitbox=1` on the web, or `--hitbox=1` in a desktop run.
## clean=1 wins, so a recording stays clear.
static func wants_hitbox() -> bool:
	_ensure_parsed()
	return _hitbox and not hides_overlay()

static func tick_play(game: Node, _delta: float) -> void:
	if not _active or _spawn_at < 0.0 or _piano_spawned or _hazard_spent:
		return
	if float(game.elapsed) + 0.00001 < _spawn_at:
		return
	_spawn_piano(game)
	_piano_spawned = true

## The scheduled piano is the death in the clip, not the Slime's split.
static func bypass_split(killer: String) -> bool:
	return _active and _hazard == "piano" and not _hazard_spent and killer == "falling piano"

## Capture invulnerability, and a shield so the scheduled piano is the hit that ends the run.
static func ignore_hit(game: Node, killer: String) -> bool:
	if not _active:
		return false
	if _invuln:
		return true
	if _hazard == "piano" and not _hazard_spent and not _piano_connected:
		if killer == "falling piano":
			_piano_connected = true
			print("Capture piano hit at %.2fs of play" % float(game.elapsed))
			return false
		return true
	return false

## Piano deaths hand off to the next run's title card instead of the score card.
static func continue_after_death(game: Node) -> bool:
	if not _active or _hazard != "piano" or _hazard_spent:
		return false
	_hazard_spent = true
	_run_offset += 1
	if game.is_inside_tree():
		game.get_tree().reload_current_scene()
	return true

static func record_score(form_name: String, score: int) -> Dictionary:
	_ensure_parsed()
	if not _active:
		return BestScores.record(form_name, score)
	var existing := BestScores.read()
	return {
		"form": int(existing.get(form_name, 0)),
		"overall": int(existing.get("overall", 0)),
	}

static func _ensure_parsed() -> void:
	if _parsed:
		return
	_parsed = true
	var web := _test_web if _use_test else _web_search()
	var argv := _test_argv if _use_test else OS.get_cmdline_user_args()
	_apply_tokens(web, argv)

static func _web_search() -> String:
	if not OS.has_feature("web"):
		return ""
	var value: Variant = JavaScriptBridge.eval("window.location.search", true)
	if value == null:
		return ""
	return str(value)

static func _apply_tokens(web: String, argv: PackedStringArray) -> void:
	var tokens: PackedStringArray = []
	for arg in argv:
		tokens.append(arg)
	var query := web.strip_edges()
	if query.begins_with("?"):
		query = query.substr(1)
	if query != "":
		for piece in query.split("&", false):
			tokens.append(piece)
	var saw_hazard_t := false
	var hazard_t := DEFAULT_HAZARD_T
	for token in tokens:
		var item := token.strip_edges()
		if item.begins_with("--"):
			item = item.substr(2)
		elif item.begins_with("-"):
			item = item.substr(1)
		var eq := item.find("=")
		if eq <= 0:
			continue
		var key := item.substr(0, eq).uri_decode().strip_edges().to_lower()
		var value := item.substr(eq + 1).uri_decode().strip_edges()
		match key:
			"form":
				var form := value.to_lower()
				if _PLAYABLE.has(form) or _UNPLAYABLE.has(form):
					_form_key = form
					_active = true
			"seed":
				if value.is_valid_int():
					_has_seed = true
					_seed_value = int(value)
					_active = true
			"clean":
				if value == "1":
					_clean = true
					_active = true
			"rank":
				if value == "1" or value == "2" or value == "3":
					_rank = int(value)
					_active = true
			"evo":
				if value == "1":
					_evo = true
					_active = true
			"hazard":
				if value.to_lower() == "piano":
					_hazard = "piano"
					_active = true
			"hazard_t":
				if value.is_valid_float():
					saw_hazard_t = true
					hazard_t = maxf(float(value), 0.0)
			"invuln":
				if value == "1":
					_invuln = true
					_active = true
			"hitbox":
				# Debug overlay only. It does not turn on the rest of capture mode,
				# so a normal daily run can still show hurt shapes from the URL.
				if value == "1":
					_hitbox = true
	if _hazard == "piano" and saw_hazard_t:
		_hazard_t = hazard_t

static func _unplayable() -> bool:
	return _UNPLAYABLE.has(_form_key)

static func _reset_run_state() -> void:
	_spawn_at = -1.0
	_piano_spawned = false
	_piano_connected = false
	_holding = false

static func _points_to_next(game: Node) -> int:
	var gate := FormCatalog.gate_for_next_rank(int(game.rank_index))
	if gate < 0:
		return 0
	return maxi(gate - int(game.evo_points), 0)

static func _force_clean(game: Node) -> void:
	game._debug_on = false
	HitLibrary.show = false
	if game._debug_label != null:
		game._debug_label.visible = false
		game._debug_label.text = ""
	if game.is_inside_tree():
		var tree := game.get_tree()
		tree.debug_collisions_hint = false
		tree.debug_paths_hint = false
		tree.debug_navigation_hint = false

static func _show_locked(game: Node) -> void:
	if game._skip_label != null:
		game._skip_label.text = ""
	var parent: Node = game._hud if game._hud != null else game
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.07, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.position = Vector2(36, 96)
	dim.size = Vector2(408, 78)
	dim.z_index = 6
	parent.add_child(dim)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var font: Font = load("res://ui/font_kaito5x7_outlined.fnt")
	if font is FontFile:
		var outlined := font as FontFile
		outlined.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		outlined.hinting = TextServer.HINTING_NONE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("ffe56a"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = "%s\nNOT PLAYABLE YET" % str(_NAMES.get(_form_key, "UNKNOWN"))
	label.position = Vector2(36, 96)
	label.size = Vector2(408, 78)
	label.z_index = 7
	parent.add_child(label)

static func _schedule_piano(game: Node) -> void:
	var reveal := float(game.REVEAL_SECONDS)
	var play_t := maxf(_hazard_t - reveal, 0.0)
	var size: Vector2 = game._viewport_size()
	var player_pos: Vector2 = game._player.position
	var piano_x := _piano_x(player_pos.x, size.x)
	var impact_y := _impact_y(player_pos, game._player.sprite_name(), piano_x)
	var start_y := -SpawnDirector.body_radius(SpawnDirector.PIANO) - 8.0
	var dt := 1.0 / 60.0
	var impact_frame := int(round(play_t / dt))
	var spawn_frame := _spawn_frame(impact_frame, start_y, impact_y)
	_spawn_at = float(spawn_frame) * dt
	print("Capture piano lands near %.2fs (play %.2fs, spawn %.2fs)" % [_hazard_t, play_t, _spawn_at])

static func _spawn_frame(impact_frame: int, start_y: float, impact_y: float) -> int:
	var lo := 0
	var hi := maxi(impact_frame, 0)
	var best := 0
	while lo <= hi:
		var mid := (lo + hi) >> 1
		if _y_on_frame(mid, impact_frame, start_y) >= impact_y:
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return best

## Piano anchor y after the tick of `frame`, if it spawned on `spawn_frame`.
static func _y_on_frame(spawn_frame: int, frame: int, start_y: float) -> float:
	var dt := 1.0 / 60.0
	var y := start_y
	var warn := -1.0
	var spawned := false
	for f in frame + 1:
		if not spawned and f >= spawn_frame:
			spawned = true
			warn = Difficulty.HAZARD_WARN
		if not spawned:
			continue
		var step := dt
		if warn > 0.0:
			warn -= step
			if warn > 0.0:
				continue
			step = -warn
			warn = 0.0
		y += Difficulty.PIANO_FALL * Difficulty.speed_scale(float(f) * dt) * step
	return y

static func _impact_y(player_pos: Vector2, player_file: String, piano_x: float) -> float:
	var lo := -80.0
	var hi := player_pos.y + 80.0
	for _i in 18:
		var mid := (lo + hi) * 0.5
		var gap := HitLibrary.gap(player_pos, player_file, "hurt", Vector2(piano_x, mid), "piano.png", "threat")
		if gap <= 0.0:
			hi = mid
		else:
			lo = mid
	return hi

static func _piano_x(player_x: float, field_x: float) -> float:
	var span := maxf(field_x - 80.0, 40.0)
	var lane := clampf((player_x - 40.0) / span, 0.0, 1.0)
	return 40.0 + lane * span

static func _spawn_piano(game: Node) -> void:
	var size: Vector2 = game._viewport_size()
	var player_x := float(game._player.position.x)
	var span := maxf(size.x - 80.0, 40.0)
	var lane := clampf((player_x - 40.0) / span, 0.0, 1.0)
	game._spawn_enemy({
		"t": float(game.elapsed),
		"kind": SpawnDirector.PIANO,
		"x_ratio": lane,
		"phase": 0.0,
		"stop_ratio": 0.2,
		"y_bias": 0.0,
		"wave_amp": 8.0,
	}, size)

static func _format_seconds(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(snapped(value, 0.01))
