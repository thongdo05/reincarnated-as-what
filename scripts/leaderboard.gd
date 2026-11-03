extends Node
class_name Leaderboard

## Online bests. One device id lives in user:// next to the local bests.
## The publishable key is public by design. Never put a service_role or
## secret key in this client.

const PROFILE_PATH := "user://leaderboard.json"
const URL := "https://piayoqekmrhqfuhhvexg.supabase.co"
const PUBLISHABLE_KEY := "sb_publishable_0p0UqM_GPBLuLohH9d5q1Q_ode-jvwM"
const FORMAT_HINT := "Use 1-12 letters, numbers, spaces, _ or -."
const REJECTED_NAME := "That name isn't allowed, try another"
const UNREACHABLE := "Can't reach leaderboard - tap to retry"
const SCORE_NOT_POSTED := "score not posted"
const RETRY_SECONDS := 3.2
const REQUEST_TIMEOUT := 15.0
## Two extra tries after the first failure. Transport, timeout, 5xx, and 429 only.
const NETWORK_BACKOFF: Array[float] = [0.8, 2.0]

static func should_submit() -> bool:
	# Every finished run can post, including a challenged form.
	return true

static func clean_name(raw: String) -> String:
	var collapsed := raw.replace("\t", " ").replace("\n", " ").replace("\r", " ")
	while collapsed.find("  ") >= 0:
		collapsed = collapsed.replace("  ", " ")
	return collapsed.strip_edges()

## Length and character set only. The server decides which names are allowed.
static func local_name_error(raw: String) -> String:
	var clean := clean_name(raw)
	if clean.length() < 1 or clean.length() > 12:
		return FORMAT_HINT
	var pattern := RegEx.new()
	if pattern.compile("^[A-Za-z0-9 _-]+$") != OK or pattern.search(clean) == null:
		return FORMAT_HINT
	return ""

static func encode_rpc(body: Dictionary) -> String:
	var json := JSON.stringify(body)
	if not body.has("p_form") or body["p_form"] != null:
		return json
	if json.find("\"p_form\":null") >= 0 or json.find("\"p_form\": null") >= 0:
		return json
	# Overall board. A missing key is not the same as JSON null on this API.
	if json == "{}":
		return "{\"p_form\":null}"
	return json.substr(0, json.length() - 1) + ",\"p_form\":null}"

static func short_form(key: String) -> String:
	match key:
		"goblin":
			return "GOBLIN"
		"vending_machine":
			return "VEND"
		"cat":
			return "CAT"
		"demon_lord":
			return "DEMON"
		"slime":
			return "SLIME"
		_:
			return key.to_upper()

func player_name() -> String:
	return clean_name(str(_read().get("name", "")))

func has_posted() -> bool:
	return bool(_read().get("posted", false))

func device_id() -> String:
	var data := _read()
	var id := str(data.get("device_id", ""))
	if id == "":
		id = _uuid_v4()
		data["device_id"] = id
		_write(data)
	return id

func set_local_name(raw: String) -> String:
	var data := _read()
	if str(data.get("device_id", "")) == "":
		data["device_id"] = _uuid_v4()
	var clean := clean_name(raw)
	data["name"] = clean
	_write(data)
	return clean

func submit_score(form: String, score_value: int, survival_ms: int, done: Callable) -> void:
	_rpc("submit_score", {
		"p_device_id": device_id(),
		"p_name": player_name(),
		"p_form": form,
		"p_score": score_value,
		"p_survival_ms": survival_ms,
	}, func(parsed: Dictionary) -> void:
		if bool(parsed.get("ok", false)):
			_mark_posted(str(parsed.get("data", {}).get("name", player_name())))
		if done.is_valid():
			done.call(parsed)
	)

func set_remote_name(raw: String, done: Callable) -> void:
	var clean := clean_name(raw)
	_rpc("set_name", {
		"p_device_id": device_id(),
		"p_name": clean,
	}, func(parsed: Dictionary) -> void:
		if bool(parsed.get("ok", false)):
			_mark_posted(str(parsed.get("data", {}).get("name", clean)))
		if done.is_valid():
			done.call(parsed)
	)

