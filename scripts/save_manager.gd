extends Node

## Autoload singleton for dynamic save/load system
## Supports unlimited named user saves + autosave slots

signal game_saved(save_id: String)
signal game_loaded(save_id: String)

const SAVE_VERSION := 2
const SAVE_DIR := "user://saves/"
const INDEX_PATH := "user://saves/index.json"
const MAX_AUTOSAVES := 3

var active_save_id: String = ""  # Currently active save ("" = none)
var _pending_load_data: Dictionary = {}

func _ready() -> void:
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

# ── Path helpers ──────────────────────────────────────────────────────────

func _get_save_path(save_id: String) -> String:
	return SAVE_DIR + save_id + ".json"

func _generate_save_id() -> String:
	## Generate a unique save ID based on timestamp
	return "save_%d" % Time.get_unix_time_from_system()

func _get_autosave_id(slot: int) -> String:
	return "autosave_%d" % slot

# ── Index management ──────────────────────────────────────────────────────

func _load_index() -> Dictionary:
	## Returns the save index: { "saves": [...], "last_save_id": "..." }
	if not FileAccess.file_exists(INDEX_PATH):
		return {"saves": [], "last_save_id": ""}
	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if not file:
		return {"saves": [], "last_save_id": ""}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {"saves": [], "last_save_id": ""}
	return json.data

func _save_index(index: Dictionary) -> void:
	var file := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(index, "\t"))

func _update_index_entry(save_id: String, display_name: String, is_autosave: bool) -> void:
	var index := _load_index()
	var saves: Array = index.get("saves", [])

	# Find and update existing entry, or add new
	var found := false
	for i in saves.size():
		if saves[i].get("id", "") == save_id:
			saves[i]["display_name"] = display_name
			saves[i]["is_autosave"] = is_autosave
			saves[i]["timestamp"] = Time.get_datetime_string_from_system()
			found = true
			break

	if not found:
		saves.append({
			"id": save_id,
			"display_name": display_name,
			"is_autosave": is_autosave,
			"timestamp": Time.get_datetime_string_from_system(),
		})

	index["saves"] = saves
	index["last_save_id"] = save_id
	_save_index(index)

func _remove_index_entry(save_id: String) -> void:
	var index := _load_index()
	var saves: Array = index.get("saves", [])
	var new_saves: Array = []
	for entry in saves:
		if entry.get("id", "") != save_id:
			new_saves.append(entry)
	index["saves"] = new_saves
	if index.get("last_save_id", "") == save_id:
		index["last_save_id"] = ""
	_save_index(index)

# ── Query saves ───────────────────────────────────────────────────────────

func get_all_saves() -> Array:
	## Returns array of save entries sorted by timestamp (newest first).
	## Each entry: { "id", "display_name", "is_autosave", "timestamp" }
	var index := _load_index()
	var saves: Array = index.get("saves", [])
	# Validate that files still exist
	var valid: Array = []
	for entry in saves:
		if FileAccess.file_exists(_get_save_path(entry.get("id", ""))):
			valid.append(entry)
	# Sort newest first
	valid.sort_custom(func(a, b): return a.get("timestamp", "") > b.get("timestamp", ""))
	return valid

func get_user_saves() -> Array:
	## Returns only non-autosave entries
	var all_saves := get_all_saves()
	var result: Array = []
	for entry in all_saves:
		if not entry.get("is_autosave", false):
			result.append(entry)
	return result

func get_autosaves() -> Array:
	## Returns only autosave entries
	var all_saves := get_all_saves()
	var result: Array = []
	for entry in all_saves:
		if entry.get("is_autosave", false):
			result.append(entry)
	return result

func has_any_save() -> bool:
	return get_all_saves().size() > 0

func has_save(save_id: String) -> bool:
	return FileAccess.file_exists(_get_save_path(save_id))

func get_last_save_id() -> String:
	var index := _load_index()
	var last_id: String = index.get("last_save_id", "")
	if last_id != "" and has_save(last_id):
		return last_id
	return ""

func get_save_info(save_id: String) -> Dictionary:
	## Returns game progress info for a save. Empty dict if not found.
	if not has_save(save_id):
		return {}
	var file := FileAccess.open(_get_save_path(save_id), FileAccess.READ)
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

# ── Save ──────────────────────────────────────────────────────────────────

