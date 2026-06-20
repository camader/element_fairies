extends "res://scripts/minigames/mini_game_base.gd"

## Tangram Puzzle mini-game (grid-based)
## Place colored pieces onto a 6x6 grid to fill a target silhouette

const GRID_COLS := 6
const GRID_ROWS := 6
const CELL_SIZE := 50.0
const MAX_HINTS := 3

const PIECE_DEFS := [
	{"name": "I", "cells": [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0)], "color": Color(0.2, 0.6, 1.0)},
	{"name": "L", "cells": [Vector2i(0,0), Vector2i(0,1), Vector2i(0,2), Vector2i(1,2)], "color": Color(1.0, 0.5, 0.2)},
	{"name": "T", "cells": [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(1,1)], "color": Color(0.8, 0.2, 0.8)},
	{"name": "S", "cells": [Vector2i(0,1), Vector2i(1,1), Vector2i(1,0), Vector2i(2,0)], "color": Color(0.2, 0.8, 0.4)},
	{"name": "O", "cells": [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)], "color": Color(1.0, 0.85, 0.2)},
	{"name": "J", "cells": [Vector2i(0,0), Vector2i(0,1), Vector2i(1,1)], "color": Color(0.9, 0.3, 0.3)},
]

const SILHOUETTES := [
	[Vector2i(2,0), Vector2i(3,0), Vector2i(2,1), Vector2i(3,1),
	 Vector2i(0,2), Vector2i(1,2), Vector2i(2,2), Vector2i(3,2), Vector2i(4,2), Vector2i(5,2),
	 Vector2i(0,3), Vector2i(1,3), Vector2i(2,3), Vector2i(3,3), Vector2i(4,3), Vector2i(5,3),
	 Vector2i(2,4), Vector2i(3,4), Vector2i(2,5), Vector2i(3,5)],
	[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0), Vector2i(5,0),
	 Vector2i(2,1), Vector2i(3,1), Vector2i(2,2), Vector2i(3,2),
	 Vector2i(2,3), Vector2i(3,3), Vector2i(2,4), Vector2i(3,4), Vector2i(2,5), Vector2i(3,5)],
	[Vector2i(0,2), Vector2i(0,3), Vector2i(1,2), Vector2i(1,3),
	 Vector2i(2,1), Vector2i(2,2), Vector2i(2,3), Vector2i(2,4),
	 Vector2i(3,1), Vector2i(3,2), Vector2i(3,3), Vector2i(3,4),
	 Vector2i(4,0), Vector2i(4,1), Vector2i(4,2), Vector2i(4,3), Vector2i(4,4), Vector2i(4,5),
	 Vector2i(5,2), Vector2i(5,3)],
	[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0), Vector2i(5,0),
	 Vector2i(0,1), Vector2i(1,1), Vector2i(4,1), Vector2i(5,1),
	 Vector2i(0,2), Vector2i(1,2), Vector2i(4,2), Vector2i(5,2),
	 Vector2i(0,3), Vector2i(1,3), Vector2i(2,3), Vector2i(3,3), Vector2i(4,3), Vector2i(5,3)],
]

# ── Grid / game state ─────────────────────────────────────────────────────────
var target_cells: Array = []
var grid_occupied: Array = []
var grid_rects: Array = []
var selected_piece_index: int = -1
var selected_rotation: int = 0
var placed_pieces: Dictionary = {}
var _placed_rotations: Dictionary = {}

# ── UI references ─────────────────────────────────────────────────────────────
# piece_buttons[i] is the tray Button for piece i; also serves as the preview container
var piece_buttons: Array[Button] = []
# Per-piece rotation currently displayed in the tray (persists across select/deselect)
var _tray_rotations: Array[int] = []
var _clear_btn: Button
var _hint_btn: Button
var _solution_btn: Button
var _left_panel: Control

# ── Hint / solution state ─────────────────────────────────────────────────────
var _hints_remaining: int = MAX_HINTS
var _showing_solution: bool = false

