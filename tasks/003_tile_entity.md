# Task 003: Tile Entity

## Objective
Create the Tile scene and script for individual grid tiles.

## Dependencies
- Task 002 (Data Resources)

## Reference
- `/docs/ARCHITECTURE.md` → Scene Hierarchy
- `/docs/SYSTEMS.md` → Grid System

## Deliverables

### 1. Tile Scene
Create `/scenes/board/tile.tscn`:

**Node Structure:**
```
Tile (Node2D)
├── Sprite2D (displays tile artwork)
└── AnimationPlayer (for effects)
```

### 2. Tile Script
Create `/scripts/entities/tile.gd`:

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `tile_data` | TileData | Reference to tile resource |
| `grid_position` | Vector2i | Current row, col in grid |

**Methods:**
| Method | Description |
|--------|-------------|
| `setup(data: TileData, pos: Vector2i)` | Initialize tile with data |
| `get_type() -> TileType` | Returns tile type enum |
| `get_match_value(count: int) -> int` | Returns effect value |
| `play_match_animation()` | Trigger match/clear animation |
| `play_spawn_animation()` | Trigger spawn/fall animation |

**Signals:**
| Signal | Description |
|--------|-------------|
| `animation_finished` | Emitted when any animation completes |

### 3. Placeholder Visuals
- Use colored rectangles as placeholder sprites
- Colors: Red (sword), Blue (shield), Green (potion), Yellow (lightning), Grey (filler)
- Size: 64x64 pixels recommended

### 4. Basic Animations
Create in AnimationPlayer:
- `match` - Scale up slightly, fade out (0.3s)
- `spawn` - Start transparent, fade in while falling (0.2s)
- `idle` - Default state

## Acceptance Criteria
- [ ] Tile scene instantiates without errors
- [ ] Tile displays correct color based on TileData
- [ ] `get_type()` returns correct TileType
- [ ] `get_match_value()` returns correct values for 3/4/5
- [ ] Animations play when triggered
