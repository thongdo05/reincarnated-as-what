extends Control
class_name LeaderboardScreen

## Top 50, all-time or today (UTC), overall or one form.
## The player's row is marked. If they sit outside the top 50, their rank is pinned.

signal closed
signal rename_requested

const PERIODS: Array = [["all", "ALL-TIME"], ["daily", "DAILY"]]
const FORMS: Array = [
	["", "ALL"],
	["slime", "SLIME"],
	["goblin", "GOBLIN"],
	["vending_machine", "VEND"],
	["cat", "CAT"],
	["demon_lord", "DEMON"],
]

var _client: Leaderboard
var _font: Font
var _period := "all"
var _form := ""
var _token := 0
var _status: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _me: Control
var _me_label: Label
var _name_label: Label
var _period_buttons: Array[Button] = []
var _form_buttons: Array[Button] = []
var _header: Control
var _period_row: HBoxContainer
var _form_row: HBoxContainer
var _footer: HBoxContainer
var _list_ready := false
var _list_has_me := false
var _my_rank := -1
var _pin: Dictionary = {}

func setup(client: Leaderboard, font: Font) -> void:
	_client = client
	_font = font
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	z_index = 6
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("100c14")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_header = Control.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	var title := _label("LEADERBOARD", 18, Color("f0d78c"))
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(title)
	var back := _button("BACK", Color("241428"), Color("f2fbff"), 18)
	back.name = "Back"
	back.pressed.connect(_on_back)
	_header.add_child(back)
	_period_row = HBoxContainer.new()
	_period_row.add_theme_constant_override("separation", 6)
	add_child(_period_row)
	for entry in PERIODS:
		var period_button := _button(str(entry[1]), Color("241428"), Color("f2fbff"), 9)
		period_button.pressed.connect(show_period.bind(str(entry[0])))
		period_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_period_row.add_child(period_button)
		_period_buttons.append(period_button)
	_form_row = HBoxContainer.new()
	_form_row.add_theme_constant_override("separation", 4)
	add_child(_form_row)
	for entry in FORMS:
		var form_button := _button(str(entry[1]), Color("241428"), Color("f2fbff"), 9)
		form_button.pressed.connect(show_form.bind(str(entry[0])))
		form_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		form_button.clip_text = true
		_form_row.add_child(form_button)
		_form_buttons.append(form_button)
	_status = _label("", 9, Color("a49fcf"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll.gui_input.connect(_on_scroll_input)
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_list)
	_me = Panel.new()
	_me.visible = false
	_me.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_me.add_theme_stylebox_override("panel", _row_style(true))
	add_child(_me)
	_me_label = _label("", 9, Color("241428"))
	_me_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_me_label.offset_left = 6
	_me_label.offset_right = -6
	_me_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_me.add_child(_me_label)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 8)
	add_child(_footer)
	_name_label = _label("NO NAME", 9, Color("f2fbff"))
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer.add_child(_name_label)
	var rename := _button("RENAME", Color("14324f"), Color("f2fbff"), 9)
	rename.custom_minimum_size = Vector2(110, 36)
	rename.pressed.connect(func() -> void:
		rename_requested.emit()
	)
	_footer.add_child(rename)
	resized.connect(_layout)
	_style_tabs()
	_refresh_name()

func open() -> void:
	visible = true
	_period = "all"
	_form = ""
	_style_tabs()
	_refresh_name()
	_layout()
	_reload()

func dismiss() -> void:
	visible = false
	_token += 1

func show_period(period: String) -> void:
	_period = "daily" if period == "daily" else "all"
	_style_tabs()
	_reload()

func show_form(form: String) -> void:
	_form = form
	_style_tabs()
	_reload()

func set_player_name(player_name: String) -> void:
	_refresh_name(player_name)

func _on_back() -> void:
	visible = false
	closed.emit()

func _reload() -> void:
	if _client == null:
		return
	_token += 1
	var token := _token
	_status.text = "..."
	_status.add_theme_color_override("font_color", Color("a49fcf"))
	_clear_rows()
	_me.visible = false
	_list_ready = false
	_list_has_me = false
	_my_rank = -1
	_pin = {}
	_client.fetch_board(_form, _period, _on_board.bind(token))
	_client.fetch_rank(_form, _period, _on_rank.bind(token))

func _on_board(parsed: Dictionary, token: int) -> void:
	if token != _token or not visible:
		return
	if not bool(parsed.get("ok", false)):
		_status.text = "leaderboard offline"
		_status.add_theme_color_override("font_color", Color("a49fcf"))
		_clear_rows()
		return
	var rows: Array = parsed.get("rows", [])
	_clear_rows()
	_list_ready = true
	if rows.is_empty():
		_status.text = "No scores yet."
		_sync_pin()
		return
	_status.text = ""
	var row_h := float(_metrics()["row"])
	var mine := -1
	for i in rows.size():
		var row: Dictionary = rows[i]
		var mine_row := bool(row.get("is_me", false))
		if mine_row:
			mine = i
		_list.add_child(_make_row(row, mine_row, row_h, _form == ""))
	_list_has_me = mine >= 0
	_sync_pin()
	if mine >= 0:
		call_deferred("_scroll_to", mine, row_h)

func _on_rank(parsed: Dictionary, token: int) -> void:
	if token != _token or not visible:
		return
	if not bool(parsed.get("ok", false)):
		return
	var rows: Array = parsed.get("rows", [])
	if rows.is_empty() or typeof(rows[0]) != TYPE_DICTIONARY:
		_my_rank = 0
		_pin = {}
		_sync_pin()
		return
	_pin = rows[0]
	_my_rank = int(_pin.get("rank", 0))
	_sync_pin()

