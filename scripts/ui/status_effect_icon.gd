class_name StatusEffectIcon
extends Control

## UI component that displays a single status effect icon with stack count and duration bar.

@onready var icon_texture: TextureRect = $IconTexture
@onready var stack_label: Label = $StackLabel
@onready var duration_bar: ProgressBar = $DurationBar
@onready var icon_background: ColorRect = $IconBackground

var _effect_type: StatusTypes.StatusType
var _max_duration: float = 0.0
var _current_effect: StatusEffect


func _ready() -> void:
	# Ensure minimum size
	custom_minimum_size = Vector2(32, 32)

	# Initialize stack label to hidden (shown only when stacks > 1)
	if stack_label:
		stack_label.visible = false

	# Initialize duration bar to hidden
	if duration_bar:
		duration_bar.visible = false


func setup(effect: StatusEffect) -> void:
	"""Initialize the icon display with a status effect."""
	if effect == null:
		return

	_current_effect = effect
	_effect_type = effect.data.effect_type
	_max_duration = effect.data.duration

	# Set icon texture
	if icon_texture:
		if effect.data.icon:
			icon_texture.texture = effect.data.icon
			icon_texture.visible = true
			if icon_background:
				icon_background.visible = false
		else:
			# Try to use generated placeholder icon
			var placeholder := StatusEffectIcons.get_icon_texture(_effect_type)
			if placeholder:
				icon_texture.texture = placeholder
				icon_texture.visible = true
				if icon_background:
					icon_background.visible = false
			else:
				# Fall back to colored background
				_apply_placeholder_visual(_effect_type)

	# Update the display with current values
	update_display(effect)


func update_display(effect: StatusEffect) -> void:
	"""Update the display with current stack count and duration."""
	if effect == null:
		return

	_current_effect = effect

	# Update stack count display
	if stack_label:
		if effect.stacks > 1:
			stack_label.text = "x%d" % effect.stacks
			stack_label.visible = true
		else:
			stack_label.visible = false

	# Update duration bar
	if duration_bar:
		if _max_duration > 0:
			duration_bar.visible = true
			duration_bar.max_value = _max_duration
			duration_bar.value = effect.remaining_duration
		else:
			# Permanent effect - hide duration bar
			duration_bar.visible = false


func get_effect_type() -> StatusTypes.StatusType:
	"""Return the effect type this icon represents."""
	return _effect_type


func get_current_effect() -> StatusEffect:
	"""Return the current effect being displayed."""
	return _current_effect


func _apply_placeholder_visual(type: StatusTypes.StatusType) -> void:
	"""Apply a colored background as placeholder visual based on effect type."""
	if not icon_background:
		return

	icon_background.visible = true
	icon_background.color = _get_placeholder_color(type)

	# Hide the texture rect since we're using a placeholder
	if icon_texture:
		icon_texture.visible = false


func _get_placeholder_color(type: StatusTypes.StatusType) -> Color:
	"""Return a placeholder color based on the effect type."""
	match type:
		StatusTypes.StatusType.POISON:
			return Color(0.2, 0.8, 0.2)  # Green
		StatusTypes.StatusType.BLEED:
			return Color(0.8, 0.2, 0.2)  # Red
		StatusTypes.StatusType.ATTACK_UP:
			return Color(1.0, 0.6, 0.1)  # Orange/Yellow
		StatusTypes.StatusType.DODGE:
			return Color(0.3, 0.5, 1.0)  # Blue
		StatusTypes.StatusType.EVASION:
			return Color(0.6, 0.6, 0.6)  # Gray
		StatusTypes.StatusType.MANA_BLOCK:
			return Color(0.6, 0.2, 0.8)  # Purple
		# Defensive queue status colors (Mirror Warden)
		StatusTypes.StatusType.REFLECTION_QUEUED:
			return Color(0.3, 0.5, 1.0)  # Blue
		StatusTypes.StatusType.CANCEL_QUEUED:
			return Color(0.9, 0.3, 0.3)  # Red
		StatusTypes.StatusType.ABSORB_QUEUED:
			return Color(0.3, 0.8, 0.3)  # Green
		StatusTypes.StatusType.ABSORB_STORED:
			return Color(0.3, 0.8, 0.3)  # Green
		StatusTypes.StatusType.INVINCIBILITY:
			return Color(1.0, 0.9, 0.3)  # Gold
		_:
			return Color(0.5, 0.5, 0.5)  # Default gray


func _get_type_symbol(type: StatusTypes.StatusType) -> String:
	"""Return a text symbol to display for the effect type."""
	match type:
		StatusTypes.StatusType.POISON:
			return "P"
		StatusTypes.StatusType.BLEED:
			return "B"
		StatusTypes.StatusType.ATTACK_UP:
			return "A"
		StatusTypes.StatusType.DODGE:
			return "D"
		StatusTypes.StatusType.EVASION:
			return "E"
		StatusTypes.StatusType.MANA_BLOCK:
			return "M"
		# Defensive queue status symbols (Mirror Warden)
		StatusTypes.StatusType.REFLECTION_QUEUED:
			return "R"
		StatusTypes.StatusType.CANCEL_QUEUED:
			return "C"
		StatusTypes.StatusType.ABSORB_QUEUED:
			return "A"
		StatusTypes.StatusType.ABSORB_STORED:
			return "S"
		StatusTypes.StatusType.INVINCIBILITY:
			return "I"
		_:
			return "?"
