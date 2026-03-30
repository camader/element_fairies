extends "res://scripts/minigames/mini_game_base.gd"

## Maze Puzzle mini-game
## Navigate a marker through a grid maze from start to finish

const MAZE_WIDTH := 11
const MAZE_HEIGHT := 9
const CELL_SIZE := 50.0

var maze: Array = []  # 2D array: 0=wall, 1=path
var player_cell := Vector2i(1, 1)
var goal_cell := Vector2i(MAZE_WIDTH - 2, MAZE_HEIGHT - 2)
var player_marker: ColorRect
var maze_container: Control

func _setup_game() -> void:
	if title_label:
		title_label.text = "Maze Puzzle!"
	_set_instructions("Use WASD or Arrow Keys to guide your fairy through the maze to the golden star.")
	_generate_maze()
	_build_maze_ui()

func _generate_maze() -> void:
	# Initialize with walls
	maze.resize(MAZE_HEIGHT)
	for y in MAZE_HEIGHT:
		maze[y] = []
		for x in MAZE_WIDTH:
			maze[y].append(0)

	# Recursive backtracker maze generation (on odd cells)
	var stack: Array[Vector2i] = []
	var start := Vector2i(1, 1)
	maze[start.y][start.x] = 1
	stack.push_back(start)

	while stack.size() > 0:
		var current: Vector2i = stack.back()
		var neighbors: Array[Vector2i] = []

		for dir: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
			var next: Vector2i = current + dir
			if next.x > 0 and next.x < MAZE_WIDTH - 1 and next.y > 0 and next.y < MAZE_HEIGHT - 1:
				if maze[next.y][next.x] == 0:
					neighbors.append(next)

		if neighbors.size() > 0:
			var chosen: Vector2i = neighbors[randi() % neighbors.size()]
			# Carve wall between
			var between := (current + chosen) / 2
			maze[between.y][between.x] = 1
			maze[chosen.y][chosen.x] = 1
			stack.push_back(chosen)
		else:
			stack.pop_back()

	# Ensure goal is reachable
	maze[goal_cell.y][goal_cell.x] = 1

func _build_maze_ui() -> void:
	if not game_area:
		return

	maze_container = Control.new()
	maze_container.custom_minimum_size = Vector2(MAZE_WIDTH * CELL_SIZE, MAZE_HEIGHT * CELL_SIZE)
	maze_container.position = Vector2(
		(game_area.size.x - MAZE_WIDTH * CELL_SIZE) / 2.0,
		(game_area.size.y - MAZE_HEIGHT * CELL_SIZE) / 2.0
	)
	game_area.add_child(maze_container)

	# Draw maze
	for y in MAZE_HEIGHT:
		for x in MAZE_WIDTH:
			var cell := ColorRect.new()
			cell.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			cell.size = Vector2(CELL_SIZE, CELL_SIZE)
			if maze[y][x] == 0:
				cell.color = Color(0.15, 0.1, 0.25)  # Wall
			else:
				cell.color = Color(0.85, 0.82, 0.75)  # Path
			maze_container.add_child(cell)

	# Goal marker
	var goal := ColorRect.new()
	goal.position = Vector2(goal_cell.x * CELL_SIZE + 5, goal_cell.y * CELL_SIZE + 5)
	goal.size = Vector2(CELL_SIZE - 10, CELL_SIZE - 10)
	goal.color = Color(1.0, 0.84, 0.0)
	maze_container.add_child(goal)

	# Star on goal
	var star_label := Label.new()
	star_label.text = "★"
	star_label.position = Vector2(goal_cell.x * CELL_SIZE + 10, goal_cell.y * CELL_SIZE + 5)
	star_label.add_theme_font_size_override("font_size", 28)
	maze_container.add_child(star_label)

	# Player marker
	player_marker = ColorRect.new()
	player_marker.size = Vector2(CELL_SIZE - 10, CELL_SIZE - 10)
	player_marker.color = GameState.FAIRY_COLORS[GameState.selected_fairy]
	_update_player_position()
	maze_container.add_child(player_marker)

func _update_player_position() -> void:
	if player_marker:
		player_marker.position = Vector2(
			player_cell.x * CELL_SIZE + 5,
			player_cell.y * CELL_SIZE + 5
		)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var dir := Vector2i.ZERO
		if event.keycode == KEY_W or event.keycode == KEY_UP:
			dir = Vector2i(0, -1)
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
			dir = Vector2i(0, 1)
		elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
			dir = Vector2i(-1, 0)
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			dir = Vector2i(1, 0)

		if dir != Vector2i.ZERO:
			_try_move(dir)
			get_viewport().set_input_as_handled()

func _try_move(dir: Vector2i) -> void:
	var next := player_cell + dir
	if next.x >= 0 and next.x < MAZE_WIDTH and next.y >= 0 and next.y < MAZE_HEIGHT:
		if maze[next.y][next.x] == 1:
			player_cell = next
			_update_player_position()
			if player_cell == goal_cell:
				await get_tree().create_timer(0.3).timeout
				_complete(true)
