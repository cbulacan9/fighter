extends Node
## Test harness for SequenceTracker and SequencePattern validation
##
## This script provides comprehensive test coverage for the sequence system,
## including pattern matching, sequence tracking, banking, activation, and signals.


## Test result counters
var _tests_passed: int = 0
var _tests_failed: int = 0
var _tests_run: int = 0

## Signal tracking for signal tests
var _signal_received: bool = false
var _last_signal_data: Dictionary = {}

## Tracker instance used across tests
var _tracker: SequenceTracker


func _ready() -> void:
	print("\n========================================")
	print("SEQUENCE SYSTEM TEST SUITE")
	print("========================================\n")

	_run_all_tests()

	print("\n========================================")
	print("TEST RESULTS")
	print("========================================")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)
	print("Total:  %d" % _tests_run)
	print("========================================\n")

	if _tests_failed == 0:
		print("[SUCCESS] All tests passed!")
	else:
		print("[FAILURE] Some tests failed.")


func _run_all_tests() -> void:
	print("--- Pattern Matching Tests ---")
	_test_prefix_match()
	_test_full_match()
	_test_no_match()

	print("\n--- Sequence Tracking Tests ---")
	_test_record_single_match()
	_test_record_valid_sequence()
	_test_whiff_breaks_sequence()
	_test_sequence_completion()

	print("\n--- Banking Tests ---")
	_test_bank_sequence()
	_test_bank_multiple_stacks()
	_test_max_stacks()

	print("\n--- Activation Tests ---")
	_test_activate_banked()
	_test_activate_consumes_stack()
	_test_has_completable_sequence()

	print("\n--- Multi-Pattern Tests ---")
	_test_multiple_patterns()
	_test_overlapping_prefixes()

	print("\n--- Signal Tests ---")
	_test_progress_signal()
	_test_completed_signal()
	_test_broken_signal()

	print("\n--- Reset Tests ---")
	_test_reset_clears_all()


#region Helper Methods

## Creates a fresh SequenceTracker with test patterns
func _reset_tracker() -> void:
	_tracker = SequenceTracker.new()
	var patterns: Array[SequencePattern] = [
		_create_bear_pattern(),
		_create_hawk_pattern(),
		_create_snake_pattern()
	]
	_tracker.setup(patterns)
	_disconnect_all_signals()


## Disconnects all signal connections from the tracker
func _disconnect_all_signals() -> void:
	if _tracker.sequence_progressed.is_connected(_on_sequence_progressed):
		_tracker.sequence_progressed.disconnect(_on_sequence_progressed)
	if _tracker.sequence_completed.is_connected(_on_sequence_completed):
		_tracker.sequence_completed.disconnect(_on_sequence_completed)
	if _tracker.sequence_broken.is_connected(_on_sequence_broken):
		_tracker.sequence_broken.disconnect(_on_sequence_broken)
	if _tracker.sequence_banked.is_connected(_on_sequence_banked):
		_tracker.sequence_banked.disconnect(_on_sequence_banked)
	if _tracker.sequence_activated.is_connected(_on_sequence_activated):
		_tracker.sequence_activated.disconnect(_on_sequence_activated)


## Records the Bear sequence: SWORD, SHIELD, SHIELD
func _complete_bear_sequence() -> void:
	_tracker.record_match(TileTypes.Type.SWORD)
	_tracker.record_match(TileTypes.Type.SHIELD)
	_tracker.record_match(TileTypes.Type.SHIELD)


## Records the Hawk sequence: SHIELD, LIGHTNING
func _complete_hawk_sequence() -> void:
	_tracker.record_match(TileTypes.Type.SHIELD)
	_tracker.record_match(TileTypes.Type.LIGHTNING)


## Records the Snake sequence: LIGHTNING, SWORD, SHIELD
func _complete_snake_sequence() -> void:
	_tracker.record_match(TileTypes.Type.LIGHTNING)
	_tracker.record_match(TileTypes.Type.SWORD)
	_tracker.record_match(TileTypes.Type.SHIELD)


