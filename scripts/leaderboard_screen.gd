extends Control
class_name LeaderboardScreen

## Top 50, all-time or today (UTC), overall or one form.
## The player's row is marked. If they sit outside the top 50, their rank is pinned.

signal closed
signal rename_requested

const ROW_GAP := 8
const ROW_PAD := 4
const ROW_INK := Color("f2fbff")
const ROW_MINE_INK := Color("100c14")

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
var _name_label: Label
var _period_buttons: Array[Button] = []
var _form_buttons: Array[Button] = []
var _header: Control
var _period_row: HBoxContainer
var _form_row: HBoxContainer
var _footer: HBoxContainer
var _list_ready := false
var _can_retry := false
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
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.gui_input.connect(_on_status_input)
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
	_me.clip_contents = true
	_me.add_theme_stylebox_override("panel", _row_style(true))
	add_child(_me)
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

## Local rows for a screenshot or a layout check. Does not call the server.
func preview(rows: Array, player_name: String = "") -> void:
	visible = true
	_period = "all"
	_form = ""
	_style_tabs()
	if _name_label != null and player_name != "":
		_name_label.text = player_name
	_token += 1
	_layout()
	_on_board({"ok": true, "rows": rows}, _token)

func _on_back() -> void:
	visible = false
	closed.emit()

func _reload() -> void:
	if _client == null:
		return
	_token += 1
	var token := _token
	_can_retry = false
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		_clear_rows()
		if Leaderboard.is_network_error(parsed):
			_show_unreachable()
		else:
			_can_retry = false
			_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_status.text = str(parsed.get("error", ""))
			_status.add_theme_color_override("font_color", Color("a49fcf"))
		_layout()
		return
	var rows: Array = parsed.get("rows", [])
	_clear_rows()
	_list_ready = true
	_can_retry = false
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rows.is_empty():
		_status.text = "No scores yet."
		_sync_pin()
		return
	_status.text = ""
	var row_h := float(_metrics()["row"])
	var row_w := _scroll.size.x
	var mine := -1
	for i in rows.size():
		var row: Dictionary = rows[i]
		var mine_row := bool(row.get("is_me", false))
		if mine_row:
			mine = i
		_list.add_child(_make_row(row, mine_row, row_h, _form == "", row_w))
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
		_clear_drawn(_me)
		_layout()
		return
	_me.visible = true
	_layout()
	_fill_row(_me, _pin, true, _me.size.y, _form == "", _me.size.x)

func _make_row(row: Dictionary, mine: bool, row_h: float, overall: bool, width: float) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, row_h)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _row_style(mine))
	if mine:
		panel.name = "me"
	_fill_row(panel, row, mine, row_h, overall, width)
	return panel

## Rank, name, score, and form are separate pixel-snapped strings. The yellow
## row uses the plain face so the outlined stroke cannot fatten the letters.
static func column_boxes(width: float, overall: bool) -> Dictionary:
	var scale := 2 if width + 0.5 >= _min_row_width(2, overall) else 1
	var rank_w := PixelFont.plain_advance("#9999") * scale
	var score_w := PixelFont.plain_advance("9,999,999") * scale
	var form_w := PixelFont.plain_advance("GOBLIN") * scale if overall else 0
	var you_w := PixelFont.plain_advance("YOU")
	var rank_x := float(ROW_PAD)
	var name_x := rank_x + rank_w + ROW_GAP
	var you_x := width - ROW_PAD - you_w
	var right := you_x - ROW_GAP
	var form_x := right
	if overall:
		form_x = right - form_w
		right = form_x - ROW_GAP
	var score_x := right - score_w
	var name_w := score_x - ROW_GAP - name_x
	return {
		"scale": scale,
		"rank_x": rank_x,
		"rank_w": float(rank_w),
		"name_x": name_x,
		"name_w": name_w,
		"score_x": score_x,
		"score_w": float(score_w),
		"form_x": form_x,
		"form_w": float(form_w),
		"you_x": you_x,
		"you_w": float(you_w),
	}

