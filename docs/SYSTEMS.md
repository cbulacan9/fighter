# Puzzle Fighter - Core Systems Specification

## 0. GameConstants (Autoload)

### Purpose
Centralized constants used across multiple systems. Registered as autoload in project.godot.

### Constants
| Constant | Type | Value | Description |
|----------|------|-------|-------------|
| `PET_MANA_COST` | int | 33 | Mana cost to activate pet tiles (allows 3 activations per full bar) |
| `CLEAR_ANIMATION_TIME` | float | 0.2 | Duration of tile clear animation |
| `FALL_ANIMATION_TIME_PER_ROW` | float | 0.07 | Fall animation time per row of distance |
| `SPAWN_ANIMATION_TIME` | float | 0.15 | Duration of new tile spawn animation |

### Usage
```gdscript
# Access from any script
var cost := GameConstants.PET_MANA_COST
var anim_time := GameConstants.CLEAR_ANIMATION_TIME
```

---

## 0.1 TileTypeHelper (Utility)

### Purpose
Static helper methods for tile type checks. Eliminates duplicate helper functions across systems.

### Static Methods
| Method | Input | Output | Description |
|--------|-------|--------|-------------|
| `is_hunter_pet_type` | TileTypes.Type | bool | True if BEAR_PET, HAWK_PET, or SNAKE_PET |
| `is_special_tile` | TileTypes.Type | bool | True if pet tile or ALPHA_COMMAND (not replaceable) |

### Usage
```gdscript
if TileTypeHelper.is_hunter_pet_type(tile.tile_data.tile_type):
    # Handle pet tile
if TileTypeHelper.is_special_tile(tile_type):
    # Don't replace this tile
```

---

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
Collect Adjacent FILLER Tiles (also removed)
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

### Internal Architecture
The cascade logic is centralized in `_run_cascade_loop()` to eliminate code duplication:

| Method | Description |
|--------|-------------|
| `process_matches(initial_matches)` | Entry point for player-initiated matches. Calls `_run_cascade_loop(result, matches, false)` |
| `process_single_removal(row, col)` | Entry point for tile consumption (pet clicks). Does gravity/fill first, then calls `_run_cascade_loop(result, new_matches, true)` |
| `_run_cascade_loop(result, matches, tag_first_as_cascade)` | Core loop that processes matches, applies gravity, fills empty spaces, and checks for cascades |

The `tag_first_as_cascade` parameter controls match origin tagging:
- `false`: First round tagged as PLAYER_INITIATED (for combo tracking)
- `true`: All matches tagged as CASCADE (for pet tile consumption)

### FILLER Tile Clearing
FILLER tiles (Empty Boxes) can be cleared in two ways:
1. **Direct matching**: 3+ FILLER tiles in a row/column match and clear like normal tiles
2. **Adjacent clearing**: FILLER tiles orthogonally adjacent to any matched tiles are automatically cleared

This allows players to remove FILLER tiles placed by effects like Hawk's ability.

### External Tile Changes
When abilities modify tiles on a board (e.g., Hawk replacing tiles with FILLER), the board automatically checks for new matches and processes them. This is handled by `BoardManager.check_and_resolve_matches()`.

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
| `alpha_command_free_activations` | int | Free pet activations remaining from Alpha Command |

### Fighter Pet Activation
The Fighter class owns the logic for determining if a pet can be activated:

| Method | Description |
|--------|-------------|
| `can_activate_pet()` | Returns true if fighter has free activations OR enough mana (≥ PET_MANA_COST) |
| `has_free_pet_activation()` | Returns true if alpha_command_free_activations > 0 |
| `use_free_pet_activation()` | Decrements free activations, returns true if one was used |

This centralizes the "can afford pet?" check that was previously duplicated in BoardManager, ClickConditionChecker, and AIController.

### Effect Application

**Note:** Tile availability varies by character. See CHARACTERS.md for character-specific tile sets.

#### Hunter Tiles
| Tile Type | Target | Effect Logic |
|-----------|--------|--------------|
| SWORD | Enemy | Reduce armor first, then HP. Consumes Focus stacks for bonus damage (7.5% per stack). |
| SHIELD | Self | Add armor (cap at max_hp) |
| FOCUS | Self | Add Focus stacks (1/2/3 for 3/4/5-match). Max 10 stacks (75% max bonus). Consumed on next SWORD match for bonus damage. |
| FILLER | None | No combat effect. Matchable; also cleared when adjacent to other matches. |

#### Other Character Tiles (Future)
| Tile Type | Target | Effect Logic |
|-----------|--------|--------------|
| POTION | Self | Add HP (cap at max_hp) |
| LIGHTNING | Enemy | Add stun duration (diminishing returns) |

