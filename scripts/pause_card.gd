extends Panel
class_name PauseCard

## Centred pause guide. Three tabs, short lines, and the pickup icons.
## Resume, sound, and the store row share the bottom bar.
## Dragon copy is filled only for the current form, on the YOU tab.

signal resume_pressed

const BODY := Color("f2fbff")
const ACCENT := Color("ffbcea")
const FINAL := Color("ffe56a")
const KICKER := Color("ffd84a")
const INK := Color("100c14")

## kaito5x7 outlined is 9px. 18 is 2x body, 27 is 3x headings. Both are whole pixels.
const BODY_PX := 18
const HEAD_PX := 27
## Pickup descriptions are one step smaller so both columns fit on one line.
const EFFECT_PX := 9
## Bottom-bar labels are one step smaller so REMOVE ADS and RESTORE keep padding.
const BAR_PX := 9
const LINE := 22.0
const HEAD_H := 33.0

const PANEL_W := 428.0
const PANEL_H := 264.0
const INSET := 2.0
## Body text stays this far inside the gold border, on every side.
const PAD := 8.0
const TAB_H := 44.0
const BAR_H := 44.0
const RESUME_W := 120.0
## "SND OFF" at 18px needs more than a 44px square. Height stays 44.
const SOUND_W := 88.0
## Native icon size. Gem art is 8px and is drawn at 3x (24) inside this box.
const ICON := 28.0

var _font: Font
var _tab := PauseGuide.TAB_YOU
var _store := false
var _placeholders := false
var _form_id := 0
var _rank := 0
var _points := 0
var _split_ready := true
var _sprite_file := ""
var _portrait_scale := 2

var _tabs: Array[Button] = []
var _you: Control
var _portrait: Control
var _name: Label
var _rank_label: Label
var _next: Label
var _meter: Control
var _weapon: Label
var _traits: Array[Label] = []
var _pickups: Control
var _pickup_icons: Array[TextureRect] = []
var _pickup_names: Array[Label] = []
var _pickup_effects: Array[Label] = []
var _icon_px: Array[int] = []
var _footer: Label
var _controls: Control
var _control_labels: Array[Label] = []
var _resume: Button
var _remove_ph: Button
var _restore_ph: Button
var _sound_slot := Rect2()
var _remove_slot := Rect2()
var _restore_slot := Rect2()

func setup(font: Font) -> void:
	_font = font
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.bg_color.a = 0.96
	style.set_border_width_all(2)
	style.border_color = Color("f0d78c")
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	add_theme_stylebox_override("panel", style)
	for i in PauseGuide.TAB_NAMES.size():
		var tab := _button(PauseGuide.TAB_NAMES[i])
		tab.pressed.connect(_on_tab.bind(i))
		_tabs.append(tab)
		add_child(tab)
	_you = Control.new()
	_you.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_you)
	_portrait = _Portrait.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_you.add_child(_portrait)
	_name = _label(BODY, HEAD_PX)
	_rank_label = _label(ACCENT, BODY_PX)
	_next = _label(ACCENT, BODY_PX)
	_meter = _Meter.new()
	_weapon = _label(BODY, BODY_PX)
	_you.add_child(_name)
	_you.add_child(_rank_label)
	_you.add_child(_next)
	_you.add_child(_meter)
	_you.add_child(_weapon)
	# Trait lines. At most two short sentences, plus the slime split flag.
	for trait_slot in 3:
		var line := _label(BODY, BODY_PX)
		_traits.append(line)
		_you.add_child(line)
	_pickups = Control.new()
	_pickups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pickups.visible = false
	add_child(_pickups)
	for item in PauseGuide.pickups():
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.texture = ArtLibrary.texture(str(item["icon"]))
		var title := _label(KICKER, BODY_PX)
		title.text = str(item["name"])
		var effect := _label(BODY, BODY_PX)
		effect.text = str(item["effect"])
		_pickup_icons.append(icon)
		_pickup_names.append(title)
		_pickup_effects.append(effect)
		_icon_px.append(int(item["icon_px"]))
		_pickups.add_child(icon)
		_pickups.add_child(title)
		_pickups.add_child(effect)
	# The footer string stays in PauseGuide. A 22px line does not fit under the 28px grid.
	_footer = _label(KICKER, BODY_PX)
	_footer.text = PauseGuide.pickup_footer()
	_footer.visible = false
	_pickups.add_child(_footer)
	_controls = Control.new()
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.visible = false
	add_child(_controls)
	for line in PauseGuide.controls():
		var label := _label(BODY, BODY_PX)
		label.text = line
		_control_labels.append(label)
		_controls.add_child(label)
	_resume = _button("RESUME", BAR_PX, 4.0)
	_resume.pressed.connect(_on_resume)
	add_child(_resume)
	_remove_ph = _button("REMOVE ADS", BAR_PX, 4.0)
	_restore_ph = _button("RESTORE", BAR_PX, 4.0)
	_remove_ph.visible = false
	_restore_ph.visible = false
	add_child(_remove_ph)
	add_child(_restore_ph)
	_style_tabs()

