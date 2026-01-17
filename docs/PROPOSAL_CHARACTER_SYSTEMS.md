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

### 4. Combo Sequences

**Purpose:** Track tile match order, reward specific patterns (Hunter's core mechanic).

**Requirements:**
- Track sequence of tile types matched
- Pattern matching against defined sequences
- Whiff detection (invalid match breaks sequence)
- Sequence banking (complete sequence persists until used)
- Visual indicator of current sequence progress
- Multiple valid sequences per character

**Data Structures:**

```gdscript
class_name SequencePattern extends Resource
@export var name: String
@export var pattern: Array[TileType]  # e.g., [PHYSICAL, SHIELD, SHIELD]
@export var terminator: TileType      # e.g., PET (must be clicked, not matched)
@export var on_complete: AbilityData

class_name SequenceTracker extends RefCounted
var _current_sequence: Array[TileType] = []
var _banked_sequences: Array[SequencePattern] = []
var _valid_patterns: Array[SequencePattern] = []

signal sequence_progressed(current: Array, possible_completions: Array)
signal sequence_completed(pattern: SequencePattern)
signal sequence_broken()
```

**Operations:**
| Operation | Description |
|-----------|-------------|
| `record_match(tile_type)` | Add to current sequence, check validity |
| `check_completion()` | See if current sequence matches any pattern |
| `bank_sequence(pattern)` | Store completed sequence for later activation |
| `activate_banked(pattern)` | Use a banked sequence (triggers ability) |
| `break_sequence()` | Reset current sequence (whiff) |
| `get_possible_patterns()` | Return patterns that could still complete |

**Whiff Logic:**
```
On match:
  1. Append tile_type to current_sequence
  2. Check if current_sequence is prefix of ANY valid pattern
  3. If no valid prefix exists → break_sequence()
  4. If exact match of pattern (minus terminator) → mark as completable
  5. On terminator click → bank or activate
```

**Integration Points:**
- BoardManager → SequenceTracker (on match resolved)
- SequenceTracker → UI (sequence progress display)
- SequenceTracker → Tile (enable terminator clickability)
- SequenceTracker → AbilitySystem (on activation)

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
│   ├── sequence_tracker.gd      # NEW
│   └── effect_processor.gd      # NEW (unified effect handling)
├── data/
│   ├── character_data.gd        # NEW
│   ├── mana_config.gd           # NEW
│   ├── status_effect_data.gd    # NEW
│   ├── sequence_pattern.gd      # NEW
│   ├── ability_data.gd          # NEW
│   └── tile_data.gd             # MODIFIED (add click support)
├── entities/
│   ├── tile.gd                  # MODIFIED (click handling)
│   └── fighter.gd               # MODIFIED (status effects integration)
├── ui/
│   ├── mana_bar.gd              # NEW
│   ├── sequence_indicator.gd    # NEW
│   └── status_effect_display.gd # NEW
└── managers/
    └── combat_manager.gd        # MODIFIED (effect processor integration)

resources/
├── characters/
│   ├── hunter.tres              # FUTURE
│   ├── assassin.tres            # FUTURE
│   ├── mirror_warden.tres       # FUTURE
│   └── apothecary.tres          # FUTURE
├── effects/
│   ├── poison.tres
│   ├── bleed.tres
│   └── ...
└── sequences/
    ├── bear_sequence.tres
    ├── hawk_sequence.tres
    └── snake_sequence.tres

test/
├── test_mana_system.gd          # NEW
├── test_status_effects.gd       # NEW
├── test_sequence_tracker.gd     # NEW
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
| **SequenceIndicator** | Shows current sequence progress, highlights next valid tiles |
| **StatusEffectBar** | Row of icons for active effects, stack count, duration |
| **ClickableHighlight** | Visual cue when tile is clickable (glow, pulse) |
| **AbilityButton** | For manual ability activation (if needed beyond tile clicks) |

### HUD Layout Update

```
┌─────────────────────────────────────────────┐
│  [Player HP Bar]         [Enemy HP Bar]     │
│  [Player Mana Bar(s)]    [Enemy Mana Bar(s)]│
│  [Status Effects]        [Status Effects]   │
│  [Sequence Indicator]                       │
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

**Recommendation:** Defer AI updates until Phase 6. For testing, AI can use simple random behavior.

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
| Can Pet tiles be matched? | **No.** Pet tiles can only be clicked, not matched. They serve purely as sequence terminators/activators. |
| Multi-bar mana drain | **Instant full drain.** Assassin's ultimate drains both bars instantly on activation. No partial activation. |
| Poison interactions | **Two distinct mechanics:** (1) Transmute poison = instant damage that scales if poison status is active; (2) Poison status = DoT that ticks over time. They synergize but are separate. |
| Character unlock criteria | **Beat to unlock.** Defeating a character as an AI opponent unlocks them for player use. |

### Implications for Implementation

**Pet Tiles (Click-Only):**
- `is_matchable = false`, `is_clickable = true`
- Grid logic must skip Pet tiles during match detection
- **Normal physics** — Pet tiles fall during cascades like other tiles
- Spawn rules: min 1, max 2 on board at all times

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
