extends SceneTree

## Hop mode stays off the default boot, keeps its own best scores, and a run
## can tick. godot --headless --path . -s res://tests/hop_smoke.gd

var _failed := 0
var _done := false

func _initialize() -> void:
	_failed += _check_flags()
	_failed += _check_hook()
	_failed += _check_scores()
	_failed += _check_gates()
	_failed += _check_art()
	_failed += _check_split()
	_failed += _check_idle()
	_failed += _check_bot_bounds()

func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	# The tree is ready here, so the hop scene's _ready runs on add_child.
	_failed += _check_scene()
	if _failed > 0:
		push_error("%d hop smoke checks failed" % _failed)
		quit(1)
		return true
	print("HOP_SMOKE_OK")
	quit(0)
	return true

func _check_flags() -> int:
	var failed := 0
	HopMode.reset_for_test(PackedStringArray(), "")
	if HopMode.requested():
		push_error("hop mode activated with no flag")
		failed += 1
	HopMode.reset_for_test(PackedStringArray(["--mode=hop"]), "")
	if not HopMode.requested():
		push_error("--mode=hop did not activate hop mode")
		failed += 1
	HopMode.reset_for_test(PackedStringArray(["--mode=hop", "--form=goblin", "--seed=7", "--bot=1"]), "")
	if HopMode.forced_form() != FormCatalog.Id.GOBLIN or not HopMode.has_seed() or HopMode.seed_value() != 7 or not HopMode.drive_bot():
		push_error("hop flags did not keep form, seed, and bot")
		failed += 1
	HopMode.reset_for_test(PackedStringArray(), "?mode=hop")
	if not HopMode.requested():
		push_error("?mode=hop did not activate hop mode")
		failed += 1
	HopMode.reset_for_test(PackedStringArray(["--mode=hop"]), "?mode=flappy")
	if HopMode.requested():
		push_error("query string should win when it names another mode")
		failed += 1
	HopMode.reset_for_test(PackedStringArray(["--mode=flappy"]), "?mode=hop&form=slime")
	if not HopMode.requested() or HopMode.forced_form() != FormCatalog.Id.SLIME:
		push_error("query ?mode=hop should beat an earlier --mode")
		failed += 1
	HopMode.reset_for_test(PackedStringArray(), "")
	return failed

func _check_hook() -> int:
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var hop_at := src.find("HopMode.redirect")
	var boot_at := src.find("CaptureMode.boot")
	var flap_at := src.find("FlappyMode.attach(self)")
	if hop_at < 0 or boot_at < 0 or hop_at > boot_at:
		push_error("hop redirect must run before the normal game boot")
		return 1
	if flap_at < 0 or flap_at < boot_at:
		push_error("flappy should still attach during the normal boot")
		return 1
	HopMode.reset_for_test(PackedStringArray(["--mode=flappy"]), "")
	FlappyMode.reset_for_test(PackedStringArray(["--mode=flappy"]), "")
	if HopMode.requested() or not FlappyMode.is_active():
		push_error("mode=flappy must select flappy and leave hop off")
		HopMode.reset_for_test(PackedStringArray(), "")
		FlappyMode.reset_for_test(PackedStringArray(), "")
		return 1
	HopMode.reset_for_test(PackedStringArray(["--mode=hop"]), "")
	FlappyMode.reset_for_test(PackedStringArray(["--mode=hop"]), "")
	if not HopMode.requested() or FlappyMode.is_active():
		push_error("mode=hop must select hop and leave flappy off")
		HopMode.reset_for_test(PackedStringArray(), "")
		FlappyMode.reset_for_test(PackedStringArray(), "")
		return 1
	if HopMode.SAVE_PATH == FlappyMode.SAVE_PATH:
		push_error("hop and flappy best scores must use different files")
		return 1
	HopMode.reset_for_test(PackedStringArray(), "")
	FlappyMode.reset_for_test(PackedStringArray(), "")
	return 0

