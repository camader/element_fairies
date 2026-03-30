extends "res://scripts/fairy_powers/fairy_power_base.gd"

## Water fairy power: extinguishes fire walls, fills pools to raise platforms

func get_power_name() -> String:
	return "Tidal Wave"

func get_power_color() -> Color:
	return Color(0.2, 0.5, 1.0)

func _can_affect(obstacle: Node3D) -> bool:
	return obstacle.is_in_group("fire_wall") or obstacle.is_in_group("water_pool")

func _apply_effect(obstacle: Node3D, _player: CharacterBody3D) -> void:
	if obstacle.is_in_group("fire_wall"):
		_tween_remove(obstacle)
	elif obstacle.is_in_group("water_pool"):
		_raise_pool(obstacle)

func _raise_pool(pool: Node3D) -> void:
	var tween: Tween = pool.get_tree().create_tween()
	tween.tween_property(pool, "position:y", pool.position.y + 1.5, 0.6).set_ease(Tween.EASE_OUT)

	for child in pool.get_children():
		if child is MeshInstance3D and child.material_override:
			var mat: StandardMaterial3D = child.material_override
			mat.albedo_color = Color(0.2, 0.5, 1.0, 0.9)
			mat.emission_energy_multiplier = 0.8

	pool.remove_from_group("water_pool")
	pool.remove_from_group("terrain_obstacle")
	pool.add_to_group("cleared_obstacle")
