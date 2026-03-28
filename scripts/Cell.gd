extends Button

signal cell_clicked
signal cell_changed(new_value: int)

@onready var number_label: Label = $NumberLabel
@onready var highlight_rect: ColorRect = $HighlightRect

var cell_value: int = 0
var is_original: bool = false
var is_selected: bool = false
var is_highlighted_row: bool = false
var is_highlighted_col: bool = false
var is_highlighted_box: bool = false
var is_error: bool = false
var draft_numbers: Array = []

var color_selected: Color = Color(0.35, 0.65, 1.0, 0.45)
var color_highlight_row: Color = Color(0.5, 0.9, 0.6, 0.25)
var color_highlight_col: Color = Color(0.95, 0.9, 0.5, 0.25)
var color_highlight_box: Color = Color(0.7, 0.6, 0.95, 0.25)
var color_error: Color = Color(1.0, 0.45, 0.45, 0.4)
var color_original: Color = Color(0.1, 0.1, 0.1)
var color_user: Color = Color(0.15, 0.45, 0.85)

func _ready():
	pressed.connect(_on_pressed)
	_setup_transparent_style()
	update_display()
	_create_draft_labels()

var draft_labels: Array = []

func _create_draft_labels():
	for i in range(9):
		var label = Label.new()
		label.name = "Draft_" + str(i + 1)
		label.anchor_left = (i % 3) / 3.0
		label.anchor_right = (i % 3 + 1) / 3.0
		label.anchor_top = (i / 3) / 3.0
		label.anchor_bottom = (i / 3 + 1) / 3.0
		label.offset_left = 1
		label.offset_top = 1
		label.offset_right = -1
		label.offset_bottom = -1
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.15, 0.5, 0.35))
		label.add_theme_color_override("font_outline_color", Color(0.15, 0.5, 0.35))
		label.add_theme_constant_override("outline_size", 1)
		add_child(label)
		label.visible = false
		draft_labels.append(label)

func _setup_transparent_style():
	var style = StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)

func _on_pressed():
	cell_clicked.emit()

func add_draft(num: int):
	if cell_value != 0:
		return
	if num in draft_numbers:
		draft_numbers.erase(num)
	else:
		draft_numbers.append(num)
		draft_numbers.sort()
	update_display()

func clear_drafts():
	draft_numbers.clear()
	update_display()

func remove_draft(num: int):
	if num in draft_numbers:
		draft_numbers.erase(num)
		update_display()

func has_draft(num: int) -> bool:
	return num in draft_numbers

func set_cell_value(value: int, original: bool = false):
	cell_value = value
	is_original = original
	if value != 0:
		draft_numbers.clear()
	update_display()

func set_selected(selected: bool):
	is_selected = selected
	update_highlight()

func set_valid(valid: bool):
	is_error = not valid
	update_highlight()

func set_highlighted_row(highlighted: bool):
	is_highlighted_row = highlighted
	update_highlight()

func set_highlighted_col(highlighted: bool):
	is_highlighted_col = highlighted
	update_highlight()

func set_highlighted_box(highlighted: bool):
	is_highlighted_box = highlighted
	update_highlight()

func clear_highlights():
	is_selected = false
	is_highlighted_row = false
	is_highlighted_col = false
	is_highlighted_box = false
	is_error = false
	highlight_rect.color = Color.TRANSPARENT

func set_box_style(row: int, col: int):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.95, 1)
	style.set_corner_radius_all(0)
	style.set_border_width_all(1)
	style.border_color = Color(0.6, 0.6, 0.6)
	if col == 2 or col == 5:
		style.set_border_width(SIDE_RIGHT, 3)
	if row == 2 or row == 5:
		style.set_border_width(SIDE_BOTTOM, 3)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)

func update_display():
	if number_label == null:
		return

	if cell_value == 0:
		number_label.text = ""
	else:
		number_label.text = str(cell_value)

	if is_original:
		number_label.add_theme_color_override("font_color", color_original)
	else:
		number_label.add_theme_color_override("font_color", color_user)

	if draft_labels.is_empty():
		return

	var draft_set = {}
	for num in draft_numbers:
		draft_set[num] = true

	for i in range(9):
		var label = draft_labels[i]
		var num = i + 1
		if draft_set.has(num):
			label.text = str(num)
			label.visible = true
		else:
			label.visible = false

func update_highlight():
	if highlight_rect == null:
		return

	if is_error:
		highlight_rect.color = color_error
	elif is_selected:
		highlight_rect.color = color_selected
	elif is_highlighted_box:
		highlight_rect.color = color_highlight_box
	elif is_highlighted_row or is_highlighted_col:
		highlight_rect.color = color_highlight_row
	else:
		highlight_rect.color = Color.TRANSPARENT
