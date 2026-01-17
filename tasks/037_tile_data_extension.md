# Task 037: Tile Data Extension for Clickable Tiles

## Objective
Extend TileData to support click-to-activate tiles with conditions and effects.

## Dependencies
- Task 003 (Tile Entity)
- Task 002 (Data Resources)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Clickable Tiles section
- `/docs/CHARACTERS.md` → Specialty tiles

## Deliverables

### 1. Create Click Condition Enum
Add to `/scripts/data/tile_types.gd`:

```gdscript
enum ClickCondition {
    NONE,             # Not clickable
    ALWAYS,           # Can always click
    SEQUENCE_COMPLETE, # Requires completed sequence (Hunter's Pet)
    MANA_FULL,        # Requires full mana bar(s)
    COOLDOWN,         # Time-based cooldown
    CUSTOM,           # Custom condition check
}
```

### 2. Create EffectData Resource
Create `/scripts/data/effect_data.gd`:

```gdscript
class_name EffectData extends Resource

enum EffectTarget {
    SELF,
    ENEMY,
    BOTH,
    BOARD_SELF,
    BOARD_ENEMY,
}

enum EffectType {
    DAMAGE,
    HEAL,
    SHIELD,
    STUN,
    STATUS_APPLY,
    STATUS_REMOVE,
    MANA_ADD,
    MANA_DRAIN,
    TILE_TRANSFORM,
    TILE_HIDE,
    CUSTOM,
}

@export var effect_type: EffectType
@export var target: EffectTarget = EffectTarget.ENEMY
@export var base_value: int = 0
@export var values_by_match_size: Dictionary = {3: 10, 4: 25, 5: 50}
@export var status_effect: StatusEffectData  # For STATUS_APPLY
@export var status_types_to_remove: Array[int] = []  # For STATUS_REMOVE
@export var duration: float = 0.0  # For timed effects
@export var custom_effect_id: String = ""  # For CUSTOM type

func get_value_for_match(match_count: int) -> int:
    var capped = mini(match_count, 5)
    if values_by_match_size.has(capped):
        return values_by_match_size[capped]
    return base_value
```

### 3. Extend TileData Resource
Modify `/scripts/data/tile_data.gd`:

```gdscript
class_name TileData extends Resource

@export var tile_type: TileTypes.TileType
@export var display_name: String = ""
@export var sprite: Texture2D

# Match behavior
@export var is_matchable: bool = true
@export var match_effect: EffectData

# Click behavior
@export var is_clickable: bool = false
@export var click_condition: TileTypes.ClickCondition = TileTypes.ClickCondition.NONE
@export var click_effect: EffectData
@export var click_cooldown: float = 0.0  # For COOLDOWN condition

# Passive effect (triggered on match, separate from main effect)
@export var passive_effect: EffectData

# Visual
@export var clickable_highlight_color: Color = Color(1, 1, 0.5, 0.5)

# Spawn rules
@export var min_on_board: int = 0  # Minimum tiles of this type (Pet = 1)
@export var max_on_board: int = -1  # Maximum tiles (-1 = no limit, Pet = 2)

func can_be_matched() -> bool:
    return is_matchable

func can_be_clicked() -> bool:
    return is_clickable and click_condition != TileTypes.ClickCondition.NONE
```

### 4. Create Click Condition Checker
Create `/scripts/systems/click_condition_checker.gd`:

```gdscript
class_name ClickConditionChecker extends RefCounted

var _sequence_tracker  # Set externally, type: SequenceTracker
var _mana_system  # Set externally, type: ManaSystem
var _cooldown_timers: Dictionary = {}  # {Tile: float}

func set_sequence_tracker(tracker) -> void:
    _sequence_tracker = tracker

func set_mana_system(mana_system) -> void:
    _mana_system = mana_system

func can_click(tile, fighter: Fighter) -> bool:
    if not tile or not tile.tile_data:
        return false

    var data = tile.tile_data as TileData
    if not data.is_clickable:
        return false

    match data.click_condition:
        TileTypes.ClickCondition.NONE:
            return false

        TileTypes.ClickCondition.ALWAYS:
            return true

        TileTypes.ClickCondition.SEQUENCE_COMPLETE:
            if _sequence_tracker:
                return _sequence_tracker.has_completable_sequence()
            return false

        TileTypes.ClickCondition.MANA_FULL:
            if _mana_system and fighter:
                return _mana_system.are_all_bars_full(fighter)
            return false

        TileTypes.ClickCondition.COOLDOWN:
            return not _is_on_cooldown(tile)

        TileTypes.ClickCondition.CUSTOM:
            return _check_custom_condition(tile, fighter)

    return false

func start_cooldown(tile) -> void:
    if tile and tile.tile_data:
        var data = tile.tile_data as TileData
        if data.click_cooldown > 0:
            _cooldown_timers[tile] = data.click_cooldown

func tick(delta: float) -> void:
    var to_remove: Array = []
    for tile in _cooldown_timers.keys():
        _cooldown_timers[tile] -= delta
        if _cooldown_timers[tile] <= 0:
            to_remove.append(tile)

    for tile in to_remove:
        _cooldown_timers.erase(tile)

func _is_on_cooldown(tile) -> bool:
    return _cooldown_timers.has(tile) and _cooldown_timers[tile] > 0

func _check_custom_condition(tile, fighter: Fighter) -> bool:
    # Override in subclass or implement custom logic
    return true
```

### 5. Update Existing Tile Resources
Update `/resources/tiles/` to include new properties:

For all existing tiles (sword, shield, potion, etc.):
```
is_matchable = true
is_clickable = false
click_condition = NONE
```

### 6. Create Example Specialty Tile Resource
Create `/resources/tiles/pet.tres` (Hunter's Pet tile):

```
[gd_resource type="Resource" script_class="TileData"]

tile_type = [PET enum value]
display_name = "Pet"
is_matchable = false
is_clickable = true
click_condition = SEQUENCE_COMPLETE
min_on_board = 1
max_on_board = 2
```

## Acceptance Criteria
- [ ] ClickCondition enum created with all conditions
- [ ] EffectData resource created with all effect types
- [ ] TileData extended with click properties
- [ ] ClickConditionChecker implemented
- [ ] Cooldown timer working
- [ ] Existing tile resources updated
- [ ] Example specialty tile resource created
- [ ] All resources load without errors