static func _min_row_width(scale: int, overall: bool) -> float:
	var rank_w := PixelFont.plain_advance("#9999") * scale
	var name_w := PixelFont.plain_advance("MMMMMMMMMMMM") * scale
	var score_w := PixelFont.plain_advance("9,999,999") * scale
	var form_w := PixelFont.plain_advance("GOBLIN") * scale if overall else 0
	var you_w := PixelFont.plain_advance("YOU")
	var gaps := 4 if overall else 3
	return float(ROW_PAD * 2 + rank_w + name_w + score_w + form_w + you_w + ROW_GAP * gaps)

func _fill_row(panel: Control, row: Dictionary, mine: bool, row_h: float, overall: bool, width: float) -> void:
	_clear_drawn(panel)
	if width < 32.0:
		return
	var boxes := column_boxes(width, overall)
	var scale := int(boxes["scale"])
	var ink := ROW_MINE_INK if mine else ROW_INK
	var outlined := not mine
	var rank := "#%d" % int(row.get("rank", 0))
	var who := str(row.get("name", ""))
	var points := ScoreRules.format_score(int(row.get("score", 0)))
	var form := Leaderboard.short_form(str(row.get("form", ""))) if overall else ""
	_place_text(panel, rank, ink, outlined, scale, float(boxes["rank_x"]), row_h, "Rank")
	var name_clip := Control.new()
	name_clip.name = "Name"
	name_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_clip.clip_contents = true
	name_clip.position = Vector2(float(boxes["name_x"]) - scale, 0)
	name_clip.size = Vector2(float(boxes["name_w"]) + scale * 2.0, row_h)
	panel.add_child(name_clip)
	_place_text(name_clip, who, ink, outlined, scale, float(scale), row_h, "NameText")
	var score_pen := float(boxes["score_x"]) + float(boxes["score_w"]) - PixelFont.plain_advance(points) * scale
	_place_text(panel, points, ink, outlined, scale, score_pen, row_h, "Score")
	if form != "":
		_place_text(panel, form, ink, outlined, scale, float(boxes["form_x"]), row_h, "Form")
	if mine:
		_place_text(panel, "YOU", ink, false, 1, float(boxes["you_x"]), row_h, "You")

func _place_text(parent: Control, text: String, fill: Color, outlined: bool, scale: int, pen_x: float, row_h: float, node_name: String) -> void:
	if text.is_empty():
		return
	var texture := PixelFont.row_texture(text, fill, outlined, scale)
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = texture.get_size()
	rect.custom_minimum_size = rect.size
	var y := int((row_h - rect.size.y) * 0.5)
	rect.position = Vector2(floorf(pen_x) - scale, y)
	parent.add_child(rect)

func _clear_drawn(panel: Control) -> void:
	if panel == null:
		return
	for child in panel.get_children():
		panel.remove_child(child)
		child.free()

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
		"row": 32.0 if tall else 26.0,
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
	var status_h := 28.0 if _can_retry else 14.0
	_status.position = Vector2(pad, y)
	_status.size = Vector2(width - pad * 2.0, status_h)
	y += status_h
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

func _show_unreachable() -> void:
	_can_retry = true
	_status.text = Leaderboard.UNREACHABLE
	_status.mouse_filter = Control.MOUSE_FILTER_STOP
	_status.add_theme_color_override("font_color", Color("a49fcf"))

func _on_status_input(event: InputEvent) -> void:
	if not _can_retry or not _is_press(event):
		return
	_status.accept_event()
	_reload()

func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT and mouse.device != InputEvent.DEVICE_ID_EMULATION
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

func _on_scroll_input(event: InputEvent) -> void:
	if _can_retry and _is_press(event):
		_scroll.accept_event()
		_reload()
		return
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
