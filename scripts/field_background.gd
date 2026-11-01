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

## Decks wide enough for the 28px archer. Feet y is the top of the grass.
## The two higher islands are too narrow and too high for a 44px archer.
const ISLANDS: Array[Vector2] = [
	Vector2(81, 69),
	Vector2(358, 79),
]

var field_size := Vector2(TILE_W, TILE_H)
var scroll_sky := 0.0
var scroll_clouds := 0.0
var scroll_far := 0.0
var scroll_near := 0.0

func setup(_seed_value: int, size: Vector2) -> void:
	field_size = size
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func tick(delta: float, size: Vector2) -> void:
	field_size = size
	scroll_sky += delta * SCROLL_BASE * SKY_FACTOR
	scroll_clouds += delta * SCROLL_BASE * CLOUDS_FACTOR
	scroll_far += delta * SCROLL_BASE * FAR_FACTOR
	scroll_near += delta * SCROLL_BASE * NEAR_FACTOR
	if is_inside_tree():
		queue_redraw()

func island_feet(index: int) -> float:
	return ISLANDS[clampi(index, 0, ISLANDS.size() - 1)].y

func _draw() -> void:
	_blit("bg_sky.png", scroll_sky)
	_blit("bg_clouds.png", scroll_clouds)
	_blit("bg_far.png", scroll_far)
	_blit("bg_near.png", scroll_near)

func _blit(file_name: String, scroll: float) -> void:
	var tex := ArtLibrary.texture(file_name)
	if tex == null:
		return
	var offset := fposmod(scroll, TILE_W)
	var x := -offset
	var guard := 0
	while x < field_size.x and guard < 8:
		draw_texture(tex, Vector2(x, 0.0))
		x += TILE_W
		guard += 1
