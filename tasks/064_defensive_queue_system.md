# Task 064: Defensive Queue System

## Objective
Implement the Mirror Warden's core mechanic: queueing reactive defensive abilities with timing windows.

## Dependencies
- Task 045 (Character Data Resource)
- Task 030 (Status Effect Integration)

## Reference
- `/docs/CHARACTERS.md` → The Mirror Warden

## Overview
Matching defensive tiles queues that effect with a countdown timer:
- Queued abilities expire if not triggered within their window
- Matching the same type 3x in a row stacks into a stronger version
- A visible UI indicator shows when Warden is in defensive posture

## Deliverables

### 1. Create DefensiveQueue Class
Create `/scripts/systems/defensive_queue.gd`:

```gdscript
class_name DefensiveQueue extends RefCounted

signal ability_queued(ability_type: DefenseType, stacks: int, duration: float)
signal ability_triggered(ability_type: DefenseType, trigger_context: Dictionary)
signal ability_expired(ability_type: DefenseType)
signal stack_increased(ability_type: DefenseType, new_stacks: int)

enum DefenseType {
    REFLECTION,  # Pre-attack counter
    CANCEL,      # Post-attack cancel
    ABSORB       # On-hit damage storage
}

class QueuedAbility:
    var defense_type: DefenseType
    var remaining_time: float
    var stacks: int = 1
    var stored_damage: int = 0  # For Absorb
    var max_stacks: int = 3

var _queued_abilities: Dictionary = {}  # {DefenseType: QueuedAbility}
var _enabled: bool = true

const DEFAULT_DURATION = 5.0
const STACK_DURATION_REFRESH = true

func queue_ability(defense_type: DefenseType, duration: float = DEFAULT_DURATION) -> void:
    if not _enabled:
        return

    if _queued_abilities.has(defense_type):
        # Stack existing ability
        var ability = _queued_abilities[defense_type]
        if ability.stacks < ability.max_stacks:
            ability.stacks += 1
            if STACK_DURATION_REFRESH:
                ability.remaining_time = duration
            stack_increased.emit(defense_type, ability.stacks)
    else:
        # Create new queued ability
        var ability = QueuedAbility.new()
        ability.defense_type = defense_type
        ability.remaining_time = duration
        ability.stacks = 1
        _queued_abilities[defense_type] = ability
        ability_queued.emit(defense_type, 1, duration)

func tick(delta: float) -> void:
    var expired: Array[DefenseType] = []

    for defense_type in _queued_abilities.keys():
        var ability = _queued_abilities[defense_type]
        ability.remaining_time -= delta
        if ability.remaining_time <= 0:
            expired.append(defense_type)

    for defense_type in expired:
        _queued_abilities.erase(defense_type)
        ability_expired.emit(defense_type)

func has_queued(defense_type: DefenseType) -> bool:
    return _queued_abilities.has(defense_type)

func get_stacks(defense_type: DefenseType) -> int:
    if _queued_abilities.has(defense_type):
        return _queued_abilities[defense_type].stacks
    return 0

func try_trigger(defense_type: DefenseType, context: Dictionary) -> bool:
    """
    Attempt to trigger a queued ability.
    Returns true if ability was triggered and consumed.
    """
    if not _queued_abilities.has(defense_type):
        return false

    var ability = _queued_abilities[defense_type]
    ability_triggered.emit(defense_type, context)
    _queued_abilities.erase(defense_type)
    return true

func consume_stack(defense_type: DefenseType) -> int:
    """
    Consume one stack from a queued ability.
    Returns remaining stacks (0 if ability removed).
    """
    if not _queued_abilities.has(defense_type):
        return 0

    var ability = _queued_abilities[defense_type]
    ability.stacks -= 1

    if ability.stacks <= 0:
        _queued_abilities.erase(defense_type)
        return 0

    return ability.stacks

func store_damage(amount: int) -> void:
    """For Absorb ability - store damage for later release."""
    if _queued_abilities.has(DefenseType.ABSORB):
        _queued_abilities[DefenseType.ABSORB].stored_damage += amount

func get_stored_damage() -> int:
    if _queued_abilities.has(DefenseType.ABSORB):
        return _queued_abilities[DefenseType.ABSORB].stored_damage
    return 0

func clear_all() -> void:
    _queued_abilities.clear()

func get_all_queued() -> Array[DefenseType]:
    var result: Array[DefenseType] = []
    for key in _queued_abilities.keys():
        result.append(key)
    return result
```

