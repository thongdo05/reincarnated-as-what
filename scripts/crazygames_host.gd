extends Node
class_name CrazyGamesHost

## Talks to the official addon at res://addons/crazygames.
## The autoloads are registered only for the CrazyGames export. Every SDK
## call is skipped unless CrazyGamesBridge.get_environment() is "local" or
## "crazygames", because the SDK throws on any other host.

const INIT_TIMEOUT_MSEC := 15000
const VIEWPORT := Vector2(480, 270)
## SDK data keys. Only the CrazyGames build reads or writes these.
const CLOUD_BEST := "best_scores"
const CLOUD_DAILY := "daily_run"
const CLOUD_PROFILE := "leaderboard"
const CLOUD_AUDIO := "audio"
const CLOUD_PRIVACY := "privacy_notice"
const PRIVACY_URL := "https://thongdo05.github.io/reincarnated-as-what/privacy.html"
const PRIVACY_FILE := "user://crazygames_privacy_seen.txt"

signal launch_ready

## -1 follows the export feature. Tests set 0 or 1. A normal build leaves this at -1.
static var _force_wanted := -1
static var _test_store_on := false
static var _cloud_loaded := false
static var _cloud_memory: Dictionary = {}
static var _invite_override := ""
static var _test_params: Dictionary = {}
static var _suggested_name := ""

var _booted := false
var _initialised := false
var _playing := false
var _want_play := false
var _launch_done := false
var _invite_params: Dictionary = {}


static func wanted() -> bool:
	if _force_wanted >= 0:
		return _force_wanted == 1
	return OS.has_feature("crazygames") or OS.has_feature("CRAZYGAMES")


static func force_for_test(mode: int) -> void:
	_force_wanted = mode
	if mode != 1:
		_test_store_on = false
		_cloud_loaded = false
		_cloud_memory.clear()
		_invite_override = ""
		_test_params.clear()
		_suggested_name = ""


static func use_memory_store_for_test(seed: Dictionary = {}) -> void:
	_force_wanted = 1
	_test_store_on = true
	_cloud_loaded = true
	_cloud_memory = seed.duplicate(true)


static func set_invite_override_for_test(url: String) -> void:
	_invite_override = url


static func set_invite_params_for_test(params: Dictionary) -> void:
	_test_params = params.duplicate(true)


static func set_suggested_name_for_test(name: String) -> void:
	_suggested_name = name


static func suggested_name() -> String:
	return _suggested_name


static func cloud_handles() -> bool:
	return wanted() and _cloud_loaded


static func cloud_get(key: String) -> String:
	return str(_cloud_memory.get(key, ""))


static func cloud_set(key: String, value: String) -> void:
	if not cloud_handles():
		return
	_cloud_memory[key] = value
	if _test_store_on:
		return
	var host := _live_host()
	if host != null:
		host._sdk_set(key, value)


## Cloud wins when the key is already in the SDK. Otherwise the local file is the one-time copy.
static func migrated_value(has_cloud: bool, cloud_value: String, file_body: String) -> String:
	if has_cloud:
		return cloud_value
	return file_body


static func cloud_flag(key: String, default_on: bool) -> bool:
	var raw := cloud_get(key).strip_edges().to_lower()
	if raw == "":
		return default_on
	if raw == "1" or raw == "true":
		return true
	if raw == "0" or raw == "false":
		return false
	return default_on


## A CrazyGames invite link is usable when the SDK returned an http(s) URL
## that is not the GitHub Pages game. An empty result (local preview, SDK
## disabled) hides Challenge instead of copying an outside link.
static func invite_link_usable(url: String) -> bool:
	var link := url.strip_edges()
	if link == "":
		return false
	var lower := link.to_lower()
	if lower.find("github.io") >= 0 or lower.find("thongdo05") >= 0:
		return false
	return lower.begins_with("https://") or lower.begins_with("http://")


static func challenge_visible(crazygames: bool, invite_url: String) -> bool:
	if not crazygames:
		return true
	return invite_link_usable(invite_url)


static func shows_privacy_notice(crazygames: bool, seen: bool) -> bool:
	return crazygames and not seen


static func username_from_user(user: Dictionary) -> String:
	var sources: Array[Dictionary] = [user]
	if user.get("user") is Dictionary:
		sources.append(user["user"])
	for source in sources:
		for key in ["username", "userName"]:
			if not source.has(key):
				continue
			var clean := Leaderboard.clean_name(str(source[key]))
			if clean != "" and Leaderboard.local_name_error(clean) == "":
				return clean
	return ""


static func _live_host() -> CrazyGamesHost:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	var tree := loop as SceneTree
	if tree.root == null:
		return null
	var found := tree.root.find_child("CrazyGamesHost", true, false)
	return found as CrazyGamesHost


## True only for the two environments where SDK methods are allowed to run.
static func call_allowed(environment: String) -> bool:
	return environment == "local" or environment == "crazygames"


