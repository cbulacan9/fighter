# Task 039: Click Activation Flow

## Objective
Implement the effect processing system for click-activated tiles.

## Dependencies
- Task 038 (Click Input Handler)
- Task 030 (Status Effect Integration)
- Task 034 (Mana System Core)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Clickable Tiles section
- `/docs/CHARACTERS.md` → Specialty tile effects

## Deliverables

### 1. Create EffectProcessor
Create `/scripts/systems/effect_processor.gd`:

```gdscript
class_name EffectProcessor extends RefCounted

signal effect_processed(effect: EffectData, source: Fighter, target: Fighter, value: int)
signal effect_failed(effect: EffectData, reason: String)

var _combat_manager: CombatManager
var _status_manager: StatusEffectManager
var _mana_system: ManaSystem

func setup(combat_manager: CombatManager) -> void:
    _combat_manager = combat_manager
    if combat_manager:
        _status_manager = combat_manager.status_effect_manager
        _mana_system = combat_manager.mana_system

func process_effect(effect: EffectData, source: Fighter, match_count: int = 0) -> void:
    if effect == null:
        return

    var target = _resolve_target(effect.target, source)
    var value = _calculate_value(effect, match_count)

    match effect.effect_type:
        EffectData.EffectType.DAMAGE:
            _apply_damage(target, source, value)

        EffectData.EffectType.HEAL:
            _apply_heal(target, value)

        EffectData.EffectType.SHIELD:
            _apply_shield(target, value)

        EffectData.EffectType.STUN:
            _apply_stun(target, effect.duration)

        EffectData.EffectType.STATUS_APPLY:
            _apply_status(target, source, effect.status_effect)

        EffectData.EffectType.STATUS_REMOVE:
            _remove_status(target, effect.status_types_to_remove)

        EffectData.EffectType.MANA_ADD:
            _add_mana(target, value)

        EffectData.EffectType.MANA_DRAIN:
            _drain_mana(target, value)

        EffectData.EffectType.TILE_TRANSFORM:
            _transform_tiles(effect, source)

        EffectData.EffectType.TILE_HIDE:
            _hide_tiles(effect, source)

        EffectData.EffectType.CUSTOM:
            _process_custom_effect(effect, source, target)

    effect_processed.emit(effect, source, target, value)

func _resolve_target(target_type: EffectData.EffectTarget, source: Fighter) -> Fighter:
    if not _combat_manager:
        return null

    match target_type:
        EffectData.EffectTarget.SELF:
            return source
        EffectData.EffectTarget.ENEMY:
            return _get_enemy_of(source)
        EffectData.EffectTarget.BOTH:
            return null  # Handle both in effect-specific logic
        _:
            return source

func _get_enemy_of(fighter: Fighter) -> Fighter:
    if not _combat_manager:
        return null

    if fighter == _combat_manager.player_fighter:
        return _combat_manager.enemy_fighter
    else:
        return _combat_manager.player_fighter

func _calculate_value(effect: EffectData, match_count: int) -> int:
    if match_count > 0:
        return effect.get_value_for_match(match_count)
    return effect.base_value

func _apply_damage(target: Fighter, source: Fighter, amount: int) -> void:
    if target and _combat_manager:
        _combat_manager._apply_damage(target, source, amount)

func _apply_heal(target: Fighter, amount: int) -> void:
    if target:
        target.heal(amount)
        if _combat_manager:
            _combat_manager.healing_done.emit(target, amount)

func _apply_shield(target: Fighter, amount: int) -> void:
    if target:
        target.add_armor(amount)
        if _combat_manager:
            _combat_manager.armor_gained.emit(target, amount)

func _apply_stun(target: Fighter, duration: float) -> void:
    if target and _combat_manager:
        _combat_manager.apply_stun(target, duration)

func _apply_status(target: Fighter, source: Fighter, status_data: StatusEffectData) -> void:
    if target and _status_manager and status_data:
        _status_manager.apply(target, status_data, source)

func _remove_status(target: Fighter, types: Array[int]) -> void:
    if target and _status_manager:
        var typed_array: Array[StatusTypes.StatusType] = []
        for t in types:
            typed_array.append(t as StatusTypes.StatusType)
        _status_manager.cleanse(target, typed_array)

func _add_mana(target: Fighter, amount: int) -> void:
    if target and _mana_system:
        _mana_system.add_mana(target, amount)

func _drain_mana(target: Fighter, amount: int) -> void:
    if target and _mana_system:
        _mana_system.drain(target, amount)

func _transform_tiles(effect: EffectData, source: Fighter) -> void:
    # Tile transformation handled by BoardManager
    # Emit signal for BoardManager to process
    pass

func _hide_tiles(effect: EffectData, source: Fighter) -> void:
    # Tile hiding (smoke bomb) handled by BoardManager
    # Emit signal for BoardManager to process
    pass

func _process_custom_effect(effect: EffectData, source: Fighter, target: Fighter) -> void:
    # Custom effects identified by effect.custom_effect_id
    # Implement specific logic or use a registry pattern
    match effect.custom_effect_id:
        "smoke_bomb_passive":
            _smoke_bomb_passive(source)
        "smoke_bomb_active":
            _smoke_bomb_active(source)
        "shadow_step_passive":
            _shadow_step_passive(source, effect)
        "shadow_step_active":
            _shadow_step_active(target, effect)
        _:
            push_warning("Unknown custom effect: %s" % effect.custom_effect_id)

# === Character-Specific Custom Effects ===

func _smoke_bomb_passive(source: Fighter) -> void:
    # Hide 1 enemy tile in smoke for 3 seconds
    var enemy_board = _get_enemy_board(source)
    if enemy_board:
        enemy_board.hide_random_tiles(1, 3.0)

func _smoke_bomb_active(source: Fighter) -> void:
    # Hide random enemy row + column for 3 seconds
    var enemy_board = _get_enemy_board(source)
    if enemy_board:
        enemy_board.hide_random_row_and_column(3.0)

func _shadow_step_passive(source: Fighter, effect: EffectData) -> void:
    # Grant dodge chance based on match size
    # Effect data should contain dodge chance values
    if _status_manager:
        var dodge_effect = StatusEffectData.new()
        dodge_effect.effect_type = StatusTypes.StatusType.DODGE
        dodge_effect.duration = 10.0
        dodge_effect.base_value = effect.base_value  # Dodge chance
        _status_manager.apply(source, dodge_effect)

func _shadow_step_active(target: Fighter, effect: EffectData) -> void:
    # Block enemy mana generation for 5 seconds
    if _mana_system and target:
        _mana_system.block_mana(target, effect.duration)

func _get_enemy_board(source: Fighter) -> BoardManager:
    # Get the enemy's board manager
    # This requires access to GameManager or board references
    return null  # Implement based on scene structure
```

