# Task Plan: Hunter Combo System v2

**Status:** Approved
**Date:** 2026-01-18
**Tag:** v0.1.0-hunter (baseline before changes)

---

## Overview

Implement the multi-tree combo system for Hunter, replacing the linear match history approach with parallel combo trees and spawn-on-completion Pet tiles.

---

## Phase 1: Core Data Structures

### Task 1.1: MatchOrigin Enum
**File:** `scripts/data/tile_types.gd` (or new file)

Add:
```gdscript
enum MatchOrigin {
	PLAYER_INITIATED,  # Direct result of player's move
    CASCADE            # Result of gravity fill
}
```

### Task 1.2: Update MatchResult
**File:** `scripts/systems/match_detector.gd` or relevant data class

Add `origin: MatchOrigin` field to MatchResult. Default to PLAYER_INITIATED; CascadeHandler will tag CASCADE matches.

### Task 1.3: ComboTree Class
**File:** `scripts/data/combo_tree.gd` (NEW)

```gdscript
class_name ComboTree
extends RefCounted

var pattern: SequencePattern
var progress: int = 0
var matched_tiles: Array[int] = []

func next_required() -> int:
    return pattern.pattern[progress]

func is_complete() -> bool:
    return progress >= pattern.pattern.size()

func advance(tile_type: int) -> void:
    matched_tiles.append(tile_type)
    progress += 1
```

### Task 1.4: Add Pet Tile Types
**File:** `scripts/data/tile_types.gd`

Add to TileType enum:
```gdscript
BEAR_PET,
HAWK_PET,
SNAKE_PET
```

---

## Phase 2: SequenceTracker Rewrite

### Task 2.1: Rewrite SequenceTracker
**File:** `scripts/systems/sequence_tracker.gd` (REWRITE)

**Key changes:**
- Remove `_match_history` linear tracking
- Add `_active_trees: Array[ComboTree]`
- Implement `process_initiating_matches(tile_types: Array[int])`
- Trees advance or die individually
- Auto-complete when pattern fulfilled

**Signals:**
```gdscript
signal tree_started(pattern_name: String)
signal tree_progressed(pattern_name: String, progress: int, total: int)
signal tree_died(pattern_name: String)
signal sequence_completed(pet_type: int)  # PetType enum value
```

**Algorithm:**
```
1. For each active tree:
   - If next_required() in tile_types: advance tree
   - Else: kill tree (emit tree_died)
   - If tree.is_complete(): emit sequence_completed, remove tree

2. For each tile_type in input:
   - For each pattern starting with tile_type:
     - If no tree for this pattern at progress=1: create new tree
     - Check immediate completion
```

### Task 2.2: Update SequencePattern
**File:** `scripts/data/sequence_pattern.gd`

Add field:
```gdscript
@export var pet_type: int = -1  # TileTypes.Type.BEAR_PET, etc.
```

Remove or deprecate `terminator` field.

---

## Phase 3: Pet System

### Task 3.1: PetSpawner Component
**File:** `scripts/systems/pet_spawner.gd` (NEW)

```gdscript
class_name PetSpawner
extends Node

const MAX_PET_PER_TYPE: int = 3

var _pet_counts: Dictionary = {}  # {pet_type: count}

signal pet_spawned(pet_type: int, column: int)
signal pet_spawn_blocked(pet_type: int)
signal pet_activated(pet_type: int)

func _on_sequence_completed(pet_type: int) -> void:
    if _pet_counts.get(pet_type, 0) >= MAX_PET_PER_TYPE:
        pet_spawn_blocked.emit(pet_type)
        return

    var column := randi() % 8  # Grid.COLS
    pet_spawned.emit(pet_type, column)
    _pet_counts[pet_type] = _pet_counts.get(pet_type, 0) + 1

func _on_pet_clicked(pet_type: int) -> void:
    _pet_counts[pet_type] = maxi(_pet_counts.get(pet_type, 0) - 1, 0)
    pet_activated.emit(pet_type)

func get_count(pet_type: int) -> int:
    return _pet_counts.get(pet_type, 0)

func reset() -> void:
    _pet_counts.clear()
```

### Task 3.2: Pet Tile Resources
**Files:** `resources/tiles/bear_pet.tres`, `hawk_pet.tres`, `snake_pet.tres` (NEW)

Each resource:
```
tile_type = BEAR_PET / HAWK_PET / SNAKE_PET
is_matchable = false
is_clickable = true
click_condition = ALWAYS
```

### Task 3.3: Update Hunter Sequences
**Files:** `resources/sequences/bear_sequence.tres`, etc.

Update each:
- `bear_sequence.tres`: pattern = [SWORD, SHIELD, SHIELD], pet_type = BEAR_PET
- `hawk_sequence.tres`: pattern = [SHIELD, FOCUS], pet_type = HAWK_PET
- `snake_sequence.tres`: pattern = [FOCUS, SWORD, SHIELD], pet_type = SNAKE_PET

Remove Pet from TileSpawner weights for Hunter.

---

## Phase 4: BoardManager Integration

### Task 4.1: Tag Match Origins
**File:** `scripts/managers/board_manager.gd`

Modify match processing:
1. First `find_matches()` call after player move → tag as PLAYER_INITIATED
2. Subsequent `find_matches()` calls during cascade → tag as CASCADE

### Task 4.2: Filter Matches for SequenceTracker
**File:** `scripts/managers/board_manager.gd` or `game_manager.gd`

When passing matches to SequenceTracker:
```gdscript
var initiating_types: Array[int] = []
for match_result in cascade_result.all_matches:
    if match_result.origin == MatchOrigin.PLAYER_INITIATED:
        if match_result.tile_type not in initiating_types:
            initiating_types.append(match_result.tile_type)

sequence_tracker.process_initiating_matches(initiating_types)
```

