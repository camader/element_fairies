extends "res://scripts/minigames/mini_game_base.gd"

## Jigsaw Puzzle mini-game with drag and drop
## Colored pieces must be dragged from the left to matching slots on the right

const GRID_SIZE := 4
const CELL_SIZE := 70.0

var pieces: Array[Panel] = []
var slots: Array[Panel] = []
var target_colors: Array[Color] = []
var placed_count := 0
var dragging_piece: Panel = null
var drag_offset := Vector2.ZERO

func _setup_game() -> void:
	if title_label:
		title_label.text = "Jigsaw Puzzle!"
	_set_instructions("Drag each colored piece from the left and drop it on the matching colored slot on the right.")
	_build_puzzle()

func _build_puzzle() -> void:
	if not game_area:
		return

	var area_size := game_area.size

	# Generate target pattern colors
	for i in GRID_SIZE * GRID_SIZE:
		var hue := float(i) / float(GRID_SIZE * GRID_SIZE)
		target_colors.append(Color.from_hsv(hue, 0.7, 0.9))

	var grid_width := GRID_SIZE * CELL_SIZE
	var grid_height := GRID_SIZE * CELL_SIZE

	# === RIGHT SIDE: Target grid slots ===
	var grid_offset_x := area_size.x * 0.55
	var grid_offset_y := (area_size.y - grid_height) / 2.0

	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var slot := Panel.new()
			slot.position = Vector2(grid_offset_x + x * CELL_SIZE, grid_offset_y + y * CELL_SIZE)
			slot.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
			var style := StyleBoxFlat.new()
			style.bg_color = target_colors[y * GRID_SIZE + x] * 0.35
			style.border_color = target_colors[y * GRID_SIZE + x]
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			slot.add_theme_stylebox_override("panel", style)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			game_area.add_child(slot)
			slots.append(slot)

	# === LEFT SIDE: Draggable pieces scattered ===
	var indices: Array[int] = []
	for i in GRID_SIZE * GRID_SIZE:
		indices.append(i)
	indices.shuffle()

	var scatter_max_x := area_size.x * 0.4
	var rows := ceili(float(indices.size()) / 4.0)

	for i in indices.size():
		var piece := Panel.new()
		piece.size = Vector2(CELL_SIZE - 8, CELL_SIZE - 8)
		# Lay out in a scattered grid on the left
		var col := i % 4
		var row := i / 4
		var px := 10.0 + col * (CELL_SIZE + 5) + randf_range(-5, 5)
		var py := grid_offset_y + row * (CELL_SIZE + 5) + randf_range(-5, 5)
		piece.position = Vector2(px, py)

		var style := StyleBoxFlat.new()
		style.bg_color = target_colors[indices[i]]
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		piece.add_theme_stylebox_override("panel", style)
		piece.set_meta("target_index", indices[i])
		piece.set_meta("placed", false)
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game_area.add_child(piece)
		pieces.append(piece)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_pick_up(event.global_position)
		else:
			_try_drop()
	elif event is InputEventMouseMotion and dragging_piece:
		dragging_piece.global_position = event.global_position + drag_offset

func _try_pick_up(mouse_pos: Vector2) -> void:
	# Iterate in reverse so topmost piece is picked first
	for i in range(pieces.size() - 1, -1, -1):
		var piece := pieces[i]
		if piece.get_meta("placed"):
			continue
		if piece.get_global_rect().has_point(mouse_pos):
			dragging_piece = piece
			drag_offset = piece.global_position - mouse_pos
			# Move to top
			game_area.move_child(piece, -1)
			break

func _try_drop() -> void:
	if not dragging_piece:
		return

	var target_idx: int = dragging_piece.get_meta("target_index")
	if target_idx < slots.size():
		var target_slot := slots[target_idx]
		var slot_center := target_slot.global_position + target_slot.size / 2.0
		var piece_center := dragging_piece.global_position + dragging_piece.size / 2.0

		if piece_center.distance_to(slot_center) < CELL_SIZE:
			# Snap to slot
			dragging_piece.global_position = target_slot.global_position + Vector2(2, 2)
			dragging_piece.set_meta("placed", true)
			placed_count += 1

			if placed_count >= GRID_SIZE * GRID_SIZE:
				dragging_piece = null
				await get_tree().create_timer(0.5).timeout
				_complete(true)
				return

	dragging_piece = null
