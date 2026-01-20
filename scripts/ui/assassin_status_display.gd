class_name AssassinStatusDisplay
extends Control

## Displays Assassin ability readiness and dodge chance in a panel similar to WardenDefenseDisplay.
## Shows:
## - Smoke Bomb ability readiness (mana bar 0 full)
## - Shadow Step ability readiness (mana bar 1 full)
## - Current dodge percentage (base agility + dodge status stacks)
##
## Layout:
## +---------------------------------------+
## | [#] SMOKE BOMB    READY               |
## | [#] SHADOW STEP   --                  |
## | DODGE: 35%                            |
## +---------------------------------------+

const DIM_MODULATE := Color(0.3, 0.3, 0.3, 1.0)
const BRIGHT_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const READY_COLOR := Color(0.3, 1.0, 0.3, 1.0)  # Green for ready
const NOT_READY_COLOR := Color(0.5, 0.5, 0.5, 1.0)  # Gray for not ready
const DODGE_BONUS_COLOR := Color(0.3, 1.0, 0.3, 1.0)  # Green when above base
const DODGE_BASE_COLOR := Color(1.0, 1.0, 1.0, 1.0)  # White at base
const TRANCE_COLOR := Color(1.0, 0.4, 0.2, 1.0)  # Orange-red for Predator's Trance

const ICON_SIZE := Vector2(20, 20)
const ROW_SPACING := 4
const ROW_HEIGHT := 24

# Ability type colors
const SMOKE_COLOR := Color(0.5, 0.3, 0.7)  # Purple
const SHADOW_COLOR := Color(0.2, 0.3, 0.6)  # Blue
const TRANCE_ICON_COLOR := Color(1.0, 0.3, 0.1)  # Orange for Trance icon

# Ability definitions
const ABILITIES := [
	{"name": "SMOKE BOMB", "bar_index": 0, "color": Color(0.5, 0.3, 0.7)},
	{"name": "SHADOW STEP", "bar_index": 1, "color": Color(0.2, 0.3, 0.6)},
]

var _fighter: Fighter
var _mana_system: ManaSystem
var _status_manager: StatusEffectManager
var _tile_spawner: TileSpawner
var _ability_rows: Array = []  # [{row: HBoxContainer, icon: ColorRect, status_label: Label}]
var _dodge_label: Label
var _trance_row: HBoxContainer
var _trance_counter_label: Label
var _active_tweens: Array = []

@onready var _background: ColorRect = $Background
@onready var _vbox: VBoxContainer = $VBox


func _ready() -> void:
	# Ensure VBox exists
	if not _vbox:
		_vbox = $VBox
	if not _vbox:
		_vbox = VBoxContainer.new()
		_vbox.name = "VBox"
		_vbox.add_theme_constant_override("separation", ROW_SPACING)
		add_child(_vbox)

	# Ensure background exists
	if not _background:
		_background = $Background
	if not _background:
		_background = ColorRect.new()
		_background.name = "Background"
		_background.color = Color(0.05, 0.05, 0.05, 0.85)
		add_child(_background)
		move_child(_background, 0)


func setup(fighter: Fighter, mana_system: ManaSystem, status_manager: StatusEffectManager, tile_spawner: TileSpawner = null) -> void:
	"""Initialize the display with a fighter and their systems."""
	clear()

	_fighter = fighter
	_mana_system = mana_system
	_status_manager = status_manager
	_tile_spawner = tile_spawner

	if not fighter or not mana_system:
		visible = false
		return

	visible = true

	# Build the UI rows
	_build_ui()

	# Connect to mana system signals
	if mana_system:
		if not mana_system.mana_changed.is_connected(_on_mana_changed):
			mana_system.mana_changed.connect(_on_mana_changed)
		if not mana_system.mana_full.is_connected(_on_mana_full):
			mana_system.mana_full.connect(_on_mana_full)
		if not mana_system.mana_drained.is_connected(_on_mana_drained):
			mana_system.mana_drained.connect(_on_mana_drained)

	# Connect to status manager signals for dodge updates
	if status_manager:
		if not status_manager.effect_applied.is_connected(_on_status_effect_applied):
			status_manager.effect_applied.connect(_on_status_effect_applied)
		if not status_manager.effect_removed.is_connected(_on_status_effect_removed):
			status_manager.effect_removed.connect(_on_status_effect_removed)

	# Connect to tile spawner signals for trance tracking
	if tile_spawner:
		if not tile_spawner.predators_trance_started.is_connected(_on_trance_started):
			tile_spawner.predators_trance_started.connect(_on_trance_started)
		if not tile_spawner.predators_trance_match_used.is_connected(_on_trance_match_used):
			tile_spawner.predators_trance_match_used.connect(_on_trance_match_used)
		if not tile_spawner.predators_trance_ended.is_connected(_on_trance_ended):
			tile_spawner.predators_trance_ended.connect(_on_trance_ended)

	# Initial update
	_update_all_abilities()
	_update_dodge_display()
	_update_trance_display(0, TileSpawner.PREDATORS_TRANCE_MAX_MATCHES, false)


