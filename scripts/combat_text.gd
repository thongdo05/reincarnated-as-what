extends Node2D
class_name CombatText

var items: Array[Dictionary] = []

const CALLOUTS: Array[String] = ["WINNER!", "OVERDRIVE", "BOMB", "TAKEOVER!"]

## One banner at a time. A new WINNER! / OVERDRIVE / POWER replaces the one
## on screen so the pops do not stack on the ship.
func push_callout(text: String, at: Vector2, color: Color, life: float = 0.4) -> void:
	var kept: Array[Dictionary] = []
	for item in items:
		if _is_callout(str(item["text"])):
			continue
		kept.append(item)
	items = kept
	push(text, at, color, life)

func _is_callout(text: String) -> bool:
	if CALLOUTS.has(text):
		return true
	return text.begins_with("POWER")

func push(text: String, at: Vector2, color: Color, life: float = 0.34) -> void:
	if items.size() >= 6:
		items.remove_at(0)
	items.append({
		"text": text,
		"pos": at,
		"vel": Vector2(0, -22),
		"life": life,
		"max_life": life,
		"color": color,
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
	for item in items:
		var life := float(item["life"])
		var max_life := float(item["max_life"])
		var color: Color = item["color"]
		var text := str(item["text"])
		if text.is_empty():
			continue
		var fill := Color(color.r, color.g, color.b, 1.0)
		draw_texture(PixelFont.outlined_texture(text, fill), item["pos"] - Vector2(PixelFont.PAD, PixelFont.PAD), Color(1, 1, 1, clampf(life / max_life, 0.0, 1.0)))
