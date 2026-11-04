extends SceneTree

## Stills of each dragon-phase tier, a hatch, the cultist shield, and a returned dragon.
## xvfb-run godot --path . -s res://tests/dragon_phase_shots.gd

var _phase := 0
var _frames := 0
var _game: Node
var _field := Vector2(480, 270)

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))

func _process(_delta: float) -> bool:
	if _phase == 0:
		var packed: PackedScene = load("res://scenes/main.tscn")
		_game = packed.instantiate()
		root.add_child(_game)
		_frames = 0
		_phase = 1
		return false
	_frames += 1
	if _phase == 1:
		if _frames < 3:
			return false
		_ready_play()
		_game.set_process(false)
		_game.form_id = FormCatalog.Id.DRAGON
		_game._player.adopt_dragon(1.0)
		_game._player.position = Vector2(90, 140)
		_game._begin_dragon_phase()
		if _game._dragon_spawns != null:
			_game._dragon_spawns.arm_at(10000.0)
		_game._refresh_hud()
		_frames = 0
		_phase = 2
		return false
	if _phase == 2:
		_stage_tier1()
		_frames = 0
		_phase = 3
		return false
	if _phase == 3:
		if _frames < 2:
			return false
		if not _save("tier1_action.png"):
			return true
		_stage_tier2()
		_frames = 0
		_phase = 4
		return false
	if _phase == 4:
		if _frames < 2:
			return false
		if not _save("tier2_action.png"):
			return true
		_stage_tier3()
		_frames = 0
		_phase = 5
		return false
	if _phase == 5:
		if _frames < 2:
			return false
		if not _save("tier3_action.png"):
			return true
		_stage_tier4()
		_frames = 0
		_phase = 6
		return false
	if _phase == 6:
		if _frames < 2:
			return false
		if not _save("tier4_elder.png"):
			return true
		_stage_hatch()
		_frames = 0
		_phase = 7
		return false
	if _phase == 7:
		if _frames < 2:
			return false
		if not _save("egg_hatch.png"):
			return true
		_stage_shield()
		_frames = 0
		_phase = 8
		return false
	if _phase == 8:
		if _frames < 2:
			return false
		if not _save("cultist_shield.png"):
			return true
		_stage_return()
		_frames = 0
		_phase = 9
		return false
	if _frames < 2:
		return false
	if not _save("dragon_return.png"):
		return true
	print("DRAGON_PHASE_SHOTS_OK")
	quit(0)
	return true

func _ready_play() -> void:
	var game = _game
	game.phase = game.PHASE_PLAY
	game._reveal.visible = false
	if game._hint_label != null:
		game._hint_label.visible = false
	if game._world_flash != null:
		game._world_flash.visible = false
	game._world_flash_left = 0.0
	game._paused = false
	game.elapsed = 4.0
	game.invuln = 0.0
	game._player.alive = true
	game._player.invulnerable = false
	game._player.visible = true
	game._clear_field()
	if game._title_board_button != null:
		game._title_board_button.visible = false

func _wipe() -> void:
	_game._clear_field()
	_game._player.position = Vector2(90, 140)
	_game._player.queue_redraw()
	if _game._background != null:
		_game._background.queue_redraw()

func _stage_tier1() -> void:
	_wipe()
	_drive(DragonPhase.BAT, Vector2(360, 58), 6)
	_drive(DragonPhase.BAT, Vector2(410, 96), 4)
	_drive(DragonPhase.WHELP, Vector2(300, 150), 16)
	_drive(DragonPhase.KOBOLD, Vector2(390, 210), 14)
	_drive(DragonPhase.EGG, Vector2(250, 200), 46)
	_redraw()

func _stage_tier2() -> void:
	_wipe()
	_drive(DragonPhase.WYVERN, Vector2(400, 70), 20)
	_drive(DragonPhase.RIDER, Vector2(360, 150), 18)
	_drive(DragonPhase.SLIME, Vector2(210, 210), 4)
	var slime := _drive(DragonPhase.SLIME, Vector2(300, 210), 6)
	_spill(slime)
	_redraw()

func _stage_tier3() -> void:
	_wipe()
	var rider := _drive(DragonPhase.WHELP, Vector2(250, 120), 2)
	var cult := _drive(DragonPhase.CULTIST, Vector2(310, 150), 1)
	_bind(rider, cult)
	cult.tick(0.1, _game._player.position, 1.0, 1.0)
	_drive(DragonPhase.WRAITH, Vector2(470, 110), 96)
	_redraw()

func _stage_tier4() -> void:
	_wipe()
	_drive(DragonPhase.ELDER, Vector2(390, 170), 16)
	_redraw()