# ── Drag state ────────────────────────────────────────────────────────────────
var _drag_piece_index: int = -1
var _drag_rotation: int = 0
var _drag_original_rotation: int = 0
var _drag_origin_cells: Array[Vector2i] = []  # empty = originated from library
var _drag_visual: Control = null

# ── Solver ────────────────────────────────────────────────────────────────────
var _solution: Dictionary = {}
var _solver_grid: Array = []
var _piece_rotations: Array = []

# =============================================================================
# Setup
# =============================================================================

func _setup_game() -> void:
	if title_label:
		title_label.text = "Tangram Puzzle!"
	_set_instructions("Drag pieces onto the grid. Right-click a placed piece to rotate it. Drag back to tray to remove.")

	var idx := randi() % SILHOUETTES.size()
	target_cells = SILHOUETTES[idx].duplicate()

	grid_occupied.resize(GRID_ROWS)
	for y in GRID_ROWS:
		grid_occupied[y] = []
		for x in GRID_COLS:
			grid_occupied[y].append(-1)

	_solve()
	_build_ui()

func _build_ui() -> void:
	if not game_area:
		return

	# Initialise per-piece tray rotations for this build
	_tray_rotations.resize(PIECE_DEFS.size())
	for i in PIECE_DEFS.size():
		_tray_rotations[i] = 0

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)
	game_area.add_child(hbox)

	# Left panel — keep reference for drop hit-testing
	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(170, 0)
	left_panel.add_theme_constant_override("separation", 6)
	hbox.add_child(left_panel)
	_left_panel = left_panel

	var tray_label := Label.new()
	tray_label.text = "Pieces:"
	tray_label.add_theme_font_size_override("font_size", 16)
	tray_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	left_panel.add_child(tray_label)

	for i in PIECE_DEFS.size():
		# Single button per piece: shows the piece preview, draggable from anywhere on it
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 48)
		btn.text = ""
		btn.clip_contents = false
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.gui_input.connect(_on_piece_btn_gui_input.bind(i))
		left_panel.add_child(btn)
		piece_buttons.append(btn)
		_draw_piece_preview(btn, i, 0)

	_clear_btn = Button.new()
	_clear_btn.text = "Clear All"
	_clear_btn.custom_minimum_size = Vector2(120, 32)
	_clear_btn.add_theme_font_size_override("font_size", 14)
	var clear_style := StyleBoxFlat.new()
	clear_style.bg_color = Color(0.6, 0.2, 0.2)
	clear_style.corner_radius_top_left = 4; clear_style.corner_radius_top_right = 4
	clear_style.corner_radius_bottom_left = 4; clear_style.corner_radius_bottom_right = 4
	_clear_btn.add_theme_stylebox_override("normal", clear_style)
	_clear_btn.pressed.connect(_on_clear_btn_pressed)
	left_panel.add_child(_clear_btn)

	_hint_btn = Button.new()
	_hint_btn.text = "Hint (%d)" % _hints_remaining
	_hint_btn.custom_minimum_size = Vector2(120, 32)
	_hint_btn.add_theme_font_size_override("font_size", 14)
	_hint_btn.disabled = _solution.is_empty()
	_hint_btn.pressed.connect(_on_hint_pressed)
	left_panel.add_child(_hint_btn)

	_solution_btn = Button.new()
	_solution_btn.text = "Show Solution"
	_solution_btn.custom_minimum_size = Vector2(120, 32)
	_solution_btn.add_theme_font_size_override("font_size", 14)
	_solution_btn.disabled = _solution.is_empty()
	_solution_btn.pressed.connect(_on_show_solution_pressed)
	left_panel.add_child(_solution_btn)

	# Grid
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
			cell.color = Color(0.25, 0.25, 0.35) if Vector2i(x, y) in target_cells else Color(0.12, 0.12, 0.15)

			var btn := Button.new()
			btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			btn.flat = true
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.gui_input.connect(_on_cell_gui_input.bind(Vector2i(x, y)))
			cell.add_child(btn)

			grid_container.add_child(cell)
			grid_rects[y].append(cell)

