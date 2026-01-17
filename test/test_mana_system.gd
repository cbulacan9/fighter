extends Node
## Test Runner for ManaSystem and ManaBar classes
## Validates mana system behavior in isolation
##
## Note: This test uses a workaround for GDScript's type system.
## The ManaSystem expects Fighter type but we use MockFighter (extends Node).
## We use untyped calls via Callable or Variant to bypass static type checking.

# Test tracking
var _tests_passed: int = 0
var _tests_failed: int = 0
var _current_test: String = ""

# Test instances - using variant type to allow MockFighter
var _mana_system: ManaSystem
var _fighter1: MockFighter
var _fighter2: MockFighter

# Signal tracking for signal tests
var _signal_received: bool = false
var _signal_data: Dictionary = {}


func _ready() -> void:
	print("\n========================================")
	print("  MANA SYSTEM TEST SUITE")
	print("========================================\n")

	_run_all_tests()

	print("\n========================================")
	print("  TEST RESULTS")
	print("========================================")
	print("  Passed: %d" % _tests_passed)
	print("  Failed: %d" % _tests_failed)
	print("  Total:  %d" % (_tests_passed + _tests_failed))
	print("========================================\n")

	if _tests_failed > 0:
		print("SOME TESTS FAILED!")
	else:
		print("ALL TESTS PASSED!")


func _run_all_tests() -> void:
	# Setup tests
	print("[Category: Setup Tests]")
	_run_test("_test_setup_single_bar")
	_run_test("_test_setup_dual_bar")
	_run_test("_test_setup_no_mana")

	# Add mana tests
	print("\n[Category: Add Mana Tests]")
	_run_test("_test_add_mana")
	_run_test("_test_add_mana_capped")
	_run_test("_test_add_mana_from_match")

	# Drain mana tests
	print("\n[Category: Drain Mana Tests]")
	_run_test("_test_drain_mana")
	_run_test("_test_drain_all")
	_run_test("_test_drain_empty")

	# Multi-bar tests
	print("\n[Category: Multi-bar Tests]")
	_run_test("_test_dual_bar_independent")
	_run_test("_test_all_bars_full_check")

	# Blocking tests
	print("\n[Category: Blocking Tests]")
	_run_test("_test_mana_block")
	_run_test("_test_mana_block_timer")

	# Signal tests
	print("\n[Category: Signal Tests]")
	_run_test("_test_mana_changed_signal")
	_run_test("_test_mana_full_signal")
	_run_test("_test_all_bars_full_signal")

	# Reset tests
	print("\n[Category: Reset Tests]")
	_run_test("_test_reset_fighter")
	_run_test("_test_reset_all")

	# Ultimate tests
	print("\n[Category: Ultimate Tests]")
	_run_test("_test_can_use_ultimate_single")
	_run_test("_test_can_use_ultimate_dual")

	# Tick tests
	print("\n[Category: Tick Tests]")
	_run_test("_test_tick_decay")
	_run_test("_test_tick_block_expiry")


func _run_test(test_name: String) -> void:
	_current_test = test_name
	_setup_test()

	var passed := false
	match test_name:
		"_test_setup_single_bar":
			passed = _test_setup_single_bar()
		"_test_setup_dual_bar":
			passed = _test_setup_dual_bar()
		"_test_setup_no_mana":
			passed = _test_setup_no_mana()
		"_test_add_mana":
			passed = _test_add_mana()
		"_test_add_mana_capped":
			passed = _test_add_mana_capped()
		"_test_add_mana_from_match":
			passed = _test_add_mana_from_match()
		"_test_drain_mana":
			passed = _test_drain_mana()
		"_test_drain_all":
			passed = _test_drain_all()
		"_test_drain_empty":
			passed = _test_drain_empty()
		"_test_dual_bar_independent":
			passed = _test_dual_bar_independent()
		"_test_all_bars_full_check":
			passed = _test_all_bars_full_check()
		"_test_mana_block":
			passed = _test_mana_block()
		"_test_mana_block_timer":
			passed = _test_mana_block_timer()
		"_test_mana_changed_signal":
			passed = _test_mana_changed_signal()
		"_test_mana_full_signal":
			passed = _test_mana_full_signal()
		"_test_all_bars_full_signal":
			passed = _test_all_bars_full_signal()
		"_test_reset_fighter":
			passed = _test_reset_fighter()
		"_test_reset_all":
			passed = _test_reset_all()
		"_test_can_use_ultimate_single":
			passed = _test_can_use_ultimate_single()
		"_test_can_use_ultimate_dual":
			passed = _test_can_use_ultimate_dual()
		"_test_tick_decay":
			passed = _test_tick_decay()
		"_test_tick_block_expiry":
			passed = _test_tick_block_expiry()
		_:
			print("  [SKIP] Unknown test: %s" % test_name)
			return

	if passed:
		_tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_tests_failed += 1
		print("  [FAIL] %s" % test_name)

	_teardown_test()


