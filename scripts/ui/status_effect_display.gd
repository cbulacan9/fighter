class_name StatusEffectDisplay
extends HBoxContainer

## Container that displays all active status effects for a fighter.
## Automatically updates when effects are applied, removed, or changed.

@export var icon_scene: PackedScene
@export var max_visible_effects: int = 6

var _fighter: Fighter
var _status_manager: StatusEffectManager
var _icons: Dictionary = {}  # StatusTypes.StatusType -> StatusEffectIcon


func _ready() -> void:
	# Default icon scene if not set
	if icon_scene == null:
		icon_scene = preload("res://scenes/ui/status_effect_icon.tscn")

	# Set up container properties
	add_theme_constant_override("separation", 4)


func setup(fighter: Fighter, status_manager: StatusEffectManager = null) -> void:
	"""Initialize the display with a fighter and status manager."""
	_cleanup_connections()
	_clear_all_icons()

	_fighter = fighter
	_status_manager = status_manager

	if _fighter == null:
		return

	# Connect to fighter signals for status effect changes
	if not _fighter.status_effect_applied.is_connected(_on_status_effect_applied):
		_fighter.status_effect_applied.connect(_on_status_effect_applied)
	if not _fighter.status_effect_removed.is_connected(_on_status_effect_removed):
		_fighter.status_effect_removed.connect(_on_status_effect_removed)

	# Connect to status manager signals if available
	if _status_manager:
		if not _status_manager.effect_stacked.is_connected(_on_effect_stacked):
			_status_manager.effect_stacked.connect(_on_effect_stacked)

	# Initial refresh to show any existing effects
	_refresh_all()


func _process(_delta: float) -> void:
	"""Update duration displays for all active icons."""
	if _fighter == null:
		return

	# Update duration bars for all icons
	for effect_type in _icons.keys():
		var icon: StatusEffectIcon = _icons[effect_type]
		if icon and is_instance_valid(icon):
			var effect := _get_effect_for_type(effect_type)
			if effect:
				icon.update_display(effect)


func _on_status_effect_applied(effect: StatusEffect) -> void:
	"""Called when a new status effect is applied to the fighter."""
	if effect == null:
		return

	var effect_type := effect.data.effect_type

	# Check if we already have an icon for this effect type
	if _icons.has(effect_type):
		# Update existing icon
		var icon: StatusEffectIcon = _icons[effect_type]
		if icon and is_instance_valid(icon):
			icon.update_display(effect)
	else:
		# Create new icon
		_create_icon(effect)


func _on_status_effect_removed(effect_type: StatusTypes.StatusType) -> void:
	"""Called when a status effect is removed from the fighter."""
	_remove_icon(effect_type)


func _on_effect_stacked(target: Fighter, effect: StatusEffect, _new_stacks: int) -> void:
	"""Called when a status effect's stack count changes."""
	if target != _fighter:
		return

	var effect_type := effect.data.effect_type
	if _icons.has(effect_type):
		var icon: StatusEffectIcon = _icons[effect_type]
		if icon and is_instance_valid(icon):
			icon.update_display(effect)


func _create_icon(effect: StatusEffect) -> void:
	"""Create a new icon for the given effect."""
	if effect == null or icon_scene == null:
		return

	var effect_type := effect.data.effect_type

	# Don't exceed max visible effects
	if _icons.size() >= max_visible_effects:
		return

	# Don't create duplicate icons
	if _icons.has(effect_type):
		return

	# Instance the icon scene
	var icon: StatusEffectIcon = icon_scene.instantiate() as StatusEffectIcon
	if icon == null:
		return

	# Add to container and setup
	add_child(icon)
	icon.setup(effect)

	# Store reference
	_icons[effect_type] = icon


func _remove_icon(effect_type: StatusTypes.StatusType) -> void:
	"""Remove the icon for the given effect type."""
	if not _icons.has(effect_type):
		return

	var icon: StatusEffectIcon = _icons[effect_type]
	_icons.erase(effect_type)

	if icon and is_instance_valid(icon):
		icon.queue_free()


func _refresh_all() -> void:
	"""Refresh the display by clearing and recreating all icons."""
	_clear_all_icons()

	if _fighter == null:
		return

	# Get all active effects on the fighter
	var effects := _fighter.get_all_status_effects()

	# Create icons for each effect (up to max_visible_effects)
	var count := 0
	for effect in effects:
		if count >= max_visible_effects:
			break
		_create_icon(effect)
		count += 1


func _clear_all_icons() -> void:
	"""Remove all icons from the display."""
	for effect_type in _icons.keys():
		var icon: StatusEffectIcon = _icons[effect_type]
		if icon and is_instance_valid(icon):
			icon.queue_free()
	_icons.clear()


func _get_effect_for_type(effect_type: StatusTypes.StatusType) -> StatusEffect:
	"""Get the current effect for a given type from the fighter."""
	if _fighter == null:
		return null

	if _status_manager:
		return _status_manager.get_effect(_fighter, effect_type)

	# Fallback: search through all effects
	var effects := _fighter.get_all_status_effects()
	for effect in effects:
		if effect.data.effect_type == effect_type:
			return effect

	return null


func _cleanup_connections() -> void:
	"""Disconnect all signal connections."""
	if _fighter:
		if _fighter.status_effect_applied.is_connected(_on_status_effect_applied):
			_fighter.status_effect_applied.disconnect(_on_status_effect_applied)
		if _fighter.status_effect_removed.is_connected(_on_status_effect_removed):
			_fighter.status_effect_removed.disconnect(_on_status_effect_removed)

	if _status_manager:
		if _status_manager.effect_stacked.is_connected(_on_effect_stacked):
			_status_manager.effect_stacked.disconnect(_on_effect_stacked)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_connections()