func show_form(id: int, rank_index: int, points: int, split_ready: bool) -> void:
	_form_id = id
	_rank = rank_index
	_points = points
	_split_ready = split_ready
	var spec := FormCatalog.rank_spec(id, rank_index)
	_sprite_file = str(spec["sprite"])
	if id == FormCatalog.Id.SLIME and not split_ready and spec.has("sprite_small"):
		_sprite_file = str(spec["sprite_small"])
	_name.text = FormCatalog.display_name(id)
	_name.add_theme_color_override("font_color", FormCatalog.title_color(id))
	var total := FormCatalog.rank_table(id).size()
	_rank_label.text = "Rank %d/%d" % [rank_index + 1, total]
	var gate := FormCatalog.gate_for_next_rank(rank_index)
	var at_cap := gate < 0
	if at_cap:
		var level := Difficulty.power_level(points)
		_next.text = "POWER +%d" % level
		_next.add_theme_color_override("font_color", FINAL)
	else:
		_next.text = "Next form: %d/%d" % [maxi(points, 0), gate]
		_next.add_theme_color_override("font_color", ACCENT)
	(_meter as _Meter).set_fill(rank_index, HudLayout.fill_px(points, rank_index))
	_weapon.text = FormCatalog.guide_weapon(id, rank_index)
	var lines := FormCatalog.guide_trait_lines(id, rank_index, split_ready)
	for i in _traits.size():
		var label := _traits[i]
		label.visible = i < lines.size()
		label.text = lines[i] if i < lines.size() else ""
	(_portrait as _Portrait).set_sprite(_sprite_file, _portrait_scale)
	apply_layout()

func set_store_row(enabled: bool, placeholders: bool) -> void:
	_store = enabled
	_placeholders = placeholders and enabled
	_remove_ph.visible = _placeholders
	_restore_ph.visible = _placeholders
	apply_layout()

func open_for_runs(runs_started: int) -> void:
	show_tab(PauseGuide.tab_for_runs(runs_started))

func show_tab(index: int) -> void:
	_tab = clampi(index, 0, PauseGuide.TAB_NAMES.size() - 1)
	_you.visible = _tab == PauseGuide.TAB_YOU
	_pickups.visible = _tab == PauseGuide.TAB_PICKUPS
	_controls.visible = _tab == PauseGuide.TAB_CONTROLS
	_style_tabs()
	apply_layout()

func step_tab(dir: int) -> void:
	var count := PauseGuide.TAB_NAMES.size()
	show_tab(posmod(_tab + dir, count))

func tab_index() -> int:
	return _tab

func sound_slot() -> Rect2:
	return _sound_slot

func remove_slot() -> Rect2:
	return _remove_slot

func restore_slot() -> Rect2:
	return _restore_slot

func resume_control() -> Button:
	return _resume

func tab_controls() -> Array[Button]:
	return _tabs

func heading_text() -> String:
	return _name.text if _name != null else ""

func weapon_text() -> String:
	return _weapon.text if _weapon != null else ""

func trait_text() -> String:
	if _traits.is_empty():
		return ""
	var parts: PackedStringArray = []
	for label in _traits:
		if label.text != "":
			parts.append(label.text)
	return " ".join(parts)

func next_text() -> String:
	return _next.text if _next != null else ""

func rank_line() -> String:
	return _rank_label.text if _rank_label != null else ""

func pickup_text() -> String:
	var parts: PackedStringArray = []
	for label in _pickup_names:
		parts.append(label.text)
	for label in _pickup_effects:
		parts.append(label.text)
	return " ".join(parts)

func controls_text() -> String:
	var parts: PackedStringArray = []
	for label in _control_labels:
		parts.append(label.text)
	return " ".join(parts)

