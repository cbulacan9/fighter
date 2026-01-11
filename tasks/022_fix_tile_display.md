# Task 022: Fix Tile Display

## Objective
Fix tiles not rendering on the game board due to timing and texture issues.

## Priority
**Critical** - Game is unplayable without visible tiles.

## Dependencies
- Task 003 (Tile Entity) - modifying existing implementation

## Problem Analysis

### Issue 1: @onready Timing (Primary)
**Location:** `scripts/entities/tile.gd`

The `setup()` function is called immediately after tile instantiation in `TileSpawner.spawn_tile()`, but before the tile enters the scene tree. The `@onready` variables (`sprite`, `animation_player`) are `null` at this point, causing `_update_visual()` to silently fail.

**Call sequence:**
```
TileSpawner.spawn_tile()
  → tile_scene.instantiate()      # Tile created, NOT in tree
  → tile.setup(data, pos)         # Called here
    → _update_visual()            # sprite is null, does nothing
  → return tile
BoardManager._place_tile()
  → _tiles_container.add_child(tile)  # NOW enters tree, @onready set
                                       # But _update_visual() never re-called
```

### Issue 2: PlaceholderTexture2D (Secondary)
**Location:** `scenes/board/tile.tscn`

`PlaceholderTexture2D` is an editor placeholder that may not render visibly at runtime. Even if Issue 1 is fixed, the texture itself may not display correctly.

## Deliverables

### Fix 1: Add _ready() Visual Update
In `scripts/entities/tile.gd`, add a `_ready()` function:

```
func _ready() -> void:
    _update_visual()
```

This ensures visuals are applied after `@onready` variables are initialized.

### Fix 2: Replace PlaceholderTexture2D
In `scenes/board/tile.tscn`, replace the Sprite2D texture with a visible alternative.

**Option A: Create a simple white texture**
- Create a 64x64 white PNG in `assets/sprites/`
- Assign to Sprite2D texture
- Color modulation will tint it correctly

**Option B: Use ColorRect instead of Sprite2D**
- Replace Sprite2D with ColorRect child
- Update `tile.gd` to reference ColorRect
- Set color directly instead of modulate

**Recommended: Option A** - simpler change, preserves existing code structure.

### Fix 3: Update _update_visual() (Optional Enhancement)
Consider making `_update_visual()` more robust:

```
func _update_visual() -> void:
    if not is_inside_tree():
        return  # Will be called again in _ready()

    if sprite and tile_data:
        if tile_data.sprite:
            sprite.texture = tile_data.sprite
        else:
            sprite.modulate = tile_data.color
```

## Files to Modify

| File | Change |
|------|--------|
| `scripts/entities/tile.gd` | Add `_ready()` with `_update_visual()` call |
| `scenes/board/tile.tscn` | Replace PlaceholderTexture2D with real texture |
| `assets/sprites/tile_base.png` | Create 64x64 white square (new file) |

## Testing

1. Run the game
2. Verify both boards display 6x8 grids of colored tiles
3. Verify tile colors match their types:
   - Sword: Red
   - Shield: Blue
   - Potion: Green
   - Lightning: Yellow
   - Filler: Grey
4. Verify tiles respond to drag input
5. Verify match animations play correctly

## Acceptance Criteria
- [ ] Tiles visible on both player and enemy boards
- [ ] Tile colors correspond to tile types
- [ ] No console errors related to null references
- [ ] Existing functionality (drag, match, cascade) unaffected
