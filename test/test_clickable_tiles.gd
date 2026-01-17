extends Node
## Test Runner for Clickable Tiles System
## Validates ClickConditionChecker and effect configuration in isolation.
##
## Tests cover:
## - Click condition evaluation (ALWAYS, NONE, SEQUENCE_COMPLETE, COOLDOWN)
## - Cooldown timer behavior
## - Effect data configuration validation

# =============================================================================
# MOCK CLASSES
# =============================================================================

## Mock tile class for testing without actual Tile scene dependencies
class MockTile:
	var tile_data: PuzzleTileData

	func _init(data: PuzzleTileData = null) -> void:
		tile_data = data


## Mock sequence tracker for testing SEQUENCE_COMPLETE condition
class MockSequenceTracker:
	var has_complete: bool = false

	func has_completable_sequence() -> bool:
		return has_complete


## Mock mana system for testing MANA_FULL condition
class MockManaSystem:
	var _all_bars_full: bool = false

	func are_all_bars_full(_fighter) -> bool:
		return _all_bars_full


# =============================================================================
# TEST INFRASTRUCTURE
# =============================================================================

# Test tracking
var _tests_passed: int = 0
var _tests_failed: int = 0
var _current_test: String = ""

# Test instances
var _condition_checker: ClickConditionChecker
var _mock_sequence_tracker: MockSequenceTracker
var _mock_mana_system: MockManaSystem
var _fighter1: MockFighter
var _fighter2: MockFighter


func _ready() -> void:
	print("\n========================================")
	print("  CLICKABLE TILES TEST SUITE")
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
	# Condition tests
	print("[Category: Click Condition Tests]")
	_run_test("_test_always_clickable")
	_run_test("_test_non_clickable")
	_run_test("_test_sequence_condition_not_met")
	_run_test("_test_sequence_condition_met")
	_run_test("_test_cooldown_available")
	_run_test("_test_cooldown_active")
	_run_test("_test_cooldown_expires")
	_run_test("_test_mana_full_condition")

	# Threshold tests
	print("\n[Category: Threshold Tests]")
	_run_test("_test_click_vs_drag_threshold")

	# Effect configuration tests
	print("\n[Category: Effect Configuration Tests]")
	_run_test("_test_damage_effect")
	_run_test("_test_heal_effect")
	_run_test("_test_status_apply_effect")
	_run_test("_test_mana_effect")
	_run_test("_test_shield_effect")
	_run_test("_test_stun_effect")


func _run_test(test_name: String) -> void:
	_current_test = test_name
	_setup_test()

	var passed := false
	match test_name:
		# Condition tests
		"_test_always_clickable":
			passed = _test_always_clickable()
		"_test_non_clickable":
			passed = _test_non_clickable()
		"_test_sequence_condition_not_met":
			passed = _test_sequence_condition_not_met()
		"_test_sequence_condition_met":
			passed = _test_sequence_condition_met()
		"_test_cooldown_available":
			passed = _test_cooldown_available()
		"_test_cooldown_active":
			passed = _test_cooldown_active()
		"_test_cooldown_expires":
			passed = _test_cooldown_expires()
		"_test_mana_full_condition":
			passed = _test_mana_full_condition()
		# Threshold tests
		"_test_click_vs_drag_threshold":
			passed = _test_click_vs_drag_threshold()
		# Effect tests
		"_test_damage_effect":
			passed = _test_damage_effect()
		"_test_heal_effect":
			passed = _test_heal_effect()
		"_test_status_apply_effect":
			passed = _test_status_apply_effect()
		"_test_mana_effect":
			passed = _test_mana_effect()
		"_test_shield_effect":
			passed = _test_shield_effect()
		"_test_stun_effect":
			passed = _test_stun_effect()
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
	_condition_checker = ClickConditionChecker.new()
	_mock_sequence_tracker = MockSequenceTracker.new()
	_mock_mana_system = MockManaSystem.new()
	_fighter1 = _get_mock_fighter(0)
	_fighter2 = _get_mock_fighter(1)
	if _fighter1:
		_fighter1.reset()
	if _fighter2:
		_fighter2.reset()