### 2. Integrate with CombatManager
Modify `/scripts/managers/combat_manager.gd`:

```gdscript
# Add to CombatManager

var effect_processor: EffectProcessor

func _ready() -> void:
    # ... existing code ...
    _setup_effect_processor()

func _setup_effect_processor() -> void:
    effect_processor = EffectProcessor.new()
    effect_processor.setup(self)

func process_tile_activation(tile: Tile, source: Fighter) -> void:
    if not tile or not tile.tile_data:
        return

    var data = tile.tile_data as TileData
    if data.click_effect:
        effect_processor.process_effect(data.click_effect, source)

func process_match_effect(tile_data: TileData, source: Fighter, match_count: int) -> void:
    if tile_data.match_effect:
        effect_processor.process_effect(tile_data.match_effect, source, match_count)

    if tile_data.passive_effect:
        effect_processor.process_effect(tile_data.passive_effect, source, match_count)
```

### 3. Connect BoardManager to CombatManager
Modify BoardManager to use effect processing:

```gdscript
# In BoardManager

func _on_tile_activated(tile: Tile, effect: EffectData) -> void:
    # Forward to CombatManager for effect processing
    var combat_manager = _get_combat_manager()
    if combat_manager:
        combat_manager.process_tile_activation(tile, _get_owner_fighter())

func _get_combat_manager() -> CombatManager:
    return get_node_or_null("/root/Main/CombatManager")

func _get_owner_fighter() -> Fighter:
    var combat_manager = _get_combat_manager()
    if combat_manager:
        if is_player_board:
            return combat_manager.player_fighter
        else:
            return combat_manager.enemy_fighter
    return null
```

