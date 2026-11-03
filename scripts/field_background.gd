extends Node2D
class_name FieldBackground

## Four painted layers, each 480x270, tiled on x.
## Sky, then clouds, then far (castles, islands), then near (hills).
## Scroll factors: sky 0.05, clouds 0.15, far 0.3, near 0.6.
## Near stays at 28 px/s, so a planted archer still drifts with the ground.
## Enemies are not part of these layers. Island archers read scroll_far to stay on a deck.

const TILE_W := 480.0
const TILE_H := 270.0
const GROUND_FEET := 234.0
const SKY_FACTOR := 0.05
const CLOUDS_FACTOR := 0.15
const FAR_FACTOR := 0.3
const NEAR_FACTOR := 0.6
## 0.6 of this base is the previous near speed, 28 px/s.
const SCROLL_BASE := 28.0 / NEAR_FACTOR

## Decks on the redrawn far layer that hold the 28×44 archer.
## Feet y is the top grass row. The high right island would clip the skull.
const ISLANDS: Array[Vector2] = [
	Vector2(63, 43),
	Vector2(227, 59),
]

var field_size := Vector2(TILE_W, TILE_H)
var world_id := WorldCatalog.SKY_CASTLE
var scroll_sky := 0.0
var scroll_clouds := 0.0
var scroll_far := 0.0
var scroll_near := 0.0
var factor_sky := SKY_FACTOR
var factor_clouds := CLOUDS_FACTOR
var factor_far := FAR_FACTOR
var factor_near := NEAR_FACTOR
var tex_sky: Texture2D
var tex_clouds: Texture2D
var tex_far: Texture2D
var tex_near: Texture2D

func setup(_seed_value: int, size: Vector2) -> void:
	field_size = size
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Swap the four painted layers. Decks and the ground line stay put.
## Scroll restarts so the new tile is not already half off the left edge.
func apply_world(id: String) -> void:
	world_id = id
	var set := WorldCatalog.layers(id)
	if set.size() == 4:
		tex_sky = set[0]
		tex_clouds = set[1]
		tex_far = set[2]
		tex_near = set[3]
	var speeds := WorldCatalog.factors(id)
	if speeds.size() == 4:
		factor_sky = speeds[0]
		factor_clouds = speeds[1]
		factor_far = speeds[2]
		factor_near = speeds[3]
	scroll_sky = 0.0
	scroll_clouds = 0.0
	scroll_far = 0.0
	scroll_near = 0.0
	if is_inside_tree():
		queue_redraw()

func tick(delta: float, size: Vector2, scroll_scale: float = 1.0) -> void:
	field_size = size
	var scale := maxf(scroll_scale, 0.0)
	scroll_sky += delta * SCROLL_BASE * factor_sky * scale
	scroll_clouds += delta * SCROLL_BASE * factor_clouds * scale
	scroll_far += delta * SCROLL_BASE * factor_far * scale
	scroll_near += delta * SCROLL_BASE * factor_near * scale
	if is_inside_tree():
		queue_redraw()

func island_feet(index: int) -> float:
	return ISLANDS[clampi(index, 0, ISLANDS.size() - 1)].y

func _draw() -> void:
	_blit(tex_sky, "bg_sky.png", scroll_sky)
	_blit(tex_clouds, "bg_clouds.png", scroll_clouds)
	_blit(tex_far, "bg_far.png", scroll_far)
	_blit(tex_near, "bg_near.png", scroll_near)

func _blit(tex: Texture2D, fallback: String, scroll: float) -> void:
	if tex == null:
		tex = ArtLibrary.texture(fallback)
	if tex == null:
		return
	var offset := fposmod(scroll, TILE_W)
	var x := -offset
	var guard := 0
	while x < field_size.x and guard < 8:
		draw_texture(tex, Vector2(x, 0.0))
		x += TILE_W
		guard += 1
