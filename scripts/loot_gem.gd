extends Node2D
class_name LootGem

## A kill drops one of these. It drifts left with the field and is picked up on touch.
## It is not worth points. Goblins spend them on the slingshot.

var radius := 7.0
var drift := 92.0

func tick(delta: float) -> void:
	position.x -= drift * delta
	position.y += sin(position.x * 0.05) * 8.0 * delta
	if is_inside_tree():
		queue_redraw()

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -7),
		Vector2(6, 0),
		Vector2(0, 7),
		Vector2(-6, 0),
	]), Color("ffd56a"))
	draw_rect(Rect2(-2, -3, 3, 3), Color("fff6c8"))
