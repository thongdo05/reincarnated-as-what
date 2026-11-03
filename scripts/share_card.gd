extends RefCounted
class_name ShareCard

## 270x270 card, exported at 4x. Layout follows share/share_card_template.json
## and the marketing share cards: slanted plate, extruded names, pink gag.
## Run fields replace the example values in share/share_cards_config.json.

const INK := Color("14121f")
const PAPER := Color("f2fbff")
const BASE := 270
const SCALE := 4

const GAGS := {
	"piano": "Struck a final chord.",
	"anvil": "Out of order.",
	"skeleton_archer": "The crown fell off.",
	"dire_wolf": "Hostile takeover failed.",
	"floating_eye": "Lost a staring contest.",
	"wyvern": "A bad time to look up.",
	"lich_king": "The crown stayed.",
	"death_knight": "Outlasted.",
	"great_dragon": "The sky caught fire.",
}

const NAME_TO_KILLER := {
	"Floating Eye": "floating_eye",
	"Dire Wolf": "dire_wolf",
	"Skeleton Archer": "skeleton_archer",
	"Wyvern": "wyvern",
	"falling anvil": "anvil",
	"falling piano": "piano",
	"a falling anvil": "anvil",
	"a falling piano": "piano",
	"a Dire Wolf": "dire_wolf",
	"a Floating Eye": "floating_eye",
	"a Skeleton Archer": "skeleton_archer",
	"a Wyvern": "wyvern",
	"Lich King": "lich_king",
	"Death Knight": "death_knight",
	"Great Dragon": "great_dragon",
	"shot": "floating_eye",
	"something": "floating_eye",
	"Thing": "floating_eye",
}

static var _config: Dictionary = {}

static func _ensure() -> void:
	if not _config.is_empty():
		return
	_config = JSON.parse_string(FileAccess.get_file_as_string("res://share/share_cards_config.json"))

static func form_key(form_id: int) -> String:
	return FormCatalog.key_for(form_id)

static func killer_id(killer_name: String) -> String:
	return str(NAME_TO_KILLER.get(killer_name, "floating_eye"))

static func resolve(run: Dictionary) -> Dictionary:
	_ensure()
	var forms: Dictionary = _config["forms"]
	var form := str(run.get("form", "slime"))
	if not forms.has(form):
		form = "slime"
	var spec: Dictionary = forms[form]
	var names: Array = spec["rank_names"]
	var rank := clampi(int(run.get("rank_reached", 1)), 1, names.size())
	var killers: Dictionary = _config["killers"]
	var killer := str(run.get("killer", spec["example_killer"]))
	if not killers.has(killer):
		killer = str(spec["example_killer"])
	var killer_spec: Dictionary = killers[killer]
	var gag := str(run.get("gag", ""))
	if gag.is_empty():
		gag = str(GAGS.get(killer, spec["example_gag"]))
	var score_value: Variant = run.get("score", 0)
	var score_text := str(score_value)
	if typeof(score_value) != TYPE_STRING:
		score_text = ScoreRules.format_score(int(score_value))
	var time_text := str(run.get("time", "0:00"))
	var sprites: Array = spec["sprites"]
	return {
		"form": form,
		"form_name": str(spec["form_name"]),
		"rank_reached": rank,
		"rank_name": str(names[rank - 1]),
		"sprite": str(sprites[rank - 1]),
		"time": time_text,
		"score": score_text,
		"killer": killer,
		"killer_label": str(killer_spec["label"]),
		"killer_sprite": str(killer_spec["sprite"]),
		"gag": gag,
		"theme": spec["theme"],
	}

static func render(run: Dictionary) -> Image:
	var card := render_base(run)
	card.resize(BASE * SCALE, BASE * SCALE, Image.INTERPOLATE_NEAREST)
	return card

static func render_base(run: Dictionary) -> Image:
	var fields := resolve(run)
	var theme: Dictionary = fields["theme"]
	var card := Image.create(BASE, BASE, false, Image.FORMAT_RGBA8)
	_burst(card, theme)
	var ribbon := (load("res://share/brand_ribbon.png") as Texture2D).get_image()
	card.blit_rect(ribbon, Rect2i(Vector2i.ZERO, ribbon.get_size()), Vector2i.ZERO)
	_hero(card, str(fields["sprite"]), theme)
	_right_column(card, fields, theme)
	_stats(card, fields)
	_gag(card, str(fields["gag"]))
	return card

