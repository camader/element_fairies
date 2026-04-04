extends "res://scripts/minigames/mini_game_base.gd"

## Connect the Pipes mini-game
## 5x5 grid of pipe segments - rotate them to connect source (top-left) to drain (bottom-right)

const GRID_SIZE := 5
const PIPE_SIZE := 60.0

# Directions
const UP := 0
const RIGHT := 1
const DOWN := 2
const LEFT := 3

# Pipe type definitions: each type maps rotation (0-3) to [connections, character]
# Connections are arrays of direction constants
var PIPE_TYPES := {
	"straight": {
		0: { "connections": [LEFT, RIGHT], "char": "━" },
		1: { "connections": [UP, DOWN], "char": "┃" },
		2: { "connections": [LEFT, RIGHT], "char": "━" },
		3: { "connections": [UP, DOWN], "char": "┃" },
	},
	"corner": {
		0: { "connections": [UP, RIGHT], "char": "┗" },
		1: { "connections": [RIGHT, DOWN], "char": "┏" },
		2: { "connections": [DOWN, LEFT], "char": "┓" },
		3: { "connections": [UP, LEFT], "char": "┛" },
	},
	"t_piece": {
		0: { "connections": [UP, RIGHT, DOWN], "char": "┣" },
		1: { "connections": [LEFT, RIGHT, DOWN], "char": "┳" },
		2: { "connections": [UP, DOWN, LEFT], "char": "┫" },
		3: { "connections": [UP, LEFT, RIGHT], "char": "┻" },
	},
	"cross": {
		0: { "connections": [UP, RIGHT, DOWN, LEFT], "char": "╋" },
		1: { "connections": [UP, RIGHT, DOWN, LEFT], "char": "╋" },
		2: { "connections": [UP, RIGHT, DOWN, LEFT], "char": "╋" },
		3: { "connections": [UP, RIGHT, DOWN, LEFT], "char": "╋" },
	},
}

var DIR_OFFSETS := {
	UP: Vector2i(0, -1),
	RIGHT: Vector2i(1, 0),
	DOWN: Vector2i(0, 1),
	LEFT: Vector2i(-1, 0),
}

var OPPOSITE := { UP: DOWN, DOWN: UP, LEFT: RIGHT, RIGHT: LEFT }

var pipe_grid: Array = []  # 2D array of { "type": String, "rotation": int }
var grid_container: GridContainer
var buttons: Array = []  # Flat array of buttons matching grid order

func _setup_game() -> void:
	if title_label:
		title_label.text = "Connect the Pipes!"
	_set_instructions("Rotate pipes to connect the source (top-left) to the drain (bottom-right).")

	_generate_puzzle()
	_build_ui()

