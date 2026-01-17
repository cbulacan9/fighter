# Task 036: Mana System Tests

## Objective
Create test harness to validate mana system behavior in isolation.

## Dependencies
- Task 034 (Mana System Core)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Testing approach

## Deliverables

### 1. Create Test Scene
Create `/test/test_mana_system.tscn`:

Structure:
```
TestManaSystem (Node)
├── TestRunner (Node) [script: test_mana_system.gd]
├── MockFighter1 (Node)
└── MockFighter2 (Node)
```

### 2. Create Test Runner Script
Create `/test/test_mana_system.gd`:

```gdscript
extends Node

var mana_system: ManaSystem
var fighter1: MockFighter
var fighter2: MockFighter

var test_results: Array[String] = []
var tests_passed: int = 0
var tests_failed: int = 0

# Test configs
var single_bar_config: ManaConfig
var dual_bar_config: ManaConfig
var no_mana_config: ManaConfig

func _ready() -> void:
    _setup()
    call_deferred("_run_all_tests")

func _setup() -> void:
    mana_system = ManaSystem.new()

    # Create mock fighters
    fighter1 = MockFighter.new()
    fighter1.name = "Fighter1"
    add_child(fighter1)

    fighter2 = MockFighter.new()
    fighter2.name = "Fighter2"
    add_child(fighter2)

    # Create test configs
    single_bar_config = _create_single_bar_config()
    dual_bar_config = _create_dual_bar_config()
    no_mana_config = _create_no_mana_config()

func _run_all_tests() -> void:
    print("=== Mana System Tests ===")

    # Setup tests
    _test_setup_single_bar()
    _test_setup_dual_bar()
    _test_setup_no_mana()

    # Add mana tests
    _test_add_mana()
    _test_add_mana_capped()
    _test_add_mana_from_match()

    # Drain tests
    _test_drain_mana()
    _test_drain_all()
    _test_drain_empty()

    # Multi-bar tests
    _test_dual_bar_independent()
    _test_all_bars_full_check()

    # Blocking tests
    _test_mana_block()
    _test_mana_block_timer()

    # Signal tests
    _test_mana_changed_signal()
    _test_mana_full_signal()
    _test_all_bars_full_signal()

    # Reset tests
    _test_reset_fighter()
    _test_reset_all()

    # Ultimate readiness tests
    _test_can_use_ultimate_single()
    _test_can_use_ultimate_dual()

    # Tick tests
    _test_tick_decay()
    _test_tick_block_expiry()

    # Print results
    print("=== Results ===")
    print("Passed: %d" % tests_passed)
    print("Failed: %d" % tests_failed)
    for result in test_results:
        print(result)

func _reset_state() -> void:
    mana_system = ManaSystem.new()

# === Test Methods ===

func _test_setup_single_bar() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)

    var bar_count = mana_system.get_bar_count(fighter1)
    if bar_count == 1:
        _pass("Setup single bar")
    else:
        _fail("Setup single bar - expected 1, got %d" % bar_count)

func _test_setup_dual_bar() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, dual_bar_config)

    var bar_count = mana_system.get_bar_count(fighter1)
    if bar_count == 2:
        _pass("Setup dual bar")
    else:
        _fail("Setup dual bar - expected 2, got %d" % bar_count)

func _test_setup_no_mana() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, no_mana_config)

    var bar_count = mana_system.get_bar_count(fighter1)
    if bar_count == 0:
        _pass("Setup no mana")
    else:
        _fail("Setup no mana - expected 0, got %d" % bar_count)

func _test_add_mana() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)

    mana_system.add_mana(fighter1, 25)
    var current = mana_system.get_mana(fighter1)

    if current == 25:
        _pass("Add mana")
    else:
        _fail("Add mana - expected 25, got %d" % current)

func _test_add_mana_capped() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)

    mana_system.add_mana(fighter1, 150)  # Over max
    var current = mana_system.get_mana(fighter1)
    var max_val = mana_system.get_max_mana(fighter1)

    if current == max_val:
        _pass("Add mana capped at max")
    else:
        _fail("Add mana capped - expected %d, got %d" % [max_val, current])

func _test_add_mana_from_match() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)

    mana_system.add_mana_from_match(fighter1, 3)
    var current = mana_system.get_mana(fighter1)
    var expected = single_bar_config.get_mana_for_match(3)

    if current == expected:
        _pass("Add mana from match")
    else:
        _fail("Add mana from match - expected %d, got %d" % [expected, current])

func _test_drain_mana() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)
    mana_system.add_mana(fighter1, 50)

    var drained = mana_system.drain(fighter1, 20)
    var remaining = mana_system.get_mana(fighter1)

    if drained == 20 and remaining == 30:
        _pass("Drain mana")
    else:
        _fail("Drain mana - drained %d, remaining %d" % [drained, remaining])

func _test_drain_all() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)
    mana_system.add_mana(fighter1, 75)

    var drained = mana_system.drain_all(fighter1)
    var remaining = mana_system.get_mana(fighter1)

    if drained == 75 and remaining == 0:
        _pass("Drain all mana")
    else:
        _fail("Drain all - drained %d, remaining %d" % [drained, remaining])

func _test_drain_empty() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)

    var drained = mana_system.drain(fighter1, 50)

    if drained == 0:
        _pass("Drain from empty")
    else:
        _fail("Drain from empty - drained %d" % drained)

func _test_dual_bar_independent() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, dual_bar_config)

    mana_system.add_mana(fighter1, 30, 0)  # Bar 0
    mana_system.add_mana(fighter1, 50, 1)  # Bar 1

    var bar0 = mana_system.get_mana(fighter1, 0)
    var bar1 = mana_system.get_mana(fighter1, 1)

    if bar0 == 30 and bar1 == 50:
        _pass("Dual bar independent")
    else:
        _fail("Dual bar independent - bar0=%d, bar1=%d" % [bar0, bar1])

func _test_all_bars_full_check() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, dual_bar_config)

    mana_system.add_mana(fighter1, 100, 0)
    var all_full_one = mana_system.are_all_bars_full(fighter1)

    mana_system.add_mana(fighter1, 100, 1)
    var all_full_both = mana_system.are_all_bars_full(fighter1)

    if not all_full_one and all_full_both:
        _pass("All bars full check")
    else:
        _fail("All bars full check - one=%s, both=%s" % [all_full_one, all_full_both])

func _test_mana_block() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)
    mana_system.add_mana(fighter1, 20)

    mana_system.block_mana(fighter1, 5.0)
    var gained = mana_system.add_mana(fighter1, 30)

    if gained == 0:
        _pass("Mana block prevents gain")
    else:
        _fail("Mana block - gained %d when blocked" % gained)

func _test_mana_block_timer() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)

    mana_system.block_mana(fighter1, 2.0)

    # Tick past block duration
    mana_system.tick(3.0)

    var gained = mana_system.add_mana(fighter1, 30)

    if gained == 30:
        _pass("Mana block timer expires")
    else:
        _fail("Mana block timer - gained %d after expiry" % gained)

func _test_mana_changed_signal() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)

    var signal_received = false
    var received_value = 0
    mana_system.mana_changed.connect(func(f, idx, cur, max_v):
        if f == fighter1:
            signal_received = true
            received_value = cur
    )

    mana_system.add_mana(fighter1, 40)

    if signal_received and received_value == 40:
        _pass("Mana changed signal")
    else:
        _fail("Mana changed signal - received=%s, value=%d" % [signal_received, received_value])

func _test_mana_full_signal() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)

    var signal_received = false
    mana_system.mana_full.connect(func(f, idx):
        if f == fighter1:
            signal_received = true
    )

    mana_system.add_mana(fighter1, 100)

    if signal_received:
        _pass("Mana full signal")
    else:
        _fail("Mana full signal - not received")

func _test_all_bars_full_signal() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, dual_bar_config)

    var signal_received = false
    mana_system.all_bars_full.connect(func(f):
        if f == fighter1:
            signal_received = true
    )

    mana_system.add_mana(fighter1, 100, 0)
    mana_system.add_mana(fighter1, 100, 1)

    if signal_received:
        _pass("All bars full signal")
    else:
        _fail("All bars full signal - not received")

func _test_reset_fighter() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)
    mana_system.add_mana(fighter1, 75)

    mana_system.reset_fighter(fighter1)
    var current = mana_system.get_mana(fighter1)

    if current == 0:
        _pass("Reset fighter mana")
    else:
        _fail("Reset fighter - still has %d mana" % current)

func _test_reset_all() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)
    mana_system.setup_fighter(fighter2, single_bar_config)
    mana_system.add_mana(fighter1, 50)
    mana_system.add_mana(fighter2, 60)

    mana_system.reset_all()

    var f1 = mana_system.get_mana(fighter1)
    var f2 = mana_system.get_mana(fighter2)

    if f1 == 0 and f2 == 0:
        _pass("Reset all")
    else:
        _fail("Reset all - f1=%d, f2=%d" % [f1, f2])

func _test_can_use_ultimate_single() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)

    var can_use_empty = mana_system.can_use_ultimate(fighter1)
    mana_system.add_mana(fighter1, 100)
    var can_use_full = mana_system.can_use_ultimate(fighter1)

    if not can_use_empty and can_use_full:
        _pass("Can use ultimate (single bar)")
    else:
        _fail("Can use ultimate single - empty=%s, full=%s" % [can_use_empty, can_use_full])

func _test_can_use_ultimate_dual() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, dual_bar_config)

    mana_system.add_mana(fighter1, 100, 0)
    var can_use_one = mana_system.can_use_ultimate(fighter1)

    mana_system.add_mana(fighter1, 100, 1)
    var can_use_both = mana_system.can_use_ultimate(fighter1)

    if not can_use_one and can_use_both:
        _pass("Can use ultimate (dual bar)")
    else:
        _fail("Can use ultimate dual - one=%s, both=%s" % [can_use_one, can_use_both])

func _test_tick_decay() -> void:
    _reset_state()
    var decay_config = ManaConfig.new()
    decay_config.bar_count = 1
    decay_config.max_mana = [100]
    decay_config.decay_rate = 10.0  # 10 mana per second

    mana_system.setup_fighter(fighter1, decay_config)
    mana_system.add_mana(fighter1, 50)

    mana_system.tick(2.0)  # Should decay 20
    var current = mana_system.get_mana(fighter1)

    if current == 30:
        _pass("Mana decay on tick")
    else:
        _fail("Mana decay - expected 30, got %d" % current)

func _test_tick_block_expiry() -> void:
    _reset_state()
    mana_system.setup_fighter(fighter1, single_bar_config)
    mana_system.block_mana(fighter1, 1.0)

    mana_system.tick(0.5)
    var blocked_mid = mana_system.add_mana(fighter1, 10) == 0

    mana_system.tick(0.6)
    var blocked_after = mana_system.add_mana(fighter1, 10) == 0

    if blocked_mid and not blocked_after:
        _pass("Block expiry on tick")
    else:
        _fail("Block expiry - mid=%s, after=%s" % [blocked_mid, blocked_after])

# === Helper Methods ===

func _pass(test_name: String) -> void:
    tests_passed += 1
    test_results.append("[PASS] %s" % test_name)
    print("[PASS] %s" % test_name)

func _fail(message: String) -> void:
    tests_failed += 1
    test_results.append("[FAIL] %s" % message)
    print("[FAIL] %s" % message)

func _create_single_bar_config() -> ManaConfig:
    var config = ManaConfig.new()
    config.bar_count = 1
    config.max_mana = [100]
    config.mana_per_match = {3: 10, 4: 20, 5: 35}
    config.require_all_bars_full = true
    return config

func _create_dual_bar_config() -> ManaConfig:
    var config = ManaConfig.new()
    config.bar_count = 2
    config.max_mana = [100, 100]
    config.mana_per_match = {3: 10, 4: 20, 5: 35}
    config.require_all_bars_full = true
    return config

func _create_no_mana_config() -> ManaConfig:
    var config = ManaConfig.new()
    config.bar_count = 0
    config.max_mana = []
    return config
```

## Acceptance Criteria
- [ ] Test scene runs without errors
- [ ] All setup tests pass
- [ ] All add/drain tests pass
- [ ] Multi-bar tests pass
- [ ] Blocking tests pass
- [ ] Signal tests pass
- [ ] Reset tests pass
- [ ] Ultimate readiness tests pass
- [ ] Tick tests pass
- [ ] Tests run in isolation
