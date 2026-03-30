extends Control

## Fairy rescue cutscene shown after defeating a boss

@onready var title_label: Label = $VBox/TitleLabel
@onready var message_label: Label = $VBox/MessageLabel
@onready var fairy_label: Label = $VBox/FairyLabel
@onready var continue_button: Button = $VBox/ContinueButton

func _ready() -> void:
	var level_data := GameState.get_level_data()
	var level := GameState.current_level

	if level < 5 and level_data["rescue"] != null:
		var rescued_fairy: GameState.Fairy = level_data["rescue"]
		var rescued_name: String = GameState.FAIRY_NAMES[rescued_fairy]
		var rescued_color: Color = GameState.FAIRY_COLORS[rescued_fairy]

		title_label.text = "Fairy Rescued!"
		message_label.text = "You freed the %s from the darkness!" % rescued_name
		fairy_label.text = rescued_name
		fairy_label.add_theme_color_override("font_color", rescued_color)

		# Tint background
		var bg := $Background as ColorRect
		bg.color = rescued_color * 0.15 + Color(0.05, 0.05, 0.1)
	else:
		title_label.text = "The Fairy Princess is Saved!"
		message_label.text = "With all fairies united, peace returns to the realm!"
		fairy_label.text = "Fairy Princess"

func _on_continue_button_pressed() -> void:
	CampaignManager.advance_to_next_level()
