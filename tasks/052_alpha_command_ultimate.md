# Task 052: Alpha Command Ultimate

## Objective
Implement the Hunter's ultimate ability that doubles pet ability effects.

## Dependencies
- Task 051 (Hunter Abilities)
- Task 034 (Mana System Core)

## Reference
- `/docs/CHARACTERS.md` → Hunter Ultimate

## Deliverables

### 1. Create Alpha Command Status Effect
Create `/resources/effects/alpha_command_status.tres`:

```gdscript
effect_type = ALPHA_COMMAND  # New status type
duration = 8.0
tick_behavior = ON_TIME
tick_interval = 1.0  # For decay tracking
base_value = 2.0  # 2x multiplier
value_per_stack = 0.0
stack_behavior = REPLACE
```

Add to StatusTypes:
```gdscript
enum StatusType {
    # ... existing types ...
    ALPHA_COMMAND,  # Hunter ultimate buff
}
```

### 2. Create Alpha Command Ability
Create `/resources/abilities/alpha_command.tres`:

```gdscript
ability_id = "alpha_command"
display_name = "Alpha Command"
description = "Your animal companions become empowered. Pet abilities deal 2x damage and self-buffs are 2x stronger. Effect decays over 8 seconds."
icon = [alpha_command_icon.png]
requires_full_mana = true
drains_all_mana = true
duration = 8.0

effects = [alpha_command_apply.tres]
```

### 3. Create Alpha Command Effect
Create `/resources/effects/alpha_command_apply.tres`:

```gdscript
effect_type = STATUS_APPLY
target = SELF
status_effect = alpha_command_status.tres
```

### 4. Implement Multiplier Decay
```gdscript
# In StatusEffectManager or Alpha Command handler

func get_alpha_command_multiplier(fighter: Fighter) -> float:
    var effect = get_effect(fighter, StatusTypes.StatusType.ALPHA_COMMAND)
    if not effect:
        return 1.0

    # Calculate decay based on remaining duration
    var total_duration = effect.data.duration
    var remaining = effect.remaining_duration

    if total_duration <= 0:
        return effect.data.base_value

    # Linear decay from 2x to 1x
    var progress = remaining / total_duration
    var multiplier = 1.0 + (effect.data.base_value - 1.0) * progress

    return multiplier
```

### 5. Ultimate Activation Flow
Modify BoardManager or CombatManager:

```gdscript
func activate_ultimate(fighter: Fighter) -> void:
    var char_data = _get_character_data(fighter)
    if not char_data or not char_data.ultimate_ability:
        return

    var ability = char_data.ultimate_ability

    # Check mana requirement
    if ability.requires_full_mana:
        if not _mana_system.can_use_ultimate(fighter):
            return

    # Drain mana
    if ability.drains_all_mana:
        _mana_system.drain_all(fighter)

    # Apply effects
    for effect in ability.effects:
        _effect_processor.process_effect(effect, fighter)

    # Visual feedback
    _show_ultimate_activation(fighter, ability)

func _show_ultimate_activation(fighter: Fighter, ability: AbilityData) -> void:
    # Full-screen flash or character animation
    # Sound effect
    # Ability name display
    pass
```

### 6. Modify Pet Ability to Use Multiplier
```gdscript
func _process_pet_ability(pattern: SequencePattern, stacks: int, _unused: float) -> void:
    var fighter = _get_owner_fighter()
    var combat_manager = _get_combat_manager()

    if not combat_manager:
        return

    # Get actual multiplier from Alpha Command
    var multiplier = 1.0
    if combat_manager.status_effect_manager:
        multiplier = combat_manager.status_effect_manager.get_alpha_command_multiplier(fighter)

    # Apply offensive effect with multiplier
    if pattern.on_complete_effect:
        var scaled_value = int(pattern.on_complete_effect.base_value * multiplier)
        # Create modified effect or pass multiplier
        _apply_scaled_effect(pattern.on_complete_effect, fighter, multiplier)

    # Apply self-buff with multiplier
    if pattern.self_buff_effect:
        _apply_scaled_effect(pattern.self_buff_effect, fighter, multiplier)
```

### 7. Ultimate UI Indicator
Show when ultimate is ready and active:

```gdscript
# In HUD or ManaBarContainer

func _on_all_bars_full(fighter: Fighter) -> void:
    if fighter == _player_fighter:
        _show_ultimate_ready_indicator()

func _show_ultimate_ready_indicator() -> void:
    # Glow effect on mana bar
    # "Ultimate Ready" text
    # Optional: Show ability icon
    pass
```

### 8. Alpha Command Visual Effect
```gdscript
func _show_alpha_command_active(fighter: Fighter) -> void:
    # Aura around fighter portrait
    # Glowing effect on pet tiles
    # Particle effects
    pass

func _show_alpha_command_decay(remaining: float, total: float) -> void:
    # Fade the aura based on decay
    var intensity = remaining / total
    # Update visual intensity
    pass
```

## Acceptance Criteria
- [ ] Alpha Command requires full mana
- [ ] Activation drains all mana
- [ ] 2x multiplier applied to pet abilities
- [ ] Multiplier decays over 8 seconds
- [ ] Visual indicator when ultimate ready
- [ ] Visual effect while ultimate active
- [ ] Decay visible in UI
