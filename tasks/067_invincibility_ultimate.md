# Task 067: Invincibility Ultimate

## Objective
Implement the Mirror Warden's ultimate ability that grants complete damage immunity.

## Dependencies
- Task 066 (Reflection, Cancel, Absorb)
- Task 034 (Mana System Core)

## Reference
- `/docs/CHARACTERS.md` → Mirror Warden Ultimate Ability

## Deliverables

### 1. Implement INVINCIBILITY Status
Add handling in StatusEffectManager:

```gdscript
func has_invincibility(fighter: Fighter) -> bool:
    return has_effect(fighter, StatusTypes.StatusType.INVINCIBILITY)
```

### 2. Damage Immunity Check
In CombatManager, check invincibility before any damage:

```gdscript
func _apply_damage(target: Fighter, source: Fighter, amount: int, unavoidable: bool = false) -> void:
    # Invincibility blocks ALL damage, even unavoidable
    if _status_manager.has_invincibility(target):
        _show_immune_text(target)
        return

    # ... rest of damage flow ...
```

### 3. Status Effect Immunity
During Invincibility, also block negative status effects:

```gdscript
func apply_status(target: Fighter, status_data: StatusEffectData, source: Fighter = null) -> bool:
    # Block negative effects during invincibility
    if _is_negative_effect(status_data.effect_type):
        if has_invincibility(target):
            return false  # Blocked

    # Normal application...
```

### 4. Invincibility Visual Effect
While Invincibility is active:
- Golden aura/glow around Warden
- Shield bubble effect
- Damage numbers show as "IMMUNE"
- Timer countdown visible

```gdscript
# In Fighter or HUD

func _on_invincibility_applied(fighter: Fighter, duration: float) -> void:
    _show_invincibility_aura(fighter)
    _start_invincibility_timer(duration)

func _on_invincibility_expired(fighter: Fighter) -> void:
    _hide_invincibility_aura(fighter)
    _show_invincibility_end_effect(fighter)
```

### 5. Ultimate Activation
Verify CombatManager.activate_ultimate works for Warden:

```gdscript
func activate_ultimate(fighter: Fighter) -> bool:
    var char_data = _get_character_data(fighter)
    if not char_data or not char_data.ultimate_ability:
        return false

    var ability = char_data.ultimate_ability

    # Check mana
    if ability.requires_full_mana:
        if not mana_system.can_use_ultimate(fighter):
            return false

    # Drain mana
    if ability.drains_all_mana:
        mana_system.drain_all(fighter)

    # Apply effects (invincibility status)
    for effect_data in ability.effects:
        effect_processor.process_effect(effect_data, fighter)

    ultimate_activated.emit(fighter, ability)
    return true
```

### 6. Interaction with Defensive Queue
During Invincibility:
- Defensive queue can still be used (stacking for after)
- Absorb doesn't store damage (no damage incoming)
- Reflection has nothing to reflect

### 7. Duration Timer UI
Show remaining invincibility time:
- Progress bar overlay
- Countdown number
- Warning flash when about to expire

### 8. Sound and Visual Feedback
- Activation: Dramatic power-up sound, flash
- During: Low hum, golden particles
- Expiring: Warning sound at 2 seconds
- Expired: Dispel sound, aura fade

## Acceptance Criteria
- [ ] Ultimate requires full mana
- [ ] Activation drains all mana
- [ ] Complete damage immunity for 8 seconds
- [ ] Negative status effects blocked
- [ ] Visual aura while active
- [ ] Timer countdown visible
- [ ] Warning when about to expire
- [ ] Proper interaction with defensive queue
