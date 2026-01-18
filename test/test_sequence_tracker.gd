extends Node
## Test harness for SequenceTracker multi-tree combo system
##
## This script provides comprehensive test coverage for the Hunter v2 combo system,
## including parallel tree tracking, tree advancement, tree death, and sequence completion.


## Test result counters
var _tests_passed: int = 0
var _tests_failed: int = 0
var _tests_run: int = 0

## Signal tracking
var _signal_received: bool = false
var _last_signal_data: Dictionary = {}

## Test instances
var _tracker: SequenceTracker
var _bear_pattern: SequencePattern
var _hawk_pattern: SequencePattern
var _snake_pattern: SequencePattern


func _ready() -> void:
	print("\n========================================")
	print("SEQUENCE TRACKER MULTI-TREE TEST SUITE")
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
	print("--- Single Tree Tests ---")
	_test_single_tree_start()
	_test_single_tree_progression()
	_test_single_tree_completion()

	print("\n--- Multiple Tree Tests ---")
	_test_multiple_trees_active()
	_test_multiple_trees_from_single_match()

	print("\n--- Tree Death Tests ---")
	_test_individual_tree_death()
	_test_tree_death_starts_new_tree()
	_test_multiple_trees_mixed_survival()

	print("\n--- Auto-Completion Tests ---")
	_test_auto_complete_on_pattern_match()
	_test_immediate_completion_short_pattern()

	print("\n--- Duplicate Prevention Tests ---")
	_test_no_duplicate_trees_for_same_pattern()
	_test_no_duplicate_after_death()

	print("\n--- Signal Tests ---")
	_test_tree_started_signal()
	_test_tree_progressed_signal()
	_test_tree_died_signal()
	_test_sequence_completed_signal()

	print("\n--- Reset Tests ---")
	_test_reset_clears_all_trees()

	print("\n--- Edge Case Tests ---")
	_test_empty_tile_types_array()
	_test_no_matching_patterns()
	_test_tree_progress_accessor()


#region Helper Methods

## Creates a fresh SequenceTracker with test patterns
func _reset_tracker() -> void:
	_tracker = SequenceTracker.new()
	_bear_pattern = _create_bear_pattern()
	_hawk_pattern = _create_hawk_pattern()
	_snake_pattern = _create_snake_pattern()

	var patterns: Array[SequencePattern] = [
		_bear_pattern,
		_hawk_pattern,
		_snake_pattern
	]
	_tracker.setup(patterns)
	_disconnect_all_signals()


## Disconnects all signal connections from the tracker
func _disconnect_all_signals() -> void:
	if _tracker.tree_started.is_connected(_on_tree_started):
		_tracker.tree_started.disconnect(_on_tree_started)
	if _tracker.tree_progressed.is_connected(_on_tree_progressed):
		_tracker.tree_progressed.disconnect(_on_tree_progressed)
	if _tracker.tree_died.is_connected(_on_tree_died):
		_tracker.tree_died.disconnect(_on_tree_died)
	if _tracker.sequence_completed.is_connected(_on_sequence_completed):
		_tracker.sequence_completed.disconnect(_on_sequence_completed)


## Creates Bear pattern: [SWORD, SHIELD, SHIELD] -> BEAR_PET
func _create_bear_pattern() -> SequencePattern:
	var pattern := SequencePattern.new()
	pattern.sequence_id = "bear"
	pattern.display_name = "Bear"
	pattern.pattern = [
		TileTypes.Type.SWORD,
		TileTypes.Type.SHIELD,
		TileTypes.Type.SHIELD
	]
	pattern.pet_type = TileTypes.Type.BEAR_PET
	pattern.max_stacks = 3
	return pattern


## Creates Hawk pattern: [SHIELD, LIGHTNING] -> HAWK_PET
func _create_hawk_pattern() -> SequencePattern:
	var pattern := SequencePattern.new()
	pattern.sequence_id = "hawk"
	pattern.display_name = "Hawk"
	pattern.pattern = [
		TileTypes.Type.SHIELD,
		TileTypes.Type.LIGHTNING
	]
	pattern.pet_type = TileTypes.Type.HAWK_PET
	pattern.max_stacks = 3
	return pattern