func _setup_test() -> void:
	_mana_system = ManaSystem.new()
	_fighter1 = _get_mock_fighter(0)
	_fighter2 = _get_mock_fighter(1)
	_fighter1.reset()
	_fighter2.reset()
	_fighter1.mana_system = _mana_system
	_fighter2.mana_system = _mana_system
	_signal_received = false
	_signal_data.clear()


func _teardown_test() -> void:
	_mana_system = null


func _get_mock_fighter(index: int) -> MockFighter:
	var fighters := get_tree().get_nodes_in_group("mock_fighters")
	if index < fighters.size():
		return fighters[index] as MockFighter
	return null


# =============================================================================
# HELPER METHODS - ManaSystem Wrappers (bypass type checking)
# =============================================================================
# These wrappers use call() to bypass GDScript's static type checking,
# allowing us to pass MockFighter where Fighter is expected.

func _setup_fighter_mock(fighter: MockFighter, config: ManaConfig) -> void:
	# Use call() to bypass type checking - ManaSystem.setup_fighter expects Fighter
	_mana_system.call("setup_fighter", fighter, config)


func _add_mana_mock(fighter: MockFighter, amount: int, bar_index: int = 0) -> int:
	return _mana_system.call("add_mana", fighter, amount, bar_index)


func _add_mana_from_match_mock(fighter: MockFighter, match_count: int, bar_index: int = 0) -> int:
	return _mana_system.call("add_mana_from_match", fighter, match_count, bar_index)


func _drain_mock(fighter: MockFighter, amount: int, bar_index: int = 0) -> int:
	return _mana_system.call("drain", fighter, amount, bar_index)


func _drain_all_mock(fighter: MockFighter) -> int:
	return _mana_system.call("drain_all", fighter)


func _block_mana_mock(fighter: MockFighter, duration: float, bar_index: int = -1) -> void:
	_mana_system.call("block_mana", fighter, duration, bar_index)


func _get_mana_mock(fighter: MockFighter, bar_index: int = 0) -> int:
	return _mana_system.call("get_mana", fighter, bar_index)


func _get_max_mana_mock(fighter: MockFighter, bar_index: int = 0) -> int:
	return _mana_system.call("get_max_mana", fighter, bar_index)


func _get_bar_count_mock(fighter: MockFighter) -> int:
	return _mana_system.call("get_bar_count", fighter)


func _has_fighter_mock(fighter: MockFighter) -> bool:
	return _mana_system.call("has_fighter", fighter)


func _is_full_mock(fighter: MockFighter, bar_index: int = 0) -> bool:
	return _mana_system.call("is_full", fighter, bar_index)


func _are_all_bars_full_mock(fighter: MockFighter) -> bool:
	return _mana_system.call("are_all_bars_full", fighter)


func _is_bar_blocked_mock(fighter: MockFighter, bar_index: int = 0) -> bool:
	return _mana_system.call("is_bar_blocked", fighter, bar_index)


func _can_use_ultimate_mock(fighter: MockFighter) -> bool:
	return _mana_system.call("can_use_ultimate", fighter)


func _reset_fighter_mock(fighter: MockFighter) -> void:
	_mana_system.call("reset_fighter", fighter)


# =============================================================================
# HELPER METHODS - Config Creation
# =============================================================================

func _create_single_bar_config() -> ManaConfig:
	var config := ManaConfig.new()
	config.bar_count = 1
	config.max_mana = [100]
	config.mana_per_match = {3: 10, 4: 20, 5: 35}
	config.decay_rate = 0.0
	config.require_all_bars_full = true
	return config


func _create_dual_bar_config() -> ManaConfig:
	var config := ManaConfig.new()
	config.bar_count = 2
	config.max_mana = [100, 100]
	config.mana_per_match = {3: 10, 4: 20, 5: 35}
	config.decay_rate = 0.0
	config.require_all_bars_full = true
	return config


