class_name SequencePattern
extends Resource

## Unique identifier for this sequence
@export var sequence_id: String = ""

## Display name for UI
@export var display_name: String = ""

## The tile types that must be matched in order
## Uses TileTypes.Type enum values
@export var pattern: Array[int] = []

## The tile type that terminates/activates the sequence (usually clicked)
## Uses TileTypes.Type enum value
@export var terminator: int = -1

## Effect triggered when sequence is activated (offensive/enemy effect)
@export var on_complete_effect: EffectData

## Secondary effect (for self-buff component)
@export var self_buff_effect: EffectData

## Maximum times this sequence can be stacked
@export var max_stacks: int = 3

## Icon for UI display
@export var icon: Texture2D

## Description for UI
@export_multiline var description: String = ""


## Returns the length of the pattern (excluding terminator)
func get_pattern_length() -> int:
	return pattern.size()


## Returns the full sequence length including terminator
func get_full_length() -> int:
	return pattern.size() + 1


## Checks if the given sequence matches the start of this pattern
## Returns true if sequence is a valid prefix of pattern
func matches_prefix(sequence: Array[int]) -> bool:
	if sequence.size() > pattern.size():
		return false

	for i in range(sequence.size()):
		if sequence[i] != pattern[i]:
			return false

	return true


## Checks if the given sequence exactly matches this pattern (excluding terminator)
func is_complete_match(sequence: Array[int]) -> bool:
	if sequence.size() != pattern.size():
		return false

	for i in range(sequence.size()):
		if sequence[i] != pattern[i]:
			return false

	return true


## Returns how many elements of the sequence match the pattern from the start
func get_match_progress(sequence: Array[int]) -> int:
	var matched := 0
	var check_length := mini(sequence.size(), pattern.size())

	for i in range(check_length):
		if sequence[i] != pattern[i]:
			break
		matched += 1

	return matched


## Returns the next expected tile type in the pattern given current progress
## Returns -1 if sequence is already complete or invalid
func get_next_expected(current_progress: int) -> int:
	if current_progress < 0 or current_progress >= pattern.size():
		return -1
	return pattern[current_progress]


## Returns a string representation of the pattern for debugging
func get_pattern_string() -> String:
	var parts: Array[String] = []
	for tile_type in pattern:
		parts.append(_tile_type_name(tile_type))
	parts.append(_tile_type_name(terminator) + " (click)")
	return " -> ".join(parts)


func _tile_type_name(tile_type: int) -> String:
	# Map tile type enum values to names
	# This uses TileTypes.Type enum
	match tile_type:
		TileTypes.Type.SWORD:
			return "Physical"
		TileTypes.Type.SHIELD:
			return "Shield"
		TileTypes.Type.POTION:
			return "Potion"
		TileTypes.Type.LIGHTNING:
			return "Stun"
		TileTypes.Type.FILLER:
			return "Empty"
		TileTypes.Type.PET:
			return "Pet"
		TileTypes.Type.MANA:
			return "Mana"
		_:
			return "Unknown(%d)" % tile_type