# =============================================================================
# Input
# =============================================================================

func _input(event: InputEvent) -> void:
	if _showing_solution:
		return

	if event is InputEventMouseMotion:
		if _drag_piece_index >= 0:
			_reposition_drag_visual(event.global_position)
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _drag_piece_index >= 0:
			_try_drop_drag(mb.global_position)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			if _drag_piece_index >= 0:
				_drag_rotation = (_drag_rotation + 1) % 4
				_rebuild_drag_visual_cells()
				_reposition_drag_visual(get_global_mouse_position())
			elif selected_piece_index >= 0:
				selected_rotation = (selected_rotation + 1) % 4
				_tray_rotations[selected_piece_index] = selected_rotation
				_refresh_selected_preview()

# Mouse-down on a tray piece button: start drag from library using the current tray rotation.
# If released back over the tray without moving, _try_drop_drag treats it as click-to-select.
func _on_piece_btn_gui_input(event: InputEvent, piece_index: int) -> void:
	if _showing_solution or _drag_piece_index >= 0:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if piece_index in placed_pieces:
		return

	selected_piece_index = -1
	selected_rotation = 0
	_drag_piece_index = piece_index
	_drag_rotation = _tray_rotations[piece_index]       # pick up the tray's current rotation
	_drag_original_rotation = _tray_rotations[piece_index]
	_drag_origin_cells.clear()  # empty = from library

	_create_drag_visual(mb.global_position)
	_update_piece_highlights()
	get_viewport().set_input_as_handled()

func _on_cell_gui_input(event: InputEvent, grid_pos: Vector2i) -> void:
	if _showing_solution or _drag_piece_index >= 0:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return

	get_viewport().set_input_as_handled()

	var piece_at: int = grid_occupied[grid_pos.y][grid_pos.x]

	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			if piece_at != -1 and selected_piece_index < 0:
				_start_drag(grid_pos, piece_at, mb.global_position)
			elif selected_piece_index >= 0:
				_try_place_at(grid_pos)
		MOUSE_BUTTON_RIGHT:
			if piece_at != -1:
				_try_rotate_placed(piece_at)

# =============================================================================
# Rotation helpers
# =============================================================================

func _get_rotated_cells(piece_index: int, rotation: int) -> Array[Vector2i]:
	var cells: Array = PIECE_DEFS[piece_index]["cells"]
	var result: Array[Vector2i] = []
	for c in cells:
		result.append(c)
	for _t in rotation:
		var rotated: Array[Vector2i] = []
		for c in result:
			rotated.append(Vector2i(c.y, -c.x))
		var min_x: int = rotated[0].x
		var min_y: int = rotated[0].y
		for c in rotated:
			if c.x < min_x: min_x = c.x
			if c.y < min_y: min_y = c.y
		result.clear()
		for c in rotated:
			result.append(Vector2i(c.x - min_x, c.y - min_y))
	return result

func _compute_rotations(cells: Array) -> Array:
	var seen: Array = []
	var result: Array = []
	var cur: Array[Vector2i] = []
	for c in cells:
		cur.append(c as Vector2i)
	for _r in 4:
		var sorted_cur := cur.duplicate()
		sorted_cur.sort()
		var already := false
		for s in seen:
			if s == sorted_cur:
				already = true; break
		if not already:
			seen.append(sorted_cur)
			result.append(cur.duplicate())
		var rotated: Array[Vector2i] = []
		for c in cur:
			rotated.append(Vector2i(c.y, -c.x))
		var min_x: int = rotated[0].x
		var min_y: int = rotated[0].y
		for c in rotated:
			if c.x < min_x: min_x = c.x
			if c.y < min_y: min_y = c.y
		cur.clear()
		for c in rotated:
			cur.append(Vector2i(c.x - min_x, c.y - min_y))
	return result

# =============================================================================
# UI helpers
# =============================================================================

