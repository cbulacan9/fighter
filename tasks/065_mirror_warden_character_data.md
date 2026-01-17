# Task 065: Mirror Warden Character Data

## Objective
Create the Mirror Warden character resource with all tiles and abilities defined.

## Dependencies
- Task 064 (Defensive Queue System)
- Task 045 (Character Data Resource)

## Reference
- `/docs/CHARACTERS.md` → The Mirror Warden

## Deliverables

### 1. Create Mirror Warden Character Resource
Create `/resources/characters/mirror_warden.tres`:

```gdscript
character_id = "mirror_warden"
display_name = "The Mirror Warden"
archetype = "Tank"
description = "A defensive specialist who queues reactive abilities to counter enemy attacks. Rewards anticipation and timing with powerful defensive payoffs."

basic_tiles = [
    magic_attack.tres,
    shield.tres,
    health.tres
]
specialty_tiles = [
    reflection.tres,
    cancel.tres,
    absorb.tres
]

spawn_weights = {
    MAGIC: 25,
    SHIELD: 25,
    HEALTH: 25,
    REFLECTION: 8,
    CANCEL: 9,
    ABSORB: 8
}

mana_config = single_bar.tres
sequences = []

ultimate_ability = invincibility.tres

base_hp = 120  # Higher HP for tank
base_armor = 10  # Starts with some armor
is_starter = false
unlock_opponent_id = "mirror_warden"

# Special flag for defensive queue
uses_defensive_queue = true
```

### 2. Add New Tile Types
Modify `/scripts/data/tile_types.gd`:

```gdscript
enum Type {
    # Existing...
    REFLECTION,  # Mirror Warden specialty
    CANCEL,      # Mirror Warden specialty
    ABSORB,      # Mirror Warden specialty
}
```

### 3. Create Reflection Tile
Create `/resources/tiles/reflection.tres`:

```gdscript
tile_type = REFLECTION
display_name = "Mirror Shield"
is_matchable = true
is_clickable = false
match_effect = queue_reflection_effect.tres
```

### 4. Create Cancel Tile
Create `/resources/tiles/cancel.tres`:

```gdscript
tile_type = CANCEL
display_name = "Nullify"
is_matchable = true
is_clickable = false
match_effect = queue_cancel_effect.tres
```

### 5. Create Absorb Tile
Create `/resources/tiles/absorb.tres`:

```gdscript
tile_type = ABSORB
display_name = "Soul Trap"
is_matchable = true
is_clickable = false
match_effect = queue_absorb_effect.tres
```

### 6. Create Queue Effect Resources

**queue_reflection_effect.tres:**
```gdscript
effect_type = CUSTOM
custom_effect_id = "queue_reflection"
target = SELF
duration = 5.0  # Window duration
```

**queue_cancel_effect.tres:**
```gdscript
effect_type = CUSTOM
custom_effect_id = "queue_cancel"
target = SELF
duration = 5.0
```

**queue_absorb_effect.tres:**
```gdscript
effect_type = CUSTOM
custom_effect_id = "queue_absorb"
target = SELF
duration = 5.0
```

### 7. Create Invincibility Ultimate
Create `/resources/abilities/invincibility.tres`:

```gdscript
ability_id = "invincibility"
display_name = "Invincibility"
description = "Grants complete damage immunity for 8 seconds."
requires_full_mana = true
drains_all_mana = true
duration = 8.0

effects = [invincibility_buff.tres]
```

Create `/resources/effects/invincibility_buff.tres`:
```gdscript
effect_type = STATUS_APPLY
target = SELF
status_effect = invincibility_status.tres
```

Create `/resources/effects/invincibility_status.tres`:
```gdscript
effect_type = INVINCIBILITY
duration = 8.0
tick_behavior = ON_TIME
tick_interval = 0.1
```

### 8. Add INVINCIBILITY to StatusTypes
Modify `/scripts/data/status_types.gd`:

```gdscript
enum StatusType {
    # Existing...
    INVINCIBILITY,  # Complete damage immunity
}
```

### 9. Add CharacterData Property
Modify CharacterData:

```gdscript
@export var uses_defensive_queue: bool = false

func has_defensive_queue() -> bool:
    return uses_defensive_queue
```

## Acceptance Criteria
- [ ] Mirror Warden character resource created
- [ ] REFLECTION, CANCEL, ABSORB tile types added
- [ ] INVINCIBILITY status type added
- [ ] All specialty tile resources created
- [ ] Queue effect resources created
- [ ] Invincibility ultimate defined
- [ ] Higher HP/armor for tank archetype
- [ ] Resources load without errors
