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
var killer_name := ""
var grazed := false
var ignore_id := -1
var age := 0.0
var spin := 0.0

func setup(data: Dictionary, player_owned: bool) -> void:
	position = data["position"]
	velocity = data["velocity"]
	gravity = float(data.get("gravity", 0.0))
	damage = int(data.get("damage", 1))
	radius = float(data.get("radius", 4.0))
	splits = int(data.get("splits", 0))
	color = data.get("color", Color.WHITE)
	style = str(data.get("style", "blob"))
	killer_name = str(data.get("killer_name", ""))
	from_player = player_owned

func tick(delta: float) -> void:
	age += delta
	velocity.y += gravity * delta
	position += velocity * delta
	spin += delta * (9.0 if style == "stone" else 4.0)
	if is_inside_tree():
		queue_redraw()

func _draw() -> void:
	if style == "stone":
		draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
		draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), color)
		draw_rect(Rect2(-radius + 1, -radius + 1, radius, radius * 0.6), Color("fff1c2"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif style == "arrow":
		draw_rect(Rect2(-radius, -1.5, radius * 2.2, 3), Color("c9854a"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-radius - 4, 0),
			Vector2(-radius + 2, -4),
			Vector2(-radius + 2, 4),
		]), Color("f0d78c"))
	else:
		draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), color)
		draw_rect(Rect2(-radius * 0.4, -radius * 0.7, radius * 0.7, radius * 0.5), Color("f4fbff"))
