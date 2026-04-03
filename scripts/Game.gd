extends Node2D

@onready var grid_container: GridContainer = $SudokuBoard/GridContainer
@onready var timer_label: Label = $TimerLabel
@onready var difficulty_option: OptionButton = $DifficultyOption
@onready var mode_option: OptionButton = $ModeOption
@onready var status_label: Label = $StatusLabel
@onready var input_mode_label: Label = $InputModeLabel
@onready var number_grid: GridContainer = $RightPanel/NumberGrid
@onready var right_panel: VBoxContainer = $RightPanel
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer
@onready var sound_settings_panel: PopupPanel = $SoundSettingsPanel

var game_grid: Array = []
var solution_grid: Array = []
var original_puzzle: Array = []
var selected_cell: Vector2i = Vector2i(-1, -1)
var is_game_active: bool = false
var elapsed_time: float = 0.0
var difficulty: int = 1
var game_mode: int = 0  # 0=休闲, 1=限时, 2=创造
var is_timed_mode: bool = false
var remaining_time: float = 0.0
var time_limit: float = 0.0
var last_counting_second: int = -1
var last_minute_mark: int = -1
var is_draft_input_mode: bool = false
var instant_conflict_check: bool = true
var undo_stack: Array = []
var redo_stack: Array = []
var max_history_steps: int = 200

var cell_scene: PackedScene = preload("res://scenes/Cell.tscn")
var cells: Array = []
var texture_num_button: Texture2D = preload("res://assets/pics/num_button.png")
var texture_chose_button: Texture2D = preload("res://assets/pics/chosed_button.png")
var texture_unchose_button: Texture2D = preload("res://assets/pics/unChosed_button.png")

var bgm_tracks: Array = [
	preload("res://assets/bgm/happy_xiaoxiaole_bgm_1.mp3"),
	preload("res://assets/bgm/happy_xiaoxiaole_bgm_2.mp3")
]
var sfx_bubble: AudioStream = preload("res://assets/soundEffect/bubble_1.mp3")
var sfx_book: AudioStream = preload("res://assets/soundEffect/book_turn_the_page_3.mp3")
var sfx_bell: AudioStream = preload("res://assets/soundEffect/bell.mp3")
var sfx_failed: AudioStream = preload("res://assets/soundEffect/failed_2.mp3")
var sfx_magic: AudioStream = preload("res://assets/soundEffect/magic_1.mp3")
var sfx_success: AudioStream = preload("res://assets/soundEffect/success_1.mp3")
var sfx_disappear: AudioStream = preload("res://assets/soundEffect/disappear_1.mp3")
var sfx_warning: AudioStream = preload("res://assets/soundEffect/warning_3.mp3")
var sfx_warning2: AudioStream = preload("res://assets/soundEffect/warning_2.mp3")
var sfx_pencil: AudioStream = preload("res://assets/soundEffect/pencil_write.mp3")
var sfx_counting: AudioStream = preload("res://assets/soundEffect/counting_1.mp3")
var sfx_failed_1: AudioStream = preload("res://assets/soundEffect/failed_1.mp3")
var sfx_notice: AudioStream = preload("res://assets/soundEffect/notice_5.mp3")

func _ready():
	setup_board_border()
	initialize_game()
	setup_difficulty_options()
	setup_mode_options()
	setup_number_buttons()
	setup_audio()
	new_game()

func setup_audio():
	bgm_player.finished.connect(_on_bgm_finished)
	# 设置初始音量
	bgm_player.volume_db = linear_to_db(0.8)
	sfx_player.volume_db = linear_to_db(0.8)

func play_sfx(sfx: AudioStream):
	sfx_player.stream = sfx
	sfx_player.play()

func _on_bgm_finished():
	var current_index = bgm_tracks.find(bgm_player.stream)
	var next_index = (current_index + 1) % bgm_tracks.size()
	bgm_player.stream = bgm_tracks[next_index]
	bgm_player.play()

func _on_sound_settings_pressed():
	var panel = sound_settings_panel
	var window_size = Vector2(1000, 850)
	var panel_size = panel.size
	panel.position = Vector2(
		(window_size.x - panel_size.x) / 2,
		(window_size.y - panel_size.y) / 2
	)
	panel.popup()

