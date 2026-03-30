extends Node3D

## Procedural terrain generator using chunk-based approach with FastNoiseLite

const ChunkScript = preload("res://scripts/terrain/chunk.gd")
const BiomeScript = preload("res://scripts/terrain/biome_data.gd")
const ObstacleScript = preload("res://scripts/terrain/terrain_obstacles.gd")
const DecorationScript = preload("res://scripts/terrain/terrain_decorations.gd")

const LOAD_RADIUS := 5
const UNLOAD_RADIUS := 7
const WORLD_BOUNDARY := 6

var _noise: FastNoiseLite
var _cliff_noise: FastNoiseLite  # Second noise layer for cliffs
var _region_noise: FastNoiseLite  # Very low freq — plains vs hills zones
var _path_noise: FastNoiseLite    # Low freq abs ridges — corridors through hills
var _biome: RefCounted  # BiomeData instance
var _chunks: Dictionary = {}  # Vector2i -> chunk Node3D
var _obstacles_node: Node3D
var _decorations_node: Node3D
var _landmarks_placed := false
var _landmark_positions: Array[Vector3] = []
var _clue_positions: Array[Vector3] = []
var _boss_landmark_position: Vector3 = Vector3.ZERO

signal terrain_ready

func initialize(biome_type: String, seed_val: int = 0) -> void:
	_biome = BiomeScript.new()
	_biome.configure_for_biome(biome_type)

	var base_seed: int = seed_val if seed_val != 0 else randi()

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = _biome.noise_frequency
	_noise.fractal_octaves = _biome.noise_octaves
	_noise.fractal_lacunarity = _biome.noise_lacunarity
	_noise.fractal_gain = _biome.noise_gain
	_noise.seed = base_seed

	# Cliff noise: low frequency, high contrast ridges
	_cliff_noise = FastNoiseLite.new()
	_cliff_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_cliff_noise.frequency = 0.015
	_cliff_noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	_cliff_noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	_cliff_noise.seed = base_seed + 500

	# Region noise: very low frequency simplex — large plains/hills zones
	_region_noise = FastNoiseLite.new()
	_region_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_region_noise.frequency = _biome.region_frequency
	_region_noise.fractal_octaves = 2
	_region_noise.seed = base_seed + 1000

	# Path noise: low frequency simplex — abs() creates ridge corridors
	_path_noise = FastNoiseLite.new()
	_path_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_path_noise.frequency = _biome.path_frequency
	_path_noise.fractal_octaves = 2
	_path_noise.seed = base_seed + 2000

	_obstacles_node = Node3D.new()
	_obstacles_node.name = "Obstacles"
	add_child(_obstacles_node)

	_decorations_node = Node3D.new()
	_decorations_node.name = "Decorations"
	add_child(_decorations_node)

func update_chunks(player_pos: Vector3) -> void:
	var player_chunk: Vector2i = _world_to_chunk(player_pos)

	for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var coord := Vector2i(player_chunk.x + dx, player_chunk.y + dz)
			if abs(coord.x) > WORLD_BOUNDARY or abs(coord.y) > WORLD_BOUNDARY:
				continue
			if not _chunks.has(coord):
				_generate_chunk(coord)

	var to_remove: Array[Vector2i] = []
	var keys: Array = _chunks.keys()
	for i in range(keys.size()):
		var coord: Vector2i = keys[i]
		var dist: float = Vector2(coord.x - player_chunk.x, coord.y - player_chunk.y).length()
		if dist > UNLOAD_RADIUS:
			to_remove.append(coord)

	for coord in to_remove:
		var chunk: Node3D = _chunks[coord]
		chunk.queue_free()
		_chunks.erase(coord)

