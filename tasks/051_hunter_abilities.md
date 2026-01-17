# Task 051: Hunter Abilities (Bear/Hawk/Snake)

## Objective
Implement the three pet ability effects and their corresponding self-buffs.

## Dependencies
- Task 050 (Pet Tile Implementation)
- Task 030 (Status Effect Integration)
- Task 039 (Click Activation Flow)

## Reference
- `/docs/CHARACTERS.md` → Hunter Pet Abilities

## Deliverables

### 1. Bear Ability - Bleed + Attack Buff

**Bear Offensive: Bleed Stack**
Create `/resources/effects/bear_bleed.tres`:
```gdscript
effect_type = STATUS_APPLY
target = ENEMY
status_effect = bleed_status.tres
```

Create `/resources/effects/bleed_status.tres`:
```gdscript
effect_type = BLEED
duration = 0.0  # Until triggered
tick_behavior = ON_MATCH
base_value = 10
stack_behavior = ADDITIVE
max_stacks = 5
```

**Bear Self-Buff: Attack Strength**
Create `/resources/effects/bear_attack_up.tres`:
```gdscript
effect_type = STATUS_APPLY
target = SELF
status_effect = attack_up_status.tres
```

### 2. Hawk Ability - Tile Replace + Evasion

**Hawk Offensive: Replace Enemy Tiles**
Create `/resources/effects/hawk_replace.tres`:
```gdscript
effect_type = CUSTOM
target = BOARD_ENEMY
custom_effect_id = "hawk_tile_replace"
base_value = 10  # Number of tiles to replace
```

Implement in EffectProcessor:
```gdscript
func _hawk_tile_replace(source: Fighter, value: int) -> void:
    var enemy_board = _get_enemy_board(source)
    if not enemy_board:
        return

    # Get random matchable tile positions
    var positions = enemy_board.get_random_matchable_positions(value)

    # Replace with empty box tiles
    for pos in positions:
        enemy_board.replace_tile_at(pos, TileTypes.TileType.FILLER)
```

**Hawk Self-Buff: Evasion**
Create `/resources/effects/hawk_evasion.tres`:
```gdscript
effect_type = STATUS_APPLY
target = SELF
status_effect = evasion_status.tres
```

Create `/resources/effects/evasion_status.tres`:
```gdscript
effect_type = EVASION
duration = 0.0  # Until consumed
stack_behavior = ADDITIVE
max_stacks = 3
```

### 3. Snake Ability - Board Stun + Cleanse

**Snake Offensive: Board Stun**
Create `/resources/effects/snake_stun.tres`:
```gdscript
effect_type = STUN
target = ENEMY
duration = 3.0
```

**Snake Self-Buff: Cleanse Poison**
Create `/resources/effects/snake_cleanse.tres`:
```gdscript
effect_type = STATUS_REMOVE
target = SELF
status_types_to_remove = [POISON]
```

### 4. Add Tile Replacement to BoardManager
```gdscript
func get_random_matchable_positions(count: int) -> Array[Vector2i]:
    var matchable: Array[Vector2i] = []

    for row in range(_grid.ROWS):
        for col in range(_grid.COLS):
            var tile = _grid.get_tile(row, col)
            if tile and tile.tile_data and tile.tile_data.is_matchable:
                matchable.append(Vector2i(row, col))

    matchable.shuffle()
    return matchable.slice(0, mini(count, matchable.size()))

func replace_tile_at(pos: Vector2i, new_type: TileTypes.TileType) -> void:
    var old_tile = _grid.get_tile(pos.x, pos.y)
    if old_tile:
        old_tile.queue_free()

    var new_tile = _tile_spawner._create_tile(new_type)
    _grid.set_tile(pos.x, pos.y, new_tile)

    # Visual feedback
    new_tile.play_spawn_animation()
```

### 5. Stacking Self-Buffs
Implement 3x stack limit for self-buffs as specified:

```gdscript
# In status effect application, check for existing stacks
func _apply_self_buff(fighter: Fighter, effect_data: StatusEffectData) -> void:
    var current_stacks = _status_manager.get_stacks(fighter, effect_data.effect_type)

    if current_stacks >= 3:
        # Already at max self-buff stacks
        return

    _status_manager.apply(fighter, effect_data)
```

### 6. Create Effect Visual Feedback
Add visual feedback for each ability:

```gdscript
# Bear: Red slash effect on enemy
# Hawk: Tiles transforming with particle effect
# Snake: Freeze/ice effect on enemy board

func _show_ability_effect(ability_id: String, target_position: Vector2) -> void:
    match ability_id:
        "bear":
            _spawn_bleed_effect(target_position)
        "hawk":
            _spawn_replace_effect(target_position)
        "snake":
            _spawn_stun_effect(target_position)
```

## Acceptance Criteria
- [ ] Bear bleed applies damage on enemy match
- [ ] Bear attack buff stacks up to 3x
- [ ] Hawk replaces 10 enemy tiles with empty boxes
- [ ] Hawk evasion makes next attack auto-miss
- [ ] Snake stuns enemy board for 3 seconds
- [ ] Snake cleanses poison from self
- [ ] Self-buffs cap at 3 stacks
- [ ] Visual feedback for each ability
