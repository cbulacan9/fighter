# Task 054: Assassin Character Data

## Objective
Create the Assassin character resource with all tiles, mana configuration, and abilities defined.

## Dependencies
- Task 045 (Character Data Resource)
- Task 033 (Mana Config)

## Reference
- `/docs/CHARACTERS.md` → The Assassin

## Deliverables

### 1. Create Assassin Character Resource
Create `/resources/characters/assassin.tres`:

```gdscript
character_id = "assassin"
display_name = "The Assassin"
archetype = "Brawler"
description = "A high-mobility damage dealer who obscures the battlefield and evades attacks. Builds toward an explosive ultimate that chains sword attacks automatically."

basic_tiles = [
    physical_attack.tres,  # Uses existing sword
    stun.tres,             # Uses existing lightning
    mana.tres,             # NEW - fills mana bars
    filler.tres            # Uses existing filler
]
specialty_tiles = [
    smoke_bomb.tres,
    shadow_step.tres
]

spawn_weights = {
    SWORD: 25,
    LIGHTNING: 15,
    MANA: 20,
    FILLER: 20,
    SMOKE_BOMB: 10,
    SHADOW_STEP: 10
}

mana_config = dual_bar.tres
sequences = []  # No sequences for Assassin

ultimate_ability = predators_trance.tres

base_hp = 90  # Slightly lower HP for glass cannon
is_starter = false
unlock_opponent_id = "assassin"
```

### 2. Add New Tile Types
Modify `/scripts/data/tile_types.gd`:

```gdscript
enum Type {
    # Existing...
    MANA,        # Fills mana bars
    SMOKE_BOMB,  # Assassin specialty
    SHADOW_STEP, # Assassin specialty
}
```

### 3. Create Mana Tile Resource
Create `/resources/tiles/mana.tres`:

```gdscript
tile_type = MANA
display_name = "Mana Crystal"
is_matchable = true
is_clickable = false
match_effect = mana_gain_effect.tres
```

### 4. Create Smoke Bomb Tile Resource
Create `/resources/tiles/smoke_bomb.tres`:

```gdscript
tile_type = SMOKE_BOMB
display_name = "Smoke Bomb"
is_matchable = true
is_clickable = true
click_condition = MANA_FULL  # Bar 0 must be full
mana_bar_index = 0
match_effect = smoke_bomb_passive.tres  # Hides 1 enemy tile
click_effect = smoke_bomb_active.tres   # Hides row + column
```

### 5. Create Shadow Step Tile Resource
Create `/resources/tiles/shadow_step.tres`:

```gdscript
tile_type = SHADOW_STEP
display_name = "Shadow Step"
is_matchable = true
is_clickable = true
click_condition = MANA_FULL  # Bar 1 must be full
mana_bar_index = 1
match_effect = shadow_step_passive.tres  # Grants dodge chance
click_effect = shadow_step_active.tres   # Blocks enemy mana
```

### 6. Create Effect Resources
Create in `/resources/effects/`:

**mana_gain_effect.tres:**
- effect_type = MANA_ADD
- target = SELF
- values_by_match_size = {3: 15, 4: 25, 5: 40}

**smoke_bomb_passive.tres:**
- effect_type = CUSTOM
- custom_effect_id = "smoke_bomb_passive"
- base_value = 1 (tiles to hide)
- duration = 3.0

**smoke_bomb_active.tres:**
- effect_type = CUSTOM
- custom_effect_id = "smoke_bomb_active"
- duration = 3.0

**shadow_step_passive.tres:**
- effect_type = STATUS_APPLY
- target = SELF
- status_effect = dodge_status.tres
- values_by_match_size = {3: 20, 4: 40, 5: 75} (dodge %)

**shadow_step_active.tres:**
- effect_type = CUSTOM
- custom_effect_id = "shadow_step_active"
- target = ENEMY
- duration = 5.0 (mana block duration)

### 7. Create Dodge Status Effect
Create `/resources/effects/dodge_status.tres`:

```gdscript
effect_type = DODGE
duration = 10.0
stack_behavior = REPLACE
base_value = 0.2  # 20% base, overridden by match size
```

### 8. Create Predator's Trance Ultimate
Create `/resources/abilities/predators_trance.tres`:

```gdscript
ability_id = "predators_trance"
display_name = "Predator's Trance"
description = "All new tiles become swords. Matched swords auto-chain into more sword drops."
requires_full_mana = true
drains_all_mana = true
duration = 10.0

effects = [predators_trance_buff.tres]
```

## Acceptance Criteria
- [ ] Assassin character resource created
- [ ] Dual mana bar configuration works
- [ ] Smoke Bomb and Shadow Step tiles defined
- [ ] MANA, SMOKE_BOMB, SHADOW_STEP tile types added
- [ ] All effect resources created
- [ ] Predator's Trance ultimate defined
- [ ] Resources load without errors
