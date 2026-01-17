# Task 047: Basic Starter Character

## Objective
Complete the Basic/Squire starter character using MVP tile mechanics.

## Dependencies
- Task 045 (Character Data Resource)
- Task 046 (Character Loading & Selection)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Basic Starter Character

## Deliverables

### 1. Create Basic Character Resource
Create `/resources/characters/basic.tres`:

```gdscript
[gd_resource type="Resource" script_class="CharacterData"]

character_id = "basic"
display_name = "Squire"
archetype = "Balanced"
description = "A balanced fighter learning the ways of combat. No special abilities, but reliable and consistent. Master the basics here before facing greater challenges."

portrait = [load portrait texture]
portrait_small = [load small portrait]

basic_tiles = [
    ExtResource("sword.tres"),
    ExtResource("shield.tres"),
    ExtResource("potion.tres"),
    ExtResource("stun.tres"),
    ExtResource("filler.tres")
]
specialty_tiles = []

spawn_weights = {
    SWORD: 20,
    SHIELD: 20,
    POTION: 15,
    LIGHTNING: 10,
    FILLER: 35
}

mana_config = null
sequences = []
ultimate_ability = null

base_hp = 100
base_armor = 0

is_starter = true
unlock_opponent_id = ""
```

### 2. Create/Verify Basic Tile Resources
Ensure these exist in `/resources/tiles/`:

**sword.tres:**
```gdscript
tile_type = SWORD
display_name = "Sword"
is_matchable = true
is_clickable = false
match_effect = [damage effect: 10/25/50]
```

**shield.tres:**
```gdscript
tile_type = SHIELD
display_name = "Shield"
is_matchable = true
is_clickable = false
match_effect = [armor effect: 10/25/50]
```

**potion.tres:**
```gdscript
tile_type = POTION
display_name = "Health Potion"
is_matchable = true
is_clickable = false
match_effect = [heal effect: 10/25/50]
```

**stun.tres:**
```gdscript
tile_type = LIGHTNING
display_name = "Lightning"
is_matchable = true
is_clickable = false
match_effect = [stun effect: 1/2/3 seconds]
```

**filler.tres:**
```gdscript
tile_type = FILLER
display_name = "Crate"
is_matchable = true
is_clickable = false
match_effect = null  # No effect
```

### 3. Create Effect Resources for Basic Tiles
Create in `/resources/effects/`:

**damage_effect.tres:**
```gdscript
effect_type = DAMAGE
target = ENEMY
values_by_match_size = {3: 10, 4: 25, 5: 50}
```

**armor_effect.tres:**
```gdscript
effect_type = SHIELD
target = SELF
values_by_match_size = {3: 10, 4: 25, 5: 50}
```

**heal_effect.tres:**
```gdscript
effect_type = HEAL
target = SELF
values_by_match_size = {3: 10, 4: 25, 5: 50}
```

**stun_effect.tres:**
```gdscript
effect_type = STUN
target = ENEMY
# Duration in seconds
values_by_match_size = {3: 1, 4: 2, 5: 3}
```

### 4. Create Character Portrait Assets
Create placeholder portraits in `/assets/ui/portraits/`:
- basic_portrait.png (128x128)
- basic_portrait_small.png (64x64)

### 5. Verify Integration
Ensure the basic character:
- Loads correctly in CharacterRegistry
- Is selected as default when no character chosen
- Plays correctly with all MVP mechanics
- Works as both player and AI opponent

## Acceptance Criteria
- [ ] Basic character resource created
- [ ] All basic tile resources created
- [ ] All effect resources created
- [ ] Portraits exist (even if placeholder)
- [ ] Character loads without errors
- [ ] Game plays correctly with basic character
- [ ] AI can use basic character