### Task 4.3: Wire PetSpawner
**File:** `scripts/managers/game_manager.gd` or `board_manager.gd`

- Connect SequenceTracker.sequence_completed → PetSpawner._on_sequence_completed
- Connect PetSpawner.pet_spawned → BoardManager (add tile at column, row 0)
- Connect Pet tile click → PetSpawner._on_pet_clicked

---

## Phase 5: UI Components

### Task 5.1: ComboTreeDisplay
**File:** `scripts/ui/combo_tree_display.gd` (NEW)
**Scene:** `scenes/ui/combo_tree_display.tscn` (NEW)

**Structure:**
```
ComboTreeDisplay (Control)
├── VBox
│   ├── BearRow (HBox): Label + TileIcons[3]
│   ├── HawkRow (HBox): Label + TileIcons[2]
│   └── SnakeRow (HBox): Label + TileIcons[3]
```

**Behavior:**
- Default: All tile icons dimmed (modulate = 0.4)
- On `tree_started`: Brighten first icon of that sequence
- On `tree_progressed`: Brighten icon at progress index
- On `tree_died`: Red flash, dim all icons for that sequence
- On `sequence_completed`: Glow effect, then dim all

**Methods:**
```gdscript
func setup(sequence_tracker: SequenceTracker) -> void
func _on_tree_started(pattern_name: String) -> void
func _on_tree_progressed(pattern_name: String, progress: int, total: int) -> void
func _on_tree_died(pattern_name: String) -> void
func _on_sequence_completed(pet_type: int) -> void
func reset() -> void
```

### Task 5.2: PetPopulationDisplay
**File:** `scripts/ui/pet_population_display.gd` (NEW)
**Scene:** `scenes/ui/pet_population_display.tscn` (NEW)

**Structure:**
```
PetPopulationDisplay (Control)
├── HBox
│   ├── BearCounter: Icon + "0/3"
│   ├── HawkCounter: Icon + "0/3"
│   └── SnakeCounter: Icon + "0/3"
└── MaxPopLabel (hidden by default)
```

**Behavior:**
- Update counters on pet_spawned / pet_activated signals
- Flash "MAX POP" label for 1.5s on pet_spawn_blocked

**Methods:**
```gdscript
func setup(pet_spawner: PetSpawner) -> void
func _on_pet_spawned(pet_type: int, _column: int) -> void
func _on_pet_spawn_blocked(pet_type: int) -> void
func _on_pet_activated(pet_type: int) -> void
func _update_display() -> void
func _flash_max_pop(pet_type: int) -> void
```

### Task 5.3: Remove SequenceIndicator for Hunter
**Files:** HUD setup, game_manager.gd

- Do NOT instantiate SequenceIndicator when character is Hunter
- Instantiate ComboTreeDisplay + PetPopulationDisplay instead
- Keep SequenceIndicator code for potential use by other characters (or delete if unused)

---

## Phase 6: AI Updates

### Task 6.1: Hunter AI Combo Evaluation
**File:** `scripts/controllers/ai_controller.gd`

Add Hunter-specific move evaluation:

```gdscript
func _evaluate_hunter_move(move: Move, board: BoardManager) -> float:
    var score := 0.0

    # Simulate which tile types would be in initiating matches
    var simulated_types := _simulate_initiating_matches(move, board)

    # Check tree advancement
    for tree in sequence_tracker.get_active_trees():
        if tree.next_required() in simulated_types:
            # Reward advancing trees, more for trees closer to completion
            var completion_bonus := float(tree.progress) / float(tree.pattern.pattern.size())
            score += 10.0 + (completion_bonus * 20.0)

    # Check new tree starts
    for pattern in sequence_tracker.get_valid_patterns():
        if pattern.pattern[0] in simulated_types:
            score += 5.0

    return score
```

### Task 6.2: AI Pet Click Timing
**File:** `scripts/controllers/ai_controller.gd`

Add logic to decide when to click Pets:
- Easy: Click immediately when available
- Medium: Click when advantageous (low HP = prefer Snake, need damage = prefer Bear)
- Hard: Strategic banking based on game state

---

## Phase 7: Testing

### Task 7.1: SequenceTracker Tests
**File:** `test/test_sequence_tracker.gd`

Test cases:
- Single tree start and completion
- Multiple trees active simultaneously
- Individual tree death (others survive)
- Auto-complete on pattern match
- No duplicate trees for same pattern

### Task 7.2: PetSpawner Tests
**File:** `test/test_pet_spawner.gd`

Test cases:
- Pet spawns on sequence_completed
- Cap enforcement (3 per type)
- pet_spawn_blocked signal at cap
- Count decrements on activation
- Reset clears all counts

---

## Dependency Order

```
Phase 1 (Data) → Phase 2 (SequenceTracker) → Phase 3 (Pet System)
                                                    ↓
Phase 4 (BoardManager) ←────────────────────────────┘
         ↓
Phase 5 (UI) → Phase 6 (AI) → Phase 7 (Testing)
```

**Critical path:** 1.1 → 1.3 → 2.1 → 3.1 → 4.2 → 5.1

---

## Acceptance Criteria

- [ ] Cascades do not advance combo trees
- [ ] Multiple trees can be active; individual pruning works
- [ ] Pet tiles spawn from top on combo completion
- [ ] 3-per-type cap enforced with MAX POP feedback
- [ ] ComboTreeDisplay shows dim/bright states correctly
- [ ] PetPopulationDisplay shows accurate counts
- [ ] AI Hunter uses same combo system
- [ ] All tests pass

---

*End of Task Plan*
