extends Node
## Comprehensive test suite for StatusEffectManager.
## Run this scene to validate status effect behavior in isolation.

# Test results tracking
var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _current_test: String = ""

# Test fixtures
var _manager: StatusEffectManager
var _fighter1: MockFighter
var _fighter2: MockFighter


func _ready() -> void:
	print("\n========================================")
	print("  STATUS EFFECT SYSTEM TEST SUITE")
	print("========================================\n")

	_run_all_tests()

	print("\n========================================")
	print("  TEST RESULTS")
	print("========================================")
	print("  Total:  %d" % _tests_run)
	print("  Passed: %d" % _tests_passed)
	print("  Failed: %d" % _tests_failed)
	print("========================================\n")

	if _tests_failed > 0:
		print("SOME TESTS FAILED!")
	else:
		print("ALL TESTS PASSED!")


func _run_all_tests() -> void:
	# Basic Application Tests
	print("[CATEGORY] Basic Application Tests")
	_test_apply_single_effect()
	_test_apply_multiple_effects()
	_test_effect_removal()
	_test_cleanse_all()
	_test_cleanse_specific()

	# Stacking Behavior Tests
	print("\n[CATEGORY] Stacking Behavior Tests")
	_test_additive_stacking()
	_test_refresh_stacking()
	_test_replace_stacking()
	_test_max_stacks()

	# Duration Tests
	print("\n[CATEGORY] Duration Tests")
	_test_duration_expiry()
	_test_permanent_effect()

	# Tick Damage Tests
	print("\n[CATEGORY] Tick Damage Tests")
	_test_poison_tick_damage()
	_test_bleed_on_match()

	# Modifier Tests
	print("\n[CATEGORY] Modifier Tests")
	_test_attack_up_modifier()
	_test_dodge_chance()
	_test_evasion_auto_miss()


# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func _setup() -> void:
	_manager = StatusEffectManager.new()
	_fighter1 = _get_mock_fighter(0)
	_fighter2 = _get_mock_fighter(1)
	_fighter1.status_manager = _manager
	_fighter2.status_manager = _manager
	_fighter1.reset()
	_fighter2.reset()


func _teardown() -> void:
	_manager.clear_all()
	_manager = null


func _get_mock_fighter(index: int) -> MockFighter:
	var fighters := get_tree().get_nodes_in_group("mock_fighters")
	if index < fighters.size():
		return fighters[index] as MockFighter
	return null


# =============================================================================
# HELPER METHODS - Create Test Effect Data
# =============================================================================

func _create_poison_data(damage: float = 5.0, duration: float = 3.0, stacks: int = 99) -> StatusEffectData:
	var data := StatusEffectData.new()
	data.effect_id = "test_poison"
	data.display_name = "Test Poison"
	data.effect_type = StatusTypes.StatusType.POISON
	data.duration = duration
	data.tick_interval = 1.0
	data.max_stacks = stacks
	data.stack_behavior = StatusTypes.StackBehavior.ADDITIVE
	data.tick_behavior = StatusTypes.TickBehavior.ON_TIME
	data.base_value = damage
	data.value_per_stack = 2.0
	return data


func _create_bleed_data(damage: float = 10.0, duration: float = 5.0) -> StatusEffectData:
	var data := StatusEffectData.new()
	data.effect_id = "test_bleed"
	data.display_name = "Test Bleed"
	data.effect_type = StatusTypes.StatusType.BLEED
	data.duration = duration
	data.max_stacks = 5
	data.stack_behavior = StatusTypes.StackBehavior.ADDITIVE
	data.tick_behavior = StatusTypes.TickBehavior.ON_MATCH
	data.base_value = damage
	data.value_per_stack = 5.0
	return data


