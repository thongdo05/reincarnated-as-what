extends RefCounted
class_name ShareCard

## 270x270 card, exported at 4x. Layout follows share/share_card_template.json.
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
	if form_id == FormCatalog.Id.GOBLIN:
		return "goblin"
	return "slime"

static func killer_id(killer_name: String) -> String:
	return str(NAME_TO_KILLER.get(killer_name, "floating_eye"))

static func resolve(run: Dictionary) -> Dictionary:
	_ensure()
	var forms: Dictionary = _config["forms"]
	var form := str(run.get("form", "slime"))
	if not forms.has(form):
		form = "slime"
	var spec: Dictionary = forms[form]
	var rank := clampi(int(run.get("rank_reached", 1)), 1, 3)
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
	var names: Array = spec["rank_names"]
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
	var core_a := Color(str(cores[0]))
	var core_b := Color(str(cores[1]))
	var origin := Vector2(64, 104)
	for y in BASE:
		for x in BASE:
			var delta := Vector2(x, y) - origin
			var dist := delta.length_squared()
			var color := bg
			if dist < 46.0 * 46.0:
				color = core_b
			elif dist < 58.0 * 58.0:
				color = core_a
			else:
				var turns := (atan2(delta.y, delta.x) + PI) / TAU * 16.0
				color = ray if posmod(int(floor(turns)), 2) == 0 else bg
			card.set_pixel(x, y, color)

static func _hero(card: Image, sprite_name: String, _theme: Dictionary) -> void:
	var source := (ArtLibrary.texture(sprite_name) as Texture2D).get_image()
	var used := source.get_used_rect()
	var sprite := source.get_region(Rect2i(used.position, used.size))
	var scale := 1
	for candidate in [3, 2, 1]:
		if sprite.get_width() * candidate <= 112 and sprite.get_height() * candidate <= 112:
			scale = candidate
			break
	if scale > 1:
		sprite.resize(sprite.get_width() * scale, sprite.get_height() * scale, Image.INTERPOLATE_NEAREST)
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
	var name_images := _fit_name(str(fields["form_name"]), _gold_ramp(), Color(str(theme["name_ext"])), 3)
	var rank_images := _fit_name(str(fields["rank_name"]), _ramp(theme["rank_ramp"]), Color(str(theme["rank_ext"])), 2)
	var reborn := PixelFont.outlined_image("REBORN AS", PAPER)
	var reached := PixelFont.outlined_image("REACHED", PAPER)
	var tight := name_images.size() > 1 and rank_images.size() > 1
	var gap := 1 if tight else 3
	var name_h := 0
	for image in name_images:
		name_h += image.get_height()
	var plate_h := name_h + (4 if tight else 10)
	var y := 48
	_blit_centered(card, reborn, 191, y)
	y += reborn.get_used_rect().size.y + gap
	var plate_top := y
	_fill_rect(card, 118, plate_top, 269, plate_top + plate_h, Color(str(theme["plate_edge"])))
	_fill_rect(card, 122, plate_top + 2, 269, plate_top + plate_h - 2, INK)
	var text_y := plate_top + 4
	for image in name_images:
		_blit_centered(card, image, 194, text_y)
		text_y += image.get_height()
	y = plate_top + plate_h + gap
	var tiles := 3
	var tile := 12
	var row_w := int(reached.get_used_rect().size.x) + 6 + tiles * tile + 6
	var x := 191 - row_w / 2
	_blit_clipped(card, reached, Vector2i(x, y))
	x += int(reached.get_used_rect().size.x) + 8
	var rank := int(fields["rank_reached"])
	for i in tiles:
		var on := i < rank
		_fill_rect(card, x, y, x + tile - 1, y + tile - 1, INK)
		_fill_rect(card, x + 1, y + 1, x + tile - 2, y + tile - 2, Color("f0a52a") if on else Color("3d4160"))
		var digit := PixelFont.outlined_image(str(i + 1), INK if on else Color("8f9cc4"))
		_blit_centered(card, digit, x + tile / 2, y + 2)
		x += tile + 3
	y += tile + 3
	for image in rank_images:
		_blit_centered(card, image, 191, y)
		y += image.get_height()

static func _stats(card: Image, fields: Dictionary) -> void:
	_fill_rect(card, 6, 164, 263, 236, Color("eb31bc"))
	_fill_rect(card, 8, 166, 261, 234, INK)
	_fill_rect(card, 80, 170, 81, 230, Color("3d4160"))
	_fill_rect(card, 188, 170, 189, 230, Color("3d4160"))
	_blit_centered(card, PixelFont.outlined_image("LASTED", Color("a49fcf")), 43, 170)
	_blit_centered(card, PixelFont.outlined_image("SCORE", Color("a49fcf")), 134, 170)
	_blit_centered(card, PixelFont.outlined_image("DIED TO", Color("a49fcf")), 225, 170)
	var time_img := _fit_stat(str(fields["time"]))
	var score_img := _fit_stat(str(fields["score"]))
	_blit_centered(card, time_img, 43, 188)
	_blit_centered(card, score_img, 134, 188)
	var killer := _killer_sprite(str(fields["killer_sprite"]))
	_blit_centered(card, killer, 225, 186)
	_blit_centered(card, PixelFont.outlined_image(str(fields["killer_label"]), Color("ff9aa2")), 225, 224)

