extends Node3D

## Main 3D world scene with procedural terrain generation

const TerrainGeneratorScript = preload("res://scripts/terrain/terrain_generator.gd")

var terrain: Node3D = null
var _player: CharacterBody3D = null
var _boss_landmark_spawned := false
var _update_timer := 0.0
const UPDATE_INTERVAL := 0.5

# Landmark scene names for this level
var _landmark_names: Array[String] = []

const BIOME_LANDMARK_NAMES = {
	"volcanic": ["Ember Spire", "Magma Shrine", "Obsidian Gate", "Flame Altar", "Cinder Peak"],
	"forest": ["Mossy Hollow", "Ancient Oak", "Hidden Grotto", "Fern Chapel", "Root Throne"],
	"frozen": ["Frost Spire", "Ice Crystal Cave", "Glacier Altar", "Snowdrift Shrine", "Frozen Falls"],
	"ocean": ["Coral Tower", "Tidal Shrine", "Pearl Gate", "Wave Altar", "Shell Throne"],
	"mixed": ["Prism Spire", "Unity Shrine", "Convergence Gate", "Harmony Altar", "Starlight Throne"],
}

func _ready() -> void:
	var level_data: Dictionary = GameState.get_level_data()
	var biome: String = level_data["biome"]

	var names_arr: Array = BIOME_LANDMARK_NAMES.get(biome, BIOME_LANDMARK_NAMES["volcanic"])
	for n in names_arr:
		_landmark_names.append(n)

	# Setup environment
	_setup_environment(biome)

	# Create terrain generator
	terrain = TerrainGeneratorScript.new()
	terrain.name = "TerrainGenerator"
	add_child(terrain)
	terrain.initialize(biome, GameState.current_level * 1000 + 42)

	# Generate initial chunks around spawn
	terrain.update_chunks(Vector3.ZERO)
	terrain.create_boundary_walls()

	# Place landmarks procedurally
	var stars_needed: int = level_data["stars_required"]
	var landmark_positions: Array[Vector3] = terrain.place_landmarks(stars_needed)
	var clue_positions: Array[Vector3] = terrain.place_clues(landmark_positions)

	_spawn_landmarks(landmark_positions)
	_spawn_clues(clue_positions, landmark_positions)

	# Place guardian obstacles near landmarks and clues
	terrain.place_guardian_obstacles(landmark_positions + clue_positions)

	# Spawn player
	_spawn_player()

	# Reveal starting area
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			GameState.reveal_map_at(_player.global_position + Vector3(dx * GameState.MAP_CELL_SIZE, 0, dz * GameState.MAP_CELL_SIZE))

	# Listen for boss unlock
	GameState.boss_unlocked.connect(_on_boss_unlocked)

	# Auto-save on milestone signals
	GameState.landmark_completed.connect(_on_milestone_autosave)
	GameState.star_collected.connect(_on_star_autosave)

	# Restore saved state if loading from a save
	if SaveManager.has_pending_load():
		call_deferred("_deferred_restore_save")

func _setup_environment(biome: String) -> void:
	# Main directional light - low angle for strong terrain shadows
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var sun_colors = {
		"volcanic": Color(1.0, 0.8, 0.6),
		"forest": Color(0.95, 0.95, 0.8),
		"frozen": Color(0.85, 0.9, 1.0),
		"ocean": Color(0.95, 0.95, 1.0),
		"mixed": Color(1.0, 0.9, 0.95),
	}
	sun.light_color = sun_colors.get(biome, Color.WHITE)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.directional_shadow_max_distance = 120.0
	# Low angle sun = long shadows that reveal terrain shape
	sun.rotation_degrees = Vector3(-25, -45, 0)
	sun.position = Vector3(0, 10, 0)
	add_child(sun)

	# Fill light from opposite side - dimmer, no shadows
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = sun.light_color * 0.6 + Color(0.2, 0.2, 0.3)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-40, 135, 0)
	add_child(fill)

	# World environment
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()

	var sky_colors = {
		"volcanic": Color(0.35, 0.18, 0.12),
		"forest": Color(0.25, 0.4, 0.55),
		"frozen": Color(0.55, 0.7, 0.85),
		"ocean": Color(0.35, 0.55, 0.85),
		"mixed": Color(0.35, 0.3, 0.45),
	}
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky_colors.get(biome, Color(0.3, 0.3, 0.5))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Low ambient so shadows are visible - terrain reads better
	env.ambient_light_color = sun.light_color * 0.2
	env.ambient_light_energy = 0.25
	env.fog_enabled = true
	env.fog_light_color = sky_colors.get(biome, Color(0.3, 0.3, 0.5))
	env.fog_density = 0.003
	# SSAO for extra depth on terrain
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.5
	env_node.environment = env
	add_child(env_node)