## How many screen pixels one viewport pixel becomes.
## Integer scale is what GitHub Pages and the phone builds use.
## The CrazyGames export switches the root window to fractional so an
## 800x450 iframe fills the 480x270 view instead of letterboxing at 1x.
static func presented_scale(window: Vector2, viewport: Vector2, integer_scale: bool) -> float:
	if viewport.x < 1.0 or viewport.y < 1.0 or window.x < 1.0 or window.y < 1.0:
		return 1.0
	var fitted := _fitted_window(window, viewport)
	var fit := minf(fitted.x / viewport.x, fitted.y / viewport.y)
	if integer_scale:
		return maxf(floorf(fit), 1.0)
	return maxf(fit, 0.01)


static func glyph_css_px(glyph_px: float, window: Vector2, viewport: Vector2, integer_scale: bool) -> float:
	return glyph_px * presented_scale(window, viewport, integer_scale)


## Shrink the engine safe rect by CSS safe-area insets, in window pixels.
## A zero CSS inset leaves the engine rect alone.
static func merge_safe_rect(window: Vector2, engine_safe: Rect2, css_insets: Vector4) -> Rect2:
	var safe := engine_safe
	if safe.size.x < 1.0 or safe.size.y < 1.0:
		safe = Rect2(Vector2.ZERO, window)
	if css_insets == Vector4.ZERO:
		return safe
	var left := maxf(safe.position.x, css_insets.x)
	var top := maxf(safe.position.y, css_insets.y)
	var right := minf(safe.position.x + safe.size.x, window.x - css_insets.z)
	var bottom := minf(safe.position.y + safe.size.y, window.y - css_insets.w)
	if right - left < 1.0 or bottom - top < 1.0:
		return safe
	return Rect2(left, top, right - left, bottom - top)


static func _fitted_window(window: Vector2, viewport: Vector2) -> Vector2:
	var viewport_aspect := viewport.x / viewport.y
	var window_aspect := window.x / window.y
	if is_equal_approx(viewport_aspect, window_aspect):
		return window
	if viewport_aspect < window_aspect:
		return Vector2(window.y * viewport_aspect, window.y)
	return Vector2(window.x, window.x / viewport_aspect)


func _ready() -> void:
	if not wanted():
		return
	_boot()


func gameplay_start() -> void:
	_want_play = true
	_flush()


func gameplay_stop() -> void:
	_want_play = false
	_flush()


func happy_time() -> void:
	if not _can_call():
		return
	var game := _game_module()
	if game != null and game.has_method("happy_time"):
		game.happy_time()


## Window pixels. "l,t,r,b" from the page, or zero when the probe is absent.
func css_insets() -> Vector4:
	if not wanted() or not OS.has_feature("web"):
		return Vector4.ZERO
	var raw = JavaScriptBridge.eval("window.rawSafeInsets ? window.rawSafeInsets() : '0,0,0,0'", true)
	return _parse_insets(str(raw) if raw != null else "")


static func _parse_insets(raw: String) -> Vector4:
	var parts := raw.split(",")
	if parts.size() != 4:
		return Vector4.ZERO
	var values: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i in 4:
		if not parts[i].is_valid_float():
			return Vector4.ZERO
		values[i] = maxf(float(parts[i]), 0.0)
	return Vector4(values[0], values[1], values[2], values[3])


func ready_for_launch() -> void:
	if _launch_done:
		return
	await launch_ready


func launch_query() -> String:
	var parts: PackedStringArray = []
	var seed := str(_invite_params.get("seed", "")).strip_edges()
	var form := str(_invite_params.get("form", "")).strip_edges().to_lower()
	if seed != "" and seed.is_valid_int():
		parts.append("seed=%s" % seed)
	if form != "" and FormCatalog.id_from_key(form) >= 0:
		parts.append("form=%s" % form.uri_encode())
	return "&".join(parts)


func current_invite_url(seed_value: int, form_key: String) -> String:
	if _invite_override != "":
		return _invite_override
	if not _can_call():
		return ""
	var game := _game_module()
	if game == null or not game.has_method("request_invite_url"):
		return ""
	var raw = game.call("request_invite_url", Replay.invite_params(seed_value, form_key))
	if raw == null:
		return ""
	var text := str(raw).strip_edges()
	if text == "" or text.to_lower() == "null":
		return ""
	return text


func privacy_seen() -> bool:
	if cloud_handles():
		return cloud_get(CLOUD_PRIVACY) == "1"
	if not wanted():
		return true
	return FileAccess.file_exists(PRIVACY_FILE)