func _create_no_mana_config() -> ManaConfig:
	var config := ManaConfig.new()
	config.bar_count = 0
	config.max_mana = []
	config.mana_per_match = {}
	config.decay_rate = 0.0
	config.require_all_bars_full = false
	return config


func _create_decay_config(decay_rate: float) -> ManaConfig:
	var config := ManaConfig.new()
	config.bar_count = 1
	config.max_mana = [100]
	config.mana_per_match = {3: 10, 4: 20, 5: 35}
	config.decay_rate = decay_rate
	config.require_all_bars_full = true
	return config


# =============================================================================
# SETUP TESTS
# =============================================================================

func _test_setup_single_bar() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Verify fighter is registered
	if not _has_fighter_mock(_fighter1):
		print("    Error: Fighter not registered")
		return false

	# Verify bar count
	if _get_bar_count_mock(_fighter1) != 1:
		print("    Error: Expected 1 bar, got %d" % _get_bar_count_mock(_fighter1))
		return false

	# Verify max mana
	if _get_max_mana_mock(_fighter1, 0) != 100:
		print("    Error: Expected max mana 100, got %d" % _get_max_mana_mock(_fighter1, 0))
		return false

	# Verify initial mana is 0
	if _get_mana_mock(_fighter1, 0) != 0:
		print("    Error: Expected initial mana 0, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	return true


func _test_setup_dual_bar() -> bool:
	var config := _create_dual_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Verify bar count
	if _get_bar_count_mock(_fighter1) != 2:
		print("    Error: Expected 2 bars, got %d" % _get_bar_count_mock(_fighter1))
		return false

	# Verify both bars have correct max mana
	if _get_max_mana_mock(_fighter1, 0) != 100:
		print("    Error: Bar 0 expected max 100, got %d" % _get_max_mana_mock(_fighter1, 0))
		return false

	if _get_max_mana_mock(_fighter1, 1) != 100:
		print("    Error: Bar 1 expected max 100, got %d" % _get_max_mana_mock(_fighter1, 1))
		return false

	return true


func _test_setup_no_mana() -> bool:
	var config := _create_no_mana_config()
	_setup_fighter_mock(_fighter1, config)

	# Fighter should NOT be registered with 0 bars
	if _has_fighter_mock(_fighter1):
		print("    Error: Fighter should not be registered with 0 bars")
		return false

	# Bar count should return 0
	if _get_bar_count_mock(_fighter1) != 0:
		print("    Error: Expected 0 bars, got %d" % _get_bar_count_mock(_fighter1))
		return false

	return true


# =============================================================================
# ADD MANA TESTS
# =============================================================================

func _test_add_mana() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Add mana and verify
	var added := _add_mana_mock(_fighter1, 50)

	if added != 50:
		print("    Error: Expected to add 50, actually added %d" % added)
		return false

	if _get_mana_mock(_fighter1, 0) != 50:
		print("    Error: Expected mana 50, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	return true


func _test_add_mana_capped() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Add more than max
	_add_mana_mock(_fighter1, 150)

	# Should be capped at max (100)
	if _get_mana_mock(_fighter1, 0) != 100:
		print("    Error: Expected mana capped at 100, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	# Try to add more when already full
	var added := _add_mana_mock(_fighter1, 50)

	if added != 0:
		print("    Error: Expected 0 added when full, got %d" % added)
		return false

	return true


func _test_add_mana_from_match() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Test 3-match (should give 10)
	var added := _add_mana_from_match_mock(_fighter1, 3)
	if added != 10:
		print("    Error: 3-match expected 10 mana, got %d" % added)
		return false

	# Test 4-match (should give 20)
	added = _add_mana_from_match_mock(_fighter1, 4)
	if added != 20:
		print("    Error: 4-match expected 20 mana, got %d" % added)
		return false

	# Test 5-match (should give 35)
	added = _add_mana_from_match_mock(_fighter1, 5)
	if added != 35:
		print("    Error: 5-match expected 35 mana, got %d" % added)
		return false

	# Total should be 10 + 20 + 35 = 65
	if _get_mana_mock(_fighter1, 0) != 65:
		print("    Error: Expected total mana 65, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	return true


# =============================================================================
# DRAIN MANA TESTS
# =============================================================================

func _test_drain_mana() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Setup: Add some mana first
	_add_mana_mock(_fighter1, 80)

	# Drain partial amount
	var drained := _drain_mock(_fighter1, 30)

	if drained != 30:
		print("    Error: Expected to drain 30, actually drained %d" % drained)
		return false

	if _get_mana_mock(_fighter1, 0) != 50:
		print("    Error: Expected mana 50 after drain, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	return true


func _test_drain_all() -> bool:
	var config := _create_dual_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Setup: Add mana to both bars
	_add_mana_mock(_fighter1, 80, 0)
	_add_mana_mock(_fighter1, 60, 1)

	# Drain all
	var total_drained := _drain_all_mock(_fighter1)

	if total_drained != 140:
		print("    Error: Expected to drain 140 total, actually drained %d" % total_drained)
		return false

	if _get_mana_mock(_fighter1, 0) != 0:
		print("    Error: Bar 0 should be 0, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	if _get_mana_mock(_fighter1, 1) != 0:
		print("    Error: Bar 1 should be 0, got %d" % _get_mana_mock(_fighter1, 1))
		return false

	return true


func _test_drain_empty() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Try to drain from empty bar
	var drained := _drain_mock(_fighter1, 50)

	if drained != 0:
		print("    Error: Expected to drain 0 from empty bar, got %d" % drained)
		return false

	# Add some mana, then drain more than available
	_add_mana_mock(_fighter1, 30)
	drained = _drain_mock(_fighter1, 50)

	if drained != 30:
		print("    Error: Expected to drain only 30, got %d" % drained)
		return false

	if _get_mana_mock(_fighter1, 0) != 0:
		print("    Error: Mana should be 0, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	return true


# =============================================================================
# MULTI-BAR TESTS
# =============================================================================

func _test_dual_bar_independent() -> bool:
	var config := _create_dual_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Add mana to bar 0 only
	_add_mana_mock(_fighter1, 50, 0)

	if _get_mana_mock(_fighter1, 0) != 50:
		print("    Error: Bar 0 should be 50, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	if _get_mana_mock(_fighter1, 1) != 0:
		print("    Error: Bar 1 should still be 0, got %d" % _get_mana_mock(_fighter1, 1))
		return false

	# Add mana to bar 1 only
	_add_mana_mock(_fighter1, 70, 1)

	if _get_mana_mock(_fighter1, 0) != 50:
		print("    Error: Bar 0 should still be 50, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	if _get_mana_mock(_fighter1, 1) != 70:
		print("    Error: Bar 1 should be 70, got %d" % _get_mana_mock(_fighter1, 1))
		return false

	return true


func _test_all_bars_full_check() -> bool:
	var config := _create_dual_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Neither bar full
	if _are_all_bars_full_mock(_fighter1):
		print("    Error: Should not report all bars full when empty")
		return false

	# Fill bar 0 only
	_add_mana_mock(_fighter1, 100, 0)

	if _are_all_bars_full_mock(_fighter1):
		print("    Error: Should not report all bars full when only one is full")
		return false

	if not _is_full_mock(_fighter1, 0):
		print("    Error: Bar 0 should report as full")
		return false

	# Fill bar 1
	_add_mana_mock(_fighter1, 100, 1)

	if not _are_all_bars_full_mock(_fighter1):
		print("    Error: Should report all bars full when both are full")
		return false

	return true


# =============================================================================
# BLOCKING TESTS
# =============================================================================

func _test_mana_block() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Add some mana first
	_add_mana_mock(_fighter1, 30)

	# Block mana gain
	_block_mana_mock(_fighter1, 5.0)

	# Verify blocked
	if not _is_bar_blocked_mock(_fighter1, 0):
		print("    Error: Bar should be blocked")
		return false

	# Try to add mana while blocked
	var added := _add_mana_mock(_fighter1, 50)

	if added != 0:
		print("    Error: Should not add mana while blocked, added %d" % added)
		return false

	if _get_mana_mock(_fighter1, 0) != 30:
		print("    Error: Mana should still be 30, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	return true


func _test_mana_block_timer() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Block for 2 seconds
	_block_mana_mock(_fighter1, 2.0)

	# Verify blocked initially
	if not _is_bar_blocked_mock(_fighter1, 0):
		print("    Error: Bar should be blocked initially")
		return false

	# Tick for 1 second - should still be blocked
	_mana_system.tick(1.0)

	if not _is_bar_blocked_mock(_fighter1, 0):
		print("    Error: Bar should still be blocked after 1 second")
		return false

	# Tick for another 1.5 seconds - should now be unblocked
	_mana_system.tick(1.5)

	if _is_bar_blocked_mock(_fighter1, 0):
		print("    Error: Bar should be unblocked after block expires")
		return false

	# Verify can add mana again
	var added := _add_mana_mock(_fighter1, 50)
	if added != 50:
		print("    Error: Should be able to add mana after block expires, added %d" % added)
		return false

	return true


# =============================================================================
# SIGNAL TESTS
# =============================================================================

func _test_mana_changed_signal() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Connect to signal
	_signal_received = false
	_mana_system.mana_changed.connect(_on_mana_changed_test)

	# Add mana to trigger signal
	_add_mana_mock(_fighter1, 50)

	if not _signal_received:
		print("    Error: mana_changed signal not received")
		_mana_system.mana_changed.disconnect(_on_mana_changed_test)
		return false

	if _signal_data.get("current") != 50:
		print("    Error: Signal current mana should be 50, got %s" % str(_signal_data.get("current")))
		_mana_system.mana_changed.disconnect(_on_mana_changed_test)
		return false

	if _signal_data.get("max_value") != 100:
		print("    Error: Signal max mana should be 100, got %s" % str(_signal_data.get("max_value")))
		_mana_system.mana_changed.disconnect(_on_mana_changed_test)
		return false

	_mana_system.mana_changed.disconnect(_on_mana_changed_test)
	return true


func _on_mana_changed_test(fighter, bar_index: int, current: int, max_value: int) -> void:
	_signal_received = true
	_signal_data["fighter"] = fighter
	_signal_data["bar_index"] = bar_index
	_signal_data["current"] = current
	_signal_data["max_value"] = max_value


func _test_mana_full_signal() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Connect to signal
	_signal_received = false
	_mana_system.mana_full.connect(_on_mana_full_test)

	# Add mana but not full
	_add_mana_mock(_fighter1, 50)

	if _signal_received:
		print("    Error: mana_full signal should not fire when not full")
		_mana_system.mana_full.disconnect(_on_mana_full_test)
		return false

	# Fill to max
	_add_mana_mock(_fighter1, 50)

	if not _signal_received:
		print("    Error: mana_full signal not received when bar becomes full")
		_mana_system.mana_full.disconnect(_on_mana_full_test)
		return false

	_mana_system.mana_full.disconnect(_on_mana_full_test)
	return true


func _on_mana_full_test(fighter, bar_index: int) -> void:
	_signal_received = true
	_signal_data["fighter"] = fighter
	_signal_data["bar_index"] = bar_index


func _test_all_bars_full_signal() -> bool:
	var config := _create_dual_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Connect to signal
	_signal_received = false
	_mana_system.all_bars_full.connect(_on_all_bars_full_test)

	# Fill first bar only
	_add_mana_mock(_fighter1, 100, 0)

	if _signal_received:
		print("    Error: all_bars_full signal should not fire when only one bar is full")
		_mana_system.all_bars_full.disconnect(_on_all_bars_full_test)
		return false

	# Fill second bar
	_add_mana_mock(_fighter1, 100, 1)

	if not _signal_received:
		print("    Error: all_bars_full signal not received when all bars become full")
		_mana_system.all_bars_full.disconnect(_on_all_bars_full_test)
		return false

	_mana_system.all_bars_full.disconnect(_on_all_bars_full_test)
	return true


func _on_all_bars_full_test(fighter) -> void:
	_signal_received = true
	_signal_data["fighter"] = fighter


# =============================================================================
# RESET TESTS
# =============================================================================

func _test_reset_fighter() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Add mana and block
	_add_mana_mock(_fighter1, 75)
	_block_mana_mock(_fighter1, 5.0)

	# Verify state before reset
	if _get_mana_mock(_fighter1, 0) != 75:
		print("    Error: Setup failed - mana should be 75")
		return false

	if not _is_bar_blocked_mock(_fighter1, 0):
		print("    Error: Setup failed - bar should be blocked")
		return false

	# Reset
	_reset_fighter_mock(_fighter1)

	# Verify reset cleared mana
	if _get_mana_mock(_fighter1, 0) != 0:
		print("    Error: Mana should be 0 after reset, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	# Verify reset cleared block
	if _is_bar_blocked_mock(_fighter1, 0):
		print("    Error: Block should be cleared after reset")
		return false

	return true


func _test_reset_all() -> bool:
	var config1 := _create_single_bar_config()
	var config2 := _create_dual_bar_config()

	_setup_fighter_mock(_fighter1, config1)
	_setup_fighter_mock(_fighter2, config2)

	# Add mana to both fighters
	_add_mana_mock(_fighter1, 60)
	_add_mana_mock(_fighter2, 80, 0)
	_add_mana_mock(_fighter2, 40, 1)

	# Reset all
	_mana_system.reset_all()

	# Verify fighter 1 reset
	if _get_mana_mock(_fighter1, 0) != 0:
		print("    Error: Fighter 1 mana should be 0, got %d" % _get_mana_mock(_fighter1, 0))
		return false

	# Verify fighter 2 reset (both bars)
	if _get_mana_mock(_fighter2, 0) != 0:
		print("    Error: Fighter 2 bar 0 should be 0, got %d" % _get_mana_mock(_fighter2, 0))
		return false

	if _get_mana_mock(_fighter2, 1) != 0:
		print("    Error: Fighter 2 bar 1 should be 0, got %d" % _get_mana_mock(_fighter2, 1))
		return false

	return true


# =============================================================================
# ULTIMATE TESTS
# =============================================================================

func _test_can_use_ultimate_single() -> bool:
	var config := _create_single_bar_config()
	config.require_all_bars_full = true
	_setup_fighter_mock(_fighter1, config)

	# Not full - can't use ultimate
	_add_mana_mock(_fighter1, 50)

	if _can_use_ultimate_mock(_fighter1):
		print("    Error: Should not be able to use ultimate when not full")
		return false

	# Fill to max
	_add_mana_mock(_fighter1, 50)

	if not _can_use_ultimate_mock(_fighter1):
		print("    Error: Should be able to use ultimate when full")
		return false

	return true


func _test_can_use_ultimate_dual() -> bool:
	var config := _create_dual_bar_config()
	config.require_all_bars_full = true
	_setup_fighter_mock(_fighter1, config)

	# Fill only one bar
	_add_mana_mock(_fighter1, 100, 0)

	if _can_use_ultimate_mock(_fighter1):
		print("    Error: Should not be able to use ultimate with only one bar full")
		return false

	# Fill second bar
	_add_mana_mock(_fighter1, 100, 1)

	if not _can_use_ultimate_mock(_fighter1):
		print("    Error: Should be able to use ultimate when all bars full")
		return false

	return true


# =============================================================================
# TICK TESTS
# =============================================================================

func _test_tick_decay() -> bool:
	# Create config with decay rate of 10 mana per second
	var config := _create_decay_config(10.0)
	_setup_fighter_mock(_fighter1, config)

	# Add mana
	_add_mana_mock(_fighter1, 50)

	# Tick for 2 seconds (should decay 20 mana)
	_mana_system.tick(2.0)

	var current_mana := _get_mana_mock(_fighter1, 0)

	# Expected: 50 - 20 = 30 (decay is int(10.0 * 2.0) = 20)
	if current_mana != 30:
		print("    Error: Expected mana 30 after decay, got %d" % current_mana)
		return false

	# Tick until empty
	_mana_system.tick(5.0)

	current_mana = _get_mana_mock(_fighter1, 0)
	if current_mana != 0:
		print("    Error: Mana should decay to 0, got %d" % current_mana)
		return false

	return true


func _test_tick_block_expiry() -> bool:
	var config := _create_single_bar_config()
	_setup_fighter_mock(_fighter1, config)

	# Block for 1 second
	_block_mana_mock(_fighter1, 1.0)

	if not _is_bar_blocked_mock(_fighter1, 0):
		print("    Error: Bar should be blocked initially")
		return false

	# Tick for 0.5 seconds
	_mana_system.tick(0.5)

	if not _is_bar_blocked_mock(_fighter1, 0):
		print("    Error: Bar should still be blocked after 0.5 seconds")
		return false

	# Tick for another 0.6 seconds (total 1.1 seconds)
	_mana_system.tick(0.6)

	if _is_bar_blocked_mock(_fighter1, 0):
		print("    Error: Bar should be unblocked after block duration expires")
		return false

	return true