func _create_attack_up_data(modifier: float = 0.25, duration: float = 5.0) -> StatusEffectData:
	var data := StatusEffectData.new()
	data.effect_id = "test_attack_up"
	data.display_name = "Test Attack Up"
	data.effect_type = StatusTypes.StatusType.ATTACK_UP
	data.duration = duration
	data.max_stacks = 3
	data.stack_behavior = StatusTypes.StackBehavior.ADDITIVE
	data.tick_behavior = StatusTypes.TickBehavior.ON_TIME
	data.base_value = modifier
	data.value_per_stack = 0.1
	return data


func _create_dodge_data(chance: float = 0.5, duration: float = 5.0) -> StatusEffectData:
	var data := StatusEffectData.new()
	data.effect_id = "test_dodge"
	data.display_name = "Test Dodge"
	data.effect_type = StatusTypes.StatusType.DODGE
	data.duration = duration
	data.max_stacks = 1
	data.stack_behavior = StatusTypes.StackBehavior.REFRESH
	data.tick_behavior = StatusTypes.TickBehavior.ON_TIME
	data.base_value = chance
	data.value_per_stack = 0.0
	return data


func _create_evasion_data(duration: float = 0.0) -> StatusEffectData:
	var data := StatusEffectData.new()
	data.effect_id = "test_evasion"
	data.display_name = "Test Evasion"
	data.effect_type = StatusTypes.StatusType.EVASION
	data.duration = duration  # 0 = permanent until consumed
	data.max_stacks = 3
	data.stack_behavior = StatusTypes.StackBehavior.ADDITIVE
	data.tick_behavior = StatusTypes.TickBehavior.ON_TIME
	data.base_value = 1.0
	data.value_per_stack = 0.0
	return data


func _create_refresh_effect_data(duration: float = 3.0) -> StatusEffectData:
	var data := StatusEffectData.new()
	data.effect_id = "test_refresh"
	data.display_name = "Test Refresh Effect"
	data.effect_type = StatusTypes.StatusType.ATTACK_UP
	data.duration = duration
	data.max_stacks = 1
	data.stack_behavior = StatusTypes.StackBehavior.REFRESH
	data.tick_behavior = StatusTypes.TickBehavior.ON_TIME
	data.base_value = 0.1
	data.value_per_stack = 0.0
	return data


func _create_replace_effect_data(value: float = 10.0, duration: float = 3.0) -> StatusEffectData:
	var data := StatusEffectData.new()
	data.effect_id = "test_replace"
	data.display_name = "Test Replace Effect"
	data.effect_type = StatusTypes.StatusType.ATTACK_UP
	data.duration = duration
	data.max_stacks = 1
	data.stack_behavior = StatusTypes.StackBehavior.REPLACE
	data.tick_behavior = StatusTypes.TickBehavior.ON_TIME
	data.base_value = value
	data.value_per_stack = 0.0
	return data


# =============================================================================
# ASSERTION HELPERS
# =============================================================================

func _assert_true(condition: bool, message: String) -> bool:
	if condition:
		return true
	else:
		_fail(message)
		return false


func _assert_false(condition: bool, message: String) -> bool:
	return _assert_true(not condition, message)


func _assert_equals(expected, actual, message: String) -> bool:
	if expected == actual:
		return true
	else:
		_fail("%s (expected: %s, got: %s)" % [message, str(expected), str(actual)])
		return false


func _assert_greater(value, threshold, message: String) -> bool:
	if value > threshold:
		return true
	else:
		_fail("%s (value: %s, threshold: %s)" % [message, str(value), str(threshold)])
		return false


func _assert_less(value, threshold, message: String) -> bool:
	if value < threshold:
		return true
	else:
		_fail("%s (value: %s, threshold: %s)" % [message, str(value), str(threshold)])
		return false


func _assert_approximately(expected: float, actual: float, tolerance: float, message: String) -> bool:
	if absf(expected - actual) <= tolerance:
		return true
	else:
		_fail("%s (expected: %s, got: %s, tolerance: %s)" % [message, str(expected), str(actual), str(tolerance)])
		return false


