# Task 020: Game Manager

## Objective
Implement the central state machine controlling match flow.

## Dependencies
- All previous tasks

## Reference
- `/docs/ARCHITECTURE.md` → State Machines
- `/docs/SYSTEMS.md` → Game Manager

## Deliverables

### 1. Game Manager Script
Update `/scripts/managers/game_manager.gd`:

**GameState Enum:**
| State | Description |
|-------|-------------|
| `INIT` | Loading, setup |
| `COUNTDOWN` | Pre-match countdown |
| `BATTLE` | Active gameplay |
| `PAUSED` | Game paused (PvE) |
| `END` | Match concluded |
| `STATS` | Showing statistics |

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `current_state` | GameState | Current state |
| `player_board` | BoardManager | Player's board |
| `enemy_board` | BoardManager | Enemy's board |
| `combat_manager` | CombatManager | Combat system |
| `ai_controller` | AIController | AI opponent |
| `ui_manager` | UIManager | UI coordinator |
| `match_timer` | float | Elapsed time |

### 2. State Machine Methods

| Method | Description |
|--------|-------------|
| `change_state(new_state)` | Transition to state |
| `_enter_state(state)` | State entry logic |
| `_exit_state(state)` | State exit logic |
| `_process_state(delta)` | Per-frame state logic |

### 3. State Transitions

```
INIT:
    entry: Setup boards, fighters, UI
    exit: Everything initialized
    → COUNTDOWN

COUNTDOWN:
    entry: Show countdown overlay
    exit: Countdown finished signal
    → BATTLE

BATTLE:
    entry: Enable input, start AI, start timer
    exit: Match ended or pause requested
    → PAUSED (on pause input)
    → END (on fighter defeated)

PAUSED:
    entry: Disable input, pause AI, show menu
    exit: Resume or quit
    → BATTLE (on resume)
    → INIT (on quit, reset everything)

END:
    entry: Disable input, stop AI, show result
    exit: Result acknowledged
    → STATS

STATS:
    entry: Show stats screen
    exit: Player choice
    → INIT (on rematch)
    → Quit game (on quit)
```

### 4. Initialization Sequence

`_ready()` or `start_match()`:
1. Load fighter data resources
2. Initialize CombatManager with fighters
3. Initialize both BoardManagers
4. Initialize AIController with enemy board
5. Setup UI connections
6. Change state to COUNTDOWN

### 5. Battle Loop

In BATTLE state `_process(delta)`:
```
# Update timer
match_timer += delta

# Tick combat (stun timers)
combat_manager.tick(delta)

# Check stun states, update boards
update_board_stun_states()

# AI runs independently via _process
```

### 6. Signal Connections

| Signal | Source | Handler |
|--------|--------|---------|
| `countdown_finished` | GameOverlay | → BATTLE |
| `resume_pressed` | GameOverlay | → BATTLE |
| `quit_pressed` | GameOverlay | → INIT or quit |
| `continue_pressed` | GameOverlay | → STATS |
| `match_ended` | CombatManager | → END |
| `rematch_pressed` | StatsScreen | → INIT |

### 7. Pause Handling

```
_input(event):
    if event.is_action_pressed("pause"):
        if current_state == BATTLE:
            change_state(PAUSED)
        elif current_state == PAUSED:
            change_state(BATTLE)
```

### 8. Reset Functionality

For rematch:
```
reset_match():
    match_timer = 0
    combat_manager.reset()
    player_board.reset()
    enemy_board.reset()
    stats_tracker.reset()
    change_state(COUNTDOWN)
```

## Acceptance Criteria
- [ ] All 6 states implemented
- [ ] Transitions work correctly
- [ ] Pause toggles during battle
- [ ] Match ends on fighter defeat
- [ ] Timer tracks match duration
- [ ] Rematch resets everything
- [ ] State changes emit signals for UI