# Draws piece squares as children of container with a small padding offset.
func _draw_piece_preview(container: Control, piece_index: int, rotation: int) -> void:
	var cells := _get_rotated_cells(piece_index, rotation)
	var col: Color = PIECE_DEFS[piece_index]["color"]
	var s := 13.0
	var pad := 8.0
	for cell_pos in cells:
		var rect := ColorRect.new()
		rect.color = col
		rect.size = Vector2(s, s)
		rect.position = Vector2(pad + cell_pos.x * (s + 2.0), pad + cell_pos.y * (s + 2.0))
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(rect)

func _refresh_selected_preview() -> void:
	if selected_piece_index < 0:
		return
	var btn := piece_buttons[selected_piece_index]
	for child in btn.get_children():
		child.free()
	_draw_piece_preview(btn, selected_piece_index, selected_rotation)

func _update_piece_highlights() -> void:
	for i in piece_buttons.size():
		var btn := piece_buttons[i]
		if i == selected_piece_index or i == _drag_piece_index:
			btn.modulate = Color(1, 1, 1, 1.0)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.45, 0.7)
			style.corner_radius_top_left = 4; style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4; style.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", style)
		elif i in placed_pieces:
			btn.modulate = Color(1, 1, 1, 0.35)
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")
		else:
			btn.modulate = Color(1, 1, 1, 1.0)
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")

func _cell_color(grid_pos: Vector2i) -> Color:
	return Color(0.25, 0.25, 0.35) if grid_pos in target_cells else Color(0.12, 0.12, 0.15)

# =============================================================================
# Drag and drop
# =============================================================================

func _start_drag(grid_pos: Vector2i, piece_index: int, mouse_global: Vector2) -> void:
	var world_cells: Array = placed_pieces[piece_index]
	var rot: int = _placed_rotations.get(piece_index, 0)

	_drag_piece_index = piece_index
	_drag_rotation = rot
	_drag_original_rotation = rot
	_drag_origin_cells.clear()
	for c in world_cells:
		_drag_origin_cells.append(c)

	for cell in world_cells:
		grid_occupied[cell.y][cell.x] = -1
		grid_rects[cell.y][cell.x].color = _cell_color(cell)
	placed_pieces.erase(piece_index)
	_placed_rotations.erase(piece_index)

	_create_drag_visual(mouse_global)
	_update_piece_highlights()

func _create_drag_visual(mouse_global: Vector2) -> void:
	if _drag_visual:
		_drag_visual.free()
	_drag_visual = Control.new()
	_drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_visual)
	_rebuild_drag_visual_cells()
	_reposition_drag_visual(mouse_global)

func _rebuild_drag_visual_cells() -> void:
	if not _drag_visual:
		return
	for child in _drag_visual.get_children():
		child.free()
	var cells := _get_rotated_cells(_drag_piece_index, _drag_rotation)
	var col := PIECE_DEFS[_drag_piece_index]["color"] as Color
	col.a = 0.75
	for cell_pos in cells:
		var rect := ColorRect.new()
		rect.color = col
		rect.size = Vector2(CELL_SIZE, CELL_SIZE)
		rect.position = Vector2(cell_pos.x * (CELL_SIZE + 2), cell_pos.y * (CELL_SIZE + 2))
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drag_visual.add_child(rect)

func _drag_visual_offset() -> Vector2:
	var cells := _get_rotated_cells(_drag_piece_index, _drag_rotation)
	var max_x := 0
	var max_y := 0
	for c in cells:
		if c.x > max_x: max_x = c.x
		if c.y > max_y: max_y = c.y
	return Vector2((max_x + 1) * (CELL_SIZE + 2) / 2.0, (max_y + 1) * (CELL_SIZE + 2) / 2.0)

func _reposition_drag_visual(mouse_global: Vector2) -> void:
	if _drag_visual:
		_drag_visual.position = mouse_global - _drag_visual_offset()

