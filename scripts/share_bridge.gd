extends RefCounted
class_name ShareBridge

## Mobile share sheet and the clipboard fallback. Web keeps shareRunCard /
## shareRunText in the page shell. This script never calls those.

const IOS_REQUEST := "user://share_sheet_request.json"
const IOS_RESULT := "user://share_sheet_result.txt"
const IOS_READY := "user://share_sheet_ready"
const IOS_WAIT_FRAMES := 90


static func mobile_body(text: String, link: String) -> String:
	if link.is_empty():
		return text
	if text.is_empty():
		return link
	return "%s\n%s" % [text, link]


## web: the page shell. ios_sheet / android_sheet: native share UI.
## clipboard: copy the text and show a toast. desktop_file: save the PNG.
static func channel_for(web: bool, ios: bool, android: bool, ios_plugin: bool, android_runtime: bool) -> String:
	if web:
		return "web"
	if ios:
		return "ios_sheet" if ios_plugin else "clipboard"
	if android:
		return "android_sheet" if android_runtime else "clipboard"
	return "desktop_file"


## Where a challenge-link copy goes. Headless tests skip the clipboard call.
static func copy_channel(web: bool, headless: bool) -> String:
	if web:
		return "web"
	if headless:
		return "skip"
	return "clipboard"


## iOS and Android append the challenge link. The CrazyGames build never does.
static func share_appends_link(crazygames: bool, web: bool, mobile: bool) -> bool:
	if crazygames or web or not mobile:
		return false
	return true


static func strip_urls(text: String) -> String:
	var out := ""
	var i := 0
	while i < text.length():
		var rest := text.substr(i).to_lower()
		if rest.begins_with("https://") or rest.begins_with("http://"):
			while i < text.length():
				var ch := text.substr(i, 1)
				if ch == " " or ch == "\n" or ch == "\t":
					break
				i += 1
			continue
		out += text.substr(i, 1)
		i += 1
	return out.strip_edges()


static func current_channel() -> String:
	return channel_for(
		OS.has_feature("web"),
		OS.has_feature("ios"),
		OS.has_feature("android"),
		ios_plugin_ready(),
		android_runtime_ready()
	)


static func ios_plugin_ready() -> bool:
	return FileAccess.file_exists(IOS_READY)


static func android_runtime_ready() -> bool:
	return OS.has_feature("android") and Engine.has_singleton("AndroidRuntime")


static func read_ios_result() -> String:
	if not FileAccess.file_exists(IOS_RESULT):
		return ""
	var file := FileAccess.open(IOS_RESULT, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text().strip_edges()
	file.close()
	return text


static func write_ios_request(text: String, image_path: String) -> bool:
	_remove(IOS_RESULT)
	var file := FileAccess.open(IOS_REQUEST, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"text": text, "image": image_path}))
	file.close()
	return true


## The iOS plugin polls user:// and writes "shown" or "failed". Headless and
## editor builds have no plugin, so this returns false immediately.
static func await_ios_sheet(host: Node, text: String, image_path: String) -> bool:
	if host == null or not host.is_inside_tree() or not ios_plugin_ready():
		return false
	if not write_ios_request(text, image_path):
		return false
	var frames := 0
	while frames < IOS_WAIT_FRAMES:
		var result := read_ios_result()
		if result == "shown":
			_remove(IOS_RESULT)
			_remove(IOS_REQUEST)
			return true
		if result == "failed":
			_remove(IOS_RESULT)
			_remove(IOS_REQUEST)
			return false
		await host.get_tree().process_frame
		frames += 1
	_remove(IOS_REQUEST)
	return false


## Opens the Android share sheet with the text and link. The PNG is attached
## when the content resolver accepts it. A failure returns false so the caller
## can copy the text and show a toast instead of failing silently.
static func android_share(text: String, image_path: String) -> bool:
	if not android_runtime_ready():
		return false
	var runtime: Variant = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return false
	var activity: Variant = runtime.getActivity()
	if activity == null:
		return false
	var image_uri: Variant = _android_image_uri(activity, image_path)
	return _android_send(activity, text, image_uri)


static func _android_send(activity: Variant, text: String, image_uri: Variant) -> bool:
	var wrapper := _java()
	if wrapper == null:
		return false
	var Intent: Variant = wrapper.call("wrap", "android.content.Intent")
	if Intent == null:
		return false
	var share: Variant = Intent.Intent()
	if share == null:
		return false
	share.setAction(Intent.ACTION_SEND)
	share.putExtra(Intent.EXTRA_TEXT, text)
	if image_uri != null:
		share.setType("image/png")
		share.putExtra(Intent.EXTRA_STREAM, image_uri)
		share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
	else:
		share.setType("text/plain")
	if _java_failed():
		return false
	var chooser: Variant = Intent.createChooser(share, "Share")
	if chooser == null or _java_failed():
		return false
	activity.startActivity(chooser)
	return not _java_failed()


## MediaStore gives the other app a content URI. file:// crashes on API 24+,
## which is this project's minimum. A rejected insert just drops the image.
static func _android_image_uri(activity: Variant, image_path: String) -> Variant:
	if image_path.is_empty() or not FileAccess.file_exists(image_path):
		return null
	var wrapper := _java()
	if wrapper == null:
		return null
	var BitmapFactory: Variant = wrapper.call("wrap", "android.graphics.BitmapFactory")
	var bitmap: Variant = BitmapFactory.decodeFile(image_path)
	if bitmap == null or _java_failed():
		return null
	var Media: Variant = wrapper.call("wrap", "android.provider.MediaStore$Images$Media")
	var Values: Variant = wrapper.call("wrap", "android.content.ContentValues")
	var values: Variant = Values.ContentValues()
	if values == null:
		return null
	values.put("_display_name", "reincarnated.png")
	values.put("mime_type", "image/png")
	var resolver: Variant = activity.getContentResolver()
	if resolver == null or _java_failed():
		return null
	var uri: Variant = resolver.insert(Media.EXTERNAL_CONTENT_URI, values)
	if uri == null or _java_failed():
		return null
	var stream: Variant = resolver.openOutputStream(uri)
	if stream == null or _java_failed():
		return null
	var Format: Variant = wrapper.call("wrap", "android.graphics.Bitmap$CompressFormat")
	var wrote: Variant = bitmap.compress(Format.PNG, 100, stream)
	stream.flush()
	stream.close()
	if _java_failed() or not bool(wrote):
		return null
	return uri


static func _java() -> Object:
	if not Engine.has_singleton("JavaClassWrapper"):
		return null
	return Engine.get_singleton("JavaClassWrapper")


static func _java_failed() -> bool:
	var wrapper := _java()
	if wrapper == null or not wrapper.has_method("get_exception"):
		return false
	var err: Variant = wrapper.call("get_exception")
	return err != null


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
