extends "res://scripts/fairy_powers/fairy_power_base.gd"

## Ice fairy power: builds ice bridges over gaps, freezes water surfaces

func get_power_name() -> String:
	return "Frost Bridge"

func get_power_color() -> Color:
	return Color(0.6, 0.9, 1.0)

func _can_affect(obstacle: Node3D) -> bool:
	return obstacle.is_in_group("gap") or obstacle.is_in_group("water_pool")

func _apply_effect(obstacle: Node3D, _player: CharacterBody3D) -> void:
	if obstacle.is_in_group("gap"):
		_spawn_ice_bridge(obstacle)
		_tween_remove(obstacle)
	elif obstacle.is_in_group("water_pool"):
		_freeze_pool(obstacle)

func _spawn_ice_bridge(gap: Node3D) -> void:
	var bridge := StaticBody3D.new()
	bridge.position = gap.global_position

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 0.3, 2.0)
	mesh.mesh = box
	mesh.position.y = 0.15

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.3
	mat.roughness = 0.05
	mesh.material_override = mat
	bridge.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 0.3, 2.0)
	col.shape = shape
	col.position.y = 0.15
	bridge.add_child(col)

	bridge.scale = Vector3.ZERO
	gap.get_tree().current_scene.add_child(bridge)
	var tween: Tween = gap.get_tree().create_tween()
	tween.tween_property(bridge, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)

func _freeze_pool(pool: Node3D) -> void:
	for child in pool.get_children():
		if child is MeshInstance3D and child.material_override:
			var mat: StandardMaterial3D = child.material_override
			mat.albedo_color = Color(0.7, 0.9, 1.0, 0.9)
			mat.emission = Color(0.5, 0.7, 1.0)

	pool.remove_from_group("water_pool")
	pool.remove_from_group("terrain_obstacle")
	pool.add_to_group("frozen_pool")
	pool.add_to_group("cleared_obstacle")
