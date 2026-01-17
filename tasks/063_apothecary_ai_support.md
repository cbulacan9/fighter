# Task 063: Apothecary AI Support

## Objective
Extend AI controller to play Apothecary character effectively with variety chain optimization and poison strategy.

## Dependencies
- Task 062 (Transmute Ultimate)
- Task 014 (AI Controller)

## Reference
- `/docs/SYSTEMS.md` → AI Controller
- `/docs/CHARACTERS.md` → Apothecary

## Deliverables

### 1. Extend AIController for Apothecary
Add Apothecary-specific logic:

```gdscript
func _evaluate_moves() -> Array:
    if _is_apothecary():
        return _evaluate_apothecary_moves()
    # ... other character checks ...

func _is_apothecary() -> bool:
    return _character_data and _character_data.character_id == "apothecary"
```

### 2. Variety Chain-Aware Move Evaluation
Apothecary AI should:
- Prioritize matches that add unique types to the chain
- Avoid repeating types until chain is large enough
- Value the multiplied match appropriately

```gdscript
var _variety_tracker: VarietyTracker

func _evaluate_apothecary_moves() -> Array:
    var moves: Array = []
    var current_unique = _variety_tracker.get_unique_types()

    for move in _get_all_possible_moves():
        var score = _score_apothecary_move(move, current_unique)
        moves.append({"move": move, "score": score})

    return moves

func _score_apothecary_move(move, current_unique: Array) -> float:
    var score: float = 0.0
    var result = _simulate_move(move)

    for match_result in result.matches:
        var tile_type = match_result.tile_type
        var base_value = _get_match_value(match_result)

        if current_unique.has(tile_type):
            # This is a repeat - check if multiplier is worth it
            var potential_multiplier = _variety_tracker.get_current_multiplier()
            if potential_multiplier >= 2.0:  # Worth using now
                score += base_value * potential_multiplier
            else:
                score -= 20.0  # Penalty for wasting chain too early
        else:
            # New unique type - good for building chain
            score += base_value + 30.0  # Bonus for variety

    return score
```

### 3. Specialty Tile Click Decision
When to click Poison Vial:
- When mana is charging toward ultimate
- When enemy doesn't have much poison yet
- To stack poison before Transmute

When to click Healing Elixir:
- When board has many filler tiles
- When low on health
- To set up health matches

```gdscript
func _should_click_poison() -> bool:
    var poison_tiles = _get_tiles_of_type(TileTypes.Type.POISON_TILE)
    if poison_tiles.is_empty():
        return false

    var enemy = _get_enemy_fighter()
    if not enemy:
        return false

    # Click poison if enemy has low poison stacks
    var enemy_poison = _status_manager.get_stacks(enemy, StatusTypes.StatusType.POISON)
    if enemy_poison < 3:
        return randf() < 0.7  # 70% chance

    return false

func _should_click_potion() -> bool:
    var potion_tiles = _get_tiles_of_type(TileTypes.Type.POTION_TILE)
    if potion_tiles.is_empty():
        return false

    # Click potion if board has many filler tiles
    var filler_count = _count_tiles_of_type(TileTypes.Type.FILLER)
    if filler_count >= 8:  # 8+ filler tiles worth transforming
        return true

    # Click if low health and few filler (emergency heal setup)
    var fighter = _get_owner_fighter()
    if fighter and fighter.current_hp < 30 and filler_count >= 3:
        return true

    return false
```

### 4. Ultimate Timing
When to use Transmute:
- Mana full
- Enemy already has poison stacks (synergy)
- Enemy board has many matchable tiles

```gdscript
func _should_use_ultimate() -> bool:
    if not _is_mana_full():
        return false

    var enemy = _get_enemy_fighter()
    if not enemy:
        return false

    # Better when enemy has poison (synergy)
    var enemy_poison = _status_manager.get_stacks(enemy, StatusTypes.StatusType.POISON)
    if enemy_poison >= 2:
        return true

    # Use when mana is full and enemy is healthy (long fight benefit)
    if enemy.current_hp > 50:
        return randf() < 0.6

    return false
```

### 5. Variety Chain Strategy
AI should plan ahead for variety chains:
- Track what types are available on board
- Prefer moves that lead to high-value multiplied matches

```gdscript
func _evaluate_chain_potential(current_unique: Array) -> float:
    # Look at available tile types on board
    var available_types = _get_available_tile_types()
    var potential_unique = 0

    for tile_type in available_types:
        if not current_unique.has(tile_type):
            potential_unique += 1

    return potential_unique * 0.5  # Potential additional multiplier
```

### 6. Difficulty Adjustments
```gdscript
func _apply_difficulty_modifiers() -> void:
    match _difficulty:
        Difficulty.EASY:
            _variety_awareness = 0.3  # Often wastes chains
            _poison_strategy = 0.3
            _ultimate_timing = 0.2

        Difficulty.MEDIUM:
            _variety_awareness = 0.6
            _poison_strategy = 0.5
            _ultimate_timing = 0.5

        Difficulty.HARD:
            _variety_awareness = 0.9  # Maximizes variety chains
            _poison_strategy = 0.8
            _ultimate_timing = 0.8
```

## Acceptance Criteria
- [ ] AI recognizes when playing Apothecary
- [ ] AI builds variety chains (prioritizes unique types)
- [ ] AI uses Poison Vial to stack poison on enemy
- [ ] AI uses Healing Elixir when filler tiles are abundant
- [ ] AI times Transmute for poison synergy
- [ ] AI avoids wasting chains on low multipliers
- [ ] Difficulty affects AI variety chain skill