func _teardown_test() -> void:
	_condition_checker.clear_all_cooldowns()
	_condition_checker = null
	_mock_sequence_tracker = null
	_mock_mana_system = null


func _get_mock_fighter(index: int) -> MockFighter:
	var fighters := get_tree().get_nodes_in_group("mock_fighters")
	if index < fighters.size():
		return fighters[index] as MockFighter
	return null


# =============================================================================
# HELPER METHODS - TileData Creation
# =============================================================================

## Create a tile with ALWAYS clickable condition
func _create_always_clickable() -> PuzzleTileData:
	var data := PuzzleTileData.new()
	data.tile_type = TileTypes.Type.PET
	data.display_name = "Test Clickable Tile"
	data.is_clickable = true
	data.click_condition = TileTypes.ClickCondition.ALWAYS
	return data


## Create a non-clickable tile (NONE condition)
func _create_non_clickable() -> PuzzleTileData:
	var data := PuzzleTileData.new()
	data.tile_type = TileTypes.Type.SWORD
	data.display_name = "Test Non-Clickable Tile"
	data.is_clickable = false
	data.click_condition = TileTypes.ClickCondition.NONE
	return data


## Create a tile that requires sequence completion
func _create_sequence_clickable() -> PuzzleTileData:
	var data := PuzzleTileData.new()
	data.tile_type = TileTypes.Type.PET
	data.display_name = "Test Sequence Tile"
	data.is_clickable = true
	data.click_condition = TileTypes.ClickCondition.SEQUENCE_COMPLETE
	return data


## Create a tile with cooldown condition
func _create_cooldown_clickable(cooldown: float = 2.0) -> PuzzleTileData:
	var data := PuzzleTileData.new()
	data.tile_type = TileTypes.Type.PET
	data.display_name = "Test Cooldown Tile"
	data.is_clickable = true
	data.click_condition = TileTypes.ClickCondition.COOLDOWN
	data.click_cooldown = cooldown
	return data


## Create a tile with mana full condition
func _create_mana_full_clickable() -> PuzzleTileData:
	var data := PuzzleTileData.new()
	data.tile_type = TileTypes.Type.PET
	data.display_name = "Test Mana Full Tile"
	data.is_clickable = true
	data.click_condition = TileTypes.ClickCondition.MANA_FULL
	return data


## Create a mock tile with the given tile data
func _create_mock_tile(data: PuzzleTileData) -> MockTile:
	return MockTile.new(data)


## Create a damage effect for testing
func _create_damage_effect(damage: int = 25) -> EffectData:
	var effect := EffectData.new()
	effect.effect_id = "test_damage"
	effect.effect_type = EffectData.EffectType.DAMAGE
	effect.target = EffectData.TargetType.ENEMY
	effect.base_value = damage
	effect.values_by_match_size = {3: 10, 4: 25, 5: 50}
	return effect


## Create a heal effect for testing
func _create_heal_effect(heal_amount: int = 20) -> EffectData:
	var effect := EffectData.new()
	effect.effect_id = "test_heal"
	effect.effect_type = EffectData.EffectType.HEAL
	effect.target = EffectData.TargetType.SELF
	effect.base_value = heal_amount
	return effect


## Create a status apply effect for testing
func _create_status_apply_effect() -> EffectData:
	var effect := EffectData.new()
	effect.effect_id = "test_status"
	effect.effect_type = EffectData.EffectType.STATUS_APPLY
	effect.target = EffectData.TargetType.ENEMY

	# Create a status effect data
	var status_data := StatusEffectData.new()
	status_data.effect_id = "test_poison"
	status_data.effect_type = StatusTypes.StatusType.POISON
	status_data.duration = 5.0
	status_data.base_value = 3.0
	effect.status_effect = status_data

	return effect


## Create a mana add effect for testing
func _create_mana_effect(amount: int = 25, duration: float = 0.0) -> EffectData:
	var effect := EffectData.new()
	effect.effect_id = "test_mana"
	effect.effect_type = EffectData.EffectType.MANA_ADD
	effect.target = EffectData.TargetType.SELF
	effect.base_value = amount
	effect.duration = duration
	return effect


