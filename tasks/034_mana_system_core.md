# Task 034: Mana System Core

## Objective
Implement the core ManaSystem that manages mana bars and integrates with match processing.

## Dependencies
- Task 033 (Mana Config & Data)
- Task 012 (Fighter State)
- Task 013 (Combat Manager)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Mana System section

## Deliverables

### 1. Create ManaSystem
Create `/scripts/systems/mana_system.gd`:

```gdscript
class_name ManaSystem extends RefCounted

signal mana_changed(fighter: Fighter, bar_index: int, current: int, max_value: int)
signal mana_full(fighter: Fighter, bar_index: int)
signal all_bars_full(fighter: Fighter)
signal mana_drained(fighter: Fighter, bar_index: int, amount: int)
signal mana_blocked(fighter: Fighter, bar_index: int, duration: float)

# Mana bars per fighter: {Fighter: Array[ManaBar]}
var _mana_bars: Dictionary = {}
# Config per fighter: {Fighter: ManaConfig}
var _configs: Dictionary = {}

func setup_fighter(fighter: Fighter, config: ManaConfig) -> void:
    if config == null or config.bar_count == 0:
        return

    _configs[fighter] = config
    _mana_bars[fighter] = []

    for i in range(config.bar_count):
        var bar = ManaBar.new(config.get_max_mana(i))
        bar.mana_changed.connect(_on_bar_mana_changed.bind(fighter, i))
        bar.mana_full.connect(_on_bar_full.bind(fighter, i))
        _mana_bars[fighter].append(bar)

func remove_fighter(fighter: Fighter) -> void:
    _mana_bars.erase(fighter)
    _configs.erase(fighter)

func add_mana(fighter: Fighter, amount: int, bar_index: int = 0) -> int:
    if not _mana_bars.has(fighter):
        return 0

    var bars = _mana_bars[fighter] as Array
    if bar_index >= bars.size():
        return 0

    return bars[bar_index].add(amount)

func add_mana_from_match(fighter: Fighter, match_count: int, bar_index: int = 0) -> int:
    if not _configs.has(fighter):
        return 0

    var config = _configs[fighter] as ManaConfig
    var amount = config.get_mana_for_match(match_count)
    return add_mana(fighter, amount, bar_index)

func add_mana_all_bars(fighter: Fighter, amount: int) -> void:
    if not _mana_bars.has(fighter):
        return

    for bar in _mana_bars[fighter]:
        bar.add(amount)

func drain(fighter: Fighter, amount: int, bar_index: int = 0) -> int:
    if not _mana_bars.has(fighter):
        return 0

    var bars = _mana_bars[fighter] as Array
    if bar_index >= bars.size():
        return 0

    var drained = bars[bar_index].drain(amount)
    if drained > 0:
        mana_drained.emit(fighter, bar_index, drained)
    return drained

func drain_all(fighter: Fighter) -> int:
    if not _mana_bars.has(fighter):
        return 0

    var total_drained = 0
    var bars = _mana_bars[fighter] as Array
    for i in range(bars.size()):
        var drained = bars[i].drain_all()
        if drained > 0:
            mana_drained.emit(fighter, i, drained)
        total_drained += drained

    return total_drained

func block_mana(fighter: Fighter, duration: float, bar_index: int = -1) -> void:
    if not _mana_bars.has(fighter):
        return

    var bars = _mana_bars[fighter] as Array
    if bar_index >= 0 and bar_index < bars.size():
        # Block specific bar
        bars[bar_index].block(duration)
        mana_blocked.emit(fighter, bar_index, duration)
    else:
        # Block all bars
        for i in range(bars.size()):
            bars[i].block(duration)
            mana_blocked.emit(fighter, i, duration)

func is_full(fighter: Fighter, bar_index: int = 0) -> bool:
    if not _mana_bars.has(fighter):
        return false

    var bars = _mana_bars[fighter] as Array
    if bar_index >= bars.size():
        return false

    return bars[bar_index].is_full()

func are_all_bars_full(fighter: Fighter) -> bool:
    if not _mana_bars.has(fighter):
        return false

    var bars = _mana_bars[fighter] as Array
    for bar in bars:
        if not bar.is_full():
            return false
    return true

func can_use_ultimate(fighter: Fighter) -> bool:
    if not _configs.has(fighter):
        return false

    var config = _configs[fighter] as ManaConfig
    if config.require_all_bars_full:
        return are_all_bars_full(fighter)
    else:
        return is_full(fighter, 0)

func get_mana(fighter: Fighter, bar_index: int = 0) -> int:
    if not _mana_bars.has(fighter):
        return 0

    var bars = _mana_bars[fighter] as Array
    if bar_index >= bars.size():
        return 0

    return bars[bar_index].current

func get_max_mana(fighter: Fighter, bar_index: int = 0) -> int:
    if not _mana_bars.has(fighter):
        return 0

    var bars = _mana_bars[fighter] as Array
    if bar_index >= bars.size():
        return 0

    return bars[bar_index].max_value

func get_percentage(fighter: Fighter, bar_index: int = 0) -> float:
    if not _mana_bars.has(fighter):
        return 0.0

    var bars = _mana_bars[fighter] as Array
    if bar_index >= bars.size():
        return 0.0

    return bars[bar_index].get_percentage()

func get_bar_count(fighter: Fighter) -> int:
    if not _mana_bars.has(fighter):
        return 0
    return _mana_bars[fighter].size()

func tick(delta: float) -> void:
    for fighter in _mana_bars.keys():
        var bars = _mana_bars[fighter] as Array
        var config = _configs.get(fighter) as ManaConfig

        for bar in bars:
            bar.tick(delta)

            # Apply decay if configured
            if config and config.decay_rate > 0:
                var decay = int(config.decay_rate * delta)
                if decay > 0:
                    bar.drain(decay)

func reset_fighter(fighter: Fighter) -> void:
    if not _mana_bars.has(fighter):
        return

    for bar in _mana_bars[fighter]:
        bar.reset()

func reset_all() -> void:
    for fighter in _mana_bars.keys():
        reset_fighter(fighter)

# Signal handlers
func _on_bar_mana_changed(current: int, max_value: int, fighter: Fighter, bar_index: int) -> void:
    mana_changed.emit(fighter, bar_index, current, max_value)

func _on_bar_full(fighter: Fighter, bar_index: int) -> void:
    mana_full.emit(fighter, bar_index)
    if are_all_bars_full(fighter):
        all_bars_full.emit(fighter)
```