func _generate_chunk(coord: Vector2i) -> void:
	var chunk: Node3D = ChunkScript.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	add_child(chunk)
	chunk.generate(_noise, _biome, coord, _cliff_noise, _region_noise, _path_noise)
	_chunks[coord] = chunk

	if Vector2(coord).length() > 1.0:
		ObstacleScript.spawn_obstacles(
			_obstacles_node,
			coord,
			_biome,
			_noise,
			get_height_at,
			Callable(self, "get_terrain_info_at")
		)

	# Spawn decorative props on flat areas
	DecorationScript.spawn_decorations(
		_decorations_node,
		coord,
		_biome,
		get_height_at,
		Callable(self, "get_terrain_info_at")
	)

func get_height_at(world_pos: Vector3) -> float:
	var coord: Vector2i = _world_to_chunk(world_pos)
	if _chunks.has(coord):
		var chunk: Node3D = _chunks[coord]
		var chunk_size: float = ChunkScript.CHUNK_SIZE
		var local_x: float = fmod(world_pos.x - coord.x * chunk_size, chunk_size)
		var local_z: float = fmod(world_pos.z - coord.y * chunk_size, chunk_size)
		if local_x < 0:
			local_x += chunk_size
		if local_z < 0:
			local_z += chunk_size
		return chunk.get_height_at_local(local_x, local_z)
	# Fallback: recompute with full formula
	return _compute_height(world_pos.x, world_pos.z)

func _compute_height(wx: float, wz: float) -> float:
	var h: float = _noise.get_noise_2d(wx, wz) * _biome.noise_amplitude

	var rv: float = _region_noise.get_noise_2d(wx, wz)
	var region_factor: float = ChunkScript._smoothstep_range(rv, _biome.region_threshold, _biome.region_blend_range)
	var amp_scale: float = lerpf(_biome.plains_amplitude_scale, _biome.hills_amplitude_scale, region_factor)
	h *= amp_scale

	var pv: float = absf(_path_noise.get_noise_2d(wx, wz))
	var path_factor: float = ChunkScript._smoothstep_range(pv, _biome.path_width, _biome.path_width * 0.5)
	var path_flatten: float = (1.0 - path_factor) * region_factor * _biome.path_depth
	h = lerpf(h, 0.0, path_flatten)

	var cliff_val: float = _cliff_noise.get_noise_2d(wx, wz)
	if cliff_val > 0.3:
		var cliff_mask: float = region_factor * path_factor
		h += (cliff_val - 0.3) * 25.0 * cliff_mask

	return h

func get_terrain_info_at(world_pos: Vector3) -> Dictionary:
	var wx: float = world_pos.x
	var wz: float = world_pos.z

	var rv: float = _region_noise.get_noise_2d(wx, wz)
	var region_factor: float = ChunkScript._smoothstep_range(rv, _biome.region_threshold, _biome.region_blend_range)

	var pv: float = absf(_path_noise.get_noise_2d(wx, wz))
	var path_factor: float = ChunkScript._smoothstep_range(pv, _biome.path_width, _biome.path_width * 0.5)

	var is_chokepoint: bool = region_factor > 0.6 and path_factor < 0.3

	# Path direction: perpendicular to the gradient of path_noise
	# Gradient points away from path center; perpendicular = along the path
	var eps := 0.5
	var pn_dx: float = _path_noise.get_noise_2d(wx + eps, wz) - _path_noise.get_noise_2d(wx - eps, wz)
	var pn_dz: float = _path_noise.get_noise_2d(wx, wz + eps) - _path_noise.get_noise_2d(wx, wz - eps)
	var path_dir := Vector2(-pn_dz, pn_dx).normalized()

	return {
		"region_factor": region_factor,
		"path_factor": path_factor,
		"is_chokepoint": is_chokepoint,
		"height": get_height_at(world_pos),
		"path_direction": path_dir,
	}

func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	var chunk_size: float = ChunkScript.CHUNK_SIZE
	return Vector2i(
		floori(world_pos.x / chunk_size),
		floori(world_pos.z / chunk_size)
	)

