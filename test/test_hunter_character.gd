extends Node

## Integration test for the Hunter character.
## Validates that all Hunter pieces are properly configured and work together.

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("\n=== Hunter Character Integration Tests ===\n")

	_test_hunter_character_exists()
	_test_hunter_character_properties()
	_test_hunter_tile_resources()
	_test_hunter_sequences()
	_test_hunter_sequence_effects()
	_test_hunter_ultimate_ability()
	_test_alpha_command_status()
	_test_spawn_weights()

	_print_summary()


func _test_hunter_character_exists() -> void:
	print("Test: Hunter Character Exists...")
	var registry := CharacterRegistry.new()
	registry.load_all()

	var hunter := registry.get_character("hunter")
	if hunter != null:
		_pass("Hunter character found in registry")
	else:
		_fail("Hunter character not found in registry")


func _test_hunter_character_properties() -> void:
	print("Test: Hunter Character Properties...")
	var registry := CharacterRegistry.new()
	registry.load_all()

	var hunter := registry.get_character("hunter")
	if not hunter:
		_fail("Cannot test properties - hunter character not loaded")
		return

	var errors: Array[String] = []

	if hunter.character_id != "hunter":
		errors.append("character_id should be 'hunter', got '%s'" % hunter.character_id)
	if hunter.display_name != "The Hunter":
		errors.append("display_name should be 'The Hunter', got '%s'" % hunter.display_name)
	if hunter.archetype != "Combo Specialist":
		errors.append("archetype should be 'Combo Specialist', got '%s'" % hunter.archetype)
	if hunter.base_hp != 100:
		errors.append("base_hp should be 100, got %d" % hunter.base_hp)
	if hunter.is_starter:
		errors.append("is_starter should be false")
	if hunter.unlock_opponent_id != "hunter":
		errors.append("unlock_opponent_id should be 'hunter', got '%s'" % hunter.unlock_opponent_id)
	if hunter.mana_config == null:
		errors.append("mana_config should not be null")
	if hunter.sequences.size() != 3:
		errors.append("sequences should have 3 sequences, got %d" % hunter.sequences.size())
	if hunter.ultimate_ability == null:
		errors.append("ultimate_ability should not be null")
	if hunter.basic_tiles.size() != 4:
		errors.append("basic_tiles should have 4 tiles, got %d" % hunter.basic_tiles.size())
	if hunter.specialty_tiles.size() != 1:
		errors.append("specialty_tiles should have 1 tile (pet), got %d" % hunter.specialty_tiles.size())

	if errors.is_empty():
		_pass("All hunter character properties are correct")
	else:
		for error in errors:
			_fail(error)


func _test_hunter_tile_resources() -> void:
	print("Test: Hunter Tile Resources...")
	var registry := CharacterRegistry.new()
	registry.load_all()

	var hunter := registry.get_character("hunter")
	if not hunter:
		_fail("Cannot test tiles - hunter character not loaded")
		return

	var tiles := hunter.get_all_tiles()
	var expected_types := [
		TileTypes.Type.SWORD,
		TileTypes.Type.SHIELD,
		TileTypes.Type.LIGHTNING,
		TileTypes.Type.FILLER,
		TileTypes.Type.PET
	]

	var found_types: Array[int] = []
	for tile in tiles:
		if tile != null:
			found_types.append(tile.tile_type)

	var missing: Array[String] = []
	for expected in expected_types:
		if expected not in found_types:
			missing.append(TileTypes.Type.keys()[expected])

	if missing.is_empty():
		_pass("All 5 tile types found (SWORD, SHIELD, LIGHTNING, FILLER, PET)")
	else:
		_fail("Missing tile types: %s" % str(missing))

	# Test Pet tile specific properties
	for tile in tiles:
		if tile and tile.tile_type == TileTypes.Type.PET:
			var errors: Array[String] = []
			if tile.is_matchable:
				errors.append("Pet tile should not be matchable")
			if not tile.is_clickable:
				errors.append("Pet tile should be clickable")
			if tile.click_condition != TileTypes.ClickCondition.SEQUENCE_COMPLETE:
				errors.append("Pet tile click_condition should be SEQUENCE_COMPLETE")
			if tile.min_on_board != 1:
				errors.append("Pet tile min_on_board should be 1")
			if tile.max_on_board != 2:
				errors.append("Pet tile max_on_board should be 2")

			if errors.is_empty():
				_pass("Pet tile has correct clickable configuration")
			else:
				for error in errors:
					_fail(error)
			break


