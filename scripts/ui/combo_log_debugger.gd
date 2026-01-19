class_name ComboLogDebugger
extends Control

## Debug panel that logs combo tree events in real-time.
## Toggle visibility with F3 key.
##
## Shows:
## - Tree started events
## - Tree progress events
## - Tree death events
## - Sequence completion events
## - Match processing events

const MAX_LOG_LINES := 20
const LOG_FADE_TIME := 10.0  # Seconds before old entries start fading

var _sequence_tracker: SequenceTracker
var _log_entries: Array[Dictionary] = []  # {text: String, time: float, color: Color}

# UI elements (created programmatically)
var _panel: PanelContainer
var _vbox: VBoxContainer
var _title_label: Label
var _log_container: VBoxContainer
var _clear_button: Button

# Colors for different event types
const COLOR_STARTED := Color(0.5, 0.8, 1.0)    # Light blue
const COLOR_PROGRESS := Color(0.5, 1.0, 0.5)   # Light green
const COLOR_DIED := Color(1.0, 0.5, 0.5)       # Light red
const COLOR_COMPLETED := Color(1.0, 1.0, 0.5)  # Yellow
const COLOR_MATCH := Color(0.8, 0.8, 0.8)      # Light gray
const COLOR_INFO := Color(0.6, 0.6, 0.6)       # Gray


func _ready() -> void:
	# Disable entirely in non-debug builds for performance
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		visible = false
		return

	# Always create UI programmatically
	_create_ui()
	visible = false  # Hidden by default


func _create_ui() -> void:
	# Panel
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(300, 250)
	add_child(_panel)

	# Add a semi-transparent background style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)

	# Margin container
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	# VBox
	_vbox = VBoxContainer.new()
	_vbox.name = "VBox"
	_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(_vbox)

	# Title
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "COMBO LOG (F3 to toggle)"
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_vbox.add_child(_title_label)

	# Separator
	var sep := HSeparator.new()
	_vbox.add_child(sep)

	# Scroll container for log
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_vbox.add_child(scroll)

	# Log container
	_log_container = VBoxContainer.new()
	_log_container.name = "LogContainer"
	_log_container.add_theme_constant_override("separation", 2)
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_log_container)

	# Clear button
	_clear_button = Button.new()
	_clear_button.name = "ClearButton"
	_clear_button.text = "Clear Log"
	_clear_button.pressed.connect(_on_clear_pressed)
	_vbox.add_child(_clear_button)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()


## Sets up the debugger with a sequence tracker
func setup(sequence_tracker: SequenceTracker) -> void:
	# Skip setup in non-debug builds
	if not OS.is_debug_build():
		return

	# Disconnect from old tracker
	if _sequence_tracker:
		_disconnect_signals()

	_sequence_tracker = sequence_tracker

	if _sequence_tracker:
		_connect_signals()
		_log("Combo debugger connected", COLOR_INFO)


func _connect_signals() -> void:
	if not _sequence_tracker:
		return

	if not _sequence_tracker.tree_started.is_connected(_on_tree_started):
		_sequence_tracker.tree_started.connect(_on_tree_started)
	if not _sequence_tracker.tree_progressed.is_connected(_on_tree_progressed):
		_sequence_tracker.tree_progressed.connect(_on_tree_progressed)
	if not _sequence_tracker.tree_died.is_connected(_on_tree_died):
		_sequence_tracker.tree_died.connect(_on_tree_died)
	if not _sequence_tracker.sequence_completed.is_connected(_on_sequence_completed):
		_sequence_tracker.sequence_completed.connect(_on_sequence_completed)


func _disconnect_signals() -> void:
	if not _sequence_tracker:
		return

	if _sequence_tracker.tree_started.is_connected(_on_tree_started):
		_sequence_tracker.tree_started.disconnect(_on_tree_started)
	if _sequence_tracker.tree_progressed.is_connected(_on_tree_progressed):
		_sequence_tracker.tree_progressed.disconnect(_on_tree_progressed)
	if _sequence_tracker.tree_died.is_connected(_on_tree_died):
		_sequence_tracker.tree_died.disconnect(_on_tree_died)
	if _sequence_tracker.sequence_completed.is_connected(_on_sequence_completed):
		_sequence_tracker.sequence_completed.disconnect(_on_sequence_completed)


