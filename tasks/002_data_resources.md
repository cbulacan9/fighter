# Task 002: Data Resources

## Objective
Create Resource scripts for tile and fighter data configuration.

## Dependencies
- Task 001 (Project Setup)

## Reference
- `/docs/ARCHITECTURE.md` → Resource Definitions
- `/docs/SYSTEMS.md` → Tile Spawner, Combat Manager

## Deliverables

### 1. TileType Enum
Create `/scripts/data/tile_types.gd`:
- Define global enum: SWORD, SHIELD, POTION, LIGHTNING, FILLER
- Register as autoload or use `class_name`

### 2. TileData Resource
Create `/scripts/data/tile_data.gd` extending Resource:

**Properties:**
| Export | Type | Description |
|--------|------|-------------|
| `tile_type` | TileType | Enum value |
| `display_name` | String | Human-readable name |
| `sprite` | Texture2D | Tile artwork |
| `color` | Color | Fallback/tint color |
| `match_3_value` | int | Effect value for 3-match |
| `match_4_value` | int | Effect value for 4-match |
| `match_5_value` | int | Effect value for 5-match |

**Method:**
- `get_value(match_count: int) -> int` - Returns appropriate value (capped at 5)

### 3. FighterData Resource
Create `/scripts/data/fighter_data.gd` extending Resource:

**Properties:**
| Export | Type | Description |
|--------|------|-------------|
| `fighter_name` | String | Display name |
| `max_hp` | int | Starting/max health (default 100) |
| `portrait` | Texture2D | Character portrait |
| `tile_weights` | Dictionary | {TileType: float} spawn weights |

### 4. Create Default Resources
In `/resources/tiles/`:
- `sword.tres` - Sword tile (10/25/50)
- `shield.tres` - Shield tile (10/25/50)
- `potion.tres` - Potion tile (10/25/50)
- `lightning.tres` - Lightning tile (1/2/3 for stun seconds)
- `filler.tres` - Filler tile (0/0/0)

In `/resources/fighters/`:
- `default_player.tres` - 100 HP, balanced weights
- `default_enemy.tres` - 100 HP, balanced weights

## Acceptance Criteria
- [ ] TileType enum accessible globally
- [ ] TileData resources load in editor
- [ ] FighterData resources load in editor
- [ ] All 5 tile resources created with correct values
- [ ] Both fighter resources created
