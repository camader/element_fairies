extends CharacterBody3D

## 3D fairy player controller with powers and fairy switching

@export var move_speed := 8.0
@export var rotation_speed := 10.0
@export var gravity := 20.0
@export var jump_force := 8.0

const CAMERA_DISTANCE := 10.0
const CAMERA_MIN_DISTANCE := 3.0
const CAMERA_MAX_DISTANCE := 14.0
const CAMERA_LOOK_HEIGHT := 1.5
const MOUSE_SENSITIVITY := 0.003
const PITCH_MIN := 0.15  # ~9 degrees (nearly level, looking at horizon)
const PITCH_MAX := 1.45  # ~83 degrees (looking steeply down at ground)

const FirePowerScript = preload("res://scripts/fairy_powers/fire_power.gd")
const EarthPowerScript = preload("res://scripts/fairy_powers/earth_power.gd")
const IcePowerScript = preload("res://scripts/fairy_powers/ice_power.gd")
const WaterPowerScript = preload("res://scripts/fairy_powers/water_power.gd")
const RainbowPowerScript = preload("res://scripts/fairy_powers/rainbow_power.gd")

@onready var model: Node3D = $Model
@onready var fairy_model: Node3D = $Model/FireFairyModel
@onready var anim_player: AnimationPlayer = $Model/FireFairyModel/AnimationPlayer
# Legacy references for material overrides — find meshes in GLB hierarchy
var fairy_mesh: MeshInstance3D
var wing_left: MeshInstance3D
var wing_right: MeshInstance3D

var camera_pivot: Node3D
var camera: Camera3D
var _reveal_timer := 0.0
const REVEAL_INTERVAL := 0.25
const FALL_THRESHOLD := -30.0
var _last_safe_position := Vector3.ZERO

# Camera orbit angles
var _camera_yaw := 0.0
var _camera_pitch := 0.85  # Start at ~49 degrees down — good overview of terrain

# Fairy powers
var _current_power: RefCounted
var _powers: Dictionary = {}

# Radar ping
const RADAR_COOLDOWN := 10.0
const RADAR_RADIUS := 40.0
const RADAR_EXPAND_TIME := 1.2
var _radar_cooldown_timer := 0.0

func _ready() -> void:
	_setup_model_refs()
	_setup_powers()
	_apply_fairy_appearance()
	if anim_player:
		anim_player.play("Idle")
	camera_pivot = Node3D.new()
	camera_pivot.set_as_top_level(true)
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.fov = 50.0
	camera_pivot.add_child(camera)
	# Camera sits at origin of pivot; pivot position/rotation does everything
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	# Initialize pivot position and rotation (same formula as _physics_process)
	var init_offset := _get_camera_offset()
	camera_pivot.global_position = global_position + Vector3(0, CAMERA_LOOK_HEIGHT, 0) + init_offset
	var init_fwd: Vector3 = (-init_offset).normalized()
	var init_yaw_angle: float = atan2(init_fwd.x, init_fwd.z)
	var init_pitch_angle: float = asin(clampf(-init_fwd.y, -1.0, 1.0))
	camera_pivot.basis = Basis((Quaternion(Vector3.UP, init_yaw_angle + PI) * Quaternion(Vector3.RIGHT, -init_pitch_angle)).normalized())

	GameState.fairy_switched.connect(_on_fairy_switched)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _get_camera_offset() -> Vector3:
	# Camera sits behind and above the player.
	# _camera_yaw defines "which way the player faces on screen"
	# Camera is placed opposite to that direction.
	var horizontal_dist: float = CAMERA_DISTANCE * cos(_camera_pitch)
	var vertical_dist: float = CAMERA_DISTANCE * sin(_camera_pitch)
	return Vector3(
		-sin(_camera_yaw) * horizontal_dist,
		vertical_dist,
		-cos(_camera_yaw) * horizontal_dist
	)

func _setup_model_refs() -> void:
	## Find mesh nodes inside the GLB model for material overrides.
	## Falls back to legacy primitive nodes if GLB is not present.
	if fairy_model:
		fairy_mesh = _find_child_by_type(fairy_model, "MeshInstance3D", "PuffBody")
		wing_left = _find_child_by_type(fairy_model, "MeshInstance3D", "WingLeft")
		wing_right = _find_child_by_type(fairy_model, "MeshInstance3D", "WingRight")
	else:
		fairy_mesh = model.get_node_or_null("FairyMesh") as MeshInstance3D
		wing_left = model.get_node_or_null("WingLeft") as MeshInstance3D
		wing_right = model.get_node_or_null("WingRight") as MeshInstance3D


