# Task 004: Grid System

## Objective
Implement the Grid class for managing the 6x8 tile array with wrapping support.

## Dependencies
- Task 003 (Tile Entity)

## Reference
- `/docs/SYSTEMS.md` → Grid System

## Deliverables

### 1. Grid Script
Create `/scripts/systems/grid.gd`:

**Constants:**
| Constant | Value |
|----------|-------|
| `ROWS` | 6 |
| `COLS` | 8 |
| `CELL_SIZE` | Vector2(64, 64) |

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `_tiles` | Array[Array] | 2D array of Tile references |

**Core Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `initialize()` | void | Creates empty 2D array |
| `get_tile(row, col)` | Tile | Returns tile at wrapped position |
| `set_tile(row, col, tile)` | void | Places tile at position |
| `clear_tile(row, col)` | Tile | Removes and returns tile |
| `is_empty(row, col)` | bool | Checks if position is null |

**Position Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `wrap_row(row)` | int | Wraps row index to valid range |
| `wrap_col(col)` | int | Wraps column index to valid range |
| `wrap_position(row, col)` | Vector2i | Wraps both coordinates |
| `grid_to_world(row, col)` | Vector2 | Converts grid pos to pixel pos |
| `world_to_grid(world_pos)` | Vector2i | Converts pixel pos to grid pos |

**Row/Column Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `get_row(row_index)` | Array[Tile] | Returns all tiles in row |
| `get_column(col_index)` | Array[Tile] | Returns all tiles in column |
| `shift_row(row_index, offset)` | void | Shifts row by offset (wraps) |
| `shift_column(col_index, offset)` | void | Shifts column by offset (wraps) |

**Utility Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `get_all_tiles()` | Array[Tile] | Flat array of all tiles |
| `get_empty_positions()` | Array[Vector2i] | All positions with null |
| `get_column_empties(col)` | Array[int] | Empty row indices in column |

### 2. Wrapping Implementation
```
wrap_row(row):
    return ((row % ROWS) + ROWS) % ROWS

wrap_col(col):
    return ((col % COLS) + COLS) % COLS
```
This handles negative offsets correctly.

### 3. Shift Implementation
Row shift example (offset = 2 on row 0):
- Tiles at cols [0,1,2,3,4,5,6,7] move to [2,3,4,5,6,7,0,1]
- Visual: tiles slide right, wrap around

Column shift follows same logic vertically.

## Acceptance Criteria
- [ ] Grid initializes with 6x8 null array
- [ ] `get_tile` with out-of-bounds coords wraps correctly
- [ ] `shift_row` wraps tiles around edges
- [ ] `shift_column` wraps tiles around edges
- [ ] `grid_to_world` returns correct pixel positions
- [ ] `world_to_grid` returns correct grid coordinates
