# Task 024: Fix Initial State Transition

## Objective
Fix the GameManager state machine so that `_setup_match()` is called during initialization.

## Priority
**Critical** - Root cause of boards not initializing

## Problem
In `game_manager.gd`:
- `current_state` is initialized to `GameState.INIT`
- `_initialize_systems()` calls `change_state(GameState.INIT)`
- `change_state()` has early return: `if current_state == new_state: return`
- Since state is already INIT, nothing happens
- `_enter_state(INIT)` never runs, so `_setup_match()` never runs

## Solution
Change the initial state to a different value so the transition to INIT actually triggers.

## Implementation

In `scripts/managers/game_manager.gd`, change line ~17:

**Before:**
```gdscript
var current_state: GameState = GameState.INIT
```

**After:**
```gdscript
var current_state: GameState = GameState.STATS  # or any state other than INIT
```

Alternatively, use a sentinel value by adding a new state:

**Option B - Add NONE state:**
```gdscript
enum GameState {
    NONE = -1,  # Add this
    INIT,
    COUNTDOWN,
    BATTLE,
    PAUSED,
    END,
    STATS
}

var current_state: GameState = GameState.NONE
```

## Recommended Fix
Option B (NONE state) is cleaner as it explicitly represents "not yet initialized", but the simpler fix (setting initial state to STATS) works too.

## After Fix
The initialization flow will be:
1. `current_state = STATS` (or NONE)
2. `change_state(INIT)` is called
3. `current_state != new_state`, so it proceeds
4. `_enter_state(INIT)` runs
5. `_setup_match()` runs
6. Boards get initialized
7. Tiles are created

## Acceptance Criteria
- [ ] `_setup_match()` is called during initialization
- [ ] Debug output shows `[GameManager] _setup_match called`
- [ ] Debug output shows `[BoardManager] initialize() called`
- [ ] Tiles appear on the game board
