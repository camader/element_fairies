extends "res://scripts/minigames/mini_game_base.gd"

## Simon Says mini-game
## Watch the sequence of flashing panels, then repeat it from memory

const ROUNDS_TO_WIN := 5
const FLASH_DURATION := 0.5
const FLASH_GAP := 0.3
const PANEL_SIZE := 150.0

const PANEL_COLORS_DIM := [
	Color(0.5, 0.1, 0.1),  # Red
	Color(0.1, 0.1, 0.5),  # Blue
	Color(0.1, 0.5, 0.1),  # Green
	Color(0.5, 0.5, 0.1),  # Yellow
]
const PANEL_COLORS_BRIGHT := [
	Color(1.0, 0.3, 0.3),  # Red
	Color(0.3, 0.3, 1.0),  # Blue
	Color(0.3, 1.0, 0.3),  # Green
	Color(1.0, 1.0, 0.3),  # Yellow
]
const PANEL_LABELS := ["Red", "Blue", "Green", "Yellow"]

var sequence: Array[int] = []
var player_index := 0
var current_round := 0
var is_playing_sequence := false

var panel_buttons: Array[Button] = []
var round_label: Label
var status_label: Label

func _setup_game() -> void:
	if title_label:
		title_label.text = "Simon Says!"
	_set_instructions("Watch the sequence, then repeat it by clicking the panels.")
	_build_ui()
	_start_round()

func _build_ui() -> void:
	if not game_area:
		return

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	game_area.add_child(vbox)

	# Status labels
	var info_box := HBoxContainer.new()
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	info_box.add_theme_constant_override("separation", 40)
	vbox.add_child(info_box)

	round_label = Label.new()
	round_label.text = "Round 1/%d" % ROUNDS_TO_WIN
	round_label.add_theme_font_size_override("font_size", 22)
	round_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	info_box.add_child(round_label)

	status_label = Label.new()
	status_label.text = "Watch..."
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	info_box.add_child(status_label)

	# 2x2 grid of panels
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(center)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)

	for i in 4:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(PANEL_SIZE, PANEL_SIZE)
		btn.text = PANEL_LABELS[i]
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		_set_panel_color(btn, i, false)
		btn.pressed.connect(_on_panel_pressed.bind(i))
		grid.add_child(btn)
		panel_buttons.append(btn)

func _set_panel_color(btn: Button, index: int, bright: bool) -> void:
	var color: Color = PANEL_COLORS_BRIGHT[index] if bright else PANEL_COLORS_DIM[index]
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", style.duplicate())
	btn.add_theme_stylebox_override("hover", style.duplicate())
	btn.add_theme_stylebox_override("pressed", style.duplicate())

func _start_round() -> void:
	current_round += 1
	round_label.text = "Round %d/%d" % [current_round, ROUNDS_TO_WIN]
	status_label.text = "Watch..."

	# Add one to the sequence
	sequence.append(randi_range(0, 3))
	player_index = 0

	await get_tree().create_timer(0.5).timeout
	_play_sequence()

func _play_sequence() -> void:
	is_playing_sequence = true
	for i in sequence.size():
		var panel_idx: int = sequence[i]
		_set_panel_color(panel_buttons[panel_idx], panel_idx, true)
		await get_tree().create_timer(FLASH_DURATION).timeout
		_set_panel_color(panel_buttons[panel_idx], panel_idx, false)
		if i < sequence.size() - 1:
			await get_tree().create_timer(FLASH_GAP).timeout
	is_playing_sequence = false
	status_label.text = "Your turn!"
	status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))

func _on_panel_pressed(index: int) -> void:
	if is_playing_sequence:
		return

	# Flash the pressed panel briefly
	_set_panel_color(panel_buttons[index], index, true)
	await get_tree().create_timer(0.15).timeout
	_set_panel_color(panel_buttons[index], index, false)

	if index == sequence[player_index]:
		player_index += 1
		if player_index >= sequence.size():
			# Round complete
			if current_round >= ROUNDS_TO_WIN:
				status_label.text = "You win!"
				is_playing_sequence = true  # Block further input
				await get_tree().create_timer(0.5).timeout
				_complete(true)
			else:
				status_label.text = "Correct!"
				await get_tree().create_timer(0.8).timeout
				_start_round()
	else:
		# Wrong panel
		status_label.text = "Wrong!"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		is_playing_sequence = true  # Block further input
		await get_tree().create_timer(0.5).timeout
		_complete(false)
