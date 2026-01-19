class_name ComboTreeDisplay
extends Control

## Displays Hunter combo sequences with visual progress feedback.
## Shows all three sequences (Bear, Hawk, Snake) with tiles that
## brighten as combos progress and dim when completed or broken.
## Also shows pet population counts and pet tile colors inline.
##
## Layout:
## ┌──────────────────────────────────────────────────┐
## │  0/3 [■] BEAR:  [SWORD] → [SHIELD] → [SHIELD]   │
## │  0/3 [■] HAWK:  [SHIELD] → [LIGHTNING]          │
## │  0/3 [■] SNAKE: [LIGHTNING] → [SWORD] → [SHIELD]│
## └──────────────────────────────────────────────────┘

const DIM_MODULATE := Color(0.4, 0.4, 0.4, 1.0)
const BRIGHT_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const COMPLETE_COLOR := Color(1.0, 1.0, 1.0, 1.0)  # White glow (avoids color blending issues)
const DEATH_COLOR := Color(1.0, 0.3, 0.3, 1.0)  # Red flash
const MAX_POP_COLOR := Color(1.0, 0.5, 0.2, 1.0)  # Orange for max population

const ICON_SIZE := Vector2(24, 24)
const ARROW_SIZE := Vector2(16, 16)
const ROW_SPACING := 4
const ICON_SPACING := 4
const MAX_PET_PER_TYPE := 3

var _sequence_tracker: SequenceTracker
var _pet_spawner: PetSpawner
var _pattern_rows: Dictionary = {}  # {pattern_name: {label: Label, icons: Array[Control], pattern: SequencePattern, count_label: Label}}
var _active_tweens: Dictionary = {}  # {pattern_name: Array[Tween]} - track active tweens to prevent accumulation

@onready var _vbox: VBoxContainer = $VBox


## Sets up the display with a sequence tracker and connects to its signals.
func setup(sequence_tracker: SequenceTracker) -> void:
	_sequence_tracker = sequence_tracker

	# Connect to tree signals
	if sequence_tracker:
		if not sequence_tracker.tree_started.is_connected(_on_tree_started):
			sequence_tracker.tree_started.connect(_on_tree_started)
		if not sequence_tracker.tree_progressed.is_connected(_on_tree_progressed):
			sequence_tracker.tree_progressed.connect(_on_tree_progressed)
		if not sequence_tracker.tree_died.is_connected(_on_tree_died):
			sequence_tracker.tree_died.connect(_on_tree_died)
		if not sequence_tracker.sequence_completed.is_connected(_on_sequence_completed):
			sequence_tracker.sequence_completed.connect(_on_sequence_completed)

	_build_display()
	reset()


## Sets up the pet spawner connection for population display.
func setup_pet_spawner(pet_spawner: PetSpawner) -> void:
	_pet_spawner = pet_spawner

	if pet_spawner:
		# Listen to confirmed spawns (after tile is actually placed)
		if not pet_spawner.pet_spawn_confirmed.is_connected(_on_pet_spawn_confirmed):
			pet_spawner.pet_spawn_confirmed.connect(_on_pet_spawn_confirmed)
		if not pet_spawner.pet_activated.is_connected(_on_pet_activated):
			pet_spawner.pet_activated.connect(_on_pet_activated)
		if not pet_spawner.pet_spawn_blocked.is_connected(_on_pet_spawn_blocked):
			pet_spawner.pet_spawn_blocked.connect(_on_pet_spawn_blocked)

	_update_all_counts()


func _ready() -> void:
	# Ensure VBox exists
	if not _vbox:
		_vbox = $VBox

	if not _vbox:
		# Create VBox if it doesn't exist (for programmatic instantiation)
		_vbox = VBoxContainer.new()
		_vbox.name = "VBox"
		_vbox.add_theme_constant_override("separation", ROW_SPACING)
		add_child(_vbox)


## Builds the visual display for all patterns in the tracker.
func _build_display() -> void:
	if not _vbox or not _sequence_tracker:
		return

	# Clear existing rows
	for child in _vbox.get_children():
		child.queue_free()
	_pattern_rows.clear()

	# Create rows for each pattern
	var patterns := _sequence_tracker.get_valid_patterns()
	for pattern in patterns:
		if pattern.pet_type >= 0:  # Only Hunter-style patterns with pets
			_create_pattern_row(pattern)


