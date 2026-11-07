extends Control
class_name NamePrompt

## Name entry. The web export asks with window.prompt. iOS Safari does not
## deliver keystrokes into a Godot LineEdit, and while that field is editing
## the web shell refocuses a hidden IME node, so OK, CANCEL, and other buttons
## miss taps after the keyboard closes. Desktop builds keep this dialog.

signal decided(clean: String, source: String)
signal cancelled

const PROMPT_MESSAGE := "Your leaderboard name (1-12 letters, numbers, spaces, or -)"

var source := ""
var _font: Font
var _edit: LineEdit
var _error: Label
var _asking := false
var _picker := false
var _picker_value := ""
var _picker_name: Label

func setup(font: Font) -> void:
	_font = font
	if CrazyGamesHost.wanted():
		_picker = true
		_setup_picker()
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	z_index = 8
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("100c14")
	style.set_border_width_all(2)
	style.border_color = Color("f0d78c")
	style.set_corner_radius_all(0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_top = 6
	box.offset_right = -8
	box.offset_bottom = -6
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var title := _label("YOUR NAME", 18, Color("f0d78c"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := _label(Leaderboard.FORMAT_HINT, 9, Color("a49fcf"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	_edit = LineEdit.new()
	_edit.virtual_keyboard_enabled = not OS.has_feature("web")
	_edit.virtual_keyboard_show_on_focus = not OS.has_feature("web")
	_edit.max_length = 12
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.caret_blink = true
	_edit.context_menu_enabled = false
	_edit.custom_minimum_size = Vector2(0, 36)
	_edit.add_theme_font_override("font", _font)
	_edit.add_theme_font_size_override("font_size", 18)
	_edit.add_theme_color_override("font_color", Color("f2fbff"))
	_edit.add_theme_color_override("font_uneditable_color", Color("f2fbff"))
	_edit.add_theme_color_override("font_placeholder_color", Color("a49fcf"))
	_edit.add_theme_color_override("caret_color", Color("f0d78c"))
	var field := StyleBoxFlat.new()
	field.bg_color = Color("241428")
	field.set_border_width_all(2)
	field.border_color = Color("f2fbff")
	field.set_content_margin_all(4)
	field.set_corner_radius_all(0)
	for state in ["normal", "focus", "read_only"]:
		_edit.add_theme_stylebox_override(state, field)
	if _browser_prompt():
		# A focused LineEdit on the web export starts Godot's IME focus timer.
		_edit.editable = false
		_edit.focus_mode = Control.FOCUS_NONE
		_edit.gui_input.connect(_on_web_edit_tap)
	else:
		_edit.text_submitted.connect(func(_text: String) -> void:
			_confirm()
		)
	box.add_child(_edit)
	_error = _label("", 9, Color("ffd84a"))
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.custom_minimum_size = Vector2(0, 14)
	box.add_child(_error)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var ok := _button("OK", Color("f0d78c"), Color("241428"))
	ok.pressed.connect(_confirm)
	var cancel := _button("CANCEL", Color("241428"), Color("f2fbff"))
	cancel.pressed.connect(_cancel)
	row.add_child(ok)
	row.add_child(cancel)

func open(current: String, from: String, ask := true) -> void:
	source = from
	_error.text = ""
	if _picker:
		var shown := Leaderboard.clean_name(current)
		if shown == "" and CrazyGamesHost.suggested_name() != "":
			shown = CrazyGamesHost.suggested_name()
		_picker_value = shown
		_refresh_picker_name()
		visible = true
		return
	_edit.text = Leaderboard.clean_name(current)
	if _browser_prompt():
		# Pass ask=false when the caller is about to show_error. The prompt
		# would cover that message, and a filter rejection is not a fresh tap.
		_release_stuck_input()
		if ask:
			_ask_browser()
		return
	visible = true
	_edit.grab_focus()
	_edit.caret_column = _edit.text.length()

func close() -> void:
	visible = false
	if _browser_prompt():
		_release_stuck_input()
	elif _edit != null and _edit.has_focus():
		_edit.release_focus()

func show_error(message: String) -> void:
	# The filter message stays on this dialog. OK asks again on the web export.
	visible = true
	_error.text = message
	if _browser_prompt():
		_release_stuck_input()

func current_text() -> String:
	if _picker:
		return _picker_value
	if _edit == null:
		return ""
	return _edit.text

func place_for(viewport: Vector2) -> void:
	if _picker:
		var panel_w := minf(468.0, maxf(viewport.x - 8.0, 220.0))
		var panel_h := minf(266.0, maxf(viewport.y - 4.0, 180.0))
		position = Vector2(maxf((viewport.x - panel_w) * 0.5, 2.0), maxf((viewport.y - panel_h) * 0.5, 2.0))
		size = Vector2(panel_w, panel_h)
		custom_minimum_size = size
		return
	var width := minf(440.0, maxf(viewport.x - 16.0, 160.0))
	var height := 146.0
	position = Vector2(maxf((viewport.x - width) * 0.5, 8.0), 4.0)
	size = Vector2(width, height)
	custom_minimum_size = size

## null and blank mean the player dismissed the prompt. Anything else is a
## candidate for the same clean_name / local_name_error rules as the dialog.
static func interpret_prompt(raw: Variant) -> Dictionary:
	if raw == null:
		return {"action": "cancel", "name": ""}
	var clean := Leaderboard.clean_name(str(raw))
	if clean == "":
		return {"action": "cancel", "name": ""}
	return {"action": "submit", "name": clean}

static func prompt_js(current: String) -> String:
	return "window.prompt(%s, %s)" % [
		JSON.stringify(PROMPT_MESSAGE),
		JSON.stringify(Leaderboard.clean_name(current)),
	]

static func uses_window_prompt(web: bool, crazygames: bool) -> bool:
	return web and not crazygames


func _browser_prompt() -> bool:
	return uses_window_prompt(OS.has_feature("web"), CrazyGamesHost.wanted())

func _ask_browser() -> void:
	if _asking or not _browser_prompt():
		return
	_asking = true
	var result: Variant = JavaScriptBridge.eval(prompt_js(_edit.text), true)
	_asking = false
	_release_stuck_input()
	var parsed := interpret_prompt(result)
	if str(parsed.get("action", "")) == "cancel":
		if not visible:
			cancelled.emit()
		return
	var clean := str(parsed.get("name", ""))
	_edit.text = clean
	decided.emit(clean, source)

func _confirm() -> void:
	if _browser_prompt():
		_ask_browser()
		return
	var clean := Leaderboard.clean_name(current_text())
	if _picker:
		_picker_value = clean
		_refresh_picker_name()
	elif _edit != null:
		_edit.text = clean
	decided.emit(clean, source)

func _cancel() -> void:
	close()
	cancelled.emit()

func _on_web_edit_tap(event: InputEvent) -> void:
	if not _browser_prompt() or not _is_press(event) or _is_emulated_mouse(event):
		return
	accept_event()
	_ask_browser()

func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

func _is_emulated_mouse(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION

func _release_stuck_input() -> void:
	if _edit != null:
		_edit.release_focus()
		if _edit.has_method("unedit"):
			_edit.unedit()
		if _edit.has_method("cancel_ime"):
			_edit.cancel_ime()
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
	if not _browser_prompt() or not is_inside_tree():
		return
	DisplayServer.virtual_keyboard_hide()
	JavaScriptBridge.eval("if (window.lbReleaseInput) window.lbReleaseInput();", true)
	call_deferred("_flush_stuck_pointer")

func _flush_stuck_pointer() -> void:
	if not is_inside_tree():
		return
	var viewport := get_viewport()
	var pos := viewport.get_mouse_position() if viewport != null else Vector2.ZERO
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos
	Input.parse_input_event(release)
	for index in 3:
		var touch := InputEventScreenTouch.new()
		touch.index = index
		touch.pressed = false
		touch.position = pos
		Input.parse_input_event(touch)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(caption: String, bg: Color, ink: Color) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(120, 40)
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(2)
	style.border_color = Color("f2fbff")
	style.set_corner_radius_all(0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	return button

func _setup_picker() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	z_index = 60
	set_process_input(true)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("100c14")
	style.set_border_width_all(2)
	style.border_color = Color("f0d78c")
	style.set_corner_radius_all(0)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_top = 4
	box.offset_right = -6
	box.offset_bottom = -4
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var title := _label("YOUR NAME", 18, Color("f0d78c"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := _label(Leaderboard.FORMAT_HINT, 9, Color("a49fcf"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_picker_name = _label("", 18, Color("f2fbff"))
	_picker_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_name.custom_minimum_size = Vector2(0, 20)
	box.add_child(_picker_name)
	_error = _label("", 9, Color("ffd84a"))
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.custom_minimum_size = Vector2(0, 12)
	box.add_child(_error)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	var keys: Array[String] = []
	for code in range(65, 91):
		keys.append(char(code))
	for code in range(48, 58):
		keys.append(char(code))
	keys.append("-")
	keys.append("_")
	keys.append("SPC")
	keys.append("DEL")
	for key in keys:
		var button := _picker_key(key)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var ok := _button("OK", Color("f0d78c"), Color("241428"))
	ok.custom_minimum_size = Vector2(108, 24)
	ok.pressed.connect(_confirm)
	var skip := _button("SKIP", Color("241428"), Color("f2fbff"))
	skip.custom_minimum_size = Vector2(108, 24)
	skip.pressed.connect(_cancel)
	row.add_child(ok)
	row.add_child(skip)
	_refresh_picker_name()


func _picker_key(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 20)
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("f2fbff"))
	button.add_theme_color_override("font_hover_color", Color("f2fbff"))
	button.add_theme_color_override("font_pressed_color", Color("241428"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("241428")
	normal.set_border_width_all(2)
	normal.border_color = Color("f2fbff")
	normal.set_corner_radius_all(0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("f0d78c")
	for state in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(func() -> void:
		_picker_press(caption)
	)
	return button


func _picker_press(caption: String) -> void:
	if caption == "DEL":
		_picker_backspace()
		return
	if caption == "SPC":
		_picker_type(" ")
		return
	_picker_type(caption)


func _picker_type(ch: String) -> void:
	if not _picker_char_ok(ch) or _picker_value.length() >= 12:
		return
	_picker_value += ch
	_refresh_picker_name()


func _picker_backspace() -> void:
	if _picker_value.length() == 0:
		return
	_picker_value = _picker_value.substr(0, _picker_value.length() - 1)
	_refresh_picker_name()


func _picker_char_ok(ch: String) -> bool:
	if ch == " " or ch == "-" or ch == "_":
		return true
	if ch.length() != 1:
		return false
	var code := ch.unicode_at(0)
	return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


func _refresh_picker_name() -> void:
	if _picker_name == null:
		return
	_picker_name.text = _picker_value if _picker_value != "" else "_"


func _input(event: InputEvent) -> void:
	if not _picker or not visible or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed:
		return
	var viewport := get_viewport()
	if key.keycode == KEY_ESCAPE:
		if viewport != null:
			viewport.set_input_as_handled()
		_cancel()
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		if viewport != null:
			viewport.set_input_as_handled()
		_confirm()
		return
	if key.keycode == KEY_BACKSPACE:
		if viewport != null:
			viewport.set_input_as_handled()
		_picker_backspace()
		return
	if key.echo:
		return
	var ch := char(key.unicode)
	if not _picker_char_ok(ch):
		return
	if viewport != null:
		viewport.set_input_as_handled()
	_picker_type(ch)


func _exit_tree() -> void:
	if _browser_prompt():
		JavaScriptBridge.eval("if (window.lbReleaseInput) window.lbReleaseInput();", true)