func _find_child_by_type(parent: Node, type_name: String, name_hint: String) -> MeshInstance3D:
	## Search children recursively for a MeshInstance3D whose name contains hint.
	for child in parent.get_children():
		if child is MeshInstance3D and name_hint in child.name:
			return child
		var found := _find_child_by_type(child, type_name, name_hint)
		if found:
			return found
	return null


func play_animation(anim_name: String) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	var anim := anim_player.get_animation(anim_name)
	# Idle and Fly should loop, Cast and Celebrate play once then return to Idle
	if anim_name in ["Idle", "Fly"]:
		anim.loop_mode = Animation.LOOP_LINEAR
	else:
		anim.loop_mode = Animation.LOOP_NONE
	anim_player.play(anim_name)
	if anim_name not in ["Idle", "Fly"]:
		# After one-shot animations finish, return to Idle
		await anim_player.animation_finished
		play_animation("Idle")


func _setup_powers() -> void:
	_powers[GameState.Fairy.FIRE] = FirePowerScript.new()
	_powers[GameState.Fairy.EARTH] = EarthPowerScript.new()
	_powers[GameState.Fairy.ICE] = IcePowerScript.new()
	_powers[GameState.Fairy.WATER] = WaterPowerScript.new()
	_powers[GameState.Fairy.RAINBOW] = RainbowPowerScript.new()
	_current_power = _powers.get(GameState.active_fairy, _powers[GameState.Fairy.FIRE])

func _on_fairy_switched(_fairy: GameState.Fairy) -> void:
	_current_power = _powers.get(GameState.active_fairy, _powers[GameState.Fairy.FIRE])
	_apply_fairy_appearance()

func _apply_fairy_appearance() -> void:
	var fairy_color: Color = GameState.FAIRY_COLORS[GameState.active_fairy]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fairy_color
	mat.emission_enabled = true
	mat.emission = fairy_color * 0.3
	mat.emission_energy_multiplier = 0.5
	if fairy_mesh:
		fairy_mesh.material_override = mat

	var wing_mat := StandardMaterial3D.new()
	wing_mat.albedo_color = Color(fairy_color, 0.6)
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.emission_enabled = true
	wing_mat.emission = fairy_color * 0.5
	wing_mat.emission_energy_multiplier = 0.8
	if wing_left:
		wing_left.material_override = wing_mat
	if wing_right:
		wing_right.material_override = wing_mat

	var glow := model.get_node_or_null("GlowLight")
	if glow and glow is OmniLight3D:
		glow.light_color = fairy_color

func _physics_process(delta: float) -> void:
	if _current_power:
		_current_power.update(delta)

	if _radar_cooldown_timer > 0:
		_radar_cooldown_timer -= delta

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Input
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_back", "move_forward")

	# Camera-relative movement: forward = from camera toward player
	var cam_forward := Vector3(sin(_camera_yaw), 0, cos(_camera_yaw))
	var cam_right := Vector3(-cam_forward.z, 0, cam_forward.x)
	var move_dir := (cam_right * input_dir.x + cam_forward * input_dir.y).normalized()

	if move_dir.length() > 0.1:
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		var target_rot := atan2(move_dir.x, move_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rot, rotation_speed * delta)
		if anim_player and anim_player.current_animation != "Fly":
			play_animation("Fly")
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 8.0)
		if anim_player and anim_player.current_animation == "Fly":
			play_animation("Idle")
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 8.0)

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	move_and_slide()

	# Track safe position and respawn if fallen off the map
	if is_on_floor():
		_last_safe_position = global_position
	elif global_position.y < FALL_THRESHOLD:
		global_position = _last_safe_position if _last_safe_position != Vector3.ZERO else Vector3(0, 5, 0)
		velocity = Vector3.ZERO

	# Camera position: snap to target (no lerp = no jitter/slide)
	var look_target := global_position + Vector3(0, CAMERA_LOOK_HEIGHT, 0)
	var cam_offset := _get_camera_offset()
	camera_pivot.global_position = look_target + cam_offset

	# Camera looks toward player: tested formula is yaw+PI, -pitch
	var forward: Vector3 = (-cam_offset).normalized()
	var look_yaw: float = atan2(forward.x, forward.z)
	var look_pitch: float = asin(clampf(-forward.y, -1.0, 1.0))
	var yaw_quat := Quaternion(Vector3.UP, look_yaw + PI)
	var pitch_quat := Quaternion(Vector3.RIGHT, -look_pitch)
	var cam_quat: Quaternion = (yaw_quat * pitch_quat).normalized()
	camera_pivot.basis = Basis(cam_quat)

	# Reveal minimap
	_reveal_timer += delta
	if _reveal_timer >= REVEAL_INTERVAL:
		_reveal_timer = 0.0
		GameState.reveal_map_at(global_position)

