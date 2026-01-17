# Task 035: Mana UI Components

## Objective
Create UI components to display mana bars for fighters.

## Dependencies
- Task 034 (Mana System Core)
- Task 015 (HUD)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → UI Requirements

## Deliverables

### 1. Create ManaBar UI Scene
Create `/scenes/ui/mana_bar.tscn`:

Structure:
```
ManaBarUI (Control)
├── Background (ColorRect)
├── Fill (ColorRect)
├── Glow (ColorRect) [for full state]
└── Label (Label) [optional: shows value]
```

### 2. Create ManaBar UI Script
Create `/scripts/ui/mana_bar_ui.gd`:

```gdscript
class_name ManaBarUI extends Control

signal clicked()

@export var fill_color: Color = Color(0.3, 0.5, 1.0)  # Blue
@export var full_color: Color = Color(0.5, 0.8, 1.0)  # Bright blue
@export var blocked_color: Color = Color(0.5, 0.5, 0.5)  # Grey
@export var glow_when_full: bool = true
@export var show_value_label: bool = false
@export var animate_changes: bool = true
@export var animation_duration: float = 0.2

@onready var background: ColorRect = $Background
@onready var fill: ColorRect = $Fill
@onready var glow: ColorRect = $Glow
@onready var label: Label = $Label

var _current_value: int = 0
var _max_value: int = 100
var _is_blocked: bool = false
var _is_full: bool = false
var _tween: Tween

func _ready() -> void:
    if glow:
        glow.visible = false
    if label:
        label.visible = show_value_label
    _update_display()

func setup(max_value: int) -> void:
    _max_value = max_value
    _current_value = 0
    _update_display()

func set_value(current: int, max_value: int = -1) -> void:
    if max_value > 0:
        _max_value = max_value

    var previous = _current_value
    _current_value = current
    _is_full = _current_value >= _max_value

    if animate_changes and previous != current:
        _animate_fill(previous, current)
    else:
        _update_display()

func set_blocked(blocked: bool) -> void:
    _is_blocked = blocked
    _update_display()

func _update_display() -> void:
    if not fill:
        return

    # Calculate fill percentage
    var percentage = 0.0
    if _max_value > 0:
        percentage = clampf(float(_current_value) / float(_max_value), 0.0, 1.0)

    # Update fill width
    fill.anchor_right = percentage

    # Update colors
    if _is_blocked:
        fill.color = blocked_color
    elif _is_full:
        fill.color = full_color
    else:
        fill.color = fill_color

    # Update glow
    if glow:
        glow.visible = glow_when_full and _is_full and not _is_blocked

    # Update label
    if label and show_value_label:
        label.text = "%d/%d" % [_current_value, _max_value]

func _animate_fill(from: int, to: int) -> void:
    if _tween:
        _tween.kill()

    var from_pct = clampf(float(from) / float(_max_value), 0.0, 1.0)
    var to_pct = clampf(float(to) / float(_max_value), 0.0, 1.0)

    _tween = create_tween()
    _tween.tween_property(fill, "anchor_right", to_pct, animation_duration)
    _tween.tween_callback(_update_display)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            clicked.emit()
```

### 3. Create ManaBarContainer for Multiple Bars
Create `/scripts/ui/mana_bar_container.gd`:

