extends RefCounted
class_name PixelFont

## Kaito 5x7. The outlined atlas is the one that sits on the sky.
## Score digits are the plain atlas, outlined, gold-ramped, then doubled.

const INK := Color("14121f")
const PAPER := Color("f2fbff")
const PAD := 2

static var _plain_img: Image
static var _out_img: Image
static var _plain: Dictionary
static var _out: Dictionary
static var _cache: Dictionary = {}

static func _ensure() -> void:
	if _plain_img != null:
		return
	_plain = JSON.parse_string(FileAccess.get_file_as_string("res://ui/font_kaito5x7.json"))
	_out = JSON.parse_string(FileAccess.get_file_as_string("res://ui/font_kaito5x7_outlined.json"))
	# These PNGs are the BMFont pages. A fresh Godot 4.7 import marks that
	# importer as skip, so load() as a Texture2D fails in CI. Read the bytes.
	_plain_img = _png("res://ui/font_kaito5x7.png")
	_out_img = _png("res://ui/font_kaito5x7_outlined.png")

static func _png(path: String) -> Image:
	var image := Image.new()
	var err := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	if err != OK:
		push_error("could not read %s" % path)
	return image

static func score_image(text: String) -> Image:
	_ensure()
	var key := "s|" + text
	if _cache.has(key):
		return _cache[key]
	var glyphs: Dictionary = _plain["glyphs"]
	var width := 1
	for i in text.length():
		var glyph: Dictionary = glyphs[text.substr(i, 1)]
		width += int(glyph["advance"])
	var image := Image.create(width + 4, 15, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var drawn := PackedInt32Array()
	var pen := PAD
	for i in text.length():
		var glyph: Dictionary = glyphs[text.substr(i, 1)]
		var origin := Vector2i(int(glyph["x"]), int(glyph["y"]))
		var size := Vector2i(int(glyph["w"]), int(glyph["h"]))
		var off: Array = glyph["offset"]
		for yy in size.y:
			for xx in size.x:
				if _plain_img.get_pixel(origin.x + xx, origin.y + yy).a <= 0.5:
					continue
				drawn.append(pen + int(off[0]) + xx)
				drawn.append(PAD + int(off[1]) + yy)
				drawn.append(yy)
		pen += int(glyph["advance"])
	var body := {}
	for n in range(0, drawn.size(), 3):
		body[_key(drawn[n], drawn[n + 1])] = true
	for n in range(0, drawn.size(), 3):
		var px := drawn[n]
		var py := drawn[n + 1]
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx: int = px + int(dx)
				var ny: int = py + int(dy)
				if body.has(_key(nx, ny)):
					continue
				if nx < 0 or ny < 0 or nx >= image.get_width() or ny >= image.get_height():
					continue
				if image.get_pixel(nx, ny).a <= 0.5:
					image.set_pixel(nx, ny, INK)
	var ramp: Array[Color] = [
		Color("fff3a0"), Color("fff3a0"),
		Color("ffd84a"), Color("ffd84a"), Color("ffd84a"),
		Color("f0a52a"), Color("f0a52a"),
	]
	for n in range(0, drawn.size(), 3):
		var row := mini(drawn[n + 2], 6)
		image.set_pixel(drawn[n], drawn[n + 1], ramp[row])
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	_cache[key] = image
	return image

static func score_texture(text: String) -> Texture2D:
	var key := "st|" + text
	if _cache.has(key):
		return _cache[key]
	var texture := ImageTexture.create_from_image(score_image(text))
	_cache[key] = texture
	return texture

## Padded outlined string. The pen sits at (PAD, PAD) inside the image.
static func outlined_image(text: String, fill: Color) -> Image:
	_ensure()
	var key := "o|" + text + "|" + fill.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var glyphs: Dictionary = _out["glyphs"]
	var width := PAD
	for i in text.length():
		var ch := text.substr(i, 1)
		if not glyphs.has(ch):
			ch = "?"
		width += int(glyphs[ch]["advance"])
	var image := Image.create(maxi(width + 4, 4), 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	if text.is_empty():
		_cache[key] = image
		return image
	var pen := PAD
	for i in text.length():
		var ch := text.substr(i, 1)
		if not glyphs.has(ch):
			ch = "?"
		var glyph: Dictionary = glyphs[ch]
		var origin := Vector2i(int(glyph["x"]), int(glyph["y"]))
		var size := Vector2i(int(glyph["w"]), int(glyph["h"]))
		var off: Array = glyph["offset"]
		for yy in size.y:
			for xx in size.x:
				var src := _out_img.get_pixel(origin.x + xx, origin.y + yy)
				if src.a <= 0.5:
					continue
				var color := INK
				if src.r > 0.9 and src.g > 0.9 and src.b > 0.9:
					color = fill
				var dx := pen + int(off[0]) + xx
				var dy := PAD + int(off[1]) + yy
				if dx < 0 or dy < 0 or dx >= image.get_width() or dy >= image.get_height():
					continue
				image.set_pixel(dx, dy, color)
		pen += int(glyph["advance"])
	_cache[key] = image
	return image

static func outlined_texture(text: String, fill: Color) -> Texture2D:
	var key := "ot|" + text + "|" + fill.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var texture := ImageTexture.create_from_image(outlined_image(text, fill))
	_cache[key] = texture
	return texture

static func draw_outlined(canvas: CanvasItem, text: String, pen: Vector2, fill: Color) -> void:
	if text.is_empty():
		return
	canvas.draw_texture(outlined_texture(text, fill), pen - Vector2(PAD, PAD))

static func checksum(image: Image) -> int:
	var acc := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.5:
				continue
			var red := int(round(pixel.r * 255.0))
			var green := int(round(pixel.g * 255.0))
			var blue := int(round(pixel.b * 255.0))
			acc = (acc + red * 3 + green * 5 + blue * 7 + x * 11 + y * 13) & 0xFFFFFFFF
	return acc

static func plain_atlas() -> Image:
	_ensure()
	return _plain_img

static func plain_glyphs() -> Dictionary:
	_ensure()
	return _plain["glyphs"]

static func _key(x: int, y: int) -> int:
	return y * 8192 + x
