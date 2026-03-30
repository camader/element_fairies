extends Node3D

## A single chunk of procedural terrain

const CHUNK_SIZE := 16.0
const CHUNK_VERTS := 17  # vertices per side (16 quads + 1)
const VERT_SPACING := CHUNK_SIZE / 16.0

var chunk_coord: Vector2i = Vector2i.ZERO
var _mesh_instance: MeshInstance3D
var _static_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _height_data: PackedFloat32Array  # CHUNK_VERTS * CHUNK_VERTS heights
var _region_data: PackedFloat32Array  # per-vertex region_factor (0=plains, 1=hills)
var _path_data: PackedFloat32Array    # per-vertex path_factor (0=on path, 1=off path)

func generate(noise: FastNoiseLite, biome: RefCounted, coord: Vector2i, cliff_noise: FastNoiseLite = null, region_noise: FastNoiseLite = null, path_noise: FastNoiseLite = null) -> void:
	chunk_coord = coord
	position = Vector3(coord.x * CHUNK_SIZE, 0, coord.y * CHUNK_SIZE)

	_generate_height_data(noise, biome, cliff_noise, region_noise, path_noise)
	_build_mesh(biome)
	_build_collision()

func _generate_height_data(noise: FastNoiseLite, biome: RefCounted, cliff_noise: FastNoiseLite, region_noise: FastNoiseLite, path_noise: FastNoiseLite) -> void:
	var vert_count: int = CHUNK_VERTS * CHUNK_VERTS
	_height_data = PackedFloat32Array()
	_height_data.resize(vert_count)
	_region_data = PackedFloat32Array()
	_region_data.resize(vert_count)
	_path_data = PackedFloat32Array()
	_path_data.resize(vert_count)

	var world_offset := Vector2(chunk_coord.x * CHUNK_SIZE, chunk_coord.y * CHUNK_SIZE)

	for z in range(CHUNK_VERTS):
		for x in range(CHUNK_VERTS):
			var idx: int = z * CHUNK_VERTS + x
			var world_x: float = world_offset.x + x * VERT_SPACING
			var world_z: float = world_offset.y + z * VERT_SPACING

			# Base terrain height
			var h: float = noise.get_noise_2d(world_x, world_z) * biome.noise_amplitude

			# Region factor: 0 = plains, 1 = hills
			var region_factor: float = 0.5
			if region_noise:
				var rv: float = region_noise.get_noise_2d(world_x, world_z)
				region_factor = _smoothstep_range(rv, biome.region_threshold, biome.region_blend_range)

			# Modulate amplitude by region
			var amp_scale: float = lerpf(biome.plains_amplitude_scale, biome.hills_amplitude_scale, region_factor)
			h *= amp_scale

			# Path factor: 0 = on path, 1 = off path
			var path_factor: float = 1.0
			if path_noise:
				var pv: float = absf(path_noise.get_noise_2d(world_x, world_z))
				path_factor = _smoothstep_range(pv, biome.path_width, biome.path_width * 0.5)

			# Flatten paths through hill regions
			var path_flatten: float = (1.0 - path_factor) * region_factor * biome.path_depth
			h = lerpf(h, 0.0, path_flatten)

			# Cliff ridges: only in hills and off paths
			if cliff_noise:
				var cliff_val: float = cliff_noise.get_noise_2d(world_x, world_z)
				if cliff_val > 0.3:
					var cliff_mask: float = region_factor * path_factor
					h += (cliff_val - 0.3) * 25.0 * cliff_mask

			_height_data[idx] = h
			_region_data[idx] = region_factor
			_path_data[idx] = path_factor

## Compute smoothstep: returns 0 when value < threshold, 1 when value > threshold + blend_range
static func _smoothstep_range(value: float, threshold: float, blend_range: float) -> float:
	if blend_range <= 0.0:
		return 1.0 if value >= threshold else 0.0
	var t: float = clampf((value - threshold) / blend_range, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func get_height_at_local(local_x: float, local_z: float) -> float:
	var gx: float = clampf(local_x / VERT_SPACING, 0.0, 15.99)
	var gz: float = clampf(local_z / VERT_SPACING, 0.0, 15.99)
	var ix: int = int(gx)
	var iz: int = int(gz)
	var fx: float = gx - ix
	var fz: float = gz - iz
	var h00: float = _height_data[iz * CHUNK_VERTS + ix]
	var h10: float = _height_data[iz * CHUNK_VERTS + min(ix + 1, CHUNK_VERTS - 1)]
	var h01: float = _height_data[min(iz + 1, CHUNK_VERTS - 1) * CHUNK_VERTS + ix]
	var h11: float = _height_data[min(iz + 1, CHUNK_VERTS - 1) * CHUNK_VERTS + min(ix + 1, CHUNK_VERTS - 1)]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)

