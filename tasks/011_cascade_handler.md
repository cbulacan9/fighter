# Task 011: Cascade Handler

## Objective
Implement tile removal, gravity, refill, and chain reaction processing.

## Dependencies
- Task 009 (Match Detector)
- Task 010 (Tile Spawner)

## Reference
- `/docs/SYSTEMS.md` → Cascade Handler

## Deliverables

### 1. Cascade Handler Script
Create `/scripts/systems/cascade_handler.gd`:

**Dependencies:**
- Reference to Grid
- Reference to TileSpawner
- Reference to MatchDetector

### 2. CascadeResult Structure
| Field | Type | Description |
|-------|------|-------------|
| `all_matches` | Array[MatchResult] | Every match in chain |
| `total_tiles_cleared` | int | Sum of cleared tiles |
| `chain_count` | int | Number of cascade iterations |

### 3. Core Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `process_matches(matches: Array)` | CascadeResult | Full cascade loop |
| `remove_tiles(positions: Array)` | void | Clear tiles at positions |
| `apply_gravity()` | Array[TileMove] | Calculate fall movements |
| `fill_empty_spaces()` | Array[Tile] | Spawn and place new tiles |

### 4. Cascade Loop Algorithm

```
process_matches(initial_matches):
    result = CascadeResult.new()
    current_matches = initial_matches

    while current_matches.size() > 0:
        result.chain_count += 1
        result.all_matches.append_array(current_matches)

        # Get all positions to clear
        positions = collect_positions(current_matches)
        result.total_tiles_cleared += positions.size()

        # Remove matched tiles
        remove_tiles(positions)

        # Wait for clear animation
        await clear_animation_complete

        # Apply gravity
        moves = apply_gravity()

        # Wait for fall animation
        await fall_animation_complete

        # Fill empty spaces from top
        new_tiles = fill_empty_spaces()

        # Wait for spawn animation
        await spawn_animation_complete

        # Check for new matches
        current_matches = match_detector.find_matches(grid)

    return result
```

### 5. Gravity Logic
For each column, from bottom to top:
1. Find empty spaces
2. Tiles above empty spaces fall down
3. Track original and target positions for animation

**TileMove structure:**
| Field | Type |
|-------|------|
| `tile` | Tile |
| `from_row` | int |
| `to_row` | int |

### 6. Fill Logic
After gravity:
1. For each column, count empty spaces at top
2. Spawn that many tiles
3. Place above grid (for fall animation)
4. Animate falling into position

### 7. Animation Coordination
- Clear animation: 0.3s (tiles fade/shrink)
- Fall animation: 0.2s per row fallen
- Spawn animation: 0.2s (fade in while falling)

Use signals or await for sequencing.

### 8. Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `tiles_cleared` | count | Tiles removed this step |
| `tiles_fell` | moves | Gravity applied |
| `tiles_spawned` | tiles | New tiles created |
| `cascade_complete` | result | Full cascade finished |

## Acceptance Criteria
- [ ] Matched tiles are removed
- [ ] Tiles above fall down correctly
- [ ] Empty spaces filled from top
- [ ] Chain reactions detected and processed
- [ ] Animations play in correct sequence
- [ ] CascadeResult contains accurate data
