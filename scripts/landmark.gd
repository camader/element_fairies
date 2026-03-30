extends Area3D

## A landmark in the world that triggers a mini-game when the player enters

@export var landmark_id: String = "landmark_01"
@export var landmark_name: String = "Mystic Stone"
@export var mini_game_override: String = ""  # Empty = random, "__boss__" = boss arena

@onready var label: Label3D = $Label3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var particles: GPUParticles3D = $Particles

var _player_nearby := false
var _completed := false
var _discovered := false

func _ready() -> void:
	if landmark_id in GameState.completed_landmarks:
		_completed = true
		_discovered = true
		_set_completed_appearance()
	elif landmark_id in GameState.discovered_pois or is_in_group("boss_landmark"):
		_discovered = true
	else:
		# Hide until clue is found
		_set_hidden(true)
	if label:
		label.text = landmark_name
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.clue_discovered.connect(_on_clue_discovered)

func _on_clue_discovered(_clue_id: String) -> void:
	if not _discovered and landmark_id in GameState.discovered_pois:
		_discovered = true
		_set_hidden(false)

func _set_hidden(hidden: bool) -> void:
	if mesh:
		mesh.visible = not hidden
	if label:
		label.visible = not hidden
	if particles:
		particles.visible = not hidden
		particles.emitting = not hidden

func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and _discovered and not _completed and event.is_action_pressed("interact"):
		if mini_game_override == "__boss__":
			_enter_boss_arena()
		else:
			_start_mini_game()

func _enter_boss_arena() -> void:
	CampaignManager.enter_boss_arena()

func _start_mini_game() -> void:
	var game_type: String
	if mini_game_override != "" and mini_game_override != "__boss__":
		game_type = mini_game_override
	else:
		game_type = GameState.get_random_mini_game()

	var scene_path := "res://scenes/minigames/%s.tscn" % game_type
	var mini_game_scene: PackedScene = load(scene_path) as PackedScene
	if mini_game_scene:
		# Free mouse before pausing so player doesn't re-capture
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		var player := get_tree().get_first_node_in_group("player")
		if player and "_want_capture" in player:
			player._want_capture = false
		var instance: Node = mini_game_scene.instantiate()
		instance.landmark_id = landmark_id
		instance.connect("mini_game_completed", _on_mini_game_completed)
		get_tree().current_scene.add_child(instance)
		get_tree().paused = true
		instance.process_mode = Node.PROCESS_MODE_ALWAYS

func _on_mini_game_completed(success: bool) -> void:
	get_tree().paused = false
	# Re-capture mouse and tell player to resume capturing
	var player := get_tree().get_first_node_in_group("player")
	if player and "_want_capture" in player:
		player._want_capture = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if success:
		_completed = true
		GameState.complete_landmark(landmark_id)
		GameState.collect_star()
		_set_completed_appearance()
		if player and player.has_method("play_animation"):
			player.play_animation("Celebrate")

func _set_completed_appearance() -> void:
	if mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.8, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 1.0, 0.4)
		mat.emission_energy_multiplier = 1.0
		mesh.material_override = mat

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_nearby = true
		if _discovered and not _completed and label:
			label.text = landmark_name + "\n[E] to interact"

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_nearby = false
		if label:
			label.text = landmark_name