func mark_privacy_seen() -> void:
	if not wanted():
		return
	if cloud_handles():
		cloud_set(CLOUD_PRIVACY, "1")
		return
	var file := FileAccess.open(PRIVACY_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("1")
	file.close()


func _boot() -> void:
	if _booted:
		return
	_booted = true
	if _test_store_on:
		_read_invite_params()
		_finish_launch()
		return
	var cg := get_node_or_null("/root/CrazyGames")
	if cg == null:
		push_warning("CrazyGames autoload is missing. Run tools/prepare_crazygames_export.py before this export.")
		_read_invite_params()
		_finish_launch()
		return
	var started := Time.get_ticks_msec()
	while not bool(cg.get("is_initialised")) and Time.get_ticks_msec() - started < INIT_TIMEOUT_MSEC:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_initialised = bool(cg.get("is_initialised"))
	_read_invite_params()
	if _initialised and _data_usable():
		_load_cloud()
		_flush()
		_fetch_username()
	_finish_launch()


func _finish_launch() -> void:
	_launch_done = true
	launch_ready.emit()


func _read_invite_params() -> void:
	_invite_params = {}
	for key in _test_params.keys():
		_invite_params[str(key)] = str(_test_params[key])
	if not OS.has_feature("web"):
		return
	for key in ["seed", "form"]:
		if str(_invite_params.get(key, "")).strip_edges() != "":
			continue
		var value := _invite_param(key)
		if value != "":
			_invite_params[key] = value


func _invite_param(param_name: String) -> String:
	var bridge := get_node_or_null("/root/CrazyGamesBridge")
	if bridge != null and bridge.has_method("get_invite_link_param"):
		var value = bridge.call("get_invite_link_param", param_name)
		return str(value).strip_edges() if value != null else ""
	return ""


func _data_module() -> Object:
	var cg := get_node_or_null("/root/CrazyGames")
	if cg == null:
		return null
	var data = cg.get("Data")
	return data if data is Object else null


func _data_usable() -> bool:
	if not _can_call() or not OS.has_feature("web"):
		return false
	var probe = JavaScriptBridge.eval("(function(){ try { if (!window.CrazyGames || !window.CrazyGames.SDK || !window.CrazyGames.SDK.data || typeof window.CrazyGames.SDK.data.getItem !== 'function') return 'missing'; window.CrazyGames.SDK.data.getItem('best_scores'); return 'ok'; } catch (e) { return 'error'; } })()", true)
	return str(probe) == "ok"


func _load_cloud() -> void:
	var files := {
		CLOUD_BEST: BestScores.SAVE_PATH,
		CLOUD_DAILY: DailyRun.SAVE_PATH,
		CLOUD_PROFILE: Leaderboard.PROFILE_PATH,
	}
	for key in files.keys():
		var has_cloud := _sdk_has(str(key))
		var cloud_value := _sdk_get(str(key)) if has_cloud else ""
		var path := str(files[key])
		var file_body := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var chosen := migrated_value(has_cloud, cloud_value, file_body)
		if has_cloud:
			_cloud_memory[key] = chosen
		elif chosen.strip_edges() != "" and _sdk_set(str(key), chosen):
			_cloud_memory[key] = chosen
	if _sdk_has(CLOUD_AUDIO):
		_cloud_memory[CLOUD_AUDIO] = _sdk_get(CLOUD_AUDIO)
	elif FileAccess.file_exists(AudioCues.SETTINGS_PATH):
		var on := AudioCues.read_enabled(AudioCues.SETTINGS_PATH)
		var flag := "1" if on else "0"
		if _sdk_set(CLOUD_AUDIO, flag):
			_cloud_memory[CLOUD_AUDIO] = flag
	if _sdk_has(CLOUD_PRIVACY):
		_cloud_memory[CLOUD_PRIVACY] = _sdk_get(CLOUD_PRIVACY)
	_cloud_loaded = true


func _sdk_has(key: String) -> bool:
	var data := _data_module()
	if data == null or not data.has_method("data_has_key"):
		return false
	return bool(data.call("data_has_key", key))


func _sdk_get(key: String) -> String:
	var data := _data_module()
	if data == null or not data.has_method("data_get_item"):
		return ""
	var value = data.call("data_get_item", key)
	return str(value) if value != null else ""


func _sdk_set(key: String, value: String) -> bool:
	var data := _data_module()
	if data == null or not data.has_method("data_set_item"):
		return false
	return bool(data.call("data_set_item", key, value))


func _fetch_username() -> void:
	if not _can_call():
		return
	var cg := get_node_or_null("/root/CrazyGames")
	if cg == null:
		return
	var user_mod = cg.get("User")
	if user_mod == null or not user_mod.has_method("get_user_async"):
		return
	var result = await user_mod.get_user_async()
	if not is_inside_tree() or typeof(result) != TYPE_DICTIONARY:
		return
	var clean := username_from_user(result)
	if clean != "":
		_suggested_name = clean


func _can_call() -> bool:
	if not wanted() or not _initialised or not OS.has_feature("web"):
		return false
	return call_allowed(_environment())


func _environment() -> String:
	var bridge := get_node_or_null("/root/CrazyGamesBridge")
	if bridge == null or not bridge.has_method("get_environment"):
		return "disabled"
	var env = bridge.call("get_environment")
	if env == null:
		return "disabled"
	return str(env)


func _game_module() -> Object:
	var cg := get_node_or_null("/root/CrazyGames")
	if cg == null:
		return null
	var game = cg.get("Game")
	return game if game is Object else null


func _flush() -> void:
	if not _initialised:
		return
	if not _can_call():
		return
	var game := _game_module()
	if game == null:
		return
	if _want_play and not _playing and game.has_method("gameplay_start"):
		game.gameplay_start()
		_playing = true
	elif not _want_play and _playing and game.has_method("gameplay_stop"):
		game.gameplay_stop()
		_playing = false