func fetch_board(form: Variant, period: String, done: Callable) -> void:
	var form_value: Variant = null if str(form) == "" else form
	_rpc("get_leaderboard", {
		"p_form": form_value,
		"p_period": "daily" if period == "daily" else "all",
		"p_limit": 50,
		"p_device_id": device_id(),
	}, done, 0, "board", _bump("board"))

func fetch_rank(form: Variant, period: String, done: Callable) -> void:
	var form_value: Variant = null if form == null or str(form) == "" else form
	_rpc("get_my_rank", {
		"p_device_id": device_id(),
		"p_form": form_value,
		"p_period": "daily" if period == "daily" else "all",
	}, done, 0, "rank", _bump("rank"))

func set_page_cover(on: bool) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if (window.lbSetCover) window.lbSetCover(%s);" % ("true" if on else "false"), true)

func call_later(seconds: float, action: Callable) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(seconds, 0.05)
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(timer)
	timer.timeout.connect(func() -> void:
		timer.queue_free()
		if action.is_valid():
			action.call()
	, CONNECT_ONE_SHOT)
	timer.start()

## How long "..." may stay up. A hung web request never calls back, so the
## screen must give up on its own instead of waiting out every retry.
static func loading_limit() -> float:
	return REQUEST_TIMEOUT + 1.0

var _js_http: JavaScriptObject
var _js_wait: Dictionary = {}
var _js_seq := 0
var _live: Dictionary = {}
var _kind_gen: Dictionary = {}

func _bump(kind: String) -> int:
	if _live.has(kind):
		var node: Variant = _live[kind]
		_live.erase(kind)
		if typeof(node) == TYPE_OBJECT and is_instance_valid(node) and node is HTTPRequest:
			(node as HTTPRequest).cancel_request()
			(node as Node).queue_free()
	_kind_gen[kind] = int(_kind_gen.get(kind, 0)) + 1
	return int(_kind_gen[kind])

func _current(kind: String, gen: int) -> bool:
	return kind == "" or int(_kind_gen.get(kind, 0)) == gen

## One request node at a time per kind. The web export posts with fetch().text()
## because Godot's HTTP client reads response.body.getReader(), and iPhone
## Safari can leave that read pending so request_completed never fires.
func _rpc(method: String, body: Dictionary, done: Callable, attempt: int = 0, kind: String = "", gen: int = 0) -> void:
	if not _current(kind, gen):
		return
	if OS.has_feature("web") and _web_post_ready():
		_rpc_web(method, body, done, attempt, kind, gen)
		return
	_rpc_http(method, body, done, attempt, kind, gen)

func _web_post_ready() -> bool:
	var ready: Variant = JavaScriptBridge.eval("typeof window.lbPost === 'function'", true)
	return bool(ready)

func _rpc_web(method: String, body: Dictionary, done: Callable, attempt: int, kind: String, gen: int) -> void:
	_bind_js_http()
	_js_seq += 1
	var id := _js_seq
	_js_wait[id] = {
		"method": method,
		"body": body,
		"done": done,
		"attempt": attempt,
		"kind": kind,
		"gen": gen,
	}
	if kind != "":
		_live[kind] = id
	var url := "%s/rest/v1/rpc/%s" % [URL, method]
	var headers := [
		["apikey", PUBLISHABLE_KEY],
		["Content-Type", "application/json"],
		["Accept", "application/json"],
	]
	JavaScriptBridge.eval(
		"window.lbPost(%s,%s,%s,%d,%d);" % [
			JSON.stringify(url),
			JSON.stringify(headers),
			JSON.stringify(encode_rpc(body)),
			int(REQUEST_TIMEOUT * 1000.0),
			id,
		],
		true
	)

func _bind_js_http() -> void:
	if _js_http != null:
		return
	_js_http = JavaScriptBridge.create_callback(_on_js_http)
	JavaScriptBridge.get_interface("window").__lbHttp = _js_http

func _on_js_http(args: Array) -> void:
	if args.size() < 3:
		return
	var id := int(args[0])
	if not _js_wait.has(id):
		return
	var job: Dictionary = _js_wait[id]
	_js_wait.erase(id)
	var kind := str(job.get("kind", ""))
	var gen := int(job.get("gen", 0))
	if kind != "" and _live.get(kind) == id:
		_live.erase(kind)
	if not _current(kind, gen):
		return
	var status := int(args[1])
	var text := str(args[2])
	var result := HTTPRequest.RESULT_SUCCESS if status > 0 else HTTPRequest.RESULT_CANT_CONNECT
	var parsed := parse_response(result, status, text.to_utf8_buffer())
	_finish_rpc(str(job.get("method", "")), job.get("body", {}), job.get("done", Callable()), int(job.get("attempt", 0)), parsed, kind, gen)