func place_landmarks(count: int) -> Array[Vector3]:
	_landmark_positions.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _noise.seed + 42

	var min_distance := 25.0
	var chunk_size: float = ChunkScript.CHUNK_SIZE
	var max_range: float = WORLD_BOUNDARY * chunk_size * 0.7

	var attempts := 0
	while _landmark_positions.size() < count and attempts < 500:
		attempts += 1
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(20.0, max_range)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)

		var too_close := pos.length() < 15.0
		for existing in _landmark_positions:
			if pos.distance_to(existing) < min_distance:
				too_close = true
				break

		if not too_close:
			pos.y = get_height_at(pos) + 0.5
			_landmark_positions.append(pos)

	return _landmark_positions

# Which obstacle types each fairy power can clear
const FAIRY_CLEARABLE := {
	GameState.Fairy.FIRE: ["ice_block", "water_pool"],
	GameState.Fairy.EARTH: ["gap", "lava_gap", "fire_wall"],
	GameState.Fairy.ICE: ["gap", "water_pool"],
	GameState.Fairy.WATER: ["fire_wall", "water_pool"],
	# Rainbow only does teleport — not a barrier type
}

func place_guardian_obstacles(positions: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _noise.seed + 200

	# Build list of clearable obstacle types per unlocked fairy, intersected with biome types
	var fairy_to_types: Dictionary = {}  # Fairy -> Array[String]
	for fairy in GameState.unlocked_fairies:
		if fairy not in FAIRY_CLEARABLE:
			continue
		var clearable: Array = FAIRY_CLEARABLE[fairy]
		var available: Array[String] = []
		for t in clearable:
			if t in _biome.obstacle_types:
				available.append(t)
		if available.size() > 0:
			fairy_to_types[fairy] = available

	# If no clearable types match the biome, fall back to all biome types
	if fairy_to_types.is_empty():
		fairy_to_types[GameState.unlocked_fairies[0]] = _biome.obstacle_types.duplicate()

	var usable_fairies: Array = fairy_to_types.keys()

	for pos in positions:
		# Direction from spawn toward this landmark/clue
		var approach_dir := Vector3(pos.x, 0, pos.z).normalized()
		if approach_dir.length_squared() < 0.01:
			approach_dir = Vector3(1, 0, 0)

		# Perpendicular direction — barrier line runs along this
		var perp_dir := Vector3(-approach_dir.z, 0, approach_dir.x)

		# Place barrier 6-10 units before the target (on approach side)
		var barrier_dist: float = rng.randf_range(6.0, 10.0)
		var barrier_center := Vector3(
			pos.x - approach_dir.x * barrier_dist,
			0,
			pos.z - approach_dir.z * barrier_dist
		)

		# How many distinct fairy powers this barrier requires
		var num_power_types: int
		if GameState.current_level <= 1:
			num_power_types = 1
		else:
			num_power_types = rng.randi_range(1, mini(usable_fairies.size(), GameState.unlocked_fairies.size()))

		# Pick which fairies' obstacle types to use
		var shuffled: Array = usable_fairies.duplicate()
		for si in range(shuffled.size() - 1, 0, -1):
			var sj: int = rng.randi_range(0, si)
			var tmp = shuffled[si]
			shuffled[si] = shuffled[sj]
			shuffled[sj] = tmp
		var chosen_fairies: Array = shuffled.slice(0, num_power_types)

		# Collect the obstacle types from the chosen fairies
		var barrier_types: Array[String] = []
		for fairy in chosen_fairies:
			for t in fairy_to_types[fairy]:
				if t not in barrier_types:
					barrier_types.append(t)

		if barrier_types.is_empty():
			continue

		# Create barrier: 3-4 obstacles in a line perpendicular to approach
		var barrier_count: int = rng.randi_range(3, 4)
		var spacing: float = 3.5

		for i in range(barrier_count):
			var offset: float = (i - (barrier_count - 1) / 2.0) * spacing
			var obs_pos := barrier_center + perp_dir * offset
			obs_pos.y = get_height_at(obs_pos)

			var obs_type: String = barrier_types[rng.randi() % barrier_types.size()]
			var obstacle: StaticBody3D = ObstacleScript._create_obstacle(obs_type, obs_pos)
			if obstacle:
				obstacle.rotation.y = atan2(approach_dir.x, approach_dir.z)
				_obstacles_node.add_child(obstacle)

func place_clues(landmark_positions_arr: Array[Vector3]) -> Array[Vector3]:
	_clue_positions.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _noise.seed + 99

	for lm_pos in landmark_positions_arr:
		var dir: Vector3 = lm_pos.normalized()
		var dist: float = lm_pos.length() * rng.randf_range(0.3, 0.6)
		var offset := Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
		var clue_pos: Vector3 = dir * dist + offset
		clue_pos.y = get_height_at(clue_pos) + 0.5
		_clue_positions.append(clue_pos)

	return _clue_positions

## Searches near a position for the lowest terrain point (a natural depression).
## Returns the depression center position with its terrain height.
func find_depression_near(pos: Vector3, search_radius: float = 6.0) -> Vector3:
	var best_pos := pos
	var best_h: float = get_height_at(pos)
	var step := 1.5
	var cx: float = pos.x
	var cz: float = pos.z
	var r: float = step
	while r <= search_radius:
		for i in range(8):
			var angle: float = i * TAU / 8.0
			var sample := Vector3(cx + cos(angle) * r, 0, cz + sin(angle) * r)
			var h: float = get_height_at(sample)
			if h < best_h:
				best_h = h
				best_pos = sample
		r += step
	best_pos.y = best_h
	return best_pos

## Creates a self-leveling terrain pool at a depression, optionally hiding a clue.
func place_clue_pool(center_pos: Vector3, hidden_clue_id: String = "") -> StaticBody3D:
	var depression := find_depression_near(center_pos)
	var pool: StaticBody3D = ObstacleScript.make_terrain_pool(
		depression, get_height_at, 3.0, hidden_clue_id
	)
	_obstacles_node.add_child(pool)
	return pool

func place_boss_landmark() -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = _noise.seed + 777
	var chunk_size: float = ChunkScript.CHUNK_SIZE
	var max_range: float = WORLD_BOUNDARY * chunk_size * 0.6
	var angle: float = rng.randf() * TAU
	var dist: float = rng.randf_range(30.0, max_range)
	_boss_landmark_position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	_boss_landmark_position.y = get_height_at(_boss_landmark_position) + 0.5
	return _boss_landmark_position

func get_spawn_position() -> Vector3:
	var h: float = get_height_at(Vector3.ZERO)
	return Vector3(0, h + 1.0, 0)

func create_boundary_walls() -> void:
	# Invisible catch floor so the player can never fall into the void
	var catch_floor := StaticBody3D.new()
	catch_floor.name = "CatchFloor"
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	var chunk_size: float = ChunkScript.CHUNK_SIZE
	var world_extent: float = (WORLD_BOUNDARY + 2) * chunk_size
	floor_shape.size = Vector3(world_extent * 2.0, 1.0, world_extent * 2.0)
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0, -25.0, 0)
	catch_floor.add_child(floor_col)
	add_child(catch_floor)

	# Invisible walls slightly inside the map edge so the player stays on terrain
	var wall_height := 60.0
	var wall_thickness := 2.0
	var boundary: float = (WORLD_BOUNDARY - 0.5) * chunk_size
	var wall_length: float = boundary * 2.0 + wall_thickness * 2.0

	var walls := StaticBody3D.new()
	walls.name = "BoundaryWalls"
	add_child(walls)

	var wall_y: float = wall_height / 2.0 - 30.0

	var positions: Array[Vector3] = [
		Vector3(0, wall_y, -boundary),
		Vector3(0, wall_y, boundary),
		Vector3(boundary, wall_y, 0),
		Vector3(-boundary, wall_y, 0),
	]
	var sizes: Array[Vector3] = [
		Vector3(wall_length, wall_height, wall_thickness),
		Vector3(wall_length, wall_height, wall_thickness),
		Vector3(wall_thickness, wall_height, wall_length),
		Vector3(wall_thickness, wall_height, wall_length),
	]

	for i in range(positions.size()):
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = sizes[i]
		col.shape = shape
		col.position = positions[i]
		walls.add_child(col)
