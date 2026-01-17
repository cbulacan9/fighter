# Task 029: Status Effect Manager

## Objective
Implement the core StatusEffectManager that tracks and processes active status effects on fighters.

## Dependencies
- Task 028 (Status Effect Data)
- Task 012 (Fighter State)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Status Effects section

## Deliverables

### 1. Create StatusEffectManager
Create `/scripts/systems/status_effect_manager.gd`:

```gdscript
class_name StatusEffectManager extends RefCounted

signal effect_applied(target: Fighter, effect: StatusEffect)
signal effect_removed(target: Fighter, effect_type: StatusTypes.StatusType)
signal effect_ticked(target: Fighter, effect: StatusEffect, damage: float)
signal effect_stacked(target: Fighter, effect: StatusEffect, new_stacks: int)

# Active effects per fighter: {Fighter: {StatusType: StatusEffect}}
var _active_effects: Dictionary = {}

func apply(target: Fighter, effect_data: StatusEffectData, source: Fighter = null, stacks: int = 1) -> void
func remove(target: Fighter, effect_type: StatusTypes.StatusType) -> void
func remove_all(target: Fighter) -> void
func cleanse(target: Fighter, types: Array[StatusTypes.StatusType] = []) -> void
func tick(delta: float) -> void
func get_effect(target: Fighter, effect_type: StatusTypes.StatusType) -> StatusEffect
func has_effect(target: Fighter, effect_type: StatusTypes.StatusType) -> bool
func get_stacks(target: Fighter, effect_type: StatusTypes.StatusType) -> int
func get_modifier(target: Fighter, effect_type: StatusTypes.StatusType) -> float
func get_all_effects(target: Fighter) -> Array[StatusEffect]
```

### 2. Implement Core Methods

**apply():**
```gdscript
func apply(target: Fighter, effect_data: StatusEffectData, source: Fighter = null, stacks: int = 1) -> void:
    if not _active_effects.has(target):
        _active_effects[target] = {}

    var effects = _active_effects[target]
    var effect_type = effect_data.effect_type

    if effects.has(effect_type):
        # Handle stacking based on behavior
        var existing = effects[effect_type] as StatusEffect
        match effect_data.stack_behavior:
            StatusTypes.StackBehavior.ADDITIVE:
                existing.stacks = mini(existing.stacks + stacks, effect_data.max_stacks)
                effect_stacked.emit(target, existing, existing.stacks)
            StatusTypes.StackBehavior.REFRESH:
                existing.remaining_duration = effect_data.duration
            StatusTypes.StackBehavior.REPLACE:
                effects[effect_type] = StatusEffect.new(effect_data, source)
                effects[effect_type].stacks = stacks
                effect_applied.emit(target, effects[effect_type])
            StatusTypes.StackBehavior.INDEPENDENT:
                # For independent, we'd need array storage - simplified here
                existing.stacks = mini(existing.stacks + stacks, effect_data.max_stacks)
    else:
        var new_effect = StatusEffect.new(effect_data, source)
        new_effect.stacks = mini(stacks, effect_data.max_stacks)
        effects[effect_type] = new_effect
        effect_applied.emit(target, new_effect)
```

**tick():**
```gdscript
func tick(delta: float) -> void:
    for target in _active_effects.keys():
        var effects = _active_effects[target]
        var to_remove: Array[StatusTypes.StatusType] = []

        for effect_type in effects.keys():
            var effect = effects[effect_type] as StatusEffect

            # Update duration
            if effect.data.duration > 0:
                effect.remaining_duration -= delta
                if effect.is_expired():
                    to_remove.append(effect_type)
                    continue

            # Process ticks for ON_TIME effects
            if effect.data.tick_behavior == StatusTypes.TickBehavior.ON_TIME:
                effect.tick_timer += delta
                if effect.tick_timer >= effect.data.tick_interval:
                    effect.tick_timer -= effect.data.tick_interval
                    _process_tick(target, effect)

        # Remove expired effects
        for effect_type in to_remove:
            _remove_internal(target, effect_type)
```

**cleanse():**
```gdscript
func cleanse(target: Fighter, types: Array[StatusTypes.StatusType] = []) -> void:
    if not _active_effects.has(target):
        return

    if types.is_empty():
        # Cleanse all effects
        for effect_type in _active_effects[target].keys():
            effect_removed.emit(target, effect_type)
        _active_effects[target].clear()
    else:
        # Cleanse specific types
        for effect_type in types:
            if _active_effects[target].has(effect_type):
                _remove_internal(target, effect_type)
```

### 3. Implement Modifier Calculation

```gdscript
func get_modifier(target: Fighter, effect_type: StatusTypes.StatusType) -> float:
    var effect = get_effect(target, effect_type)
    if effect == null:
        return 0.0
    return effect.get_value()

# Helper for damage calculation
func apply_damage_modifiers(target: Fighter, base_damage: float) -> float:
    var modified = base_damage

    # Check for ATTACK_UP on attacker (would need attacker param)
    # Check for DODGE on target
    if has_effect(target, StatusTypes.StatusType.DODGE):
        var dodge_chance = get_modifier(target, StatusTypes.StatusType.DODGE)
        if randf() < dodge_chance:
            return 0.0  # Dodged

    # Check for EVASION (auto-miss)
    if has_effect(target, StatusTypes.StatusType.EVASION):
        remove(target, StatusTypes.StatusType.EVASION)
        return 0.0

    return modified
```

### 4. Internal Helper Methods

```gdscript
func _process_tick(target: Fighter, effect: StatusEffect) -> void:
    match effect.data.effect_type:
        StatusTypes.StatusType.POISON:
            var damage = effect.get_value()
            target.take_damage(int(damage))
            effect_ticked.emit(target, effect, damage)
        StatusTypes.StatusType.BLEED:
            # Bleed triggers on match, not time - handled elsewhere
            pass

func _remove_internal(target: Fighter, effect_type: StatusTypes.StatusType) -> void:
    if _active_effects.has(target) and _active_effects[target].has(effect_type):
        _active_effects[target].erase(effect_type)
        effect_removed.emit(target, effect_type)

func _on_target_matched(target: Fighter) -> void:
    # Called when target makes a match - triggers ON_MATCH effects
    if not _active_effects.has(target):
        return

    var bleed = get_effect(target, StatusTypes.StatusType.BLEED)
    if bleed:
        var damage = bleed.get_value()
        target.take_damage(int(damage))
        effect_ticked.emit(target, bleed, damage)
        bleed.stacks -= 1
        if bleed.stacks <= 0:
            _remove_internal(target, StatusTypes.StatusType.BLEED)
```

## Acceptance Criteria
- [ ] StatusEffectManager class created
- [ ] apply() correctly handles all stack behaviors
- [ ] tick() processes duration and time-based effects
- [ ] cleanse() removes effects (all or specific types)
- [ ] Modifier calculation working
- [ ] All signals emit correctly
- [ ] No memory leaks (effects cleaned up when fighter removed)
