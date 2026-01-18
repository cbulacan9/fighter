extends Node
## Test harness for PetSpawner component
##
## This script provides comprehensive test coverage for the pet spawning system,
## including spawn triggers, cap enforcement, and signal emissions.


## Test result counters
var _tests_passed: int = 0
var _tests_failed: int = 0
var _tests_run: int = 0

## Signal tracking
var _spawned_received: bool = false
var _blocked_received: bool = false
var _activated_received: bool = false
var _last_spawned_type: int = -1
var _last_spawned_column: int = -1
var _last_blocked_type: int = -1
var _last_activated_type: int = -1

## Test instance
var _spawner: PetSpawner


func _ready() -> void:
	print("\n========================================")
	print("PET SPAWNER TEST SUITE")
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
	print("--- Basic Spawn Tests ---")
	_test_pet_spawns_on_sequence_completed()
	_test_spawn_increments_count()
	_test_spawn_emits_valid_column()

	print("\n--- Cap Enforcement Tests ---")
	_test_cap_enforcement()
	_test_cap_per_type_is_three()
	_test_blocked_signal_at_cap()

	print("\n--- Activation Tests ---")
	_test_count_decrements_on_activation()
	_test_activation_emits_signal()
	_test_cannot_go_below_zero()

	print("\n--- Reset Tests ---")
	_test_reset_clears_counts()
	_test_reset_allows_spawning_again()

	print("\n--- Independent Type Cap Tests ---")
	_test_independent_type_caps()
	_test_all_types_can_max_out()

	print("\n--- Edge Case Tests ---")
	_test_invalid_pet_type()
	_test_get_all_counts()
	_test_is_at_cap()


#region Helper Methods

## Creates a fresh PetSpawner instance
func _reset_spawner() -> void:
	if _spawner:
		_spawner.queue_free()

	_spawner = PetSpawner.new()
	add_child(_spawner)
	_disconnect_all_signals()
	_reset_signal_state()


## Disconnects all signal connections
func _disconnect_all_signals() -> void:
	if _spawner.pet_spawned.is_connected(_on_pet_spawned):
		_spawner.pet_spawned.disconnect(_on_pet_spawned)
	if _spawner.pet_spawn_blocked.is_connected(_on_pet_spawn_blocked):
		_spawner.pet_spawn_blocked.disconnect(_on_pet_spawn_blocked)
	if _spawner.pet_activated.is_connected(_on_pet_activated):
		_spawner.pet_activated.disconnect(_on_pet_activated)


## Resets all signal tracking state
func _reset_signal_state() -> void:
	_spawned_received = false
	_blocked_received = false
	_activated_received = false
	_last_spawned_type = -1
	_last_spawned_column = -1
	_last_blocked_type = -1
	_last_activated_type = -1


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


## Connect all signals for testing
func _connect_signals() -> void:
	_spawner.pet_spawned.connect(_on_pet_spawned)
	_spawner.pet_spawn_blocked.connect(_on_pet_spawn_blocked)
	_spawner.pet_activated.connect(_on_pet_activated)

#endregion


#region Signal Handlers

func _on_pet_spawned(pet_type: int, column: int) -> void:
	_spawned_received = true
	_last_spawned_type = pet_type
	_last_spawned_column = column


func _on_pet_spawn_blocked(pet_type: int) -> void:
	_blocked_received = true
	_last_blocked_type = pet_type


func _on_pet_activated(pet_type: int) -> void:
	_activated_received = true
	_last_activated_type = pet_type

#endregion


#region Basic Spawn Tests

## Test: pet_spawned signal emits on sequence completion
func _test_pet_spawns_on_sequence_completed() -> void:
	_reset_spawner()
	_connect_signals()

	_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)

	_assert_true(_spawned_received, "pet_spawned signal should be emitted")
	_assert_equal(_last_spawned_type, TileTypes.Type.BEAR_PET, "Spawned type should be BEAR_PET")


## Test: Count increments after spawn
func _test_spawn_increments_count() -> void:
	_reset_spawner()

	_assert_equal(_spawner.get_count(TileTypes.Type.BEAR_PET), 0, "Initial count should be 0")

	_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)
	_assert_equal(_spawner.get_count(TileTypes.Type.BEAR_PET), 1, "Count should be 1 after spawn")

	_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)
	_assert_equal(_spawner.get_count(TileTypes.Type.BEAR_PET), 2, "Count should be 2 after second spawn")


