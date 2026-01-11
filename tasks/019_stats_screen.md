# Task 019: Stats Screen

## Objective
Implement end-of-match statistics display.

## Dependencies
- Task 013 (Combat Manager)

## Reference
- Design Doc → Section 9 Round End

## Deliverables

### 1. Stats Screen Scene
Create `/scenes/ui/stats_screen.tscn`:

**Node Structure:**
```
StatsScreen (CanvasLayer)
└── Panel (Control)
    ├── Header (Label) ["Match Statistics"]
    ├── StatsContainer (VBoxContainer)
    │   ├── DamageDealt (HBoxContainer)
    │   ├── LargestCombo (HBoxContainer)
    │   ├── TilesBroken (HBoxContainer)
    │   ├── HealingDone (HBoxContainer)
    │   ├── DamageBlocked (HBoxContainer)
    │   ├── MatchDuration (HBoxContainer)
    │   └── StunInflicted (HBoxContainer)
    └── ButtonContainer (HBoxContainer)
        ├── RematchButton (Button)
        └── QuitButton (Button)
```

### 2. Match Stats Data
Create stats tracking structure:

| Stat | Type | Description |
|------|------|-------------|
| `damage_dealt` | int | Total sword damage |
| `largest_match` | int | Biggest single match |
| `tiles_broken` | int | Total tiles cleared |
| `healing_done` | int | Total HP restored |
| `damage_blocked` | int | Total armor absorbed |
| `match_duration` | float | Seconds elapsed |
| `stun_inflicted` | float | Total stun seconds |
| `longest_chain` | int | Most cascades in sequence |

### 3. Stats Tracker
Add to CombatManager or create `/scripts/systems/stats_tracker.gd`:

**Methods:**
| Method | Description |
|--------|-------------|
| `reset()` | Clear all stats |
| `record_damage(amount)` | Track damage |
| `record_match(count, chain)` | Track match size |
| `record_heal(amount)` | Track healing |
| `record_armor_used(amount)` | Track blocked damage |
| `record_stun(duration)` | Track stun time |
| `get_stats() -> MatchStats` | Return all stats |

**Tracking during match:**
```
# In CombatManager
_on_damage_dealt(target, result):
    if target == enemy_fighter:
        stats.record_damage(result.total_damage)
        stats.record_armor_used(result.armor_absorbed)
```

### 4. Stats Screen Script
Create `/scripts/ui/stats_screen.gd`:

**Methods:**
| Method | Description |
|--------|-------------|
| `show_stats(stats: MatchStats)` | Populate and display |
| `hide()` | Close screen |

**Signals:**
| Signal | Description |
|--------|-------------|
| `rematch_pressed` | Player wants to play again |
| `quit_pressed` | Player wants to exit |

### 5. Stat Row Format
Each stat row (HBoxContainer):
```
[StatName Label]          [Value Label]
"Total Damage Dealt"      "247"
```
- Left-aligned name
- Right-aligned value
- Consistent spacing

### 6. Duration Formatting
Convert seconds to readable format:
```
format_duration(seconds):
    minutes = int(seconds / 60)
    secs = int(seconds) % 60
    return "%d:%02d" % [minutes, secs]
```
Example: 95 seconds → "1:35"

### 7. Visual Polish
- Fade-in animation when shown
- Stats could animate counting up (optional)
- Clear visual hierarchy
- Consistent with game's art style

### 8. Flow Integration
```
GameManager END state:
    → show_result(winner)
    → on continue_pressed:
        → show_stats(collected_stats)
        → on rematch_pressed:
            → reset and return to INIT
        → on quit_pressed:
            → exit to menu (or quit game for MVP)
```

## Acceptance Criteria
- [ ] All 7+ stats display correctly
- [ ] Duration formatted as M:SS
- [ ] Stats populated from match data
- [ ] Rematch button resets game
- [ ] Quit button exits appropriately
- [ ] Screen appears after result dismiss
