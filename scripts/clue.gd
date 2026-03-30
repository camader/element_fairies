extends Area3D

## A discoverable clue that reveals a point of interest on the minimap

@export var clue_id: String = "clue_01"
@export var clue_text: String = "A mysterious glow lies to the north..."
@export var reveals_poi: String = "landmark_02"  # The POI this clue reveals on map

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D

var _collected := false
var hidden_by_obstacle := false  # True when buried under a terrain pool

func _ready() -> void:
	add_to_group("clue")
	if clue_id in GameState.discovered_clues:
		_collected = true
		visible = false
		monitoring = false
	elif hidden_by_obstacle:
		visible = false
		monitoring = false
	body_entered.connect(_on_body_entered)

## Called when the obstacle covering this clue is destroyed (e.g. water evaporated by fire)
func reveal() -> void:
	if _collected:
		return
	hidden_by_obstacle = false
	visible = true
	monitoring = true
	# Pop-in animation
	scale = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not _collected:
		_collected = true
		GameState.discover_clue(clue_id, reveals_poi)
		_show_clue_popup()
		# Fade out
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3.ZERO, 0.5)
		tween.tween_callback(queue_free)

func _show_clue_popup() -> void:
	# Find the HUD and show a clue message
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_clue_message"):
		hud.show_clue_message(clue_text)