## Creates Snake pattern: [LIGHTNING, SWORD, SHIELD] -> SNAKE_PET
func _create_snake_pattern() -> SequencePattern:
	var pattern := SequencePattern.new()
	pattern.sequence_id = "snake"
	pattern.display_name = "Snake"
	pattern.pattern = [
		TileTypes.Type.LIGHTNING,
		TileTypes.Type.SWORD,
		TileTypes.Type.SHIELD
	]
	pattern.pet_type = TileTypes.Type.SNAKE_PET
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


## Helper to get tree by pattern name
func _get_tree_by_name(trees: Array[ComboTree], name: String) -> ComboTree:
	for tree: ComboTree in trees:
		if tree.pattern.display_name == name:
			return tree
	return null


## Helper to count trees by pattern name
func _count_trees_by_name(trees: Array[ComboTree], name: String) -> int:
	var count := 0
	for tree: ComboTree in trees:
		if tree.pattern.display_name == name:
			count += 1
	return count

#endregion


#region Signal Handlers

func _on_tree_started(pattern_name: String) -> void:
	_signal_received = true
	_last_signal_data = {
		"type": "tree_started",
		"pattern_name": pattern_name
	}


func _on_tree_progressed(pattern_name: String, progress: int, total: int) -> void:
	_signal_received = true
	_last_signal_data = {
		"type": "tree_progressed",
		"pattern_name": pattern_name,
		"progress": progress,
		"total": total
	}


func _on_tree_died(pattern_name: String) -> void:
	_signal_received = true
	_last_signal_data = {
		"type": "tree_died",
		"pattern_name": pattern_name
	}


func _on_sequence_completed(pet_type: int) -> void:
	_signal_received = true
	_last_signal_data = {
		"type": "sequence_completed",
		"pet_type": pet_type
	}

#endregion


#region Single Tree Tests

## Test: Start Bear tree with SWORD
func _test_single_tree_start() -> void:
	_reset_tracker()

	var types: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types)

	var trees := _tracker.get_active_trees()
	_assert_equal(trees.size(), 1, "Should have 1 active tree after SWORD")

	var bear_tree := _get_tree_by_name(trees, "Bear")
	_assert_true(bear_tree != null, "Active tree should be Bear")
	_assert_equal(bear_tree.progress, 1, "Bear tree should be at progress 1")


## Test: Bear tree advances with correct tiles
func _test_single_tree_progression() -> void:
	_reset_tracker()

	# Start Bear: SWORD
	var types1: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types1)

	# Advance: SHIELD
	var types2: Array[int] = [TileTypes.Type.SHIELD]
	_tracker.process_initiating_matches(types2)

	var trees := _tracker.get_active_trees()
	_assert_equal(trees.size(), 2, "Should have 2 trees (Bear advanced, Hawk started)")

	var bear_tree := _get_tree_by_name(trees, "Bear")
	_assert_true(bear_tree != null, "Bear tree should still exist")
	_assert_equal(bear_tree.progress, 2, "Bear tree should be at progress 2")


## Test: Bear tree completes with full pattern
func _test_single_tree_completion() -> void:
	_reset_tracker()

	# Complete Bear: SWORD -> SHIELD -> SHIELD
	var types1: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types1)

	var types2: Array[int] = [TileTypes.Type.SHIELD]
	_tracker.process_initiating_matches(types2)

	var types3: Array[int] = [TileTypes.Type.SHIELD]
	_tracker.process_initiating_matches(types3)

	# After completion, Bear tree should be removed
	var trees := _tracker.get_active_trees()
	var bear_tree := _get_tree_by_name(trees, "Bear")
	_assert_true(bear_tree == null, "Bear tree should be removed after completion")

#endregion


#region Multiple Tree Tests

