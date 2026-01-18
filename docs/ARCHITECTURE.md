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
				  │    Distributed UI Layer   │
				  │  (HUD, Overlays, Screens) │
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
| **StatsTracker** | Collects match statistics (damage, healing, chains, duration) |

### UI Components (Distributed Pattern)
| Component | Responsibility |
|-----------|----------------|
| **HUD** | Health bars, armor display, fighter portraits, mana bars, status effects |
| **DamageNumberSpawner** | Spawns floating damage/heal/armor/stun/miss numbers |
| **StunOverlay** | Grey overlay on stunned board with timer display |
| **GameOverlay** | Countdown, pause menu, victory/defeat splash |
| **StatsScreen** | End-of-match statistics display |
| **StatusEffectDisplay** | Shows active status effects with icons and duration |
| **AbilityAnnouncementSpawner** | Spawns floating announcements for PET ability activations |

## Data Flow

### Match Resolution Sequence
1. **InputHandler** detects drag release
2. **MatchDetector** scans for valid matches
3. If no match → **InputHandler** triggers snap-back animation
4. If match found → **BoardManager** locks input, processes match:
   - **CascadeHandler** detects matches, emits `matches_processed` **IMMEDIATELY**
   - **BoardManager** emits `immediate_matches` → **CombatManager** applies effects
   - **UI reacts instantly** (damage numbers spawn, health bars update)
   - **CascadeHandler** plays tile removal animations
   - **TileSpawner** fills empty spaces with animations
   - **MatchDetector** checks for chain reactions (loop until stable)
5. `cascade_complete` emits → Stats recorded
6. **BoardManager** unlocks input

**Key Change:** Effects apply immediately when matches are detected, before animations complete. This provides responsive gameplay feedback.

### Combat Effect Flow
```
Match Data → CombatManager → Target Fighter State
				│
		 Effect Resolution:
		 - Sword → Damage (armor first, then HP)
		 - Shield → Add armor (cap at max HP)
		 - Potion → Heal (cap at max HP)
		 - Lightning → Apply stun (diminishing returns)
				│
				├──→ Fighter.hp_changed ──→ HUD (health bar update)
				├──→ damage_dealt ────────→ DamageNumberSpawner
				├──→ healing_done ────────→ DamageNumberSpawner
				├──→ armor_gained ────────→ DamageNumberSpawner
				└──→ stun_applied ────────→ GameManager → StunOverlay
```

## Scene Hierarchy

```
Main (Node)
├── GameManager (Node)
│   └── [Coordinates all systems, holds UI references]
├── CombatManager (Node)
│   ├── player_fighter (Fighter instance)
│   └── enemy_fighter (Fighter instance)
├── Boards (Node2D)
│   ├── EnemyBoard (BoardManager)
│   │   └── [Grid, InputHandler, MatchDetector, etc.]
│   └── PlayerBoard (BoardManager)
│       └── [Grid, InputHandler, MatchDetector, etc.]
├── AIController (Node)
└── UI (CanvasLayer)
	├── HUD (Control)
	│   ├── PlayerPanel (HealthBar, Portrait)
	│   └── EnemyPanel (HealthBar, Portrait)
	├── PlayerStunOverlay (StunOverlay)
	├── EnemyStunOverlay (StunOverlay)
	├── DamageNumbers (DamageNumberSpawner)
	├── GameOverlay (CanvasLayer)
	│   ├── CountdownPanel
	│   ├── PausePanel
	│   └── ResultPanel
	└── StatsScreen (CanvasLayer)
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

### Game Flow Signals
| Signal | Emitter | Listeners |
|--------|---------|-----------|
| `state_changed(new_state)` | GameManager | All systems |
| `immediate_matches(matches)` | BoardManager | GameManager (applies combat effects immediately) |
| `matches_resolved(cascade_result)` | BoardManager | GameManager (stats recording) |
| `match_ended(winner_id)` | CombatManager | GameManager |

### Combat Signals
| Signal | Emitter | Listeners |
|--------|---------|-----------|
| `damage_dealt(target, result)` | CombatManager | GameManager, DamageNumberSpawner |
| `healing_done(target, amount)` | CombatManager | GameManager, DamageNumberSpawner |
| `armor_gained(target, amount)` | CombatManager | DamageNumberSpawner |
| `stun_applied(target, duration)` | CombatManager | GameManager |
| `stun_ended(fighter)` | CombatManager | GameManager |
| `damage_dodged(target, source)` | CombatManager | DamageNumberSpawner |
| `status_damage_dealt(target, damage, effect_type)` | CombatManager | DamageNumberSpawner |

### Fighter Signals
| Signal | Emitter | Listeners |
|--------|---------|-----------|
| `hp_changed(current, max_hp)` | Fighter | HUD |
| `armor_changed(current)` | Fighter | HUD |

### UI Signals (User Actions)
| Signal | Emitter | Listeners |
|--------|---------|-----------|
| `countdown_finished` | GameOverlay | GameManager |
| `resume_pressed` | GameOverlay | GameManager |
| `quit_pressed` | GameOverlay | GameManager |
| `continue_pressed` | GameOverlay | GameManager |
| `rematch_pressed` | StatsScreen | GameManager |

### Signal Wiring Location
Signal connections are established in two places:
1. **GameManager._connect_signals()** — Connects to CombatManager, BoardManager, GameOverlay, StatsScreen
2. **Component.setup()** methods — HUD and DamageNumberSpawner connect to their data sources during setup

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
| Distributed UI components | Each UI element is self-contained with own logic; GameManager coordinates via setup() calls and signal connections; avoids monolithic UIManager |
| StunOverlay per board | Separate overlay instances allow independent stun states for player/enemy |
| HUD connects to Fighter signals | Direct connection reduces indirection; Fighter owns HP/armor state |
| DamageNumberSpawner listens to CombatManager | Centralizes visual feedback spawning for all effect types |

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
│       ├── health_bar.tscn
│       ├── damage_number.tscn
│       ├── game_overlay.tscn
│       ├── stats_screen.tscn
│       └── stun_overlay.tscn
├── scripts/
│   ├── managers/
│   │   ├── game_manager.gd
│   │   ├── board_manager.gd
│   │   └── combat_manager.gd
│   ├── systems/
│   │   ├── grid.gd
│   │   ├── match_detector.gd
│   │   ├── cascade_handler.gd
│   │   ├── input_handler.gd
│   │   ├── tile_spawner.gd
│   │   └── stats_tracker.gd
│   ├── controllers/
│   │   └── ai_controller.gd
│   ├── entities/
│   │   ├── tile.gd
│   │   └── fighter.gd
│   ├── ui/
│   │   ├── hud.gd
│   │   ├── health_bar.gd
│   │   ├── damage_number.gd
│   │   ├── damage_number_spawner.gd
│   │   ├── game_overlay.gd
│   │   ├── stats_screen.gd
│   │   ├── stun_overlay.gd
│   │   ├── status_effect_display.gd
│   │   ├── status_effect_icon.gd
│   │   ├── ability_announcement.gd
│   │   └── ability_announcement_spawner.gd
│   └── data/
│       ├── tile_data.gd
│       ├── tile_types.gd
│       └── fighter_data.gd
├── resources/
│   ├── tiles/
│   └── fighters/
└── assets/
	├── sprites/
	└── ui/
```