### 4. Add Tile Hiding Support to BoardManager
For Smoke Bomb effects:

```gdscript
# Add to BoardManager

signal tiles_hidden(positions: Array, duration: float)
signal tiles_revealed(positions: Array)

var _hidden_tiles: Dictionary = {}  # {Vector2i: float remaining_time}

func hide_random_tiles(count: int, duration: float) -> void:
    var available_positions: Array[Vector2i] = []
    for row in range(_grid.ROWS):
        for col in range(_grid.COLS):
            var pos = Vector2i(row, col)
            if not _hidden_tiles.has(pos):
                var tile = _grid.get_tile(row, col)
                if tile:
                    available_positions.append(pos)

    available_positions.shuffle()
    var to_hide = available_positions.slice(0, mini(count, available_positions.size()))

    for pos in to_hide:
        _hide_tile_at(pos, duration)

    tiles_hidden.emit(to_hide, duration)

func hide_random_row_and_column(duration: float) -> void:
    var row = randi() % _grid.ROWS
    var col = randi() % _grid.COLS

    var positions: Array[Vector2i] = []

    # Hide entire row
    for c in range(_grid.COLS):
        var pos = Vector2i(row, c)
        if not _hidden_tiles.has(pos):
            _hide_tile_at(pos, duration)
            positions.append(pos)

    # Hide entire column
    for r in range(_grid.ROWS):
        if r != row:  # Skip intersection
            var pos = Vector2i(r, col)
            if not _hidden_tiles.has(pos):
                _hide_tile_at(pos, duration)
                positions.append(pos)

    tiles_hidden.emit(positions, duration)

func _hide_tile_at(pos: Vector2i, duration: float) -> void:
    _hidden_tiles[pos] = duration
    var tile = _grid.get_tile(pos.x, pos.y)
    if tile:
        tile.set_hidden(true)

func _process_hidden_tiles(delta: float) -> void:
    var to_reveal: Array[Vector2i] = []

    for pos in _hidden_tiles.keys():
        _hidden_tiles[pos] -= delta
        if _hidden_tiles[pos] <= 0:
            to_reveal.append(pos)

    for pos in to_reveal:
        _hidden_tiles.erase(pos)
        var tile = _grid.get_tile(pos.x, pos.y)
        if tile:
            tile.set_hidden(false)

    if to_reveal.size() > 0:
        tiles_revealed.emit(to_reveal)
```

### 5. Add Hidden State to Tile
Modify `/scripts/entities/tile.gd`:

```gdscript
# Add to Tile

var is_hidden: bool = false

func set_hidden(hidden: bool) -> void:
    is_hidden = hidden
    if hidden:
        # Show smoke/fog overlay
        modulate = Color(0.3, 0.3, 0.3, 0.8)
        # Or use a smoke sprite overlay
    else:
        modulate = Color.WHITE
```

## Acceptance Criteria
- [ ] EffectProcessor handles all effect types
- [ ] Effects correctly resolve targets (self/enemy)
- [ ] Match count affects effect values
- [ ] Status effects applied through processor
- [ ] Mana effects work through processor
- [ ] Custom effects dispatch correctly
- [ ] Tile hiding works with duration
- [ ] Hidden tiles reveal after timer
- [ ] Integration with CombatManager complete
