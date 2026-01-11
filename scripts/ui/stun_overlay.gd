class_name StunOverlay
extends Control

const FADE_DURATION: float = 0.15

@onready var darken: ColorRect = $Darken
@onready var stun_label: Label = $StunLabel

var is_active: bool = false
var _remaining_time: float = 0.0
var _tween: Tween


func _ready() -> void:
	visible = false
	modulate.a = 0.0


func _process(delta: float) -> void:
	if is_active and _remaining_time > 0:
		_remaining_time -= delta
		_update_timer_display()


func show_stun(duration: float) -> void:
	is_active = true
	_remaining_time = duration
	visible = true
	_update_timer_display()

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)


func hide_stun() -> void:
	is_active = false

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_tween.tween_callback(_on_fade_complete)


func update_timer(remaining: float) -> void:
	_remaining_time = remaining
	_update_timer_display()


func _update_timer_display() -> void:
	if stun_label:
		if _remaining_time > 0:
			stun_label.text = "%.1fs" % _remaining_time
		else:
			stun_label.text = ""


func _on_fade_complete() -> void:
	visible = false


func set_overlay_size(width: float, height: float) -> void:
	custom_minimum_size = Vector2(width, height)
	size = Vector2(width, height)
	if darken:
		darken.size = Vector2(width, height)
