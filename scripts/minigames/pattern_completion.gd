extends "res://scripts/minigames/mini_game_base.gd"

## Pattern Completion mini-game
## Identify the next symbol in a repeating pattern sequence

const ROUNDS_TO_WIN := 3
const SEQUENCE_LENGTH := 5
const NUM_CHOICES := 4

const PATTERN_SYMBOLS := [
	["★", "♦", "✿"],
	["☀", "☽", "⚡"],
	["♥", "✦", "★"],
	["⚡", "✿", "♦"],
	["☽", "☀", "♥"],
]
const PATTERN_COLORS := [
	[Color(1.0, 0.84, 0.0), Color(0.0, 0.75, 1.0), Color(1.0, 0.4, 0.7)],
	[Color(1.0, 0.6, 0.0), Color(0.7, 0.7, 1.0), Color(1.0, 1.0, 0.2)],
	[Color(1.0, 0.2, 0.3), Color(0.4, 1.0, 0.8), Color(1.0, 0.84, 0.0)],
	[Color(1.0, 1.0, 0.2), Color(1.0, 0.4, 0.7), Color(0.0, 0.75, 1.0)],
	[Color(0.7, 0.7, 1.0), Color(1.0, 0.6, 0.0), Color(1.0, 0.2, 0.3)],
]

var current_round := 0
var correct_count := 0
var current_answer_index := -1  # Index in the cycle (0, 1, or 2)
var current_symbols: Array = []
var current_colors: Array = []
var is_waiting := false

var score_label: Label
var sequence_container: HBoxContainer
var choices_container: HBoxContainer
var feedback_label: Label

func _setup_game() -> void:
	if title_label:
		title_label.text = "Pattern Completion!"
	_set_instructions("Find the next symbol in each pattern sequence.")
	_build_ui()
	_start_round()

func _build_ui() -> void:
	if not game_area:
		return

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	game_area.add_child(vbox)

	# Score label
	score_label = Label.new()
	score_label.text = "Correct: 0/%d" % ROUNDS_TO_WIN
	score_label.add_theme_font_size_override("font_size", 22)
	score_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_label)

	# Sequence display row
	var seq_center := CenterContainer.new()
	vbox.add_child(seq_center)

	sequence_container = HBoxContainer.new()
	sequence_container.add_theme_constant_override("separation", 12)
	seq_center.add_child(sequence_container)

	# Feedback label
	feedback_label = Label.new()
	feedback_label.text = ""
	feedback_label.add_theme_font_size_override("font_size", 20)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(feedback_label)

	# Answer choices row
	var choices_center := CenterContainer.new()
	vbox.add_child(choices_center)

	choices_container = HBoxContainer.new()
	choices_container.add_theme_constant_override("separation", 15)
	choices_center.add_child(choices_container)

func _start_round() -> void:
	is_waiting = false
	feedback_label.text = ""

	# Pick a pattern set (avoid repeats if possible)
	var pattern_idx := current_round % PATTERN_SYMBOLS.size()
	current_symbols = PATTERN_SYMBOLS[pattern_idx]
	current_colors = PATTERN_COLORS[pattern_idx]

	# The cycle is 3 symbols. Show 5 items (indices 0..4 of the cycle), answer is index 5.
	# Cycle index for answer: 5 % 3 = 2
	current_answer_index = SEQUENCE_LENGTH % current_symbols.size()

	_build_sequence()
	_build_choices()

func _build_sequence() -> void:
	# Clear old
	for child in sequence_container.get_children():
		child.queue_free()

	# Show SEQUENCE_LENGTH symbols + "?"
	for i in SEQUENCE_LENGTH:
		var cycle_idx: int = i % current_symbols.size()
		var lbl := Label.new()
		lbl.text = current_symbols[cycle_idx]
		lbl.add_theme_font_size_override("font_size", 42)
		lbl.add_theme_color_override("font_color", current_colors[cycle_idx])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(55, 55)
		sequence_container.add_child(lbl)

	# Question mark
	var q_label := Label.new()
	q_label.text = "?"
	q_label.add_theme_font_size_override("font_size", 42)
	q_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_label.custom_minimum_size = Vector2(55, 55)
	sequence_container.add_child(q_label)

func _build_choices() -> void:
	# Clear old
	for child in choices_container.get_children():
		child.queue_free()

	# Build 4 choices: the correct answer + 3 distractors
	var correct_symbol: String = current_symbols[current_answer_index]
	var correct_color: Color = current_colors[current_answer_index]

	# Gather distractor pool from all symbols not matching the answer
	var all_symbols: Array[Dictionary] = []
	for p in PATTERN_SYMBOLS.size():
		for s in PATTERN_SYMBOLS[p].size():
			var sym: String = PATTERN_SYMBOLS[p][s]
			var col: Color = PATTERN_COLORS[p][s]
			if sym != correct_symbol:
				all_symbols.append({"symbol": sym, "color": col})

	all_symbols.shuffle()

	# Build choice list
	var choices: Array[Dictionary] = []
	choices.append({"symbol": correct_symbol, "color": correct_color, "correct": true})
	var added := 0
	for entry in all_symbols:
		if added >= NUM_CHOICES - 1:
			break
		# Avoid duplicate symbols in choices
		var dupe := false
		for c in choices:
			if c.symbol == entry.symbol:
				dupe = true
				break
		if not dupe:
			choices.append({"symbol": entry.symbol, "color": entry.color, "correct": false})
			added += 1

	choices.shuffle()

	for i in choices.size():
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = choice.symbol
		btn.custom_minimum_size = Vector2(80, 80)
		btn.add_theme_font_size_override("font_size", 36)
		btn.add_theme_color_override("font_color", choice.color)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.25)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.border_color = choice.color.darkened(0.3)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		btn.add_theme_stylebox_override("normal", style.duplicate())
		btn.add_theme_stylebox_override("hover", style.duplicate())
		btn.add_theme_stylebox_override("pressed", style.duplicate())

		btn.pressed.connect(_on_choice_pressed.bind(choice.correct, choice.symbol))
		choices_container.add_child(btn)

func _on_choice_pressed(is_correct: bool, symbol: String) -> void:
	if is_waiting:
		return
	is_waiting = true

	if is_correct:
		correct_count += 1
		score_label.text = "Correct: %d/%d" % [correct_count, ROUNDS_TO_WIN]
		feedback_label.text = "Correct!"
		feedback_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))

		# Reveal the answer in the sequence
		_reveal_answer()

		if correct_count >= ROUNDS_TO_WIN:
			await get_tree().create_timer(0.5).timeout
			_complete(true)
			return
	else:
		var correct_sym: String = current_symbols[current_answer_index]
		feedback_label.text = "Wrong! It was %s" % correct_sym
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_reveal_answer()

	current_round += 1

	# Check if all rounds exhausted without enough correct
	if current_round >= ROUNDS_TO_WIN and correct_count < ROUNDS_TO_WIN:
		await get_tree().create_timer(0.5).timeout
		_complete(false)
		return

	await get_tree().create_timer(1.2).timeout
	_start_round()

func _reveal_answer() -> void:
	# Replace the "?" with the correct answer
	var children := sequence_container.get_children()
	if children.size() > 0:
		var q_label: Label = children[children.size() - 1]
		q_label.text = current_symbols[current_answer_index]
		q_label.add_theme_color_override("font_color", current_colors[current_answer_index])

	# Disable choice buttons
	for child in choices_container.get_children():
		if child is Button:
			child.disabled = true
