# Task 060: Apothecary Character Data

## Objective
Create the Apothecary character resource with all tiles and abilities defined.

## Dependencies
- Task 059 (Variety Chain System)
- Task 045 (Character Data Resource)

## Reference
- `/docs/CHARACTERS.md` → The Apothecary

## Deliverables

### 1. Create Apothecary Character Resource
Create `/resources/characters/apothecary.tres`:

```gdscript
character_id = "apothecary"
display_name = "The Apothecary"
archetype = "Status Effect"
description = "A variety-focused caster who rewards diverse matching patterns with damage multipliers. Specializes in poison damage and board manipulation."

basic_tiles = [
    magic_attack.tres,
    health.tres,
    mana.tres,
    filler.tres
]
specialty_tiles = [
    poison_tile.tres,
    potion_tile.tres
]

spawn_weights = {
    MAGIC: 25,
    HEALTH: 20,
    MANA: 20,
    FILLER: 20,
    POISON_TILE: 8,
    POTION_TILE: 7
}

mana_config = single_bar.tres
sequences = []  # Uses variety chain instead

ultimate_ability = transmute.tres

base_hp = 95
is_starter = false
unlock_opponent_id = "apothecary"

# Special flag for variety chain system
uses_variety_chain = true
```

### 2. Add New Tile Types
Modify `/scripts/data/tile_types.gd`:

```gdscript
enum Type {
    # Existing...
    MAGIC,        # Apothecary attack
    HEALTH,       # Apothecary heal (renamed from POTION to avoid confusion)
    POISON_TILE,  # Apothecary specialty
    POTION_TILE,  # Apothecary specialty (different from HEALTH)
}
```

### 3. Create Magic Attack Tile
Create `/resources/tiles/magic_attack.tres`:

```gdscript
tile_type = MAGIC
display_name = "Magic Attack"
is_matchable = true
is_clickable = false
match_effect = magic_damage_effect.tres
```

### 4. Create Health Tile
Create `/resources/tiles/health.tres`:

```gdscript
tile_type = HEALTH
display_name = "Health"
is_matchable = true
is_clickable = false
match_effect = heal_effect.tres  # Uses existing heal effect
```

### 5. Create Poison Specialty Tile
Create `/resources/tiles/poison_tile.tres`:

```gdscript
tile_type = POISON_TILE
display_name = "Poison Vial"
is_matchable = true
is_clickable = true
click_condition = ALWAYS  # Can always click to apply poison
match_effect = null  # No passive on match
click_effect = apply_poison_effect.tres
```

### 6. Create Potion Specialty Tile
Create `/resources/tiles/potion_tile.tres`:

```gdscript
tile_type = POTION_TILE
display_name = "Healing Elixir"
is_matchable = true
is_clickable = true
click_condition = ALWAYS
match_effect = null  # No passive on match
click_effect = transmute_filler_effect.tres
```

### 7. Create Effect Resources

**magic_damage_effect.tres:**
```gdscript
effect_type = DAMAGE
target = ENEMY
values_by_match_size = {3: 12, 4: 28, 5: 55}  # Slightly higher than physical
```

**apply_poison_effect.tres:**
```gdscript
effect_type = STATUS_APPLY
target = ENEMY
status_effect = poison.tres  # Uses existing poison status
stacks_to_apply = 2
```

**transmute_filler_effect.tres:**
```gdscript
effect_type = CUSTOM
custom_effect_id = "apothecary_potion"
target = BOARD_SELF
# Replaces all FILLER tiles with HEALTH tiles
```

### 8. Create Transmute Ultimate
Create `/resources/abilities/transmute.tres`:

```gdscript
ability_id = "transmute"
display_name = "Transmute"
description = "Poisons 10 random tiles on the enemy's board. When matched, they deal unavoidable poison damage."
requires_full_mana = true
drains_all_mana = true

effects = [transmute_effect.tres]
```

Create `/resources/effects/transmute_effect.tres`:
```gdscript
effect_type = CUSTOM
custom_effect_id = "transmute_poison_board"
target = BOARD_ENEMY
base_value = 10  # Number of tiles to poison
```

### 9. Add CharacterData Property
Modify CharacterData to support variety chain:

```gdscript
@export var uses_variety_chain: bool = false

func has_variety_chain() -> bool:
    return uses_variety_chain
```

## Acceptance Criteria
- [ ] Apothecary character resource created
- [ ] MAGIC, HEALTH, POISON_TILE, POTION_TILE types added
- [ ] All tile resources created
- [ ] Poison Vial applies poison on click
- [ ] Healing Elixir transmutes filler tiles on click
- [ ] Transmute ultimate defined
- [ ] uses_variety_chain flag works
- [ ] Resources load without errors
