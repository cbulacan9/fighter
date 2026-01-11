# Task 027: Debug Combat Damage

## Objective
Diagnose why matching tiles doesn't deal damage to the opponent.

## Priority
**Critical** - Combat not functioning

## Problem Summary
- User can match tiles (tiles are cleared and replaced)
- But opponent health bar doesn't decrease
- No damage appears to be applied

## Signal Chain to Trace
The damage flow should be:
1. `BoardManager.commit_shift()` → finds matches → calls `_cascade_handler.process_matches()`
2. `CascadeHandler.process_matches()` → processes matches → emits `cascade_complete(result)`
3. `BoardManager._on_cascade_complete()` → emits `matches_resolved(result)`
4. `GameManager._on_player_matches_resolved()` → calls `combat_manager.process_cascade_result()`
5. `CombatManager.process_cascade_result()` → calls `apply_match_effect()` for each match
6. `CombatManager.apply_match_effect()` → for SWORD tiles, calls `target.take_damage()`
7. `Fighter.take_damage()` → reduces HP, emits `hp_changed`

## Diagnostic Steps

### Step 1: Add Debug Prints to BoardManager

In `scripts/managers/board_manager.gd`, add to `commit_shift()`:

```gdscript
func commit_shift() -> void:
    var cells_moved := _calculate_cells_moved()
    print("[BoardManager] commit_shift: cells_moved = ", cells_moved)

    # ... existing code ...

    var matches := _match_detector.find_matches(grid)
    print("[BoardManager] commit_shift: matches found = ", matches.size())
    if matches.size() > 0:
        for m in matches:
            print("[BoardManager] Match: ", m.tile_type, " count=", m.count)
        _cascade_handler.process_matches(matches)
    else:
        set_state(BoardState.IDLE)
```

Add to `_on_cascade_complete()`:

```gdscript
func _on_cascade_complete(result: CascadeHandler.CascadeResult) -> void:
    print("[BoardManager] _on_cascade_complete called")
    print("[BoardManager] all_matches count: ", result.all_matches.size())
    matches_resolved.emit(result)
    set_state(BoardState.IDLE)
```

### Step 2: Add Debug Prints to GameManager

In `scripts/managers/game_manager.gd`:

```gdscript
func _connect_signals() -> void:
    # ... existing code ...

    # Board signals
    if player_board:
        print("[GameManager] Connecting player_board.matches_resolved signal")
        player_board.matches_resolved.connect(_on_player_matches_resolved)
    else:
        print("[GameManager] WARNING: player_board is null in _connect_signals!")

func _on_player_matches_resolved(result: CascadeHandler.CascadeResult) -> void:
    print("[GameManager] _on_player_matches_resolved called!")
    print("[GameManager] all_matches count: ", result.all_matches.size())
    if combat_manager:
        print("[GameManager] Calling combat_manager.process_cascade_result")
        combat_manager.process_cascade_result(true, result)
    else:
        print("[GameManager] ERROR: combat_manager is null!")
    _stats_tracker.record_cascade_result(result)
```

### Step 3: Add Debug Prints to CombatManager

In `scripts/managers/combat_manager.gd`:

```gdscript
func process_cascade_result(source_is_player: bool, result: CascadeHandler.CascadeResult) -> void:
    print("[CombatManager] process_cascade_result called")
    print("[CombatManager] source_is_player: ", source_is_player)
    print("[CombatManager] all_matches count: ", result.all_matches.size())

    var source := get_fighter(source_is_player)
    print("[CombatManager] source fighter: ", source)

    for match_result in result.all_matches:
        print("[CombatManager] Processing match: type=", match_result.tile_type, " count=", match_result.count)
        apply_match_effect(source, match_result)

func apply_match_effect(source: Fighter, match_result: MatchDetector.MatchResult) -> void:
    var effect_value := _get_effect_value(match_result.tile_type, match_result.count)
    print("[CombatManager] apply_match_effect: type=", match_result.tile_type, " count=", match_result.count, " value=", effect_value)

    # ... existing code ...

    match match_result.tile_type:
        TileTypes.Type.SWORD:
            target = get_opponent(source)
            print("[CombatManager] SWORD: dealing ", effect_value, " damage to ", target)
            var result := target.take_damage(effect_value)
            print("[CombatManager] Damage result: hp_damage=", result.hp_damage, " armor_absorbed=", result.armor_absorbed)
            damage_dealt.emit(target, result)
```

### Step 4: Run and Check Output

Run the game and match some tiles. Look for:
1. Does `[BoardManager] commit_shift` show matches found?
2. Does `[BoardManager] _on_cascade_complete` get called?
3. Does `[GameManager] _on_player_matches_resolved` get called?
4. Does `[CombatManager] process_cascade_result` get called?
5. Does `apply_match_effect` show correct damage values?

## Likely Issues

1. **Signal not connected**: `player_board.matches_resolved` might not be connected to GameManager
2. **combat_manager is null**: CombatManager reference might not be set
3. **Fighters not initialized**: `player_fighter` or `enemy_fighter` might be null
4. **Effect value is 0**: Tile data might not have damage values

## Acceptance Criteria
- [ ] Debug output identifies the failure point
- [ ] Root cause documented
- [ ] Damage properly applies when matching SWORD tiles