## Creates a row for a single pattern with count, pet color, label, and combo icons.
## Layout: [0/3] [■] BEAR: [■] > [■] > [■]
func _create_pattern_row(pattern: SequencePattern) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ICON_SPACING)

	# Pet count label (e.g., "0/3")
	var count_label := Label.new()
	count_label.text = "0/%d" % MAX_PET_PER_TYPE
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size = Vector2(24, 0)
	row.add_child(count_label)

	# Pet tile color indicator
	var pet_color_icon := _create_tile_icon(pattern.pet_type)
	row.add_child(pet_color_icon)

	# Pattern name label
	var label := Label.new()
	label.text = "%s:" % pattern.display_name.to_upper()
	label.custom_minimum_size = Vector2(52, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	# Tile icons with arrows between them
	var icons: Array[Control] = []
	for i in range(pattern.pattern.size()):
		if i > 0:
			# Add arrow between icons
			var arrow := _create_arrow()
			row.add_child(arrow)

		var tile_type: int = pattern.pattern[i]
		var icon := _create_tile_icon(tile_type)
		icons.append(icon)
		row.add_child(icon)

	_vbox.add_child(row)

	# Store reference for later updates
	_pattern_rows[pattern.display_name] = {
		"label": label,
		"icons": icons,
		"pattern": pattern,
		"count_label": count_label,
		"pet_color_icon": pet_color_icon
	}


## Creates a tile icon for the given tile type.
func _create_tile_icon(tile_type: int) -> Control:
	var container := Control.new()
	container.custom_minimum_size = ICON_SIZE

	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.custom_minimum_size = ICON_SIZE
	bg.color = Color(0.1, 0.1, 0.1, 0.8)
	container.add_child(bg)

	# Tile color indicator
	var color_rect := ColorRect.new()
	color_rect.name = "TileColor"
	color_rect.custom_minimum_size = ICON_SIZE - Vector2(4, 4)
	color_rect.position = Vector2(2, 2)
	color_rect.color = _get_tile_color(tile_type)
	container.add_child(color_rect)

	# Glow overlay (for highlighting)
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.custom_minimum_size = ICON_SIZE + Vector2(4, 4)
	glow.position = Vector2(-2, -2)
	glow.color = COMPLETE_COLOR
	glow.modulate.a = 0.0
	glow.z_index = -1
	container.add_child(glow)

	return container


## Creates an arrow indicator between tile icons.
func _create_arrow() -> Control:
	var arrow_label := Label.new()
	arrow_label.text = ">"
	arrow_label.add_theme_font_size_override("font_size", 10)
	arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_label.custom_minimum_size = ARROW_SIZE
	arrow_label.modulate = Color(0.6, 0.6, 0.6, 1.0)
	return arrow_label


## Resets all icons to dimmed state and count labels to 0.
func reset() -> void:
	for pattern_name in _pattern_rows:
		var row: Dictionary = _pattern_rows[pattern_name]
		var icons: Array = row.icons
		for icon in icons:
			_set_icon_modulate(icon, DIM_MODULATE)
		# Reset count label
		var count_label: Label = row.get("count_label")
		if count_label:
			count_label.text = "0/%d" % MAX_PET_PER_TYPE
			count_label.modulate = Color.WHITE


## Signal handler: tree started - brighten first icon.
func _on_tree_started(pattern_name: String) -> void:
	if pattern_name in _pattern_rows:
		var row: Dictionary = _pattern_rows[pattern_name]
		var icons: Array = row.icons
		if icons.size() > 0:
			_set_icon_modulate(icons[0], BRIGHT_MODULATE)


## Signal handler: tree progressed - brighten icon at progress index.
func _on_tree_progressed(pattern_name: String, progress: int, _total: int) -> void:
	if pattern_name in _pattern_rows:
		var row: Dictionary = _pattern_rows[pattern_name]
		var icons: Array = row.icons
		# Progress is 1-indexed, so icon index is progress - 1
		# But we brighten icons up to and including the current progress
		for i in range(mini(progress, icons.size())):
			_set_icon_modulate(icons[i], BRIGHT_MODULATE)


## Kills all active tweens for a pattern to prevent accumulation.
func _kill_pattern_tweens(pattern_name: String) -> void:
	if pattern_name in _active_tweens:
		for tween in _active_tweens[pattern_name]:
			if tween and tween.is_valid():
				tween.kill()
		_active_tweens[pattern_name].clear()


## Tracks a tween for a pattern so it can be killed later.
func _track_tween(pattern_name: String, tween: Tween) -> void:
	if pattern_name not in _active_tweens:
		_active_tweens[pattern_name] = []
	_active_tweens[pattern_name].append(tween)


## Signal handler: tree died - red flash then dim all icons.
func _on_tree_died(pattern_name: String) -> void:
	if pattern_name in _pattern_rows:
		_kill_pattern_tweens(pattern_name)
		var row: Dictionary = _pattern_rows[pattern_name]
		var icons: Array = row.icons
		for icon in icons:
			# Flash red then dim
			var tween := create_tween()
			_track_tween(pattern_name, tween)
			tween.tween_callback(_set_icon_modulate.bind(icon, DEATH_COLOR))
			tween.tween_interval(0.1)
			tween.tween_callback(_set_icon_modulate.bind(icon, DIM_MODULATE)).set_delay(0.3)


## Signal handler: sequence completed - glow then dim all icons.
func _on_sequence_completed(pet_type: int) -> void:
	var pattern_name := _get_pattern_name_for_pet(pet_type)
	if pattern_name in _pattern_rows:
		_kill_pattern_tweens(pattern_name)
		var row: Dictionary = _pattern_rows[pattern_name]
		var icons: Array = row.icons
		for icon in icons:
			# Glow yellow then dim
			var tween := create_tween()
			_track_tween(pattern_name, tween)
			tween.tween_callback(_set_icon_glow.bind(icon, 1.0))
			tween.tween_callback(_set_icon_modulate.bind(icon, COMPLETE_COLOR))
			tween.tween_interval(0.15)
			tween.tween_callback(_set_icon_glow.bind(icon, 0.0)).set_delay(0.5)
			tween.tween_callback(_set_icon_modulate.bind(icon, DIM_MODULATE))


## Maps pet_type to pattern display name.
func _get_pattern_name_for_pet(pet_type: int) -> String:
	match pet_type:
		TileTypes.Type.BEAR_PET:
			return "Bear"
		TileTypes.Type.HAWK_PET:
			return "Hawk"
		TileTypes.Type.SNAKE_PET:
			return "Snake"
	return ""


## Sets the modulate color of an icon's tile color rect.
func _set_icon_modulate(icon: Control, color: Color) -> void:
	if not icon:
		return
	var tile_color := icon.get_node_or_null("TileColor") as ColorRect
	if tile_color:
		tile_color.modulate = color


## Sets the glow alpha of an icon.
func _set_icon_glow(icon: Control, alpha: float) -> void:
	if not icon:
		return
	var glow := icon.get_node_or_null("Glow") as ColorRect
	if glow:
		glow.modulate.a = alpha


## Returns the display color for a tile type.
func _get_tile_color(tile_type: int) -> Color:
	match tile_type:
		TileTypes.Type.SWORD:
			return Color(0.9, 0.2, 0.2)  # Red
		TileTypes.Type.SHIELD:
			return Color(0.3, 0.5, 0.95)  # Blue
		TileTypes.Type.POTION:
			return Color(0.2, 0.9, 0.2)  # Green
		TileTypes.Type.LIGHTNING:
			return Color(0.95, 0.95, 0.2)  # Yellow
		TileTypes.Type.FILLER:
			return Color(0.5, 0.5, 0.5)  # Gray
		TileTypes.Type.PET:
			return Color(0.8, 0.4, 0.95)  # Purple
		TileTypes.Type.MANA:
			return Color(0.2, 0.8, 0.95)  # Cyan
		TileTypes.Type.BEAR_PET:
			return Color(0.6, 0.3, 0.1)  # Brown
		TileTypes.Type.HAWK_PET:
			return Color(0.95, 0.95, 0.95)  # White
		TileTypes.Type.SNAKE_PET:
			return Color(0.2, 0.6, 0.3)  # Green
		TileTypes.Type.FOCUS:
			return Color(0.95, 0.85, 0.2)  # Yellow/Gold
		_:
			return Color(0.4, 0.4, 0.4)


## Disconnects from sequence tracker and pet spawner signals.
func clear() -> void:
	# Kill all active tweens to prevent memory leaks
	for pattern_name in _active_tweens:
		_kill_pattern_tweens(pattern_name)
	_active_tweens.clear()

	if _sequence_tracker:
		if _sequence_tracker.tree_started.is_connected(_on_tree_started):
			_sequence_tracker.tree_started.disconnect(_on_tree_started)
		if _sequence_tracker.tree_progressed.is_connected(_on_tree_progressed):
			_sequence_tracker.tree_progressed.disconnect(_on_tree_progressed)
		if _sequence_tracker.tree_died.is_connected(_on_tree_died):
			_sequence_tracker.tree_died.disconnect(_on_tree_died)
		if _sequence_tracker.sequence_completed.is_connected(_on_sequence_completed):
			_sequence_tracker.sequence_completed.disconnect(_on_sequence_completed)

	if _pet_spawner:
		if _pet_spawner.pet_spawn_confirmed.is_connected(_on_pet_spawn_confirmed):
			_pet_spawner.pet_spawn_confirmed.disconnect(_on_pet_spawn_confirmed)
		if _pet_spawner.pet_activated.is_connected(_on_pet_activated):
			_pet_spawner.pet_activated.disconnect(_on_pet_activated)
		if _pet_spawner.pet_spawn_blocked.is_connected(_on_pet_spawn_blocked):
			_pet_spawner.pet_spawn_blocked.disconnect(_on_pet_spawn_blocked)

	_sequence_tracker = null
	_pet_spawner = null


# --- Pet Spawner Signal Handlers ---

## Called when a pet spawn is confirmed - update the count display
func _on_pet_spawn_confirmed(pet_type: int) -> void:
	_update_count_for_pet(pet_type)


## Called when a pet is activated (clicked) - update the count display
func _on_pet_activated(pet_type: int) -> void:
	_update_count_for_pet(pet_type)


## Called when pet spawn is blocked due to max population
func _on_pet_spawn_blocked(pet_type: int) -> void:
	var pattern_name := _get_pattern_name_for_pet(pet_type)
	if pattern_name in _pattern_rows:
		var row: Dictionary = _pattern_rows[pattern_name]
		var count_label: Label = row.get("count_label")
		if count_label:
			# Kill any existing tweens for this pattern before creating new one
			_kill_pattern_tweens(pattern_name)
			# Flash the count label orange to indicate max
			var tween := create_tween()
			_track_tween(pattern_name, tween)
			tween.tween_property(count_label, "modulate", MAX_POP_COLOR, 0.1)
			tween.tween_property(count_label, "modulate", Color.WHITE, 0.3).set_delay(0.5)


## Updates the count label for a specific pet type
func _update_count_for_pet(pet_type: int) -> void:
	var pattern_name := _get_pattern_name_for_pet(pet_type)
	if pattern_name in _pattern_rows:
		var row: Dictionary = _pattern_rows[pattern_name]
		var count_label: Label = row.get("count_label")
		if count_label and _pet_spawner:
			var count := _pet_spawner.get_count(pet_type)
			count_label.text = "%d/%d" % [count, MAX_PET_PER_TYPE]
			# Color the label based on count
			if count >= MAX_PET_PER_TYPE:
				count_label.modulate = MAX_POP_COLOR
			else:
				count_label.modulate = Color.WHITE


## Updates all count labels from pet spawner state
func _update_all_counts() -> void:
	_update_count_for_pet(TileTypes.Type.BEAR_PET)
	_update_count_for_pet(TileTypes.Type.HAWK_PET)
	_update_count_for_pet(TileTypes.Type.SNAKE_PET)
