extends "res://scripts/minigames/mini_game_base.gd"

## Sliding Tile Puzzle mini-game
## 3x3 grid with tiles 1-8 and one empty space - slide tiles to solve

const GRID_SIZE := 3
const TILE_SIZE := 80.0
const SHUFFLE_MOVES := 60

var board: Array = []  # 2D array, 0 = empty space
var empty_pos := Vector2i(2, 2)
var move_count := 0
var moves_label: Label
var grid: GridContainer
var solved := false

func _setup_game() -> void:
	if title_label:
		title_label.text = "Sliding Puzzle!"
	_set_instructions("Click tiles next to the empty space to slide them. Arrange 1-8 in order!")

	_init_board()
	_shuffle_board()
	_build_ui()

func _init_board() -> void:
	board.resize(GRID_SIZE)
	var num := 1
	for y in GRID_SIZE:
		board[y] = []
		for x in GRID_SIZE:
			if y == GRID_SIZE - 1 and x == GRID_SIZE - 1:
				board[y].append(0)
			else:
				board[y].append(num)
				num += 1

func _shuffle_board() -> void:
	# Shuffle by making random valid moves from the solved state (guarantees solvability)
	for i in SHUFFLE_MOVES:
		var neighbors: Array[Vector2i] = []
		for dir: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var adj: Vector2i = empty_pos + dir
			if adj.x >= 0 and adj.x < GRID_SIZE and adj.y >= 0 and adj.y < GRID_SIZE:
				neighbors.append(adj)
		var chosen: Vector2i = neighbors[randi() % neighbors.size()]
		board[empty_pos.y][empty_pos.x] = board[chosen.y][chosen.x]
		board[chosen.y][chosen.x] = 0
		empty_pos = chosen

func _build_ui() -> void:
	if not game_area:
		return

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	game_area.add_child(vbox)

	# Move counter
	moves_label = Label.new()
	moves_label.text = "Moves: 0"
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moves_label.add_theme_font_size_override("font_size", 18)
	moves_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	vbox.add_child(moves_label)

	# Center the grid
	var center := CenterContainer.new()
	vbox.add_child(center)

	# Grid
	grid = GridContainer.new()
	grid.columns = GRID_SIZE
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	center.add_child(grid)

	_refresh_grid()

func _refresh_grid() -> void:
	if not grid:
		return

	# Clear existing children
	for child in grid.get_children():
		child.queue_free()

	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var value: int = board[y][x]
			if value == 0:
				# Empty space - invisible placeholder
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
				grid.add_child(spacer)
			else:
				var tile := Button.new()
				tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
				tile.text = str(value)
				tile.add_theme_font_size_override("font_size", 24)

				var stylebox := StyleBoxFlat.new()
				stylebox.bg_color = Color(0.3, 0.25, 0.5)
				stylebox.corner_radius_top_left = 6
				stylebox.corner_radius_top_right = 6
				stylebox.corner_radius_bottom_left = 6
				stylebox.corner_radius_bottom_right = 6
				tile.add_theme_stylebox_override("normal", stylebox)

				var hover_style := StyleBoxFlat.new()
				hover_style.bg_color = Color(0.4, 0.35, 0.65)
				hover_style.corner_radius_top_left = 6
				hover_style.corner_radius_top_right = 6
				hover_style.corner_radius_bottom_left = 6
				hover_style.corner_radius_bottom_right = 6
				tile.add_theme_stylebox_override("hover", hover_style)

				var pos := Vector2i(x, y)
				tile.pressed.connect(_on_tile_clicked.bind(pos))
				grid.add_child(tile)

func _on_tile_clicked(pos: Vector2i) -> void:
	if solved:
		return

	# Check if this tile is adjacent to the empty space
	var dist: int = abs(pos.x - empty_pos.x) + abs(pos.y - empty_pos.y)
	if dist != 1:
		return

	# Swap tile with empty space
	board[empty_pos.y][empty_pos.x] = board[pos.y][pos.x]
	board[pos.y][pos.x] = 0
	empty_pos = pos

	move_count += 1
	moves_label.text = "Moves: %d" % move_count

	_refresh_grid()

	if _check_solved():
		solved = true
		moves_label.text = "Solved in %d moves!" % move_count
		moves_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		await get_tree().create_timer(0.5).timeout
		_complete(true)

func _check_solved() -> bool:
	var expected := 1
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			if y == GRID_SIZE - 1 and x == GRID_SIZE - 1:
				if board[y][x] != 0:
					return false
			else:
				if board[y][x] != expected:
					return false
				expected += 1
	return true