static func _burst(card: Image, theme: Dictionary) -> void:
	var bg := Color(str(theme["bg"]))
	var ray := Color(str(theme["ray"]))
	var cores: Array = theme["core"]
	card.fill(bg)
	var origin := Vector2(64, 104)
	var reach := 600.0
	for i in range(0, 16, 2):
		var a0 := TAU * float(i) / 16.0 - 0.02
		var a1 := TAU * float(i + 1) / 16.0 + 0.02
		_fill_polygon(card, [
			origin,
			origin + Vector2(cos(a0), sin(a0)) * reach,
			origin + Vector2(cos(a1), sin(a1)) * reach,
		], ray)
	_fill_ellipse(card, 64, 104, 58, 58, Color(str(cores[0])))
	_fill_ellipse(card, 64, 104, 46, 46, Color(str(cores[1])))
	var white := Color("ffffff")
	for line in _speed_lines():
		var pts: Array = line
		_fill_polygon(card, [
			Vector2(float(pts[0]), float(pts[1])),
			Vector2(float(pts[2]), float(pts[3])),
			Vector2(float(pts[4]), float(pts[5])),
		], white)


static func _speed_lines() -> Array:
	return [
		[-39.3823, 310.6317, -198.4357, 643.5623, -210.4631, 637.5448],
		[292.2811, 215.7204, 605.2548, 362.9272, 600.5467, 372.5474],
		[299.8683, 193.9732, 625.9349, 314.3074, 623.2405, 321.3708],
		[-142.8162, 195.5946, -482.9587, 350.6500, -486.2269, 343.2706],
		[-177.6337, 228.0394, -467.8501, 381.7327, -471.6809, 374.2701],
		[107.4526, 359.9842, 172.4366, 694.1199, 156.3689, 696.8474],
		[-153.5166, -10.4752, -470.7664, -168.0752, -463.0486, -182.7398],
		[325.8763, 182.9144, 639.9030, 272.3321, 637.0235, 281.8878],
		[205.2427, 284.3398, 437.9458, 573.2170, 429.9460, 579.4824],
		[157.9833, -109.0335, 300.3183, -447.5013, 312.0138, -442.3416],
		[-93.0323, -83.2025, -326.3532, -351.6582, -316.8084, -359.6647],
		[272.2480, 190.7025, 619.6574, 330.3733, 616.1300, 338.8455],
		[-40.8831, -120.3497, -194.7204, -437.3536, -185.4660, -441.6800],
		[-150.0401, -23.6050, -453.9259, -198.9073, -448.7653, -207.5634],
		[136.6481, -149.7448, 224.5545, -474.1196, 233.7291, -471.4929],
		[-162.2959, -10.2733, -475.0576, -159.4709, -468.0253, -173.3969],
		[33.1835, -133.2835, -21.5022, -489.8766, -5.0314, -492.0157],
		[246.1612, 270.9415, 511.1958, 504.0198, 501.4206, 514.6863],
		[209.1858, 309.1628, 413.6765, 591.5719, 407.4921, 595.9484],
		[-67.6727, -129.2786, -236.4418, -415.3599, -225.3812, -421.6030],
		[234.7994, -65.7769, 484.6168, -323.8803, 494.3981, -314.0401],
		[-148.9589, -39.4975, -436.7918, -226.4657, -430.3212, -236.0684],
		[213.2770, -131.3283, 380.4166, -405.7848, 390.3397, -399.4902],
		[-51.8931, -89.6034, -250.1286, -407.1978, -238.1729, -414.3546],
		[-105.5944, -120.7849, -303.3646, -370.3873, -291.3184, -379.4758],
		[11.1309, 343.3787, -58.7400, 691.3116, -72.0383, 688.3745],
		[311.1967, 139.2810, 658.5873, 184.4109, 657.3421, 193.1357],
		[231.1993, 255.3653, 513.6607, 501.2471, 503.8792, 512.0518],
		[226.8541, 275.9876, 480.4973, 535.8912, 472.5441, 543.4220],
		[220.7503, -59.9616, 474.4400, -333.6517, 482.7611, -325.6966],
		[-197.8409, 19.9403, -509.5402, -72.2146, -504.9354, -86.5583],
		[220.7129, -76.0591, 453.6710, -352.2417, 462.1093, -344.8975],
		[-109.6829, 317.2782, -308.4823, 574.3796, -321.1941, 564.0277],
		[199.6120, 292.9434, 417.6749, 588.6793, 410.0166, 594.1760],
		[90.2425, 353.7227, 133.0956, 700.0082, 120.3107, 701.3517],
		[46.2195, 325.5332, 21.5927, 702.4995, 10.4070, 701.6017],
		[-110.3536, 291.4215, -338.6493, 548.8298, -350.6197, 537.6940],
		[-28.3797, -131.4556, -161.2410, -452.1173, -149.0194, -456.9124],
		[-36.7405, -97.4553, -211.4136, -429.0547, -197.2507, -436.1371],
		[115.3790, -165.6190, 169.0089, -486.7395, 183.6055, -483.9579],
	]


