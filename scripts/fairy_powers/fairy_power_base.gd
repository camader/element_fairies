extends RefCounted

## Base class for fairy power interactions with terrain obstacles

const ProjectileScript = preload("res://scripts/fairy_powers/fairy_projectile.gd")

var power_range := 8.0
var cooldown := 0.5
var _cooldown_timer := 0.0

func get_power_name() -> String:
	return "None"

func get_power_color() -> Color:
	return Color.WHITE

func can_use() -> bool:
	return _cooldown_timer <= 0.0

func update(delta: float) -> void:
	if _cooldown_timer > 0:
		_cooldown_timer -= delta

func get_cooldown_fraction() -> float:
	if cooldown <= 0:
		return 0.0
	return clampf(_cooldown_timer / cooldown, 0.0, 1.0)

func activate(player: CharacterBody3D) -> bool:
	if not can_use():
		return false

	_spawn_projectile(player)
	_cooldown_timer = cooldown
	return true

func _spawn_projectile(player: CharacterBody3D) -> void:
	var forward := Vector3(sin(player.model.rotation.y), 0, cos(player.model.rotation.y))
	var projectile := Node3D.new()
	projectile.set_script(ProjectileScript)
	projectile.direction = forward
	projectile.speed = 20.0
	projectile.max_range = power_range
	projectile.power_color = get_power_color()
	projectile.power = self
	projectile.source_player = player
	player.get_tree().current_scene.add_child(projectile)
	projectile.global_position = player.global_position + Vector3(0, 1.0, 0) + forward * 0.5

func _can_affect(_obstacle: Node3D) -> bool:
	return false

func _apply_effect(_obstacle: Node3D, _player: CharacterBody3D) -> void:
	pass

func _tween_remove(obstacle: Node3D) -> void:
	var tween: Tween = obstacle.get_tree().create_tween()
	tween.tween_property(obstacle, "scale", Vector3(0.001, 0.001, 0.001), 0.5)
	tween.tween_callback(obstacle.queue_free)

	for child in obstacle.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
