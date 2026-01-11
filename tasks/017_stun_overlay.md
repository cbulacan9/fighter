# Task 017: Stun Overlay

## Objective
Implement visual stun effect on board when fighter is stunned.

## Dependencies
- Task 013 (Combat Manager)

## Reference
- `/docs/SYSTEMS.md` → UI Manager (Stun Overlay)
- Design Doc → Section 6 Stun

## Deliverables

### 1. Stun Overlay Scene
Create `/scenes/ui/stun_overlay.tscn`:

**Node Structure:**
```
StunOverlay (CanvasLayer)
├── Darken (ColorRect)
├── StunIcon (Sprite2D or Label) [optional]
└── Timer (Label) [optional: shows remaining]
```

### 2. Stun Overlay Script
Create `/scripts/ui/stun_overlay.gd`:

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `is_active` | bool | Currently showing |
| `target_board` | BoardManager | Board to overlay |

**Methods:**
| Method | Description |
|--------|-------------|
| `show_stun(duration: float)` | Activate overlay |
| `hide_stun()` | Deactivate overlay |
| `update_timer(remaining: float)` | Update display |

### 3. Visual Design

**Darken layer:**
- Color: Grey with alpha (#00000080)
- Covers entire board area
- Semi-transparent (player can see tiles)

**Optional elements:**
- Lightning bolt icon centered
- Countdown text showing seconds remaining

### 4. Animation

**On show:**
- Fade in over 0.15s
- Optional: Flash effect

**On hide:**
- Fade out over 0.15s

**During stun:**
- Optional: Subtle pulse animation
- Timer countdown updates each frame

### 5. Board Integration
Add to BoardManager:
- Child StunOverlay node
- Positioned to cover grid area exactly

```
# In BoardManager
func _on_stun_applied(duration):
    stun_overlay.show_stun(duration)
    set_state(BoardState.STUNNED)

func _on_stun_ended():
    stun_overlay.hide_stun()
    set_state(BoardState.IDLE)
```

### 6. Sizing
Overlay must match board dimensions:
- Width: COLS * CELL_SIZE
- Height: ROWS * CELL_SIZE
- Position: Same origin as grid

### 7. Input Blocking
While stunned:
- InputHandler disabled via BoardManager state
- Visual overlay reinforces that input is blocked

### 8. Combat Manager Connection
Listen to signals:
- `stun_applied(target, duration)` → Show on target's board
- `stun_ended(fighter)` → Hide on that fighter's board

Alternatively, Fighter.stun_changed signal with remaining time.

## Acceptance Criteria
- [ ] Overlay appears when stun applied
- [ ] Overlay covers only the affected board
- [ ] Board visually greyed out
- [ ] Overlay hides when stun ends
- [ ] Fade animations smooth
- [ ] Optional timer shows remaining time