func _check_scores() -> int:
	if HopMode.SAVE_PATH == BestScores.SAVE_PATH:
		push_error("hop best scores must not use the main score file")
		return 1
	var before := JSON.stringify(BestScores.read())
	var saved := HopMode.record("SLIME", 4321)
	var after := JSON.stringify(BestScores.read())
	if before != after:
		push_error("hop record wrote the main best-score file")
		return 1
	if int(saved["form"]) < 4321 or int(saved["overall"]) < 4321:
		push_error("hop record did not keep the hop score")
		return 1
	if int(HopMode.read_scores().get("SLIME", 0)) < 4321:
		push_error("hop score file missing the slime best")
		return 1
	return 0

func _check_gates() -> int:
	var hop := HopBalance.gates()
	var main := Difficulty.gates()
	if hop.size() != 2 or int(hop[0]) == int(main[0]) or int(hop[1]) == int(main[1]):
		push_error("hop rank gates should be tuned apart from the side-scroller")
		return 1
	if int(hop[1]) < int(hop[0]) * 3:
		push_error("hop rank 3 should be a rare gate, well above rank 2")
		return 1
	return 0

func _check_art() -> int:
	var files := [
		"slime_r1.png",
		"goblin_r1.png",
		"slime_shot.png",
		"slingshot_stone.png",
		"floating_eye.png",
		"dire_wolf.png",
		"skeleton_archer.png",
		"wyvern.png",
		"piano.png",
		"anvil.png",
		"arrow.png",
		"floating_eye_bolt.png",
		"wyvern_shot.png",
		"coin.png",
		"gem.png",
		"bg_near.png",
		"bg_far.png",
		"bg_sky.png",
		"bg_clouds.png",
		"title_cards/title_slime.png",
		"title_cards/title_goblin.png",
		"fx/fx_reborn_tease_card.png",
		"ui/hud_clock_icon.png",
	]
	var failed := 0
	for file in files:
		if ArtLibrary.texture(file) == null:
			push_error("hop art missing %s" % file)
			failed += 1
	return failed

func _check_split() -> int:
	var world := HopWorld.new()
	world.setup(20261101, FormCatalog.Id.SLIME)
	world.invuln = 0.0
	world._hurt_player("falling piano")
	if not world.alive or not world.small or world.split_ready:
		push_error("slime split should spend the trait once and keep the run")
		return 1
	world.invuln = 0.0
	world._hurt_player("falling piano")
	if world.alive or world.killer != "falling piano":
		push_error("a second hit on the small slime should end the run")
		return 1
	var goblin := HopWorld.new()
	goblin.setup(20261101, FormCatalog.Id.GOBLIN)
	if goblin.hop_duration() >= HopBalance.HOP_SLIME:
		push_error("goblin hop should be slightly quicker than the slime hop")
		return 1
	if not goblin.goblin_airborne():
		goblin.try_hop(1, 0)
		goblin.hop_u = 0.5
	if not goblin.goblin_airborne():
		push_error("goblin should leave the ground in the middle of a hop")
		return 1
	return 0

func _check_idle() -> int:
	var world := HopWorld.new()
	world.setup(20261101, FormCatalog.Id.SLIME)
	var steps := 0
	while world.alive and steps < 1200:
		world.tick(1.0 / 60.0)
		steps += 1
	var life := float(steps) / 60.0
	if world.killer != "the road" or life < 2.5 or life > 8.0:
		push_error("idling should lose to the road in a few seconds, got %s at %.2f" % [world.killer, life])
		return 1
	return 0

func _check_scene() -> int:
	var packed := load("res://scenes/hop/hop_main.tscn") as PackedScene
	if packed == null:
		push_error("hop scene did not load")
		return 1
	var node := packed.instantiate()
	root.add_child(node)
	if not (node is HopGame) or node.world == null or node.phase != HopGame.REVEAL:
		push_error("hop scene should open on a title card without replacing a live run")
		node.free()
		return 1
	node.free()
	return 0

func _check_bot_bounds() -> int:
	var failed := 0
	for form in [FormCatalog.Id.SLIME, FormCatalog.Id.GOBLIN]:
		var world := HopWorld.new()
		world.setup(20261107, form)
		var guard := 0
		while world.alive and guard < 4000:
			HopBot.steer(world)
			world.tick(1.0 / 60.0)
			guard += 1
		if world.elapsed < 8.0 or world.elapsed > 70.0:
			push_error("%s bot life %.2f is outside 8-70s on the smoke seed" % [FormCatalog.display_name(form), world.elapsed])
			failed += 1
	return failed