## Test: Spawned column is within valid range (0-7)
func _test_spawn_emits_valid_column() -> void:
	_reset_spawner()
	_connect_signals()

	# Test multiple spawns to check column range
	var all_valid := true
	for i in 10:
		_reset_signal_state()
		_spawner.reset()
		_spawner.on_sequence_completed(TileTypes.Type.HAWK_PET)

		if _last_spawned_column < 0 or _last_spawned_column >= 8:
			all_valid = false
			break

	_assert_true(all_valid, "All spawned columns should be in range [0, 7]")

#endregion


#region Cap Enforcement Tests

## Test: Spawn is blocked at cap
func _test_cap_enforcement() -> void:
	_reset_spawner()
	_connect_signals()

	# Spawn 3 bears (max)
	for i in 3:
		_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)

	_assert_equal(_spawner.get_count(TileTypes.Type.BEAR_PET), 3, "Should have 3 bears")
	_reset_signal_state()

	# 4th should be blocked
	_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)

	_assert_true(_blocked_received, "pet_spawn_blocked should be emitted at cap")
	_assert_false(_spawned_received, "pet_spawned should NOT be emitted when blocked")
	_assert_equal(_spawner.get_count(TileTypes.Type.BEAR_PET), 3, "Count should stay at 3")


## Test: Cap is exactly 3 per type
func _test_cap_per_type_is_three() -> void:
	_reset_spawner()

	# Verify MAX_PET_PER_TYPE constant
	_assert_equal(PetSpawner.MAX_PET_PER_TYPE, 3, "MAX_PET_PER_TYPE should be 3")


## Test: pet_spawn_blocked signal emits at cap
func _test_blocked_signal_at_cap() -> void:
	_reset_spawner()
	_connect_signals()

	# Fill to cap
	for i in 3:
		_spawner.on_sequence_completed(TileTypes.Type.SNAKE_PET)

	_reset_signal_state()

	# Try to spawn one more
	_spawner.on_sequence_completed(TileTypes.Type.SNAKE_PET)

	_assert_true(_blocked_received, "Should receive blocked signal")
	_assert_equal(_last_blocked_type, TileTypes.Type.SNAKE_PET, "Blocked type should be SNAKE_PET")

#endregion


#region Activation Tests

## Test: Count decrements on activation
func _test_count_decrements_on_activation() -> void:
	_reset_spawner()

	_spawner.on_sequence_completed(TileTypes.Type.HAWK_PET)
	_assert_equal(_spawner.get_count(TileTypes.Type.HAWK_PET), 1, "Should have 1 hawk")

	_spawner.on_pet_activated(TileTypes.Type.HAWK_PET)
	_assert_equal(_spawner.get_count(TileTypes.Type.HAWK_PET), 0, "Should have 0 hawks after activation")


## Test: Activation emits signal
func _test_activation_emits_signal() -> void:
	_reset_spawner()
	_connect_signals()

	_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)
	_reset_signal_state()

	_spawner.on_pet_activated(TileTypes.Type.BEAR_PET)

	_assert_true(_activated_received, "pet_activated signal should be emitted")
	_assert_equal(_last_activated_type, TileTypes.Type.BEAR_PET, "Activated type should be BEAR_PET")


## Test: Count cannot go below zero
func _test_cannot_go_below_zero() -> void:
	_reset_spawner()

	# Activate without any pets
	_spawner.on_pet_activated(TileTypes.Type.SNAKE_PET)
	_assert_equal(_spawner.get_count(TileTypes.Type.SNAKE_PET), 0, "Count should remain 0, not go negative")

	# Spawn one, activate twice
	_spawner.on_sequence_completed(TileTypes.Type.SNAKE_PET)
	_spawner.on_pet_activated(TileTypes.Type.SNAKE_PET)
	_spawner.on_pet_activated(TileTypes.Type.SNAKE_PET)

	_assert_equal(_spawner.get_count(TileTypes.Type.SNAKE_PET), 0, "Count should not go below 0")

#endregion


#region Reset Tests