func _test_hunter_sequences() -> void:
	print("Test: Hunter Sequences...")
	var registry := CharacterRegistry.new()
	registry.load_all()

	var hunter := registry.get_character("hunter")
	if not hunter:
		_fail("Cannot test sequences - hunter character not loaded")
		return

	var errors: Array[String] = []
	var found_sequences: Dictionary = {}

	for seq in hunter.sequences:
		if seq == null:
			errors.append("Null sequence found")
			continue
		found_sequences[seq.sequence_id] = seq

	# Check Bear sequence
	if not found_sequences.has("bear"):
		errors.append("Missing bear sequence")
	else:
		var bear: SequencePattern = found_sequences["bear"]
		if bear.display_name != "Bear":
			errors.append("Bear display_name wrong: %s" % bear.display_name)
		# Pattern should be [SWORD, SHIELD, SHIELD] = [0, 1, 1]
		if bear.pattern != [0, 1, 1]:
			errors.append("Bear pattern wrong: %s (expected [0, 1, 1])" % str(bear.pattern))
		if bear.terminator != TileTypes.Type.PET:
			errors.append("Bear terminator should be PET")
		if bear.max_stacks != 3:
			errors.append("Bear max_stacks should be 3")

	# Check Hawk sequence
	if not found_sequences.has("hawk"):
		errors.append("Missing hawk sequence")
	else:
		var hawk: SequencePattern = found_sequences["hawk"]
		if hawk.display_name != "Hawk":
			errors.append("Hawk display_name wrong: %s" % hawk.display_name)
		# Pattern should be [SHIELD, LIGHTNING] = [1, 3]
		if hawk.pattern != [1, 3]:
			errors.append("Hawk pattern wrong: %s (expected [1, 3])" % str(hawk.pattern))
		if hawk.terminator != TileTypes.Type.PET:
			errors.append("Hawk terminator should be PET")
		if hawk.max_stacks != 3:
			errors.append("Hawk max_stacks should be 3")

	# Check Snake sequence
	if not found_sequences.has("snake"):
		errors.append("Missing snake sequence")
	else:
		var snake: SequencePattern = found_sequences["snake"]
		if snake.display_name != "Snake":
			errors.append("Snake display_name wrong: %s" % snake.display_name)
		# Pattern should be [LIGHTNING, SWORD, SHIELD] = [3, 0, 1]
		if snake.pattern != [3, 0, 1]:
			errors.append("Snake pattern wrong: %s (expected [3, 0, 1])" % str(snake.pattern))
		if snake.terminator != TileTypes.Type.PET:
			errors.append("Snake terminator should be PET")
		if snake.max_stacks != 3:
			errors.append("Snake max_stacks should be 3")

	if errors.is_empty():
		_pass("All 3 hunter sequences correctly configured")
	else:
		for error in errors:
			_fail(error)


func _test_hunter_sequence_effects() -> void:
	print("Test: Hunter Sequence Effects...")

	var errors: Array[String] = []

	# Test bear effects
	var bear_bleed := load("res://resources/effects/bear_bleed_effect.tres") as EffectData
	var bear_buff := load("res://resources/effects/bear_attack_buff.tres") as EffectData
	if bear_bleed == null:
		errors.append("bear_bleed_effect.tres not found")
	elif bear_bleed.target != EffectData.TargetType.ENEMY:
		errors.append("bear_bleed should target ENEMY")
	if bear_buff == null:
		errors.append("bear_attack_buff.tres not found")
	elif bear_buff.target != EffectData.TargetType.SELF:
		errors.append("bear_attack_buff should target SELF")

	# Test hawk effects
	var hawk_replace := load("res://resources/effects/hawk_tile_replace.tres") as EffectData
	var hawk_evasion := load("res://resources/effects/hawk_evasion.tres") as EffectData
	if hawk_replace == null:
		errors.append("hawk_tile_replace.tres not found")
	elif hawk_replace.target != EffectData.TargetType.BOARD_ENEMY:
		errors.append("hawk_tile_replace should target BOARD_ENEMY")
	if hawk_evasion == null:
		errors.append("hawk_evasion.tres not found")
	elif hawk_evasion.target != EffectData.TargetType.SELF:
		errors.append("hawk_evasion should target SELF")

	# Test snake effects
	var snake_stun := load("res://resources/effects/snake_stun.tres") as EffectData
	var snake_cleanse := load("res://resources/effects/snake_cleanse.tres") as EffectData
	if snake_stun == null:
		errors.append("snake_stun.tres not found")
	elif snake_stun.effect_type != EffectData.EffectType.STUN:
		errors.append("snake_stun should be STUN type")
	elif snake_stun.duration != 3.0:
		errors.append("snake_stun duration should be 3.0 seconds")
	if snake_cleanse == null:
		errors.append("snake_cleanse.tres not found")
	elif snake_cleanse.effect_type != EffectData.EffectType.STATUS_REMOVE:
		errors.append("snake_cleanse should be STATUS_REMOVE type")

	if errors.is_empty():
		_pass("All hunter sequence effects correctly configured")
	else:
		for error in errors:
			_fail(error)


