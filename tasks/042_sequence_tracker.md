# Task 042: Sequence Tracker

## Objective
Implement the SequenceTracker system that monitors match order and detects sequence completions.

## Dependencies
- Task 041 (Sequence Pattern Data)
- Task 009 (Match Detector)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Combo Sequences section
- `/docs/CHARACTERS.md` → Hunter combo system

## Deliverables

### 1. Create SequenceTracker
Create `/scripts/systems/sequence_tracker.gd`:

```gdscript
class_name SequenceTracker extends RefCounted

signal sequence_progressed(current: Array, possible_completions: Array)
signal sequence_completed(pattern: SequencePattern)
signal sequence_banked(pattern: SequencePattern, stacks: int)
signal sequence_broken()
signal sequence_activated(pattern: SequencePattern, stacks: int)

## Currently matched tile types in order
var _current_sequence: Array[TileTypes.TileType] = []

## Patterns this tracker is watching for
var _valid_patterns: Array[SequencePattern] = []

## Completed sequences waiting for activation
var _banked_sequences: Dictionary = {}  # {sequence_id: SequenceState}

## Reference for sequence state
var _sequence_states: Dictionary = {}  # {sequence_id: SequenceState}

func setup(patterns: Array[SequencePattern]) -> void:
    _valid_patterns = patterns
    _current_sequence.clear()
    _banked_sequences.clear()

    for pattern in patterns:
        _sequence_states[pattern.sequence_id] = SequenceState.new(pattern)

func record_match(tile_type: TileTypes.TileType) -> void:
    # Add to current sequence
    _current_sequence.append(tile_type)

    # Check if still valid prefix for any pattern
    var still_valid = _has_valid_prefix()

    if not still_valid:
        # Whiff - break sequence
        _break_sequence()
        return

    # Check for completions
    _check_completions()

    # Emit progress
    var possible = _get_possible_completions()
    sequence_progressed.emit(_current_sequence.duplicate(), possible)

func _has_valid_prefix() -> bool:
    for pattern in _valid_patterns:
        if pattern.matches_prefix(_current_sequence):
            return true
    return false

func _check_completions() -> void:
    for pattern in _valid_patterns:
        if pattern.is_complete_match(_current_sequence):
            _complete_sequence(pattern)
            return

func _complete_sequence(pattern: SequencePattern) -> void:
    # Bank the sequence
    var state = _sequence_states.get(pattern.sequence_id) as SequenceState
    if state:
        state.is_complete = true
        state.add_stack()
        _banked_sequences[pattern.sequence_id] = state

    sequence_completed.emit(pattern)
    sequence_banked.emit(pattern, state.stacks if state else 1)

    # Clear current sequence for next
    _current_sequence.clear()

func _break_sequence() -> void:
    _current_sequence.clear()
    sequence_broken.emit()

func _get_possible_completions() -> Array[SequencePattern]:
    var possible: Array[SequencePattern] = []
    for pattern in _valid_patterns:
        if pattern.matches_prefix(_current_sequence):
            possible.append(pattern)
    return possible

func has_completable_sequence() -> bool:
    return not _banked_sequences.is_empty()

func get_banked_sequences() -> Array[SequencePattern]:
    var result: Array[SequencePattern] = []
    for seq_id in _banked_sequences.keys():
        var state = _banked_sequences[seq_id] as SequenceState
        if state and state.stacks > 0:
            result.append(state.pattern)
    return result

func get_banked_stacks(pattern: SequencePattern) -> int:
    var state = _banked_sequences.get(pattern.sequence_id) as SequenceState
    if state:
        return state.stacks
    return 0

func activate_sequence(pattern: SequencePattern) -> bool:
    var state = _banked_sequences.get(pattern.sequence_id) as SequenceState
    if state and state.stacks > 0:
        var stacks = state.stacks
        state.consume_stack()

        if state.stacks <= 0:
            _banked_sequences.erase(pattern.sequence_id)

        sequence_activated.emit(pattern, stacks)
        return true

    return false

func get_current_sequence() -> Array[TileTypes.TileType]:
    return _current_sequence.duplicate()

func get_sequence_length() -> int:
    return _current_sequence.size()

func clear_current() -> void:
    _current_sequence.clear()

func reset() -> void:
    _current_sequence.clear()
    _banked_sequences.clear()
    for state in _sequence_states.values():
        state.reset()
```

