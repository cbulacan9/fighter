# Task 012: Fighter State

## Objective
Implement fighter state management for HP, armor, and stun.

## Dependencies
- Task 002 (Data Resources)

## Reference
- `/docs/SYSTEMS.md` → Combat Manager (Fighter State)

## Deliverables

### 1. Fighter Script
Create `/scripts/entities/fighter.gd`:

**Exports:**
| Export | Type | Description |
|--------|------|-------------|
| `fighter_data` | FighterData | Configuration resource |

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `current_hp` | int | Current health |
| `max_hp` | int | Maximum health |
| `armor` | int | Damage buffer |
| `stun_remaining` | float | Seconds of stun left |
| `is_defeated` | bool | HP reached 0 |

### 2. Core Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `initialize(data: FighterData)` | void | Setup from resource |
| `take_damage(amount: int)` | DamageResult | Apply damage |
| `heal(amount: int)` | int | Restore HP, returns actual |
| `add_armor(amount: int)` | int | Add shield, returns actual |
| `apply_stun(duration: float)` | float | Add stun, returns actual |
| `tick_stun(delta: float)` | void | Reduce stun timer |
| `is_stunned() -> bool` | bool | Check stun state |
| `reset()` | void | Restore to full |

### 3. DamageResult Structure
| Field | Type | Description |
|-------|------|-------------|
| `total_damage` | int | Damage requested |
| `armor_absorbed` | int | Damage to armor |
| `hp_damage` | int | Damage to HP |
| `defeated` | bool | HP reached 0 |

### 4. Damage Logic
```
take_damage(amount):
    result = DamageResult.new()
    result.total_damage = amount

    # Armor absorbs first
    if armor > 0:
        absorbed = min(armor, amount)
        armor -= absorbed
        amount -= absorbed
        result.armor_absorbed = absorbed

    # Remaining damages HP
    current_hp = max(0, current_hp - amount)
    result.hp_damage = amount

    if current_hp == 0:
        is_defeated = true
        result.defeated = true

    return result
```

### 5. Heal Logic
```
heal(amount):
    actual = min(amount, max_hp - current_hp)
    current_hp += actual
    return actual
```

### 6. Armor Logic
```
add_armor(amount):
    actual = min(amount, max_hp - armor)
    armor += actual
    return actual
```

### 7. Stun Logic
```
apply_stun(duration):
    if stun_remaining > 0:
        # Diminishing returns
        duration *= 0.5
    duration = max(0.25, duration)  # Minimum stun
    stun_remaining += duration
    return duration

tick_stun(delta):
    stun_remaining = max(0, stun_remaining - delta)
```

### 8. Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `hp_changed` | current, max | HP value changed |
| `armor_changed` | current | Armor value changed |
| `stun_changed` | remaining | Stun timer changed |
| `defeated` | none | HP reached 0 |

## Acceptance Criteria
- [ ] Fighter initializes with correct max HP
- [ ] Damage reduces armor before HP
- [ ] Heal caps at max HP
- [ ] Armor caps at max HP
- [ ] Stun has diminishing returns
- [ ] `defeated` signal emits at 0 HP
- [ ] All changes emit appropriate signals
