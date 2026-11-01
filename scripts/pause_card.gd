extends PanelContainer
class_name PauseCard

## Compact pause plate. Copy comes from FormCatalog so a new form is one table row.
## The plate stays clear of the pause and sound buttons, which sit on the right.

const BODY := Color("f2fbff")
const ACCENT := Color("ffbcea")
const FINAL := Color("ffe56a")
const KICKER := Color("ffd84a")

var _font: Font
var _title: Label
var _heading: Label
var _weapon: Label
var _trait: Label
var _next: Label
var _points: Label
var _meter: Control
var _row: HBoxContainer
var _inner_width := 360.0

func setup(font: Font) -> void:
	_font = font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var style := StyleBoxFlat.new()
	style.bg_color = Color("100c14")
	style.bg_color.a = 0.94
	style.set_border_width_all(2)
	style.border_color = Color("f0d78c")
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	_title = _label(KICKER)
	_heading = _label(BODY)
	_weapon = _label(BODY)
	_trait = _label(BODY)
	box.add_child(_title)
	box.add_child(_heading)
	box.add_child(_weapon)
	box.add_child(_trait)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 4)
	_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(_row)
	_next = _label(ACCENT, false)
	_meter = _Meter.new()
	_points = _label(BODY, false)
	_row.add_child(_next)
	_row.add_child(_meter)
	_row.add_child(_points)
	_title.text = "PAUSED"

func show_form(id: int, rank_index: int, points: int, split_ready: bool) -> void:
	_heading.text = FormCatalog.card_heading(id, rank_index)
	_heading.add_theme_color_override("font_color", FormCatalog.title_color(id))
	_weapon.text = "WEAPON  " + FormCatalog.weapon_line(id, rank_index)
	_trait.text = "TRAIT  " + FormCatalog.trait_line(id, split_ready)
	var at_cap := FormCatalog.gate_for_next_rank(rank_index) < 0
	_meter.visible = not at_cap
	_points.visible = not at_cap
	if at_cap:
		_next.text = "NEXT RANK  FINAL FORM"
		_next.add_theme_color_override("font_color", FINAL)
		_size_line(_next)
	else:
		_next.text = "NEXT RANK"
		_next.add_theme_color_override("font_color", ACCENT)
		_points.text = FormCatalog.next_rank_text(rank_index, points)
		_size_line(_next)
		_size_line(_points)
		(_meter as _Meter).set_fill(rank_index, HudLayout.fill_px(points, rank_index))
	_apply_width()

func set_card_width(width: float) -> void:
	_inner_width = maxf(width - 12.0, 80.0)
	custom_minimum_size = Vector2(width, 0)
	_apply_width()

func heading_text() -> String:
	return _heading.text if _heading != null else ""

func weapon_text() -> String:
	return _weapon.text if _weapon != null else ""

func trait_text() -> String:
	return _trait.text if _trait != null else ""

func next_text() -> String:
	return _next.text if _next != null else ""

func _apply_width() -> void:
	if _weapon == null:
		return
	for label in [_title, _heading, _weapon, _trait]:
		label.custom_minimum_size = Vector2(_inner_width, _text_height(label.text, _inner_width))

func _text_height(text: String, width: float) -> float:
	if text.is_empty() or _font == null:
		return 11.0
	var box := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, 9)
	return maxf(box.y, 11.0)

func _size_line(label: Label) -> void:
	var width := 4.0
	if _font != null and not label.text.is_empty():
		width = _font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	label.custom_minimum_size = Vector2(width, 11)

func _label(color: Color, wrap: bool = true) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	return label

class _Meter extends Control:
	var _rank := 0
	var _fill := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size = Vector2(94, 12)
		size = Vector2(94, 12)

	func set_fill(rank_index: int, fill_px: int) -> void:
		_rank = rank_index
		_fill = fill_px
		queue_redraw()

	func _draw() -> void:
		draw_texture(ArtLibrary.texture(HudLayout.meter_file(_rank)), Vector2.ZERO)
		if _fill <= 0:
			return
		var fill := ArtLibrary.texture("ui/hud_evo_meter_fill_64x6.png")
		var width := mini(_fill, HudLayout.FILL_FULL)
		# Same inset the HUD uses: fill sits 28px in and 3px down in the 94x12 frame.
		draw_texture_rect_region(fill, Rect2(Vector2(28, 3), Vector2(width, 6)), Rect2(0, 0, width, 6))
