extends "res://scripts/minigames/mini_game_base.gd"

## Scrambled Letters mini-game
## Unscramble 3 fairy-themed words by clicking letter tiles in order

const WORD_LIST := [
	"FAIRY", "MAGIC", "STAR", "WAND", "SPELL",
	"CHARM", "DREAM", "LIGHT", "FROST", "FLAME",
	"BLOOM", "CRYSTAL",
]
const WORDS_PER_GAME := 3
const TILE_SIZE := 50.0

var words_to_solve: Array[String] = []
var current_word_index: int = 0
var current_word: String = ""
var scrambled: Array[String] = []
var answer: Array[String] = []
var correct_count: int = 0

var tile_container: HBoxContainer
var answer_container: HBoxContainer
var progress_label: Label
var status_label: Label
var tile_buttons: Array[Button] = []
var answer_buttons: Array[Button] = []

func _setup_game() -> void:
	if title_label:
		title_label.text = "Scrambled Letters!"
	_set_instructions("Click the letter tiles in order to spell the word. Unscramble all 3 words to win!")

	# Pick 3 random unique words
	var pool := WORD_LIST.duplicate()
	pool.shuffle()
	for i in WORDS_PER_GAME:
		words_to_solve.append(pool[i])

	_build_ui()
	_load_word(0)

func _build_ui() -> void:
	if not game_area:
		return

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	game_area.add_child(vbox)

	# Progress label
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 18)
	progress_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	vbox.add_child(progress_label)

	# Status label (shows "Correct!" between words)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	status_label.text = ""
	vbox.add_child(status_label)

	# Answer row (where selected letters appear)
	var answer_label := Label.new()
	answer_label.text = "Your answer:"
	answer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	answer_label.add_theme_font_size_override("font_size", 16)
	answer_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(answer_label)

	answer_container = HBoxContainer.new()
	answer_container.alignment = BoxContainer.ALIGNMENT_CENTER
	answer_container.add_theme_constant_override("separation", 6)
	vbox.add_child(answer_container)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Scrambled tiles row
	var tiles_label := Label.new()
	tiles_label.text = "Available letters:"
	tiles_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tiles_label.add_theme_font_size_override("font_size", 16)
	tiles_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(tiles_label)

	tile_container = HBoxContainer.new()
	tile_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tile_container.add_theme_constant_override("separation", 6)
	vbox.add_child(tile_container)

func _load_word(index: int) -> void:
	current_word_index = index
	current_word = words_to_solve[index]
	answer.clear()

	# Scramble the letters ensuring they aren't in original order
	scrambled = []
	for ch in current_word:
		scrambled.append(ch)
	for _attempt in 20:
		scrambled.shuffle()
		var scrambled_str := ""
		for ch in scrambled:
			scrambled_str += ch
		if scrambled_str != current_word:
			break

	_update_progress()
	_rebuild_tiles()
	_rebuild_answer()

func _update_progress() -> void:
	if progress_label:
		progress_label.text = "Correct: " + str(correct_count) + "/" + str(WORDS_PER_GAME)

func _rebuild_tiles() -> void:
	if not tile_container:
		return

	# Clear existing tiles
	for child in tile_container.get_children():
		child.queue_free()
	tile_buttons.clear()

	for i in scrambled.size():
		var btn := Button.new()
		btn.text = scrambled[i]
		btn.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		btn.add_theme_font_size_override("font_size", 22)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.35, 0.5)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", style)
		btn.pressed.connect(_on_tile_pressed.bind(i))
		tile_container.add_child(btn)
		tile_buttons.append(btn)

func _rebuild_answer() -> void:
	if not answer_container:
		return

	# Clear existing answer tiles
	for child in answer_container.get_children():
		child.queue_free()
	answer_buttons.clear()

	for i in answer.size():
		var btn := Button.new()
		btn.text = answer[i]
		btn.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		btn.add_theme_font_size_override("font_size", 22)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.4, 0.5, 0.6)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", style)
		btn.pressed.connect(_on_answer_pressed.bind(i))
		answer_container.add_child(btn)
		answer_buttons.append(btn)

	# Show empty placeholders for remaining letters
	var remaining := current_word.length() - answer.size()
	for i in remaining:
		var placeholder := ColorRect.new()
		placeholder.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		placeholder.color = Color(0.15, 0.15, 0.2)
		answer_container.add_child(placeholder)

func _on_tile_pressed(tile_index: int) -> void:
	if tile_index >= tile_buttons.size():
		return
	var btn := tile_buttons[tile_index]
	if btn.disabled:
		return

	# Move letter to answer
	answer.append(scrambled[tile_index])
	btn.disabled = true
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.2, 0.2, 0.25)
	disabled_style.corner_radius_top_left = 6
	disabled_style.corner_radius_top_right = 6
	disabled_style.corner_radius_bottom_left = 6
	disabled_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("disabled", disabled_style)

	# Store which tile index this answer letter came from
	_rebuild_answer()
	_check_answer()

func _on_answer_pressed(answer_index: int) -> void:
	if answer_index >= answer.size():
		return

	# Find the corresponding tile and re-enable it
	var removed_letter: String = answer[answer_index]
	# Find first disabled tile with this letter
	for i in tile_buttons.size():
		if tile_buttons[i].disabled and scrambled[i] == removed_letter:
			tile_buttons[i].disabled = false
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.35, 0.5)
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			tile_buttons[i].add_theme_stylebox_override("normal", style)
			break

	answer.remove_at(answer_index)
	_rebuild_answer()

func _check_answer() -> void:
	if answer.size() != current_word.length():
		return

	var answer_str := ""
	for ch in answer:
		answer_str += ch

	if answer_str == current_word:
		correct_count += 1
		_update_progress()

		# Flash answer green
		for btn in answer_buttons:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.8, 0.2)
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			btn.add_theme_stylebox_override("normal", style)

		if correct_count >= WORDS_PER_GAME:
			status_label.text = "All words solved!"
			await get_tree().create_timer(0.5).timeout
			_complete(true)
		else:
			status_label.text = "Correct!"
			await get_tree().create_timer(0.8).timeout
			status_label.text = ""
			_load_word(current_word_index + 1)