static func _hero(card: Image, sprite_name: String, _theme: Dictionary) -> void:
	var source := (ArtLibrary.texture(sprite_name) as Texture2D).get_image()
	var used := source.get_used_rect()
	var sprite := source.get_region(Rect2i(used.position, used.size))
	var hero_scale := 1
	for candidate in [3, 2, 1]:
		if sprite.get_width() * candidate <= 112 and sprite.get_height() * candidate <= 112:
			hero_scale = candidate
			break
	if hero_scale > 1:
		sprite.resize(sprite.get_width() * hero_scale, sprite.get_height() * hero_scale, Image.INTERPOLATE_NEAREST)
	var hero := _outlined(sprite, 2, INK)
	var center := 64
	var ground := 152
	for bump in [[-40, 7], [-28, 10], [28, 10], [40, 7]]:
		var dx := int(bump[0])
		var radius := int(bump[1])
		_fill_ellipse(card, center + dx, ground + 2, radius, radius, INK)
		_fill_ellipse(card, center + dx, ground + 2, radius - 2, radius - 2, PAPER)
	_blit_clipped(card, hero, Vector2i(center - hero.get_width() / 2, ground - hero.get_height() + 4))


static func _right_column(card: Image, fields: Dictionary, theme: Dictionary) -> void:
	var name_images := _fit_big(str(fields["form_name"]), _name_ramp(), Color(str(theme["name_ext"])), 3)
	var rank_images := _fit_big(str(fields["rank_name"]), _as_colors(theme["rank_ramp"]), Color(str(theme["rank_ext"])), 2)
	var reborn := PixelFont.outlined_image("REBORN AS", PAPER)
	var reached := PixelFont.outlined_image("REACHED", PAPER)
	var tight := name_images.size() > 1 and rank_images.size() > 1
	var pad := 2 if tight else (4 if name_images.size() > 1 else 5)
	var line_gap := 0 if tight else 1
	var gap := 1 if tight else 3
	var name_h := _stack_height(name_images, line_gap)
	var plate_h := name_h + pad * 2
	var rank_h := _stack_height(rank_images, line_gap)
	var label_h := _content_h(reborn)
	var stack := label_h + gap + plate_h + 4 + gap + 14 + 2 + rank_h
	var y := 41 + maxi(0, int((121 - stack) / 2))
	_blit_centered(card, reborn, 191, y)
	y += label_h + gap
	var plate_top := y + 2
	var plate_bot := plate_top + plate_h
	var slant := 8
	var edge := Color(str(theme["plate_edge"]))
	_fill_polygon(card, [
		Vector2(118 + slant, plate_top - 2), Vector2(BASE, plate_top - 2),
		Vector2(BASE, plate_bot + 2), Vector2(118, plate_bot + 2),
	], edge)
	_fill_polygon(card, [
		Vector2(121 + slant, plate_top), Vector2(BASE, plate_top),
		Vector2(BASE, plate_bot), Vector2(121, plate_bot),
	], INK)
	var text_y := plate_top + pad
	for image in name_images:
		_blit_centered(card, image, 194, text_y)
		text_y += _content_h(image) + line_gap
	y = plate_bot + 2 + gap
	var tile := 12
	var tile_gap := 3
	var label_w := _content_w(reached)
	var row_w := label_w + 6 + 3 * tile + 2 * tile_gap
	var x := 191 - int(row_w / 2)
	_blit_content(card, reached, x, y + 2)
	x += label_w + 6
	var rank := int(fields["rank_reached"])
	for i in 3:
		var on := i < rank
		var tile_x := x + i * (tile + tile_gap)
		_plate(card, tile_x, y, tile_x + tile - 1, y + tile - 1, Color("f0a52a") if on else Color("3d4160"), INK, 1)
		_fill_rect(card, tile_x + 2, y + 2, tile_x + tile - 4, y + 2, Color("fff3a0") if on else Color("5a6488"))
		var digit := _plain_text(str(i + 1), INK if on else Color("8f9cc4"))
		_blit_centered(card, digit, tile_x + int(tile / 2), y + 3)
	y += 14 + (1 if tight else 2)
	for image in rank_images:
		_blit_centered(card, image, 191, y)
		y += _content_h(image) + line_gap


