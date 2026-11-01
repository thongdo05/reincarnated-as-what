extends Node2D
class_name Shot

var velocity := Vector2.ZERO
var gravity := 0.0
var damage := 1
var radius := 4.0
var splits := 0
var from_player := true
var color := Color.WHITE
var style := "blob"
var sprite_name := ""
var killer_name := ""
var grazed := false
var ignore_id := -1
var age := 0.0

func setup(data: Dictionary, player_owned: bool) -> void:
	position = data["position"]
	velocity = data["velocity"]
	gravity = float(data.get("gravity", 0.0))
	damage = int(data.get("damage", 1))
	radius = float(data.get("radius", 4.0))
	splits = int(data.get("splits", 0))
	color = data.get("color", Color.WHITE)
	style = str(data.get("style", "blob"))
	sprite_name = str(data.get("sprite", ""))
	killer_name = str(data.get("killer_name", ""))
	from_player = player_owned
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func tick(delta: float) -> void:
	age += delta
	velocity.y += gravity * delta
	position += velocity * delta
	if is_inside_tree():
		queue_redraw()

## The cell drawn this frame. Demon orbs advance through the pulse sheet.
## A one-frame shot returns the whole sprite.
func drawn_frame() -> Rect2:
	return ArtLibrary.frame_source(sprite_name, age)

func _draw() -> void:
	if sprite_name.is_empty():
		return
	# Art is already aimed: player shots face right, enemy shots face left. Do not flip.
	# draw_loop plays a strip (the demon orbs). A single frame still draws once.
	ArtLibrary.draw_loop(self, sprite_name, age)
