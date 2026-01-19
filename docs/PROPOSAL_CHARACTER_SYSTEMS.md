# Proposal: Character Systems Implementation

**Status:** Draft - Pending Approval
**Date:** 2026-01-16

---

## Executive Summary

This proposal outlines the architectural changes required to implement the character system described in CHARACTERS.md. The approach is **core systems first**: build foundational mechanics (mana, clickable tiles, status effects, combo sequences) as independent, testable modules before implementing specific characters.

### Key Decisions (From Interview)

| Decision | Choice |
|----------|--------|
| Implementation approach | Core systems only (characters later) |
| Tile strategy | Hybrid: Sword/Shield/Potion shared, specialty tiles per-character |
| Multiplayer scope | AI opponents only |
| First character (later) | Hunter |
| Character selection | Unlockable roster |
| Status effect behavior | Flexible system, tune per-effect |
| Testing approach | Independent test harnesses per system |

---

## Architectural Overview

### Current State

```
TileTypes (enum) ──→ TileData (resource) ──→ Tile (entity)
						   │
					CombatManager
						   │
			  ┌────────────┼────────────┐
			  ▼            ▼            ▼
		   Damage       Healing       Stun
```

### Proposed State

```
CharacterData ──→ TileConfig[] ──→ TileData (resource) ──→ Tile (entity)
	 │                                    │
	 │                             ┌──────┴──────┐
	 │                             ▼             ▼
	 │                        Matchable     Clickable
	 │                             │             │
	 └──→ AbilityConfig[]         ▼             ▼
			  │              MatchEffect    ClickEffect
			  │                   │             │
			  ▼                   └──────┬──────┘
		 ManaConfig                      ▼
			  │                   EffectProcessor
			  ▼                          │
		 ManaSystem              ┌───────┼───────┐
								 ▼       ▼       ▼
							Damage   Status   Board
									 Effect   Manip
```

---

## Core Systems

### 1. Mana System

**Purpose:** Track mana accumulation from tile matches, trigger abilities at thresholds.

