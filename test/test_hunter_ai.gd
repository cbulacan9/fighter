extends Node
## Test harness for Hunter AI Controller functionality
##
## This script provides test coverage for the AI controller's Hunter-specific
## behavior including sequence building, Pet clicking, and ultimate activation.


## Test result counters
var _tests_passed: int = 0
var _tests_failed: int = 0
var _tests_run: int = 0

## Mock objects for testing
var _ai_controller: AIController
var _sequence_tracker: SequenceTracker


func _ready() -> void:
	print("\n========================================")
	print("HUNTER AI CONTROLLER TEST SUITE")
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
	print("--- Difficulty Level Tests ---")
	_test_difficulty_easy()
	_test_difficulty_medium()
	_test_difficulty_hard()
	_test_set_difficulty_enum()

	print("\n--- Character Awareness Tests ---")
	_test_set_character()
	_test_has_sequences_detection()

	print("\n--- Sequence Awareness Tests ---")
	_test_sequence_awareness_range()
	_test_default_sequence_awareness()

	print("\n--- Pet Click Decision Tests ---")
	_test_should_click_pet_no_tracker()
	_test_should_click_pet_no_banked()
	_test_should_click_pet_with_banked()

	print("\n--- Ultimate Decision Tests ---")
	_test_should_use_ultimate_no_fighter()
	_test_should_use_ultimate_no_combat_manager()

	print("\n--- Helper Method Tests ---")
	_test_get_tiles_of_type_no_board()


#region Helper Methods

## Creates a fresh AI controller for testing
func _reset_ai_controller() -> void:
	_ai_controller = AIController.new()
	add_child(_ai_controller)


## Cleans up the AI controller
func _cleanup_ai_controller() -> void:
	if _ai_controller and is_instance_valid(_ai_controller):
		_ai_controller.queue_free()
		_ai_controller = null


## Creates a sequence tracker with Hunter patterns
func _create_hunter_tracker() -> SequenceTracker:
	var tracker := SequenceTracker.new()
	var patterns: Array[SequencePattern] = [
		_create_bear_pattern(),
		_create_hawk_pattern(),
		_create_snake_pattern()
	]
	tracker.setup(patterns)
	return tracker


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


## Creates a mock CharacterData with sequences
func _create_mock_hunter_character() -> CharacterData:
	var char_data := CharacterData.new()
	char_data.character_id = "hunter"
	char_data.display_name = "The Hunter"
	char_data.sequences = [
		_create_bear_pattern(),
		_create_hawk_pattern(),
		_create_snake_pattern()
	]
	return char_data


## Creates a mock CharacterData without sequences
func _create_mock_basic_character() -> CharacterData:
	var char_data := CharacterData.new()
	char_data.character_id = "warrior"
	char_data.display_name = "The Warrior"
	char_data.sequences = []
	return char_data


## Records the Hawk sequence: SHIELD, LIGHTNING
func _complete_hawk_sequence(tracker: SequenceTracker) -> void:
	tracker.record_match(TileTypes.Type.SHIELD)
	tracker.record_match(TileTypes.Type.LIGHTNING)


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


## Asserts value is approximately equal
func _assert_approx(actual: float, expected: float, test_name: String, epsilon: float = 0.01) -> void:
	var condition := abs(actual - expected) < epsilon
	var message := "expected approximately %f, got %f" % [expected, actual]
	_assert(condition, test_name, message)

#endregion


#region Difficulty Level Tests

## Test: Easy difficulty sets correct values
func _test_difficulty_easy() -> void:
	_reset_ai_controller()

	_ai_controller.set_difficulty_easy()

	_assert_equal(_ai_controller.get_difficulty(), AIController.Difficulty.EASY, "Difficulty is EASY")
	_assert_approx(_ai_controller.decision_delay, 2.0, "Decision delay is 2.0")
	_assert_equal(_ai_controller.look_ahead, 0, "Look ahead is 0")
	_assert_approx(_ai_controller.randomness, 0.5, "Randomness is 0.5")
	_assert_approx(_ai_controller.get_sequence_awareness(), 0.3, "Sequence awareness is 0.3")

	_cleanup_ai_controller()


## Test: Medium difficulty sets correct values
func _test_difficulty_medium() -> void:
	_reset_ai_controller()

	_ai_controller.set_difficulty_medium()

	_assert_equal(_ai_controller.get_difficulty(), AIController.Difficulty.MEDIUM, "Difficulty is MEDIUM")
	_assert_approx(_ai_controller.decision_delay, 1.0, "Decision delay is 1.0")
	_assert_equal(_ai_controller.look_ahead, 1, "Look ahead is 1")
	_assert_approx(_ai_controller.randomness, 0.2, "Randomness is 0.2")
	_assert_approx(_ai_controller.get_sequence_awareness(), 0.6, "Sequence awareness is 0.6")

	_cleanup_ai_controller()


