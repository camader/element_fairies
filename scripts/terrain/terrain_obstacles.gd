extends RefCounted

## Spawns terrain obstacles per chunk based on biome data

const ChunkScript = preload("res://scripts/terrain/chunk.gd")

static func spawn_obstacles(parent: Node3D, chunk_coord: Vector2i, biome: RefCounted, noise: FastNoiseLite, height_func: Callable, terrain_info_func: Callable = Callable()) -> Array[Node3D]:
	var obstacles: Array[Node3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(chunk_coord)

	var chunk_size: float = ChunkScript.CHUNK_SIZE
	var chunk_world := Vector3(chunk_coord.x * chunk_size, 0, chunk_coord.y * chunk_size)

	# Build clearable obstacle types from unlocked fairies intersected with biome types
	var clearable_types: Array[String] = _get_clearable_types(biome)

	# Determine how many obstacles in this chunk
	var count: int = int(biome.obstacle_density * 4)
	if rng.randf() > biome.obstacle_density * 3.0:
		return obstacles

	for i in range(count):
		var local_x: float = rng.randf_range(2.0, chunk_size - 2.0)
		var local_z: float = rng.randf_range(2.0, chunk_size - 2.0)
		var world_pos := Vector3(chunk_world.x + local_x, 0, chunk_world.z + local_z)

		var is_chokepoint := false
		var path_dir := Vector2(1, 0)

		if terrain_info_func.is_valid():
			var info: Dictionary = terrain_info_func.call(world_pos)
			var region_factor: float = info.region_factor
			var path_factor: float = info.path_factor
			path_dir = info.path_direction

			# Skip spawning in steep hill interiors (not traversable)
			if region_factor > 0.8 and path_factor > 0.7:
				continue

			is_chokepoint = info.is_chokepoint
			if not is_chokepoint:
				# Sparse random cull for non-chokepoints
				if rng.randf() > 0.5:
					continue
		else:
			if rng.randf() > 0.5:
				continue

		# Chokepoint barriers use only clearable types; random obstacles use any biome type
		var barrier_types: Array[String] = clearable_types if clearable_types.size() > 0 else biome.obstacle_types

		if is_chokepoint:
			# Chokepoint barrier: 2-3 obstacles in a line ACROSS the path
			var barrier_dir := Vector3(path_dir.x, 0, path_dir.y)
			var barrier_count: int = rng.randi_range(2, 3)
			var spacing := 3.0
			var facing_yaw: float = atan2(barrier_dir.x, barrier_dir.z)

			for bi in range(barrier_count):
				var offset: float = (bi - (barrier_count - 1) / 2.0) * spacing
				var obs_pos := world_pos + barrier_dir * offset
				obs_pos.y = height_func.call(obs_pos)

				var obs_type: String = barrier_types[rng.randi() % barrier_types.size()]
				var obstacle: StaticBody3D = _create_obstacle(obs_type, obs_pos)
				if obstacle:
					obstacle.rotation.y = facing_yaw
					parent.add_child(obstacle)
					obstacles.append(obstacle)
		else:
			world_pos.y = height_func.call(world_pos)
			var obs_types: Array[String] = biome.obstacle_types
			var obstacle_type: String = obs_types[rng.randi() % obs_types.size()]
			var obstacle: StaticBody3D = _create_obstacle(obstacle_type, world_pos)
			if obstacle:
				parent.add_child(obstacle)
				obstacles.append(obstacle)

	return obstacles

## Returns obstacle types the player can actually clear with their current fairies,
## intersected with what this biome offers.
static func _get_clearable_types(biome: RefCounted) -> Array[String]:
	const FAIRY_CLEARABLE := {
		GameState.Fairy.FIRE: ["ice_block", "water_pool"],
		GameState.Fairy.EARTH: ["gap", "lava_gap", "fire_wall"],
		GameState.Fairy.ICE: ["gap", "water_pool"],
		GameState.Fairy.WATER: ["fire_wall", "water_pool"],
	}
	var result: Array[String] = []
	for fairy in GameState.unlocked_fairies:
		if fairy not in FAIRY_CLEARABLE:
			continue
		for t in FAIRY_CLEARABLE[fairy]:
			if t in biome.obstacle_types and t not in result:
				result.append(t)
	return result

static func _create_obstacle(type: String, pos: Vector3) -> StaticBody3D:
	match type:
		"ice_block":
			return _make_ice_block(pos)
		"fire_wall":
			return _make_fire_wall(pos)
		"water_pool":
			return _make_water_pool(pos)
		"gap":
			return _make_gap(pos)
		"lava_gap":
			return _make_lava_gap(pos)
		"teleport_pad":
			return _make_teleport_pad(pos)
	return null

## Creates a self-leveling water pool that fills a terrain depression.
## Samples surrounding terrain to find the rim height, places a flat water
## surface at that level. Fire power can evaporate it to reveal hidden clues.
static func make_terrain_pool(center_pos: Vector3, height_func: Callable, radius: float = 3.0, hidden_clue_id: String = "") -> StaticBody3D:
	# Sample surrounding terrain to find rim height
	var rim_height: float = center_pos.y
	var sample_count := 8
	for i in range(sample_count):
		var angle: float = i * TAU / sample_count
		var sample_pos := Vector3(center_pos.x + cos(angle) * radius, 0, center_pos.z + sin(angle) * radius)
		var h: float = height_func.call(sample_pos)
		rim_height = maxf(rim_height, h)

	# Water surface sits at rim height
	var water_y: float = rim_height

	var body := StaticBody3D.new()
	body.position = Vector3(center_pos.x, water_y, center_pos.z)
	body.add_to_group("water_pool")
	body.add_to_group("terrain_obstacle")
	body.add_to_group("terrain_pool")

	if hidden_clue_id != "":
		body.set_meta("hidden_clue_id", hidden_clue_id)

	# Flat water surface mesh
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.15
	mesh.mesh = cyl
	mesh.position.y = 0.075

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.2, 0.6, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.15, 0.5)
	mat.emission_energy_multiplier = 0.2
	mat.roughness = 0.0
	mat.metallic = 0.4
	mesh.material_override = mat
	body.add_child(mesh)

	# Collision — thin disc at water level
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.3
	col.shape = shape
	col.position.y = 0.15
	body.add_child(col)

	return body