### 2. Integrate with BoardManager
Modify `/scripts/managers/board_manager.gd`:

```gdscript
# Add to BoardManager

var sequence_tracker: SequenceTracker

signal sequence_progressed(current: Array, possible: Array)
signal sequence_completed(pattern: SequencePattern)
signal sequence_broken()

func _setup_sequence_tracker(patterns: Array[SequencePattern]) -> void:
    sequence_tracker = SequenceTracker.new()
    sequence_tracker.setup(patterns)

    sequence_tracker.sequence_progressed.connect(_on_sequence_progressed)
    sequence_tracker.sequence_completed.connect(_on_sequence_completed)
    sequence_tracker.sequence_broken.connect(_on_sequence_broken)
    sequence_tracker.sequence_activated.connect(_on_sequence_activated)

    # Connect to click condition checker
    if click_condition_checker:
        click_condition_checker.set_sequence_tracker(sequence_tracker)

func _on_matches_resolved(result: CascadeHandler.CascadeResult) -> void:
    # ... existing match processing ...

    # Record matches for sequence tracking
    if sequence_tracker:
        for match_result in result.all_matches:
            # Get tile type from first position
            var pos = match_result.positions[0]
            var tile = _grid.get_tile(pos.x, pos.y)
            if tile and tile.tile_data:
                sequence_tracker.record_match(tile.tile_data.tile_type)

func _on_sequence_progressed(current: Array, possible: Array) -> void:
    sequence_progressed.emit(current, possible)

func _on_sequence_completed(pattern: SequencePattern) -> void:
    sequence_completed.emit(pattern)
    # Update Pet tile clickability
    _update_clickable_highlights()

func _on_sequence_broken() -> void:
    sequence_broken.emit()

func _on_sequence_activated(pattern: SequencePattern, stacks: int) -> void:
    # Process the sequence effects
    var fighter = _get_owner_fighter()
    var combat_manager = _get_combat_manager()

    if combat_manager and pattern.on_complete_effect:
        # Apply offensive effect with stack multiplier if ultimate is active
        combat_manager.effect_processor.process_effect(
            pattern.on_complete_effect,
            fighter,
            0  # No match count for sequence effects
        )

    if combat_manager and pattern.self_buff_effect:
        # Apply self-buff
        combat_manager.effect_processor.process_effect(
            pattern.self_buff_effect,
            fighter,
            0
        )
```

### 3. Pet Tile Click Handler
When Pet tile is clicked, activate banked sequence:

```gdscript
# In BoardManager._on_tile_clicked or _activate_tile

func _activate_tile(tile: Tile) -> void:
    var data = tile.tile_data as TileData

    # Check if this is a sequence terminator (Pet)
    if sequence_tracker and data.tile_type == _get_pet_tile_type():
        var banked = sequence_tracker.get_banked_sequences()
        if banked.size() > 0:
            # Activate first banked sequence
            # Could also show UI to choose which sequence
            sequence_tracker.activate_sequence(banked[0])
            return

    # Regular click activation
    # ...
```

### 4. Handle Match Order Correctly
Ensure matches are recorded in the correct order during cascades:

```gdscript
# The cascade handler should process matches in order
# Each match in the cascade should be recorded separately
# This is important for sequence tracking

func _process_cascade_matches(matches: Array[MatchResult]) -> void:
    for match_result in matches:
        # Record for sequence (use dominant tile type)
        if sequence_tracker:
            var tile_type = match_result.tile_type
            sequence_tracker.record_match(tile_type)

        # Process match effects...
```

## Acceptance Criteria
- [ ] SequenceTracker tracks match order
- [ ] Pattern matching detects valid sequences
- [ ] Whiff correctly breaks sequence
- [ ] Completed sequences can be banked
- [ ] Stacking works up to max_stacks
- [ ] Activation consumes stacks
- [ ] Pet tile clickable when sequence complete
- [ ] Integration with BoardManager complete
- [ ] All signals emit correctly
