extends Control

## Victory screen shown after completing all 5 levels

func _on_title_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
