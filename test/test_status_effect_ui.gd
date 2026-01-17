extends Node
## Test suite for Status Effect UI components (Task 031)
## Tests StatusEffectIcon, StatusEffectDisplay, and HUD integration.

var _status_manager: StatusEffectManager
var _player_fighter: MockFighter
var _enemy_fighter: MockFighter

# Test effect data
var _poison_data: StatusEffectData
var _bleed_data: StatusEffectData
var _attack_up_data: StatusEffectData
var _dodge_data: StatusEffectData

var _test_results: Dictionary = {}
var _current_test: String = ""


func _ready() -> void:
	print("\n========================================")
	print("STATUS EFFECT UI TEST SUITE (Task 031)")
	print("========================================\n")

	_setup_test_environment()
	await get_tree().process_frame

	# Run all tests
	await _run_all_tests()

	# Print summary
	_print_summary()


func _setup_test_environment() -> void:
	_status_manager = StatusEffectManager.new()

	_player_fighter = MockFighter.new("Player")
	_player_fighter.status_manager = _status_manager

	_enemy_fighter = MockFighter.new("Enemy")
	_enemy_fighter.status_manager = _status_manager

	# Create test effect data
	_poison_data = StatusEffectData.new()
	_poison_data.effect_id = "test_poison"
	_poison_data.display_name = "Test Poison"
	_poison_data.effect_type = StatusTypes.StatusType.POISON
	_poison_data.duration = 5.0
	_poison_data.tick_interval = 1.0
	_poison_data.base_value = 5.0
	_poison_data.max_stacks = 5
	_poison_data.stack_behavior = StatusTypes.StackBehavior.ADDITIVE

	_bleed_data = StatusEffectData.new()
	_bleed_data.effect_id = "test_bleed"
	_bleed_data.display_name = "Test Bleed"
	_bleed_data.effect_type = StatusTypes.StatusType.BLEED
	_bleed_data.duration = 3.0
	_bleed_data.tick_interval = 1.0
	_bleed_data.base_value = 3.0
	_bleed_data.max_stacks = 10
	_bleed_data.stack_behavior = StatusTypes.StackBehavior.ADDITIVE
	_bleed_data.tick_behavior = StatusTypes.TickBehavior.ON_MATCH

	_attack_up_data = StatusEffectData.new()
	_attack_up_data.effect_id = "test_attack_up"
	_attack_up_data.display_name = "Test Attack Up"
	_attack_up_data.effect_type = StatusTypes.StatusType.ATTACK_UP
	_attack_up_data.duration = 10.0
	_attack_up_data.base_value = 0.25
	_attack_up_data.max_stacks = 1
	_attack_up_data.stack_behavior = StatusTypes.StackBehavior.REFRESH

	_dodge_data = StatusEffectData.new()
	_dodge_data.effect_id = "test_dodge"
	_dodge_data.display_name = "Test Dodge"
	_dodge_data.effect_type = StatusTypes.StatusType.DODGE
	_dodge_data.duration = 0.0  # Permanent
	_dodge_data.base_value = 0.2
	_dodge_data.max_stacks = 3
	_dodge_data.stack_behavior = StatusTypes.StackBehavior.ADDITIVE


func _run_all_tests() -> void:
	# StatusEffectIcon tests
	await _test_icon_creation()
	await _test_icon_placeholder_generation()
	await _test_icon_stack_display()
	await _test_icon_duration_bar()
	await _test_icon_permanent_effect()

	# StatusEffectDisplay tests
	await _test_display_creation()
	await _test_display_effect_added()
	await _test_display_effect_removed()
	await _test_display_max_visible()
	await _test_display_stack_update()

	# Integration tests
	await _test_icons_generator_all_types()


func _test_icon_creation() -> void:
	_start_test("StatusEffectIcon - Basic Creation")

	# Create icon instance
	var icon_scene := preload("res://scenes/ui/status_effect_icon.tscn")
	var icon: StatusEffectIcon = icon_scene.instantiate()
	add_child(icon)
	await get_tree().process_frame

	# Apply effect
	_status_manager.apply(_player_fighter, _poison_data)
	var effect := _status_manager.get_effect(_player_fighter, StatusTypes.StatusType.POISON)

	icon.setup(effect)
	await get_tree().process_frame

	_assert(icon.get_effect_type() == StatusTypes.StatusType.POISON, "Icon should have POISON effect type")
	_assert(icon.get_current_effect() != null, "Icon should have current effect")
	_assert(icon.get_current_effect().data.effect_type == StatusTypes.StatusType.POISON, "Current effect should be POISON")

	# Cleanup
	icon.queue_free()
	_status_manager.remove_all(_player_fighter)
	_end_test()


