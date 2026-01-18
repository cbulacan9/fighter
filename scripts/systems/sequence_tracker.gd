class_name SequenceTracker
extends RefCounted

## Multi-tree combo tracker for the Hunter character.
## Multiple combo trees can be active simultaneously, each tracking progress
## toward a specific sequence pattern. Trees advance or die independently.

# === New Multi-Tree Signals ===

## Emitted when a new combo tree starts tracking a pattern
signal tree_started(pattern_name: String)

## Emitted when a tree advances (matched a tile in its sequence)
signal tree_progressed(pattern_name: String, progress: int, total: int)

## Emitted when a tree dies (didn't match required tile)
signal tree_died(pattern_name: String)

## Emitted when a sequence is fully completed - triggers pet spawn
signal sequence_completed(pet_type: int)

# === Legacy Signals (kept for backward compatibility) ===

## Emitted when a match is recorded and the sequence is still valid
signal sequence_progressed(current: Array, possible_completions: Array)

## Emitted when a completed sequence is banked (with current stack count)
signal sequence_banked(pattern: SequencePattern, stacks: int)

## Emitted when an invalid match breaks the current sequence
@warning_ignore("unused_signal")
signal sequence_broken()

## Emitted when a banked sequence is activated (consumed)
signal sequence_activated(pattern: SequencePattern, stacks: int)

## Signal for history updates (for UI) - now reports active tree info
signal history_updated(history: Array, highlighted_indices: Array)

# === Multi-Tree State ===

## Active combo trees - multiple can track different patterns simultaneously
var _active_trees: Array[ComboTree] = []

## Patterns this tracker is watching for
var _valid_patterns: Array[SequencePattern] = []

## Reference for all sequence states (legacy support)
var _sequence_states: Dictionary = {}  # {sequence_id: SequenceState}

## Completed sequences waiting for activation (legacy support for non-pet patterns)
var _banked_sequences: Dictionary = {}  # {sequence_id: SequenceState}


## Initializes the tracker with the patterns to watch for.
## Call this when setting up a character that uses sequences.
func setup(patterns: Array[SequencePattern]) -> void:
	_valid_patterns = patterns.duplicate()
	_active_trees.clear()
	_banked_sequences.clear()
	_sequence_states.clear()

	for pattern in patterns:
		_sequence_states[pattern.sequence_id] = SequenceState.new(pattern)


## Core algorithm: Process tile types from initiating (player-caused) matches.
## This is the main entry point for the multi-tree combo system.
##
## Algorithm:
## 1. For each active tree: advance if next tile matches, otherwise kill it
## 2. For each tile type: start new trees for patterns that begin with that type
func process_initiating_matches(tile_types: Array[int]) -> void:
	if tile_types.is_empty():
		return

	print("SEQUENCE: Processing initiating matches: %s" % _types_to_string(tile_types))

	# Step 1: Process existing trees (iterate over copy to allow removal)
	var trees_to_remove: Array[ComboTree] = []
	var completed_patterns: Array[SequencePattern] = []

	for tree: ComboTree in _active_trees.duplicate():
		var next_required: int = tree.next_required()

		if next_required in tile_types:
			# Tree advances
			tree.advance(next_required)
			print("SEQUENCE: Tree '%s' advanced to %d/%d" % [
				tree.pattern.display_name,
				tree.progress,
				tree.pattern.pattern.size()
			])
			tree_progressed.emit(
				tree.pattern.display_name,
				tree.progress,
				tree.pattern.pattern.size()
			)

			# Check for completion
			if tree.is_complete():
				print("SEQUENCE: === TREE COMPLETED: %s ===" % tree.pattern.display_name)
				completed_patterns.append(tree.pattern)
				trees_to_remove.append(tree)
		else:
			# Tree dies - required tile not in matches
			print("SEQUENCE: Tree '%s' died (needed %s, got %s)" % [
				tree.pattern.display_name,
				_get_type_name(next_required),
				_types_to_string(tile_types)
			])
			tree_died.emit(tree.pattern.display_name)
			trees_to_remove.append(tree)

	# Remove completed and dead trees
	for tree: ComboTree in trees_to_remove:
		var idx := _active_trees.find(tree)
		if idx >= 0:
			_active_trees.remove_at(idx)

	# Emit completion signals for completed patterns
	for pattern in completed_patterns:
		_emit_sequence_completed(pattern)

	# Step 2: Start new trees for patterns that begin with any tile in tile_types
	for tile_type in tile_types:
		for pattern in _valid_patterns:
			if pattern.pattern.is_empty():
				continue

			# Check if pattern starts with this tile type
			if pattern.pattern[0] == tile_type:
				# Check if we already have a tree for this pattern at progress=1
				var already_exists := false
				for existing_tree in _active_trees:
					if existing_tree.pattern.sequence_id == pattern.sequence_id and existing_tree.progress == 1:
						already_exists = true
						break

				if not already_exists:
					# Create new tree
					var new_tree := ComboTree.new(pattern)
					new_tree.advance(tile_type)
					_active_trees.append(new_tree)

					print("SEQUENCE: Started new tree '%s' (progress 1/%d)" % [
						pattern.display_name,
						pattern.pattern.size()
					])
					tree_started.emit(pattern.display_name)
					tree_progressed.emit(pattern.display_name, 1, pattern.pattern.size())

					# Check for immediate completion (single-tile patterns)
					if new_tree.is_complete():
						print("SEQUENCE: === IMMEDIATE COMPLETION: %s ===" % pattern.display_name)
						_emit_sequence_completed(pattern)
						var idx := _active_trees.find(new_tree)
						if idx >= 0:
							_active_trees.remove_at(idx)

	# Emit legacy signals for compatibility
	_emit_legacy_signals()


