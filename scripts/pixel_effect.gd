extends Node2D
class_name PixelEffect

## One static frame, scaled and faded. The art has no animation strips.

var sprite_name := ""
var life := 0.4
var max_life := 0.4
var start_scale := 0.6
var end_scale := 1.4

func setup(file_name: String, at: Vector2, duration: float, from_scale: float, to_scale: float) -> void:
	sprite_name = file_name
	position = at
	life = duration
	max_life = duration
	start_scale = from_scale
	end_scale = to_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func tick(delta: float) -> bool:
	life -= delta
	queue_redraw()
	return life > 0.0

func _draw() -> void:
	if sprite_name.is_empty() or max_life <= 0.0:
		return
	var t := 1.0 - clampf(life / max_life, 0.0, 1.0)
	var scale := lerpf(start_scale, end_scale, t)
	var alpha := clampf(1.0 - smoothstep(0.25, 1.0, t), 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale, scale))
	ArtLibrary.draw_anchored(self, sprite_name, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
