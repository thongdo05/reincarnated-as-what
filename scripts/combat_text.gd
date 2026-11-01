extends Node2D
class_name CombatText

var items: Array[Dictionary] = []

func push(text: String, at: Vector2, color: Color) -> void:
	items.append({
		"text": text,
		"pos": at,
		"vel": Vector2(0, -36),
		"life": 0.7,
		"max_life": 0.7,
		"color": color,
		"size": 0.0,
	})

func tick(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for item in items:
		item["life"] = float(item["life"]) - delta
		item["pos"] = item["pos"] + item["vel"] * delta
		if float(item["life"]) > 0.0:
			keep.append(item)
	items = keep
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for item in items:
		var life := float(item["life"])
		var max_life := float(item["max_life"])
		var color: Color = item["color"]
		color.a = clampf(life / max_life, 0.0, 1.0)
		var pos: Vector2 = item["pos"]
		var text := str(item["text"])
		if font != null and not text.is_empty():
			draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
