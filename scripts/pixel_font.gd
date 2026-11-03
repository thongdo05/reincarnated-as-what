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
	_plain = _json("res://ui/font_kaito5x7.json")
	_out = _json("res://ui/font_kaito5x7_outlined.json")
	# A clean Godot 4.7 import sets the page PNGs to importer "skip" because the
	# BMFont already owns them. Skip files are not resources, and the web export
	# does not pack them unless export_presets names them. FileAccess then
	# returns 0 bytes. Image.get_pixel on that empty page returns opaque black,
	# so every glyph cell was painted as a solid rectangle. SND stayed readable
	# because Labels use the FontFile, which embeds the page. Prefer that page,
	# and fall back to the raw PNG when the export included it.
	_plain_img = _atlas("res://ui/font_kaito5x7.png", "res://ui/font_kaito5x7.fnt")
	_out_img = _atlas("res://ui/font_kaito5x7_outlined.png", "res://ui/font_kaito5x7_outlined.fnt")

static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("could not read %s" % path)
		return {}
	return parsed

static func _atlas(png_path: String, font_path: String) -> Image:
	var from_font := _font_page(font_path)
	if _page_ok(from_font):
		return from_font
	var from_png := _png(png_path)
	if _page_ok(from_png):
		return from_png
	push_error("font atlas missing: %s" % png_path)
	return Image.create(1, 1, false, Image.FORMAT_RGBA8)

static func _font_page(path: String) -> Image:
	var font := load(path) as FontFile
	if font == null:
		return null
	return font.get_texture_image(0, Vector2i.ZERO, 0)

static func _png(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	var err := image.load_png_from_buffer(bytes)
	if err != OK:
		push_error("could not read %s" % path)
		return null
	return image

## A real Kaito page is mostly clear, with white or outlined ink. A missing
## page, or a page that loaded as one filled rectangle, is not usable.
static func _page_ok(image: Image) -> bool:
	if image == null or image.get_width() < 16 or image.get_height() < 16:
		return false
	return interior_holes(image) > 32

## Image.get_pixel on a 0-size image returns opaque black. Never sample that.
static func sample_alpha(image: Image, x: int, y: int) -> float:
	if image == null or x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return 0.0
	return image.get_pixel(x, y).a

static func sample_color(image: Image, x: int, y: int) -> Color:
	if sample_alpha(image, x, y) <= 0.0:
		return Color(0, 0, 0, 0)
	return image.get_pixel(x, y)

## True when the opaque pixels form one filled rectangle. Real glyphs leave
## transparent counters inside the used bounds (0, 4, A, the clock, the score).
static func is_solid_block(image: Image) -> bool:
	if image == null or image.get_width() < 2 or image.get_height() < 2:
		return true
	var used := image.get_used_rect()
	if used.size.x < 3 or used.size.y < 3:
		return true
	return interior_holes(image) < 4

static func interior_holes(image: Image) -> int:
	if image == null:
		return 0
	var used := image.get_used_rect()
	var holes := 0
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if sample_alpha(image, x, y) <= 0.5:
				holes += 1
	return holes

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
				if sample_alpha(_plain_img, origin.x + xx, origin.y + yy) <= 0.5:
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
				var src := sample_color(_out_img, origin.x + xx, origin.y + yy)
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

static func plain_advance(text: String) -> int:
	_ensure()
	var glyphs: Dictionary = _plain["glyphs"]
	var width := 0
	for i in text.length():
		var ch := text.substr(i, 1)
		if not glyphs.has(ch):
			ch = "?"
		width += int(glyphs[ch]["advance"])
	return width

## Hard pixels of the Kaito face. Outlined keeps the 1px stroke the tab labels
## use. Plain is the same letters with no stroke, so a dark tint on the yellow
## "you" row does not turn into a blurry bold.
static func row_image(text: String, fill: Color, outlined: bool, scale: int) -> Image:
	_ensure()
	var step := maxi(scale, 1)
	var key := "row|%s|%s|%s|%d" % [text, fill.to_html(false), "o" if outlined else "p", step]
	if _cache.has(key):
		return _cache[key]
	var glyphs: Dictionary = _out["glyphs"] if outlined else _plain["glyphs"]
	var atlas := _out_img if outlined else _plain_img
	var margin := 1
	var width := margin
	for i in text.length():
		var ch := text.substr(i, 1)
		if not glyphs.has(ch):
			ch = "?"
		width += int(glyphs[ch]["advance"])
	width += margin
	# 11 covers the outlined cell (offset -1, height 11). Plain glyphs sit one
	# pixel in so their fill lines up with the outlined fill.
	var image := Image.create(maxi(width, 1), 11, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var pen := margin
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
				var src := sample_color(atlas, origin.x + xx, origin.y + yy)
				if src.a <= 0.5:
					continue
				var color := fill
				if outlined and (src.r <= 0.9 or src.g <= 0.9 or src.b <= 0.9):
					color = INK
				var dx := pen + int(off[0]) + xx
				var dy := margin + int(off[1]) + yy
				if dx < 0 or dy < 0 or dx >= image.get_width() or dy >= image.get_height():
					continue
				image.set_pixel(dx, dy, color)
		pen += int(glyph["advance"])
	if step > 1:
		image.resize(image.get_width() * step, image.get_height() * step, Image.INTERPOLATE_NEAREST)
	_cache[key] = image
	return image

static func row_texture(text: String, fill: Color, outlined: bool, scale: int) -> Texture2D:
	var key := "rowt|%s|%s|%s|%d" % [text, fill.to_html(false), "o" if outlined else "p", maxi(scale, 1)]
	if _cache.has(key):
		return _cache[key]
	var texture := ImageTexture.create_from_image(row_image(text, fill, outlined, scale))
	_cache[key] = texture
	return texture

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
