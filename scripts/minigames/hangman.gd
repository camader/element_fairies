extends "res://scripts/minigames/mini_game_base.gd"

## Hangman mini-game
## Guess a fairy-themed word letter by letter before running out of lives

const WORD_LIST := [
	"ENCHANTED", "PIXIEDUST", "MOONLIGHT", "STARSHINE", "GLOWWING",
	"SPARKLE", "CRYSTAL", "BLOSSOM", "FLUTTER", "SHIMMER",
	"MYSTICAL", "TWILIGHT",
]
const MAX_LIVES := 6

var target_word: String = ""
var revealed: Array[bool] = []
var lives: int = MAX_LIVES
var word_label: Label
var lives_label: Label
var letter_buttons: Dictionary = {}  # char -> Button

func _setup_game() -> void:
	if title_label:
		title_label.text = "Hangman!"
	_set_instructions("Click letters to guess the word. You have 6 lives!")

	# Pick a random word
	target_word = WORD_LIST[randi() % WORD_LIST.size()]
	revealed.resize(target_word.length())
	for i in target_word.length():
		revealed[i] = false

	_build_ui()

func _build_ui() -> void:
	if not game_area:
		return

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	game_area.add_child(vbox)

	# Lives display
	lives_label = Label.new()
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lives_label.add_theme_font_size_override("font_size", 22)
	lives_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	vbox.add_child(lives_label)
	_update_lives_display()

	# Word display
	word_label = Label.new()
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_label.add_theme_font_size_override("font_size", 28)
	word_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(word_label)
	_update_word_display()

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Letter buttons: A-M row
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 4)
	vbox.add_child(row1)

	for i in range(0, 13):  # A(65) through M(77)
		var ch := char(65 + i)
		var btn := _create_letter_button(ch)
		row1.add_child(btn)
		letter_buttons[ch] = btn

	# Letter buttons: N-Z row
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 4)
	vbox.add_child(row2)

	for i in range(13, 26):  # N(78) through Z(90)
		var ch := char(65 + i)
		var btn := _create_letter_button(ch)
		row2.add_child(btn)
		letter_buttons[ch] = btn

func _create_letter_button(ch: String) -> Button:
	var btn := Button.new()
	btn.text = ch
	btn.custom_minimum_size = Vector2(40, 40)
	btn.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.35)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	btn.pressed.connect(_on_letter_pressed.bind(ch))
	return btn

func _on_letter_pressed(ch: String) -> void:
	if lives <= 0:
		return

	var btn: Button = letter_buttons[ch]
	btn.disabled = true

	# Check if the letter is in the word
	var found := false
	for i in target_word.length():
		if target_word[i] == ch:
			revealed[i] = true
			found = true

	if found:
		# Correct guess - green button
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.6, 0.2)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("disabled", style)
		_update_word_display()

		# Check for win
		var all_revealed := true
		for r in revealed:
			if not r:
				all_revealed = false
				break
		if all_revealed:
			word_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
			await get_tree().create_timer(0.5).timeout
			_complete(true)
	else:
		# Wrong guess - red button, lose a life
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.6, 0.2, 0.2)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("disabled", style)
		lives -= 1
		_update_lives_display()

		if lives <= 0:
			# Reveal the full word before failing
			for i in target_word.length():
				revealed[i] = true
			_update_word_display()
			word_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
			await get_tree().create_timer(0.5).timeout
			_complete(false)

func _update_word_display() -> void:
	if not word_label:
		return
	var display := ""
	for i in target_word.length():
		if i > 0:
			display += " "
		if revealed[i]:
			display += target_word[i]
		else:
			display += "_"
	word_label.text = display

func _update_lives_display() -> void:
	if not lives_label:
		return
	var hearts := ""
	for i in MAX_LIVES:
		if i < lives:
			hearts += "\u2665"
		else:
			hearts += "\u2661"
	lives_label.text = "Lives: " + hearts
