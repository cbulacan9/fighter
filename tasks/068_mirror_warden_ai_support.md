# Task 068: Mirror Warden AI Support

## Objective
Extend AI controller to play Mirror Warden character effectively with defensive timing and queue management.

## Dependencies
- Task 067 (Invincibility Ultimate)
- Task 014 (AI Controller)

## Reference
- `/docs/SYSTEMS.md` → AI Controller
- `/docs/CHARACTERS.md` → Mirror Warden

## Deliverables

### 1. Extend AIController for Mirror Warden
Add Mirror Warden-specific logic:

```gdscript
func _evaluate_moves() -> Array:
    if _is_mirror_warden():
        return _evaluate_warden_moves()
    # ... other character checks ...

func _is_mirror_warden() -> bool:
    return _character_data and _character_data.character_id == "mirror_warden"
```

### 2. Defensive Queue-Aware Move Evaluation
Warden AI should:
- Maintain defensive queue (always have something queued)
- Prioritize defensive tiles when health is low
- Stack same defensive type when anticipating attacks

```gdscript
var _defensive_queue: DefensiveQueue

func _evaluate_warden_moves() -> Array:
    var moves: Array = []

    for move in _get_all_possible_moves():
        var score = _score_warden_move(move)
        moves.append({"move": move, "score": score})

    return moves

func _score_warden_move(move) -> float:
    var score: float = 0.0
    var result = _simulate_move(move)

    for match_result in result.matches:
        var tile_type = match_result.tile_type
        var base_value = _get_match_value(match_result)

        match tile_type:
            TileTypes.Type.REFLECTION:
                score += _score_reflection_value(match_result)
            TileTypes.Type.CANCEL:
                score += _score_cancel_value(match_result)
            TileTypes.Type.ABSORB:
                score += _score_absorb_value(match_result)
            _:
                score += base_value

    return score
```

### 3. Reactive Defense Strategy
AI should anticipate enemy attacks:
- Watch enemy's board for attack tile matches
- Queue Reflection before expected attacks
- Queue Cancel after taking damage

```gdscript
func _score_reflection_value(match_result: MatchResult) -> float:
    var base = 20.0

    # Higher value if enemy has attack tiles ready
    if _enemy_has_attack_potential():
        base += 40.0

    # Stack bonus if already have Reflection queued
    if _defensive_queue.has_queued(DefensiveQueue.DefenseType.REFLECTION):
        var stacks = _defensive_queue.get_stacks(DefensiveQueue.DefenseType.REFLECTION)
        if stacks < 3:
            base += 30.0  # Want to stack

    return base

func _enemy_has_attack_potential() -> bool:
    var enemy_board = _get_enemy_board()
    if not enemy_board:
        return false

    # Check if enemy has sword/attack tiles that could match
    var attack_count = enemy_board.count_tiles_of_type(TileTypes.Type.SWORD)
    return attack_count >= 3
```

### 4. Cancel Timing
AI should use Cancel effectively after being hit:

```gdscript
func _score_cancel_value(match_result: MatchResult) -> float:
    var base = 15.0
    var fighter = _get_owner_fighter()

    # High value if we have negative status effects
    if fighter:
        if fighter.is_stunned():
            base += 60.0  # Desperate to cancel stun
        if _status_manager.has_effect(fighter, StatusTypes.StatusType.POISON):
            base += 40.0
        if _status_manager.has_effect(fighter, StatusTypes.StatusType.BLEED):
            base += 40.0

    # In cancel window - very valuable
    if _is_in_cancel_window():
        base += 50.0

    return base
```

### 5. Absorb Strategy
AI should use Absorb for damage mitigation and counter-attacks:

```gdscript
func _score_absorb_value(match_result: MatchResult) -> float:
    var base = 15.0

    # Value based on stored damage
    var stored = _defensive_queue.get_stored_damage()
    if stored > 0:
        # Already storing - maintain it
        base += 20.0

    # Value if low health (need mitigation)
    var fighter = _get_owner_fighter()
    if fighter and fighter.current_hp < fighter.max_hp * 0.5:
        base += 30.0

    return base

func _should_release_absorb() -> bool:
    var stored = _defensive_queue.get_stored_damage()
    if stored < 20:
        return false  # Not enough stored

    # Release if we have a good attack match available
    # Or if Absorb is about to expire
    return true
```

### 6. Ultimate Decision
When to use Invincibility:
- About to take fatal damage
- Enemy is about to use ultimate
- Need time to set up defensive queue

```gdscript
func _should_use_ultimate() -> bool:
    if not _is_mana_full():
        return false

    var fighter = _get_owner_fighter()
    if not fighter:
        return false

    # Use when low health
    if fighter.current_hp < 25:
        return true

    # Use when enemy has full mana (counter their ultimate)
    var enemy = _get_enemy_fighter()
    if enemy:
        var enemy_mana = _get_enemy_mana_percent()
        if enemy_mana >= 0.9:
            return randf() < 0.7  # 70% chance to preempt

    return false
```

### 7. Defensive Posture Management
AI should show defensive intent through play patterns:

```gdscript
func _get_defensive_priority() -> float:
    """
    Returns 0.0-1.0 indicating how defensive AI should play.
    Higher = prioritize defensive tiles.
    """
    var fighter = _get_owner_fighter()
    if not fighter:
        return 0.5

    var hp_percent = float(fighter.current_hp) / fighter.max_hp

    if hp_percent < 0.3:
        return 0.9  # Very defensive
    elif hp_percent < 0.5:
        return 0.7
    elif hp_percent > 0.8:
        return 0.3  # More aggressive
    else:
        return 0.5
```

### 8. Difficulty Adjustments
```gdscript
func _apply_difficulty_modifiers() -> void:
    match _difficulty:
        Difficulty.EASY:
            _defensive_timing = 0.3  # Poor timing
            _queue_management = 0.3
            _ultimate_timing = 0.2

        Difficulty.MEDIUM:
            _defensive_timing = 0.6
            _queue_management = 0.6
            _ultimate_timing = 0.5

        Difficulty.HARD:
            _defensive_timing = 0.9  # Excellent timing
            _queue_management = 0.9
            _ultimate_timing = 0.8
```

## Acceptance Criteria
- [ ] AI recognizes when playing Mirror Warden
- [ ] AI maintains defensive queue (prioritizes defensive tiles)
- [ ] AI anticipates enemy attacks for Reflection timing
- [ ] AI uses Cancel after receiving negative effects
- [ ] AI manages Absorb for damage mitigation and release
- [ ] AI uses Invincibility when about to die
- [ ] Defensive priority scales with health
- [ ] Difficulty affects defensive skill