func _on_bgm_volume_changed(value: float):
	bgm_player.volume_db = -60.0 if value <= 0.0 else linear_to_db(value / 100.0)

func _on_sfx_volume_changed(value: float):
	sfx_player.volume_db = -60.0 if value <= 0.0 else linear_to_db(value / 100.0)

func _on_close_settings_pressed():
	sound_settings_panel.hide()

func setup_board_border():
	var board = $SudokuBoard
	var board_style = StyleBoxFlat.new()
	board_style.bg_color = Color(1, 1, 1, 1)
	board_style.set_corner_radius_all(0)
	board_style.set_border_width_all(4)
	board_style.border_color = Color(0.3, 0.3, 0.3, 1)
	board.add_theme_stylebox_override("panel", board_style)

func reset_history():
	undo_stack.clear()
	redo_stack.clear()

func _duplicate_grid(grid: Array) -> Array:
	var copy = []
	for row in grid:
		copy.append(row.duplicate())
	return copy

func _capture_state() -> Dictionary:
	var drafts = []
	for i in range(81):
		drafts.append(cells[i].draft_numbers.duplicate())
	return {
		"game_grid": _duplicate_grid(game_grid),
		"drafts": drafts,
		"selected_cell": selected_cell,
		"is_game_active": is_game_active,
		"elapsed_time": elapsed_time,
		"remaining_time": remaining_time,
		"status_text": status_label.text
	}

func _restore_state(state: Dictionary):
	game_grid = _duplicate_grid(state["game_grid"])
	for i in range(81):
		cells[i].draft_numbers = Array(state["drafts"][i])
	update_grid_display()
	for i in range(81):
		cells[i].update_display()

	selected_cell = state["selected_cell"]
	if selected_cell != Vector2i(-1, -1):
		highlight_related_cells(selected_cell.x, selected_cell.y)
	else:
		clear_highlights()

	is_game_active = state["is_game_active"]
	elapsed_time = state["elapsed_time"]
	remaining_time = state["remaining_time"]
	status_label.text = state["status_text"]
	if instant_conflict_check:
		refresh_conflict_marks()

func push_undo_snapshot():
	undo_stack.append(_capture_state())
	if undo_stack.size() > max_history_steps:
		undo_stack.pop_front()
	redo_stack.clear()

func undo_action():
	if undo_stack.is_empty():
		return
	var current_state = _capture_state()
	var previous_state = undo_stack.pop_back()
	redo_stack.append(current_state)
	_restore_state(previous_state)
	status_label.text = "已撤销"

func redo_action():
	if redo_stack.is_empty():
		return
	var current_state = _capture_state()
	var next_state = redo_stack.pop_back()
	undo_stack.append(current_state)
	_restore_state(next_state)
	status_label.text = "已重做"

func refresh_conflict_marks():
	for row in range(9):
		for col in range(9):
			var index = row * 9 + col
			var value = game_grid[row][col]
			if value == 0:
				cells[index].set_valid(true)
			else:
				cells[index].set_valid(SudokuValidator.is_cell_valid(game_grid, row, col, value))

func clear_conflict_marks():
	for cell in cells:
		cell.set_valid(true)

func toggle_input_mode():
	is_draft_input_mode = not is_draft_input_mode
	update_input_mode_label()

func update_input_mode_label():
	input_mode_label.text = "输入模式：候选（Tab）" if is_draft_input_mode else "输入模式：填数（Tab）"

func toggle_conflict_check():
	instant_conflict_check = not instant_conflict_check
	if instant_conflict_check:
		refresh_conflict_marks()
		status_label.text = "即时冲突检测：开启"
	else:
		clear_conflict_marks()
		status_label.text = "即时冲突检测：关闭"

func select_cell(row: int, col: int):
	if selected_cell != Vector2i(-1, -1):
		var prev_index = selected_cell.x * 9 + selected_cell.y
		cells[prev_index].set_selected(false)

	selected_cell = Vector2i(clamp(row, 0, 8), clamp(col, 0, 8))
	highlight_related_cells(selected_cell.x, selected_cell.y)

