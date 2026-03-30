extends RefCounted

## Spawns decorative props (trees, rocks, crystals) on flat terrain areas
## All props use StaticBody3D with collision so the player can't walk through them.
## Materials are shared across instances to reduce draw call overhead.

const ChunkScript = preload("res://scripts/terrain/chunk.gd")

# Cached shared materials — created once, reused across all decorations
static var _trunk_mat: StandardMaterial3D
static var _rock_mats: Array[StandardMaterial3D] = []
static var _crystal_mat: StandardMaterial3D
static var _leaf_mats: Dictionary = {}  # "color_hex" -> StandardMaterial3D
static var _coral_mats: Array[StandardMaterial3D] = []

static func _get_trunk_mat() -> StandardMaterial3D:
	if not _trunk_mat:
		_trunk_mat = StandardMaterial3D.new()
		_trunk_mat.albedo_color = Color(0.35, 0.22, 0.1)
		_trunk_mat.roughness = 0.95
	return _trunk_mat

static func _get_leaf_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _leaf_mats.has(key):
		return _leaf_mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	_leaf_mats[key] = mat
	return mat

static func _get_rock_mat(color: Color) -> StandardMaterial3D:
	# Quantize rock colors to reduce unique materials
	var quantized := Color(
		snappedf(color.r, 0.05),
		snappedf(color.g, 0.05),
		snappedf(color.b, 0.05)
	)
	var key := quantized.to_html()
	if _leaf_mats.has(key):
		return _leaf_mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = quantized
	mat.roughness = 0.95
	_leaf_mats[key] = mat
	return mat

static func _get_crystal_mat() -> StandardMaterial3D:
	if not _crystal_mat:
		_crystal_mat = StandardMaterial3D.new()
		_crystal_mat.albedo_color = Color(0.6, 0.85, 1.0, 0.85)
		_crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_crystal_mat.emission_enabled = true
		_crystal_mat.emission = Color(0.4, 0.65, 0.9)
		_crystal_mat.emission_energy_multiplier = 0.5
		_crystal_mat.roughness = 0.1
	return _crystal_mat

static func _get_coral_mat(color: Color) -> StandardMaterial3D:
	var quantized := Color(
		snappedf(color.r, 0.1),
		snappedf(color.g, 0.1),
		snappedf(color.b, 0.1)
	)
	var key := "coral_" + quantized.to_html()
	if _leaf_mats.has(key):
		return _leaf_mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = quantized
	mat.roughness = 0.7
	_leaf_mats[key] = mat
	return mat