## Emits sequence_completed signal with pet_type from pattern
func _emit_sequence_completed(pattern: SequencePattern) -> void:
	var pet_type := pattern.pet_type if pattern.pet_type >= 0 else -1

	if pet_type >= 0:
		# New multi-tree path: emit pet type for spawning
		sequence_completed.emit(pet_type)
	else:
		# Legacy path: bank the sequence
		var state := _sequence_states.get(pattern.sequence_id) as SequenceState
		if state:
			state.mark_complete()
			state.add_stack()
			_banked_sequences[pattern.sequence_id] = state
			sequence_banked.emit(pattern, state.stacks)


## Emits legacy signals for backward compatibility with existing UI
func _emit_legacy_signals() -> void:
	# Build a representation of current state for legacy signals
	var current_tiles: Array = []
	var possible: Array[SequencePattern] = []

	# Get tiles from the most advanced tree (or all trees)
	for tree: ComboTree in _active_trees:
		for tile in tree.matched_tiles:
			if tile not in current_tiles:
				current_tiles.append(tile)

		# Any non-complete tree is a possible completion
		if not tree.is_complete():
			if tree.pattern not in possible:
				possible.append(tree.pattern)

	sequence_progressed.emit(current_tiles, possible)


## Returns all currently active combo trees (for UI display)
func get_active_trees() -> Array[ComboTree]:
	return _active_trees.duplicate()


## Returns tile types that would advance at least one active tree
func get_possible_next_tiles() -> Array[int]:
	var result: Array[int] = []

	for tree: ComboTree in _active_trees:
		var next: int = tree.next_required()
		if next >= 0 and next not in result:
			result.append(next)

	return result


## Returns true if any active tree is close to completion (legacy support)
func has_completable_sequence() -> bool:
	# Check active trees - if any is 1 tile away from completion
	for tree: ComboTree in _active_trees:
		if tree.pattern.pattern.size() - tree.progress <= 1:
			return true

	# Also check legacy banked sequences
	for seq_id in _banked_sequences.keys():
		var state := _banked_sequences[seq_id] as SequenceState
		if state and state.has_stacks():
			return true

	return false


## Returns all patterns that have banked stacks available (legacy support)
func get_banked_sequences() -> Array[SequencePattern]:
	var result: Array[SequencePattern] = []

	for seq_id in _banked_sequences.keys():
		var state := _banked_sequences[seq_id] as SequenceState
		if state and state.has_stacks():
			result.append(state.pattern)

	return result