## Creates Bear pattern: [SWORD, SHIELD, SHIELD] - max 3 stacks
func _create_bear_pattern() -> SequencePattern:
	var pattern := SequencePattern.new()
	pattern.sequence_id = "bear"
	pattern.display_name = "Bear"
	pattern.pattern = [
		TileTypes.Type.SWORD,
		TileTypes.Type.SHIELD,
		TileTypes.Type.SHIELD
	]
	pattern.terminator = TileTypes.Type.PET
	pattern.max_stacks = 3
	return pattern


## Creates Hawk pattern: [SHIELD, LIGHTNING] - max 3 stacks
func _create_hawk_pattern() -> SequencePattern:
	var pattern := SequencePattern.new()
	pattern.sequence_id = "hawk"
	pattern.display_name = "Hawk"
	pattern.pattern = [
		TileTypes.Type.SHIELD,
		TileTypes.Type.LIGHTNING
	]
	pattern.terminator = TileTypes.Type.PET
	pattern.max_stacks = 3
	return pattern


## Creates Snake pattern: [LIGHTNING, SWORD, SHIELD] - max 3 stacks
func _create_snake_pattern() -> SequencePattern:
	var pattern := SequencePattern.new()
	pattern.sequence_id = "snake"
	pattern.display_name = "Snake"
	pattern.pattern = [
		TileTypes.Type.LIGHTNING,
		TileTypes.Type.SWORD,
		TileTypes.Type.SHIELD
	]
	pattern.terminator = TileTypes.Type.PET
	pattern.max_stacks = 3
	return pattern


## Asserts a condition and reports pass/fail
func _assert(condition: bool, test_name: String, message: String = "") -> void:
	_tests_run += 1
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_tests_failed += 1
		var fail_msg := "  [FAIL] %s" % test_name
		if message != "":
			fail_msg += " - %s" % message
		print(fail_msg)


## Asserts two values are equal
func _assert_equal(actual, expected, test_name: String) -> void:
	var condition := actual == expected
	var message := "expected %s, got %s" % [str(expected), str(actual)]
	_assert(condition, test_name, message)


## Asserts a value is true
func _assert_true(value: bool, test_name: String) -> void:
	_assert(value, test_name, "expected true, got false")


## Asserts a value is false
func _assert_false(value: bool, test_name: String) -> void:
	_assert(not value, test_name, "expected false, got true")


## Resets signal tracking state
func _reset_signal_state() -> void:
	_signal_received = false
	_last_signal_data.clear()

#endregion


#region Signal Handlers

func _on_sequence_progressed(current: Array, possible_completions: Array) -> void:
	_signal_received = true
	_last_signal_data = {
		"type": "progressed",
		"current": current,
		"possible_completions": possible_completions
	}


func _on_sequence_completed(pattern: SequencePattern) -> void:
	_signal_received = true
	_last_signal_data = {
		"type": "completed",
		"pattern": pattern
	}


func _on_sequence_broken() -> void:
	_signal_received = true
	_last_signal_data = {
		"type": "broken"
	}


func _on_sequence_banked(pattern: SequencePattern, stacks: int) -> void:
	_signal_received = true
	_last_signal_data = {
		"type": "banked",
		"pattern": pattern,
		"stacks": stacks
	}


func _on_sequence_activated(pattern: SequencePattern, stacks: int) -> void:
	_signal_received = true
	_last_signal_data = {
		"type": "activated",
		"pattern": pattern,
		"stacks": stacks
	}

#endregion


#region Pattern Matching Tests

