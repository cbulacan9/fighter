class_name ManaBarUI
extends Control

signal clicked()

## Fill color for normal state (partial fill)
@export var fill_color: Color = Color(0.3, 0.5, 1.0)
## Fill color when bar is full
@export var full_color: Color = Color(0.5, 0.8, 1.0)
## Fill color when mana is blocked
@export var blocked_color: Color = Color(0.5, 0.5, 0.5)
## Background color
@export var background_color: Color = Color(0.15, 0.15, 0.2)
## Glow color for full state
@export var glow_color: Color = Color(0.7, 0.9, 1.0, 0.3)
## Show glow effect when bar is full
@export var glow_when_full: bool = true
## Show the value label
@export var show_value_label: bool = false
## Animate value changes
@export var animate_changes: bool = true
## Duration of fill animation
@export var animation_duration: float = 0.2
## Glow pulse speed (cycles per second)
@export var glow_pulse_speed: float = 2.0

@onready var background: ColorRect = $Background
@onready var fill: ColorRect = $Fill
@onready var glow: ColorRect = $Glow
@onready var label: Label = $Label

var _current_value: int = 0
var _max_value: int = 100
var _is_blocked: bool = false
var _is_full: bool = false
var _tween: Tween
var _glow_tween: Tween
var _glow_pulsing: bool = false


func _ready() -> void:
	if glow:
		glow.visible = false
	if label:
		label.visible = show_value_label
	_update_display()


func _process(delta: float) -> void:
	# Update glow pulse if needed
	if glow and _glow_pulsing and not _glow_tween:
		_start_glow_pulse()


func setup(max_value: int) -> void:
	_max_value = maxi(1, max_value)  # Ensure at least 1 to avoid division by zero
	_current_value = 0
	_is_full = false
	_is_blocked = false
	_update_display()


func set_value(current: int, max_value: int = -1) -> void:
	if max_value > 0:
		_max_value = max_value

	var previous := _current_value
	_current_value = clampi(current, 0, _max_value)
	_is_full = _current_value >= _max_value

	if animate_changes and previous != _current_value:
		_animate_fill(previous, _current_value)
	else:
		_update_display()


func set_blocked(blocked: bool) -> void:
	if _is_blocked == blocked:
		return
	_is_blocked = blocked
	_update_display()


func get_value() -> int:
	return _current_value


func get_max_value() -> int:
	return _max_value


func is_full() -> bool:
	return _is_full


func is_blocked() -> bool:
	return _is_blocked


func _update_display() -> void:
	if not is_inside_tree():
		return

	# Calculate fill percentage
	var percentage := 0.0
	if _max_value > 0:
		percentage = clampf(float(_current_value) / float(_max_value), 0.0, 1.0)

	# Update fill width using anchor
	if fill:
		fill.anchor_right = percentage

	# Update fill color based on state
	if fill:
		if _is_blocked:
			fill.color = blocked_color
		elif _is_full:
			fill.color = full_color
		else:
			fill.color = fill_color

	# Update glow visibility and effect
	_update_glow()

	# Update label text
	if label:
		label.visible = show_value_label
		if show_value_label:
			label.text = "%d/%d" % [_current_value, _max_value]


func _update_glow() -> void:
	if not glow:
		return

	var should_show_glow := glow_when_full and _is_full and not _is_blocked

	if should_show_glow:
		glow.visible = true
		if not _glow_pulsing:
			_glow_pulsing = true
			_start_glow_pulse()
	else:
		glow.visible = false
		_glow_pulsing = false
		_stop_glow_pulse()


func _start_glow_pulse() -> void:
	if not glow or not _glow_pulsing:
		return

	if _glow_tween:
		_glow_tween.kill()

	# Calculate pulse duration from speed
	var pulse_duration := 1.0 / glow_pulse_speed if glow_pulse_speed > 0 else 0.5

	_glow_tween = create_tween()
	_glow_tween.set_loops()  # Infinite loop
	_glow_tween.set_ease(Tween.EASE_IN_OUT)
	_glow_tween.set_trans(Tween.TRANS_SINE)

	# Pulse alpha between 0.2 and 0.5
	var base_color := glow_color
	var dim_color := Color(base_color.r, base_color.g, base_color.b, 0.15)
	var bright_color := Color(base_color.r, base_color.g, base_color.b, 0.5)

	glow.color = dim_color
	_glow_tween.tween_property(glow, "color", bright_color, pulse_duration)
	_glow_tween.tween_property(glow, "color", dim_color, pulse_duration)


func _stop_glow_pulse() -> void:
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null


func _animate_fill(from: int, to: int) -> void:
	if _tween:
		_tween.kill()

	if not fill or not is_inside_tree():
		_update_display()
		return

	var from_pct := clampf(float(from) / float(_max_value), 0.0, 1.0)
	var to_pct := clampf(float(to) / float(_max_value), 0.0, 1.0)

	# Set starting position
	fill.anchor_right = from_pct

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(fill, "anchor_right", to_pct, animation_duration)
	_tween.tween_callback(_update_display)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			clicked.emit()
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_stop_glow_pulse()
		if _tween:
			_tween.kill()
