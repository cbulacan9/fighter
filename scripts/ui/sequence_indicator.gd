class_name SequenceIndicator
extends Control

## UI component that displays current sequence progress and banked sequences.
## Shows the tiles matched in the current sequence, possible pattern completions,
## and banked sequences with stack counts.

const ICON_SIZE := Vector2(24, 24)
const BANKED_ICON_SIZE := Vector2(32, 32)
const BANKED_CONTAINER_SIZE := Vector2(40, 40)
const ANIMATION_DURATION := 0.2
const FLASH_COLOR_COMPLETION := Color(1.5, 1.5, 1.0)
const FLASH_COLOR_BREAK := Color(1.0, 0.5, 0.5)
const COMPLETED_TILE_MODULATE := Color(0.5, 0.5, 0.5, 0.7)
const TERMINATOR_MODULATE := Color(1.0, 1.0, 0.5)
const GLOW_COLOR := Color(1.0, 1.0, 0.5, 0.3)

@export var show_possible_completions: bool = true
@export var max_visible_completions: int = 3

@onready var current_container: HBoxContainer = $VBox/TopRow/CurrentSequence
@onready var arrow: TextureRect = $VBox/TopRow/Arrow
@onready var completions_container: VBoxContainer = $VBox/PossibleCompletions
@onready var banked_container: HBoxContainer = $VBox/TopRow/BankedSequences

var _sequence_tracker: SequenceTracker
var _tile_icons: Dictionary = {}  # {TileTypes.Type: Texture2D}
var _tween: Tween


func _ready() -> void:
	_load_tile_icons()
	_update_display()


## Sets up the indicator with a sequence tracker to monitor
## Call this when the board manager is initialized with a character that uses sequences
func setup(tracker: SequenceTracker) -> void:
	_sequence_tracker = tracker

	if tracker:
		# Connect to tracker signals
		if not tracker.sequence_progressed.is_connected(_on_sequence_progressed):
			tracker.sequence_progressed.connect(_on_sequence_progressed)
		if not tracker.sequence_completed.is_connected(_on_sequence_completed):
			tracker.sequence_completed.connect(_on_sequence_completed)
		if not tracker.sequence_broken.is_connected(_on_sequence_broken):
			tracker.sequence_broken.connect(_on_sequence_broken)
		if not tracker.sequence_banked.is_connected(_on_sequence_banked):
			tracker.sequence_banked.connect(_on_sequence_banked)
		if not tracker.sequence_activated.is_connected(_on_sequence_activated):
			tracker.sequence_activated.connect(_on_sequence_activated)

	_update_display()


## Clears the tracker connection and resets display
func clear() -> void:
	if _sequence_tracker:
		if _sequence_tracker.sequence_progressed.is_connected(_on_sequence_progressed):
			_sequence_tracker.sequence_progressed.disconnect(_on_sequence_progressed)
		if _sequence_tracker.sequence_completed.is_connected(_on_sequence_completed):
			_sequence_tracker.sequence_completed.disconnect(_on_sequence_completed)
		if _sequence_tracker.sequence_broken.is_connected(_on_sequence_broken):
			_sequence_tracker.sequence_broken.disconnect(_on_sequence_broken)
		if _sequence_tracker.sequence_banked.is_connected(_on_sequence_banked):
			_sequence_tracker.sequence_banked.disconnect(_on_sequence_banked)
		if _sequence_tracker.sequence_activated.is_connected(_on_sequence_activated):
			_sequence_tracker.sequence_activated.disconnect(_on_sequence_activated)

	_sequence_tracker = null
	_update_display()


## Loads icons for each tile type
## Icons are stored in assets/ui/icons/ directory
## Falls back to placeholder colors if icons don't exist
func _load_tile_icons() -> void:
	# Try to load icons from assets
	# If not available, we'll create colored placeholders in _create_tile_icon
	var icon_paths := {
		TileTypes.Type.SWORD: "res://assets/ui/icons/sword_small.png",
		TileTypes.Type.SHIELD: "res://assets/ui/icons/shield_small.png",
		TileTypes.Type.POTION: "res://assets/ui/icons/potion_small.png",
		TileTypes.Type.LIGHTNING: "res://assets/ui/icons/stun_small.png",
		TileTypes.Type.FILLER: "res://assets/ui/icons/filler_small.png",
		TileTypes.Type.PET: "res://assets/ui/icons/pet_small.png",
		TileTypes.Type.MANA: "res://assets/ui/icons/mana_small.png",
	}

	for tile_type in icon_paths:
		var path: String = icon_paths[tile_type]
		if ResourceLoader.exists(path):
			_tile_icons[tile_type] = load(path) as Texture2D