func _try_drop_drag(mouse_global: Vector2) -> void:
	var piece_index := _drag_piece_index
	var from_library := _drag_origin_cells.is_empty()

	# Drop over the piece tray
	if _left_panel and _left_panel.get_global_rect().has_point(mouse_global):
		if from_library:
			# Quick release back on tray = click-to-select, preserving current rotation
			_end_drag()
			selected_piece_index = piece_index
			selected_rotation = _tray_rotations[piece_index]
			_refresh_selected_preview()
			_update_piece_highlights()
		else:
			# Drag from grid onto tray = remove piece (grid already cleared at drag start)
			_end_drag()
		return

	# Try to place on the grid
	var piece_origin := mouse_global - _drag_visual_offset()
	var anchor := _grid_pos_at(piece_origin + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0))

	var placed := false
	if anchor.x >= 0:
		placed = _attempt_place_drag(anchor)

	if not placed:
		_restore_drag_to_origin()
	else:
		_check_win()

	_end_drag()

func _attempt_place_drag(anchor: Vector2i) -> bool:
	var cells := _get_rotated_cells(_drag_piece_index, _drag_rotation)
	var col: Color = PIECE_DEFS[_drag_piece_index]["color"]
	var world_cells: Array[Vector2i] = []
	for offset in cells:
		var cx := anchor.x + offset.x
		var cy := anchor.y + offset.y
		if cx < 0 or cx >= GRID_COLS or cy < 0 or cy >= GRID_ROWS:
			return false
		if grid_occupied[cy][cx] != -1:
			return false
		world_cells.append(Vector2i(cx, cy))
	for cell in world_cells:
		grid_occupied[cell.y][cell.x] = _drag_piece_index
		grid_rects[cell.y][cell.x].color = col
	placed_pieces[_drag_piece_index] = world_cells
	_placed_rotations[_drag_piece_index] = _drag_rotation
	return true

func _restore_drag_to_origin() -> void:
	if _drag_origin_cells.is_empty():
		return  # From library — nothing to restore
	var col: Color = PIECE_DEFS[_drag_piece_index]["color"]
	for cell in _drag_origin_cells:
		grid_occupied[cell.y][cell.x] = _drag_piece_index
		grid_rects[cell.y][cell.x].color = col
	placed_pieces[_drag_piece_index] = _drag_origin_cells.duplicate()
	_placed_rotations[_drag_piece_index] = _drag_original_rotation

func _end_drag() -> void:
	_drag_piece_index = -1
	_drag_rotation = 0
	_drag_original_rotation = 0
	_drag_origin_cells.clear()
	if _drag_visual:
		_drag_visual.free()
		_drag_visual = null
	_update_piece_highlights()

func _grid_pos_at(global_pos: Vector2) -> Vector2i:
	for y in GRID_ROWS:
		for x in GRID_COLS:
			if grid_rects[y][x].get_global_rect().has_point(global_pos):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

# =============================================================================
# Piece placement and rotation
# =============================================================================

func _try_place_at(grid_pos: Vector2i) -> void:
	if selected_piece_index < 0 or selected_piece_index >= PIECE_DEFS.size():
		return
	if selected_piece_index in placed_pieces:
		return
	var cells := _get_rotated_cells(selected_piece_index, selected_rotation)
	var col: Color = PIECE_DEFS[selected_piece_index]["color"]
	var world_cells: Array[Vector2i] = []
	for offset in cells:
		var cx := grid_pos.x + offset.x
		var cy := grid_pos.y + offset.y
		if cx < 0 or cx >= GRID_COLS or cy < 0 or cy >= GRID_ROWS:
			return
		if grid_occupied[cy][cx] != -1:
			return
		world_cells.append(Vector2i(cx, cy))
	for cell in world_cells:
		grid_occupied[cell.y][cell.x] = selected_piece_index
		grid_rects[cell.y][cell.x].color = col
	placed_pieces[selected_piece_index] = world_cells
	_placed_rotations[selected_piece_index] = selected_rotation
	selected_piece_index = -1
	selected_rotation = 0
	_update_piece_highlights()
	_check_win()

