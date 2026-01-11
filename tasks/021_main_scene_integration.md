# Task 021: Main Scene Integration

## Objective
Assemble all systems into the main scene for a playable MVP.

## Dependencies
- Task 020 (Game Manager)
- All previous tasks complete

## Reference
- `/docs/ARCHITECTURE.md` → Scene Hierarchy

## Deliverables

### 1. Main Scene Structure
Update `/scenes/main.tscn`:

```
Main (Node)
├── GameManager (Node)
├── CombatManager (Node)
├── Boards (Node2D)
│   ├── PlayerBoard (BoardManager scene)
│   └── EnemyBoard (BoardManager scene)
├── AIController (Node)
└── UI (CanvasLayer)
    ├── HUD (HUD scene)
    ├── GameOverlay (GameOverlay scene)
    ├── StatsScreen (StatsScreen scene)
    └── DamageNumbers (Node2D)
```

### 2. Node References
GameManager needs exported references or `get_node` paths to:
- CombatManager
- PlayerBoard
- EnemyBoard
- AIController
- All UI components

### 3. Layout Positioning

**Portrait mobile layout (720x1280):**
```
┌────────────────────────────────────┐ 0
│            Enemy HUD               │
│  [Portrait] [HP Bar] [Combo]       │ 100
├────────────────────────────────────┤
│                                    │
│          Enemy Board               │
│           (6x8 grid)               │ 100-500
│                                    │
├────────────────────────────────────┤ 500
│           Divider/Gap              │
├────────────────────────────────────┤ 550
│                                    │
│          Player Board              │
│           (6x8 grid)               │ 550-950
│                                    │
├────────────────────────────────────┤
│            Player HUD              │
│  [Portrait] [HP Bar] [Combo]       │ 950-1050
└────────────────────────────────────┘ 1280
```

### 4. Board Positioning
Calculate board positions:
```
CELL_SIZE = 64
BOARD_WIDTH = 8 * 64 = 512
BOARD_HEIGHT = 6 * 64 = 384

# Center horizontally
board_x = (720 - 512) / 2 = 104

enemy_board.position = Vector2(104, 100)
player_board.position = Vector2(104, 550)
```

### 5. Resource Assignment
In main scene or via code:
- Assign `default_player.tres` to PlayerBoard
- Assign `default_enemy.tres` to EnemyBoard
- Assign tile scene reference to boards
- Assign tile resources to spawners

### 6. Signal Wiring
Connect all signals (code or editor):

**CombatManager → UI:**
- damage_dealt → DamageNumberSpawner
- healing_done → DamageNumberSpawner
- armor_gained → DamageNumberSpawner
- stun_applied → StunOverlay, DamageNumberSpawner
- fighter_defeated → GameManager

**GameManager → UI:**
- state_changed → GameOverlay, HUD

**Boards → CombatManager:**
- matches_resolved → process effects

**GameOverlay → GameManager:**
- countdown_finished, resume_pressed, etc.

### 7. Initialization Order
In `_ready()` of Main scene script or GameManager:
1. CombatManager.initialize(player_data, enemy_data)
2. PlayerBoard.initialize(player_data, true)
3. EnemyBoard.initialize(enemy_data, false)
4. AIController.board = EnemyBoard
5. HUD.setup(player_fighter, enemy_fighter)
6. GameManager.change_state(INIT)

### 8. Input Mapping
In Project Settings → Input Map:
- `pause` → Escape key
- Touch/mouse handled by InputHandler

### 9. Testing Checklist
Verify end-to-end:
- [ ] Game starts with countdown
- [ ] Player can drag tiles
- [ ] Matches trigger and clear
- [ ] Cascades work
- [ ] Damage/heal/armor/stun apply correctly
- [ ] AI makes moves
- [ ] HP bars update
- [ ] Damage numbers appear
- [ ] Stun overlay shows
- [ ] Game ends on 0 HP
- [ ] Result screen displays
- [ ] Stats screen shows correct data
- [ ] Rematch resets properly
- [ ] Pause works

### 10. Known MVP Limitations
Document for future:
- Combo meter visual only (no activation)
- Single difficulty AI
- No audio
- Placeholder art
- No main menu (starts directly)

## Acceptance Criteria
- [ ] Main scene assembles all components
- [ ] Layout fits 720x1280 screen
- [ ] All signals connected
- [ ] Full game loop playable
- [ ] Player can defeat AI
- [ ] AI can defeat player
- [ ] Rematch functionality works
- [ ] No critical errors during play
