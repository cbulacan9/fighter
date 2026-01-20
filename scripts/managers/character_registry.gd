class_name CharacterRegistry
extends RefCounted

## Registry for loading and accessing character data resources.
## Uses static preloads to ensure characters are included in Android/mobile exports.
## NOTE: When adding new characters, add them to CHARACTER_RESOURCES below.

var _characters: Dictionary = {}  # {character_id: CharacterData}

## Static list of all character resources - required for Android export compatibility.
## DirAccess scanning doesn't work in packaged APK builds.
const CHARACTER_RESOURCES: Array[Resource] = [
	preload("res://resources/characters/basic.tres"),
	preload("res://resources/characters/hunter.tres"),
	preload("res://resources/characters/assassin.tres"),
	preload("res://resources/characters/mirror_warden.tres"),
	# Add new characters here when created
]


## Loads all character resources from the static list.
func load_all() -> void:
	_characters.clear()

	for resource in CHARACTER_RESOURCES:
		if resource is CharacterData:
			var char_data: CharacterData = resource
			if char_data.validate():
				_characters[char_data.character_id] = char_data
			else:
				push_warning("CharacterRegistry: Invalid character data: %s" % char_data.character_id)
		else:
			push_warning("CharacterRegistry: Resource is not CharacterData")


## Returns the CharacterData for the given character ID, or null if not found.
func get_character(id: String) -> CharacterData:
	return _characters.get(id)


## Returns all loaded characters as an array.
func get_all_characters() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for char_data: CharacterData in _characters.values():
		result.append(char_data)
	return result


## Returns the first starter character (is_starter = true).
## If no starter is found, returns null.
func get_starter() -> CharacterData:
	for char_data: CharacterData in _characters.values():
		if char_data.is_starter:
			return char_data
	return null


## Returns all starter characters (is_starter = true).
func get_starter_characters() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for char_data: CharacterData in _characters.values():
		if char_data.is_starter:
			result.append(char_data)
	return result


## Returns all unlockable characters (is_starter = false).
func get_unlockable_characters() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for char_data: CharacterData in _characters.values():
		if not char_data.is_starter:
			result.append(char_data)
	return result


## Returns the number of loaded characters.
func get_character_count() -> int:
	return _characters.size()


## Checks if a character with the given ID exists.
func has_character(id: String) -> bool:
	return _characters.has(id)