## Test: Single tile matches pattern prefix
func _test_prefix_match() -> void:
	var bear := _create_bear_pattern()

	# Single SWORD should match Bear prefix
	var seq1: Array[int] = [TileTypes.Type.SWORD]
	_assert_true(bear.matches_prefix(seq1), "SWORD matches Bear prefix")

	# SWORD, SHIELD should match Bear prefix
	var seq2: Array[int] = [TileTypes.Type.SWORD, TileTypes.Type.SHIELD]
	_assert_true(bear.matches_prefix(seq2), "SWORD, SHIELD matches Bear prefix")

	# Single SHIELD should match Hawk prefix
	var hawk := _create_hawk_pattern()
	var seq3: Array[int] = [TileTypes.Type.SHIELD]
	_assert_true(hawk.matches_prefix(seq3), "SHIELD matches Hawk prefix")


## Test: Complete sequence matches pattern
func _test_full_match() -> void:
	var bear := _create_bear_pattern()

	# Full Bear sequence should match completely
	var seq: Array[int] = [
		TileTypes.Type.SWORD,
		TileTypes.Type.SHIELD,
		TileTypes.Type.SHIELD
	]
	_assert_true(bear.is_complete_match(seq), "Full Bear sequence is complete match")

	# Partial sequence should not be complete match
	var partial: Array[int] = [TileTypes.Type.SWORD, TileTypes.Type.SHIELD]
	_assert_false(bear.is_complete_match(partial), "Partial sequence is not complete match")


## Test: Invalid sequence doesn't match
func _test_no_match() -> void:
	var bear := _create_bear_pattern()

	# POTION doesn't match Bear prefix
	var seq1: Array[int] = [TileTypes.Type.POTION]
	_assert_false(bear.matches_prefix(seq1), "POTION does not match Bear prefix")

	# SWORD, SWORD doesn't match Bear (expects SWORD, SHIELD)
	var seq2: Array[int] = [TileTypes.Type.SWORD, TileTypes.Type.SWORD]
	_assert_false(bear.matches_prefix(seq2), "SWORD, SWORD does not match Bear prefix")

	# Sequence longer than pattern doesn't match
	var seq3: Array[int] = [
		TileTypes.Type.SWORD,
		TileTypes.Type.SHIELD,
		TileTypes.Type.SHIELD,
		TileTypes.Type.SWORD
	]
	_assert_false(bear.matches_prefix(seq3), "Sequence longer than pattern does not match")

#endregion


#region Sequence Tracking Tests

## Test: Records tile to current sequence
func _test_record_single_match() -> void:
	_reset_tracker()

	_tracker.record_match(TileTypes.Type.SWORD)
	var current := _tracker.get_current_sequence()

	_assert_equal(current.size(), 1, "Current sequence has 1 element")
	_assert_equal(current[0], TileTypes.Type.SWORD, "Current sequence contains SWORD")


## Test: Builds up valid sequence
func _test_record_valid_sequence() -> void:
	_reset_tracker()

	# Build partial Bear sequence
	_tracker.record_match(TileTypes.Type.SWORD)
	_tracker.record_match(TileTypes.Type.SHIELD)

	var current := _tracker.get_current_sequence()
	_assert_equal(current.size(), 2, "Current sequence has 2 elements")
	_assert_true(_tracker.is_building_sequence(), "Tracker is building a sequence")


## Test: Invalid match clears sequence
func _test_whiff_breaks_sequence() -> void:
	_reset_tracker()

	# Start Bear sequence
	_tracker.record_match(TileTypes.Type.SWORD)

	# Record invalid tile (POTION doesn't continue any valid pattern from SWORD)
	_tracker.record_match(TileTypes.Type.POTION)

	var current := _tracker.get_current_sequence()
	_assert_equal(current.size(), 0, "Sequence cleared after whiff")
	_assert_false(_tracker.is_building_sequence(), "No longer building sequence after whiff")


## Test: Detects when sequence complete
func _test_sequence_completion() -> void:
	_reset_tracker()

	# Complete the Hawk sequence (shortest pattern)
	_tracker.record_match(TileTypes.Type.SHIELD)
	_tracker.record_match(TileTypes.Type.LIGHTNING)

	# Sequence should be cleared (banked) after completion
	var current := _tracker.get_current_sequence()
	_assert_equal(current.size(), 0, "Current sequence cleared after completion")

	# Should have a banked sequence now
	_assert_true(_tracker.has_completable_sequence(), "Has completable sequence after completion")

