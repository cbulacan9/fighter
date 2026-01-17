# Task 056: Shadow Step Implementation

## Objective
Implement the Assassin's Shadow Step tile with passive dodge and active mana block.

## Dependencies
- Task 054 (Assassin Character Data)
- Task 055 (Smoke Bomb - for mana bar integration pattern)

## Reference
- `/docs/CHARACTERS.md` → Assassin Specialty Tiles

## Deliverables

### 1. Implement Shadow Step Passive Effect
When Shadow Step is matched, grant dodge chance based on match size:
- 3-match: 20% dodge chance
- 4-match: 40% dodge chance
- 5-match: 75% dodge chance

Create/update DODGE status effect handling:
```gdscript
# In StatusEffectManager or CombatManager

func _check_dodge(target: Fighter) -> bool:
    var dodge_effect = get_effect(target, StatusTypes.StatusType.DODGE)
    if not dodge_effect:
        return false

    var dodge_chance = dodge_effect.data.base_value
    if randf() < dodge_chance:
        # Consume the dodge effect
        remove(target, StatusTypes.StatusType.DODGE)
        return true
    return false
```

### 2. Implement Shadow Step Active Effect
When Shadow Step is clicked (with full mana bar 1), block enemy mana generation for 5 seconds.

In EffectProcessor:
```gdscript
func _shadow_step_active(target: Fighter, effect: EffectData) -> void:
    if _mana_system and target:
        _mana_system.block_all_bars(target, effect.duration)
```

Add to ManaSystem:
```gdscript
func block_all_bars(fighter: Fighter, duration: float) -> void:
    var bars = _fighter_bars.get(fighter, [])
    for bar in bars:
        bar.block(duration)
```

### 3. Dodge vs Evasion Clarification
- **DODGE** (Shadow Step): Percentage chance to avoid attack, consumed on success
- **EVASION** (Hawk): Guaranteed auto-miss, stack-based

Ensure damage application checks both:
```gdscript
func _apply_damage(target: Fighter, source: Fighter, amount: int) -> void:
    # Check evasion first (guaranteed miss)
    if _check_and_consume_evasion(target):
        _show_evade_text(target)
        return

    # Check dodge second (chance-based)
    if _check_dodge(target):
        _show_dodge_text(target)
        return

    # Apply damage normally...
```

### 4. Mana Block Visual Indicator
When a fighter's mana is blocked:
- Show visual on mana bars (grayed out, X overlay, etc.)
- Show remaining block duration
- Mana bar doesn't fill during block

### 5. Update CombatManager Integration
Ensure dodge check is integrated into damage flow:
- Dodge checked before damage application
- Visual feedback ("Dodged!")
- Dodge status consumed on successful dodge

## Acceptance Criteria
- [ ] Matching Shadow Step grants dodge chance (20%/40%/75% by match size)
- [ ] Dodge chance actually prevents damage when roll succeeds
- [ ] Dodge effect consumed after successful dodge
- [ ] Clicking Shadow Step (when mana bar 1 full) blocks enemy mana for 5s
- [ ] Blocked mana bars show visual indicator
- [ ] Mana bar 1 drains on active use
- [ ] Dodge and Evasion work as separate mechanics