func move_selection(row_delta: int, col_delta: int):
	if selected_cell == Vector2i(-1, -1):
		select_cell(0, 0)
		return
	select_cell(selected_cell.x + row_delta, selected_cell.y + col_delta)

func _key_to_number(key_code: Key) -> int:
	if key_code >= KEY_1 and key_code <= KEY_9:
		return key_code - KEY_0
	if key_code >= KEY_KP_1 and key_code <= KEY_KP_9:
		return key_code - KEY_KP_0
	return -1

func _process(delta):
	if is_game_active:
		if is_timed_mode:
			remaining_time -= delta
			if remaining_time <= 0:
				remaining_time = 0
				game_timeout()
			else:
				handle_timed_mode_sfx()
		else:
			elapsed_time += delta
		update_timer_display()

func initialize_game():
	grid_container.columns = 9
	cells.clear()

	for i in range(81):
		var cell = cell_scene.instantiate()
		cell.custom_minimum_size = Vector2(70, 70)
		var row = i / 9
		var col = i % 9
		cell.cell_clicked.connect(_on_cell_clicked.bind(row, col))
		grid_container.add_child(cell)
		cell.set_box_style(row, col)
		cells.append(cell)

func setup_difficulty_options():
	if difficulty_option.item_count == 0:
		difficulty_option.add_item("简单", 1)
		difficulty_option.add_item("中等", 2)
		difficulty_option.add_item("困难", 3)
		difficulty_option.add_item("极难", 4)
	difficulty_option.selected = 0

func setup_mode_options():
	if mode_option.item_count == 0:
		mode_option.add_item("休闲模式", 0)
		mode_option.add_item("限时模式", 1)
		mode_option.add_item("创造模式", 2)
	mode_option.selected = 0
	update_mode_ui()