func _spawn_player() -> void:
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	_player = player_scene.instantiate()
	_player.name = "Player"
	var spawn_pos: Vector3 = terrain.get_spawn_position()
	add_child(_player)
	_player.global_position = spawn_pos

	# Add HUD
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud: Node = hud_scene.instantiate()
	add_child(hud)

func _spawn_landmarks(positions: Array[Vector3]) -> void:
	var landmark_scene: PackedScene = load("res://scenes/landmark.tscn")
	for i in range(positions.size()):
		var lm: Node = landmark_scene.instantiate()
		lm.landmark_id = "landmark_%02d" % (i + 1)
		lm.landmark_name = _landmark_names[i] if i < _landmark_names.size() else "Landmark %d" % (i + 1)
		lm.position = positions[i]
		add_child(lm)

func _spawn_clues(clue_positions: Array[Vector3], landmark_positions: Array[Vector3]) -> void:
	var clue_scene: PackedScene = load("res://scenes/clue.tscn")
	var clue_texts: Array[String] = [
		"A faint glow beckons from the distance...",
		"Strange energy pulses from beyond the hills...",
		"The air shimmers with magical resonance...",
		"Ancient runes point the way forward...",
		"A gentle hum draws you onward...",
	]
	var hidden_clue_texts: Array[String] = [
		"Something shimmers beneath the water's surface...",
		"A muffled glow pulses deep under the pool...",
		"You sense magic trapped below the waterline...",
		"Ripples hint at something hidden in the depths...",
		"An ancient light flickers under the still water...",
	]

	# Decide which clues to hide under terrain pools (every other one, skip first)
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain._noise.seed + 333
	var hide_indices: Array[int] = []
	for i in range(clue_positions.size()):
		if i > 0 and rng.randf() < 0.4:
			hide_indices.append(i)

	for i in range(clue_positions.size()):
		var clue: Node = clue_scene.instantiate()
		var clue_id: String = "clue_%02d" % (i + 1)
		clue.clue_id = clue_id
		clue.reveals_poi = "landmark_%02d" % (i + 1)

		if i in hide_indices:
			# Place clue in a terrain depression, hidden under water
			var depression: Vector3 = terrain.find_depression_near(clue_positions[i])
			clue.position = depression + Vector3(0, 0.5, 0)
			clue.clue_text = hidden_clue_texts[i] if i < hidden_clue_texts.size() else "Something stirs below the surface..."
			clue.hidden_by_obstacle = true
			add_child(clue)
			# Create the terrain pool covering the clue
			terrain.place_clue_pool(depression, clue_id)
		else:
			clue.clue_text = clue_texts[i] if i < clue_texts.size() else "Something lies ahead..."
			clue.position = clue_positions[i]
			add_child(clue)

func _on_boss_unlocked() -> void:
	if not _boss_landmark_spawned:
		_boss_landmark_spawned = true
		_spawn_boss_landmark()

func _spawn_boss_landmark() -> void:
	var boss_pos: Vector3 = terrain.place_boss_landmark()
	var landmark_scene: PackedScene = load("res://scenes/landmark.tscn")
	var lm: Node = landmark_scene.instantiate()
	lm.landmark_id = "boss_landmark"
	lm.landmark_name = "Boss Challenge"
	lm.position = boss_pos
	lm.add_to_group("boss_landmark")
	lm.mini_game_override = "__boss__"
	add_child(lm)

func _physics_process(delta: float) -> void:
	if not _player:
		return

	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		terrain.update_chunks(_player.global_position)

func _deferred_restore_save() -> void:
	SaveManager.restore_after_world_ready()
	# Update landmark/clue visuals to match restored state
	for node in get_tree().get_nodes_in_group("clue"):
		if node.clue_id in GameState.discovered_clues:
			node.visible = false
			node.monitoring = false
	_show_save_toast("Game loaded")

func _on_milestone_autosave(_landmark_id: String) -> void:
	_autosave()

func _on_star_autosave(_total: int) -> void:
	_autosave()

func _autosave() -> void:
	if SaveManager.active_slot > 0:
		SaveManager.save_game()
		_show_save_toast("Game saved")

func _show_save_toast(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_save_toast"):
		hud.show_save_toast(text)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()

func _open_pause_menu() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var player := get_tree().get_first_node_in_group("player")
	if player and "_want_capture" in player:
		player._want_capture = false
	var pause_menu_script = preload("res://scripts/ui/pause_menu.gd")
	var menu := Control.new()
	menu.set_script(pause_menu_script)
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