func clear() -> void:
	"""Remove all UI elements and disconnect signals."""
	# Kill all active tweens
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()

	# Disconnect signals
	if _mana_system:
		if _mana_system.mana_changed.is_connected(_on_mana_changed):
			_mana_system.mana_changed.disconnect(_on_mana_changed)
		if _mana_system.mana_full.is_connected(_on_mana_full):
			_mana_system.mana_full.disconnect(_on_mana_full)
		if _mana_system.mana_drained.is_connected(_on_mana_drained):
			_mana_system.mana_drained.disconnect(_on_mana_drained)

	if _status_manager:
		if _status_manager.effect_applied.is_connected(_on_status_effect_applied):
			_status_manager.effect_applied.disconnect(_on_status_effect_applied)
		if _status_manager.effect_removed.is_connected(_on_status_effect_removed):
			_status_manager.effect_removed.disconnect(_on_status_effect_removed)

	if _tile_spawner:
		if _tile_spawner.predators_trance_started.is_connected(_on_trance_started):
			_tile_spawner.predators_trance_started.disconnect(_on_trance_started)
		if _tile_spawner.predators_trance_match_used.is_connected(_on_trance_match_used):
			_tile_spawner.predators_trance_match_used.disconnect(_on_trance_match_used)
		if _tile_spawner.predators_trance_ended.is_connected(_on_trance_ended):
			_tile_spawner.predators_trance_ended.disconnect(_on_trance_ended)

	# Clear UI elements
	if _vbox:
		for child in _vbox.get_children():
			child.queue_free()
	_ability_rows.clear()

	# Dodge label is a direct child, not in VBox
	if _dodge_label and is_instance_valid(_dodge_label):
		_dodge_label.queue_free()
	_dodge_label = null
	_trance_row = null
	_trance_counter_label = null

	_fighter = null
	_mana_system = null
	_status_manager = null
	_tile_spawner = null


func _build_ui() -> void:
	"""Build the UI rows for abilities and dodge display."""
	if not _vbox:
		return

	# Clear existing rows
	for child in _vbox.get_children():
		child.queue_free()
	_ability_rows.clear()

	# Create rows for each ability
	for ability in ABILITIES:
		_create_ability_row(ability)

	# Create trance counter row
	_create_trance_row()

	# Create dodge display (positioned in top right, outside VBox)
	_create_dodge_label()

	# Update background size
	_update_background_size()


