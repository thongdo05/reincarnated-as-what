extends Node2D
class_name DeathFx

var elapsed := 0.0
var sprite_name := ""
var active := false
var crowned := false
var pop_name := ""
var flash_name := ""

func start(at: Vector2, sprite: String) -> void:
	position = at
	sprite_name = sprite
	elapsed = 0.0
	active = true
	visible = true
	crowned = FxTimeline.wears_crown(sprite)
	pop_name = FxTimeline.pop_file(ArtLibrary.art_bbox(sprite))
	flash_name = FxTimeline.flash_file(sprite)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	if not active or sprite_name.is_empty():
		return
	var frame := int(floor(elapsed * FxTimeline.FPS + 0.0001))
	if frame < 0 or frame > 10:
		return
	if frame <= 1:
		if ArtLibrary.has_file(flash_name):
			ArtLibrary.draw_anchored(self, flash_name)
		else:
			ArtLibrary.draw_loop(self, sprite_name, 0.0)
		ArtLibrary.draw_loop(self, "fx/fx_death_hit.png", float(frame) / FxTimeline.FPS)
	elif frame <= 4:
		ArtLibrary.draw_loop(self, pop_name, float(frame - 2) / FxTimeline.FPS)
	if frame >= 5 and frame <= 8:
		ArtLibrary.draw_loop(self, "fx/fx_death_puff.png", float(frame - 5) / FxTimeline.FPS)
	if crowned and frame >= 5 and frame <= 10:
		var head := Vector2(0.0, -ArtLibrary.anchor(sprite_name).y)
		ArtLibrary.draw_loop(self, "fx/fx_crown_fly.png", float(frame - 5) / FxTimeline.FPS, head)
