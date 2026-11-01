extends Node2D
class_name PowerDrop

## Rare pickup. A steady bob, a white ring, and a sparkle keep it from reading
## as an enemy shot. The center icon is an existing sprite, scaled.

const LIFE := 3.1
const RING := Color(0.949, 0.984, 1.0, 0.95)

var kind := "bomb"
var sprite_name := "anvil.png"
var radius := 8.0
var drift := 26.0
var age := 0.0
var life := LIFE

func setup(drop_kind: String) -> void:
	kind = drop_kind
	match drop_kind:
		"shield":
			sprite_name = "hit_flash.png"
		"rapid":
			sprite_name = "slime_shot.png"
		"magnet":
			sprite_name = "ui/hud_coin_icon.png"
		_:
			kind = "bomb"
			sprite_name = "anvil.png"
	radius = 8.0
	age = 0.0
	life = LIFE
	visible = true
	modulate = Color.WHITE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func tick(delta: float) -> bool:
	age += delta
	position.x -= drift * delta
	var remain := life - age
	if remain < 0.5:
		modulate.a = clampf(remain / 0.5, 0.0, 1.0)
	if is_inside_tree():
		queue_redraw()
	return age < life

func bob_offset() -> float:
	return sin(age * 4.0) * 2.0

func _draw() -> void:
	var bob := bob_offset()
	draw_arc(Vector2(0.0, bob), 11.0, 0.0, TAU, 20, RING, 1.5, true)
	draw_set_transform(Vector2(0.0, bob), 0.0, _icon_scale())
	ArtLibrary.draw_anchored(self, sprite_name)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var spin := age * 5.0
	var spark := Vector2(cos(spin), sin(spin)) * 9.0 + Vector2(0.0, bob)
	draw_set_transform(spark, 0.0, Vector2(0.8, 0.8))
	ArtLibrary.draw_anchored(self, "graze_sparkle.png", Color(1, 1, 1, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _icon_scale() -> Vector2:
	if kind == "bomb":
		return Vector2(0.55, 0.55)
	if kind == "rapid":
		return Vector2(1.3, 1.3)
	return Vector2.ONE
