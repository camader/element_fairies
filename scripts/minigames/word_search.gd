extends "res://scripts/minigames/mini_game_base.gd"

## Word Search mini-game
## Find fairy-themed words hidden in a grid

const GRID_SIZE := 10
const CELL_SIZE := 45.0

const WORD_LIST := [
	"FAIRY", "MAGIC", "STAR", "WING", "FIRE",
	"WATER", "EARTH", "ICE", "GLOW", "WAND",
]
const WORDS_TO_FIND := 4

var grid: Array = []  # 2D char array
var words_placed: Array[String] = []
var words_found: Array[String] = []
var cell_buttons: Array = []  # 2D Button array
var selecting := false
var selected_cells: Array[Vector2i] = []
var word_labels: Array[Label] = []

func _setup_game() -> void:
	if title_label:
		title_label.text = "Word Search!"
	_set_instructions("Click letters one by one to spell each word from the list. Words can go right, down, or diagonally.")
	_generate_grid()
	_build_ui()

func _generate_grid() -> void:
	# Initialize empty grid
	grid.resize(GRID_SIZE)
	for y in GRID_SIZE:
		grid[y] = []
		for x in GRID_SIZE:
			grid[y].append("")

	# Shuffle and try to place words
	var shuffled_words := WORD_LIST.duplicate()
	shuffled_words.shuffle()

	for word in shuffled_words:
		if words_placed.size() >= WORDS_TO_FIND:
			break
		if _try_place_word(word):
			words_placed.append(word)

	# Fill empty cells with random letters
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			if grid[y][x] == "":
				grid[y][x] = char(randi_range(65, 90))  # A-Z

func _try_place_word(word: String) -> bool:
	# Try random directions and positions
	var directions := [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)
	]
	for _attempt in 50:
		var dir: Vector2i = directions[randi() % directions.size()]
		var start_x := randi_range(0, GRID_SIZE - 1)
		var start_y := randi_range(0, GRID_SIZE - 1)

		# Check if word fits
		var end_x := start_x + dir.x * (word.length() - 1)
		var end_y := start_y + dir.y * (word.length() - 1)
		if end_x < 0 or end_x >= GRID_SIZE or end_y < 0 or end_y >= GRID_SIZE:
			continue

		# Check for conflicts
		var can_place := true
		for i in word.length():
			var cx: int = start_x + dir.x * i
			var cy: int = start_y + dir.y * i
			if grid[cy][cx] != "" and grid[cy][cx] != word[i]:
				can_place = false
				break

		if can_place:
			for i in word.length():
				var cx: int = start_x + dir.x * i
				var cy: int = start_y + dir.y * i
				grid[cy][cx] = word[i]
			return true

	return false

func _build_ui() -> void:
	if not game_area:
		return

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 30)
	game_area.add_child(hbox)

	# Grid
	var grid_container := GridContainer.new()
	grid_container.columns = GRID_SIZE
	grid_container.add_theme_constant_override("h_separation", 2)
	grid_container.add_theme_constant_override("v_separation", 2)
	hbox.add_child(grid_container)

	cell_buttons.resize(GRID_SIZE)
	for y in GRID_SIZE:
		cell_buttons[y] = []
		for x in GRID_SIZE:
			var btn := Button.new()
			btn.text = grid[y][x]
			btn.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			btn.add_theme_font_size_override("font_size", 20)
			btn.pressed.connect(_on_cell_pressed.bind(Vector2i(x, y)))
			grid_container.add_child(btn)
			cell_buttons[y].append(btn)

	# Word list
	var word_panel := VBoxContainer.new()
	word_panel.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(word_panel)

	var list_title := Label.new()
	list_title.text = "Find these words:"
	list_title.add_theme_font_size_override("font_size", 18)
	word_panel.add_child(list_title)

	for word in words_placed:
		var lbl := Label.new()
		lbl.text = word
		lbl.add_theme_font_size_override("font_size", 16)
		word_panel.add_child(lbl)
		word_labels.append(lbl)

func _on_cell_pressed(pos: Vector2i) -> void:
	if not selecting:
		selecting = true
		selected_cells.clear()
		selected_cells.append(pos)
		_highlight_cell(pos, Color(0.5, 0.7, 1.0, 0.5))
	else:
		selected_cells.append(pos)
		_highlight_cell(pos, Color(0.5, 0.7, 1.0, 0.5))
		# Check if selection forms a valid word
		var word := _get_selected_word()
		if word in words_placed and word not in words_found:
			words_found.append(word)
			_mark_word_found(word)
			for cell in selected_cells:
				_highlight_cell(cell, Color(0.2, 0.8, 0.2, 0.5))
			selecting = false
			selected_cells.clear()
			if words_found.size() >= words_placed.size():
				await get_tree().create_timer(0.5).timeout
				_complete(true)
		elif selected_cells.size() >= 10:
			# Too long, reset
			_clear_highlights()
			selecting = false
			selected_cells.clear()

func _get_selected_word() -> String:
	var word := ""
	for cell in selected_cells:
		word += grid[cell.y][cell.x]
	return word

func _highlight_cell(pos: Vector2i, color: Color) -> void:
	var btn: Button = cell_buttons[pos.y][pos.x]
	var style := StyleBoxFlat.new()
	style.bg_color = color
	btn.add_theme_stylebox_override("normal", style)

func _clear_highlights() -> void:
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var btn: Button = cell_buttons[y][x]
			btn.remove_theme_stylebox_override("normal")

func _mark_word_found(word: String) -> void:
	for lbl in word_labels:
		if lbl.text == word:
			lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
			lbl.text = word + " ✓"
			break
