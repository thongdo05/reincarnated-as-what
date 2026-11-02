extends SceneTree

## In-game shots of every form at rank 4 and rank 5, plus the FINAL FORM moment.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/evolution_shots.gd

var _phase := 0
var _frames := 0
var _index := 0
var _game: Node
var _specs: Array[Dictionary] = []
var _out := "user://evolution_shots"

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(480, 270))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for form in FormCatalog.IDS:
		var key := FormCatalog.key_for(form)
		_specs.append({"form": form, "rank": 3, "file": "%s_r4.png" % key, "kind": "play"})
		_specs.append({"form": form, "rank": 4, "file": "%s_r5.png" % key, "kind": "play"})
	_specs.append({"form": FormCatalog.Id.SLIME, "rank": 3, "file": "final_form_slime.png", "kind": "final"})
	_specs.append({"form": FormCatalog.Id.DEMON, "rank": 3, "file": "final_form_demon.png", "kind": "final"})

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
		if _frames < 3:
			return false
		_apply(_specs[_index])
		_frames = 0
		_phase = 2
		return false
	_frames += 1
	var spec: Dictionary = _specs[_index]
	var need := 8
	if str(spec["kind"]) == "final":
		need = 40
	if _frames < need:
		if str(spec["kind"]) == "final":
			_game._process(1.0 / 60.0)
		return false
	_save(str(spec["file"]))
	_index += 1
	if _index >= _specs.size():
		print("EVOLUTION_SHOTS_OK")
		quit(0)
		return true
	_apply(_specs[_index])
	_frames = 0
	return false

func _apply(spec: Dictionary) -> void:
	var game = _game
	var form := int(spec["form"])
	var rank := int(spec["rank"])
	game.form_id = form
	game.phase = game.PHASE_PLAY
	game._reveal.visible = false
	if game._hint_label != null:
		game._hint_label.visible = false
	game._paused = false
	game._pause_overlay.visible = false
	game.rank_index = rank
	game.evo_points = int(FormCatalog.rank_gates()[rank - 1]) if rank > 0 else 0
	game.invuln = 30.0
	game.elapsed = 12.0
	game._player.form_id = form
	game._player.rank_index = rank
	game._player.small = false
	game._player.alive = true
	game._player.visible = true
	game._player.invulnerable = true
	game._player.evolve_t = -1.0
	game._player.evolve_final = false
	game._player.fx_mode = ""
	game._final_flash = 0.0
	game._player._apply_radius()
	game._player.position = Vector2(148, 132)
	game._player.aim = game._player.position
	game._clear_field()
	game._spawn_enemy({
		"t": 0.0,
		"kind": SpawnDirector.EYE,
		"x_ratio": 0.78,
		"phase": 0.4,
		"stop_ratio": 0.2,
		"y_bias": -28.0,
		"wave_amp": 8.0,
		"hold_fire": true,
	}, Vector2(480, 270))
	game._spawn_shot({
		"position": Vector2(300, 90),
		"velocity": Vector2(-90, 18),
		"sprite": "floating_eye_bolt.png",
		"damage": 1,
		"killer_name": "Floating Eye",
	}, false)
	game._spawn_shot({
		"position": Vector2(340, 168),
		"velocity": Vector2(-110, -12),
		"sprite": "arrow.png",
		"damage": 1,
		"killer_name": "Skeleton Archer",
	}, false)
	for shot_spec in FormCatalog.player_shots(form, game._player.position, rank):
		game._spawn_shot(shot_spec, true)
	if str(spec["kind"]) == "final":
		var old_sprite: String = game._player.sprite_name()
		game.rank_index = rank + 1
		game._player.set_rank(rank + 1)
		game._player.begin_evolve(old_sprite, game._player.sprite_name(), true)
		game._final_evolve = true
		game._final_flash = 1.1
		game._slow_left = Difficulty.FINAL_SLOWMO_SECONDS
	game._refresh_hud()
	game._player.queue_redraw()

func _save(file_name: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := _out + "/" + file_name
	var err := image.save_png(path)
	print("SAVED %s err %s" % [ProjectSettings.globalize_path(path), err])