static func _make_ice_block(pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_to_group("ice_block")
	body.add_to_group("terrain_obstacle")

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 2.5, 2.0)
	mesh.mesh = box
	mesh.position.y = 1.25

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.85, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.3
	mat.roughness = 0.1
	mesh.material_override = mat
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.5, 2.0)
	col.shape = shape
	col.position.y = 1.25
	body.add_child(col)

	return body

static func _make_fire_wall(pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_to_group("fire_wall")
	body.add_to_group("terrain_obstacle")

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.0, 3.0, 0.5)
	mesh.mesh = box
	mesh.position.y = 1.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 3.0, 0.5)
	col.shape = shape
	col.position.y = 1.5
	body.add_child(col)

	var light := OmniLight3D.new()
	light.position.y = 2.0
	light.light_color = Color(1.0, 0.4, 0.0)
	light.light_energy = 2.0
	light.omni_range = 5.0
	body.add_child(light)

	return body

static func _make_water_pool(pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_to_group("water_pool")
	body.add_to_group("terrain_obstacle")

	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.5
	cyl.bottom_radius = 2.5
	cyl.height = 0.2
	mesh.mesh = cyl
	mesh.position.y = 0.1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.3, 0.8, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.2, 0.6)
	mat.emission_energy_multiplier = 0.3
	mat.roughness = 0.0
	mat.metallic = 0.3
	mesh.material_override = mat
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.5
	shape.height = 0.5
	col.shape = shape
	col.position.y = 0.25
	body.add_child(col)

	return body

static func _make_gap(pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_to_group("gap")
	body.add_to_group("terrain_obstacle")

	for side in [-1.5, 1.5]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.15
		cyl.height = 2.0
		post.mesh = cyl
		post.position = Vector3(side, 1.0, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.4, 0.2)
		post.material_override = mat
		body.add_child(post)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 0.3)
	col.shape = shape
	col.position.y = 1.5
	body.add_child(col)

	return body

static func _make_lava_gap(pos: Vector3) -> StaticBody3D:
	var body: StaticBody3D = _make_gap(pos)
	body.remove_from_group("gap")
	body.add_to_group("lava_gap")

	var lava_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 0.1, 0.3)
	lava_mesh.mesh = box
	lava_mesh.position.y = -0.2

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.0)
	mat.emission_energy_multiplier = 3.0
	lava_mesh.material_override = mat
	body.add_child(lava_mesh)

	return body

static func _make_teleport_pad(pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_to_group("teleport_pad")
	body.add_to_group("terrain_obstacle")

	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.5
	cyl.bottom_radius = 1.5
	cyl.height = 0.15
	mesh.mesh = cyl
	mesh.position.y = 0.075

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.3, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.2, 0.9)
	mat.emission_energy_multiplier = 1.5
	mesh.material_override = mat
	body.add_child(mesh)

	return body
