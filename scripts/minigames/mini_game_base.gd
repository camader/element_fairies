extends Control
class_name MiniGameBase

## Base class for all mini-games

signal mini_game_completed(success: bool)

var landmark_id: String = ""
var difficulty: int = 1  # Higher = harder (larger mazes, more differences, etc.)

var title_label: Label
var instructions_label: Label
var game_area: Control

func _ready() -> void:
	title_label = get_node_or_null("Panel/MarginContainer/VBoxContainer/TitleLabel")
	instructions_label = get_node_or_null("Panel/MarginContainer/VBoxContainer/InstructionsLabel")
	game_area = get_node_or_null("Panel/MarginContainer/VBoxContainer/GameArea")
	await get_tree().process_frame
	if is_inside_tree():
		_setup_game()

func _setup_game() -> void:
	pass

func set_difficulty(level: int) -> void:
	difficulty = level

func _set_instructions(text: String) -> void:
	if instructions_label:
		instructions_label.text = text

func _complete(success: bool) -> void:
	if success:
		_show_win_screen()
	else:
		mini_game_completed.emit(false)
		queue_free()

func _show_win_screen() -> void:
	# Intercept all input so the game underneath stays frozen
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.07, 0.20)
	panel_style.border_color = Color(1.0, 0.85, 0.2)
	panel_style.border_width_left = 3; panel_style.border_width_right = 3
	panel_style.border_width_top = 3; panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 14; panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14; panel_style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var stars := Label.new()
	stars.text = "* * * * *"
	stars.add_theme_font_size_override("font_size", 26)
	stars.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stars)

	var win_label := Label.new()
	win_label.text = "YOU WIN!"
	win_label.add_theme_font_size_override("font_size", 54)
	win_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(win_label)

	var congrats := Label.new()
	congrats.text = "Congratulations!"
	congrats.add_theme_font_size_override("font_size", 22)
	congrats.add_theme_color_override("font_color", Color(0.80, 0.80, 1.0))
	congrats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(congrats)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(gap)

	var btn_row := CenterContainer.new()
	vbox.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "Continue"
	ok_btn.custom_minimum_size = Vector2(160, 48)
	ok_btn.add_theme_font_size_override("font_size", 20)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.22, 0.52, 0.22)
	btn_style.corner_radius_top_left = 8; btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8; btn_style.corner_radius_bottom_right = 8
	ok_btn.add_theme_stylebox_override("normal", btn_style)
	btn_row.add_child(ok_btn)

	ok_btn.pressed.connect(func():
		mini_game_completed.emit(true)
		queue_free()
	)

func _on_quit_button_pressed() -> void:
	_complete(false)

func _exit_tree() -> void:
	title_label = null
	instructions_label = null
	game_area = null
