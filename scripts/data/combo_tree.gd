class_name ComboTree
extends RefCounted

## Tracks progress through a single combo sequence pattern.
## Multiple ComboTrees can be active simultaneously in the multi-tree system.

var pattern: SequencePattern
var progress: int = 0
var matched_tiles: Array[int] = []


func _init(p_pattern: SequencePattern = null) -> void:
	pattern = p_pattern
	progress = 0
	matched_tiles = []


## Returns the next required tile type to advance this tree.
## Returns -1 if the pattern is complete or invalid.
func next_required() -> int:
	if progress >= pattern.pattern.size():
		return -1
	return pattern.pattern[progress]


## Returns true if the combo tree has matched all required tiles.
func is_complete() -> bool:
	return progress >= pattern.pattern.size()


## Advances the tree by recording a matched tile type.
func advance(tile_type: int) -> void:
	matched_tiles.append(tile_type)
	progress += 1


## Resets the tree to its initial state.
func reset() -> void:
	progress = 0
	matched_tiles.clear()


func _to_string() -> String:
	return "ComboTree[%s, progress=%d/%d]" % [
		pattern.display_name if pattern else "null",
		progress,
		pattern.pattern.size() if pattern else 0
	]
