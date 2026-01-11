# Puzzle Fighter - Core Systems Specification

## 1. Grid System

### Purpose
Manages the 6x8 tile array and provides position calculations with wrapping support.

### Properties
| Property | Type | Description |
|----------|------|-------------|
| `ROWS` | const int | 6 |
| `COLS` | const int | 8 |
| `tiles` | 2D Array | Tile references [row][col] |

### Operations
| Operation | Input | Output | Description |
|-----------|-------|--------|-------------|
| `get_tile` | row, col | Tile | Returns tile at position (with wrapping) |
| `set_tile` | row, col, tile | void | Places tile at position |
| `wrap_position` | row, col | Vector2i | Normalizes position to valid grid coords |
| `get_row` | row_index | Array | Returns all tiles in row |
| `get_column` | col_index | Array | Returns all tiles in column |
| `shift_row` | row_index, offset | void | Moves row horizontally (wraps) |
| `shift_column` | col_index, offset | void | Moves column vertically (wraps) |
| `get_empty_positions` | none | Array | Returns positions with null tiles |

### Wrapping Logic
- Row wrap: `col = col % COLS` (negative handled)
- Column wrap: `row = row % ROWS` (negative handled)

---

## 2. Input Handler

### Purpose
Processes touch/mouse input for row and column dragging.

### Properties
| Property | Type | Description |
|----------|------|-------------|
| `drag_threshold` | float | Minimum pixels to determine drag direction |
| `is_dragging` | bool | Currently processing a drag |
| `drag_axis` | enum | HORIZONTAL or VERTICAL |
| `drag_start_pos` | Vector2 | World position of drag start |
| `drag_row_or_col` | int | Index of row/column being dragged |
| `original_positions` | Array | Tile positions before drag (for snap-back) |

### Drag Flow
1. **Press**: Record start position, store original tile positions
2. **Move**: Determine axis (once past threshold), preview tile movement
3. **Release**: Request match validation
   - Match found → Confirm move
   - No match → Animate snap-back to original positions

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `drag_started` | axis, index | Began dragging row/column |
| `drag_updated` | offset | Drag position changed |
| `drag_released` | final_offset | Drag completed |
| `snap_back_requested` | none | No valid match, revert |

---

## 3. Match Detector

### Purpose
Scans the grid for valid matches (3+ aligned identical tiles).

### Match Detection Algorithm
1. Scan all rows left-to-right for horizontal matches
2. Scan all columns top-to-bottom for vertical matches
3. Group connected matches of same type
4. Return list of MatchResult objects

### MatchResult Structure
| Field | Type | Description |
|-------|------|-------------|
| `tile_type` | TileType | Type of matched tiles |
| `positions` | Array[Vector2i] | Grid coordinates of matched tiles |
| `count` | int | Number of tiles (capped at 5 for rewards) |

### Operations
| Operation | Input | Output | Description |
|-----------|-------|--------|-------------|
| `find_matches` | Grid | Array[MatchResult] | Returns all valid matches |
| `has_any_match` | Grid | bool | Quick check for any valid match |
| `preview_match` | Grid, move | bool | Check if hypothetical move creates match |

### Edge Cases
- Overlapping matches: Count each tile once, largest match takes priority
- Cross patterns: Treated as single match if same type
- 6+ tiles: Capped at 5-match rewards

---

## 4. Cascade Handler

### Purpose
Manages tile removal, gravity fill, and chain reaction processing.

### Cascade Sequence
```
Remove Matched Tiles
        ↓
Apply Gravity (tiles fall down)
        ↓
Spawn New Tiles (from top)
        ↓
Wait for animations
        ↓
Check for new matches
        ↓
If matches exist → Loop
If no matches → Complete
```

### Operations
| Operation | Input | Output | Description |
|-----------|-------|--------|-------------|
| `remove_tiles` | Array[Vector2i] | void | Clears tiles at positions |
| `apply_gravity` | Grid | Array[TileMove] | Calculates fall movements |
| `fill_empty` | Grid, Spawner | Array[Tile] | Creates new tiles for empty spaces |
| `process_cascade` | initial_matches | CascadeResult | Full cascade loop |

### CascadeResult Structure
| Field | Type | Description |
|-------|------|-------------|
| `all_matches` | Array[MatchResult] | Every match in cascade chain |
| `total_tiles_cleared` | int | Sum of all tiles removed |
| `chain_count` | int | Number of cascade iterations |

---

## 5. Tile Spawner

### Purpose
Creates new tiles with weighted random type selection.

### Properties
| Property | Type | Description |
|----------|------|-------------|
| `weights` | Dictionary | {TileType: float} spawn probabilities |

### Operations
| Operation | Input | Output | Description |
|-----------|-------|--------|-------------|
| `spawn_tile` | none | Tile | Creates random weighted tile |
| `spawn_multiple` | count | Array[Tile] | Creates multiple tiles |
| `set_weights` | Dictionary | void | Updates spawn weights |

