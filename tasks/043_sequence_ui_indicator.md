# Task 043: Sequence UI Indicator

## Objective
Create UI component to display current sequence progress and banked sequences.

## Dependencies
- Task 042 (Sequence Tracker)
- Task 015 (HUD)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → UI Requirements
- `/docs/CHARACTERS.md` → Hunter combo system

## Deliverables

### 1. Create SequenceIndicator Scene
Create `/scenes/ui/sequence_indicator.tscn`:

Structure:
```
SequenceIndicator (Control)
├── CurrentSequence (HBoxContainer)
│   └── [Dynamic TileIcon children]
├── Arrow (TextureRect)
├── PossibleCompletions (VBoxContainer)
│   └── [Dynamic SequencePreview children]
└── BankedSequences (HBoxContainer)
    └── [Dynamic BankedIcon children]
```

### 2. Create SequenceIndicator Script
Create `/scripts/ui/sequence_indicator.gd`:

```gdscript
class_name SequenceIndicator extends Control

@export var tile_icon_scene: PackedScene
@export var sequence_preview_scene: PackedScene
@export var banked_icon_scene: PackedScene

@export var show_possible_completions: bool = true
@export var max_visible_completions: int = 3

@onready var current_container: HBoxContainer = $CurrentSequence
@onready var arrow: TextureRect = $Arrow
@onready var completions_container: VBoxContainer = $PossibleCompletions
@onready var banked_container: HBoxContainer = $BankedSequences

var _sequence_tracker: SequenceTracker
var _tile_icons: Dictionary = {}  # Preloaded tile type icons

func setup(tracker: SequenceTracker) -> void:
    _sequence_tracker = tracker

    if tracker:
        tracker.sequence_progressed.connect(_on_sequence_progressed)
        tracker.sequence_completed.connect(_on_sequence_completed)
        tracker.sequence_broken.connect(_on_sequence_broken)
        tracker.sequence_banked.connect(_on_sequence_banked)
        tracker.sequence_activated.connect(_on_sequence_activated)

    _load_tile_icons()
    _update_display()

func _load_tile_icons() -> void:
    # Load icons for each tile type
    _tile_icons[TileTypes.TileType.SWORD] = preload("res://assets/ui/icons/sword_small.png")
    _tile_icons[TileTypes.TileType.SHIELD] = preload("res://assets/ui/icons/shield_small.png")
    _tile_icons[TileTypes.TileType.POTION] = preload("res://assets/ui/icons/potion_small.png")
    _tile_icons[TileTypes.TileType.LIGHTNING] = preload("res://assets/ui/icons/stun_small.png")
    # Add more as needed

func _update_display() -> void:
    _update_current_sequence()
    _update_possible_completions()
    _update_banked_sequences()

func _update_current_sequence() -> void:
    # Clear existing icons
    for child in current_container.get_children():
        child.queue_free()

    if not _sequence_tracker:
        return

    var current = _sequence_tracker.get_current_sequence()

    for tile_type in current:
        var icon = _create_tile_icon(tile_type)
        if icon:
            current_container.add_child(icon)

    # Show/hide arrow based on sequence length
    if arrow:
        arrow.visible = current.size() > 0

func _update_possible_completions() -> void:
    # Clear existing previews
    for child in completions_container.get_children():
        child.queue_free()

    if not show_possible_completions or not _sequence_tracker:
        completions_container.visible = false
        return

    var current = _sequence_tracker.get_current_sequence()
    if current.is_empty():
        completions_container.visible = false
        return

    var possible = _sequence_tracker._get_possible_completions()
    completions_container.visible = possible.size() > 0

    var count = 0
    for pattern in possible:
        if count >= max_visible_completions:
            break

        var preview = _create_sequence_preview(pattern, current.size())
        if preview:
            completions_container.add_child(preview)
        count += 1

func _update_banked_sequences() -> void:
    # Clear existing icons
    for child in banked_container.get_children():
        child.queue_free()

    if not _sequence_tracker:
        return

    var banked = _sequence_tracker.get_banked_sequences()

    for pattern in banked:
        var stacks = _sequence_tracker.get_banked_stacks(pattern)
        var icon = _create_banked_icon(pattern, stacks)
        if icon:
            banked_container.add_child(icon)

func _create_tile_icon(tile_type: TileTypes.TileType) -> TextureRect:
    var icon = TextureRect.new()
    icon.custom_minimum_size = Vector2(24, 24)
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

    if _tile_icons.has(tile_type):
        icon.texture = _tile_icons[tile_type]

    return icon

func _create_sequence_preview(pattern: SequencePattern, progress: int) -> Control:
    var container = HBoxContainer.new()

    # Show remaining tiles in pattern
    for i in range(pattern.pattern.size()):
        var icon = _create_tile_icon(pattern.pattern[i])

        # Dim completed tiles
        if i < progress:
            icon.modulate = Color(0.5, 0.5, 0.5, 0.7)
        else:
            icon.modulate = Color.WHITE

        container.add_child(icon)

    # Add terminator icon
    var term_icon = _create_tile_icon(pattern.terminator)
    term_icon.modulate = Color(1, 1, 0.5)  # Highlight terminator
    container.add_child(term_icon)

    # Add pattern name
    var label = Label.new()
    label.text = pattern.display_name
    label.add_theme_font_size_override("font_size", 12)
    container.add_child(label)

    return container

func _create_banked_icon(pattern: SequencePattern, stacks: int) -> Control:
    var container = Control.new()
    container.custom_minimum_size = Vector2(40, 40)

    var icon = TextureRect.new()
    icon.custom_minimum_size = Vector2(32, 32)
    icon.position = Vector2(4, 4)
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    if pattern.icon:
        icon.texture = pattern.icon
    container.add_child(icon)

    # Stack count badge
    if stacks > 1:
        var badge = Label.new()
        badge.text = "x%d" % stacks
        badge.position = Vector2(24, 24)
        badge.add_theme_font_size_override("font_size", 10)
        container.add_child(badge)

    # Ready glow
    var glow = ColorRect.new()
    glow.color = Color(1, 1, 0.5, 0.3)
    glow.size = Vector2(40, 40)
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    container.add_child(glow)
    container.move_child(glow, 0)  # Behind icon

    return container

# Signal handlers
func _on_sequence_progressed(current: Array, possible: Array) -> void:
    _update_display()

func _on_sequence_completed(pattern: SequencePattern) -> void:
    _update_display()
    _flash_completion(pattern)

func _on_sequence_broken() -> void:
    _update_display()
    _flash_break()

func _on_sequence_banked(pattern: SequencePattern, stacks: int) -> void:
    _update_banked_sequences()

func _on_sequence_activated(pattern: SequencePattern, stacks: int) -> void:
    _update_banked_sequences()

func _flash_completion(pattern: SequencePattern) -> void:
    # Visual feedback for sequence completion
    var tween = create_tween()
    tween.tween_property(banked_container, "modulate", Color(1.5, 1.5, 1), 0.1)
    tween.tween_property(banked_container, "modulate", Color.WHITE, 0.2)

func _flash_break() -> void:
    # Visual feedback for sequence break
    var tween = create_tween()
    tween.tween_property(current_container, "modulate", Color(1, 0.5, 0.5), 0.1)
    tween.tween_property(current_container, "modulate", Color.WHITE, 0.2)
```