## Test: Multiple trees from simultaneous tile matches
func _test_multiple_trees_active() -> void:
	_reset_tracker()

	# Match SWORD and SHIELD simultaneously - starts Bear and Hawk
	var types: Array[int] = [TileTypes.Type.SWORD, TileTypes.Type.SHIELD]
	_tracker.process_initiating_matches(types)

	var trees := _tracker.get_active_trees()
	_assert_equal(trees.size(), 2, "Should have 2 active trees")

	var bear_tree := _get_tree_by_name(trees, "Bear")
	var hawk_tree := _get_tree_by_name(trees, "Hawk")
	_assert_true(bear_tree != null, "Bear tree should exist")
	_assert_true(hawk_tree != null, "Hawk tree should exist")


## Test: LIGHTNING starts Snake, advances nothing new
func _test_multiple_trees_from_single_match() -> void:
	_reset_tracker()

	# Start with LIGHTNING - only starts Snake
	var types: Array[int] = [TileTypes.Type.LIGHTNING]
	_tracker.process_initiating_matches(types)

	var trees := _tracker.get_active_trees()
	_assert_equal(trees.size(), 1, "Should have 1 active tree")

	var snake_tree := _get_tree_by_name(trees, "Snake")
	_assert_true(snake_tree != null, "Snake tree should exist")
	_assert_equal(snake_tree.progress, 1, "Snake tree should be at progress 1")

#endregion


#region Tree Death Tests

## Test: Tree dies when required tile not matched
func _test_individual_tree_death() -> void:
	_reset_tracker()

	# Start Bear tree
	var types1: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types1)
	_assert_equal(_tracker.get_active_trees().size(), 1, "Should have 1 active tree")

	# Match POTION - doesn't advance Bear, kills it
	var types2: Array[int] = [TileTypes.Type.POTION]
	_tracker.process_initiating_matches(types2)

	var trees := _tracker.get_active_trees()
	_assert_equal(trees.size(), 0, "Bear should die - no new patterns start with POTION")


## Test: Tree death can start new tree
func _test_tree_death_starts_new_tree() -> void:
	_reset_tracker()

	# Start Bear tree
	var types1: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types1)
	_assert_equal(_tracker.get_active_trees().size(), 1, "Should have Bear tree")

	# Match LIGHTNING - kills Bear, starts Snake
	var types2: Array[int] = [TileTypes.Type.LIGHTNING]
	_tracker.process_initiating_matches(types2)

	var trees := _tracker.get_active_trees()
	_assert_equal(trees.size(), 1, "Bear should die, Snake should start")

	var snake_tree := _get_tree_by_name(trees, "Snake")
	_assert_true(snake_tree != null, "Snake tree should exist")


## Test: Multiple trees with mixed survival
func _test_multiple_trees_mixed_survival() -> void:
	_reset_tracker()

	# Start Bear and Hawk (SWORD and SHIELD)
	var types1: Array[int] = [TileTypes.Type.SWORD, TileTypes.Type.SHIELD]
	_tracker.process_initiating_matches(types1)
	_assert_equal(_tracker.get_active_trees().size(), 2, "Should have Bear and Hawk trees")

	# Match LIGHTNING - advances Hawk (completes it), kills Bear, starts Snake
	var types2: Array[int] = [TileTypes.Type.LIGHTNING]
	_tracker.process_initiating_matches(types2)

	var trees := _tracker.get_active_trees()
	# Hawk completes (removed), Bear dies (removed), Snake starts (added)
	_assert_equal(trees.size(), 1, "Should have 1 tree (Snake)")

	var snake_tree := _get_tree_by_name(trees, "Snake")
	_assert_true(snake_tree != null, "Snake tree should exist")

#endregion


#region Auto-Completion Tests

