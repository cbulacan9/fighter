# Task 044: Sequence System Tests

## Objective
Create test harness to validate sequence tracking behavior in isolation.

## Dependencies
- Task 042 (Sequence Tracker)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Testing approach

## Deliverables

### 1. Create Test Scene
Create `/test/test_sequences.tscn`

### 2. Create Test Runner Script
Create `/test/test_sequences.gd`:

```gdscript
extends Node

var sequence_tracker: SequenceTracker
var test_results: Array[String] = []
var tests_passed: int = 0
var tests_failed: int = 0

# Test patterns
var bear_pattern: SequencePattern
var hawk_pattern: SequencePattern
var snake_pattern: SequencePattern

func _ready() -> void:
    _setup()
    call_deferred("_run_all_tests")

func _setup() -> void:
    # Create test patterns
    bear_pattern = _create_bear_pattern()
    hawk_pattern = _create_hawk_pattern()
    snake_pattern = _create_snake_pattern()

func _run_all_tests() -> void:
    print("=== Sequence System Tests ===")

    # Pattern matching tests
    _test_prefix_match()
    _test_full_match()
    _test_no_match()

    # Sequence tracking tests
    _test_record_single_match()
    _test_record_valid_sequence()
    _test_whiff_breaks_sequence()
    _test_sequence_completion()

    # Banking tests
    _test_bank_sequence()
    _test_bank_multiple_stacks()
    _test_max_stacks()

    # Activation tests
    _test_activate_banked()
    _test_activate_consumes_stack()
    _test_has_completable_sequence()

    # Multi-pattern tests
    _test_multiple_patterns()
    _test_overlapping_prefixes()

    # Signal tests
    _test_progress_signal()
    _test_completed_signal()
    _test_broken_signal()

    # Reset tests
    _test_reset_clears_all()

    # Print results
    print("=== Results ===")
    print("Passed: %d" % tests_passed)
    print("Failed: %d" % tests_failed)
    for result in test_results:
        print(result)

func _reset_tracker() -> void:
    sequence_tracker = SequenceTracker.new()
    sequence_tracker.setup([bear_pattern, hawk_pattern, snake_pattern])

# === Pattern Matching Tests ===

func _test_prefix_match() -> void:
    var seq: Array[TileTypes.TileType] = [TileTypes.TileType.SWORD]

    if bear_pattern.matches_prefix(seq):
        _pass("Prefix match - single tile")
    else:
        _fail("Prefix match - should match SWORD prefix for bear")

func _test_full_match() -> void:
    var seq: Array[TileTypes.TileType] = [
        TileTypes.TileType.SWORD,
        TileTypes.TileType.SHIELD,
        TileTypes.TileType.SHIELD
    ]

    if bear_pattern.is_complete_match(seq):
        _pass("Full match - bear pattern")
    else:
        _fail("Full match - should match bear pattern")

func _test_no_match() -> void:
    var seq: Array[TileTypes.TileType] = [
        TileTypes.TileType.POTION,
        TileTypes.TileType.POTION
    ]

    if not bear_pattern.matches_prefix(seq):
        _pass("No match - invalid prefix")
    else:
        _fail("No match - should not match potion prefix for bear")

# === Sequence Tracking Tests ===

func _test_record_single_match() -> void:
    _reset_tracker()
    sequence_tracker.record_match(TileTypes.TileType.SWORD)

    var current = sequence_tracker.get_current_sequence()
    if current.size() == 1 and current[0] == TileTypes.TileType.SWORD:
        _pass("Record single match")
    else:
        _fail("Record single match - sequence not recorded")

func _test_record_valid_sequence() -> void:
    _reset_tracker()
    sequence_tracker.record_match(TileTypes.TileType.SWORD)
    sequence_tracker.record_match(TileTypes.TileType.SHIELD)

    var current = sequence_tracker.get_current_sequence()
    if current.size() == 2:
        _pass("Record valid sequence")
    else:
        _fail("Record valid sequence - wrong length: %d" % current.size())

func _test_whiff_breaks_sequence() -> void:
    _reset_tracker()
    sequence_tracker.record_match(TileTypes.TileType.SWORD)
    sequence_tracker.record_match(TileTypes.TileType.POTION)  # Invalid for any pattern

    var current = sequence_tracker.get_current_sequence()
    if current.is_empty():
        _pass("Whiff breaks sequence")
    else:
        _fail("Whiff breaks sequence - sequence not cleared")

func _test_sequence_completion() -> void:
    _reset_tracker()
    # Complete bear: SWORD → SHIELD → SHIELD
    sequence_tracker.record_match(TileTypes.TileType.SWORD)
    sequence_tracker.record_match(TileTypes.TileType.SHIELD)
    sequence_tracker.record_match(TileTypes.TileType.SHIELD)

    if sequence_tracker.has_completable_sequence():
        _pass("Sequence completion detected")
    else:
        _fail("Sequence completion - not detected")

# === Banking Tests ===

func _test_bank_sequence() -> void:
    _reset_tracker()
    _complete_bear_sequence()

    var banked = sequence_tracker.get_banked_sequences()
    if banked.size() == 1 and banked[0].sequence_id == "bear":
        _pass("Bank sequence")
    else:
        _fail("Bank sequence - not banked correctly")

func _test_bank_multiple_stacks() -> void:
    _reset_tracker()
    _complete_bear_sequence()
    _complete_bear_sequence()

    var stacks = sequence_tracker.get_banked_stacks(bear_pattern)
    if stacks == 2:
        _pass("Bank multiple stacks")
    else:
        _fail("Bank multiple stacks - expected 2, got %d" % stacks)

func _test_max_stacks() -> void:
    _reset_tracker()
    # Complete more than max_stacks
    for i in range(5):
        _complete_bear_sequence()

    var stacks = sequence_tracker.get_banked_stacks(bear_pattern)
    if stacks == bear_pattern.max_stacks:
        _pass("Max stacks cap")
    else:
        _fail("Max stacks - expected %d, got %d" % [bear_pattern.max_stacks, stacks])

# === Activation Tests ===

func _test_activate_banked() -> void:
    _reset_tracker()
    _complete_bear_sequence()

    var success = sequence_tracker.activate_sequence(bear_pattern)
    if success:
        _pass("Activate banked sequence")
    else:
        _fail("Activate banked - failed")

func _test_activate_consumes_stack() -> void:
    _reset_tracker()
    _complete_bear_sequence()
    _complete_bear_sequence()

    sequence_tracker.activate_sequence(bear_pattern)
    var stacks = sequence_tracker.get_banked_stacks(bear_pattern)

    if stacks == 1:
        _pass("Activate consumes stack")
    else:
        _fail("Activate consumes stack - expected 1, got %d" % stacks)

func _test_has_completable_sequence() -> void:
    _reset_tracker()

    var before = sequence_tracker.has_completable_sequence()
    _complete_bear_sequence()
    var after = sequence_tracker.has_completable_sequence()

    if not before and after:
        _pass("Has completable sequence")
    else:
        _fail("Has completable - before=%s, after=%s" % [before, after])

# === Multi-pattern Tests ===

func _test_multiple_patterns() -> void:
    _reset_tracker()

    # Complete hawk: SHIELD → STUN
    sequence_tracker.record_match(TileTypes.TileType.SHIELD)
    sequence_tracker.record_match(TileTypes.TileType.LIGHTNING)

    var banked = sequence_tracker.get_banked_sequences()
    var has_hawk = false
    for p in banked:
        if p.sequence_id == "hawk":
            has_hawk = true

    if has_hawk:
        _pass("Multiple patterns - hawk completed")
    else:
        _fail("Multiple patterns - hawk not detected")

func _test_overlapping_prefixes() -> void:
    _reset_tracker()

    # SHIELD could start hawk or be part of bear
    sequence_tracker.record_match(TileTypes.TileType.SHIELD)
    var possible = sequence_tracker._get_possible_completions()

    # Should still be valid for patterns that accept SHIELD
    if possible.size() > 0:
        _pass("Overlapping prefixes handled")
    else:
        _fail("Overlapping prefixes - no possibilities found")

# === Signal Tests ===

func _test_progress_signal() -> void:
    _reset_tracker()
    var signal_received = false

    sequence_tracker.sequence_progressed.connect(func(cur, pos):
        signal_received = true
    )

    sequence_tracker.record_match(TileTypes.TileType.SWORD)

    if signal_received:
        _pass("Progress signal emitted")
    else:
        _fail("Progress signal - not received")

func _test_completed_signal() -> void:
    _reset_tracker()
    var signal_received = false
    var received_pattern: SequencePattern = null

    sequence_tracker.sequence_completed.connect(func(pattern):
        signal_received = true
        received_pattern = pattern
    )

    _complete_bear_sequence()

    if signal_received and received_pattern == bear_pattern:
        _pass("Completed signal emitted")
    else:
        _fail("Completed signal - not received correctly")

func _test_broken_signal() -> void:
    _reset_tracker()
    var signal_received = false

    sequence_tracker.sequence_broken.connect(func():
        signal_received = true
    )

    sequence_tracker.record_match(TileTypes.TileType.SWORD)
    sequence_tracker.record_match(TileTypes.TileType.POTION)  # Whiff

    if signal_received:
        _pass("Broken signal emitted")
    else:
        _fail("Broken signal - not received")

# === Reset Tests ===

func _test_reset_clears_all() -> void:
    _reset_tracker()
    _complete_bear_sequence()
    sequence_tracker.record_match(TileTypes.TileType.SHIELD)

    sequence_tracker.reset()

    var current = sequence_tracker.get_current_sequence()
    var banked = sequence_tracker.get_banked_sequences()

    if current.is_empty() and banked.is_empty():
        _pass("Reset clears all")
    else:
        _fail("Reset - current=%d, banked=%d" % [current.size(), banked.size()])

# === Helper Methods ===

func _complete_bear_sequence() -> void:
    sequence_tracker.record_match(TileTypes.TileType.SWORD)
    sequence_tracker.record_match(TileTypes.TileType.SHIELD)
    sequence_tracker.record_match(TileTypes.TileType.SHIELD)

func _pass(test_name: String) -> void:
    tests_passed += 1
    test_results.append("[PASS] %s" % test_name)
    print("[PASS] %s" % test_name)

func _fail(message: String) -> void:
    tests_failed += 1
    test_results.append("[FAIL] %s" % message)
    print("[FAIL] %s" % message)

func _create_bear_pattern() -> SequencePattern:
    var pattern = SequencePattern.new()
    pattern.sequence_id = "bear"
    pattern.display_name = "Bear"
    pattern.pattern = [
        TileTypes.TileType.SWORD,
        TileTypes.TileType.SHIELD,
        TileTypes.TileType.SHIELD
    ]
    pattern.terminator = TileTypes.TileType.FILLER  # Pet placeholder
    pattern.max_stacks = 3
    return pattern

func _create_hawk_pattern() -> SequencePattern:
    var pattern = SequencePattern.new()
    pattern.sequence_id = "hawk"
    pattern.display_name = "Hawk"
    pattern.pattern = [
        TileTypes.TileType.SHIELD,
        TileTypes.TileType.LIGHTNING
    ]
    pattern.terminator = TileTypes.TileType.FILLER
    pattern.max_stacks = 3
    return pattern

func _create_snake_pattern() -> SequencePattern:
    var pattern = SequencePattern.new()
    pattern.sequence_id = "snake"
    pattern.display_name = "Snake"
    pattern.pattern = [
        TileTypes.TileType.LIGHTNING,
        TileTypes.TileType.SWORD,
        TileTypes.TileType.SHIELD
    ]
    pattern.terminator = TileTypes.TileType.FILLER
    pattern.max_stacks = 3
    return pattern
```

## Acceptance Criteria
- [ ] Test scene runs without errors
- [ ] All pattern matching tests pass
- [ ] All sequence tracking tests pass
- [ ] All banking tests pass
- [ ] All activation tests pass
- [ ] All signal tests pass
- [ ] Reset tests pass
- [ ] Tests run in isolation