func _create_ability_row(ability: Dictionary) -> void:
	"""Create a single ability row with icon, label, and status indicator."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size.y = ROW_HEIGHT

	# Ability type icon (colored square)
	var icon := ColorRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = ICON_SIZE
	icon.color = ability.color
	row.add_child(icon)

	# Ability label
	var label := Label.new()
	label.text = ability.name
	label.custom_minimum_size = Vector2(90, 0)
	label.add_theme_font_size_override("font_size", 11)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	# Status label (READY or --)
	var status_label := Label.new()
	status_label.text = "--"
	status_label.custom_minimum_size = Vector2(50, 0)
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", NOT_READY_COLOR)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(status_label)

	_vbox.add_child(row)

	# Store references
	_ability_rows.append({
		"row": row,
		"icon": icon,
		"status_label": status_label,
		"bar_index": ability.bar_index,
	})

	# Start dimmed
	row.modulate = DIM_MODULATE


func _create_dodge_label() -> void:
	"""Create the dodge percentage display positioned in top right corner."""
	# Remove old dodge label if it exists
	if _dodge_label and _dodge_label.get_parent():
		_dodge_label.get_parent().remove_child(_dodge_label)
		_dodge_label.queue_free()

	_dodge_label = Label.new()
	var base_dodge := _fighter.agility if _fighter else 0
	_dodge_label.text = "DODGE: %d%%" % base_dodge
	_dodge_label.add_theme_font_size_override("font_size", 10)
	_dodge_label.add_theme_color_override("font_color", DODGE_BASE_COLOR)

	# Add directly to this Control (not VBox) for absolute positioning
	add_child(_dodge_label)

	# Position will be updated in _update_background_size() after layout settles


func _create_trance_row() -> void:
	"""Create the Predator's Trance counter row."""
	_trance_row = HBoxContainer.new()
	_trance_row.add_theme_constant_override("separation", 6)
	_trance_row.custom_minimum_size.y = ROW_HEIGHT

	# Trance type icon (colored square)
	var icon := ColorRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = ICON_SIZE
	icon.color = TRANCE_ICON_COLOR
	_trance_row.add_child(icon)

	# Trance label
	var label := Label.new()
	label.text = "TRANCE"
	label.custom_minimum_size = Vector2(90, 0)
	label.add_theme_font_size_override("font_size", 11)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trance_row.add_child(label)

	# Counter label (shows X/4 or --)
	_trance_counter_label = Label.new()
	_trance_counter_label.text = "--"
	_trance_counter_label.custom_minimum_size = Vector2(50, 0)
	_trance_counter_label.add_theme_font_size_override("font_size", 11)
	_trance_counter_label.add_theme_color_override("font_color", NOT_READY_COLOR)
	_trance_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trance_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_trance_row.add_child(_trance_counter_label)

	_vbox.add_child(_trance_row)

	# Start dimmed
	_trance_row.modulate = DIM_MODULATE


func _update_trance_display(current: int, max_matches: int, is_active: bool) -> void:
	"""Update the trance counter display."""
	if not _trance_counter_label or not _trance_row:
		return

	if is_active:
		_trance_counter_label.text = "%d/%d" % [current, max_matches]
		_trance_counter_label.add_theme_color_override("font_color", TRANCE_COLOR)
		_trance_row.modulate = BRIGHT_MODULATE
	else:
		_trance_counter_label.text = "--"
		_trance_counter_label.add_theme_color_override("font_color", NOT_READY_COLOR)
		_trance_row.modulate = DIM_MODULATE


func _flash_trance_row(is_exhausted: bool = false) -> void:
	"""Flash the trance row when a match is used."""
	if not _trance_row:
		return

	var flash_color := Color(1.5, 0.3, 0.3, 1.0) if is_exhausted else Color(1.5, 1.0, 0.5, 1.0)
	var tween := create_tween()
	_active_tweens.append(tween)
	tween.tween_property(_trance_row, "modulate", flash_color, 0.1)
	tween.tween_property(_trance_row, "modulate", BRIGHT_MODULATE, 0.2)


func _update_background_size() -> void:
	"""Update background to cover all rows and position dodge label."""
	if not _background or not _vbox:
		return

	# Wait for layout to settle
	await get_tree().process_frame

	var content_size := _vbox.size
	# Add extra width to accommodate dodge label in top right
	var bg_width := content_size.x + 70  # Extra space for dodge label
	_background.custom_minimum_size = Vector2(bg_width, content_size.y) + Vector2(8, 8)
	_background.size = Vector2(bg_width, content_size.y) + Vector2(8, 8)
	_background.position = Vector2(-4, -4)

	# Position dodge label in top right corner
	if _dodge_label:
		var label_width: float = _dodge_label.size.x if _dodge_label.size.x > 0 else 70.0
		_dodge_label.position = Vector2(bg_width - label_width - 4, 2)


func _update_ability_status(bar_index: int) -> void:
	"""Update the READY/-- display for an ability."""
	if not _fighter or not _mana_system:
		return

	for row_data in _ability_rows:
		if row_data.bar_index != bar_index:
			continue

		var row: HBoxContainer = row_data.row
		var status_label: Label = row_data.status_label
		var is_ready := _mana_system.is_full(_fighter, bar_index)

		if status_label:
			if is_ready:
				status_label.text = "READY"
				status_label.add_theme_color_override("font_color", READY_COLOR)
			else:
				status_label.text = "--"
				status_label.add_theme_color_override("font_color", NOT_READY_COLOR)

		if row:
			row.modulate = BRIGHT_MODULATE if is_ready else DIM_MODULATE

		break


func _update_all_abilities() -> void:
	"""Update all ability statuses."""
	for ability in ABILITIES:
		_update_ability_status(ability.bar_index)


