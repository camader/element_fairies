extends Control

## Minimap that reveals as the player explores, with height contours and obstacle markers

const MINIMAP_CELL_SIZE := 4.0
const DRAW_RADIUS := 30
const CONTOUR_INTERVAL := 3.0  # World units between contour lines

var _player_color := Color(1.0, 1.0, 0.2)
var _landmark_color := Color(1.0, 0.5, 0.1)
var _boss_color := Color(1.0, 0.2, 0.2)
var _active_obstacle_color := Color(0.9, 0.2, 0.2, 0.7)
var _cleared_obstacle_color := Color(0.2, 0.9, 0.3, 0.6)
var _radar_ping_color := Color(0.4, 0.7, 1.0)

# Radar ping highlights: Array of { "world_pos": Vector3, "alpha": float }
var _radar_pings: Array[Dictionary] = []

# Cache heights for visible cells: Vector2i -> float
var _height_cache: Dictionary = {}
var _needs_redraw := true
var _redraw_timer := 0.0
const REDRAW_INTERVAL := 0.25  # Redraw at most 4 times per second
var _last_player_cell := Vector2i.ZERO

func _ready() -> void:
	GameState.map_revealed.connect(_on_map_updated)
	GameState.clue_discovered.connect(_on_clue_discovered)

func _get_biome_colors() -> Array:
	# Returns [low_color, high_color] for height gradient
	var biome_palettes = {
		"volcanic": [Color(0.2, 0.08, 0.05, 0.7), Color(0.5, 0.25, 0.1, 0.7)],
		"forest": [Color(0.1, 0.2, 0.08, 0.7), Color(0.25, 0.45, 0.2, 0.7)],
		"frozen": [Color(0.3, 0.35, 0.45, 0.7), Color(0.65, 0.75, 0.9, 0.7)],
		"ocean": [Color(0.1, 0.15, 0.35, 0.7), Color(0.4, 0.5, 0.3, 0.7)],
		"mixed": [Color(0.15, 0.12, 0.2, 0.7), Color(0.4, 0.35, 0.45, 0.7)],
	}
	var data: Dictionary = GameState.get_level_data()
	var biome: String = data["biome"]
	return biome_palettes.get(biome, [Color(0.2, 0.3, 0.2, 0.7), Color(0.4, 0.6, 0.3, 0.7)])

func _get_terrain_height(world_x: float, world_z: float) -> float:
	# Find terrain generator in the scene and sample height
	var terrain: Node = null
	var world_root: Node = get_tree().current_scene
	if world_root:
		terrain = world_root.get_node_or_null("TerrainGenerator")
	if terrain and terrain.has_method("get_height_at"):
		return terrain.get_height_at(Vector3(world_x, 0, world_z))
	return 0.0

func _cache_cell_height(cell: Vector2i) -> float:
	if _height_cache.has(cell):
		return _height_cache[cell]
	var world_x: float = cell.x * GameState.MAP_CELL_SIZE
	var world_z: float = cell.y * GameState.MAP_CELL_SIZE
	var h: float = _get_terrain_height(world_x, world_z)
	_height_cache[cell] = h
	return h

func add_radar_ping(world_pos: Vector3) -> void:
	_radar_pings.append({"world_pos": world_pos, "alpha": 1.0, "time_left": 8.0})
	_needs_redraw = true

func _on_map_updated(_cell: Vector2i) -> void:
	_needs_redraw = true

func _on_clue_discovered(_clue_id: String) -> void:
	_needs_redraw = true

func _process(delta: float) -> void:
	_redraw_timer += delta

	# Tick radar pings
	if not _radar_pings.is_empty():
		for i in range(_radar_pings.size() - 1, -1, -1):
			_radar_pings[i].time_left -= delta
			if _radar_pings[i].time_left <= 2.0:
				_radar_pings[i].alpha = maxf(_radar_pings[i].time_left / 2.0, 0.0)
			if _radar_pings[i].time_left <= 0.0:
				_radar_pings.remove_at(i)
		_needs_redraw = true

	if _redraw_timer < REDRAW_INTERVAL:
		return
	_redraw_timer = 0.0

	# Check if player has moved to a new cell
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var cell := GameState.world_to_cell(player.global_position)
		if cell != _last_player_cell:
			_last_player_cell = cell
			_needs_redraw = true

	if _needs_redraw:
		_needs_redraw = false
		queue_redraw()

