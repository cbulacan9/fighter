class_name WardenDefenseDisplay
extends Control

## Displays Warden defense queue status in a panel similar to Hunter's ComboTreeDisplay.
## Shows three defense rows (Reflection, Cancel, Absorb) with timers and status indicators.
##
## Layout:
## +--------------------------------------------------+
## | [#] REFLECT   [========--]  x2                   |
## | [#] CANCEL    [----------]  --                   |
## | [#] ABSORB    [==========]  x1  [+45 stored]     |
## +--------------------------------------------------+

const DIM_MODULATE := Color(0.3, 0.3, 0.3, 1.0)
const BRIGHT_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const ENHANCED_COLOR := Color(1.0, 0.85, 0.2, 1.0)  # Gold for enhanced
const TRIGGERED_COLOR := Color(1.0, 1.0, 1.0, 1.0)  # White flash
const EXPIRED_COLOR := Color(1.0, 0.3, 0.3, 1.0)  # Red flash

const ICON_SIZE := Vector2(20, 20)
const ROW_SPACING := 4
const ROW_HEIGHT := 24
const TIMER_BAR_WIDTH := 80
const TIMER_BAR_HEIGHT := 12

# Defense type colors
const REFLECTION_COLOR := Color(0.7, 0.3, 0.9)  # Purple
const CANCEL_COLOR := Color(0.3, 0.8, 0.3)  # Green
const ABSORB_COLOR := Color(0.3, 0.5, 0.9)  # Blue

# Defense types in display order
const DEFENSE_TYPES := [
	StatusTypes.StatusType.REFLECTION_QUEUED,
	StatusTypes.StatusType.CANCEL_QUEUED,
	StatusTypes.StatusType.ABSORB_QUEUED,
]

# Labels for each defense type
const DEFENSE_LABELS := {
	StatusTypes.StatusType.REFLECTION_QUEUED: "REFLECT",
	StatusTypes.StatusType.CANCEL_QUEUED: "CANCEL",
	StatusTypes.StatusType.ABSORB_QUEUED: "ABSORB",
}

# Colors for each defense type
const DEFENSE_COLORS := {
	StatusTypes.StatusType.REFLECTION_QUEUED: REFLECTION_COLOR,
	StatusTypes.StatusType.CANCEL_QUEUED: CANCEL_COLOR,
	StatusTypes.StatusType.ABSORB_QUEUED: ABSORB_COLOR,
}

# Duration map for timer bars
const DURATION_MAP := {
	StatusTypes.StatusType.REFLECTION_QUEUED: DefensiveQueueManager.REFLECTION_WINDOW,
	StatusTypes.StatusType.CANCEL_QUEUED: DefensiveQueueManager.CANCEL_WINDOW,
	StatusTypes.StatusType.ABSORB_QUEUED: DefensiveQueueManager.ABSORB_WINDOW,
}

var _fighter: Fighter
var _defensive_queue: DefensiveQueueManager
var _defense_rows: Dictionary = {}  # {StatusType: {row: HBoxContainer, icon: ColorRect, timer_bar: ProgressBar, stack_label: Label, absorb_label: Label, glow: ColorRect}}
var _active_tweens: Dictionary = {}  # {StatusType: Array[Tween]}

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


func setup(fighter: Fighter, defensive_queue: DefensiveQueueManager) -> void:
	"""Initialize the display with a fighter and their defensive queue manager."""
	clear()

	_fighter = fighter
	_defensive_queue = defensive_queue

	if not defensive_queue:
		visible = false
		return

	visible = true

	# Build the UI rows
	_build_ui()

	# Connect to defensive queue signals
	if not defensive_queue.defense_queued.is_connected(_on_defense_queued):
		defensive_queue.defense_queued.connect(_on_defense_queued)
	if not defensive_queue.defense_triggered.is_connected(_on_defense_triggered):
		defensive_queue.defense_triggered.connect(_on_defense_triggered)
	if not defensive_queue.defense_expired.is_connected(_on_defense_expired):
		defensive_queue.defense_expired.connect(_on_defense_expired)
	if not defensive_queue.absorb_damage_stored.is_connected(_on_absorb_damage_stored):
		defensive_queue.absorb_damage_stored.connect(_on_absorb_damage_stored)


