extends "res://scripts/minigames/mini_game_base.gd"

## Tangram Puzzle mini-game (grid-based)
## Place colored pieces onto a 6x6 grid to fill a target silhouette

const GRID_COLS := 6
const GRID_ROWS := 6
const CELL_SIZE := 50.0

# Piece definitions: each piece is a name, color, and array of Vector2i offsets
const PIECE_DEFS := [
	{"name": "I", "cells": [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0)], "color": Color(0.2, 0.6, 1.0)},
	{"name": "L", "cells": [Vector2i(0,0), Vector2i(0,1), Vector2i(0,2), Vector2i(1,2)], "color": Color(1.0, 0.5, 0.2)},
	{"name": "T", "cells": [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(1,1)], "color": Color(0.8, 0.2, 0.8)},
	{"name": "S", "cells": [Vector2i(0,1), Vector2i(1,1), Vector2i(1,0), Vector2i(2,0)], "color": Color(0.2, 0.8, 0.4)},
	{"name": "O", "cells": [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)], "color": Color(1.0, 0.85, 0.2)},
	{"name": "J", "cells": [Vector2i(0,0), Vector2i(0,1), Vector2i(1,1)], "color": Color(0.9, 0.3, 0.3)},
]

# Silhouette patterns: array of Vector2i cells that must be filled
const SILHOUETTES := [
	# Cross
	[Vector2i(2,0), Vector2i(3,0), Vector2i(2,1), Vector2i(3,1),
	 Vector2i(0,2), Vector2i(1,2), Vector2i(2,2), Vector2i(3,2), Vector2i(4,2), Vector2i(5,2),
	 Vector2i(0,3), Vector2i(1,3), Vector2i(2,3), Vector2i(3,3), Vector2i(4,3), Vector2i(5,3),
	 Vector2i(2,4), Vector2i(3,4), Vector2i(2,5), Vector2i(3,5)],
	# T-shape
	[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0), Vector2i(5,0),
	 Vector2i(2,1), Vector2i(3,1),
	 Vector2i(2,2), Vector2i(3,2),
	 Vector2i(2,3), Vector2i(3,3),
	 Vector2i(2,4), Vector2i(3,4),
	 Vector2i(2,5), Vector2i(3,5)],
	# Arrow pointing right
	[Vector2i(0,2), Vector2i(0,3),
	 Vector2i(1,2), Vector2i(1,3),
	 Vector2i(2,1), Vector2i(2,2), Vector2i(2,3), Vector2i(2,4),
	 Vector2i(3,1), Vector2i(3,2), Vector2i(3,3), Vector2i(3,4),
	 Vector2i(4,0), Vector2i(4,1), Vector2i(4,2), Vector2i(4,3), Vector2i(4,4), Vector2i(4,5),
	 Vector2i(5,2), Vector2i(5,3)],
	# Rectangle with notch
	[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0), Vector2i(5,0),
	 Vector2i(0,1), Vector2i(1,1), Vector2i(4,1), Vector2i(5,1),
	 Vector2i(0,2), Vector2i(1,2), Vector2i(4,2), Vector2i(5,2),
	 Vector2i(0,3), Vector2i(1,3), Vector2i(2,3), Vector2i(3,3), Vector2i(4,3), Vector2i(5,3)],
]

var target_cells: Array = []  # Array of Vector2i
var grid_occupied: Array = []  # 2D array: -1 = empty, piece_index if occupied
var grid_rects: Array = []     # 2D array of ColorRect
var selected_piece_index: int = -1
var placed_pieces: Dictionary = {}  # piece_index -> Array of Vector2i cells placed
var piece_buttons: Array[Button] = []
var piece_preview_containers: Array[Control] = []

func _setup_game() -> void:
	if title_label:
		title_label.text = "Tangram Puzzle!"
	_set_instructions("Click a piece on the left, then click a grid cell to place it. Fill the dark silhouette!")

	# Pick a random silhouette
	var idx := randi() % SILHOUETTES.size()
	target_cells = SILHOUETTES[idx].duplicate()

	# Initialize grid
	grid_occupied.resize(GRID_ROWS)
	for y in GRID_ROWS:
		grid_occupied[y] = []
		for x in GRID_COLS:
			grid_occupied[y].append(-1)

	_build_ui()