#endregion


#region Banking Tests

## Test: Completed sequence is banked
func _test_bank_sequence() -> void:
	_reset_tracker()

	var hawk := _create_hawk_pattern()
	_complete_hawk_sequence()

	var stacks := _tracker.get_banked_stacks(hawk)
	_assert_equal(stacks, 1, "Banked sequence has 1 stack")


## Test: Can bank multiple stacks
func _test_bank_multiple_stacks() -> void:
	_reset_tracker()

	var hawk := _create_hawk_pattern()

	# Complete the sequence twice
	_complete_hawk_sequence()
	_complete_hawk_sequence()

	var stacks := _tracker.get_banked_stacks(hawk)
	_assert_equal(stacks, 2, "Banked sequence has 2 stacks")


## Test: Cannot exceed max stacks
func _test_max_stacks() -> void:
	_reset_tracker()

	var hawk := _create_hawk_pattern()

	# Complete the sequence 5 times (max is 3)
	_complete_hawk_sequence()
	_complete_hawk_sequence()
	_complete_hawk_sequence()
	_complete_hawk_sequence()
	_complete_hawk_sequence()

	var stacks := _tracker.get_banked_stacks(hawk)
	_assert_equal(stacks, 3, "Stacks capped at max_stacks (3)")

#endregion


#region Activation Tests

## Test: Can activate banked sequence
func _test_activate_banked() -> void:
	_reset_tracker()

	var hawk := _create_hawk_pattern()
	_complete_hawk_sequence()

	var activated := _tracker.activate_sequence(hawk)
	_assert_true(activated, "Successfully activated banked sequence")


## Test: Activation reduces stack count
func _test_activate_consumes_stack() -> void:
	_reset_tracker()

	var hawk := _create_hawk_pattern()
	_complete_hawk_sequence()
	_complete_hawk_sequence()

	_assert_equal(_tracker.get_banked_stacks(hawk), 2, "Initial stacks is 2")

	_tracker.activate_sequence(hawk)
	_assert_equal(_tracker.get_banked_stacks(hawk), 1, "Stacks reduced to 1 after activation")

	_tracker.activate_sequence(hawk)
	_assert_equal(_tracker.get_banked_stacks(hawk), 0, "Stacks reduced to 0 after second activation")

	# Cannot activate with no stacks
	var activated := _tracker.activate_sequence(hawk)
	_assert_false(activated, "Cannot activate with no stacks")


## Test: Detects banked sequences
func _test_has_completable_sequence() -> void:
	_reset_tracker()

	_assert_false(_tracker.has_completable_sequence(), "No completable sequence initially")

	_complete_hawk_sequence()
	_assert_true(_tracker.has_completable_sequence(), "Has completable sequence after completion")

	var hawk := _create_hawk_pattern()
	_tracker.activate_sequence(hawk)
	_assert_false(_tracker.has_completable_sequence(), "No completable sequence after activation")

#endregion


#region Multi-Pattern Tests

## Test: Tracks multiple different patterns
func _test_multiple_patterns() -> void:
	_reset_tracker()

	var hawk := _create_hawk_pattern()
	var bear := _create_bear_pattern()

	# Complete Hawk
	_complete_hawk_sequence()
	_assert_equal(_tracker.get_banked_stacks(hawk), 1, "Hawk has 1 stack")

	# Complete Bear
	_complete_bear_sequence()
	_assert_equal(_tracker.get_banked_stacks(bear), 1, "Bear has 1 stack")

	# Both should still be tracked
	_assert_equal(_tracker.get_banked_stacks(hawk), 1, "Hawk still has 1 stack")

	var banked := _tracker.get_banked_sequences()
	_assert_equal(banked.size(), 2, "Two patterns banked")


