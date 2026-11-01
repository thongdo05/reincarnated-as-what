extends RefCounted
class_name HopMode

## Experimental hop mode. Off unless the page query or the user args ask for it.
## Web: ?mode=hop. Desktop and headless: --mode=hop (args after --).
## When both are present the query string is applied last, same as CaptureMode.
## Best scores go to their own file so a hop run never writes the main board.

const SCENE_PATH := "res://scenes/hop/hop_main.tscn"
const SAVE_PATH := "user://hop_best_scores.json"

static var _parsed := false
static var _active := false
static var _form_key := ""
static var _has_seed := false
static var _seed_value := 0
static var _bot := false
static var _use_test := false
static var _test_web := ""
static var _test_argv: PackedStringArray = PackedStringArray()

static func requested() -> bool:
	_ensure()
	return _active

static func forced_form() -> int:
	_ensure()
	if _form_key == "slime":
		return FormCatalog.Id.SLIME
	if _form_key == "goblin":
		return FormCatalog.Id.GOBLIN
	return -1

static func has_seed() -> bool:
	_ensure()
	return _has_seed

static func seed_value() -> int:
	_ensure()
	return _seed_value

static func drive_bot() -> bool:
	_ensure()
	return _active and _bot

## Leaves the host unprocessed and swaps in the hop scene. False when the
## launch is a normal game, so the caller continues the side-scroller boot.
static func redirect(host: Node) -> bool:
	if not requested():
		return false
	if host == null or not host.is_inside_tree():
		return false
	var packed := load(SCENE_PATH) as PackedScene
	host.process_mode = Node.PROCESS_MODE_DISABLED
	if packed == null:
		push_error("hop scene missing at %s" % SCENE_PATH)
		return true
	# The main scene is still entering the tree. Changing it inline tries to
	# remove that node mid-add.
	host.get_tree().call_deferred("change_scene_to_packed", packed)
	return true

static func reset_for_test(argv: PackedStringArray, web: String = "") -> void:
	_parsed = false
	_active = false
	_form_key = ""
	_has_seed = false
	_seed_value = 0
	_bot = false
	_use_test = true
	_test_web = web
	_test_argv = argv

static func read_scores() -> Dictionary:
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

static func record(form_name: String, score: int) -> Dictionary:
	var saved := read_scores()
	saved[form_name] = maxi(int(saved.get(form_name, 0)), score)
	saved["overall"] = maxi(int(saved.get("overall", 0)), score)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(saved))
		file.close()
	return {
		"form": int(saved.get(form_name, 0)),
		"overall": int(saved.get("overall", 0)),
	}

static func _ensure() -> void:
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
			"mode":
				_active = value.to_lower() == "hop"
			"form":
				var form := value.to_lower()
				if form == "slime" or form == "goblin":
					_form_key = form
			"seed":
				if value.is_valid_int():
					_has_seed = true
					_seed_value = int(value)
			"bot":
				_bot = value == "1"