## Create a shield effect for testing
func _create_shield_effect(amount: int = 15) -> EffectData:
	var effect := EffectData.new()
	effect.effect_id = "test_shield"
	effect.effect_type = EffectData.EffectType.SHIELD
	effect.target = EffectData.TargetType.SELF
	effect.base_value = amount
	return effect


## Create a stun effect for testing
func _create_stun_effect(duration: float = 1.5) -> EffectData:
	var effect := EffectData.new()
	effect.effect_id = "test_stun"
	effect.effect_type = EffectData.EffectType.STUN
	effect.target = EffectData.TargetType.ENEMY
	effect.duration = duration
	return effect


# =============================================================================
# CONDITION TESTS
# =============================================================================

## Test 1: ALWAYS condition allows click
func _test_always_clickable() -> bool:
	var tile_data := _create_always_clickable()
	var mock_tile := _create_mock_tile(tile_data)

	# ALWAYS condition should return true
	var can_click := _condition_checker.can_click(mock_tile, _fighter1)

	if not can_click:
		print("    Error: ALWAYS condition should allow click")
		return false

	return true


## Test 2: NONE condition blocks click
func _test_non_clickable() -> bool:
	var tile_data := _create_non_clickable()
	var mock_tile := _create_mock_tile(tile_data)

	# NONE condition should return false
	var can_click := _condition_checker.can_click(mock_tile, _fighter1)

	if can_click:
		print("    Error: NONE condition should block click")
		return false

	return true


## Test 3: SEQUENCE_COMPLETE without tracker fails
func _test_sequence_condition_not_met() -> bool:
	var tile_data := _create_sequence_clickable()
	var mock_tile := _create_mock_tile(tile_data)

	# Without sequence tracker, should return false
	var can_click := _condition_checker.can_click(mock_tile, _fighter1)

	if can_click:
		print("    Error: SEQUENCE_COMPLETE without tracker should fail")
		return false

	# With sequence tracker but no complete sequence
	_mock_sequence_tracker.has_complete = false
	_condition_checker.set_sequence_tracker(_mock_sequence_tracker)

	can_click = _condition_checker.can_click(mock_tile, _fighter1)

	if can_click:
		print("    Error: SEQUENCE_COMPLETE with incomplete sequence should fail")
		return false

	return true


## Test 4: SEQUENCE_COMPLETE with complete sequence passes
func _test_sequence_condition_met() -> bool:
	var tile_data := _create_sequence_clickable()
	var mock_tile := _create_mock_tile(tile_data)

	# Set up tracker with complete sequence
	_mock_sequence_tracker.has_complete = true
	_condition_checker.set_sequence_tracker(_mock_sequence_tracker)

	var can_click := _condition_checker.can_click(mock_tile, _fighter1)

	if not can_click:
		print("    Error: SEQUENCE_COMPLETE with complete sequence should pass")
		return false

	return true


## Test 5: COOLDOWN condition allows first click
func _test_cooldown_available() -> bool:
	var tile_data := _create_cooldown_clickable(2.0)
	var mock_tile := _create_mock_tile(tile_data)

	# First click should be allowed (no cooldown active)
	var can_click := _condition_checker.can_click(mock_tile, _fighter1)

	if not can_click:
		print("    Error: COOLDOWN condition should allow first click")
		return false

	return true


## Test 6: COOLDOWN condition blocks during cooldown
func _test_cooldown_active() -> bool:
	var tile_data := _create_cooldown_clickable(2.0)
	var mock_tile := _create_mock_tile(tile_data)

	# First click allowed
	if not _condition_checker.can_click(mock_tile, _fighter1):
		print("    Error: Initial click should be allowed")
		return false

	# Start cooldown
	_condition_checker.start_cooldown(mock_tile)

	# Now should be blocked
	var can_click := _condition_checker.can_click(mock_tile, _fighter1)

	if can_click:
		print("    Error: Should be blocked during cooldown")
		return false

	# Verify cooldown remaining is approximately correct
	var remaining := _condition_checker.get_cooldown_remaining(mock_tile)
	if remaining < 1.9 or remaining > 2.1:
		print("    Error: Cooldown remaining should be ~2.0, got %.2f" % remaining)
		return false

	return true


