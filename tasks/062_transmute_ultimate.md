# Task 062: Transmute Ultimate

## Objective
Implement the Apothecary's ultimate ability that poisons tiles on the enemy's board.

## Dependencies
- Task 061 (Poison & Potion Implementation)
- Task 034 (Mana System Core)

## Reference
- `/docs/CHARACTERS.md` → Apothecary Ultimate Ability

## Overview
Transmute poisons 10 random tiles on the enemy's board. When enemy matches poisoned tiles, they take unavoidable poison damage. Damage scales with existing poison status.

## Deliverables

### 1. Add TRANSMUTE_POISON to TileData
Tiles can have a "poisoned" state that's separate from status effects:

```gdscript
# In Tile entity
var is_transmute_poisoned: bool = false
var transmute_poison_source: Fighter = null
var transmute_poison_damage: int = 15

func set_transmute_poisoned(poisoned: bool, source: Fighter = null, damage: int = 15) -> void:
    is_transmute_poisoned = poisoned
    transmute_poison_source = source
    transmute_poison_damage = damage
    _update_poison_visual()

func _update_poison_visual() -> void:
    if is_transmute_poisoned:
        # Add green tint/overlay
        modulate = Color(0.7, 1.0, 0.7, 1.0)
        # Could add particle effect
    else:
        modulate = Color.WHITE
```

### 2. Implement Transmute Effect
Add custom effect handler in EffectProcessor:

```gdscript
func _transmute_poison_board(source: Fighter, value: int) -> void:
    var enemy_board = _get_enemy_board(source)
    if not enemy_board:
        return

    var positions = enemy_board.get_random_matchable_positions(value)

    for pos in positions:
        var tile = enemy_board.get_tile_at(pos)
        if tile:
            tile.set_transmute_poisoned(true, source, _calculate_transmute_damage(source))

func _calculate_transmute_damage(source: Fighter) -> int:
    var base_damage = 15

    # Check if enemy has poison status - bonus damage
    var enemy = _get_enemy_of(source)
    if enemy and _status_manager.has_effect(enemy, StatusTypes.StatusType.POISON):
        var poison_stacks = _status_manager.get_stacks(enemy, StatusTypes.StatusType.POISON)
        base_damage += poison_stacks * 5  # +5 damage per poison stack

    return base_damage
```

### 3. Handle Poisoned Tile Matches
When enemy matches tiles that are transmute-poisoned:

```gdscript
# In BoardManager or CombatManager

func _on_match_resolved(match_result: MatchResult) -> void:
    # Check for transmute-poisoned tiles
    var poison_damage = 0
    var poison_source: Fighter = null

    for pos in match_result.positions:
        var tile = _grid.get_tile(pos.x, pos.y)
        if tile and tile.is_transmute_poisoned:
            poison_damage += tile.transmute_poison_damage
            poison_source = tile.transmute_poison_source

    if poison_damage > 0:
        _apply_transmute_poison_damage(poison_damage, poison_source)
```

### 4. Unavoidable Damage
Transmute poison damage bypasses:
- Dodge (DODGE status)
- Evasion (EVASION status)
- Possibly armor? (design decision)

```gdscript
func _apply_transmute_poison_damage(damage: int, source: Fighter) -> void:
    var target = _get_owner_fighter()  # The one who matched

    # This damage is unavoidable - skip dodge/evasion checks
    target.take_damage(damage, true)  # true = unavoidable

    # Visual feedback
    _show_poison_damage_text(target, damage)
```

### 5. Synergy with Poison Status
If the enemy already has POISON status when matching transmute-poisoned tiles:
- Additional damage multiplier
- Could refresh/add poison stacks

```gdscript
func _apply_transmute_poison_damage(damage: int, source: Fighter) -> void:
    var target = _get_owner_fighter()

    # Synergy: if target has poison status, deal bonus damage
    if _status_manager.has_effect(target, StatusTypes.StatusType.POISON):
        damage = int(damage * 1.5)  # 50% bonus

    target.take_damage(damage, true)
```

### 6. Visual Distinction
Transmute-poisoned tiles need clear visual:
- Green glow/tint
- Poison bubble particles
- Distinct from hidden tiles

### 7. Cleanse Interaction
Hunter's Snake cleanse should also clear transmute poison from own tiles:

```gdscript
func _snake_cleanse(fighter: Fighter) -> void:
    # Clear poison status
    _status_manager.cleanse(fighter, [StatusTypes.StatusType.POISON])

    # Also clear transmute poison from own board
    var own_board = _get_own_board(fighter)
    if own_board:
        own_board.clear_transmute_poison()
```

Add to BoardManager:
```gdscript
func clear_transmute_poison() -> void:
    for row in range(_grid.ROWS):
        for col in range(_grid.COLS):
            var tile = _grid.get_tile(row, col)
            if tile:
                tile.set_transmute_poisoned(false)
```

## Acceptance Criteria
- [ ] Transmute poisons 10 random enemy tiles
- [ ] Poisoned tiles have distinct visual (green tint)
- [ ] Matching poisoned tiles deals damage
- [ ] Damage is unavoidable (bypasses dodge/evasion)
- [ ] Synergy with poison status increases damage
- [ ] Snake cleanse removes transmute poison from board
- [ ] Ultimate requires and drains full mana
