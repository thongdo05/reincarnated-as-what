extends RefCounted
class_name FlappyMode

## Experimental tap mode. Off unless the page query or the user args say
## mode=flappy, parsed the same way CaptureMode reads flags (query wins).
## With the flag unset, attach() does not touch the run.

## Per-form flap. `flap` is the upward speed a tap sets (px/s). `gravity` pulls
## down (px/s^2). +y is down, so the hop height is flap^2 / (2 * gravity).
## Slime: heavier, bouncier hop and a floatier fall. Goblin: shorter hop, faster fall.
## gap_start / gap_end are the clear flight opening in px, lerped over gap_ramp.
## The goblin flutter fits a tighter slot. The slime hop needs the wider one.
const FEEL := {
	"slime": {
		"flap": 292.0,
		"gravity": 640.0,
		"gap_start": 116.0,
		"gap_end": 74.0,
	},
	"goblin": {
		"flap": 214.0,
		"gravity": 1280.0,
		"gap_start": 84.0,
		"gap_end": 44.0,
	},
}

## Gap course and the mode's own rank gates. Main Difficulty gates are not used.
## Rank 2 is inside a normal short run. Rank 3 sits just above the bot bulk,
## so a hot run can still reach it and a typical one does not.
const COURSE := {
	"first_t": 0.85,
	"interval": 1.48,
	"scroll": 172.0,
	"scroll_end": 236.0,
	"scroll_ramp": 18.0,
	"gap_ramp": 18.0,
	"gap_shift": 72.0,
	"spawn_x_pad": 36.0,
}

const GATES: Array[int] = [640, 1600]

## Separate from user://best_scores.json so a flappy run cannot raise the main ladder.
const SAVE_PATH := "user://best_scores_flappy.json"

static var _rng := RandomNumberGenerator.new()
static var _gates: Array = []
static var _parsed := false
static var _on := false
static var _use_test := false
static var _test_web := ""
static var _test_argv: PackedStringArray = PackedStringArray()
static var _flap := false
static var _lock_x := 0.0
static var _next_t := 0.0
static var _prev_gap := 120.0

static func is_active() -> bool:
	_ensure()
	return _on

static func feel_for(form_id: int) -> Dictionary:
	if form_id == FormCatalog.Id.SLIME:
		return FEEL["slime"]
	return FEEL["goblin"]

static func flap_speed(form_id: int) -> float:
	return float(feel_for(form_id)["flap"])

static func gravity_of(form_id: int) -> float:
	return float(feel_for(form_id)["gravity"])

static func hop_px(form_id: int) -> float:
	var g := gravity_of(form_id)
	if g <= 1.0:
		return 0.0
	var v := flap_speed(form_id)
	return (v * v) / (2.0 * g)

static func gate_for_next_rank(rank_index: int) -> int:
	if rank_index < 0 or rank_index >= GATES.size():
		return -1
	return int(GATES[rank_index])

static func rank_for_points(points: int) -> int:
	var rank := 0
	for gate in GATES:
		if points >= int(gate):
			rank += 1
	return mini(rank, GATES.size())

static func next_rank_text(rank_index: int, points: int) -> String:
	var gate := gate_for_next_rank(rank_index)
	if gate < 0:
		return "FINAL FORM"
	return "%d/%d" % [maxi(points, 0), gate]

static func fill_px(points: int, rank_index: int) -> int:
	var nxt := gate_for_next_rank(rank_index)
	if nxt < 0:
		return HudLayout.FILL_FULL
	var prev := 0
	if rank_index > 0 and rank_index - 1 < GATES.size():
		prev = int(GATES[rank_index - 1])
	var span := nxt - prev
	if span <= 0:
		return HudLayout.FILL_FULL
	var along := clampf(float(points - prev) / float(span), 0.0, 1.0)
	return int(round(float(HudLayout.FILL_FULL) * along))

static func queue_flap() -> void:
	_flap = true

static func clear_flap() -> void:
	_flap = false

static func lock_x() -> float:
	return _lock_x

static func gates() -> Array:
	return _gates.duplicate()

static func read_scores() -> Dictionary:
	return _read_scores()

