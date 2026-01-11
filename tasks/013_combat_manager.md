# Task 013: Combat Manager

## Objective
Implement combat effect resolution from match results.

## Dependencies
- Task 011 (Cascade Handler)
- Task 012 (Fighter State)

## Reference
- `/docs/SYSTEMS.md` → Combat Manager
- `/docs/ARCHITECTURE.md` → Combat Effect Flow

## Deliverables

### 1. Combat Manager Script
Create `/scripts/managers/combat_manager.gd`:

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `player_fighter` | Fighter | Player state |
| `enemy_fighter` | Fighter | Enemy state |

### 2. Core Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `initialize(player_data, enemy_data)` | void | Setup fighters |
| `process_cascade_result(source, result)` | void | Apply all effects |
| `apply_match_effect(source, match)` | void | Apply single match |
| `get_fighter(is_player: bool)` | Fighter | Get fighter ref |
| `get_opponent(fighter)` | Fighter | Get other fighter |
| `tick(delta)` | void | Update stun timers |
| `check_victory()` | int | 0=ongoing, 1=player, 2=enemy, 3=draw |

### 3. Effect Application

**`apply_match_effect(source_fighter, match_result)`:**
```
effect_value = match_result.get_effect_value()
target = source_fighter  # Default for self-buffs

match match_result.tile_type:
    SWORD:
        target = get_opponent(source_fighter)
        result = target.take_damage(effect_value)
        emit damage_dealt(target, result)
    SHIELD:
        actual = source_fighter.add_armor(effect_value)
        emit armor_gained(source_fighter, actual)
    POTION:
        actual = source_fighter.heal(effect_value)
        emit healing_done(source_fighter, actual)
    LIGHTNING:
        target = get_opponent(source_fighter)
        actual = target.apply_stun(effect_value)
        emit stun_applied(target, actual)
    FILLER:
        pass  # No combat effect
```

### 4. Cascade Processing
`process_cascade_result(source_fighter, cascade_result)`:
1. Iterate through all matches in cascade
2. Apply each match effect
3. After all effects, check for victory
4. Emit `cascade_effects_complete`

### 5. Victory Check
```
check_victory():
    player_dead = player_fighter.is_defeated
    enemy_dead = enemy_fighter.is_defeated

    if player_dead and enemy_dead:
        return 3  # Draw
    elif enemy_dead:
        return 1  # Player wins
    elif player_dead:
        return 2  # Enemy wins
    return 0  # Ongoing
```

### 6. Stun Tick
Called each frame during battle:
```
tick(delta):
    player_fighter.tick_stun(delta)
    enemy_fighter.tick_stun(delta)

    # Notify boards of stun state changes
    if player stun ended:
        emit stun_ended(player_fighter)
    if enemy stun ended:
        emit stun_ended(enemy_fighter)
```

### 7. Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `damage_dealt` | target, result | Damage applied |
| `healing_done` | target, amount | HP restored |
| `armor_gained` | target, amount | Shield added |
| `stun_applied` | target, duration | Stun started |
| `stun_ended` | fighter | Stun wore off |
| `fighter_defeated` | fighter | HP reached 0 |
| `match_ended` | winner_id | Game over |

### 8. Integration
- BoardManager calls `process_cascade_result` after cascade
- GameManager listens to `match_ended`
- UIManager listens to all effect signals
- BoardManager listens to stun signals

## Acceptance Criteria
- [ ] Sword matches damage opponent
- [ ] Shield matches add armor to self
- [ ] Potion matches heal self
- [ ] Lightning matches stun opponent
- [ ] Filler matches have no effect
- [ ] Victory detected correctly
- [ ] Draw detected on simultaneous death
- [ ] Stun timers tick down