func _sync_pin() -> void:
	if not _list_ready or _list_has_me or _my_rank <= 0 or _pin.is_empty():
		_me.visible = false
		_layout()
		return
	_me.visible = true
	_me_label.text = _row_text(_pin, true, _form == "")
	_layout()

func _make_row(row: Dictionary, mine: bool, row_h: float, overall: bool) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, row_h)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _row_style(mine))
	if mine:
		panel.name = "me"
	var label := _label(_row_text(row, mine, overall), 9, Color("241428") if mine else Color("f2fbff"))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 4
	label.offset_right = -4
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	panel.add_child(label)
	return panel

func _row_text(row: Dictionary, mine: bool, overall: bool) -> String:
	var rank := int(row.get("rank", 0))
	var who := str(row.get("name", ""))
	var points := ScoreRules.format_score(int(row.get("score", 0)))
	var form := Leaderboard.short_form(str(row.get("form", ""))) if overall else ""
	var text := "#%d  %s  %s" % [rank, who, points]
	if form != "":
		text += "  " + form
	if mine:
		text += "  YOU"
	return text

func _row_style(mine: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f0d78c") if mine else Color("241428")
	style.set_border_width_all(1)
	style.border_color = Color("f0d78c") if mine else Color("3a3350")
	style.set_corner_radius_all(0)
	style.content_margin_left = 4
	style.content_margin_right = 4
	return style

func _scroll_to(index: int, row_h: float) -> void:
	if _scroll == null:
		return
	_scroll.scroll_vertical = int(maxf(index * (row_h + 2.0) - 8.0, 0.0))

func _clear_rows() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()

func _refresh_name(player_name: String = "") -> void:
	if _name_label == null or _client == null:
		return
	var shown := player_name if player_name != "" else _client.player_name()
	if shown == "":
		_name_label.text = "NO NAME"
		return
	_name_label.text = shown

func _style_tabs() -> void:
	for i in _period_buttons.size():
		_paint(_period_buttons[i], str(PERIODS[i][0]) == _period)
	for i in _form_buttons.size():
		_paint(_form_buttons[i], str(FORMS[i][0]) == _form)

func _paint(button: Button, selected: bool) -> void:
	var bg := Color("f0d78c") if selected else Color("241428")
	var ink := Color("241428") if selected else Color("f2fbff")
	var edge := Color("f0d78c") if selected else Color("f2fbff")
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = bg
		style.set_border_width_all(2)
		style.border_color = edge
		style.set_corner_radius_all(0)
		style.content_margin_left = 4
		style.content_margin_right = 4
		button.add_theme_stylebox_override(state, style)

func _metrics() -> Dictionary:
	var tall := size.y >= 420.0
	return {
		"tab": 44.0 if tall else 36.0,
		"row": 32.0 if tall else 22.0,
		"header": 44.0 if tall else 36.0,
		"pad": 8.0 if tall else 6.0,
	}

func _layout() -> void:
	if _header == null:
		return
	var m: Dictionary = _metrics()
	var pad := float(m["pad"])
	var header_h := float(m["header"])
	var tab_h := float(m["tab"])
	var width := size.x
	var y := pad
	_header.position = Vector2(pad, y)
	_header.size = Vector2(width - pad * 2.0, header_h)
	var back := _header.get_node("Back") as Button
	var title := _header.get_node("Title") as Label
	if back != null:
		back.position = Vector2(_header.size.x - 88.0, 0)
		back.size = Vector2(88, header_h)
		back.custom_minimum_size = back.size
	if title != null:
		title.position = Vector2(0, 0)
		title.size = Vector2(maxf(_header.size.x - 96.0, 40.0), header_h)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	y += header_h + 4.0
	_period_row.position = Vector2(pad, y)
	_period_row.size = Vector2(width - pad * 2.0, tab_h)
	for child in _period_row.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.y = tab_h
	y += tab_h + 4.0
	_form_row.position = Vector2(pad, y)
	_form_row.size = Vector2(width - pad * 2.0, tab_h)
	for child in _form_row.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.y = tab_h
	y += tab_h + 2.0
	_status.position = Vector2(pad, y)
	_status.size = Vector2(width - pad * 2.0, 14)
	y += 14.0
	var footer_h := tab_h
	var me_h := float(m["row"]) + 6.0 if _me.visible else 0.0
	var bottom := size.y - pad - footer_h
	if me_h > 0.0:
		_me.position = Vector2(pad, bottom - me_h)
		_me.size = Vector2(width - pad * 2.0, me_h - 4.0)
		bottom -= me_h
	_footer.position = Vector2(pad, size.y - pad - footer_h)
	_footer.size = Vector2(width - pad * 2.0, footer_h)
	_scroll.position = Vector2(pad, y)
	_scroll.size = Vector2(width - pad * 2.0, maxf(bottom - y, 24.0))

func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_scroll.scroll_vertical -= int(drag.relative.y)
		_scroll.accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_scroll.scroll_vertical -= int(motion.relative.y)
			_scroll.accept_event()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			_scroll.scroll_vertical -= 24
			_scroll.accept_event()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			_scroll.scroll_vertical += 24
			_scroll.accept_event()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(caption: String, bg: Color, ink: Color, font_size: int) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(2)
	style.border_color = Color("f2fbff")
	style.set_corner_radius_all(0)
	style.content_margin_left = 4
	style.content_margin_right = 4
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	return button