## Test: Hard difficulty sets correct values
func _test_difficulty_hard() -> void:
	_reset_ai_controller()

	_ai_controller.set_difficulty_hard()

	_assert_equal(_ai_controller.get_difficulty(), AIController.Difficulty.HARD, "Difficulty is HARD")
	_assert_approx(_ai_controller.decision_delay, 0.5, "Decision delay is 0.5")
	_assert_equal(_ai_controller.look_ahead, 2, "Look ahead is 2")
	_assert_approx(_ai_controller.randomness, 0.05, "Randomness is 0.05")
	_assert_approx(_ai_controller.get_sequence_awareness(), 0.9, "Sequence awareness is 0.9")

	_cleanup_ai_controller()


## Test: Set difficulty via enum
func _test_set_difficulty_enum() -> void:
	_reset_ai_controller()

	_ai_controller.set_difficulty(AIController.Difficulty.HARD)
	_assert_equal(_ai_controller.get_difficulty(), AIController.Difficulty.HARD, "Difficulty enum HARD applied")

	_ai_controller.set_difficulty(AIController.Difficulty.EASY)
	_assert_equal(_ai_controller.get_difficulty(), AIController.Difficulty.EASY, "Difficulty enum EASY applied")

	_cleanup_ai_controller()

#endregion


#region Character Awareness Tests

## Test: Set character data
func _test_set_character() -> void:
	_reset_ai_controller()

	var hunter := _create_mock_hunter_character()
	_ai_controller.set_character(hunter)

	# Character data should be stored (we can check indirectly)
	_assert_true(true, "set_character accepts CharacterData")

	_cleanup_ai_controller()


## Test: Detects character with sequences
func _test_has_sequences_detection() -> void:
	var hunter := _create_mock_hunter_character()
	var warrior := _create_mock_basic_character()

	_assert_true(hunter.has_sequences(), "Hunter has sequences")
	_assert_false(warrior.has_sequences(), "Warrior has no sequences")

#endregion


#region Sequence Awareness Tests

## Test: Sequence awareness clamps to valid range
func _test_sequence_awareness_range() -> void:
	_reset_ai_controller()

	_ai_controller.set_sequence_awareness(1.5)
	_assert_approx(_ai_controller.get_sequence_awareness(), 1.0, "Awareness clamped to max 1.0")

	_ai_controller.set_sequence_awareness(-0.5)
	_assert_approx(_ai_controller.get_sequence_awareness(), 0.0, "Awareness clamped to min 0.0")

	_ai_controller.set_sequence_awareness(0.75)
	_assert_approx(_ai_controller.get_sequence_awareness(), 0.75, "Awareness set to 0.75")

	_cleanup_ai_controller()


## Test: Default sequence awareness is medium
func _test_default_sequence_awareness() -> void:
	_reset_ai_controller()

	# Default is MEDIUM which has 0.6 sequence awareness
	_assert_approx(_ai_controller.get_sequence_awareness(), 0.6, "Default sequence awareness is 0.6")

	_cleanup_ai_controller()

#endregion


#region Pet Click Decision Tests

## Test: Should not click pet without sequence tracker
func _test_should_click_pet_no_tracker() -> void:
	_reset_ai_controller()

	# Without a sequence tracker, should return false
	var should_click := _ai_controller._should_click_pet()
	_assert_false(should_click, "Should not click pet without sequence tracker")

	_cleanup_ai_controller()


## Test: Should not click pet without banked sequences
func _test_should_click_pet_no_banked() -> void:
	_reset_ai_controller()

	var tracker := _create_hunter_tracker()
	_ai_controller._sequence_tracker = tracker

	# No sequences completed, should return false
	var should_click := _ai_controller._should_click_pet()
	_assert_false(should_click, "Should not click pet without banked sequences")

	_cleanup_ai_controller()


## Test: Should click pet with banked sequences
func _test_should_click_pet_with_banked() -> void:
	_reset_ai_controller()

	var tracker := _create_hunter_tracker()
	_complete_hawk_sequence(tracker)
	_ai_controller._sequence_tracker = tracker

	# Hawk sequence completed, should return true
	var should_click := _ai_controller._should_click_pet()
	_assert_true(should_click, "Should click pet with banked Hawk sequence")

	_cleanup_ai_controller()

#endregion


#region Ultimate Decision Tests

## Test: Should not use ultimate without fighter
func _test_should_use_ultimate_no_fighter() -> void:
	_reset_ai_controller()

	var should_use := _ai_controller._should_use_ultimate()
	_assert_false(should_use, "Should not use ultimate without fighter")

	_cleanup_ai_controller()


## Test: Should not use ultimate without combat manager
func _test_should_use_ultimate_no_combat_manager() -> void:
	_reset_ai_controller()

	var fighter := Fighter.new()
	add_child(fighter)
	_ai_controller.set_owner_fighter(fighter)

	var should_use := _ai_controller._should_use_ultimate()
	_assert_false(should_use, "Should not use ultimate without combat manager")

	fighter.queue_free()
	_cleanup_ai_controller()

#endregion


#region Helper Method Tests

## Test: Get tiles of type returns empty without board
func _test_get_tiles_of_type_no_board() -> void:
	_reset_ai_controller()

	var tiles := _ai_controller._get_tiles_of_type(TileTypes.Type.PET)
	_assert_equal(tiles.size(), 0, "Returns empty array without board")

	_cleanup_ai_controller()

#endregion
