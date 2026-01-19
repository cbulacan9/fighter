class_name CharacterRegistry
extends RefCounted

## Registry for loading and accessing character data resources.
## Scans the characters directory and provides access to CharacterData by ID.

const CHARACTERS_PATH := "res://resources/characters/"

var _characters: Dictionary = {}  # {character_id: CharacterData}


## Loads all character resources from the characters directory.
func load_all() -> void:
	_characters.clear()

	var dir := DirAccess.open(CHARACTERS_PATH)
	if not dir:
		push_error("CharacterRegistry: Failed to open characters directory: %s" % CHARACTERS_PATH)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path := CHARACTERS_PATH + file_name
			var resource := load(resource_path)

			if resource is CharacterData:
				var char_data: CharacterData = resource
				if char_data.validate():
					_characters[char_data.character_id] = char_data
				else:
					push_warning("CharacterRegistry: Invalid character data in file: %s" % file_name)
			else:
				push_warning("CharacterRegistry: File is not CharacterData: %s" % file_name)

		file_name = dir.get_next()

	dir.list_dir_end()


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
