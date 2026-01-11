# Task 023: Debug Board Initialization

## Objective
Diagnose why boards are not being initialized and tiles are not being created.

## Priority
**Critical** - Blocking gameplay

## Problem Summary
- Remote scene tree shows `Tiles` container is empty
- `fighter_data` on PlayerBoard is `<null>` at runtime
- TileSpawner is correctly configured (has tile_scene, 5 resources, total_weight=100)
- No errors in console

## Root Cause Analysis
The `fighter_data` being null indicates `BoardManager.initialize()` is either:
1. Not being called (GameManager can't find board references)
2. Being called with null data (fighter resources not loading)

## Diagnostic Steps

### Step 1: Add Debug Prints to GameManager

In `scripts/managers/game_manager.gd`, add print statements:

**In `_load_fighter_data()`:**
```gdscript
func _load_fighter_data() -> void:
    _player_data = load(player_data_path)
    _enemy_data = load(enemy_data_path)
    print("[GameManager] Loaded player_data: ", _player_data)
    print("[GameManager] Loaded enemy_data: ", _enemy_data)
```

**In `_find_node_references()`:**
```gdscript
func _find_node_references() -> void:
    var parent := get_parent()
    print("[GameManager] Parent node: ", parent)
    if not parent:
        print("[GameManager] ERROR: No parent found!")
        return

    combat_manager = parent.get_node_or_null("CombatManager")
    print("[GameManager] CombatManager: ", combat_manager)

    var boards := parent.get_node_or_null("Boards")
    print("[GameManager] Boards node: ", boards)
    if boards:
        player_board = boards.get_node_or_null("PlayerBoard")
        enemy_board = boards.get_node_or_null("EnemyBoard")
        print("[GameManager] player_board: ", player_board)
        print("[GameManager] enemy_board: ", enemy_board)
    # ... rest of function
```

**In `_setup_match()`:**
```gdscript
func _setup_match() -> void:
    print("[GameManager] _setup_match called")
    print("[GameManager] player_board is: ", player_board)
    print("[GameManager] enemy_board is: ", enemy_board)
    print("[GameManager] _player_data is: ", _player_data)
    print("[GameManager] _enemy_data is: ", _enemy_data)

    # ... existing code ...

    if player_board:
        print("[GameManager] Calling player_board.initialize()")
        player_board.initialize(_player_data, true)
    else:
        print("[GameManager] ERROR: player_board is null!")
```

### Step 2: Add Debug Prints to BoardManager

In `scripts/managers/board_manager.gd`:

**In `initialize()`:**
```gdscript
func initialize(fighter: FighterData, is_player: bool) -> void:
    print("[BoardManager] initialize() called")
    print("[BoardManager] fighter param: ", fighter)
    print("[BoardManager] is_player: ", is_player)

    fighter_data = fighter
    # ... rest of function ...

    print("[BoardManager] Calling generate_initial_board()")
    generate_initial_board()
```

**In `generate_initial_board()`:**
```gdscript
func generate_initial_board() -> void:
    print("[BoardManager] generate_initial_board() called")
    print("[BoardManager] _tile_spawner: ", _tile_spawner)
    print("[BoardManager] _tiles_container: ", _tiles_container)

    _clear_all_tiles()

    for row in range(Grid.ROWS):
        for col in range(Grid.COLS):
            var tile := _tile_spawner.spawn_tile()
            print("[BoardManager] Spawned tile: ", tile, " at ", row, ",", col)
            tile.grid_position = Vector2i(row, col)
            _place_tile(tile, row, col)

    print("[BoardManager] Finished creating ", Grid.ROWS * Grid.COLS, " tiles")
    _remove_initial_matches()
```

### Step 3: Run and Check Output

Run the game and check the Output panel for the print statements. Look for:
1. Are fighter resources loading? (Should see non-null values)
2. Is Boards node found? (Should see the node reference)
3. Are player_board and enemy_board found?
4. Is initialize() being called?
5. Is generate_initial_board() being called?
6. Are tiles being spawned?

## Expected Output (if working correctly)
```
[GameManager] Loaded player_data: <FighterData#...>
[GameManager] Loaded enemy_data: <FighterData#...>
[GameManager] Parent node: Main:<Node#...>
[GameManager] Boards node: Boards:<Node2D#...>
[GameManager] player_board: PlayerBoard:<Node2D#...>
[GameManager] enemy_board: EnemyBoard:<Node2D#...>
[GameManager] _setup_match called
[GameManager] Calling player_board.initialize()
[BoardManager] initialize() called
[BoardManager] Calling generate_initial_board()
[BoardManager] Spawned tile: <Tile#...> at 0,0
... (48 tiles total)
```

## Likely Issues to Find

1. **If parent is null**: GameManager might not be in the scene tree properly
2. **If Boards is null**: Node name mismatch or scene structure issue
3. **If player_board is null**: Node name mismatch ("PlayerBoard" vs actual name)
4. **If _player_data is null**: Resource path incorrect or file missing
5. **If _tile_spawner is null**: BoardManager._ready() didn't run or node missing

## After Diagnosis
Once the specific failure point is identified, create a targeted fix.

## Acceptance Criteria
- [ ] Debug output identifies the failure point
- [ ] Root cause documented
- [ ] Fix implemented and tiles display correctly
