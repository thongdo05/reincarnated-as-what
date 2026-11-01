extends Node2D
class_name FlappyGate

## One Flappy-style opening. Both columns are the existing anvil hazard, tiled.
## There is no new wall art and no drawn rectangle.

const SPRITE := "anvil.png"
const STEP := 12.0
const COL_X: Array[float] = [0.0, 16.0]
const STAGGER := 6.0
## Anvil threat shapes extend about this far past the anchor, so the removed
## band is the flight opening plus this pad. The clear corridor is `gap_height`.
const THREAT_PAD := 8.0

var gap_center := 120.0
var gap_height := 100.0
var _cells: Array[Vector2] = []

func setup(at_x: float, center: float, opening: float, floor_y: float) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2
	position = Vector2(at_x, 0.0)
	gap_center = center
	gap_height = opening
	_cells.clear()
	var y := 0.0
	while y <= floor_y:
		_add_cell(COL_X[0], y, center, opening, floor_y)
		_add_cell(COL_X[1], y + STAGGER, center, opening, floor_y)
		y += STEP

func tick(delta: float, speed: float) -> void:
	position.x -= speed * delta
	queue_redraw()

func offscreen() -> bool:
	return position.x < -80.0

func hits_ship(ship: PlayerShip) -> bool:
	if ship == null:
		return false
	# "hurt" is the player's full-body shape, not a small core.
	var file := ship.sprite_name()
	for cell in _cells:
		var at := Vector2(position.x + cell.x, cell.y)
		if HitLibrary.overlaps(ship.position, file, "hurt", at, SPRITE, "threat"):
			return true
	return false

func wall_point() -> Vector2:
	if _cells.is_empty():
		return position
	var cell := _cells[0]
	return Vector2(position.x + cell.x, cell.y)

func wall_sprite() -> String:
	return SPRITE

func cell_count() -> int:
	return _cells.size()

func flight_top() -> float:
	return gap_center - gap_height * 0.5

func flight_bottom() -> float:
	return gap_center + gap_height * 0.5

func has_both_sides() -> bool:
	var above := false
	var below := false
	var top := flight_top()
	var bottom := flight_bottom()
	for cell in _cells:
		if cell.y < top:
			above = true
		elif cell.y > bottom:
			below = true
	return above and below

func _add_cell(x: float, y: float, center: float, opening: float, floor_y: float) -> void:
	if y < -2.0 or y > floor_y:
		return
	if absf(y - center) < opening * 0.5 + THREAT_PAD:
		return
	_cells.append(Vector2(x, y))

func _draw() -> void:
	var tex := ArtLibrary.texture(SPRITE)
	if tex == null:
		return
	var origin := ArtLibrary.anchor(SPRITE)
	for cell in _cells:
		draw_texture(tex, cell - origin)
