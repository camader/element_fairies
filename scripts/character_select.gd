extends Control

## Character selection screen - pick your fairy

func _on_fire_button_pressed() -> void:
	_select_fairy(GameState.Fairy.FIRE)

func _on_water_button_pressed() -> void:
	_select_fairy(GameState.Fairy.WATER)

func _on_earth_button_pressed() -> void:
	_select_fairy(GameState.Fairy.EARTH)

func _on_ice_button_pressed() -> void:
	_select_fairy(GameState.Fairy.ICE)

func _select_fairy(fairy: GameState.Fairy) -> void:
	GameState.selected_fairy = fairy
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/world.tscn")
