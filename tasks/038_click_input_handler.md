# Task 038: Click Input Handler

## Objective
Extend input handling to support click-to-activate tiles separate from drag gestures.

## Dependencies
- Task 037 (Tile Data Extension)
- Task 006 (Input Handler)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Clickable Tiles section

## Deliverables

### 1. Extend InputHandler for Click Detection
Modify `/scripts/systems/input_handler.gd`:

```gdscript
# Add to InputHandler

signal tile_clicked(tile: Tile)
signal tile_click_attempted(tile: Tile, success: bool)

@export var click_threshold: float = 10.0  # Max movement for click vs drag
@export var click_time_threshold: float = 0.3  # Max time for click

var _press_position: Vector2 = Vector2.ZERO
var _press_time: float = 0.0
var _press_tile: Tile = null
var _is_potential_click: bool = false

func _input(event: InputEvent) -> void:
    if not _input_enabled:
        return

    if event is InputEventMouseButton:
        _handle_mouse_button(event)
    elif event is InputEventMouseMotion:
        _handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
    if event.button_index != MOUSE_BUTTON_LEFT:
        return

    if event.pressed:
        _on_press(event.position)
    else:
        _on_release(event.position)

func _on_press(position: Vector2) -> void:
    _press_position = position
    _press_time = Time.get_ticks_msec() / 1000.0
    _press_tile = _get_tile_at_position(position)
    _is_potential_click = true

    # Existing drag start logic...
    _start_drag(position)

func _on_release(position: Vector2) -> void:
    var release_time = Time.get_ticks_msec() / 1000.0
    var elapsed = release_time - _press_time
    var movement = position.distance_to(_press_position)

    # Check if this was a click (short time, minimal movement)
    if _is_potential_click and elapsed < click_time_threshold and movement < click_threshold:
        _handle_click(_press_tile)
    else:
        # Existing drag release logic...
        _end_drag(position)

    _is_potential_click = false
    _press_tile = null

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
    if not _is_dragging:
        return

    var movement = event.position.distance_to(_press_position)
    if movement >= click_threshold:
        _is_potential_click = false

    # Existing drag motion logic...
    _update_drag(event.position)

func _handle_click(tile: Tile) -> void:
    if tile == null:
        return

    # Check if tile is clickable
    if not tile.tile_data or not tile.tile_data.is_clickable:
        return

    # Emit signal for BoardManager to handle
    tile_clicked.emit(tile)

func _get_tile_at_position(position: Vector2) -> Tile:
    # Convert screen position to tile
    # This should use existing grid/tile position logic
    var local_pos = to_local(position)
    var grid_pos = _screen_to_grid(local_pos)
    return _grid.get_tile(grid_pos.x, grid_pos.y)
```

### 2. Add Click Handling to BoardManager
Modify `/scripts/managers/board_manager.gd`:

```gdscript
# Add to BoardManager

signal tile_activated(tile: Tile, effect: EffectData)

var click_condition_checker: ClickConditionChecker

func _ready() -> void:
    # ... existing code ...
    _setup_click_handling()

func _setup_click_handling() -> void:
    click_condition_checker = ClickConditionChecker.new()

    if _input_handler:
        _input_handler.tile_clicked.connect(_on_tile_clicked)

func _on_tile_clicked(tile: Tile) -> void:
    if state != BoardState.IDLE:
        return  # Can't click during resolution or stun

    if not _can_click_tile(tile):
        _input_handler.tile_click_attempted.emit(tile, false)
        return

    _activate_tile(tile)
    _input_handler.tile_click_attempted.emit(tile, true)

func _can_click_tile(tile: Tile) -> bool:
    if not tile or not tile.tile_data:
        return false

    if not tile.tile_data.is_clickable:
        return false

    # Use condition checker
    var fighter = _get_owner_fighter()
    return click_condition_checker.can_click(tile, fighter)

func _activate_tile(tile: Tile) -> void:
    var data = tile.tile_data as TileData

    # Start cooldown if applicable
    click_condition_checker.start_cooldown(tile)

    # Get click effect
    var effect = data.click_effect
    if effect:
        tile_activated.emit(tile, effect)

    # Visual feedback
    tile.play_activation_animation()

    # Some tiles are consumed on activation
    if _should_consume_tile(tile):
        _consume_tile(tile)

func _should_consume_tile(tile: Tile) -> bool:
    # Pet tiles are not consumed, just trigger effect
    # Other clickable tiles might be consumed
    return false  # Default: don't consume

func _consume_tile(tile: Tile) -> void:
    var pos = _grid.get_tile_position(tile)
    _grid.remove_tile(pos.x, pos.y)
    # Trigger cascade/refill
```

### 3. Add Visual Feedback for Clickable Tiles
Modify `/scripts/entities/tile.gd`:

```gdscript
# Add to Tile

signal clicked()
signal activation_started()
signal activation_finished()

var is_clickable_highlighted: bool = false
var _highlight_tween: Tween

func update_clickable_state(can_click: bool) -> void:
    if can_click and not is_clickable_highlighted:
        _show_clickable_highlight()
    elif not can_click and is_clickable_highlighted:
        _hide_clickable_highlight()

func _show_clickable_highlight() -> void:
    is_clickable_highlighted = true

    if _highlight_tween:
        _highlight_tween.kill()

    # Pulsing glow effect
    _highlight_tween = create_tween()
    _highlight_tween.set_loops()
    _highlight_tween.tween_property(self, "modulate", Color(1.2, 1.2, 0.8), 0.5)
    _highlight_tween.tween_property(self, "modulate", Color.WHITE, 0.5)

func _hide_clickable_highlight() -> void:
    is_clickable_highlighted = false

    if _highlight_tween:
        _highlight_tween.kill()
        _highlight_tween = null

    modulate = Color.WHITE

func play_activation_animation() -> void:
    activation_started.emit()

    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
    tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
    tween.tween_callback(func(): activation_finished.emit())
```

### 4. Update Clickable State on Relevant Events
Add to BoardManager:

```gdscript
func _process(_delta: float) -> void:
    # Update clickable highlights based on current state
    _update_clickable_highlights()

func _update_clickable_highlights() -> void:
    if state != BoardState.IDLE:
        # Hide all highlights when not idle
        for tile in _grid.get_all_tiles():
            if tile:
                tile.update_clickable_state(false)
        return

    var fighter = _get_owner_fighter()
    for tile in _grid.get_all_tiles():
        if tile and tile.tile_data and tile.tile_data.is_clickable:
            var can_click = click_condition_checker.can_click(tile, fighter)
            tile.update_clickable_state(can_click)
```

## Acceptance Criteria
- [ ] Click detection distinct from drag gestures
- [ ] Click threshold prevents accidental clicks during drag
- [ ] Time threshold for click duration
- [ ] Clickable tiles emit signals when clicked
- [ ] BoardManager validates click conditions
- [ ] Visual highlight for clickable tiles
- [ ] Activation animation plays on click
- [ ] Clicks blocked during RESOLVING/STUNNED states
