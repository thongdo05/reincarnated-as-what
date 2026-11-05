extends Node2D
class_name SheetFx

## One non-looping strip. Position is already the enemy anchor plus the
## manifest offset, and the sheet's own anchor is the frame centre.

var sprite_name := ""
var age := 0.0
var duration := 0.4

func setup(file_name: String, at: Vector2) -> void:
	sprite_name = file_name
	position = at
	age = 0.0
	duration = DragonPhase.sheet_time(file_name)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func tick(delta: float) -> bool:
	age += delta
	if is_inside_tree():
		queue_redraw()
	return age < duration

func _draw() -> void:
	if sprite_name == "":
		return
	ArtLibrary.draw_loop(self, sprite_name, age)
