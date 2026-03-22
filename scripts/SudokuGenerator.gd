class_name SudokuGenerator
extends RefCounted

const GRID_SIZE = 9
const BOX_SIZE = 3

static func generate_solution() -> Array:
	var grid = create_empty_grid()
	fill_grid(grid)
	return grid

static func fill_grid(grid: Array) -> bool:
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			if grid[row][col] == 0:
				var numbers = range(1, 10)
				numbers.shuffle()

				for num in numbers:
					if is_valid_placement(grid, row, col, num):
						grid[row][col] = num

						if fill_grid(grid):
							return true

						grid[row][col] = 0

				return false
	return true

static func create_empty_grid() -> Array:
	var grid = []
	for i in range(GRID_SIZE):
		var row = []
		row.resize(GRID_SIZE)
		row.fill(0)
		grid.append(row)
	return grid

static func is_valid_placement(grid: Array, row: int, col: int, num: int) -> bool:
	if num in grid[row]:
		return false

	for r in range(GRID_SIZE):
		if grid[r][col] == num:
			return false

	var box_row = (row / BOX_SIZE) * BOX_SIZE
	var box_col = (col / BOX_SIZE) * BOX_SIZE

	for r in range(box_row, box_row + BOX_SIZE):
		for c in range(box_col, box_col + BOX_SIZE):
			if grid[r][c] == num:
				return false

	return true

static func create_puzzle(solution: Array, difficulty: int) -> Array:
	var puzzle = []
	for row in solution:
		puzzle.append(row.duplicate())

	var cells_to_remove = get_cells_to_remove(difficulty)
	var removed_count = 0

	while removed_count < cells_to_remove:
		var row = randi() % GRID_SIZE
		var col = randi() % GRID_SIZE

		if puzzle[row][col] != 0:
			puzzle[row][col] = 0
			removed_count += 1

	return puzzle

static func get_cells_to_remove(difficulty: int) -> int:
	match difficulty:
		1: return 30
		2: return 40
		3: return 50
		4: return 60
		_: return 35

static func solve_grid(grid: Array) -> bool:
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			if grid[row][col] == 0:
				for num in range(1, 10):
					if is_valid_placement(grid, row, col, num):
						grid[row][col] = num
						if solve_grid(grid):
							return true
						grid[row][col] = 0
				return false
	return true