## Returns the number of banked stacks for a specific pattern (legacy support)
func get_banked_stacks(pattern: SequencePattern) -> int:
	if not pattern:
		return 0

	var state := _banked_sequences.get(pattern.sequence_id) as SequenceState
	if state:
		return state.stacks
	return 0


## Activates (consumes) one stack of a banked sequence (legacy support)
func activate_sequence(pattern: SequencePattern) -> bool:
	if not pattern:
		return false

	var state := _banked_sequences.get(pattern.sequence_id) as SequenceState
	if not state or not state.has_stacks():
		return false

	var stacks_before := state.stacks
	state.consume_stack()

	if state.stacks <= 0:
		_banked_sequences.erase(pattern.sequence_id)
		state.reset_completion()

	sequence_activated.emit(pattern, stacks_before)
	return true


## Legacy method: Records a match of the given tile type
## Now wraps process_initiating_matches for backward compatibility
func record_match(tile_type: int) -> void:
	var types: Array[int] = [tile_type]
	process_initiating_matches(types)


## Clears all active trees and resets to initial state
func reset() -> void:
	_active_trees.clear()
	_banked_sequences.clear()

	for state in _sequence_states.values():
		if state is SequenceState:
			state.reset()

	print("SEQUENCE: Reset - all trees cleared")


## Returns all valid patterns this tracker is watching
func get_valid_patterns() -> Array[SequencePattern]:
	return _valid_patterns.duplicate()


## Returns the SequenceState for a specific pattern (legacy support)
func get_sequence_state(pattern: SequencePattern) -> SequenceState:
	if not pattern:
		return null
	return _sequence_states.get(pattern.sequence_id) as SequenceState


## Returns true if there are active trees (legacy: was "building sequence")
func is_building_sequence() -> bool:
	return not _active_trees.is_empty()


## Returns the progress (0.0 to 1.0) of the most advanced active tree
func get_completion_progress() -> float:
	if _active_trees.is_empty():
		return 0.0

	var max_progress := 0.0

	for tree: ComboTree in _active_trees:
		if tree.pattern.pattern.size() > 0:
			var tree_progress: float = float(tree.progress) / float(tree.pattern.pattern.size())
			max_progress = maxf(max_progress, tree_progress)

	return minf(max_progress, 1.0)


## Returns a copy of matched tiles from all active trees (legacy support)
func get_current_sequence() -> Array[int]:
	var result: Array[int] = []
	for tree: ComboTree in _active_trees:
		for tile in tree.matched_tiles:
			if tile not in result:
				result.append(tile)
	return result


## Returns match history equivalent (from active trees)
func get_match_history() -> Array[int]:
	return get_current_sequence()


## Returns the total matched tiles across all trees
func get_sequence_length() -> int:
	var count := 0
	for tree: ComboTree in _active_trees:
		count += tree.progress
	return count


## Clears all active trees (legacy: was "clear current")
func clear_current() -> void:
	_active_trees.clear()


# === Helper Methods ===

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
		TileTypes.Type.BEAR_PET: return "BEAR_PET"
		TileTypes.Type.HAWK_PET: return "HAWK_PET"
		TileTypes.Type.SNAKE_PET: return "SNAKE_PET"
		_: return "UNKNOWN(%d)" % tile_type


## Helper to convert array of types to readable string
func _types_to_string(types: Array[int]) -> String:
	var parts: Array[String] = []
	for t in types:
		parts.append(_get_type_name(t))
	return "[%s]" % ", ".join(parts)


## Returns a string representation for debugging
func _to_string() -> String:
	var tree_info: Array[String] = []
	for tree: ComboTree in _active_trees:
		tree_info.append("%s(%d/%d)" % [
			tree.pattern.display_name,
			tree.progress,
			tree.pattern.pattern.size()
		])

	var banked_count := 0
	for state in _banked_sequences.values():
		if state is SequenceState:
			banked_count += state.stacks

	return "SequenceTracker[trees=[%s], patterns=%d, banked=%d]" % [
		", ".join(tree_info),
		_valid_patterns.size(),
		banked_count
	]
