extends Node2D
class_name LootGem

## A Goblin kill drops a coin or a gem. It drifts left. Touching it scores and fills the meter.
## It does not upgrade the slingshot. Evolution does that.

var sprite_name := "gem.png"
var radius := 3.0
var drift := 42.0
var age := 0.0
var life := 99.0

func setup(file_name: String) -> void:
	sprite_name = file_name
	radius = ArtLibrary.radius_for(file_name, 0.65)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func tick(delta: float) -> bool:
	age += delta
	position.x -= drift * delta
	position.y += sin(position.x * 0.08) * 10.0 * delta
	var remain := life - age
	if remain < 0.55:
		modulate.a = clampf(remain / 0.55, 0.0, 1.0)
	else:
		modulate.a = 1.0
	if is_inside_tree():
		queue_redraw()
	return age < life

## One pixel of vertical bob, sin(t * 4), drawn on top of the drift.
func bob_offset() -> float:
	return sin(age * 4.0)

func _draw() -> void:
	draw_set_transform(Vector2(0.0, bob_offset()), 0.0, Vector2.ONE)
	ArtLibrary.draw_anchored(self, sprite_name)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