### Weight Normalization
Weights are normalized to sum to 1.0 at runtime. Example:
- Sword: 20, Shield: 20, Potion: 15, Lightning: 10, Filler: 35
- Total: 100 → Sword = 0.20 probability

### Initial Board Generation
- Generate full 6x8 grid
- After generation, scan for pre-existing matches
- If matches exist, regenerate affected tiles until clean

---

## 6. Combat Manager

### Purpose
Manages fighter state (HP, armor, stun) and applies match effects.

### Fighter State
| Property | Type | Description |
|----------|------|-------------|
| `current_hp` | int | Current health (0 = defeated) |
| `max_hp` | int | Maximum health (default 100) |
| `armor` | int | Damage buffer (capped at max_hp) |
| `stun_remaining` | float | Seconds of stun left |
| `is_defeated` | bool | HP reached 0 |

### Effect Application
| Tile Type | Target | Effect Logic |
|-----------|--------|--------------|
| SWORD | Enemy | Reduce armor first, then HP |
| SHIELD | Self | Add armor (cap at max_hp) |
| POTION | Self | Add HP (cap at max_hp) |
| LIGHTNING | Enemy | Add stun duration (diminishing returns) |
| FILLER | None | No effect |

### Stun Diminishing Returns
- Base stun applied fully if target not stunned
- If already stunned: `new_stun = base_stun * 0.5`
- Minimum stun addition: 0.25 seconds

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `damage_dealt` | target, amount, was_armor | Damage applied |
| `healing_done` | target, amount | HP restored |
| `armor_gained` | target, amount | Shield added |
| `stun_applied` | target, duration | Stun started/extended |
| `fighter_defeated` | fighter | HP reached 0 |

---

## 7. AI Controller

### Purpose
Makes decisions for the AI opponent's board.

### Decision Process
1. Evaluate all possible moves (row shifts, column shifts)
2. Score each move based on:
   - Match value (damage potential prioritized)
   - Cascade potential
   - Defensive value (if low HP)
3. Select move based on difficulty settings

### Difficulty Scaling
| Setting | Behavior |
|---------|----------|
| Reaction Delay | Time between decisions (lower = harder) |
| Look-ahead | Cascade prediction depth |
| Randomness | Chance to pick suboptimal move |
| Priority Weights | Offensive vs defensive balance |

### Operations
| Operation | Input | Output | Description |
|-----------|-------|--------|-------------|
| `evaluate_board` | Grid | Array[ScoredMove] | All moves with scores |
| `select_move` | Array[ScoredMove] | Move | Choose based on difficulty |
| `execute_move` | Move | void | Apply to board |

---

## 8. UI Manager

### Purpose
Controls all visual feedback and UI elements.

### Components
| Component | Description |
|-----------|-------------|
| HealthBar | Displays HP and armor as segmented bar |
| ComboMeter | Progress bar (visual only in MVP) |
| Portrait | Fighter image display |
| DamageNumber | Floating number popup |
| StunOverlay | Grey overlay on stunned board |
| GameOverlay | Countdown, pause menu, victory/defeat |
| StatsScreen | End-of-match statistics |

### Damage Number Behavior
- Spawn at tile match position
- Float upward with fade
- Color coded: Red (damage), Green (heal), Blue (armor), Yellow (stun)

### Health Bar Display
- Shows HP as filled portion
- Armor displayed as secondary overlay/segment
- Animate changes smoothly

### Signals Listened
| Signal | Response |
|--------|----------|
| `damage_dealt` | Spawn damage number, update health bar |
| `healing_done` | Spawn heal number, update health bar |
| `armor_gained` | Spawn armor number, update armor display |
| `stun_applied` | Show stun overlay on target board |
| `game_state_changed` | Show/hide appropriate overlays |

---

## 9. Game Manager

### Purpose
Controls overall match flow and game state.

### State Transitions
```
INIT → COUNTDOWN → BATTLE ⇄ PAUSED
                      ↓
                     END → STATS → INIT
```

### State Behaviors
| State | Board Input | AI Active | UI Visible |
|-------|-------------|-----------|------------|
| INIT | Disabled | No | Loading |
| COUNTDOWN | Disabled | No | Countdown timer |
| BATTLE | Enabled | Yes | HUD only |
| PAUSED | Disabled | No | Pause menu |
| END | Disabled | No | Victory/Defeat splash |
| STATS | Disabled | No | Stats summary |

### Match Statistics Tracked
- Total damage dealt
- Total healing done
- Total damage blocked (armor)
- Tiles broken
- Largest single match
- Longest chain
- Stun time inflicted
- Match duration

### Operations
| Operation | Input | Output | Description |
|-----------|-------|--------|-------------|
| `start_match` | none | void | Begin countdown |
| `pause_match` | none | void | Enter pause state |
| `resume_match` | none | void | Return to battle |
| `end_match` | winner | void | Trigger end sequence |
| `show_stats` | none | void | Display statistics |
| `rematch` | none | void | Reset and restart |
