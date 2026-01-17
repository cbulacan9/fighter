class_name SequenceTracker
extends RefCounted

## Emitted when a match is recorded and the sequence is still valid
signal sequence_progressed(current: Array, possible_completions: Array)

## Emitted when a sequence pattern is fully matched (before banking)
signal sequence_completed(pattern: SequencePattern)

## Emitted when a completed sequence is banked (with current stack count)
signal sequence_banked(pattern: SequencePattern, stacks: int)

## Emitted when an invalid match breaks the current sequence
@warning_ignore("unused_signal")
signal sequence_broken()

## Emitted when a banked sequence is activated (consumed)
signal sequence_activated(pattern: SequencePattern, stacks: int)

## Match history - last N tile types matched
var _match_history: Array[int] = []
const MAX_HISTORY_SIZE: int = 10

## Patterns this tracker is watching for
var _valid_patterns: Array[SequencePattern] = []

## Completed sequences waiting for activation
var _banked_sequences: Dictionary = {}  # {sequence_id: SequenceState}

## Reference for all sequence states
var _sequence_states: Dictionary = {}  # {sequence_id: SequenceState}

## Signal for history updates (for UI)
signal history_updated(history: Array, highlighted_indices: Array)


## Initializes the tracker with the patterns to watch for
## Call this when setting up a character that uses sequences
func setup(patterns: Array[SequencePattern]) -> void:
	_valid_patterns = patterns.duplicate()
	_match_history.clear()
	_banked_sequences.clear()
	_sequence_states.clear()

	for pattern in patterns:
		_sequence_states[pattern.sequence_id] = SequenceState.new(pattern)


## Records a match of the given tile type and updates sequence state
## Uses history-based approach - patterns are detected in recent match history
func record_match(tile_type: int) -> void:
	var type_name := _get_type_name(tile_type)
	print("SEQUENCE: Recording match - %s (type %d)" % [type_name, tile_type])

	# Add to history
	_match_history.append(tile_type)

	# Trim history to max size
	while _match_history.size() > MAX_HISTORY_SIZE:
		_match_history.pop_front()

	print("SEQUENCE: History now: %s" % _history_to_string())

	# Check for pattern completions in the history
	var completed_pattern := _check_pattern_in_history()
	var highlighted_indices: Array[int] = []

	if completed_pattern:
		print("SEQUENCE: === PATTERN FOUND: %s ===" % completed_pattern.display_name)
		highlighted_indices = _get_pattern_indices(completed_pattern)
		_complete_sequence(completed_pattern)

	# Emit history update for UI
	var history_copy: Array = []
	history_copy.assign(_match_history)
	var indices_copy: Array = []
	indices_copy.assign(highlighted_indices)
	history_updated.emit(history_copy, indices_copy)

	# Also emit progress for backwards compatibility
	var possible := _get_possible_completions_from_history()
	sequence_progressed.emit(history_copy, possible)


## Helper to get tile type name for debug
func _get_type_name(tile_type: int) -> String:
	match tile_type:
		TileTypes.Type.SWORD: return "SWORD"
		TileTypes.Type.SHIELD: return "SHIELD"
		TileTypes.Type.LIGHTNING: return "LIGHTNING"
		TileTypes.Type.FILLER: return "FILLER"
		TileTypes.Type.PET: return "PET"
		TileTypes.Type.POTION: return "POTION"
		TileTypes.Type.MANA: return "MANA"
		_: return "UNKNOWN(%d)" % tile_type


## Helper to convert history to readable string
func _history_to_string() -> String:
	var parts: Array[String] = []
	for t in _match_history:
		parts.append(_get_type_name(t))
	return "[%s]" % ", ".join(parts)


## Checks if any pattern is completed at the END of the match history
## Returns the completed pattern or null
func _check_pattern_in_history() -> SequencePattern:
	if _match_history.is_empty():
		return null

	# Check each pattern - look for it at the end of history
	for pattern in _valid_patterns:
		var pattern_tiles := pattern.pattern
		var pattern_len := pattern_tiles.size()

		if _match_history.size() >= pattern_len:
			# Check if last N tiles match the pattern
			var matches := true
			for i in range(pattern_len):
				var history_idx := _match_history.size() - pattern_len + i
				if _match_history[history_idx] != pattern_tiles[i]:
					matches = false
					break

			if matches:
				return pattern

	return null


