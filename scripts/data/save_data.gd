class_name SaveData
extends Resource

## Persistent save data for tracking unlocked characters and match statistics.
## Stores unlocked characters, defeated opponents, and win/loss records.

const SAVE_PATH = "user://save_data.tres"

## List of character IDs that have been unlocked
@export var unlocked_characters: Array[String] = []

## List of opponent character IDs that have been defeated
@export var defeated_opponents: Array[String] = []

## Total number of matches won
@export var total_wins: int = 0

## Total number of matches lost
@export var total_losses: int = 0


## Loads existing save data or creates a new instance if none exists.
static func load_or_create() -> SaveData:
	if ResourceLoader.exists(SAVE_PATH):
		var data = load(SAVE_PATH) as SaveData
		if data:
			return data
	return SaveData.new()


## Saves the current data to the user directory.
func save() -> void:
	var error := ResourceSaver.save(self, SAVE_PATH)
	if error != OK:
		push_error("SaveData: Failed to save data, error code: %d" % error)


## Unlocks a character by ID if not already unlocked.
func unlock_character(character_id: String) -> void:
	if not unlocked_characters.has(character_id):
		unlocked_characters.append(character_id)
		save()


## Records defeating an opponent and increments win count.
func record_defeat(opponent_id: String) -> void:
	if not defeated_opponents.has(opponent_id):
		defeated_opponents.append(opponent_id)
	total_wins += 1
	save()


## Records a loss and increments loss count.
func record_loss() -> void:
	total_losses += 1
	save()


## Returns true if the character is in the unlocked list.
func is_unlocked(character_id: String) -> bool:
	return unlocked_characters.has(character_id)


## Returns true if the opponent has been defeated at least once.
func has_defeated(opponent_id: String) -> bool:
	return defeated_opponents.has(opponent_id)


## Returns the total number of matches played.
func get_total_matches() -> int:
	return total_wins + total_losses


## Returns the win rate as a percentage (0.0 to 100.0).
func get_win_rate() -> float:
	var total := get_total_matches()
	if total == 0:
		return 0.0
	return (float(total_wins) / float(total)) * 100.0


## Clears all save data (for debug/reset purposes).
func clear_all() -> void:
	unlocked_characters.clear()
	defeated_opponents.clear()
	total_wins = 0
	total_losses = 0
	save()