### 3. Create SequenceIndicator Scene File
Create `/scenes/ui/sequence_indicator.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/sequence_indicator.gd" id="1"]

[node name="SequenceIndicator" type="Control"]
custom_minimum_size = Vector2(200, 60)
script = ExtResource("1")

[node name="CurrentSequence" type="HBoxContainer" parent="."]
offset_right = 150.0
offset_bottom = 30.0

[node name="Arrow" type="TextureRect" parent="."]
visible = false
offset_left = 155.0
offset_top = 5.0
offset_right = 175.0
offset_bottom = 25.0

[node name="PossibleCompletions" type="VBoxContainer" parent="."]
offset_top = 32.0
offset_right = 200.0
offset_bottom = 60.0

[node name="BankedSequences" type="HBoxContainer" parent="."]
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -120.0
offset_bottom = 40.0
```

### 4. Integrate with HUD
Modify `/scripts/ui/hud.gd`:

```gdscript
# Add to HUD

@onready var player_sequence_indicator: SequenceIndicator = $PlayerPanel/SequenceIndicator

func setup(player_fighter: Fighter, enemy_fighter: Fighter) -> void:
    # ... existing setup code ...

    # Setup sequence indicator (if character uses sequences)
    if player_sequence_indicator:
        var board_manager = _get_player_board()
        if board_manager and board_manager.sequence_tracker:
            player_sequence_indicator.setup(board_manager.sequence_tracker)
            player_sequence_indicator.visible = true
        else:
            player_sequence_indicator.visible = false

func _get_player_board() -> BoardManager:
    return get_node_or_null("/root/Main/Boards/PlayerBoard")
```

### 5. Update HUD Scene
Add SequenceIndicator to HUD scene for player panel.

## Acceptance Criteria
- [ ] Current sequence displays matched tile icons
- [ ] Possible completions show remaining pattern
- [ ] Completed tiles dimmed in preview
- [ ] Banked sequences show with stack count
- [ ] Visual feedback on completion/break
- [ ] Integration with HUD complete
- [ ] Indicator hidden for characters without sequences
