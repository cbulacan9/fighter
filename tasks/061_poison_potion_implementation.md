# Task 061: Poison & Potion Tile Implementation

## Objective
Implement the Apothecary's clickable specialty tiles: Poison Vial and Healing Elixir.

## Dependencies
- Task 060 (Apothecary Character Data)
- Task 039 (Click Activation Flow)

## Reference
- `/docs/CHARACTERS.md` → Apothecary Specialty Tiles

## Deliverables

### 1. Implement Poison Vial Click Effect
When Poison Vial is clicked, apply poison stacks to enemy.

In EffectProcessor, verify STATUS_APPLY handles stacks:
```gdscript
func _apply_status(target: Fighter, source: Fighter, status_data: StatusEffectData, stacks: int = 1) -> void:
    if target and _status_manager and status_data:
        _status_manager.apply(target, status_data, source, stacks)
```

The apply_poison_effect.tres should specify stacks_to_apply = 2.

### 2. Implement Potion Click Effect (Transmute Filler)
When Healing Elixir is clicked, replace all FILLER tiles on own board with HEALTH tiles.

Add custom effect handler in EffectProcessor:
```gdscript
func _apothecary_potion(source: Fighter) -> void:
    var own_board = _get_own_board(source)
    if not own_board:
        return

    var filler_positions = own_board.get_tiles_of_type(TileTypes.Type.FILLER)
    for tile in filler_positions:
        var pos = own_board.get_tile_position(tile)
        own_board.replace_tile_at(pos, TileTypes.Type.HEALTH)
```

Add to BoardManager:
```gdscript
func get_tile_position(tile: Tile) -> Vector2i:
    for row in range(_grid.ROWS):
        for col in range(_grid.COLS):
            if _grid.get_tile(row, col) == tile:
                return Vector2i(row, col)
    return Vector2i(-1, -1)
```

### 3. Tile Replacement Visual Effect
When tiles are replaced:
- Fade out old tile
- Spawn effect (sparkle/transmutation)
- Fade in new tile

```gdscript
func replace_tile_at(pos: Vector2i, new_type: TileTypes.Type, animated: bool = true) -> bool:
    var old_tile = _grid.get_tile(pos.x, pos.y)
    if not old_tile:
        return false

    if animated:
        # Play transmute animation
        old_tile.play_transmute_out()
        await old_tile.transmute_finished

    old_tile.queue_free()

    var new_tile = _tile_spawner.create_tile_of_type(new_type)
    _grid.set_tile(pos.x, pos.y, new_tile)
    _position_tile(new_tile, pos)

    if animated:
        new_tile.play_transmute_in()

    return true
```

### 4. Poison Status Enhancement
Ensure poison status works with variety chain multiplier:
- Poison damage can be multiplied if applied during a variety chain
- Track base damage vs multiplied damage

### 5. Click Availability
Both tiles should be clickable whenever they exist on board:
- click_condition = ALWAYS
- No mana requirement for these abilities
- Just click to activate

### 6. Visual Distinction
Poison Vial and Healing Elixir need distinct visuals:
- Poison: Green/purple, skull or toxic symbol
- Potion: Red/pink, heart or plus symbol
- Both should have "clickable" glow when available

### 7. Sound Effects (Placeholder)
Add sound effect hooks:
- Poison applied: bubbling/hissing sound
- Potion used: magical chime/transformation sound

## Acceptance Criteria
- [ ] Clicking Poison Vial applies 2 poison stacks to enemy
- [ ] Clicking Healing Elixir replaces all FILLER tiles with HEALTH tiles
- [ ] Tile replacement has visual animation
- [ ] Both tiles are always clickable (no conditions)
- [ ] Poison works with variety chain multiplier
- [ ] Tiles have distinct visual appearance
- [ ] Tiles consumed/removed after use (or remain for re-match)
