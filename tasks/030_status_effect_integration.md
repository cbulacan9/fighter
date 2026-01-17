# Task 030: Status Effect Integration

## Objective
Integrate StatusEffectManager with existing game systems (Fighter, CombatManager, GameManager).

## Dependencies
- Task 029 (Status Effect Manager)
- Task 013 (Combat Manager)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Status Effects Integration Points

## Deliverables

### 1. Extend Fighter Class
Modify `/scripts/entities/fighter.gd`:

```gdscript
# Add to Fighter class

signal status_effect_applied(effect: StatusEffect)
signal status_effect_removed(effect_type: StatusTypes.StatusType)

# Reference to manager (set by CombatManager)
var status_manager: StatusEffectManager

func has_status(effect_type: StatusTypes.StatusType) -> bool:
    if status_manager:
        return status_manager.has_effect(self, effect_type)
    return false

func get_status_stacks(effect_type: StatusTypes.StatusType) -> int:
    if status_manager:
        return status_manager.get_stacks(self, effect_type)
    return 0

func is_mana_blocked() -> bool:
    return has_status(StatusTypes.StatusType.MANA_BLOCK)
```

### 2. Extend CombatManager
Modify `/scripts/managers/combat_manager.gd`:

```gdscript
# Add to CombatManager

var status_effect_manager: StatusEffectManager

signal status_effect_applied(target: Fighter, effect: StatusEffect)
signal status_effect_removed(target: Fighter, effect_type: StatusTypes.StatusType)
signal status_damage_dealt(target: Fighter, damage: float, effect_type: StatusTypes.StatusType)

func _ready() -> void:
    # ... existing code ...
    _setup_status_effects()

func _setup_status_effects() -> void:
    status_effect_manager = StatusEffectManager.new()

    # Connect signals
    status_effect_manager.effect_applied.connect(_on_status_effect_applied)
    status_effect_manager.effect_removed.connect(_on_status_effect_removed)
    status_effect_manager.effect_ticked.connect(_on_status_effect_ticked)

    # Set manager reference on fighters
    if player_fighter:
        player_fighter.status_manager = status_effect_manager
    if enemy_fighter:
        enemy_fighter.status_manager = status_effect_manager

func tick(delta: float) -> void:
    # ... existing stun tick code ...

    # Tick status effects
    if status_effect_manager:
        status_effect_manager.tick(delta)

func apply_status_effect(target: Fighter, effect_data: StatusEffectData, source: Fighter = null, stacks: int = 1) -> void:
    if status_effect_manager:
        status_effect_manager.apply(target, effect_data, source, stacks)

func cleanse_status(target: Fighter, types: Array[StatusTypes.StatusType] = []) -> void:
    if status_effect_manager:
        status_effect_manager.cleanse(target, types)

func _on_status_effect_applied(target: Fighter, effect: StatusEffect) -> void:
    status_effect_applied.emit(target, effect)
    target.status_effect_applied.emit(effect)

func _on_status_effect_removed(target: Fighter, effect_type: StatusTypes.StatusType) -> void:
    status_effect_removed.emit(target, effect_type)
    target.status_effect_removed.emit(effect_type)

func _on_status_effect_ticked(target: Fighter, effect: StatusEffect, damage: float) -> void:
    status_damage_dealt.emit(target, damage, effect.data.effect_type)
```

### 3. Modify Damage Calculation
Update damage application in CombatManager to respect status effects:

```gdscript
func _apply_damage(target: Fighter, source: Fighter, base_damage: int) -> void:
    var final_damage = base_damage

    # Apply attacker's damage modifiers
    if source and status_effect_manager:
        var attack_bonus = status_effect_manager.get_modifier(source, StatusTypes.StatusType.ATTACK_UP)
        if attack_bonus > 0:
            final_damage = int(final_damage * (1.0 + attack_bonus))

    # Check target's defensive effects
    if status_effect_manager:
        # Check dodge
        if status_effect_manager.has_effect(target, StatusTypes.StatusType.DODGE):
            var dodge_chance = status_effect_manager.get_modifier(target, StatusTypes.StatusType.DODGE)
            if randf() < dodge_chance:
                # Damage dodged - emit signal for UI feedback
                damage_dodged.emit(target)
                return

        # Check evasion (auto-miss, consumes effect)
        if status_effect_manager.has_effect(target, StatusTypes.StatusType.EVASION):
            status_effect_manager.remove(target, StatusTypes.StatusType.EVASION)
            damage_dodged.emit(target)
            return

    # Apply damage normally
    var result = target.take_damage(final_damage)
    damage_dealt.emit(target, result)
```

### 4. Connect to Match Resolution
Notify status manager when matches occur (for ON_MATCH effects like Bleed):

```gdscript
# In CombatManager or BoardManager

func _on_matches_resolved(result: CascadeHandler.CascadeResult, is_player: bool) -> void:
    var matcher = player_fighter if is_player else enemy_fighter

    # Notify status manager that this fighter matched
    if status_effect_manager:
        status_effect_manager._on_target_matched(matcher)

    # ... rest of existing match processing ...
```

### 5. Update GameManager
Connect new CombatManager signals in GameManager:

```gdscript
func _connect_signals() -> void:
    # ... existing connections ...

    if combat_manager:
        combat_manager.status_effect_applied.connect(_on_status_effect_applied)
        combat_manager.status_effect_removed.connect(_on_status_effect_removed)
        combat_manager.status_damage_dealt.connect(_on_status_damage_dealt)

func _on_status_effect_applied(target: Fighter, effect: StatusEffect) -> void:
    # Forward to UI (implemented in Task 031)
    pass

func _on_status_effect_removed(target: Fighter, effect_type: StatusTypes.StatusType) -> void:
    # Forward to UI
    pass

func _on_status_damage_dealt(target: Fighter, damage: float, effect_type: StatusTypes.StatusType) -> void:
    # Spawn damage number for DoT
    pass
```

### 6. Reset on Match End
Ensure status effects are cleared when match resets:

```gdscript
# In CombatManager.reset()
func reset() -> void:
    # ... existing reset code ...

    if status_effect_manager:
        status_effect_manager.remove_all(player_fighter)
        status_effect_manager.remove_all(enemy_fighter)
```

## Acceptance Criteria
- [ ] Fighter has status effect query methods
- [ ] CombatManager owns and ticks StatusEffectManager
- [ ] Status effects modify damage calculation
- [ ] ON_MATCH effects trigger when fighter matches
- [ ] Signals propagate from manager → CombatManager → GameManager
- [ ] Effects cleared on match reset
- [ ] No crashes when applying effects during gameplay
