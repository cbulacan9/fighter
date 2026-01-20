class_name DefensiveQueueDisplay
extends HBoxContainer

## Container managing defense icons for the Mirror Warden's Defensive Queue System.
## Shows queued defenses with timer bars and tracks their state via signals.

const ICON_SCENE := preload("res://scenes/ui/defensive_queue_icon.tscn")

const DURATION_MAP := {
	StatusTypes.StatusType.REFLECTION_QUEUED: DefensiveQueueManager.REFLECTION_WINDOW,
	StatusTypes.StatusType.CANCEL_QUEUED: DefensiveQueueManager.CANCEL_WINDOW,
	StatusTypes.StatusType.ABSORB_QUEUED: DefensiveQueueManager.ABSORB_WINDOW,
}

var _fighter: Fighter
var _defensive_queue: DefensiveQueueManager
var _icons: Dictionary = {}  # {StatusType: DefensiveQueueIcon}


func _ready() -> void:
	# Space icons apart
	add_theme_constant_override("separation", 4)
	# Disable processing until we have icons to update
	set_process(false)


func setup(fighter: Fighter, defensive_queue: DefensiveQueueManager) -> void:
	"""Initialize the display with a fighter and their defensive queue manager."""
	clear()

	_fighter = fighter
	_defensive_queue = defensive_queue

	if not defensive_queue:
		visible = false
		return

	visible = true

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
	"""Remove all icons and disconnect signals."""
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

	# Remove all icons
	for icon in _icons.values():
		if is_instance_valid(icon):
			icon.queue_free()
	_icons.clear()

	_fighter = null
	_defensive_queue = null


func _process(_delta: float) -> void:
	"""Update timer bars for all icons."""
	if _icons.is_empty():
		set_process(false)
		return

	if not _defensive_queue or not _fighter:
		return

	# Update each icon's timer from the defensive queue state
	for defense_type in _icons.keys():
		var icon: DefensiveQueueIcon = _icons[defense_type]
		if not is_instance_valid(icon):
			continue

		if _defensive_queue.has_queued_defense(_fighter, defense_type):
			# Get time remaining from internal state
			var queue_data: Dictionary = _defensive_queue._queued_defenses.get(_fighter, {})
			var defense_data: Dictionary = queue_data.get(defense_type, {})
			var time_remaining: float = defense_data.get("time_remaining", 0.0)
			icon.update_timer(time_remaining)

			# Update enhanced state
			var is_enhanced: bool = defense_data.get("enhanced", false)
			icon.set_enhanced(is_enhanced)


func _on_defense_queued(fighter: Fighter, defense_type: StatusTypes.StatusType) -> void:
	"""Called when a new defense is queued."""
	if fighter != _fighter:
		return

	# Enable processing since we have icons to update
	set_process(true)

	# Remove existing icon for this type if any
	if _icons.has(defense_type):
		var old_icon: DefensiveQueueIcon = _icons[defense_type]
		if is_instance_valid(old_icon):
			old_icon.queue_free()
		_icons.erase(defense_type)

	# Get duration and enhanced state from queue manager
	var duration: float = DURATION_MAP.get(defense_type, 2.0)
	var is_enhanced := _defensive_queue.is_enhanced(fighter, defense_type)

	# Apply enhanced duration multiplier
	if is_enhanced:
		duration *= DefensiveQueueManager.ENHANCED_DURATION_MULTIPLIER

	# Create new icon
	var icon: DefensiveQueueIcon = ICON_SCENE.instantiate()
	add_child(icon)
	icon.setup(defense_type, duration, is_enhanced)

	_icons[defense_type] = icon


func _on_defense_triggered(fighter: Fighter, defense_type: StatusTypes.StatusType) -> void:
	"""Called when a defense triggers (reflects, cancels, or absorbs)."""
	if fighter != _fighter:
		return

	if _icons.has(defense_type):
		var icon: DefensiveQueueIcon = _icons[defense_type]
		if is_instance_valid(icon):
			icon.play_trigger_animation()
		_icons.erase(defense_type)


func _on_defense_expired(fighter: Fighter, defense_type: StatusTypes.StatusType) -> void:
	"""Called when a defense expires without triggering."""
	if fighter != _fighter:
		return

	if _icons.has(defense_type):
		var icon: DefensiveQueueIcon = _icons[defense_type]
		if is_instance_valid(icon):
			icon.play_expire_animation()
		_icons.erase(defense_type)


func _on_absorb_damage_stored(fighter: Fighter, _amount: int, total: int) -> void:
	"""Called when damage is absorbed and stored."""
	if fighter != _fighter:
		return

	if _icons.has(StatusTypes.StatusType.ABSORB_QUEUED):
		var icon: DefensiveQueueIcon = _icons[StatusTypes.StatusType.ABSORB_QUEUED]
		if is_instance_valid(icon):
			icon.update_absorb_counter(total)


func get_icon_count() -> int:
	"""Return the number of active defense icons."""
	return _icons.size()


func has_defense_icon(defense_type: StatusTypes.StatusType) -> bool:
	"""Check if an icon exists for the given defense type."""
	return _icons.has(defense_type) and is_instance_valid(_icons[defense_type])
