extends "res://scripts/fairy_powers/fairy_power_base.gd"

## Earth fairy power: spawns ramps over gaps, extinguishes fire walls

func get_power_name() -> String:
	return "Stone Bridge"

func get_power_color() -> Color:
	return Color(0.5, 0.7, 0.2)

func _can_affect(obstacle: Node3D) -> bool:
	return obstacle.is_in_group("gap") or obstacle.is_in_group("lava_gap") or obstacle.is_in_group("fire_wall")

func _apply_effect(obstacle: Node3D, _player: CharacterBody3D) -> void:
	if obstacle.is_in_group("gap") or obstacle.is_in_group("lava_gap"):
		_spawn_ramp(obstacle)
		_tween_remove(obstacle)
	elif obstacle.is_in_group("fire_wall"):
		_tween_remove(obstacle)

func _spawn_ramp(gap: Node3D) -> void:
	var ramp := StaticBody3D.new()
	ramp.position = gap.global_position

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 0.5, 2.0)
	mesh.mesh = box
	mesh.position.y = 0.25

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.35, 0.25)
	mat.roughness = 1.0
	mesh.material_override = mat
	ramp.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 0.5, 2.0)
	col.shape = shape
	col.position.y = 0.25
	ramp.add_child(col)

	ramp.scale = Vector3.ZERO
	gap.get_tree().current_scene.add_child(ramp)
	var tween: Tween = gap.get_tree().create_tween()
	tween.tween_property(ramp, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT)