func apply_layout() -> void:
	if _resume == null or size.x < 8.0:
		return
	var width := size.x
	var height := size.y
	var inner_w := width - INSET * 2.0
	var tab_w := floorf(inner_w / float(_tabs.size()))
	for i in _tabs.size():
		var tab := _tabs[i]
		var extra := 0.0
		if i == _tabs.size() - 1:
			extra = inner_w - tab_w * float(_tabs.size())
		tab.position = Vector2(INSET + tab_w * float(i), INSET)
		tab.size = Vector2(tab_w + extra, TAB_H)
	var bar_y := height - INSET - BAR_H
	var resume_w := RESUME_W
	if _store:
		# Leave the remove-ads label its full 18px width beside SND OFF.
		resume_w = 112.0
	_resume.position = Vector2(INSET, bar_y)
	_resume.size = Vector2(resume_w, BAR_H)
	_sound_slot = Rect2(width - INSET - SOUND_W, bar_y, SOUND_W, BAR_H)
	if _store:
		var gap := 2.0
		var left := INSET + resume_w + gap
		var right := _sound_slot.position.x - gap
		var restore_w := 92.0
		var remove_w := maxf(right - left - gap - restore_w, 44.0)
		_remove_slot = Rect2(left, bar_y, remove_w, BAR_H)
		_restore_slot = Rect2(left + remove_w + gap, bar_y, restore_w, BAR_H)
	else:
		_remove_slot = Rect2()
		_restore_slot = Rect2()
	_place_button(_remove_ph, _remove_slot)
	_place_button(_restore_ph, _restore_slot)
	var content := Rect2(INSET + PAD, INSET + TAB_H + PAD, width - (INSET + PAD) * 2.0, bar_y - PAD - (INSET + TAB_H + PAD))
	for page in [_you, _pickups, _controls]:
		page.position = content.position
		page.size = content.size
		page.clip_contents = true
	var local := Rect2(Vector2.ZERO, content.size)
	_layout_you(local)
	_layout_pickups(local)
	_layout_controls(local)

