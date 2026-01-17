class_name SequenceIndicator
extends Control

## UI component that displays match history with pattern highlighting.
## Shows the last 10 tiles matched, highlighting when patterns complete.

const HISTORY_SIZE := 10
const ICON_SIZE := Vector2(28, 28)
const ICON_SPACING := 2
const HIGHLIGHT_BORDER_COLOR := Color(1.0, 1.0, 0.3, 1.0)  # Yellow glow
const HIGHLIGHT_DURATION := 1.5
const EMPTY_SLOT_COLOR := Color(0.2, 0.2, 0.2, 0.5)
const HIGHLIGHT_SCALE := 1.15  # Scale up when highlighted
const PULSE_SPEED := 8.0  # Speed of pulse animation

@onready var history_container: HBoxContainer = $VBox/HistoryContainer
@onready var banked_label: Label = $VBox/BankedLabel

var _sequence_tracker: SequenceTracker
var _history_slots: Array[Control] = []
var _highlighted_indices: Array[int] = []
var _highlight_timer: float = 0.0


func _ready() -> void:
	_create_history_slots()
	_update_display()


func _process(delta: float) -> void:
	# Animate and fade out highlights over time
	if _highlight_timer > 0:
		_highlight_timer -= delta

		# Pulse animation for highlighted slots
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.001 * PULSE_SPEED) * 0.08
		var fade := minf(_highlight_timer / 0.5, 1.0)  # Fade out in last 0.5 seconds

		for idx in _highlighted_indices:
			if idx >= 0 and idx < _history_slots.size():
				var slot := _history_slots[idx]
				slot.scale = Vector2.ONE * HIGHLIGHT_SCALE * pulse

				# Fade the glow
				var glow := slot.get_node_or_null("Glow") as ColorRect
				if glow:
					glow.modulate.a = fade

		if _highlight_timer <= 0:
			_clear_highlights()


## Creates the 10 empty history slots
func _create_history_slots() -> void:
	if not history_container:
		return

	# Clear existing
	for child in history_container.get_children():
		child.queue_free()
	_history_slots.clear()

	# Create slots
	for i in range(HISTORY_SIZE):
		var slot := _create_empty_slot()
		history_container.add_child(slot)
		_history_slots.append(slot)


func _create_empty_slot() -> Control:
	var container := Control.new()
	container.custom_minimum_size = ICON_SIZE
	container.pivot_offset = ICON_SIZE / 2  # Center pivot for scaling

	# Glow border (behind everything, larger than slot)
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.custom_minimum_size = ICON_SIZE + Vector2(6, 6)
	glow.position = Vector2(-3, -3)
	glow.color = HIGHLIGHT_BORDER_COLOR
	glow.visible = false
	container.add_child(glow)

	var bg := ColorRect.new()
	bg.name = "Background"
	bg.custom_minimum_size = ICON_SIZE
	bg.color = EMPTY_SLOT_COLOR
	container.add_child(bg)

	var color_rect := ColorRect.new()
	color_rect.name = "TileColor"
	color_rect.custom_minimum_size = ICON_SIZE - Vector2(4, 4)
	color_rect.position = Vector2(2, 2)
	color_rect.visible = false
	container.add_child(color_rect)

	return container


## Sets up the indicator with a sequence tracker
func setup(tracker: SequenceTracker) -> void:
	_disconnect_signals()
	_sequence_tracker = tracker

	if tracker:
		if not tracker.history_updated.is_connected(_on_history_updated):
			tracker.history_updated.connect(_on_history_updated)
		if not tracker.sequence_completed.is_connected(_on_sequence_completed):
			tracker.sequence_completed.connect(_on_sequence_completed)
		if not tracker.sequence_banked.is_connected(_on_sequence_banked):
			tracker.sequence_banked.connect(_on_sequence_banked)
		if not tracker.sequence_activated.is_connected(_on_sequence_activated):
			tracker.sequence_activated.connect(_on_sequence_activated)

	_update_display()


func _disconnect_signals() -> void:
	if _sequence_tracker:
		if _sequence_tracker.history_updated.is_connected(_on_history_updated):
			_sequence_tracker.history_updated.disconnect(_on_history_updated)
		if _sequence_tracker.sequence_completed.is_connected(_on_sequence_completed):
			_sequence_tracker.sequence_completed.disconnect(_on_sequence_completed)
		if _sequence_tracker.sequence_banked.is_connected(_on_sequence_banked):
			_sequence_tracker.sequence_banked.disconnect(_on_sequence_banked)
		if _sequence_tracker.sequence_activated.is_connected(_on_sequence_activated):
			_sequence_tracker.sequence_activated.disconnect(_on_sequence_activated)


