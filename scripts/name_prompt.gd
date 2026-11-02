extends Control
class_name NamePrompt

## Name entry. On a phone the web shell puts a real text field over this one
## so iPhone Safari can open its keyboard. The server accepts or rejects the name.

signal decided(clean: String, source: String)
signal cancelled

var source := ""
var _font: Font
var _edit: LineEdit
var _error: Label
var _web_open := false
var _bound := false

func setup(font: Font) -> void:
	_font = font
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
	_edit.max_length = 12
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.caret_blink = true
	_edit.context_menu_enabled = false
	_edit.custom_minimum_size = Vector2(0, 36)
	_edit.add_theme_font_override("font", _font)
	_edit.add_theme_font_size_override("font_size", 18)
	_edit.add_theme_color_override("font_color", Color("f2fbff"))
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
	_edit.text_submitted.connect(func(_text: String) -> void:
		_confirm()
	)
	_edit.gui_input.connect(_on_edit_input)
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
	_bind_web()

func open(current: String, from: String) -> void:
	source = from
	visible = true
	_error.text = ""
	_edit.text = Leaderboard.clean_name(current)
	_edit.grab_focus()
	_edit.caret_column = _edit.text.length()
	_sync_web_field(true)

func close() -> void:
	visible = false
	_web_open = false
	_hide_web_field()

func show_error(message: String) -> void:
	visible = true
	_error.text = message

func current_text() -> String:
	if _web_open:
		var web: Variant = _web_value()
		if web != null:
			return str(web)
	return _edit.text

func place_for(viewport: Vector2) -> void:
	var width := minf(440.0, maxf(viewport.x - 16.0, 160.0))
	var height := 146.0
	position = Vector2(maxf((viewport.x - width) * 0.5, 8.0), 4.0)
	size = Vector2(width, height)
	custom_minimum_size = size

func _process(_delta: float) -> void:
	if visible and _web_open:
		_sync_web_field(false)

func _confirm() -> void:
	var clean := Leaderboard.clean_name(current_text())
	_edit.text = clean
	decided.emit(clean, source)

func _cancel() -> void:
	close()
	cancelled.emit()

func _on_edit_input(event: InputEvent) -> void:
	var press := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		press = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		press = (event as InputEventScreenTouch).pressed
	if press:
		_sync_web_field(true)

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

func _coarse_pointer() -> bool:
	if not OS.has_feature("web"):
		return false
	var value: Variant = JavaScriptBridge.eval(
		"!!(window.matchMedia && window.matchMedia('(pointer: coarse)').matches)",
		true
	)
	return bool(value)

func _bind_web() -> void:
	if _bound or not OS.has_feature("web"):
		return
	_bound = true
	var on_input := JavaScriptBridge.create_callback(_on_web_input)
	var on_submit := JavaScriptBridge.create_callback(_on_web_submit)
	var win = JavaScriptBridge.get_interface("window")
	win.__lbOnNameInput = on_input
	win.__lbOnNameSubmit = on_submit

func _on_web_input(args: Array) -> void:
	if args.is_empty():
		return
	_edit.text = str(args[0])
	_edit.caret_column = _edit.text.length()

func _on_web_submit(args: Array) -> void:
	if not args.is_empty():
		_edit.text = str(args[0])
	_confirm()

func _sync_web_field(set_text: bool) -> void:
	if not _coarse_pointer() or _edit == null:
		return
	var rect := _edit.get_global_rect()
	var view := get_viewport_rect().size
	var text := "null"
	if set_text:
		text = JSON.stringify(_edit.text)
	_web_open = true
	JavaScriptBridge.eval(
		"if (window.lbShowNameField) window.lbShowNameField(%s,%s,%s,%s,%s,%s,%s);" % [
			rect.position.x, rect.position.y, rect.size.x, rect.size.y, view.x, view.y, text
		],
		true
	)

func _hide_web_field() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if (window.lbHideNameField) window.lbHideNameField();", true)

func _web_value() -> Variant:
	if not OS.has_feature("web"):
		return null
	return JavaScriptBridge.eval("window.lbNameValue ? window.lbNameValue() : null", true)

func _exit_tree() -> void:
	_hide_web_field()