func _stage_hatch() -> void:
	_wipe()
	var egg := _drive(DragonPhase.EGG, Vector2(280, 160), 0)
	var guard := 0
	while egg.alive and guard < 400:
		egg.tick(1.0 / 60.0, _game._player.position, 1.0, 1.0)
		guard += 1
	var bye: Dictionary = egg.take_farewell()
	var offset: Vector2 = bye.get("offset", Vector2.ZERO)
	_game._play_sheet(str(bye.get("file", "")), egg.position + offset)
	if not _game._sheets.is_empty():
		var fx: SheetFx = _game._sheets[_game._sheets.size() - 1]
		fx.age = fx.duration * 0.5
		fx.queue_redraw()
	for extra in egg.take_spawns():
		_game._spawn_enemy(extra, _field)
	egg.visible = false
	_redraw()

func _stage_shield() -> void:
	_wipe()
	var whelp := _drive(DragonPhase.WHELP, Vector2(230, 140), 2)
	var cult := _drive(DragonPhase.CULTIST, Vector2(300, 150), 1)
	_bind(whelp, cult)
	cult.tick(0.1, _game._player.position, 1.0, 1.0)
	cult.queue_redraw()
	whelp.queue_redraw()
	_redraw()

func _stage_return() -> void:
	_wipe()
	_game._spawn_boss({
		"slug": "great_dragon",
		"generation": 4,
		"hold_x": 400.0,
		"origin_y": 130.0,
		"phase": 0.2,
		"wave_amp": 8.0,
	}, _field)
	var boss := _game._living_boss() as BossActor
	boss.intro_left = 0.0
	boss.state = BossActor.HOLD
	boss.position = Vector2(400, 128)
	boss.hp = int(float(boss.max_hp) * 0.2)
	boss._attack_cd = 0.0
	boss._attack_i = 0
	boss._summon_cd = 80.0
	for _i in 8:
		boss.tick(0.05, _game._player.position, 200.0, 1.0)
	boss.queue_redraw()
	if _game._boss_banner != null:
		_game._boss_banner.queue_redraw()
	_redraw()

func _drive(id: int, at: Vector2, steps: int) -> DragonEnemy:
	_game._spawn_enemy({
		"dragon": true,
		"dragon_id": id,
		"kind": id,
		"hp_mul": 2.0,
		"x_ratio": 0.7,
		"phase": 0.3,
		"stop_ratio": 0.3,
		"wave_amp": 12.0,
		"y_bias": 0.0,
		"spawn_at": at,
	}, _field)
	var enemy := _game._enemies[_game._enemies.size() - 1] as DragonEnemy
	enemy.fire_room = -1
	var player: Vector2 = _game._player.position
	for _i in steps:
		for spec in enemy.tick(0.05, player, 1.0, 1.0):
			_game._spawn_shot(spec, false)
		for extra in enemy.take_spawns():
			_game._spawn_enemy(extra, _field)
	enemy.queue_redraw()
	return enemy

func _bind(a: DragonEnemy, b: DragonEnemy) -> void:
	var allies: Array[EnemyActor] = []
	for enemy in _game._enemies:
		if enemy is DragonEnemy:
			allies.append(enemy)
	a.bind_allies(allies)
	b.bind_allies(allies)

func _spill(slime: DragonEnemy) -> void:
	var visual := slime.death_visual()
	var offset: Vector2 = visual.get("offset", Vector2.ZERO)
	_game._play_sheet(str(visual.get("file", "")), slime.position + offset)
	for spec in slime.death_shots():
		_game._spawn_shot(spec, false)
	if not _game._sheets.is_empty():
		var fx: SheetFx = _game._sheets[_game._sheets.size() - 1]
		fx.age = fx.duration * 0.45
		fx.queue_redraw()
	slime.visible = false

func _redraw() -> void:
	for enemy in _game._enemies:
		if is_instance_valid(enemy):
			enemy.queue_redraw()
	for shot in _game._shots:
		if is_instance_valid(shot):
			shot.queue_redraw()
	if _game._boss_banner != null:
		_game._boss_banner.queue_redraw()

func _save(file_name: String) -> bool:
	if _game != null and _game.has_method("_refresh_hud"):
		_game._refresh_hud()
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image for %s" % file_name)
		quit(1)
		return false
	if image.get_width() < 900:
		image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var path := "/opt/cursor/artifacts/%s" % file_name
	if image.save_png(path) != OK:
		push_error("save failed %s" % path)
		quit(1)
		return false
	print("WROTE %s %sx%s" % [path, image.get_width(), image.get_height()])
	return true
