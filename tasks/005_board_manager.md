# Task 005: Board Manager

## Objective
Create the BoardManager scene that owns and coordinates a player's grid.

## Dependencies
- Task 004 (Grid System)

## Reference
- `/docs/ARCHITECTURE.md` → Scene Hierarchy, State Machines
- `/docs/SYSTEMS.md` → All systems interact through BoardManager

## Deliverables

### 1. Board Scene
Create `/scenes/board/board.tscn`:

**Node Structure:**
```
Board (Node2D) [board_manager.gd]
├── Grid (Node2D) [grid.gd]
│   └── Tiles (Node2D) [container for tile instances]
├── InputHandler (Node) [placeholder]
└── MatchDetector (Node) [placeholder]
```

### 2. Board Manager Script
Create `/scripts/managers/board_manager.gd`:

**Exports:**
| Export | Type | Description |
|--------|------|-------------|
| `tile_scene` | PackedScene | Reference to tile.tscn |
| `fighter_data` | FighterData | Owner's fighter config |

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `grid` | Grid | Reference to Grid node |
| `state` | BoardState | Current board state |
| `is_player_controlled` | bool | Human or AI controlled |

**Board States (enum):**
| State | Description |
|-------|-------------|
| `IDLE` | Awaiting input |
| `DRAGGING` | Processing drag input |
| `RESOLVING` | Processing matches/cascades |
| `STUNNED` | Input locked from stun |

**Methods:**
| Method | Description |
|--------|-------------|
| `initialize(fighter: FighterData, is_player: bool)` | Setup board |
| `generate_initial_board()` | Fill grid with no pre-matches |
| `get_state() -> BoardState` | Returns current state |
| `set_state(state: BoardState)` | Changes state |
| `lock_input()` | Prevents input processing |
| `unlock_input()` | Allows input processing |
| `apply_stun(duration: float)` | Enter stunned state |

**Signals:**
| Signal | Parameters | Description |
|--------|------------|-------------|
| `state_changed` | new_state | Board state changed |
| `matches_resolved` | match_results | Matches processed |
| `ready_for_input` | none | Board idle and accepting |

### 3. Initial Board Generation
Logic for `generate_initial_board()`:
1. Create all 64 tiles using TileSpawner (Task 010)
2. Place tiles in grid
3. Check for existing matches
4. If matches exist, replace those tiles
5. Repeat until no matches

**Temporary**: Until TileSpawner exists, use random tile types.

### 4. Tile Container Setup
- Tiles node holds all Tile instances
- Position tiles based on `grid.grid_to_world(row, col)`
- Board origin at top-left of grid

## Acceptance Criteria
- [ ] Board scene loads without errors
- [ ] `initialize()` creates 64 tiles
- [ ] No pre-existing matches on generated board
- [ ] State can be changed and queried
- [ ] Tiles visually display in 6x8 grid