func clear() -> void:
	"""Remove all UI elements and disconnect signals."""
	# Kill all active tweens
	for defense_type in _active_tweens:
		_kill_defense_tweens(defense_type)
	_active_tweens.clear()

	# Disconnect signals
	if _defensive_queue:
		if _defensive_queue.defense_queued.is_connected(_on_defense_queued):
			_defensive_queue.defense_queued.disconnect(_on_defense_queued)
		if _defensive_queue.defense_triggered.is_connected(_on_defense_triggered):
			_defensive_queue.defense_triggered.disconnect(_on_defense_triggered)
		if _defensive_queue.defense_expired.is_connected(_on_defense_expired):
			_defensive_queue.defense_expired.disconnect(_on_defense_expired)
		if _defensive_queue.absorb_damage_stored.is_connected(_on_absorb_damage_stored):
			_defensive_queue.absorb_damage_stored.disconnect(_on_absorb_damage_stored)

	# Clear UI elements
	if _vbox:
		for child in _vbox.get_children():
			child.queue_free()
	_defense_rows.clear()

	_fighter = null
	_defensive_queue = null


func _process(_delta: float) -> void:
	"""Update timer bars for all active defenses."""
	if not _defensive_queue or not _fighter:
		return

	for defense_type in DEFENSE_TYPES:
		if not _defense_rows.has(defense_type):
			continue

		var row_data: Dictionary = _defense_rows[defense_type]
		var timer_bar: ProgressBar = row_data.get("timer_bar")
		var stack_label: Label = row_data.get("stack_label")
		var glow: ColorRect = row_data.get("glow")

		if _defensive_queue.has_queued_defense(_fighter, defense_type):
			# Get time remaining from internal state
			var queue_data: Dictionary = _defensive_queue._queued_defenses.get(_fighter, {})
			var defense_data: Dictionary = queue_data.get(defense_type, {})
			var time_remaining: float = defense_data.get("time_remaining", 0.0)
			var stacks: int = defense_data.get("stacks", 1)
			var is_enhanced: bool = defense_data.get("enhanced", false)

			# Update timer bar
			var max_duration: float = DURATION_MAP.get(defense_type, 2.0)
			if is_enhanced:
				max_duration *= DefensiveQueueManager.ENHANCED_DURATION_MULTIPLIER
			if timer_bar:
				timer_bar.max_value = max_duration
				timer_bar.value = time_remaining

			# Update stack label
			if stack_label:
				stack_label.text = "x%d" % stacks

			# Update glow for enhanced state
			if glow and is_enhanced:
				glow.modulate.a = 0.5

			# Ensure row is bright when active
			_set_row_active(defense_type, true, is_enhanced)
		else:
			# No active defense - dim the row
			_set_row_active(defense_type, false, false)
			if timer_bar:
				timer_bar.value = 0
			if stack_label:
				stack_label.text = "--"
			if glow:
				glow.modulate.a = 0.0


func _build_ui() -> void:
	"""Build the UI rows for each defense type."""
	if not _vbox:
		return

	# Clear existing rows
	for child in _vbox.get_children():
		child.queue_free()
	_defense_rows.clear()

	# Create rows for each defense type
	for defense_type in DEFENSE_TYPES:
		_create_defense_row(defense_type)

	# Update background size
	_update_background_size()


