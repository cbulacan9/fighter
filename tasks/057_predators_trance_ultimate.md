# Task 057: Predator's Trance Ultimate

## Objective
Implement the Assassin's ultimate ability that converts tile drops to swords and creates auto-chain combos.

## Dependencies
- Task 056 (Shadow Step)
- Task 034 (Mana System Core)

## Reference
- `/docs/CHARACTERS.md` → Assassin Ultimate Ability

## Deliverables

### 1. Create Predator's Trance Status Effect
Create `/resources/effects/predators_trance_status.tres`:

```gdscript
effect_type = PREDATORS_TRANCE
duration = 10.0
tick_behavior = ON_TIME
tick_interval = 0.1  # For tracking
```

Add PREDATORS_TRANCE to StatusTypes enum.

### 2. Implement Sword-Only Drops
When Predator's Trance is active, modify TileSpawner:

```gdscript
func _select_tile_type() -> TileTypes.Type:
    # Check for Predator's Trance
    if _is_predators_trance_active():
        return TileTypes.Type.SWORD

    # Normal selection...
```

Add method to check status:
```gdscript
var _owner_fighter: Fighter

func set_owner_fighter(fighter: Fighter) -> void:
    _owner_fighter = fighter

func _is_predators_trance_active() -> bool:
    if not _owner_fighter:
        return false
    return _owner_fighter.has_status(StatusTypes.StatusType.PREDATORS_TRANCE)
```

### 3. Implement Auto-Chain Mechanic
When swords are matched during Predator's Trance:
- 3-match: Next 1 drop becomes sword, auto-chains
- 4-match: Next 2 drops become swords, auto-chain
- 5-match: Next 3 drops become swords, auto-chain

Create chain tracker:
```gdscript
class_name AutoChainTracker extends RefCounted

var _pending_chains: int = 0
var _chain_tiles: Array[Tile] = []  # Tiles marked as chain tiles

func add_chains(count: int) -> void:
    _pending_chains += count

func consume_chain() -> bool:
    if _pending_chains > 0:
        _pending_chains -= 1
        return true
    return false

func has_pending_chains() -> bool:
    return _pending_chains > 0
```

### 4. Auto-Match Logic
When a chain tile lands after cascade:
1. Mark tile as "chain tile" (special visual)
2. After cascade settles, check for matches involving chain tiles
3. If chain tile matches, trigger match automatically
4. Chain tiles cannot continue combo indefinitely (mark as "consumed")

```gdscript
# In BoardManager or CascadeHandler

func _on_tiles_landed(tiles: Array[Tile]) -> void:
    if not _auto_chain_tracker.has_pending_chains():
        return

    for tile in tiles:
        if tile.tile_data.tile_type == TileTypes.Type.SWORD:
            if _auto_chain_tracker.consume_chain():
                tile.set_chain_tile(true)

    # After all tiles land, check for auto-matches
    call_deferred("_process_auto_chains")

func _process_auto_chains() -> void:
    var chain_tiles = _get_chain_tiles()
    for tile in chain_tiles:
        var match_result = _match_detector.check_tile_matches(tile)
        if match_result:
            tile.set_chain_consumed(true)  # Can't chain further
            _execute_match(match_result)
```

### 5. Chain Tile Visual
Chain tiles should have distinct visual:
- Golden glow or aura
- Particle effect
- Different when consumed (dimmer)

### 6. Ultimate Activation
Modify CombatManager.activate_ultimate() for Assassin:
- Requires both mana bars full
- Drains both bars
- Applies Predator's Trance status

### 7. Auto-Chain Prevention
Tiles spawned from auto-chain cannot create infinite loops:
- Mark tiles as "chain_consumed" after auto-matching
- Consumed tiles don't trigger new chains
- Only manually matched swords (during Trance) create new chains

## Acceptance Criteria
- [ ] Ultimate requires both mana bars full
- [ ] Activation drains both bars
- [ ] All new tile drops become swords during Trance
- [ ] 3/4/5 sword matches queue 1/2/3 auto-chains
- [ ] Auto-chain tiles land and auto-match
- [ ] Chain tiles have distinct visual
- [ ] Auto-chains cannot loop infinitely
- [ ] Trance lasts 10 seconds then expires