func _pass(test_name: String) -> void:
	_tests_run += 1
	_tests_passed += 1
	print("  [PASS] %s" % test_name)


func _fail(message: String) -> void:
	_tests_run += 1
	_tests_failed += 1
	print("  [FAIL] %s: %s" % [_current_test, message])


# =============================================================================
# BASIC APPLICATION TESTS
# =============================================================================

func _test_apply_single_effect() -> void:
	_current_test = "test_apply_single_effect"
	_setup()

	var poison_data := _create_poison_data()
	_manager.apply(_fighter1, poison_data)

	if _assert_true(_manager.has_effect(_fighter1, StatusTypes.StatusType.POISON),
			"Fighter should have poison effect"):
		if _assert_equals(1, _manager.get_stacks(_fighter1, StatusTypes.StatusType.POISON),
				"Poison should have 1 stack"):
			_pass(_current_test)

	_teardown()


func _test_apply_multiple_effects() -> void:
	_current_test = "test_apply_multiple_effects"
	_setup()

	var poison_data := _create_poison_data()
	var attack_up_data := _create_attack_up_data()

	_manager.apply(_fighter1, poison_data)
	_manager.apply(_fighter1, attack_up_data)

	var has_poison := _manager.has_effect(_fighter1, StatusTypes.StatusType.POISON)
	var has_attack := _manager.has_effect(_fighter1, StatusTypes.StatusType.ATTACK_UP)

	if _assert_true(has_poison, "Fighter should have poison effect"):
		if _assert_true(has_attack, "Fighter should have attack up effect"):
			var all_effects := _manager.get_all_effects(_fighter1)
			if _assert_equals(2, all_effects.size(), "Fighter should have exactly 2 effects"):
				_pass(_current_test)

	_teardown()


func _test_effect_removal() -> void:
	_current_test = "test_effect_removal"
	_setup()

	var poison_data := _create_poison_data()
	_manager.apply(_fighter1, poison_data)

	if not _assert_true(_manager.has_effect(_fighter1, StatusTypes.StatusType.POISON),
			"Fighter should have poison before removal"):
		_teardown()
		return

	_manager.remove(_fighter1, StatusTypes.StatusType.POISON)

	if _assert_false(_manager.has_effect(_fighter1, StatusTypes.StatusType.POISON),
			"Fighter should not have poison after removal"):
		_pass(_current_test)

	_teardown()


func _test_cleanse_all() -> void:
	_current_test = "test_cleanse_all"
	_setup()

	var poison_data := _create_poison_data()
	var attack_up_data := _create_attack_up_data()
	var bleed_data := _create_bleed_data()

	_manager.apply(_fighter1, poison_data)
	_manager.apply(_fighter1, attack_up_data)
	_manager.apply(_fighter1, bleed_data)

	var effects_before := _manager.get_all_effects(_fighter1)
	if not _assert_equals(3, effects_before.size(), "Fighter should have 3 effects before cleanse"):
		_teardown()
		return

	# Empty array = cleanse all
	var empty_types: Array[StatusTypes.StatusType] = []
	_manager.cleanse(_fighter1, empty_types)

	var effects_after := _manager.get_all_effects(_fighter1)
	if _assert_equals(0, effects_after.size(), "Fighter should have 0 effects after cleanse all"):
		_pass(_current_test)

	_teardown()


func _test_cleanse_specific() -> void:
	_current_test = "test_cleanse_specific"
	_setup()

	var poison_data := _create_poison_data()
	var attack_up_data := _create_attack_up_data()
	var bleed_data := _create_bleed_data()

	_manager.apply(_fighter1, poison_data)
	_manager.apply(_fighter1, attack_up_data)
	_manager.apply(_fighter1, bleed_data)

	# Cleanse only poison and bleed
	var types_to_cleanse: Array[StatusTypes.StatusType] = [
		StatusTypes.StatusType.POISON,
		StatusTypes.StatusType.BLEED
	]
	_manager.cleanse(_fighter1, types_to_cleanse)

	var has_poison := _manager.has_effect(_fighter1, StatusTypes.StatusType.POISON)
	var has_bleed := _manager.has_effect(_fighter1, StatusTypes.StatusType.BLEED)
	var has_attack := _manager.has_effect(_fighter1, StatusTypes.StatusType.ATTACK_UP)

	if _assert_false(has_poison, "Poison should be cleansed"):
		if _assert_false(has_bleed, "Bleed should be cleansed"):
			if _assert_true(has_attack, "Attack Up should remain"):
				_pass(_current_test)

	_teardown()


