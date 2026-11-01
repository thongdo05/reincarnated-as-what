extends SceneTree

## Capture-mode flags. Run with: godot --headless -s res://tests/capture_check.gd

var _failed := 0
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_failed += _check_parse()
	_failed += _check_noop_files()
	_failed += _check_rank_and_clean()
	_failed += _check_unplayable()
	_failed += _check_evo()
	_failed += _check_piano()
	if _failed > 0:
		push_error("%d capture checks failed" % _failed)
		quit(1)
		return true
	print("CAPTURE_OK")
	quit(0)
	return true

func _check_parse() -> int:
	var failed := 0
	failed += _boot_case(PackedStringArray(), "", false, "")
	failed += _boot_case(PackedStringArray(["--form=goblin", "--rank=3", "--seed=42", "--clean=1"]), "", true, "form=goblin")
	failed += _boot_case(PackedStringArray(["--form=slime"]), "?form=cat&hazard=piano&hazard_t=8&evo=1&invuln=1", true, "form=cat")
	CaptureMode.reset_for_test(PackedStringArray(["--form=slime"]), "?form=cat&hazard=piano&hazard_t=8&evo=1&invuln=1")
	var text := CaptureMode.summary()
	if text.find("hazard=piano") < 0 or text.find("hazard_t=8") < 0 or text.find("form=slime") >= 0:
		push_error("the query string should win and keep the other flags (%s)" % text)
		failed += 1
	failed += _boot_case(PackedStringArray(["--form=nope", "--clean=0", "--hazard_t=3"]), "", false, "")
	return failed

func _boot_case(argv: PackedStringArray, web: String, active: bool, needle: String) -> int:
	CaptureMode.reset_for_test(argv, web)
	var node := _stub()
	CaptureMode.boot(node)
	var failed := 0
	if CaptureMode.is_active() != active:
		push_error("active=%s for %s %s" % [str(active), str(argv), web])
		failed += 1
	if needle != "" and CaptureMode.summary().find(needle) < 0:
		push_error("summary missing %s (%s)" % [needle, CaptureMode.summary()])
		failed += 1
	node.free()
	return failed

func _stub() -> Node2D:
	var node := Node2D.new()
	node.set_script(load("res://scripts/game.gd"))
	return node

func _check_noop_files() -> int:
	var failed := 0
	var daily_path := ProjectSettings.globalize_path("user://daily_run.json")
	var best_path := ProjectSettings.globalize_path("user://best_scores.json")
	var daily_before := FileAccess.get_file_as_string(daily_path)
	var best_before := FileAccess.get_file_as_string(best_path)
	CaptureMode.reset_for_test(PackedStringArray(["--form=slime", "--seed=7", "--clean=1"]))
	var game := _game()
	var daily_after := FileAccess.get_file_as_string(daily_path)
	if daily_after != daily_before:
		push_error("a capture run should not write the daily index")
		failed += 1
	if int(game.day_seed) != 7 or int(game.form_id) != FormCatalog.Id.SLIME:
		push_error("seed and form were not forced (seed %s form %s)" % [str(game.day_seed), str(game.form_id)])
		failed += 1
	game.score = 99999
	game.phase = game.PHASE_DEAD
	game._show_game_over()
	var best_after := FileAccess.get_file_as_string(best_path)
	if best_after != best_before:
		push_error("a capture run should not write best scores")
		failed += 1
	_free(game)
	CaptureMode.reset_for_test(PackedStringArray())
	var plain := _game()
	var daily_plain := FileAccess.get_file_as_string(daily_path)
	if daily_plain == daily_before:
		push_error("a normal run should still consume the daily index")
		failed += 1
	if CaptureMode.is_active():
		push_error("the cleared flags should not stay active")
		failed += 1
	_free(plain)
	_restore(daily_path, daily_before)
	_restore(best_path, best_before)
	return failed

func _check_rank_and_clean() -> int:
	var failed := 0
	CaptureMode.reset_for_test(PackedStringArray(["--form=goblin", "--rank=3", "--clean=1", "--seed=3"]))
	var game := _game()
	if int(game.rank_index) != 2 or game._player.sprite_name() != "goblin_r3.png":
		push_error("rank 3 should start on the goblin king (%s rank %s)" % [game._player.sprite_name(), str(game.rank_index)])
		failed += 1
	if int(game.evo_points) != int(FormCatalog.rank_gates()[1]):
		push_error("rank 3 should start with the meter already full")
		failed += 1
	HitLibrary.show = true
	game._debug_on = true
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_H
	game._unhandled_input(key)
	key.keycode = KEY_D
	game._unhandled_input(key)
	if HitLibrary.show or game._debug_on or game._debug_label.visible:
		push_error("clean=1 should hide hitboxes and the D overlay and block those keys")
		failed += 1
	_free(game)
	HitLibrary.show = false
	return failed