func _generate_puzzle() -> void:
	# Initialize grid with empty data
	pipe_grid.resize(GRID_SIZE)
	for y in GRID_SIZE:
		pipe_grid[y] = []
		for x in GRID_SIZE:
			pipe_grid[y].append({ "type": "straight", "rotation": 0 })

	# Generate a valid path from (0,0) to (4,4) using random walk
	var path: Array[Vector2i] = []
	var visited: Dictionary = {}
	var success := _find_path(Vector2i(0, 0), Vector2i(GRID_SIZE - 1, GRID_SIZE - 1), visited, path)

	if not success:
		# Fallback: simple L-shaped path
		path.clear()
		for x in GRID_SIZE:
			path.append(Vector2i(x, 0))
		for y in range(1, GRID_SIZE):
			path.append(Vector2i(GRID_SIZE - 1, y))

	# Set pipe types along the path based on direction changes
	for i in path.size():
		var pos: Vector2i = path[i]
		var from_dir := -1
		var to_dir := -1

		if i > 0:
			var diff: Vector2i = pos - path[i - 1]
			if diff == Vector2i(1, 0): from_dir = LEFT
			elif diff == Vector2i(-1, 0): from_dir = RIGHT
			elif diff == Vector2i(0, 1): from_dir = UP
			elif diff == Vector2i(0, -1): from_dir = DOWN

		if i < path.size() - 1:
			var diff: Vector2i = path[i + 1] - pos
			if diff == Vector2i(1, 0): to_dir = RIGHT
			elif diff == Vector2i(-1, 0): to_dir = LEFT
			elif diff == Vector2i(0, 1): to_dir = DOWN
			elif diff == Vector2i(0, -1): to_dir = UP

		var needed_connections: Array[int] = []
		if from_dir >= 0:
			needed_connections.append(from_dir)
		if to_dir >= 0:
			needed_connections.append(to_dir)

		# Source and drain: need connection in path direction
		if i == 0 and to_dir >= 0:
			needed_connections = [to_dir]
		if i == path.size() - 1 and from_dir >= 0:
			needed_connections = [from_dir]

		# Find the pipe type and rotation that matches
		var found_pipe := _find_matching_pipe(needed_connections)
		pipe_grid[pos.y][pos.x] = found_pipe

	# Fill non-path cells with random pipe types
	var path_set: Dictionary = {}
	for p in path:
		path_set[p] = true

	var types := ["straight", "corner", "t_piece", "cross"]
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			if not path_set.has(Vector2i(x, y)):
				pipe_grid[y][x] = { "type": types[randi() % types.size()], "rotation": randi() % 4 }

	# Randomize rotations of all pipes (including path pipes)
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var random_rotations: int = randi() % 4
			for r in random_rotations:
				pipe_grid[y][x]["rotation"] = (pipe_grid[y][x]["rotation"] + 1) % 4

