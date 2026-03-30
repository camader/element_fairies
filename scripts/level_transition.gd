extends Control

## Level intro screen showing fairy, objective, and biome name

@onready var level_label: Label = $VBox/LevelLabel
@onready var fairy_label: Label = $VBox/FairyLabel
@onready var biome_label: Label = $VBox/BiomeLabel
@onready var objective_label: Label = $VBox/ObjectiveLabel
@onready var start_button: Button = $VBox/StartButton

func _ready() -> void:
	var data := GameState.get_level_data()
	var level := GameState.current_level

	level_label.text = "Level %d" % level
	fairy_label.text = "Playing as: %s" % GameState.FAIRY_NAMES[GameState.active_fairy]

	var biome_name: String = data["biome_name"]
	biome_label.text = biome_name

	if level < 5:
		var rescue_name: String = GameState.FAIRY_NAMES[data["rescue"]]
		objective_label.text = "Explore the %s, collect %d stars,\nand rescue the %s!" % [biome_name, data["stars_required"], rescue_name]
	else:
		objective_label.text = "All fairies united! Explore the %s,\ncollect %d stars, and save the Fairy Princess!" % [biome_name, data["stars_required"]]

	if level >= 2:
		objective_label.text += "\n\nPress 1-%d to switch between unlocked fairies" % GameState.unlocked_fairies.size()

	# Color the background based on fairy
	var bg := $Background as ColorRect
	var fairy_color: Color = GameState.FAIRY_COLORS[GameState.active_fairy]
	bg.color = fairy_color * 0.2 + Color(0.05, 0.05, 0.1)

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")
