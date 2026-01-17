# Task 028: Status Effect Data & Types

## Objective
Create the data structures and enums for the status effect system.

## Dependencies
- Task 002 (Data Resources)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Status Effects section
- `/docs/CHARACTERS.md` → Status effects used by characters

## Deliverables

### 1. Create StatusType Enum
Create `/scripts/data/status_types.gd`:

```gdscript
class_name StatusTypes

enum StatusType {
    POISON,       # DoT, ticks damage over time
    BLEED,        # Damage on enemy's next match
    DODGE,        # Chance to avoid next attack
    ATTACK_UP,    # Damage multiplier buff
    EVASION,      # Next attack auto-misses
    MANA_BLOCK,   # Prevent mana generation
}

enum StackBehavior {
    ADDITIVE,     # Stacks increase magnitude
    REFRESH,      # New application refreshes duration
    INDEPENDENT,  # Each stack tracks separately
    REPLACE,      # New application replaces old
}

enum TickBehavior {
    ON_TIME,      # Ticks every X seconds
    ON_MATCH,     # Triggers when target matches
    ON_HIT,       # Triggers when target is hit
    ON_ACTION,    # Triggers on any target action
}
```

### 2. Create StatusEffectData Resource
Create `/scripts/data/status_effect_data.gd`:

```gdscript
class_name StatusEffectData extends Resource

@export var effect_id: String
@export var display_name: String
@export var effect_type: StatusTypes.StatusType
@export var icon: Texture2D

# Duration
@export var duration: float = 0.0  # 0 = permanent until removed
@export var tick_interval: float = 1.0  # For DoT effects

# Stacking
@export var max_stacks: int = 99
@export var stack_behavior: StatusTypes.StackBehavior = StatusTypes.StackBehavior.ADDITIVE

# Tick behavior
@export var tick_behavior: StatusTypes.TickBehavior = StatusTypes.TickBehavior.ON_TIME

# Effect values (interpretation depends on effect_type)
@export var base_value: float = 0.0  # Damage per tick, buff %, etc.
@export var value_per_stack: float = 0.0  # Additional value per stack
```

### 3. Create StatusEffect Runtime Class
Create `/scripts/systems/status_effect.gd`:

```gdscript
class_name StatusEffect extends RefCounted

var data: StatusEffectData
var remaining_duration: float
var stacks: int = 1
var source: Fighter  # Who applied it
var tick_timer: float = 0.0

func _init(effect_data: StatusEffectData, source_fighter: Fighter = null) -> void:
    data = effect_data
    remaining_duration = effect_data.duration
    source = source_fighter
    tick_timer = 0.0

func get_value() -> float:
    return data.base_value + (data.value_per_stack * (stacks - 1))

func is_expired() -> bool:
    return data.duration > 0 and remaining_duration <= 0
```

### 4. Create Default Effect Resources
Create resource files in `/resources/effects/`:

**poison.tres:**
- effect_type: POISON
- duration: 5.0
- tick_interval: 1.0
- base_value: 5 (damage per tick)
- stack_behavior: ADDITIVE
- max_stacks: 10

**bleed.tres:**
- effect_type: BLEED
- duration: 0 (until triggered)
- tick_behavior: ON_MATCH
- base_value: 10
- stack_behavior: ADDITIVE
- max_stacks: 5

**attack_up.tres:**
- effect_type: ATTACK_UP
- duration: 10.0
- base_value: 0.25 (25% increase)
- stack_behavior: ADDITIVE
- max_stacks: 3

## Acceptance Criteria
- [ ] StatusTypes enum created with all types
- [ ] StatusEffectData resource script created
- [ ] StatusEffect runtime class created
- [ ] At least 3 default effect resources created
- [ ] Resources load without errors in editor