func _build_mesh(biome: RefCounted) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var path_dirt_color := Color(0.45, 0.35, 0.2)

	for z in range(CHUNK_VERTS - 1):
		for x in range(CHUNK_VERTS - 1):
			var i00: int = z * CHUNK_VERTS + x
			var i10: int = z * CHUNK_VERTS + (x + 1)
			var i01: int = (z + 1) * CHUNK_VERTS + x
			var i11: int = (z + 1) * CHUNK_VERTS + (x + 1)

			var v00 := Vector3(x * VERT_SPACING, _height_data[i00], z * VERT_SPACING)
			var v10 := Vector3((x + 1) * VERT_SPACING, _height_data[i10], z * VERT_SPACING)
			var v01 := Vector3(x * VERT_SPACING, _height_data[i01], (z + 1) * VERT_SPACING)
			var v11 := Vector3((x + 1) * VERT_SPACING, _height_data[i11], (z + 1) * VERT_SPACING)

			# Triangle 1: v00, v10, v01
			var n1: Vector3 = (v10 - v00).cross(v01 - v00).normalized()
			var steepness1: float = 1.0 - abs(n1.y)
			var cliff_color := Color(0.25, 0.2, 0.18)

			for vi_idx in [i00, i10, i01]:
				var vi_pos: Vector3
				match vi_idx:
					i00: vi_pos = v00
					i10: vi_pos = v10
					i01: vi_pos = v01
				var col: Color = _vertex_color(vi_idx, vi_pos.y, biome, steepness1, cliff_color, path_dirt_color)
				st.set_normal(n1)
				st.set_color(col)
				st.add_vertex(vi_pos)

			# Triangle 2: v10, v11, v01
			var n2: Vector3 = (v11 - v10).cross(v01 - v10).normalized()
			var steepness2: float = 1.0 - abs(n2.y)

			for vi_idx in [i10, i11, i01]:
				var vi_pos: Vector3
				match vi_idx:
					i10: vi_pos = v10
					i11: vi_pos = v11
					i01: vi_pos = v01
				var col: Color = _vertex_color(vi_idx, vi_pos.y, biome, steepness2, cliff_color, path_dirt_color)
				st.set_normal(n2)
				st.set_color(col)
				st.add_vertex(vi_pos)

	var mesh: ArrayMesh = st.commit()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

func _vertex_color(idx: int, height: float, biome: RefCounted, steepness: float, cliff_color: Color, path_dirt_color: Color) -> Color:
	var norm_h: float = clampf((height / biome.noise_amplitude + 1.0) / 2.0, 0.0, 1.0)
	var col: Color = biome.ground_color.lerp(biome.base_color, norm_h)

	var region_factor: float = _region_data[idx]
	var path_factor: float = _path_data[idx]

	# Plains: bias toward ground_color (flatter, more uniform)
	if region_factor < 0.3:
		col = col.lerp(biome.ground_color, (1.0 - region_factor / 0.3) * 0.4)

	# Paths through hills: blend toward packed-dirt tone
	if region_factor > 0.3 and path_factor < 0.5:
		var path_blend: float = (1.0 - path_factor / 0.5) * region_factor
		col = col.lerp(path_dirt_color, path_blend * 0.6)

	# Hills: darken steep faces to look like rock cliffs
	if steepness > 0.5:
		var cliff_blend: float = clampf((steepness - 0.5) * 2.0, 0.0, 1.0) * region_factor
		col = col.lerp(cliff_color, cliff_blend)

	return col

func _build_collision() -> void:
	var faces := PackedVector3Array()
	for z in range(CHUNK_VERTS - 1):
		for x in range(CHUNK_VERTS - 1):
			var v00 := Vector3(x * VERT_SPACING, _height_data[z * CHUNK_VERTS + x], z * VERT_SPACING)
			var v10 := Vector3((x + 1) * VERT_SPACING, _height_data[z * CHUNK_VERTS + (x + 1)], z * VERT_SPACING)
			var v01 := Vector3(x * VERT_SPACING, _height_data[(z + 1) * CHUNK_VERTS + x], (z + 1) * VERT_SPACING)
			var v11 := Vector3((x + 1) * VERT_SPACING, _height_data[(z + 1) * CHUNK_VERTS + (x + 1)], (z + 1) * VERT_SPACING)
			faces.append(v00)
			faces.append(v10)
			faces.append(v01)
			faces.append(v10)
			faces.append(v11)
			faces.append(v01)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)

	_static_body = StaticBody3D.new()
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = shape
	_static_body.add_child(_collision_shape)
	add_child(_static_body)
