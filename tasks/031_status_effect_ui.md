# Task 031: Status Effect UI

## Objective
Create UI components to display active status effects on fighters.

## Dependencies
- Task 030 (Status Effect Integration)
- Task 015 (HUD)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → UI Requirements

## Deliverables

### 1. Create StatusEffectIcon Scene
Create `/scenes/ui/status_effect_icon.tscn`:

Structure:
```
StatusEffectIcon (Control)
├── IconTexture (TextureRect)
├── StackLabel (Label)
└── DurationBar (ProgressBar) [optional]
```

### 2. Create StatusEffectIcon Script
Create `/scripts/ui/status_effect_icon.gd`:

```gdscript
class_name StatusEffectIcon extends Control

@onready var icon_texture: TextureRect = $IconTexture
@onready var stack_label: Label = $StackLabel
@onready var duration_bar: ProgressBar = $DurationBar

var effect_type: StatusTypes.StatusType
var _max_duration: float = 0.0

func setup(effect: StatusEffect) -> void:
    effect_type = effect.data.effect_type

    if effect.data.icon:
        icon_texture.texture = effect.data.icon
    else:
        # Use default icon based on type
        icon_texture.texture = _get_default_icon(effect_type)

    _max_duration = effect.data.duration
    update_display(effect)

func update_display(effect: StatusEffect) -> void:
    # Update stack count
    if effect.stacks > 1:
        stack_label.visible = true
        stack_label.text = "x%d" % effect.stacks
    else:
        stack_label.visible = false

    # Update duration bar
    if _max_duration > 0 and duration_bar:
        duration_bar.visible = true
        duration_bar.max_value = _max_duration
        duration_bar.value = effect.remaining_duration
    elif duration_bar:
        duration_bar.visible = false

func _get_default_icon(type: StatusTypes.StatusType) -> Texture2D:
    # Return placeholder icons based on effect type
    # These should be replaced with actual assets
    match type:
        StatusTypes.StatusType.POISON:
            return preload("res://assets/ui/icons/poison.png")
        StatusTypes.StatusType.BLEED:
            return preload("res://assets/ui/icons/bleed.png")
        StatusTypes.StatusType.ATTACK_UP:
            return preload("res://assets/ui/icons/attack_up.png")
        StatusTypes.StatusType.DODGE:
            return preload("res://assets/ui/icons/dodge.png")
        StatusTypes.StatusType.EVASION:
            return preload("res://assets/ui/icons/evasion.png")
        StatusTypes.StatusType.MANA_BLOCK:
            return preload("res://assets/ui/icons/mana_block.png")
        _:
            return null
```

### 3. Create StatusEffectDisplay Container
Create `/scripts/ui/status_effect_display.gd`:

```gdscript
class_name StatusEffectDisplay extends HBoxContainer

@export var icon_scene: PackedScene
@export var max_visible_effects: int = 6

var _fighter: Fighter
var _status_manager: StatusEffectManager
var _icons: Dictionary = {}  # {StatusType: StatusEffectIcon}

func setup(fighter: Fighter, status_manager: StatusEffectManager) -> void:
    _fighter = fighter
    _status_manager = status_manager

    # Connect to fighter's status signals
    fighter.status_effect_applied.connect(_on_effect_applied)
    fighter.status_effect_removed.connect(_on_effect_removed)

    # Initialize with any existing effects
    _refresh_all()

func _on_effect_applied(effect: StatusEffect) -> void:
    if _icons.has(effect.data.effect_type):
        # Update existing icon
        _icons[effect.data.effect_type].update_display(effect)
    else:
        # Create new icon
        _create_icon(effect)

func _on_effect_removed(effect_type: StatusTypes.StatusType) -> void:
    if _icons.has(effect_type):
        _icons[effect_type].queue_free()
        _icons.erase(effect_type)

func _create_icon(effect: StatusEffect) -> void:
    if not icon_scene:
        return

    if _icons.size() >= max_visible_effects:
        return  # Don't exceed max

    var icon: StatusEffectIcon = icon_scene.instantiate()
    add_child(icon)
    icon.setup(effect)
    _icons[effect.data.effect_type] = icon

func _refresh_all() -> void:
    # Clear existing
    for icon in _icons.values():
        icon.queue_free()
    _icons.clear()

    # Recreate from current effects
    if _status_manager and _fighter:
        for effect in _status_manager.get_all_effects(_fighter):
            _create_icon(effect)

func _process(_delta: float) -> void:
    # Update duration displays
    if _status_manager and _fighter:
        for effect_type in _icons.keys():
            var effect = _status_manager.get_effect(_fighter, effect_type)
            if effect:
                _icons[effect_type].update_display(effect)
```

### 4. Create Status Effect Icon Scene
Create the scene file `/scenes/ui/status_effect_icon.tscn`:

```
[gd_scene format=3]

[node name="StatusEffectIcon" type="Control"]
custom_minimum_size = Vector2(32, 32)
script = ExtResource("status_effect_icon.gd")

[node name="IconTexture" type="TextureRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
stretch_mode = 5

[node name="StackLabel" type="Label" parent="."]
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -20.0
offset_top = -16.0
text = "x1"
horizontal_alignment = 2

[node name="DurationBar" type="ProgressBar" parent="."]
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -4.0
show_percentage = false
```

### 5. Integrate with HUD
Modify `/scripts/ui/hud.gd`:

```gdscript
# Add to HUD

@onready var player_status_display: StatusEffectDisplay = $PlayerPanel/StatusEffects
@onready var enemy_status_display: StatusEffectDisplay = $EnemyPanel/StatusEffects

func setup(player_fighter: Fighter, enemy_fighter: Fighter) -> void:
    # ... existing setup code ...

    # Setup status effect displays
    if player_status_display and player_fighter:
        player_status_display.setup(player_fighter, _get_status_manager())
    if enemy_status_display and enemy_fighter:
        enemy_status_display.setup(enemy_fighter, _get_status_manager())

func _get_status_manager() -> StatusEffectManager:
    # Get from CombatManager
    var combat_manager = get_node_or_null("/root/Main/CombatManager")
    if combat_manager:
        return combat_manager.status_effect_manager
    return null
```

### 6. Update HUD Scene
Modify `/scenes/ui/hud.tscn` to include StatusEffectDisplay nodes:

Add to PlayerPanel and EnemyPanel:
```
[node name="StatusEffects" type="HBoxContainer" parent="PlayerPanel"]
offset_top = [below health bar]
script = ExtResource("status_effect_display.gd")
icon_scene = ExtResource("status_effect_icon.tscn")
```

### 7. Create Placeholder Icons
Create placeholder icon assets in `/assets/ui/icons/`:
- poison.png (green skull or droplet)
- bleed.png (red droplet)
- attack_up.png (red sword/arrow up)
- dodge.png (blue wind/motion lines)
- evasion.png (ghost/fade effect)
- mana_block.png (purple X or lock)

Size: 32x32 pixels

## Acceptance Criteria
- [ ] StatusEffectIcon displays effect icon, stacks, and duration
- [ ] StatusEffectDisplay shows all active effects on a fighter
- [ ] Icons appear when effects applied
- [ ] Icons update when stacks change
- [ ] Icons disappear when effects removed
- [ ] Duration bar animates smoothly
- [ ] HUD displays status effects for both fighters
- [ ] Placeholder icons exist for all effect types