func _check_unplayable() -> int:
	var failed := 0
	CaptureMode.reset_for_test(PackedStringArray(["--form=cat", "--seed=3"]))
	var game := _game()
	if int(game.form_id) != FormCatalog.Id.CAT:
		push_error("cat should boot as a playable form")
		failed += 1
	if game._title_card.texture != ArtLibrary.texture("title_cards/title_cat.png"):
		push_error("the cat reveal should use the cat title card")
		failed += 1
	if game._sound.played.find("reveal_vending_machine") >= 0:
		push_error("the cat card has no sting")
		failed += 1
	for _i in 120:
		game._process(1.0 / 60.0)
	if CaptureMode.holding() or int(game.phase) == game.PHASE_REVEAL:
		push_error("cat should leave the title card and play")
		failed += 1
	if float(game.elapsed) <= 0.0:
		push_error("cat should start gameplay")
		failed += 1
	for child in game._hud.get_children():
		if child is Label and str(child.text).find("NOT PLAYABLE YET") >= 0:
			push_error("cat should not show the locked card")
			failed += 1
	_free(game)
	CaptureMode.reset_for_test(PackedStringArray(["--form=vending_machine"]))
	var vending := _game()
	if int(vending.form_id) != FormCatalog.Id.VENDING:
		push_error("vending machine should boot playable")
		failed += 1
	if vending._sound.played.find("reveal_vending_machine") < 0:
		push_error("the vending machine reveal should play its sting")
		failed += 1
	if vending._title_card.texture != ArtLibrary.texture("title_cards/title_vending_machine.png"):
		push_error("the vending machine reveal should use its title card")
		failed += 1
	_free(vending)
	CaptureMode.reset_for_test(PackedStringArray(["--form=demon_lord", "--seed=5"]))
	var demon := _game()
	if int(demon.form_id) != FormCatalog.Id.DEMON or demon._player.sprite_name() != "demon_lord_r1.png":
		push_error("demon lord should boot on its rank 1 sprite")
		failed += 1
	_free(demon)
	CaptureMode.reset_for_test(PackedStringArray())
	return failed

func _check_evo() -> int:
	var failed := 0
	CaptureMode.reset_for_test(PackedStringArray(["--form=slime", "--evo=1", "--invuln=1", "--seed=1"]))
	var game := _game()
	game._begin_play()
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_E
	game._unhandled_input(key)
	if int(game.rank_index) != 1 or game._player.fx_mode != "glow":
		push_error("E should reach rank 2 through the real evolve")
		failed += 1
	game._unhandled_input(key)
	if int(game.rank_index) != 2 or not game._player.evolve_final:
		push_error("a second E should reach the final form")
		failed += 1
	game._hurt_player("falling anvil")
	if int(game.phase) != game.PHASE_PLAY:
		push_error("invuln=1 should ignore hits")
		failed += 1
	_free(game)
	return failed

func _check_piano() -> int:
	var failed := 0
	CaptureMode.reset_for_test(PackedStringArray(["--form=slime", "--hazard=piano", "--hazard_t=6", "--seed=11"]))
	var game := _game()
	var step := 1.0 / 60.0
	for _i in 700:
		if int(game.phase) == game.PHASE_DEAD:
			break
		game._process(step)
	if int(game.phase) != game.PHASE_DEAD or str(game.killer_name) != "falling piano":
		push_error("the piano should be the hit that ends the run (phase %s killer %s t %.2f)" % [str(game.phase), str(game.killer_name), float(game.elapsed)])
		failed += 1
	elif absf(float(game.elapsed) - (6.0 - float(game.REVEAL_SECONDS))) > 0.2:
		push_error("the piano should land near 6s from the start (play t %.2f)" % float(game.elapsed))
		failed += 1
	_free(game)
	return failed

func _game() -> Node:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	return game

func _free(game: Node) -> void:
	if game.get_parent() != null:
		game.get_parent().remove_child(game)
	game.free()

func _restore(path: String, contents: String) -> void:
	if contents == "":
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(contents)
	file.close()