static func _stats(card: Image, fields: Dictionary) -> void:
	var top := 164
	var bottom := 236
	_plate(card, 6, top, BASE - 7, bottom, INK, Color("eb31bc"), 3)
	_fill_rect(card, 80, top + 6, 80, bottom - 6, Color("3d4160"))
	_fill_rect(card, 188, top + 6, 188, bottom - 6, Color("3d4160"))
	_blit_centered(card, _plain_text("LASTED", Color("a49fcf")), 43, top + 6)
	_blit_centered(card, _plain_text("SCORE", Color("a49fcf")), 134, top + 6)
	_blit_centered(card, _plain_text("DIED TO", Color("a49fcf")), 225, top + 6)
	var time_img := _fit_stat(str(fields["time"]))
	var score_img := _fit_stat(str(fields["score"]))
	_blit_centered(card, time_img, 43, top + 26)
	var score_y := top + 26 if score_img.get_height() > 24 else top + 30
	_blit_centered(card, score_img, 134, score_y)
	var killer := _killer_sprite(str(fields["killer_sprite"]))
	var slot_top := top + 15
	var slot_bot := bottom - 12
	var killer_y := slot_top + int((slot_bot - slot_top - killer.get_height()) / 2)
	_blit_clipped(card, killer, Vector2i(225 - killer.get_width() / 2, killer_y))
	_blit_centered(card, _plain_text(str(fields["killer_label"]), Color("ff9aa2")), 225, bottom - 10)


static func _gag(card: Image, gag: String) -> void:
	var image := _font_text(gag, Color("ffbcea"), 2, INK, Color("eb31bc"))
	if image.get_width() > 262:
		image = _font_text(gag, Color("ffbcea"), 1, INK, Color("eb31bc"))
	var y := 241 if image.get_height() > 12 else 247
	_blit_centered(card, image, 135, y)


static func _fit_big(text: String, ramp: Array, extrude: Color, max_scale: int) -> Array:
	for glyph_scale in range(max_scale, 1, -1):
		var depth := 3 if glyph_scale == 3 else 2
		var image := _big_text(text, glyph_scale, ramp, extrude, 2, depth, 1)
		if image.get_width() <= 150:
			return [image]
	var words := text.split(" ")
	if words.size() > 1:
		var best: Array = []
		for i in range(1, words.size()):
			var first := " ".join(words.slice(0, i))
			var second := " ".join(words.slice(i, words.size()))
			var images := [
				_big_text(first, 2, ramp, extrude, 2, 2, 1),
				_big_text(second, 2, ramp, extrude, 2, 2, 1),
			]
			var wide := maxi(images[0].get_width(), images[1].get_width())
			if wide <= 150 and (best.is_empty() or wide < int(best[0])):
				best = [wide, images]
		if not best.is_empty():
			return best[1]
	return [_big_text(text, 1, ramp, extrude, 2, 1, 1)]


static func _fit_stat(text: String) -> Image:
	var image := _big_text(text, 3, _name_ramp(), Color("eb31bc"), 2, 2, 0)
	if image.get_width() > 104:
		image = _big_text(text, 2, _name_ramp(), Color("eb31bc"), 2, 2, 0)
	return image


