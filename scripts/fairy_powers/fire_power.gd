extends "res://scripts/fairy_powers/fairy_power_base.gd"

## Fire fairy power: melts ice blocks, evaporates water pools

func get_power_name() -> String:
	return "Flame Burst"

func get_power_color() -> Color:
	return Color(1.0, 0.4, 0.0)

func _can_affect(obstacle: Node3D) -> bool:
	return obstacle.is_in_group("ice_block") or obstacle.is_in_group("water_pool")

func _apply_effect(obstacle: Node3D, _player: CharacterBody3D) -> void:
	if obstacle.is_in_group("ice_block"):
		for child in obstacle.get_children():
			if child is MeshInstance3D and child.material_override:
				var tween: Tween = obstacle.get_tree().create_tween()
				tween.tween_property(child.material_override, "albedo_color:a", 0.0, 0.8)
		_tween_remove(obstacle)

	elif obstacle.is_in_group("water_pool"):
		# Check if this pool is hiding a clue
		if obstacle.has_meta("hidden_clue_id"):
			var clue_id: String = obstacle.get_meta("hidden_clue_id")
			for clue in obstacle.get_tree().get_nodes_in_group("clue"):
				if clue.has_method("reveal") and clue.clue_id == clue_id:
					clue.reveal()
					break
		# Steam burst effect for terrain pools
		if obstacle.is_in_group("terrain_pool"):
			_spawn_steam_burst(obstacle)
		_tween_remove(obstacle)

func _spawn_steam_burst(pool: Node3D) -> void:
	for i in range(5):
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.6
		sphere.height = 1.2
		puff.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.9, 0.95, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		puff.material_override = mat
		pool.get_tree().current_scene.add_child(puff)
		puff.global_position = pool.global_position + Vector3(
			randf_range(-1.5, 1.5), 0.5 + i * 0.3, randf_range(-1.5, 1.5)
		)
		var tween: Tween = pool.get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(puff, "position:y", puff.position.y + 4.0, 1.0 + i * 0.15)
		tween.tween_property(puff, "scale", Vector3(2.5, 2.5, 2.5), 1.0 + i * 0.15)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.8 + i * 0.1).set_delay(0.2)
		tween.set_parallel(false)
		tween.tween_callback(puff.queue_free)
