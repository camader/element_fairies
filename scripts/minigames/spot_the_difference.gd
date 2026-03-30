extends "res://scripts/minigames/mini_game_base.gd"

## Spot the Difference mini-game
## Two grids of colored cells are shown - player must click the cells that differ

const GRID_SIZE := 5
const NUM_DIFFERENCES := 3

var differences: Array[Vector2i] = []
var found: Array[Vector2i] = []
var grid_left: GridContainer
var grid_right: GridContainer

func _setup_game() -> void:
	if title_label:
		title_label.text = "Spot the Difference!"
	_set_instructions("Find %d differences! Click on the RIGHT grid." % NUM_DIFFERENCES)
	_build_grids()

func _build_grids() -> void:
	if not game_area:
		return

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	game_area.add_child(hbox)

	# Generate base colors
	var colors: Array[Color] = []
	for i in GRID_SIZE * GRID_SIZE:
		colors.append(Color(randf_range(0.2, 0.9), randf_range(0.2, 0.9), randf_range(0.2, 0.9)))

	# Pick difference positions
	var positions: Array[int] = []
	for i in GRID_SIZE * GRID_SIZE:
		positions.append(i)
	positions.shuffle()
	for i in NUM_DIFFERENCES:
		var pos: int = positions[i]
		differences.append(Vector2i(pos % GRID_SIZE, pos / GRID_SIZE))

	# Left grid (original)
	grid_left = _create_grid(colors, false)
	hbox.add_child(grid_left)

	# Right grid (with differences)
	var altered_colors := colors.duplicate()
	for diff_pos in differences:
		var idx: int = diff_pos.y * GRID_SIZE + diff_pos.x
		altered_colors[idx] = Color(randf_range(0.2, 0.9), randf_range(0.2, 0.9), randf_range(0.2, 0.9))

	grid_right = _create_grid(altered_colors, true)
	hbox.add_child(grid_right)

func _create_grid(colors: Array[Color], clickable: bool) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = GRID_SIZE
	grid.custom_minimum_size = Vector2(300, 300)
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)

	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(56, 56)
			var stylebox := StyleBoxFlat.new()
			stylebox.bg_color = colors[y * GRID_SIZE + x]
			cell.add_theme_stylebox_override("normal", stylebox)
			cell.add_theme_stylebox_override("hover", stylebox)
			cell.add_theme_stylebox_override("pressed", stylebox)
			if clickable:
				var pos := Vector2i(x, y)
				cell.pressed.connect(_on_cell_clicked.bind(pos, cell))
			grid.add_child(cell)

	return grid

func _on_cell_clicked(pos: Vector2i, cell: Button) -> void:
	if pos in differences and pos not in found:
		found.append(pos)
		# Mark as found
		var stylebox := StyleBoxFlat.new()
		stylebox.bg_color = Color.GREEN
		stylebox.border_color = Color.WHITE
		stylebox.border_width_left = 3
		stylebox.border_width_right = 3
		stylebox.border_width_top = 3
		stylebox.border_width_bottom = 3
		cell.add_theme_stylebox_override("normal", stylebox)
		cell.add_theme_stylebox_override("hover", stylebox)

		if found.size() >= NUM_DIFFERENCES:
			# Small delay then complete
			await get_tree().create_timer(0.5).timeout
			_complete(true)
