class_name HealthBar
extends Control

const ANIMATION_DURATION: float = 0.2
const LOW_HP_THRESHOLD: float = 0.25

@onready var background: ColorRect = $Background
@onready var armor_fill: ColorRect = $ArmorFill
@onready var health_fill: ColorRect = $HealthFill
@onready var label: Label = $Label

var max_value: int = 100
var current_hp: int = 100
var current_armor: int = 0

var _tween: Tween


func setup(max_hp: int) -> void:
	max_value = max_hp
	current_hp = max_hp
	current_armor = 0
	_update_display(false)


func set_hp(value: int) -> void:
	current_hp = clampi(value, 0, max_value)
	_update_display(true)


func set_armor(value: int) -> void:
	current_armor = clampi(value, 0, max_value)
	_update_display(true)


func _update_display(animate: bool) -> void:
	if not is_inside_tree():
		return

	var total_width := size.x
	var hp_ratio := float(current_hp) / float(max_value) if max_value > 0 else 0.0
	var armor_ratio := float(current_armor) / float(max_value) if max_value > 0 else 0.0

	var target_hp_width := hp_ratio * total_width
	var target_armor_width := armor_ratio * total_width

	# Update health color based on HP level
	if hp_ratio <= LOW_HP_THRESHOLD:
		health_fill.color = Color(0.9, 0.2, 0.2)  # Red when low
	else:
		health_fill.color = Color(0.2, 0.8, 0.2)  # Green normally

	if animate:
		_animate_change(target_hp_width, target_armor_width)
	else:
		health_fill.size.x = target_hp_width
		armor_fill.size.x = target_armor_width

	if label:
		label.text = "%d/%d" % [current_hp, max_value]


func _animate_change(hp_width: float, armor_width: float) -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)

	_tween.tween_property(health_fill, "size:x", hp_width, ANIMATION_DURATION)
	_tween.tween_property(armor_fill, "size:x", armor_width, ANIMATION_DURATION)


func _ready() -> void:
	_update_display(false)
