# Task 066: Reflection, Cancel, Absorb Implementation

## Objective
Implement the Mirror Warden's three defensive specialty tiles with their queue and trigger mechanics.

## Dependencies
- Task 065 (Mirror Warden Character Data)
- Task 064 (Defensive Queue System)

## Reference
- `/docs/CHARACTERS.md` → Mirror Warden Specialty Tiles

## Deliverables

### 1. Implement Reflection (Pre-Attack Counter)
When Reflection is queued and enemy attacks within window:
- Reflect damage back to attacker
- Stacks multiply reflection (1x/2x/3x)
- Original attack is negated

Add effect handler:
```gdscript
func _queue_reflection(fighter: Fighter, duration: float) -> void:
    var queue = _get_defensive_queue(fighter)
    if queue:
        queue.queue_ability(DefensiveQueue.DefenseType.REFLECTION, duration)
```

In CombatManager damage flow:
```gdscript
func _apply_damage(target: Fighter, source: Fighter, amount: int) -> void:
    var queue = _get_defensive_queue(target)

    # Check Reflection
    if queue and queue.has_queued(DefensiveQueue.DefenseType.REFLECTION):
        var stacks = queue.get_stacks(DefensiveQueue.DefenseType.REFLECTION)
        var reflect_damage = amount * stacks

        queue.try_trigger(DefensiveQueue.DefenseType.REFLECTION, {
            "original_damage": amount,
            "reflected_damage": reflect_damage
        })

        # Show reflection visual
        _show_reflection_effect(target, source)

        # Apply reflected damage to attacker
        source.take_damage(reflect_damage)

        return  # Original damage negated
```

### 2. Implement Cancel (Post-Attack Negation)
Cancel window opens after receiving an attack:
- Within 2 seconds after being hit, matching Cancel triggers
- Cancels negative effects (stun, poison, bleed) from that attack
- Does NOT cancel damage already taken

Add tracking for post-attack window:
```gdscript
var _cancel_windows: Dictionary = {}  # {Fighter: float remaining_time}

func _on_damage_received(target: Fighter, source: Fighter, damage: int) -> void:
    # Open cancel window
    _cancel_windows[target] = 2.0  # 2 second window

func _process_cancel_window(delta: float) -> void:
    var expired: Array[Fighter] = []
    for fighter in _cancel_windows.keys():
        _cancel_windows[fighter] -= delta
        if _cancel_windows[fighter] <= 0:
            expired.append(fighter)
    for fighter in expired:
        _cancel_windows.erase(fighter)

func _on_cancel_matched(fighter: Fighter) -> void:
    if _cancel_windows.has(fighter) and _cancel_windows[fighter] > 0:
        var queue = _get_defensive_queue(fighter)
        if queue and queue.has_queued(DefensiveQueue.DefenseType.CANCEL):
            # Trigger cancel - remove recent negative effects
            _cancel_recent_effects(fighter)
            queue.try_trigger(DefensiveQueue.DefenseType.CANCEL, {})
            _cancel_windows.erase(fighter)
```

Cancel effect removal:
```gdscript
func _cancel_recent_effects(fighter: Fighter) -> void:
    # Remove stun
    if fighter.is_stunned():
        fighter.clear_stun()

    # Remove negative status effects applied in last 2 seconds
    var negative_types = [
        StatusTypes.StatusType.POISON,
        StatusTypes.StatusType.BLEED,
        StatusTypes.StatusType.MANA_BLOCK
    ]

    for effect_type in negative_types:
        if _status_manager.has_effect(fighter, effect_type):
            _status_manager.remove(fighter, effect_type)
```

### 3. Implement Absorb (Damage Storage)
Absorb passively reduces and stores incoming damage:
- Reduces damage taken by 50% per stack
- Stored damage released on next attack combo
- Stacks scale release damage (4x/5x match bonus)

```gdscript
func _apply_damage(target: Fighter, source: Fighter, amount: int) -> void:
    var queue = _get_defensive_queue(target)

    # ... Reflection check first ...

    # Check Absorb
    if queue and queue.has_queued(DefensiveQueue.DefenseType.ABSORB):
        var stacks = queue.get_stacks(DefensiveQueue.DefenseType.ABSORB)
        var absorb_percent = 0.25 * stacks  # 25%/50%/75%
        var absorbed = int(amount * absorb_percent)

        queue.store_damage(absorbed)
        amount -= absorbed

        _show_absorb_effect(target, absorbed)

    # Apply remaining damage
    target.take_damage(amount)
```

Absorb release on attack:
```gdscript
func _on_warden_attack_match(fighter: Fighter, match_count: int) -> void:
    var queue = _get_defensive_queue(fighter)
    if not queue:
        return

    var stored = queue.get_stored_damage()
    if stored <= 0:
        return

    # Release stored damage with combo bonus
    var multiplier = 1.0
    if match_count >= 5:
        multiplier = 2.0
    elif match_count >= 4:
        multiplier = 1.5

    var release_damage = int(stored * multiplier)
    var enemy = _get_enemy_of(fighter)

    if enemy:
        enemy.take_damage(release_damage)
        _show_absorb_release_effect(fighter, enemy, release_damage)

    # Clear stored damage
    queue.try_trigger(DefensiveQueue.DefenseType.ABSORB, {
        "stored": stored,
        "released": release_damage
    })
```

### 4. Visual Effects
Each defensive ability needs distinct visuals:

**Reflection:**
- Mirror/shield effect when queued
- Flash when triggered
- Beam going back to attacker

**Cancel:**
- Nullify symbol when queued
- Dispel effect when triggered
- Status effect icons disappear

**Absorb:**
- Dark aura when queued
- Damage number absorbed (purple/dark)
- Explosion when released

### 5. Stacking Behavior
When same defensive type matched 3x in a row:
- Stacks increase (max 3)
- Timer refreshes
- Power increases per stack

Detection:
```gdscript
var _last_match_types: Array[TileTypes.Type] = []

func _on_match_resolved(match_result: MatchResult) -> void:
    _last_match_types.append(match_result.tile_type)
    if _last_match_types.size() > 3:
        _last_match_types.pop_front()

    # Check for triple stack
    if _last_match_types.size() == 3:
        if _all_same_type(_last_match_types):
            # This creates a stacked ability
            pass
```

## Acceptance Criteria
- [ ] Reflection queues and reflects damage when attacked
- [ ] Reflection stacks multiply reflected damage
- [ ] Cancel queues and opens window after being hit
- [ ] Cancel removes stun and negative effects when triggered
- [ ] Absorb reduces damage and stores it
- [ ] Absorb releases stored damage on attack match
- [ ] Combo bonus (4x/5x) affects Absorb release
- [ ] All abilities show distinct visual effects
- [ ] Stacking (3x same match) increases power