# Right-click on a placed piece: rotate it in place using the top-left corner as anchor.
func _try_rotate_placed(piece_index: int) -> void:
	var world_cells: Array = placed_pieces[piece_index]
	var cur_rot: int = _placed_rotations.get(piece_index, 0)
	var new_rot := (cur_rot + 1) % 4

	var min_x: int = world_cells[0].x
	var min_y: int = world_cells[0].y
	for c in world_cells:
		if c.x < min_x: min_x = c.x
		if c.y < min_y: min_y = c.y
	var anchor := Vector2i(min_x, min_y)

	# Temporarily clear from grid so overlap check is clean
	for cell in world_cells:
		grid_occupied[cell.y][cell.x] = -1

	var new_offsets := _get_rotated_cells(piece_index, new_rot)
	var world_new: Array[Vector2i] = []
	var valid := true
	for offset in new_offsets:
		var cx := anchor.x + offset.x
		var cy := anchor.y + offset.y
		if cx < 0 or cx >= GRID_COLS or cy < 0 or cy >= GRID_ROWS:
			valid = false; break
		if grid_occupied[cy][cx] != -1:
			valid = false; break
		world_new.append(Vector2i(cx, cy))

	if not valid:
		for cell in world_cells:
			grid_occupied[cell.y][cell.x] = piece_index
		return

	var col: Color = PIECE_DEFS[piece_index]["color"]
	for cell in world_cells:
		grid_rects[cell.y][cell.x].color = _cell_color(cell)
	for cell in world_new:
		grid_occupied[cell.y][cell.x] = piece_index
		grid_rects[cell.y][cell.x].color = col
	placed_pieces[piece_index] = world_new
	_placed_rotations[piece_index] = new_rot
	_check_win()

func _check_win() -> void:
	for cell in target_cells:
		if grid_occupied[cell.y][cell.x] == -1:
			return
	await get_tree().create_timer(0.5).timeout
	_complete(true)

# =============================================================================
# Board state management
# =============================================================================

func _clear_board() -> void:
	if _drag_piece_index >= 0:
		_end_drag()
	for piece_index in placed_pieces:
		var cells: Array = placed_pieces[piece_index]
		for cell in cells:
			grid_occupied[cell.y][cell.x] = -1
			grid_rects[cell.y][cell.x].color = _cell_color(cell)
	placed_pieces.clear()
	_placed_rotations.clear()
	selected_piece_index = -1
	selected_rotation = 0
	for i in piece_buttons.size():
		var btn := piece_buttons[i]
		for child in btn.get_children():
			child.free()
		_tray_rotations[i] = 0
		_draw_piece_preview(btn, i, 0)
	_update_piece_highlights()

func _full_reset() -> void:
	if _drag_visual:
		_drag_visual.free()
		_drag_visual = null

	for child in game_area.get_children():
		child.free()

	target_cells.clear(); grid_occupied.clear(); grid_rects.clear()
	placed_pieces.clear(); _placed_rotations.clear()
	piece_buttons.clear(); _tray_rotations.clear()
	selected_piece_index = -1; selected_rotation = 0
	_drag_piece_index = -1; _drag_rotation = 0; _drag_original_rotation = 0
	_drag_origin_cells.clear()
	_hints_remaining = MAX_HINTS; _showing_solution = false
	_solution.clear(); _solver_grid.clear(); _piece_rotations.clear()
	_clear_btn = null; _hint_btn = null; _solution_btn = null; _left_panel = null

	if title_label:
		title_label.text = "Tangram Puzzle!"
	_set_instructions("Drag pieces onto the grid. Right-click a placed piece to rotate it. Drag back to tray to remove.")

	var idx := randi() % SILHOUETTES.size()
	target_cells = SILHOUETTES[idx].duplicate()
	grid_occupied.resize(GRID_ROWS)
	for y in GRID_ROWS:
		grid_occupied[y] = []
		for x in GRID_COLS:
			grid_occupied[y].append(-1)

	_solve()
	_build_ui()