## Test: Hawk completes in 2 tiles (SHIELD -> LIGHTNING)
func _test_auto_complete_on_pattern_match() -> void:
	_reset_tracker()

	# Start Hawk: SHIELD
	var types1: Array[int] = [TileTypes.Type.SHIELD]
	_tracker.process_initiating_matches(types1)

	var trees_before := _tracker.get_active_trees()
	var hawk_tree := _get_tree_by_name(trees_before, "Hawk")
	_assert_true(hawk_tree != null, "Hawk tree should exist")
	_assert_equal(hawk_tree.progress, 1, "Hawk should be at progress 1")

	# Complete Hawk: LIGHTNING
	var types2: Array[int] = [TileTypes.Type.LIGHTNING]
	_tracker.process_initiating_matches(types2)

	var trees_after := _tracker.get_active_trees()
	var hawk_after := _get_tree_by_name(trees_after, "Hawk")
	_assert_true(hawk_after == null, "Hawk should be removed after completion")


## Test: Short pattern immediate completion detection
func _test_immediate_completion_short_pattern() -> void:
	_reset_tracker()

	# Create a 1-tile test pattern
	var short_pattern := SequencePattern.new()
	short_pattern.sequence_id = "short"
	short_pattern.display_name = "Short"
	short_pattern.pattern = [TileTypes.Type.MANA]
	short_pattern.pet_type = -1  # No pet, just for testing

	var patterns: Array[SequencePattern] = [short_pattern]
	_tracker.setup(patterns)

	# Match MANA - should immediately complete
	var types: Array[int] = [TileTypes.Type.MANA]
	_tracker.process_initiating_matches(types)

	var trees := _tracker.get_active_trees()
	# Pattern should complete immediately and be removed
	_assert_equal(trees.size(), 0, "Short pattern should complete immediately")

#endregion


#region Duplicate Prevention Tests

## Test: No duplicate trees for same pattern
func _test_no_duplicate_trees_for_same_pattern() -> void:
	_reset_tracker()

	# First SWORD starts Bear
	var types1: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types1)
	_assert_equal(_tracker.get_active_trees().size(), 1, "Should have 1 Bear tree")

	# Second SWORD should NOT create duplicate Bear
	var types2: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types2)

	var trees := _tracker.get_active_trees()
	var bear_count := _count_trees_by_name(trees, "Bear")
	_assert_equal(bear_count, 1, "Should only have one Bear tree")


## Test: After tree dies, same pattern can start fresh
func _test_no_duplicate_after_death() -> void:
	_reset_tracker()

	# Start Bear
	var types1: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types1)

	# Kill Bear with POTION
	var types2: Array[int] = [TileTypes.Type.POTION]
	_tracker.process_initiating_matches(types2)
	_assert_equal(_tracker.get_active_trees().size(), 0, "Bear should be dead")

	# SWORD should start new Bear
	var types3: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types3)

	var trees := _tracker.get_active_trees()
	var bear_count := _count_trees_by_name(trees, "Bear")
	_assert_equal(bear_count, 1, "New Bear tree should start after death")

#endregion


#region Signal Tests

## Test: tree_started signal emitted
func _test_tree_started_signal() -> void:
	_reset_tracker()
	_reset_signal_state()
	_tracker.tree_started.connect(_on_tree_started)

	var types: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types)

	_assert_true(_signal_received, "tree_started signal should be received")
	_assert_equal(_last_signal_data.get("type"), "tree_started", "Signal type should be tree_started")
	_assert_equal(_last_signal_data.get("pattern_name"), "Bear", "Pattern name should be Bear")


## Test: tree_progressed signal emitted
func _test_tree_progressed_signal() -> void:
	_reset_tracker()
	_reset_signal_state()
	_tracker.tree_progressed.connect(_on_tree_progressed)

	# Start Bear
	var types1: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types1)

	_assert_true(_signal_received, "tree_progressed signal should be received")
	_assert_equal(_last_signal_data.get("progress"), 1, "Progress should be 1")
	_assert_equal(_last_signal_data.get("total"), 3, "Total should be 3 for Bear")

	_reset_signal_state()

	# Advance Bear
	var types2: Array[int] = [TileTypes.Type.SHIELD]
	_tracker.process_initiating_matches(types2)

	# Note: SHIELD also starts Hawk, so we may get multiple signals
	# Check that a Bear signal was emitted
	_assert_true(_signal_received, "tree_progressed signal should be received for advancement")


