class_name DefensiveQueueIcon
extends Control

## Individual defense icon showing type letter, timer bar, and optional absorb counter.
## Follows StatusEffectIcon pattern but specialized for defensive queue visualization.

signal triggered()
signal expired()

const COLORS := {
	StatusTypes.StatusType.REFLECTION_QUEUED: Color(0.8, 0.3, 1.0),   # Purple
	StatusTypes.StatusType.CANCEL_QUEUED: Color(0.4, 1.0, 0.4),       # Green
	StatusTypes.StatusType.ABSORB_QUEUED: Color(0.3, 0.7, 1.0),       # Blue
}

const LABELS := {
	StatusTypes.StatusType.REFLECTION_QUEUED: "R",
	StatusTypes.StatusType.CANCEL_QUEUED: "C",
	StatusTypes.StatusType.ABSORB_QUEUED: "A",
}

const ENHANCED_COLOR := Color(1.0, 0.9, 0.3)  # Gold for enhanced border

@onready var icon_background: ColorRect = $IconBackground
@onready var icon_label: Label = $IconLabel
@onready var timer_bar: ProgressBar = $TimerBar
@onready var absorb_counter: Label = $AbsorbCounter
@onready var enhanced_border: ColorRect = $EnhancedBorder

var _defense_type: StatusTypes.StatusType
var _max_duration: float = 0.0
var _time_remaining: float = 0.0
var _is_enhanced: bool = false
var _stored_damage: int = 0
var _enhanced_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(24, 40)

	if absorb_counter:
		absorb_counter.visible = false

	if enhanced_border:
		enhanced_border.visible = false


func setup(defense_type: StatusTypes.StatusType, duration: float, is_enhanced: bool) -> void:
	"""Initialize the icon with a defense type and duration."""
	_defense_type = defense_type
	_max_duration = duration
	_time_remaining = duration
	_is_enhanced = is_enhanced
	_stored_damage = 0

	# Set background color
	if icon_background:
		icon_background.color = COLORS.get(defense_type, Color(0.5, 0.5, 0.5))

	# Set label text
	if icon_label:
		icon_label.text = LABELS.get(defense_type, "?")

	# Setup timer bar
	if timer_bar:
		timer_bar.max_value = duration
		timer_bar.value = duration

	# Show absorb counter only for absorb type
	if absorb_counter:
		absorb_counter.visible = defense_type == StatusTypes.StatusType.ABSORB_QUEUED
		absorb_counter.text = "0"

	# Setup enhanced indicator
	_update_enhanced_state()

	visible = true
	modulate.a = 1.0


func update_timer(time_remaining: float) -> void:
	"""Update the timer bar with remaining time."""
	_time_remaining = time_remaining

	if timer_bar:
		timer_bar.value = time_remaining

	# Fade slightly as time runs out
	if _max_duration > 0:
		var ratio := time_remaining / _max_duration
		modulate.a = 0.5 + (ratio * 0.5)


func update_absorb_counter(stored_damage: int) -> void:
	"""Update the absorb damage counter (for Absorb type only)."""
	_stored_damage = stored_damage

	if absorb_counter and _defense_type == StatusTypes.StatusType.ABSORB_QUEUED:
		absorb_counter.text = str(stored_damage)
		absorb_counter.visible = true


func set_enhanced(is_enhanced: bool) -> void:
	"""Update enhanced state (3 consecutive matches)."""
	_is_enhanced = is_enhanced
	_update_enhanced_state()


func play_trigger_animation() -> void:
	"""Flash animation when defense triggers."""
	triggered.emit()

	# Quick flash to white then fade out
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.2)
	tween.tween_callback(queue_free)


func play_expire_animation() -> void:
	"""Fade out animation when defense expires."""
	expired.emit()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func get_defense_type() -> StatusTypes.StatusType:
	return _defense_type


func get_time_remaining() -> float:
	return _time_remaining


func is_enhanced() -> bool:
	return _is_enhanced


func _update_enhanced_state() -> void:
	"""Update the enhanced border visibility and pulsing effect."""
	if not enhanced_border:
		return

	if _is_enhanced:
		enhanced_border.visible = true
		_start_enhanced_pulse()
	else:
		enhanced_border.visible = false
		_stop_enhanced_pulse()


func _start_enhanced_pulse() -> void:
	"""Start pulsing gold border for enhanced state."""
	if _enhanced_tween:
		_enhanced_tween.kill()

	if not enhanced_border:
		return

	enhanced_border.modulate = ENHANCED_COLOR

	_enhanced_tween = create_tween()
	_enhanced_tween.set_loops()

	# Pulse: bright -> dim -> bright
	_enhanced_tween.tween_property(enhanced_border, "modulate:a", 0.3, 0.4).set_ease(Tween.EASE_IN_OUT)
	_enhanced_tween.tween_property(enhanced_border, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_IN_OUT)


func _stop_enhanced_pulse() -> void:
	"""Stop the enhanced pulse animation."""
	if _enhanced_tween:
		_enhanced_tween.kill()
		_enhanced_tween = null


func _exit_tree() -> void:
	"""Clean up infinite loop tween when node is freed."""
	if _enhanced_tween:
		_enhanced_tween.kill()
		_enhanced_tween = null