## Updates all display sections
func _update_display() -> void:
	_update_current_sequence()
	_update_possible_completions()
	_update_banked_sequences()


## Updates the current sequence display with matched tile icons
func _update_current_sequence() -> void:
	if not current_container:
		return

	# Clear existing icons
	_clear_container(current_container)

	if not _sequence_tracker:
		_set_arrow_visible(false)
		return

	var current := _sequence_tracker.get_current_sequence()

	for tile_type in current:
		var icon := _create_tile_icon(tile_type)
		if icon:
			current_container.add_child(icon)

	# Show/hide arrow based on sequence length
	_set_arrow_visible(current.size() > 0)


## Updates the possible completions preview
## Shows patterns that can still be completed from the current sequence state
func _update_possible_completions() -> void:
	if not completions_container:
		return

	# Clear existing previews
	_clear_container(completions_container)

	if not show_possible_completions or not _sequence_tracker:
		completions_container.visible = false
		return

	var current := _sequence_tracker.get_current_sequence()
	if current.is_empty():
		completions_container.visible = false
		return

	var possible := _sequence_tracker._get_possible_completions()
	completions_container.visible = possible.size() > 0

	var count := 0
	for pattern in possible:
		if count >= max_visible_completions:
			break

		var preview := _create_sequence_preview(pattern, current.size())
		if preview:
			completions_container.add_child(preview)
		count += 1


## Updates the banked sequences display
## Shows all completed sequences with their stack counts
func _update_banked_sequences() -> void:
	if not banked_container:
		return

	# Clear existing icons
	_clear_container(banked_container)

	if not _sequence_tracker:
		return

	var banked := _sequence_tracker.get_banked_sequences()

	for pattern in banked:
		var stacks := _sequence_tracker.get_banked_stacks(pattern)
		var icon := _create_banked_icon(pattern, stacks)
		if icon:
			banked_container.add_child(icon)


## Creates a tile icon for the given tile type
func _create_tile_icon(tile_type: int) -> Control:
	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	if _tile_icons.has(tile_type):
		icon.texture = _tile_icons[tile_type]
	else:
		# Create a colored placeholder
		return _create_placeholder_icon(tile_type)

	return icon


