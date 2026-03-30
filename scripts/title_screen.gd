extends Control

@onready var button_container: VBoxContainer = $VBoxContainer
var _slot_panel: Panel = null
var _slot_mode: String = ""  # "new_game" or "load"

func _ready() -> void:
	# Show/hide Continue button
	var continue_btn := $VBoxContainer/ContinueButton
	var last_slot := SaveManager.get_last_slot()
	continue_btn.visible = last_slot > 0

func _on_new_game_button_pressed() -> void:
	_show_slot_picker("new_game")

func _on_continue_button_pressed() -> void:
	var last_slot := SaveManager.get_last_slot()
	if last_slot > 0:
		SaveManager.load_game(last_slot)

func _on_load_button_pressed() -> void:
	_show_slot_picker("load")

func _on_exit_button_pressed() -> void:
	get_tree().quit()

# ── Slot picker UI ────────────────────────────────────────────────────────

func _show_slot_picker(mode: String) -> void:
	if _slot_panel:
		_slot_panel.queue_free()
	_slot_mode = mode

	_slot_panel = Panel.new()
	_slot_panel.set_anchors_preset(Control.PRESET_CENTER)
	_slot_panel.custom_minimum_size = Vector2(500, 400)
	_slot_panel.offset_left = -250
	_slot_panel.offset_top = -200
	_slot_panel.offset_right = 250
	_slot_panel.offset_bottom = 200
	add_child(_slot_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 15)
	_slot_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Select Save Slot" if mode == "new_game" else "Load Save Slot"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for i in range(1, SaveManager.MAX_SLOTS + 1):
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(0, 60)
		slot_btn.add_theme_font_size_override("font_size", 18)

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

	# Delete save option (only in load mode)
	if mode == "load":
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 5)
		vbox.add_child(spacer)

		var delete_hbox := HBoxContainer.new()
		delete_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		delete_hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(delete_hbox)

		for i in range(1, SaveManager.MAX_SLOTS + 1):
			if SaveManager.has_save(i):
				var del_btn := Button.new()
				del_btn.text = "Delete Slot %d" % i
				del_btn.add_theme_font_size_override("font_size", 14)
				del_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
				var slot_idx := i
				del_btn.pressed.connect(_on_delete_slot.bind(slot_idx))
				delete_hbox.add_child(del_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_close_slot_picker)
	vbox.add_child(back_btn)

func _on_slot_selected(slot: int) -> void:
	if _slot_mode == "new_game" and SaveManager.has_save(slot):
		_show_overwrite_confirm(slot)
		return
	_close_slot_picker()
	if _slot_mode == "new_game":
		SaveManager.active_slot = slot
		SaveManager.delete_save(slot)
		CampaignManager.start_new_campaign()
	elif _slot_mode == "load":
		SaveManager.load_game(slot)

var _confirm_panel: Panel = null

func _show_overwrite_confirm(slot: int) -> void:
	if _confirm_panel:
		_confirm_panel.queue_free()

	_confirm_panel = Panel.new()
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.custom_minimum_size = Vector2(420, 180)
	_confirm_panel.offset_left = -210
	_confirm_panel.offset_top = -90
	_confirm_panel.offset_right = 210
	_confirm_panel.offset_bottom = 90
	add_child(_confirm_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 15)
	_confirm_panel.add_child(vbox)

	var info := SaveManager.get_slot_info(slot)
	var fairy_name: String = GameState.FAIRY_NAMES.get(info.get("fairy", 0), "Fire Fairy")
	var label := Label.new()
	label.text = "Overwrite Slot %d?\nLevel %d | Stars: %d | %s" % [
		slot, info.get("level", 1), info.get("stars", 0), fairy_name
	]
	label.add_theme_font_size_override("font_size", 18)
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
	yes_btn.pressed.connect(func():
		_confirm_panel.queue_free()
		_confirm_panel = null
		_close_slot_picker()
		SaveManager.active_slot = slot
		SaveManager.delete_save(slot)
		CampaignManager.start_new_campaign()
	)
	hbox.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(120, 40)
	no_btn.add_theme_font_size_override("font_size", 18)
	no_btn.pressed.connect(func():
		_confirm_panel.queue_free()
		_confirm_panel = null
	)
	hbox.add_child(no_btn)

func _on_delete_slot(slot: int) -> void:
	SaveManager.delete_save(slot)
	# Refresh the picker
	_show_slot_picker(_slot_mode)
	# Update continue button visibility
	$VBoxContainer/ContinueButton.visible = SaveManager.get_last_slot() > 0

func _close_slot_picker() -> void:
	if _slot_panel:
		_slot_panel.queue_free()
		_slot_panel = null