func _create_defense_row(defense_type: StatusTypes.StatusType) -> void:
	"""Create a single defense row with icon, label, timer bar, and stack indicator."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size.y = ROW_HEIGHT

	# Container for icon with glow effect
	var icon_container := Control.new()
	icon_container.custom_minimum_size = ICON_SIZE + Vector2(4, 4)

	# Glow rectangle (behind icon)
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.custom_minimum_size = ICON_SIZE + Vector2(4, 4)
	glow.position = Vector2(-2, -2)
	glow.color = ENHANCED_COLOR
	glow.modulate.a = 0.0
	icon_container.add_child(glow)

	# Defense type icon (colored square)
	var icon := ColorRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = ICON_SIZE
	icon.position = Vector2(2, 2)
	icon.color = DEFENSE_COLORS.get(defense_type, Color.WHITE)
	icon_container.add_child(icon)

	row.add_child(icon_container)

	# Defense label
	var label := Label.new()
	label.text = DEFENSE_LABELS.get(defense_type, "DEFENSE")
	label.custom_minimum_size = Vector2(56, 0)
	label.add_theme_font_size_override("font_size", 11)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	# Timer bar
	var timer_bar := ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(TIMER_BAR_WIDTH, TIMER_BAR_HEIGHT)
	timer_bar.max_value = DURATION_MAP.get(defense_type, 2.0)
	timer_bar.value = 0
	timer_bar.show_percentage = false
	# Style the progress bar
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	bar_style.corner_radius_top_left = 2
	bar_style.corner_radius_top_right = 2
	bar_style.corner_radius_bottom_left = 2
	bar_style.corner_radius_bottom_right = 2
	timer_bar.add_theme_stylebox_override("background", bar_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = DEFENSE_COLORS.get(defense_type, Color.WHITE)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	timer_bar.add_theme_stylebox_override("fill", fill_style)
	row.add_child(timer_bar)

	# Stack indicator label
	var stack_label := Label.new()
	stack_label.text = "--"
	stack_label.custom_minimum_size = Vector2(24, 0)
	stack_label.add_theme_font_size_override("font_size", 11)
	stack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(stack_label)

	# Absorb damage counter (only for absorb type)
	var absorb_label: Label = null
	if defense_type == StatusTypes.StatusType.ABSORB_QUEUED:
		absorb_label = Label.new()
		absorb_label.text = ""
		absorb_label.custom_minimum_size = Vector2(64, 0)
		absorb_label.add_theme_font_size_override("font_size", 10)
		absorb_label.add_theme_color_override("font_color", ABSORB_COLOR)
		absorb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(absorb_label)

	_vbox.add_child(row)

	# Store references
	_defense_rows[defense_type] = {
		"row": row,
		"icon": icon,
		"icon_container": icon_container,
		"label": label,
		"timer_bar": timer_bar,
		"stack_label": stack_label,
		"absorb_label": absorb_label,
		"glow": glow,
	}

	# Start dimmed
	_set_row_active(defense_type, false, false)


func _update_background_size() -> void:
	"""Update background to cover all rows."""
	if not _background or not _vbox:
		return

	# Wait for layout to settle
	await get_tree().process_frame

	var content_size := _vbox.size
	_background.custom_minimum_size = content_size + Vector2(8, 8)
	_background.size = content_size + Vector2(8, 8)
	_background.position = Vector2(-4, -4)


func _set_row_active(defense_type: StatusTypes.StatusType, active: bool, enhanced: bool) -> void:
	"""Set the visual state of a row (active/dimmed)."""
	if not _defense_rows.has(defense_type):
		return

	var row_data: Dictionary = _defense_rows[defense_type]
	var row: HBoxContainer = row_data.get("row")
	var glow: ColorRect = row_data.get("glow")

	if row:
		if active:
			row.modulate = BRIGHT_MODULATE
		else:
			row.modulate = DIM_MODULATE

	if glow:
		if enhanced and active:
			glow.modulate.a = 0.5
		else:
			glow.modulate.a = 0.0


func _kill_defense_tweens(defense_type: StatusTypes.StatusType) -> void:
	"""Kill all active tweens for a defense type."""
	if defense_type in _active_tweens:
		for tween in _active_tweens[defense_type]:
			if tween and tween.is_valid():
				tween.kill()
		_active_tweens[defense_type].clear()


func _track_tween(defense_type: StatusTypes.StatusType, tween: Tween) -> void:
	"""Track a tween for a defense type."""
	if defense_type not in _active_tweens:
		_active_tweens[defense_type] = []
	_active_tweens[defense_type].append(tween)


# --- Signal Handlers ---

func _on_defense_queued(fighter: Fighter, defense_type: StatusTypes.StatusType) -> void:
	"""Called when a new defense is queued."""
	if fighter != _fighter:
		return

	if not _defense_rows.has(defense_type):
		return

	# Get enhanced state
	var is_enhanced := _defensive_queue.is_enhanced(fighter, defense_type)

	# Activate the row with a bright flash
	_kill_defense_tweens(defense_type)
	var row_data: Dictionary = _defense_rows[defense_type]
	var row: HBoxContainer = row_data.get("row")

	if row:
		var tween := create_tween()
		_track_tween(defense_type, tween)
		tween.tween_property(row, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
		tween.tween_property(row, "modulate", BRIGHT_MODULATE, 0.2)

	_set_row_active(defense_type, true, is_enhanced)


func _on_defense_triggered(fighter: Fighter, defense_type: StatusTypes.StatusType) -> void:
	"""Called when a defense triggers (reflects, cancels, or absorbs)."""
	if fighter != _fighter:
		return

	if not _defense_rows.has(defense_type):
		return

	# Flash white then dim
	_kill_defense_tweens(defense_type)
	var row_data: Dictionary = _defense_rows[defense_type]
	var row: HBoxContainer = row_data.get("row")

	if row:
		var tween := create_tween()
		_track_tween(defense_type, tween)
		tween.tween_property(row, "modulate", TRIGGERED_COLOR * 1.5, 0.1)
		tween.tween_property(row, "modulate", DIM_MODULATE, 0.3)


func _on_defense_expired(fighter: Fighter, defense_type: StatusTypes.StatusType) -> void:
	"""Called when a defense expires without triggering."""
	if fighter != _fighter:
		return

	if not _defense_rows.has(defense_type):
		return

	# Flash red then dim
	_kill_defense_tweens(defense_type)
	var row_data: Dictionary = _defense_rows[defense_type]
	var row: HBoxContainer = row_data.get("row")

	if row:
		var tween := create_tween()
		_track_tween(defense_type, tween)
		tween.tween_property(row, "modulate", EXPIRED_COLOR, 0.1)
		tween.tween_property(row, "modulate", DIM_MODULATE, 0.3)


func _on_absorb_damage_stored(fighter: Fighter, _amount: int, total: int) -> void:
	"""Called when damage is absorbed and stored."""
	if fighter != _fighter:
		return

	var defense_type := StatusTypes.StatusType.ABSORB_QUEUED
	if not _defense_rows.has(defense_type):
		return

	var row_data: Dictionary = _defense_rows[defense_type]
	var absorb_label: Label = row_data.get("absorb_label")

	if absorb_label:
		absorb_label.text = "+%d stored" % total
		# Flash the label
		var tween := create_tween()
		_track_tween(defense_type, tween)
		tween.tween_property(absorb_label, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
		tween.tween_property(absorb_label, "modulate", Color.WHITE, 0.2)


## Reset the display for a new match.
func reset() -> void:
	"""Reset the display state for a new match."""
	# Kill all tweens
	for defense_type in _active_tweens:
		_kill_defense_tweens(defense_type)
	_active_tweens.clear()

	# Reset all rows to dimmed state
	for defense_type in DEFENSE_TYPES:
		if not _defense_rows.has(defense_type):
			continue

		var row_data: Dictionary = _defense_rows[defense_type]
		var timer_bar: ProgressBar = row_data.get("timer_bar")
		var stack_label: Label = row_data.get("stack_label")
		var absorb_label: Label = row_data.get("absorb_label")
		var glow: ColorRect = row_data.get("glow")

		if timer_bar:
			timer_bar.value = 0
		if stack_label:
			stack_label.text = "--"
		if absorb_label:
			absorb_label.text = ""
		if glow:
			glow.modulate.a = 0.0

		_set_row_active(defense_type, false, false)