## Test hook. The exported game never calls this.
static func reset_for_test(argv: PackedStringArray, web: String = "") -> void:
	_clear_gates()
	_flap = false
	_parsed = false
	_on = false
	_use_test = true
	_test_web = web
	_test_argv = argv

static func clear_test_hook() -> void:
	_clear_gates()
	_flap = false
	_use_test = false
	_test_web = ""
	_test_argv = PackedStringArray()
	_parsed = false
	_on = false

static func attach(game: Node) -> void:
	_clear_gates()
	_flap = false
	if not is_active():
		return
	_seed_run(game)
	if game._hint_label != null:
		game._hint_label.text = "Tap anywhere to flap"
	_add_tag(game)
	_open_retry(game)
	if int(game.rank_index) > 0:
		var index := int(game.rank_index) - 1
		if index >= 0 and index < GATES.size():
			game.evo_points = int(GATES[index])
			game._refresh_hud()
	print("Flappy test mode (tap to flap)")

static func relock(game: Node) -> void:
	if not is_active():
		return
	_clear_gates()
	_flap = false
	_seed_run(game)

static func integrate_ship(ship: PlayerShip, delta: float, _bounds: Rect2) -> void:
	var feel := feel_for(ship.form_id)
	ship.velocity.x = 0.0
	ship.velocity.y += float(feel["gravity"]) * delta
	if _flap:
		_flap = false
		ship.velocity.y = -float(feel["flap"])
	ship.position.x = _lock_x
	ship.position.y += ship.velocity.y * delta
	ship.aim = ship.position

## True when this event was the flap (or was a pointer the default drag must not see).
static func consume_pointer(game: Node, event: InputEvent) -> bool:
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		return true
	var press := false
	var pos := Vector2.INF
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return true
		press = true
		pos = touch.position
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return false
		if not mouse.pressed:
			return true
		press = true
		pos = mouse.position
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode != KEY_SPACE:
			return false
		if not key.pressed or key.echo:
			return true
		press = true
	else:
		return false
	if not press:
		return true
	if pos != Vector2.INF and (game._hits_pause(pos) or game._hits_sound(pos) or game._hits_audio_blocked(pos)):
		return true
	if game._try_skip_tease():
		return true
	if int(game.phase) == int(game.PHASE_DEAD) and bool(game.game_over_visible):
		game._on_restart()
		return true
	if int(game.phase) == int(game.PHASE_REVEAL):
		game._try_skip_reveal()
		return true
	if int(game.phase) == int(game.PHASE_PLAY):
		queue_flap()
	return true

static func tick(game: Node, delta: float, size: Vector2, _bounds: Rect2) -> void:
	if not _on:
		return
	if int(game.phase) != int(game.PHASE_PLAY):
		return
	_edges(game, size)
	if int(game.phase) != int(game.PHASE_PLAY):
		return
	var elapsed := float(game.elapsed)
	var speed := _scroll(elapsed)
	var guard := 0
	while elapsed + 0.00001 >= _next_t and guard < 4:
		guard += 1
		_spawn(game, _next_t, size)
		_next_t += float(COURSE["interval"])
	var keep: Array = []
	for gate in _gates:
		if not is_instance_valid(gate):
			continue
		gate.tick(delta, speed)
		if gate.offscreen():
			gate.queue_free()
			continue
		keep.append(gate)
		var ship: PlayerShip = game._player
		if ship != null and ship.alive and not ship.invulnerable and gate.hits_ship(ship):
			game._hurt_player("pillar")
			if int(game.phase) != int(game.PHASE_PLAY) or not ship.alive:
				_gates = keep
				return
	_gates = keep

static func record_score(form_name: String, score: int) -> Dictionary:
	# A capture run still must not write a best, including this side file.
	if CaptureMode.is_active():
		var existing := _read_scores()
		return {
			"form": int(existing.get(form_name, 0)),
			"overall": int(existing.get("overall", 0)),
		}
	var saved := BestScores.apply(_read_scores(), form_name, score)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(saved))
		file.close()
	return {
		"form": int(saved.get(form_name, 0)),
		"overall": int(saved.get("overall", 0)),
	}

static func _seed_run(game: Node) -> void:
	_rng.seed = int(game.day_seed) + 9241
	var size: Vector2 = game._viewport_size()
	_prev_gap = size.y * 0.46
	_next_t = float(COURSE["first_t"])
	if game._player != null:
		_lock_x = game._player.position.x

