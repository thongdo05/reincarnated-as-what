extends Node2D
class_name LairTransition

## Crack-mask swap onto the dragon lair. Timings are the approved manifest:
## banner 0.4, flash 0.1, cracks 0.6, wipe 0.6, settle 0.8.
## The mask is screen-space. White shows the lair. The old world stays underneath
## until the wipe finishes, then the live background becomes the lair.

const BANNER := 0.4
const FLASH := 0.1
const CRACKS := 0.6
const WIPE := 0.6
const SETTLE := 0.8
const SWAP_AT := BANNER + FLASH + CRACKS + WIPE
const TOTAL := SWAP_AT + SETTLE
const FIELD := Vector2(480, 270)

const MASKS: Array[Texture2D] = [
	preload("res://art/worlds/dragon_lair/transition/crack_mask_r1.png"),
	preload("res://art/worlds/dragon_lair/transition/crack_mask_r2.png"),
	preload("res://art/worlds/dragon_lair/transition/crack_mask_r3.png"),
	preload("res://art/worlds/dragon_lair/transition/crack_mask_r4.png"),
	preload("res://art/worlds/dragon_lair/transition/crack_mask_r5.png"),
	preload("res://art/worlds/dragon_lair/transition/crack_mask_r6.png"),
	preload("res://art/worlds/dragon_lair/transition/crack_mask_r7.png"),
	preload("res://art/worlds/dragon_lair/transition/crack_mask_r8.png"),
]

var elapsed := 0.0
var running := false
var swapped := false
var _built := false
var _viewport: SubViewport
var _preview: FieldBackground
var _rect: ColorRect
var _mat: ShaderMaterial
var _rim_flip := false

static func blocks_at(t: float) -> bool:
	return t < SWAP_AT

func blocks_spawns() -> bool:
	return running and not swapped

func phase_name() -> String:
	if not running and swapped:
		return "done"
	if not running:
		return "idle"
	if elapsed < BANNER:
		return "banner"
	if elapsed < BANNER + FLASH:
		return "flash"
	if elapsed < BANNER + FLASH + CRACKS:
		return "cracks"
	if elapsed < SWAP_AT:
		return "wipe"
	return "settle"

func begin() -> void:
	running = true
	swapped = false
	elapsed = 0.0
	_ensure()
	visible = false
	z_index = 1

func cancel() -> void:
	running = false
	visible = false

func preview_background() -> FieldBackground:
	_ensure()
	return _preview

## Real-time clock. Returns true on the frame the lair should become the live world.
func advance(delta: float) -> bool:
	if not running:
		return false
	var before := elapsed
	elapsed += delta
	_place_on_screen()
	_paint()
	var just := false
	if not swapped and elapsed >= SWAP_AT:
		swapped = true
		just = true
		visible = false
	if elapsed >= TOTAL:
		running = false
		visible = false
	elif before < BANNER and elapsed >= BANNER:
		visible = true
	return just

func _place_on_screen() -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		position = Vector2.ZERO
		return
	# The playfield shakes. The mask stays locked to the screen.
	position = -parent.position

func _ensure() -> void:
	if _built:
		return
	_built = true
	_viewport = SubViewport.new()
	_viewport.name = "LairPreview"
	_viewport.size = Vector2i(int(FIELD.x), int(FIELD.y))
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)
	_preview = FieldBackground.new()
	_preview.setup(0, FIELD)
	_preview.apply_world(WorldCatalog.DRAGON_LAIR)
	_viewport.add_child(_preview)
	_rect = ColorRect.new()
	_rect.position = Vector2.ZERO
	_rect.size = FIELD
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://art/worlds/dragon_lair/lair_reveal.gdshader")
	_rect.material = _mat
	add_child(_rect)

func _paint() -> void:
	if _rect == null or _preview == null:
		return
	var phase := phase_name()
	if phase == "banner" or phase == "settle" or phase == "done" or phase == "idle":
		visible = phase == "flash"
		return
	visible = true
	var flash := 1.0 if phase == "flash" else 0.0
	z_index = 30 if phase == "flash" else 1
	var mask_i := MASKS.size() - 1
	var wipe_x := -4.0
	if phase == "cracks":
		var along := clampf((elapsed - BANNER - FLASH) / CRACKS, 0.0, 0.999)
		mask_i = clampi(int(along * float(MASKS.size())), 0, MASKS.size() - 1)
		wipe_x = FIELD.x + 8.0
	elif phase == "wipe":
		var along := clampf((elapsed - BANNER - FLASH - CRACKS) / WIPE, 0.0, 1.0)
		wipe_x = lerpf(FIELD.x, -4.0, along)
	if phase != "flash":
		_rim_flip = not _rim_flip
	var tex := _viewport.get_texture()
	_mat.set_shader_parameter("lair_tex", tex)
	_mat.set_shader_parameter("mask_tex", MASKS[mask_i])
	_mat.set_shader_parameter("wipe_x", wipe_x)
	_mat.set_shader_parameter("flash", flash)
	_mat.set_shader_parameter("rim_hot", 1.0 if _rim_flip else 0.0)
	_mat.set_shader_parameter("field", FIELD)

func scroll(delta: float, size: Vector2, scroll_scale: float) -> void:
	if _preview == null or not running:
		return
	_preview.tick(delta, size, scroll_scale)