func _layout_you(area: Rect2) -> void:
	if _name == null:
		return
	var frame := _frame_size(_sprite_file)
	var scale := 2
	var name_px := HEAD_PX
	var placed := false
	while not placed:
		var portrait := frame * float(scale)
		var text_x := area.position.x + portrait.x + 6.0
		var text_w := area.end.x - text_x
		if text_w < 80.0 and scale == 2:
			scale = 1
			continue
		var rows: Array[Dictionary] = []
		var name_h := HEAD_H if name_px == HEAD_PX else LINE
		rows.append({"node": _name, "h": name_h, "px": name_px})
		rows.append({"node": _rank_label, "h": LINE, "px": BODY_PX})
		var next_w := _text_width(_next.text, BODY_PX)
		var meter_w := 94.0
		var overflow := next_w > text_w + 0.5 or _text_width(_name.text, name_px) > text_w + 0.5
		if next_w + 6.0 + meter_w <= text_w:
			rows.append({"node": _next, "h": LINE, "px": BODY_PX, "meter": true})
		else:
			rows.append({"node": _next, "h": LINE, "px": BODY_PX})
			rows.append({"node": _meter, "h": 14.0, "meter_only": true})
		var weapon_w := _text_width(_weapon.text, BODY_PX)
		if weapon_w > text_w + 0.5:
			overflow = true
		rows.append({"node": _weapon, "h": LINE, "px": BODY_PX})
		for label in _traits:
			if not label.visible or label.text.is_empty():
				continue
			if _text_width(label.text, BODY_PX) > text_w + 0.5:
				overflow = true
			rows.append({"node": label, "h": LINE, "px": BODY_PX})
		var total := 0.0
		for row in rows:
			total += float(row["h"])
		var last_try := scale == 1 and name_px == BODY_PX
		if (total <= area.size.y + 0.5 and not overflow) or last_try:
			_portrait_scale = scale
			(_portrait as _Portrait).set_sprite(_sprite_file, scale)
			_portrait.position = Vector2(area.position.x, area.position.y)
			_portrait.size = Vector2(maxf(portrait.x, 1.0), area.size.y)
			var y := area.position.y + maxf((area.size.y - total) * 0.5, 0.0)
			y = floorf(y)
			for row in rows:
				var node := row["node"] as Control
				var h := float(row["h"])
				if row.has("meter_only"):
					node.position = Vector2(text_x, y + 1.0)
					node.size = Vector2(meter_w, 12.0)
				elif bool(row.get("meter", false)):
					(node as Label).add_theme_font_size_override("font_size", BODY_PX)
					(node as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
					node.position = Vector2(text_x, y)
					node.size = Vector2(next_w + 2.0, h)
					_meter.position = Vector2(text_x + next_w + 6.0, y + floorf((h - 12.0) * 0.5))
					_meter.size = Vector2(meter_w, 12.0)
				else:
					var label := node as Label
					var px := int(row["px"])
					label.add_theme_font_size_override("font_size", px)
					label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if bool(row.get("wrap", false)) else TextServer.AUTOWRAP_OFF
					label.position = Vector2(text_x, y)
					label.size = Vector2(text_w, h)
				y += h
			for label in _traits:
				if label.text.is_empty():
					label.visible = false
			placed = true
			continue
		if name_px == HEAD_PX:
			name_px = BODY_PX
			continue
		if scale == 2:
			scale = 1
			name_px = HEAD_PX
			continue
		placed = true

func _layout_pickups(area: Rect2) -> void:
	var cols := 2
	var gutter := 8.0
	var count := _pickup_names.size()
	var col_w := floorf((area.size.x - gutter) / float(cols))
	var row_count := int(ceil(float(count) / float(cols)))
	var y := area.position.y
	for r in row_count:
		var row_h := ICON + LINE
		for c in cols:
			var i := r * cols + c
			if i >= count:
				continue
			var x := area.position.x + float(c) * (col_w + gutter)
			var icon_px := float(_icon_px[i])
			var icon := _pickup_icons[i]
			icon.position = Vector2(x + floorf((ICON - icon_px) * 0.5), y + floorf((ICON - icon_px) * 0.5))
			icon.size = Vector2(icon_px, icon_px)
			var title := _pickup_names[i]
			title.position = Vector2(x + ICON + 4.0, y + floorf((ICON - LINE) * 0.5))
			title.size = Vector2(maxf(col_w - ICON - 4.0, 1.0), LINE)
			title.autowrap_mode = TextServer.AUTOWRAP_OFF
			title.clip_text = true
			var effect := _pickup_effects[i]
			effect.add_theme_font_size_override("font_size", EFFECT_PX)
			effect.autowrap_mode = TextServer.AUTOWRAP_OFF
			effect.clip_text = true
			effect.position = Vector2(x, y + ICON)
			effect.size = Vector2(col_w, LINE)
		y += row_h
	_footer.visible = false

func _layout_controls(area: Rect2) -> void:
	var y := area.position.y
	for label in _control_labels:
		label.position = Vector2(area.position.x, y)
		label.size = Vector2(area.size.x, LINE)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		y += LINE

func _style_tabs() -> void:
	for i in _tabs.size():
		var on := i == _tab
		var bg := Color("3a2c18") if on else Color("1a1422")
		var edge := Color("f0d78c") if on else Color("5c5348")
		var ink := KICKER if on else BODY
		_paint(_tabs[i], bg, edge)
		_tabs[i].add_theme_color_override("font_color", ink)
		_tabs[i].add_theme_color_override("font_hover_color", ink)
		_tabs[i].add_theme_color_override("font_pressed_color", ink)

func _place_button(button: Button, slot: Rect2) -> void:
	button.visible = _placeholders and slot.size.x >= 1.0
	if slot.size.x < 1.0:
		return
	button.position = slot.position
	button.size = slot.size

func _on_resume() -> void:
	resume_pressed.emit()

func _on_tab(index: int) -> void:
	show_tab(index)

func _text_width(text: String, px: int) -> float:
	if _font == null or text.is_empty():
		return 0.0
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x

func _frame_size(file_name: String) -> Vector2:
	if file_name.is_empty():
		return Vector2(26, 26)
	var src := ArtLibrary.frame_source(file_name, 0.0)
	if src.size.x < 1.0 or src.size.y < 1.0:
		return Vector2(26, 26)
	return src.size

func _button(text: String, px: int = BODY_PX, h_pad: float = 2.0) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", px)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, BODY)
	button.add_theme_color_override("font_disabled_color", Color("8d88a8"))
	_paint(button, Color("241428"), Color("f0d78c"), h_pad)
	return button

func _paint(button: Button, bg: Color, edge: Color, h_pad: float = 2.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(2)
	style.border_color = edge
	style.set_corner_radius_all(0)
	style.content_margin_left = h_pad
	style.content_margin_right = h_pad
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)

func _label(color: Color, px: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	return label

class _Portrait extends Control:
	var _file := ""
	var _scale := 2

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_sprite(file_name: String, scale: int) -> void:
		_file = file_name
		_scale = maxi(scale, 1)
		queue_redraw()

	func _draw() -> void:
		if _file.is_empty():
			return
		var src := ArtLibrary.frame_source(_file, 0.0)
		var tex := ArtLibrary.texture(ArtLibrary.loop_file(_file))
		if tex == null or src.size.x < 1.0:
			return
		var dest := src.size * float(_scale)
		var at := Vector2(0.0, floorf((size.y - dest.y) * 0.5))
		draw_texture_rect_region(tex, Rect2(at, dest), src)

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
		draw_texture_rect_region(fill, Rect2(Vector2(28, 3), Vector2(width, 6)), Rect2(0, 0, width, 6))
