class_name ManaBar
extends RefCounted

signal mana_changed(current: int, max_value: int)
signal mana_full()
signal mana_empty()

var current: int = 0
var max_value: int = 100
var is_blocked: bool = false
var _block_timer: float = 0.0


func _init(max_mana: int = 100) -> void:
	max_value = max_mana
	current = 0


func add(amount: int) -> int:
	if is_blocked:
		return 0

	var previous := current
	current = mini(current + amount, max_value)
	var actual_gain := current - previous

	if actual_gain > 0:
		mana_changed.emit(current, max_value)
		if current >= max_value:
			mana_full.emit()

	return actual_gain


func drain(amount: int) -> int:
	var previous := current
	current = maxi(current - amount, 0)
	var actual_drain := previous - current

	if actual_drain > 0:
		mana_changed.emit(current, max_value)
		if current <= 0:
			mana_empty.emit()

	return actual_drain


func drain_all() -> int:
	var drained := current
	current = 0
	mana_changed.emit(current, max_value)
	mana_empty.emit()
	return drained


func is_full() -> bool:
	return current >= max_value


func is_empty() -> bool:
	return current <= 0


func get_percentage() -> float:
	if max_value <= 0:
		return 0.0
	return float(current) / float(max_value)


func block(duration: float) -> void:
	is_blocked = true
	_block_timer = duration


func tick(delta: float) -> void:
	if is_blocked and _block_timer > 0:
		_block_timer -= delta
		if _block_timer <= 0:
			is_blocked = false
			_block_timer = 0.0


func reset() -> void:
	current = 0
	is_blocked = false
	_block_timer = 0.0
	mana_changed.emit(current, max_value)
