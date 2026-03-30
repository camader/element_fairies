extends Control

## In-game pause menu with save, load, resume, and exit options

var _slot_panel: Panel = null
var _slot_mode: String = ""

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
	_close_slot_picker()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var player := get_tree().get_first_node_in_group("player")
	if player and "_want_capture" in player:
		player._want_capture = true
	queue_free()

func _on_save() -> void:
	if SaveManager.active_slot > 0:
		SaveManager.save_game()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_save_toast"):
			hud.show_save_toast("Game saved")
		_on_resume()
	else:
		_show_slot_picker("save")

func _on_load() -> void:
	_show_slot_picker("load")

func _on_exit() -> void:
	if SaveManager.active_slot > 0:
		SaveManager.save_game()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

# ── Slot picker ────────────────────────────────────────────────────────────

func _show_slot_picker(mode: String) -> void:
	if _slot_panel:
		_slot_panel.queue_free()
	_slot_mode = mode

	_slot_panel = Panel.new()
	_slot_panel.set_anchors_preset(Control.PRESET_CENTER)
	_slot_panel.custom_minimum_size = Vector2(500, 380)
	_slot_panel.offset_left = -250
	_slot_panel.offset_top = -190
	_slot_panel.offset_right = 250
	_slot_panel.offset_bottom = 190
	add_child(_slot_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 12)
	_slot_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Save to Slot" if mode == "save" else "Load Save Slot"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for i in range(1, SaveManager.MAX_SLOTS + 1):
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(0, 55)
		slot_btn.add_theme_font_size_override("font_size", 16)

		var info := SaveManager.get_slot_info(i)
		if info.is_empty():
			slot_btn.text = "Slot %d - Empty" % i
			if mode == "load":
				slot_btn.disabled = true
		else:
			var fairy_name: String = GameState.FAIRY_NAMES.get(info.get("fairy", 0), "Fire Fairy")
			slot_btn.text = "Slot %d - Level %d | Stars: %d | %s\n%s" % [
				i, info.get("level", 1), info.get("stars", 0),
				fairy_name, info.get("timestamp", "")
			]

		var slot_idx := i
		slot_btn.pressed.connect(_on_slot_selected.bind(slot_idx))
		vbox.add_child(slot_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 35)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(_close_slot_picker)
	vbox.add_child(back_btn)

func _on_slot_selected(slot: int) -> void:
	_close_slot_picker()
	if _slot_mode == "save":
		SaveManager.active_slot = slot
		SaveManager.save_game()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_save_toast"):
			hud.show_save_toast("Saved to slot %d" % slot)
		_on_resume()
	elif _slot_mode == "load":
		get_tree().paused = false
		SaveManager.load_game(slot)
		queue_free()

func _close_slot_picker() -> void:
	if _slot_panel:
		_slot_panel.queue_free()
		_slot_panel = null
