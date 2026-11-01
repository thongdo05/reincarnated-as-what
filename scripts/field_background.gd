extends Node2D
class_name FieldBackground

## Three cheap parallax layers. Rects and a few circles, no textures.
## Far sky and clouds, mid castles and islands, near hills and crystals.
## Everything scrolls left so a still ship reads as flying right.

var field_size := Vector2(780, 360)
var scroll_far := 0.0
var scroll_mid := 0.0
var scroll_near := 0.0
var _clouds: Array[Dictionary] = []
var _spires: Array[Dictionary] = []
var _islands: Array[Dictionary] = []
var _hills: Array[Dictionary] = []
var _crystals: Array[Dictionary] = []

func setup(seed_value: int, size: Vector2) -> void:
	field_size = size
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 17
	_clouds.clear()
	_spires.clear()
	_islands.clear()
	_hills.clear()
	_crystals.clear()
	var span := maxf(size.x, 200.0)
	for i in 7:
		_clouds.append({
			"x": rng.randf_range(0.0, span),
			"y": rng.randf_range(28.0, size.y * 0.42),
			"w": rng.randf_range(36.0, 78.0),
			"tint": rng.randf(),
		})
	for i in 5:
		_spires.append({
			"x": rng.randf_range(0.0, span),
			"h": rng.randf_range(70.0, 150.0),
			"w": rng.randf_range(14.0, 28.0),
		})
	for i in 4:
		_islands.append({
			"x": rng.randf_range(0.0, span),
			"y": rng.randf_range(size.y * 0.28, size.y * 0.62),
			"w": rng.randf_range(54.0, 110.0),
		})
	for i in 6:
		_hills.append({
			"x": rng.randf_range(0.0, span),
			"r": rng.randf_range(42.0, 78.0),
			"tree": rng.randf() > 0.45,
		})
	for i in 5:
		_crystals.append({
			"x": rng.randf_range(0.0, span),
			"y": rng.randf_range(size.y * 0.42, size.y * 0.72),
			"magenta": rng.randf() > 0.5,
		})

func tick(delta: float, size: Vector2) -> void:
	field_size = size
	scroll_far += delta * 16.0
	scroll_mid += delta * 36.0
	scroll_near += delta * 84.0
	queue_redraw()

func _draw() -> void:
	var width := field_size.x
	var height := field_size.y
	_draw_sky(width, height)
	_draw_clouds(width)
	_draw_mid(width, height)
	_draw_near(width, height)

func _draw_sky(width: float, height: float) -> void:
	var bands: Array[Color] = [
		Color("4ea2ff"),
		Color("79c0ff"),
		Color("ffb3dc"),
		Color("ffd0ea"),
		Color("ffe08a"),
		Color("fff3c4"),
	]
	var band_h := height / float(bands.size())
	for i in bands.size():
		draw_rect(Rect2(0, band_h * float(i), width, band_h + 1.0), bands[i])
	var sun_x := _wrap(width * 0.72 - scroll_far * 0.15, width, 40.0)
	draw_circle(Vector2(sun_x, height * 0.22), 22.0, Color("fff6c8"))

func _draw_clouds(width: float) -> void:
	for cloud in _clouds:
		var x := _wrap(float(cloud["x"]) - scroll_far, width, 120.0)
		var y := float(cloud["y"])
		var w := float(cloud["w"])
		var tint := Color("fff7ff") if float(cloud["tint"]) > 0.5 else Color("ffe4f4")
		draw_rect(Rect2(x, y, w, 14), tint)
		draw_rect(Rect2(x + w * 0.2, y - 8.0, w * 0.55, 12), Color("ffffff"))
		draw_rect(Rect2(x + w * 0.45, y - 3.0, w * 0.4, 10), tint)

func _draw_mid(width: float, height: float) -> void:
	for spire in _spires:
		var x := _wrap(float(spire["x"]) - scroll_mid, width, 80.0)
		var h := float(spire["h"])
		var w := float(spire["w"])
		var top := height - 30.0 - h
		draw_rect(Rect2(x, top, w, h), Color("3d2a5c"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 2, top + 8),
			Vector2(x + w * 0.5, top - 16),
			Vector2(x + w + 2, top + 8),
		]), Color("2a1c44"))
		var windows := int(h / 22.0)
		for n in windows:
			draw_rect(Rect2(x + w * 0.35, top + 18.0 + float(n) * 20.0, 4, 5), Color("ffd56a"))
	for island in _islands:
		var x := _wrap(float(island["x"]) - scroll_mid * 1.15, width, 140.0)
		var y := float(island["y"])
		var w := float(island["w"])
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, y),
			Vector2(x + w, y),
			Vector2(x + w * 0.78, y + 22),
			Vector2(x + w * 0.22, y + 22),
		]), Color("8a6248"))
		draw_rect(Rect2(x + 4, y - 8, w - 8, 10), Color("3dba5a"))

func _draw_near(width: float, height: float) -> void:
	var ground_y := height - 6.0
	for hill in _hills:
		var x := _wrap(float(hill["x"]) - scroll_near, width, 160.0)
		var r := float(hill["r"])
		draw_circle(Vector2(x, ground_y), r, Color("2f9e4a"))
		draw_circle(Vector2(x, ground_y - 6.0), r * 0.72, Color("46c45a"))
		if bool(hill["tree"]):
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 8, ground_y - r * 0.35),
				Vector2(x, ground_y - r * 0.35 - 22),
				Vector2(x + 8, ground_y - r * 0.35),
			]), Color("1f7a38"))
	for crystal in _crystals:
		var x := _wrap(float(crystal["x"]) - scroll_near * 1.2, width, 40.0)
		var y := float(crystal["y"])
		var gem := Color("ff4fd8") if bool(crystal["magenta"]) else Color("b07cff")
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, y - 8),
			Vector2(x + 5, y),
			Vector2(x, y + 8),
			Vector2(x - 5, y),
		]), gem)
	draw_rect(Rect2(0, height - 10, width, 10), Color("1f7a38"))

func _wrap(x: float, width: float, margin: float) -> float:
	var span := width + margin
	var wrapped := fmod(x, span)
	if wrapped < -margin * 0.5:
		wrapped += span
	return wrapped