func _test_icon_placeholder_generation() -> void:
	_start_test("StatusEffectIcon - Placeholder Generation")

	# Test that StatusEffectIcons can generate textures for all types
	var poison_tex := StatusEffectIcons.get_icon_texture(StatusTypes.StatusType.POISON)
	var bleed_tex := StatusEffectIcons.get_icon_texture(StatusTypes.StatusType.BLEED)
	var attack_tex := StatusEffectIcons.get_icon_texture(StatusTypes.StatusType.ATTACK_UP)
	var dodge_tex := StatusEffectIcons.get_icon_texture(StatusTypes.StatusType.DODGE)
	var evasion_tex := StatusEffectIcons.get_icon_texture(StatusTypes.StatusType.EVASION)
	var mana_block_tex := StatusEffectIcons.get_icon_texture(StatusTypes.StatusType.MANA_BLOCK)

	_assert(poison_tex != null, "Poison placeholder texture should be generated")
	_assert(bleed_tex != null, "Bleed placeholder texture should be generated")
	_assert(attack_tex != null, "Attack Up placeholder texture should be generated")
	_assert(dodge_tex != null, "Dodge placeholder texture should be generated")
	_assert(evasion_tex != null, "Evasion placeholder texture should be generated")
	_assert(mana_block_tex != null, "Mana Block placeholder texture should be generated")

	# Verify cache works
	var poison_tex2 := StatusEffectIcons.get_icon_texture(StatusTypes.StatusType.POISON)
	_assert(poison_tex == poison_tex2, "Cached texture should be returned")

	_end_test()


func _test_icon_stack_display() -> void:
	_start_test("StatusEffectIcon - Stack Display")

	var icon_scene := preload("res://scenes/ui/status_effect_icon.tscn")
	var icon: StatusEffectIcon = icon_scene.instantiate()
	add_child(icon)
	await get_tree().process_frame

	# Apply effect with 1 stack
	_status_manager.apply(_player_fighter, _poison_data, null, 1)
	var effect := _status_manager.get_effect(_player_fighter, StatusTypes.StatusType.POISON)

	icon.setup(effect)
	await get_tree().process_frame

	var stack_label := icon.get_node_or_null("StackLabel") as Label
	_assert(stack_label != null, "Stack label should exist")
	_assert(not stack_label.visible, "Stack label should be hidden with 1 stack")

	# Add more stacks
	_status_manager.apply(_player_fighter, _poison_data, null, 2)
	effect = _status_manager.get_effect(_player_fighter, StatusTypes.StatusType.POISON)
	icon.update_display(effect)
	await get_tree().process_frame

	_assert(effect.stacks == 3, "Effect should have 3 stacks")
	_assert(stack_label.visible, "Stack label should be visible with multiple stacks")
	_assert(stack_label.text == "x3", "Stack label should show x3")

	# Cleanup
	icon.queue_free()
	_status_manager.remove_all(_player_fighter)
	_end_test()


func _test_icon_duration_bar() -> void:
	_start_test("StatusEffectIcon - Duration Bar")

	var icon_scene := preload("res://scenes/ui/status_effect_icon.tscn")
	var icon: StatusEffectIcon = icon_scene.instantiate()
	add_child(icon)
	await get_tree().process_frame

	# Apply effect with duration
	_status_manager.apply(_player_fighter, _poison_data)
	var effect := _status_manager.get_effect(_player_fighter, StatusTypes.StatusType.POISON)

	icon.setup(effect)
	await get_tree().process_frame

	var duration_bar := icon.get_node_or_null("DurationBar") as ProgressBar
	_assert(duration_bar != null, "Duration bar should exist")
	_assert(duration_bar.visible, "Duration bar should be visible for timed effects")
	_assert(duration_bar.max_value == _poison_data.duration, "Duration bar max should match effect duration")
	_assert(duration_bar.value == effect.remaining_duration, "Duration bar value should match remaining duration")

	# Simulate time passing
	effect.update_duration(2.0)
	icon.update_display(effect)
	await get_tree().process_frame

	_assert(absf(duration_bar.value - 3.0) < 0.01, "Duration bar should update as time passes")

	# Cleanup
	icon.queue_free()
	_status_manager.remove_all(_player_fighter)
	_end_test()


