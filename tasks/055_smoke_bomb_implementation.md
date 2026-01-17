# Task 055: Smoke Bomb Implementation

## Objective
Implement the Assassin's Smoke Bomb tile with passive and active effects.

## Dependencies
- Task 054 (Assassin Character Data)
- Task 039 (Click Activation Flow)

## Reference
- `/docs/CHARACTERS.md` → Assassin Specialty Tiles

## Deliverables

### 1. Implement Smoke Bomb Passive Effect
When Smoke Bomb is matched, hide 1 random enemy tile for 3 seconds.

In EffectProcessor, the `smoke_bomb_passive` handler already exists. Verify it:
- Gets enemy board
- Calls `hide_random_tiles(1, 3.0)`
- Tiles become obscured (can't see what they are)

### 2. Implement Smoke Bomb Active Effect
When Smoke Bomb is clicked (with full mana bar 0), hide a random row AND column on enemy board.

In EffectProcessor, the `smoke_bomb_active` handler already exists. Verify it:
- Gets enemy board
- Calls `hide_random_row_and_column(3.0)`
- Drains mana bar 0

### 3. Hidden Tile Visual Enhancement
Modify BoardManager hidden tile handling:
- Hidden tiles show a "smoke cloud" visual instead of just darkening
- Enemy player can still interact with hidden tiles (drag/match) but can't see the type
- Match detection still works normally on hidden tiles

### 4. Smoke Cloud Sprite/Visual
Create smoke visual for hidden tiles:
- Could be a particle effect or animated sprite
- Fades in when tile is hidden
- Fades out when revealed

### 5. Mana Bar Integration
Ensure specialty tiles respect their mana_bar_index:
- Smoke Bomb click only enabled when mana bar 0 is full
- Shadow Step click only enabled when mana bar 1 is full
- ClickConditionChecker needs to check specific bar

Modify ClickConditionChecker:
```gdscript
func _check_mana_full(tile: Tile, fighter: Fighter) -> bool:
    if not _mana_system:
        return false

    var bar_index = tile.tile_data.mana_bar_index
    if bar_index >= 0:
        return _mana_system.is_bar_full(fighter, bar_index)
    else:
        return _mana_system.are_all_bars_full(fighter)
```

### 6. Mana Drain on Active Use
When active ability is used:
- Drain the specific mana bar (not all bars)
- Add method to ManaSystem: `drain_bar(fighter, bar_index)`

## Acceptance Criteria
- [ ] Matching Smoke Bomb hides 1 random enemy tile for 3 seconds
- [ ] Clicking Smoke Bomb (when mana bar 0 full) hides row + column
- [ ] Hidden tiles show smoke visual
- [ ] Hidden tiles still function normally (can be matched)
- [ ] Mana bar 0 drains on active use
- [ ] Click only available when specific mana bar is full