static func spawn_decorations(parent: Node3D, chunk_coord: Vector2i, biome: RefCounted, height_func: Callable, terrain_info_func: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(chunk_coord) + 7777

	var chunk_size: float = ChunkScript.CHUNK_SIZE
	var chunk_world := Vector3(chunk_coord.x * chunk_size, 0, chunk_coord.y * chunk_size)

	var count: int = rng.randi_range(3, 6)
	for i in range(count):
		var local_x: float = rng.randf_range(1.0, chunk_size - 1.0)
		var local_z: float = rng.randf_range(1.0, chunk_size - 1.0)
		var world_pos := Vector3(chunk_world.x + local_x, 0, chunk_world.z + local_z)

		if terrain_info_func.is_valid():
			var info: Dictionary = terrain_info_func.call(world_pos)
			# Only spawn decorations on relatively flat ground
			if info.region_factor > 0.5:
				continue

		world_pos.y = height_func.call(world_pos)

		var prop: Node3D = _create_prop(biome.biome_type, world_pos, rng)
		if prop:
			# Add prop to tree first, then attach collision deferred
			# so the physics body RID is valid when shapes are registered
			var deferred_col: CollisionShape3D = prop.get_meta("_deferred_col", null)
			if deferred_col:
				prop.remove_meta("_deferred_col")
				parent.add_child(prop)
				prop.add_child(deferred_col)
			else:
				parent.add_child(prop)

static func _create_prop(biome_type: String, pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	match biome_type:
		"forest":
			return _make_tree(pos, rng, Color(0.15, 0.35, 0.1), Color(0.2, 0.45, 0.15))
		"frozen":
			if rng.randf() > 0.5:
				return _make_tree(pos, rng, Color(0.2, 0.35, 0.25), Color(0.55, 0.7, 0.6))
			else:
				return _make_crystal(pos, rng)
		"ocean":
			if rng.randf() > 0.4:
				return _make_tree(pos, rng, Color(0.3, 0.5, 0.25), Color(0.35, 0.55, 0.3))
			else:
				return _make_coral(pos, rng)
		"volcanic":
			return _make_rock_formation(pos, rng)
		"mixed":
			var roll: float = rng.randf()
			if roll < 0.4:
				return _make_tree(pos, rng, Color(0.2, 0.35, 0.15), Color(0.25, 0.4, 0.2))
			elif roll < 0.7:
				return _make_rock_formation(pos, rng)
			else:
				return _make_crystal(pos, rng)
	return null

static func _make_tree(pos: Vector3, rng: RandomNumberGenerator, leaf_color: Color, leaf_highlight: Color) -> StaticBody3D:
	var tree := StaticBody3D.new()
	tree.position = pos
	tree.add_to_group("decoration")

	var trunk_height: float = rng.randf_range(1.5, 3.5)
	var trunk_radius: float = rng.randf_range(0.1, 0.2)

	# Trunk
	var trunk_mesh := MeshInstance3D.new()
	var trunk_cyl := CylinderMesh.new()
	trunk_cyl.top_radius = trunk_radius * 0.7
	trunk_cyl.bottom_radius = trunk_radius
	trunk_cyl.height = trunk_height
	trunk_mesh.mesh = trunk_cyl
	trunk_mesh.position.y = trunk_height / 2.0
	trunk_mesh.material_override = _get_trunk_mat()
	tree.add_child(trunk_mesh)

	# Canopy — single cone instead of multiple layers (reduces draw calls)
	var canopy_radius: float = rng.randf_range(0.8, 1.6)
	var cone_mesh := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = canopy_radius
	cone.height = canopy_radius * 1.8
	cone_mesh.mesh = cone
	cone_mesh.position.y = trunk_height + canopy_radius * 0.25
	cone_mesh.material_override = _get_leaf_mat(leaf_color.lerp(leaf_highlight, 0.3))
	tree.add_child(cone_mesh)

	# Collision — cylinder for trunk + lower canopy (deferred via metadata)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = maxf(trunk_radius, 0.25)  # At least 0.25 so player bumps into it
	shape.height = trunk_height + 0.5
	col.shape = shape
	col.position.y = shape.height / 2.0
	tree.set_meta("_deferred_col", col)

	tree.rotation.y = rng.randf() * TAU
	return tree

static func _make_rock_formation(pos: Vector3, rng: RandomNumberGenerator) -> StaticBody3D:
	var rocks := StaticBody3D.new()
	rocks.position = pos
	rocks.add_to_group("decoration")

	# Single rock mesh instead of 1-3 separate ones
	var rock_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	var sx: float = rng.randf_range(0.6, 1.4)
	var sy: float = rng.randf_range(0.4, 1.0)
	var sz: float = rng.randf_range(0.6, 1.2)
	box.size = Vector3(sx, sy, sz)
	rock_mesh.mesh = box
	rock_mesh.position.y = sy / 2.0
	rock_mesh.rotation = Vector3(
		rng.randf_range(-0.2, 0.2),
		rng.randf() * TAU,
		rng.randf_range(-0.2, 0.2)
	)

	rock_mesh.material_override = _get_rock_mat(Color(
		rng.randf_range(0.2, 0.35),
		rng.randf_range(0.12, 0.2),
		rng.randf_range(0.08, 0.15)
	))
	rocks.add_child(rock_mesh)

	# Collision (deferred via metadata)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(sx, sy, sz)
	col.shape = shape
	col.position.y = sy / 2.0
	rocks.set_meta("_deferred_col", col)

	return rocks

static func _make_crystal(pos: Vector3, rng: RandomNumberGenerator) -> StaticBody3D:
	var crystal := StaticBody3D.new()
	crystal.position = pos
	crystal.add_to_group("decoration")

	# Single shard instead of 2-4 separate meshes
	var shard_mesh := MeshInstance3D.new()
	var prism := CylinderMesh.new()
	var bottom_r: float = rng.randf_range(0.15, 0.3)
	prism.top_radius = 0.02
	prism.bottom_radius = bottom_r
	prism.height = rng.randf_range(0.7, 1.5)
	prism.radial_segments = 6
	shard_mesh.mesh = prism
	shard_mesh.position.y = prism.height / 2.0
	shard_mesh.rotation = Vector3(
		rng.randf_range(-0.3, 0.3),
		rng.randf() * TAU,
		rng.randf_range(-0.3, 0.3)
	)
	shard_mesh.material_override = _get_crystal_mat()
	crystal.add_child(shard_mesh)

	# Collision (deferred via metadata)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = maxf(bottom_r, 0.3)
	shape.height = prism.height
	col.shape = shape
	col.position.y = prism.height / 2.0
	crystal.set_meta("_deferred_col", col)

	return crystal

static func _make_coral(pos: Vector3, rng: RandomNumberGenerator) -> StaticBody3D:
	var coral := StaticBody3D.new()
	coral.position = pos
	coral.add_to_group("decoration")

	# Reduced to 2 branches max instead of 3-6
	var branch_count: int = rng.randi_range(1, 2)
	var max_height := 0.0
	var max_radius := 0.0
	for i in range(branch_count):
		var branch_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var bottom_r: float = rng.randf_range(0.08, 0.15)
		cyl.top_radius = rng.randf_range(0.03, 0.08)
		cyl.bottom_radius = bottom_r
		cyl.height = rng.randf_range(0.4, 1.0)
		branch_mesh.mesh = cyl
		var bx: float = rng.randf_range(-0.4, 0.4)
		var bz: float = rng.randf_range(-0.4, 0.4)
		branch_mesh.position = Vector3(bx, cyl.height / 2.0, bz)
		branch_mesh.rotation = Vector3(
			rng.randf_range(-0.4, 0.4),
			rng.randf() * TAU,
			rng.randf_range(-0.4, 0.4)
		)
		max_height = maxf(max_height, cyl.height)
		max_radius = maxf(max_radius, absf(bx) + bottom_r)
		max_radius = maxf(max_radius, absf(bz) + bottom_r)

		var hue: float = rng.randf_range(0.0, 0.1)
		branch_mesh.material_override = _get_coral_mat(
			Color.from_hsv(hue, rng.randf_range(0.5, 0.8), rng.randf_range(0.6, 0.9))
		)
		coral.add_child(branch_mesh)

	# Collision — cylinder around the cluster (deferred via metadata)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = maxf(max_radius, 0.3)
	shape.height = max_height
	col.shape = shape
	col.position.y = max_height / 2.0
	coral.set_meta("_deferred_col", col)

	return coral
