extends Node

## Autoload singleton for multi-slot save/load system

signal game_saved(slot: int)
signal game_loaded(slot: int)

const SAVE_VERSION := 1
const MAX_SLOTS := 3
const META_PATH := "user://save_meta.json"

var active_slot: int = -1  # Currently active save slot (-1 = none)
var _pending_load_data: Dictionary = {}  # Data to restore after world loads

func _get_save_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

# ── Slot info ──────────────────────────────────────────────────────────────

func has_any_save() -> bool:
	for i in range(1, MAX_SLOTS + 1):
		if has_save(i):
			return true
	return false

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))

func get_last_slot() -> int:
	if not FileAccess.file_exists(META_PATH):
		return -1
	var file := FileAccess.open(META_PATH, FileAccess.READ)
	if not file:
		return -1
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return -1
	var data: Dictionary = json.data
	var slot: int = data.get("last_slot", -1)
	if slot > 0 and has_save(slot):
		return slot
	return -1

func _save_meta() -> void:
	var file := FileAccess.open(META_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"last_slot": active_slot}))

func get_slot_info(slot: int) -> Dictionary:
	## Returns summary info for a slot (for slot picker UI). Empty dict if no save.
	if not has_save(slot):
		return {}
	var file := FileAccess.open(_get_save_path(slot), FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data: Dictionary = json.data
	var campaign: Dictionary = data.get("campaign", {})
	var meta: Dictionary = data.get("metadata", {})
	var level_progress: Dictionary = data.get("level_progress", {})
	return {
		"level": campaign.get("current_level", 1),
		"stars": level_progress.get("star_pieces", 0),
		"timestamp": meta.get("timestamp", ""),
		"fairy": campaign.get("active_fairy", 0),
	}

# ── Save ───────────────────────────────────────────────────────────────────

func save_game(slot: int = -1) -> bool:
	if slot < 1:
		slot = active_slot
	if slot < 1:
		return false

	var player := _get_player()
	var player_pos := Vector3.ZERO
	var last_safe := Vector3.ZERO
	if player:
		player_pos = player.global_position
		last_safe = player._last_safe_position

	# Serialize revealed_cells: Dictionary[Vector2i, bool] -> Array[[x, y]]
	var cells_array: Array = []
	for cell: Vector2i in GameState.revealed_cells:
		cells_array.append([cell.x, cell.y])

	# Serialize unlocked_fairies as int array
	var fairies_array: Array[int] = []
	for f: GameState.Fairy in GameState.unlocked_fairies:
		fairies_array.append(int(f))

	var save_data := {
		"campaign": {
			"current_level": GameState.current_level,
			"unlocked_fairies": fairies_array,
			"active_fairy": int(GameState.active_fairy),
			"selected_fairy": int(GameState.selected_fairy),
		},
		"level_progress": {
			"star_pieces": GameState.star_pieces,
			"stars_required": GameState.stars_required,
			"boss_defeated": GameState.boss_defeated,
			"completed_landmarks": GameState.completed_landmarks.duplicate(),
			"discovered_clues": GameState.discovered_clues.duplicate(),
			"discovered_pois": GameState.discovered_pois.duplicate(),
			"revealed_cells": cells_array,
		},
		"player": {
			"position": [player_pos.x, player_pos.y, player_pos.z],
			"last_safe_position": [last_safe.x, last_safe.y, last_safe.z],
		},
		"metadata": {
			"save_version": SAVE_VERSION,
			"timestamp": Time.get_datetime_string_from_system(),
		},
	}

	var file := FileAccess.open(_get_save_path(slot), FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open save file for slot %d" % slot)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	active_slot = slot
	_save_meta()
	game_saved.emit(slot)
	return true

# ── Load ───────────────────────────────────────────────────────────────────

func load_game(slot: int) -> bool:
	if not has_save(slot):
		return false

	var file := FileAccess.open(_get_save_path(slot), FileAccess.READ)
	if not file:
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("SaveManager: Failed to parse save file for slot %d" % slot)
		return false

	var data: Dictionary = json.data
	var campaign: Dictionary = data.get("campaign", {})
	var level_progress: Dictionary = data.get("level_progress", {})

	# Restore campaign state
	GameState.current_level = campaign.get("current_level", 1)

	GameState.unlocked_fairies.clear()
	for f_int: int in campaign.get("unlocked_fairies", [0]):
		GameState.unlocked_fairies.append(f_int as GameState.Fairy)

	GameState.active_fairy = campaign.get("active_fairy", 0) as GameState.Fairy
	GameState.selected_fairy = campaign.get("selected_fairy", 0) as GameState.Fairy

	# Set stars_required from level data before restoring progress
	var level_data := GameState.get_level_data()
	GameState.stars_required = level_data.get("stars_required", 3)

	# Reset level state (will be restored after world loads)
	GameState.reset()

	# Store data to apply after world scene is ready
	_pending_load_data = data
	active_slot = slot
	_save_meta()

	# Change to world scene — restoration happens in restore_after_world_ready()
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	return true

func has_pending_load() -> bool:
	return not _pending_load_data.is_empty()

func restore_after_world_ready() -> void:
	## Called by world.gd after terrain is generated. Restores level progress and player position.
	if _pending_load_data.is_empty():
		return

	var data: Dictionary = _pending_load_data
	_pending_load_data = {}

	var level_progress: Dictionary = data.get("level_progress", {})
	var player_data: Dictionary = data.get("player", {})

	# Restore level progress
	GameState.star_pieces = level_progress.get("star_pieces", 0)
	GameState.boss_defeated = level_progress.get("boss_defeated", false)

	for lm_id: String in level_progress.get("completed_landmarks", []):
		if lm_id not in GameState.completed_landmarks:
			GameState.completed_landmarks.append(lm_id)

	for clue_id: String in level_progress.get("discovered_clues", []):
		if clue_id not in GameState.discovered_clues:
			GameState.discovered_clues.append(clue_id)

	for poi_id: String in level_progress.get("discovered_pois", []):
		if poi_id not in GameState.discovered_pois:
			GameState.discovered_pois.append(poi_id)

	# Restore revealed cells
	for cell_arr: Array in level_progress.get("revealed_cells", []):
		if cell_arr.size() >= 2:
			var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
			GameState.revealed_cells[cell] = true

	# Restore player position
	var player := _get_player()
	if player:
		var pos: Array = player_data.get("position", [0, 5, 0])
		var safe: Array = player_data.get("last_safe_position", pos)
		player.global_position = Vector3(pos[0], pos[1], pos[2])
		player._last_safe_position = Vector3(safe[0], safe[1], safe[2])

	# Re-emit signals so UI updates
	GameState.star_collected.emit(GameState.star_pieces)
	if GameState.star_pieces >= GameState.stars_required:
		GameState.boss_unlocked.emit()

	game_loaded.emit(active_slot)

# ── Delete ─────────────────────────────────────────────────────────────────

func delete_save(slot: int) -> void:
	var path := _get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if active_slot == slot:
		active_slot = -1
		_save_meta()

# ── Helpers ────────────────────────────────────────────────────────────────

func _get_player() -> CharacterBody3D:
	var tree := get_tree()
	if tree:
		return tree.get_first_node_in_group("player") as CharacterBody3D
	return null