# =============================================================================
# STACKING BEHAVIOR TESTS
# =============================================================================

func _test_additive_stacking() -> void:
	_current_test = "test_additive_stacking"
	_setup()

	var poison_data := _create_poison_data(5.0, 3.0, 10)  # base 5, 10 max stacks

	_manager.apply(_fighter1, poison_data, null, 1)
	if not _assert_equals(1, _manager.get_stacks(_fighter1, StatusTypes.StatusType.POISON),
			"Should have 1 stack initially"):
		_teardown()
		return

	_manager.apply(_fighter1, poison_data, null, 2)
	if not _assert_equals(3, _manager.get_stacks(_fighter1, StatusTypes.StatusType.POISON),
			"Should have 3 stacks after adding 2"):
		_teardown()
		return

	# Verify value calculation: base_value + value_per_stack * (stacks - 1)
	# = 5.0 + 2.0 * (3 - 1) = 5.0 + 4.0 = 9.0
	var modifier := _manager.get_modifier(_fighter1, StatusTypes.StatusType.POISON)
	if _assert_approximately(9.0, modifier, 0.01, "Modifier should be 9.0 (base 5 + 2*2)"):
		_pass(_current_test)

	_teardown()


func _test_refresh_stacking() -> void:
	_current_test = "test_refresh_stacking"
	_setup()

	var refresh_data := _create_refresh_effect_data(5.0)  # 5 second duration

	_manager.apply(_fighter1, refresh_data)

	# Simulate time passing (2 seconds)
	_manager.tick(2.0)

	var effect := _manager.get_effect(_fighter1, StatusTypes.StatusType.ATTACK_UP)
	if effect == null:
		_fail("Effect should exist after 2 seconds")
		_teardown()
		return

	var remaining_before := effect.remaining_duration
	if not _assert_approximately(3.0, remaining_before, 0.1,
			"Should have ~3 seconds remaining"):
		_teardown()
		return

	# Apply again - should refresh duration
	_manager.apply(_fighter1, refresh_data)

	effect = _manager.get_effect(_fighter1, StatusTypes.StatusType.ATTACK_UP)
	if _assert_approximately(5.0, effect.remaining_duration, 0.1,
			"Duration should be refreshed to 5 seconds"):
		_pass(_current_test)

	_teardown()


func _test_replace_stacking() -> void:
	_current_test = "test_replace_stacking"
	_setup()

	var replace_data_1 := _create_replace_effect_data(10.0, 3.0)
	var replace_data_2 := _create_replace_effect_data(25.0, 3.0)

	_manager.apply(_fighter1, replace_data_1)

	var modifier_1 := _manager.get_modifier(_fighter1, StatusTypes.StatusType.ATTACK_UP)
	if not _assert_approximately(10.0, modifier_1, 0.01, "Initial modifier should be 10.0"):
		_teardown()
		return

	# Apply new effect - should replace
	_manager.apply(_fighter1, replace_data_2)

	var modifier_2 := _manager.get_modifier(_fighter1, StatusTypes.StatusType.ATTACK_UP)
	if _assert_approximately(25.0, modifier_2, 0.01, "Modifier should be replaced with 25.0"):
		_pass(_current_test)

	_teardown()


