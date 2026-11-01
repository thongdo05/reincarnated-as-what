extends Node2D
class_name LootGem

## A Goblin kill drops a coin or a gem. It drifts left. Touching it scores and fills the meter.
## It does not upgrade the slingshot. Evolution does that.

var sprite_name := "gem.png"
var radius := 3.0
var drift := 42.0

func setup(file_name: String) -> void:
	sprite_name = file_name
	radius = ArtLibrary.radius_for(file_name, 0.65)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func tick(delta: float) -> void:
	position.x -= drift * delta
	position.y += sin(position.x * 0.08) * 10.0 * delta
	if is_inside_tree():
		queue_redraw()

func _draw() -> void:
	ArtLibrary.draw_anchored(self, sprite_name)
