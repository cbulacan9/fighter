# Task 006: Input Handler

## Objective
Implement touch/mouse input detection for dragging rows and columns.

## Dependencies
- Task 005 (Board Manager)

## Reference
- `/docs/SYSTEMS.md` → Input Handler

## Deliverables

### 1. Input Handler Script
Create `/scripts/systems/input_handler.gd`:

**Exports:**
| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `drag_threshold` | float | 10.0 | Pixels before axis locks |
| `cell_size` | float | 64.0 | Size of one tile |

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `is_dragging` | bool | Currently in drag |
| `drag_axis` | DragAxis | NONE, HORIZONTAL, VERTICAL |
| `drag_start_world` | Vector2 | World position of press |
| `drag_start_grid` | Vector2i | Grid position of press |
| `drag_index` | int | Row or column being dragged |
| `current_offset` | float | Pixel offset from start |

**DragAxis Enum:**
- `NONE` - Not determined yet
- `HORIZONTAL` - Dragging a row
- `VERTICAL` - Dragging a column

**Methods:**
| Method | Description |
|--------|-------------|
| `_input(event)` | Process input events |
| `_on_press(pos: Vector2)` | Handle press start |
| `_on_drag(pos: Vector2)` | Handle drag movement |
| `_on_release()` | Handle drag end |
| `reset()` | Clear drag state |
| `set_enabled(enabled: bool)` | Enable/disable input |

**Signals:**
| Signal | Parameters | Description |
|--------|------------|-------------|
| `drag_started` | axis, index, start_pos | Drag began |
| `drag_moved` | offset_pixels | Drag position updated |
| `drag_ended` | final_offset | Drag released |

### 2. Input Detection Logic

**Press:**
1. Check if input enabled
2. Convert screen position to grid position
3. Verify position is within grid bounds
4. Store start position
5. Set `is_dragging = true`

**Drag:**
1. Calculate delta from start position
2. If axis not determined and delta > threshold:
   - If abs(delta.x) > abs(delta.y): HORIZONTAL
   - Else: VERTICAL
3. Once axis locked, emit `drag_moved` with offset

**Release:**
1. Emit `drag_ended` with final offset
2. Call `reset()`

### 3. Coordinate Conversion
Input handler needs reference to Grid for:
- `world_to_grid()` - Determine which tile was pressed
- Grid bounds checking

### 4. Integration Points
- BoardManager enables/disables input based on state
- BoardManager listens to signals to update grid visually
- BoardManager validates moves on `drag_ended`

## Acceptance Criteria
- [ ] Press on tile starts drag state
- [ ] Axis determined after threshold movement
- [ ] `drag_moved` emits with correct pixel offset
- [ ] `drag_ended` emits on release
- [ ] Input can be enabled/disabled
- [ ] Works with both mouse and touch
