# Task 058: Assassin AI Support

## Objective
Extend AI controller to play Assassin character effectively with mana management and ability timing.

## Dependencies
- Task 057 (Predator's Trance Ultimate)
- Task 014 (AI Controller)

## Reference
- `/docs/SYSTEMS.md` → AI Controller
- `/docs/CHARACTERS.md` → Assassin

## Deliverables

### 1. Extend AIController for Assassin
Add Assassin-specific logic:

```gdscript
func _evaluate_moves() -> Array:
    if _is_assassin():
        return _evaluate_assassin_moves()
    elif _character_data and _character_data.has_sequences():
        return _evaluate_sequence_moves()
    else:
        return _evaluate_standard_moves()

func _is_assassin() -> bool:
    return _character_data and _character_data.character_id == "assassin"
```

### 2. Mana-Aware Move Evaluation
Assassin AI should:
- Prioritize mana tiles when bars aren't full
- Value sword matches highly when Trance is active
- Consider smoke/shadow tiles based on mana state

```gdscript
func _evaluate_assassin_moves() -> Array:
    var moves: Array = []

    for move in _get_all_possible_moves():
        var score = _score_assassin_move(move)
        moves.append({"move": move, "score": score})

    return moves

func _score_assassin_move(move) -> float:
    var score: float = 0.0
    var result = _simulate_move(move)

    for match_result in result.matches:
        var tile_type = match_result.tile_type

        # High value for mana when not full
        if tile_type == TileTypes.Type.MANA:
            if not _is_mana_full():
                score += 40.0
            else:
                score += 10.0

        # Extremely high value for swords during Trance
        elif tile_type == TileTypes.Type.SWORD:
            if _is_trance_active():
                score += 60.0 * match_result.count  # Big bonus for chains
            else:
                score += _get_match_value(match_result)

        # Standard scoring for other tiles
        else:
            score += _get_match_value(match_result)

    return score
```

### 3. Specialty Tile Activation Decision
When to use Smoke Bomb (active):
- Enemy has strong tiles visible
- Setting up for ultimate
- Defensive when low HP

When to use Shadow Step (active):
- Enemy mana is high (block their ultimate)
- Enemy about to activate ability

```gdscript
func _should_use_smoke_bomb() -> bool:
    if not _is_mana_bar_full(0):
        return false

    # Use when enemy has threatening visible board state
    # Or when preparing for Trance
    if _is_preparing_for_trance():
        return true

    return randf() < 0.3  # 30% chance when available (difficulty-adjusted)

func _should_use_shadow_step() -> bool:
    if not _is_mana_bar_full(1):
        return false

    var enemy = _get_enemy_fighter()
    if enemy and _get_enemy_mana_percent() > 0.7:
        return true  # Block enemy's ultimate charge

    return false
```

### 4. Ultimate Decision
When to use Predator's Trance:
- Both mana bars full
- Board has sword matches available
- Enemy HP is low (finish them)

```gdscript
func _should_use_ultimate() -> bool:
    if not _are_all_mana_bars_full():
        return false

    # Check for sword match potential
    var sword_matches = _count_potential_sword_matches()
    if sword_matches >= 2:
        return true

    # Use if enemy is low HP
    var enemy = _get_enemy_fighter()
    if enemy and enemy.current_hp < 30:
        return true

    return false
```

### 5. Trance Mode Strategy
When Trance is active:
- Prioritize sword matches above all else
- Create cascades for more sword drops
- Avoid wasting time on non-sword matches

```gdscript
func _is_trance_active() -> bool:
    var fighter = _get_owner_fighter()
    return fighter and fighter.has_status(StatusTypes.StatusType.PREDATORS_TRANCE)

func _score_trance_move(move) -> float:
    # During Trance, ONLY care about swords
    var result = _simulate_move(move)
    var sword_count = 0

    for match_result in result.matches:
        if match_result.tile_type == TileTypes.Type.SWORD:
            sword_count += match_result.count

    return sword_count * 100.0  # Massive weight on swords
```

### 6. Difficulty Adjustments
```gdscript
func _apply_difficulty_modifiers() -> void:
    match _difficulty:
        Difficulty.EASY:
            _mana_awareness = 0.3
            _ability_timing = 0.2  # Rarely uses abilities optimally
            _trance_efficiency = 0.3

        Difficulty.MEDIUM:
            _mana_awareness = 0.6
            _ability_timing = 0.5
            _trance_efficiency = 0.6

        Difficulty.HARD:
            _mana_awareness = 0.9
            _ability_timing = 0.8
            _trance_efficiency = 0.9
```

## Acceptance Criteria
- [ ] AI recognizes when playing Assassin
- [ ] AI prioritizes mana tiles when bars aren't full
- [ ] AI uses Smoke Bomb effectively
- [ ] AI uses Shadow Step to block enemy mana
- [ ] AI activates Trance when optimal
- [ ] AI maximizes sword chains during Trance
- [ ] Difficulty affects AI skill level