## Test: Handles shared prefixes correctly
func _test_overlapping_prefixes() -> void:
	_reset_tracker()

	# SHIELD is a prefix for Hawk (SHIELD, LIGHTNING)
	# Start with SHIELD
	_tracker.record_match(TileTypes.Type.SHIELD)
	_assert_true(_tracker.is_building_sequence(), "Building sequence after SHIELD")

	# Get possible completions - should include Hawk
	var current := _tracker.get_current_sequence()
	_assert_equal(current.size(), 1, "Current sequence has 1 element")

	# Complete with LIGHTNING to form Hawk
	_tracker.record_match(TileTypes.Type.LIGHTNING)

	var hawk := _create_hawk_pattern()
	_assert_equal(_tracker.get_banked_stacks(hawk), 1, "Hawk completed from overlapping prefix")

#endregion


#region Signal Tests

## Test: sequence_progressed signal fires
func _test_progress_signal() -> void:
	_reset_tracker()
	_reset_signal_state()

	_tracker.sequence_progressed.connect(_on_sequence_progressed)

	_tracker.record_match(TileTypes.Type.SWORD)

	_assert_true(_signal_received, "sequence_progressed signal received")
	_assert_equal(_last_signal_data.get("type"), "progressed", "Signal type is progressed")

	var current: Array = _last_signal_data.get("current", [])
	_assert_equal(current.size(), 1, "Signal contains current sequence with 1 element")


## Test: sequence_completed signal fires
func _test_completed_signal() -> void:
	_reset_tracker()
	_reset_signal_state()

	_tracker.sequence_completed.connect(_on_sequence_completed)

	_complete_hawk_sequence()

	_assert_true(_signal_received, "sequence_completed signal received")
	_assert_equal(_last_signal_data.get("type"), "completed", "Signal type is completed")

	var pattern: SequencePattern = _last_signal_data.get("pattern")
	_assert_equal(pattern.sequence_id, "hawk", "Completed pattern is Hawk")


## Test: sequence_broken signal fires
func _test_broken_signal() -> void:
	_reset_tracker()
	_reset_signal_state()

	_tracker.sequence_broken.connect(_on_sequence_broken)

	# Start a valid sequence
	_tracker.record_match(TileTypes.Type.SWORD)
	_reset_signal_state()  # Clear the progress signal

	# Break it with an invalid tile
	_tracker.record_match(TileTypes.Type.POTION)

	_assert_true(_signal_received, "sequence_broken signal received")
	_assert_equal(_last_signal_data.get("type"), "broken", "Signal type is broken")

#endregion


#region Reset Tests

## Test: Reset clears current and banked
func _test_reset_clears_all() -> void:
	_reset_tracker()

	var hawk := _create_hawk_pattern()
	var bear := _create_bear_pattern()

	# Build up some state
	_complete_hawk_sequence()
	_complete_hawk_sequence()
	_complete_bear_sequence()

	# Start a partial sequence
	_tracker.record_match(TileTypes.Type.SWORD)

	# Verify state exists
	_assert_true(_tracker.is_building_sequence(), "Building sequence before reset")
	_assert_equal(_tracker.get_banked_stacks(hawk), 2, "Hawk has 2 stacks before reset")
	_assert_equal(_tracker.get_banked_stacks(bear), 1, "Bear has 1 stack before reset")

	# Reset
	_tracker.reset()

	# Verify all cleared
	_assert_false(_tracker.is_building_sequence(), "Not building sequence after reset")
	_assert_equal(_tracker.get_banked_stacks(hawk), 0, "Hawk has 0 stacks after reset")
	_assert_equal(_tracker.get_banked_stacks(bear), 0, "Bear has 0 stacks after reset")
	_assert_false(_tracker.has_completable_sequence(), "No completable sequences after reset")

	var current := _tracker.get_current_sequence()
	_assert_equal(current.size(), 0, "Current sequence empty after reset")

#endregion
