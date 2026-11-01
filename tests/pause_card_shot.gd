extends SceneTree

## Saves 480x270 pause-card shots. Not part of CI.
## xvfb-run godot --path . -s res://tests/pause_card_shot.gd

var _phase := 0
var _frames := 0
var _index := 0
var _game: Node
var _specs: Array[Dictionary] = []

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(480, 270))
	_specs = [
		{
			"form": FormCatalog.Id.SLIME,
			"rank": 0,
			"points": 480,
			"file": "pause_slime_r1.png",
			"heading": "SLIME, Slime (rank 1/3)",
			"need": "Split ready.",
		},
		{
			"form": FormCatalog.Id.SLIME,
			"rank": 2,
			"points": Difficulty.GATE_RANK3,
			"file": "pause_slime_r3.png",
			"heading": "SLIME, Ooze Titan (rank 3/3)",
			"need": "FINAL FORM",
		},
		{
			"form": FormCatalog.Id.GOBLIN,
			"rank": 1,
			"points": Difficulty.GATE_RANK2 + 2800,
			"file": "pause_goblin_r2.png",
			"heading": "GOBLIN, Goblin Chief (rank 2/3)",
			"need": "WEAPON",
		},
	]

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
	print("CARD %s | %s | %s | %s" % [
		spec["file"],
		card.heading_text(),
		card.weapon_text(),
		card.trait_text(),
	])
	print("NEXT %s" % card.next_text())
	if card.heading_text() != str(spec["heading"]):
		push_error("heading mismatch for %s" % spec["file"])
		quit(1)
		return true
	var blob: String = str(card.weapon_text()) + str(card.trait_text()) + str(card.next_text())
	if blob.find(str(spec["need"])) < 0:
		push_error("missing %s on %s" % [spec["need"], spec["file"]])
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
	var err := image.save_png(path)
	if err != OK:
		push_error("save failed %s" % path)
		quit(1)
		return true
	print("WROTE %s" % path)
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
	game._layout_pause(Vector2(480, 270))
	game._pause_overlay.visible = true
	if game._pause_button != null:
		game._pause_button.visible = true
	if game._sound_button != null:
		game._sound_button.visible = true
