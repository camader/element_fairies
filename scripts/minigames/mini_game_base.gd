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
	mini_game_completed.emit(success)
	queue_free()

func _on_quit_button_pressed() -> void:
	_complete(false)

func _exit_tree() -> void:
	title_label = null
	instructions_label = null
	game_area = null