func _test_icon_permanent_effect() -> void:
	_start_test("StatusEffectIcon - Permanent Effect (No Duration)")

	var icon_scene := preload("res://scenes/ui/status_effect_icon.tscn")
	var icon: StatusEffectIcon = icon_scene.instantiate()
	add_child(icon)
	await get_tree().process_frame

	# Apply permanent effect (duration = 0)
	_status_manager.apply(_player_fighter, _dodge_data)
	var effect := _status_manager.get_effect(_player_fighter, StatusTypes.StatusType.DODGE)

	icon.setup(effect)
	await get_tree().process_frame

	var duration_bar := icon.get_node_or_null("DurationBar") as ProgressBar
	_assert(duration_bar != null, "Duration bar should exist")
	_assert(not duration_bar.visible, "Duration bar should be hidden for permanent effects")

	# Cleanup
	icon.queue_free()
	_status_manager.remove_all(_player_fighter)
	_end_test()


func _test_display_creation() -> void:
	_start_test("StatusEffectDisplay - Basic Creation")

	var display_scene := preload("res://scenes/ui/status_effect_display.tscn")
	var display: StatusEffectDisplay = display_scene.instantiate()
	add_child(display)
	await get_tree().process_frame

	display.setup(_player_fighter, _status_manager)
	await get_tree().process_frame

	_assert(display.get_child_count() == 0, "Display should start empty with no effects")

	# Cleanup
	display.queue_free()
	_end_test()


func _test_display_effect_added() -> void:
	_start_test("StatusEffectDisplay - Effect Added")

	var display_scene := preload("res://scenes/ui/status_effect_display.tscn")
	var display: StatusEffectDisplay = display_scene.instantiate()
	add_child(display)
	await get_tree().process_frame

	display.setup(_player_fighter, _status_manager)
	await get_tree().process_frame

	# Apply an effect
	_status_manager.apply(_player_fighter, _poison_data)
	await get_tree().process_frame

	_assert(display.get_child_count() == 1, "Display should have 1 icon after effect applied")

	# Apply another effect
	_status_manager.apply(_player_fighter, _bleed_data)
	await get_tree().process_frame

	_assert(display.get_child_count() == 2, "Display should have 2 icons after second effect")

	# Cleanup
	display.queue_free()
	_status_manager.remove_all(_player_fighter)
	_end_test()


func _test_display_effect_removed() -> void:
	_start_test("StatusEffectDisplay - Effect Removed")

	var display_scene := preload("res://scenes/ui/status_effect_display.tscn")
	var display: StatusEffectDisplay = display_scene.instantiate()
	add_child(display)
	await get_tree().process_frame

	display.setup(_player_fighter, _status_manager)

	# Apply effects
	_status_manager.apply(_player_fighter, _poison_data)
	_status_manager.apply(_player_fighter, _bleed_data)
	await get_tree().process_frame

	_assert(display.get_child_count() == 2, "Display should have 2 icons")

	# Remove one effect
	_status_manager.remove(_player_fighter, StatusTypes.StatusType.POISON)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for queue_free

	_assert(display.get_child_count() == 1, "Display should have 1 icon after removal")

	# Remove remaining effect
	_status_manager.remove(_player_fighter, StatusTypes.StatusType.BLEED)
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(display.get_child_count() == 0, "Display should be empty after all effects removed")

	# Cleanup
	display.queue_free()
	_end_test()