## Test 7: COOLDOWN condition allows after timer expires
func _test_cooldown_expires() -> bool:
	var tile_data := _create_cooldown_clickable(1.0)  # 1 second cooldown
	var mock_tile := _create_mock_tile(tile_data)

	# Start cooldown
	_condition_checker.start_cooldown(mock_tile)

	# Should be blocked initially
	if _condition_checker.can_click(mock_tile, _fighter1):
		print("    Error: Should be blocked initially")
		return false

	# Tick for 0.5 seconds - still blocked
	_condition_checker.tick(0.5)
	if _condition_checker.can_click(mock_tile, _fighter1):
		print("    Error: Should still be blocked after 0.5s")
		return false

	# Tick for another 0.6 seconds (total 1.1s) - should be available
	_condition_checker.tick(0.6)

	var can_click := _condition_checker.can_click(mock_tile, _fighter1)
	if not can_click:
		print("    Error: Should be clickable after cooldown expires")
		return false

	# Verify cooldown is cleared
	var remaining := _condition_checker.get_cooldown_remaining(mock_tile)
	if remaining > 0:
		print("    Error: Cooldown remaining should be 0 after expiry, got %.2f" % remaining)
		return false

	return true


## Test 8: MANA_FULL condition behavior
func _test_mana_full_condition() -> bool:
	var tile_data := _create_mana_full_clickable()
	var mock_tile := _create_mock_tile(tile_data)

	# Without mana system - should fail
	var can_click := _condition_checker.can_click(mock_tile, _fighter1)
	if can_click:
		print("    Error: MANA_FULL without mana system should fail")
		return false

	# Set mana system but not full
	_mock_mana_system._all_bars_full = false
	_condition_checker.set_mana_system(_mock_mana_system)

	can_click = _condition_checker.can_click(mock_tile, _fighter1)
	if can_click:
		print("    Error: MANA_FULL with empty mana should fail")
		return false

	# Set mana to full
	_mock_mana_system._all_bars_full = true

	can_click = _condition_checker.can_click(mock_tile, _fighter1)
	if not can_click:
		print("    Error: MANA_FULL with full mana should pass")
		return false

	return true


# =============================================================================
# THRESHOLD TESTS
# =============================================================================

## Test 9: Verify click vs drag threshold values are configured
func _test_click_vs_drag_threshold() -> bool:
	# This test verifies that the tile data has appropriate threshold values
	# The actual threshold implementation is in InputHandler/Tile scripts
	# We just verify the configuration values exist

	var tile_data := _create_always_clickable()

	# Verify clickable_highlight_color exists (visual feedback for clickable tiles)
	if tile_data.clickable_highlight_color == Color.TRANSPARENT:
		print("    Error: Clickable highlight color should not be transparent")
		return false

	# Verify click_cooldown can be configured
	var cooldown_tile := _create_cooldown_clickable(2.5)
	if cooldown_tile.click_cooldown != 2.5:
		print("    Error: Click cooldown should be configurable, expected 2.5, got %.2f" % cooldown_tile.click_cooldown)
		return false

	# Verify is_clickable and click_condition work together
	var clickable_tile := _create_always_clickable()
	if not clickable_tile.can_be_clicked():
		print("    Error: can_be_clicked() should return true for ALWAYS condition")
		return false

	var non_clickable := _create_non_clickable()
	if non_clickable.can_be_clicked():
		print("    Error: can_be_clicked() should return false for NONE condition")
		return false

	return true


# =============================================================================
# EFFECT CONFIGURATION TESTS
# =============================================================================

