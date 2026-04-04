extends Node

## Autoload singleton tracking all game progress

signal star_collected(total: int)
signal landmark_completed(landmark_id: String)
signal clue_discovered(clue_id: String)
signal map_revealed(cell: Vector2i)
signal boss_unlocked
signal fairy_switched(fairy: Fairy)

# Character data
enum Fairy { FIRE, WATER, EARTH, ICE, RAINBOW }

const FAIRY_NAMES := {
	Fairy.FIRE: "Fire Fairy",
	Fairy.WATER: "Water Fairy",
	Fairy.EARTH: "Earth Fairy",
	Fairy.ICE: "Ice Fairy",
	Fairy.RAINBOW: "Rainbow Fairy",
}

const FAIRY_COLORS := {
	Fairy.FIRE: Color(1.0, 0.3, 0.1),
	Fairy.WATER: Color(0.2, 0.5, 1.0),
	Fairy.EARTH: Color(0.4, 0.7, 0.2),
	Fairy.ICE: Color(0.6, 0.9, 1.0),
	Fairy.RAINBOW: Color(0.9, 0.5, 1.0),
}

# Campaign state
var current_level: int = 1
var unlocked_fairies: Array[Fairy] = [Fairy.FIRE]
var active_fairy: Fairy = Fairy.FIRE

# Game progress
var selected_fairy: Fairy = Fairy.FIRE
var star_pieces: int = 0
var stars_required: int = 3
var completed_landmarks: Array[String] = []
var discovered_clues: Array[String] = []
var discovered_pois: Array[String] = []
var boss_defeated: bool = false

# Minimap fog - tracks which grid cells have been revealed
var revealed_cells: Dictionary = {}

# Minimap grid settings
const MAP_CELL_SIZE := 4.0
const REVEAL_RADIUS := 3

const MINI_GAME_TYPES := [
	"spot_the_difference",
	"jigsaw_puzzle",
	"maze_puzzle",
	"word_search",
	"memory_match",
	"simon_says",
	"pattern_completion",
	"find_the_fairy",
	"sliding_puzzle",
	"pipe_puzzle",
	"tangram",
	"hangman",
	"scrambled_letters",
]

# Level configuration
const LEVEL_DATA := {
	1: {
		"play_as": Fairy.FIRE,
		"rescue": Fairy.EARTH,
		"biome": "frozen",
		"biome_name": "Frozen Peaks",
		"boss_puzzles": 3,
		"stars_required": 3,
	},
	2: {
		"play_as": Fairy.EARTH,
		"rescue": Fairy.ICE,
		"biome": "volcanic",
		"biome_name": "Volcanic Ridges",
		"boss_puzzles": 3,
		"stars_required": 3,
	},
	3: {
		"play_as": Fairy.ICE,
		"rescue": Fairy.WATER,
		"biome": "ocean",
		"biome_name": "Ocean Islands",
		"boss_puzzles": 3,
		"stars_required": 3,
	},
	4: {
		"play_as": Fairy.WATER,
		"rescue": Fairy.RAINBOW,
		"biome": "forest",
		"biome_name": "Forest Hills",
		"boss_puzzles": 3,
		"stars_required": 3,
	},
	5: {
		"play_as": Fairy.FIRE,  # All fairies available
		"rescue": null,  # Fairy Princess
		"biome": "mixed",
		"biome_name": "Convergence Realm",
		"boss_puzzles": 5,
		"stars_required": 5,
	},
}

func get_level_data() -> Dictionary:
	return LEVEL_DATA.get(current_level, LEVEL_DATA[1])

func reset() -> void:
	star_pieces = 0
	completed_landmarks.clear()
	discovered_clues.clear()
	discovered_pois.clear()
	revealed_cells.clear()
	boss_defeated = false

func reset_campaign() -> void:
	current_level = 1
	unlocked_fairies = [Fairy.FIRE]
	active_fairy = Fairy.FIRE
	selected_fairy = Fairy.FIRE
	reset()

func start_level(level: int) -> void:
	current_level = level
	var data := get_level_data()
	if level < 5:
		active_fairy = data["play_as"]
		selected_fairy = active_fairy
	else:
		active_fairy = Fairy.FIRE
		selected_fairy = Fairy.FIRE
	stars_required = data["stars_required"]
	reset()

func switch_fairy(fairy: Fairy) -> void:
	if fairy in unlocked_fairies:
		active_fairy = fairy
		selected_fairy = fairy
		fairy_switched.emit(fairy)

func collect_star() -> void:
	star_pieces += 1
	star_collected.emit(star_pieces)
	if star_pieces >= stars_required:
		boss_unlocked.emit()

func complete_landmark(landmark_id: String) -> void:
	if landmark_id not in completed_landmarks:
		completed_landmarks.append(landmark_id)
		landmark_completed.emit(landmark_id)

func discover_clue(clue_id: String, poi_id: String) -> void:
	if clue_id not in discovered_clues:
		discovered_clues.append(clue_id)
		if poi_id not in discovered_pois:
			discovered_pois.append(poi_id)
		clue_discovered.emit(clue_id)

func reveal_map_at(world_pos: Vector3) -> void:
	var center_cell := world_to_cell(world_pos)
	for dy in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
		for dx in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
			var cell := Vector2i(center_cell.x + dx, center_cell.y + dy)
			if cell not in revealed_cells:
				revealed_cells[cell] = true
				map_revealed.emit(cell)

func world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / MAP_CELL_SIZE),
		floori(world_pos.z / MAP_CELL_SIZE)
	)

func is_cell_revealed(cell: Vector2i) -> bool:
	return cell in revealed_cells

func is_boss_available() -> bool:
	return star_pieces >= stars_required

func get_random_mini_game() -> String:
	return MINI_GAME_TYPES[randi() % MINI_GAME_TYPES.size()]
