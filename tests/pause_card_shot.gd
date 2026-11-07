extends SceneTree

## Saves 480x270 pause-guide shots. Not part of CI.
## xvfb-run godot --path . -s res://tests/pause_card_shot.gd

var _phase := 0
var _frames := 0
var _index := 0
var _game: Node
var _specs: Array[Dictionary] = []

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(480, 270))
	var power_points := Difficulty.GATE_RANK5 + Difficulty.power_step_points(1)
	_specs = [
		_spec("you", false, FormCatalog.Id.SLIME, 0, 480, "pause_you.png"),
		_spec("pickups", false, FormCatalog.Id.SLIME, 0, 480, "pause_pickups.png"),
		_spec("controls", false, FormCatalog.Id.SLIME, 0, 480, "pause_controls.png"),
		_spec("you", true, FormCatalog.Id.SLIME, 0, 480, "pause_you_ios.png"),
		_spec("pickups", true, FormCatalog.Id.SLIME, 0, 480, "pause_pickups_ios.png"),
		_spec("controls", true, FormCatalog.Id.SLIME, 0, 480, "pause_controls_ios.png"),
		_spec("you", false, FormCatalog.Id.DEMON, 4, power_points, "pause_rank5.png"),
		_spec("you", false, FormCatalog.Id.DRAGON, 0, 200, "pause_dragon_you.png"),
		_spec("pickups", false, FormCatalog.Id.DRAGON, 0, 200, "pause_dragon_pickups.png"),
	]

func _spec(tab: String, ios: bool, form: int, rank: int, points: int, file: String) -> Dictionary:
	return {
		"tab": tab,
		"ios": ios,
		"form": form,
		"rank": rank,
		"points": points,
		"file": file,
	}

func _process(_delta: float) -> bool:
	if _phase == 0:
		var packed: PackedScene = load("res://scenes/main.tscn")
		_game = packed.instantiate()
		root.add_child(_game)
		_frames = 0
		_phase = 1
		return false
	if _phase == 1:
		_frames += 1
		if _frames < 2:
			return false
		_apply(_specs[_index])
		_frames = 0
		_phase = 2
		return false
	_frames += 1
	if _frames < 4:
		return false
	var spec: Dictionary = _specs[_index]
	var card = _game._pause_card
	var err := _check(spec, card)
	if err != "":
		push_error("%s: %s" % [spec["file"], err])
		quit(1)
		return true
	var image := root.get_texture().get_image()
	if image == null or image.get_width() != 480 or image.get_height() != 270:
		var size := image.get_size() if image != null else Vector2i.ZERO
		push_error("expected 480x270, got %s" % size)
		quit(1)
		return true
	var path := "/opt/cursor/artifacts/pause-card/%s" % spec["file"]
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/pause-card")
	var save_err := image.save_png(path)
	if save_err != OK:
		push_error("save failed %s" % path)
		quit(1)
		return true
	print("WROTE %s | %s | %s | %s" % [path, card.heading_text(), card.weapon_text(), card.next_text()])
	_index += 1
	if _index >= _specs.size():
		print("SHOTS_OK")
		quit(0)
		return true
	_game.queue_free()
	_game = null
	_phase = 0
	return false

func _apply(spec: Dictionary) -> void:
	var game = _game
	game.form_id = int(spec["form"])
	game.phase = 1
	game._reveal.visible = false
	game._hint_label.visible = false
	game._paused = true
	game.rank_index = int(spec["rank"])
	game.evo_points = int(spec["points"])
	game._player.form_id = int(spec["form"])
	game._player.rank_index = int(spec["rank"])
	game._player.small = false
	game._player._apply_radius()
	game._player.position = Vector2(300, 200)
	game._player.aim = game._player.position
	game._player.queue_redraw()
	game._refresh_hud()
	game._refresh_pause_card()
	var tab := PauseGuide.TAB_YOU
	if str(spec["tab"]) == "pickups":
		tab = PauseGuide.TAB_PICKUPS
	elif str(spec["tab"]) == "controls":
		tab = PauseGuide.TAB_CONTROLS
	game._pause_card.show_tab(tab)
	game._pause_card.set_store_row(bool(spec["ios"]), bool(spec["ios"]))
	game._layout_pause(Vector2(480, 270))
	game._pause_overlay.visible = true
	if game._pause_button != null:
		game._pause_button.visible = true
	if game._sound_button != null:
		game._sound_button.visible = true

func _check(spec: Dictionary, card) -> String:
	var tab := str(spec["tab"])
	if tab == "you" and card.heading_text() != FormCatalog.display_name(int(spec["form"])):
		return "heading %s" % card.heading_text()
	if int(spec["rank"]) >= 4 and card.next_text().find("POWER +") < 0:
		return "rank 5 should show POWER, got %s" % card.next_text()
	if tab != "you" and PauseGuide.mentions_secret(card.pickup_text() + card.controls_text()):
		return "secret leaked into the public tabs"
	if tab == "pickups" and card.pickup_text().find(str(Difficulty.GEM_SCORE)) < 0:
		return "pickup copy missing the gem score"
	var view := Rect2(Vector2.ZERO, Vector2(480, 270))
	var card_rect: Rect2 = card.get_global_rect()
	if not view.encloses(card_rect):
		return "card leaves the 480x270 view %s" % card_rect
	var pause_rect: Rect2 = _game._pause_button.get_global_rect()
	if card_rect.intersects(pause_rect):
		return "card overlaps pause %s / %s" % [card_rect, pause_rect]
	var targets: Array[Control] = []
	for tab_button in card.tab_controls():
		targets.append(tab_button)
	targets.append(card.resume_control())
	targets.append(_game._sound_button)
	if bool(spec["ios"]):
		targets.append(card._remove_ph)
		targets.append(card._restore_ph)
	for target in targets:
		var rect := target.get_global_rect()
		if not target.visible:
			return "missing target %s" % target
		if rect.size.x + 0.01 < 44.0 or rect.size.y + 0.01 < 44.0:
			return "target under 44px %s %s" % [target, rect.size]
		if not view.encloses(rect) or not card_rect.encloses(rect):
			return "target outside %s" % rect
	for i in targets.size():
		for j in range(i + 1, targets.size()):
			var a: Rect2 = targets[i].get_global_rect()
			var b: Rect2 = targets[j].get_global_rect()
			if a.intersects(b):
				return "targets overlap %s %s" % [a, b]
	return _check_lines(card)

func _check_lines(card) -> String:
	var pages: Array[Control] = [card._you, card._pickups, card._controls]
	for page in pages:
		if not page.visible:
			continue
		for child in page.get_children():
			if child is Label and child.visible:
				var label := child as Label
				if label.text.is_empty():
					continue
				if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
					return "wrapped line %s" % label.text
				var width: float = card._text_width(label.text, label.get_theme_font_size("font_size"))
				if width > label.size.x + 1.0:
					return "clipped '%s' %s > %s" % [label.text, width, label.size.x]
				var rect := label.get_global_rect()
				if rect.position.y < -0.5 or rect.end.y > 270.5 or rect.end.x > 480.5:
					return "label outside '%s' %s" % [label.text, rect]
	return ""
