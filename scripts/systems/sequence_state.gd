class_name SequenceState
extends RefCounted

## The sequence pattern this state tracks
var pattern: SequencePattern

## Whether the sequence pattern has been fully matched (ready for terminator)
var is_complete: bool = false

## Current number of stacked completions
var stacks: int = 0


func _init(seq_pattern: SequencePattern = null) -> void:
	pattern = seq_pattern
	is_complete = false
	stacks = 0


## Adds a stack when the sequence is completed and banked
## Respects max_stacks limit from the pattern
func add_stack() -> void:
	if pattern:
		stacks = mini(stacks + 1, pattern.max_stacks)
	else:
		stacks += 1


## Attempts to consume a stack for ability activation
## Returns true if a stack was consumed, false if no stacks available
func consume_stack() -> bool:
	if stacks > 0:
		stacks -= 1
		return true
	return false


## Consumes all stacks and returns the number consumed
## Useful for abilities that scale with stack count
func consume_all_stacks() -> int:
	var consumed := stacks
	stacks = 0
	return consumed


## Returns true if at maximum stacks
func is_max_stacks() -> bool:
	if pattern:
		return stacks >= pattern.max_stacks
	return false


## Returns true if there are any stacks available
func has_stacks() -> bool:
	return stacks > 0


## Returns the current stack count
func get_stacks() -> int:
	return stacks


## Returns remaining stacks until max
func stacks_until_max() -> int:
	if pattern:
		return pattern.max_stacks - stacks
	return 0


## Marks the sequence as complete (pattern matched, awaiting terminator)
func mark_complete() -> void:
	is_complete = true


## Resets the completion state (but not stacks)
func reset_completion() -> void:
	is_complete = false


## Fully resets the state (completion and stacks)
func reset() -> void:
	is_complete = false
	stacks = 0


## Returns a string representation for debugging
func _to_string() -> String:
	var pattern_name := "None"
	if pattern:
		pattern_name = pattern.display_name
	return "SequenceState[%s]: complete=%s, stacks=%d" % [pattern_name, is_complete, stacks]
