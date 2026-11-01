extends RefCounted
class_name ArtLibrary

## Reads res://art/manifest.json. Anchors are pixels from the top-left of the frame.
## A center anchor draws the sprite around the node's origin. A bottom-center anchor
## (the skeleton archer) puts the feet on the node's origin.

const ROOT := "res://art/"

static var _entries: Dictionary = {}
static var _textures: Dictionary = {}
static var _ready := false

static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	var path := ROOT + "manifest.json"
	if not FileAccess.file_exists(path):
		push_error("art manifest missing at %s" % path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("art manifest is not a list")
		return
	for item in parsed:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		_entries[str(entry.get("file", ""))] = entry

static func entry(file_name: String) -> Dictionary:
	_ensure()
	return _entries.get(file_name, {})

static func has_file(file_name: String) -> bool:
	return not entry(file_name).is_empty()

static func file_count() -> int:
	_ensure()
	return _entries.size()

static func texture(file_name: String) -> Texture2D:
	if _textures.has(file_name):
		return _textures[file_name]
	var tex: Texture2D = load(ROOT + file_name)
	if tex == null:
		push_error("missing art %s" % file_name)
	_textures[file_name] = tex
	return tex

static func anchor(file_name: String) -> Vector2:
	var data := entry(file_name)
	var point: Array = data.get("anchor", [0, 0])
	return Vector2(float(point[0]), float(point[1]))

## Opaque art size when the manifest measured one, otherwise the frame size.
static func art_bbox(file_name: String) -> Vector2:
	var data := entry(file_name)
	if data.has("art_bbox"):
		var box: Array = data["art_bbox"]
		return Vector2(float(box[0]), float(box[1]))
	var size: Array = data.get("size", [8, 8])
	return Vector2(float(size[0]), float(size[1]))

## Circle radius whose diameter is pct of the average art-box side.
## pct stays inside 0.50-0.65 so the hitbox is smaller than the sprite.
static func radius_for(file_name: String, pct: float) -> float:
	var box := art_bbox(file_name)
	var band := clampf(pct, 0.50, 0.65)
	return band * (box.x + box.y) * 0.25

static func draw_anchored(canvas: CanvasItem, file_name: String, tint: Color = Color.WHITE) -> void:
	var tex := texture(file_name)
	if tex == null:
		return
	canvas.draw_texture(tex, -anchor(file_name), tint)
