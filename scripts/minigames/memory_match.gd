extends "res://scripts/minigames/mini_game_base.gd"

## Memory Match mini-game
## Flip cards to find matching pairs of fairy-themed symbols

const GRID_COLS := 4
const GRID_ROWS := 4
const CARD_SIZE := 70.0
const FLIP_BACK_DELAY := 0.8

const SYMBOLS := ["★", "♦", "✿", "☀", "☽", "⚡", "♥", "✦"]
const SYMBOL_COLORS := [
	Color(1.0, 0.84, 0.0),    # ★ Gold
	Color(0.0, 0.75, 1.0),    # ♦ Blue
	Color(1.0, 0.4, 0.7),     # ✿ Pink
	Color(1.0, 0.6, 0.0),     # ☀ Orange
	Color(0.7, 0.7, 1.0),     # ☽ Lavender
	Color(1.0, 1.0, 0.2),     # ⚡ Yellow
	Color(1.0, 0.2, 0.3),     # ♥ Red
	Color(0.4, 1.0, 0.8),     # ✦ Teal
]

var cards: Array[Dictionary] = []  # {button, symbol_index, face_up, matched}
var first_flip: int = -1
var second_flip: int = -1
var is_checking := false
var pairs_found := 0

func _setup_game() -> void:
	if title_label:
		title_label.text = "Memory Match!"
	_set_instructions("Flip cards to find matching pairs of fairy symbols.")
	_build_board()

func _build_board() -> void:
	if not game_area:
		return

	# Create shuffled pairs
	var indices: Array[int] = []
	for i in SYMBOLS.size():
		indices.append(i)
		indices.append(i)
	indices.shuffle()

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_area.add_child(center)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	center.add_child(grid)

	for i in GRID_COLS * GRID_ROWS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(CARD_SIZE, CARD_SIZE)
		btn.text = "?"
		btn.add_theme_font_size_override("font_size", 28)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.25, 0.15, 0.35)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", style.duplicate())
		btn.add_theme_stylebox_override("hover", style.duplicate())
		btn.add_theme_stylebox_override("pressed", style.duplicate())

		btn.pressed.connect(_on_card_pressed.bind(i))
		grid.add_child(btn)

		cards.append({
			"button": btn,
			"symbol_index": indices[i],
			"face_up": false,
			"matched": false,
		})

func _on_card_pressed(index: int) -> void:
	if is_checking:
		return
	var card: Dictionary = cards[index]
	if card.face_up or card.matched:
		return

	_flip_up(index)

	if first_flip == -1:
		first_flip = index
	elif second_flip == -1:
		second_flip = index
		is_checking = true
		await get_tree().create_timer(0.3).timeout
		_check_match()

func _flip_up(index: int) -> void:
	var card: Dictionary = cards[index]
	card.face_up = true
	var sym_idx: int = card.symbol_index
	var btn: Button = card.button
	btn.text = SYMBOLS[sym_idx]

	var style := StyleBoxFlat.new()
	style.bg_color = SYMBOL_COLORS[sym_idx].darkened(0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style.duplicate())
	btn.add_theme_stylebox_override("hover", style.duplicate())
	btn.add_theme_stylebox_override("pressed", style.duplicate())
	btn.add_theme_color_override("font_color", SYMBOL_COLORS[sym_idx])

func _flip_down(index: int) -> void:
	var card: Dictionary = cards[index]
	card.face_up = false
	var btn: Button = card.button
	btn.text = "?"

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.15, 0.35)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style.duplicate())
	btn.add_theme_stylebox_override("hover", style.duplicate())
	btn.add_theme_stylebox_override("pressed", style.duplicate())
	btn.remove_theme_color_override("font_color")

func _check_match() -> void:
	var card_a: Dictionary = cards[first_flip]
	var card_b: Dictionary = cards[second_flip]

	if card_a.symbol_index == card_b.symbol_index:
		# Match found
		card_a.matched = true
		card_b.matched = true
		pairs_found += 1

		# Highlight matched pair green
		for idx in [first_flip, second_flip]:
			var btn: Button = cards[idx].button
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.4, 0.15)
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			btn.add_theme_stylebox_override("normal", style.duplicate())
			btn.add_theme_stylebox_override("hover", style.duplicate())
			btn.add_theme_stylebox_override("pressed", style.duplicate())
			btn.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))

		first_flip = -1
		second_flip = -1
		is_checking = false

		if pairs_found >= SYMBOLS.size():
			await get_tree().create_timer(0.5).timeout
			_complete(true)
	else:
		# No match — flip back
		await get_tree().create_timer(FLIP_BACK_DELAY).timeout
		_flip_down(first_flip)
		_flip_down(second_flip)
		first_flip = -1
		second_flip = -1
		is_checking = false
