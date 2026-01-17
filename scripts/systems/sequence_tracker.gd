class_name SequenceTracker
extends RefCounted

## Emitted when a match is recorded and the sequence is still valid
signal sequence_progressed(current: Array, possible_completions: Array)

## Emitted when a sequence pattern is fully matched (before banking)
signal sequence_completed(pattern: SequencePattern)

## Emitted when a completed sequence is banked (with current stack count)
signal sequence_banked(pattern: SequencePattern, stacks: int)

## Emitted when an invalid match breaks the current sequence
signal sequence_broken()

## Emitted when a banked sequence is activated (consumed)
signal sequence_activated(pattern: SequencePattern, stacks: int)

## Currently matched tile types in order
var _current_sequence: Array[int] = []

## Patterns this tracker is watching for
var _valid_patterns: Array[SequencePattern] = []

## Completed sequences waiting for activation
var _banked_sequences: Dictionary = {}  # {sequence_id: SequenceState}

## Reference for all sequence states
var _sequence_states: Dictionary = {}  # {sequence_id: SequenceState}


## Initializes the tracker with the patterns to watch for
## Call this when setting up a character that uses sequences
func setup(patterns: Array[SequencePattern]) -> void:
	_valid_patterns = patterns.duplicate()
	_current_sequence.clear()
	_banked_sequences.clear()
	_sequence_states.clear()

	for pattern in patterns:
		_sequence_states[pattern.sequence_id] = SequenceState.new(pattern)


## Records a match of the given tile type and updates sequence state
## This should be called for each match during cascade resolution
func record_match(tile_type: int) -> void:
	# Add to current sequence
	_current_sequence.append(tile_type)

	# Check if still valid prefix for any pattern
	var still_valid := _has_valid_prefix()

	if not still_valid:
		# Whiff - break sequence
		_break_sequence()
		return

	# Check for completions
	_check_completions()

	# Emit progress with remaining possible completions
	var possible := _get_possible_completions()
	var current_copy: Array = []
	current_copy.assign(_current_sequence)
	var possible_copy: Array = []
	possible_copy.assign(possible)
	sequence_progressed.emit(current_copy, possible_copy)


## Checks if the current sequence is a valid prefix of any pattern
func _has_valid_prefix() -> bool:
	if _current_sequence.is_empty():
		return true

	for pattern in _valid_patterns:
		if pattern.matches_prefix(_current_sequence):
			return true

	return false


## Checks if the current sequence exactly matches any pattern
func _check_completions() -> void:
	for pattern in _valid_patterns:
		if pattern.is_complete_match(_current_sequence):
			_complete_sequence(pattern)
			return


## Called when a sequence pattern is fully matched
## Banks the sequence and resets for the next one
func _complete_sequence(pattern: SequencePattern) -> void:
	# Get or create the state for this pattern
	var state := _sequence_states.get(pattern.sequence_id) as SequenceState
	if not state:
		state = SequenceState.new(pattern)
		_sequence_states[pattern.sequence_id] = state

	# Mark as complete and add a stack
	state.mark_complete()
	state.add_stack()

	# Bank the sequence
	_banked_sequences[pattern.sequence_id] = state

	# Emit signals
	sequence_completed.emit(pattern)
	sequence_banked.emit(pattern, state.stacks)

	# Clear current sequence for next
	_current_sequence.clear()


## Called when the current sequence is broken by an invalid match
func _break_sequence() -> void:
	_current_sequence.clear()
	sequence_broken.emit()


## Returns all patterns that could still be completed from the current state
func _get_possible_completions() -> Array[SequencePattern]:
	var possible: Array[SequencePattern] = []

	for pattern in _valid_patterns:
		if pattern.matches_prefix(_current_sequence):
			possible.append(pattern)

	return possible


## Returns true if there is at least one banked sequence ready for activation
func has_completable_sequence() -> bool:
	for seq_id in _banked_sequences.keys():
		var state := _banked_sequences[seq_id] as SequenceState
		if state and state.has_stacks():
			return true
	return false


## Returns all patterns that have banked stacks available
func get_banked_sequences() -> Array[SequencePattern]:
	var result: Array[SequencePattern] = []

	for seq_id in _banked_sequences.keys():
		var state := _banked_sequences[seq_id] as SequenceState
		if state and state.has_stacks():
			result.append(state.pattern)

	return result


## Returns the number of banked stacks for a specific pattern
func get_banked_stacks(pattern: SequencePattern) -> int:
	if not pattern:
		return 0

	var state := _banked_sequences.get(pattern.sequence_id) as SequenceState
	if state:
		return state.stacks
	return 0


## Activates (consumes) one stack of a banked sequence
## Returns true if activation was successful
func activate_sequence(pattern: SequencePattern) -> bool:
	if not pattern:
		return false

	var state := _banked_sequences.get(pattern.sequence_id) as SequenceState
	if not state or not state.has_stacks():
		return false

	# Store the stack count before consumption for the signal
	var stacks_before := state.stacks

	# Consume one stack
	state.consume_stack()

	# Remove from banked if no stacks left
	if state.stacks <= 0:
		_banked_sequences.erase(pattern.sequence_id)
		state.reset_completion()

	# Emit the activated signal with stacks before consumption
	sequence_activated.emit(pattern, stacks_before)
	return true


## Returns a copy of the current sequence
func get_current_sequence() -> Array[int]:
	var result: Array[int] = []
	result.assign(_current_sequence)
	return result


## Returns the length of the current sequence
func get_sequence_length() -> int:
	return _current_sequence.size()


## Clears the current in-progress sequence without breaking
## (Does not emit sequence_broken signal)
func clear_current() -> void:
	_current_sequence.clear()


## Fully resets the tracker to initial state
## Clears current sequence, banked sequences, and all state
func reset() -> void:
	_current_sequence.clear()
	_banked_sequences.clear()

	for state in _sequence_states.values():
		if state is SequenceState:
			state.reset()


## Returns all valid patterns this tracker is watching
func get_valid_patterns() -> Array[SequencePattern]:
	return _valid_patterns.duplicate()


## Returns the SequenceState for a specific pattern
func get_sequence_state(pattern: SequencePattern) -> SequenceState:
	if not pattern:
		return null
	return _sequence_states.get(pattern.sequence_id) as SequenceState


## Returns true if the current sequence matches the start of any valid pattern
func is_building_sequence() -> bool:
	return not _current_sequence.is_empty() and _has_valid_prefix()


## Returns the progress (0.0 to 1.0) toward the nearest completable pattern
func get_completion_progress() -> float:
	if _current_sequence.is_empty():
		return 0.0

	var max_progress := 0.0

	for pattern in _valid_patterns:
		if pattern.matches_prefix(_current_sequence):
			var progress := float(_current_sequence.size()) / float(pattern.get_pattern_length())
			max_progress = maxf(max_progress, progress)

	return minf(max_progress, 1.0)


## Returns a string representation for debugging
func to_string() -> String:
	var current_str := "["
	for i in range(_current_sequence.size()):
		if i > 0:
			current_str += ", "
		current_str += str(_current_sequence[i])
	current_str += "]"

	var banked_count := 0
	for state in _banked_sequences.values():
		if state is SequenceState:
			banked_count += state.stacks

	return "SequenceTracker[current=%s, patterns=%d, banked=%d]" % [
		current_str,
		_valid_patterns.size(),
		banked_count
	]
