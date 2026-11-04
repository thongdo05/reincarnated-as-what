extends RefCounted
class_name ArtLibrary

## Reads res://art/manifest.json. Anchors are pixels from the top-left of the frame.
## A center anchor draws the sprite around the node's origin. A bottom-center anchor
## (the skeleton archer) puts the feet on the node's origin.
## Idle sheets are horizontal strips named <sprite>_idle.png. Demon orb shots are
## strips on the projectile file itself, with no separate _idle sibling.
## Hitboxes use one frame (frame_size, else art_bbox, else size), so a strip's
## full width never becomes a collision box.

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

## Opaque art size when the manifest measured one, otherwise one frame.
## Sheets expose frame_size so the strip width is not treated as the body.
static func art_bbox(file_name: String) -> Vector2:
	var data := entry(file_name)
	if data.has("art_bbox"):
		var box: Array = data["art_bbox"]
		return Vector2(float(box[0]), float(box[1]))
	if data.has("frame_size"):
		var frame: Array = data["frame_size"]
		return Vector2(float(frame[0]), float(frame[1]))
	var size: Array = data.get("size", [8, 8])
	return Vector2(float(size[0]), float(size[1]))

## <name>.png -> <name>_idle.png when that sheet is in the manifest.
static func loop_file(base_file: String) -> String:
	var idle := base_file.trim_suffix(".png") + "_idle.png"
	if has_file(idle):
		return idle
	return base_file

## Circle radius whose diameter is pct of the average art-box side.
## pct stays inside 0.50-0.65 so the hitbox is smaller than the sprite.
## Ringed player forms store was_art_bbox. A radius taken from the box uses
## that pre-ring measurement, so the outline does not change the result.
static func radius_for(file_name: String, pct: float) -> float:
	var data := entry(file_name)
	var box := art_bbox(file_name)
	if data.has("was_art_bbox"):
		var old: Array = data["was_art_bbox"]
		box = Vector2(float(old[0]), float(old[1]))
	var band := clampf(pct, 0.50, 0.65)
	return band * (box.x + box.y) * 0.25

static func draw_anchored(canvas: CanvasItem, file_name: String, tint: Color = Color.WHITE) -> void:
	# A multi-frame file is a horizontal strip. Drawing the whole texture would
	# show every frame side by side, so a still call shows frame 0 only.
	if int(entry(file_name).get("frames", 1)) > 1:
		draw_loop(canvas, file_name, 0.0, Vector2.ZERO, tint)
		return
	var tex := texture(file_name)
	if tex == null:
		return
	canvas.draw_texture(tex, -anchor(file_name), tint)

## One cell of a horizontal strip. Single-frame files return the whole texture.
## Looping sheets wrap. A non-looping sheet holds its last frame.
static func frame_source(file_name: String, time_sec: float) -> Rect2:
	var file := loop_file(file_name)
	var data := entry(file)
	var frames := int(data.get("frames", 1))
	if frames <= 1:
		var tex := texture(file)
		if tex != null:
			return Rect2(Vector2.ZERO, tex.get_size())
		return Rect2(Vector2.ZERO, art_bbox(file))
	var frame_box: Array = data.get("frame_size", [1, 1])
	var frame := Vector2(float(frame_box[0]), float(frame_box[1]))
	var index := frame_index(file, time_sec)
	return Rect2(frame.x * float(index), 0.0, frame.x, frame.y)

## Same index draw_loop uses, so a hurt frame can follow the picture.
static func frame_index(file_name: String, time_sec: float) -> int:
	var file := loop_file(file_name)
	var data := entry(file)
	var frames := int(data.get("frames", 1))
	if frames <= 1:
		return 0
	var fps := float(data.get("fps", 6))
	if fps <= 0.0:
		fps = 6.0
	var index := int(floor(time_sec * fps))
	if bool(data.get("loop", true)):
		return posmod(index, frames)
	return clampi(index, 0, frames - 1)

## Draw base_file, or its idle sheet, around origin. origin is the actor's
## anchor point in the canvas's local space (Vector2.ZERO for the actor itself).
## The anchor is the static sprite's, which matches one frame of the sheet.
static func draw_loop(canvas: CanvasItem, base_file: String, time_sec: float, origin: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE, scale: float = 1.0) -> void:
	var file := loop_file(base_file)
	var tex := texture(file)
	if tex == null:
		return
	var frames := int(entry(file).get("frames", 1))
	var point := anchor(base_file) * scale
	var at := origin - point
	if canvas is Node2D and not is_equal_approx(scale, 1.0):
		var node := canvas as Node2D
		at = (node.position + at).round() - node.position
	if frames <= 1:
		if is_equal_approx(scale, 1.0):
			canvas.draw_texture(tex, at, tint)
			return
		canvas.draw_texture_rect(tex, Rect2(at, tex.get_size() * scale), false, tint)
		return
	var src := frame_source(base_file, time_sec)
	canvas.draw_texture_rect_region(tex, Rect2(at, src.size * scale), src, tint)
