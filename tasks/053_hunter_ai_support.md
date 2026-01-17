# Task 053: Hunter AI Support

## Objective
Extend AI controller to play Hunter character effectively with sequences and Pet activation.

## Dependencies
- Task 052 (Alpha Command Ultimate)
- Task 014 (AI Controller)

## Reference
- `/docs/SYSTEMS.md` → AI Controller
- `/docs/CHARACTERS.md` → Hunter

## Deliverables

### 1. Extend AIController for Character Awareness
Modify `/scripts/controllers/ai_controller.gd`:

```gdscript
var _character_data: CharacterData
var _sequence_tracker: SequenceTracker

func setup(board: BoardManager, match_detector: MatchDetector) -> void:
    _board = board
    _match_detector = match_detector
    _sequence_tracker = board.sequence_tracker

func set_character(char_data: CharacterData) -> void:
    _character_data = char_data

func _evaluate_moves() -> Array[ScoredMove]:
    if _character_data and _character_data.has_sequences():
        return _evaluate_sequence_moves()
    else:
        return _evaluate_standard_moves()
```

### 2. Sequence-Aware Move Evaluation
```gdscript
func _evaluate_sequence_moves() -> Array[ScoredMove]:
    var moves: Array[ScoredMove] = []

    # Get current sequence state
    var current = _sequence_tracker.get_current_sequence()
    var possible = _sequence_tracker._get_possible_completions()

    # Evaluate each possible move
    for move in _get_all_possible_moves():
        var score = _score_sequence_move(move, current, possible)
        moves.append(ScoredMove.new(move, score))

    return moves

func _score_sequence_move(move: Move, current: Array, possible: Array) -> float:
    var score: float = 0.0

    # Simulate the move
    var result = _simulate_move(move)

    # Score based on match type
    for match_result in result.matches:
        var tile_type = match_result.tile_type

        # Check if this advances any sequence
        for pattern in possible:
            var next_index = current.size()
            if next_index < pattern.pattern.size():
                if tile_type == pattern.pattern[next_index]:
                    score += 50.0  # Bonus for advancing sequence
                    break

        # Standard match value
        score += _get_match_value(match_result)

    # Penalty for breaking sequence
    if result.breaks_sequence:
        score -= 100.0

    return score

func _simulate_move(move: Move) -> SimulationResult:
    # Create temporary grid copy
    # Apply move
    # Check for matches
    # Check if sequence would break
    # Return result
    pass
```

### 3. Pet Click Decision
```gdscript
func _should_click_pet() -> bool:
    if not _sequence_tracker:
        return false

    if not _sequence_tracker.has_completable_sequence():
        return false

    var banked = _sequence_tracker.get_banked_sequences()
    if banked.is_empty():
        return false

    # Decision factors:
    # - Which sequence is banked?
    # - What's the current game state?
    # - Is ultimate active?

    var pattern = banked[0]

    # Always use Snake if we're poisoned
    if pattern.sequence_id == "snake":
        var fighter = _board._get_owner_fighter()
        if fighter and fighter.has_status(StatusTypes.StatusType.POISON):
            return true

    # Use Hawk if enemy has lots of tiles to replace
    if pattern.sequence_id == "hawk":
        return true  # Usually good to use

    # Use Bear for damage
    if pattern.sequence_id == "bear":
        return true

    return true  # Default: use when available

func _click_pet() -> void:
    var pet_tiles = _board.get_tiles_of_type(TileTypes.TileType.PET)
    if pet_tiles.size() > 0:
        _board._on_tile_clicked(pet_tiles[0])
```

### 4. Ultimate Activation Decision
```gdscript
func _should_use_ultimate() -> bool:
    var fighter = _board._get_owner_fighter()
    if not fighter:
        return false

    var mana_system = _get_mana_system()
    if not mana_system or not mana_system.can_use_ultimate(fighter):
        return false

    # Use ultimate when:
    # - We have sequences banked
    # - Enemy is low HP (finish them off)
    # - We're in a good position

    if _sequence_tracker and _sequence_tracker.has_completable_sequence():
        return true  # Good time to use

    return false

func _activate_ultimate() -> void:
    var combat_manager = _get_combat_manager()
    if combat_manager:
        combat_manager.activate_ultimate(_board._get_owner_fighter())
```

### 5. AI Decision Loop Update
```gdscript
func _process(delta: float) -> void:
    if not _enabled:
        return

    _decision_timer += delta
    if _decision_timer < _reaction_delay:
        return

    _decision_timer = 0.0

    # Check for Pet click first
    if _should_click_pet():
        _click_pet()
        return

    # Check for ultimate
    if _should_use_ultimate():
        _activate_ultimate()
        return

    # Normal move evaluation
    var moves = _evaluate_moves()
    if moves.size() > 0:
        var selected = _select_move(moves)
        _execute_move(selected)
```

### 6. Difficulty Adjustments for Hunter AI
```gdscript
func _apply_difficulty_modifiers() -> void:
    match _difficulty:
        Difficulty.EASY:
            # Rarely completes sequences
            # Often breaks sequences by accident
            _sequence_awareness = 0.3
            _click_delay = 1.5

        Difficulty.MEDIUM:
            # Sometimes completes sequences
            _sequence_awareness = 0.6
            _click_delay = 1.0

        Difficulty.HARD:
            # Actively works toward sequences
            # Uses ultimate effectively
            _sequence_awareness = 0.9
            _click_delay = 0.5

var _sequence_awareness: float = 1.0
var _click_delay: float = 0.5

func _score_sequence_move(move: Move, current: Array, possible: Array) -> float:
    var score = _base_score_move(move)

    # Apply sequence awareness
    if randf() > _sequence_awareness:
        return score  # Ignore sequence scoring sometimes

    # ... rest of sequence scoring ...
```

## Acceptance Criteria
- [ ] AI recognizes when playing Hunter
- [ ] AI builds toward sequences
- [ ] AI clicks Pet when sequence complete
- [ ] AI uses ultimate appropriately
- [ ] AI prioritizes Snake when poisoned
- [ ] Difficulty affects sequence play quality
- [ ] AI doesn't break sequences unnecessarily
