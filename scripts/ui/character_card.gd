class_name CharacterCard
extends Control

## A UI card component displaying a character for selection.
## Shows portrait, name, and locked state for character selection screens.

signal pressed()
signal selected()

@onready var portrait: TextureRect = $Portrait
@onready var name_label: Label = $NameLabel
@onready var locked_overlay: ColorRect = $LockedOverlay
@onready var button: Button = $Button
@onready var selection_highlight: Panel = $SelectionHighlight

var _character: CharacterData
var _is_unlocked: bool = true
var _is_selected: bool = false


func _ready() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)

	# Hide selection highlight by default
	if selection_highlight:
		selection_highlight.visible = false


## Sets up the card with character data and unlock status.
func setup(char_data: CharacterData, unlocked: bool) -> void:
	_character = char_data
	_is_unlocked = unlocked

	# Set portrait - prefer small portrait if available, generate placeholder if missing
	if portrait:
		portrait.texture = PlaceholderTextures.get_or_generate_portrait(char_data, true)

	# Set name
	if name_label:
		name_label.text = char_data.display_name

	# Show/hide locked overlay
	if locked_overlay:
		locked_overlay.visible = not unlocked

	# Disable button if locked
	if button:
		button.disabled = not unlocked


## Returns the character data for this card.
func get_character() -> CharacterData:
	return _character


## Returns true if this character is unlocked.
func is_unlocked() -> bool:
	return _is_unlocked


## Sets the selected state of this card.
func set_selected(selected: bool) -> void:
	_is_selected = selected
	if selection_highlight:
		selection_highlight.visible = _is_selected


## Returns true if this card is currently selected.
func is_selected() -> bool:
	return _is_selected


func _on_button_pressed() -> void:
	if _is_unlocked:
		pressed.emit()
		selected.emit()
