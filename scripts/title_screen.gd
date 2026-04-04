extends Control

@onready var button_container: VBoxContainer = $VBoxContainer
var _panel: Panel = null  # Reusable modal panel

func _ready() -> void:
	var continue_btn := $VBoxContainer/ContinueButton
	var last_id := SaveManager.get_last_save_id()
	continue_btn.visible = last_id != ""

func _on_new_game_button_pressed() -> void:
	_show_save_name_dialog()

func _on_continue_button_pressed() -> void:
	var last_id := SaveManager.get_last_save_id()
	if last_id != "":
		SaveManager.load_game(last_id)

func _on_load_button_pressed() -> void:
	_show_load_picker()

func _on_mini_games_button_pressed() -> void:
	_show_mini_game_picker()

func _on_exit_button_pressed() -> void:
	get_tree().quit()

# ── Helpers ───────────────────────────────────────────────────────────────

func _close_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null

func _create_modal(width: float, height: float) -> VBoxContainer:
	## Creates a centered modal panel and returns its inner VBoxContainer
	_close_panel()
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(width, height)
	_panel.offset_left = -width / 2.0
	_panel.offset_top = -height / 2.0
	_panel.offset_right = width / 2.0
	_panel.offset_bottom = height / 2.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)
	return vbox

func _add_title(vbox: VBoxContainer, text: String) -> void:
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

func _add_back_button(vbox: VBoxContainer) -> void:
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_close_panel)
	vbox.add_child(back_btn)

func _format_save_label(info: Dictionary, display_name: String) -> String:
	var fairy_name: String = GameState.FAIRY_NAMES.get(info.get("fairy", 0), "Fire Fairy")
	return "%s — Level %d | Stars: %d | %s\n%s" % [
		display_name,
		info.get("level", 1),
		info.get("stars", 0),
		fairy_name,
		info.get("timestamp", ""),
	]

# ── New Game: Name dialog ─────────────────────────────────────────────────

func _show_save_name_dialog() -> void:
	var vbox := _create_modal(450, 200)
	_add_title(vbox, "New Game")

	var name_input := LineEdit.new()
	name_input.placeholder_text = "Enter save name..."
	name_input.custom_minimum_size = Vector2(0, 40)
	name_input.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_input)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.custom_minimum_size = Vector2(120, 40)
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.pressed.connect(func():
		var save_name := name_input.text.strip_edges()
		if save_name == "":
			save_name = "Save %s" % Time.get_datetime_string_from_system().replace("T", " ").left(16)
		var save_id := SaveManager._generate_save_id()
		_close_panel()
		SaveManager.active_save_id = save_id
		# We'll save after campaign starts (autosave at level start handles it)
		# Store the display name for the first save
		SaveManager._update_index_entry(save_id, save_name, false)
		CampaignManager.start_new_campaign()
	)
	hbox.add_child(start_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(_close_panel)
	hbox.add_child(cancel_btn)

	name_input.grab_focus()

# ── Load Game picker ──────────────────────────────────────────────────────

func _show_load_picker() -> void:
	var all_saves := SaveManager.get_all_saves()

	var vbox := _create_modal(550, 500)
	_add_title(vbox, "Load Game")

	if all_saves.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No saved games found."
		empty_lbl.add_theme_font_size_override("font_size", 18)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_lbl)
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 300)
		vbox.add_child(scroll)

		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 8)
		scroll.add_child(list)

		for entry in all_saves:
			var save_id: String = entry.get("id", "")
			var display_name: String = entry.get("display_name", save_id)
			var is_auto: bool = entry.get("is_autosave", false)
			var info := SaveManager.get_save_info(save_id)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			list.add_child(row)

			var load_btn := Button.new()
			load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			load_btn.custom_minimum_size = Vector2(0, 55)
			load_btn.add_theme_font_size_override("font_size", 16)
			var prefix := "[Auto] " if is_auto else ""
			load_btn.text = prefix + _format_save_label(info, display_name)
			var sid := save_id
			load_btn.pressed.connect(func():
				_close_panel()
				SaveManager.load_game(sid)
			)
			row.add_child(load_btn)

			var del_btn := Button.new()
			del_btn.text = "✕"
			del_btn.custom_minimum_size = Vector2(40, 55)
			del_btn.add_theme_font_size_override("font_size", 18)
			del_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
			del_btn.pressed.connect(func():
				SaveManager.delete_save(sid)
				_show_load_picker()  # Refresh
				$VBoxContainer/ContinueButton.visible = SaveManager.get_last_save_id() != ""
			)
			row.add_child(del_btn)

	_add_back_button(vbox)

# ── Save Game picker (called from pause menu or in-game) ──────────────────