func _update_dodge_display() -> void:
	"""Calculate and display current dodge percentage."""
	if not _dodge_label or not _fighter:
		return

	# Base dodge from agility
	var total_dodge := _fighter.agility

	# Add dodge status stacks if present
	if _status_manager and _status_manager.has_effect(_fighter, StatusTypes.StatusType.DODGE):
		var dodge_modifier := _status_manager.get_modifier(_fighter, StatusTypes.StatusType.DODGE)
		total_dodge += int(dodge_modifier * 100)

	_dodge_label.text = "DODGE: %d%%" % total_dodge

	# Color based on whether we have bonus dodge
	if total_dodge > _fighter.agility:
		_dodge_label.add_theme_color_override("font_color", DODGE_BONUS_COLOR)
	else:
		_dodge_label.add_theme_color_override("font_color", DODGE_BASE_COLOR)


func _flash_ability_ready(bar_index: int) -> void:
	"""Flash an ability row when it becomes ready."""
	for row_data in _ability_rows:
		if row_data.bar_index != bar_index:
			continue

		var row: HBoxContainer = row_data.row
		if row:
			var tween := create_tween()
			_active_tweens.append(tween)
			tween.tween_property(row, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
			tween.tween_property(row, "modulate", BRIGHT_MODULATE, 0.2)

		break


# --- Signal Handlers ---

func _on_mana_changed(fighter: Fighter, bar_index: int, _current: int, _max_value: int) -> void:
	"""Called when mana changes for any fighter."""
	if fighter != _fighter:
		return

	_update_ability_status(bar_index)


func _on_mana_full(fighter: Fighter, bar_index: int) -> void:
	"""Called when a mana bar becomes full."""
	if fighter != _fighter:
		return

	_update_ability_status(bar_index)
	_flash_ability_ready(bar_index)


func _on_mana_drained(fighter: Fighter, bar_index: int, _amount: int) -> void:
	"""Called when mana is drained from a bar."""
	if fighter != _fighter:
		return

	_update_ability_status(bar_index)


func _on_status_effect_applied(target: Fighter, effect: StatusEffect) -> void:
	"""Called when a status effect is applied."""
	if target != _fighter:
		return

	if effect.data.effect_type == StatusTypes.StatusType.DODGE:
		_update_dodge_display()
		# Flash the dodge label
		if _dodge_label:
			var tween := create_tween()
			_active_tweens.append(tween)
			tween.tween_property(_dodge_label, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
			tween.tween_property(_dodge_label, "modulate", Color.WHITE, 0.2)


func _on_status_effect_removed(target: Fighter, effect_type: StatusTypes.StatusType) -> void:
	"""Called when a status effect is removed."""
	if target != _fighter:
		return

	if effect_type == StatusTypes.StatusType.DODGE:
		_update_dodge_display()

	if effect_type == StatusTypes.StatusType.PREDATORS_TRANCE:
		_update_trance_display(0, TileSpawner.PREDATORS_TRANCE_MAX_MATCHES, false)


# --- Trance Signal Handlers ---

func _on_trance_started() -> void:
	"""Called when Predator's Trance is activated."""
	_update_trance_display(0, TileSpawner.PREDATORS_TRANCE_MAX_MATCHES, true)
	_flash_trance_row()


func _on_trance_match_used(current: int, max_matches: int) -> void:
	"""Called when a sword match is used during trance."""
	_update_trance_display(current, max_matches, true)
	var is_exhausted := current >= max_matches
	_flash_trance_row(is_exhausted)


func _on_trance_ended() -> void:
	"""Called when Predator's Trance ends (either expired or exhausted)."""
	_update_trance_display(0, TileSpawner.PREDATORS_TRANCE_MAX_MATCHES, false)


## Reset the display for a new match.
func reset() -> void:
	"""Reset the display state for a new match."""
	# Kill all tweens
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()

	# Reset all abilities to initial state
	for row_data in _ability_rows:
		var row: HBoxContainer = row_data.row
		var status_label: Label = row_data.status_label

		if status_label:
			status_label.text = "--"
			status_label.add_theme_color_override("font_color", NOT_READY_COLOR)

		if row:
			row.modulate = DIM_MODULATE

	# Reset dodge display
	_update_dodge_display()

	# Reset trance display
	_update_trance_display(0, TileSpawner.PREDATORS_TRANCE_MAX_MATCHES, false)
