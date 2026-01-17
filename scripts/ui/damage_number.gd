class_name DamageNumber
extends Node2D

enum EffectType {
	DAMAGE,
	HEAL,
	ARMOR,
	STUN,
	MISS
}

const COLORS := {
	EffectType.DAMAGE: Color(1.0, 0.27, 0.27),   # Red
	EffectType.HEAL: Color(0.27, 1.0, 0.27),     # Green
	EffectType.ARMOR: Color(0.27, 0.27, 1.0),    # Blue
	EffectType.STUN: Color(1.0, 1.0, 0.27),      # Yellow
	EffectType.MISS: Color(0.7, 0.7, 0.7)        # Gray
}

const PREFIXES := {
	EffectType.DAMAGE: "-",
	EffectType.HEAL: "+",
	EffectType.ARMOR: "+",
	EffectType.STUN: "",
	EffectType.MISS: ""
}

const ANIMATION_DURATION: float = 1.0
const FLOAT_DISTANCE: float = 50.0

@onready var label: Label = $Label

var _tween: Tween


func setup(value: float, type: EffectType, pos: Vector2) -> void:
	position = pos

	var prefix: String = PREFIXES.get(type, "")
	var color: Color = COLORS.get(type, Color.WHITE)

	if type == EffectType.MISS:
		label.text = "MISS"
	elif type == EffectType.STUN:
		label.text = "%.1fs" % value
	elif type == EffectType.ARMOR:
		label.text = "%s%d" % [prefix, int(value)]
	else:
		label.text = "%s%d" % [prefix, int(value)]

	label.add_theme_color_override("font_color", color)

	# Add random X offset to prevent stacking
	position.x += randf_range(-10.0, 10.0)


func play() -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	# Float upward
	_tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, ANIMATION_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Scale pop
	_tween.tween_property(self, "scale", Vector2(1.2, 1.2), ANIMATION_DURATION * 0.2) \
		.set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), ANIMATION_DURATION * 0.1)

	# Fade out at end
	_tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION * 0.3) \
		.set_delay(ANIMATION_DURATION * 0.7)

	# Queue free when done
	_tween.chain().tween_callback(queue_free)
