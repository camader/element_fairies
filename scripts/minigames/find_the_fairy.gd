extends "res://scripts/minigames/mini_game_base.gd"

## Find the Fairy mini-game
## A 4x4 grid of face-down cards hides one fairy - find it in 3 guesses using proximity hints

const GRID_SIZE := 4
const MAX_GUESSES := 3
const CARD_SIZE := 70.0

var fairy_pos := Vector2i.ZERO
var guesses_remaining := MAX_GUESSES
var guesses_label: Label
var grid: GridContainer
var game_over := false

func _setup_game() -> void:
	if title_label:
		title_label.text = "Find the Fairy!"
	_set_instructions("One card hides a fairy. Click to reveal - you have 3 guesses!")

	# Place fairy randomly
	fairy_pos = Vector2i(randi() % GRID_SIZE, randi() % GRID_SIZE)

	_build_ui()

func _build_ui() -> void:
	if not game_area:
		return

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	game_area.add_child(vbox)

	# Guesses label
	guesses_label = Label.new()
	guesses_label.text = "Guesses remaining: %d" % guesses_remaining
	guesses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guesses_label.add_theme_font_size_override("font_size", 18)
	guesses_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	vbox.add_child(guesses_label)

	# Center the grid
	var center := CenterContainer.new()
	vbox.add_child(center)

	# Grid
	grid = GridContainer.new()
	grid.columns = GRID_SIZE
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	center.add_child(grid)

	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var card := Button.new()
			card.custom_minimum_size = Vector2(CARD_SIZE, CARD_SIZE)
			card.text = "?"
			card.add_theme_font_size_override("font_size", 28)

			var stylebox := StyleBoxFlat.new()
			stylebox.bg_color = Color(0.25, 0.15, 0.4)
			stylebox.corner_radius_top_left = 8
			stylebox.corner_radius_top_right = 8
			stylebox.corner_radius_bottom_left = 8
			stylebox.corner_radius_bottom_right = 8
			card.add_theme_stylebox_override("normal", stylebox)

			var hover_style := StyleBoxFlat.new()
			hover_style.bg_color = Color(0.35, 0.25, 0.55)
			hover_style.corner_radius_top_left = 8
			hover_style.corner_radius_top_right = 8
			hover_style.corner_radius_bottom_left = 8
			hover_style.corner_radius_bottom_right = 8
			card.add_theme_stylebox_override("hover", hover_style)

			var pos := Vector2i(x, y)
			card.pressed.connect(_on_card_clicked.bind(pos, card))
			grid.add_child(card)

func _on_card_clicked(pos: Vector2i, card: Button) -> void:
	if game_over:
		return

	if pos == fairy_pos:
		# Found the fairy!
		game_over = true
		card.text = "✦"
		card.add_theme_font_size_override("font_size", 32)
		var win_style := StyleBoxFlat.new()
		win_style.bg_color = Color(0.2, 0.8, 0.2)
		win_style.corner_radius_top_left = 8
		win_style.corner_radius_top_right = 8
		win_style.corner_radius_bottom_left = 8
		win_style.corner_radius_bottom_right = 8
		card.add_theme_stylebox_override("normal", win_style)
		card.add_theme_stylebox_override("hover", win_style)
		guesses_label.text = "You found the fairy!"
		guesses_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		await get_tree().create_timer(0.5).timeout
		_complete(true)
	else:
		# Wrong guess - show proximity hint
		guesses_remaining -= 1
		var distance: int = abs(pos.x - fairy_pos.x) + abs(pos.y - fairy_pos.y)

		var hint_text := ""
		var hint_color := Color.WHITE

		if distance <= 1:
			hint_text = "Hot!"
			hint_color = Color(0.9, 0.3, 0.1)
		elif distance <= 2:
			hint_text = "Warm"
			hint_color = Color(0.9, 0.8, 0.2)
		else:
			hint_text = "Cold"
			hint_color = Color(0.2, 0.4, 0.9)

		card.text = hint_text
		card.add_theme_font_size_override("font_size", 14)
		card.disabled = true

		var hint_style := StyleBoxFlat.new()
		hint_style.bg_color = hint_color
		hint_style.corner_radius_top_left = 8
		hint_style.corner_radius_top_right = 8
		hint_style.corner_radius_bottom_left = 8
		hint_style.corner_radius_bottom_right = 8
		card.add_theme_stylebox_override("normal", hint_style)
		card.add_theme_stylebox_override("hover", hint_style)
		card.add_theme_stylebox_override("disabled", hint_style)

		guesses_label.text = "Guesses remaining: %d" % guesses_remaining

		if guesses_remaining <= 0:
			game_over = true
			guesses_label.text = "No guesses left! The fairy was hidden..."
			guesses_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			# Reveal fairy position
			var fairy_idx: int = fairy_pos.y * GRID_SIZE + fairy_pos.x
			var fairy_card: Button = grid.get_child(fairy_idx)
			fairy_card.text = "✦"
			fairy_card.add_theme_font_size_override("font_size", 32)
			var reveal_style := StyleBoxFlat.new()
			reveal_style.bg_color = Color(0.6, 0.2, 0.6)
			reveal_style.corner_radius_top_left = 8
			reveal_style.corner_radius_top_right = 8
			reveal_style.corner_radius_bottom_left = 8
			reveal_style.corner_radius_bottom_right = 8
			fairy_card.add_theme_stylebox_override("normal", reveal_style)
			fairy_card.add_theme_stylebox_override("hover", reveal_style)
			await get_tree().create_timer(0.5).timeout
			_complete(false)
