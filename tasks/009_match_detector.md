# Task 009: Match Detector

## Objective
Implement match detection algorithm for finding 3+ aligned tiles.

## Dependencies
- Task 005 (Board Manager)

## Reference
- `/docs/SYSTEMS.md` → Match Detector

## Deliverables

### 1. Match Detector Script
Create `/scripts/systems/match_detector.gd`:

**MatchResult Class/Dictionary:**
| Field | Type | Description |
|-------|------|-------------|
| `tile_type` | TileType | Type of matched tiles |
| `positions` | Array[Vector2i] | Grid coordinates |
| `count` | int | Number of tiles (capped at 5) |

### 2. Core Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `find_matches(grid: Grid)` | Array[MatchResult] | Find all current matches |
| `has_any_match(grid: Grid)` | bool | Quick check for any match |
| `preview_match(grid: Grid, axis, index, offset)` | bool | Check hypothetical move |

### 3. Detection Algorithm

**Horizontal Scan:**
```
For each row:
    current_type = null
    current_run = []
    For each column:
        tile = grid.get_tile(row, col)
        if tile.type == current_type:
            current_run.append(position)
        else:
            if current_run.length >= 3:
                record_match(current_run)
            current_type = tile.type
            current_run = [position]
    # Check final run
    if current_run.length >= 3:
        record_match(current_run)
```

**Vertical Scan:**
Same logic, iterating columns then rows.

### 4. Match Merging
If horizontal and vertical matches share tiles of same type:
- Merge into single match
- Count unique positions only
- Forms L, T, or + shapes

### 5. Preview Mode
For `preview_match()`:
1. Create temporary grid state
2. Apply hypothetical shift
3. Run `has_any_match()` on temp state
4. Return result (don't modify real grid)

### 6. Filler Tile Handling
- Filler tiles CAN form matches
- They clear but produce no combat effect
- Detection treats them same as other types

### 7. Count Capping
Match count capped at 5 for reward calculation:
- 6+ tiles still all clear
- Effect value uses 5-match reward

## Acceptance Criteria
- [ ] Detects horizontal matches of 3, 4, 5+ tiles
- [ ] Detects vertical matches of 3, 4, 5+ tiles
- [ ] Merges connected same-type matches
- [ ] `preview_match` works without modifying grid
- [ ] Returns correct MatchResult data
- [ ] `has_any_match` returns quickly for validation
