# Task 049: Hunter Character Data

## Objective
Create the Hunter character resource with all tiles, sequences, and abilities defined.

## Dependencies
- Task 045 (Character Data Resource)
- Task 041 (Sequence Pattern Data)

## Reference
- `/docs/CHARACTERS.md` → The Hunter

## Deliverables

### 1. Create Hunter Character Resource
Create `/resources/characters/hunter.tres`:

```gdscript
character_id = "hunter"
display_name = "The Hunter"
archetype = "Stun Heavy"
description = "A combo-sequence specialist who commands animal companions. Match tiles in specific sequences, then click Pet to unleash devastating abilities. Rewards precise board management."

basic_tiles = [
    physical_attack.tres,
    shield.tres,
    stun.tres,
    empty_box.tres
]
specialty_tiles = [
    pet.tres
]

spawn_weights = {
    PHYSICAL: 25,
    SHIELD: 25,
    STUN: 20,
    FILLER: 25,
    PET: 5  # Low spawn, guaranteed minimum
}

mana_config = single_bar_config.tres
sequences = [bear_sequence, hawk_sequence, snake_sequence]

ultimate_ability = alpha_command.tres

base_hp = 100
is_starter = false
unlock_opponent_id = "hunter"  # Beat Hunter AI to unlock
```

### 2. Create Hunter-Specific Tile Data

**physical_attack.tres:**
```gdscript
tile_type = PHYSICAL
display_name = "Physical Attack"
is_matchable = true
match_effect = damage_effect.tres
```

**pet.tres:**
```gdscript
tile_type = PET
display_name = "Pet"
is_matchable = false
is_clickable = true
click_condition = SEQUENCE_COMPLETE
min_on_board = 1
max_on_board = 2
```

**empty_box.tres:**
```gdscript
tile_type = FILLER
display_name = "Empty Box"
is_matchable = true
spawn_weight_modifier = 0.5  # Low spawn rate
```

### 3. Add PET to TileTypes
Modify `/scripts/data/tile_types.gd`:

```gdscript
enum TileType {
    # Existing
    SWORD,
    SHIELD,
    POTION,
    LIGHTNING,
    FILLER,
    MANA,
    # Hunter
    PHYSICAL,
    PET,
    # ... more as needed
}
```

### 4. Create Hunter Sequence Resources
Create in `/resources/sequences/`:

**bear_sequence.tres:**
```gdscript
sequence_id = "bear"
display_name = "Bear"
pattern = [PHYSICAL, SHIELD, SHIELD]
terminator = PET
on_complete_effect = bear_bleed.tres
self_buff_effect = bear_attack_up.tres
max_stacks = 3
description = "Physical → Shield → Shield → Pet"
```

**hawk_sequence.tres:**
```gdscript
sequence_id = "hawk"
display_name = "Hawk"
pattern = [SHIELD, STUN]
terminator = PET
on_complete_effect = hawk_replace.tres
self_buff_effect = hawk_evasion.tres
max_stacks = 3
description = "Shield → Stun → Pet"
```

**snake_sequence.tres:**
```gdscript
sequence_id = "snake"
display_name = "Snake"
pattern = [STUN, PHYSICAL, SHIELD]
terminator = PET
on_complete_effect = snake_stun.tres
self_buff_effect = snake_cleanse.tres
max_stacks = 3
description = "Stun → Physical → Shield → Pet"
```

### 5. Create Hunter Ability Effects
Create effect resources for each ability.

### 6. Create Alpha Command Ultimate
Create `/resources/abilities/alpha_command.tres`:

```gdscript
ability_id = "alpha_command"
display_name = "Alpha Command"
description = "2x multiplier to pet ability offensive effects and self-buffs. Multiplier decays over time."
requires_full_mana = true
drains_all_mana = true
duration = 8.0

effects = [alpha_buff.tres]
```

## Acceptance Criteria
- [ ] Hunter character resource created
- [ ] All Hunter tiles defined
- [ ] All sequences defined with effects
- [ ] Alpha Command ultimate defined
- [ ] PET tile type added to enum
- [ ] Resources load without errors
