class_name GrayCrownDailyDialog
extends Panel

var _edition: Dictionary = {}
var _title_label: Label
var _meta_label: Label
var _fake_marker: Label
var _headlines_box: VBoxContainer
var _close_button: Button
var _headline_texts: Array[String] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_ui()
	hide()


func open(edition: Dictionary) -> void:
	_ensure_ui()
	_edition = edition.duplicate(true)
	_render()
	show()
	if _close_button != null:
		_close_button.grab_focus()


func headline_texts() -> Array:
	return _headline_texts.duplicate()


func fake_marker_text() -> String:
	return "" if _fake_marker == null else str(_fake_marker.text)


func close_dialog() -> void:
	hide()


func _ensure_ui() -> void:
	if _headlines_box != null:
		return
	_build_ui()


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.055, 0.052, 0.047, 0.97)
	bg.border_color = Color(0.34, 0.31, 0.25, 1.0)
	bg.border_width_left = 2
	bg.border_width_top = 2
	bg.border_width_right = 2
	bg.border_width_bottom = 2
	add_theme_stylebox_override("panel", bg)

	var margin := MarginContainer.new()
	margin.name = "RootMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "RootBox"
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "灰冠日报"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "关闭"
	_close_button.custom_minimum_size = Vector2(72, 44)
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.pressed.connect(close_dialog)
	header.add_child(_close_button)

	_meta_label = Label.new()
	_meta_label.name = "MetaLabel"
	_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_meta_label)

	_fake_marker = Label.new()
	_fake_marker.name = "FakeEditionMarker"
	_fake_marker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fake_marker.add_theme_font_size_override("font_size", 16)
	_fake_marker.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42, 1.0))
	_fake_marker.hide()
	root.add_child(_fake_marker)

	var scroll := ScrollContainer.new()
	scroll.name = "HeadlineScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_headlines_box = VBoxContainer.new()
	_headlines_box.name = "HeadlinesBox"
	_headlines_box.add_theme_constant_override("separation", 8)
	_headlines_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_headlines_box)


func _render() -> void:
	_headline_texts.clear()
	_title_label.text = str(_edition.get("publication", "灰冠日报"))
	_meta_label.text = "第 %d 周 · 周报存档" % [int(_edition.get("week_index", 0)) + 1]
	var marker := str(_edition.get("edition_marker", ""))
	var church_marker := str(_edition.get("church_marker", ""))
	if marker != "":
		_fake_marker.text = "%s：%s" % [marker, church_marker if church_marker != "" else "版面被改写"]
		_fake_marker.show()
	else:
		_fake_marker.text = ""
		_fake_marker.hide()
	for child in _headlines_box.get_children():
		_headlines_box.remove_child(child)
		child.queue_free()
	var headlines: Array = _edition.get("headlines", []) if _edition.get("headlines", []) is Array else []
	for i in range(headlines.size()):
		if not headlines[i] is Dictionary:
			continue
		var headline: Dictionary = headlines[i]
		var text := str(headline.get("display_text", headline.get("id", "")))
		_headline_texts.append(text)
		var row := Label.new()
		row.name = "Headline_%d" % i
		row.text = "%d. %s" % [i + 1, text]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size.y = 44
		row.add_theme_font_size_override("font_size", 16)
		_headlines_box.add_child(row)