## Creates a colored placeholder icon when texture is not available
func _create_placeholder_icon(tile_type: int) -> Control:
	var container := Control.new()
	container.custom_minimum_size = ICON_SIZE

	var color_rect := ColorRect.new()
	color_rect.custom_minimum_size = ICON_SIZE
	color_rect.color = _get_tile_color(tile_type)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(color_rect)

	# Add border
	var border := ColorRect.new()
	border.custom_minimum_size = ICON_SIZE
	border.color = Color(0.2, 0.2, 0.2, 1.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(border)
	container.move_child(border, 0)

	# Inset the color rect slightly for border effect
	color_rect.position = Vector2(2, 2)
	color_rect.custom_minimum_size = ICON_SIZE - Vector2(4, 4)

	return container


## Returns a color for the given tile type
func _get_tile_color(tile_type: int) -> Color:
	match tile_type:
		TileTypes.Type.SWORD:
			return Color(0.8, 0.2, 0.2)  # Red
		TileTypes.Type.SHIELD:
			return Color(0.3, 0.5, 0.9)  # Blue
		TileTypes.Type.POTION:
			return Color(0.2, 0.8, 0.2)  # Green
		TileTypes.Type.LIGHTNING:
			return Color(0.9, 0.9, 0.2)  # Yellow
		TileTypes.Type.FILLER:
			return Color(0.5, 0.5, 0.5)  # Gray
		TileTypes.Type.PET:
			return Color(0.7, 0.4, 0.9)  # Purple
		TileTypes.Type.MANA:
			return Color(0.2, 0.7, 0.9)  # Cyan
		_:
			return Color(0.4, 0.4, 0.4)  # Default gray


## Creates a preview for a possible sequence completion
## Shows the full pattern with completed tiles dimmed
func _create_sequence_preview(pattern: SequencePattern, progress: int) -> Control:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	# Show all tiles in the pattern
	for i in range(pattern.pattern.size()):
		var icon := _create_tile_icon(pattern.pattern[i])

		# Dim completed tiles
		if i < progress:
			icon.modulate = COMPLETED_TILE_MODULATE
		else:
			icon.modulate = Color.WHITE

		container.add_child(icon)

	# Add terminator icon with highlight
	var term_icon := _create_tile_icon(pattern.terminator)
	term_icon.modulate = TERMINATOR_MODULATE
	container.add_child(term_icon)

	# Add pattern name label
	var label := Label.new()
	label.text = pattern.display_name
	label.add_theme_font_size_override("font_size", 12)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	return container


## Creates an icon for a banked sequence with stack count badge
func _create_banked_icon(pattern: SequencePattern, stacks: int) -> Control:
	var container := Control.new()
	container.custom_minimum_size = BANKED_CONTAINER_SIZE

	# Glow background (shows ready state)
	var glow := ColorRect.new()
	glow.color = GLOW_COLOR
	glow.size = BANKED_CONTAINER_SIZE
	glow.position = Vector2.ZERO
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(glow)

	# Pattern icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = BANKED_ICON_SIZE
	icon.position = Vector2(4, 4)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	if pattern.icon:
		icon.texture = pattern.icon
	else:
		# Create a placeholder based on the pattern's first tile type
		var placeholder := _create_banked_placeholder(pattern)
		placeholder.position = Vector2(4, 4)
		container.add_child(placeholder)
		icon.queue_free()
		icon = null

	if icon:
		container.add_child(icon)

	# Stack count badge
	if stacks > 1:
		var badge := Label.new()
		badge.text = "x%d" % stacks
		badge.position = Vector2(24, 24)
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_color_override("font_shadow_color", Color.BLACK)
		badge.add_theme_constant_override("shadow_offset_x", 1)
		badge.add_theme_constant_override("shadow_offset_y", 1)
		container.add_child(badge)

	# Tooltip with pattern info
	if pattern.description:
		container.tooltip_text = "%s\n%s" % [pattern.display_name, pattern.description]
	else:
		container.tooltip_text = pattern.display_name

	return container


## Creates a placeholder icon for banked sequences without a custom icon
func _create_banked_placeholder(pattern: SequencePattern) -> Control:
	var container := Control.new()
	container.custom_minimum_size = BANKED_ICON_SIZE

	var color_rect := ColorRect.new()
	color_rect.size = BANKED_ICON_SIZE
	color_rect.position = Vector2.ZERO
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Use first tile type color for the placeholder
	if pattern.pattern.size() > 0:
		color_rect.color = _get_tile_color(pattern.pattern[0])
	else:
		color_rect.color = Color(0.5, 0.5, 0.5)

	container.add_child(color_rect)

	return container


## Sets arrow visibility (with null check)
func _set_arrow_visible(is_visible: bool) -> void:
	if arrow:
		arrow.visible = is_visible


## Clears all children from a container
func _clear_container(container: Container) -> void:
	if not container:
		return

	for child in container.get_children():
		child.queue_free()


## Plays a flash animation on completion
func _flash_completion(pattern: SequencePattern) -> void:
	if not banked_container:
		return

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(banked_container, "modulate", FLASH_COLOR_COMPLETION, 0.1)
	_tween.tween_property(banked_container, "modulate", Color.WHITE, ANIMATION_DURATION)


## Plays a flash animation on sequence break
func _flash_break() -> void:
	if not current_container:
		return

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(current_container, "modulate", FLASH_COLOR_BREAK, 0.1)
	_tween.tween_property(current_container, "modulate", Color.WHITE, ANIMATION_DURATION)


# --- Signal Handlers ---

func _on_sequence_progressed(_current: Array, _possible: Array) -> void:
	_update_display()


func _on_sequence_completed(pattern: SequencePattern) -> void:
	_update_display()
	_flash_completion(pattern)


func _on_sequence_broken() -> void:
	_update_display()
	_flash_break()


func _on_sequence_banked(_pattern: SequencePattern, _stacks: int) -> void:
	_update_banked_sequences()


func _on_sequence_activated(_pattern: SequencePattern, _stacks: int) -> void:
	_update_banked_sequences()
