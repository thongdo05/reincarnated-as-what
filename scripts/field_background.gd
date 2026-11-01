extends Node2D
class_name FieldBackground

var field_size := Vector2(360, 780)
var scroll := 0.0
var _motes: Array[Dictionary] = []

func setup(seed_value: int, size: Vector2) -> void:
	field_size = size
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 17
	_motes.clear()
	for i in 28:
		_motes.append({
			"x": rng.randf_range(20.0, maxf(size.x - 20.0, 40.0)),
			"y": rng.randf_range(0.0, maxf(size.y, 100.0)),
			"speed": rng.randf_range(18.0, 46.0),
			"shade": rng.randf_range(0.25, 0.55),
		})

func tick(delta: float, size: Vector2) -> void:
	field_size = size
	scroll += delta * 42.0
	queue_redraw()

func _draw() -> void:
	var width := field_size.x
	var height := field_size.y
	draw_rect(Rect2(0, 0, width, height), Color("100c14"))
	draw_rect(Rect2(0, 0, 14, height), Color("1b1424"))
	draw_rect(Rect2(width - 14, 0, 14, height), Color("1b1424"))
	var brick := 22.0
	var offset := fmod(scroll, brick)
	var y := -brick + offset
	while y < height:
		draw_rect(Rect2(2, y, 10, 12), Color("32283f"))
		draw_rect(Rect2(width - 12, y + 8.0, 10, 12), Color("32283f"))
		y += brick
	for mote in _motes:
		var my := fmod(float(mote["y"]) + scroll * float(mote["speed"]) / 42.0, height)
		var shade := float(mote["shade"])
		draw_rect(Rect2(float(mote["x"]), my, 2, 2), Color(shade, shade * 0.85, shade * 1.1))
