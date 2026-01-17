class_name CharacterSelect
extends Control

## Character selection screen for choosing a fighter before battle.
## Displays available characters in a grid and allows selection.

signal character_selected(character_id: String)
signal back_pressed()

@export var character_card_scene: PackedScene

@onready var cards_container: GridContainer = $VBoxContainer/CardsContainer
@onready var description_panel: Panel = $VBoxContainer/DescriptionPanel
@onready var description_label: Label = $VBoxContainer/DescriptionPanel/MarginContainer/VBoxContainer/Description
@onready var archetype_label: Label = $VBoxContainer/DescriptionPanel/MarginContainer/VBoxContainer/Archetype
@onready var character_name_label: Label = $VBoxContainer/DescriptionPanel/MarginContainer/VBoxContainer/CharacterName
@onready var select_button: Button = $VBoxContainer/ButtonContainer/SelectButton
@onready var back_button: Button = $VBoxContainer/ButtonContainer/BackButton

var _characters: Array[CharacterData] = []
var _unlocked_ids: Array[String] = []
var _selected_character: CharacterData = null
var _character_cards: Array[CharacterCard] = []


func _ready() -> void:
	if select_button:
		select_button.pressed.connect(_on_select_pressed)
		select_button.disabled = true

	if back_button:
		back_button.pressed.connect(_on_back_pressed)


## Sets up the character select screen with available characters and unlocked IDs.
func setup(characters: Array[CharacterData], unlocked: Array[String] = []) -> void:
	_characters = characters
	_unlocked_ids = unlocked
	_selected_character = null
	_populate_cards()

	# Update button states
	if select_button:
		select_button.disabled = true

	# Clear description
	_update_description(null)


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
		_character_cards.append(card)


## Creates a character card for the given character data.
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

	var unlocked := _is_unlocked(char_data)
	card.setup(char_data, unlocked)

	# Connect signals
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
	# Deselect all cards
	for card in _character_cards:
		card.set_selected(false)

	# Select the pressed card
	for card in _character_cards:
		if card.get_character() == char_data:
			card.set_selected(true)
			break

	_selected_character = char_data
	_update_description(char_data)

	# Enable select button
	if select_button:
		select_button.disabled = false


## Updates the description panel with character info.
func _update_description(char_data: CharacterData) -> void:
	if not char_data:
		if description_label:
			description_label.text = "Select a character to view their abilities."
		if archetype_label:
			archetype_label.text = ""
		if character_name_label:
			character_name_label.text = ""
		return

	if character_name_label:
		character_name_label.text = char_data.display_name

	if archetype_label:
		archetype_label.text = char_data.archetype

	if description_label:
		var desc := char_data.description
		if not char_data.passive_description.is_empty():
			desc += "\n\nPassive: " + char_data.passive_description
		description_label.text = desc


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
	for card in _character_cards:
		var char_data := card.get_character()
		if char_data and char_data.character_id == character_id and card.is_unlocked():
			_on_card_pressed(char_data)
			return