## Returns the indices in history that match the given pattern (at the end)
func _get_pattern_indices(pattern: SequencePattern) -> Array[int]:
	var indices: Array[int] = []
	var pattern_len := pattern.pattern.size()
	var start_idx := _match_history.size() - pattern_len

	for i in range(pattern_len):
		indices.append(start_idx + i)

	return indices


## Returns patterns that could be completed with more matches
func _get_possible_completions_from_history() -> Array[SequencePattern]:
	var possible: Array[SequencePattern] = []

	# For each pattern, check if the end of history is a prefix
	for pattern in _valid_patterns:
		var pattern_tiles := pattern.pattern

		# Check various suffix lengths of history against pattern prefix
		for suffix_len in range(1, mini(pattern_tiles.size(), _match_history.size() + 1)):
			var history_suffix: Array[int] = []
			for i in range(suffix_len):
				history_suffix.append(_match_history[_match_history.size() - suffix_len + i])

			# Check if this suffix matches the start of the pattern
			var matches := true
			for i in range(suffix_len):
				if history_suffix[i] != pattern_tiles[i]:
					matches = false
					break

			if matches and suffix_len < pattern_tiles.size():
				if not possible.has(pattern):
					possible.append(pattern)
				break

	return possible


## Called when a sequence pattern is fully matched
## Banks the sequence for later activation
func _complete_sequence(pattern: SequencePattern) -> void:
	print("SEQUENCE: === COMPLETED %s ===" % pattern.display_name)

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
	print("SEQUENCE: Banked! Total stacks: %d" % state.stacks)

	# Emit signals
	sequence_completed.emit(pattern)
	sequence_banked.emit(pattern, state.stacks)

	# Note: We DON'T clear the history - it persists and shows what was matched


## Returns all patterns that could still be completed from the current state
## (For backwards compatibility - uses history-based detection now)
func _get_possible_completions() -> Array[SequencePattern]:
	return _get_possible_completions_from_history()


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


## Returns a copy of the match history (last N tiles matched)
func get_current_sequence() -> Array[int]:
	var result: Array[int] = []
	result.assign(_match_history)
	return result


## Returns the match history
func get_match_history() -> Array[int]:
	var result: Array[int] = []
	result.assign(_match_history)
	return result


## Returns the length of the match history
func get_sequence_length() -> int:
	return _match_history.size()


## Clears the match history
func clear_current() -> void:
	_match_history.clear()


## Fully resets the tracker to initial state
## Clears match history, banked sequences, and all state
func reset() -> void:
	_match_history.clear()
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


## Returns true if there are matches in the history
func is_building_sequence() -> bool:
	return not _match_history.is_empty()


## Returns the progress (0.0 to 1.0) toward the nearest completable pattern
func get_completion_progress() -> float:
	if _match_history.is_empty():
		return 0.0

	var max_progress := 0.0

	for pattern in _valid_patterns:
		var pattern_tiles := pattern.pattern
		# Check how much of the pattern is matched at the end of history
		for match_len in range(1, mini(pattern_tiles.size(), _match_history.size()) + 1):
			var matches := true
			for i in range(match_len):
				var history_idx := _match_history.size() - match_len + i
				if _match_history[history_idx] != pattern_tiles[i]:
					matches = false
					break
			if matches:
				var progress := float(match_len) / float(pattern.get_pattern_length())
				max_progress = maxf(max_progress, progress)

	return minf(max_progress, 1.0)


## Returns a string representation for debugging
func _to_string() -> String:
	var history_str := _history_to_string()

	var banked_count := 0
	for state in _banked_sequences.values():
		if state is SequenceState:
			banked_count += state.stacks

	return "SequenceTracker[history=%s, patterns=%d, banked=%d]" % [
		history_str,
		_valid_patterns.size(),
		banked_count
	]