func get_power_cooldown() -> float:
	if _current_power:
		return _current_power.get_cooldown_fraction()
	return 0.0

func get_camera_yaw() -> float:
	return _camera_yaw

func get_facing_yaw() -> float:
	return model.rotation.y

var _tab_held := false
var _mouse_in_window := true
var _want_capture := true  # Whether we want the mouse captured (when not in UI mode)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_ENTER:
			_mouse_in_window = true
			# Re-capture if tab is released and window is focused
			if _want_capture and get_window().has_focus():
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		NOTIFICATION_WM_MOUSE_EXIT:
			_mouse_in_window = false
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if _want_capture and _mouse_in_window:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	# Mouse camera rotation (only when captured)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_camera_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_camera_pitch += event.relative.y * MOUSE_SENSITIVITY
		_camera_pitch = clampf(_camera_pitch, PITCH_MIN, PITCH_MAX)

	# Tab hold = free mouse; release = recapture only if mouse is in window + focused
	if event is InputEventKey and event.keycode == KEY_TAB:
		if event.pressed and not event.is_echo():
			_tab_held = true
			_want_capture = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif not event.pressed:
			_tab_held = false
			_want_capture = true
			if _mouse_in_window and get_window().has_focus():
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func get_radar_cooldown_fraction() -> float:
	return clampf(_radar_cooldown_timer / RADAR_COOLDOWN, 0.0, 1.0)

func _activate_radar_ping() -> void:
	if _radar_cooldown_timer > 0:
		_spawn_power_fizzle()
		return
	_radar_cooldown_timer = RADAR_COOLDOWN
	_spawn_radar_ring()

func _spawn_radar_ring() -> void:
	# Expanding ring visual centered on player
	var ring_origin := global_position + Vector3(0, 0.5, 0)
	var fairy_color: Color = GameState.FAIRY_COLORS[GameState.active_fairy]

	# Ring mesh — a torus-like flat ring using a cylinder with thin height
	var ring_node := MeshInstance3D.new()
	ring_node.name = "RadarRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.8
	ring_mesh.outer_radius = 1.2
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 16
	ring_node.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(fairy_color, 0.6)
	ring_mat.emission_enabled = true
	ring_mat.emission = fairy_color
	ring_mat.emission_energy_multiplier = 2.0
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.no_depth_test = true
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_node.material_override = ring_mat
	ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	get_tree().current_scene.add_child(ring_node)
	ring_node.global_position = ring_origin

	# Find undiscovered clues within radar radius
	var found_clues: Array[Node] = []
	for clue in get_tree().get_nodes_in_group("clue"):
		if not clue is Node3D:
			continue
		if clue.clue_id in GameState.discovered_clues:
			continue
		var dist: float = ring_origin.distance_to(clue.global_position)
		if dist <= RADAR_RADIUS:
			found_clues.append(clue)

	# Animate ring expanding outward
	var tween := get_tree().create_tween()
	var target_scale: float = RADAR_RADIUS
	tween.tween_property(ring_node, "scale", Vector3(target_scale, target_scale, target_scale), RADAR_EXPAND_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, RADAR_EXPAND_TIME)
	tween.tween_callback(ring_node.queue_free)

	# Spawn highlight beacons at clue positions (timed to when the ring reaches them)
	# Also notify the minimap
	var minimap: Control = null
	var hud_node := get_tree().get_first_node_in_group("hud")
	if hud_node:
		minimap = hud_node.get_node_or_null("MinimapPanel/Minimap")

	for clue in found_clues:
		var dist: float = ring_origin.distance_to(clue.global_position)
		var trigger_time: float = (dist / RADAR_RADIUS) * RADAR_EXPAND_TIME
		_spawn_clue_beacon(clue.global_position, fairy_color, trigger_time)
		if minimap and minimap.has_method("add_radar_ping"):
			minimap.add_radar_ping(clue.global_position)

	# If nothing found, show a brief "nothing found" toast
	if found_clues.is_empty():
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_save_toast"):
			hud.show_save_toast("No clues nearby")

