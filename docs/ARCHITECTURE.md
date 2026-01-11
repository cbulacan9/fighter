# Puzzle Fighter - Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        GameManager                          │
│              (State Machine, Match Flow)                    │
└─────────────────┬───────────────────────────┬───────────────┘
                  │                           │
       ┌──────────▼──────────┐     ┌──────────▼──────────┐
       │   PlayerController  │     │    AIController     │
       │   (Human Input)     │     │   (AI Decision)     │
       └──────────┬──────────┘     └──────────┬──────────┘
                  │                           │
                  └─────────────┬─────────────┘
                                │
                  ┌─────────────▼─────────────┐
                  │       BoardManager        │
                  │  (Grid State, Tile Ops)   │
                  └─────────────┬─────────────┘
                                │
        ┌───────────┬───────────┼───────────┬───────────┐
        ▼           ▼           ▼           ▼           ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
   │  Grid   │ │  Match  │ │ Cascade │ │  Input  │ │  Tile   │
   │ System  │ │ Detector│ │ Handler │ │ Handler │ │ Spawner │
   └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘
                                │
                  ┌─────────────▼─────────────┐
                  │      CombatManager        │
                  │  (HP, Armor, Stun, FX)    │
                  └─────────────┬─────────────┘
                                │
                  ┌─────────────▼─────────────┐
                  │        UIManager          │
                  │ (HUD, Feedback, Screens)  │
                  └───────────────────────────┘
```

## Core Systems

| System | Responsibility |
|--------|----------------|
| **GameManager** | Match state machine (Countdown → Battle → End), round flow, pause |
| **BoardManager** | Owns grid state, coordinates tile operations, triggers match detection |
| **Grid** | 6x8 2D array of tile references, position math, wrapping logic |
| **InputHandler** | Drag detection, row/column movement, snap-back logic |
| **MatchDetector** | Scans for 3+ aligned tiles, returns match data (type, count, positions) |
| **CascadeHandler** | Processes tile removal, gravity fill, chain reaction loop |
| **TileSpawner** | Creates new tiles with weighted random type selection |
| **CombatManager** | Applies match effects (damage, heal, armor, stun), manages fighter state |
| **AIController** | Evaluates board, selects moves based on difficulty |
| **UIManager** | Health bars, damage numbers, stun overlay, victory/defeat screens |

## Data Flow

### Match Resolution Sequence
1. **InputHandler** detects drag release
2. **MatchDetector** scans for valid matches
3. If no match → **InputHandler** triggers snap-back animation
4. If match found → **BoardManager** locks input, processes match:
   - **CascadeHandler** removes matched tiles
   - **TileSpawner** fills empty spaces
   - **MatchDetector** checks for chain reactions (loop until stable)
5. **CombatManager** receives aggregated match data, applies effects
6. **UIManager** displays feedback (damage numbers, HP changes)
7. **BoardManager** unlocks input

### Combat Effect Flow
```
Match Data → CombatManager → Target Fighter State
                ↓
         Effect Resolution:
         - Sword → Damage (armor first, then HP)
         - Shield → Add armor (cap at max HP)
         - Potion → Heal (cap at max HP)
         - Lightning → Apply stun (diminishing returns)
                ↓
         UIManager → Visual Feedback
```

## Scene Hierarchy

```
Main (Node)
├── GameManager (Node)
├── CombatManager (Node)
│   ├── PlayerFighter (Resource/Node)
│   └── EnemyFighter (Resource/Node)
├── Boards (Node)
│   ├── PlayerBoard (BoardManager)
│   │   ├── Grid (Node2D)
│   │   │   └── Tiles (Node2D) [64 Tile instances]
│   │   ├── InputHandler (Node)
│   │   └── MatchDetector (Node)
│   └── EnemyBoard (BoardManager)
│       └── [Same structure, AI-controlled]
├── UIManager (CanvasLayer)
│   ├── PlayerHUD (Control)
│   ├── EnemyHUD (Control)
│   ├── GameOverlay (Control)
│   └── DamageNumbers (Node2D)
└── AIController (Node)
```

## State Machines

### GameManager States
| State | Description | Transitions |
|-------|-------------|-------------|
| **INIT** | Load resources, setup boards | → COUNTDOWN |
| **COUNTDOWN** | Display 3-2-1 timer | → BATTLE |
| **BATTLE** | Active gameplay, input enabled | → PAUSED, END |
| **PAUSED** | Input disabled, pause menu shown | → BATTLE |
| **END** | Victory/defeat determined | → STATS |
| **STATS** | Display match statistics | → INIT (rematch) |

### BoardManager States
| State | Description |
|-------|-------------|
| **IDLE** | Awaiting input |
| **DRAGGING** | Player actively moving row/column |
| **RESOLVING** | Processing matches and cascades |
| **STUNNED** | Input locked due to stun effect |

## Signal Communication

Key signals for decoupled communication:

| Signal | Emitter | Listeners |
|--------|---------|-----------|
| `match_found(match_data)` | MatchDetector | BoardManager, CombatManager |
| `cascade_complete` | CascadeHandler | BoardManager |
| `effect_applied(effect_type, value, target)` | CombatManager | UIManager |
| `fighter_defeated(fighter)` | CombatManager | GameManager |
| `stun_applied(target, duration)` | CombatManager | BoardManager, UIManager |
| `game_state_changed(new_state)` | GameManager | All systems |

## Resource Definitions

### TileData (Resource)
- `type`: Enum (SWORD, SHIELD, POTION, LIGHTNING, FILLER)
- `sprite`: Texture reference
- `match_values`: Array [3-match, 4-match, 5-match]

### FighterData (Resource)
- `max_hp`: int
- `tile_weights`: Dictionary {tile_type: spawn_weight}
- `portrait`: Texture reference

### MatchResult (Data Object)
- `tile_type`: TileType enum
- `count`: int (3-5, capped)
- `positions`: Array of Vector2i
- `effect_value`: int (looked up from TileData)

## Technical Decisions

| Decision | Rationale |
|----------|-----------|
| Separate BoardManager per player | Allows independent board states, easier AI integration |
| Signal-based communication | Loose coupling, easier testing and modification |
| Resources for static data | Godot-native, editor-friendly configuration |
| State machines for flow control | Clear state management, predictable behavior |
| Grid as 2D array | Simple indexing, efficient for 6x8 size |

## File Structure

```
project/
├── scenes/
│   ├── main.tscn
│   ├── board/
│   │   ├── board.tscn
│   │   └── tile.tscn
│   └── ui/
│       ├── hud.tscn
│       ├── damage_number.tscn
│       └── game_overlay.tscn
├── scripts/
│   ├── managers/
│   │   ├── game_manager.gd
│   │   ├── board_manager.gd
│   │   ├── combat_manager.gd
│   │   └── ui_manager.gd
│   ├── systems/
│   │   ├── grid.gd
│   │   ├── match_detector.gd
│   │   ├── cascade_handler.gd
│   │   ├── input_handler.gd
│   │   └── tile_spawner.gd
│   ├── controllers/
│   │   └── ai_controller.gd
│   ├── entities/
│   │   └── tile.gd
│   └── data/
│       ├── tile_data.gd
│       └── fighter_data.gd
├── resources/
│   ├── tiles/
│   └── fighters/
└── assets/
    ├── sprites/
    └── ui/
```
