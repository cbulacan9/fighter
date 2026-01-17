# Task 033: Mana Config & Data

## Objective
Create the data structures for the mana system configuration.

## Dependencies
- Task 002 (Data Resources)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Mana System section
- `/docs/CHARACTERS.md` → Assassin (dual mana bars)

## Deliverables

### 1. Create ManaConfig Resource
Create `/scripts/data/mana_config.gd`:

```gdscript
class_name ManaConfig extends Resource

## Number of mana bars (1 for most characters, 2 for Assassin)
@export var bar_count: int = 1

## Maximum mana per bar
@export var max_mana: Array[int] = [100]

## Mana gained per match size {match_count: mana_amount}
@export var mana_per_match: Dictionary = {
    3: 10,
    4: 20,
    5: 35
}

## Which tile types generate mana (for characters with Mana tiles)
## Empty array means no tiles generate mana directly
@export var mana_tile_types: Array[int] = []  # TileType enum values

## Mana decay rate per second (0 = no decay)
@export var decay_rate: float = 0.0

## Whether all bars must be full for ultimate
@export var require_all_bars_full: bool = true

func get_max_mana(bar_index: int) -> int:
    if bar_index < max_mana.size():
        return max_mana[bar_index]
    return 100  # Default

func get_mana_for_match(match_count: int) -> int:
    # Cap at 5-match value
    var capped_count = mini(match_count, 5)
    if mana_per_match.has(capped_count):
        return mana_per_match[capped_count]
    return 0

func validate() -> bool:
    # Ensure max_mana array matches bar_count
    if max_mana.size() != bar_count:
        push_warning("ManaConfig: max_mana array size doesn't match bar_count")
        return false
    return true
```

### 2. Create ManaBar Runtime Class
Create `/scripts/systems/mana_bar.gd`:

```gdscript
class_name ManaBar extends RefCounted

signal mana_changed(current: int, max_value: int)
signal mana_full()
signal mana_empty()

var current: int = 0
var max_value: int = 100
var is_blocked: bool = false
var _block_timer: float = 0.0

func _init(max_mana: int = 100) -> void:
    max_value = max_mana
    current = 0

func add(amount: int) -> int:
    if is_blocked:
        return 0

    var previous = current
    current = mini(current + amount, max_value)
    var actual_gain = current - previous

    if actual_gain > 0:
        mana_changed.emit(current, max_value)
        if current >= max_value:
            mana_full.emit()

    return actual_gain

func drain(amount: int) -> int:
    var previous = current
    current = maxi(current - amount, 0)
    var actual_drain = previous - current

    if actual_drain > 0:
        mana_changed.emit(current, max_value)
        if current <= 0:
            mana_empty.emit()

    return actual_drain

func drain_all() -> int:
    var drained = current
    current = 0
    mana_changed.emit(current, max_value)
    mana_empty.emit()
    return drained

func is_full() -> bool:
    return current >= max_value

func is_empty() -> bool:
    return current <= 0

func get_percentage() -> float:
    if max_value <= 0:
        return 0.0
    return float(current) / float(max_value)

func block(duration: float) -> void:
    is_blocked = true
    _block_timer = duration

func tick(delta: float) -> void:
    if is_blocked and _block_timer > 0:
        _block_timer -= delta
        if _block_timer <= 0:
            is_blocked = false
            _block_timer = 0.0

func reset() -> void:
    current = 0
    is_blocked = false
    _block_timer = 0.0
    mana_changed.emit(current, max_value)
```

### 3. Create Default Mana Configs
Create resource files in `/resources/mana/`:

**single_bar.tres** (default for most characters):
```
[gd_resource type="Resource" script_class="ManaConfig"]
bar_count = 1
max_mana = [100]
mana_per_match = {3: 10, 4: 20, 5: 35}
mana_tile_types = []
decay_rate = 0.0
require_all_bars_full = true
```

**dual_bar.tres** (for Assassin):
```
[gd_resource type="Resource" script_class="ManaConfig"]
bar_count = 2
max_mana = [100, 100]
mana_per_match = {3: 10, 4: 20, 5: 35}
mana_tile_types = []
decay_rate = 0.0
require_all_bars_full = true
```

**no_mana.tres** (for Basic starter character):
```
[gd_resource type="Resource" script_class="ManaConfig"]
bar_count = 0
max_mana = []
mana_per_match = {}
mana_tile_types = []
decay_rate = 0.0
require_all_bars_full = false
```

### 4. Create Mana Tile Type
If not already present, add MANA to TileTypes enum:

```gdscript
# In tile_types.gd
enum TileType {
    SWORD,
    SHIELD,
    POTION,
    LIGHTNING,
    FILLER,
    MANA,  # NEW - generates mana on match
    # ... character-specific tiles added later
}
```

## Acceptance Criteria
- [ ] ManaConfig resource script created
- [ ] ManaBar runtime class created with all methods
- [ ] Signal emissions work correctly
- [ ] Default config resources created (single, dual, none)
- [ ] ManaBar blocking works with timer
- [ ] Resources load without errors