func _spawn_clue_beacon(pos: Vector3, color: Color, delay: float) -> void:
	## Spawns a glowing pillar/beacon at a clue's position after a delay,
	## similar to the landmark zone highlight but temporary.
	var beacon := Node3D.new()
	beacon.name = "ClueBeacon"
	get_tree().current_scene.add_child(beacon)
	beacon.global_position = pos

	# Start invisible, appear after delay
	beacon.visible = false

	# Pillar of light
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.8
	cyl.height = 15.0
	pillar.mesh = cyl
	pillar.position.y = cyl.height / 2.0
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(color, 0.3)
	pillar_mat.emission_enabled = true
	pillar_mat.emission = color
	pillar_mat.emission_energy_multiplier = 1.5
	pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar_mat.no_depth_test = true
	pillar_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pillar.material_override = pillar_mat
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(pillar)

	# Ground ring glow
	var ground_ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 2.5
	torus.rings = 24
	torus.ring_segments = 12
	ground_ring.mesh = torus
	ground_ring.position.y = 0.3
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(color, 0.5)
	ring_mat.emission_enabled = true
	ring_mat.emission = color
	ring_mat.emission_energy_multiplier = 2.0
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.no_depth_test = true
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground_ring.material_override = ring_mat
	ground_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(ground_ring)

	# Light
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 6.0
	light.position.y = 2.0
	beacon.add_child(light)

	# Tween: appear after delay, stay for 6 seconds, fade out over 2 seconds
	var tween := get_tree().create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func(): beacon.visible = true)
	tween.tween_interval(6.0)
	tween.tween_property(pillar_mat, "albedo_color:a", 0.0, 2.0)
	tween.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, 2.0)
	tween.parallel().tween_property(light, "light_energy", 0.0, 2.0)
	tween.tween_callback(beacon.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("radar_ping"):
		_activate_radar_ping()

	if event.is_action_pressed("use_power") and _current_power:
		if _current_power.can_use():
			play_animation("Cast")
			_spawn_power_effect()
			# Delay projectile spawn to match the cast animation swing (frame 14/36 @ 24fps)
			get_tree().create_timer(0.55).timeout.connect(func():
				_current_power.activate(self)
			)
		else:
			_spawn_power_fizzle()

	# Fairy switching — available whenever multiple fairies unlocked
	if GameState.unlocked_fairies.size() > 1:
		if event.is_action_pressed("switch_fairy_1") and GameState.Fairy.FIRE in GameState.unlocked_fairies:
			GameState.switch_fairy(GameState.Fairy.FIRE)
		elif event.is_action_pressed("switch_fairy_2") and GameState.Fairy.EARTH in GameState.unlocked_fairies:
			GameState.switch_fairy(GameState.Fairy.EARTH)
		elif event.is_action_pressed("switch_fairy_3") and GameState.Fairy.ICE in GameState.unlocked_fairies:
			GameState.switch_fairy(GameState.Fairy.ICE)
		elif event.is_action_pressed("switch_fairy_4") and GameState.Fairy.WATER in GameState.unlocked_fairies:
			GameState.switch_fairy(GameState.Fairy.WATER)
		elif event.is_action_pressed("switch_fairy_5") and GameState.Fairy.RAINBOW in GameState.unlocked_fairies:
			GameState.switch_fairy(GameState.Fairy.RAINBOW)

func _spawn_power_effect() -> void:
	# Flash the player glow light when projectile fires
	var fairy_color: Color = GameState.FAIRY_COLORS[GameState.active_fairy]
	var glow := model.get_node_or_null("GlowLight")
	if glow and glow is OmniLight3D:
		var orig_energy: float = glow.light_energy
		var orig_range: float = glow.omni_range
		glow.light_energy = 4.0
		glow.omni_range = 8.0
		glow.light_color = fairy_color
		var glow_tween := get_tree().create_tween()
		glow_tween.tween_property(glow, "light_energy", orig_energy, 0.4)
		glow_tween.parallel().tween_property(glow, "omni_range", orig_range, 0.4)

func _spawn_power_fizzle() -> void:
	# Small dim flash when power is on cooldown
	var glow := model.get_node_or_null("GlowLight")
	if glow and glow is OmniLight3D:
		var orig_energy: float = glow.light_energy
		glow.light_energy = 1.5
		var tween := get_tree().create_tween()
		tween.tween_property(glow, "light_energy", orig_energy, 0.2)

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