func _find_path(start: Vector2i, goal: Vector2i, visited: Dictionary, path: Array[Vector2i]) -> bool:
	path.append(start)
	visited[start] = true

	if start == goal:
		return true

	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	# Shuffle directions for randomness
	for i in range(dirs.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var tmp: Vector2i = dirs[i]
		dirs[i] = dirs[j]
		dirs[j] = tmp

	for dir: Vector2i in dirs:
		var next: Vector2i = start + dir
		if next.x >= 0 and next.x < GRID_SIZE and next.y >= 0 and next.y < GRID_SIZE:
			if not visited.has(next):
				if _find_path(next, goal, visited, path):
					return true

	path.pop_back()
	return false

func _find_matching_pipe(needed: Array[int]) -> Dictionary:
	if needed.size() == 0:
		return { "type": "straight", "rotation": 0 }

	# Try each pipe type and rotation
	for type_name: String in PIPE_TYPES:
		for rot: int in range(4):
			var conns: Array = PIPE_TYPES[type_name][rot]["connections"]
			# Check if all needed connections are present
			var all_match := true
			for n: int in needed:
				if n not in conns:
					all_match = false
					break
			if all_match and conns.size() >= needed.size():
				# Prefer exact match (same number of connections)
				if conns.size() == needed.size():
					return { "type": type_name, "rotation": rot }

	# Fallback: find any pipe that has all needed connections
	for type_name: String in PIPE_TYPES:
		for rot: int in range(4):
			var conns: Array = PIPE_TYPES[type_name][rot]["connections"]
			var all_match := true
			for n: int in needed:
				if n not in conns:
					all_match = false
					break
			if all_match:
				return { "type": type_name, "rotation": rot }

	return { "type": "cross", "rotation": 0 }

func _build_ui() -> void:
	if not game_area:
		return

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	game_area.add_child(vbox)

	# Center the grid
	var center := CenterContainer.new()
	vbox.add_child(center)

	grid_container = GridContainer.new()
	grid_container.columns = GRID_SIZE
	grid_container.add_theme_constant_override("h_separation", 2)
	grid_container.add_theme_constant_override("v_separation", 2)
	center.add_child(grid_container)

	buttons.clear()
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(PIPE_SIZE, PIPE_SIZE)
			btn.add_theme_font_size_override("font_size", 28)

			var stylebox := StyleBoxFlat.new()
			stylebox.corner_radius_top_left = 4
			stylebox.corner_radius_top_right = 4
			stylebox.corner_radius_bottom_left = 4
			stylebox.corner_radius_bottom_right = 4

			# Color source and drain differently
			if x == 0 and y == 0:
				stylebox.bg_color = Color(0.2, 0.5, 0.2)
			elif x == GRID_SIZE - 1 and y == GRID_SIZE - 1:
				stylebox.bg_color = Color(0.5, 0.2, 0.2)
			else:
				stylebox.bg_color = Color(0.2, 0.2, 0.35)

			btn.add_theme_stylebox_override("normal", stylebox)

			var hover_style := stylebox.duplicate()
			hover_style.bg_color = stylebox.bg_color.lightened(0.15)
			btn.add_theme_stylebox_override("hover", hover_style)

			var pos := Vector2i(x, y)
			btn.pressed.connect(_on_pipe_clicked.bind(pos))
			grid_container.add_child(btn)
			buttons.append(btn)

	_refresh_display()

	# Check button
	var check_center := CenterContainer.new()
	vbox.add_child(check_center)

	var check_btn := Button.new()
	check_btn.text = "Check Connection"
	check_btn.custom_minimum_size = Vector2(180, 40)
	check_btn.add_theme_font_size_override("font_size", 16)

	var check_style := StyleBoxFlat.new()
	check_style.bg_color = Color(0.3, 0.5, 0.3)
	check_style.corner_radius_top_left = 6
	check_style.corner_radius_top_right = 6
	check_style.corner_radius_bottom_left = 6
	check_style.corner_radius_bottom_right = 6
	check_btn.add_theme_stylebox_override("normal", check_style)

	var check_hover := StyleBoxFlat.new()
	check_hover.bg_color = Color(0.4, 0.6, 0.4)
	check_hover.corner_radius_top_left = 6
	check_hover.corner_radius_top_right = 6
	check_hover.corner_radius_bottom_left = 6
	check_hover.corner_radius_bottom_right = 6
	check_btn.add_theme_stylebox_override("hover", check_hover)

	check_btn.pressed.connect(_on_check_pressed)
	check_center.add_child(check_btn)

func _on_pipe_clicked(pos: Vector2i) -> void:
	pipe_grid[pos.y][pos.x]["rotation"] = (pipe_grid[pos.y][pos.x]["rotation"] + 1) % 4
	_refresh_display()

func _refresh_display() -> void:
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var idx: int = y * GRID_SIZE + x
			var pipe: Dictionary = pipe_grid[y][x]
			var type_data: Dictionary = PIPE_TYPES[pipe["type"]][pipe["rotation"]]
			buttons[idx].text = type_data["char"]

func _on_check_pressed() -> void:
	# Flood fill from source (0,0) to check if drain (4,4) is reachable
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	visited[Vector2i(0, 0)] = true

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		var pipe: Dictionary = pipe_grid[current.y][current.x]
		var type_data: Dictionary = PIPE_TYPES[pipe["type"]][pipe["rotation"]]
		var connections: Array = type_data["connections"]

		for dir: int in connections:
			var offset: Vector2i = DIR_OFFSETS[dir]
			var neighbor: Vector2i = current + offset

			if neighbor.x < 0 or neighbor.x >= GRID_SIZE or neighbor.y < 0 or neighbor.y >= GRID_SIZE:
				continue
			if visited.has(neighbor):
				continue

			# Check if the neighbor connects back
			var n_pipe: Dictionary = pipe_grid[neighbor.y][neighbor.x]
			var n_data: Dictionary = PIPE_TYPES[n_pipe["type"]][n_pipe["rotation"]]
			var n_conns: Array = n_data["connections"]
			var opposite_dir: int = OPPOSITE[dir]

			if opposite_dir in n_conns:
				visited[neighbor] = true
				queue.append(neighbor)

	var drain := Vector2i(GRID_SIZE - 1, GRID_SIZE - 1)
	if visited.has(drain):
		_set_instructions("Pipes connected! Well done!")
		await get_tree().create_timer(0.5).timeout
		_complete(true)
	else:
		_set_instructions("Not connected yet - keep rotating!")