### 2. Integrate with CombatManager
Modify `/scripts/managers/combat_manager.gd`:

```gdscript
# Add to CombatManager

var mana_system: ManaSystem

signal mana_changed(fighter: Fighter, bar_index: int, current: int, max_value: int)
signal ultimate_ready(fighter: Fighter)

func _ready() -> void:
    # ... existing code ...
    _setup_mana_system()

func _setup_mana_system() -> void:
    mana_system = ManaSystem.new()
    mana_system.mana_changed.connect(_on_mana_changed)
    mana_system.all_bars_full.connect(_on_all_bars_full)

func initialize(player_data: FighterData, enemy_data: FighterData) -> void:
    # ... existing initialization ...

    # Setup mana for fighters (if they have mana config)
    if player_data and player_data.mana_config:
        mana_system.setup_fighter(player_fighter, player_data.mana_config)
    if enemy_data and enemy_data.mana_config:
        mana_system.setup_fighter(enemy_fighter, enemy_data.mana_config)

func process_cascade_result(is_player: bool, result: CascadeHandler.CascadeResult) -> void:
    var fighter = player_fighter if is_player else enemy_fighter

    # ... existing match processing ...

    # Process mana gain from matches
    _process_mana_from_matches(fighter, result)

func _process_mana_from_matches(fighter: Fighter, result: CascadeHandler.CascadeResult) -> void:
    if not mana_system:
        return

    # Check if fighter is mana blocked
    if fighter.is_mana_blocked():
        return

    for match_result in result.all_matches:
        var match_count = match_result.positions.size()
        # TODO: Check if tile type generates mana for this character
        # For now, all matches generate mana
        mana_system.add_mana_from_match(fighter, match_count)

func tick(delta: float) -> void:
    # ... existing tick code ...

    if mana_system:
        mana_system.tick(delta)

func reset() -> void:
    # ... existing reset code ...

    if mana_system:
        mana_system.reset_all()

func _on_mana_changed(fighter: Fighter, bar_index: int, current: int, max_value: int) -> void:
    mana_changed.emit(fighter, bar_index, current, max_value)

func _on_all_bars_full(fighter: Fighter) -> void:
    ultimate_ready.emit(fighter)
```

### 3. Extend FighterData
Modify `/scripts/data/fighter_data.gd`:

```gdscript
# Add to FighterData

@export var mana_config: ManaConfig
```

### 4. Extend Fighter
Modify `/scripts/entities/fighter.gd`:

```gdscript
# Add to Fighter

signal mana_changed(bar_index: int, current: int, max_value: int)
signal ultimate_ready()

var mana_system: ManaSystem  # Set by CombatManager

func is_mana_blocked() -> bool:
    # Check status effect
    if has_status(StatusTypes.StatusType.MANA_BLOCK):
        return true
    return false

func get_mana(bar_index: int = 0) -> int:
    if mana_system:
        return mana_system.get_mana(self, bar_index)
    return 0

func can_use_ultimate() -> bool:
    if mana_system:
        return mana_system.can_use_ultimate(self)
    return false
```

## Acceptance Criteria
- [ ] ManaSystem class created with all methods
- [ ] Multi-bar support working (1-2 bars)
- [ ] Mana gained from matches
- [ ] Mana blocking respects timer
- [ ] Ultimate readiness detection working
- [ ] Integration with CombatManager complete
- [ ] All signals emit correctly
- [ ] Reset clears all mana state