## Test: tree_died signal emitted
func _test_tree_died_signal() -> void:
	_reset_tracker()
	_reset_signal_state()
	_tracker.tree_died.connect(_on_tree_died)

	# Start Bear
	var types1: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types1)

	_reset_signal_state()

	# Kill Bear with POTION
	var types2: Array[int] = [TileTypes.Type.POTION]
	_tracker.process_initiating_matches(types2)

	_assert_true(_signal_received, "tree_died signal should be received")
	_assert_equal(_last_signal_data.get("type"), "tree_died", "Signal type should be tree_died")
	_assert_equal(_last_signal_data.get("pattern_name"), "Bear", "Dead pattern should be Bear")


## Test: sequence_completed signal emitted with pet type
func _test_sequence_completed_signal() -> void:
	_reset_tracker()
	_reset_signal_state()
	_tracker.sequence_completed.connect(_on_sequence_completed)

	# Complete Hawk: SHIELD -> LIGHTNING
	var types1: Array[int] = [TileTypes.Type.SHIELD]
	_tracker.process_initiating_matches(types1)

	_reset_signal_state()

	var types2: Array[int] = [TileTypes.Type.LIGHTNING]
	_tracker.process_initiating_matches(types2)

	_assert_true(_signal_received, "sequence_completed signal should be received")
	_assert_equal(_last_signal_data.get("type"), "sequence_completed", "Signal type should be sequence_completed")
	_assert_equal(_last_signal_data.get("pet_type"), TileTypes.Type.HAWK_PET, "Pet type should be HAWK_PET")

#endregion


#region Reset Tests

## Test: reset() clears all active trees
func _test_reset_clears_all_trees() -> void:
	_reset_tracker()

	# Start multiple trees
	var types1: Array[int] = [TileTypes.Type.SWORD, TileTypes.Type.SHIELD, TileTypes.Type.LIGHTNING]
	_tracker.process_initiating_matches(types1)
	_assert_true(_tracker.get_active_trees().size() > 0, "Should have active trees before reset")

	# Reset
	_tracker.reset()

	_assert_equal(_tracker.get_active_trees().size(), 0, "Should have no trees after reset")
	_assert_false(_tracker.is_building_sequence(), "is_building_sequence should be false after reset")

#endregion


#region Edge Case Tests

## Test: Empty tile types array
func _test_empty_tile_types_array() -> void:
	_reset_tracker()

	var types: Array[int] = []
	_tracker.process_initiating_matches(types)

	_assert_equal(_tracker.get_active_trees().size(), 0, "Empty input should not start any trees")


## Test: Tile type that doesn't match any pattern start
func _test_no_matching_patterns() -> void:
	_reset_tracker()

	# POTION doesn't start any of our test patterns
	var types: Array[int] = [TileTypes.Type.POTION]
	_tracker.process_initiating_matches(types)

	_assert_equal(_tracker.get_active_trees().size(), 0, "POTION should not start any trees")


## Test: Tree progress accessor methods
func _test_tree_progress_accessor() -> void:
	_reset_tracker()

	# Start Bear and advance it
	var types1: Array[int] = [TileTypes.Type.SWORD]
	_tracker.process_initiating_matches(types1)

	var types2: Array[int] = [TileTypes.Type.SHIELD]
	_tracker.process_initiating_matches(types2)

	# Check accessor methods
	_assert_true(_tracker.is_building_sequence(), "is_building_sequence should be true")

	var progress := _tracker.get_completion_progress()
	_assert_true(progress > 0.0, "Completion progress should be > 0")

	var possible := _tracker.get_possible_next_tiles()
	_assert_true(possible.size() > 0, "Should have possible next tiles")
	_assert_true(TileTypes.Type.SHIELD in possible, "SHIELD should be in possible next tiles for Bear")

#endregion
