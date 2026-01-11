# Task 008: Snap-Back Animation

## Objective
Implement snap-back behavior when a move doesn't create a valid match.

## Dependencies
- Task 007 (Row/Column Shifting)

## Reference
- `/docs/SYSTEMS.md` → Input Handler (Snap-Back Rule)
- Design Doc → Section 3 Controls

## Deliverables

### 1. Snap-Back Flow
After `drag_ended`:
1. Calculate final cell positions
2. Request match check from MatchDetector (preview mode)
3. If valid match → commit shift, proceed to resolution
4. If no match → animate snap-back

### 2. Snap-Back Animation
Tiles animate from their current visual position back to original positions:
- Duration: 0.2 seconds
- Easing: Ease-out
- All affected tiles animate simultaneously

### 3. BoardManager Integration
Add to board_manager.gd:

| Method | Description |
|--------|-------------|
| `check_move_validity() -> bool` | Preview match check |
| `animate_snap_back()` | Trigger revert animation |

**Signal additions:**
| Signal | Parameters | Description |
|--------|------------|-------------|
| `snap_back_started` | none | Animation beginning |
| `snap_back_finished` | none | Animation complete |

### 4. State Handling
During snap-back:
- State remains DRAGGING until animation complete
- Input blocked during animation
- On complete, return to IDLE

### 5. Animation Implementation Options

**Option A: Tween-based**
- Create Tween for each tile
- Animate `position` property
- Use `tween.finished` signal

**Option B: AnimationPlayer**
- Use tile's AnimationPlayer
- Create `snap_back` animation dynamically
- Coordinate with AnimationPlayer signals

Recommend **Option A** for flexibility.

### 6. Edge Case: Partial Drag
If player drags less than half a cell and releases:
- Should still snap back (no cell change)
- Animation distance may be small but should still play

## Acceptance Criteria
- [ ] Invalid moves trigger snap-back
- [ ] Tiles animate smoothly to original positions
- [ ] Animation takes ~0.2 seconds
- [ ] Input blocked during animation
- [ ] State returns to IDLE after animation
- [ ] Valid moves do NOT trigger snap-back