func _rpc_http(method: String, body: Dictionary, done: Callable, attempt: int, kind: String, gen: int) -> void:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	http.use_threads = false
	http.accept_gzip = false
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)
	for child in http.get_children():
		child.process_mode = Node.PROCESS_MODE_ALWAYS
	if kind != "":
		_live[kind] = http
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, resp: PackedByteArray) -> void:
		if kind != "" and _live.get(kind) == http:
			_live.erase(kind)
		var parsed := parse_response(result, code, resp)
		if is_instance_valid(http):
			http.queue_free()
		if not _current(kind, gen):
			return
		_finish_rpc(method, body, done, attempt, parsed, kind, gen)
	, CONNECT_ONE_SHOT)
	var err := http.request(
		"%s/rest/v1/rpc/%s" % [URL, method],
		["apikey: %s" % PUBLISHABLE_KEY, "Content-Type: application/json", "Accept: application/json"],
		HTTPClient.METHOD_POST,
		encode_rpc(body)
	)
	if err != OK:
		if kind != "" and _live.get(kind) == http:
			_live.erase(kind)
		http.queue_free()
		if _current(kind, gen):
			_finish_rpc(method, body, done, attempt, {"ok": false, "error": "offline", "rows": [], "data": {}}, kind, gen)

func _finish_rpc(method: String, body: Dictionary, done: Callable, attempt: int, parsed: Dictionary, kind: String = "", gen: int = 0) -> void:
	if not _current(kind, gen):
		return
	var delay := next_retry_delay(attempt) if is_network_error(parsed) else -1.0
	if delay >= 0.0:
		call_later(delay, func() -> void:
			_rpc(method, body, done, attempt + 1, kind, gen)
		)
		return
	if done.is_valid():
		done.call(parsed)

static func is_network_error(parsed: Dictionary) -> bool:
	return str(parsed.get("error", "")) == "offline"

## Seconds to wait before extra attempt `attempt` (0 then 1). -1 when the
## two extra tries are already used.
static func next_retry_delay(attempt: int) -> float:
	if attempt < 0 or attempt >= NETWORK_BACKOFF.size():
		return -1.0
	return float(NETWORK_BACKOFF[attempt])

static func parse_response(result: int, code: int, resp: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS or code == 429 or code >= 500:
		return {"ok": false, "error": "offline", "rows": [], "data": {}}
	var text := resp.get_string_from_utf8().strip_edges()
	if code < 200 or code >= 300:
		return _http_error(code, text)
	if text == "":
		return {"ok": true, "error": "", "rows": [], "data": {}}
	return _parse_body(text)

static func _http_error(code: int, text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = parsed
		var err := _error_field(data)
		if err == "":
			err = "http_%d" % code
		return {"ok": false, "error": err, "rows": [], "data": data}
	return {"ok": false, "error": "http_%d" % code, "rows": [], "data": {}}

static func _parse_body(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_ARRAY:
		return {"ok": true, "error": "", "rows": parsed, "data": {}}
	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = parsed
		if data.has("ok"):
			return {
				"ok": bool(data.get("ok", false)),
				"error": str(data.get("error", "")),
				"rows": [],
				"data": data,
			}
		var err := _error_field(data)
		if err == "":
			err = "bad_response"
		return {"ok": false, "error": err, "rows": [], "data": data}
	return {"ok": false, "error": "bad_response", "rows": [], "data": {}}

static func _error_field(data: Dictionary) -> String:
	if data.has("error") and str(data["error"]) != "":
		return str(data["error"])
	if data.has("message") and str(data["message"]) != "":
		return str(data["message"])
	return ""

func _mark_posted(name: String) -> void:
	var data := _read()
	if str(data.get("device_id", "")) == "":
		data["device_id"] = device_id()
	data["name"] = clean_name(name)
	data["posted"] = true
	_write(data)

func _read() -> Dictionary:
	if not FileAccess.file_exists(PROFILE_PATH):
		return {}
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _write(data: Dictionary) -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

static func _uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]
