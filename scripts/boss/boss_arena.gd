extends Control

## Boss arena: presents sequential puzzles that must all be beaten

var _puzzle_count: int = 3
var _current_puzzle: int = 0
var _puzzles_completed: int = 0

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var progress_label: Label = $Panel/VBox/ProgressLabel
@onready var puzzle_container: Control = $Panel/VBox/PuzzleContainer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var level_data: Dictionary = GameState.get_level_data()
	_puzzle_count = level_data["boss_puzzles"]

	if GameState.current_level == 5:
		title_label.text = "Final Boss: The Shadow"
	else:
		title_label.text = "Boss Challenge"

	_update_progress()
	_start_next_puzzle()

func _update_progress() -> void:
	progress_label.text = "Puzzle %d / %d" % [_current_puzzle + 1, _puzzle_count]

func _start_next_puzzle() -> void:
	if _puzzles_completed >= _puzzle_count:
		_on_all_puzzles_complete()
		return

	_current_puzzle = _puzzles_completed
	_update_progress()

	# Pick a random mini-game with increasing difficulty
	var game_type := GameState.get_random_mini_game()
	var scene_path := "res://scenes/minigames/%s.tscn" % game_type
	var mini_game_scene: PackedScene = load(scene_path) as PackedScene
	if mini_game_scene:
		var instance: Node = mini_game_scene.instantiate()
		instance.landmark_id = "boss_puzzle_%d" % _current_puzzle
		# Set difficulty based on level and puzzle number
		if instance.has_method("set_difficulty"):
			instance.set_difficulty(GameState.current_level + _current_puzzle)
		instance.connect("mini_game_completed", _on_puzzle_completed)
		puzzle_container.add_child(instance)

func _on_puzzle_completed(success: bool) -> void:
	if success:
		_puzzles_completed += 1
		# Clean up current puzzle
		for child in puzzle_container.get_children():
			child.queue_free()
		# Start next or finish
		if _puzzles_completed >= _puzzle_count:
			_on_all_puzzles_complete()
		else:
			# Brief delay then next puzzle
			await get_tree().create_timer(0.5).timeout
			_start_next_puzzle()
	else:
		# Failed - restart this puzzle only
		for child in puzzle_container.get_children():
			child.queue_free()
		await get_tree().create_timer(0.3).timeout
		_start_next_puzzle()

func _on_all_puzzles_complete() -> void:
	CampaignManager.on_boss_defeated()