### 2. Create DefensiveQueue UI
Create `/scripts/ui/defensive_queue_indicator.gd`:

```gdscript
class_name DefensiveQueueIndicator extends Control

@onready var ability_container: HBoxContainer = $AbilityContainer

var _ability_displays: Dictionary = {}  # {DefenseType: AbilityDisplay}

class AbilityDisplay:
    var icon: TextureRect
    var timer_bar: ProgressBar
    var stack_label: Label

func setup(defensive_queue: DefensiveQueue) -> void:
    defensive_queue.ability_queued.connect(_on_ability_queued)
    defensive_queue.ability_expired.connect(_on_ability_expired)
    defensive_queue.ability_triggered.connect(_on_ability_triggered)
    defensive_queue.stack_increased.connect(_on_stack_increased)

func _process(delta: float) -> void:
    # Update timer bars
    for defense_type in _ability_displays.keys():
        _update_timer_display(defense_type)
```

### 3. Integrate with CombatManager
Modify CombatManager to check defensive queue before/after attacks:

```gdscript
var _player_defensive_queue: DefensiveQueue
var _enemy_defensive_queue: DefensiveQueue

func _apply_damage(target: Fighter, source: Fighter, amount: int) -> void:
    var queue = _get_defensive_queue(target)

    # Pre-attack: Check Reflection (must be within 2 sec before attack)
    if queue.has_queued(DefensiveQueue.DefenseType.REFLECTION):
        # Reflect damage back to source
        var stacks = queue.get_stacks(DefensiveQueue.DefenseType.REFLECTION)
        var reflect_amount = amount * stacks  # Stacks multiply reflection
        queue.try_trigger(DefensiveQueue.DefenseType.REFLECTION, {"damage": amount})
        _apply_reflected_damage(source, reflect_amount)
        return  # Original damage negated

    # On-hit: Check Absorb
    if queue.has_queued(DefensiveQueue.DefenseType.ABSORB):
        queue.store_damage(amount)
        var stacks = queue.get_stacks(DefensiveQueue.DefenseType.ABSORB)
        var absorbed = int(amount * 0.5 * stacks)  # Absorb reduces damage
        amount -= absorbed
        # Damage stored for later release

    # Apply remaining damage
    target.take_damage(amount)

    # Post-attack: Cancel window opens
    # (Cancel is checked on next match within 2 sec)
```

### 4. Timing Window Mechanics
Reflection - Pre-attack window:
- Activated when attack is "incoming" (visual telegraph)
- Must be queued before damage resolves

Cancel - Post-attack window:
- Can be triggered within 2 seconds after receiving damage
- Cancels the effect (not damage, but status effects, stun, etc.)

Absorb - On-hit:
- Passively stores damage when hit
- Released on next match combo

### 5. Visible Defensive Posture
When any ability is queued, show indicator to opponent:
- "Warden is defending!" warning
- Icon showing which defense is active
- Timer visible to both players

## Acceptance Criteria
- [ ] DefensiveQueue tracks queued abilities with timers
- [ ] Abilities expire after duration if not triggered
- [ ] Stacking (3x match) increases ability power
- [ ] Reflection works as pre-attack counter
- [ ] Cancel works as post-attack effect negation
- [ ] Absorb stores and releases damage
- [ ] UI shows defensive posture to both players
- [ ] Timers visible and update correctly