```gdscript
class_name ManaBarContainer extends VBoxContainer

@export var mana_bar_scene: PackedScene
@export var bar_spacing: float = 4.0

var _fighter: Fighter
var _mana_system: ManaSystem
var _bars: Array[ManaBarUI] = []

func setup(fighter: Fighter, mana_system: ManaSystem) -> void:
    _fighter = fighter
    _mana_system = mana_system

    # Clear existing bars
    for bar in _bars:
        bar.queue_free()
    _bars.clear()

    if not mana_system:
        return

    # Create bars based on fighter's config
    var bar_count = mana_system.get_bar_count(fighter)
    for i in range(bar_count):
        var bar = _create_bar(i)
        _bars.append(bar)

    # Connect to mana system signals
    if not mana_system.mana_changed.is_connected(_on_mana_changed):
        mana_system.mana_changed.connect(_on_mana_changed)

func _create_bar(bar_index: int) -> ManaBarUI:
    if not mana_bar_scene:
        push_error("ManaBarContainer: mana_bar_scene not set")
        return null

    var bar: ManaBarUI = mana_bar_scene.instantiate()
    add_child(bar)

    var max_mana = _mana_system.get_max_mana(_fighter, bar_index)
    bar.setup(max_mana)

    # Set initial value
    var current = _mana_system.get_mana(_fighter, bar_index)
    bar.set_value(current, max_mana)

    return bar

func _on_mana_changed(fighter: Fighter, bar_index: int, current: int, max_value: int) -> void:
    if fighter != _fighter:
        return

    if bar_index < _bars.size():
        _bars[bar_index].set_value(current, max_value)

func update_blocked_state() -> void:
    if _fighter and _fighter.is_mana_blocked():
        for bar in _bars:
            bar.set_blocked(true)
    else:
        for bar in _bars:
            bar.set_blocked(false)
```

### 4. Create ManaBar Scene File
Create `/scenes/ui/mana_bar.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/mana_bar_ui.gd" id="1"]

[node name="ManaBarUI" type="Control"]
custom_minimum_size = Vector2(150, 12)
script = ExtResource("1")

[node name="Background" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.15, 0.15, 0.2, 1)

[node name="Fill" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 0.0
anchor_bottom = 1.0
color = Color(0.3, 0.5, 1.0, 1)

[node name="Glow" type="ColorRect" parent="."]
visible = false
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.7, 0.9, 1.0, 0.3)

[node name="Label" type="Label" parent="."]
visible = false
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
horizontal_alignment = 1
vertical_alignment = 1
```

### 5. Integrate with HUD
Modify `/scripts/ui/hud.gd`:

```gdscript
# Add to HUD

@onready var player_mana_container: ManaBarContainer = $PlayerPanel/ManaContainer
@onready var enemy_mana_container: ManaBarContainer = $EnemyPanel/ManaContainer

func setup(player_fighter: Fighter, enemy_fighter: Fighter) -> void:
    # ... existing setup code ...

    # Setup mana bars
    var mana_system = _get_mana_system()
    if player_mana_container and player_fighter:
        player_mana_container.setup(player_fighter, mana_system)
    if enemy_mana_container and enemy_fighter:
        enemy_mana_container.setup(enemy_fighter, mana_system)

func _get_mana_system() -> ManaSystem:
    var combat_manager = get_node_or_null("/root/Main/CombatManager")
    if combat_manager:
        return combat_manager.mana_system
    return null

func _process(_delta: float) -> void:
    # Update blocked state (in case status effect applied)
    if player_mana_container:
        player_mana_container.update_blocked_state()
    if enemy_mana_container:
        enemy_mana_container.update_blocked_state()
```

### 6. Update HUD Scene
Modify `/scenes/ui/hud.tscn` to include ManaBarContainer nodes:

Add to PlayerPanel and EnemyPanel (below health bar):
```
[node name="ManaContainer" type="VBoxContainer" parent="PlayerPanel"]
offset_top = [below health bar]
script = ExtResource("mana_bar_container.gd")
mana_bar_scene = ExtResource("mana_bar.tscn")
```

### 7. Ultimate Ready Indicator (Optional)
Add visual feedback when ultimate is ready:

```gdscript
# In ManaBarContainer

signal ultimate_ready

func _on_mana_changed(fighter: Fighter, bar_index: int, current: int, max_value: int) -> void:
    # ... existing code ...

    # Check if all bars full
    if _mana_system and _mana_system.are_all_bars_full(_fighter):
        ultimate_ready.emit()
        _show_ultimate_ready_effect()

func _show_ultimate_ready_effect() -> void:
    # Pulse animation or glow effect
    for bar in _bars:
        bar.glow.visible = true
```

## Acceptance Criteria
- [ ] ManaBarUI displays current/max mana visually
- [ ] Fill animation smooth when value changes
- [ ] Full state shows glow effect
- [ ] Blocked state shows grey color
- [ ] ManaBarContainer supports multiple bars
- [ ] Bars update when mana_changed signal received
- [ ] HUD displays mana bars for both fighters
- [ ] Bars hidden for characters with no mana config
