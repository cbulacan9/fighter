# Task 018: Game Overlays

## Objective
Implement countdown, pause menu, and victory/defeat screens.

## Dependencies
- Task 001 (Project Setup)

## Reference
- `/docs/SYSTEMS.md` → Game Manager States
- Design Doc → Section 9 Game Flow

## Deliverables

### 1. Game Overlay Scene
Create `/scenes/ui/game_overlay.tscn`:

**Node Structure:**
```
GameOverlay (CanvasLayer)
├── CountdownPanel (Control)
│   └── CountdownLabel (Label)
├── PausePanel (Control)
│   ├── PauseLabel (Label)
│   ├── ResumeButton (Button)
│   └── QuitButton (Button)
└── ResultPanel (Control)
    ├── ResultLabel (Label) ["Victory!" / "Defeat!" / "Draw!"]
    └── ContinueButton (Button)
```

### 2. Game Overlay Script
Create `/scripts/ui/game_overlay.gd`:

**Methods:**
| Method | Description |
|--------|-------------|
| `show_countdown()` | Start 3-2-1 sequence |
| `show_pause()` | Display pause menu |
| `hide_pause()` | Close pause menu |
| `show_result(winner_id: int)` | Display outcome |
| `hide_all()` | Clear all panels |

**Signals:**
| Signal | Description |
|--------|-------------|
| `countdown_finished` | 3-2-1 complete |
| `resume_pressed` | Player wants to continue |
| `quit_pressed` | Player wants to exit |
| `continue_pressed` | Proceed after result |

### 3. Countdown Display

**Sequence:**
1. Show "3" - hold 1 second
2. Show "2" - hold 1 second
3. Show "1" - hold 1 second
4. Show "GO!" - hold 0.5 seconds
5. Emit `countdown_finished`
6. Hide panel

**Visual style:**
- Large centered text (72px+)
- Optional: Scale animation on each number
- Optional: Sound cue per number (future)

**Implementation:**
```
func show_countdown():
    countdown_panel.visible = true
    for num in [3, 2, 1]:
        countdown_label.text = str(num)
        await get_tree().create_timer(1.0).timeout
    countdown_label.text = "GO!"
    await get_tree().create_timer(0.5).timeout
    countdown_panel.visible = false
    countdown_finished.emit()
```

### 4. Pause Menu

**Trigger:**
- Escape key or pause button (PvE only)
- Not available during PvP (future)

**Panel contents:**
- "PAUSED" header
- Resume button → emits `resume_pressed`
- Quit button → emits `quit_pressed`

**Visual:**
- Centered modal panel
- Semi-transparent background
- Game visible but dimmed behind

### 5. Result Screen

**Winner ID mapping:**
- 1 = Player wins → "VICTORY!"
- 2 = Enemy wins → "DEFEAT!"
- 3 = Draw → "DRAW!"

**Panel contents:**
- Large result text
- Color coded (green/red/yellow)
- Continue button → emits `continue_pressed` → leads to stats

### 6. Panel Management
Only one panel visible at a time:
```
func _show_panel(panel):
    countdown_panel.visible = false
    pause_panel.visible = false
    result_panel.visible = false
    panel.visible = true
```

### 7. GameManager Integration
GameManager controls overlay:
```
COUNTDOWN state → show_countdown()
PAUSED state → show_pause()
END state → show_result(winner_id)
BATTLE state → hide_all()
```

### 8. Input Handling
- Pause panel captures input (buttons)
- Escape key toggles pause during battle
- Result panel waits for button press

## Acceptance Criteria
- [ ] Countdown displays 3, 2, 1, GO!
- [ ] Countdown emits signal when complete
- [ ] Pause menu shows with Resume/Quit
- [ ] Pause buttons emit correct signals
- [ ] Result screen shows correct outcome
- [ ] Only one overlay panel visible at a time