func setup_number_buttons():
	var num_style = StyleBoxTexture.new()
	num_style.texture = texture_num_button
	var black_color = Color(0, 0, 0)
	var hover_text_color = Color(0.15, 0.45, 0.85)
	var pressed_text_color = Color(0.1, 0.3, 0.7)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.85, 0.9, 1.0, 1)
	hover_style.set_corner_radius_all(15)
	hover_style.set_border_width_all(2)
	hover_style.border_color = Color(0.4, 0.6, 1.0)
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.6, 0.7, 0.9, 1)
	pressed_style.set_corner_radius_all(15)
	pressed_style.set_border_width_all(2)
	pressed_style.border_color = Color(0.3, 0.5, 0.85)
	
	for i in range(1, 10):
		var btn_name = "Btn" + str(i)
		var btn = number_grid.get_node(btn_name)
		btn.add_theme_stylebox_override("normal", num_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.add_theme_stylebox_override("focus", num_style)
		btn.add_theme_color_override("font_color", black_color)
		btn.add_theme_color_override("font_hover_color", hover_text_color)
		btn.add_theme_color_override("font_pressed_color", pressed_text_color)
		btn.pressed.connect(_on_number_pressed.bind(i))
		btn.gui_input.connect(_on_number_button_input.bind(i))
	var clear_btn = right_panel.get_node("BtnClear")
	clear_btn.pressed.connect(_on_clear_pressed)
	
	var normal_style = StyleBoxTexture.new()
	normal_style.texture = texture_unchose_button
	var func_hover_style = StyleBoxTexture.new()
	func_hover_style.texture = texture_chose_button
	var func_buttons = ["BtnValidate", "BtnSolve", "BtnClearAll", "BtnClear", "NewGameButton", "BtnExport", "BtnImport"]
	for btn_name in func_buttons:
		var btn = right_panel.get_node(btn_name)
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", func_hover_style)
		btn.add_theme_stylebox_override("pressed", func_hover_style)
		btn.add_theme_stylebox_override("focus", func_hover_style)
		btn.add_theme_color_override("font_color", black_color)
		btn.add_theme_color_override("font_hover_color", black_color)
		btn.add_theme_color_override("font_pressed_color", black_color)

func new_game():
	solution_grid = SudokuGenerator.generate_solution()
	game_grid = SudokuGenerator.create_puzzle(solution_grid, difficulty)
	original_puzzle = []
	for row in game_grid:
		original_puzzle.append(row.duplicate())

	selected_cell = Vector2i(-1, -1)
	is_game_active = true
	elapsed_time = 0.0
	is_draft_input_mode = false
	update_input_mode_label()
	reset_history()
	is_timed_mode = (game_mode == 1)
	if is_timed_mode:
		remaining_time = get_time_limit(difficulty)
		time_limit = remaining_time
		last_counting_second = -1
		last_minute_mark = -1

	update_grid_display()
	clear_highlights()
	if instant_conflict_check:
		refresh_conflict_marks()
	status_label.text = "游戏进行中..."

func get_time_limit(diff: int) -> float:
	match diff:
		1: return 5 * 60  # 简单 5分钟
		2: return 8 * 60  # 中等 8分钟
		3: return 12 * 60 # 困难 12分钟
		4: return 18 * 60 # 极难 18分钟
		_: return 5 * 60

func _on_difficulty_changed(index: int):
	play_sfx(sfx_book)
	difficulty = difficulty_option.get_item_id(index)
	if game_mode == 0 or game_mode == 1:  # 休闲模式或限时模式
		new_game()

func _on_mode_changed(index: int):
	play_sfx(sfx_book)
	game_mode = mode_option.get_item_id(index)
	if game_mode == 2:  # 创造模式
		enter_create_mode()
	else:  # 休闲模式或限时模式
		new_game()
	update_mode_ui()

func update_mode_ui():
	var export_btn = right_panel.get_node("BtnExport")
	var import_btn = right_panel.get_node("BtnImport")
	export_btn.visible = (game_mode == 2)
	import_btn.visible = (game_mode == 2)
	difficulty_option.visible = (game_mode == 0 or game_mode == 1)

func enter_create_mode():
	solution_grid = SudokuGenerator.create_empty_grid()
	game_grid = SudokuGenerator.create_empty_grid()
	original_puzzle = SudokuGenerator.create_empty_grid()
	selected_cell = Vector2i(-1, -1)
	is_game_active = true
	elapsed_time = 0.0
	is_draft_input_mode = false
	update_input_mode_label()
	reset_history()
	is_timed_mode = false
	update_grid_display()
	clear_highlights()
	status_label.text = "创造模式 - 自由编辑"

func _on_cell_clicked(row: int, col: int):
	if not is_game_active:
		return
	select_cell(row, col)

func set_cell_value(value: int, record_undo: bool = true):
	if not is_game_active or selected_cell == Vector2i(-1, -1):
		return

	var row = selected_cell.x
	var col = selected_cell.y

	if original_puzzle[row][col] != 0:
		return

	if record_undo:
		push_undo_snapshot()

	game_grid[row][col] = value
	var index = row * 9 + col
	cells[index].set_cell_value(value, false)

	if value != 0:
		clear_related_drafts(row, col, value)

	if instant_conflict_check:
		refresh_conflict_marks()

	if SudokuValidator.is_game_complete(game_grid):
		game_completed()

func clear_related_drafts(row: int, col: int, value: int):
	for c in range(9):
		if c != col:
			cells[row * 9 + c].remove_draft(value)
	for r in range(9):
		if r != row:
			cells[r * 9 + col].remove_draft(value)
	var box_row = (row / 3) * 3
	var box_col = (col / 3) * 3
	for r in range(box_row, box_row + 3):
		for c in range(box_col, box_col + 3):
			if r != row or c != col:
				cells[r * 9 + c].remove_draft(value)

func highlight_related_cells(row: int, col: int):
	clear_highlights()

	for c in range(9):
		var index = row * 9 + c
		cells[index].set_highlighted_row(true)

	for r in range(9):
		var index = r * 9 + col
		cells[index].set_highlighted_col(true)

	var box_row = (row / 3) * 3
	var box_col = (col / 3) * 3
	for r in range(box_row, box_row + 3):
		for c in range(box_col, box_col + 3):
			var index = r * 9 + c
			cells[index].set_highlighted_box(true)

	var selected_index = row * 9 + col
	cells[selected_index].set_selected(true)

func clear_highlights():
	for cell in cells:
		cell.clear_highlights()

func update_grid_display():
	for row in range(9):
		for col in range(9):
			var index = row * 9 + col
			var value = game_grid[row][col]
			var is_original = original_puzzle[row][col] != 0
			cells[index].set_cell_value(value, is_original)

func update_timer_display():
	var time_to_show = remaining_time if is_timed_mode else elapsed_time
	var minutes = int(time_to_show) / 60
	var seconds = int(time_to_show) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	if is_timed_mode and remaining_time <= 60:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 1, 1))