# --- Signal Handlers ---

func _on_tree_started(pattern_name: String) -> void:
	_log("▶ %s tree STARTED" % pattern_name, COLOR_STARTED)


func _on_tree_progressed(pattern_name: String, progress: int, total: int) -> void:
	_log("↑ %s tree PROGRESSED (%d/%d)" % [pattern_name, progress, total], COLOR_PROGRESS)


func _on_tree_died(pattern_name: String) -> void:
	_log("✗ %s tree DIED" % pattern_name, COLOR_DIED)


func _on_sequence_completed(pet_type: int) -> void:
	var pet_name := _get_pet_name(pet_type)
	_log("★ %s sequence COMPLETED!" % pet_name, COLOR_COMPLETED)


## Logs a match event (call from board manager)
func log_match(tile_types: Array, is_initiating: bool) -> void:
	var type_names: Array[String] = []
	for t in tile_types:
		type_names.append(_get_tile_name(t))

	var prefix := "MATCH" if is_initiating else "CASCADE"
	var color := COLOR_MATCH if is_initiating else COLOR_INFO
	_log("%s: %s" % [prefix, ", ".join(type_names)], color)


## Logs the current active trees
func log_active_trees() -> void:
	if not _sequence_tracker:
		return

	var trees := _sequence_tracker.get_active_trees()
	if trees.is_empty():
		_log("No active trees", COLOR_INFO)
	else:
		for tree in trees:
			_log("  Active: %s (%d/%d)" % [
				tree.pattern.display_name,
				tree.progress,
				tree.pattern.pattern.size()
			], COLOR_INFO)


# --- Helper Methods ---

func _log(text: String, color: Color = Color.WHITE) -> void:
	var timestamp := "%.1f" % (Time.get_ticks_msec() / 1000.0)
	var entry := {
		"text": "[%s] %s" % [timestamp, text],
		"time": Time.get_ticks_msec(),
		"color": color
	}
	_log_entries.append(entry)

	# Add new label directly instead of rebuilding entire display
	_add_log_label(entry)

	# Trim old entries and remove corresponding labels
	while _log_entries.size() > MAX_LOG_LINES:
		_log_entries.pop_front()
		if _log_container and _log_container.get_child_count() > 0:
			var oldest_label := _log_container.get_child(0)
			_log_container.remove_child(oldest_label)
			oldest_label.queue_free()


func _add_log_label(entry: Dictionary) -> void:
	if not _log_container:
		return

	var label := Label.new()
	label.text = entry.text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", entry.color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_log_container.add_child(label)


func _update_display() -> void:
	if not _log_container:
		return

	# Clear existing labels
	for child in _log_container.get_children():
		child.queue_free()

	# Add labels for all entries
	for entry in _log_entries:
		_add_log_label(entry)


func _on_clear_pressed() -> void:
	_log_entries.clear()
	_update_display()


func _get_pet_name(pet_type: int) -> String:
	match pet_type:
		TileTypes.Type.BEAR_PET:
			return "BEAR"
		TileTypes.Type.HAWK_PET:
			return "HAWK"
		TileTypes.Type.SNAKE_PET:
			return "SNAKE"
		_:
			return "UNKNOWN"


func _get_tile_name(tile_type: int) -> String:
	match tile_type:
		TileTypes.Type.SWORD:
			return "Sword"
		TileTypes.Type.SHIELD:
			return "Shield"
		TileTypes.Type.POTION:
			return "Potion"
		TileTypes.Type.LIGHTNING:
			return "Lightning"
		TileTypes.Type.FILLER:
			return "Filler"
		TileTypes.Type.PET:
			return "Pet"
		TileTypes.Type.MANA:
			return "Mana"
		_:
			return "Unknown(%d)" % tile_type


## Cleanup
func clear() -> void:
	_disconnect_signals()
	_sequence_tracker = null
	_log_entries.clear()


func reset() -> void:
	_log_entries.clear()
	_update_display()
	_log("--- Match Reset ---", COLOR_INFO)
