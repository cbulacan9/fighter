class_name UnlockManager
extends RefCounted

## Manages character unlocks based on defeated opponents.
## Tracks match results and triggers unlock events when conditions are met.

signal character_unlocked(character_id: String)

var _save_data: SaveData
var _character_registry: CharacterRegistry


## Initializes the unlock manager with a character registry.
func setup(registry: CharacterRegistry) -> void:
	_character_registry = registry
	_save_data = SaveData.load_or_create()
	_process_unlocks()


## Checks for any pending unlocks based on defeated opponents.
func _process_unlocks() -> void:
	if not _character_registry:
		return

	# Check if any defeated opponents should unlock characters
	for char_data in _character_registry.get_all_characters():
		if char_data.is_starter:
			continue
		if char_data.unlock_opponent_id != "":
			if _save_data.has_defeated(char_data.unlock_opponent_id):
				if not _save_data.is_unlocked(char_data.character_id):
					_unlock(char_data.character_id)


## Called when a match is won against an opponent.
func on_match_won(opponent_id: String) -> void:
	_save_data.record_defeat(opponent_id)

	# Check if this unlocks any characters
	if _character_registry:
		for char_data in _character_registry.get_all_characters():
			if char_data.unlock_opponent_id == opponent_id:
				if not _save_data.is_unlocked(char_data.character_id):
					_unlock(char_data.character_id)


## Called when a match is lost.
func on_match_lost() -> void:
	_save_data.record_loss()


## Unlocks a character and emits the unlocked signal.
func _unlock(character_id: String) -> void:
	_save_data.unlock_character(character_id)
	character_unlocked.emit(character_id)


## Returns true if a character is available for selection.
## Starter characters are always unlocked.
func is_unlocked(character_id: String) -> bool:
	if not _character_registry:
		return false

	var char_data := _character_registry.get_character(character_id)
	if char_data and char_data.is_starter:
		return true
	return _save_data.is_unlocked(character_id)


## Returns an array of all unlocked character IDs.
func get_unlocked_ids() -> Array[String]:
	var result: Array[String] = []
	if not _character_registry:
		return result

	for char_data in _character_registry.get_all_characters():
		if is_unlocked(char_data.character_id):
			result.append(char_data.character_id)
	return result


## Returns match statistics dictionary.
func get_stats() -> Dictionary:
	return {
		"wins": _save_data.total_wins,
		"losses": _save_data.total_losses,
		"win_rate": _save_data.get_win_rate(),
		"total_matches": _save_data.get_total_matches(),
		"unlocked_count": get_unlocked_ids().size()
	}


## Returns the raw save data (for advanced access).
func get_save_data() -> SaveData:
	return _save_data


## Forces a save (useful after batch operations).
func force_save() -> void:
	if _save_data:
		_save_data.save()