static func _edges(game: Node, size: Vector2) -> void:
	var ship: PlayerShip = game._player
	if ship == null or not ship.alive:
		return
	var floor_y := minf(FieldBackground.GROUND_FEET, size.y)
	# radius is the full-body hurt extent, so a drip or a goblin foot counts.
	var min_y := ship.radius
	var max_y := floor_y - ship.radius
	if max_y <= min_y:
		return
	var at_top := ship.position.y <= min_y
	var at_bottom := ship.position.y >= max_y
	if not at_top and not at_bottom:
		return
	if ship.invulnerable:
		_nudge(ship, min_y, max_y, at_top, at_bottom)
		return
	game._hurt_player("ceiling" if at_top else "floor")
	if ship.alive:
		_nudge(ship, min_y, max_y, at_top, at_bottom)

static func _nudge(ship: PlayerShip, min_y: float, max_y: float, at_top: bool, at_bottom: bool) -> void:
	ship.position.y = clampf(ship.position.y, min_y + 0.5, max_y - 0.5)
	if at_top and ship.velocity.y < 0.0:
		ship.velocity.y = 0.0
	if at_bottom and ship.velocity.y > 0.0:
		ship.velocity.y = 0.0

static func _opening(elapsed: float, form_id: int) -> float:
	var feel := feel_for(form_id)
	var ramp := float(COURSE["gap_ramp"])
	var u := clampf(elapsed / maxf(ramp, 0.01), 0.0, 1.0)
	return lerpf(float(feel["gap_start"]), float(feel["gap_end"]), u)

static func _scroll(elapsed: float) -> float:
	var ramp := float(COURSE["scroll_ramp"])
	var u := clampf(elapsed / maxf(ramp, 0.01), 0.0, 1.0)
	return lerpf(float(COURSE["scroll"]), float(COURSE["scroll_end"]), u)

static func _next_center(opening: float, field_h: float) -> float:
	var half := opening * 0.5
	var lo := half + 22.0
	var hi := field_h - 40.0 - half
	if hi < lo:
		return field_h * 0.46
	var shift := float(COURSE["gap_shift"])
	var center := _prev_gap + _rng.randf_range(-shift, shift)
	center = clampf(center, lo, hi)
	_prev_gap = center
	return center

static func _spawn(game: Node, elapsed: float, size: Vector2) -> void:
	var opening := _opening(elapsed, int(game.form_id))
	var center := _next_center(opening, size.y)
	var gate := FlappyGate.new()
	var floor_y := minf(FieldBackground.GROUND_FEET + 16.0, size.y - 4.0)
	gate.setup(size.x + float(COURSE["spawn_x_pad"]), center, opening, floor_y)
	game.add_child(gate)
	_gates.append(gate)

static func _add_tag(game: Node) -> void:
	var hud: Node = game._hud
	if hud == null or hud.get_node_or_null("FlappyTag") != null:
		return
	var label := Label.new()
	label.name = "FlappyTag"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.text = "FLAPPY TEST"
	var font: Font = load("res://ui/font_kaito5x7_outlined.fnt")
	if font is FontFile:
		var outlined := font as FontFile
		outlined.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		outlined.hinting = TextServer.HINTING_NONE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("ffe56a"))
	label.position = Vector2(4, 250)
	label.size = Vector2(140, 16)
	label.z_index = 6
	hud.add_child(label)

static func _open_retry(game: Node) -> void:
	var card: Node = game._game_over
	if card == null or card.get_child_count() < 1:
		return
	var shade := card.get_child(0)
	if shade is ColorRect:
		(shade as ColorRect).mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _clear_gates() -> void:
	var old := _gates.duplicate()
	_gates.clear()
	for gate in old:
		if is_instance_valid(gate):
			gate.queue_free()

static func _read_scores() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"overall": 0}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {"overall": 0}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"overall": 0}
	return parsed

static func _ensure() -> void:
	if _parsed:
		return
	_parsed = true
	_on = false
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
	var mode := ""
	var saw := false
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
		if key != "mode":
			continue
		saw = true
		mode = value.to_lower()
	_on = saw and mode == "flappy"
