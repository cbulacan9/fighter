# Task 041: Sequence Pattern Data

## Objective
Create the data structures for combo sequence patterns.

## Dependencies
- Task 002 (Data Resources)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Combo Sequences section
- `/docs/CHARACTERS.md` → Hunter sequences

## Deliverables

### 1. Create SequencePattern Resource
Create `/scripts/data/sequence_pattern.gd`:

```gdscript
class_name SequencePattern extends Resource

## Unique identifier for this sequence
@export var sequence_id: String

## Display name for UI
@export var display_name: String

## The tile types that must be matched in order
@export var pattern: Array[TileTypes.TileType] = []

## The tile type that terminates/activates the sequence (usually clicked)
@export var terminator: TileTypes.TileType

## Effect triggered when sequence is activated
@export var on_complete_effect: EffectData

## Secondary effect (for self-buff component)
@export var self_buff_effect: EffectData

## Maximum times this sequence can be stacked
@export var max_stacks: int = 3

## Icon for UI display
@export var icon: Texture2D

## Description for UI
@export_multiline var description: String = ""

func get_pattern_length() -> int:
    return pattern.size()

func matches_prefix(sequence: Array[TileTypes.TileType]) -> bool:
    if sequence.size() > pattern.size():
        return false

    for i in range(sequence.size()):
        if sequence[i] != pattern[i]:
            return false

    return true

func is_complete_match(sequence: Array[TileTypes.TileType]) -> bool:
    if sequence.size() != pattern.size():
        return false

    for i in range(sequence.size()):
        if sequence[i] != pattern[i]:
            return false

    return true
```

### 2. Create Hunter Sequence Resources
Create sequence resources in `/resources/sequences/`:

**bear_sequence.tres:**
```gdscript
sequence_id = "bear"
display_name = "Bear"
pattern = [PHYSICAL, SHIELD, SHIELD]  # Physical → Shield → Shield
terminator = PET
# on_complete_effect = bleed stack on enemy
# self_buff_effect = attack strength increase
max_stacks = 3
description = "Physical → Shield → Shield → Pet\nApplies bleed to enemy, buffs attack."
```

**hawk_sequence.tres:**
```gdscript
sequence_id = "hawk"
display_name = "Hawk"
pattern = [SHIELD, STUN]  # Shield → Stun
terminator = PET
# on_complete_effect = replace 10 enemy tiles with empty boxes
# self_buff_effect = evasion (next attack auto-misses)
max_stacks = 3
description = "Shield → Stun → Pet\nReplaces enemy tiles, grants evasion."
```

**snake_sequence.tres:**
```gdscript
sequence_id = "snake"
display_name = "Snake"
pattern = [STUN, PHYSICAL, SHIELD]  # Stun → Physical → Shield
terminator = PET
# on_complete_effect = 3-second enemy board stun
# self_buff_effect = cleanses own poison
max_stacks = 3
description = "Stun → Physical → Shield → Pet\nStuns enemy board, cleanses poison."
```

### 3. Create SequenceState Runtime Class
Create `/scripts/systems/sequence_state.gd`:

```gdscript
class_name SequenceState extends RefCounted

var pattern: SequencePattern
var is_complete: bool = false
var stacks: int = 0

func _init(seq_pattern: SequencePattern) -> void:
    pattern = seq_pattern
    is_complete = false
    stacks = 0

func add_stack() -> void:
    stacks = mini(stacks + 1, pattern.max_stacks)

func consume_stack() -> bool:
    if stacks > 0:
        stacks -= 1
        return true
    return false

func reset() -> void:
    is_complete = false
    stacks = 0
```

### 4. Create Sequence Effect Data
Create effect data for Hunter sequences:

**bear_bleed_effect.tres:**
```gdscript
effect_type = STATUS_APPLY
target = ENEMY
status_effect = [bleed status with 1 stack]
```

**bear_attack_buff.tres:**
```gdscript
effect_type = STATUS_APPLY
target = SELF
status_effect = [attack_up status]
```

**hawk_tile_replace.tres:**
```gdscript
effect_type = CUSTOM
target = BOARD_ENEMY
custom_effect_id = "hawk_tile_replace"
base_value = 10  # Number of tiles to replace
```

**hawk_evasion.tres:**
```gdscript
effect_type = STATUS_APPLY
target = SELF
status_effect = [evasion status - next attack misses]
```

**snake_stun.tres:**
```gdscript
effect_type = STUN
target = ENEMY
duration = 3.0
```

**snake_cleanse.tres:**
```gdscript
effect_type = STATUS_REMOVE
target = SELF
status_types_to_remove = [POISON]
```

## Acceptance Criteria
- [ ] SequencePattern resource script created
- [ ] Pattern matching methods work correctly
- [ ] All three Hunter sequences created as resources
- [ ] SequenceState runtime class created
- [ ] Effect data for all sequence abilities created
- [ ] Resources load without errors