func clear() -> void:
	_disconnect_signals()
	_sequence_tracker = null
	_update_display()


func reset() -> void:
	_clear_highlights()
	_update_display()


## Updates the display based on current tracker state
func _update_display() -> void:
	if not is_inside_tree():
		return

	var history: Array[int] = []
	if _sequence_tracker:
		history = _sequence_tracker.get_match_history()

	# Update each slot
	for i in range(HISTORY_SIZE):
		if i < _history_slots.size():
			var slot := _history_slots[i]
			var history_idx := i

			if history_idx < history.size():
				_set_slot_tile(slot, history[history_idx])
			else:
				_set_slot_empty(slot)

	# Update banked sequences label
	_update_banked_label()


func _set_slot_tile(slot: Control, tile_type: int) -> void:
	var color_rect := slot.get_node_or_null("TileColor") as ColorRect
	var bg := slot.get_node_or_null("Background") as ColorRect

	if color_rect:
		color_rect.color = _get_tile_color(tile_type)
		color_rect.visible = true

	if bg:
		bg.color = Color(0.1, 0.1, 0.1, 0.8)


func _set_slot_empty(slot: Control) -> void:
	var color_rect := slot.get_node_or_null("TileColor") as ColorRect
	var bg := slot.get_node_or_null("Background") as ColorRect

	if color_rect:
		color_rect.visible = false

	if bg:
		bg.color = EMPTY_SLOT_COLOR


func _highlight_slots(indices: Array) -> void:
	_clear_highlights()

	for idx in indices:
		if idx >= 0 and idx < _history_slots.size():
			var slot := _history_slots[idx]

			# Show the glow border
			var glow := slot.get_node_or_null("Glow") as ColorRect
			if glow:
				glow.visible = true
				glow.modulate.a = 1.0

			# Brighten the tile color
			var color_rect := slot.get_node_or_null("TileColor") as ColorRect
			if color_rect and color_rect.visible:
				# Store original color and brighten it
				var bright_color := color_rect.color.lightened(0.4)
				color_rect.color = bright_color

			# Initial scale
			slot.scale = Vector2.ONE * HIGHLIGHT_SCALE

	_highlighted_indices.assign(indices)
	_highlight_timer = HIGHLIGHT_DURATION


func _clear_highlights() -> void:
	for i in range(_history_slots.size()):
		var slot := _history_slots[i]

		# Hide the glow
		var glow := slot.get_node_or_null("Glow") as ColorRect
		if glow:
			glow.visible = false

		# Reset scale
		slot.scale = Vector2.ONE

		# Restore original tile color (re-apply from history)
		if _sequence_tracker:
			var history := _sequence_tracker.get_match_history()
			if i < history.size():
				var color_rect := slot.get_node_or_null("TileColor") as ColorRect
				if color_rect:
					color_rect.color = _get_tile_color(history[i])

	_highlighted_indices.clear()


func _update_banked_label() -> void:
	if not banked_label:
		return

	if not _sequence_tracker:
		banked_label.text = ""
		return

	var banked := _sequence_tracker.get_banked_sequences()
	if banked.is_empty():
		banked_label.text = ""
	else:
		var text := "Ready: "
		for i in range(banked.size()):
			if i > 0:
				text += ", "
			var pattern := banked[i]
			var stacks := _sequence_tracker.get_banked_stacks(pattern)
			text += "%s" % pattern.display_name
			if stacks > 1:
				text += " x%d" % stacks
		banked_label.text = text


## Returns a color for the given tile type
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
		_:
			return Color(0.4, 0.4, 0.4)


# --- Signal Handlers ---

func _on_history_updated(_history: Array, highlighted_indices: Array) -> void:
	_update_display()

	# Highlight completed pattern tiles
	if highlighted_indices.size() > 0:
		_highlight_slots(highlighted_indices)


func _on_sequence_completed(_pattern: SequencePattern) -> void:
	# Flash effect handled by history_updated highlights
	pass


func _on_sequence_banked(_pattern: SequencePattern, _stacks: int) -> void:
	_update_banked_label()


func _on_sequence_activated(_pattern: SequencePattern, _stacks: int) -> void:
	_update_banked_label()
