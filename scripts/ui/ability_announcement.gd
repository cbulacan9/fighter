class_name AbilityAnnouncement
extends Control

## Displays a floating announcement when abilities are activated

const DISPLAY_DURATION := 2.0
const FADE_DURATION := 0.5
const FLOAT_DISTANCE := 30.0

@onready var label: Label = $Label
@onready var effect_label: Label = $EffectLabel

var _timer: float = 0.0
var _start_pos: Vector2


func _ready() -> void:
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return

	_timer -= delta

	if _timer <= 0:
		visible = false
		queue_free()
		return

	# Float upward
	var progress := 1.0 - (_timer / DISPLAY_DURATION)
	position.y = _start_pos.y - (progress * FLOAT_DISTANCE)

	# Fade out in last portion
	if _timer < FADE_DURATION:
		modulate.a = _timer / FADE_DURATION
	else:
		modulate.a = 1.0


func show_announcement(ability_name: String, effect_description: String, color: Color = Color.WHITE) -> void:
	if label:
		label.text = ability_name
		label.add_theme_color_override("font_color", color)

	if effect_label:
		effect_label.text = effect_description

	_start_pos = position
	_timer = DISPLAY_DURATION
	modulate.a = 1.0
	visible = true
