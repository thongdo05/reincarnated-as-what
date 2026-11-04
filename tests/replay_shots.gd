extends SceneTree

## Saves the replay pass frames. Not part of CI.
## xvfb-run godot --path . -s res://tests/replay_shots.gd

var _phase := 0
var _frames := 0
var _shot_at := 0
var _game: Node
var _lesson: Node

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(480, 270))
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/replay")

func _process(_delta: float) -> bool:
	match _phase:
		0:
			return _boot_lesson()
		1:
			return _grab_lesson()
		2:
			return _boot_death()
		3:
			return _grab_death()
		4:
			return _boot_busy()
		5:
			return _grab_busy()
		6:
			return _grab_share()
		7:
			return _save_share()
	return false

func _boot_lesson() -> bool:
	Replay.reset_seen_for_test()
	var packed: PackedScene = load("res://scenes/main.tscn")
	_lesson = packed.instantiate()
	_lesson.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_lesson)
	_frames = 0
	_phase = 1
	return false

func _grab_lesson() -> bool:
	_frames += 1
	if _frames > 900:
		push_error("tutorial frames did not arrive (t %.2f phase %s)" % [float(_lesson.elapsed), str(_lesson.phase)])
		quit(1)
		return true
	_lesson._process(1.0 / 60.0)
	var elapsed := float(_lesson.elapsed)
	var phase := int(_lesson.phase)
	if phase == _lesson.PHASE_PLAY and _shot_at == 0 and elapsed >= 1.0:
		_save("tutorial_drag.png")
		_shot_at = 1
	elif _shot_at == 1 and elapsed >= 4.0:
		_save("tutorial_gem.png")
		_shot_at = 2
	elif _shot_at == 2 and elapsed >= 6.6:
		_save("tutorial_shot.png")
		_lesson.free()
		_lesson = null
		_phase = 2
		_frames = 0
	return false

func _boot_death() -> bool:
	var best := FileAccess.open("user://best_scores.json", FileAccess.WRITE)
	if best != null:
		best.store_string(JSON.stringify({"epoch": BestScores.SCORE_EPOCH, "overall": 100, "SLIME": 100, "GOBLIN": 100}))
		best.close()
	var packed: PackedScene = load("res://scenes/main.tscn")
	_game = packed.instantiate()
	_game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_game)
	_game._begin_play()
	_game.score = 8400
	_game.rank_index = 1
	_game.elapsed = 18.0
	_game._kill_player("Dire Wolf")
	_game._skip_death_to_card()
	_frames = 0
	_phase = 3
	return false

func _grab_death() -> bool:
	_frames += 1
	_game._process(1.0 / 60.0)
	if _frames < 18:
		return false
	_save("death_new_best.png")
	if _game._new_best_label == null or _game._new_best_label.text != "NEW BEST!":
		push_error("death shot missed NEW BEST")
		quit(1)
		return true
	_phase = 4
	return false

func _boot_busy() -> bool:
	_game.queue_free()
	_game = null
	var packed: PackedScene = load("res://scenes/main.tscn")
	_game = packed.instantiate()
	_game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_game)
	_game._begin_play()
	_game.invuln = 99.0
	_game._player.invulnerable = true
	_game._player.position = Vector2(240, 150)
	_game._player.aim = _game._player.position
	_game._player.begin_evolve(_game._player.sprite_name(), _game._player.sprite_name(), false)
	_game._player.evolve_t = 0.5
	_game._player._apply_evolve_visual()
	_game._overdrive_flash = 1.0
	_game._spawn_fx("winner_burst.png", Vector2(240, 150), 3.0, 1.0, 1.0)
	_game._spawn_fx("evolved_burst.png", Vector2(236, 146), 3.0, 1.1, 1.1)
	_game._spawn_fx("death_puff.png", Vector2(248, 154), 3.0, 1.3, 1.3)
	_game._spawn_fx("hit_flash.png", Vector2(220, 140), 3.0, 1.4, 1.4)
	_game._combat.push("OVERDRIVE", Vector2(190, 120), Color("ffe56a"), 4.0)
	_game._combat.push("+2,400", Vector2(210, 168), Color("241428"), 4.0)
	_game._combat.push("WINNER!", Vector2(250, 118), Color("ffe56a"), 4.0)
	for i in 7:
		_game._spawn_shot({
			"position": Vector2(168.0 + float(i) * 22.0, 150.0),
			"velocity": Vector2.ZERO,
			"sprite": "floating_eye_bolt.png" if i % 2 == 0 else "arrow.png",
			"radius": 5.0,
			"damage": 1,
			"killer_name": "Floating Eye",
		}, false)
	_frames = 0
	_phase = 5
	return false

func _grab_busy() -> bool:
	_frames += 1
	_game.position = Vector2.ZERO
	_game._process(1.0 / 60.0)
	_game.position = Vector2.ZERO
	if _frames < 3:
		return false
	_save("bullets_over_fx.png")
	if not _prove_bolt():
		quit(1)
		return true
	_phase = 6
	return false

func _grab_share() -> bool:
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color("100c14")
	panel.size = Vector2(480, 270)
	panel.position = Vector2.ZERO
	layer.add_child(panel)
	var label := Label.new()
	label.position = Vector2(24, 48)
	label.size = Vector2(432, 180)
	label.text = Replay.daily_text(20261101, FormCatalog.Id.GOBLIN, 8400, "Goblin Chief")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font: Font = load("res://ui/font_kaito5x7_outlined.fnt")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("f2fbff"))
	layer.add_child(label)
	var link := Label.new()
	link.position = Vector2(24, 200)
	link.size = Vector2(432, 48)
	link.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	link.text = Replay.beat_url(20261101, "goblin")
	link.add_theme_font_override("font", font)
	link.add_theme_font_size_override("font_size", 9)
	link.add_theme_color_override("font_color", Color("ffd84a"))
	layer.add_child(link)
	_frames = 0
	_phase = 7
	return false

func _save_share() -> bool:
	_frames += 1
	if _frames < 3:
		return false
	_save("share_text.png")
	print("SHOTS_OK")
	quit(0)
	return true

func _prove_bolt() -> bool:
	var image := root.get_texture().get_image()
	var bolt := ArtLibrary.texture("floating_eye_bolt.png").get_image()
	var ink := Color(0, 0, 0, 0)
	var have := false
	for y in bolt.get_height():
		for x in bolt.get_width():
			var pixel := bolt.get_pixel(x, y)
			if pixel.a > 0.9 and pixel.r < 0.25 and pixel.b < 0.35:
				ink = pixel
				have = true
				break
		if have:
			break
	if not have:
		push_error("bolt sprite has no dark core")
		return false
	var hits := 0
	for y in range(120, 180):
		for x in range(140, 360):
			var seen := image.get_pixel(x, y)
			var drift := absf(seen.r - ink.r) + absf(seen.g - ink.g) + absf(seen.b - ink.b)
			if drift < 0.08:
				hits += 1
	print("BOLT_PIXEL core %s hits %d" % [ink, hits])
	if hits < 8:
		push_error("enemy bullet cores were covered (hits %d)" % hits)
		return false
	print("BULLETS_VISIBLE")
	return true

func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image for %s" % file_name)
		return
	var path := "/opt/cursor/artifacts/replay/%s" % file_name
	var err := image.save_png(path)
	if err != OK:
		push_error("save failed %s" % path)
		return
	print("WROTE %s %s" % [path, image.get_size()])