func _test_max_stacks() -> void:
	_current_test = "test_max_stacks"
	_setup()

	var poison_data := _create_poison_data(5.0, 10.0, 3)  # max 3 stacks

	# Try to apply 5 stacks
	_manager.apply(_fighter1, poison_data, null, 5)

	if not _assert_equals(3, _manager.get_stacks(_fighter1, StatusTypes.StatusType.POISON),
			"Stacks should be capped at max (3)"):
		_teardown()
		return

	# Try to add more stacks
	_manager.apply(_fighter1, poison_data, null, 2)

	if _assert_equals(3, _manager.get_stacks(_fighter1, StatusTypes.StatusType.POISON),
			"Stacks should still be capped at max (3)"):
		_pass(_current_test)

	_teardown()


# =============================================================================
# DURATION TESTS
# =============================================================================

func _test_duration_expiry() -> void:
	_current_test = "test_duration_expiry"
	_setup()

	var poison_data := _create_poison_data(5.0, 2.0)  # 2 second duration

	_manager.apply(_fighter1, poison_data)

	if not _assert_true(_manager.has_effect(_fighter1, StatusTypes.StatusType.POISON),
			"Effect should exist initially"):
		_teardown()
		return

	# Tick for 1 second - should still exist
	_manager.tick(1.0)
	if not _assert_true(_manager.has_effect(_fighter1, StatusTypes.StatusType.POISON),
			"Effect should exist after 1 second"):
		_teardown()
		return

	# Tick for 1.5 more seconds - should expire
	_manager.tick(1.5)
	if _assert_false(_manager.has_effect(_fighter1, StatusTypes.StatusType.POISON),
			"Effect should be expired after 2.5 seconds"):
		_pass(_current_test)

	_teardown()


func _test_permanent_effect() -> void:
	_current_test = "test_permanent_effect"
	_setup()

	var evasion_data := _create_evasion_data(0.0)  # duration 0 = permanent

	_manager.apply(_fighter1, evasion_data)

	if not _assert_true(_manager.has_effect(_fighter1, StatusTypes.StatusType.EVASION),
			"Permanent effect should exist initially"):
		_teardown()
		return

	# Tick for a long time
	_manager.tick(100.0)

	if _assert_true(_manager.has_effect(_fighter1, StatusTypes.StatusType.EVASION),
			"Permanent effect should still exist after 100 seconds"):
		_pass(_current_test)

	_teardown()


# =============================================================================
# TICK DAMAGE TESTS
# =============================================================================

func _test_poison_tick_damage() -> void:
	_current_test = "test_poison_tick_damage"
	_setup()

	var poison_data := _create_poison_data(10.0, 5.0)  # 10 damage, 5 second duration
	poison_data.tick_interval = 1.0

	_manager.apply(_fighter1, poison_data)
	_fighter1.reset()  # Clear any damage from applying

	# Tick for 1 second - should trigger 1 tick
	_manager.tick(1.0)

	if not _assert_equals(1, _fighter1.get_damage_count(),
			"Should have taken 1 damage instance"):
		_teardown()
		return

	if not _assert_equals(10, _fighter1.get_total_damage_taken(),
			"Should have taken 10 damage"):
		_teardown()
		return

	# Tick for 2 more seconds - should trigger 2 more ticks
	_fighter1.damage_taken_log.clear()
	_manager.tick(2.0)

	if _assert_equals(2, _fighter1.get_damage_count(),
			"Should have taken 2 more damage instances"):
		if _assert_equals(20, _fighter1.get_total_damage_taken(),
				"Should have taken 20 more damage"):
			_pass(_current_test)

	_teardown()


func _test_bleed_on_match() -> void:
	_current_test = "test_bleed_on_match"
	_setup()

	var bleed_data := _create_bleed_data(15.0, 10.0)  # 15 damage

	_manager.apply(_fighter1, bleed_data)
	_fighter1.reset()  # Clear any damage from applying

	# Time ticks should NOT cause bleed damage
	_manager.tick(5.0)
	if not _assert_equals(0, _fighter1.get_damage_count(),
			"Bleed should not tick on time"):
		_teardown()
		return

	# Simulate a match - this should trigger bleed
	_manager._on_target_matched(_fighter1)

	if not _assert_equals(1, _fighter1.get_damage_count(),
			"Bleed should trigger on match"):
		_teardown()
		return

	if _assert_equals(15, _fighter1.get_total_damage_taken(),
			"Bleed should deal 15 damage"):
		_pass(_current_test)

	_teardown()


