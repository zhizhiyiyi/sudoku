class_name SudokuValidator
extends RefCounted

const GRID_SIZE = 9
const BOX_SIZE = 3

static func is_grid_valid(grid: Array) -> bool:
	for row in range(GRID_SIZE):
		if not is_row_valid(grid, row):
			return false

	for col in range(GRID_SIZE):
		if not is_column_valid(grid, col):
			return false

	for box_row in range(0, GRID_SIZE, BOX_SIZE):
		for box_col in range(0, GRID_SIZE, BOX_SIZE):
			if not is_box_valid(grid, box_row, box_col):
				return false

	return true

static func is_row_valid(grid: Array, row: int) -> bool:
	var seen = {}
	for col in range(GRID_SIZE):
		var num = grid[row][col]
		if num != 0:
			if seen.has(num):
				return false
			seen[num] = true
	return true

static func is_column_valid(grid: Array, col: int) -> bool:
	var seen = {}
	for row in range(GRID_SIZE):
		var num = grid[row][col]
		if num != 0:
			if seen.has(num):
				return false
			seen[num] = true
	return true

static func is_box_valid(grid: Array, start_row: int, start_col: int) -> bool:
	var seen = {}
	for row in range(start_row, start_row + BOX_SIZE):
		for col in range(start_col, start_col + BOX_SIZE):
			var num = grid[row][col]
			if num != 0:
				if seen.has(num):
					return false
				seen[num] = true
	return true

static func is_cell_valid(grid: Array, row: int, col: int, num: int) -> bool:
	if num == 0:
		return true

	for c in range(GRID_SIZE):
		if c != col and grid[row][c] == num:
			return false

	for r in range(GRID_SIZE):
		if r != row and grid[r][col] == num:
			return false

	var box_row = (row / BOX_SIZE) * BOX_SIZE
	var box_col = (col / BOX_SIZE) * BOX_SIZE

	for r in range(box_row, box_row + BOX_SIZE):
		for c in range(box_col, box_col + BOX_SIZE):
			if (r != row or c != col) and grid[r][c] == num:
				return false

	return true

static func is_game_complete(grid: Array) -> bool:
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			if grid[row][col] == 0:
				return false
	return is_grid_valid(grid)
