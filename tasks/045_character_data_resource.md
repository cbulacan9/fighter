# Task 045: Character Data Resource

## Objective
Create the CharacterData resource that defines a complete playable character.

## Dependencies
- Task 033 (Mana Config)
- Task 041 (Sequence Pattern Data)
- Task 037 (Tile Data Extension)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Character Data Architecture

## Deliverables

### 1. Create CharacterData Resource
Create `/scripts/data/character_data.gd`:

```gdscript
class_name CharacterData extends Resource

@export var character_id: String
@export var display_name: String
@export var archetype: String  # "Brawler", "Tank", etc.
@export_multiline var description: String = ""

# Visual
@export var portrait: Texture2D
@export var portrait_small: Texture2D

# Tiles
@export var basic_tiles: Array[TileData] = []
@export var specialty_tiles: Array[TileData] = []
@export var spawn_weights: Dictionary = {}  # {TileType: float}

# Systems
@export var mana_config: ManaConfig
@export var sequences: Array[SequencePattern] = []

# Abilities
@export var ultimate_ability: AbilityData
@export var passive_description: String = ""

# Stats
@export var base_hp: int = 100
@export var base_armor: int = 0

# Unlock
@export var is_starter: bool = false
@export var unlock_opponent_id: String = ""  # Beat this character to unlock

func get_all_tiles() -> Array[TileData]:
    var all: Array[TileData] = []
    all.append_array(basic_tiles)
    all.append_array(specialty_tiles)
    return all

func get_spawn_weight(tile_type: TileTypes.TileType) -> float:
    if spawn_weights.has(tile_type):
        return spawn_weights[tile_type]
    return 1.0

func has_mana_system() -> bool:
    return mana_config != null and mana_config.bar_count > 0

func has_sequences() -> bool:
    return sequences.size() > 0
```

### 2. Create AbilityData Resource
Create `/scripts/data/ability_data.gd`:

```gdscript
class_name AbilityData extends Resource

@export var ability_id: String
@export var display_name: String
@export_multiline var description: String = ""
@export var icon: Texture2D

# Activation
@export var requires_full_mana: bool = true
@export var drains_all_mana: bool = true
@export var cooldown: float = 0.0

# Effects
@export var effects: Array[EffectData] = []

# Duration (for channeled abilities)
@export var duration: float = 0.0

func get_effects() -> Array[EffectData]:
    return effects
```

### 3. Create Basic Starter Character
Create `/resources/characters/basic.tres`:

```gdscript
character_id = "basic"
display_name = "Squire"
archetype = "Balanced"
description = "A balanced fighter with no special abilities. Master the basics before advancing."

# Uses MVP tiles
basic_tiles = [sword, shield, potion, stun, filler]
specialty_tiles = []

# No mana
mana_config = null

# No sequences
sequences = []

# Simple ultimate (if any)
ultimate_ability = null

base_hp = 100
is_starter = true
```

### 4. Create Shared Basic Tiles
Ensure basic tiles exist in `/resources/tiles/`:
- sword.tres (SWORD type, damage effect)
- shield.tres (SHIELD type, armor effect)
- potion.tres (POTION type, heal effect)
- stun.tres (LIGHTNING type, stun effect)
- filler.tres (FILLER type, no effect)

## Acceptance Criteria
- [ ] CharacterData resource created
- [ ] AbilityData resource created
- [ ] Basic starter character resource created
- [ ] All helper methods work correctly
- [ ] Resources load without errors