# =============================================================================
# MODIFIER TESTS
# =============================================================================

func _test_attack_up_modifier() -> void:
	_current_test = "test_attack_up_modifier"
	_setup()

	var attack_up_data := _create_attack_up_data(0.25, 10.0)  # 25% base, +10% per stack
	attack_up_data.value_per_stack = 0.10

	_manager.apply(_fighter1, attack_up_data, null, 1)

	var modifier := _manager.get_modifier(_fighter1, StatusTypes.StatusType.ATTACK_UP)
	if not _assert_approximately(0.25, modifier, 0.001,
			"1 stack should give 0.25 (25%) modifier"):
		_teardown()
		return

	# Add more stacks
	_manager.apply(_fighter1, attack_up_data, null, 2)  # Now 3 stacks

	modifier = _manager.get_modifier(_fighter1, StatusTypes.StatusType.ATTACK_UP)
	# Expected: 0.25 + 0.10 * (3 - 1) = 0.25 + 0.20 = 0.45
	if _assert_approximately(0.45, modifier, 0.001,
			"3 stacks should give 0.45 (45%) modifier"):
		_pass(_current_test)

	_teardown()


func _test_dodge_chance() -> void:
	_current_test = "test_dodge_chance"
	_setup()

	var dodge_data := _create_dodge_data(0.5, 10.0)  # 50% dodge chance

	_manager.apply(_fighter1, dodge_data)

	var has_dodge := _manager.has_effect(_fighter1, StatusTypes.StatusType.DODGE)
	if not _assert_true(has_dodge, "Fighter should have dodge effect"):
		_teardown()
		return

	var modifier := _manager.get_modifier(_fighter1, StatusTypes.StatusType.DODGE)
	if _assert_approximately(0.5, modifier, 0.001,
			"Dodge modifier should be 0.5 (50%)"):
		_pass(_current_test)

	_teardown()


func _test_evasion_auto_miss() -> void:
	_current_test = "test_evasion_auto_miss"
	_setup()

	var evasion_data := _create_evasion_data()

	_manager.apply(_fighter1, evasion_data, null, 2)  # 2 stacks

	if not _assert_true(_manager.has_effect(_fighter1, StatusTypes.StatusType.EVASION),
			"Fighter should have evasion effect"):
		_teardown()
		return

	if not _assert_equals(2, _manager.get_stacks(_fighter1, StatusTypes.StatusType.EVASION),
			"Should have 2 evasion stacks"):
		_teardown()
		return

	# Apply damage with modifiers - should be blocked by evasion
	var modified_damage := _manager.apply_damage_modifiers(_fighter1, 50.0, _fighter2)

	if not _assert_equals(0.0, modified_damage,
			"Damage should be 0 due to evasion"):
		_teardown()
		return

	# Evasion stack should be consumed
	if not _assert_equals(1, _manager.get_stacks(_fighter1, StatusTypes.StatusType.EVASION),
			"Should have 1 evasion stack remaining"):
		_teardown()
		return

	# Apply damage again - should consume second stack
	modified_damage = _manager.apply_damage_modifiers(_fighter1, 50.0, _fighter2)

	if not _assert_equals(0.0, modified_damage,
			"Second attack should also be evaded"):
		_teardown()
		return

	# All stacks consumed - evasion should be removed
	if _assert_false(_manager.has_effect(_fighter1, StatusTypes.StatusType.EVASION),
			"Evasion should be removed after all stacks consumed"):
		_pass(_current_test)

	_teardown()