func save_game(save_id: String = "", display_name: String = "") -> bool:
	## Save to a specific save_id. If empty, uses active_save_id.
	if save_id == "":
		save_id = active_save_id
	if save_id == "":
		return false

	var is_autosave := save_id.begins_with("autosave_")
	if display_name == "" and not is_autosave:
		display_name = save_id

	var player := _get_player()
	var player_pos := Vector3.ZERO
	var last_safe := Vector3.ZERO
	if player:
		player_pos = player.global_position
		last_safe = player._last_safe_position

	var cells_array: Array = []
	for cell: Vector2i in GameState.revealed_cells:
		cells_array.append([cell.x, cell.y])

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
			"display_name": display_name,
		},
	}

	var file := FileAccess.open(_get_save_path(save_id), FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open save file for %s" % save_id)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	active_save_id = save_id
	_update_index_entry(save_id, display_name, is_autosave)
	game_saved.emit(save_id)
	return true

func autosave() -> bool:
	## Rotate through autosave slots and save to the oldest one
	var autosaves := get_autosaves()
	var slot := 1

	if autosaves.size() < MAX_AUTOSAVES:
		# Fill empty slots first
		slot = autosaves.size() + 1
	else:
		# Overwrite the oldest autosave
		var oldest_time := ""
		var oldest_id := ""
		for entry in autosaves:
			var ts: String = entry.get("timestamp", "")
			if oldest_time == "" or ts < oldest_time:
				oldest_time = ts
				oldest_id = entry.get("id", "")
		# Extract slot number from id
		if oldest_id.begins_with("autosave_"):
			slot = int(oldest_id.replace("autosave_", ""))

	var save_id := _get_autosave_id(slot)
	return save_game(save_id, "Autosave %d" % slot)

# ── Load ──────────────────────────────────────────────────────────────────

func load_game(save_id: String) -> bool:
	if not has_save(save_id):
		return false

	var file := FileAccess.open(_get_save_path(save_id), FileAccess.READ)
	if not file:
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("SaveManager: Failed to parse save file %s" % save_id)
		return false

	var data: Dictionary = json.data
	var campaign: Dictionary = data.get("campaign", {})

	GameState.current_level = campaign.get("current_level", 1)

	GameState.unlocked_fairies.clear()
	for f_int: int in campaign.get("unlocked_fairies", [0]):
		GameState.unlocked_fairies.append(f_int as GameState.Fairy)

	GameState.active_fairy = campaign.get("active_fairy", 0) as GameState.Fairy
	GameState.selected_fairy = campaign.get("selected_fairy", 0) as GameState.Fairy

	var level_data := GameState.get_level_data()
	GameState.stars_required = level_data.get("stars_required", 3)

	GameState.reset()

	_pending_load_data = data
	active_save_id = save_id

	# Update last_save_id in index
	var index := _load_index()
	index["last_save_id"] = save_id
	_save_index(index)

	get_tree().change_scene_to_file("res://scenes/world.tscn")
	return true

func has_pending_load() -> bool:
	return not _pending_load_data.is_empty()

func restore_after_world_ready() -> void:
	if _pending_load_data.is_empty():
		return

	var data: Dictionary = _pending_load_data
	_pending_load_data = {}

	var level_progress: Dictionary = data.get("level_progress", {})
	var player_data: Dictionary = data.get("player", {})

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

	for cell_arr: Array in level_progress.get("revealed_cells", []):
		if cell_arr.size() >= 2:
			var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
			GameState.revealed_cells[cell] = true

	var player := _get_player()
	if player:
		var pos: Array = player_data.get("position", [0, 5, 0])
		var safe: Array = player_data.get("last_safe_position", pos)
		player.global_position = Vector3(pos[0], pos[1], pos[2])
		player._last_safe_position = Vector3(safe[0], safe[1], safe[2])

	GameState.star_collected.emit(GameState.star_pieces)
	if GameState.star_pieces >= GameState.stars_required:
		GameState.boss_unlocked.emit()

	game_loaded.emit(active_save_id)

# ── Delete ────────────────────────────────────────────────────────────────

func delete_save(save_id: String) -> void:
	var path := _get_save_path(save_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_remove_index_entry(save_id)
	if active_save_id == save_id:
		active_save_id = ""

# ── Helpers ───────────────────────────────────────────────────────────────

func _get_player() -> CharacterBody3D:
	var tree := get_tree()
	if tree:
		return tree.get_first_node_in_group("player") as CharacterBody3D
	return null