## Test 10: Damage effect is configured correctly
func _test_damage_effect() -> bool:
	var effect := _create_damage_effect(25)

	# Verify effect type
	if effect.effect_type != EffectData.EffectType.DAMAGE:
		print("    Error: Effect type should be DAMAGE")
		return false

	# Verify target
	if effect.target != EffectData.TargetType.ENEMY:
		print("    Error: Damage target should be ENEMY")
		return false

	# Verify base value
	if effect.base_value != 25:
		print("    Error: Base value should be 25, got %d" % effect.base_value)
		return false

	# Verify match size values
	if effect.get_value_for_match(3) != 10:
		print("    Error: Match-3 value should be 10, got %d" % effect.get_value_for_match(3))
		return false

	if effect.get_value_for_match(4) != 25:
		print("    Error: Match-4 value should be 25, got %d" % effect.get_value_for_match(4))
		return false

	if effect.get_value_for_match(5) != 50:
		print("    Error: Match-5 value should be 50, got %d" % effect.get_value_for_match(5))
		return false

	return true


## Test 11: Heal effect is configured correctly
func _test_heal_effect() -> bool:
	var effect := _create_heal_effect(20)

	# Verify effect type
	if effect.effect_type != EffectData.EffectType.HEAL:
		print("    Error: Effect type should be HEAL")
		return false

	# Verify target is self
	if effect.target != EffectData.TargetType.SELF:
		print("    Error: Heal target should be SELF")
		return false

	# Verify base value
	if effect.base_value != 20:
		print("    Error: Base value should be 20, got %d" % effect.base_value)
		return false

	return true


## Test 12: Status apply effect has status data
func _test_status_apply_effect() -> bool:
	var effect := _create_status_apply_effect()

	# Verify effect type
	if effect.effect_type != EffectData.EffectType.STATUS_APPLY:
		print("    Error: Effect type should be STATUS_APPLY")
		return false

	# Verify status effect data exists
	if effect.status_effect == null:
		print("    Error: STATUS_APPLY effect must have status_effect data")
		return false

	var status_data := effect.status_effect as StatusEffectData
	if status_data == null:
		print("    Error: status_effect should be StatusEffectData type")
		return false

	# Verify status data is configured
	if status_data.effect_type != StatusTypes.StatusType.POISON:
		print("    Error: Status effect type should be POISON")
		return false

	if status_data.duration <= 0:
		print("    Error: Status effect should have positive duration")
		return false

	return true


## Test 13: Mana effect has proper configuration
func _test_mana_effect() -> bool:
	var effect := _create_mana_effect(25, 5.0)

	# Verify effect type
	if effect.effect_type != EffectData.EffectType.MANA_ADD:
		print("    Error: Effect type should be MANA_ADD")
		return false

	# Verify target is self
	if effect.target != EffectData.TargetType.SELF:
		print("    Error: Mana effect target should be SELF")
		return false

	# Verify base value
	if effect.base_value != 25:
		print("    Error: Base value should be 25, got %d" % effect.base_value)
		return false

	# Verify duration is set (for timed mana effects)
	if effect.duration != 5.0:
		print("    Error: Duration should be 5.0, got %.2f" % effect.duration)
		return false

	return true


## Test 14: Shield effect is configured correctly
func _test_shield_effect() -> bool:
	var effect := _create_shield_effect(15)

	# Verify effect type
	if effect.effect_type != EffectData.EffectType.SHIELD:
		print("    Error: Effect type should be SHIELD")
		return false

	# Verify target is self
	if effect.target != EffectData.TargetType.SELF:
		print("    Error: Shield target should be SELF")
		return false

	# Verify base value
	if effect.base_value != 15:
		print("    Error: Base value should be 15, got %d" % effect.base_value)
		return false

	return true


## Test 15: Stun effect is configured correctly
func _test_stun_effect() -> bool:
	var effect := _create_stun_effect(1.5)

	# Verify effect type
	if effect.effect_type != EffectData.EffectType.STUN:
		print("    Error: Effect type should be STUN")
		return false

	# Verify target is enemy
	if effect.target != EffectData.TargetType.ENEMY:
		print("    Error: Stun target should be ENEMY")
		return false

	# Verify duration
	if effect.duration != 1.5:
		print("    Error: Duration should be 1.5, got %.2f" % effect.duration)
		return false

	return true