### Stun Diminishing Returns (Lightning tile)
- Base stun applied fully if target not stunned
- If already stunned: `new_stun = base_stun * 0.5`
- Minimum stun addition: 0.25 seconds
- **Note:** Hunter does not have Lightning tiles. Stun mechanics apply to characters with Lightning in their tile set.

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
- Color coded: Red (damage), Green (heal), Blue (armor), Yellow (stun), Gray (miss)

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

---

## 10. Stats Tracker

### Purpose
Collects and aggregates match statistics for end-of-match display.

### MatchStats Structure
| Field | Type | Description |
|-------|------|-------------|
| `damage_dealt` | int | Total damage dealt to enemy |
| `largest_match` | int | Highest tile count in a single match |
| `tiles_broken` | int | Total tiles cleared |
| `healing_done` | int | Total HP restored |
| `damage_blocked` | int | Total damage absorbed by armor |
| `match_duration` | float | Match length in seconds |
| `stun_inflicted` | float | Total stun time applied to enemy |
| `longest_chain` | int | Deepest cascade chain count |

### Operations
| Operation | Input | Output | Description |
|-----------|-------|--------|-------------|
| `reset` | none | void | Clear all stats |
| `start_match` | none | void | Record match start time |
| `end_match` | none | void | Calculate match duration |
| `record_damage` | amount | void | Add to damage dealt |
| `record_armor_used` | amount | void | Add to damage blocked |
| `record_match` | tile_count, chain_depth | void | Update match/chain records |
| `record_heal` | amount | void | Add to healing done |
| `record_stun` | duration | void | Add to stun inflicted |
| `record_cascade_result` | CascadeResult | void | Process full cascade stats |
| `get_stats` | none | MatchStats | Return current statistics |

### Integration
- Created and owned by GameManager
- Records events via GameManager signal handlers
- Consumed by StatsScreen via `get_stats()`

---

## 11. UI Components (Distributed Pattern)

UI is implemented as independent components rather than a centralized UIManager. GameManager coordinates setup and signal wiring.

### HUD
**Purpose:** Displays health bars, armor, and fighter portraits.

**Setup:** `setup(player_fighter, enemy_fighter)`
- Connects to Fighter.hp_changed and Fighter.armor_changed signals
- Each fighter's stats displayed in separate panel

**Child Components:**
- HealthBar: Animated bar showing HP and armor segments

### DamageNumberSpawner
**Purpose:** Creates floating numbers for combat feedback.

**Setup:** `setup(combat_manager, player_pos, enemy_pos)`
- Connects to CombatManager signals: damage_dealt, healing_done, armor_gained, stun_applied, damage_dodged, status_damage_dealt
- Spawns numbers at fighter positions based on target

**Number Types (color-coded):**
- DAMAGE (red): HP damage dealt
- HEAL (green): HP restored
- ARMOR (blue): Shield points gained
- STUN (yellow): Stun duration applied
- MISS (gray): Attack dodged/evaded

### StunOverlay
**Purpose:** Visual indicator when a board is stunned.

**Operations:**
| Operation | Input | Output | Description |
|-----------|-------|--------|-------------|
| `show_stun` | duration | void | Fade in overlay, start timer |
| `hide_stun` | none | void | Fade out overlay |
| `update_timer` | remaining | void | Update countdown display |

**Behavior:**
- Grey semi-transparent overlay covers board
- Displays remaining stun time
- Fades in/out with 0.15s duration

### GameOverlay
**Purpose:** Modal overlays for game flow (countdown, pause, results).

**Panels:**
- CountdownPanel: 3-2-1-GO! sequence
- PausePanel: Resume/Quit buttons
- ResultPanel: Victory/Defeat/Draw display

**Signals Emitted:**
| Signal | Description |
|--------|-------------|
| `countdown_finished` | Countdown complete, start battle |
| `resume_pressed` | Player resumed from pause |
| `quit_pressed` | Player quit game |
| `continue_pressed` | Player continuing after result |

### StatsScreen
**Purpose:** End-of-match statistics display.

**Setup:** `show_stats(MatchStats, combat_log_entries)`
- Displays all tracked statistics
- Shows combat log summary (scrollable, up to 100 entries)
- Provides Rematch and Quit options

**Signals Emitted:**
| Signal | Description |
|--------|-------------|
| `rematch_pressed` | Player wants to play again |
| `quit_pressed` | Player exiting game |

---

## 12. Immediate Effect System

### Purpose
Applies combat effects (damage, healing, armor, stun, mana) immediately when matches are detected, before tile animations complete. This provides responsive gameplay feedback.

### Flow
```
Match Detected
	  ↓
CascadeHandler emits matches_processed (IMMEDIATE)
	  ↓
BoardManager receives → emits immediate_matches
	  ↓
GameManager receives → calls combat_manager.process_immediate_matches()
	  ↓
Effects Applied (damage numbers spawn, health bars update)
	  ↓
Animations play in background (purely visual)
	  ↓
cascade_complete emits → Stats recorded
```