static func _big_text(text: String, glyph_scale: int, ramp: Array, extrude: Color, outline: int, depth: int, slant: int) -> Image:
	var glyphs: Dictionary = PixelFont.plain_glyphs()
	var atlas := PixelFont.plain_atlas()
	var rows := 8
	var width := 0
	for i in text.length():
		var ch := text.substr(i, 1)
		if glyphs.has(ch):
			width += int(glyphs[ch]["advance"]) * glyph_scale
	var mask_w := maxi(width + (rows - 1) * slant, 1)
	var mask_h := rows * glyph_scale
	var pad := outline + depth + 1
	var full_w := mask_w + pad * 2
	var full_h := mask_h + pad * 2
	var glyph_bits := PackedByteArray()
	glyph_bits.resize(full_w * full_h)
	glyph_bits.fill(0)
	var pen := pad
	for i in text.length():
		var ch := text.substr(i, 1)
		if not glyphs.has(ch):
			continue
		var glyph: Dictionary = glyphs[ch]
		var origin_x := int(glyph["x"])
		var origin_y := int(glyph["y"])
		var glyph_w := int(glyph["w"])
		var glyph_h := mini(int(glyph["h"]), rows)
		for yy in glyph_h:
			var shift := (rows - 1 - yy) * slant
			for xx in glyph_w:
				if PixelFont.sample_alpha(atlas, origin_x + xx, origin_y + yy) <= 0.5:
					continue
				for sy in glyph_scale:
					for sx in glyph_scale:
						var dx := pen + xx * glyph_scale + sx + shift
						var dy := pad + yy * glyph_scale + sy
						if dx >= 0 and dy >= 0 and dx < full_w and dy < full_h:
							glyph_bits[dy * full_w + dx] = 1
		pen += int(glyph["advance"]) * glyph_scale
	var outline_bits := _fill_notches(_dilate(glyph_bits, full_w, full_h, outline), full_w, full_h)
	var extrude_bits := PackedByteArray()
	extrude_bits.resize(full_w * full_h)
	extrude_bits.fill(0)
	for step in range(1, depth + 1):
		for y in full_h:
			var row := y * full_w
			for x in full_w:
				if outline_bits[row + x] == 0:
					continue
				var nx := x + step
				var ny := y + step
				if nx < full_w and ny < full_h:
					extrude_bits[ny * full_w + nx] = 1
	extrude_bits = _fill_notches(extrude_bits, full_w, full_h)
	var image := Image.create(full_w, full_h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ramp_n := ramp.size()
	for y in full_h:
		var row := y * full_w
		for x in full_w:
			var index := row + x
			if extrude_bits[index] != 0:
				image.set_pixel(x, y, extrude)
			if outline_bits[index] != 0:
				image.set_pixel(x, y, INK)
			if glyph_bits[index] != 0 and ramp_n > 0:
				var t := float(y - pad) / float(maxi(mask_h - 1, 1))
				var ramp_i := clampi(int(t * float(ramp_n)), 0, ramp_n - 1)
				image.set_pixel(x, y, ramp[ramp_i])
	_drop_isolated(image, extrude)
	return _crop(image)


static func _font_text(text: String, fill: Color, glyph_scale: int, outline_color: Color, shadow: Color) -> Image:
	var base := _mask_text(text)
	var w := int(base["w"])
	var h := int(base["h"])
	var bits: PackedByteArray = base["bits"]
	var outlined := _dilate(bits, w, h, 1)
	var image := Image.create(w + 1, h + 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			if outlined[y * w + x] == 0:
				continue
			if x + 1 < image.get_width() and y + 1 < image.get_height():
				image.set_pixel(x + 1, y + 1, shadow)
	for y in h:
		for x in w:
			if outlined[y * w + x] == 0:
				continue
			image.set_pixel(x, y, outline_color)
			if bits[y * w + x] != 0:
				image.set_pixel(x, y, fill)
	image = _crop(image)
	if glyph_scale > 1:
		image.resize(image.get_width() * glyph_scale, image.get_height() * glyph_scale, Image.INTERPOLATE_NEAREST)
	return image


static func _plain_text(text: String, fill: Color) -> Image:
	var base := _mask_text(text)
	var w := int(base["w"])
	var h := int(base["h"])
	var bits: PackedByteArray = base["bits"]
	var image := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			if bits[y * w + x] != 0:
				image.set_pixel(x, y, fill)
	return _crop(image)


static func _mask_text(text: String) -> Dictionary:
	var glyphs: Dictionary = PixelFont.plain_glyphs()
	var atlas := PixelFont.plain_atlas()
	var pad := 2
	var width := pad * 2
	var height := 9 + pad * 2
	for i in text.length():
		var ch := text.substr(i, 1)
		if glyphs.has(ch):
			width += int(glyphs[ch]["advance"])
	var bits := PackedByteArray()
	bits.resize(width * height)
	bits.fill(0)
	var pen := pad
	for i in text.length():
		var ch := text.substr(i, 1)
		if not glyphs.has(ch):
			continue
		var glyph: Dictionary = glyphs[ch]
		var origin_x := int(glyph["x"])
		var origin_y := int(glyph["y"])
		for yy in int(glyph["h"]):
			for xx in int(glyph["w"]):
				if PixelFont.sample_alpha(atlas, origin_x + xx, origin_y + yy) <= 0.5:
					continue
				var dx := pen + xx
				var dy := yy + pad
				if dx >= 0 and dy >= 0 and dx < width and dy < height:
					bits[dy * width + dx] = 1
		pen += int(glyph["advance"])
	return {"w": width, "h": height, "bits": bits}


static func _dilate(src: PackedByteArray, w: int, h: int, radius: int) -> PackedByteArray:
	var cur := src
	for _i in radius:
		var nxt := cur.duplicate()
		for y in h:
			for x in w:
				if cur[y * w + x] != 0:
					continue
				var hit := false
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						var nx := x + ox
						var ny := y + oy
						if nx < 0 or ny < 0 or nx >= w or ny >= h:
							continue
						if cur[ny * w + nx] != 0:
							hit = true
							break
					if hit:
						break
				if hit:
					nxt[y * w + x] = 1
		cur = nxt
	return cur


static func _fill_notches(src: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var cur := src.duplicate()
	var changed := true
	while changed:
		changed = false
		var add: Array[int] = []
		for y in h:
			for x in w:
				if cur[y * w + x] != 0:
					continue
				var n := 0
				if x + 1 < w and cur[y * w + x + 1] != 0:
					n += 1
				if x > 0 and cur[y * w + x - 1] != 0:
					n += 1
				if y + 1 < h and cur[(y + 1) * w + x] != 0:
					n += 1
				if y > 0 and cur[(y - 1) * w + x] != 0:
					n += 1
				if n >= 3:
					add.append(y * w + x)
		if not add.is_empty():
			changed = true
			for index in add:
				cur[index] = 1
	return cur


static func _drop_isolated(image: Image, extrude: Color) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var clear: Array[Vector2i] = []
	for y in h:
		for x in w:
			if image.get_pixel(x, y) != extrude:
				continue
			var n := 0
			if x + 1 < w and image.get_pixel(x + 1, y).a > 0.5:
				n += 1
			if x > 0 and image.get_pixel(x - 1, y).a > 0.5:
				n += 1
			if y + 1 < h and image.get_pixel(x, y + 1).a > 0.5:
				n += 1
			if y > 0 and image.get_pixel(x, y - 1).a > 0.5:
				n += 1
			if n <= 1:
				clear.append(Vector2i(x, y))
	for point in clear:
		image.set_pixel(point.x, point.y, Color(0, 0, 0, 0))


static func _crop(image: Image) -> Image:
	var used := image.get_used_rect()
	if used.size.x < 1 or used.size.y < 1:
		return image
	return image.get_region(Rect2i(used.position, used.size))


static func _stack_height(images: Array, line_gap: int) -> int:
	var total := 0
	for image in images:
		total += _content_h(image)
	if images.size() > 1:
		total += line_gap * (images.size() - 1)
	return total


static func _content_w(image: Image) -> int:
	return int(image.get_used_rect().size.x)


static func _content_h(image: Image) -> int:
	return int(image.get_used_rect().size.y)


static func _name_ramp() -> Array:
	return [Color("f2fbff"), Color("f2fbff"), Color("fff3a0"), Color("ffd84a"), Color("ffd84a"), Color("f0a52a")]


static func _as_colors(value: Variant) -> Array:
	var colors: Array = []
	for item in value:
		colors.append(Color(str(item)))
	return colors


static func _killer_sprite(file_name: String) -> Image:
	var source := (ArtLibrary.texture(file_name) as Texture2D).get_image()
	var used := source.get_used_rect()
	var crop_h := mini(44, int(used.size.y))
	var sprite := source.get_region(Rect2i(used.position, Vector2i(int(used.size.x), crop_h)))
	return _outlined(sprite, 1, Color("a49fcf"))


static func _outlined(source: Image, radius: int, color: Color) -> Image:
	var image := Image.create(source.get_width() + radius * 2, source.get_height() + radius * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x, y).a <= 0.5:
				continue
			for oy in range(-radius, radius + 1):
				for ox in range(-radius, radius + 1):
					if ox * ox + oy * oy > radius * radius + radius:
						continue
					image.set_pixel(x + radius + ox, y + radius + oy, color)
	image.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(radius, radius))
	return image


static func _blit_centered(card: Image, image: Image, cx: int, y: int) -> void:
	var used := image.get_used_rect()
	if used.size.x < 1:
		return
	_blit_clipped(card, image, Vector2i(cx - int(used.position.x + used.size.x / 2), y - int(used.position.y)))


static func _blit_content(card: Image, image: Image, x: int, y: int) -> void:
	var used := image.get_used_rect()
	if used.size.x < 1:
		return
	_blit_clipped(card, image, Vector2i(x - int(used.position.x), y - int(used.position.y)))


static func _blit_clipped(card: Image, image: Image, dest: Vector2i) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.5:
				continue
			var dx := dest.x + x
			var dy := dest.y + y
			if dx < 0 or dy < 0 or dx >= card.get_width() or dy >= card.get_height():
				continue
			card.set_pixel(dx, dy, pixel)


static func _fill_rect(card: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1 + 1, card.get_height())):
		for x in range(maxi(x0, 0), mini(x1 + 1, card.get_width())):
			card.set_pixel(x, y, color)


static func _fill_ellipse(card: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var nx := float(x - cx) / float(rx)
			var ny := float(y - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0 and x >= 0 and y >= 0 and x < card.get_width() and y < card.get_height():
				card.set_pixel(x, y, color)


static func _fill_polygon(card: Image, points: Array, color: Color) -> void:
	if points.size() < 3:
		return
	var min_y := card.get_height()
	var max_y := 0
	for point in points:
		var py := int(floor(float(point.y)))
		min_y = mini(min_y, py)
		max_y = maxi(max_y, int(ceil(float(point.y))))
	min_y = clampi(min_y, 0, card.get_height() - 1)
	max_y = clampi(max_y, 0, card.get_height() - 1)
	var count := points.size()
	for y in range(min_y, max_y + 1):
		var scan := float(y) + 0.5
		var xs: Array[float] = []
		for i in count:
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % count]
			var cross := (a.y <= scan and b.y > scan) or (b.y <= scan and a.y > scan)
			if not cross:
				continue
			var t := (scan - a.y) / (b.y - a.y)
			xs.append(a.x + t * (b.x - a.x))
		xs.sort()
		var pair := 0
		while pair + 1 < xs.size():
			var x_start := int(ceil(xs[pair]))
			var x_end := int(floor(xs[pair + 1]))
			for x in range(maxi(x_start, 0), mini(x_end + 1, card.get_width())):
				card.set_pixel(x, y, color)
			pair += 2


static func _plate(card: Image, x0: int, y0: int, x1: int, y1: int, fill: Color, edge: Color, cut: int) -> void:
	_fill_polygon(card, [
		Vector2(x0 + cut, y0 - 1), Vector2(x1 - cut, y0 - 1),
		Vector2(x1 + 1, y0 + cut - 1), Vector2(x1 + 1, y1 - cut + 1),
		Vector2(x1 - cut, y1 + 1), Vector2(x0 + cut, y1 + 1),
		Vector2(x0 - 1, y1 - cut + 1), Vector2(x0 - 1, y0 + cut - 1),
	], edge)
	_fill_polygon(card, [
		Vector2(x0 + cut, y0), Vector2(x1 - cut, y0),
		Vector2(x1, y0 + cut), Vector2(x1, y1 - cut),
		Vector2(x1 - cut, y1), Vector2(x0 + cut, y1),
		Vector2(x0, y1 - cut), Vector2(x0, y0 + cut),
	], fill)
