extends Node

## Integration test for the Basic/Squire starter character.
## Validates that all pieces are properly configured and work together.

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("\n=== Basic Character Integration Tests ===\n")

	_test_character_registry_loads()
	_test_basic_character_exists()
	_test_basic_character_properties()
	_test_tile_resources_exist()
	_test_tile_match_effects()
	_test_effect_resources_valid()
	_test_spawn_weights()
	_test_placeholder_texture_generation()

	_print_summary()


func _test_character_registry_loads() -> void:
	print("Test: Character Registry Loads...")
	var registry := CharacterRegistry.new()
	registry.load_all()

	if registry.get_character_count() > 0:
		_pass("Registry loaded %d character(s)" % registry.get_character_count())
	else:
		_fail("Registry failed to load any characters")


func _test_basic_character_exists() -> void:
	print("Test: Basic Character Exists...")
	var registry := CharacterRegistry.new()
	registry.load_all()

	var basic := registry.get_character("basic")
	if basic != null:
		_pass("Basic character found in registry")
	else:
		_fail("Basic character not found in registry")


func _test_basic_character_properties() -> void:
	print("Test: Basic Character Properties...")
	var registry := CharacterRegistry.new()
	registry.load_all()

	var basic := registry.get_character("basic")
	if not basic:
		_fail("Cannot test properties - basic character not loaded")
		return

	var errors: Array[String] = []

	if basic.character_id != "basic":
		errors.append("character_id should be 'basic', got '%s'" % basic.character_id)
	if basic.display_name != "Squire":
		errors.append("display_name should be 'Squire', got '%s'" % basic.display_name)
	if basic.archetype != "Balanced":
		errors.append("archetype should be 'Balanced', got '%s'" % basic.archetype)
	if basic.base_hp != 100:
		errors.append("base_hp should be 100, got %d" % basic.base_hp)
	if not basic.is_starter:
		errors.append("is_starter should be true")
	if basic.mana_config != null:
		errors.append("mana_config should be null for basic character")
	if basic.sequences.size() > 0:
		errors.append("sequences should be empty for basic character")
	if basic.ultimate_ability != null:
		errors.append("ultimate_ability should be null for basic character")
	if basic.basic_tiles.size() != 5:
		errors.append("basic_tiles should have 5 tiles, got %d" % basic.basic_tiles.size())

	if errors.is_empty():
		_pass("All basic character properties are correct")
	else:
		for error in errors:
			_fail(error)