static func _gag(card: Image, gag: String) -> void:
	var image := _phrase(gag, 2, Color("ffbcea"), INK, 1, 0, false)
	if image.get_width() > 262:
		image = _phrase(gag, 1, Color("ffbcea"), INK, 1, 0, false)
	_blit_centered(card, image, 135, 246)

static func _fit_name(text: String, ramp: Array, extrude: Color, max_scale: int) -> Array:
	for scale in range(max_scale, 1, -1):
		var image := _phrase(text, scale, PAPER, extrude, 2, 0, true, ramp)
		if image.get_width() <= 150:
			return [image]
	var words := text.split(" ")
	if words.size() > 1:
		var best: Array = []
		for i in range(1, words.size()):
			var first := " ".join(words.slice(0, i))
			var second := " ".join(words.slice(i, words.size()))
			var images := [
				_phrase(first, 2, PAPER, extrude, 2, 0, true, ramp),
				_phrase(second, 2, PAPER, extrude, 2, 0, true, ramp),
			]
			var wide := maxi(images[0].get_width(), images[1].get_width())
			if wide <= 150 and (best.is_empty() or wide < int(best[0])):
				best = [wide, images]
		if not best.is_empty():
			return best[1]
	return [_phrase(text, 1, PAPER, extrude, 1, 0, true, ramp)]

static func _fit_stat(text: String) -> Image:
	var image := _phrase(text, 3, PAPER, Color("eb31bc"), 2, 0, true, _gold_ramp())
	if image.get_width() > 104:
		image = _phrase(text, 2, PAPER, Color("eb31bc"), 2, 0, true, _gold_ramp())
	return image

static func _phrase(text: String, scale: int, _fill: Color, extrude: Color, depth: int, slant: int, ramped: bool, ramp: Array = []) -> Image:
	var glyphs: Dictionary = PixelFont.plain_glyphs()
	var atlas := PixelFont.plain_atlas()
	var advances := 0
	for i in text.length():
		var ch := text.substr(i, 1)
		if glyphs.has(ch):
			advances += int(glyphs[ch]["advance"])
	var width := advances * scale + depth + slant * 8 + 8
	var height := 12 * scale + depth + 4
	var image := Image.create(maxi(width, 4), maxi(height, 4), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var pen := 2
	for i in text.length():
		var ch := text.substr(i, 1)
		if not glyphs.has(ch):
			continue
		var glyph: Dictionary = glyphs[ch]
		_stamp_glyph(image, atlas, glyph, pen + depth, 2 + depth, scale, extrude, slant, false, ramp)
		_stamp_glyph(image, atlas, glyph, pen, 2, scale, PAPER, slant, ramped, ramp)
		pen += int(glyph["advance"]) * scale
	var used := image.get_used_rect()
	if used.size.x < 1 or used.size.y < 1:
		return image
	return image.get_region(Rect2i(used.position, used.size))

static func _stamp_glyph(image: Image, atlas: Image, glyph: Dictionary, pen_x: int, pen_y: int, scale: int, color: Color, slant: int, ramped: bool, ramp: Array) -> void:
	var origin := Vector2i(int(glyph["x"]), int(glyph["y"]))
	var size := Vector2i(int(glyph["w"]), int(glyph["h"]))
	for yy in size.y:
		var shift := (6 - mini(yy, 6)) * slant * scale
		var row_color := color
		if ramped and not ramp.is_empty():
			row_color = ramp[mini(yy, ramp.size() - 1)]
		for xx in size.x:
			if atlas.get_pixel(origin.x + xx, origin.y + yy).a <= 0.5:
				continue
			for sy in scale:
				for sx in scale:
					var dx := pen_x + xx * scale + sx + shift
					var dy := pen_y + yy * scale + sy
					if dx < 0 or dy < 0 or dx >= image.get_width() or dy >= image.get_height():
						continue
					image.set_pixel(dx, dy, row_color)

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

static func _gold_ramp() -> Array:
	return [Color("fff3a0"), Color("fff3a0"), Color("ffd84a"), Color("ffd84a"), Color("ffd84a"), Color("f0a52a"), Color("f0a52a")]

static func _ramp(value: Variant) -> Array:
	var colors: Array = value
	var ramp: Array = []
	for i in 7:
		ramp.append(Color(str(colors[mini(i * colors.size() / 7, colors.size() - 1)])))
	return ramp

static func _blit_centered(card: Image, image: Image, cx: int, y: int) -> void:
	if image.get_width() < 1:
		return
	var dest := Vector2i(cx - image.get_width() / 2, y)
	_blit_clipped(card, image, dest)

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