func _show_save_picker() -> void:
	## Can be called to show save dialog — create new or overwrite existing
	var user_saves := SaveManager.get_user_saves()

	var vbox := _create_modal(550, 500)
	_add_title(vbox, "Save Game")

	# New save button
	var new_save_btn := Button.new()
	new_save_btn.text = "+ Create New Save"
	new_save_btn.custom_minimum_size = Vector2(0, 45)
	new_save_btn.add_theme_font_size_override("font_size", 18)
	new_save_btn.pressed.connect(func():
		_close_panel()
		_show_save_name_input_for_save()
	)
	vbox.add_child(new_save_btn)

	if not user_saves.is_empty():
		var sep_label := Label.new()
		sep_label.text = "— or overwrite existing —"
		sep_label.add_theme_font_size_override("font_size", 14)
		sep_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sep_label)

		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 250)
		vbox.add_child(scroll)

		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 8)
		scroll.add_child(list)

		for entry in user_saves:
			var save_id: String = entry.get("id", "")
			var display_name: String = entry.get("display_name", save_id)
			var info := SaveManager.get_save_info(save_id)

			var save_btn := Button.new()
			save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			save_btn.custom_minimum_size = Vector2(0, 50)
			save_btn.add_theme_font_size_override("font_size", 16)
			save_btn.text = _format_save_label(info, display_name)
			var sid := save_id
			var sname := display_name
			save_btn.pressed.connect(func():
				_close_panel()
				_show_overwrite_confirm(sid, sname)
			)
			list.add_child(save_btn)

	_add_back_button(vbox)

func _show_save_name_input_for_save() -> void:
	var vbox := _create_modal(450, 200)
	_add_title(vbox, "Save As")

	var name_input := LineEdit.new()
	name_input.placeholder_text = "Enter save name..."
	name_input.custom_minimum_size = Vector2(0, 40)
	name_input.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_input)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(120, 40)
	save_btn.add_theme_font_size_override("font_size", 18)
	save_btn.pressed.connect(func():
		var save_name := name_input.text.strip_edges()
		if save_name == "":
			save_name = "Save %s" % Time.get_datetime_string_from_system().replace("T", " ").left(16)
		var save_id := SaveManager._generate_save_id()
		_close_panel()
		SaveManager.save_game(save_id, save_name)
	)
	hbox.add_child(save_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(_close_panel)
	hbox.add_child(cancel_btn)

	name_input.grab_focus()

func _show_overwrite_confirm(save_id: String, display_name: String) -> void:
	var info := SaveManager.get_save_info(save_id)

	var vbox := _create_modal(450, 200)
	_add_title(vbox, "Overwrite Save?")

	var label := Label.new()
	label.text = _format_save_label(info, display_name)
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var yes_btn := Button.new()
	yes_btn.text = "Overwrite"
	yes_btn.custom_minimum_size = Vector2(120, 40)
	yes_btn.add_theme_font_size_override("font_size", 18)
	var sid := save_id
	var sname := display_name
	yes_btn.pressed.connect(func():
		_close_panel()
		SaveManager.save_game(sid, sname)
	)
	hbox.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(120, 40)
	no_btn.add_theme_font_size_override("font_size", 18)
	no_btn.pressed.connect(_close_panel)
	hbox.add_child(no_btn)

# ── Mini Game Picker ──────────────────────────────────────────────────────

func _show_mini_game_picker() -> void:
	var vbox := _create_modal(550, 520)
	_add_title(vbox, "Mini Games")

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	var game_names := {
		"word_search": "Word Search",
		"spot_the_difference": "Spot the Difference",
		"jigsaw_puzzle": "Jigsaw Puzzle",
		"maze_puzzle": "Maze",
		"memory_match": "Memory Match",
		"simon_says": "Simon Says",
		"pattern_completion": "Pattern Completion",
		"find_the_fairy": "Find the Fairy",
		"sliding_puzzle": "Sliding Puzzle",
		"pipe_puzzle": "Connect the Pipes",
		"tangram": "Tangram",
		"hangman": "Hangman",
		"scrambled_letters": "Scrambled Letters",
	}

	for game_id in GameState.MINI_GAME_TYPES:
		var btn := Button.new()
		btn.text = game_names.get(game_id, game_id)
		btn.custom_minimum_size = Vector2(240, 50)
		btn.add_theme_font_size_override("font_size", 16)
		var gid: String = game_id
		btn.pressed.connect(_launch_mini_game.bind(gid))
		grid.add_child(btn)

	_add_back_button(vbox)

func _launch_mini_game(game_id: String) -> void:
	_close_panel()
	var scene_path := "res://scenes/minigames/%s.tscn" % game_id
	var mini_game_scene: PackedScene = load(scene_path)
	if not mini_game_scene:
		push_error("Failed to load mini game: %s" % scene_path)
		return
	var instance: Node = mini_game_scene.instantiate()
	instance.connect("mini_game_completed", _on_debug_mini_game_completed)
	add_child(instance)

func _on_debug_mini_game_completed(_success: bool) -> void:
	# Back to title screen — nothing to do, mini game frees itself
	pass
