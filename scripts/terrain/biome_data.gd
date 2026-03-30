extends RefCounted

## Defines noise parameters and visual settings for each biome

var biome_type: String = "volcanic"
var noise_frequency: float = 0.04
var noise_amplitude: float = 6.0
var noise_octaves: int = 4
var noise_lacunarity: float = 2.0
var noise_gain: float = 0.5
var base_color: Color = Color(0.4, 0.2, 0.1)
var accent_color: Color = Color(1.0, 0.3, 0.0)
var ground_color: Color = Color(0.3, 0.15, 0.1)
var obstacle_types: Array[String] = []
var obstacle_density: float = 0.15

# Region noise — controls plains vs hills zones
var region_frequency: float = 0.008
var region_threshold: float = 0.1
var region_blend_range: float = 0.15
var plains_amplitude_scale: float = 0.1
var hills_amplitude_scale: float = 1.0

# Path noise — carves corridors through hills
var path_frequency: float = 0.012
var path_width: float = 0.2
var path_depth: float = 0.7

func configure_for_biome(biome: String) -> void:
	biome_type = biome
	match biome:
		"volcanic":
			# Earth fairy level + Fire from L1: lava gaps, fire walls (Earth), ice blocks (Fire)
			noise_frequency = 0.035
			noise_amplitude = 8.0
			noise_octaves = 4
			base_color = Color(0.35, 0.15, 0.08)
			accent_color = Color(1.0, 0.4, 0.0)
			ground_color = Color(0.25, 0.12, 0.08)
			obstacle_types = ["lava_gap", "fire_wall", "ice_block"]
			obstacle_density = 0.12
			region_threshold = 0.0
			region_blend_range = 0.12
			path_width = 0.15
			path_depth = 0.6
		"forest":
			# Water fairy level + Fire, Earth, Ice: fire walls, water pools, gaps, ice blocks
			noise_frequency = 0.04
			noise_amplitude = 6.0
			noise_octaves = 5
			base_color = Color(0.2, 0.4, 0.15)
			accent_color = Color(0.3, 0.6, 0.2)
			ground_color = Color(0.18, 0.3, 0.1)
			obstacle_types = ["fire_wall", "water_pool", "gap", "ice_block"]
			obstacle_density = 0.10
			region_threshold = 0.1
			region_blend_range = 0.15
			path_width = 0.2
			path_depth = 0.7
		"frozen":
			# Fire fairy level (L1): ice blocks, water pools — Fire clears both
			noise_frequency = 0.03
			noise_amplitude = 10.0
			noise_octaves = 4
			base_color = Color(0.7, 0.85, 0.95)
			accent_color = Color(0.5, 0.7, 1.0)
			ground_color = Color(0.6, 0.75, 0.85)
			obstacle_types = ["ice_block", "water_pool"]
			obstacle_density = 0.12
			region_threshold = 0.15
			region_blend_range = 0.2
			hills_amplitude_scale = 1.2
			path_width = 0.25
			path_depth = 0.8
		"ocean":
			# Ice fairy level + Fire, Earth: gaps, water pools (Ice), ice blocks (Fire), fire walls (Earth)
			noise_frequency = 0.045
			noise_amplitude = 4.0
			noise_octaves = 3
			base_color = Color(0.2, 0.35, 0.5)
			accent_color = Color(0.3, 0.6, 0.9)
			ground_color = Color(0.6, 0.55, 0.35)
			obstacle_types = ["gap", "water_pool", "ice_block", "fire_wall"]
			obstacle_density = 0.12
			region_threshold = 0.2
			region_blend_range = 0.15
			plains_amplitude_scale = 0.05
			hills_amplitude_scale = 0.6
			path_width = 0.25
			path_depth = 0.8
		"mixed":
			noise_frequency = 0.04
			noise_amplitude = 7.0
			noise_octaves = 5
			base_color = Color(0.4, 0.35, 0.3)
			accent_color = Color(0.7, 0.5, 0.9)
			ground_color = Color(0.3, 0.28, 0.25)
			obstacle_types = ["ice_block", "fire_wall", "water_pool", "gap", "teleport_pad"]
			obstacle_density = 0.15
			region_threshold = 0.1
			region_blend_range = 0.15
			path_width = 0.2
			path_depth = 0.7
