class_name PetPopulationDisplay
extends Control

## Shows current Pet counts with MAX POP feedback when cap reached.
## Displays: Bear 0/3  Hawk 0/3  Snake 0/3
## Shows "MAX POP" label briefly when a pet spawn is blocked.

const ICON_SIZE := Vector2(20, 20)
const COUNTER_SPACING := 12
const MAX_POP_DURATION := 1.5
const HIGHLIGHT_COLOR := Color(1.0, 1.0, 0.5, 1.0)  # Yellow highlight

var _pet_spawner: PetSpawner

@onready var _hbox: HBoxContainer = $HBox
@onready var _max_pop_label: Label = $MaxPopLabel
@onready var _bear_counter: HBoxContainer
@onready var _hawk_counter: HBoxContainer
@onready var _snake_counter: HBoxContainer
@onready var _bear_label: Label
@onready var _hawk_label: Label
@onready var _snake_label: Label


func _ready() -> void:
	# Ensure containers exist
	if not _hbox:
		_hbox = $HBox
	if not _max_pop_label:
		_max_pop_label = $MaxPopLabel

	# Build the display if needed
	if _hbox and _hbox.get_child_count() == 0:
		_build_display()

	# Hide MAX POP label initially
	if _max_pop_label:
		_max_pop_label.visible = false


## Sets up the display with a PetSpawner and connects to its signals.
func setup(pet_spawner: PetSpawner) -> void:
	_pet_spawner = pet_spawner

	if pet_spawner:
		if not pet_spawner.pet_spawned.is_connected(_on_pet_spawned):
			pet_spawner.pet_spawned.connect(_on_pet_spawned)
		if not pet_spawner.pet_spawn_blocked.is_connected(_on_pet_spawn_blocked):
			pet_spawner.pet_spawn_blocked.connect(_on_pet_spawn_blocked)
		if not pet_spawner.pet_activated.is_connected(_on_pet_activated):
			pet_spawner.pet_activated.connect(_on_pet_activated)

	_update_display()


## Builds the visual display with counters for each pet type.
func _build_display() -> void:
	if not _hbox:
		return

	# Clear existing children
	for child in _hbox.get_children():
		child.queue_free()

	# Create Bear counter
	_bear_counter = _create_counter("Bear", Color(0.7, 0.4, 0.2))  # Brown
	_bear_label = _bear_counter.get_node("CountLabel") as Label
	_hbox.add_child(_bear_counter)

	# Spacer
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(COUNTER_SPACING, 0)
	_hbox.add_child(spacer1)

	# Create Hawk counter
	_hawk_counter = _create_counter("Hawk", Color(0.3, 0.6, 0.9))  # Light blue
	_hawk_label = _hawk_counter.get_node("CountLabel") as Label
	_hbox.add_child(_hawk_counter)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(COUNTER_SPACING, 0)
	_hbox.add_child(spacer2)

	# Create Snake counter
	_snake_counter = _create_counter("Snake", Color(0.2, 0.8, 0.3))  # Green
	_snake_label = _snake_counter.get_node("CountLabel") as Label
	_hbox.add_child(_snake_counter)


## Creates a counter widget for a pet type.
func _create_counter(pet_name: String, color: Color) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	# Pet icon/label
	var icon_container := Control.new()
	icon_container.custom_minimum_size = ICON_SIZE

	var icon_bg := ColorRect.new()
	icon_bg.custom_minimum_size = ICON_SIZE
	icon_bg.color = color
	icon_container.add_child(icon_bg)

	container.add_child(icon_container)

	# Count label
	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.text = "0/3"
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(count_label)

	# Store pet name as metadata for highlighting
	container.set_meta("pet_name", pet_name)

	return container


## Updates the display based on current PetSpawner state.
func _update_display() -> void:
	if not _pet_spawner:
		if _bear_label:
			_bear_label.text = "0/3"
		if _hawk_label:
			_hawk_label.text = "0/3"
		if _snake_label:
			_snake_label.text = "0/3"
		return

	if _bear_label:
		_bear_label.text = "%d/3" % _pet_spawner.get_count(TileTypes.Type.BEAR_PET)
	if _hawk_label:
		_hawk_label.text = "%d/3" % _pet_spawner.get_count(TileTypes.Type.HAWK_PET)
	if _snake_label:
		_snake_label.text = "%d/3" % _pet_spawner.get_count(TileTypes.Type.SNAKE_PET)


## Signal handler: pet spawned - update display and highlight counter.
func _on_pet_spawned(pet_type: int, _column: int) -> void:
	_update_display()
	_highlight_counter(pet_type)


## Signal handler: pet spawn blocked - flash MAX POP label.
func _on_pet_spawn_blocked(pet_type: int) -> void:
	_flash_max_pop(pet_type)


## Signal handler: pet activated - update display.
func _on_pet_activated(_pet_type: int) -> void:
	_update_display()


## Highlights the counter for a pet type briefly.
func _highlight_counter(pet_type: int) -> void:
	var counter: HBoxContainer = _get_counter_for_pet(pet_type)
	if not counter:
		return

	var label := counter.get_node_or_null("CountLabel") as Label
	if label:
		var original_color := label.modulate
		var tween := create_tween()
		tween.tween_property(label, "modulate", HIGHLIGHT_COLOR, 0.1)
		tween.tween_property(label, "modulate", original_color, 0.3)


## Flashes the MAX POP label for the given pet type.
func _flash_max_pop(pet_type: int) -> void:
	if not _max_pop_label:
		return

	# Set text with pet name
	var pet_name := _get_pet_name(pet_type)
	_max_pop_label.text = "%s MAX!" % pet_name

	# Show label and start timer to hide
	_max_pop_label.visible = true
	_max_pop_label.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_interval(MAX_POP_DURATION - 0.5)
	tween.tween_property(_max_pop_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): _max_pop_label.visible = false)


## Returns the counter container for a pet type.
func _get_counter_for_pet(pet_type: int) -> HBoxContainer:
	match pet_type:
		TileTypes.Type.BEAR_PET:
			return _bear_counter
		TileTypes.Type.HAWK_PET:
			return _hawk_counter
		TileTypes.Type.SNAKE_PET:
			return _snake_counter
	return null


## Returns the display name for a pet type.
func _get_pet_name(pet_type: int) -> String:
	match pet_type:
		TileTypes.Type.BEAR_PET:
			return "Bear"
		TileTypes.Type.HAWK_PET:
			return "Hawk"
		TileTypes.Type.SNAKE_PET:
			return "Snake"
	return "Pet"


## Resets the display to initial state.
func reset() -> void:
	_update_display()
	if _max_pop_label:
		_max_pop_label.visible = false


## Disconnects from PetSpawner signals.
func clear() -> void:
	if _pet_spawner:
		if _pet_spawner.pet_spawned.is_connected(_on_pet_spawned):
			_pet_spawner.pet_spawned.disconnect(_on_pet_spawned)
		if _pet_spawner.pet_spawn_blocked.is_connected(_on_pet_spawn_blocked):
			_pet_spawner.pet_spawn_blocked.disconnect(_on_pet_spawn_blocked)
		if _pet_spawner.pet_activated.is_connected(_on_pet_activated):
			_pet_spawner.pet_activated.disconnect(_on_pet_activated)

	_pet_spawner = null
