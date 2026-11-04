extends Node2D
class_name Shot

var velocity := Vector2.ZERO
var gravity := 0.0
var damage := 1
var pierce := 0
var radius := 4.0
var splits := 0
var splash := 0
var splash_radius := 0.0
var hit_ids: Array[int] = []
var from_player := true
var color := Color.WHITE
var style := "blob"
var sprite_name := ""
var killer_name := ""
var grazed := false
var ignore_id := -1
var age := 0.0
var homing := 0.0
var cruise := 0.0
var expires := false
var life := 0.0

func setup(data: Dictionary, player_owned: bool) -> void:
	position = data["position"]
	velocity = data["velocity"]
	gravity = float(data.get("gravity", 0.0))
	damage = int(data.get("damage", 1))
	pierce = int(data.get("pierce", 0))
	radius = float(data.get("radius", 4.0))
	splits = int(data.get("splits", 0))
	splash = int(data.get("splash", 0))
	splash_radius = float(data.get("splash_radius", 0.0))
	color = data.get("color", Color.WHITE)
	style = str(data.get("style", "blob"))
	sprite_name = str(data.get("sprite", ""))
	killer_name = str(data.get("killer_name", ""))
	from_player = player_owned
	hit_ids.clear()
	grazed = false
	age = 0.0
	ignore_id = int(data.get("ignore_id", -1))
	homing = float(data.get("homing", 0.0))
	cruise = velocity.length()
	expires = bool(data.get("expires", false))
	life = float(data.get("life", 0.0))
	visible = bool(data.get("visible", true))
	modulate = Color.WHITE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func tick(delta: float) -> void:
	age += delta
	if expires:
		life -= delta
	velocity.y += gravity * delta
	position += velocity * delta
	if visible and is_inside_tree():
		queue_redraw()

## The cell drawn this frame. Demon orbs advance through the pulse sheet.
## A one-frame shot returns the whole sprite.
func drawn_frame() -> Rect2:
	return ArtLibrary.frame_source(sprite_name, age)

func _draw() -> void:
	if sprite_name.is_empty():
		return
	# Art is already aimed: player shots face right, enemy shots face left. Do not flip.
	# Player bullets stay translucent so enemy shots read through the stream.
	var tint := Color(1, 1, 1, 0.42) if from_player else Color.WHITE
	# The spiral skull is 8px. At 2x it still reads as a skull, and the hit stays inside it.
	var scale := 2.0 if sprite_name == BossCatalog.SPIRAL_SKULL else 1.0
	ArtLibrary.draw_loop(self, sprite_name, age, Vector2.ZERO, tint, scale)
	if HitLibrary.show:
		var role := "body" if from_player else "threat"
		var color := Color(0.45, 0.9, 1.0, 0.95) if from_player else Color(1.0, 0.55, 0.2, 0.95)
		HitLibrary.draw(self, sprite_name, role, color)
