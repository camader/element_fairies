extends Node3D

## Projectile fired by fairy powers — flies forward, applies effect on obstacle hit

var direction: Vector3
var speed := 20.0
var max_range := 8.0
var hit_radius := 1.5
var power_color: Color
var power: RefCounted
var source_player: CharacterBody3D

var _traveled := 0.0
var _hit_area: Area3D

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(power_color, 0.9)
	mat.emission_enabled = true
	mat.emission = power_color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mesh.material_override = mat
	add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = power_color
	light.light_energy = 2.0
	light.omni_range = 3.0
	add_child(light)

	# Use Area3D for collision detection instead of per-frame group search
	_hit_area = Area3D.new()
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = hit_radius
	col.shape = shape
	_hit_area.add_child(col)
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = 1  # Detect StaticBody3D obstacles on layer 1
	_hit_area.body_entered.connect(_on_body_entered)
	add_child(_hit_area)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("terrain_obstacle"):
		if power._can_affect(body):
			power._apply_effect(body, source_player)
			_spawn_impact()
			queue_free()

func _physics_process(delta: float) -> void:
	var step: float = speed * delta
	global_position += direction * step
	_traveled += step

	if _traveled >= max_range:
		_spawn_fizzle()
		queue_free()

func _spawn_impact() -> void:
	var burst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	burst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(power_color, 0.8)
	mat.emission_enabled = true
	mat.emission = power_color
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	burst.material_override = mat
	var impact_pos := global_position
	get_tree().current_scene.add_child(burst)
	burst.global_position = impact_pos

	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector3(3, 3, 3), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.set_parallel(false)
	tween.tween_callback(burst.queue_free)

func _spawn_fizzle() -> void:
	var puff := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	puff.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(power_color, 0.4)
	mat.emission_enabled = true
	mat.emission = power_color
	mat.emission_energy_multiplier = 1.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material_override = mat
	var fizzle_pos := global_position
	get_tree().current_scene.add_child(puff)
	puff.global_position = fizzle_pos

	var tween := get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(puff.queue_free)
