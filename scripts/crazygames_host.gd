extends Node
class_name CrazyGamesHost

## Talks to the official addon at res://addons/crazygames.
## The autoloads are registered only for the CrazyGames export. Every SDK
## call is skipped unless CrazyGamesBridge.get_environment() is "local" or
## "crazygames", because the SDK throws on any other host.

const INIT_TIMEOUT_MSEC := 15000
const VIEWPORT := Vector2(480, 270)

var _booted := false
var _initialised := false
var _playing := false
var _want_play := false


static func wanted() -> bool:
	return OS.has_feature("crazygames") or OS.has_feature("CRAZYGAMES")


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


func _boot() -> void:
	if _booted:
		return
	_booted = true
	var cg := get_node_or_null("/root/CrazyGames")
	if cg == null:
		push_warning("CrazyGames autoload is missing. Run tools/prepare_crazygames_export.py before this export.")
		return
	var started := Time.get_ticks_msec()
	while not bool(cg.get("is_initialised")) and Time.get_ticks_msec() - started < INIT_TIMEOUT_MSEC:
		await get_tree().process_frame
	_initialised = bool(cg.get("is_initialised"))
	if _initialised:
		_flush()


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