## Test: Reset clears all counts
func _test_reset_clears_counts() -> void:
	_reset_spawner()

	# Spawn various pets
	_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)
	_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)
	_spawner.on_sequence_completed(TileTypes.Type.HAWK_PET)
	_spawner.on_sequence_completed(TileTypes.Type.SNAKE_PET)

	_assert_equal(_spawner.get_count(TileTypes.Type.BEAR_PET), 2, "Should have 2 bears before reset")
	_assert_equal(_spawner.get_count(TileTypes.Type.HAWK_PET), 1, "Should have 1 hawk before reset")
	_assert_equal(_spawner.get_count(TileTypes.Type.SNAKE_PET), 1, "Should have 1 snake before reset")

	_spawner.reset()

	_assert_equal(_spawner.get_count(TileTypes.Type.BEAR_PET), 0, "Bear count should be 0 after reset")
	_assert_equal(_spawner.get_count(TileTypes.Type.HAWK_PET), 0, "Hawk count should be 0 after reset")
	_assert_equal(_spawner.get_count(TileTypes.Type.SNAKE_PET), 0, "Snake count should be 0 after reset")


## Test: Can spawn again after reset
func _test_reset_allows_spawning_again() -> void:
	_reset_spawner()
	_connect_signals()

	# Fill bears to cap
	for i in 3:
		_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)

	# Reset
	_spawner.reset()
	_reset_signal_state()

	# Should be able to spawn again
	_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)

	_assert_true(_spawned_received, "Should be able to spawn after reset")
	_assert_equal(_spawner.get_count(TileTypes.Type.BEAR_PET), 1, "Should have 1 bear after reset spawn")

#endregion


#region Independent Type Cap Tests

## Test: Each pet type has independent cap
func _test_independent_type_caps() -> void:
	_reset_spawner()
	_connect_signals()

	# Fill bears to cap
	for i in 3:
		_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)

	_reset_signal_state()

	# Hawks should still work
	_spawner.on_sequence_completed(TileTypes.Type.HAWK_PET)

	_assert_true(_spawned_received, "Hawk should spawn even though Bears are at cap")
	_assert_false(_blocked_received, "Hawk spawn should not be blocked")
	_assert_equal(_spawner.get_count(TileTypes.Type.HAWK_PET), 1, "Should have 1 hawk")


## Test: All three types can reach max independently
func _test_all_types_can_max_out() -> void:
	_reset_spawner()

	# Fill all types to cap
	for i in 3:
		_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)
		_spawner.on_sequence_completed(TileTypes.Type.HAWK_PET)
		_spawner.on_sequence_completed(TileTypes.Type.SNAKE_PET)

	_assert_equal(_spawner.get_count(TileTypes.Type.BEAR_PET), 3, "Bears should be at cap")
	_assert_equal(_spawner.get_count(TileTypes.Type.HAWK_PET), 3, "Hawks should be at cap")
	_assert_equal(_spawner.get_count(TileTypes.Type.SNAKE_PET), 3, "Snakes should be at cap")

#endregion


#region Edge Case Tests

## Test: Invalid pet type is handled gracefully
func _test_invalid_pet_type() -> void:
	_reset_spawner()
	_connect_signals()

	# Try to spawn with invalid type (SWORD is not a pet type)
	_spawner.on_sequence_completed(TileTypes.Type.SWORD)

	_assert_false(_spawned_received, "Should not spawn for invalid pet type")
	_assert_false(_blocked_received, "Should not block for invalid pet type")

	# Count should remain 0 for invalid type
	_assert_equal(_spawner.get_count(TileTypes.Type.SWORD), 0, "Invalid type should have 0 count")


## Test: get_all_counts returns dictionary
func _test_get_all_counts() -> void:
	_reset_spawner()

	_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)
	_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)
	_spawner.on_sequence_completed(TileTypes.Type.HAWK_PET)

	var counts := _spawner.get_all_counts()

	_assert_equal(counts.get(TileTypes.Type.BEAR_PET), 2, "get_all_counts should return 2 for bears")
	_assert_equal(counts.get(TileTypes.Type.HAWK_PET), 1, "get_all_counts should return 1 for hawks")
	_assert_equal(counts.get(TileTypes.Type.SNAKE_PET), 0, "get_all_counts should return 0 for snakes")


## Test: is_at_cap helper method
func _test_is_at_cap() -> void:
	_reset_spawner()

	_assert_false(_spawner.is_at_cap(TileTypes.Type.BEAR_PET), "Should not be at cap initially")

	# Fill to cap
	for i in 3:
		_spawner.on_sequence_completed(TileTypes.Type.BEAR_PET)

	_assert_true(_spawner.is_at_cap(TileTypes.Type.BEAR_PET), "Should be at cap after 3 spawns")

	# Other types should not be at cap
	_assert_false(_spawner.is_at_cap(TileTypes.Type.HAWK_PET), "Hawks should not be at cap")

#endregion
