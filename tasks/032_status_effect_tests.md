# Task 032: Status Effect Tests

## Objective
Create test harness to validate status effect system behavior in isolation.

## Dependencies
- Task 030 (Status Effect Integration)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Testing approach

## Deliverables

### 1. Create Test Scene
Create `/test/test_status_effects.tscn`:

Structure:
```
TestStatusEffects (Node)
├── TestRunner (Node) [script: test_status_effects.gd]
├── MockFighter1 (Node)
└── MockFighter2 (Node)
```

### 2. Create Mock Fighter for Testing
Create `/test/mock_fighter.gd`:

```gdscript
class_name MockFighter extends Node

signal hp_changed(current: int, max_hp: int)
signal status_effect_applied(effect: StatusEffect)
signal status_effect_removed(effect_type: StatusTypes.StatusType)

var max_hp: int = 100
var current_hp: int = 100
var status_manager: StatusEffectManager
var damage_taken_log: Array[int] = []

func take_damage(amount: int) -> Dictionary:
    damage_taken_log.append(amount)
    current_hp = maxi(0, current_hp - amount)
    hp_changed.emit(current_hp, max_hp)
    return {"hp_damage": amount, "armor_absorbed": 0}

func heal(amount: int) -> void:
    current_hp = mini(current_hp + amount, max_hp)
    hp_changed.emit(current_hp, max_hp)

func reset() -> void:
    current_hp = max_hp
    damage_taken_log.clear()

func has_status(effect_type: StatusTypes.StatusType) -> bool:
    if status_manager:
        return status_manager.has_effect(self, effect_type)
    return false
```

### 3. Create Test Runner Script
Create `/test/test_status_effects.gd`:

```gdscript
extends Node

@onready var fighter1: MockFighter = $MockFighter1
@onready var fighter2: MockFighter = $MockFighter2

var status_manager: StatusEffectManager
var test_results: Array[String] = []
var tests_passed: int = 0
var tests_failed: int = 0

# Test effect resources
var poison_effect: StatusEffectData
var bleed_effect: StatusEffectData
var attack_up_effect: StatusEffectData

func _ready() -> void:
    _setup()
    call_deferred("_run_all_tests")

func _setup() -> void:
    status_manager = StatusEffectManager.new()
    fighter1.status_manager = status_manager
    fighter2.status_manager = status_manager

    # Load or create test effect data
    poison_effect = _create_poison_effect()
    bleed_effect = _create_bleed_effect()
    attack_up_effect = _create_attack_up_effect()

func _run_all_tests() -> void:
    print("=== Status Effect Tests ===")

    # Basic application tests
    _test_apply_single_effect()
    _test_apply_multiple_effects()
    _test_effect_removal()
    _test_cleanse_all()
    _test_cleanse_specific()

    # Stacking tests
    _test_additive_stacking()
    _test_refresh_stacking()
    _test_replace_stacking()
    _test_max_stacks()

    # Duration tests
    _test_duration_expiry()
    _test_permanent_effect()

    # Tick tests
    _test_poison_tick_damage()
    _test_bleed_on_match()

    # Modifier tests
    _test_attack_up_modifier()
    _test_dodge_chance()
    _test_evasion_auto_miss()

    # Print results
    print("=== Results ===")
    print("Passed: %d" % tests_passed)
    print("Failed: %d" % tests_failed)
    for result in test_results:
        print(result)

func _reset_state() -> void:
    status_manager.remove_all(fighter1)
    status_manager.remove_all(fighter2)
    fighter1.reset()
    fighter2.reset()

# === Test Methods ===

func _test_apply_single_effect() -> void:
    _reset_state()
    status_manager.apply(fighter1, poison_effect)

    if status_manager.has_effect(fighter1, StatusTypes.StatusType.POISON):
        _pass("Apply single effect")
    else:
        _fail("Apply single effect - effect not found")

func _test_apply_multiple_effects() -> void:
    _reset_state()
    status_manager.apply(fighter1, poison_effect)
    status_manager.apply(fighter1, attack_up_effect)

    var effects = status_manager.get_all_effects(fighter1)
    if effects.size() == 2:
        _pass("Apply multiple effects")
    else:
        _fail("Apply multiple effects - expected 2, got %d" % effects.size())

func _test_effect_removal() -> void:
    _reset_state()
    status_manager.apply(fighter1, poison_effect)
    status_manager.remove(fighter1, StatusTypes.StatusType.POISON)

    if not status_manager.has_effect(fighter1, StatusTypes.StatusType.POISON):
        _pass("Effect removal")
    else:
        _fail("Effect removal - effect still present")

func _test_cleanse_all() -> void:
    _reset_state()
    status_manager.apply(fighter1, poison_effect)
    status_manager.apply(fighter1, bleed_effect)
    status_manager.cleanse(fighter1)

    if status_manager.get_all_effects(fighter1).is_empty():
        _pass("Cleanse all")
    else:
        _fail("Cleanse all - effects remain")

func _test_cleanse_specific() -> void:
    _reset_state()
    status_manager.apply(fighter1, poison_effect)
    status_manager.apply(fighter1, bleed_effect)
    status_manager.cleanse(fighter1, [StatusTypes.StatusType.POISON])

    var has_poison = status_manager.has_effect(fighter1, StatusTypes.StatusType.POISON)
    var has_bleed = status_manager.has_effect(fighter1, StatusTypes.StatusType.BLEED)

    if not has_poison and has_bleed:
        _pass("Cleanse specific")
    else:
        _fail("Cleanse specific - wrong effects remaining")

func _test_additive_stacking() -> void:
    _reset_state()
    status_manager.apply(fighter1, poison_effect, null, 1)
    status_manager.apply(fighter1, poison_effect, null, 2)

    var stacks = status_manager.get_stacks(fighter1, StatusTypes.StatusType.POISON)
    if stacks == 3:
        _pass("Additive stacking")
    else:
        _fail("Additive stacking - expected 3, got %d" % stacks)

func _test_max_stacks() -> void:
    _reset_state()
    # Apply more than max stacks
    for i in range(15):
        status_manager.apply(fighter1, poison_effect)

    var stacks = status_manager.get_stacks(fighter1, StatusTypes.StatusType.POISON)
    if stacks == poison_effect.max_stacks:
        _pass("Max stacks cap")
    else:
        _fail("Max stacks cap - expected %d, got %d" % [poison_effect.max_stacks, stacks])

func _test_refresh_stacking() -> void:
    _reset_state()
    var refresh_effect = _create_refresh_effect()
    status_manager.apply(fighter1, refresh_effect)

    # Simulate time passing
    var effect = status_manager.get_effect(fighter1, refresh_effect.effect_type)
    effect.remaining_duration = 1.0  # Nearly expired

    # Apply again - should refresh
    status_manager.apply(fighter1, refresh_effect)
    effect = status_manager.get_effect(fighter1, refresh_effect.effect_type)

    if effect.remaining_duration == refresh_effect.duration:
        _pass("Refresh stacking")
    else:
        _fail("Refresh stacking - duration not reset")

func _test_replace_stacking() -> void:
    _reset_state()
    var replace_effect = _create_replace_effect()
    status_manager.apply(fighter1, replace_effect, fighter1, 2)
    status_manager.apply(fighter1, replace_effect, fighter2, 1)

    var effect = status_manager.get_effect(fighter1, replace_effect.effect_type)
    if effect.source == fighter2 and effect.stacks == 1:
        _pass("Replace stacking")
    else:
        _fail("Replace stacking - not replaced correctly")

func _test_duration_expiry() -> void:
    _reset_state()
    status_manager.apply(fighter1, poison_effect)

    # Simulate time passing beyond duration
    for i in range(int(poison_effect.duration) + 2):
        status_manager.tick(1.0)

    if not status_manager.has_effect(fighter1, StatusTypes.StatusType.POISON):
        _pass("Duration expiry")
    else:
        _fail("Duration expiry - effect still present")

func _test_permanent_effect() -> void:
    _reset_state()
    var permanent = _create_permanent_effect()
    status_manager.apply(fighter1, permanent)

    # Tick many times
    for i in range(100):
        status_manager.tick(1.0)

    if status_manager.has_effect(fighter1, permanent.effect_type):
        _pass("Permanent effect")
    else:
        _fail("Permanent effect - expired unexpectedly")

func _test_poison_tick_damage() -> void:
    _reset_state()
    status_manager.apply(fighter1, poison_effect, null, 2)

    var initial_hp = fighter1.current_hp
    status_manager.tick(poison_effect.tick_interval)

    var expected_damage = poison_effect.base_value + poison_effect.value_per_stack
    var actual_damage = initial_hp - fighter1.current_hp

    if actual_damage == int(expected_damage):
        _pass("Poison tick damage")
    else:
        _fail("Poison tick damage - expected %d, got %d" % [expected_damage, actual_damage])

func _test_bleed_on_match() -> void:
    _reset_state()
    status_manager.apply(fighter1, bleed_effect, null, 2)

    var initial_hp = fighter1.current_hp
    status_manager._on_target_matched(fighter1)

    var damage = initial_hp - fighter1.current_hp
    if damage > 0:
        _pass("Bleed on match")
    else:
        _fail("Bleed on match - no damage dealt")

func _test_attack_up_modifier() -> void:
    _reset_state()
    status_manager.apply(fighter1, attack_up_effect, null, 2)

    var modifier = status_manager.get_modifier(fighter1, StatusTypes.StatusType.ATTACK_UP)
    var expected = attack_up_effect.base_value + attack_up_effect.value_per_stack

    if absf(modifier - expected) < 0.01:
        _pass("Attack up modifier")
    else:
        _fail("Attack up modifier - expected %.2f, got %.2f" % [expected, modifier])

func _test_dodge_chance() -> void:
    _reset_state()
    var dodge_effect = _create_dodge_effect()
    status_manager.apply(fighter1, dodge_effect)

    # This is probabilistic, so we just verify the modifier exists
    var modifier = status_manager.get_modifier(fighter1, StatusTypes.StatusType.DODGE)
    if modifier > 0:
        _pass("Dodge chance modifier")
    else:
        _fail("Dodge chance modifier - not set")

func _test_evasion_auto_miss() -> void:
    _reset_state()
    var evasion_effect = _create_evasion_effect()
    status_manager.apply(fighter1, evasion_effect)

    # Verify evasion is present
    if status_manager.has_effect(fighter1, StatusTypes.StatusType.EVASION):
        _pass("Evasion effect applied")
    else:
        _fail("Evasion effect not applied")

# === Helper Methods ===

func _pass(test_name: String) -> void:
    tests_passed += 1
    test_results.append("[PASS] %s" % test_name)
    print("[PASS] %s" % test_name)

func _fail(message: String) -> void:
    tests_failed += 1
    test_results.append("[FAIL] %s" % message)
    print("[FAIL] %s" % message)

func _create_poison_effect() -> StatusEffectData:
    var effect = StatusEffectData.new()
    effect.effect_id = "test_poison"
    effect.effect_type = StatusTypes.StatusType.POISON
    effect.duration = 5.0
    effect.tick_interval = 1.0
    effect.base_value = 5.0
    effect.value_per_stack = 2.0
    effect.max_stacks = 10
    effect.stack_behavior = StatusTypes.StackBehavior.ADDITIVE
    effect.tick_behavior = StatusTypes.TickBehavior.ON_TIME
    return effect

func _create_bleed_effect() -> StatusEffectData:
    var effect = StatusEffectData.new()
    effect.effect_id = "test_bleed"
    effect.effect_type = StatusTypes.StatusType.BLEED
    effect.duration = 0.0  # Until triggered
    effect.base_value = 10.0
    effect.max_stacks = 5
    effect.stack_behavior = StatusTypes.StackBehavior.ADDITIVE
    effect.tick_behavior = StatusTypes.TickBehavior.ON_MATCH
    return effect

func _create_attack_up_effect() -> StatusEffectData:
    var effect = StatusEffectData.new()
    effect.effect_id = "test_attack_up"
    effect.effect_type = StatusTypes.StatusType.ATTACK_UP
    effect.duration = 10.0
    effect.base_value = 0.25
    effect.value_per_stack = 0.1
    effect.max_stacks = 3
    effect.stack_behavior = StatusTypes.StackBehavior.ADDITIVE
    return effect

func _create_refresh_effect() -> StatusEffectData:
    var effect = StatusEffectData.new()
    effect.effect_id = "test_refresh"
    effect.effect_type = StatusTypes.StatusType.ATTACK_UP
    effect.duration = 5.0
    effect.stack_behavior = StatusTypes.StackBehavior.REFRESH
    return effect

func _create_replace_effect() -> StatusEffectData:
    var effect = StatusEffectData.new()
    effect.effect_id = "test_replace"
    effect.effect_type = StatusTypes.StatusType.DODGE
    effect.duration = 5.0
    effect.stack_behavior = StatusTypes.StackBehavior.REPLACE
    return effect

func _create_permanent_effect() -> StatusEffectData:
    var effect = StatusEffectData.new()
    effect.effect_id = "test_permanent"
    effect.effect_type = StatusTypes.StatusType.MANA_BLOCK
    effect.duration = 0.0  # Permanent
    return effect

func _create_dodge_effect() -> StatusEffectData:
    var effect = StatusEffectData.new()
    effect.effect_id = "test_dodge"
    effect.effect_type = StatusTypes.StatusType.DODGE
    effect.duration = 10.0
    effect.base_value = 0.5  # 50% dodge chance
    return effect

func _create_evasion_effect() -> StatusEffectData:
    var effect = StatusEffectData.new()
    effect.effect_id = "test_evasion"
    effect.effect_type = StatusTypes.StatusType.EVASION
    effect.duration = 0.0  # Until consumed
    return effect
```

### 4. Run Instructions
Add to test scene or create launcher:

```gdscript
# To run tests, either:
# 1. Set test_status_effects.tscn as main scene temporarily
# 2. Or create a test launcher that instances the scene

# Results will print to console
```

## Acceptance Criteria
- [ ] Test scene runs without errors
- [ ] All basic application tests pass
- [ ] All stacking behavior tests pass
- [ ] Duration expiry test passes
- [ ] Tick damage tests pass
- [ ] Modifier calculation tests pass
- [ ] Tests can be run in isolation (no game dependencies)
- [ ] Test results clearly indicate pass/fail
