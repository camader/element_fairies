extends Control

## In-game pause menu with save, load, resume, and exit options

var _panel: Panel = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Dim background overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	add_child(overlay)

	# Main menu panel
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(350, 350)
	panel.offset_left = -175
	panel.offset_top = -175
	panel.offset_right = 175
	panel.offset_bottom = 175
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 30
	vbox.offset_top = 25
	vbox.offset_right = -30
	vbox.offset_bottom = -25
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	_add_button(vbox, "Resume", _on_resume)
	_add_button(vbox, "Save Game", _on_save)
	_add_button(vbox, "Load Game", _on_load)
	_add_button(vbox, "Exit to Main Menu", _on_exit)

func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 45)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume()

# ── Actions ────────────────────────────────────────────────────────────────

func _on_resume() -> void:
	_close_panel()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var player := get_tree().get_first_node_in_group("player")
	if player and "_want_capture" in player:
		player._want_capture = true
	queue_free()

func _on_save() -> void:
	_show_save_picker()

func _on_load() -> void:
	_show_load_picker()

func _on_exit() -> void:
	if SaveManager.active_save_id != "":
		SaveManager.autosave()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

# ── Modal helpers ─────────────────────────────────────────────────────────

func _close_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null

func _create_modal(width: float, height: float) -> VBoxContainer:
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

func _format_save_label(info: Dictionary, display_name: String) -> String:
	var fairy_name: String = GameState.FAIRY_NAMES.get(info.get("fairy", 0), "Fire Fairy")
	return "%s — Level %d | Stars: %d | %s\n%s" % [
		display_name,
		info.get("level", 1),
		info.get("stars", 0),
		fairy_name,
		info.get("timestamp", ""),
	]

func _show_save_toast(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_save_toast"):
		hud.show_save_toast(text)

# ── Save picker ───────────────────────────────────────────────────────────

func _show_save_picker() -> void:
	var user_saves := SaveManager.get_user_saves()

	var vbox := _create_modal(520, 450)

	var title := Label.new()
	title.text = "Save Game"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# New save button
	var new_save_btn := Button.new()
	new_save_btn.text = "+ Create New Save"
	new_save_btn.custom_minimum_size = Vector2(0, 45)
	new_save_btn.add_theme_font_size_override("font_size", 18)
	new_save_btn.pressed.connect(func():
		_close_panel()
		_show_save_name_input()
	)
	vbox.add_child(new_save_btn)

	# Quick save to current slot if active
	if SaveManager.active_save_id != "" and not SaveManager.active_save_id.begins_with("autosave_"):
		var quick_btn := Button.new()
		quick_btn.text = "Quick Save (current)"
		quick_btn.custom_minimum_size = Vector2(0, 40)
		quick_btn.add_theme_font_size_override("font_size", 16)
		quick_btn.pressed.connect(func():
			_close_panel()
			SaveManager.save_game()
			_show_save_toast("Game saved")
			_on_resume()
		)
		vbox.add_child(quick_btn)

	if not user_saves.is_empty():
		var sep_label := Label.new()
		sep_label.text = "— or overwrite existing —"
		sep_label.add_theme_font_size_override("font_size", 14)
		sep_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sep_label)

		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 180)
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
			save_btn.add_theme_font_size_override("font_size", 15)
			save_btn.text = _format_save_label(info, display_name)
			var sid := save_id
			var sname := display_name
			save_btn.pressed.connect(func():
				_close_panel()
				SaveManager.save_game(sid, sname)
				_show_save_toast("Saved to \"%s\"" % sname)
				_on_resume()
			)
			list.add_child(save_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 35)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(_close_panel)
	vbox.add_child(back_btn)

func _show_save_name_input() -> void:
	var vbox := _create_modal(420, 190)

	var title := Label.new()
	title.text = "Save As"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

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
		_show_save_toast("Saved as \"%s\"" % save_name)
		_on_resume()
	)
	hbox.add_child(save_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(_close_panel)
	hbox.add_child(cancel_btn)

	name_input.grab_focus()

# ── Load picker ───────────────────────────────────────────────────────────

func _show_load_picker() -> void:
	var all_saves := SaveManager.get_all_saves()

	var vbox := _create_modal(520, 450)

	var title := Label.new()
	title.text = "Load Game"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

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
			load_btn.custom_minimum_size = Vector2(0, 50)
			load_btn.add_theme_font_size_override("font_size", 15)
			var prefix := "[Auto] " if is_auto else ""
			load_btn.text = prefix + _format_save_label(info, display_name)
			var sid := save_id
			load_btn.pressed.connect(func():
				_close_panel()
				get_tree().paused = false
				SaveManager.load_game(sid)
				queue_free()
			)
			row.add_child(load_btn)

			var del_btn := Button.new()
			del_btn.text = "✕"
			del_btn.custom_minimum_size = Vector2(40, 50)
			del_btn.add_theme_font_size_override("font_size", 18)
			del_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
			var sid2 := save_id
			del_btn.pressed.connect(func():
				SaveManager.delete_save(sid2)
				_show_load_picker()  # Refresh
			)
			row.add_child(del_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 35)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(_close_panel)
	vbox.add_child(back_btn)