**Requirements:**
- Support 1-2 mana bars per character (Assassin has dual bars)
- Mana gained from matching designated tile types
- Threshold-based ability activation
- Drain on ability use (partial or full)
- Blockable by enemy effects (Assassin's Shadow Step blocks enemy mana)

**Data Structures:**

```gdscript
class_name ManaConfig extends Resource
@export var bar_count: int = 1
@export var max_mana: Array[int] = [100]  # Per bar
@export var mana_tile_types: Array[TileType] = []
@export var mana_per_match: Dictionary = {3: 10, 4: 20, 5: 35}

class_name ManaBar extends RefCounted
var current: int = 0
var max_value: int = 100
var is_blocked: bool = false
signal mana_changed(current, max_value)
signal threshold_reached(bar_index)
```

**Operations:**
| Operation | Description |
|-----------|-------------|
| `add_mana(bar_index, amount)` | Add mana, emit signal if threshold reached |
| `drain(bar_index, amount)` | Remove mana (for ability use) |
| `drain_all()` | Empty all bars (for ultimates requiring full bars) |
| `block(bar_index, duration)` | Prevent mana gain for duration |
| `is_full(bar_index)` | Check if bar at max |
| `are_all_full()` | Check if all bars full (ultimate condition) |

**Integration Points:**
- BoardManager → ManaSystem (on match, if tile is mana-generating)
- ManaSystem → UI (mana bar display)
- ManaSystem → AbilitySystem (threshold triggers)

---

### 2. Clickable Tiles

**Purpose:** Allow tiles to be activated by clicking, not just matching.

**Requirements:**
- Tiles have two interaction modes: matchable and/or clickable
- Click activation triggers an effect (distinct from match effect)
- Visual indicator for clickable state
- Cooldowns or conditions for click activation
- Some tiles only clickable when conditions met (e.g., Hunter's Pet after sequence)

**Data Structures:**

```gdscript
# Extension to TileData
class_name TileData extends Resource
@export var tile_type: TileType
@export var is_matchable: bool = true
@export var is_clickable: bool = false
@export var match_effect: EffectData
@export var click_effect: EffectData
@export var click_condition: ClickCondition  # Optional

enum ClickCondition {
	ALWAYS,           # Can always click
	SEQUENCE_COMPLETE, # Hunter's Pet
    MANA_FULL,        # Requires full mana
    COOLDOWN          # Time-based
}
```

**Tile State Machine Extension:**

```
         ┌──────────┐
         │  IDLE    │◄─────────────────┐
         └────┬─────┘                  │
              │                        │
    ┌─────────┼─────────┐              │
    ▼         ▼         ▼              │
DRAGGING  MATCHING  CLICKABLE          │
    │         │         │              │
    │         │         ▼              │
    │         │    ACTIVATING ─────────┘
    │         │
    └─────────┴────► CLEARING
```

**Operations:**
| Operation | Description |
|-----------|-------------|
| `can_click(tile)` | Check if tile is currently clickable |
| `activate(tile)` | Trigger click effect |
| `set_clickable(tile, bool)` | Enable/disable click state |

**Integration Points:**
- InputHandler → Tile (click detection, separate from drag)
- Tile → EffectProcessor (on activation)
- SequenceTracker → Tile (enable Pet clickability when sequence complete)

---

### 3. Status Effects

**Purpose:** Apply persistent effects (poison, bleed, buffs, debuffs) with duration and stacking.

**Requirements:**
- Effects have type, duration, stack count, and magnitude
- Tick-based processing (poison ticks, bleed on match, etc.)
- Stacking behavior configurable per effect type
- Visual indicators for active effects
- Cleansing mechanic (Hunter's Snake cleanses poison)
- Effects can target self or enemy

**Data Structures:**

```gdscript
class_name StatusEffectData extends Resource
@export var effect_type: StatusType
@export var duration: float = 0.0  # 0 = permanent until removed
@export var tick_interval: float = 1.0  # For DoT effects
@export var max_stacks: int = 99
@export var stack_behavior: StackBehavior

enum StatusType {
	POISON,      # DoT, ticks over time
	BLEED,       # Damage on enemy's next match
    DODGE,       # Chance to avoid next attack
    ATTACK_UP,   # Damage multiplier
    EVASION,     # Next attack auto-misses
    MANA_BLOCK,  # Prevent mana generation
}

enum StackBehavior {
    ADDITIVE,        # Stacks increase magnitude
    REFRESH,         # New application refreshes duration
    INDEPENDENT,     # Each stack tracks separately
    REPLACE,         # New application replaces old
}

class_name StatusEffect extends RefCounted
var data: StatusEffectData
var remaining_duration: float
var stacks: int = 1
var source: Fighter  # Who applied it
```

**StatusEffectManager:**

```gdscript
class_name StatusEffectManager extends Node

var _active_effects: Dictionary = {}  # {StatusType: Array[StatusEffect]}

func apply(target: Fighter, effect: StatusEffectData, stacks: int = 1)
func remove(target: Fighter, effect_type: StatusType)
func cleanse(target: Fighter, types: Array[StatusType] = [])
func tick(delta: float)
func get_modifier(type: StatusType) -> float  # For buff calculations
func has_effect(type: StatusType) -> bool
```

**Integration Points:**
- CombatManager → StatusEffectManager (apply effects from matches)
- StatusEffectManager → Fighter (damage ticks, modifiers)
- StatusEffectManager → UI (effect icons, duration display)
- Abilities → StatusEffectManager (cleanse, apply)

---

### 4. Combo Sequences (Hunter v2 — Multi-Tree System)

**Purpose:** Track tile match order with parallel combo trees, reward specific patterns (Hunter's core mechanic).

**Key Design Principles:**
- Only **player-initiated matches** count (pre-cascade); cascade matches are ignored for combo tracking
- Multiple combo trees can be active simultaneously
- Trees are pruned individually when contradicted (not all-or-nothing)
- Sequences auto-complete immediately when pattern is fulfilled
- Pet tiles spawn on completion (not always on board)

---

#### 4.1 Match Origin Tracking

BoardManager must distinguish player-initiated matches from cascade matches.

```gdscript
enum MatchOrigin {
	PLAYER_INITIATED,  # Direct result of player's move (pre-cascade)
    CASCADE            # Result of gravity fill
}

# Extension to MatchResult
class_name MatchResult extends RefCounted
var tile_type: TileType
var count: int
var positions: Array[Vector2i]
var effect_value: int
var origin: MatchOrigin  # NEW — tags where this match came from
```

**Data Flow:**
```
InputHandler.drag_released
        ↓
MatchDetector.find_matches() → tagged as PLAYER_INITIATED
        ↓
CascadeHandler.process_cascade()
        ↓
    ┌───┴───┐
    ↓       ↓
 Remove   Fill + Detect → tagged as CASCADE
        ↓
CascadeResult.all_matches (each tagged with origin)
        ↓
SequenceTracker receives ONLY PLAYER_INITIATED matches
CombatManager receives ALL matches (effects apply regardless of origin)
```

---

#### 4.2 Multi-Tree SequenceTracker

**Data Structures:**

```gdscript
class_name SequencePattern extends Resource
@export var name: String                    # "Bear", "Hawk", "Snake"
@export var pattern: Array[TileType]        # e.g., [PHYSICAL, SHIELD, SHIELD]
@export var pet_type: PetType               # Which Pet spawns on completion
@export var on_complete: AbilityData        # Ability triggered when Pet clicked

enum PetType {
    BEAR_PET,
    HAWK_PET,
    SNAKE_PET
}

class_name ComboTree extends RefCounted
var pattern: SequencePattern        # Which sequence this tree is tracking
var progress: int = 0               # Index into pattern.pattern array
var matched_tiles: Array[TileType]  # History for UI/debugging

func next_required() -> TileType:
    return pattern.pattern[progress]

func is_complete() -> bool:
    return progress >= pattern.pattern.size()

class_name SequenceTracker extends Node
var _active_trees: Array[ComboTree] = []
var _all_patterns: Array[SequencePattern] = []

signal tree_started(pattern_name: String)
signal tree_progressed(pattern_name: String, progress: int, total: int)
signal tree_died(pattern_name: String)
signal sequence_completed(pet_type: PetType)
```

**Core Algorithm:**

```gdscript
func process_initiating_matches(tile_types: Array[TileType]) -> void:
    # Step 1: Advance or kill existing trees
    for tree in _active_trees.duplicate():  # Duplicate to allow removal during iteration
        if tree.next_required() in tile_types:
            tree.progress += 1
            tree.matched_tiles.append(tree.next_required())
            emit_signal("tree_progressed", tree.pattern.name, tree.progress, tree.pattern.pattern.size())

            # Check for immediate completion (auto-complete)
            if tree.is_complete():
                emit_signal("sequence_completed", tree.pattern.pet_type)
                _active_trees.erase(tree)
        else:
            # Tree contradicted — kill it individually
            emit_signal("tree_died", tree.pattern.name)
            _active_trees.erase(tree)

    # Step 2: Start new trees for any tile that begins a pattern
    for tile_type in tile_types:
        for pattern in _all_patterns:
            if pattern.pattern[0] == tile_type:
				# Don't duplicate if tree for this pattern already at position 1
				if not _has_tree_at_start(pattern):
					var new_tree = ComboTree.new()
					new_tree.pattern = pattern
					new_tree.progress = 1
					new_tree.matched_tiles = [tile_type]
					_active_trees.append(new_tree)
					emit_signal("tree_started", pattern.name)

					# Check immediate completion (single-tile pattern edge case)
					if new_tree.is_complete():
						emit_signal("sequence_completed", new_tree.pattern.pet_type)
						_active_trees.erase(new_tree)
```

**Operations:**
| Operation | Description |
|-----------|-------------|
| `process_initiating_matches(types)` | Core algorithm — advance/kill trees, start new trees |
| `get_active_trees()` | Returns current tree states for UI |
| `get_possible_next_tiles()` | Returns tile types that would advance any active tree |
| `reset()` | Clears all active trees |

---

#### 4.3 Pet Tile System (Spawn on Completion)

Pet tiles are **not** in the random spawn pool. They spawn only when combos complete.

**TileTypes Extension:**
```gdscript
enum TileType {
	# ... existing types ...
	BEAR_PET,    # Spawns on Bear combo completion
	HAWK_PET,    # Spawns on Hawk combo completion
	SNAKE_PET    # Spawns on Snake combo completion
}
```

**Pet Tile Properties (all three types):**
```gdscript
is_matchable = false   # Cannot be matched — click only
is_clickable = true    # Always clickable when on board
click_condition = ALWAYS
```

**PetSpawner Component:**

```gdscript
class_name PetSpawner extends Node

const MAX_PET_PER_TYPE: int = 3

var _pet_counts: Dictionary = {
	PetType.BEAR_PET: 0,
	PetType.HAWK_PET: 0,
	PetType.SNAKE_PET: 0
}

signal pet_spawned(pet_type: PetType, column: int)
signal pet_spawn_blocked(pet_type: PetType)  # Cap reached

func _on_sequence_completed(pet_type: PetType) -> void:
	if _pet_counts[pet_type] >= MAX_PET_PER_TYPE:
		emit_signal("pet_spawn_blocked", pet_type)
		return

	var column = randi() % Grid.COLS
	emit_signal("pet_spawned", pet_type, column)
	_pet_counts[pet_type] += 1

func _on_pet_activated(pet_type: PetType) -> void:
	_pet_counts[pet_type] -= 1
```

**Spawn Rules:**
| Rule | Value |
|------|-------|
| **Trigger** | `sequence_completed` signal |
| **Position** | Random column, row 0 (top) |
| **Physics** | Normal gravity — falls and settles into grid |
| **Cap per type** | 3 maximum on board |
| **Cap behavior** | Combo completes but no Pet spawns; UI shows "MAX POP" feedback |

---

#### 4.4 Hunter Sequences

| Ability | Sequence | Pet Type | Notes |
|---------|----------|----------|-------|
| **Bear** | Physical → Shield → Shield | BEAR_PET | Starts with Physical (unique) |
| **Hawk** | Shield → Focus | HAWK_PET | Starts with Shield (unique) |
| **Snake** | Focus → Physical → Shield | SNAKE_PET | Starts with Focus (unique) |

**Design Note:** All sequences have unique starting tiles, preventing ambiguous tree creation from a single match. However, if a player matches multiple tile types simultaneously (e.g., Physical + Shield), multiple trees will start in parallel.

---

#### 4.5 Integration Points

- **BoardManager → SequenceTracker:** Pass only PLAYER_INITIATED match types
- **SequenceTracker → PetSpawner:** On `sequence_completed`, spawn Pet
- **PetSpawner → BoardManager:** Add Pet tile at spawn position
- **Tile (Pet click) → AbilitySystem:** Trigger ability
- **Tile (Pet click) → PetSpawner:** Decrement count
- **SequenceTracker → UI (ComboTreeDisplay):** Tree state changes
- **PetSpawner → UI (PetPopulationDisplay):** Count changes, cap feedback

---

## Character Data Architecture

### CharacterData Resource

```gdscript
class_name CharacterData extends Resource

@export var character_id: String
@export var display_name: String
@export var archetype: String  # "Brawler", "Stun Heavy", "Tank", "Status Effect"

# Tiles
@export var basic_tiles: Array[TileData]      # Shared + character basics
@export var specialty_tiles: Array[TileData]  # Character-unique

# Tile spawn weights (overrides defaults)
@export var spawn_weights: Dictionary = {}

# Mana configuration
@export var mana_config: ManaConfig

# Abilities
@export var passive_abilities: Array[AbilityData]
@export var active_abilities: Array[AbilityData]  # Tied to specialty tiles
@export var ultimate_ability: AbilityData

# Combo sequences (if applicable)
@export var sequences: Array[SequencePattern]

# Visual
@export var portrait: Texture2D
@export var tile_sprites: Dictionary  # {TileType: Texture2D}
```

### Shared vs Character-Specific Tiles

| Category | Tiles | Notes |
|----------|-------|-------|
| **Shared (All Characters)** | Physical Attack, Shield, Health/Potion | Same mechanics, possibly different sprites |
| **Shared (Optional)** | Stun, Empty Box, Mana | Available to characters that use them |
| **Character-Specific** | Smoke Bomb, Shadow Step, Pet, Reflection, Cancel, Absorb, Poison, Potion (Apothecary) | Unique mechanics |

---

## File Structure (New/Modified)

```
scripts/
├── systems/
│   ├── mana_system.gd           # NEW
│   ├── status_effect_manager.gd # NEW
│   ├── sequence_tracker.gd      # NEW (multi-tree design)
│   ├── pet_spawner.gd           # NEW (spawns Pets on combo completion)
│   └── effect_processor.gd      # NEW (unified effect handling)
├── data/
│   ├── character_data.gd        # NEW
│   ├── mana_config.gd           # NEW
│   ├── status_effect_data.gd    # NEW
│   ├── sequence_pattern.gd      # NEW (includes pet_type field)
│   ├── combo_tree.gd            # NEW (tracks individual tree progress)
│   ├── ability_data.gd          # NEW
│   └── tile_data.gd             # MODIFIED (add click support, MatchOrigin)
├── entities/
│   ├── tile.gd                  # MODIFIED (click handling)
│   └── fighter.gd               # MODIFIED (status effects integration)
├── ui/
│   ├── mana_bar.gd              # NEW
│   ├── combo_tree_display.gd    # NEW (replaces sequence_indicator for Hunter)
│   ├── pet_population_display.gd # NEW (0/3 counters + MAX POP)
│   ├── status_effect_display.gd # NEW
│   └── sequence_indicator.gd    # REMOVE (replaced by combo_tree_display for Hunter)
├── controllers/
│   └── ai_controller.gd         # MODIFIED (Hunter combo/Pet logic)
└── managers/
	├── board_manager.gd         # MODIFIED (MatchOrigin tagging)
	└── combat_manager.gd        # MODIFIED (effect processor integration)

resources/
├── characters/
│   ├── hunter.tres              # FUTURE
│   ├── assassin.tres            # FUTURE
│   ├── mirror_warden.tres       # FUTURE
│   └── apothecary.tres          # FUTURE
├── tiles/
│   ├── bear_pet.tres            # NEW (click-only Pet tile)
│   ├── hawk_pet.tres            # NEW (click-only Pet tile)
│   └── snake_pet.tres           # NEW (click-only Pet tile)
├── effects/
│   ├── poison.tres
│   ├── bleed.tres
│   └── ...
└── sequences/
	├── bear_sequence.tres       # MODIFIED (pet_type: BEAR_PET)
	├── hawk_sequence.tres       # MODIFIED (pet_type: HAWK_PET)
	└── snake_sequence.tres      # MODIFIED (pet_type: SNAKE_PET)

scenes/
└── ui/
	├── combo_tree_display.tscn  # NEW
	└── pet_population_display.tscn # NEW

test/
├── test_mana_system.gd          # NEW
├── test_status_effects.gd       # NEW
├── test_sequence_tracker.gd     # NEW (multi-tree tests)
├── test_pet_spawner.gd          # NEW
└── test_clickable_tiles.gd      # NEW
```

---

## Implementation Phases

### Phase 1: Status Effects
**Rationale:** Foundation for many character abilities. Cleanest to implement in isolation.

1. Create StatusEffectData resource
2. Implement StatusEffectManager
3. Integrate with Fighter (apply/remove, damage ticks)
4. Create test harness
5. Add UI indicators

**Deliverables:**
- Poison effect working (DoT)
- Buff effect working (Attack Up)
- Visual indicators
- Passing tests

### Phase 2: Mana System
**Rationale:** Required for ultimates and some specialty tiles.

1. Create ManaConfig resource
2. Implement ManaSystem (supports 1-2 bars)
3. Integrate with BoardManager (mana from matches)
4. Create ManaBar UI component
5. Create test harness

**Deliverables:**
- Mana accumulation from designated tiles
- Threshold detection
- Mana blocking
- UI display
- Passing tests

### Phase 3: Clickable Tiles
**Rationale:** Required for specialty tile activation.

1. Extend TileData with click properties
2. Modify InputHandler for click vs drag detection
3. Implement click activation flow
4. Add visual indicators for clickable state
5. Create test harness

**Deliverables:**
- Tiles can be clicked to activate
- Click effects trigger
- Conditions system (always, cooldown, etc.)
- Passing tests

### Phase 4: Combo Sequences
**Rationale:** Hunter-specific but architecturally interesting. Builds on previous systems.

1. Create SequencePattern resource
2. Implement SequenceTracker
3. Integrate with BoardManager (record matches)
4. Implement whiff detection
5. Implement sequence banking
6. Create sequence indicator UI
7. Create test harness

**Deliverables:**
- Sequence tracking working
- Whiff breaks sequence
- Banking and activation
- UI indicator
- Passing tests

### Phase 5: Character Framework + Basic Starter
**Rationale:** Tie systems together into character-selectable structure. Basic character validates framework without new mechanics.

1. Create CharacterData resource
2. Implement character loading in GameManager
3. Create character select screen (basic)
4. Modify BoardManager to use character tile config
5. Integrate all systems with character context
6. Create "Basic" starter character using MVP tiles
7. Implement unlock tracking (save/load)

**Deliverables:**
- CharacterData defines complete character
- Character selection works
- Systems respect character configuration
- Basic starter character playable
- Unlock system functional

### Phase 6: First Advanced Character (Hunter)
**Rationale:** Exercises all systems, most complex tile interactions.

1. Create Hunter character data
2. Implement Pet tile behavior
3. Implement Bear/Hawk/Snake abilities
4. Implement Alpha Command ultimate
5. AI support for Hunter opponent

---

## UI Requirements

### New UI Components

| Component | Description |
|-----------|-------------|
| **ManaBar(s)** | 1-2 bars below health, fill animation, threshold indicator |
| **ComboTreeDisplay** | Shows all three sequences with dim/bright states (Hunter only) |
| **PetPopulationDisplay** | Shows `0/3 BEAR  0/3 HAWK  0/3 SNAKE` counters (Hunter only) |
| **StatusEffectBar** | Row of icons for active effects, stack count, duration |
| **ClickableHighlight** | Visual cue when tile is clickable (glow, pulse) |
| **AbilityButton** | For manual ability activation (if needed beyond tile clicks) |

### ComboTreeDisplay (Hunter-Specific) — Replaces SequenceIndicator

**Replaces:** The existing `SequenceIndicator` (match history bar showing last 10 tiles as colored blocks) is **removed** for Hunter. The multi-tree system requires showing combo progress per-sequence, not a linear history.

Displays all three combo sequences with visual feedback for tree states.

**Layout:**
```
┌─────────────────────────────────────┐
│  BEAR:  [⚔️] → [🛡️] → [🛡️]          │
│  HAWK:  [🛡️] → [⚡]                  │
│  SNAKE: [⚡] → [⚔️] → [🛡️]          │
└─────────────────────────────────────┘
```

**Visual States:**
| State | Appearance |
|-------|------------|
| **Inactive** | All tiles dimmed (default) |
| **Tree started** | First matched tile brightens |
| **Tree progressed** | Additional tiles brighten left-to-right |
| **Tree completed** | Brief glow → all tiles dim → Pet spawns |
| **Tree killed** | Red flash/shake → tiles dim |

**Signals Consumed:**
- `tree_started` → Brighten first tile
- `tree_progressed` → Brighten tile at progress index
- `tree_died` → Red flash, dim all
- `sequence_completed` → Glow effect, dim

### PetPopulationDisplay (Hunter-Specific)

Shows current Pet counts with cap feedback.

**Layout:**
```
┌─────────────────────────┐
│  🐻 0/3  🦅 0/3  🐍 0/3  │
└─────────────────────────┘
```

**States:**
| State | Display |
|-------|---------|
| **Normal** | `{icon} {count}/3` for each type |
| **Pet spawned** | Increment counter, brief highlight |
| **Pet activated** | Decrement counter |
| **Cap reached** | Flash `MAX POP` overlay on blocked type |

### HUD Layout Update

```
┌─────────────────────────────────────────────┐
│  [Player HP Bar]         [Enemy HP Bar]     │
│  [Player Mana Bar(s)]    [Enemy Mana Bar(s)]│
│  [Status Effects]        [Status Effects]   │
│  [Combo Tree Display]    (Hunter only)      │
│  [Pet Population]        (Hunter only)      │
│  [Player Portrait]       [Enemy Portrait]   │
├─────────────────────────────────────────────┤
│                                             │
│              6 × 8 GAME BOARD               │
│                                             │
└─────────────────────────────────────────────┘
```

---

## AI Considerations

The AI will need updates to handle:

1. **Mana awareness** - Prioritize/avoid mana tiles based on state
2. **Sequence building** - For characters with sequences, AI must plan matches
3. **Status effect response** - Cleanse when poisoned, apply pressure when enemy stunned
4. **Ability timing** - Know when to activate abilities vs save mana
5. **Character-specific strategies** - Different AI profiles per character

### Hunter AI (Multi-Tree System)

**Constraint:** AI Hunter uses the identical SequenceTracker and combo mechanics as the player. No simplified logic.

**Move Evaluation Factors:**
| Factor | Description |
|--------|-------------|
| `tree_advancement_score` | Points for moves that progress active trees |
| `tree_start_score` | Points for moves that start new trees |
| `completion_proximity` | Higher score for trees close to completion |
| `pet_activation_priority` | When to click available Pets |

**Decision Flow:**
1. Get all possible moves (row/column shifts)
2. For each move, simulate which tile types would be in initiating matches
3. Score based on combat value + tree advancement value
4. Select move (with difficulty-based randomness)

**Difficulty Scaling:**
| Difficulty | Combo Behavior | Pet Timing |
|------------|----------------|------------|
| **Easy** | Random moves, ignores tree state | Clicks Pets immediately |
| **Medium** | Prefers tree-advancing moves | Reasonable Pet timing |
| **Hard** | Optimal combo pursuit | Strategic Pet banking |

**Recommendation:** AI Hunter implementation required in Phase 6. No deferral — same system as player.

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| System interdependencies cause integration issues | High | Test harnesses per system, clear interfaces |
| Click vs drag detection conflicts | Medium | Implement with clear gesture thresholds |
| Sequence tracking performance | Low | Optimize only if measured as problem |
| Scope creep during character implementation | High | Strict adherence to CHARACTERS.md spec |
| AI complexity explosion | Medium | Defer AI sophistication, start simple |

---

## Design Clarifications

| Question | Answer |
|----------|--------|
| Can Pet tiles be matched? | **No.** Pet tiles can only be clicked, not matched. They are skipped during match detection. |
| When do Pet tiles appear? | **On combo completion.** Pets spawn from a random column at the top when their sequence completes. They are NOT in the random spawn pool. |
| How many Pets can exist? | **3 per type maximum.** If cap reached, combo completes but no Pet spawns (UI shows MAX POP). |
| Are there distinct Pet types? | **Yes.** Three separate tile types: BEAR_PET, HAWK_PET, SNAKE_PET — each with unique sprite. |
| What counts for combos? | **Only player-initiated matches (pre-cascade).** Cascade matches apply combat effects but do NOT advance combo trees. |
| Multi-bar mana drain | **Instant full drain.** Assassin's ultimate drains both bars instantly on activation. No partial activation. |
| Poison interactions | **Two distinct mechanics:** (1) Transmute poison = instant damage that scales if poison status is active; (2) Poison status = DoT that ticks over time. They synergize but are separate. |
| Character unlock criteria | **Beat to unlock.** Defeating a character as an AI opponent unlocks them for player use. |

### Implications for Implementation

**Pet Tiles (Click-Only, Spawn on Completion):**
- `is_matchable = false`, `is_clickable = true`
- Grid logic must skip Pet tiles during match detection
- **Normal physics** — Pet tiles fall with gravity and settle into grid
- **NOT in spawn pool** — Only created by PetSpawner on `sequence_completed`
- **Three distinct types:** BEAR_PET, HAWK_PET, SNAKE_PET
- **Cap:** Maximum 3 of each type on board; combo still completes if cap reached but no Pet spawns

**Match Origin Tagging:**
- BoardManager must tag MatchResult with `origin: MatchOrigin`
- PLAYER_INITIATED = direct result of player's move (first match detection)
- CASCADE = result of gravity fill (subsequent match detections)
- SequenceTracker receives ONLY PLAYER_INITIATED matches
- CombatManager receives ALL matches (both origins apply effects)

**Multi-Tree Combo Tracking:**
- Multiple trees can be active simultaneously
- Trees are pruned individually (not all-or-nothing)
- Same tile type can exist at different positions in different trees
- Sequences auto-complete immediately when pattern fulfilled

**Instant Mana Drain:**
- `drain_all()` is atomic operation
- UI should animate both bars draining simultaneously
- No edge case for "what if one bar is full but not the other" — ultimate simply unavailable

**Poison System:**
- `StatusType.POISON` — DoT effect, ticks damage over time, stackable
- `StatusType.TRANSMUTE_POISON` — Board tile state (enemy tiles marked as poisoned)
- When enemy matches transmute-poisoned tiles:
  - Base instant damage applied
  - If enemy has POISON status active, damage multiplied/increased
- This creates Apothecary's synergy loop: apply poison status → transmute → big damage

**Unlock System:**
- Track defeated opponents in save data
- Character select screen shows locked/unlocked state
- **Starter character:** New "basic" character using MVP tile mechanics (Sword, Shield, Potion, Lightning, Filler)
- All 4 designed characters (Hunter, Assassin, Mirror Warden, Apothecary) start locked
- Defeating an AI opponent unlocks that character for player use

**Basic Starter Character (New):**
- Uses existing MVP tile set — no new systems required
- Serves as tutorial/onboarding character
- No specialty tiles, no mana, no sequences
- Simple ultimate: could be a powerful version of existing effects (e.g., "deals 50 damage" or "heals 50 HP")
- Design TBD — consider a "Squire" or "Recruit" archetype

---

## Approval

- [ ] Architecture approach approved
- [ ] Phase order approved
- [x] Open questions answered (see Design Clarifications above)
- [ ] Ready to proceed with Phase 1

---

*End of Proposal*
