# Task 007: Row/Column Shifting

## Objective
Implement real-time visual tile movement during drag with wrapping.

## Dependencies
- Task 006 (Input Handler)

## Reference
- `/docs/SYSTEMS.md` → Grid System, Input Handler

## Deliverables

### 1. Visual Drag Preview
Extend BoardManager to handle drag signals:

**On `drag_started`:**
- Store original tile positions for the row/column
- Set state to DRAGGING

**On `drag_moved`:**
- Calculate visual offset for affected tiles
- Move tile sprites to preview positions
- Handle wrapping visualization

**On `drag_ended`:**
- Snap to nearest cell boundary
- Request match validation

### 2. Wrapping Visualization
When tiles are dragged past edges:
- Tile exiting right edge appears on left
- Tile exiting left edge appears on right
- Same for top/bottom with columns

**Implementation approach:**
- Track each tile's visual position separately from grid position
- Apply modulo wrapping to visual coordinates
- Tiles smoothly slide, wrapping seamlessly

### 3. Snap-to-Cell Calculation
On release, determine final cell offset:
```
cells_moved = round(pixel_offset / cell_size)
```
This gives integer number of cells to shift.

### 4. Grid Data Update
After snap calculation:
1. Call `grid.shift_row(index, cells_moved)` or `grid.shift_column()`
2. Update each tile's `grid_position` property
3. Sync visual positions to new grid positions

### 5. BoardManager Methods
Add to board_manager.gd:

| Method | Description |
|--------|-------------|
| `preview_row_shift(row, offset)` | Visually shift row without committing |
| `preview_column_shift(col, offset)` | Visually shift column |
| `commit_shift()` | Apply previewed shift to grid data |
| `revert_preview()` | Reset visuals to grid state |

### 6. Tile Position Updates
Each tile needs:
- Smooth position interpolation during drag
- Instant snap on commit or revert

## Acceptance Criteria
- [ ] Tiles follow drag input smoothly
- [ ] Tiles wrap around edges visually
- [ ] Release snaps to nearest cell
- [ ] Grid data updated after valid shift
- [ ] Horizontal drag only moves row
- [ ] Vertical drag only moves column
