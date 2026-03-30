extends "res://scripts/fairy_powers/fairy_power_base.gd"

## Rainbow fairy power: activates teleport pads (linked pairs)

func get_power_name() -> String:
	return "Prismatic Warp"

func get_power_color() -> Color:
	return Color(0.9, 0.5, 1.0)

func _can_affect(obstacle: Node3D) -> bool:
	return obstacle.is_in_group("teleport_pad")

func _apply_effect(obstacle: Node3D, player: CharacterBody3D) -> void:
	var pads: Array[Node] = player.get_tree().get_nodes_in_group("teleport_pad")
	var best_pad: Node3D = null
	var best_dist := INF

	for pad in pads:
		if pad == obstacle:
			continue
		if pad is Node3D:
			var d: float = obstacle.global_position.distance_to(pad.global_position)
			if d < best_dist:
				best_dist = d
				best_pad = pad

	if best_pad:
		var target_pos: Vector3 = best_pad.global_position + Vector3(0, 1.5, 0)
		_flash_effect(obstacle)
		player.global_position = target_pos
		_flash_effect(best_pad)

func _flash_effect(pad: Node3D) -> void:
	for child in pad.get_children():
		if child is MeshInstance3D and child.material_override:
			var mat: StandardMaterial3D = child.material_override
			var original_energy: float = mat.emission_energy_multiplier
			mat.emission_energy_multiplier = 5.0
			var tween: Tween = pad.get_tree().create_tween()
			tween.tween_property(mat, "emission_energy_multiplier", original_energy, 0.5)