func _test_hunter_ultimate_ability() -> void:
	print("Test: Hunter Ultimate Ability...")

	var ability := load("res://resources/abilities/alpha_command.tres") as AbilityData
	if ability == null:
		_fail("alpha_command.tres not found")
		return

	var errors: Array[String] = []

	if ability.ability_id != "alpha_command":
		errors.append("ability_id should be 'alpha_command', got '%s'" % ability.ability_id)
	if ability.display_name != "Alpha Command":
		errors.append("display_name should be 'Alpha Command', got '%s'" % ability.display_name)
	if not ability.requires_full_mana:
		errors.append("requires_full_mana should be true")
	if not ability.drains_all_mana:
		errors.append("drains_all_mana should be true")
	if ability.duration != 8.0:
		errors.append("duration should be 8.0, got %f" % ability.duration)
	if ability.effects.size() == 0:
		errors.append("effects array should not be empty")

	# Check the effect
	if ability.effects.size() > 0 and ability.effects[0] != null:
		var effect: EffectData = ability.effects[0]
		if effect.effect_id != "alpha_command_buff":
			errors.append("effect_id should be 'alpha_command_buff', got '%s'" % effect.effect_id)
		if effect.effect_type != EffectData.EffectType.STATUS_APPLY:
			errors.append("effect type should be STATUS_APPLY")
		if effect.target != EffectData.TargetType.SELF:
			errors.append("effect target should be SELF")

	if errors.is_empty():
		_pass("Alpha Command ultimate ability correctly configured")
	else:
		for error in errors:
			_fail(error)


func _test_alpha_command_status() -> void:
	print("Test: Alpha Command Status Type...")

	# Check that ALPHA_COMMAND exists in StatusTypes enum
	var status_keys := StatusTypes.StatusType.keys()
	if "ALPHA_COMMAND" in status_keys:
		_pass("ALPHA_COMMAND status type exists in StatusTypes enum")
	else:
		_fail("ALPHA_COMMAND status type not found in StatusTypes enum")


func _test_spawn_weights() -> void:
	print("Test: Hunter Spawn Weights...")
	var registry := CharacterRegistry.new()
	registry.load_all()

	var hunter := registry.get_character("hunter")
	if not hunter:
		_fail("Cannot test spawn weights - hunter character not loaded")
		return

	var errors: Array[String] = []

	# Expected weights: SWORD: 25, SHIELD: 25, LIGHTNING: 20, FILLER: 25, PET: 5
	var expected := {
		TileTypes.Type.SWORD: 25.0,
		TileTypes.Type.SHIELD: 25.0,
		TileTypes.Type.LIGHTNING: 20.0,
		TileTypes.Type.FILLER: 25.0,
		TileTypes.Type.PET: 5.0
	}

	for tile_type in expected.keys():
		var expected_weight: float = expected[tile_type]
		var actual_weight: float = hunter.get_spawn_weight(tile_type)
		if abs(actual_weight - expected_weight) > 0.001:
			errors.append("Spawn weight for type %d should be %.1f, got %.1f" % [tile_type, expected_weight, actual_weight])

	if errors.is_empty():
		_pass("Hunter spawn weights correctly configured")
	else:
		for error in errors:
			_fail(error)


func _pass(message: String) -> void:
	print("  PASS: %s" % message)
	_passed += 1


func _fail(message: String) -> void:
	print("  FAIL: %s" % message)
	_failed += 1


func _print_summary() -> void:
	print("\n=== Summary ===")
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
	print("Total: %d" % (_passed + _failed))

	if _failed == 0:
		print("\nAll tests passed!")
	else:
		print("\nSome tests failed. Please check the output above.")
