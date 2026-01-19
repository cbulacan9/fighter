class_name AbilityAnnouncement
extends Control

## Displays a floating announcement when abilities are activated

const DISPLAY_DURATION := 2.0
const FADE_DURATION := 0.5
const FLOAT_DISTANCE := 30.0

@onready var label: Label = $Label
@onready var effect_label: Label = $EffectLabel

var _start_pos: Vector2
var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	visible = false


func show_announcement(ability_name: String, effect_description: String, color: Color = Color.WHITE) -> void:
	if label:
		label.text = ability_name
		label.add_theme_color_override("font_color", color)

	if effect_label:
		effect_label.text = effect_description

	_start_pos = position
	modulate.a = 1.0
	visible = true

	# Use tween instead of _process for animation
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	# Float upward over full duration
	_tween.tween_property(self, "position:y", _start_pos.y - FLOAT_DISTANCE, DISPLAY_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Stay visible, then fade out in last portion
	_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION) \
		.set_delay(DISPLAY_DURATION - FADE_DURATION)

	# Queue free when done
	_tween.chain().tween_callback(queue_free)