func _test_display_max_visible() -> void:
	_start_test("StatusEffectDisplay - Max Visible Effects")

	var display_scene := preload("res://scenes/ui/status_effect_display.tscn")
	var display: StatusEffectDisplay = display_scene.instantiate()
	display.max_visible_effects = 3
	add_child(display)
	await get_tree().process_frame

	display.setup(_player_fighter, _status_manager)
	await get_tree().process_frame

	# Create more effect data types
	var effects_data: Array[StatusEffectData] = []
	for i in range(5):
		var effect_data := StatusEffectData.new()
		effect_data.effect_id = "test_effect_%d" % i
		effect_data.display_name = "Test Effect %d" % i
		# Use different effect types
		match i:
			0: effect_data.effect_type = StatusTypes.StatusType.POISON
			1: effect_data.effect_type = StatusTypes.StatusType.BLEED
			2: effect_data.effect_type = StatusTypes.StatusType.ATTACK_UP
			3: effect_data.effect_type = StatusTypes.StatusType.DODGE
			4: effect_data.effect_type = StatusTypes.StatusType.EVASION
		effect_data.duration = 10.0
		effect_data.max_stacks = 1
		effects_data.append(effect_data)

	# Apply more effects than max_visible
	for data in effects_data:
		_status_manager.apply(_player_fighter, data)
		await get_tree().process_frame

	_assert(display.get_child_count() <= 3, "Display should not exceed max_visible_effects (3)")

	# Cleanup
	display.queue_free()
	_status_manager.remove_all(_player_fighter)
	_end_test()


func _test_display_stack_update() -> void:
	_start_test("StatusEffectDisplay - Stack Update")

	var display_scene := preload("res://scenes/ui/status_effect_display.tscn")
	var display: StatusEffectDisplay = display_scene.instantiate()
	add_child(display)
	await get_tree().process_frame

	display.setup(_player_fighter, _status_manager)
	await get_tree().process_frame

	# Apply effect
	_status_manager.apply(_player_fighter, _poison_data, null, 1)
	await get_tree().process_frame

	_assert(display.get_child_count() == 1, "Display should have 1 icon")

	var icon := display.get_child(0) as StatusEffectIcon
	_assert(icon != null, "Child should be StatusEffectIcon")

	var effect := icon.get_current_effect()
	_assert(effect.stacks == 1, "Initial stacks should be 1")

	# Add more stacks
	_status_manager.apply(_player_fighter, _poison_data, null, 2)
	await get_tree().process_frame

	effect = _status_manager.get_effect(_player_fighter, StatusTypes.StatusType.POISON)
	_assert(effect.stacks == 3, "Effect should now have 3 stacks")

	# The display updates via _process, so the icon should eventually reflect this
	# For immediate update, we'd need to trigger manually or wait

	# Cleanup
	display.queue_free()
	_status_manager.remove_all(_player_fighter)
	_end_test()


func _test_icons_generator_all_types() -> void:
	_start_test("StatusEffectIcons - All Type Generation")

	# Clear cache first
	StatusEffectIcons.clear_cache()

	# Test all effect types
	var types := [
		StatusTypes.StatusType.POISON,
		StatusTypes.StatusType.BLEED,
		StatusTypes.StatusType.ATTACK_UP,
		StatusTypes.StatusType.DODGE,
		StatusTypes.StatusType.EVASION,
		StatusTypes.StatusType.MANA_BLOCK,
	]

	for effect_type in types:
		var texture := StatusEffectIcons.get_icon_texture(effect_type)
		_assert(texture != null, "Texture for type %d should be generated" % effect_type)
		_assert(texture is ImageTexture, "Texture should be ImageTexture")

		# Verify texture dimensions
		var image := texture.get_image()
		_assert(image != null, "Texture should have valid image")
		_assert(image.get_width() == 32, "Texture width should be 32")
		_assert(image.get_height() == 32, "Texture height should be 32")

	_end_test()


# Test utility functions
func _start_test(name: String) -> void:
	_current_test = name
	_test_results[name] = {"passed": true, "errors": []}
	print("Running: %s" % name)


func _end_test() -> void:
	var result := _test_results[_current_test]
	if result["passed"]:
		print("  PASSED\n")
	else:
		print("  FAILED")
		for error in result["errors"]:
			print("    - %s" % error)
		print("")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_test_results[_current_test]["passed"] = false
		_test_results[_current_test]["errors"].append(message)
		print("  ASSERTION FAILED: %s" % message)


func _print_summary() -> void:
	print("========================================")
	print("TEST SUMMARY")
	print("========================================")

	var passed := 0
	var failed := 0

	for test_name in _test_results.keys():
		if _test_results[test_name]["passed"]:
			passed += 1
		else:
			failed += 1

	print("Total: %d tests" % (passed + failed))
	print("Passed: %d" % passed)
	print("Failed: %d" % failed)

	if failed == 0:
		print("\nAll tests PASSED!")
	else:
		print("\nSome tests FAILED. See details above.")
