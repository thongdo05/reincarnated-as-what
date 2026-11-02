extends Node2D
class_name EvolveFx

## Sheets that ride on the form. The pop's anchor sits 34 px above the form.

var sheet := ""
var sheet_time := 0.0
var anchor_at := Vector2.ZERO
var playing := false
## Rank 4 uses a smaller EVOLVED! pop. Rank 5 draws FINAL FORM! instead.
var pop_scale := 1.0

func play(t: float, hold: float = -1.0) -> void:
	var stage := FxTimeline.evolve_stage(t, hold if hold >= 0.0 else FxTimeline.EVOLVE_HOLD)
	playing = stage != "done" and stage != "none"
	visible = playing
	if not playing:
		queue_redraw()
		return
	var frame := int(floor(t * FxTimeline.FPS + 0.0001))
	anchor_at = Vector2.ZERO
	if stage == "glow":
		sheet = "fx/fx_evolve_glow.png"
		sheet_time = float(frame) / FxTimeline.FPS
	elif stage == "flash":
		sheet = "fx/fx_evolve_flash.png"
		sheet_time = float(frame - 3) / FxTimeline.FPS
	else:
		sheet = "fx/fx_evolved_pop.png"
		sheet_time = maxf(t - 5.0 / FxTimeline.FPS, 0.0)
		anchor_at = Vector2(0, -34)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	if not playing or sheet.is_empty():
		return
	if sheet == "fx/fx_evolved_pop.png" and absf(pop_scale - 1.0) > 0.01:
		draw_set_transform(anchor_at, 0.0, Vector2(pop_scale, pop_scale))
		ArtLibrary.draw_loop(self, sheet, sheet_time, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	ArtLibrary.draw_loop(self, sheet, sheet_time, anchor_at)
