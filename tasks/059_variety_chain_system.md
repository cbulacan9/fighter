# Task 059: Variety Chain System

## Objective
Implement the Apothecary's core mechanic that rewards matching different tile types in sequence.

## Dependencies
- Task 045 (Character Data Resource)
- Task 030 (Status Effect Integration)

## Reference
- `/docs/CHARACTERS.md` → The Apothecary

## Overview
Each unique tile type matched in sequence adds 0.5x to a multiplier:
- Minimum 3 unique types for any bonus
- Multiplier applies to the first repeated tile type
- Chain resets after multiplier is applied

Example: Attack → Health → Mana → Empty Box → Attack = 2x multiplier on that Attack (4 unique × 0.5x)

## Deliverables

### 1. Create VarietyTracker Class
Create `/scripts/systems/variety_tracker.gd`:

```gdscript
class_name VarietyTracker extends RefCounted

signal chain_progressed(unique_count: int, multiplier: float)
signal multiplier_applied(tile_type: TileTypes.Type, multiplier: float)
signal chain_reset()

var _unique_types: Array[TileTypes.Type] = []
var _type_order: Array[TileTypes.Type] = []  # Full order including repeats
var _enabled: bool = true

const MIN_UNIQUE_FOR_BONUS = 3
const MULTIPLIER_PER_UNIQUE = 0.5

func record_match(tile_type: TileTypes.Type) -> Dictionary:
    """
    Record a tile match. Returns multiplier info if this match triggers bonus.
    """
    if not _enabled:
        return {"multiplier": 1.0, "applied": false}

    # Check if this is a repeat
    if _unique_types.has(tile_type):
        # This is a repeat - calculate and apply multiplier
        var unique_count = _unique_types.size()
        var multiplier = _calculate_multiplier(unique_count)

        var result = {
            "multiplier": multiplier,
            "applied": multiplier > 1.0,
            "unique_count": unique_count
        }

        if multiplier > 1.0:
            multiplier_applied.emit(tile_type, multiplier)

        # Reset chain
        reset()

        return result
    else:
        # New unique type - add to chain
        _unique_types.append(tile_type)
        _type_order.append(tile_type)

        chain_progressed.emit(_unique_types.size(), _calculate_multiplier(_unique_types.size()))

        return {"multiplier": 1.0, "applied": false}

func _calculate_multiplier(unique_count: int) -> float:
    if unique_count < MIN_UNIQUE_FOR_BONUS:
        return 1.0
    return 1.0 + (unique_count * MULTIPLIER_PER_UNIQUE)

func get_current_multiplier() -> float:
    return _calculate_multiplier(_unique_types.size())

func get_unique_count() -> int:
    return _unique_types.size()

func get_unique_types() -> Array[TileTypes.Type]:
    return _unique_types.duplicate()

func reset() -> void:
    _unique_types.clear()
    _type_order.clear()
    chain_reset.emit()

func set_enabled(enabled: bool) -> void:
    _enabled = enabled
    if not enabled:
        reset()
```

### 2. Integrate with BoardManager
Modify BoardManager to use VarietyTracker for Apothecary:

```gdscript
var _variety_tracker: VarietyTracker

func initialize_with_character(char_data: CharacterData, is_player: bool) -> void:
    # ... existing code ...

    # Setup variety tracker for Apothecary
    if char_data.character_id == "apothecary":
        _variety_tracker = VarietyTracker.new()
        _variety_tracker.multiplier_applied.connect(_on_variety_multiplier)

func _on_match_resolved(match_result: MatchResult) -> void:
    var multiplier = 1.0

    if _variety_tracker:
        var variety_result = _variety_tracker.record_match(match_result.tile_type)
        multiplier = variety_result.multiplier

    # Apply match effect with multiplier
    _apply_match_effect(match_result, multiplier)
```

### 3. Create Variety Chain UI Indicator
Create `/scripts/ui/variety_indicator.gd`:

```gdscript
class_name VarietyIndicator extends Control

@onready var chain_display: HBoxContainer = $ChainDisplay
@onready var multiplier_label: Label = $MultiplierLabel

var _tile_icons: Dictionary = {}  # {TileType: TextureRect}

func setup(variety_tracker: VarietyTracker) -> void:
    variety_tracker.chain_progressed.connect(_on_chain_progressed)
    variety_tracker.multiplier_applied.connect(_on_multiplier_applied)
    variety_tracker.chain_reset.connect(_on_chain_reset)

func _on_chain_progressed(unique_count: int, multiplier: float) -> void:
    multiplier_label.text = "%.1fx" % multiplier
    _update_chain_display()

func _on_multiplier_applied(tile_type: TileTypes.Type, multiplier: float) -> void:
    # Flash effect showing multiplier applied
    _show_multiplier_popup(multiplier)

func _on_chain_reset() -> void:
    _clear_chain_display()
    multiplier_label.text = "1.0x"
```

### 4. Extend EffectProcessor for Multiplied Effects
Ensure EffectProcessor can apply damage/effect multipliers:

```gdscript
func process_effect(effect: EffectData, source: Fighter, match_count: int = 0, multiplier: float = 1.0) -> void:
    # ... existing code ...

    var value = _calculate_value(effect, match_count)
    value = int(value * multiplier)

    # Apply effect with multiplied value
```

## Acceptance Criteria
- [ ] VarietyTracker tracks unique tile types matched
- [ ] Multiplier calculated correctly (0.5x per unique type)
- [ ] Minimum 3 unique types required for bonus
- [ ] First repeated type receives the multiplier
- [ ] Chain resets after multiplier applied
- [ ] UI shows current chain progress and potential multiplier
- [ ] Integration with BoardManager works
- [ ] Effects are properly multiplied
