extends CanvasLayer

## Main game HUD with minimap, star counter, fairy indicator, and power cooldown

@onready var star_label: Label = $TopBar/StarLabel
@onready var fairy_label: Label = $TopBar/FairyLabel
@onready var level_label: Label = $TopBar/LevelLabel
@onready var minimap: Control = $MinimapPanel/Minimap
@onready var clue_popup: Panel = $CluePopup
@onready var clue_label: Label = $CluePopup/MarginContainer/ClueLabel
@onready var boss_indicator: Label = $TopBar/BossIndicator
@onready var power_indicator: Label = $PowerIndicator
@onready var fairy_switcher: HBoxContainer = $FairySwitcher

func _ready() -> void:
	add_to_group("hud")
	GameState.star_collected.connect(_on_star_collected)
	GameState.boss_unlocked.connect(_on_boss_unlocked)
	GameState.fairy_switched.connect(_on_fairy_switched)
	clue_popup.visible = false
	boss_indicator.visible = false
	_update_star_display()
	_update_fairy_display()
	_update_level_display()
	_update_fairy_switcher()

var _radar_label: Label = null

func _process(_delta: float) -> void:
	_update_power_indicator()
	_update_radar_indicator()

func _update_star_display() -> void:
	star_label.text = "★ %d / %d" % [GameState.star_pieces, GameState.stars_required]

func _update_fairy_display() -> void:
	var fairy_name: String = GameState.FAIRY_NAMES[GameState.active_fairy]
	var fairy_color: Color = GameState.FAIRY_COLORS[GameState.active_fairy]
	fairy_label.text = fairy_name
	fairy_label.add_theme_color_override("font_color", fairy_color)

func _update_level_display() -> void:
	var data := GameState.get_level_data()
	level_label.text = "Level %d - %s" % [GameState.current_level, data["biome_name"]]

func _update_power_indicator() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("get_power_cooldown"):
		return
	var cd: float = player.get_power_cooldown()
	var power_name := "Power"
	if player._current_power and player._current_power.has_method("get_power_name"):
		power_name = player._current_power.get_power_name()
	if cd > 0.0:
		power_indicator.text = "[F] %s (%.1fs)" % [power_name, cd * player._current_power.cooldown]
		power_indicator.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		power_indicator.text = "[F] %s  READY" % power_name
		power_indicator.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))

func _update_radar_indicator() -> void:
	if not _radar_label:
		_radar_label = Label.new()
		_radar_label.add_theme_font_size_override("font_size", 16)
		_radar_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		_radar_label.add_theme_constant_override("shadow_offset_x", 1)
		_radar_label.add_theme_constant_override("shadow_offset_y", 1)
		_radar_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_radar_label.anchor_left = 0.5
		_radar_label.anchor_top = 1.0
		_radar_label.anchor_right = 0.5
		_radar_label.anchor_bottom = 1.0
		_radar_label.offset_left = -150
		_radar_label.offset_top = -55
		_radar_label.offset_right = 150
		_radar_label.offset_bottom = -40
		_radar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_radar_label)

	var player := get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("get_radar_cooldown_fraction"):
		return
	var cd: float = player.get_radar_cooldown_fraction()
	if cd > 0.0:
		_radar_label.text = "[G] Radar Ping (%.1fs)" % (cd * player.RADAR_COOLDOWN)
		_radar_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	else:
		_radar_label.text = "[G] Radar Ping  READY"
		_radar_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))

func _update_fairy_switcher() -> void:
	# Show fairy switcher whenever multiple fairies are unlocked
	fairy_switcher.visible = GameState.unlocked_fairies.size() > 1
	if not fairy_switcher.visible:
		return

	# Clear existing buttons
	for child in fairy_switcher.get_children():
		child.queue_free()

	# Add button for each unlocked fairy
	var fairy_keys := [
		GameState.Fairy.FIRE, GameState.Fairy.EARTH, GameState.Fairy.ICE,
		GameState.Fairy.WATER, GameState.Fairy.RAINBOW
	]
	for i in range(fairy_keys.size()):
		var fairy: GameState.Fairy = fairy_keys[i]
		if fairy in GameState.unlocked_fairies:
			var btn := Label.new()
			var color: Color = GameState.FAIRY_COLORS[fairy]
			btn.text = "[%d] %s" % [i + 1, GameState.FAIRY_NAMES[fairy].split(" ")[0]]
			btn.add_theme_font_size_override("font_size", 14)
			if fairy == GameState.active_fairy:
				btn.add_theme_color_override("font_color", color)
			else:
				btn.add_theme_color_override("font_color", color * 0.5)
			fairy_switcher.add_child(btn)

func _on_star_collected(_total: int) -> void:
	_update_star_display()

func _on_boss_unlocked() -> void:
	boss_indicator.visible = true
	boss_indicator.text = "⚡ Boss Challenge Available!"

func _on_fairy_switched(_fairy: GameState.Fairy) -> void:
	_update_fairy_display()
	_update_fairy_switcher()

var _save_toast: Label = null

func show_save_toast(text: String) -> void:
	if not _save_toast:
		_save_toast = Label.new()
		_save_toast.add_theme_font_size_override("font_size", 16)
		_save_toast.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		_save_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		_save_toast.add_theme_constant_override("shadow_offset_x", 1)
		_save_toast.add_theme_constant_override("shadow_offset_y", 1)
		_save_toast.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_save_toast.anchor_left = 1.0
		_save_toast.anchor_top = 1.0
		_save_toast.anchor_right = 1.0
		_save_toast.anchor_bottom = 1.0
		_save_toast.offset_left = -200
		_save_toast.offset_top = -30
		_save_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(_save_toast)
	_save_toast.text = text
	_save_toast.modulate.a = 1.0
	_save_toast.visible = true
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_save_toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): _save_toast.visible = false)

func show_clue_message(text: String) -> void:
	clue_label.text = text
	clue_popup.visible = true
	clue_popup.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(clue_popup, "modulate:a", 1.0, 0.3)
	tween.tween_interval(3.0)
	tween.tween_property(clue_popup, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): clue_popup.visible = false)
