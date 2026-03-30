extends Node

## Autoload singleton managing campaign level flow

signal level_started(level: int)
signal level_completed(level: int)
signal campaign_completed

func start_new_campaign() -> void:
	GameState.reset_campaign()
	start_level(1)

func start_level(level: int) -> void:
	GameState.start_level(level)
	# Auto-save at level start so Continue resumes from correct level
	if SaveManager.active_slot > 0:
		SaveManager.save_game()
	level_started.emit(level)
	get_tree().change_scene_to_file("res://scenes/level_intro.tscn")

func on_boss_defeated() -> void:
	GameState.boss_defeated = true
	var level := GameState.current_level
	var data := GameState.get_level_data()

	# Unlock the rescued fairy
	if data["rescue"] != null:
		var rescued: GameState.Fairy = data["rescue"]
		if rescued not in GameState.unlocked_fairies:
			GameState.unlocked_fairies.append(rescued)

	# Auto-save after boss defeat (captures unlocked fairy + completion)
	if SaveManager.active_slot > 0:
		SaveManager.save_game()

	level_completed.emit(level)

	if level >= 5:
		campaign_completed.emit()
		get_tree().change_scene_to_file("res://scenes/victory.tscn")
	else:
		# Show rescue cutscene then advance
		get_tree().change_scene_to_file("res://scenes/fairy_rescue.tscn")

func advance_to_next_level() -> void:
	var next_level := GameState.current_level + 1
	if next_level <= 5:
		start_level(next_level)
	else:
		campaign_completed.emit()
		get_tree().change_scene_to_file("res://scenes/victory.tscn")

func enter_boss_arena() -> void:
	get_tree().change_scene_to_file("res://scenes/boss_arena.tscn")

func return_to_world() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")
