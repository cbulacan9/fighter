# Task 010: Tile Spawner

## Objective
Implement weighted random tile generation.

## Dependencies
- Task 003 (Tile Entity)

## Reference
- `/docs/SYSTEMS.md` → Tile Spawner

## Deliverables

### 1. Tile Spawner Script
Create `/scripts/systems/tile_spawner.gd`:

**Exports:**
| Export | Type | Description |
|--------|------|-------------|
| `tile_scene` | PackedScene | Reference to tile.tscn |
| `tile_resources` | Array[TileData] | All 5 tile type resources |

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `weights` | Dictionary | {TileType: float} current weights |
| `_cumulative_weights` | Array | For weighted random selection |

### 2. Core Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `set_weights(new_weights: Dictionary)` | void | Update spawn weights |
| `spawn_tile() -> Tile` | Tile | Create one random tile |
| `spawn_tiles(count: int) -> Array[Tile]` | Array | Create multiple tiles |
| `get_tile_data(type: TileType) -> TileData` | TileData | Lookup resource |

### 3. Weighted Random Algorithm

**Setup cumulative weights:**
```
weights = {SWORD: 20, SHIELD: 20, POTION: 15, LIGHTNING: 10, FILLER: 35}
total = 100
cumulative = [20, 40, 55, 65, 100]  # Running sum
```

**Selection:**
```
roll = randf() * total  # 0-100
for i in range(types.size()):
    if roll < cumulative[i]:
        return types[i]
```

### 4. Tile Instantiation
`spawn_tile()` process:
1. Select random type using weights
2. Get TileData resource for that type
3. Instantiate tile scene
4. Call `tile.setup(tile_data, Vector2i(-1, -1))` (position set later)
5. Return tile instance

### 5. Weight Configuration
Default balanced weights:
| Type | Weight | Probability |
|------|--------|-------------|
| SWORD | 20 | 20% |
| SHIELD | 20 | 20% |
| POTION | 15 | 15% |
| LIGHTNING | 10 | 10% |
| FILLER | 35 | 35% |

Weights loaded from FighterData for character-specific tuning.

### 6. Integration
- BoardManager uses spawner for initial board generation
- CascadeHandler uses spawner to fill empty spaces
- Each board has own spawner with fighter's weights

## Acceptance Criteria
- [ ] `spawn_tile()` returns valid Tile instance
- [ ] Distribution matches configured weights (test with 1000+ spawns)
- [ ] Weights can be updated at runtime
- [ ] Tile instances have correct TileData assigned
- [ ] Multiple tiles can be spawned efficiently
