class_name PetSpawner
extends Node

## Manages Pet tile spawning when Hunter combos complete.
## Enforces 3-per-type cap and emits signals for UI feedback.

const MAX_PET_PER_TYPE: int = 3
const GRID_COLS: int = 8  # Match Grid.COLS

var _pet_counts: Dictionary = {}  # {pet_type: count}

signal pet_spawned(pet_type: int, column: int)  # Request to spawn (before confirmation)
signal pet_spawn_confirmed(pet_type: int)  # After successful placement
signal pet_spawn_blocked(pet_type: int)
signal pet_activated(pet_type: int)


func _ready() -> void:
	_reset_counts()


func _reset_counts() -> void:
	_pet_counts = {
		TileTypes.Type.BEAR_PET: 0,
		TileTypes.Type.HAWK_PET: 0,
		TileTypes.Type.SNAKE_PET: 0
	}


## Called when a combo sequence completes. Requests a pet tile spawn.
## The count is NOT incremented here - it's incremented when spawn is confirmed.
func on_sequence_completed(pet_type: int) -> void:
	print("PetSpawner: on_sequence_completed called with pet_type=%d" % pet_type)

	if not _is_valid_pet_type(pet_type):
		push_warning("PetSpawner: Invalid pet_type %d" % pet_type)
		return

	if _pet_counts.get(pet_type, 0) >= MAX_PET_PER_TYPE:
		print("PetSpawner: At max cap for pet_type=%d, blocking spawn" % pet_type)
		pet_spawn_blocked.emit(pet_type)
		return

	var column := randi() % GRID_COLS
	print("PetSpawner: Requesting pet spawn for pet_type=%d at column=%d" % [pet_type, column])
	# Don't increment count here - wait for confirm_spawn to be called
	pet_spawned.emit(pet_type, column)


## Called by BoardManager after successfully placing a pet tile.
## This is when the count is actually incremented and UI should update.
func confirm_spawn(pet_type: int) -> void:
	if not _is_valid_pet_type(pet_type):
		return
	_pet_counts[pet_type] = _pet_counts.get(pet_type, 0) + 1
	print("PetSpawner: Confirmed spawn, count for pet_type=%d is now %d" % [pet_type, _pet_counts[pet_type]])
	pet_spawn_confirmed.emit(pet_type)


## Called when a Pet tile is clicked/activated
func on_pet_activated(pet_type: int) -> void:
	if not _is_valid_pet_type(pet_type):
		return
	_pet_counts[pet_type] = maxi(_pet_counts.get(pet_type, 0) - 1, 0)
	pet_activated.emit(pet_type)


## Returns the current count for a pet type
func get_count(pet_type: int) -> int:
	return _pet_counts.get(pet_type, 0)


## Returns counts for all pet types
func get_all_counts() -> Dictionary:
	return _pet_counts.duplicate()


## Check if at max capacity for a pet type
func is_at_cap(pet_type: int) -> bool:
	return _pet_counts.get(pet_type, 0) >= MAX_PET_PER_TYPE


## Reset all counts (for new match)
func reset() -> void:
	_reset_counts()


func _is_valid_pet_type(pet_type: int) -> bool:
	return pet_type in [TileTypes.Type.BEAR_PET, TileTypes.Type.HAWK_PET, TileTypes.Type.SNAKE_PET]