### Key Functions
| Function | Location | Description |
|----------|----------|-------------|
| `process_immediate_matches()` | combat_manager.gd | Applies all match effects immediately |
| `_on_player_immediate_matches()` | game_manager.gd | Handler for player board matches |
| `_on_enemy_immediate_matches()` | game_manager.gd | Handler for enemy board matches |

### Signals
| Signal | Emitter | Description |
|--------|---------|-------------|
| `matches_processed` | CascadeHandler | Fires immediately when matches detected |
| `immediate_matches` | BoardManager | Forwards to GameManager for combat processing |

---

## 13. HUD Layout System

### Purpose
Centralized layout constants for positioning UI elements (panels, portraits, combo trees) and boards. Allows easy adjustment of screen layout from a single location.

### Layout Constants (hud.gd)
| Constant | Default | Description |
|----------|---------|-------------|
| `PLAYER_X_OFFSET` | 50.0 | Horizontal shift for all player UI elements |
| `ENEMY_X_OFFSET` | 50.0 | Horizontal shift for all enemy UI elements |
| `PANEL_BASE_X` | 10.0 | Base X position for health/mana panels |
| `COMBO_TREE_BASE_X` | 290.0 | Base X position for combo tree display |
| `PLAYER_UI_Y` | 550.0 | Y position for player UI elements |
| `ENEMY_UI_Y` | 5.0 | Y position for enemy UI elements |
| `PLAYER_BOARD_OFFSET` | 120.0 | Gap between player UI and board |
| `ENEMY_BOARD_OFFSET` | 120.0 | Gap between enemy UI and board |

### Calculated Positions
| Function | Returns | Description |
|----------|---------|-------------|
| `HUD.get_player_board_y()` | float | PLAYER_UI_Y + PLAYER_BOARD_OFFSET |
| `HUD.get_enemy_board_y()` | float | ENEMY_UI_Y + ENEMY_BOARD_OFFSET |

### Elements Affected by X Offset
- Health/Mana Panel (portrait + bars)
- Combo Tree Display
- Sequence Indicator (for non-Hunter characters)

### Board Positioning
GameManager calls `_position_boards()` which:
1. Positions enemy board at `(BOARD_X, HUD.get_enemy_board_y())`
2. Positions player board at `(BOARD_X, HUD.get_player_board_y())`
3. Updates stun overlays to match board positions

---

## 14. Combat Log Debugger

### Purpose
Debug panel that logs combat events in real-time. Toggle visibility with F4 key.

### Events Logged
| Event | Color | Format |
|-------|-------|--------|
| Damage dealt | Red | "⚔ P1 - Hunter took 15 dmg to HP" |
| Armor absorbed | Orange | "🛡 P2 - Hunter blocked 10 dmg" |
| Healing | Green | "💚 P1 - Hunter healed for 8" |
| Armor gained | Blue | "🛡 P2 - Hunter gained 12 armor" |
| Dodge | Yellow | "💨 P1 - Hunter DODGED an attack!" |
| DoT damage | Purple | "☠ P1 - Hunter took 5 Bleed damage" |
| Defeat | Bright Red | "💀 P1 - Hunter DEFEATED!" |

### Player Labels
- P1 = Enemy (top board)
- P2 = Player (bottom board)

### Configuration
| Property | Value | Description |
|----------|-------|-------------|
| `MAX_LOG_LINES` | 100 | Maximum entries before oldest removed |
| Toggle Key | F4 | Show/hide the debug panel |

### Stats Screen Integration
Combat log entries are passed to StatsScreen via `show_stats(stats, combat_log_entries)` for post-match review.

---

## 15. Data Validation

### Purpose
Resource data classes include `validate()` methods to catch configuration errors early.

### PuzzleTileData.validate()
Checks for common tile configuration errors:

| Check | Warning |
|-------|---------|
| `is_clickable` but `click_condition == NONE` | Tile marked clickable but has no condition to enable clicks |
| `click_condition != NONE` but no `click_effect` | Tile has click condition but no effect to trigger |
| `min_on_board > max_on_board` | Invalid spawn rule configuration |

### CharacterData.validate()
Validates character configuration and all associated tiles:

| Check | Warning |
|-------|---------|
| Empty `character_id` | Character has no ID |
| Empty `display_name` | Character has no name |
| No tiles configured | Neither basic_tiles nor specialty_tiles populated |
| Invalid `mana_config` | Mana configuration fails validation |
| Invalid tiles | Calls `validate()` on all basic and specialty tiles |

### Usage
```gdscript
# Validate character data on load
if not character_data.validate():
    push_error("Character data validation failed")
```

Validation warnings appear in the Godot output panel during development.