func _draw() -> void:
	var map_center := size / 2.0
	var palette: Array = _get_biome_colors()
	var low_color: Color = palette[0]
	var high_color: Color = palette[1]
	var contour_color := Color(0.9, 0.9, 0.9, 0.25)

	var player := get_tree().get_first_node_in_group("player")
	var player_world_pos := Vector3.ZERO
	if player:
		player_world_pos = player.global_position
	var player_cell := GameState.world_to_cell(player_world_pos)

	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.05))

	# First pass: draw height-colored revealed cells
	# Track min/max for normalization
	var h_min := 999.0
	var h_max := -999.0
	var cell_heights: Dictionary = {}

	for dy in range(-DRAW_RADIUS, DRAW_RADIUS + 1):
		for dx in range(-DRAW_RADIUS, DRAW_RADIUS + 1):
			var cell := Vector2i(player_cell.x + dx, player_cell.y + dy)
			if GameState.is_cell_revealed(cell):
				var h: float = _cache_cell_height(cell)
				cell_heights[Vector2i(dx, dy)] = h
				if h < h_min:
					h_min = h
				if h > h_max:
					h_max = h

	var h_range: float = h_max - h_min
	if h_range < 0.5:
		h_range = 1.0

	# Draw cells colored by height
	for dy in range(-DRAW_RADIUS, DRAW_RADIUS + 1):
		for dx in range(-DRAW_RADIUS, DRAW_RADIUS + 1):
			var local := Vector2i(dx, dy)
			if not cell_heights.has(local):
				continue
			var h: float = cell_heights[local]
			var t: float = clampf((h - h_min) / h_range, 0.0, 1.0)
			var col: Color = low_color.lerp(high_color, t)

			var screen_pos := map_center + Vector2(-dx, -dy) * MINIMAP_CELL_SIZE
			draw_rect(Rect2(screen_pos, Vector2(MINIMAP_CELL_SIZE, MINIMAP_CELL_SIZE)), col)

	# Second pass: draw contour lines where height crosses contour intervals
	for dy in range(-DRAW_RADIUS, DRAW_RADIUS + 1):
		for dx in range(-DRAW_RADIUS, DRAW_RADIUS + 1):
			var local := Vector2i(dx, dy)
			if not cell_heights.has(local):
				continue
			var h: float = cell_heights[local]
			var contour_level: int = int(h / CONTOUR_INTERVAL)

			# Check right neighbor
			var right := Vector2i(dx + 1, dy)
			if cell_heights.has(right):
				var h_r: float = cell_heights[right]
				if int(h_r / CONTOUR_INTERVAL) != contour_level:
					var sx: float = map_center.x + -(dx + 1) * MINIMAP_CELL_SIZE
					var sy: float = map_center.y + -dy * MINIMAP_CELL_SIZE
					draw_line(Vector2(sx, sy), Vector2(sx, sy - MINIMAP_CELL_SIZE), contour_color, 1.0)

			# Check bottom neighbor
			var bottom := Vector2i(dx, dy + 1)
			if cell_heights.has(bottom):
				var h_b: float = cell_heights[bottom]
				if int(h_b / CONTOUR_INTERVAL) != contour_level:
					var sx: float = map_center.x + -dx * MINIMAP_CELL_SIZE
					var sy: float = map_center.y + -(dy + 1) * MINIMAP_CELL_SIZE
					draw_line(Vector2(sx, sy), Vector2(sx - MINIMAP_CELL_SIZE, sy), contour_color, 1.0)

	# Draw active obstacle markers (red)
	var obstacles: Array[Node] = get_tree().get_nodes_in_group("terrain_obstacle")
	for obs in obstacles:
		if obs is Node3D:
			var obs_cell := GameState.world_to_cell(obs.global_position)
			if GameState.is_cell_revealed(obs_cell):
				var offset := Vector2(obs_cell.x - player_cell.x, obs_cell.y - player_cell.y)
				if abs(offset.x) <= DRAW_RADIUS and abs(offset.y) <= DRAW_RADIUS:
					var screen_pos := map_center + Vector2(-offset.x, -offset.y) * MINIMAP_CELL_SIZE
					draw_rect(Rect2(screen_pos, Vector2(MINIMAP_CELL_SIZE, MINIMAP_CELL_SIZE)), _active_obstacle_color)

	# Draw cleared obstacle markers (green) — frozen pools, raised pools, etc.
	var cleared: Array[Node] = get_tree().get_nodes_in_group("cleared_obstacle")
	for obs in cleared:
		if obs is Node3D:
			var obs_cell := GameState.world_to_cell(obs.global_position)
			if GameState.is_cell_revealed(obs_cell):
				var offset := Vector2(obs_cell.x - player_cell.x, obs_cell.y - player_cell.y)
				if abs(offset.x) <= DRAW_RADIUS and abs(offset.y) <= DRAW_RADIUS:
					var screen_pos := map_center + Vector2(-offset.x, -offset.y) * MINIMAP_CELL_SIZE
					draw_rect(Rect2(screen_pos, Vector2(MINIMAP_CELL_SIZE, MINIMAP_CELL_SIZE)), _cleared_obstacle_color)

	# Draw landmark markers as approximate areas (only after corresponding clue discovered)
	var landmarks: Array[Node] = get_tree().get_nodes_in_group("landmarks")
	for lm in landmarks:
		if not "landmark_id" in lm:
			continue
		var lm_id: String = lm.landmark_id
		# Only show if the clue for this landmark has been found
		if lm_id not in GameState.discovered_pois and not lm.is_in_group("boss_landmark"):
			continue
		var lm_cell := GameState.world_to_cell(lm.global_position)
		var offset := Vector2(lm_cell.x - player_cell.x, lm_cell.y - player_cell.y)
		if abs(offset.x) <= DRAW_RADIUS and abs(offset.y) <= DRAW_RADIUS:
			var screen_pos := map_center + Vector2(-offset.x, -offset.y) * MINIMAP_CELL_SIZE
			var center := screen_pos + Vector2(MINIMAP_CELL_SIZE / 2, MINIMAP_CELL_SIZE / 2)
			var color := _landmark_color
			if lm_id in GameState.completed_landmarks:
				color = Color(0.8, 0.8, 0.2)
			if lm.is_in_group("boss_landmark"):
				color = _boss_color

			if lm_id in GameState.completed_landmarks:
				# Completed: show precise small dot
				draw_circle(center, 3.0, color)
			else:
				# Undiscovered location: large fuzzy approximate area
				draw_circle(center, 14.0, Color(color, 0.12))
				draw_circle(center, 9.0, Color(color, 0.18))
				draw_arc(center, 12.0, 0, TAU, 32, Color(color, 0.3), 1.5)

	# Draw radar ping highlights (fuzzy zones like undiscovered landmarks)
	for ping in _radar_pings:
		var ping_cell := GameState.world_to_cell(ping.world_pos)
		var ping_offset := Vector2(ping_cell.x - player_cell.x, ping_cell.y - player_cell.y)
		if abs(ping_offset.x) <= DRAW_RADIUS and abs(ping_offset.y) <= DRAW_RADIUS:
			var screen_pos := map_center + Vector2(-ping_offset.x, -ping_offset.y) * MINIMAP_CELL_SIZE
			var center := screen_pos + Vector2(MINIMAP_CELL_SIZE / 2, MINIMAP_CELL_SIZE / 2)
			var a: float = ping.alpha
			draw_circle(center, 14.0, Color(_radar_ping_color, 0.12 * a))
			draw_circle(center, 9.0, Color(_radar_ping_color, 0.2 * a))
			draw_arc(center, 12.0, 0, TAU, 32, Color(_radar_ping_color, 0.35 * a), 1.5)

	# Draw player dot and direction indicators
	var player_center := map_center + Vector2(MINIMAP_CELL_SIZE / 2, MINIMAP_CELL_SIZE / 2)
	draw_circle(player_center, 3.0, _player_color)

	if player and player.has_method("get_camera_yaw") and player.has_method("get_facing_yaw"):
		var cam_yaw: float = player.get_camera_yaw()
		var face_yaw: float = player.get_facing_yaw()

		# Camera facing indicator (white triangle, longer line)
		# Mirrored coords: negate both axes to match flipped minimap
		var cam_dir := Vector2(sin(cam_yaw), -cos(cam_yaw))
		var cam_tip := player_center - cam_dir * 12.0
		var cam_perp := Vector2(-cam_dir.y, cam_dir.x) * 3.0
		draw_line(player_center, cam_tip, Color(1.0, 1.0, 1.0, 0.6), 1.5)
		draw_polygon(
			PackedVector2Array([cam_tip, player_center + cam_perp - cam_dir * 4.0, player_center - cam_perp - cam_dir * 4.0]),
			PackedColorArray([Color(1.0, 1.0, 1.0, 0.35), Color(1.0, 1.0, 1.0, 0.35), Color(1.0, 1.0, 1.0, 0.35)])
		)

		# Player facing indicator (yellow arrow, shorter)
		var face_dir := Vector2(-sin(face_yaw), cos(face_yaw))
		var face_tip := player_center + face_dir * 8.0
		draw_line(player_center, face_tip, Color(1.0, 1.0, 0.2, 0.9), 2.0)
		# Arrowhead
		var arrow_perp := Vector2(-face_dir.y, face_dir.x) * 2.5
		draw_polygon(
			PackedVector2Array([face_tip, face_tip - face_dir * 4.0 + arrow_perp, face_tip - face_dir * 4.0 - arrow_perp]),
			PackedColorArray([_player_color, _player_color, _player_color])
		)

	# Border
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.3, 0.2), false, 2.0)