func handle_timed_mode_sfx():
	var current_second = int(remaining_time)

	# 最后3秒播放倒计时音效
	if current_second <= 3 and current_second > 0 and current_second != last_counting_second:
		play_sfx(sfx_counting)
		last_counting_second = current_second
	
	# 整数分钟播放提示音（不包括起始和结束时）
	var current_minute = current_second / 60
	if current_minute != last_minute_mark and current_minute >= 1:
		if current_minute * 60 == current_second:
			play_sfx(sfx_notice)
			last_minute_mark = current_minute

func game_completed():
	is_game_active = false
	if is_timed_mode:
		var time_used = time_limit - remaining_time
		var minutes = int(time_used) / 60
		var seconds = int(time_used) % 60
		status_label.text = "恭喜完成！用时: %02d:%02d" % [minutes, seconds]
	else:
		status_label.text = "恭喜完成！用时: " + timer_label.text
	play_sfx(sfx_success)

func game_timeout():
	is_game_active = false
	status_label.text = "时间到！挑战失败"
	play_sfx(sfx_failed_1)
	var dialog = ConfirmationDialog.new()
	dialog.title = "挑战失败"
	dialog.dialog_text = "时间到！你没有在规定时间内完成数独。"
	dialog.ok_button_text = "重新挑战"
	add_child(dialog)
	dialog.confirmed.connect(_on_timeout_retry)
	dialog.popup_centered()

func _on_timeout_retry():
	new_game()

func _on_new_game_pressed():
	play_sfx(sfx_book)
	new_game()

func _on_clear_pressed():
	play_sfx(sfx_disappear)
	if selected_cell != Vector2i(-1, -1):
		var row = selected_cell.x
		var col = selected_cell.y
		if original_puzzle[row][col] == 0:
			push_undo_snapshot()
			var index = row * 9 + col
			cells[index].clear_drafts()
	set_cell_value(0, false)

func _on_clear_all_pressed():
	play_sfx(sfx_warning2)
	var dialog = ConfirmationDialog.new()
	dialog.title = "确认清空"
	dialog.dialog_text = "确定要清空所有输入吗？"
	add_child(dialog)
	dialog.confirmed.connect(_confirm_clear_all)
	dialog.popup_centered()

func _confirm_clear_all():
	for row in range(9):
		for col in range(9):
			if original_puzzle[row][col] == 0:
				game_grid[row][col] = 0
				var index = row * 9 + col
				cells[index].clear_drafts()
	update_grid_display()
	clear_highlights()
	status_label.text = "已清空所有输入"

func _on_validate_pressed():
	var error_count = 0
	for row in range(9):
		for col in range(9):
			var index = row * 9 + col
			var value = game_grid[row][col]
			var is_valid = SudokuValidator.is_cell_valid(game_grid, row, col, value)
			cells[index].set_valid(is_valid)
			if not is_valid:
				error_count += 1
	if error_count == 0:
		status_label.text = "校验通过，全部正确！"
		play_sfx(sfx_bell)
	else:
		status_label.text = "发现 " + str(error_count) + " 处错误"
		play_sfx(sfx_failed)

func _on_solve_pressed():
	play_sfx(sfx_magic)
	if not SudokuValidator.is_grid_valid(game_grid):
		status_label.text = "当前状态有冲突，无法求解"
		return
	var grid_copy = []
	for row in game_grid:
		grid_copy.append(row.duplicate())
	if SudokuGenerator.solve_grid(grid_copy):
		for row in range(9):
			for col in range(9):
				game_grid[row][col] = grid_copy[row][col]
		update_grid_display()
		clear_highlights()
		status_label.text = "求解成功"
	else:
		status_label.text = "无解"