func _build_ui() -> void:
	if not game_area:
		return

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)
	game_area.add_child(hbox)

	# === LEFT SIDE: Piece tray ===
	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(180, 0)
	left_panel.add_theme_constant_override("separation", 8)
	hbox.add_child(left_panel)

	var tray_label := Label.new()
	tray_label.text = "Pieces:"
	tray_label.add_theme_font_size_override("font_size", 18)
	tray_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	left_panel.add_child(tray_label)

	for i in PIECE_DEFS.size():
		var piece_row := HBoxContainer.new()
		piece_row.add_theme_constant_override("separation", 6)
		left_panel.add_child(piece_row)

		var btn := Button.new()
		btn.text = PIECE_DEFS[i]["name"]
		btn.custom_minimum_size = Vector2(40, 40)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_piece_selected.bind(i))
		piece_row.add_child(btn)
		piece_buttons.append(btn)

		# Small preview of the piece shape
		var preview := Control.new()
		preview.custom_minimum_size = Vector2(80, 40)
		piece_row.add_child(preview)
		piece_preview_containers.append(preview)
		_draw_piece_preview(preview, i)

	# Clear button
	var clear_btn := Button.new()
	clear_btn.text = "Clear All"
	clear_btn.custom_minimum_size = Vector2(120, 35)
	clear_btn.add_theme_font_size_override("font_size", 14)
	var clear_style := StyleBoxFlat.new()
	clear_style.bg_color = Color(0.6, 0.2, 0.2)
	clear_style.corner_radius_top_left = 4
	clear_style.corner_radius_top_right = 4
	clear_style.corner_radius_bottom_left = 4
	clear_style.corner_radius_bottom_right = 4
	clear_btn.add_theme_stylebox_override("normal", clear_style)
	clear_btn.pressed.connect(_on_clear_pressed)
	left_panel.add_child(clear_btn)

	# === RIGHT SIDE: Grid ===
	var grid_container := GridContainer.new()
	grid_container.columns = GRID_COLS
	grid_container.add_theme_constant_override("h_separation", 2)
	grid_container.add_theme_constant_override("v_separation", 2)
	hbox.add_child(grid_container)

	grid_rects.resize(GRID_ROWS)
	for y in GRID_ROWS:
		grid_rects[y] = []
		for x in GRID_COLS:
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)

			var is_target := Vector2i(x, y) in target_cells
			if is_target:
				cell.color = Color(0.25, 0.25, 0.35)
			else:
				cell.color = Color(0.12, 0.12, 0.15)

			# Make cells clickable with a button overlay
			var btn := Button.new()
			btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			btn.flat = true
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.pressed.connect(_on_grid_cell_pressed.bind(Vector2i(x, y)))
			cell.add_child(btn)

			grid_container.add_child(cell)
			grid_rects[y].append(cell)

func _draw_piece_preview(container: Control, piece_index: int) -> void:
	var piece_def: Dictionary = PIECE_DEFS[piece_index]
	var cells: Array = piece_def["cells"]
	var col: Color = piece_def["color"]
	var preview_cell_size := 12.0

	for cell_pos in cells:
		var rect := ColorRect.new()
		rect.color = col
		rect.size = Vector2(preview_cell_size, preview_cell_size)
		rect.position = Vector2(cell_pos.x * (preview_cell_size + 1), cell_pos.y * (preview_cell_size + 1))
		container.add_child(rect)

func _on_piece_selected(piece_index: int) -> void:
	# Don't select already placed pieces
	if piece_index in placed_pieces:
		return

	selected_piece_index = piece_index
	_update_piece_highlights()

func _update_piece_highlights() -> void:
	for i in piece_buttons.size():
		if i == selected_piece_index:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.4, 0.6, 0.9)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			piece_buttons[i].add_theme_stylebox_override("normal", style)
		elif i in placed_pieces:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.3, 0.3)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			piece_buttons[i].add_theme_stylebox_override("normal", style)
		else:
			piece_buttons[i].remove_theme_stylebox_override("normal")

func _on_grid_cell_pressed(grid_pos: Vector2i) -> void:
	if selected_piece_index < 0 or selected_piece_index >= PIECE_DEFS.size():
		return
	if selected_piece_index in placed_pieces:
		return

	var piece_def: Dictionary = PIECE_DEFS[selected_piece_index]
	var cells: Array = piece_def["cells"]
	var col: Color = piece_def["color"]

	# Check if all cells of the piece fit on the grid and don't overlap
	var world_cells: Array[Vector2i] = []
	for offset in cells:
		var cx: int = grid_pos.x + offset.x
		var cy: int = grid_pos.y + offset.y
		if cx < 0 or cx >= GRID_COLS or cy < 0 or cy >= GRID_ROWS:
			return  # Out of bounds
		if grid_occupied[cy][cx] != -1:
			return  # Overlapping
		world_cells.append(Vector2i(cx, cy))

	# Place the piece
	for cell in world_cells:
		grid_occupied[cell.y][cell.x] = selected_piece_index
		grid_rects[cell.y][cell.x].color = col

	placed_pieces[selected_piece_index] = world_cells
	selected_piece_index = -1
	_update_piece_highlights()
	_check_win()

func _check_win() -> void:
	# Check if all target cells are covered
	for cell in target_cells:
		if grid_occupied[cell.y][cell.x] == -1:
			return
	# All target cells filled
	await get_tree().create_timer(0.5).timeout
	_complete(true)

func _on_clear_pressed() -> void:
	# Remove all placed pieces
	for piece_index in placed_pieces:
		var cells: Array = placed_pieces[piece_index]
		for cell in cells:
			grid_occupied[cell.y][cell.x] = -1
			var is_target := Vector2i(cell.x, cell.y) in target_cells
			if is_target:
				grid_rects[cell.y][cell.x].color = Color(0.25, 0.25, 0.35)
			else:
				grid_rects[cell.y][cell.x].color = Color(0.12, 0.12, 0.15)

	placed_pieces.clear()
	selected_piece_index = -1
	_update_piece_highlights()
