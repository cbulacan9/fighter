class_name CharacterSelect
extends Control

## Character selection screen for choosing a fighter before battle.
## Displays available characters in a grid and allows selection.

signal character_selected(character_id: String)
signal back_pressed()

@export var character_card_scene: PackedScene

@onready var title_label: Label = $VBoxContainer/Title
@onready var cards_container: GridContainer = $VBoxContainer/CardsContainer
@onready var character_card_panel: Panel = $VBoxContainer/CharacterCardPanel
@onready var character_card_display: TextureRect = $VBoxContainer/CharacterCardPanel/MarginContainer/HBoxContainer/CharacterCardDisplay
@onready var left_arrow: Button = $VBoxContainer/CharacterCardPanel/MarginContainer/HBoxContainer/LeftArrow
@onready var right_arrow: Button = $VBoxContainer/CharacterCardPanel/MarginContainer/HBoxContainer/RightArrow
@onready var select_button: Button = $VBoxContainer/ButtonContainer/SelectButton
@onready var back_button: Button = $VBoxContainer/ButtonContainer/BackButton

var _characters: Array[CharacterData] = []
var _unlocked_ids: Array[String] = []
var _selected_character: CharacterData = null
var _character_cards: Array[CharacterCard] = []
var _current_index: int = 0


func _ready() -> void:
	if select_button:
		select_button.pressed.connect(_on_select_pressed)
		select_button.disabled = true

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	if left_arrow:
		left_arrow.pressed.connect(_on_left_arrow_pressed)
	
	if right_arrow:
		right_arrow.pressed.connect(_on_right_arrow_pressed)


## Sets up the character select screen with available characters and unlocked IDs.
func setup(characters: Array[CharacterData], unlocked: Array[String] = []) -> void:
	_characters = characters
	_unlocked_ids = unlocked
	_selected_character = null
	_populate_cards()
	
	# Default select first character if available
	if _characters.size() > 0:
		var first_unlocked_index := _get_first_unlocked_index()
		if first_unlocked_index >= 0:
			_current_index = first_unlocked_index
			_select_character_by_index(_current_index)

	# Update button states
	if select_button:
		select_button.disabled = false


## Populates the cards container with character cards.
func _populate_cards() -> void:
	# Clear existing cards
	_character_cards.clear()
	for child in cards_container.get_children():
		child.queue_free()

	# Create cards for each character
	for char_data in _characters:
		var card := _create_character_card(char_data)
		cards_container.add_child(card)
		# Setup must be called AFTER add_child so @onready vars are initialized
		var unlocked := _is_unlocked(char_data)
		card.setup(char_data, unlocked)
		_character_cards.append(card)


## Creates a character card for the given character data.
## Note: setup() must be called AFTER adding the card to the tree.
func _create_character_card(char_data: CharacterData) -> CharacterCard:
	var card: CharacterCard

	if character_card_scene:
		card = character_card_scene.instantiate()
	else:
		# Fallback - try to load the scene
		var scene := load("res://scenes/ui/character_card.tscn")
		if scene:
			card = scene.instantiate()
		else:
			push_error("CharacterSelect: Could not load character_card.tscn")
			return null

	# Connect signals (can be done before add_child)
	card.pressed.connect(_on_card_pressed.bind(char_data))

	return card


## Checks if a character is unlocked.
func _is_unlocked(char_data: CharacterData) -> bool:
	# Starter characters are always unlocked
	if char_data.is_starter:
		return true

	# Check if character ID is in unlocked list
	if _unlocked_ids.has(char_data.character_id):
		return true

	# Check if unlock condition is empty (always unlocked)
	if char_data.unlock_opponent_id.is_empty():
		return true

	return false


## Called when a character card is pressed.
func _on_card_pressed(char_data: CharacterData) -> void:
	# Find the index of the pressed character
	for i in range(_characters.size()):
		if _characters[i] == char_data:
			_current_index = i
			_select_character_by_index(_current_index)
			break


## Selects a character by index and updates all UI elements.
func _select_character_by_index(index: int) -> void:
	if index < 0 or index >= _characters.size():
		return
	
	_current_index = index
	var char_data := _characters[index]
	
	# Check if character is unlocked
	if not _is_unlocked(char_data):
		return
	
	_selected_character = char_data
	
	# Update thumbnail selection highlights
	for card in _character_cards:
		card.set_selected(false)
	
	# Highlight the selected card
	for card in _character_cards:
		if card.get_character() == char_data:
			card.set_selected(true)
			break
	
	# Update character card display
	_update_character_card_display(char_data)


## Updates the central character card display.
func _update_character_card_display(char_data: CharacterData) -> void:
	if character_card_display:
		# Use character_card_texture if available, otherwise use portrait as fallback
		if char_data.character_card_texture:
			character_card_display.texture = char_data.character_card_texture
		elif char_data.portrait:
			character_card_display.texture = char_data.portrait
		else:
			character_card_display.texture = null


## Called when left arrow is pressed.
func _on_left_arrow_pressed() -> void:
	var unlocked_indices := _get_unlocked_indices()
	if unlocked_indices.is_empty():
		return
	
	# Find current position in unlocked list
	var current_pos := unlocked_indices.find(_current_index)
	if current_pos == -1:
		# Current index not in unlocked list, start from last unlocked
		_current_index = unlocked_indices[-1]
	else:
		# Move to previous (wrapping around)
		var new_pos := (current_pos - 1 + unlocked_indices.size()) % unlocked_indices.size()
		_current_index = unlocked_indices[new_pos]
	
	_select_character_by_index(_current_index)


## Called when right arrow is pressed.
func _on_right_arrow_pressed() -> void:
	var unlocked_indices := _get_unlocked_indices()
	if unlocked_indices.is_empty():
		return
	
	# Find current position in unlocked list
	var current_pos := unlocked_indices.find(_current_index)
	if current_pos == -1:
		# Current index not in unlocked list, start from first unlocked
		_current_index = unlocked_indices[0]
	else:
		# Move to next (wrapping around)
		var new_pos := (current_pos + 1) % unlocked_indices.size()
		_current_index = unlocked_indices[new_pos]
	
	_select_character_by_index(_current_index)


## Returns an array of indices of all unlocked characters.
func _get_unlocked_indices() -> Array[int]:
	var indices: Array[int] = []
	for i in range(_characters.size()):
		if _is_unlocked(_characters[i]):
			indices.append(i)
	return indices


## Returns the index of the first unlocked character, or -1 if none.
func _get_first_unlocked_index() -> int:
	var unlocked_indices := _get_unlocked_indices()
	if unlocked_indices.is_empty():
		return -1
	return unlocked_indices[0]


## Called when the select button is pressed.
func _on_select_pressed() -> void:
	if _selected_character:
		character_selected.emit(_selected_character.character_id)


## Called when the back button is pressed.
func _on_back_pressed() -> void:
	back_pressed.emit()


## Returns the currently selected character, or null if none.
func get_selected_character() -> CharacterData:
	return _selected_character


## Programmatically selects a character by ID.
func select_character(character_id: String) -> void:
	for i in range(_characters.size()):
		var char_data := _characters[i]
		if char_data.character_id == character_id and _is_unlocked(char_data):
			_current_index = i
			_select_character_by_index(_current_index)
			return


## Sets the title text (e.g., "SELECT PLAYER 1" or "SELECT PLAYER 2").
func set_title(text: String) -> void:
	if title_label:
		title_label.text = text


## Shows the character select screen.
func show_screen() -> void:
	visible = true


## Hides the character select screen.
func hide_screen() -> void:
	visible = false