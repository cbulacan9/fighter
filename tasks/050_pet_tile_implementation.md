# Task 050: Pet Tile Implementation

## Objective
Implement the Pet tile's unique behaviors: non-matchable, click-to-activate, minimum/maximum spawn rules.

## Dependencies
- Task 049 (Hunter Character Data)
- Task 038 (Click Input Handler)
- Task 042 (Sequence Tracker)

## Reference
- `/docs/CHARACTERS.md` → Hunter Pet tile
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Pet Tile clarifications

## Deliverables

### 1. Extend Match Detector for Non-Matchable Tiles
Modify `/scripts/systems/match_detector.gd`:

```gdscript
func _scan_row(row: int) -> Array[MatchResult]:
    var matches: Array[MatchResult] = []
    var col = 0

    while col < _grid.COLS:
        var tile = _grid.get_tile(row, col)

        # Skip non-matchable tiles
        if not tile or not tile.tile_data or not tile.tile_data.is_matchable:
            col += 1
            continue

        var tile_type = tile.tile_data.tile_type
        var run_length = 1
        var positions: Array[Vector2i] = [Vector2i(row, col)]

        # Count consecutive matching tiles
        for check_col in range(col + 1, _grid.COLS):
            var check_tile = _grid.get_tile(row, check_col)

            # Non-matchable tile breaks the run
            if not check_tile or not check_tile.tile_data or not check_tile.tile_data.is_matchable:
                break

            if check_tile.tile_data.tile_type == tile_type:
                run_length += 1
                positions.append(Vector2i(row, check_col))
            else:
                break

        if run_length >= 3:
            var result = MatchResult.new()
            result.tile_type = tile_type
            result.positions = positions
            result.count = run_length
            matches.append(result)

        col += run_length

    return matches
```

### 2. Implement Pet Spawn Rules in TileSpawner
Modify `/scripts/systems/tile_spawner.gd`:

```gdscript
var _min_counts: Dictionary = {}  # {TileType: int}
var _max_counts: Dictionary = {}  # {TileType: int}
var _grid: Grid  # Reference for counting

func set_spawn_rules(tile_data: TileData) -> void:
    if tile_data.min_on_board > 0:
        _min_counts[tile_data.tile_type] = tile_data.min_on_board
    if tile_data.max_on_board > 0:
        _max_counts[tile_data.tile_type] = tile_data.max_on_board

func spawn_tile() -> Tile:
    var tile_type = _select_tile_type()
    return _create_tile(tile_type)

func _select_tile_type() -> TileTypes.TileType:
    # First, check if any tile type is below minimum
    for tile_type in _min_counts.keys():
        var current = _count_on_board(tile_type)
        if current < _min_counts[tile_type]:
            return tile_type

    # Normal weighted selection, respecting maximums
    var available_types: Array = []
    var total_weight: float = 0.0

    for tile_type in _weights.keys():
        # Skip if at maximum
        if _max_counts.has(tile_type):
            if _count_on_board(tile_type) >= _max_counts[tile_type]:
                continue

        available_types.append(tile_type)
        total_weight += _weights[tile_type]

    if available_types.is_empty():
        return _get_fallback_type()

    var roll = randf() * total_weight
    var cumulative: float = 0.0

    for tile_type in available_types:
        cumulative += _weights[tile_type]
        if roll <= cumulative:
            return tile_type

    return available_types[0]

func _count_on_board(tile_type: TileTypes.TileType) -> int:
    if not _grid:
        return 0

    var count = 0
    for row in range(_grid.ROWS):
        for col in range(_grid.COLS):
            var tile = _grid.get_tile(row, col)
            if tile and tile.tile_data and tile.tile_data.tile_type == tile_type:
                count += 1
    return count

func ensure_minimums() -> void:
    # Called after cascade to ensure minimum tile counts
    for tile_type in _min_counts.keys():
        var current = _count_on_board(tile_type)
        var needed = _min_counts[tile_type] - current

        if needed > 0:
            # Spawn needed tiles in empty positions
            _spawn_minimum_tiles(tile_type, needed)

func _spawn_minimum_tiles(tile_type: TileTypes.TileType, count: int) -> void:
    var empty_positions = _grid.get_empty_positions()
    empty_positions.shuffle()

    for i in range(mini(count, empty_positions.size())):
        var pos = empty_positions[i]
        var tile = _create_tile(tile_type)
        _grid.set_tile(pos.x, pos.y, tile)
```

### 3. Pet Click Activation
Extend click handling for Pet tile:

```gdscript
# In BoardManager

func _on_tile_clicked(tile: Tile) -> void:
    if not tile or not tile.tile_data:
        return

    # Check if Pet tile
    if tile.tile_data.tile_type == TileTypes.TileType.PET:
        _handle_pet_click(tile)
        return

    # ... other click handling ...

func _handle_pet_click(tile: Tile) -> void:
    if not sequence_tracker or not sequence_tracker.has_completable_sequence():
        return

    # Get banked sequences
    var banked = sequence_tracker.get_banked_sequences()
    if banked.is_empty():
        return

    # If multiple sequences banked, could show selection UI
    # For now, activate first/most recent
    var pattern = banked[0]
    var stacks = sequence_tracker.get_banked_stacks(pattern)

    # Check for Alpha Command multiplier
    var multiplier = _get_alpha_command_multiplier()

    # Activate sequence
    sequence_tracker.activate_sequence(pattern)

    # Process effects with multiplier
    _process_pet_ability(pattern, stacks, multiplier)

func _get_alpha_command_multiplier() -> float:
    var fighter = _get_owner_fighter()
    if fighter and fighter.has_status(StatusTypes.StatusType.ALPHA_COMMAND):
        return 2.0
    return 1.0

func _process_pet_ability(pattern: SequencePattern, stacks: int, multiplier: float) -> void:
    var fighter = _get_owner_fighter()
    var combat_manager = _get_combat_manager()

    if not combat_manager:
        return

    # Apply offensive effect
    if pattern.on_complete_effect:
        var effect = pattern.on_complete_effect.duplicate()
        effect.base_value = int(effect.base_value * multiplier)
        combat_manager.effect_processor.process_effect(effect, fighter)

    # Apply self-buff
    if pattern.self_buff_effect:
        var buff = pattern.self_buff_effect.duplicate()
        buff.base_value = buff.base_value * multiplier
        combat_manager.effect_processor.process_effect(buff, fighter)
```

### 4. Pet Tile Visual Feedback
Add visual states for Pet tile:

```gdscript
# In Tile

func _process(_delta: float) -> void:
    if tile_data and tile_data.tile_type == TileTypes.TileType.PET:
        _update_pet_visual()

func _update_pet_visual() -> void:
    # Check if any sequence is completable
    var board = get_parent().get_parent() as BoardManager
    if board and board.sequence_tracker:
        var can_activate = board.sequence_tracker.has_completable_sequence()
        update_clickable_state(can_activate)
```

## Acceptance Criteria
- [ ] Pet tiles cannot be matched
- [ ] Match detection skips Pet tiles correctly
- [ ] Minimum 1 Pet tile always on board
- [ ] Maximum 2 Pet tiles enforced
- [ ] Pet spawns when count drops below minimum
- [ ] Pet click activates banked sequence
- [ ] Alpha Command multiplier applied
- [ ] Visual feedback shows when Pet is activatable