func _on_export_pressed():
	var time = Time.get_datetime_dict_from_system()
	var filename = "sudoku_%04d%02d%02d_%02d%02d%02d.json" % [
		time.year, time.month, time.day,
		time.hour, time.minute, time.second
	]
	var desktop = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	DisplayServer.file_dialog_show(
		"导出数独存档",
		desktop,
		filename,
		false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		PackedStringArray(["*.json"]),
		_on_export_file_selected
	)

func _on_export_file_selected(status: bool, selected_paths: PackedStringArray, selected_filter_index: int):
	if not status or selected_paths.is_empty():
		return
	var path = selected_paths[0]
	if not path.ends_with(".json"):
		path += ".json"
	var drafts = []
	for i in range(81):
		drafts.append(cells[i].draft_numbers.duplicate())
	var data = {
		"original": original_puzzle,
		"progress": game_grid,
		"solution": solution_grid,
		"difficulty": difficulty,
		"drafts": drafts
	}
	var json_string = JSON.stringify(data)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		status_label.text = "导出成功"

func _on_import_pressed():
	var desktop = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	DisplayServer.file_dialog_show(
		"导入数独存档",
		desktop,
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.json"]),
		_on_import_file_selected
	)

func _on_import_file_selected(status: bool, selected_paths: PackedStringArray, selected_filter_index: int):
	if not status or selected_paths.is_empty():
		return
	var path = selected_paths[0]
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.data
			original_puzzle = []
			for row in data["original"]:
				original_puzzle.append(Array(row))
			game_grid = []
			for row in data["progress"]:
				game_grid.append(Array(row))
			solution_grid = []
			for row in data["solution"]:
				solution_grid.append(Array(row))
			difficulty = int(data["difficulty"])
			is_draft_input_mode = false
			update_input_mode_label()
			selected_cell = Vector2i(-1, -1)
			is_game_active = true
			update_grid_display()
			clear_highlights()
			if data.has("drafts"):
				var drafts = data["drafts"]
				for i in range(81):
					cells[i].draft_numbers = Array(drafts[i])
					cells[i].update_display()
			status_label.text = "导入成功"

func _on_number_pressed(num: int):
	if is_draft_input_mode:
		play_sfx(sfx_pencil)
		add_draft_number(num)
	else:
		play_sfx(sfx_bubble)
		set_cell_value(num)

func _on_number_secondary_pressed(num: int):
	if selected_cell == Vector2i(-1, -1):
		return
	play_sfx(sfx_pencil)
	add_draft_number(num)

func add_draft_number(num: int):
	if selected_cell == Vector2i(-1, -1):
		return
	var row = selected_cell.x
	var col = selected_cell.y
	if original_puzzle[row][col] != 0:
		return
	push_undo_snapshot()
	var index = row * 9 + col
	cells[index].add_draft(num)

func _on_number_button_input(event: InputEvent, num: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_on_number_secondary_pressed(num)

func _input(event):
	if not is_game_active:
		return

	if event is InputEventKey and event.pressed:
		var key_code = event.keycode

		if key_code == KEY_UP:
			move_selection(-1, 0)
			get_viewport().set_input_as_handled()
		elif key_code == KEY_DOWN:
			move_selection(1, 0)
			get_viewport().set_input_as_handled()
		elif key_code == KEY_LEFT:
			move_selection(0, -1)
			get_viewport().set_input_as_handled()
		elif key_code == KEY_RIGHT:
			move_selection(0, 1)
			get_viewport().set_input_as_handled()
		elif key_code == KEY_TAB:
			toggle_input_mode()
			get_viewport().set_input_as_handled()
		elif key_code == KEY_Z and event.ctrl_pressed:
			undo_action()
			get_viewport().set_input_as_handled()
		elif key_code == KEY_Y and event.ctrl_pressed:
			redo_action()
			get_viewport().set_input_as_handled()
		elif key_code == KEY_BACKSPACE or key_code == KEY_DELETE or key_code == KEY_0 or key_code == KEY_KP_0:
			play_sfx(sfx_disappear)
			set_cell_value(0)
			get_viewport().set_input_as_handled()
		else:
			var num = _key_to_number(key_code)
			if num == -1:
				return
			if is_draft_input_mode:
				play_sfx(sfx_pencil)
				add_draft_number(num)
			else:
				play_sfx(sfx_bubble)
				set_cell_value(num)
			get_viewport().set_input_as_handled()