# =============================================================================
# Button handlers
# =============================================================================

func _on_clear_btn_pressed() -> void:
	if _showing_solution:
		call_deferred("_full_reset")
	else:
		_clear_board()

func _on_hint_pressed() -> void:
	if _hints_remaining <= 0 or _showing_solution or _solution.is_empty():
		return
	var candidates: Array = []
	for piece_index in _solution:
		if piece_index in placed_pieces:
			continue
		var world_cells: Array = _solution[piece_index]
		var fits := true
		for cell in world_cells:
			if grid_occupied[cell.y][cell.x] != -1:
				fits = false; break
		if fits:
			candidates.append(piece_index)
	if candidates.is_empty():
		return
	var piece_index: int = candidates[randi() % candidates.size()]
	var world_cells: Array = _solution[piece_index]
	var col: Color = PIECE_DEFS[piece_index]["color"]
	for cell in world_cells:
		grid_occupied[cell.y][cell.x] = piece_index
		grid_rects[cell.y][cell.x].color = col
	placed_pieces[piece_index] = world_cells
	_placed_rotations[piece_index] = 0
	_hints_remaining -= 1
	_hint_btn.text = "Hint (%d)" % _hints_remaining
	if _hints_remaining <= 0:
		_hint_btn.disabled = true
	_update_piece_highlights()
	_check_win()

func _on_show_solution_pressed() -> void:
	_clear_board()
	for piece_index in _solution:
		var world_cells: Array = _solution[piece_index]
		var col: Color = PIECE_DEFS[piece_index]["color"]
		for cell in world_cells:
			grid_occupied[cell.y][cell.x] = piece_index
			grid_rects[cell.y][cell.x].color = col
		placed_pieces[piece_index] = world_cells
		_placed_rotations[piece_index] = 0
	_showing_solution = true
	_solution_btn.disabled = true
	_hint_btn.disabled = true
	_clear_btn.text = "Reset"
	_update_piece_highlights()

# =============================================================================
# Solver
# =============================================================================

func _solve() -> void:
	_solution.clear()
	_piece_rotations.clear()
	for i in PIECE_DEFS.size():
		_piece_rotations.append(_compute_rotations(PIECE_DEFS[i]["cells"]))
	_solver_grid.resize(GRID_ROWS)
	for y in GRID_ROWS:
		_solver_grid[y] = []
		for x in GRID_COLS:
			_solver_grid[y].append(-1)
	var target_set: Dictionary = {}
	for c in target_cells:
		target_set[c] = true
	_try_solve(target_cells.duplicate(), range(PIECE_DEFS.size()), target_set)

func _try_solve(remaining: Array, unused: Array, target_set: Dictionary) -> bool:
	if remaining.is_empty():
		return true
	var first: Vector2i = remaining[0]
	for i in unused.size():
		var piece_index: int = unused[i]
		for rot_cells in _piece_rotations[piece_index]:
			for anchor in rot_cells:
				var offset: Vector2i = first - anchor
				var world_cells: Array[Vector2i] = []
				var valid := true
				for c in rot_cells:
					var wc: Vector2i = c + offset
					if wc.x < 0 or wc.x >= GRID_COLS or wc.y < 0 or wc.y >= GRID_ROWS:
						valid = false; break
					if _solver_grid[wc.y][wc.x] != -1:
						valid = false; break
					world_cells.append(wc)
				if not valid:
					continue
				for wc in world_cells:
					_solver_grid[wc.y][wc.x] = piece_index
				_solution[piece_index] = world_cells
				var new_unused := unused.duplicate()
				new_unused.remove_at(i)
				var new_remaining := remaining.duplicate()
				for wc in world_cells:
					if target_set.has(wc):
						new_remaining.erase(wc)
				if _try_solve(new_remaining, new_unused, target_set):
					return true
				for wc in world_cells:
					_solver_grid[wc.y][wc.x] = -1
				_solution.erase(piece_index)
	return false
