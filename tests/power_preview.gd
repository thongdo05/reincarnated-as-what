extends SceneTree

## Composites each power drop beside enemy shots, using the live sprites.
## godot --headless -s res://tests/power_preview.gd

func _initialize() -> void:
	pass

func _process(_delta: float) -> bool:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var kinds := [
		["bomb", "anvil.png", 0.55],
		["shield", "hit_flash.png", 1.0],
		["rapid", "slime_shot.png", 1.3],
		["magnet", "ui/hud_coin_icon.png", 1.0],
	]
	var shots := ["floating_eye_bolt.png", "arrow.png", "wyvern_shot.png"]
	var canvas := Image.create(480, 270, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("1a1424"))
	var row := 0
	for kind in kinds:
		var y := 28 + row * 60
		_label(canvas, str(kind[0]).to_upper(), 16, y - 14)
		_ring(canvas, 78, y + 8, 12)
		_blit(canvas, str(kind[1]), 78, y + 8, float(kind[2]))
		_blit(canvas, "graze_sparkle.png", 90, y - 2, 0.8)
		var x := 150
		for shot in shots:
			_blit(canvas, shot, x, y + 8, 1.0)
			x += 48
		row += 1
	var path := "/opt/cursor/artifacts/power_drops_vs_shots.png"
	canvas.save_png(path)
	print("WROTE %s" % path)
	quit(0)
	return true

func _label(image: Image, text: String, x: int, y: int) -> void:
	var tex := PixelFont.outlined_texture(text, Color("f2fbff"))
	_blit_image(image, tex.get_image(), x, y)

func _blit(image: Image, file_name: String, cx: int, cy: int, scale: float) -> void:
	var src := ArtLibrary.texture(file_name).get_image()
	if src == null:
		return
	var anchor := ArtLibrary.anchor(file_name)
	if scale != 1.0:
		var w := maxi(int(round(float(src.get_width()) * scale)), 1)
		var h := maxi(int(round(float(src.get_height()) * scale)), 1)
		src.resize(w, h, Image.INTERPOLATE_NEAREST)
		anchor = Vector2(anchor.x * scale, anchor.y * scale)
	_blit_image(image, src, cx - int(anchor.x), cy - int(anchor.y))

func _blit_image(image: Image, src: Image, x: int, y: int) -> void:
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	image.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(x, y))

func _ring(image: Image, cx: int, cy: int, radius: int) -> void:
	for deg in 48:
		var angle := TAU * float(deg) / 48.0
		for radius_px in [radius - 1, radius, radius + 1]:
			var x := cx + int(round(cos(angle) * float(radius_px)))
			var y := cy + int(round(sin(angle) * float(radius_px)))
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			image.set_pixel(x, y, Color("f2fbff"))
