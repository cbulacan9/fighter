# Task 014: AI Controller

## Objective
Implement AI opponent that plays the tile-matching game.

## Dependencies
- Task 009 (Match Detector)
- Task 013 (Combat Manager)

## Reference
- `/docs/SYSTEMS.md` → AI Controller

## Deliverables

### 1. AI Controller Script
Create `/scripts/controllers/ai_controller.gd`:

**Exports:**
| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `decision_delay` | float | 1.0 | Seconds between moves |
| `look_ahead` | int | 1 | Cascade prediction depth |
| `randomness` | float | 0.2 | Chance of suboptimal move |

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `board` | BoardManager | AI's board reference |
| `_decision_timer` | float | Time until next move |
| `_enabled` | bool | AI active state |

### 2. Move Structure
| Field | Type | Description |
|-------|------|-------------|
| `axis` | DragAxis | HORIZONTAL or VERTICAL |
| `index` | int | Row or column index |
| `offset` | int | Cells to shift (-COLS to +COLS) |
| `score` | float | Evaluated value |

### 3. Core Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `set_enabled(enabled: bool)` | void | Start/stop AI |
| `_process(delta)` | void | Decision timer tick |
| `evaluate_all_moves()` | Array[Move] | Score every possible move |
| `evaluate_move(move)` | float | Score single move |
| `select_move(moves)` | Move | Choose based on settings |
| `execute_move(move)` | void | Apply to board |

### 4. Move Enumeration
All possible moves:
- 6 rows × (1 to 7 offset) × 2 directions = 84 row moves
- 8 columns × (1 to 5 offset) × 2 directions = 80 column moves

**Optimization:** Only evaluate moves that create matches.

### 5. Move Evaluation

**Scoring factors:**
| Factor | Weight | Description |
|--------|--------|-------------|
| Match value | 1.0 | Sum of effect values |
| Sword bonus | 1.5 | Prioritize damage |
| Multi-match | 1.2 | Per additional match |
| Cascade potential | 0.5 | Estimated chains |

**Basic scoring:**
```
evaluate_move(move):
    # Simulate move
    matches = match_detector.preview_match(grid, move)
    if matches.empty():
        return 0

    score = 0
    for match in matches:
        value = match.get_effect_value()
        if match.tile_type == SWORD:
            value *= 1.5
        score += value

    return score
```

### 6. Move Selection
```
select_move(moves):
    # Sort by score descending
    moves.sort_by(score, descending)

    # Randomness check
    if randf() < randomness and moves.size() > 1:
        # Pick from top 3 instead of best
        return moves[randi() % min(3, moves.size())]

    return moves[0]
```

### 7. Execution Flow
```
_process(delta):
    if not _enabled or board.state != IDLE:
        return

    _decision_timer -= delta
    if _decision_timer <= 0:
        _decision_timer = decision_delay

        moves = evaluate_all_moves()
        if moves.size() > 0:
            move = select_move(moves)
            execute_move(move)
```

### 8. Difficulty Presets
| Difficulty | Delay | Look-ahead | Randomness |
|------------|-------|------------|------------|
| Easy | 2.0s | 0 | 0.5 |
| Medium | 1.0s | 1 | 0.2 |
| Hard | 0.5s | 2 | 0.05 |

## Acceptance Criteria
- [ ] AI makes valid moves that create matches
- [ ] AI prioritizes high-value matches
- [ ] Decision delay controls move frequency
- [ ] Randomness introduces variability
- [ ] AI pauses when board is resolving
- [ ] AI can be enabled/disabled