func _test_tile_resources_exist() -> void:
	print("Test: Tile Resources Exist...")
	var registry := CharacterRegistry.new()
	registry.load_all()

	var basic := registry.get_character("basic")
	if not basic:
		_fail("Cannot test tiles - basic character not loaded")
		return

	var tiles := basic.get_all_tiles()
	var expected_types := [
		TileTypes.Type.SWORD,
		TileTypes.Type.SHIELD,
		TileTypes.Type.POTION,
		TileTypes.Type.LIGHTNING,
		TileTypes.Type.FILLER
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
		_pass("All 5 tile types found (SWORD, SHIELD, POTION, LIGHTNING, FILLER)")
	else:
		_fail("Missing tile types: %s" % str(missing))


func _test_tile_match_effects() -> void:
	print("Test: Tile Match Effects Configured...")
	var registry := CharacterRegistry.new()
	registry.load_all()

	var basic := registry.get_character("basic")
	if not basic:
		_fail("Cannot test effects - basic character not loaded")
		return

	var tiles := basic.get_all_tiles()
	var errors: Array[String] = []

	for tile in tiles:
		if tile == null:
			continue

		match tile.tile_type:
			TileTypes.Type.SWORD:
				if tile.match_effect == null:
					errors.append("Sword tile missing match_effect")
				elif tile.match_effect.effect_type != EffectData.EffectType.DAMAGE:
					errors.append("Sword effect should be DAMAGE")
			TileTypes.Type.SHIELD:
				if tile.match_effect == null:
					errors.append("Shield tile missing match_effect")
				elif tile.match_effect.effect_type != EffectData.EffectType.SHIELD:
					errors.append("Shield effect should be SHIELD")
			TileTypes.Type.POTION:
				if tile.match_effect == null:
					errors.append("Potion tile missing match_effect")
				elif tile.match_effect.effect_type != EffectData.EffectType.HEAL:
					errors.append("Potion effect should be HEAL")
			TileTypes.Type.LIGHTNING:
				if tile.match_effect == null:
					errors.append("Lightning tile missing match_effect")
				elif tile.match_effect.effect_type != EffectData.EffectType.STUN:
					errors.append("Lightning effect should be STUN")
			TileTypes.Type.FILLER:
				if tile.match_effect != null:
					errors.append("Filler tile should not have match_effect")

	if errors.is_empty():
		_pass("All tile match effects correctly configured")
	else:
		for error in errors:
			_fail(error)


func _test_effect_resources_valid() -> void:
	print("Test: Effect Resources Valid...")

	var damage_effect := load("res://resources/effects/damage_effect.tres") as EffectData
	var armor_effect := load("res://resources/effects/armor_effect.tres") as EffectData
	var heal_effect := load("res://resources/effects/heal_effect.tres") as EffectData
	var stun_effect := load("res://resources/effects/stun_effect.tres") as EffectData

	var errors: Array[String] = []

	if damage_effect == null:
		errors.append("damage_effect.tres not found")
	else:
		if damage_effect.get_value_for_match(3) != 10:
			errors.append("damage_effect match-3 should be 10")
		if damage_effect.get_value_for_match(4) != 25:
			errors.append("damage_effect match-4 should be 25")
		if damage_effect.get_value_for_match(5) != 50:
			errors.append("damage_effect match-5 should be 50")
		if damage_effect.target != EffectData.TargetType.ENEMY:
			errors.append("damage_effect target should be ENEMY")

	if armor_effect == null:
		errors.append("armor_effect.tres not found")
	else:
		if armor_effect.get_value_for_match(3) != 10:
			errors.append("armor_effect match-3 should be 10")
		if armor_effect.target != EffectData.TargetType.SELF:
			errors.append("armor_effect target should be SELF")

	if heal_effect == null:
		errors.append("heal_effect.tres not found")
	else:
		if heal_effect.get_value_for_match(3) != 10:
			errors.append("heal_effect match-3 should be 10")
		if heal_effect.target != EffectData.TargetType.SELF:
			errors.append("heal_effect target should be SELF")

	if stun_effect == null:
		errors.append("stun_effect.tres not found")
	else:
		if stun_effect.get_value_for_match(3) != 1:
			errors.append("stun_effect match-3 should be 1 (second)")
		if stun_effect.target != EffectData.TargetType.ENEMY:
			errors.append("stun_effect target should be ENEMY")

	if errors.is_empty():
		_pass("All effect resources valid with correct values")
	else:
		for error in errors:
			_fail(error)


func _test_spawn_weights() -> void:
	print("Test: Spawn Weights Configured...")
	var registry := CharacterRegistry.new()
	registry.load_all()

	var basic := registry.get_character("basic")
	if not basic:
		_fail("Cannot test spawn weights - basic character not loaded")
		return

	if basic.spawn_weights.is_empty():
		_pass("Basic character uses default spawn weights (empty dictionary)")
		return

	var errors: Array[String] = []
	for tile_type in basic.spawn_weights.keys():
		var weight: float = basic.spawn_weights[tile_type]
		if weight <= 0:
			errors.append("Invalid spawn weight for type %d: %f" % [tile_type, weight])

	if errors.is_empty():
		_pass("Spawn weights configured correctly")
	else:
		for error in errors:
			_fail(error)


func _test_placeholder_texture_generation() -> void:
	print("Test: Placeholder Texture Generation...")

	var registry := CharacterRegistry.new()
	registry.load_all()

	var basic := registry.get_character("basic")
	if not basic:
		_fail("Cannot test placeholder - basic character not loaded")
		return

	# Test full-size placeholder
	var portrait := PlaceholderTextures.generate_portrait(basic.character_id, 128)
	if portrait != null and portrait.get_width() == 128:
		_pass("128x128 placeholder portrait generated successfully")
	else:
		_fail("Failed to generate 128x128 placeholder portrait")

	# Test small placeholder
	var portrait_small := PlaceholderTextures.generate_portrait_small(basic.character_id)
	if portrait_small != null and portrait_small.get_width() == 64:
		_pass("64x64 placeholder portrait generated successfully")
	else:
		_fail("Failed to generate 64x64 placeholder portrait")

	# Test get_or_generate function
	var auto_portrait := PlaceholderTextures.get_or_generate_portrait(basic, false)
	if auto_portrait != null:
		_pass("get_or_generate_portrait works correctly")
	else:
		_fail("get_or_generate_portrait returned null")


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
